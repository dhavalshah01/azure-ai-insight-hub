# Agent App (Python) — Setup & Test Guide

This guide walks you through setting up and running the Python-based **RAG Agent App** locally. It assumes all Azure infrastructure (APIM, Azure OpenAI, AI Search, Application Insights) is already deployed.

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Python | 3.10 or later |
| pip | Latest |
| Azure CLI | 2.60+ (for `DefaultAzureCredential`) |
| Azure Infrastructure | APIM AI Gateway, Azure OpenAI, AI Search, App Insights deployed |

---

## Step 1 — Clone the Repository

```bash
git clone https://github.com/dhavalshah01/azure-ai-insight-hub.git
cd azure-ai-insight-hub/src/agent-app
```

---

## Step 2 — Create a Python Virtual Environment

```bash
python -m venv .venv
```

Activate the virtual environment:

- **Windows (PowerShell):**

  ```powershell
  .\.venv\Scripts\Activate.ps1
  ```

- **macOS / Linux:**

  ```bash
  source .venv/bin/activate
  ```

---

## Step 3 — Install Dependencies

```bash
pip install -r requirements.txt
```

This installs:

- `fastapi` / `uvicorn` — Web framework and ASGI server
- `openai` — Azure OpenAI SDK
- `azure-search-documents` — Azure AI Search client
- `azure-identity` — Managed Identity / `DefaultAzureCredential`
- `azure-monitor-opentelemetry` — Application Insights telemetry
- `opentelemetry-instrumentation-*` — Auto-instrumentation for FastAPI and HTTP clients
- `httpx` — Async HTTP client for APIM calls
- `python-dotenv` — Environment variable loading from `.env`

---

## Step 4 — Sign In to Azure

The search client uses `DefaultAzureCredential`, so you need an active Azure CLI session:

```bash
az login
```

If you have multiple subscriptions, set the correct one:

```bash
az account set --subscription "<your-subscription-id>"
```

---

## Step 5 — Configure Environment Variables

Create a `.env` file in the `src/agent-app` directory:

```bash
# --- Required ---
APIM_GATEWAY_URL=https://<your-apim-name>.azure-api.net
APIM_SUBSCRIPTION_KEY=<your-apim-subscription-key>
SEARCH_ENDPOINT=https://<your-search-service>.search.windows.net
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=<key>;IngestionEndpoint=https://<region>.in.applicationinsights.azure.com/

# --- Optional (defaults shown) ---
SEARCH_INDEX_NAME=macu-knowledge-base
CHAT_MODEL=gpt-4o
EMBEDDING_MODEL=text-embedding-ada-002
OPENAI_API_VERSION=2024-10-21
```

### Where to Find These Values

| Variable | Location |
|----------|----------|
| `APIM_GATEWAY_URL` | Azure Portal → API Management → Overview → Gateway URL |
| `APIM_SUBSCRIPTION_KEY` | Azure Portal → API Management → Subscriptions → Show/hide key |
| `SEARCH_ENDPOINT` | Azure Portal → AI Search → Overview → URL |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Azure Portal → Application Insights → Overview → Connection String |

---

## Step 6 — Create the Search Index and Upload Sample Data

This one-time setup creates the vector search index in Azure AI Search and uploads the sample documents from `data/sample_docs.json`:

```bash
python setup_search_index.py
```

**Expected output:**

```
Index 'macu-knowledge-base' created successfully.
Generated embedding for: MACU Auto Loan Rates
Generated embedding for: MACU Mortgage Products
Generated embedding for: MACU Digital Banking Features
Generated embedding for: MACU Branch Locations
Generated embedding for: MACU Security Policies
Uploaded 5 documents.
```

> **Note:** This script calls the APIM AI Gateway to generate embeddings for each document, so ensure your `APIM_GATEWAY_URL` and `APIM_SUBSCRIPTION_KEY` are correct.

---

## Step 7 — Run the Application

Start the FastAPI server:

```bash
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

**Expected output:**

```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Started reloader process
```

The app is now running at **http://localhost:8000**.

- Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)
- OpenAPI spec: [http://localhost:8000/openapi.json](http://localhost:8000/openapi.json)

---

## Test Cases

### Test 1 — Health Check

Verify the application is running.

```bash
curl http://localhost:8000/health
```

**Expected Response:**

```json
{"status": "healthy"}
```

---

### Test 2 — Basic RAG Query

Send a simple question that should be answered from the sample documents.

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "What are the current auto loan rates?"}'
```

