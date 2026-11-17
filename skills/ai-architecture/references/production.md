# AI Production Envelope

Decides what an AI feature costs, how fast it answers, what bounds its consumption and how it survives provider failure. Read when the feature is deep; results fill the feature doc §7 and one cost row per feature for the system docs. Model choice, access and exit → `models.md`.

## Envelope arithmetic

Compute it; a feature whose envelope was never computed ships as a surprise invoice. Work per unit of value (conversation, task, document), never per request for the average user.

- **Cost per task** = Σ over its model calls of: uncached input × input price + cache writes × write price + cache reads × read price + (visible output + reasoning tokens) × output price + per-call fees. The price is a vector; verify every component.
- **Calls per task** = turns × (1 + retries + fallbacks + escalations + judge, guardrail, embedding and rerank calls). The system prompt and tool schemas count every time. History re-sent over n turns grows with n²: cap turns, prune, cache the prefix.
- **Cost per successful task** = cost per task ÷ measured success rate. It is the only basis for comparing models, routes and migrations.
- **Tail and segments.** Report p50, p95 and p99 per user and per segment; test the p95 user against the plan price and the monthly total against the ceiling. Gate on the statistic the requirement states.
- **Fit.** The p95 task fits the context budget with headroom; peak requests and tokens per minute fit the provider quota in its own units, with a ramp plan for new and failover traffic.
- **Runtime meter.** Meter cost per unit in production, with a degradation ladder designed before launch: cheaper tier → compacted history → human hand-off or feature-off.

## Limits & hard caps

Deny by default, enforce server-side where neither the client nor the model can override, and stop work at the cap; alerts only supplement it.

| Scope | Bound | When hit |
|---|---|---|
| Request | input length; max output including reasoning; payload per modality; timeouts | reject or truncate, saying why |
| Run (workflow, graph, agent) | iterations, tool calls, tokens, wall clock, money, fan-out width and depth; loop detection | stop gracefully: persist state, report progress, offer resume |
| User / tenant | rate; quota per period; concurrency | a limit-reached state with its reset time |
| Feature | a budget with burn alerts; a bulkhead so a runaway drains only its own budget | degrade along the meter's ladder |
| Account | the provider's spend cap, last resort only: hitting it stops every tenant | incident |

What can one malicious or buggy request spend, counting reasoning, tool calls, sub-agents and retries? The floor against cost attacks is a per-user rate limit, an input-length cap and a per-user budget per period. A flat-rate plan over agentic usage needs per-user metering and caps before launch.

## Latency

- **A latency class per call site**: interactive (streamed, with a time-to-first-token budget), near-real-time, deferred, live voice (`voice.md`). Deferred work on a batch or interruptible tier costs about half: run regression evals and backfills there. A fast tier sells speed at a multiple of the price. None of them comes with a latency guarantee, so the budget is met by design, not by contract.
- **Per-stage budgets.** Split the end-to-end p95 across retrieval, rerank, generation and guardrails.
- **Lever order**: skip the model where a deterministic or precomputed answer works → move a decision to the decision tier → cut output (terse formats, caps, a reasoning budget) → merge sequential calls → parallelize → stream end to end → cache long prefixes → only then a smaller model or faster tier. Output tokens, hidden reasoning included, and sequential round trips dominate interactive latency; trimming the prompt rarely helps.
- **Guardrails placed by harm.** Block when one exposure is unacceptable or the output triggers an action; screen in parallel only if the output is held until the screen clears; check and retract afterwards only for reversible harm on passive content.
- **Hedge** only short, idempotent, cheap calls (classifiers, routers, embeddings).

### Streaming

- **Transport.** One-way server push by default; a bidirectional transport only for duplex use. A stream is a long-lived connection: check proxy buffering, idle limits and reconnect behavior.
- **Lifetime.** Tied to the connection (cancel on disconnect) or a resumable job the client re-attaches to by id and cursor. Long, expensive or agentic generations are jobs.
- **Cancellation** propagates to the model call and in-flight tool calls, so "stop" also stops billing.
- **Partial output** is persisted, discarded or shown as interrupted: decide which. Machine-consumed output is acted on only once complete and validated.
- **Timeouts**, each with a degraded path: time to first token, inter-chunk idle, and total, derived from the measured p99 generation time of the chosen model and settings, never a copied default.

