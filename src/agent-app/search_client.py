"""
Azure AI Search client for vector/hybrid search.
"""
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from azure.identity import DefaultAzureCredential
from opentelemetry import trace
from config import Config

tracer = trace.get_tracer("macu-search-client")


class KnowledgeBaseSearch:
    """Search the MACU knowledge base using vector search."""

    def __init__(self):
        credential = DefaultAzureCredential()
        self.client = SearchClient(
            endpoint=Config.SEARCH_ENDPOINT,
            index_name=Config.SEARCH_INDEX_NAME,
            credential=credential,
        )

    def search(self, query: str, embedding: list[float], top_k: int = 5) -> list[dict]:
        """Hybrid search: keyword + vector similarity."""
        with tracer.start_as_current_span("knowledge-base.search") as span:
            span.set_attribute("query", query)
            span.set_attribute("top_k", top_k)
            span.set_attribute("index", Config.SEARCH_INDEX_NAME)

            results = self.client.search(
                search_text=query,
                vector_queries=[
                    VectorizedQuery(
                        vector=embedding,
                        k_nearest_neighbors=top_k,
                        fields="content_vector",
                    )
                ],
                select=["title", "content", "source"],
                top=top_k,
            )

            documents = []
            for result in results:
                documents.append({
                    "title": result.get("title", ""),
                    "content": result.get("content", ""),
                    "source": result.get("source", ""),
                    "score": result.get("@search.score", 0),
                })

            span.set_attribute("results.count", len(documents))
            return documents