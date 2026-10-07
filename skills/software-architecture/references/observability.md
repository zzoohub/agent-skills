# Observability

Decisions for what you operate land in the Observability Contract of `system.md` §5 (default `docs/arch/system.md`; caller may redirect), binding on implementation; the backend is a Stage 5 technology choice. Software others run (a library, CLI or self-hosted product) needs diagnosability instead: structured, versioned logs or crash reports the operator can export, a verbosity switch, and no telemetry leaving their environment without consent.

---

## Signals and OpenTelemetry

**They are not interchangeable.** Logs cannot answer "p99 latency by endpoint" cheaply. Metrics cannot answer "show me this exact request's path." Traces cannot replace per-event detail, and neither traces nor diagnostic logs are an audit trail. Design which signal carries which question before instrumenting.

OpenTelemetry (OTel) is the vendor-neutral standard for emitting traces, metrics and logs. Instrument once with the OTel SDK and route through the Collector: application → OTel SDK → OTLP → Collector → whichever trace, metric and log backends the project chose.

- **Vendor lock-in is deferred** — the backend is swappable; SDK and instrumentation-library stability varies by language and signal, so check it at design time beside the pinned convention version.
- **Collector is the policy plane** — sampling, redaction, routing, batching all live there, not in app code.
- **Context propagation is standardized** — W3C `traceparent` / `baggage` headers cross every service automatically.
- **Semantic-convention names change between versions** — pin one version per service, emit through instrumentation libraries or one adapter, and record the pin in the contract.

Avoid backend-proprietary tracers and agents in new services unless OTel coverage is genuinely missing. Model-call telemetry and the AI SLI set → `ai/production.md`.

---

## Trace Architecture

### Span hygiene

Every inbound request opens a root span (method, route template — never the raw path — status); every outbound call opens a child span (store spans carry parameterized query text, never bound values); application code adds manual spans only at meaningful boundaries (use case, sub-operation). **Anti-pattern**: spans inside hot loops. `traceparent` propagates across HTTP and RPC; across a broker the producer injects it into message headers and the consumer connects with a **span link** (not span parent). Outbox relays propagate the `traceparent` they captured at insert time, not at relay time.

### Span attributes vs events

Attributes carry what you filter by: ids, status, type, route. Discrete occurrences inside a span (cache miss, rate-limited, exception) are emitted as event or log records correlated with the active span (`trace_id` / `span_id`), through whatever API the pinned convention version specifies.

**Always** add: `tenant_id`, `user_id` (when authenticated), aggregate id of the primary entity touched. These make traces filterable in production. Identifiers in telemetry follow the data inventory (class, residency, retention): telemetry is a copy of what it names (design-flow Stage 6 § Data Inventory & Lifecycle).

**Never** add: full request/response bodies, secrets, PII without redaction. The Collector's `redaction` processor catches escapes; do not rely on it as the only line of defense.

### Sampling strategy

**Default — choose one coherent mode; never put a low head rate in front of a tail sampler** (whatever the head drops never reaches the tail tier).

