# Structure

Depth for Stage 2: which parts exist, what each owns and hides, how they talk, where they run. Each rule carries the condition that breaks it. Guards land in `system.md` §5, keyed by driver id.

## Boundaries

A boundary is worth its cost when it hides a decision that is likely to change, or contains a failure, a secret or a team.

- **Find contexts by rules and change**, not by nouns. The same term under different rules is two contexts; modules that always change together are one. On an existing system the evidence is co-change in version history, schema access clusters and the call graph.
- **Each module hides one volatile decision** (a provider, a format, a ranking rule, a pricing policy) behind an interface that is smaller than what it hides. A layer or port that only forwards calls hides nothing and costs a hop on every change. *Break when* the port is a trust boundary, an anti-corruption layer, or a priced exit.
- **Dependencies point toward what changes least.** Domain rules know nothing of transport, storage or vendors. Cycles between modules mean none of them can be built, tested or deployed alone; guard with an import-graph check.
- **One writer per data set.** Everyone else reads through the owner's interface, a replica or a published contract. Two contexts writing the same tables cannot change their schema or invariants independently.
- **Generalize from two real consumers**, never from an imagined one. A shared package that keeps growing isolates nothing. *Break when* divergence would cause a correctness or security bug: centralize that rule at first use.
- **One name per concept.** Inside a context, code uses the requirement's terms one to one; a term that means two things marks a boundary.
- **Label each edge of the context map** with its relationship and whether it is sync or async. The two that carry weight: an **anti-corruption layer** where a vendor or legacy model must not leak into yours, and an **open host** (one stable published protocol) where you are upstream of several consumers.
- **Ownership.** One owner per context, no owner holding more than it can keep in its head, and the most frequent change inside one owner. When teams will grow, draw boundaries for the intended teams.

### Sourcing

Classify contexts first; the class is the budget allocator. **Core** gets the explicit domain model, the deepest tests and room to evolve. **Supporting** gets the simplest structure that works. **Generic** is decided by what the vendor actually sells:

| The vendor actually sells | Examples | Verdict |
|---|---|---|
| Liability transfer | card-data scope, identity verification, tax, certified components | Buy: you cannot write your way out of an audit |
| An earned asset | email deliverability, SMS routes, fraud signals | Buy: the value is accumulated reputation, not the API |
| Someone else's pager | 24/7 on-call, heavy infrastructure | Buy unless you staff a rotation for it |
| Spec conformance under attack | cryptography, OAuth/OIDC, sessions | An audited library you host, or the identity platform already in use; never hand-rolled |
| Just code | uploads, own-data search, flags, queues, admin CRUD | Build, adopt or buy by total cost: build + run + change + exit |

Cheap code generation lowers the build cost of "just code" and nothing else: you still own every CVE you wrote, and running cost is not writing cost. Price a vendor at the Stage 1 peak, not at today's volume. One-way sourcing decisions get an ADR in either direction.

## Shape

Decide in this order. The result is the System Pattern line and Decisions rows in `system.md` §1, with an ADR where a split or step-up was contested.

1. **What kind of thing is it?** A library, CLI, app or pipeline starts from a library core with a thin shell, pipes and filters, or a plug-in core. Steps 2–3 apply to the parts operated as services.
2. **Split test, per candidate boundary.** Name the force that needs a separate deployable: a divergent runtime or scaling profile shown in the envelope (a stateful connection tier beside stateless requests); blast-radius isolation a driver requires; a security or compliance boundary; an independent team with its own release cadence. Counter-forces: a shared transactional invariant, a chatty synchronous workflow, shared data. No force outweighs them → it stays a module. Throughput alone rarely splits a system.
3. **Step up per flow, not per system.**

| Step up | Choose when | When not | Fails as | Guard |
|---|---|---|---|---|
| **Events** between parts | Several consumers react to one fact, bursts must be buffered, or work may finish later | Read-after-write is required at most boundaries, or the system is small enough that tracing a distributed flow costs more than the decoupling returns | The dual write: state committed, event never published | Outbox; consumers dedupe by event id; age of the oldest unprocessed message as an SLO |
| **CQRS** | Read and write models differ in shape, store or consistency. Start in one store with separate query models; add an async read store only on an envelope number, with a staleness budget | Shapes are the same; a read/write ratio alone (index → cache → replica → materialized view first) | Projection lag read as truth | Lag against the budget; a rebuild-from-source test; a read-your-writes path where the writer needs one |
| **Event sourcing** | Past states must be reconstructed or re-derived under new rules | Plain audit: an append-only audit table covers it. The complexity floor is permanent | Rebuilds outgrow their budget; erasure collides with an immutable log | Upcaster tests per event version; a scheduled rebuild inside its time budget; personal data kept out of events or encrypted per subject |
| **Saga** | A business transaction spans deployables whose data cannot be co-located | The data can live in one service: move it first | A compensation fails or runs twice; other flows act on intermediate state | Order steps compensable → pivot → retriable; every step idempotent; explicit pending states; a failure-injection test per step |
| **Separate analytical store** | Analytical load competes with transactions on the primary | One replica absorbs it | The feed was never a contract, so analytics breaks on a schema change; personal data escapes erasure | The feed is versioned; every analytical copy is in the Data Inventory |

