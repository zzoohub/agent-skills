---
name: software-architecture
description: |
  Architecture docs (context, system design, ADRs, risks): the hard-to-reverse
  decisions, sized by numbers and held by guards. Build Mode: a new system
  from a PRD, or an existing one evolved (as-is recovery, re-architecture,
  migration). Review / Diagnose Mode: audit one from docs or code.
  Use when: "system design", "design doc", "architect this", "how should I
  build this", "threat model", "modernize", "audit our architecture".
  Do NOT use for: an AI feature or agent design (ai-architecture); one
  decision on an existing system (arch-decision); schemas, indexes or
  migrations (database-design); execution review of a locked design
  (plan-review).
---

# Software Architecture

## Premise

**Architecture is the set of decisions that are expensive to reverse.** Code inside a boundary is cheap now: an agent rewrites a module in an afternoon. The boundaries are not, and neither is what they protect: stored data and its formats, contracts others bind to, trust boundaries, commitments to vendors, regulators and users, anything shipped to a device. Classic design still decides how safely a system changes (what each module hides, which way dependencies point, who writes each piece of data, what happens when a part fails), so it stays. Ceremony that informs no decision goes.

Five rules, applied at every stage:

1. **Numbers before patterns.** A choice is legitimate only relative to this system's load, data, deadlines and budget.
2. **Type every door.** A one-way door gets analysis, a price and the condition that would flip it. A two-way door gets a default.
3. **The simplest shape that meets the drivers.** Each step up in complexity cites a number or a named force, never growth hopes.
4. **A claim without a guard decays.** Each load-bearing property names the check that fails when it breaks: a test, an alert, a drill.
5. **Write only what changes what the next reader does.** The docs are read cold, by an agent with an empty context or a person six months later, who must be able to start a correct change within ten minutes. A line stays only if an implementer would do something different, and wrong, without it.

## Modes & Routing