- **Tail mode** (volume affordable at a gateway): SDKs are parent-based and always-on. A gateway Collector tier with trace-ID-affinity routing (all spans of a trace reach one instance) keeps every error trace, every trace over the latency-SLO threshold (a fixed duration — tail policies can't compute live percentiles), and N% of the rest.
- **Head mode** (volume too high to buffer): parent-based + N% at the root. Rare failures are then caught by metrics and logs with exemplars, not by traces.

If both are needed, head-sample only the traffic classes whose errors you can afford to lose. Metrics are never sampled: SLIs come from unsampled metrics, so sampling limits what you can inspect, never what you alert on.

---

## Metrics Architecture

### What to measure: RED, USE, freshness

Every service emits RED per endpoint or operation; every shared resource (store, pool, queue, cache) emits USE; every async path (outbox, queue, consumer, scheduled job) gets a freshness SLI — age of the oldest pending item (time since the last successful run, for a scheduled job), consumer lag, DLQ depth — and alerts on age, not count: a stuck relay or a dead consumer raises no request errors. Durations are histograms with a bucket boundary at each latency-SLO threshold (or high-resolution histograms), so the SLI is exact rather than interpolated.

### The cardinality cliff

Metric cost scales with **active series** — one per metric × label-value combination: a `user_id` label on a per-request metric in a 1M-user system creates 1M series, the most common observability cost incident.

| Safe label | Unsafe label |
|---|---|
| `endpoint`, `method`, `status_code` | `user_id`, `request_id`, `trace_id` |
| `tenant_id` (bounded count) | `email`, `path` (unbounded) |
| `region`, `version` | `query_string`, `error_message` |

**Rule**: every label must have a small, bounded value space. Per-user / per-request data belongs in **traces** or **logs**, not metrics. If you find yourself wanting per-user metrics, you want exemplars (a metric value that links back to a trace). Give each service a series budget and alert when a deploy exceeds it.

Enable exemplars by default.

---

## SLOs and Burn-Rate Alerting

design-flow Stage 8 § Observability & SLOs derives each SLO from its driver and sets the policy (page on fast burn, ticket on slow burn); the mechanics live here.

- **SLI** = good events ÷ valid events, measured where users feel it (edge, gateway or client), not on internals. A latency SLI is the share of requests faster than its threshold.
- **Burn rate** = observed error ratio ÷ (1 − SLO target). Burn rate 1 spends exactly the budget over the period; budget consumed in a window = burn rate × window ÷ period.
- **Multiwindow, multi-burn-rate alerts** — starting parameters for a 30-day budget (after Beyer et al., the SRE workbook). An alert fires only while both windows exceed its burn rate; the short window (1/12 of the long) stops the alert soon after the burn does.

| Action | Budget consumed | Long window | Short window | Burn rate |
|---|---|---|---|---|
| Page | 2% | 1 h | 5 min | 14.4 |
| Page | 5% | 6 h | 30 min | 6 |
| Ticket | 10% | 3 d | 6 h | 1 |

For another budget period, keep the budget-consumed column and recompute: burn rate = budget consumed × period ÷ long window.

- **Only SLO burn pages.** RED/USE signals, saturation and error logs describe causes: they feed dashboards and tickets and never page on their own. *Break when* a cause predicts certain user impact before any symptom shows (a disk, quota or certificate running out): page on time-to-exhaustion, not on level.
- **Low traffic**: a few failures can burn hours of budget. Add synthetic probes, aggregate related SLIs, or lengthen the windows rather than page on single failures.
- **Async freshness**: the SLO is on the age of the oldest pending item. Backlog drain time = backlog ÷ (processing rate − arrival rate); when it exceeds the freshness target, scale out or shed before the backlog ages out.

---

## Log Architecture

### Structured by default

Logs are structured records (JSON or the platform's structured format), not strings. Every record carries `timestamp` (RFC 3339, UTC), `level`, `message` (the human-readable headline; everything else in fields), service identity (name, version) and deployment environment as resource attributes, `trace_id` / `span_id` for correlation, and context fields (`tenant_id`, `user_id`, etc.).

**Never** concatenate context into the message string; put it in a field.

`debug` is off in production, toggleable per service or per request.

### PII, retention and audit

Decide at design time what is *never* logged: passwords, tokens, full card numbers, raw request bodies on auth endpoints. Implement redaction at the **logger layer** (a hook that strips known fields) and at the **Collector layer** (a processor that scrubs known patterns). One layer of defense fails; two layers fail less often.

Diagnostic logs get a retention period and a volume budget per service. **Audit events are not diagnostic logs** and never ride the log pipeline, which samples, drops under backpressure, rotates and is readable by engineers (`security-privacy.md` § Audit Trail).

---

## Correlation Across Signals

A human must pivot in seconds: metric alert → exemplar → trace (which span failed?) → logs for that `trace_id` → the exact error and parameters. Architecturally:

- Every metric should carry exemplars on critical paths.
- Every log line touched by a request must carry `trace_id`.
- Every span must carry the identifiers a human would search by.

---

## Health Checks

| Probe | OK when | Consumer |
|---|---|---|
| **Liveness** | The process is responsive. **No dependency checks.** | The platform's restart mechanism |
| **Readiness** | *This instance* can serve: initialized, not draining, its own pool and config healthy | The router — removes one bad instance |
| **Startup** (optional) | Long-running init finished (cache warm, schema check) | Gates readiness |

**Critical**: liveness must not call dependencies — a flaky store would cascade-restart every replica into a full outage.

Readiness must not fail fleet-wide on a shared dependency either: when it blips, or its pool saturates under load, every replica goes unready at once and the system loses even its degraded modes (cached reads, clear 503s). Shared-dependency health drives degraded mode and alerts instead. If readiness does check a shared dependency, the routing layer must fail open when all targets are unready and nothing may restart or replace instances on that check — state which, because platforms differ. Where there are no probes (serverless, edge), readiness becomes dependency health in metrics plus an external synthetic check.

---

## Observability as a Port (Hexagonal)

Don't import OTel SDK types into the domain. Define ports:

```
Tracer   -> startSpan(name, attrs) -> Span (with end(), event(name, attrs), error(err))
Meter    -> counter(name) / histogram(name) / gauge(name)
Logger   -> info/warn/error with structured fields
```

The OTel adapter implements them (emitting events and errors the way the pinned convention version specifies); tests use no-op or capturing fakes. The domain emits events ("PaymentAttempted") and the application service translates them to spans/metrics/logs in one place.

Swapping vendors, or removing observability for a CLI build, is then a config change, not a refactor.

---

## What to Define in the Architecture Document

Before implementation, record in `system.md` — the Observability Contract (§5), alerting in the §5 SLO table, and the backend as a §2 Core Technology row:

- [ ] **Signal per question** — which questions traces, metrics and logs each answer; RED per service, USE per resource, freshness per async path
- [ ] **Backend** (vendor or self-hosted) and rationale
- [ ] **Collector topology** (agent/sidecar vs gateway) — for tail sampling, trace-ID-affinity routing to the sampling tier
- [ ] **Sampling policy** — mode (tail or head), what is always kept, and the budget
- [ ] **Standard attributes** every service must emit, and the **pinned semantic-convention version** (names change between versions)
- [ ] **Cardinality budget** for metrics (max series per service)
- [ ] **Redaction rule** — PII fields and redaction; diagnostic-log retention and volume budget; audit events kept out of the log pipeline
- [ ] **Alerting** — which SLOs page on fast burn and which ticket on slow burn; RED/USE signals and error logs feed dashboards and tickets, never pages on their own; histograms resolve each latency-SLO threshold
- [ ] **Correlation** — how a log finds its trace, how a metric exemplar finds its trace
- [ ] **Day-1 basics**, even at Lite rigor — error tracking, structured logs with trace ids, liveness/readiness or the platform's equivalent, an external synthetic check on the main user journey
