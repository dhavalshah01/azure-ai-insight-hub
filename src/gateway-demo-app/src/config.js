import 'dotenv/config';

// "rate-limit-tester" -> "RATE_LIMIT_TESTER"
const toEnvKey = (id) => id.toUpperCase().replace(/[^A-Z0-9]/g, '_');

const list = (value) =>
  (value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

function loadProducts() {
  const ids = list(process.env.PRODUCTS);
  if (ids.length === 0) {
    throw new Error('PRODUCTS is not set in .env (for example: PRODUCTS=free,standard,premium)');
  }

  return ids.map((id) => {
    const prefix = `PRODUCT_${toEnvKey(id)}`;
    const tpm = Number(process.env[`${prefix}_TPM`]);
    return {
      id,
      displayName: process.env[`${prefix}_DISPLAY_NAME`] || id,
      tokensPerMinute: Number.isFinite(tpm) && tpm > 0 ? tpm : null,
    };
  });
}

function loadSubscriptions(products) {
  const ids = list(process.env.SUBSCRIPTIONS);
  if (ids.length === 0) {
    throw new Error('SUBSCRIPTIONS is not set in .env (for example: SUBSCRIPTIONS=rate-limit-tester,lending-team)');
  }

  const productIds = products.map((product) => product.id);

  return ids.map((id) => {
    const prefix = `SUBSCRIPTION_${toEnvKey(id)}`;
    const productId = (process.env[`${prefix}_PRODUCT`] || '').trim();
    if (!productIds.includes(productId)) {
      throw new Error(`${prefix}_PRODUCT must be one of: ${productIds.join(', ')} (found "${productId}")`);
    }

    const key = (process.env[`${prefix}_KEY`] || '').trim();
    return {
      id,
      displayName: process.env[`${prefix}_DISPLAY_NAME`] || id,
      productId,
      key: key.startsWith('<') ? '' : key,
    };
  });
}

export function loadConfig() {
  const gatewayUrl = (process.env.APIM_GATEWAY_URL || '').trim().replace(/\/+$/, '');
  if (!gatewayUrl || gatewayUrl.includes('<')) {
    throw new Error('APIM_GATEWAY_URL is not set in .env');
  }

  const products = loadProducts();

  return {
    gatewayUrl,
    chatModel: process.env.CHAT_MODEL || 'gpt-4o',
    apiVersion: process.env.OPENAI_API_VERSION || '2024-10-21',
    port: Number(process.env.PORT) || 8100,
    products,
    subscriptions: loadSubscriptions(products),
  };
}
