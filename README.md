# Azure AI Insight Hub — POC/ Workshop

## MACU: Secure, Observable, and Scalable AI Platform

This POC demonstrates an end-to-end AI platform built on **Azure API Management (AI Gateway)**, **Application Insights**, and **Azure OpenAI** — delivering centralized LLM governance, full observability, and scalable multi-tenant access for 3,800+ internal users.

---

## Architecture Overview


![Azure AI Insight Hub Architecture](docs/images/architecture.png)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Centralized AI Platform                             │
│                                                                             │
│  ┌──────────┐    ┌──────────────────┐    ┌────────────────────────────────┐ │
│  │ Internal  │───▶│  Azure API Mgmt  │───▶│  Azure OpenAI (Multi-Region) │ │
│  │  Users    │    │  (AI Gateway)    │    │  ┌─────────┐  ┌───────────┐  │ │
│  │ (3,800)   │    │                  │    │  │ PTU     │  │ PAYG      │  │ │
│  └──────────┘    │ • Response Cache  │    │  │ East US │  │ West US   │  │ │
│                  │ • Token Limiting  │    │  └─────────┘  └───────────┘  │ │
│                  │ • Load Balancing  │    └────────────────────────────────┘ │
│                  │ • Content Safety  │                                       │
│                  │ • Multi-Tenancy   │    ┌────────────────────────────────┐ │
│                  │ • Keyless (MI)    │    │  Observability Stack           │ │
│                  └──────────────────┘    │  ┌──────────────┐              │ │
│                         │                │  │ App Insights │              │ │
│                         │                │  │ (E2E Tracing)│              │ │
│                         ▼                │  └──────┬───────┘              │ │
│                  ┌──────────────┐        │         │                      │ │
│                  │ Agent / RAG  │        │  ┌──────▼───────┐              │ │
│                  │ Pipeline     │────────│  │ Log Analytics│              │ │
│                  │ (AI Search + │        │  │ + KQL        │              │ │
│                  │  OpenAI)     │        │  └──────┬───────┘              │ │
│                  └──────────────┘        │  ┌──────▼───────┐              │ │
│                                          │  │  Workbook   │              │ │
│                                          │  │ (Dashboard) │              │ │
│                                          │  └──────────────┘              │ │
│                                          └────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Phases

This POC is organized into **5 phases**, each with its own README containing step-by-step instructions:

| Phase | Title | Description | README |
|-------|-------|-------------|--------|
| **1** | Foundation Infrastructure | Deploy core Azure resources via Bicep — APIM, App Insights, Log Analytics, Azure OpenAI, AI Search | [Phase 1](docs/phase-1-foundation-infra.md) |
| **2** | Observability Pipeline | Configure end-to-end tracing with App Insights, KQL queries, and workbook dashboards | [Phase 2](docs/phase-2-observability.md) |
| **3** | AI Gateway & APIM Policies | Centralize LLM governance — response caching, token limiting, load balancing, keyless access, multi-tenancy | [Phase 3](docs/phase-3-ai-gateway.md) |
| **4** | Agent & RAG Pipeline | Build a sample agent/RAG app (Python or Node.js) with full distributed tracing through the AI Gateway | [Phase 4](docs/phase-4-agent-rag-pipeline.md) |
| **5** | Scaling & Operations | Multi-region failover, scaling strategy from 100→3,800 users, operational dashboards & alerts | [Phase 5](docs/phase-5-scaling-operations.md) |

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Azure Subscription | Owner or Contributor + User Access Administrator |
| Azure CLI | v2.60+ (`az --version`) |
| Bicep CLI | v0.28+ (`az bicep version`) |
| Python | 3.10+ (for agent/RAG app) |
| VS Code | With Azure Tools, Bicep extensions |
| Azure OpenAI Access | GPT-4o and text-embedding-ada-002 models approved |

---

## Quick Start

```powershell
# 1. Clone this repo
git clone <repo-url>
cd azure-ai-insight-hub

# 2. Login to Azure
az login
az account set --subscription "<your-subscription-id>"

# 3. Start with Phase 1
# Follow docs/phase-1-foundation-infra.md
```

---

## Repository Structure

```
azure-ai-insight-hub/
├── README.md                          # This file
├── usecase.txt                        # Original use case description
├── docs/
│   ├── phase-1-foundation-infra.md    # Phase 1: IaC & core resources
│   ├── phase-2-observability.md       # Phase 2: Tracing & log forwarding
│   ├── phase-3-ai-gateway.md          # Phase 3: APIM AI Gateway policies
│   ├── phase-4-agent-rag-pipeline.md  # Phase 4: Agent/RAG app
│   └── phase-5-scaling-operations.md  # Phase 5: Scaling & dashboards
├── infra/
│   ├── main.bicep                     # Main Bicep orchestrator
│   ├── main.bicepparam                # Parameter file
│   └── modules/
│       ├── apim.bicep                 # APIM + AI Gateway
│       ├── openai.bicep               # Azure OpenAI (multi-region)
│       ├── monitoring.bicep           # App Insights + Log Analytics
│       ├── search.bicep               # AI Search for RAG
├── policies/
│   ├── ai-gateway-global.xml          # Global APIM policies
│   ├── ai-gateway-api.xml             # API-level policies
│   └── ai-gateway-operations.xml      # Operation-level policies
└── src/
    ├── agent-app/                     # Python agent/RAG application
    │   ├── app.py
    │   ├── requirements.txt
    │   └── ...
    └── agent-app-node/                # Node.js agent/RAG application (alternative)
        ├── src/
        │   ├── app.js
        │   └── ...
        └── package.json
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Bicep over Portal** | IaC-first approach — repeatable, auditable, version-controlled |
| **APIM as AI Gateway** | Single control plane for all LLM access — no ad-hoc deployments |
| **Managed Identity** | Keyless access — no API keys to rotate or leak |
| **PTU + PAYG load balancing** | Cost optimization: PTU for baseline, PAYG for burst |
| **Subscription-based multi-tenancy** | Per-team isolation, rate limits, and chargeback via APIM subscriptions |

---

## License

This project is for workshop/POC purposes. See individual service terms for Azure resource usage.
