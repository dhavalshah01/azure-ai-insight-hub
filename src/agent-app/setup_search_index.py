"""
One-time setup: Create Azure AI Search index and upload sample documents.
Run this script once before starting the agent app.
"""
import json
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SimpleField,
    SearchableField,
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
    SemanticConfiguration,
    SemanticSearch,
    SemanticPrioritizedFields,
    SemanticField,
)
from azure.search.documents import SearchClient
from azure.identity import DefaultAzureCredential
from config import Config


def create_index():
    """Create the search index with vector search support."""
    credential = DefaultAzureCredential()
    index_client = SearchIndexClient(
        endpoint=Config.SEARCH_ENDPOINT, credential=credential
    )

    fields = [
        SimpleField(name="id", type=SearchFieldDataType.String, key=True),
        SearchableField(name="title", type=SearchFieldDataType.String),
        SearchableField(name="content", type=SearchFieldDataType.String),
        SimpleField(name="source", type=SearchFieldDataType.String, filterable=True),
        SearchField(
            name="content_vector",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=1536,
            vector_search_profile_name="macu-vector-profile",
        ),
    ]

    vector_search = VectorSearch(
        algorithms=[HnswAlgorithmConfiguration(name="macu-hnsw")],
        profiles=[
            VectorSearchProfile(
                name="macu-vector-profile",
                algorithm_configuration_name="macu-hnsw",
            )
        ],
    )

    semantic_config = SemanticConfiguration(
        name="macu-semantic-config",
        prioritized_fields=SemanticPrioritizedFields(
            content_fields=[SemanticField(field_name="content")]
        ),
    )

    index = SearchIndex(
        name=Config.SEARCH_INDEX_NAME,
        fields=fields,
        vector_search=vector_search,
        semantic_search=SemanticSearch(configurations=[semantic_config]),
    )

    index_client.create_or_update_index(index)
    print(f"Index '{Config.SEARCH_INDEX_NAME}' created successfully.")


def upload_documents():
    """Upload sample documents with embeddings."""
    import asyncio
    from ai_gateway_client import AIGatewayClient

    credential = DefaultAzureCredential()
    search_client = SearchClient(
        endpoint=Config.SEARCH_ENDPOINT,
        index_name=Config.SEARCH_INDEX_NAME,
        credential=credential,
    )
    gateway = AIGatewayClient()

    with open("data/sample_docs.json", "r") as f:
        documents = json.load(f)

    async def add_embeddings():
        for doc in documents:
            embedding = await gateway.get_embedding(doc["content"])
            doc["content_vector"] = embedding
            print(f"Generated embedding for: {doc['title']}")

    asyncio.run(add_embeddings())

    result = search_client.upload_documents(documents)
    print(f"Uploaded {len(result)} documents.")


if __name__ == "__main__":
    create_index()
    upload_documents()