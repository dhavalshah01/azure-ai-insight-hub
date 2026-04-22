/**
 * Configuration loaded from environment variables.
 */
import dotenv from 'dotenv';

dotenv.config();

const requiredEnvVars = [
  'APIM_GATEWAY_URL',
  'APIM_SUBSCRIPTION_KEY',
  'SEARCH_ENDPOINT',
  'APPLICATIONINSIGHTS_CONNECTION_STRING'
];

for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    throw new Error(`Missing required environment variable: ${envVar}`);
  }
}

export const config = {
  // APIM AI Gateway
  apimGatewayUrl: process.env.APIM_GATEWAY_URL,
  apimSubscriptionKey: process.env.APIM_SUBSCRIPTION_KEY,

  // Azure AI Search
  searchEndpoint: process.env.SEARCH_ENDPOINT,
  searchIndexName: process.env.SEARCH_INDEX_NAME || 'macu-knowledge-base',

  // Application Insights
  appInsightsConnectionString: process.env.APPLICATIONINSIGHTS_CONNECTION_STRING,

  // Model deployments (via APIM gateway)
  chatModel: process.env.CHAT_MODEL || 'gpt-4o',
  embeddingModel: process.env.EMBEDDING_MODEL || 'text-embedding-ada-002',
  apiVersion: process.env.OPENAI_API_VERSION || '2024-10-21',

  // Server
  port: parseInt(process.env.PORT || '8000', 10),
};
