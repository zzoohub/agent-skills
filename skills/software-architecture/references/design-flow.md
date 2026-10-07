# Architecture Design Flow

Stages 1–9 of Build Mode (Stage 0: SKILL.md). Each stage opens with its output and forcing question; outputs live under the docs root (default `docs/arch/`; caller may redirect).

- Stages 2 ↔ 3 ↔ 4 co-evolve; one iteration usually suffices — move on once the ATAM gate passes.
- **ADRs are written immediately when a decision occurs, not batched at the end.**
- **Existing system:** / **Software others run:** clauses mark where a stage differs.
- **AI present** → apply the Build-mode hooks in `ai/protocol.md` at each stage.

## As-is Recovery (existing systems)

Runs first when code exists without docs, or when docs fail a drift check; scope it per `evolution.md`.
Recover from evidence, not the PRD: C4 L1/L2, stores and their writers, integrations, a measured envelope, hotspots and violations of Stage 8's rules, each claim tagged *observed* or *inferred*.
Method, where the as-is is written and retroactive ADRs → `evolution.md`.

## Stage 1 — Problem Definition

Writes `context.md` §1–2, §5–6. *What problem, for whom, why now — and how big?*

1. **Validate the PRD**: Does it describe problems or solutions? If solutions, push back to the underlying problem.
2. **Core behaviors** as verbs; **quantified success** (every goal a number: "fast" → "p99 < 500 ms"); the **boundary** — does, does not, external systems.
3. **Stakeholders** — operators/on-call, support, security/compliance, finance, integrators: one line each with their top concern; guesses become §6 assumptions.


### Quantitative Envelope

Size the problem **before any pattern talk** — architecture choices are legitimate only relative to these numbers (§2):
- **Load** per source (users, API/machine clients, devices, feeds, schedules): count × rate × peak factor (default ×5–10 consumer, ×2–3 B2B working hours) → peak in the **binding unit** — requests/s (read vs write), connections, messages/s with fan-out, egress bytes/s or jobs/s.
- **Burst shape** (ramp vs scale-out lead time; scheduled steps; reconnect and backlog-drain bursts) and the **hottest partition's** share.
- **Data** growth, working set, largest payload; **quotas** in each provider's units, with headroom at peak.
- **Unit cost**: where usage is priced, the *successful* task at the p95/p99 user (*break when* a trivial-spend prototype sits behind a hard cap — measure a week of traffic).

**One-box check**: prove one well-built process can't do it before distributing (*break when* availability, durability, isolation or geo-latency demand distribution anyway). Anchor the classes to the measured capacity of one node of the expected store or runtime (published sizing or a short spike); record anchor and source.

| Class | Envelope vs one node's measured capacity | Legitimate default |
|---|---|---|
| **S** | ≥ ~10× headroom | One deployable, one primary store; distributed patterns are illegitimate for load |
| **M** | Fits one primary in one region with headroom | Single region; replicas, cache, async offload as the envelope or an availability driver needs |
| **L** | Beyond one primary's write capacity or one region's | Distributed patterns earn their complexity; size tiers and cells at peak (`system-architecture.md` § Deployment Topology) |

Crude is fine — a ×3 error changes nothing, a ×100 error changes everything. State the inputs so the arithmetic is checkable.

**Placement constraints** (residency, sovereignty, on-prem sites, edge, devices, offline clients) sit beside the class, never in it: they force topology (Stage 7), not distributed internals. **Software others run:** the envelope is input size (typical, worst), start + process latency, memory ceiling and platform matrix — no class, no ladder. **Existing system:** measure from telemetry, including each [H,H] path's per-hop latency.

## Stage 2 — ASR Extraction & Utility Tree

Writes `context.md` §3. *Which quality attributes force structural decisions?*

A requirement is architecturally significant (an ASR) when it passes any filter:

1. Business risk (payment correctness)
2. Unusual quality level
3. External dependency uncertainty (a metered or retiring provider)
4. Cross-cutting (authentication, audit)
5. No precedent for this team
6. Past failure in similar systems
7. Regulatory — an obligation mandates an approach; name its control and evidence source (`security-privacy.md`)
8. Threat- or privacy-derived — a first STRIDE/LINDDUN pass over the context diagram's boundary crossings (tenant isolation under a compromised service token)
9. Hazard-derived *(cond.)* — a control action missing, unsafe, mistimed, or stopped too soon/applied too long (a press cycling after its safety link drops)

### Perspectives

One list, three uses: it seeds the utility tree, sets each stage's pass, and is the Self-Review / Review rubric via Perspective Coverage. ISO/IEC 25010 is the completeness check for anything it misses.

- **Rigor sets document footprint only: Lite | Full.** **Full** when you operate the system and availability, money, regulated data, tenancy, safety or scale class M/L is at stake; otherwise **Lite**, however many perspectives are deep. Lite keeps every numbered § heading in both docs (downstream skills read them) — an inapplicable § is one line, `n/a — reason`; it writes only what a deep perspective or a one-way door needs, keeps the utility-tree leaves that change a decision, and fits both docs in about 2,000 words, plus Open Questions and an ADR per one-way door — related doors on one surface share one.
- **Depth is per perspective**: **deep** only when its own trigger fires (a utility-tree scenario with a standing guard, plus an ATAM row when it rates [H,H]); otherwise **light** (one line in its template section) or **skipped** with a reason. Conditional rows skip silently when absent.
- An **unknown trigger input** counts as present for its perspective and becomes an `A-nn` to confirm; never ask only to set rigor. Security, privacy, data loss and compliance get no phase discount — prototypes usually ship.
- **Record** Perspective Coverage in `system.md` §5, one line per depth: deep (with QA ids), light, skipped (with reasons).

| Perspective | Forcing question | Deep when |
|---|---|---|
| Performance & scale | What load must hold at what latency, and what breaks first? | class M/L; a latency driver |
| Availability & resilience | When a dependency is slow, not just down, what happens, and does the system self-recover? | contractual availability; money paths; class L |
| Security | Which trust boundaries does each key scenario cross, and who can act as whom? | external exposure; multi-tenant; money; AI with tools |
| Privacy & compliance | Where is every copy of personal or regulated data, and how is each retained, exported, erased? | sensitive or sector-regulated personal data; residency (ordinary personal data → light) |
| Data integrity & lifecycle | Who is each data set's single writer, and which invariants span rows or services? | money, stock, multi-step or offline writes |
| Tenancy & isolation *(cond.)* | What isolates tenants at each resource, enforced in at least two places? | sensitive data or contractual isolation |
| Interoperability & contracts | What do others depend on, and how does it evolve without breaking them? | external consumers; public API/SDK; shipped software |
| Operability & observability | Who knows it is broken, and what can they do at 3 a.m. — via a designed, audited path, not ad-hoc writes? | an operated runtime with an availability driver |
| Delivery & change safety | How does a change reach users and get undone, and which config changes are releases? | shipped software; device fleets; frequent releases |
| Evolvability | Which likely changes touch how many modules? | long lifespan; core domain |
| Cost & unit economics | What does a unit of value cost at baseline, growth, the tail user and idle? | usage-priced inputs; thin margins; class L |
| Socio-technical fit | Who owns each context and deployable, and can owners change, test and deploy without coordinating? | more than one team, or team growth |
| User reach | Which devices, networks, locales and abilities must work, offline and slow links included? | consumer, mobile or global; accessibility duties |
| Safety *(cond.)* | Which hazards can the software cause or fail to prevent, and what is each safe state? | software can harm people or property |
| AI *(cond.)* | Which decisions does a model own, under what authority, eval gate and envelope? | tools, actions or autonomy; untrusted input or personal data in context; consequential decisions about people; generation at volume |