**Expected Behavior:**
- Returns a JSON response with `answer`, `sources`, and `usage` fields
- `answer` references auto loan rates (5.49% APR for new, 5.99% for used)
- `sources` includes `macu-rates-2024.pdf`
- `usage` contains `prompt_tokens`, `completion_tokens`, `total_tokens`

**Example Response:**

```json
{
  "answer": "MACU offers auto loan rates starting at 5.49% APR for new vehicles...",
  "sources": ["macu-rates-2024.pdf"],
  "usage": {
    "prompt_tokens": 450,
    "completion_tokens": 120,
    "total_tokens": 570
  }
}
```

---

### Test 3 — Mortgage Products Query

Validate that the RAG pipeline retrieves mortgage-related content.

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "What mortgage options does MACU offer and what is the current 30-year rate?"}'
```

**Expected Behavior:**
- `answer` mentions fixed-rate, ARM, FHA, VA, jumbo loans, and 6.875% rate
- `sources` includes `macu-mortgage-guide.pdf`

---

### Test 4 — Cross-Document Query

Ask a question that may require information from multiple documents.

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "How does MACU protect member data and what digital banking features are available?"}'
```

**Expected Behavior:**
- `answer` covers both security policies (MFA, AES encryption, SOC 2) and digital banking features (mobile deposit, Zelle, biometric login)
- `sources` includes both `macu-security-policy.pdf` and `macu-digital-banking-faq.pdf`

---

### Test 5 — Out-of-Scope Query

Ask something not covered in the sample documents.

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "What is the weather forecast for tomorrow?"}'
```

**Expected Behavior:**
- The model should indicate that the context does not contain relevant information
- No meaningful sources returned

---

### Test 6 — Custom Max Tokens

Verify the `max_tokens` parameter works correctly.

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "Tell me about MACU branch locations", "max_tokens": 50}'
```

**Expected Behavior:**
- Response answer is shorter/truncated due to the low `max_tokens` limit
- `usage.completion_tokens` should be ≤ 50

---

### Test 7 — Invalid Request (Missing Query)

Verify the API validates the request body.

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected Response:** `422 Unprocessable Entity` with a validation error indicating `query` is required.

---

### Test 8 — PowerShell Test Script (Windows)

For convenience, you can run all tests from PowerShell:

```powershell
# Health Check
Invoke-RestMethod -Uri http://localhost:8000/health

# RAG Query
$body = @{ query = "What are the auto loan rates?" } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8000/chat -Method Post -Body $body -ContentType "application/json"

# Out-of-Scope Query
$body = @{ query = "What is the capital of France?" } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8000/chat -Method Post -Body $body -ContentType "application/json"

# Invalid Request
try {
    Invoke-RestMethod -Uri http://localhost:8000/chat -Method Post -Body "{}" -ContentType "application/json"
} catch {
    Write-Host "Expected 422 error: $($_.Exception.Response.StatusCode)"
}
```

---

## Verify Telemetry in Application Insights

After running the test cases, verify that traces appear in Application Insights:

1. Go to **Azure Portal → Application Insights → Transaction Search**
2. Filter by **Event types: Request**
3. You should see `POST /chat` and `GET /health` requests
4. Click on any `/chat` request to see the full distributed trace:
   - `rag-pipeline` (parent span)
     - `rag.generate-embedding` → `ai-gateway.embeddings`
     - `rag.vector-search` → `knowledge-base.search`
     - `rag.build-prompt`
     - `rag.llm-completion` → `ai-gateway.chat-completion`

> **Tip:** Traces may take 1–2 minutes to appear in Application Insights.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `KeyError: 'APIM_GATEWAY_URL'` | Ensure `.env` file exists in `src/agent-app/` with all required variables |
| `401 Unauthorized` from APIM | Verify `APIM_SUBSCRIPTION_KEY` is correct and the subscription is active |
| `DefaultAzureCredentialError` | Run `az login` and ensure your account has **Search Index Data Contributor** role on the AI Search resource |
| `404` from embedding/chat calls | Verify model deployment names (`gpt-4o`, `text-embedding-ada-002`) match your APIM/OpenAI deployments |
| `httpx.ConnectError` | Check `APIM_GATEWAY_URL` is reachable from your network |
| Traces not appearing | Wait 1–2 minutes; verify `APPLICATIONINSIGHTS_CONNECTION_STRING` is correct |
