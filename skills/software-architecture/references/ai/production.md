# AI Production Envelope

Decides what an AI feature costs, how fast it answers, what bounds its consumption, and how it survives provider failure, drift and exit. Read when AI is deep; results fill the feature doc's envelope section (§7) and roll up into `design-flow.md` § Cost & Unit Economics.

## Envelope arithmetic

Compute the envelope, don't estimate it by adjective: a feature whose envelope was never computed ships as a surprise invoice. Work per unit of value (conversation, task, document), never per request for the average user. Verify prices, multipliers, quotas and deprecation windows per the measurement policy (`ai/protocol.md`).
- **Cost per task** = Σ over its model calls of uncached input × input price + cache writes × input price × *w* + cache reads × input price × *r* + cache storage × lifetime where billed + (visible output + reasoning tokens, returned or not) × output price + per-call fees (tools, runtime, residency, context band — the price is a vector). *w*, *r* = cache write and read multipliers; *w* = 1 with no write premium.
- **Calls per task** = turns × (1 + retries + fallbacks + escalations + judge, guardrail, embedding and rerank calls); per-call overhead (system prompt, tool schemas) counts every time. Re-sent history over *n* turns ≈ *n*·*B* + Δ·*n*(*n*−1)/2 input tokens (*B* = base context, Δ = tokens added per turn): cap *n*, prune Δ, cache the prefix.
- **Cost per successful task** = cost per task ÷ measured success rate (`ai/evals.md`) — the only basis for comparing models, routes and migrations, measured on your evals at the settings you will ship; per-token list prices compare only across hosts serving the identical snapshot.
- **Tail and segments.** Report p50/p95/p99 per user and per segment (language, channel, tenant tier); test the p95/p99 user against the plan price, and the monthly total against the cost ceiling; gate on the statistic the requirement states — never silently turn an average target into a tail gate (prototype exception: design-flow Stage 1).
- **Fit.** The p95 unit fits the context budget (`ai/context.md`) with headroom; peak requests and tokens per minute fit the provider quota in its own units, with a headroom table per feature and a ramp plan for new and failover traffic.
- **Runtime meter.** Meter cost per unit in production, with a degradation ladder designed before launch: cheaper tier → compacted history → human hand-off or feature-off.

## Limits & hard caps

Sole owner of consumption bounds. Deny by default, enforce server-side where neither the client nor the model can override, and stop work at the cap — alerts only supplement it.

| Scope | Bound | When hit |
|---|---|---|
| Request | input length; max output including reasoning; payload per modality; timeouts (below) | reject or truncate, stating why |
| Run (workflow, agent) | iterations, tool calls, tokens, wall clock, money, fan-out width and depth; loop detection | stop gracefully: persist state, report progress, offer resume |
| User / tenant | rate; quota per period (tokens or money); concurrency | a limit-reached state with its reset time |
| Feature | budget with burn alerts; a bulkhead so a runaway drains only its own budget | degrade along the meter's ladder |
| Account | the provider's spend cap — last resort only: hitting it stops every tenant | incident |

- **Cost-attack floor**, relied on by `ai/security.md`: a per-user rate limit, an input-length cap and a per-user cost budget per period.
- **Forcing question:** what can one malicious or buggy request spend, counting reasoning, tool calls, sub-agents and retries? Expensive entry points get a pre-flight estimate. *Break when* an internal batch job runs over a fixed input set: a job budget plus post-hoc review suffices.
- Every limit has a user-facing state (presentation via the ux-design capability, if available). A flat-rate plan over agentic usage needs per-user metering and caps before launch (via the pricing capability, if available).

## Latency