### Utility Tree

```
System Utility
+-- Performance
    +-- QA-01 [H,H] When 500 concurrent users search at peak, results return in < 1 s p99
```

Rate leaves **[Importance, Difficulty]** (H/M/L); each carries a `QA-nn` id, its filter tag and the goal or concern it serves. **[H,H] items are architecture drivers** — each gets an ATAM row (Stage 4); every [H,·] leaf gets a standing guard (Stage 8).

**Write each [H,H] leaf as a full quality-attribute scenario** (Bass/Clements/Kazman six-part, compressed to one sentence): *"When {stimulus} from {source} during {environment}, the {artifact} shall {response}, measured as {response measure}."* One-line shorthand stays fine for [M,·] and [L,·] leaves.

Add 3–5 **change scenarios** ("When {likely change}, at most {N} modules change", scored with the E[cost] reasoning in `service-architecture.md`) and one failure scenario. Rank the top 3–4 attributes and name their conflicts; each ADR names what it optimizes and what it trades away.

## Stage 3 — Domain Model

Writes `context.md` §4. *Which concepts and boundaries exist, and who owns each?*

Depth follows the drivers: mostly non-functional drivers need only contexts, classification, owners and glossary. Event-storm only where behavior drives the design or a context is redesigned (events → aggregates → commands → external triggers); hotspots become `A-nn` or Open Questions. Aggregate rules → `service-architecture.md`.

