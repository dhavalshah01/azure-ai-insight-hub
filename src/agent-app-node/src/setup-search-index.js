/**
 * One-time setup: Create Azure AI Search index and upload sample documents.
 * Run this script once before starting the agent app.
 *
 * Usage: npm run setup-index
 */
import { SearchIndexClient, SearchClient } from '@azure/search-documents';
import { DefaultAzureCredential } from '@azure/identity';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { config } from './config.js';
import { AIGatewayClient } from './aiGatewayClient.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Create the search index with vector search support.
 */
async function createIndex() {
  const credential = new DefaultAzureCredential();
  const indexClient = new SearchIndexClient(config.searchEndpoint, credential);

  const index = {
    name: config.searchIndexName,
    fields: [
      { name: 'id', type: 'Edm.String', key: true },
      { name: 'title', type: 'Edm.String', searchable: true },
      { name: 'content', type: 'Edm.String', searchable: true },
      { name: 'source', type: 'Edm.String', filterable: true },
      {
        name: 'content_vector',
        type: 'Collection(Edm.Single)',
        searchable: true,
        vectorSearchDimensions: 1536,
        vectorSearchProfileName: 'macu-vector-profile',
      },
    ],
    vectorSearch: {
      algorithms: [
        {
          name: 'macu-hnsw',
          kind: 'hnsw',
          parameters: {
            metric: 'cosine',
            m: 4,
            efConstruction: 400,
            efSearch: 500,
          },
        },
      ],
      profiles: [
        {
          name: 'macu-vector-profile',
          algorithmConfigurationName: 'macu-hnsw',
        },
      ],
    },
    semantic: {
      configurations: [
        {
          name: 'macu-semantic-config',
          prioritizedFields: {
            contentFields: [{ name: 'content' }],
          },
        },
      ],
    },
  };

  await indexClient.createOrUpdateIndex(index);
  console.log(`Index '${config.searchIndexName}' created successfully.`);
}

/**
 * Upload sample documents with embeddings.
 */
async function uploadDocuments() {
  const credential = new DefaultAzureCredential();
  const searchClient = new SearchClient(
    config.searchEndpoint,
    config.searchIndexName,
    credential
  );
  const gateway = new AIGatewayClient();

  // Read sample documents
  const docsPath = join(__dirname, '..', 'data', 'sample_docs.json');
  const documents = JSON.parse(readFileSync(docsPath, 'utf8'));

  // Generate embeddings for each document
  for (const doc of documents) {
    const embedding = await gateway.getEmbedding(doc.content);
    doc.content_vector = embedding;
    console.log(`Generated embedding for: ${doc.title}`);
  }

  // Upload documents
  const result = await searchClient.uploadDocuments(documents);
  console.log(`Uploaded ${result.results.length} documents.`);
}

// Main
async function main() {
  try {
    console.log('Setting up Azure AI Search index...');
    await createIndex();
    await uploadDocuments();
    console.log('Setup complete!');
  } catch (error) {
    console.error('Setup failed:', error);
    process.exit(1);
  }
}

main();
