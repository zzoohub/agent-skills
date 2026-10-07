# Operational Patterns

Dependency decisions become rows of the Resilience table in `system.md` §5 (default `docs/arch/system.md`; caller may redirect); caching decisions go in its §3.

---

## Pagination Strategy

**Default to cursor (keyset) pagination.** Offsets skip or duplicate rows when rows are inserted or deleted between requests, and deep pages get slower. *Break when* the set is small or static and the UI needs page numbers or a total — admin and back-office views may use offset.

- Cursors are opaque to clients.
- Every sort order offered to clients needs an index on (sort key, tiebreaker); physical design via the database-design capability, if available.
- An exact total on a large set costs a full count: return "has more" or an estimate unless the product needs the number.
- Record the default once, with the published-contract policy (design-flow Stage 5 § Published Contracts). Query and wire mechanics belong to the implementation guide, not the design doc.

---

## Dependency Protection & Overload

Every synchronous dependency on a critical path — store, internal service, third-party API, model provider — gets a **dependency protection contract**, recorded as one row of the `system.md` §5 Resilience table. Ask what happens when it is **slow**, not just down: slow is the common case and the more dangerous one.

### Deadlines, top-down

Every external call gets a timeout, derived top-down:

1. Start from the user-facing deadline (the latency driver or a UX limit) and propagate the **remaining** budget on every hop, in the request context and outbound headers.
2. Set each dependency's timeout just above its tail latency at the false-timeout rate you accept (0.1% false timeouts ⇒ its p99.9 under normal load; estimated until measured) and within the remaining budget.
3. If the sequential chain cannot fit, parallelize, cache or move work async. Never derive the outer timeout by summing inner ones, and never compare summed worst-case bounds with a percentile SLO.
4. Every hop drops work whose caller has already given up (deadline passed).

*Break when* no caller is waiting (offline batch): give the job a total budget instead. Model calls and streams follow the same contract; their timeout classes live in `ai/production.md` § Streaming & generation lifetime.

### Retries: one layer, on a budget

Only retry **idempotent** operations.

| Strategy | When |
|---|---|
| **No retry** | Non-idempotent writes without idempotency keys |
| **Retry with backoff** | Reads, idempotent writes |
| **Retry with idempotency key** | Critical writes (payment APIs, etc.) |

Retry at **exactly one layer** — the one that owns idempotency for the call, usually the dependency's direct client; every other layer fails fast. Independent retries multiply: three attempts at each of five layers is 3^5 = 243× load on a dependency that is already struggling. Retry only when all of these hold:

- the error is retryable (timeout, connection reset, throttled, unavailable), honoring `Retry-After`; validation, authorization, quota or spend-cap and payload-too-large errors go to handling, never to retry;
- the operation is idempotent or carries an idempotency key (`reliability-patterns.md` §2);
- backoff is exponential with full jitter;
- the deadline still has room;
- a **retry budget** allows it — a token bucket per client (successes refill a fraction of a token, each retry spends one), keeping retries under ~10% of calls and ~3 attempts per request (Beyer et al.).

Hedged requests (a second copy sent after the p95) cut tail latency only for short, idempotent, cheap calls, and spend the same budget. *Break when* many independent clients each back off politely: backoff bounds one client's work, not the population's — that is admission control's job (below). Offline idempotent batch jobs may retry throttling indefinitely within their own budget.

### Isolation and breakers

- **Bulkheads**: a concurrency limit, and its own connection pool, per dependency, so one slow dependency cannot hold every worker. Size it with Little's law (in-flight = arrival rate × latency) at normal latency plus headroom; when the dependency slows, the cap, not the timeout, bounds what it can hold.
- **Circuit breakers, with care**: a breaker fails fast to the named degraded mode, runs only on bad days and is hard to test — key it by failure domain (host, shard, cell) so one shard's failure doesn't make the whole dependency look down, and exercise the open state. To limit retries, prefer the retry budget; add a breaker only where failing fast unlocks a useful degraded mode.

### Admission control, shedding and backpressure

Protect goodput: under overload, a system that accepts everything completes nothing.

- **Admission control**: reject excess work at the edge, early and cheaply — before parsing, identity lookups or queueing. Bound the work any single request can do (page size, fan-out, payload, query cost).
- **Load shedding**: when saturated, reject the lowest-priority work first (prefetch, batch and retries before interactive first attempts) with a fast 429/503 and `Retry-After`, instead of queueing everything into timeouts. Keep a tested switch that sheds a whole traffic class.
- **Backpressure**: every queue is bounded and has a maximum age; a full queue pushes back on its producer instead of growing. A queue absorbs bursts, not sustained overload — work older than its useful life is dropped, not served late.
- **Reconnect contract**: long-lived clients (devices, sockets, mobile apps) reconnect with jittered exponential backoff and honor a server retry hint; the server admits reconnects at a bounded rate and is sized for the whole population returning after an outage or deploy (a Stage 1 load source). Session mechanics → `system-architecture.md`.

