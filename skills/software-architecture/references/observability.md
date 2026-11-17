# Observability

For what you operate: the decisions behind the Observability Contract and the SLO table in `system.md` §5. Software others run needs diagnosability instead: structured logs or crash reports the operator can export, a verbosity switch, data on stdout and diagnostics on stderr, stable exit codes, and no telemetry leaving their environment without consent.

## Decide which signal answers which question

Metrics answer "how many, how fast, how full" and are what you alert on. Traces answer "where did this request go". Logs answer "what exactly happened here". None of them is an audit trail. Emit through OpenTelemetry from one adapter and keep sampling, redaction and routing in the collector, not in application code. Semantic-convention names change between versions: pin one per service and record the pin.

- **Every service** emits rate, errors and duration per operation; **every shared resource** (store, pool, queue, cache) emits utilization and saturation; **every async path** (outbox, queue, consumer, scheduled job) emits freshness, the age of its oldest pending item. Alert on age, not count: a stuck relay raises no request errors.
- **Durations are histograms** with a bucket boundary at each SLO threshold, so the SLI is exact.
- **Spans**: one per inbound request, named by route template, and one per outbound call. Across a broker, link the consumer's span to the producer's; an outbox relay propagates the trace context captured at insert.
- **Always on spans and logs**: tenant id, user id when authenticated, the primary entity's id. **Never**: bodies, secrets, unredacted personal data. Telemetry is a copy of what it names and follows the Data Inventory.

## Sampling: one coherent mode

Never put a low head-sampling rate in front of a tail sampler; what the head drops never reaches the tail.

- **Tail mode**, when the volume is affordable: SDKs sample everything, and a collector tier that routes all spans of a trace to one instance keeps every error, every trace over the latency threshold and a share of the rest.
- **Head mode**, when it is not: sample at the root, and catch rare failures through metrics and logs with exemplars.

Metrics are never sampled: sampling limits what you can inspect, never what you alert on.

## Cardinality is the cost

Metric cost scales with active series: one per combination of label values. Every label needs a small, bounded value space (endpoint, method, status, region, version, a bounded tenant count). User, request and trace ids, emails, raw paths and error messages belong in traces and logs; link them from metrics with exemplars. Give each service a series budget and alert when a deploy exceeds it.

## SLOs and burn-rate alerts

- **SLI** = good events ÷ valid events, measured where users feel it. A latency SLI is the share of requests faster than its threshold.
- **Burn rate** = observed error ratio ÷ (1 − target). Rate 1 spends exactly the budget over the period.
- **Starting parameters for a 30-day budget.** An alert fires only while both windows exceed the rate; the short window stops it soon after the burn does.

| Action | Budget consumed | Long window | Short window | Burn rate |
|---|---|---|---|---|
| Page | 2% | 1 h | 5 min | 14.4 |
| Page | 5% | 6 h | 30 min | 6 |
| Ticket | 10% | 3 d | 6 h | 1 |

For another period: burn rate = budget consumed × period ÷ long window.

- **Only SLO burn pages.** Saturation, error logs and resource signals describe causes; they feed dashboards and tickets. *Break when* a cause predicts certain impact before any symptom (a disk, quota or certificate running out): page on time to exhaustion.
- **Low traffic**: add synthetic probes, aggregate related SLIs or lengthen windows instead of paging on single failures.
- **Async**: the SLO is on the age of the oldest pending item. Drain time = backlog ÷ (processing rate − arrival rate); when it exceeds the freshness target, scale out or shed.
- The budget also governs releases: budget exhausted means reliability work preempts features. Each SLO has an owner and a runbook.

## Logs

Structured records, never concatenated strings: timestamp in UTC, level, message, service and version, trace and span ids, context fields. Redact at the logger and again at the collector. Give each service a retention period and a volume budget. Audit events never ride the log pipeline (`security-privacy.md` § Audit trail).

## Health checks

| Probe | Passes when | Consumer |
|---|---|---|
| Liveness | The process is responsive. No dependency checks | The platform's restart mechanism |
| Readiness | This instance can serve: initialized, not draining | The router |

Liveness that calls a dependency turns one flaky store into a fleet-wide restart. Readiness must not fail fleet-wide on a shared dependency either: every replica goes unready at once and the system loses even its degraded modes. Shared-dependency health drives degraded mode and alerts instead. Where there are no probes (serverless, edge), use dependency health in metrics plus an external synthetic check.

## The contract

Record in `system.md` §5, binding on implementation:

- Signal per question, and the backend with its reason (a Core Technology row).
- Sampling mode, what is always kept, and the collector topology it needs.
- Standard attributes and the pinned convention version.
- Cardinality budget per service.
- Redaction rule; log retention and volume budget.
- Which SLOs page and which ticket.
- How a metric finds its trace and a log finds its trace.
- **Day-one basics, however small the system**: error tracking, structured logs with trace ids, liveness and readiness or the platform's equivalent, and an external synthetic check on the main journey.
