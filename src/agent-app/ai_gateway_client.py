"""
Client for calling Azure OpenAI through the APIM AI Gateway.
All LLM calls are routed through APIM for governance.
"""
import httpx
from opentelemetry import trace
from config import Config

tracer = trace.get_tracer("macu-ai-gateway-client")


class AIGatewayClient:
    """Calls Azure OpenAI via the APIM AI Gateway."""

    def __init__(self):
        self.base_url = Config.APIM_GATEWAY_URL.rstrip("/")
        self.headers = {
            "Content-Type": "application/json",
            "Ocp-Apim-Subscription-Key": Config.APIM_SUBSCRIPTION_KEY,
        }

    async def get_embedding(self, text: str) -> list[float]:
        """Generate an embedding vector via APIM → Azure OpenAI."""
        with tracer.start_as_current_span("ai-gateway.embeddings") as span:
            span.set_attribute("model", Config.EMBEDDING_MODEL)
            span.set_attribute("input.length", len(text))

            url = (
                f"{self.base_url}/openai/deployments/{Config.EMBEDDING_MODEL}"
                f"/embeddings?api-version={Config.API_VERSION}"
            )

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    url,
                    headers=self.headers,
                    json={"input": text},
                    timeout=30.0,
                )
                response.raise_for_status()

            result = response.json()
            embedding = result["data"][0]["embedding"]

            span.set_attribute("embedding.dimensions", len(embedding))
            # Capture gateway headers for observability
            span.set_attribute("gateway.trace_id", response.headers.get("x-trace-id", ""))
            span.set_attribute("gateway.region", response.headers.get("x-backend-region", ""))

            return embedding

    async def chat_completion(self, messages: list[dict], max_tokens: int = 1000) -> dict:
        """Call chat completion via APIM → Azure OpenAI."""
        with tracer.start_as_current_span("ai-gateway.chat-completion") as span:
            span.set_attribute("model", Config.CHAT_MODEL)
            span.set_attribute("max_tokens", max_tokens)
            span.set_attribute("messages.count", len(messages))

            url = (
                f"{self.base_url}/openai/deployments/{Config.CHAT_MODEL}"
                f"/chat/completions?api-version={Config.API_VERSION}"
            )

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    url,
                    headers=self.headers,
                    json={"messages": messages, "max_tokens": max_tokens},
                    timeout=60.0,
                )
                response.raise_for_status()

            result = response.json()
            usage = result.get("usage", {})

            span.set_attribute("tokens.prompt", usage.get("prompt_tokens", 0))
            span.set_attribute("tokens.completion", usage.get("completion_tokens", 0))
            span.set_attribute("tokens.total", usage.get("total_tokens", 0))
            span.set_attribute("gateway.trace_id", response.headers.get("x-trace-id", ""))
            span.set_attribute("gateway.region", response.headers.get("x-backend-region", ""))
            span.set_attribute("gateway.tokens_remaining",
                               response.headers.get("x-tokens-remaining", ""))

            return result