*Break when* durable acceptance is the requirement (order intake, telemetry ingest): accept into a durable queue and process later rather than shed. Load-test past saturation with an open-loop generator (fixed arrival rate); closed-loop tests slow down with the system and hide overload.

### Degradation and static stability

**Decide at design time, not at 3 AM.** Each dependency's degraded mode — serve stale, queue for later, disable the feature, read-only — goes in the `If slow / down` column, written as what the user sees. The primary store's degraded mode (read-only, cached reads, or offline) is chosen against the availability driver, not assumed.

**Static stability over fallback.** When a dependency or control plane is impaired, the data plane keeps serving last-known-good state (config, credentials, routes, cached reads), with capacity pre-provisioned so that losing one failure domain needs no reaction. Recovery never depends on the impaired component. A path that runs only on bad days is untested: a fallback is unqualified until it is exercised — continuously (a share of real traffic) or by scheduled drill — and the `Exercised` column says which and when ("never" is a finding); if it cannot be exercised, degrade instead. *Break when* the path is not foundational: spare capacity costs real money, so reserve it for paths whose loss stops the business. Bound staleness where stale data is unsafe (revocations, prices, entitlements).

### Size for the bad mode

The loop that keeps a system down after its trigger is gone — retry storms, cold-cache misses, backlog replay, reconnect storms — is the root cause of a metastable failure. Size backends to survive a full cache flush and a backlog drain at peak, keep error paths cheaper than success paths, and weaken the strongest loop (retry budget, shedding, rate-limited cache refill, capped drain rate, jittered reconnects). *Break when* the system runs far below capacity.

**When Availability is deep**, add `Detection` (the signal or SLO alert that notices) and `Blast radius` (which users, tenants or cells) columns, then walk each failure domain — instance, zone, region, provider, control plane, bad deploy or config change. Each needs a recovery path that doesn't depend on the failed component, meets the RPO/RTO set in Stage 6, and has been exercised (fault injection, game day, restore test). Cold-start the whole system on paper: no circular dependencies at startup.

---

## File Uploads

Flow: metadata → signed direct upload to object storage → completion call. Server-proxied uploads waste bandwidth and compute. *Break when* files are small and rare: proxying through the API within its request-size limit is simpler.

