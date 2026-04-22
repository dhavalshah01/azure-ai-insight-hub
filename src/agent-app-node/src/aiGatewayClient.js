/**
 * Client for calling Azure OpenAI through the APIM AI Gateway.
 * All LLM calls are routed through APIM for governance.
 */
import axios from 'axios';
import { getTracer } from './telemetry.js';
import { config } from './config.js';

const tracer = getTracer('macu-ai-gateway-client');

/**
 * Calls Azure OpenAI via the APIM AI Gateway.
 */
export class AIGatewayClient {
  constructor() {
    this.baseUrl = config.apimGatewayUrl.replace(/\/$/, '');
    this.headers = {
      'Content-Type': 'application/json',
      'Ocp-Apim-Subscription-Key': config.apimSubscriptionKey,
    };
  }

  /**
   * Generate an embedding vector via APIM → Azure OpenAI.
   * @param {string} text - Text to embed
   * @returns {Promise<number[]>} Embedding vector
   */
  async getEmbedding(text) {
    const span = tracer.startSpan('ai-gateway.embeddings');

    try {
      span.setAttribute('model', config.embeddingModel);
      span.setAttribute('input.length', text.length);

      const url = `${this.baseUrl}/openai/deployments/${config.embeddingModel}/embeddings?api-version=${config.apiVersion}`;

      const response = await axios.post(
        url,
        { input: text },
        { headers: this.headers, timeout: 30000 }
      );

      const embedding = response.data.data[0].embedding;

      span.setAttribute('embedding.dimensions', embedding.length);
      span.setAttribute('gateway.trace_id', response.headers['x-trace-id'] || '');
      span.setAttribute('gateway.region', response.headers['x-backend-region'] || '');

      return embedding;
    } catch (error) {
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  }

  /**
   * Call chat completion via APIM → Azure OpenAI.
   * @param {Array<{role: string, content: string}>} messages - Chat messages
   * @param {number} maxTokens - Max tokens for completion
   * @returns {Promise<object>} Chat completion response
   */
  async chatCompletion(messages, maxTokens = 1000) {
    const span = tracer.startSpan('ai-gateway.chat-completion');

    try {
      span.setAttribute('model', config.chatModel);
      span.setAttribute('max_tokens', maxTokens);
      span.setAttribute('messages.count', messages.length);

      const url = `${this.baseUrl}/openai/deployments/${config.chatModel}/chat/completions?api-version=${config.apiVersion}`;

      const response = await axios.post(
        url,
        { messages, max_tokens: maxTokens },
        { headers: this.headers, timeout: 60000 }
      );

      const result = response.data;
      const usage = result.usage || {};

      span.setAttribute('tokens.prompt', usage.prompt_tokens || 0);
      span.setAttribute('tokens.completion', usage.completion_tokens || 0);
      span.setAttribute('tokens.total', usage.total_tokens || 0);
      span.setAttribute('gateway.trace_id', response.headers['x-trace-id'] || '');
      span.setAttribute('gateway.region', response.headers['x-backend-region'] || '');
      span.setAttribute('gateway.tokens_remaining', response.headers['x-tokens-remaining'] || '');

      return result;
    } catch (error) {
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  }
}
