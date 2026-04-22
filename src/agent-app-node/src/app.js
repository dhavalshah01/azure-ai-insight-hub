/**
 * MACU Agent App — Express application with RAG pipeline.
 */

// Initialize telemetry BEFORE importing other modules
import { configureTelemetry } from './telemetry.js';
configureTelemetry();

import express from 'express';
import { RAGPipeline } from './ragPipeline.js';
import { config } from './config.js';

const app = express();
app.use(express.json());

const rag = new RAGPipeline();

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Chat endpoint
app.post('/chat', async (req, res) => {
  try {
    const { query, max_tokens = 1000 } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'query is required' });
    }

    const result = await rag.run(query);

    res.json({
      answer: result.answer,
      sources: result.sources,
      usage: result.usage,
    });
  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Start server
app.listen(config.port, () => {
  console.log(`MACU AI Agent (Node.js) running on http://localhost:${config.port}`);
  console.log('Endpoints:');
  console.log(`  GET  /health - Health check`);
  console.log(`  POST /chat   - Chat with RAG pipeline`);
});