- **Signed URL**: short-lived, scoped to one server-chosen object key (never the client's filename) under the tenant's prefix.
- **Size**: a storage-side length condition bound into the signed upload where the store supports it, plus re-verification at completion. Client checks are UX only.
- **Type**: verified from the stored bytes (magic number), not the declared content type.
- **Quarantine → validate/scan → promote**: nothing is served before promotion.
- **Serving**: user content comes from a separate origin, with download disposition unless the type is allow-listed for inline display — uploaded markup served from the app origin is stored XSS.
- **Processing** (thumbnails, text extraction) is async. **Orphans** (upload done, completion never called) are removed by a lifecycle rule.

---

## Background Jobs

Triggered by a user action: if the user can wait < ~2 s, do it inline; otherwise async. Multi-step work with side effects, or long waits → durable execution (below). Enqueue atomically with the state change: a job row in the same transaction is the simplest outbox (`reliability-patterns.md` §3), and an external queue is fed from the outbox — never written before commit, or as a separate step after it.

Four invariants for every queue and scheduler:

1. **Handlers are idempotent** (a dedup key); delivery is at-least-once.
2. **Every queue has max attempts, a DLQ, and alerts on DLQ depth and oldest-message age** — a poison message in an unwatched DLQ is silent data loss.
3. **Scheduled jobs run as a singleton** (a lock or lease, or the scheduler's own guarantee) with an explicit overlap policy (skip / queue / allow) and an explicit timezone (DST shifts skip or repeat local times). N replicas must not fire one schedule N times.
4. **The visibility or lease timeout exceeds p99 job duration**, or the job heartbeats to extend it; otherwise a slow job is redelivered while still running.

Multi-tenant queues get per-tenant concurrency caps or fair scheduling, so one tenant's burst cannot starve the rest.

---

## Durable Execution

**Escalation ladder** — choose the lightest rung that fits:

| Rung | Fits |
|---|---|
| Job table or queue | Simple fire-and-forget, one step (send email, resize image) |
| State machine in your own store | A few steps with business-visible states (status column + guarded transitions) |
| Durable execution (workflow engine) | Multi-step with side effects (payment → provision → notify), timers, compensation; long-running with waits (human approval, external callback) |

An engine is new infrastructure someone operates — a Stage 5 technology choice; adopt one when it replaces machinery you would otherwise build and run.

**Engine-neutral primitives**: durable step (checkpointed; not re-run once recorded) · durable timer · await external signal — always with a timeout and an on-timeout path · deterministic replay.

**Invariants for any engine:**

1. **It does not replace idempotency at side effects.** A step can execute more than once (crash after the side effect, before the checkpoint), so every side-effecting step passes a step-scoped idempotency key downstream (`reliability-patterns.md` §2).
2. **Workflow code between steps is deterministic**: time, randomness and I/O happen only inside steps.
3. **Versioning of in-flight runs is planned before the first deploy**: pin each run to the code version it started on and drain, or branch on a recorded version marker; never reorder or remove steps under live runs.
4. **Business-visible status still lives in your store**; engine history is not your query model.

Compensation across services follows the saga rules in `system-architecture.md`; agent runs add their own deltas (`ai/agentic.md`).

---

## Webhook Reliability

A webhook from an external provider (payments, SaaS platforms) is an at-least-once, unordered and forgeable input. Protocol:

1. **Verify** the signature **and** the timestamp tolerance (replay window); otherwise reject.
2. **Durably record, then acknowledge**: an inbox row keyed by the provider event id (`reliability-patterns.md` § Inbox pattern) or a durable enqueue — then return 2xx. Never ack before the record exists: providers don't redeliver after a 2xx. Duplicates die on the inbox's unique key.
3. **Process async** from that record. Fan-out means one independent consumer per downstream action, so one failure doesn't block the others.
4. **Handlers are order-independent**: treat an event as a notification and re-read the provider's current object state, or compare the object's version or sequence. Never order by the provider's timestamp — distinct events can share one.
5. **Reconcile DB against provider API on startup / periodically** — deliveries get lost; reconciliation is the backstop, not an optimization.
6. Confirmations that arrive later (bank transfers, manual approvals): the workflow awaits the signal (Durable Execution), with a timeout.

Sending webhooks is a published contract (Stage 5): sign with a timestamp, deliver at-least-once from an outbox with backoff and a DLQ, carry an event id and a per-object version, and offer replay.

---

## Caching

**Forcing question: what staleness can this data tolerate, and who notices?** The answer sets the tool: TTL (bounded staleness is acceptable), event-driven invalidation (when seconds matter), or versioned keys (immutable content). **Default**: cache-aside with TTL.

- **Survive a full flush at peak**: the backing store is provisioned for it, or warm-up and rate-limited refill are designed. Otherwise the cache is a hidden availability dependency, and capacity sized at the steady-state hit rate is a metastable loop.
- **Who shares a cache is a confidentiality boundary** (a one-way door — design-flow Stage 9): keys carry tenant and authorization scope, or the cache is partitioned per tenant. *Break when* the data is public and identical for every principal — then sharing is the point.
- **Public or shared responses**: HTTP/edge caching is often the cheapest tier; personalized responses never reach a shared tier (private or no-store, and vary on every input that changes the response).

- Model-response and prompt caching follow their own rules in `ai/production.md`.

### Stampede Prevention

When a popular cache entry expires, many concurrent requests hit the DB simultaneously (thundering herd). Solutions:

- **Lock-based recomputation**: First request acquires a lock, recomputes, others wait. Use distributed lock for multi-instance
- **Stale-while-revalidate**: Serve stale data while one request refreshes in the background. Best UX — users never see a cache miss
- **Probabilistic early expiration**: Each request has a small random chance of refreshing before TTL. Spreads recomputation over time

**What NOT to cache**: Auth tokens/sessions in eventually-consistent stores (security risk), data that changes per-request, anything where stale data causes financial or safety issues.

---

## Rate Limiting

**Default**: sliding-window counter — good balance of precision and resource usage. Use a token bucket when you want to allow controlled bursts; a fixed window lets up to twice the limit through across a window boundary.

- **Dimensions**: IP (unauthenticated endpoints only — proxies and shared addresses make it both evadable and unfair; aggregate IPv6 by prefix, e.g. /64, not by address) · user or API key · tenant · endpoint. Apply them in layers; the tightest limit wins.
- **Weight by cost**: expensive endpoints (search, exports, model calls) spend more of the budget per request; limits for model-backed features at every scope live in `ai/production.md`.
- **Limiter failure**: decide per endpoint what happens when the shared limiter store is down — fail open (availability) or fail closed (abuse- or cost-sensitive paths).

- **Response**: `429 Too Many Requests` with `Retry-After`; expose the remaining quota in the standard rate-limit header fields the API adopts (the implementation guide owns the exact field names).