## Caching

- **Prefix stability.** Order context from stable to volatile: tool definitions, instructions, reference documents, history, the new turn. Keep timestamps, request ids and per-user values out of the prefix; serialize deterministically; keep history append-only. A change to the tool definitions, model, reasoning setting, output format or an image usually invalidates the whole cache: fix them per session, reject disallowed tool calls in the harness instead of removing their definitions, and change configuration at session boundaries unless the provider offers an appended update.
- **Break-even.** Cache writes usually cost more than plain input and longer lifetimes cost more still, so a cached prefix pays only if it is re-read often enough within its lifetime; choose the lifetime from measured inter-arrival times. *Break when* traffic is low or prompts are short and personalized.
- **Size for a cold cache.** Where cached reads are exempt from rate limits, caching also buys throughput, and a deploy, a prompt edit or a failover that cold-starts the cache erases that headroom. Regression-test the hit rate on a production-like replay.
- **Response cache.** Exact match keyed on normalized input, model snapshot, prompt version, index version, and tenant and permission scope. Semantic match only for single-turn, non-personalized, frequently repeated queries, per tenant, with the false-hit rate measured on near-miss pairs (negations, entity swaps).
- **Never cache responses** across principals, in front of tool-calling paths, or for output that triggers an action. *Break when* the answer set is curated and pre-approved.
- **A provider's prompt cache is shared across some unit**: a workspace for one provider, the whole organization for another. Keep tenant data out of any prefix shared beyond that unit, since a cache hit is observable in timing and price.

## Failures

- **Retry by error class, in one budgeted layer**, usually the gateway or adapter. Classify by the provider's error code: throttling, overload and timeouts retry; spend-cap, refusal, content-filter, context-overflow and schema-invalid responses go to handling, never to retry.
- **A refusal is a signal, not an outage.** Retry it only through the provider's own sanctioned fallback; never route it to a model or provider with weaker safeguards, which turns a safety signal into a bypass.
- **A fallback counts only once qualified**: it passes the regression suite with its own tuned prompt, holds quota for full failover load, meets the primary's data terms, and is exercised on a schedule. Until then, degrade: the same snapshot on another host or region, a smaller model from the same provider, a cached or deterministic answer, or feature-off.
- **Static stability.** The serving path keeps its last-known-good model config, prompts and routing when the gateway config, prompt registry or flag service is impaired.

## Observability

- **Every model call emits** provider, model snapshot, prompt version and parameters; tokens by class (uncached input, cache read, cache write, output, reasoning); time to first token and total duration; finish reason, truncation and refusal included; retries and fallback taken; computed cost; feature, tenant and user attribution; the parent task trace. Emit through one adapter pinned to one convention version: the OpenTelemetry conventions for generative AI are still changing, so expect to migrate.
- **Content stays out of default telemetry.** Prompts, retrieved context and outputs live in a separate access-controlled store with its own retention and erasure, referenced from spans.
- **The AI SLI set**, with targets from the feature docs: quality pass rate per slice, with the scorer named · abstain, escalation and human-override rates · refusal rate · cost per successful task (p95) · time to first token per latency class · cache-hit rate for multi-turn features · approvals and interrupts per task for agents.
- **Drift alarms**: response length, refusal rate, tokens per task, schema failures and negative feedback, correlated with your own change log and the provider's notices.

## Red flags

- 🔴 No server-side run or user caps; the provider spend cap or a budget alert is the only control.
- 🔴 A semantic cache shared across tenants, or in front of tool-calling paths.
- 🔴 A refused request re-routed to a model with weaker safeguards.
- 🟠 Cost estimated per request for the average user.
- 🟠 Retries at several layers, or on refusal and spend-cap errors; a fallback never exercised.
- 🟠 Full prompts and outputs in default telemetry or third-party tools.