- **A latency class per call site**, bound to the cheapest service tier that meets it: *interactive* (streamed, with a time-to-first-token budget), *near-real-time*, *deferred* (batch or discounted tiers — run regression evals and backfills there, so eval cost never limits how often you evaluate).
- **Per-stage budgets.** Split the end-to-end p95 across retrieval, rerank, generation and guardrails; choose each stage's technique by budget fit on your own traffic.
- **Lever order:** skip the model where a deterministic or precomputed answer works → cut output (terse formats, output caps, a reasoning budget per call site) → merge sequential calls → parallelize → stream end to end, starting downstream calls as soon as their arguments arrive → cache long prefixes → only then a smaller model or faster tier. Output tokens (hidden reasoning included) and sequential round trips dominate interactive latency; trimming the prompt rarely helps. *Break when* prompts are very long and uncached: prefill then dominates time to first token.
- **Guardrails placed by harm.** Block when one exposure is unacceptable or the output triggers an action or a fetch; screen input in parallel only if the output is held until the screen clears; check-and-retract asynchronously only for reversible harm on passive content. Which controls actually hold → `ai/security.md`.
- **Hedge** (duplicate after p95) only short, idempotent, cheap calls — classifiers, routers, embeddings — never long generations or side-effecting steps.

### Streaming & generation lifetime

- **Transport.** One-way server push over HTTP by default; a bidirectional transport only for duplex use (live voice, co-editing). A stream is a long-lived connection: check proxy buffering, idle and platform duration limits and reconnect behavior, and pipe the upstream stream through with backpressure. Own the event schema; an agent-to-UI protocol is only a serializer at the edge.
- **Lifetime.** Tied to the connection (cancel on disconnect) or a resumable job (persist chunks; the client re-attaches by id and cursor). Long, expensive or agentic generations are jobs (`operational-patterns.md` § Durable Execution). *Break when* answers are short and cheap to regenerate.
- **Cancellation** propagates to the upstream model call and any in-flight tool calls, so "stop" also stops billing.
- **Partial output** is persisted, discarded or shown as interrupted — decide which. Machine-consumed output streams through a partial parser but is acted on, sanitized and validated only once complete; progress states ("searching…") follow the tool-call lifecycle, not text deltas.
- **Timeouts**, each with a degraded path: time to first token (from the latency class), inter-chunk idle, and total. Derive the total from the measured p99 generation time of the chosen model and reasoning budget at the feature's maximum output, plus headroom — never a copied default. General deadline rules → `operational-patterns.md`.

### Multimodal

Slow modalities (video, long audio, large documents) run as jobs with progress reporting; payloads move through object storage, not the request path; latency and cost budgets are set per modality, and inputs are resized to what the task needs. Live voice needs a duplex transport and an end-to-end conversational latency budget. Every modality is an injection channel (`ai/security.md`).

## Caching