- **Build Mode** (default): Stages 0–5, for a new system or an existing one that is changing.
- **[Review / Diagnose Mode](#review--diagnose-mode)**: audit an architecture from its docs, else its code. Read-only by default.
- **A question is not a request for documents.** "How should I build this?" with no requirements doc, or a quick comparison of shapes, gets an inline answer of about 300 words: the shape, the numbers behind it, the one-way doors and what to prove first. Write the files when the caller asks for the design to be recorded or a later step needs them.

Route by intent and state. The greenfield sentinel is the context doc (default `docs/arch/context.md`), not the `docs/arch/` directory, which a database-design pass may have created.

| State | Design, extend | Re-architect, migrate | Review, audit | One decision |
|---|---|---|---|---|
| No doc, no code | Build, greenfield | — | Ask what to review | Answer inline in ADR shape; never a full pass |
| Code, no doc | Recover as-is → Build | Recover as-is → Build + Transition Plan | Recover as-is → Review | Recover what it touches → `arch-decision` |
| Doc exists | Build (patch) | Build + Transition Plan | Review | `arch-decision` |

- **Scope.** Architecture-level decisions only. Table schemas, indexes and migration scripts go to `database-design`; the design of an AI feature or agent to `ai-architecture`; code layout to the implementing skill; execution review of a locked design to `plan-review`. Sibling skills named here are used if available. A request that spans them runs Build, then `ai-architecture` and `database-design`, with one report; when a model is the core of the product, `ai-architecture` runs inside Stage 2.
- **An existing system is patched, never regenerated.** Drift-check the docs' load-bearing claims against the code first and recover what drifted (`references/evolution.md`). Re-enter at the earliest stage whose inputs the change alters: a new business, regulatory or placement driver re-enters at Stage 0; an extension with no new driver at Stage 2. Patch named sections in place and keep an existing doc's headings and ids (older docs call drivers `QA-nn`). Supersede a reversed ADR, never edit it.
- **Ownership.** Write only under the architecture docs root (default `docs/arch/`; caller may redirect). Read the PRD and specs; never edit them. A missing or wrong input becomes a gap in your report.

## Stage 0 — Frame

**Read first** (defaults; caller may redirect): the PRD (`docs/prd/prd.md`), feature specs (`docs/prd/features/*.md`) and product brief (`docs/prd/product-brief.md`), or the memo, issue or change request the caller names; then the project conventions file, existing code and config. With no requirements source, ask where it lives. Requirements that describe a solution get pushed back to the problem behind it.

**Ask once, in one batch, only what the requirements cannot hold and a one-way door depends on**: mandated platforms, regions and jurisdictions, team and on-call model, compliance regime, budget, safety standards. Each question carries the default you will otherwise assume and what it gates. A subagent that cannot prompt applies the defaults, records them as assumptions and lists the questions in its report.

**Classify each deployable unit** as **operated** (you run it), **shipped** (others run it) or **fleet** (devices you update remotely), and answer its forcing question in one clause on the `Units` line of `context.md`:

| Type | Forcing question |
|---|---|
| Web application | What renders where, and what are the session and cache models? |
| API service | Who consumes it, and how does a breaking change ship? |
| Library / SDK / CLI | What is the public contract, and how does it evolve without breaking users? |
| Data pipeline | What happens to a record that fails mid-pipeline, and is every stage idempotent on replay? |
| Mobile / desktop app | What works offline, how do conflicting edits merge, and which old versions must the backend still serve? |
| Game | Is the client or the server authoritative, and what tick and latency budget follows? |
| Embedded / IoT | What keeps working with no connectivity, and what happens if an update fails mid-install? |
| Agent / AI service | Which decisions does a model own, with what authority, and what stops a bad run? |

**Name who builds and runs it**: people, agents, or both. When agents write most of the code, three things become architecture (`references/structure.md` § Built by agents): a declared style per context, because an undeclared one is re-guessed every session; rules enforced by a check instead of by review; and a verification loop each module can run locally in seconds.

## Stage 1 — Size & Drivers

**Envelope first** (`context.md` §2). Crude is fine: a ×3 error changes nothing, a ×100 error changes everything. Show the inputs so the arithmetic can be checked. On an existing system, measure from telemetry.

- **Load** per source (users, machine clients, agents and crawlers, devices, schedules): count × rate × peak factor (×5–10 for consumer traffic, ×2–3 for business hours, unless measured) → the peak in its **binding unit**: requests/s split read and write, concurrent sessions or connections, messages/s with fan-out, jobs/s, tokens/min.
- **Burst shape** against scale-out lead time, and the hottest partition's share.
- **Data**: growth, working set, largest payload. **Quotas** in each provider's units, with headroom at peak.
- **Unit cost** where usage is priced: the successful task for the p95 user, against the price the requirements imply. Arithmetic that says the product loses money is the first finding, not a detail.
- **Top three risks** as failure scenarios with numbers ("checkout p99 > 5 s at peak").

**One-box check.** Prove that one well-built process on one primary store cannot do the job before distributing anything. *Break when* availability, isolation, residency or geo-latency demand distribution anyway.

| Class | Envelope vs one node's capacity in the binding unit | Legitimate default |
|---|---|---|
| **S** | ≥ ~10× headroom | One deployable, one primary store; distributed patterns are illegitimate for load |
| **M** | Fits one primary in one region | Single region; replicas, cache, async offload as a driver needs |
| **L** | Beyond one primary's writes, or one region | Distribution earns its cost; size tiers and cells at peak |

Anchor the class to measured capacity; on a greenfield design that is published sizing or an assumption with a load-test spike. Class each tier in its own unit: a system can be S for data and M for concurrent sessions. Design for the envelope and about 10× beyond it; past that, record the trigger in the Scaling Ladder and plan the rewrite. Placement constraints (residency, on-prem, edge, offline clients) sit beside the class, never in it: they decide where units run, not how many exist. Software others run has no class; its envelope is input size, start and process latency, a memory ceiling and a platform matrix.

**Drivers** (`context.md` §3). A driver is a requirement that forces structure: business risk, an unusual quality level, an uncertain dependency, something cross-cutting, a regulation, a threat, a hazard. Write three to seven in total, each one sentence with a number: *"When {stimulus} during {condition}, {part} {responds}, measured as {number}."* Among them, at least one change scenario ("when a second payment provider is added, at most one module changes") and one failure scenario. Rank them and name the conflicts between them. "Fast", "scalable" and "highly available" are not drivers.

**Concerns** say where depth goes. A concern is **deep** when its trigger fires: it gets a driver, a coverage row and a guard, and you read its reference. Otherwise it is **light** (one line) or **skipped** with a reason. Deep means more analysis, not a longer document. For security, privacy, data integrity and safety an unknown trigger counts as present; for the rest, take the lighter reading and record the assumption. Security, privacy, data loss and compliance get no prototype discount; prototypes ship.

| Concern | Forcing question | Deep when | Depth in |
|---|---|---|---|
| Scale & latency | What load at what latency, and what breaks first? | class M/L; a latency driver | `structure.md` § Topology |
| Availability | When a dependency is slow, not just down, does the system recover alone? | contractual availability; money paths; class L | `operational-patterns.md` § Dependency Protection |
| Security | Which trust boundaries does each scenario cross, and who can act as whom? | external exposure; multi-tenant; money; AI with tools | `security-privacy.md` |
| Privacy & compliance | Where is every copy of personal data, and how is each retained and erased? | sensitive or regulated data; residency | `security-privacy.md` § Data duties |
| Data integrity | Who is each data set's single writer, and which invariants span rows or services? | money, stock, multi-step or offline writes | `reliability-patterns.md` |
| Tenancy *(cond.)* | What isolates tenants at each shared resource, enforced twice? | sensitive data or contractual isolation | `structure.md` § Tenancy |
| Contracts | What do others bind to, and how does it change without breaking them? | external consumers; shipped software | `structure.md` § Contracts |
| Operability | Who knows it is broken, and what can they do at 3 a.m. through a designed path? | an operated runtime with an availability driver | `observability.md` |
| Change safety | How does a change reach users and get undone? | shipped software; fleets; frequent releases | Stage 4 |
| Evolvability | Which likely changes touch how many modules? | long lifespan; core domain | `structure.md` § Boundaries |
| Cost | What does a unit of value cost at baseline, at growth, for the tail user and idle? | usage-priced inputs; thin margins; class L | Stage 4 |
| Ownership | Can each owner change and ship its part without coordinating? | more than one team, or team growth | `structure.md` § Boundaries |
| Reach | Which devices, networks, locales and abilities must work, offline included? | consumer, mobile or global; accessibility duties | the ux-design and i18n capabilities |
| Safety *(cond.)* | Which hazards can the software cause or fail to prevent, and what is each safe state? | software can harm people or property | `structure.md` § Safety |
| AI *(cond.)* | Which decisions does a model own, under what authority, eval gate and budget? | tools or actions; untrusted input or personal data in context; decisions about people; volume | the ai-architecture capability; else Stage 2 |

Then set the **size** of the record ([Output](#output)).

## Stage 2 — Shape

Boundaries, data and structure settle together, usually in one pass. Depth: `references/structure.md`.

- **Boundaries** (`context.md` §4). The same term under different rules is two contexts; modules that always change together are one. Each context names the data it owns, the volatile decisions it hides and its owner, and is classed **core** (why users pay: invest), **supporting** (build thin) or **generic** (build, adopt or buy by what the vendor actually sells). Core rigor spent on a generic context, or neglect of the core, is the most expensive mistake here.
- **Default shape.** Operated: a modular monolith whose module boundaries and single-writer data ownership a build check enforces. Shipped: a library core with a thin shell. Split a deployable, or step one flow up to events, CQRS, event sourcing or a saga, only on an envelope number or a named force: a divergent runtime profile, blast-radius isolation, a compliance boundary, an independent team.
- **Data** (`system.md` §3). Stores by access pattern, a type before a product. Each data set has one writer, a class, every copy listed (backups, logs, caches, indexes, embeddings, processors, non-production), a retention and erasure path, and a residency. Consistency is stated per operation. Whatever holds the only copy has an RPO, an RTO and a restore test. A cache is a confidentiality decision first: keys carry the tenant, and personalized output never reaches a cache shared across principals.
- **Contracts.** Every surface others bind to (APIs, events, files, CLI output, config, webhooks, tool interfaces for agents) gets its consumers, a compatibility policy (additive by default) and a CI check. Whatever a consumer can observe becomes a one-way door, so keep the surface small.
- **Driver coverage** (`system.md` §1), one row per driver: the decisions that move its number, the parameter it is most sensitive to, the evidence, and "holds unless …". Evidence is analysis shown, a measurement, a spike, or precedent whose conditions match; a pattern name is not evidence. Where it is an unverified assumption (vendor latency, model quality, a throughput ceiling), define a **spike**: a time-boxed test with a numeric pass or fail, run before the work it unblocks. A driver left uncovered goes to the Risk Register as high impact; never design past it silently.
- **AI.** A model in the path is designed with the ai-architecture capability, in the same pass when the model is the core of the product or takes consequential actions; the system docs then hold only what features share (`system.md` §1 AI Platform, §5 AI Authority). Without that capability, hold this floor: the model gets only the judgment code cannot make; authority, limits and money are enforced outside the model, and no single autonomous context combines untrusted input, sensitive access and the power to change state or send data out; model access is a port with a deterministic fake and a pinned version; seed tasks with a release gate are the feature's guard; cost is budgeted per successful task with hard caps; every AI store is a Data Inventory row.

## Stage 3 — Decide

These rules apply from the first decision on.

**Type each decision honestly.**

- **One-way doors**: the data model and stored formats; published contracts and anything consumers observe (shapes, ids, defaults, error text); the tenancy model; identity and authorization; the primary store; regions and residency; key ownership; a vendor that accumulates your data; every shipped release; training on user data; what a cache shares across principals.
- **Two-way doors**: libraries, internal structure, a cache used for speed, log format, CI tooling, and whatever sits behind a stable contract with a test suite an agent can rewrite against.

**Record each decision at the weight it carries.**

| Decision | Record |
|---|---|
| A default taken for a stated reason (a modular monolith at class S, the baseline's database) | One row in `system.md` §1 Decisions. No ADR |
| A one-way door with a live alternative; a departure from the default or the technology baseline; a trade between two drivers | An ADR (`templates/adr.md`), written when decided: what was rejected and the driver it fails, what gets worse and who pays, the guard that confirms it, a revisit trigger |
| A decision waiting on a spike, an unverified vendor fact or the caller's answer | The same ADR with status `Proposed` and what settles it |
| A two-way door | Nothing beyond the design itself |

Linked decisions on one surface share one ADR. A decision argued in an AI feature doc gets an ADR of a few lines that points there. No one-way door rests on a low-confidence assumption without a spike. *Break when* the force is law, physics or a signed SLA: record a constraint, not a trade-off. ADR numbers are shared with `arch-decision`: highest existing + 1, never restarting at 001.

**Technology**, resolved in this order and recorded in `context.md` §5:

1. Explicit mandates. On an existing system the incumbent covers the rest.
2. The house profile, if the project adopts one (default `references/house-stack.md`; the project conventions or the caller say so), after checking that it fits the target environment.
3. Otherwise select per driver: at least two candidates compared on driver fit, who operates and patches it, cost at the envelope, and exit cost.

- **Verify vendor facts now.** Versions, prices, quotas, regional availability, model names and data terms move faster than training data. A choice resting on one cites a current primary source and its date, or becomes an assumption with a spike and a `Proposed` ADR.
- **Boring by default**; novelty only in the core. *Break when* the boring option fails a hard number.
- **Lock-in is a priced option.** Buy a seam only where the chance of switching times its cost exceeds the seam's premium, aimed at a named exit. An abstraction over every dependency hides the features you are paying for.
- A pre-GA dependency on a critical path names its GA fallback.

## Stage 4 — Operate

What must hold after the document is closed (`system.md` §4–§5). State each rule once as the default and list only where this system departs from it.

- **Deployment.** Each function runs at the lowest tier (device, site, client, region, cloud) that meets its deadline during a partition, its data gravity and its residency. Per unit: where it runs, failure domain, trust zone, scaling model. Each partition-prone link says what happens on disconnect: buffer, degrade, act locally or refuse.
- **Release**, by who controls the runtime. Operated: reproducible, rolled out by isolation unit, rolled back or fixed forward on an SLO condition, schema changes as expand-contract. Shipped: versions, support and version-skew windows, a recall path; a shipped release cannot be rolled back. Fleet: staged rings with halt criteria, atomic update with fallback, signing, a kill switch. **Config that changes behavior is a release**: flags, defaults, prompts, model settings.
- **Failure.** A hard dependency gets a deadline derived top-down, retries in one layer on a budget, isolation, and a degraded mode written as what the user sees (`references/operational-patterns.md`). A write that must not be lost, duplicated or interleaved gets a transaction boundary, an outbox where a state change pairs with a publish, idempotency checked where the effect commits, and concurrency control (`references/reliability-patterns.md`). A fallback that has never run is a hypothesis: name the drill that exercises it.
- **Trust.** A threat pass over each flow that crosses a trust boundary, the build and release path included; each crossing ends in a control with a guard, a driver or an accepted risk. Authorization is enforced at the service that owns the resource (`references/security-privacy.md`).
- **Cost.** The fixed floor, the variable cost per demand unit and cost at provisioned peak, at baseline and at growth, against a target unit cost; whatever costs money while idle; a spend alert attributed by tenant or feature.
- **Scaling Ladder.** What breaks first at 10× and 100×, the metric that signals it, the planned response. "Redesign, and that is fine" is an honest 100× row.
- **Guards.** Every driver gets a standing check keyed to its id: a CI rule, an SLO alert, a scheduled drill. Evals are the guards of AI features. A guard counts once it has been shown to fail when its property breaks; mutation testing does that mechanically for tests an agent wrote. An invariant across concurrent writers or services can be guarded by a small formal model checked by a tool. Availability and latency drivers become SLOs with error budgets, paged on burn rate (`references/observability.md`); an error budget never covers a correctness invariant, security or data loss.

## Stage 5 — Record & Report

**Risks** (`risks.md`). Seed the register from Driver Coverage rows at risk and a pre-mortem: assume failure a year after launch and write the likeliest cause per driver. Each risk names the driver it threatens, an owner (a role, until people are named) and a watched signal; a risk nobody watches is fiction. Spikes get their own table: the question, a pass or fail number, a time box, what it unblocks. Accepted shortcuts go to Tech Debt with a resolution condition, undecided questions to Open Questions with a decide-by.

**Report back** a summary, not the documents: files written; the shape and the decisions behind it; one-way doors and their ADRs; spikes owed, in order; assumptions and questions for the caller; on a first Build pass, a three-line pointer for the project conventions file (load `context.md` first, `system.md` for implementation, decisions as ADRs) with the declared style per context. Push back both ways: simple CRUD does not need event sourcing, concurrent money movement needs explicit concurrency design, and a unit cost above the price is a finding about the product.

## Output

Default paths; the caller may redirect the `docs/arch/` root.

| File | Holds | Template |
|---|---|---|
| `docs/arch/context.md` | Why and what: summary, problem, envelope, drivers, domain, constraints, assumptions | `templates/context.md` |
| `docs/arch/system.md` | How: shape and decisions, components, data, deployment, cross-cutting rules | `templates/system.md` |
| `docs/arch/adr/ADR-NNN-{slug}.md` | One contested decision per file | `templates/adr.md` |
| `docs/arch/risks.md` | Risks, spikes, tech debt, open questions | `templates/risks.md` |
| `docs/arch/as-is.md` | The recovered as-is during a re-architecture or migration | `references/evolution.md` |

**Budgets.** Size sets how much is written, never how much is analyzed.

| Size | When | `context.md` | `system.md` |
|---|---|---|---|
| Small | one deployable, class S, at most two deep concerns | ≈ 600 words | ≈ 900 words |
| Standard | up to about six deep concerns | ≈ 1,500 | ≈ 2,500 |
| Large | more deep concerns than that, class L, several teams, or a regulated or safety-critical domain | ≈ 2,500 | ≈ 4,500 |

Tables count; diagram source does not. An ADR is about 250 words. Over budget, cut in this order: what the requirements or this skill already say, rows that restate a default, reasoning that belongs in an ADR. Never cut a driver, a one-way door, a number or a failure behavior.

**Defaults and exceptions.** A table lists decisions, not inventory. State the rule once ("every outbound call: deadline from the request budget, one retry in the adapter") and add a row only where this system departs from it, or where the row is itself a product decision (what the user sees when the payment provider is down). The implementer applies the default to everything unlisted. A cell is a phrase; reasoning that needs sentences belongs in an ADR.

**Numbered sections stay**, because other skills read them by number; one that does not apply is a single line, `n/a — reason`. Subsections exist only where something was decided.

## Writing

- **State the choice and its price.** Confidence goes in fields (assumption confidence, door type, ADR status), not in hedged prose.
- **Concrete over abstract.** "A per-tenant read-through cache, 15-minute TTL, stale-while-revalidate" beats "a caching layer". Name a version only where the decision rests on one.
- **Label every number**: measured (source, date), derived (inputs shown) or a target. On a greenfield design most are derived or targets; say so once per table instead of hedging each cell. Where a slot asks for something that does not exist yet (a measured capacity, a named owner, the date a fallback last ran), write the plan that will produce it: the spike, the role, the drill and its cadence.
- **This system's numbers, not reputation.** Cite precedent only with the condition that made it work.
- **Diagrams as code**: a system context diagram always; a container diagram when there is more than one deployable or trust zone; trust boundaries marked.
- **Never narrate the method.** Stage names, rule quotes and self-review tallies stay out of docs and reports. Reviews lead with findings.

## Self-Review

- Every driver is one measurable sentence with a coverage row and a guard; every step up in complexity cites a number or a named force.
- Every one-way door is in the Decisions table; each contested one has an ADR with a confirmation and a revisit trigger; none rests on a low-confidence assumption without a spike.
- Every data set has one writer; personal and regulated data have an erasure path that reaches every copy; the only copy of anything has a restore test.
- Every hard dependency has a deadline, one retry layer and a degraded mode a user would recognize.
- Every vendor fact a decision rests on carries a source and date, or is an assumption with a spike.
- Usage-priced or operated: cost per unit of value at two load levels, against the price.
- Existing system: each transition step states the driver levels it holds, its exit check and its rollback trigger.
- AI present: each feature that is core or acts consequentially has a feature doc that passes the ai-architecture gate, or the design holds the floor in Stage 2.
- Each doc is inside its budget, and no line fails the test in rule 5.

## Review / Diagnose Mode

Trigger: docs or an implementation exist, and the intent is to audit, not to build. Procedure, severities and questions: `references/review-lens.md`.

**Never regenerate.** A review that rewrites the design it was asked to critique has failed. By default write nothing: return each finding, ranked 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low, with a proposed disposition and patch text. When asked to apply them, the only writes are a targeted patch of a named defect (one edit per finding), an append to the Risk Register or Open Questions, and a new ADR via `arch-decision`. Never write a separate `review.md`. If the caller wants a redesign, say so and switch to Build Mode on the existing system.

## Reference Files

Read the section a decision touches, not the whole file.

| File | Read when |
|---|---|
| `templates/*.md` | Writing or patching that file; they hold the section numbers other skills read |
| `references/structure.md` | Stage 2: boundaries, sourcing, shape, internal style, agent-built code, contracts, data, topology, tenancy, real-time, safety |
| `references/evolution.md` | Work starts from a running system: as-is recovery, Transition Plan |
| `references/review-lens.md` | Review only |
| `references/security-privacy.md` | Security or Privacy is light or deep |
| `references/reliability-patterns.md` | A write must not be lost, duplicated or interleaved: the opening checklist for the design, the rest for the implementer |
| `references/operational-patterns.md` | Dependency protection, overload, jobs, durable execution, webhooks, caching, rate limits, uploads |
| `references/observability.md` | Operated systems: signals, sampling, cardinality, burn-rate alerts, health checks |
| `references/house-stack.md` | Only if the project adopts this house profile: preferred ecosystems and selection criteria, no products |
