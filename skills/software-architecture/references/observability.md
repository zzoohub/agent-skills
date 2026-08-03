# Observability

Observability is the property that lets you ask **new questions** about production behavior without shipping new code. The three signal types — traces, metrics, logs — are how that property is achieved. Treat observability as an architectural concern, not a "we'll add logging later" task.

This file covers the architectural decisions. Vendor / SDK choice is in `house-stack.md`.

## Table of Contents

1. [The Three Signals](#the-three-signals)
2. [OpenTelemetry as the Default](#opentelemetry-as-the-default)
3. [Trace Architecture](#trace-architecture)
4. [Metrics Architecture](#metrics-architecture)
5. [Log Architecture](#log-architecture)
6. [Correlation Across Signals](#correlation-across-signals)
7. [Health Checks](#health-checks)
8. [Observability as a Port (Hexagonal)](#observability-as-a-port-hexagonal)
9. [What to Define in the Architecture Document](#what-to-define-in-the-architecture-document)

---

## The Three Signals

| Signal | Answers | Cardinality | Cost Model |
|---|---|---|---|
| **Traces** | "Where did this request spend its time? Which call failed?" | High (one trace per request) | Per-span; sample to control cost |
| **Metrics** | "What is the rate / latency / saturation right now?" | Low (pre-aggregated) | Per active series; cardinality = pricing |
| **Logs** | "What exactly happened in this one execution?" | Highest (one record per event) | Per byte ingested; structure to enable querying |

**They are not interchangeable.** Logs cannot answer "p99 latency by endpoint" cheaply. Metrics cannot answer "show me this exact request's path." Traces cannot replace per-event audit detail. Design which signal carries which question before instrumenting.

---

## OpenTelemetry as the Default

OpenTelemetry (OTel) is the vendor-neutral standard for emitting traces, metrics, and (increasingly) logs. Instrument once with the OTel SDK; route to any backend via the **OTel Collector**.

```
Application -> OTel SDK -> OTLP -> OTel Collector -> [ Tempo | Jaeger | Datadog | Honeycomb | ... ]
                                                  -> [ Prometheus | Mimir | Datadog | ...        ]
                                                  -> [ Loki | Elastic | Datadog | ...            ]
```

The backend names above illustrate the vendor-neutral fan-out; the house pick is OTel + CF Workers Logpush per `house-stack.md` — no third-party logging vendor by default.

**Why this matters architecturally**:

- **Vendor lock-in is deferred** — the SDK and instrumentation libraries are stable, the backend is swappable.
- **Collector is the policy plane** — sampling, redaction, routing, batching all live there, not in app code.
- **Context propagation is standardized** — W3C `traceparent` / `baggage` headers cross every service automatically.

Avoid backend-specific SDKs (Datadog tracer, New Relic agent) in new services unless OTel coverage is genuinely missing. Migrating later is expensive.

---

## Trace Architecture

### Span hygiene

Every inbound request opens a root span; every outbound dependency opens a child span; the trace context (`traceparent`) propagates across HTTP, gRPC, and message brokers.

| Layer | Span Behavior |
|---|---|
| **HTTP server** | Auto-instrumented. Span per request, with `http.method`, `http.route`, `http.status_code` |
| **DB client** | Auto-instrumented. Span per query, with `db.system.name`, `db.query.text` (parameterized), `db.operation.name` (older `db.system`/`db.statement`/`db.operation` are deprecated aliases) |
| **Outbound HTTP / gRPC** | Auto-instrumented. Inject `traceparent` header automatically |
| **Message broker** | Inject `traceparent` into headers; consumer extracts and **links** (not parents) the consume span |
| **Application logic** | Manual spans only at meaningful boundaries (use case, sub-operation), not every function |

**Anti-pattern**: spans inside hot loops, spans for every domain method. Span creation is not free, and noise drowns the signal.

### Span attributes vs events

| Use a **span attribute** for | Use a **span event** for |
|---|---|
| Identifiers needed for filtering (user_id, tenant_id, order_id) | Discrete things that happened during the span ("cache_miss", "rate_limited") |
| Status, type, route | Errors with stack traces (`exception` event) |

**Always** add: `tenant_id`, `user_id` (when authenticated), aggregate id of the primary entity touched. These make traces filterable in production.

**Never** add: full request/response bodies, secrets, PII without redaction. The Collector's `redaction` processor catches escapes; do not rely on it as the only line of defense.

### Sampling strategy

You cannot afford to keep every trace. Decide where the sampler lives:

| Strategy | How | Trade-off |
|---|---|---|
| **Head sampling** (probabilistic) | Decide at root span — keep N% (e.g., 1%) | Cheap. Misses rare errors unless rate is high. |
| **Tail sampling** (in Collector) | Buffer full traces, decide after seeing the outcome | Keep all errors + slow traces + sample of healthy. Expensive Collector tier. |
| **Parent-based** | Honor upstream's decision | Required for consistency once a trace begins |

**Default**: parent-based + head sample at 1-10% at the edge, with a Collector tail-sampling tier that always keeps `error=true` and `latency > p99`.

### Distributed tracing crosses async boundaries

Traces commonly break at message broker boundaries. Fix:

1. Producer injects `traceparent` into message headers.
2. Consumer extracts `traceparent` and uses **span link** (not span parent) to connect — because consume happens minutes/hours later and is not "caused by" the producer in real time.
3. Outbox relays propagate the `traceparent` they captured at insert time, not at relay time.

Without this, a single user action shatters into disconnected traces and root-causing failures across services becomes archaeology.

---

## Metrics Architecture

### What to measure: RED + USE

| Pillar | For | Metrics |
|---|---|---|
| **RED** (request-driven services) | APIs, handlers | **R**ate, **E**rrors, **D**uration (per endpoint) |
| **USE** (resources) | DB, queues, caches | **U**tilization, **S**aturation, **E**rrors (per resource) |

Every service produces RED metrics. Every shared resource produces USE metrics. Anything else is supplementary.

### The cardinality cliff

Time-series databases bill by **active series count**. A series is one unique combination of metric name + label values. Adding `user_id` as a label on a per-request metric in a 1M-user system creates 1M series. This is the most common observability cost incident.

| Safe label | Unsafe label |
|---|---|
| `endpoint`, `method`, `status_code` | `user_id`, `request_id`, `trace_id` |
| `tenant_id` (bounded count) | `email`, `path` (unbounded) |
| `region`, `version` | `query_string`, `error_message` |

**Rule**: every label must have a small, bounded value space. Per-user / per-request data belongs in **traces** or **logs**, not metrics. If you find yourself wanting per-user metrics, you want exemplars (a metric value that links back to a trace).

### Exemplars

OTel metrics support exemplars: a metric data point can carry a `trace_id` pointer. When you see a latency spike on a dashboard, click → jump to a representative trace. This is the bridge between "something is wrong in aggregate" and "here is exactly what happened." Enable exemplars by default.

---

## Log Architecture

### Structured by default

Logs are JSON, not strings. Every log line carries:

- `timestamp` (RFC3339, UTC)
- `level` (`debug`/`info`/`warn`/`error`)
- `message` (the human-readable headline; everything else in fields)
- `service.name`, `service.version`, `deployment.environment.name`
- `trace_id`, `span_id` (for correlation)
- Context fields (`tenant_id`, `user_id`, etc.)

**Never** concatenate context into the message string (`"user 1234 failed"`). Put it in a field (`{ "user_id": 1234, "message": "user failed" }`). The first form is unqueryable; the second is.

### Log levels

| Level | Use For |
|---|---|
| `error` | The system failed to do its job. Pageable. Always shipped. |
| `warn` | The system handled a degraded path (retry succeeded, fallback triggered). Investigate trends. |
| `info` | Significant state changes (request handled, job completed, user signed up). Default ship level. |
| `debug` | Inner-loop detail. Off in production by default; toggleable per service or per request. |

**Anti-pattern**: `info` for everything. The loudest logs become useless.

### Logs vs traces

If a log line describes work that happened inside a span, prefer adding a span event or attribute. Logs are for events that don't fit cleanly into the request lifecycle (startup, scheduled jobs, async errors with no parent span).

### PII and redaction

Decide at design time what is *never* logged: passwords, tokens, full card numbers, raw request bodies on auth endpoints. Implement redaction at the **logger layer** (a hook that strips known fields) and at the **Collector layer** (a processor that scrubs known patterns). One layer of defense fails; two layers fail less often.

---

## Correlation Across Signals

The minimum viable observability stack lets a human pivot in seconds:

```
Dashboard alert (metric)
    -> click exemplar
       -> trace view (which span failed?)
          -> jump to logs for that trace_id
             -> see exact error and parameters
```

If any link in this chain is missing, root-causing in production takes hours instead of minutes. Architecturally, this means:

- Every metric should carry exemplars on critical paths.
- Every log line touched by a request must carry `trace_id`.
- Every span must carry the identifiers a human would search by.

---

## Health Checks

Health endpoints are part of observability. Don't conflate liveness and readiness.

| Endpoint | Returns OK when | Checked by |
|---|---|---|
| `/livez` | Process is running and responding. **No dependency checks.** | Container orchestrator — failures cause restart |
| `/readyz` | Process is ready to serve traffic. Checks critical dependencies (primary DB, required cache). | Load balancer — failures cause traffic shift |
| `/startupz` (optional) | Process has finished long-running init (cache warm, schema check). | Orchestrator before flipping to readyz |

**Critical**: liveness must not call dependencies. A flaky DB will cascade-restart every replica and cause a full outage. Liveness only checks "am I alive."

---

## Observability as a Port (Hexagonal)

Don't import OTel SDK types into the domain. Define ports:

```
Tracer   -> startSpan(name, attrs) -> Span (with end(), addEvent(), recordError())
Meter    -> counter(name) / histogram(name) / gauge(name)
Logger   -> info/warn/error with structured fields
```

The OTel adapter implements them; tests use no-op or capturing fakes. The domain emits events ("PaymentAttempted") and the application service translates them to spans/metrics/logs in one place.

This is the same hexagonal discipline applied to a cross-cutting concern. It also means swapping vendors or removing observability for a CLI build is a config change, not a refactor.

---

## What to Define in the Architecture Document

Before implementation:

- [ ] Backend choice (vendor or self-hosted) and rationale
- [ ] OTel Collector deployment topology (sidecar vs gateway vs both)
- [ ] Sampling strategy and budget
- [ ] Standard attributes every service must emit (`service.name`, `tenant_id`, etc.)
- [ ] Cardinality budget for metrics (max series per service)
- [ ] PII fields and redaction strategy
- [ ] Alerting baseline (which RED/USE metrics page)
- [ ] Correlation: how a log finds its trace, how a metric exemplar finds its trace

If these are not decided up front, the system will accumulate inconsistent instrumentation and become un-debuggable around the time it starts to matter.