**Bounded contexts**: same term, different rules = different context; modules that always change together are one. Label context-map edges with relationship and sync/async (`service-architecture.md` § Strategic Context Mapping). Each context lists the **volatile decisions it hides**, one module each (*break when* a pipeline's stable stages are the unit of ownership).

### Subdomain Classification & Build-vs-Buy

Classify subdomains (Evans/Vernon strategic DDD), then map contexts onto them — this is the budget allocator for everything downstream.

| Type | Definition | Strategy |
|---|---|---|
| **Core** | Differentiates the product — why users pay | Build and invest: hexagonal rigor, deepest tests, evolution headroom |
| **Supporting** | Specific, not differentiating | Build thin: simplest structure that works (plain CRUD is fine) |
| **Generic** | Solved industry-wide | Decide by what the vendor actually sells, total cost of ownership (build + run + change + exit) and your operating model; a house profile may set a default posture |

What the vendor actually sells decides; for just code, total cost of ownership at your build capacity decides:

| Vendor actually sells | Examples | Verdict |
|---|---|---|
| **Liability transfer** | card-data scope, identity checks, tax, certified components | **Buy** — you can't write your way out of an audit |
| **An earned asset** | email deliverability, SMS routes, fraud signals | **Buy** — the value is accumulated reputation, not the API |
| **Someone else's pager** | 24/7 on-call, heavy infrastructure | **Buy unless you staff a rotation for it** — code is written once; incidents still need a responder |
| **Spec conformance under attack** | cryptography, OAuth/OIDC, sessions | An audited library you host, or the identity platform the organization already runs — never hand-rolled; per-tenant federation is a one-way door (ADR) |
| **Just code** | uploads, own-data search, flags, queues, admin CRUD | **Build, adopt or buy by TCO** — building avoids per-seat cost and API drift; you staff its upkeep |

Still true against build: you own every CVE you wrote, and running cost ≠ writing cost (a self-hosted search cluster can outbill the SaaS it replaced). Weigh those, not line count. Against buy: price the vendor at the Stage 1 peak. One-way-door sourcing gets an ADR in either direction.

The most expensive architecture mistake is not a bad pattern — it's spending core-domain rigor on a generic subdomain, or core-domain *negligence* on the actual differentiator. Record the classification in `context.md` §4; Stage 5 varies internal rigor per type.

**Ownership**: name each context's owning team (or "one team" — skip the rest). Check cognitive load: one owner per context, no owner overloaded, the commonest change within one owner. When teams will grow, align boundaries to the intended teams (inverse Conway); a boundary recorded here is Stage 4 escalation evidence.

**Ubiquitous language**: code terms match PRD terms 1:1 within each context's glossary. **Existing system:** contexts come from the as-is (schema access clusters, co-change, call graph); the glossary adds a legacy → target alias column.

## Stage 4 — Pattern Selection & ATAM Gate

Writes `system.md` §1 + ADRs. *Which decisions make each driver's measure true, at what price?*

**Default for operated services: a modular monolith**, module boundaries and single-writer data ownership enforced by a fitness function (*break when* a named driver — team cadence, runtime or scaling profile, fault isolation, compliance boundary — outweighs shared transactions and coupled workflow). **Software others run:** a library core with a thin shell (the public API is the port), pipes and filters, or a plug-in core. Catalog → `system-architecture.md`.

Escalate only when:
- **CQRS** — read and write models differ in shape or consistency, or must scale independently on measured evidence; never a read/write ratio alone (index → cache → replica → materialized view first).
- **Event sourcing** — history is a domain requirement (temporal queries, reconstruction); an append-only audit log covers plain audit.
- **Event-driven** — boundaries are naturally asynchronous and eventual consistency is acceptable.

**Escalations must cite evidence**: a Stage 1 envelope number, or a non-scale driver with named evidence (a context whose required characteristics differ; an actual team boundary). A class-S envelope plus growth hopes does not justify a distributed pattern — record the trigger that *would* justify it in the Scaling Ladder (Stage 7) instead.

**Safety**: per hazard-derived driver, name the safe state. The safety function stays independent of network, cloud, general-purpose runtimes and any model, and is the simplest verifiable component; no update, security control or credential expiry may disable it; its deadline is a worst-case bound, not a percentile; its guards are fault-injection or hardware-in-the-loop tests. Ask the caller for the domain standard; involve a specialist.

**AI**: when AI is core or takes consequential actions, run `ai/protocol.md` steps 1–5 — task and the decisions the model owns, shape, autonomy & authority, context, tools — inside Stages 2–4; Stages 5–6 then design the components and data they imply.

### ATAM Gate

One `system.md` §1 row per [H,H] driver; the table is the solution strategy:
1. **Decisions / tactics** — the ADRs that move the response measure; a system pattern alone is no answer.
2. **Sensitivity / trade-off point** — the parameter the response is most sensitive to, with its setting; if it pulls another attribute the other way, name both and justify it.
3. **Evidence** — analysis shown, measurement, spike, or precedent whose conditions match; anything else is an assumption.
4. **Risk / non-risk** — "non-risk because …; breaks if …", or a risk (condition → consequence) in the Risk Register with its QA id.

**Do NOT proceed to Stage 5 without passing this gate.** No satisfactory answer? Revisit the rating or try a hybrid. If the blocker is an unverified assumption (vendor latency, model quality, throughput ceiling), specify a time-boxed **spike** with a numeric pass/fail criterion as the first implementation task and record the assumption in `context.md` §6. If still unsatisfied, document the best-effort pattern and its gaps in `system.md` §1 and add a high-impact risk to the Risk Register.

## Stage 5 — Component Design

Writes `system.md` §2. *What are the components, what does each hide, and what do others bind to?*

### Technology Baseline & Selection

Resolve the baseline in order; record it in `context.md` §5:
1. **Explicit constraints** from the caller or organization (mandated platforms, approved stacks, team skills). On an existing system the incumbent covers everything not mandated; a mandate beats the incumbent. A library's language follows its consumers' ecosystem.
2. **The house profile, if this project adopts one** (default `references/house-stack.md`; the project conventions or the caller say so; caller may redirect or omit), after checking it fits the target environment (on-prem or air-gapped, devices, residency, licensing); copy its context fields (operators, residency, cost and sourcing posture, extra criteria) into §5.
3. **Otherwise select per ASR**: compare ≥ 2 candidates on driver fit (cite the scenario), maturity and support horizon, operability (who runs, patches, is paged), cost at the envelope, and exit cost.

A choice that rests on a vendor fact — regional availability, data terms, quota, price, feature support — cites a current primary source and its date, or becomes an `A-nn` with a spike.

A baseline choice needs only its Core Technology row. Anything else needs a **deviation ADR**: the capability gap or binding constraint (end-of-support, licensing, residency, a measured bottleneck, a mandate), specific, not preference; the cost of deviating (runtime, operational burden, billing surface, operator, what it replaces by when); a revisit condition; extra criteria the profile declares. Deviation is fine when justified. Unjustified deviation is tech debt. A pre-GA dependency on a production-critical path names its GA fallback in an ADR. With no baseline, every one-way-door technology choice gets an ADR.

**Boring by default** — novelty only in the core (*break when* the novelty is the differentiator or the boring option fails a hard numeric requirement). **Lock-in is a priced option**: buy a seam only where P(switch) × switching cost exceeds its premium, aimed at a named exit (*break when* switching is genuinely likely).

**Internal structure** follows subdomain *and* risk: core contexts get a dependency-inverted (hexagonal) domain; supporting and generic ones built in-repo, the simplest structure that works; bought ones, a driven adapter (plus an anti-corruption layer if its model leaks). Verification follows risk: sensitive data, tenant isolation, money or irreversible effects earn full invariant tests and a guard in any context. A port must hide a volatile decision (*break when* it is an anti-corruption layer, a trust boundary or a priced option). Generalize from two real consumers (*break when* divergence causes correctness or security bugs). Declare each context's style in `system.md` §1 (`service-architecture.md`).

### Published Contracts

Inventory every surface others bind to — HTTP/RPC APIs, events, files and formats, CLI flags, exit codes and output, library API, config, webhooks, tool-protocol servers and agent-facing tool interfaces (one more driving adapter, with its own authorization, limits and audit). Per surface: consumers (inventoried on an existing system and kept stable through migration); compatibility policy — additive by default, versioning, deprecation window (`system-architecture.md` § API Versioning Strategy); error contract — RFC 9457 for HTTP or an equivalent machine-readable shape — and cursor pagination (`operational-patterns.md` § Pagination Strategy); a CI guard (schema diff or consumer contract test). Anything consumers can observe hardens into a one-way door — keep that surface small. At Full rigor, draw the container view (C4 L2) with trust boundaries.

## Stage 6 — Data Architecture

Writes `system.md` §3. *Who writes each data set, where do its copies live, how consistent is each operation, and how does it die?*

Choose stores by access pattern (point lookup, range scan, aggregate, text or similarity search, blob), volume and consistency need — a type, not a product. Per store: what it holds, why, **consistency per operation**, and **replication & read path** — topology (single-leader / multi-leader / leaderless) with the read anomaly it admits, and the PACELC trade-off ("on a partition choose A or C; else trade latency vs. consistency as X"). A one-word "eventual" hides the real choices.

### Data Inventory & Lifecycle

One row per data set: **single writer**; **class** (public / internal / personal / sensitive or sector-regulated / secret — duties per class in `security-privacy.md`); **every copy** — replicas, backups, logs, traces, analytics, caches, indexes and embeddings, exports, processors, non-production environments (masked or synthetic only for personal or regulated data); **retention and erasure**, backups included; **residency**; **consumers** and the read boundary they use (a replica or stated contract, not the write model). Streamed data adds event-time semantics (late, out-of-order). A processor must be eligible for the class (agreements, region). Conflicting obligations (retention mandate vs erasure right) get an ADR; erasure mechanisms and guards → `security-privacy.md`.

**Derived data inherits its source's boundary and deletion** — lineage on every summary, embedding and cached answer; retrieval with the requester's permissions (*break when* the corpus is public). **Multi-tenant** → `system-architecture.md` § Multi-Tenancy.

**Partitioning** is decided here when the key sets a throughput ceiling, ordering, a hot spot, the retention mechanism or a tenant/residency boundary: name the key per scaling dimension, hot-partition handling and rebalancing; physical layout → a database-design capability, if available. **Migrations** are versioned; no manual schema changes in production.

**Durability & recovery**: for each store holding the only copy of anything, set **RPO** and **RTO**, choose the backup mechanism that meets them, keep one immutable copy outside the production credential domain, and set a restore-test cadence. An untested backup is a hypothesis, not a backup — and data loss is the one failure you cannot roll forward from.

**Caching is a correctness and confidentiality decision**: name what is cached, its staleness bound, invalidation and who shares it — keys carry the tenant; personalized output never reaches a cache shared across principals, and action-triggering output gets no response cache (*break when* answers come from a closed, pre-approved set). Mechanics → `operational-patterns.md`.

### Key Scenarios

Walk 2–3 critical scenarios (the main journey; each [H,H] scenario sensitive to order or timing) as hops: sync/async · latency budget · idempotency and ordering · on failure (what the user sees, what persists, which key or outbox protects it). ATAM latency evidence sums along them; the STRIDE pass and write-path decisions attach to them.

## Stage 7 — Deployment

Writes `system.md` §4. *Where does each part run, how is a change shipped and undone, and what does it cost?*

### Deployment View & Topology

Place each function at the lowest tier (device, site, client, region, cloud) that meets its deadline during a partition, its safety independence, data gravity and residency, and update cost; the cloud is never inside a safety or hard-deadline loop. Per unit: where it runs, failure domain, trust zone, scaling (fixed, autoscaled or scale-to-zero; cold start). Each partition-prone link states its contract: disconnect behavior (buffer / degrade / act locally / refuse), buffer bound and overflow, command expiry, ordering and dedup keys, jittered drain. Topology and availability arithmetic → `system-architecture.md` § Deployment Topology. Each tier's recovery posture meets the Stage 6 RPO/RTO; failover targets satisfy residency and hold the keys, secrets, identity and config recovery needs; a drill is the evidence.

### Release Model

**Who controls the runtime** decides it, per deployable:
- **Operated** — no manual execution steps, everything reproducible; approval gates where the operating context requires them. Roll out (rolling, blue-green, canary) by isolation unit — tenant ring, cell, region — when one exists, never into a scheduled peak; release ≠ deploy (`system-architecture.md` § Feature Flag Architecture); an SLO condition triggers rollback or forward-fix. Schema changes ship expand-contract: this stage decides the strategy and records the ADR; lock-safe execution belongs to a database-design capability, if available.
- **Shipped** (apps, CLIs, libraries, on-prem installs) — versioning and channels, support window, the version-skew window a backend must serve (checked in CI), a recall path. A shipped release cannot be rolled back: each public release is a one-way door.
- **Fleet** (devices) — staged rings with halt criteria, atomic update with fallback to last-known-good, signing, operator-agreed windows, a kill switch.

Build and release are a trust boundary (provenance, signing, dependency admission → `security-privacy.md`). **Behavior-changing config is a release** — flags, defaults, prompts, model settings (*break when* the change cannot reach runtime behavior).

### Transition Plan

Existing system changing beyond one decision: ordered, reversible steps, each with a coexistence seam, data-migration mechanics, the level each [H,H] driver holds, an exit fitness function and a rollback trigger (method → `evolution.md`). Finish what you start — block new use of the old path, then turn it off (*break when* a frozen, cheap old path keeps a dated sunset).

### Scaling Ladder

Name **what breaks first** as load grows — so growth becomes an execution problem, not a redesign. Per step (10x, 100x): first bottleneck, trigger metric, planned response; the 100x row may honestly say "redesign, and that's fine". Two rules: the **trigger is a metric that already exists on a Stage 8 dashboard** for what you operate (a ladder nobody watches is fiction), and every planned response is a two-way door or pre-recorded as an ADR. Deferred Stage 4 escalations land here. Design for ~10x; plan the rewrite before ~100x; at class L, size cells from a blast-radius target.

### Cost & Unit Economics

Model the **fixed floor** (zero-traffic cost per environment, region or cell), the **variable cost per binding demand unit** (request, user, tenant tier, job, GB of egress) and **cost at provisioned peak**, at baseline and growth, against a target unit cost (none given → Open Question), including per-unit fees and the Stage 1 tail user. Flag anything that costs money or energy while idle. A cost driver gets a guard: a spend-burn alert on all spend, attributed by tenant or feature.

## Stage 8 — Cross-cutting Concerns

Writes `system.md` §5. *What must hold everywhere, and what keeps it true after this document?*

### Fitness Functions

Derive guards from this design's drivers and ADRs, keyed by QA id: property → check and threshold → cadence (per commit, per deploy, continual, scheduled) — CI checks, SLO alerts, evidence monitors, scheduled drills (restore, failover, load). Evals are the AI fitness functions. The check matters, not the tool — the house profile or the implementation guide names tools. A guard must be shown to fail when its property breaks.

**Coverage rule**: every [H,·] scenario gets a *standing guard*, whatever its difficulty — difficulty decides where the ATAM gate spends analysis; importance decides what must not erode. Record the ASR → guard mapping in `system.md` §5; an unguarded driver goes to the Risk Register.

### Observability & SLOs

**SLOs derive from ASRs and carry error budgets.** Each availability or latency ASR becomes an **SLI** → an **SLO target** (the ASR's number) → an **error budget** (1 − target; 99.5% ⇒ 3.6 h per 30 days). Alert on **burn rate** — page on fast burn, ticket on slow burn, not on raw threshold blips (window pairs → `observability.md`) — and on symptoms users feel, not causes: RED/USE signals feed dashboards and tickets, not pages (the time-to-exhaustion exception: `observability.md`). The budget doubles as a release governor: budget exhausted ⇒ reliability work preempts features. Each SLO has an owner and a runbook. Error budgets never cover correctness invariants, security or data loss — an invariant violation is an incident; a probabilistic component's tolerated error per failure class is a legitimate quality SLO. Record SLOs and the Observability Contract in `system.md` §5. **Software others run:** data on stdout, diagnostics on stderr, stable exit codes; telemetry opt-in.

### Reliability

Per command and consumer whose writes must not be lost, duplicated or interleaved, fill `system.md` §5 Write-path Integrity: transaction boundary; outbox when a state change pairs with a publish or external call; idempotency checked where the effect commits — broker or transport guarantees are not the mechanism; concurrency control including write skew and multi-row invariants; a merge policy for offline writers. Method → `reliability-patterns.md`.

### Security

Surface the requirement first: a lightweight **STRIDE** pass over every trust-boundary-crossing flow — trust zones, Key Scenarios, the build/release path — repeating Stage 2's first pass, plus **LINDDUN-lite** where personal data flows; model-mediated flows are trust flows (`ai/security.md`). Promote material findings to Stage 2 as security ASRs (filter #8; materiality and recording → `security-privacy.md`); every boundary ends with a control, an ASR or an accepted risk. Saltzer–Schroeder (fail-safe defaults, least privilege, complete mediation) is the generative lens any checklist only echoes. Threat summary, principals, keys, supply chain, compliance evidence and audit trail → `security-privacy.md`; hand the per-diff vulnerability list to a security-review capability (e.g. the `review-checklists` skill's security pass, if available) — don't inline it here.

### Resilience & Overload

For each hard dependency and failure domain you operate (store, queue, zone or region, a bad deploy), fill the dependency protection contract (mechanics → `operational-patterns.md`). Deadlines propagate top-down, never summed bottom-up; timeouts follow an acceptable false-timeout rate. **Retry in one layer, on a budget, by error class**, idempotent operations only (*break when* many independent clients retry — then admission control matters more). **Protect goodput**: admission control, a stated shedding order, bounded queues, bulkheads, breakers with care, backpressure, a client reconnect contract; per-client rate limits give fairness, not an aggregate bound (*break when* durable acceptance is required — buffer and process later). **Static stability over fallback**: a fallback is unqualified until exercised (*break when* pre-provisioning outprices the path). **Size for the bad mode** — cold caches, backlogs, retry storms (*break when* running far below capacity). When Availability is deep, add Detection and Blast-radius columns and a DR posture per tier (`operational-patterns.md`). Check against these incident patterns (defined in `review-lens.md`): N+1 queries, thundering herd, distributed monolith, retry storm, cold-start cascade, reconnect storm, hot partition, metastable failure.

## Stage 9 — ADR & Risk Review

Writes `adr/`, `risks.md`. *Is every one-way door recorded with its price, and what could still go wrong?*

**Driver verification**: before the pass closes, every driver — including ones promoted later by the threat or privacy pass, durability or cost — has an ATAM row with evidence, an ADR citing it in `Drivers`, and a guard. Fields → `templates/adr.md`; an ADR records the decision, not the design — link the detail instead of restating it. No recommendation without its price and flip condition: `Tradeoff` states the cost, `Revisit when` a variable and threshold, `Confirmation` the guard (*break when* the force is law, physics or a signed SLA — record a constraint, not a trade-off).

**ADR numbering is a shared namespace.** A standalone-ADR capability (e.g. the `arch-decision` skill, if available) appends to the same `adr/` directory: next number = highest existing + 1, from the directory's current max on re-runs — never restart at ADR-001; on a true collision the later writer renumbers. Reversed decisions are superseded: only the old ADR's Status changes, to `Superseded by ADR-NNN`; its body is never edited.

**Door typing**, honestly — one-way: analysis, an ADR, a decision deadline; two-way (including whatever a port hides): decide fast with a revisit trigger.
**One-way doors** (irreversible — analyze carefully): Database choice, primary language, auth architecture, core domain model.
**Two-way doors** (reversible — decide fast): Library choice, caching strategy, log format, CI tool.
Hidden one-way doors: whatever consumers observe (shapes, IDs, defaults, error text, persisted formats) once they depend on it; caching is two-way for performance but one-way for confidentiality — what a cache shares across principals cannot be un-leaked (*break when* one team changes every consumer atomically).

### Minimum ADRs

Record every decision typed `Door: One-way` in Stages 3–8, plus the defining decisions this system actually has; skip what it lacks. **Operated systems:** system pattern, internal structure, primary storage, communication style, deployment & rollback. **Software others run:** language/runtime, published-contract & compatibility policy, distribution & update model. **When applicable:** AI integration approach, autonomy & authority model, provider dependency & exit, regulatory classification (AI features); authentication/authorization (users or other principals); API design philosophy & compatibility policy (external consumers); offline/sync strategy (offline writers); concurrency model (high-throughput or real-time); build-vs-buy (one-way-door sourcing either way; a purchase names what the vendor actually sells); technology deviation from the baseline; tenancy model; topology and regions; retention & erasure; key ownership & hierarchy; safety function; one-way transition steps.

### Risk Register

Each `risks.md` Risk Register row names the QA/C ids it threatens, an owner and a watched signal; seed it from ATAM verdicts and a pre-mortem (assume failure a year after launch; write the likeliest cause per driver and Stage 8 concern). A risk with no watched signal is fiction. One line under the table rolls ATAM risks into themes. AI risks join only when AI exists, rated from this design, never pre-rated.

**Tech Debt**: each accepted shortcut, when taken, priority, resolution condition. **Open Questions**: decisions due before a stage ships — options, information needed, decide-by, blocking or not; each becomes an ADR once decided.
