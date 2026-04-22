"""Configuration loaded from environment variables."""
import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    # APIM AI Gateway
    APIM_GATEWAY_URL = os.environ["APIM_GATEWAY_URL"]          # e.g., https://apim-macu-poc.azure-api.net
    APIM_SUBSCRIPTION_KEY = os.environ["APIM_SUBSCRIPTION_KEY"]  # Team subscription key

    # Azure AI Search
    SEARCH_ENDPOINT = os.environ["SEARCH_ENDPOINT"]             # e.g., https://srch-macu-poc.search.windows.net
    SEARCH_INDEX_NAME = os.environ.get("SEARCH_INDEX_NAME", "macu-knowledge-base")

    # Application Insights
    APPINSIGHTS_CONNECTION_STRING = os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"]

    # Model deployments (via APIM gateway)
    CHAT_MODEL = os.environ.get("CHAT_MODEL", "gpt-4o")
    EMBEDDING_MODEL = os.environ.get("EMBEDDING_MODEL", "text-embedding-ada-002")
    API_VERSION = os.environ.get("OPENAI_API_VERSION", "2024-10-21")