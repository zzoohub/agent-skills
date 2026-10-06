# AI/LLM Architecture Decision Framework

**Layer:** system-level architecture (gateways, components, data flow, deployment). For LLM **design discipline** (when to use an agent at all, prompt structure, eval methodology, output contracts), see `references/llm-app/guide.md` (this skill's AI Feature Mode).

Architecture patterns for systems that integrate Large Language Models. Use this reference when the PRD includes AI-powered features — generation, summarization, search, agents, or any LLM-driven capability.

**Important**: The AI landscape evolves rapidly. This document covers **stable architectural patterns** that remain valid across model generations. For specific model choices, pricing, and benchmarks, **always verify current state via WebSearch** before committing.

---

## Table of Contents

1. [LLM Integration Patterns](#1-llm-integration-patterns) — Direct API, Gateway, Model Cascading
2. [Streaming Architecture](#2-streaming-architecture) — SSE, backpressure, frontend consumption
3. [RAG (Retrieval-Augmented Generation)](#3-rag-retrieval-augmented-generation) — When to use, tiers, vector storage, chunking, embeddings
4. [Agent Architecture](#4-agent-architecture) — Patterns, state management, MCP
5. [Multimodal Architecture](#5-multimodal-architecture) — Vision, audio/speech, multimodal RAG, output generation
6. [Cross-Cutting Concerns for AI Systems](#6-cross-cutting-concerns-for-ai-systems) — Cost, guardrails, observability, prompt management
7. [AI Testing & Evaluation](#7-ai-testing--evaluation) — RAG quality, agent reliability, prompt regression, EDD
8. [Fine-Tuning Decision Framework](#8-fine-tuning-decision-framework) — When to fine-tune vs. prompt engineer vs. RAG
9. [Model Lifecycle Management](#9-model-lifecycle-management) — Migration strategy, data flywheel
10. [AI Architecture Decision Flowchart](#10-ai-architecture-decision-flowchart)
11. [Anti-Patterns](#11-anti-patterns)

---

## When This Reference Applies

Read this if the system includes any of:
- Text generation, summarization, or transformation via LLM
- Semantic search or retrieval-augmented generation (RAG)
- Autonomous agents that use tools or make decisions
- AI-powered features (chat, copilot, content generation, classification)

If the system just calls an LLM API for a simple task (e.g., one-shot classification), a thin integration layer is sufficient — skip to the "Direct API Integration" pattern and skim the cost/observability sections.

---

## 1. LLM Integration Patterns

Three tiers of integration complexity. Choose the simplest tier that meets requirements.

### Tier 1: Direct API Integration

Call the LLM provider's API directly from your service. No middleware.

```
Service --HTTP POST--> LLM Provider API
        <--response---
```

**When**: Single provider, single model, low request volume, no fallback needs.
**Trade-offs**: Simplest to build, but you're coupled to one provider. No automatic fallback, no cost tracking, no caching.

### Tier 2: LLM Gateway

A routing layer between your service and multiple LLM providers. Handles failover, load balancing, cost tracking, and unified API format.

```
Service --> LLM Gateway --> Provider A (primary)
                        --> Provider B (fallback)
                        --> Provider C (cost-optimized)
```

**When**: Multiple models or providers, need automatic failover, want unified cost tracking, or need request/response logging.
**Trade-offs**: Adds latency overhead — typically single-digit to low-tens of milliseconds for a self-hosted/co-located gateway, ~20-40ms for a managed cloud gateway (mostly network hops). Negligible next to LLM call time (often 500ms-5s), and worth it for production reliability — benchmark your specific setup.

### Tier 3: Model Cascading

Route queries to progressively more expensive models based on complexity. A cheap model can often handle the majority of requests (frequently ~70-90% in routed workloads); expensive models handle the rest. The exact split depends on your confidence threshold and the mix of query difficulty.

```
Query --> Router/Classifier
          |-- Simple -> Small/fast model ($)
          |-- Medium -> Mid-tier model ($$)
          +-- Complex -> Frontier model ($$$)
```

**When**: High request volume where cost matters, queries vary significantly in difficulty, and you can define a confidence threshold.
**Impact**: Large but highly workload-dependent — published benchmarks report roughly 45-85% cost reduction (e.g., RouteLLM ~85% on MT-Bench but ~35-45% on MMLU/GSM8K at ~95% of GPT-4 quality; FrugalGPT up to ~98%). Verify for your own workload.

**Implementation**: Use a lightweight classifier (rule-based: token count, keyword presence, conversation depth) that routes to appropriate models. Or use the gateway's built-in router if available.

---

## 2. Streaming Architecture

Most LLM-powered features need to stream tokens to the user as they're generated, because waiting 5-30 seconds for a complete response is unacceptable UX.

### Protocol: SSE (Server-Sent Events)

SSE is the standard protocol for LLM token streaming. All major providers use SSE.

**Why SSE over WebSocket**: SSE is stateless, builds on HTTP, works natively with serverless, and requires no connection management. WebSocket is only justified when you need bidirectional real-time communication (collaborative editing, voice streams).

### Architecture Pattern

```
Client --POST /chat--> API Server --SSE stream--> LLM Provider
       <--SSE stream--              <--tokens----
```

**Key decisions**:
- **Backpressure**: Use your framework's streaming response primitive (e.g., `ReadableStream`, SSE helpers). For raw byte passthrough (proxying LLM SSE directly), pipe the provider's stream through.
- **Structured output streaming**: When the LLM emits structured JSON token-by-token, use a partial JSON parser to render progressive UI updates. Plan for this if your feature requires structured generation.
- **Frontend consumption**: Use an AI SDK that handles SSE parsing, streaming state, and error recovery. For custom implementations, use `fetch` + `ReadableStream`.
- **Timeout budgets**: a complete response typically takes 5-30s, but long generations can run 30-60s+. Set the request timeout to ~300s for **streaming** LLM endpoints (a defensive ceiling — standard 60s timeouts truncate long responses). For **non-streaming** calls, 60-120s is the usual budget (see the resilience tables in `design-flow.md` Stage 8 and `operational-patterns.md`).

---

## 3. RAG (Retrieval-Augmented Generation)

RAG connects the LLM to your data. Instead of relying on the model's training data alone, you retrieve relevant context from your own documents and include it in the prompt.

**Altitude split**: this section owns the *system* slice of RAG — when retrieval is the right shape, the tier escalation as a topology decision, vector storage by scale, and the retrieval **latency budget**. The retrieval *mechanics* (chunking, hybrid weighting, reranker choice, embedding-model selection) are design discipline — see `references/llm-app/rag.md`.

### When to Use RAG

- The LLM needs access to **private, recent, or user-specific data** not in its training set
- Answers must be **grounded in source documents** (reducing hallucination)
- The knowledge base is too large to fit comfortably in context at query time (see the stuffing threshold below)
- You need **attributable responses** with source citations, or answers must be auditable

### When NOT to Use RAG

- The task is creative generation (writing, brainstorming) — retrieval adds noise
- The knowledge fits comfortably in context and rarely changes — just include it. Rule of thumb: under ~200K tokens (about 500 pages, per Anthropic's contextual-retrieval guidance) — model-dependent. Context windows keep growing (1M tokens on several current models as of 2026-10), and prompt caching makes stuffing cheaper than standing up retrieval infrastructure. (Attention quality and per-call cost still favor retrieval as the corpus grows — recall degrades in long contexts and "lost in the middle" positional bias persists — so don't stuff just because you technically can.)
- A direct database query would work (structured data, exact lookups)
- Real-time data is needed — use tool calls to live APIs instead

### RAG Architecture Tiers

**Tier 1 — Naive RAG**: Query -> embed -> retrieve top-k chunks -> stuff into prompt -> generate. Start here. It works surprisingly well for most use cases. If retrieval quality is above 80%, you may not need anything more sophisticated.

**Tier 2 — Advanced RAG**: Adds pre-retrieval and post-retrieval optimization:
- **Hybrid search**: Combine dense (semantic embeddings) + sparse (BM25 keyword matching). Hybrid improves retrieval quality significantly over dense-only.
- **Reranking**: After initial retrieval, re-score candidates with a cross-encoder reranking model. Dramatically improves precision; typically adds tens to a few hundred ms (roughly 50-300ms) depending on candidate-pool size, model, and self-hosted-GPU vs hosted rerank API.
- **Contextual retrieval**: Before embedding, prepend a concise context summary to each chunk explaining where it fits in the source document. Reduces retrieval failures substantially.
- **Graph-based RAG**: Build entity-relationship graphs from documents. Useful for questions that require understanding relationships across the corpus.

**Tier 3 — Agentic RAG**: The LLM autonomously decides when to retrieve, what queries to use, and whether results are sufficient. Handles multi-hop questions by decomposing them into sub-queries. Use when: questions require reasoning across multiple documents, or the retrieval strategy depends on the question type.

### Retrieval Strategy Selection

| Strategy | When to Use | Latency Impact |
|---|---|---|
| Dense only (embeddings) | Homogeneous content, semantic queries | Baseline |
| Hybrid (dense + BM25) | Mixed content, exact term matching matters | +10-20ms |
| + Reranking | Precision-critical, top-k has noise | +50-300ms (GPU/self-hosted low end, hosted API higher) |
| + Query decomposition | Multi-hop questions, complex queries | +1-2s (extra LLM call) |
| + Contextual retrieval | Chunks lose meaning without document context | Build-time cost only |
| Graph-based | Thematic/relational questions across corpus | Variable |
| Parent document retrieval | Small chunks for precision, large for context | Minimal |

### Vector Storage

Choose based on your scale and existing infrastructure:

| Scale | Approach | Rationale |
|---|---|---|
| < ~100M vectors | **pgvector on PostgreSQL** | Unified relational + vector queries, no separate database. Use HNSW index for production. HNSW wants its graph in RAM — tens of millions per node is the comfortable range; toward 100M budget hundreds of GB of RAM, or partition / quantize (`halfvec`) / use a disk-based index extension. |
| > 100M vectors, cost-sensitive | **Object-storage-first vector DB** | Search for current options that use object storage as primary with SSD cache tier. |
| > 100M vectors, query-intensive | **Dedicated vector database** | Search for current benchmarks comparing options. |
| Need zero-ops | **Fully managed vector service** | Higher cost, lowest operational burden. |

**Default**: pgvector on your existing PostgreSQL — it keeps your data in one place. Only break out to a dedicated vector DB when you hit performance ceilings or need vector-specific features.

### Chunking & Embedding (design — pointer)

Chunk strategy/size/overlap and embedding-model selection (MTEB, multilingual, max input) are **retrieval-design** decisions — see `references/llm-app/rag.md`. Two consequences survive at architecture altitude:
- **Chunking sizes the vector store**: chunk size sets your vector count (storage cost + index build time) and overlap multiplies it — size the store from the expected chunk count, not raw document size.
- **Embedding dimensions size storage**: don't hardcode the model (the leaderboard shifts); lower output dimensions (or Matryoshka truncation) cut vector storage 50-75%.

---

## 4. Agent Architecture

When the system requires adaptive multi-step behavior — tool orchestration, autonomous decision-making, or long-running workflows — use agent patterns. Default to simpler patterns (augmented LLM, prompt chaining) and escalate only when needed.

**Full guide**: `references/ai-agents.md` — pattern hierarchy, protocols (MCP, A2A, AG-UI), context engineering, durable execution, multi-agent systems, and safety.

---

## 5. Multimodal Architecture

When the system processes or generates images, audio, video, or documents beyond plain text. Multimodal adds distinct architectural concerns: larger payloads, specialized preprocessing, different latency profiles, and storage requirements.

### Input Modalities

| Modality | Architecture Pattern | Key Decisions |
|---|---|---|
| **Vision (images)** | Presigned upload -> preprocess -> LLM vision API | Max image size, resize before API call (cost/latency), format conversion |
| **Documents (PDF, DOCX)** | Upload -> extract text/structure -> process as text | Extraction approach: OCR vs structured parsing vs multimodal LLM |
| **Audio/Speech** | Upload or stream -> STT -> process text -> TTS (optional) | Real-time vs batch, streaming STT for live input, language detection |
| **Video** | Upload -> extract frames + audio track -> process separately | Frame sampling rate, keyframe extraction, parallel audio/visual analysis |

### Vision Integration

Most common multimodal pattern. Two approaches:

**Direct vision API**: Send image + text prompt to a multimodal LLM. Simple, handles most use cases.

**Pipeline with preprocessing**: When you need structured extraction, OCR validation, or cost optimization. Preprocess with cheaper specialized models (OCR, object detection) and send only extracted data to the LLM for reasoning.

**Cost consideration**: Vision API calls cost significantly more than text-only. For high-volume image processing, use specialized models and reserve the LLM for reasoning.

### Audio/Speech Architecture

**Speech-to-Text (STT)**:
- **Batch**: Upload audio file -> STT API -> text. Simple, higher latency
- **Streaming**: WebSocket audio stream -> streaming STT -> real-time text. Required for voice interfaces

**Text-to-Speech (TTS)**:
- Generate audio from LLM output for voice interfaces
- **Streaming TTS**: Generate audio chunks as text streams in — critical for conversational UX

**Voice agents**: Combine streaming STT -> LLM -> streaming TTS for real-time voice conversation. Latency budget is tight (~500ms total round-trip for natural feel). Consider WebRTC for lowest latency transport.

### Multimodal RAG

Extending RAG to handle non-text content:

| Content Type | Indexing Strategy | Retrieval |
|---|---|---|
| **Images in documents** | Extract description with multimodal LLM, embed the description | Text query matches image descriptions |
| **Diagrams/charts** | Multimodal LLM generates structured description + data extraction | Text or structured query |
| **Audio/video** | Transcribe -> chunk -> embed transcription. Store timestamps for seeking | Text query, return with timestamp references |
| **Mixed documents** | Process each modality separately, link via document ID | Unified query across modalities |

**Key insight**: Most multimodal RAG works by converting non-text content into text representations for embedding. True multimodal embeddings (CLIP-style) are useful for image-to-image similarity but add complexity.

### Multimodal Anti-Patterns

**Sending raw high-res images to LLMs**: Resize to the minimum resolution the model needs. Providers downscale or tile large images, so a ~16x pixel increase often yields only ~1x-5x more tokens (with rarely any quality benefit) — the exact ratio depends on the model's tiling scheme and max-resolution cap.

**Synchronous video processing**: Video analysis is inherently slow. Always use async processing with progress callbacks.

**Ignoring modality-specific costs**: A single image analysis can cost 10-50x a text-only call. Track cost per modality separately.

---

## 6. Cross-Cutting Concerns for AI Systems

### Cost Optimization

AI inference costs can dominate cloud spend. Address this architecturally, not as an afterthought.

| Strategy | Cost Impact | Implementation Effort |
|---|---|---|
| **Prompt optimization** (trim unnecessary context) | 15-30% reduction | Low |
| **Semantic caching** (cache semantically similar queries) | 30-70% reduction for repetitive workloads | Medium |
| **Model cascading** (cheap model first, expensive for hard cases) | ~45-85% (workload-dependent) | Medium |
| **Batch API** (for non-real-time workloads) | ~50% reduction | Low |
| **Reduced embedding dimensions** | 50-75% storage reduction | Low |

**Semantic caching**: Use vector similarity to identify queries with the same meaning and serve cached responses. Cache hit rates of 60-85% are typical for support/docs workloads.

**Self-hosting threshold**: Once monthly inference spend reaches the tens of thousands of dollars (roughly $20-50K/month), evaluate self-hosted GPU clusters vs managed APIs. The break-even is highly model- and utilization-dependent — model it on token volume, target model quality, and sustained GPU utilization, not a single dollar figure. Factor in operational overhead (self-hosting TCO often runs 3-5x raw GPU rental once engineering time is included).

### Guardrails & Safety

Production AI systems need input/output validation. Layer defenses by cost and speed:

```
Input -> [Rule-based filters ~1ms] -> [ML classifiers ~10ms] -> [LLM validators ~200ms]
  -> LLM Generation ->
Output -> [Format validation ~1ms] -> [Factuality check ~10ms] -> [Safety review ~200ms]
  -> Response
```

**Key decisions**:
- **PII detection**: Search for current open-source PII detection libraries. Run as pre-processing to mask PII before it reaches the LLM.
- **Content safety**: Search for current guardrail frameworks. Evaluate based on latency, accuracy, and language support.
- **Indirect Prompt Injection (IPI)**: The most dangerous vulnerability for RAG systems. Malicious instructions embedded in retrieved documents can manipulate agent behavior. Mitigations: separate user instructions from retrieved context, validate tool calls against permissions, monitor for anomalous agent behavior.
- **Sync vs. async**: For real-time chat, heavy guardrails can add 200ms+ latency. Consider async monitoring — let the response through immediately but run background checks and flag/retract if needed.

**Regulatory awareness**: The EU AI Act (Regulation (EU) 2024/1689, binding law) increasingly mandates specific guardrails; voluntary frameworks like NIST AI RMF 1.0 and ISO/IEC 42001:2023 provide governance scaffolding to evidence compliance. Check current regulatory requirements for your domain and region.

### Observability for AI Systems

Standard RED metrics (Rate, Errors, Duration) plus AI-specific metrics:

**Essential AI metrics**:
- Token usage per request (input vs. output, by model)
- Cost per request, per user, per feature
- Time-to-first-token (TTFT) — critical for streaming UX
- Hallucination rate / groundedness score
- Cache hit rate (if using semantic caching)
- Retrieval quality (if using RAG): precision@k, relevance score

**OpenTelemetry**: OTel's GenAI semantic conventions standardize spans for LLM calls, tool usage, and agent steps; instrumentation libraries such as OpenLLMetry emit them. Use this if you're already on OTel and want unified tracing.

### Prompt Management

*Where prompts live and how they version* is a system decision (below); *how to write them* is design — see `references/llm-app/prompting.md`.

For production systems with multiple prompts that evolve over time:

- **Decouple prompts from code**: Store prompts in a registry, fetch at runtime. Enables changes without redeployment.
- **Version and test**: Every prompt change gets a version. Run eval suites before promotion.
- **A/B test**: Feature-flag infrastructure can manage prompt variants the same way it manages code variants.

For small teams, storing prompts as version-controlled files in the repo is fine. Move to a prompt registry when you have multiple prompts changing frequently.

---

## 7. AI Testing & Evaluation

AI systems need testing strategies beyond conventional software testing because outputs are non-deterministic. Treat evaluation as a first-class architectural concern — "evals are the new unit tests."

### Evaluation-Driven Development (EDD)

Inspired by TDD/BDD but reimagined for LLM systems:
1. **Define eval suite before building**: For each AI feature, define 10-30 test cases with expected output characteristics (not exact matches)
2. **Assertions over expectations**: Check for structural compliance, key information inclusion, absence of known failure modes — not string equality
3. **CI integration**: Run eval suite on every PR that modifies prompts, retrieval logic, or model configuration. Block merge if pass rate drops below threshold
4. **Traceability**: Link every evaluation score to the exact version of prompt, model, and retrieval config that produced it

### RAG Quality Evaluation

Metric selection (precision@k, recall@k, faithfulness, answer-relevance), thresholds, and golden-set design are eval **design** — see `references/llm-app/evaluation.md`. The architecture concern is that RAG quality runs as a **CI fitness function**: a golden set scored by an LLM-as-judge, automated as a CI step, blocking merge below threshold, and traceable to the exact prompt/model/retrieval version (per EDD above).

### Agent Reliability Testing

Agent metrics — task completion rate, tool-call accuracy and recovery from tool failures (trajectory eval), step efficiency, and pass^k over repeated runs — are eval **design**, defined in `references/llm-app/evaluation.md` § Agent evals. The architecture concern is the suite and its gate: 20-50 test scenarios covering common paths and edge cases, each run several times (non-determinism), with pass rate and step count tracked in CI like the RAG gate above.

### A/B Testing for AI Features

Offline evaluation often doesn't correlate with business metrics. Production A/B testing is essential:
- Test not just model swaps but prompts, hyperparameters, retrieval strategies
- Measure business outcomes (conversion, engagement, task completion), not just model quality metrics

---

## 8. Fine-Tuning Decision Framework

| Approach | When to Use | Cost | Maintenance |
|---|---|---|---|
| **Prompt engineering** | Default starting point. Task is definable in instructions. | Lowest | Lowest |
| **RAG** | LLM needs access to private/dynamic data. Answers must cite sources. | Medium | Medium (index updates) |
| **Fine-tuning** | Consistent style/format across thousands of outputs. Latency-critical. Domain-specific terminology. Prompt engineering plateaued. | High (training) | High (retraining on new data) |
| **Fine-tuning + RAG** | Domain-adapted model that also needs current data. Best quality ceiling. | Highest | Highest |

**Decision rule**: Exhaust prompt engineering and RAG before considering fine-tuning. Fine-tuning requires training data curation, compute cost, evaluation infrastructure, and ongoing maintenance. The gap between a well-prompted frontier model and a fine-tuned smaller model is narrowing with each generation.

**When fine-tuning is justified**:
- You have 1000+ high-quality input-output examples
- The task has a consistent, well-defined output format
- You need to reduce per-request cost at high volume (smaller fine-tuned model > larger general model)
- Latency requirements demand shorter prompts

---

## 9. Model Lifecycle Management

### Model Migration Strategy

LLM switching is not plug-and-play. Models have different tokenizers, context window behaviors, instruction-following patterns, and failure modes.

**Triggers for migration**: Major new model release, rising costs, latency degradation, expanding task types, governance/compliance changes.

**Required infrastructure**:
- **Stable baselines**: Before any migration, capture current performance metrics as the baseline
- **Side-by-side evaluation**: Run candidate models on the same eval suite under identical conditions. Never switch based on benchmarks alone
- **Gradual rollout**: Use feature flags to route a percentage of traffic to the new model. Monitor quality and cost before full cutover
- **Rollback plan**: Keep the old model configuration readily available. A model migration that degrades quality must be instantly reversible

**Architecture implication**: The LLM Gateway pattern (Tier 2) makes model migration dramatically easier. With a gateway, you change config instead of code.

### Data Flywheel

A production AI system generates valuable data exhaust that can improve future performance:

```
Production usage -> Collect logs (prompt/response/feedback)
    -> Curate high-quality examples
    -> Fine-tune or improve retrieval
    -> Deploy improved system
    -> Repeat
```

**Key components**:
- **Feedback collection**: Thumbs up/down, regeneration requests, user edits to AI output — all signal quality
- **Data curation**: Filter for high-quality examples, remove PII, deduplicate
- **Evaluation loop**: Verify improvements on eval suite before deploying

---

## 10. AI Architecture Decision Flowchart

```
Does the feature need an LLM?
|-- Just classification/extraction -> Consider structured prompting or fine-tuned small model
|-- Generation/conversation/reasoning -> Continue below
|
How does the LLM access knowledge?
|-- Built-in knowledge is sufficient -> Direct API call (Tier 1)
|-- Needs private/recent data -> RAG (Section 3)
|-- Needs to take actions -> Agent with tools (Section 4)
+-- Needs data + actions -> Agentic RAG (Section 3 + 4 combined)
|
How many models/providers?
|-- One -> Direct API integration
+-- Multiple or need failover -> LLM Gateway (Tier 2)
|
Is cost a concern at scale?
|-- YES -> Add model cascading (Tier 3) + semantic caching
+-- NO -> Direct calls are fine
|
Does the user need real-time output?
|-- YES -> SSE streaming (Section 2)
+-- NO -> Standard request-response, consider batch API for throughput
|
Is the agent long-running or failure-prone?
|-- YES -> Durable execution + checkpointing (Section 4 -> `ai-agents.md` §5)
+-- NO -> Stateless agent loop is fine
|
Has prompt engineering plateaued with enough training data available?
|-- YES -> Consider fine-tuning (Section 8)
+-- NO -> Keep optimizing prompts and RAG
```

---

## 11. Anti-Patterns

Design-level counterparts (prompt stuffing, no evals, over-agentifying, unvalidated structured output, logging nothing) are in `references/llm-app/guide.md` § Anti-patterns.

**RAG Everything**: Shoving all data into a vector store when half of it would be better served by structured queries (SQL) or API calls. Vector search is for semantic similarity — use the right tool for each data type.

**Agent When a Pipeline Will Do**: If the steps are predictable and don't depend on intermediate results, a hardcoded pipeline is simpler, faster, cheaper, and more debuggable than an agent.

**Ignoring LLM Costs Until the Bill Arrives**: At high volume, inference costs compound fast. Model cascading and caching should be in the architecture from day one for any high-volume feature.

**Prompt Engineering as Architecture**: Relying on prompt tweaks to compensate for missing retrieval, poor data quality, or wrong model choice. Fix the architecture first.

**Treating LLM Output as Trusted**: LLMs hallucinate. Any LLM output that drives critical decisions needs validation — either programmatic or human-in-the-loop.

**Premature Fine-Tuning**: Jumping to fine-tuning before exhausting prompt engineering and RAG. Often a better prompt or better retrieval achieves the same result with far less maintenance burden.

**Hardcoding Model Versions**: Pinning to a specific model version without a migration strategy. Design for model portability from day one.
