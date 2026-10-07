# Service Architecture Patterns

Decides **how each deployable is structured inside, per bounded context**: dependency direction, domain isolation, aggregates, and the relationships between contexts. Read at design-flow Stage 5, and at Stage 3 for aggregates and context relationships. How deployables communicate → `system-architecture.md`.

---

## Service Architecture Decision Guide

Decide **per bounded context**, and record the per-context map in `system.md` §1 — it is the content of the internal-structure ADR (`design-flow.md` § Minimum ADRs).

1. **Rigor from the subdomain type** (`design-flow.md` § Subdomain Classification & Build-vs-Buy). Core → an explicit domain model behind ports (hexagonal), with a functional core where the rules are pure computation. Supporting or generic built in-repo → the simplest structure that works: plain CRUD (a transaction script per operation), or a slice per endpoint; hexagonal only where adapter churn is expected. Bought → a driven adapter only, plus an anti-corruption layer if its model leaks (§ Strategic Context Mapping). *Break when* risk outranks type: money, authorization or safety rules inside a supporting context get the core treatment.
2. **Axis from the churn that dominates.** Prefer the decomposition minimizing E[cost] = Σ P(change) × spread(change) along the axis that *actually churns* — features churning → slices (hexagonal inside any slice that holds real rules); adapters/providers churning → hexagonal ports.
3. **Vocabulary last.** Clean and Onion are hexagonal with named layers: match the team's existing names, never migrate between them; same cost shape plus one named layer.

**Agentic-development weights.** When the code's primary writers and maintainers are AI agents, the decision inputs above stay the same but two coefficients grow, because every agent session starts context-empty and reloads what a human would remember:

- **Context cost per edit becomes a first-order term.** The style choice sets how many files (≈ tokens) an agent must load to make one change: a slice localizes a feature edit to one directory; layer-first spreads it across L layers; pass-through ceremony multiplies it for nothing. That raises the weight of spread(change) in step 2's E[cost].
- **The verification loop is part of the architecture.** Agents converge by iterating against fast deterministic feedback; a structure where each module/slice carries its own runnable test boundary (pure functional core, slice-scoped tests) multiplies effective agent capability, while whole-app-only verification starves it.

Two consequences, whatever you choose: **declare it** — record the style per bounded context in `system.md` §1, and return a one-line style declaration in the report for the caller to add to the project conventions file, since an undeclared choice is re-guessed by every future session (and reviewers judge diffs against the *declared* style, not their own default); and **hold it consistently within the project** — agents induce conventions from neighboring code, so consistency is itself part of the prompt. Deviations are fine with an ADR.

---

## Hexagonal Architecture (Ports & Adapters)
*Which of this context's outside dependencies are likely to change, and what must the domain never know about them?*
Dependencies point inward: `driving adapters → ports → domain ← ports ← driven adapters`. Per context declared hexagonal, name the driving ports (the use cases it exposes) and the driven ports (what it requires — repositories, providers, clock); each driven port hides one volatile decision (`design-flow.md` Stage 5); the domain imports nothing from adapters. Framework-neutral shape: `adapters/` (http, persistence, external) → `application/` (use cases) → `domain/` (entities, value objects, domain services, driven ports), wired in `config/`; the concrete layout belongs to the implementing capability.
**Buys**: domain tests against in-memory fakes of ports, a contract test per driven adapter against the real dependency, and provider swaps that never touch the domain.
**Choose when**: core contexts — business logic beyond simple CRUD, anticipated adapter changes (provider migrations), several people or agents editing concurrently who need clear boundaries.
**When not**: a handful of genuinely independent CRUD endpoints (a slice per endpoint is cheaper — the port/adapter ceremony buys nothing until domain logic or adapter churn exists), or a one-off internal tool whose blast radius never repays the file count. Cost shape: a fixed indirection tax on every feature (more files loaded per edit) purchasing cheap adapter swaps — worth it exactly when P(provider/infra change) is real.
**Failure mode**: leaky abstractions — the domain takes infrastructure types (a connection pool instead of a repository port), defeating the boundary. **Guard**: a dependency-rule fitness function — the domain imports nothing from adapters — for every context declared hexagonal (`design-flow.md` § Fitness Functions).