A queue for work one handler must do; a retained log for facts many consumers read or replay. Ordering holds per key only. More than about three saga steps, timers or human waits → an orchestrated durable workflow (`operational-patterns.md` § Durable Execution). A plug-in core turns the plug-in API into a published contract and third-party plug-ins into code to isolate. A backend per client type is justified only by clients with different shapes or release cadences, and owns no data.

### The modular monolith holds only with mechanisms

1. Each module owns its tables: no cross-module joins, foreign keys or writes; references by id.
2. Cross-module calls go through the module's public interface or in-process events.
3. A build check fails on imports of another module's internals and on cross-module data access.
4. A module is ready to extract when it passes (3) and owns its migrations.

The failure mode is quiet: the shared database becomes the integration layer. Module boundaries contain a bad edit, by a person or an agent, the way service boundaries do, at no network cost.

## Inside a context

Declare one style per context in `system.md` §1 and hold it. Agents and people infer conventions from neighboring code, so consistency is part of the prompt, and reviewers judge against the declared style.

- **Rigor from the class, raised by risk.** Core, and anything that moves money, decides authorization or has irreversible effects: a domain model behind ports (hexagonal), with a pure functional core where the rules are computation. Supporting and generic built in-repo: a transaction script or one slice per use case. Bought: an adapter, plus an anti-corruption layer if its model leaks.
- **Axis from the churn that dominates.** Features churn → vertical slices; a feature edit stays in one directory. Providers and infrastructure churn → ports. A rule shared by many slices turns one change into N edits, so that rule moves to the core.
- **Aggregates.** An invariant that must hold immediately lives inside one aggregate; one that may hold eventually spans aggregates through a domain event and the outbox. Keep aggregates small, reference others by id, change one per transaction. An entity that is a data bag needs none of this.
- **In-process events**: a handler that writes the same database runs inside the transaction; anything with an outside effect runs after commit from an outbox row, never from memory.

## Built by agents

When agents write and change most of the code, the architecture has to carry what a team used to carry in its head.

- **Declare, then enforce by a check.** The style per context, the dependency directions and the module boundaries are written in `system.md` and enforced in the build: import rules, structural tests, schema ownership. A rule that lives only in review erodes at an agent's throughput. Write each check's failure message as the instruction for fixing it.
- **The repository is the system of record.** What an agent needs to know (decisions, constraints, the current plan) lives in the repository as short, current files behind one brief map file. Knowledge in a chat thread or someone's head does not exist for the next session.
- **Verification speed is the bottleneck.** Give the inner loop a time budget (build and test in about a minute): each module runs its own tests in seconds against deterministic fakes of every external dependency, model ports included; the whole system boots locally or per branch; logs, traces and errors can be read from the command line. An agent converges only as fast as it gets a true signal, and acceptance tests it can rewrite are not a signal: keep them outside its write scope.
- **Locality.** A change should stay inside one context that fits in a context window: slices where features churn, no pass-through layers, narrow typed contracts between modules, a pure core that table tests cover without mocks.
- **Operations as files.** Infrastructure, flags, prompts and runbooks are reviewed code. A service that can only be configured through a console needs a reason.
- **The path to production is the next bottleneck.** When writing code is cheap, review attention, CI time, source control and environments decide throughput. Tier review by risk: people decide changes to the one-way doors (schema, published contracts, authorization, money) and read the intent of the rest; low-risk changes merge on checks alone, with post-merge tests and automatic revert as the net. An approval the reviewer cannot realistically evaluate is not a control. Schedule entropy clean-up; it does not happen by itself.
- **An agent that merges and deploys is a principal.** It runs in a sandbox with least privilege and controlled egress; credentials are scoped to the task, injected at run time through a proxy and never visible to it; destructive operations are delayed or soft, and backups live where its credentials cannot reach; new dependencies wait out a quarantine period before they can be installed.
- **Documents are context.** Every file an agent loads costs attention on every task. Stale or contradictory notes are worse than none: prune them, and turn any rule that can be checked into a check.

## Contracts

Applies to every surface in the Published Contracts table: HTTP and RPC APIs, events, files, CLI output, plug-in and tool interfaces.

- **Breaking** means removing or renaming anything; a type or meaning change; a new required input; tighter validation; a new enum value that consumers switch on exhaustively; a changed default, error shape or ordering.
- **Default**: producers change additively, consumers ignore what they do not know. A breaking change goes expand → migrate consumers → contract, with a published deprecation window. Add a version only when that cannot express the change.
- **State compatibility as reader and writer rules plus deploy order** ("new readers accept old data, so upgrade consumers first"), not as "backward" or "forward"; tools define those words differently.
- **Events and stored formats outlive their writers.** Consumers not yet written will read the retained history: never edit a published event type, and keep a reader for every version still in retention.
- **One domain core, many surfaces.** The interface for people, the API, tools for agents, voice and an operating system's assistant are adapters over the same use cases, each with its own identity, quotas and audit. An interface for agents is a published contract, not an internal convenience, and an action taken by an agent stays distinguishable from one taken by the person.
- **Guard**: a schema diff against the last release, or consumer-driven contract tests, in CI.

