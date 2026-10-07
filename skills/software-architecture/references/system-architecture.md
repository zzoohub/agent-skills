# System Architecture Patterns

Decides **which deployables exist, how they communicate, and the system-wide decisions around them**: composition (design-flow Stage 4), contract evolution (Stage 5), tenancy (Stage 6), topology and flags (Stage 7). Internal structure of one deployable → `service-architecture.md`; changing an existing system → `evolution.md`.

**Entry shape**: forcing question → **Choose when** (an envelope number or a named non-scale driver, never growth hopes) → **When not** + cost shape → **Failure mode** → **Guard** (`system.md` §5, by the driver's QA id).

---

## Composition Decision Order

Decide in this order; the system-pattern ADR records the result, plus one ADR per split or escalation.

0. **Shape first.** A library, CLI, mobile, desktop or embedded product, or a staged data pipeline? Start from a library core with a thin shell, pipes and filters, or a microkernel (§ Additional Patterns), and apply step 1 only to the parts operated as services.
1. **Split test, per candidate boundary.** Name the force that needs a separate deployable: (a) a divergent scaling or runtime profile shown in the envelope — a stateful connection tier beside a stateless request tier; (b) fault or blast-radius isolation an [H,H] scenario requires; (c) a security or compliance boundary (payment-card scope, a regulated data store); (d) an independent owning team with its own release cadence; (e) sharply divergent change volatility. Counter-forces: a shared transactional invariant, a chatty synchronous workflow, shared data relationships. No force outweighs its counter-forces → keep it a module. Throughput alone rarely splits a system (the one-box check, `design-flow.md` § Quantitative Envelope).
2. **Per flow, not per system.** One action fans out to independent reactions, or bursts must be absorbed → events for that flow. Read and write models diverge → CQRS for that path. Past states must be re-derived → event sourcing for that context. A write spanning deployables → first move the data into one; otherwise a saga.
3. **Placement is a separate input.** Residency, sovereignty, on-premises or offline constraints decide *where* units run (§ Deployment Topology), not how many deployables there are.

Composition heuristics: draw boundaries by business capability, not by technical layer; a synchronous API surface can front event-driven internals.

**Migrating an existing system** (strangler fig, branch by abstraction, parallel run, change-data-capture sync, migration red flags) → `evolution.md`.

---

## Core Patterns

### Modular Monolith — default for operated services
*Can each module change, test and ship without touching another module's data?*
**Choose when**: no force in the split test outweighs its counter-forces — the usual case for one team, or a few teams that can share a release train. Module boundaries contain a bad edit, by a person or an agent, the way service boundaries do, at zero network cost.
**Boundaries hold only with mechanisms**: (1) each module owns its tables or collections — no other module reads or writes them, no cross-module joins or foreign keys, references by id only; (2) cross-module calls go only through the module's public interface or in-process events; (3) a fitness function fails the build on imports of another module's internals and on cross-module data access (a static check, or per-module schemas with per-module credentials); (4) a module is ready to extract when it passes (3) and owns its migrations.
**When not**: modules genuinely need independent scaling or deploy cadence (the single deploy train becomes the bottleneck), or org size makes one release queue untenable.
**Failure mode**: erosion — the shared database quietly becomes the integration layer. **Guard**: mechanism (3), in CI.

### Request-Response
*Does the caller need the answer before it can proceed?*
**Choose when**: it does — a decision, a read-your-write, a confirmed money movement — and the synchronous chain on the critical path stays short.
**When not**: one action must fan out to several independent reactions — each new side effect edits the calling chain (the coupling EDA removes) — or traffic is spiky enough that synchronous back-pressure cascades failures downstream.
**Failure mode**: a slow, not down, dependency exhausts its callers' threads and connections, and availability multiplies down the chain (§ Deployment Topology). **Guard**: the dependency protection contract — propagated deadlines, one budgeted retry layer (`operational-patterns.md`) — plus a latency SLO per critical path.

### Event-Driven Architecture
*Who needs to know this happened, and can they learn it late?*
**Choose when**: several consumers react to the same fact, bursts must be buffered, work may finish later (notifications, analytics, enrichment), or producers and consumers must deploy independently.
**When not**: read-after-write consistency is required at most boundaries, or the system is small enough that broker infrastructure plus eventual-consistency debugging costs more than the decoupling returns. Cost shape: adding a consumer costs zero producer edits, but every flow becomes distributed — trace spread replaces call-stack locality.
**Broker semantics per flow** (Kleppmann: logs versus brokers): a command for exactly one handler → a work queue (competing consumers, delete on acknowledge, per-message retry and dead-letter queue). Facts many consumers react to, or that must be replayable (new projections, audit, late-joining consumers) → a retained log with independent consumer positions; its retention bounds the replay and backfill window, so record it. Ordering is per key only (`reliability-patterns.md`).
**Failure mode**: the dual write (`reliability-patterns.md` §1) — publish through an outbox and dedupe consumers by event id. **Guard**: age of the oldest unprocessed message per consumer, as an SLO; event schemas under the compatibility check (§ API Versioning Strategy).

### CQRS
*Does the read side need a different shape, store or consistency than the write side's invariants?*
**Choose when**: read models diverge from the write model (cross-aggregate projections; a different store or index type, such as search or graph; different consistency per side), or the read envelope outruns the read-scaling ladder — index → cache → replica → materialized view. Start in-store: separate query models over the same store, updated synchronously. Move to a separate read store with asynchronous projection only when an envelope number requires it, and record its staleness budget.
**When not**: read and write shapes are essentially the same — two models make every schema change a double edit plus projection upkeep, with no read-side win to pay for it.
**Failure mode**: projection lag read as truth — users miss their own writes, and a projection bug diverges silently. **Guard**: projection lag against the staleness budget; a rebuild-from-source test; a read-your-writes path where the writer needs one.

### Event Sourcing
*Must past states be reconstructed, or re-derived under new rules?*
**Choose when**: they must — temporal queries, reconstructing what was known when, re-deriving state as rules change.
**When not**: nothing in the domain requires history — the complexity floor is permanent (every schema change becomes event versioning forever); see the warning below.
**Warning**: Most applications are better served by EDA + a good audit log table.
**If adopted** (each a one-way door): an upcasting strategy per event type from day one; a snapshot policy; a measured time budget for rebuilding projections. Keep personal data out of events, or encrypt it per data subject so that erasure works by deleting the key.
**Failure mode**: rebuilds that outgrow their budget, and erasure duties colliding with an immutable log. **Guard**: a scheduled projection rebuild within its budget; upcaster tests for every event version still in retention.

### Saga
*Can the data move into one deployable instead?*
**Choose when**: a business transaction must span deployables whose data cannot be co-located. Sagas give up isolation — other flows see intermediate state (Garcia-Molina & Salem; countermeasures after Richardson):
- Classify each step as compensable, pivot (the go/no-go point) or retriable, and order them compensable → pivot → retriable, so irreversible effects (money moved, message sent) come after the pivot: they can only be offset, not undone.
- Every step and every compensation is idempotent and retryable.
- Intermediate states are explicit domain states (e.g. PENDING, a semantic lock), so other flows don't act on unconfirmed results.
- Orchestrate when there are more than ~3 steps, timers or human waits, or a status that must be queryable, and run it as a durable workflow (`operational-patterns.md` § Durable Execution); choreograph only short flows with no central invariant.

**When not**: the data can live in one service (a local transaction has none of the compensation state-space), or the flow's value doesn't justify designing and testing N compensating paths — each saga step multiplies the failure states that need coverage.
**Failure mode**: anomalies on intermediate state, and a compensation that fails or runs twice. **Guard**: per step, a test that injects a failure and asserts the compensated end state; an alert on the age of the oldest in-flight saga.

---

## Additional Patterns

### Pipes and Filters
*What happens to one bad record, and where does a rerun restart?*
**Choose when**: the work is a staged transformation (ingest → parse → validate → enrich → load) whose stages scale, fail or change independently.
**When not**: steps share rich mutable state or need interactive low-latency round trips. Cost shape: each stage is simple and replaceable, but failure handling moves into the pipes — every stage idempotent, a checkpoint/replay point, backpressure between stages, a dead-letter path for bad records.
**Failure mode**: a poison record stalls the pipeline, or a replay applies a stage twice. **Guard**: alerts on freshness (age of the oldest unprocessed record) and dead-letter depth; a replay-from-checkpoint test.

### Microkernel (Plug-in)
*Who extends the core, and can they ship without a core release?*
**Choose when**: a stable core must accept extensions (formats, rules, integrations) from third parties or per customer without core releases.
**When not**: extensions are few and internal; a plain module is cheaper. Cost shape: the plug-in API becomes a published contract (§ API Versioning Strategy) with versioning and a compatibility suite.
**Failure mode**: a plug-in that crashes or blocks the core — isolate it (a process or sandbox boundary, timeouts, resource limits); third-party plug-ins are executable dependencies, admitted like any other (`security-privacy.md`). **Guard**: the compatibility suite against every supported plug-in API version; a misbehaving-plug-in test.

### Backend-for-Frontend (BFF)
*Do clients need materially different shapes or release cadences from the same backend?*
**Choose when**: Web and mobile clients have significantly different data needs, or you want to decouple frontend release cycles from backend.
**When not**: one client, or clients with the same data needs. Cost shape: one more deployable per client type and duplicated aggregation — accept the duplication; sharing it re-couples the clients.
**Failure mode**: business logic creeping into the BFF. It holds presentation aggregation only and is owned by its frontend team. **Guard**: a dependency rule — the BFF owns no data and calls only published interfaces.

### Analytical Workload Separation
*Is analytical load competing with transactional load on the primary?*
**Choose when**: the envelope shows it competing. Climb by freshness need, query concurrency and volume: read replica → columnar (OLAP) store → event lakehouse.
**When not**: the primary's headroom or one replica absorbs it. Cost shape: every rung adds a copy of the data to secure, retain and erase.
**Failure mode**: the feed was never treated as a contract, so analytics breaks on the next schema change; personal data copied into the lake escapes retention and erasure. **Guard**: the transactional-to-analytics feed (change data capture or events) is versioned under § API Versioning Strategy; every analytical copy is listed in the data inventory (`design-flow.md` § Data Inventory & Lifecycle).

---

## Cross-Cutting Architecture Decisions

### Deployment Topology
*What must keep serving when a zone, region or cell is lost, and where may each tenant's data live, failover included?* Per-function placement and partition contracts: `design-flow.md` § Deployment View & Topology. This entry chooses the regional shape; off the public cloud, read region as site and zone as an independent failure domain within it (power, network, rack).

| Topology | Choose when | Pays | Dominant failure mode |
|---|---|---|---|
| **Single region, multi-zone** | Default: the availability target fits one region's zones; users and residency fit one region | Region loss = restore elsewhere (RTO: the drilled restore; RPO: the backup interval) | A single-zone dependency silently undoes multi-zone |
| **Cells / regional cells** (independent stamps, each serving a partition of users or tenants) | Residency or latency pins tenants to a home region, or a blast-radius target caps how many share one failure | A thin global control plane (tenant → cell directory, identity, billing); fixed cost per cell; cross-cell queries via an aggregate read model | The router or directory becomes shared fate |
| **Active-passive** (warm standby region) | The RTO cannot absorb a full restore, but each data set can have one writing region at a time | Standby capacity; RPO = replication lag at failure; RTO = detect + promote + reroute | Failover never exercised; the standby lacks capacity, keys, secrets or quota |
| **Active-active** (several writing regions) | Writes must be accepted near users in several regions, or losing a region must be invisible | A home region per key, or a merge policy, for every written data set (`reliability-patterns.md`); spare capacity everywhere | Conflicts or split brain on a data set nobody gave a home |

- **Placement is not scale** (step 3 above): decide what stays global (identity, billing, the directory) and keep regulated data out of it.
- **Availability math.** Serial dependencies multiply (three 99.9% hops ≈ 99.7%). Redundancy approaches 1 − (1 − a)ⁿ only with independent failures and automatic, exercised failover; anything shared — deploy pipeline, config push, name resolution, identity, the directory — counts once, in series.
- **Static stability** (`operational-patterns.md`) at topology scale: survivors absorb a lost cell or region without new provisioning, so n units run at no more than (n − 1)/n of capacity, and the data plane routes from a cached copy of the directory while the control plane is impaired.
- **Failover targets** satisfy residency (an in-region target, or an accepted outage) and carry what the workload needs: keys, identity, secrets, quotas, processor agreements.
- **Cells.** The tolerable share of users or tenants hit by one cell's failure or one bad deploy caps the cell size. Choose cells only when most operations stay inside one partition key. The router stays thin, static and free of business logic. Cells are also the rollout unit (`design-flow.md` § Release Model).
- **Designing at peak (scale class L).** (1) Tiers split by scaling profile — stateful connections, aggregation, stateless requests, async work — deploy separately even from one codebase. (2) Per tier: per-unit capacity (verified by an ATAM spike) × peak × headroom → unit count and provisioning lead time; pre-provision scheduled peaks. (3) Partition keys and hot-partition handling per tier: `design-flow.md` Stage 6. (4) Launch gate: an open-loop load test at or above peak with a realistic ramp, plus the game day below.
- **Guard**: a scheduled game day that loses one cell or region and measures RTO and RPO against their targets; a residency check that every copy and failover target of a pinned tenant stays in region.

### Multi-Tenancy
*What isolates tenants at each shared resource, and what proves it?*
Decide isolation per tenant tier and per shared resource — database, cache, search index, object storage, queues and jobs, compute, keys, telemetry, shared AI state (`ai/security.md`) — not once for "the database".
- **Model per tier**: *pooled* (shared resources, a tenant id on every tenant-owned record) is the default for many small tenants and scales to the largest tenant counts. *Siloed* (a dedicated store or stack) where contracts, regulation, per-tenant keys or residency, or a low tolerance for noisy neighbors demand it. *Hybrid* is normal — pool the free tier, silo the enterprise tier, or silo only the resource that needs it. Each silo adds a fixed cost floor; price it per tier (`design-flow.md` § Cost & Unit Economics). The model is a one-way door: record it as an ADR.
- **At least two enforcement points**: a tenant-scoped data-access path that cannot run without tenant context, plus a store-level guard where the engine offers one (row policies; per-tenant credentials, schemas or databases). A row policy alone is not isolation: privileged roles bypass it, and connection-scoped tenant context must be reset on pooled connections.
- **Tenant id everywhere the data goes**: cache keys, search documents, object paths, job payloads, log lines, analytics exports.
- **Noisy neighbors**: per-tenant quotas, rate limits and fair scheduling of shared workers (`operational-patterns.md`), plus a path to move a heavy tenant to a silo.
- **Lifecycle**: per-tenant export, verified deletion across every copy (`design-flow.md` § Data Inventory & Lifecycle), relocation between cells or regions, and single-tenant restore — designed up front; for regulated tiers they often decide pooled versus siloed.
- **Guard**: automated cross-tenant tests in CI — tenant A's credentials never read tenant B's data, through any resource above — plus a runtime tenant-mismatch detector.

Physical realization (policies, roles, schema- or database-per-tenant mechanics) → a database-design capability, if available.

### Real-Time Communication
*What must reach which clients within how long, and what happens to messages during a reconnect?* Generative-AI token streams → `ai/production.md` § Streaming & generation lifetime.

**SSE handles most "real-time" needs. Use WebSocket only when the client needs to send frequent messages to the server.**

**Connection management**: long-lived push connections — SSE and WebSocket alike — are stateful. Plan for:
- heartbeats, graceful draining during deploys, and per-instance connection limits;
- reconnect with message replay from a resume cursor (a per-stream sequence in commit order — `reliability-patterns.md` § Ordering; SSE's Last-Event-ID), under the reconnect contract (`operational-patterns.md`), so a deploy or outage doesn't become a reconnect storm;
- beyond one instance, a fan-out backplane (pub/sub or a connection registry) and a replay source, both on the container diagram; across regions, connections terminate near users, each room or stream has one home region for its writes, and fan-out is relayed regionally.

**Delivery per message class**: classify each message type by delivery guarantee and staleness tolerance — presence is at-most-once; votes and orders are at-least-once and idempotent; high-frequency shared state (counters, leaderboards, cursors) is coalesced and broadcast on a tick. Record fan-out (connections × messages/s × recipients per message) and the join ramp as binding load units (`design-flow.md` § Quantitative Envelope).
**Failure mode**: a deploy or outage drops every connection at once, and the reconnect-and-replay wave overloads the backplane. **Guard**: a reconnect-storm test under load; delivery lag per message class as an SLO.

### API Versioning Strategy
*Who depends on this surface, and how does it change without breaking them?*
Applies to every surface in the published-contract inventory (`design-flow.md` § Published Contracts) — events, files, CLI output and plug-in APIs as much as HTTP/RPC APIs.
- **Breaking** = removing or renaming anything; a type or meaning change; a new required input; tighter validation; a new enum value that exhaustive consumers switch on; a changed default, error shape or ordering that consumers rely on.
- **Default**: producers change additively; consumers are tolerant readers (ignore unknown fields and values). Additive-only avoids most versioning, not all of it.
- **Breaking changes** go expand → migrate consumers → contract, with a published deprecation window. Add a version (path, header, or a new event type) only when expand-contract can't express the change — typically a breaking change to a core resource, a fundamental data-model change, or consumers with long upgrade cycles.
- **State compatibility as reader/writer rules plus deploy order** ("new readers accept old data → upgrade consumers first"), not as "backward/forward" — schema registries define those words differently.
- **Events and stored formats outlive their writers**: consumers and replays not yet written will read the retained history, so never edit a published event type, and keep a reader (upcaster) for every version still in retention.
- **Guard**: a compatibility check in CI — a schema diff against the last release, or consumer-driven contract tests.

### Feature Flag Architecture
*What is this flag for, how long will it live, and what happens when the flag service is unreachable?*
A flag change is a release (`design-flow.md` § Release Model). Toggle types differ in lifetime and dynamism (Hodgson):

| Type | Lifetime | Evaluated | Default when the flag service is unreachable |
|---|---|---|---|
| Release | Days to weeks; delete after rollout | Per request | Off |
| Experiment | Weeks; sticky assignment | Per request | Control variant |
| Ops / kill switch | May be long-lived | Locally, from cached config — must work while the flag service or the system it protects is degraded | Declared per switch: last known value, or halt where it guards consequential actions |
| Permissioning / entitlement | Years | Per request; the source of truth stays in billing or authorization state, audited | Last known entitlement |

- **Flag lifecycle**: Every flag should have an owner and an expiration date. Permanent flags (entitlements) are fine; temporary flags (rollouts) that linger become tech debt.
- **Default values**: Always define a safe default for when the flag service is unreachable — per type, as in the table; one default for every flag cuts paying customers off during a flag outage.

**Failure mode**: stale flags multiply untested paths. **Guard**: a flag inventory check in CI — every flag has an owner, a type and an expiry; an expired release flag fails the build.