## Vertical Slice Architecture
*Does a typical change touch one feature, or one rule shared by many features?*
Organize by **feature**, not by layer: each feature or use case owns its handler, rules and data access, with no shared service or repository layer; `shared/` holds only true cross-cutting code (auth, middleware).
**Choose when**: features are genuinely independent; CQRS (each command or query maps to a slice); people or agents work on features independently.
**When not**: deep cross-feature invariants — one domain rule spanning many slices turns a rule change into an N-slice shotgun edit; or when infra/provider churn outweighs feature churn, since each slice's own data access re-pays every provider migration N times. Cost shape: the mirror of layer-first — feature changes have spread ≈ 1 slice (the smallest context load per edit), cross-cutting changes have spread ≈ N slices. Pick by which churn axis actually dominates.
**Failure mode**: a rule copied into several slices drifts apart; rules whose divergence causes correctness or security bugs are centralized from their first use (`design-flow.md` Stage 5). **Guard**: slices never import each other, and shared code lives only in `shared/` (a dependency-rule check).

## Functional Core, Imperative Shell
*Can the decision be computed from data already gathered?*
A pure core (input → output, no I/O) holds the rules; the shell gathers data, calls the core and performs the effects it returns.
**Choose when**: the rules can be written as gather → decide → act with no I/O inside the decision, and they are dense enough that table-driven tests pay off.
**When not**: workflows that genuinely need mid-computation I/O (conditional fetches driven by intermediate results force a fetch-everything-upfront data shuttle), or CRUD with no rules worth isolating. Cost shape: buys the cheapest verification loop available — a pure core needs table-driven tests, no mocks, which is also the best fit for agent self-verification — paid for with shell complexity wherever I/O and logic truly interleave.
**Failure mode**: I/O leaks into the core "just this once", and the cheap tests rot into mocks. **Guard**: the core may not import I/O-capable modules (a dependency-rule check).

---

## Inside a Context

### In-Process Domain Events
**Choose when** adding a side effect means editing the originating service; direct calls are fine for 1–2 side effects. **Trade-off**: flow spreads across files (harder to trace).
**Dispatch timing**: handlers that only write the same database run inside the originating transaction. Anything with an external side effect (email, HTTP call, broker publish) runs after commit from an outbox or job row written in that transaction, its handler deduplicating through an inbox — never before commit, and never from memory after commit (`reliability-patterns.md`).
**Distinct from system-level events**: in-process events inside one deployable, not a broker; system-level event-driven architecture → `system-architecture.md`.

### DDD Tactical Patterns
Apply them **with any service architecture** where the domain has complex rules, invariants to protect, or rich behavior beyond data manipulation. Forcing question per invariant: must it hold immediately (in the same transaction) or eventually? Immediately → inside one aggregate. Eventually → separate aggregates plus a domain event (Vernon, "Effective Aggregate Design"):
- Model only true invariants inside an aggregate, and keep aggregates small — contention grows with size.
- Reference other aggregates by id, never by object.
- Change one aggregate per transaction; consistency between aggregates is eventual, through domain events and the outbox. The aggregate root carries the version for optimistic concurrency (`reliability-patterns.md`).
- Value objects for concepts compared by value (money, ranges); repositories are the driven ports; a domain service holds logic that spans aggregates.

**Don't over-apply**: "Is this entity just a data bag? Then skip Aggregate."

---

## Strategic Context Mapping

Tactical patterns structure code *inside* a context; **context mapping** governs the relationship *between* contexts — and those relationships are where change is absorbed or propagated, so name them explicitly when two contexts integrate: label each context-map edge (`context.md` §4) with its relationship and whether it is sync or async. Canon: Evans (DDD), Vernon (IDDD).

| Relationship | What it means | Use when |
|---|---|---|
| **Anti-Corruption Layer (ACL)** | A translation layer keeping a foreign/legacy model from leaking into yours | Integrating a vendor or legacy system whose model you don't control |
| **Open-Host Service (OHS)** | A published, stable protocol many consumers integrate against | You are upstream to several consumers and want one contract, not N |
| **Published Language** | A shared, versioned schema (events/DTOs) at the boundary | Multiple contexts exchange data and must evolve compatibly |
| **Conformist** | Downstream adopts upstream's model as-is | Upstream won't negotiate and an ACL isn't worth the cost |
| **Shared Kernel** | A small shared model two teams co-own | Two contexts genuinely share a core concept and coordinate tightly |
| **Customer/Supplier** | Downstream's needs prioritized in upstream's planning | Upstream can flex; the dependency is a negotiated partnership |
| **Separate Ways** | No integration; each context duplicates what it needs | Integrating costs more than the duplication it removes |

ACL and OHS are the load-bearing boundary-protection patterns: an ACL stops upstream churn from forcing changes on you; an OHS lets you change internals without breaking consumers.

---

## Anti-Patterns

**Anemic Domain Model** (core contexts): entities are data holders and invariants live in services that any caller can bypass. A functional core over plain data, or a CRUD supporting context, is not anemic.

**Common-package bloat**: The `shared/` or `common/` package grows to contain half the codebase. If everything is shared, nothing is isolated.
