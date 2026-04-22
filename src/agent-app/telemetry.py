"""
OpenTelemetry configuration for the MACU Agent App.
Sends traces, metrics, and logs to Application Insights.
"""
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry.trace import StatusCode
from config import Config


def configure_telemetry():
    """Initialize Azure Monitor OpenTelemetry with Application Insights."""
    configure_azure_monitor(
        connection_string=Config.APPINSIGHTS_CONNECTION_STRING,
        enable_live_metrics=True,
    )


def get_tracer(name: str = "macu-agent") -> trace.Tracer:
    """Get a tracer instance for creating custom spans."""
    return trace.get_tracer(name)


"""
Example: Instrument the RAG pipeline with custom spans.
"""
from telemetry import get_tracer, configure_telemetry
from opentelemetry import trace
from opentelemetry.trace import StatusCode

configure_telemetry()
tracer = get_tracer("macu-rag-pipeline")


def rag_pipeline(query: str) -> str:
    """Full RAG pipeline with distributed tracing."""
    with tracer.start_as_current_span("rag-pipeline") as parent_span:
        parent_span.set_attribute("query", query)

        # Step 1: Generate embedding for the query
        with tracer.start_as_current_span("generate-query-embedding") as span:
            embedding = generate_embedding(query)
            span.set_attribute("embedding.dimensions", len(embedding))

        # Step 2: Search for relevant documents
        with tracer.start_as_current_span("vector-search") as span:
            documents = search_documents(embedding)
            span.set_attribute("search.results_count", len(documents))
            span.set_attribute("search.index", "macu-knowledge-base")

        # Step 3: Build prompt with context
        with tracer.start_as_current_span("build-prompt") as span:
            prompt = build_prompt(query, documents)
            span.set_attribute("prompt.token_estimate", len(prompt.split()))

        # Step 4: Call LLM via APIM AI Gateway
        with tracer.start_as_current_span("llm-completion") as span:
            response = call_llm_via_gateway(prompt)
            span.set_attribute("llm.model", "gpt-4o")
            span.set_attribute("llm.tokens.prompt", response.get("usage", {}).get("prompt_tokens", 0))
            span.set_attribute("llm.tokens.completion", response.get("usage", {}).get("completion_tokens", 0))
            span.set_attribute("llm.tokens.total", response.get("usage", {}).get("total_tokens", 0))

        parent_span.set_status(StatusCode.OK)
        return response["choices"][0]["message"]["content"]