# Architecture Design Flow

10-stage methodology for software architecture. Stage 0 (Auto-Classification) lives in SKILL.md. This file covers stages 1-9.

Stages 2, 3, and 4 co-evolve — domain modeling reveals new ASRs, pattern selection changes domain boundaries. One iteration is usually sufficient. (This generalizes Nuseibeh's two-peak requirements↔architecture co-evolution: Stage 2 ASRs are the requirements peak, Stages 3-4 the architecture peak.)

ADRs are written immediately when decisions occur, not batched at the end.

---

## Table of Contents
- Stage 1 — Problem Definition
- Stage 2 — ASR Extraction & Utility Tree
- Stage 3 — Domain Model
- Stage 4 — Pattern Selection & ATAM Gate · *(Stages 2↔3↔4 co-evolve)*
- Stage 5 — Component Design
- Stage 6 — Data Architecture
- Stage 7 — Deployment
- Stage 8 — Cross-cutting Concerns
- Stage 9 — ADR & Risk Review

---

## Stage 1 — Problem Definition

**What it answers**: What problem, for whom, why now?

### Process

1. **Validate the PRD**: Does it describe problems or solutions? If solutions, push back to the underlying problem.
2. **Extract core behaviors** as verbs (e.g., "searches", "uploads", "subscribes", "processes", "compiles"). These become the action vocabulary for the domain model.
3. **Quantify success criteria**: Every goal needs a number. "Fast" -> "p99 < 500ms". "Reliable" -> "99.5% uptime". "Lightweight" -> "< 50MB memory".
4. **Identify system boundary**: What this system does / does not do / what external systems it connects to.

### Quantitative Envelope (back-of-envelope)

Size the problem **before any pattern talk** — architecture choices are legitimate only relative to these numbers:

- **Load**: DAU × actions/user/day ÷ 86,400 × peak factor (default ×5-10 consumer, ×2-3 B2B working-hours) → peak RPS, split read vs write.
- **Data**: rows/day × bytes/row → growth/year; working set (data actually queried hot) vs total; largest single payload.
- **Anchors** (orders of magnitude, not benchmarks): one well-tuned Postgres sustains low-thousands of simple read QPS and hundreds of write QPS before heroics; 1M rows × 1KB ≈ 1GB; a single region carries most products to ~low-millions DAU.

Classify the **scale class** and record it with the envelope in `context.md` §2:

| Class | Envelope (any of) | Legitimate default |
|---|---|---|
| **S** | < ~100 peak RPS, < 10 GB working set | Single node + managed Postgres; distributed patterns are illegitimate |
| **M** | < ~2K peak RPS, < 500 GB working set | Single region; replicas + cache; async offload where flows demand it |
| **L** | Beyond M, or multi-region data residency | Distributed patterns now earn their complexity |

Crude is fine — a ×3 error changes nothing, a ×100 error changes everything. State the inputs so the arithmetic is checkable. Stage 4 holds every pattern escalation against this class; Stage 7 prices the same numbers.

### Output

Write to `docs/arch/context.md` §1 (Problem), §2 (System Boundary + Scale Envelope), §5 (Constraints), and §6 (Assumptions). The constraint/assumption inputs come from Stage 0 auto-classification (scale, latency, deployment, regulatory, PRD gaps).

---

## Stage 2 — ASR Extraction & Utility Tree

**What it answers**: Which quality attributes drive the architecture?

Architecturally Significant Requirements (ASRs) are the requirements that shape the system's structure. Most PRD requirements are *not* ASRs — they're features that fit into whatever structure exists. ASRs are the ones that *force* structural decisions.

### ASR Filter Criteria

A requirement is architecturally significant if it matches any of these 8 filters:

| # | Filter | Example |
|---|---|---|
| 1 | Business risk — failure would threaten the product | Payment processing correctness |
| 2 | Unusual quality level — beyond typical expectations | Sub-100ms p99 for real-time features |
| 3 | External dependency uncertainty — vendor may change or fail | LLM API pricing, availability, deprecation |
| 4 | Cross-cutting — affects multiple modules | Authentication, logging, error handling |
| 5 | No precedent — team hasn't built this before | First-time real-time collaboration |
| 6 | Past failure — similar systems have failed here | Data migration from legacy system |
| 7 | Regulatory — compliance mandates specific approaches | GDPR data residency, SOC 2 |
| 8 | Threat-derived — a STRIDE pass over a trust-boundary-crossing flow surfaces a spoof/tamper/disclosure/EoP risk | Tenant isolation under a compromised service token; tampering on the outbox relay |

### Utility Tree

Organize ASRs into a utility tree that makes priorities explicit:

```
System Utility
+-- Performance
|   +-- "API response < 500ms p99" [H, M]
|   +-- "Search results < 1s" [M, H]
+-- Availability
|   +-- "99.5% uptime" [H, L]
+-- Security
|   +-- "No PII in logs" [H, L]
+-- Cost Efficiency
    +-- "< $X/month at target load" [H, M]
```

Each scenario gets an **[Importance, Difficulty]** rating:
- **Importance**: How critical to business success (H/M/L)
- **Difficulty**: How hard to achieve architecturally (H/M/L)

**[H,H] items are architecture drivers** — they demand explicit patterns and trade-off analysis. Every [H,H] scenario must have a corresponding pattern in stage 4.

**Write each [H,H] leaf as a full quality-attribute scenario** (Bass/SEI six-part, compressed to one sentence): *"When {stimulus} from {source} during {environment}, the {artifact} shall {response}, measured as {response measure}."* — e.g. "When 500 concurrent users search during peak load (normal operations), the search path returns results in < 1s p99." One-line shorthand stays fine for [M,·] and [L,·] leaves. The reason: the ATAM gate verifies drivers against their *measure*, and a driver without stimulus, environment, and measure cannot gate anything.

### AI ASR Questions

If the PRD involves AI/LLM features, evaluate these concerns:

| Question | Why It Matters | Drives |
|---|---|---|
| Streaming required? | SSE/WebSocket infrastructure, token-by-token rendering | Transport layer, frontend architecture |
| RAG needed? | Vector store, chunking pipeline, retrieval strategy | Data architecture, infrastructure cost |
| Agent capabilities? | Tool orchestration, durable execution, safety boundaries | System pattern, security model |
| Cost ceiling? | Model selection, caching strategy, batch vs real-time | Every AI component decision |
| Hallucination tolerance? | Guardrail depth, human-in-the-loop, citation requirements | Output validation, UX design |

### Quality Attribute Trade-offs

Quality attributes trade off against each other. Make these explicit:

| Attribute | Measures | Typical Trade-off |
|---|---|---|
| Performance | Latency, throughput | vs. Maintainability (optimization adds complexity) |
| Availability | Uptime, fault tolerance | vs. Cost (redundancy is expensive) |
| Scalability | Load handling, growth capacity | vs. Simplicity (distributed systems are complex) |
| Security | Data protection, access control | vs. Usability (more security = more friction) |
| Maintainability | Changeability, debuggability | vs. Performance (abstractions add overhead) |
| Testability | Ease of verification | vs. Time-to-market (test infrastructure takes effort) |
| Deployability | Release frequency, rollback speed | vs. Stability (more deploys = more risk surface) |
| Cost Efficiency | Infrastructure spend per user | vs. Performance/Availability |

Rank the top 3-4 attributes for this system. Identify conflicts and make explicit trade-offs. Each ADR should reference which quality attributes it optimizes and which it trades away.

### Output

Write to `docs/arch/context.md` §3 (ASR & Utility Tree).

---

## Stage 3 — Domain Model

**What it answers**: What are the core domain concepts and their boundaries?

### Event Storming (Solo)

Extract domain events from the PRD:

1. **Read the PRD and list domain events** as past-tense verbs: "UserRegistered", "OrderPlaced", "PaymentProcessed", "ContentPublished".
2. **Group events by aggregate** — which entity's state changed?
3. **Identify commands** — what action triggered each event?
4. **Mark external triggers** — which events come from outside the system?

### Bounded Context Identification

Same term, different rules = different bounded context.

- "User" in auth context (credentials, sessions) vs. "User" in billing context (subscription, payment method) — different bounded contexts.
- If two modules could evolve independently without breaking each other, they're separate contexts.
- If changing one always requires changing the other, they're the same context.

### Subdomain Classification & Build-vs-Buy

Classify every bounded context (Evans/Vernon strategic DDD) — this is the budget allocator for everything downstream:

| Type | Definition | Strategy |
|---|---|---|
| **Core** | Differentiates the product — why users pay | Build and invest: hexagonal rigor, deepest tests, evolution headroom |
| **Supporting** | Necessary and specific to this product, but not differentiating | Build thin: simplest structure that works (plain CRUD is fine) |
| **Generic** | Solved industry-wide — auth, billing, email, search, analytics | **Build or self-host by default** — agentic dev collapsed the build cost, and generic subdomains are an agent's best-documented territory. Buy only what isn't code (below); each vendor adopted carries an ADR |

**Buy only what you cannot write.** Agentic dev deflated one cost: writing and changing code. A vendor is worth a permanent dependency only when it sells something else:

| Vendor actually sells | Examples | Verdict |
|---|---|---|
| **Liability transfer** | card data (PCI scope), KYC/AML, tax nexus | **Buy** — you can't write your way out of an audit |
| **An earned asset** | email deliverability (IP/DMARC reputation), SMS carrier routes, cross-merchant fraud signals | **Buy** — the value is accumulated reputation, not the API |
| **Someone else's pager** | 24/7 on-call, heavy infra to operate | **Buy** when there's no rotation — an agent writes it once; a human still wakes at 3am |
| **Spec conformance under attack** | crypto, OAuth/OIDC/passkeys, sessions | **Neither** — audited library, self-hosted |
| **Just code** | uploads, search over your own data, feature flags, cron/queues, admin CRUD, internal reporting, notifications, PDF/image | **Build** — no per-seat cost, no API drift, and the agent can read and test the whole path |

Still true against build: you own every CVE you wrote, and running cost ≠ writing cost (a self-hosted search cluster can outbill the SaaS it replaced). Weigh those, not line count.

The most expensive architecture mistake is not a bad pattern — it's spending core-domain rigor on a generic subdomain, or core-domain *negligence* on the actual differentiator. Record the classification in `context.md` §4; Stage 5 varies internal rigor per type.

### Ubiquitous Language Glossary

Code terms must match PRD terms 1:1 **within a bounded context**. No synonyms, no abbreviations that diverge from business language. Across contexts the *same* term may carry different meaning (e.g. "User" in auth vs. billing) — that is correct, not a violation; keep the glossary per-context.

| Term | Definition | Code Mapping |
|---|---|---|
| e.g., Workspace | A shared collaboration space owned by one user | `Workspace` entity, `workspace_id` |
| e.g., Member | A user with access to a workspace | `Member` value object |

Read `references/service-architecture.md` for DDD tactical patterns (entities, value objects, aggregates, domain events).

### Output

Write to `docs/arch/context.md` §4 (Domain Model).

---

## Stage 4 — Pattern Selection & ATAM Gate

**What it answers**: What architectural patterns satisfy the architecture drivers?

### System Pattern Selection

Default: **Modular Monolith** — gives domain separation without deployment overhead.

Escalate when:
- **CQRS**: Read/write ratio > 10:1 or fundamentally different read/write models
- **Event-driven**: Clear async boundaries, eventual consistency acceptable
- **Event sourcing**: Audit trail is a first-class requirement, need to reconstruct past state

**Escalations must cite evidence**: a Stage-1 envelope number (class M/L load, measured ratio) or a non-scale driver (fault isolation, compliance boundary, team boundary). A class-S envelope plus growth hopes does not justify a distributed pattern — record the trigger that *would* justify it in the Scaling Ladder (Stage 7) instead.

Read `references/system-architecture.md` for the full composition flowchart and pattern catalog.
Read `references/service-architecture.md` for internal service structure decision guide.

### AI Pattern Decision Tree

| If PRD requires... | Pattern | Key characteristics |
|---|---|---|
| Simple LLM call with structured output | Direct API | Schema validation, retry logic |
| Knowledge base Q&A | RAG | Chunking pipeline, vector store, retrieval strategy |
| User-facing AI assistant | Copilot | Streaming, conversation history, context window management |
| Multi-step task execution | Agent | Tool orchestration, durable execution, safety boundaries |
| Domain-specific language understanding | Fine-tuning | Training pipeline, evaluation suite, version management |

Real AI systems often combine patterns — a copilot typically needs RAG + streaming + conversation memory. Read `references/ai-architecture.md` for integration tiers and composition, `references/ai-agents.md` for agent-specific patterns.

### ATAM Gate

**Architecture Tradeoff Analysis Method** — simplified.

For every **[H,H] ASR** from stage 2:

1. **Identify the pattern** that addresses it
2. **Document sensitivity points** — where small changes in the pattern cause large effects
3. **Document trade-offs** — what this pattern sacrifices
4. **Verify** the pattern actually satisfies the scenario's measurement criteria

**Do NOT proceed to stage 5 without passing this gate.** Every [H,H] item must have a verified pattern.

If a [H,H] ASR has no satisfactory pattern:
- Revisit the utility tree — is the importance/difficulty rating correct?
- Consider hybrid patterns
- If the blocker is an *unverified assumption* (vendor latency, model quality, throughput ceiling): specify a time-boxed **spike** with a numeric pass/fail criterion as the first implementation task, and record the assumption in `context.md` §6 — don't let the whole design rest on an unmeasured guess
- If still unsatisfied: document the best-effort pattern and its gaps in `docs/arch/system.md` §1, add to the `docs/arch/risks.md` Risk Register as high-impact risk

### Output

Write to `docs/arch/system.md` §1 (Patterns). Write ADRs for pattern decisions as files in `docs/arch/adr/`.

---

## Stages 2 <-> 3 <-> 4 Co-Evolution

These three stages co-evolve iteratively (a generalization of Nuseibeh's two-peak requirements↔architecture model — Stage 2 is the requirements peak, Stages 3-4 the architecture peak):

- **Domain modeling (3) reveals new ASRs (2)**: "We need real-time sync across workspace members" emerges when modeling the collaboration domain.
- **Pattern selection (4) changes domain boundaries (3)**: Choosing CQRS splits a bounded context into read and write sides.
- **ASR refinement (2) constrains patterns (4)**: Tightening a latency requirement eliminates certain patterns.

One iteration through stages 2->3->4->(back to 2 if needed) is usually sufficient. Don't over-iterate — move to stage 5 once the ATAM gate passes.

---

## Stage 5 — Component Design

**What it answers**: What are the concrete components and how do they connect?

### Tech Stack Selection

Choose technologies that fit the ASRs and patterns from stages 2-4. Record each choice with rationale in the "Core Technology" table of `docs/arch/system.md` §2. Default to `references/house-stack.md`; deviating is fine but carries an ADR per that file's deviation contract (capability gap, cost of deviation, revisit condition).

**Match rigor to Stage 3's subdomain classification**: full hexagonal discipline for core contexts; a generic context built in-repo gets the simplest structure that works (rigor here is the classic misallocation); one bought as SaaS gets only a driven adapter (plus an anti-corruption layer if its model leaks — see `service-architecture.md` § Strategic Context Mapping).

### Hexagonal Architecture (Default)

Domain never depends on infrastructure. This is non-negotiable for testability and changeability.

```
[Driving Adapters] -> [Ports] -> [Domain] <- [Ports] <- [Driven Adapters]
   (HTTP, CLI)                                        (DB, APIs, Queue)
```

For each bounded context:
1. **Define ports** (interfaces the domain exposes/requires)
2. **Define adapters** (concrete implementations of ports)
3. **Verify domain independence** — domain module imports nothing from infrastructure

Framework-neutral structure:

```
src/
+-- domain/           # Pure business logic — no imports from outside
|   +-- models/       # Entities, value objects, domain errors
|   +-- services/     # Domain services (orchestrate domain logic)
|   +-- ports/        # Interfaces (driven ports)
+-- application/      # Use cases — orchestrate domain + ports
|   +-- use-cases/
+-- adapters/         # Infrastructure implementations
|   +-- http/         # Driving adapter: HTTP handlers
|   +-- persistence/  # Driven adapter: repositories
|   +-- external/     # Driven adapter: third-party API clients
+-- config/           # Wiring: dependency injection, app bootstrap
```

### Interface Contract

When the system has external consumers, the API *philosophy* is an architectural decision even though the endpoint catalog is not (see SKILL.md Scope Boundaries). Decide and record:

- **Protocol style**: REST (default for product/public APIs) · RPC (internal service-to-service, latency-critical) · GraphQL (only with many heterogeneous clients aggregating varied data) · MCP server (when AI agents are a first-class consumer — see `ai-agents.md` § MCP as Product API)
- **Versioning posture**: additive-only by default (see `system-architecture.md` § API Versioning Strategy)
- **Error contract**: one machine-readable error shape everywhere (RFC 9457 `application/problem+json` or equivalent)
- **Pagination default**: cursor-based (see `operational-patterns.md` § Pagination Strategy)

This becomes the "API design philosophy" ADR from the Stage 9 minimum list.

### AI Components

| Component | Responsibility | Isolation rationale |
|---|---|---|
| LLM Gateway | Model routing, caching, cost tracking, abstraction over providers | Swap providers without touching domain |
| Embedding Pipeline | Chunking, embedding, vector store writes | Heavy I/O, different scaling profile |
| Eval Pipeline | Quality measurement, regression detection | Runs offline, different lifecycle |

### Container Diagram

Produce a C4 Level 2 container diagram in D2 (or Mermaid/ASCII — see SKILL.md Writing Style). Show:
- Runtime containers (services, databases, queues)
- Communication protocols between them
- External system integrations

### Output

Write to `docs/arch/system.md` §2 (Components).

---

## Stage 6 — Data Architecture

**What it answers**: Where does data live, how does it flow, how is consistency maintained?

### Storage Strategy

Choose storage type based on data characteristics, not convention:

| Data Characteristic | Storage Type | Examples |
|---|---|---|
| Structured, relational, ACID needed | Relational DB (PostgreSQL, MySQL) | Core domain data, transactions |
| High-volume key-value access | Key-value store (Redis, DynamoDB) | Sessions, caches, counters |
| Document-oriented, schema-flexible | Document DB (MongoDB, CouchDB) | Content, configurations |
| Time-series, append-heavy | Time-series DB (InfluxDB, TimescaleDB) | Metrics, logs, IoT sensor data |
| Unstructured binary | Object/blob storage (S3, GCS) | Files, media, backups |
| Vector similarity search | Vector store (pgvector, dedicated) | Embeddings, semantic search |
| Graph relationships | Graph DB (Neo4j, DGraph) | Social networks, knowledge graphs |

For each data store, document:
- What it holds
- Why this storage type
- Consistency model (strong, eventual, session)

For each *stateful* store that the scale/latency ASRs make significant, also decide the **distributed-data shape** — a one-word "eventual" hides the real choices:
- **Replication topology**: single-leader / multi-leader / leaderless, and the read anomaly it admits (read-your-writes, monotonic-reads).
- **CAP/PACELC trade-off**, stated per store: "on a partition choose A or C; else trade latency vs. consistency as X." (Canon: Brewer CAP; Abadi PACELC; Kleppmann *Designing Data-Intensive Applications* ch. 5/6/9.)

Partitioning/sharding-key choice and read-replica execution are a *schema* concern — hand them to a database-design capability (e.g. the `database-design` skill, if available); this stage selects only the topology and consistency model.

**Versioned migrations are mandatory** for relational databases — no manual schema changes in production.

**Durability & recovery** — for each store holding the only copy of anything, set **RPO** (max acceptable data loss) and **RTO** (max acceptable restore time), choose the backup mechanism that meets them (PITR vs scheduled snapshots), and set a restore-test cadence. An untested backup is a hypothesis, not a backup — and data loss is the one failure you cannot roll forward from.

### AI Data

| Concern | Guidance |
|---|---|
| Chunking | Semantic chunking with 10-20% overlap. Start at ~400-512 tokens; size up to 512-1024 for long-form. Architecture slice (storage sizing consequences) in `ai-architecture.md` §3; per-document-type sizing is retrieval design — see an LLM-app-design capability (e.g. the `llm-app-design` skill's RAG reference), if available. |
| Search | Hybrid search (dense vectors + BM25 keyword) outperforms either alone. |
| Context window | Budget tokens: system prompt + retrieved context + conversation history + output must fit model limit. Track and alert on overflow. |

Read `references/ai-architecture.md` §3 for RAG, vector storage, and chunking patterns.

### Key Data Flows

Trace 2-3 critical user journeys through the data layer:
- Where data enters
- What transformations happen
- Where it's stored
- Where it's read from

### Output

Write to `docs/arch/system.md` §3 (Data).

---

## Stage 7 — Deployment

**What it answers**: How does code get to production? How much does it cost?

### CI/CD Pipeline

Minimum gates: **test -> lint -> security scan -> build -> smoke test -> deploy**.

No manual deployment steps. Everything in the pipeline is reproducible.

### Deployment Strategy

How a release reaches production is an architectural decision with a deployability-vs-stability trade-off — record it as an ADR:
- **Rollout shape**: rolling / blue-green / canary (progressive %). Default to canary for user-facing services with real traffic; blue-green when you need instant total rollback.
- **Release ≠ deploy**: ship code dark and gate exposure with feature flags (see `system-architecture.md` § Feature Flags) so deploy risk and release risk decouple.
- **Rollback / forward-fix trigger**: the SLO condition that auto-aborts a rollout, and whether recovery is rollback or roll-forward.
- **Schema-during-deploy**: expand-contract ordering so a migration and the code needing it ship safely under live traffic (execution is owned by a migration capability such as the `postgresql` skill, if available).

This stage decides the strategy and records the ADR; the lock-safe **execution** of a release and rollback is a release-engineering concern (e.g. the `release-engineer` agent) — define the boundary, don't do its job here.

### Scaling Ladder

For the chosen architecture, name **what breaks first** as load grows — so growth becomes an execution problem, not a redesign:

| Load | First bottleneck | Trigger metric | Planned response |
|---|---|---|---|
| 10x | e.g. Postgres write IOPS on the events table | p95 write latency > 50ms sustained | Partition events table; move analytics reads to a replica |
| 100x | e.g. single-region origin saturation | ... | One honest sentence is enough — often "redesign, and that's fine" |

Two rules: the **trigger is a metric that already exists on a Stage-8 dashboard** (a ladder nobody watches is fiction), and every planned response is a two-way door or pre-recorded as an ADR. This is also where deferred Stage-4 escalations land — "adopt CQRS when read p99 breaches X" belongs here, not in the current design.

### Cost Estimation

Estimate at two traffic levels relevant to the system:

| Component | Baseline (lower load) | Growth (higher load) |
|---|---|---|
| Compute | ... | ... |
| Database | ... | ... |
| Storage | ... | ... |
| Third-party APIs | ... | ... |
| **Total** | ... | ... |

Flag anything that costs money while idle.

### AI Ops

- **Model version date-pinning**: Never use "latest" — pin to specific model version dates
- **Cost alerting**: Alert at 80% of the cost ceiling from stage 2 ASRs
- **Fallback models**: Define cheaper fallback when primary model is unavailable or over budget

### Output

Write to `docs/arch/system.md` §4 (Deployment & Cost).

---

## Stage 8 — Cross-cutting Concerns

**What it answers**: What properties must hold across all components?

### Fitness Functions

3-5 automated CI checks that enforce architectural properties:

| Property | Check | Example |
|---|---|---|
| No circular dependencies | Import graph analysis | TS: `madge --circular` · Rust: `cargo-modules` / `cargo-depgraph` · Python: `pydeps --show-cycles` |
| Domain independence | Import rules | TS: `eslint-plugin-boundaries` · Rust: workspace crate boundaries (domain crate has no infra deps in `Cargo.toml`) · Python: `import-linter` contracts |
| Response time | Performance test | k6 / autocannon / wrk smoke test with p99 threshold from ASR |
| Bundle size | Build output analysis | Frontend: `size-limit`, `bundlesize` · Rust WASM: binary size threshold |
| Dependency drift | Lock file audit | Renovate/Dependabot policies, `cargo-deny`, `pip-audit`, `bun audit` |

Pick tools that fit the language of each module. The check matters; the specific tool is interchangeable.

These are the immune system of your architecture — they prevent silent erosion of design decisions. Run in CI on every commit.

**Coverage rule**: every [H,H] ASR gets a *standing guard* — a CI fitness function (structural properties) or a runtime SLO alert (behavioral properties). The ATAM gate verified the design once, at design time; guards keep it true under every commit and every deploy. Record the ASR → guard mapping in `system.md` §5; an unguarded driver goes to the Risk Register.

### Observability

**RED method** for every service:
- **R**ate: Requests per second
- **E**rrors: Errors per second
- **D**uration: Latency distribution (p50, p95, p99)

**USE method** for every resource:
- **U**tilization: How busy is the resource?
- **S**aturation: How much queued work?
- **E**rrors: How many errors?

**SLO-based alerting** — alert on SLO violations, not symptoms:
- "Error rate > 1% over 5 minutes" (availability SLO)
- "p99 latency > 500ms over 10 minutes" (latency SLO)
- "Successful login rate < 95% over 15 minutes" (business SLO)

**SLOs derive from ASRs and carry error budgets** (canon: Google SRE). Each availability/latency ASR becomes: an **SLI** (what you measure) → an **SLO target** (the ASR's number) → an **error budget** (1 − target; 99.5% ⇒ 3.6h/month). Alert on **burn rate** — how fast the budget is being consumed — with a fast window that pages and a slow window that tickets, not on raw threshold blips. The budget doubles as a release governor: budget exhausted ⇒ reliability work preempts features. Record the SLO table in `system.md` §5.

Day 1 priorities: error tracking, structured logging (JSON to stdout), health checks, uptime monitoring.

Read `references/observability.md` for OpenTelemetry strategy, sampling, cardinality budgets, and signal correlation.

### Reliability

For any system with writes that must not be lost, duplicated, or interleaved incorrectly, decide upfront:

- **Transaction boundary**: Where does each command's transaction begin and end? (Default: application service.)
- **Dual-write hazards**: If a state change must be paired with a broker publish or external call, specify the **outbox pattern**.
- **Idempotency**: Which endpoints accept `Idempotency-Key`? Which async consumers dedupe by `event.id`?
- **Concurrency control**: Which aggregates carry a `version` column for optimistic concurrency? Which paths require pessimistic locking or atomic DB operations?

Read `references/reliability-patterns.md` for transaction boundaries, idempotency, outbox, and concurrency control.

### Security

**Surface the requirement first (threat modeling).** Before listing controls, run a lightweight **STRIDE** pass over the C4 boundary diagram and the Key Data Flows: for each trust-boundary-crossing flow, ask which of Spoofing / Tampering / Repudiation / Information disclosure / Denial-of-service / Elevation-of-privilege applies, and promote any material finding back into the Stage-2 utility tree as a security ASR (filter #8) so it hits the ATAM gate like every other driver. Canon: Shostack (STRIDE, DFD trust boundaries); Saltzer-Schroeder (fail-safe defaults, least privilege, complete mediation) as the generative lens the checklist below only echoes. Hand the per-diff vulnerability/OWASP list to a security-review capability (e.g. the `security-checklists` skill, if available) — don't inline it here.

Defense in depth — never rely on a single security control:

1. **Edge**: Rate limiting, WAF, DDoS protection
2. **Transport**: TLS 1.3
3. **Authentication**: Token validation at gateway/middleware
4. **Authorization**: Permission check at service/handler level
5. **Data**: Encryption at rest, column-level encryption for PII
6. **Audit**: Immutable audit log for sensitive operations

Principle of least privilege: each component gets only the permissions it needs. Zero trust within the network — internal services authenticate to each other.

### AI Security

OWASP Top 10 for LLM Applications (2025, from the OWASP Gen AI Security Project) awareness. 3-layer defense:

1. **Input classification**: Detect and reject prompt injection, PII in prompts
2. **RAG trust boundary**: Treat retrieved context as untrusted — validate, sanitize, attribute
3. **Output validation**: Schema validation, content filtering, hallucination detection

Read `references/ai-architecture.md` guardrails section.

### Resilience

For each external dependency, decide upfront:

| Service | Timeout | Retry | If It's Down |
|---|---|---|---|
| Database | 5s | Backoff x3 | System offline |
| LLM API | 60-120s* | Backoff x2 | "AI unavailable" + cached fallback |
| Payment provider | 15s | Idempotency key | "Payments temporarily unavailable" |
| Email service | 5s | Queue for later | Silent — never block user action |

*Non-streaming LLM calls; streaming endpoints need up to ~300s (see `ai-architecture.md` §2). These are starting defaults — `operational-patterns.md` is the source of truth for timeout ranges and rationale.

Key patterns: timeout budgets (outer caller owns the budget), retry at outermost layer only (prevents retry storms), graceful degradation (degrade features, not the whole system).

Read `references/operational-patterns.md` for detailed resilience patterns.

### Production Incident Patterns (Check Against)

Verify your design doesn't contain these known failure modes:

- **N+1 queries**: ORM loads list then lazily loads relations one-by-one. Specify eager loading or dataloader patterns in the design.
- **Thundering herd**: Cache expires, all requests hit DB simultaneously. Specify stampede prevention (lock-based recomputation, stale-while-revalidate).
- **Distributed monolith**: "Microservices" that must be deployed together or share databases. Worse than a monolith.
- **Retry storm**: Nested retry logic causes exponential amplification. Define retry budgets at architecture level.
- **Cold start cascade**: All serverless instances scale to zero, traffic burst requires simultaneous cold starts. Document minimum instances and warm-up strategy.

### Design Principles as Evaluation Criteria

- **Design for failure**: Every integration point has a documented failure mode and recovery path
- **Make the wrong thing hard**: Type systems, schema validation, compile-time safety over runtime checks
- **Delay irreversible decisions**: One-way doors get rigorous analysis, two-way doors get decided fast
- **Optimize for change**: Hexagonal architecture by default because it optimizes for changeability
- **Twelve-Factor adapted**: Stateless processes, config via environment, backing services as attached resources, structured logs as event streams

### Output

Write to `docs/arch/system.md` §5 (Cross-cutting).

---

## Stage 9 — ADR & Risk Review

**What it answers**: Are all decisions recorded? What could go wrong?

Most ADRs are already written during stages 4-8. This stage reviews completeness and adds the risk register. ADRs live one-per-file in `docs/arch/adr/`; the risk register, tech debt, and open questions live in `docs/arch/risks.md`.

**ADR numbering is a shared namespace.** A standalone-ADR capability (e.g. the `arch-decision` skill) appends to the same `docs/arch/adr/` directory under the same "highest existing number + 1" rule. When re-running this stage on a system that already has ADRs, allocate numbers from the directory's current max — never restart at ADR-001. On a true collision (two files grabbed the same number), the later writer renumbers.

### ADR Format

Use this structured ADR format (Nygard/MADR-style fields) for consistency:

```
## ADR-NNN: [Title] — YYYY-MM-DD
- Status: Accepted | Proposed | Superseded by ADR-NNN
- Stage: [which design stage produced this decision]
- Door: One-way (irreversible) | Two-way (reversible)
- Context: [the situation and forces at play]
- Decision: [what was chosen]
- Why: [the reasoning — reference quality attributes]
- Rejected: [alternatives and why they were rejected]
- Tradeoff: [positive and negative consequences]
- Revisit when: [trigger conditions for reconsideration]
```

**One-way doors** (irreversible — analyze carefully): Database choice, primary language, auth architecture, core domain model.
**Two-way doors** (reversible — decide fast): Library choice, caching strategy, log format, CI tool.

### Minimum ADRs

**Always record (all software types):**
1. System architecture pattern
2. Service architecture pattern
3. Primary data storage approach
4. Communication style (sync/async/event-driven)

**Record when applicable:**
- AI integration approach — when AI features exist
- Authentication/authorization — when users exist
- API design philosophy — when external consumers exist
- Offline/sync strategy — when offline capability is needed
- Distribution/packaging — for libraries, CLIs, desktop apps
- Concurrency model — for high-throughput or real-time systems
- Build-vs-buy — when a generic subdomain (Stage 3) is bought as an external service rather than built or self-hosted; state which non-code asset the vendor sells

### Risk Register

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| e.g., LLM API price increase | High — cost ceiling exceeded | Medium | Multi-provider abstraction, usage-based rate limiting |

### AI-Specific Risks

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| Hallucination in critical output | High | Medium | Schema validation, citation requirements, human review for high-stakes |
| Model deprecation | Medium | Medium | Version pinning, abstraction layer, evaluation suite for migration testing |
| Vendor lock-in | Medium | Medium | LLM Gateway pattern, standardized prompt format |
| Cost explosion | High | Medium | Per-request cost tracking, daily budget alerts, model cascading |
| RAG poisoning | High | Low | Source trust scoring, content validation pipeline |

### Tech Debt Tracking

| Item | When | Priority | Resolution Condition |
|---|---|---|---|
| e.g., Shared DB between contexts | Stage 5 — accepted for MVP | P2 | Extract to separate DB when contexts need independent scaling |

### Conway's Law as Growth Risk

Architecture built by a small team mirrors that team's communication structure — which is optimal for the current team size. If the team grows, the architecture may need to evolve to match team boundaries. Document which module boundaries could become service boundaries if team structure demands it.

### Open Questions

Capture unresolved decisions that block nothing yet but need an answer before the relevant stage ships — each with the options on the table and the information needed to decide. Record them in the **Open Questions** section of `docs/arch/risks.md` and promote each to an ADR (a new file in `docs/arch/adr/`) once decided.

### Output

Final review of the ADRs in `docs/arch/adr/` and `docs/arch/risks.md`.
