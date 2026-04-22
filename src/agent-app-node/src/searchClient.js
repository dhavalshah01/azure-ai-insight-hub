/**
 * Azure AI Search client for vector/hybrid search.
 */
import { SearchClient } from '@azure/search-documents';
import { DefaultAzureCredential } from '@azure/identity';
import { getTracer } from './telemetry.js';
import { config } from './config.js';

const tracer = getTracer('macu-search-client');

/**
 * Search the MACU knowledge base using vector search.
 */
export class KnowledgeBaseSearch {
  constructor() {
    const credential = new DefaultAzureCredential();
    this.client = new SearchClient(
      config.searchEndpoint,
      config.searchIndexName,
      credential
    );
  }

  /**
   * Hybrid search: keyword + vector similarity.
   * @param {string} query - Search query text
   * @param {number[]} embedding - Query embedding vector
   * @param {number} topK - Number of results to return
   * @returns {Promise<Array<{title: string, content: string, source: string, score: number}>>}
   */
  async search(query, embedding, topK = 5) {
    const span = tracer.startSpan('knowledge-base.search');

    try {
      span.setAttribute('query', query);
      span.setAttribute('top_k', topK);
      span.setAttribute('index', config.searchIndexName);

      const searchResults = await this.client.search(query, {
        vectorSearchOptions: {
          queries: [
            {
              kind: 'vector',
              vector: embedding,
              kNearestNeighborsCount: topK,
              fields: ['content_vector'],
            },
          ],
        },
        select: ['title', 'content', 'source'],
        top: topK,
      });

      const documents = [];
      for await (const result of searchResults.results) {
        documents.push({
          title: result.document.title || '',
          content: result.document.content || '',
          source: result.document.source || '',
          score: result.score || 0,
        });
      }

      span.setAttribute('results.count', documents.length);
      return documents;
    } catch (error) {
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  }
}