Sole owner of prompt-prefix rules, cache economics and the cache-hit SLI; general caching (staleness, stampedes, cold start) → `operational-patterns.md`.
- **Prefix stability.** Order context from stable to volatile: tool definitions, instructions, reference documents, history, the new turn. Keep timestamps, request ids and per-user values out of the prefix; serialize deterministically, tool order included; keep history append-only. Fix the tools, output schema, model and reasoning budget per session — keep tool definitions in place and reject disallowed calls in the harness instead of removing them (which parameter changes invalidate the cache is provider-specific — check), send per-step guidance as appended messages or tool results, and switch only at session or sub-agent boundaries. Compaction leaves the stable prefix intact but invalidates the cache from the first token it rewrites: compact at task boundaries and accept one miss each. Check the provider's minimum cacheable length.
- **Break-even.** Where cache writes carry a premium, a cached prefix pays only if it is re-read more than (*w* − 1 + *s*·*L*/*p*)/(1 − *r*) times within its lifetime *L* (*s* = storage price per token per unit time where billed, else 0; *p* = input price); choose the lifetime from measured request inter-arrival times. *Break when* traffic is low or prompts are short and personalized: measure before paying for writes.
- **Size for a cold cache.** Where cache reads do not count against the input quota, effective input throughput ≈ quota ÷ (1 − hit rate); a deploy, prompt edit, failover or harness bug that cold-starts the cache erases that headroom. Plan quota and failover for a cold cache, and regression-test the hit rate on a production-like replay.
- **Response cache ladder.** (1) Exact match keyed on normalized input (or entity id), model snapshot, prompt version, retrieval-index version, and tenant and permission scope. (2) Normalize inputs upstream to raise exact hits. (3) Semantic match only for single-turn, non-personalized, non-time-sensitive, frequently repeated queries — scoped per tenant, threshold set on near-miss pairs (negations, entity swaps), false-hit rate measured on real traffic.
- **Never cache responses** across principals, in front of tool-calling or agent paths, or for output that triggers an action; treat hits as untrusted, invalidate on any source or release-unit change, and count savings only from measured hit rates. *Break when* the answer set is curated and pre-approved.
- **Provider cache scope**: per-account isolation means all your tenants share one prefix cache (partitioning → `ai/security.md`).

## Routing & cascades

- **One (model, reasoning budget) pair per task class by default**, chosen by an eval sweep of quality against tokens and latency, versioned beside the model id, set explicitly rather than left at provider defaults, with output caps that include reasoning. Dynamic routing only where variable behavior is tolerable, never on paths that must be deterministic or audited. *Break when* a task is low-volume and high-stakes: use the strongest setting, since the cost of an error dominates.
- **Route at task, thread or sub-agent boundaries**, never per turn inside a cached loop — each switch cold-starts the prefix. *Break when* the workload is stateless and single-turn.
- **Decision-tier cascade** (shape test and typed contract → `ai/protocol.md`): the cheap typed tier runs on every request, acts automatically on the slice whose calibrated confidence clears its threshold (calibration gate → `ai/evals.md`), and escalates the rest to a generative model or a human. Model the escalation rate explicitly — it usually decides cost and p95 more than the cheap tier's price — and price misroutes. *Break when* a large share escalates (you pay both tiers plus the hop), the auto-accepted slice's error exceeds tolerance, or outputs cannot be scored cheaply: route up front instead.
- **Cheap-first generative cascades** need a scorer calibrated on in-distribution labels, a threshold set with confidence bounds, an escalation path inside the latency budget, and recalibration whenever models or the traffic mix change; on latency-critical paths, pick the tier before generating — a sequential cascade pays both latencies on every deferral. Evaluate any router like a model, against an unrouted control on business outcomes, and log its decisions.

## Failures: retries & fallback

- **Retry by error class, in one budgeted layer** — usually the gateway or client adapter (contract → `operational-patterns.md`). Classify by the provider's error code, not the transport status: throttling, overload and timeouts retry; spend-cap, refusal, content-filter, context-overflow and schema-invalid responses go to handling (degrade, compact, ask the user), never to retry. A schema-repair re-ask spends the same budget.
- **Never resend a refused request to a more permissive model or provider** — that turns a safety signal into a bypass. *Break when* an evaluated class of false positives has a policy-approved exception.
- **Fallback qualification.** A fallback model or provider counts only once it passes the regression suite with its own tuned prompt variant, holds quota for full failover load and has carried ramped traffic, meets the primary's data terms (`ai/security.md`), passes the gateway with no required parameter dropped or rewritten, and is exercised on a schedule. Until then, degrade: the same snapshot on another host or region first, then a smaller model from the same provider, a cached or deterministic answer, or a clear feature-off state. *Break when* a low-stakes free-form feature can fail over on lighter checks.
- **Static stability.** The serving path keeps its last-known-good model config, prompts and routing when the control plane (gateway config, prompt registry, flags) is impaired; recovery never depends on the impaired component.

## Model access, gateway & server-side placement

- **Model access is a driven port.** The domain calls task-level operations (e.g. `classify_ticket`, `draft_reply`), never provider request types, and a deterministic fake adapter keeps it testable without a model. Provider quirks (reasoning settings, caching hints, structured-output mode, tool-schema dialect) stay in the adapter, with per-provider prompt variants — never a lowest-common-denominator interface; provider-specific features pass through explicitly, recorded as portability debt, and unsupported parameters fail loudly.
- **A gateway arrives with the second team or provider**, or with a central audit or policy requirement; until then, an in-process client adapter. A gateway is tier-0: it holds provider credentials (workload identity or short-lived, scoped, rotatable keys — never one long-lived organization-wide key), meters every price dimension per tenant, feature and task, enforces the caps above, owns the single retry layer and cost attribution, and is the natural enforcement point for tool traffic (rules → `ai/security.md`). Ask which keys, tenants and tools fall if it is compromised; pin its dependencies and allowlist its egress.
- **Server-side placement** — hosted API, dedicated capacity or self-hosted weights — follows residency and data sensitivity, latency, sustained volume × utilization (engineering time included), and who operates and patches it, never a spend threshold; record it as an ADR. Self-hosting makes serving someone's job, and serving internals are out of scope here. Reserve capacity only for steady, latency-critical load, never beyond the reserved model's retirement horizon. Client and hybrid tiers → `ai/placement.md`.

## Observability & the AI SLI set

- **Every model call emits** provider, model snapshot, prompt-template version and parameters; tokens by class (uncached input, cache read, cache write, output, reasoning); time to first token and inter-token latency at p50/p95, plus total duration; finish reason, truncation and refusal included; retries and fallback taken; computed cost; feature, tenant and user attribution; the parent task trace. Emit the OpenTelemetry generative-AI semantic conventions from one adapter pinned to one convention version. Metrics stay unsampled and attribution ids go on spans, not metric labels (`observability.md`).
- **Content stays out of default telemetry.** Prompts, retrieved context and outputs live in a separate access-controlled store with its own retention and erasure, keyed by tenant and user so a deletion request reaches them, and referenced from spans — a row in `design-flow.md` § Data Inventory & Lifecycle. Redact before any third party sees content; full-content capture is an access-controlled, time-boxed exception; the consented debug-access path is designed before launch.
- **The AI SLI set** — named here once; targets come from the feature docs, never the template; rows land in `design-flow.md` § Observability & SLOs: judge-sampled quality pass rate per slice, with the scorer named (`ai/evals.md`) · abstain, escalation and human-override rate · refusal rate · cost per successful task (p95) · time to first token and inter-token p95 per latency class · cache-hit rate for multi-turn and agent features · approvals and interrupts per task for agents.
- **Drift alarms:** response length, refusal rate, tokens per task, schema failures and negative feedback, correlated with your own change log and the provider's change notices.

## Lifecycle & exit

- **Pin immutable snapshot ids**, never moving aliases, and stamp snapshot, prompt version and parameters on every trace; where a provider offers none, record the model as unpinned — tighter scheduled-eval cadence, drift alarms and an exit ADR. Pinned is not stable: scheduled production evals catch silent drift (triggers and suites → `ai/evals.md`).
- **Config releases** (`design-flow.md` § Release Model; release unit → `ai/evals.md`) add a soak period before the staged rollout.
- **Forced-migration runbook**, sized to the shortest notice you could receive: inventory model use per call site → run the successor in shadow → regression suite with repeated trials → retune prompts per model → re-sweep the reasoning budget and re-measure tokens per task, latency and refusal rate (tokenizers and defaults do not transfer) → confirm every request parameter is still accepted → ablate scaffolds (`ai/protocol.md`) → canary with instant rollback. *Break when* weights are self-hosted: no forced retirement, but you own serving.
- **Long-lived sessions** finish on the model, prompt and tool schemas they started with — old and new run side by side — within a maximum pin lifetime.
- **Exit cost lives in evals and adapters, not SDK calls.** Keep a provider-neutral eval suite that reports cost per task and pass rate, and an alternate model that passes it at an agreed fraction of baseline, re-checked on a schedule.
- **Provider-exclusive features** on the critical path (structured-output modes, caching semantics, hosted retrieval, tools or agents, batch, tuned weights, the embedder — re-embedding is a migration, `ai/context.md`): wrap each behind the port with a tested fallback, or record a one-way-door ADR with an exit estimate. *Break when* a provider's unique capability is the product's moat: accept the lock-in by ADR, with a revisit trigger.
- **Own your state** — session and event log, transcripts, memory export, eval sets; provider-side state (stored conversations, managed memory) is a rebuildable cache.

## Red flags

- 🟠 Cost estimated per request for the average user, or models compared on list price per token.
- 🔴 No server-side run or user caps — the provider spend cap or a budget alert is the only control — or a flat-rate plan over agentic usage without per-user metering.
- 🔴 A semantic cache shared across tenants, or placed in front of tool-calling or agent paths.
- 🔴 A refused request re-sent to a more permissive model or provider.
- 🟠 Reliability assumed, not tested: retries at several layers or on refusal and spend-cap errors; a fallback never run through the regression suite or without quota for full failover; moving model aliases in production.
- 🟠 Full prompts and outputs in default telemetry or third-party tools, or content-free telemetry with no consented debug path.
