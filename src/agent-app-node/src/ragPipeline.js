/**
 * RAG Pipeline — end-to-end retrieval-augmented generation with full tracing.
 */
import { getTracer, SpanStatusCode } from './telemetry.js';
import { AIGatewayClient } from './aiGatewayClient.js';
import { KnowledgeBaseSearch } from './searchClient.js';

const tracer = getTracer('macu-rag-pipeline');

const SYSTEM_PROMPT = `You are a helpful AI assistant for MACU (Mountain America Credit Union) employees.
Use the provided context to answer questions accurately. If the context doesn't contain
relevant information, say so clearly. Always cite source documents when possible.`;

/**
 * Retrieval-Augmented Generation pipeline with observability.
 */
export class RAGPipeline {
  constructor() {
    this.gateway = new AIGatewayClient();
    this.search = new KnowledgeBaseSearch();
  }

  /**
   * Execute the full RAG pipeline with distributed tracing.
   * @param {string} userQuery - User's question
   * @returns {Promise<{answer: string, sources: string[], usage: object}>}
   */
  async run(userQuery) {
    const pipelineSpan = tracer.startSpan('rag-pipeline');
    pipelineSpan.setAttribute('user.query', userQuery);

    try {
      // Step 1: Generate query embedding
      const embeddingSpan = tracer.startSpan('rag.generate-embedding');
      let embedding;
      try {
        embedding = await this.gateway.getEmbedding(userQuery);
      } finally {
        embeddingSpan.end();
      }

      // Step 2: Search knowledge base
      const searchSpan = tracer.startSpan('rag.vector-search');
      let documents;
      try {
        documents = await this.search.search(userQuery, embedding, 5);
      } finally {
        searchSpan.end();
      }

      // Step 3: Build augmented prompt
      const promptSpan = tracer.startSpan('rag.build-prompt');
      let messages;
      try {
        const context = this._buildContext(documents);
        messages = [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: `Context:\n${context}\n\nQuestion: ${userQuery}` },
        ];
        promptSpan.setAttribute('context.documents', documents.length);
        promptSpan.setAttribute('context.length', context.length);
      } finally {
        promptSpan.end();
      }

      // Step 4: Call LLM via AI Gateway
      const completionSpan = tracer.startSpan('rag.llm-completion');
      let response;
      try {
        response = await this.gateway.chatCompletion(messages, 1000);
      } finally {
        completionSpan.end();
      }

      const answer = response.choices[0].message.content;
      const usage = response.usage || {};

      pipelineSpan.setAttribute('tokens.total', usage.total_tokens || 0);
      pipelineSpan.setStatus({ code: SpanStatusCode.OK });

      return {
        answer,
        sources: documents.filter(d => d.source).map(d => d.source),
        usage,
      };
    } catch (error) {
      pipelineSpan.recordException(error);
      pipelineSpan.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
      throw error;
    } finally {
      pipelineSpan.end();
    }
  }

  /**
   * Format retrieved documents as context for the LLM.
   * @param {Array<{title: string, content: string, source: string}>} documents
   * @returns {string}
   */
  _buildContext(documents) {
    return documents
      .map((doc, i) => `[${i + 1}] ${doc.title}\n${doc.content}\nSource: ${doc.source}`)
      .join('\n\n');
  }
}