**Flags are releases.** Each flag has a type, an owner, an expiry and a declared value when the flag service is unreachable: a release flag defaults off, a kill switch works from cached config while the system it protects is degraded, an entitlement keeps its last known value. Guard: an expired release flag fails the build.

## Data

- **Store by access pattern**: point lookup, range scan, aggregate, text or similarity search, blob. Co-locate a new index in a store you already run until a measured ceiling binds.
- **Consistency per operation**, with the read anomaly the replication topology admits. Decide which reads must see their own writes.
- **Derived data inherits its source's boundary and deletion**: summaries, embeddings, caches and analytics copies carry lineage and the requester's permissions. *Break when* the corpus is public.
- **Partitioning is architecture** when the key sets a throughput ceiling, an ordering, a hot spot, a retention mechanism or a tenant or residency boundary: name the key per scaling dimension and the plan for a hot key. Physical layout → the database-design capability, if available.
- **Recovery.** One immutable backup copy outside the production credential domain; a restore that cannot decrypt or authenticate is not a restore. Data loss is the one failure that cannot be rolled forward.
- **Key Scenarios.** Walk the main journey and each order- or timing-sensitive driver as hops: sync or async, latency budget, idempotency and ordering, and on failure what the user sees and what persists. Latency evidence sums along these hops; the threat pass and write-path decisions attach to them.

## Topology

*What must keep serving when a zone, region or cell is lost, and where may each tenant's data live, failover included?*

| Topology | Choose when | Pays | Fails as |
|---|---|---|---|
| Single region, multi-zone | Default: the availability target and residency fit one region | Region loss means restore elsewhere | One single-zone dependency undoes it |
| Cells (independent stamps per partition of tenants) | Residency or latency pins tenants, or a blast-radius target caps how many share one failure | A thin global control plane; a fixed cost per cell | The router or directory becomes shared fate |
| Active-passive | The RTO cannot absorb a restore, and each data set can have one writing region | Standby capacity; RPO is replication lag | Failover never exercised; the standby lacks capacity, keys or quota |
| Active-active | Writes must be accepted near users in several regions | A home region or merge policy per data set; spare capacity everywhere | Conflicts on a data set nobody gave a home |

- **Availability arithmetic.** Serial dependencies multiply (three 99.9% hops ≈ 99.7%). Redundancy helps only with independent failures and exercised failover; anything shared (deploy pipeline, config push, identity, DNS) counts once, in series.
- **Static stability.** Survivors absorb a lost unit without new provisioning, so n units run at no more than (n − 1)/n of capacity, and the data plane serves from last-known-good state while the control plane is impaired.
- **Failover targets** satisfy residency and hold what recovery needs: keys, identity, secrets, quotas.
- **Class L.** Split tiers by scaling profile (stateful connections, aggregation, stateless requests, async work), size each from per-unit capacity × peak × headroom, pre-provision scheduled peaks, and gate launch on an open-loop load test at or above peak.
- **Guard**: a scheduled game day that loses one unit and measures RTO and RPO.

## Tenancy

Decide isolation per tenant tier and per shared resource (database, cache, search index, object storage, queues, compute, keys, telemetry, AI state), not once for "the database". The model is a one-way door.

- **Pooled** (a tenant id on every record) is the default for many small tenants; **siloed** where contracts, regulation, per-tenant keys or noisy neighbors demand it; hybrids are normal. Each silo adds a fixed cost floor.
- **Two enforcement points**: a data-access path that cannot run without tenant context, plus a store-level guard. A row policy alone is not isolation: privileged roles bypass it, and pooled connections must reset tenant context.
- **The tenant id travels everywhere the data goes**: cache keys, search documents, object paths, job payloads, log lines, exports.
- **Noisy neighbors**: per-tenant quotas and fair scheduling, plus a path to move a heavy tenant to a silo.
- **Lifecycle designed up front**: per-tenant export, verified deletion across every copy, relocation, single-tenant restore.
- **Guard**: cross-tenant tests in CI through every shared resource, plus a runtime mismatch detector.

## Real-time

Server push over one-way streaming covers most needs; a bidirectional socket only when the client sends frequently. Long-lived connections are stateful: plan heartbeats, draining on deploy, a per-instance connection cap, reconnect with jittered backoff, and replay from a cursor that follows commit order. Classify each message type by delivery guarantee and staleness tolerance; coalesce high-frequency state onto a tick. Fan-out (connections × messages/s × recipients) and the join ramp are binding load units. Guard: a reconnect-storm test under load.

## Safety

When software can harm people or property: each hazard names its safe state. The safety function is the simplest verifiable component, independent of network, cloud, general-purpose runtimes and any model. No update, security control or expired credential may disable it. Its deadline is a worst-case bound, not a percentile, and its guards are fault-injection tests. Ask the caller for the domain standard and involve a specialist.
