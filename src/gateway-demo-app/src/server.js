import express from 'express';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadConfig } from './config.js';

let config;
try {
  config = loadConfig();
} catch (err) {
  console.error(`Configuration error: ${err.message}`);
  process.exit(1);
}

const publicDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'public');
const app = express();
app.use(express.json({ limit: '64kb' }));
app.use(express.static(publicDir));

const toNumber = (value) => {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
};

// Keys stay on the server; the browser only learns whether a key is configured
app.get('/api/config', (req, res) => {
  res.json({
    gatewayUrl: config.gatewayUrl,
    model: config.chatModel,
    products: config.products,
    subscriptions: config.subscriptions.map(({ key, ...subscription }) => ({
      ...subscription,
      hasKey: Boolean(key),
    })),
  });
});

app.post('/api/chat', async (req, res) => {
  const { subscriptionId, prompt, maxTokens, uniquePrompt = true } = req.body ?? {};

  const subscription = config.subscriptions.find((s) => s.id === subscriptionId);
  if (!subscription) {
    return res.status(400).json({ error: `Unknown subscription "${subscriptionId}"` });
  }
  if (!subscription.key) {
    return res.status(400).json({
      error: `No key configured for "${subscription.id}". Set its _KEY value in .env and restart the app.`,
    });
  }
  if (typeof prompt !== 'string' || !prompt.trim()) {
    return res.status(400).json({ error: 'Prompt is required' });
  }

  const tokens = Math.min(Math.max(parseInt(maxTokens, 10) || 500, 1), 4000);
  // A unique suffix makes every prompt different, so the APIM response cache is bypassed
  const content = uniquePrompt ? `${prompt.trim()}\n\n(Request id: ${randomUUID()})` : prompt.trim();

  const url =
    `${config.gatewayUrl}/openai/deployments/${encodeURIComponent(config.chatModel)}` +
    `/chat/completions?api-version=${encodeURIComponent(config.apiVersion)}`;

  const started = Date.now();
  const result = {
    subscriptionId: subscription.id,
    productId: subscription.productId,
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Ocp-Apim-Subscription-Key': subscription.key,
      },
      body: JSON.stringify({
        messages: [{ role: 'user', content }],
        max_tokens: tokens,
      }),
      signal: AbortSignal.timeout(120_000),
    });

    const text = await response.text();
    let body = null;
    try {
      body = JSON.parse(text);
    } catch {
      // Non-JSON body (for example an HTML error page); reported as text below
    }

    const header = (name) => response.headers.get(name);
    res.json({
      ...result,
      status: response.status,
      latencyMs: Date.now() - started,
      tokensConsumed: toNumber(header('x-tokens-consumed')),
      tokensRemaining: toNumber(header('x-tokens-remaining')),
      promptTokens: toNumber(header('x-prompt-tokens')),
      completionTokens: toNumber(header('x-completion-tokens')),
      backendRegion: header('x-backend-region'),
      traceId: header('x-trace-id'),
      retryAfter: toNumber(header('retry-after')),
      answer: body?.choices?.[0]?.message?.content ?? null,
      error: response.ok
        ? null
        : body?.error?.message || body?.message || text.slice(0, 500) || response.statusText,
    });
  } catch (err) {
    res.json({
      ...result,
      status: 0,
      latencyMs: Date.now() - started,
      error: `Could not reach the APIM gateway: ${err.cause?.code || err.message}`,
    });
  }
});

app.listen(config.port, () => {
  console.log(`Gateway demo app running at http://localhost:${config.port}`);
  console.log(`APIM gateway: ${config.gatewayUrl}`);
  for (const s of config.subscriptions) {
    console.log(`  ${s.id.padEnd(22)} product=${s.productId.padEnd(10)} key=${s.key ? 'configured' : 'MISSING'}`);
  }
});
