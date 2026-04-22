"""
RAG Pipeline — end-to-end retrieval-augmented generation with full tracing.
"""
from opentelemetry import trace
from opentelemetry.trace import StatusCode
from ai_gateway_client import AIGatewayClient
from search_client import KnowledgeBaseSearch

tracer = trace.get_tracer("macu-rag-pipeline")

SYSTEM_PROMPT = """You are a helpful AI assistant for MACU (Mountain America Credit Union) employees.
Use the provided context to answer questions accurately. If the context doesn't contain
relevant information, say so clearly. Always cite source documents when possible."""


class RAGPipeline:
    """Retrieval-Augmented Generation pipeline with observability."""

    def __init__(self):
        self.gateway = AIGatewayClient()
        self.search = KnowledgeBaseSearch()

    async def run(self, user_query: str) -> dict:
        """Execute the full RAG pipeline with distributed tracing."""
        with tracer.start_as_current_span("rag-pipeline") as pipeline_span:
            pipeline_span.set_attribute("user.query", user_query)

            # Step 1: Generate query embedding
            with tracer.start_as_current_span("rag.generate-embedding"):
                embedding = await self.gateway.get_embedding(user_query)

            # Step 2: Search knowledge base
            with tracer.start_as_current_span("rag.vector-search"):
                documents = self.search.search(user_query, embedding, top_k=5)

            # Step 3: Build augmented prompt
            with tracer.start_as_current_span("rag.build-prompt") as span:
                context = self._build_context(documents)
                messages = [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {user_query}"},
                ]
                span.set_attribute("context.documents", len(documents))
                span.set_attribute("context.length", len(context))

            # Step 4: Call LLM via AI Gateway
            with tracer.start_as_current_span("rag.llm-completion"):
                response = await self.gateway.chat_completion(messages, max_tokens=1000)

            answer = response["choices"][0]["message"]["content"]
            usage = response.get("usage", {})

            pipeline_span.set_attribute("tokens.total", usage.get("total_tokens", 0))
            pipeline_span.set_status(StatusCode.OK)

            return {
                "answer": answer,
                "sources": [d["source"] for d in documents if d.get("source")],
                "usage": usage,
            }

    @staticmethod
    def _build_context(documents: list[dict]) -> str:
        """Format retrieved documents as context for the LLM."""
        parts = []
        for i, doc in enumerate(documents, 1):
            parts.append(f"[{i}] {doc['title']}\n{doc['content']}\nSource: {doc['source']}")
        return "\n\n".join(parts)