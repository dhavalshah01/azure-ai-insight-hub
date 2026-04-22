"""
MACU Agent App — FastAPI application with RAG pipeline.
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from telemetry import configure_telemetry
from rag_pipeline import RAGPipeline
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# Initialize telemetry BEFORE creating the app
configure_telemetry()

app = FastAPI(title="MACU AI Agent", version="1.0.0")
FastAPIInstrumentor.instrument_app(app)

rag = RAGPipeline()


class ChatRequest(BaseModel):
    query: str
    max_tokens: int = 1000


class ChatResponse(BaseModel):
    answer: str
    sources: list[str]
    usage: dict


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Handle a chat request through the RAG pipeline."""
    try:
        result = await rag.run(request.query)
        return ChatResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))