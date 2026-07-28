# Service Architecture Patterns

Service architecture defines **how each service is internally structured** — code organization, domain isolation, dependency direction, and module boundaries.

For how services communicate *with each other* (event-driven, CQRS, saga, etc.), see `system-architecture.md`.

**Default: Hexagonal Architecture (Ports & Adapters).** Choose an alternative only with clear rationale documented as an ADR.

## Table of Contents

1. [Hexagonal Architecture (Ports & Adapters) — Default](#hexagonal-architecture-ports--adapters--default)
2. [Clean Architecture](#clean-architecture)
3. [Vertical Slice Architecture](#vertical-slice-architecture)
4. [Functional Core, Imperative Shell](#functional-core-imperative-shell)
5. [Service Architecture Decision Guide](#service-architecture-decision-guide)
6. [Cross-Cutting Patterns](#cross-cutting-patterns)
7. [Anti-Patterns](#anti-patterns)

---

## Hexagonal Architecture (Ports & Adapters) — Default

Organize code around a pure domain core. External concerns (HTTP, database, queues) connect through **ports** (interfaces) and **adapters** (implementations). Dependencies always point inward — domain code never imports framework or infrastructure code.

```
         +-------------------------------------+
         |            Application               |
         |  +-------------------------------+   |
Driving  |  |                               |   |  Driven
Adapters |  |     Domain / Business Logic    |   |  Adapters
(HTTP,   |--|                               |-->|  (DB, Queue,
CLI,     |  |     (Pure, no dependencies)    |   |   External
Events)  |  |                               |   |   APIs)
         |  +-------------------------------+   |
         |         Ports (Interfaces)           |
         +-------------------------------------+
```

**Strengths**: Domain logic testable in isolation (no mocks for infrastructure), adapters are swappable (swap Postgres for SQLite in tests, swap email provider without touching domain), clear boundaries prevent accidental coupling, scales with complexity.

**Trade-offs**: More files and indirection than simpler approaches, port/adapter wiring can feel ceremonial for trivial services, requires discipline to keep domain truly pure.

**Choose when**: This is the default. Business logic exists beyond simple CRUD. You anticipate adapter changes (provider migrations, testing strategies). Team size > 1 (or multiple agents editing concurrently) where clear boundaries prevent stepping on each other's code.

**When not**: a handful of genuinely independent CRUD endpoints (a slice per endpoint is cheaper — the port/adapter ceremony buys nothing until domain logic or adapter churn exists), or a one-off internal tool whose blast radius never repays the file count. Cost shape: a fixed indirection tax on every feature (more files loaded per edit) purchasing cheap adapter swaps — worth it exactly when P(provider/infra change) is real.

**Structure** (framework-neutral):

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

**Who uses it**: Netflix's Studio Workflows team documented adopting hexagonal architecture (2020 engineering blog); common in mature backends with complex domain logic that need to swap data sources and infrastructure without touching business logic.

---

## Clean Architecture

Uncle Bob's concentric circles model. Shares hexagonal's core principle (dependency inversion, domain at center) but introduces explicit **Use Case** and **Interface Adapter** layers.

```
+---------------------------------------------+
|  Frameworks & Drivers                        |
|  +----------------------------------------+  |
|  |  Interface Adapters                     |  |
|  |  +---------------------------------+   |  |
|  |  |  Use Cases                       |   |  |
|  |  |  +--------------------------+   |   |  |
|  |  |  |  Entities (Domain)       |   |   |  |
|  |  |  +--------------------------+   |   |  |
|  |  +---------------------------------+   |  |
|  +----------------------------------------+  |
+---------------------------------------------+
```

**How it differs from Hexagonal**:
- Hexagonal distinguishes *driving* (input) vs *driven* (output) adapters. Clean Architecture doesn't — it has "Interface Adapters" as one layer.
- Clean Architecture explicitly names the **Use Case** layer (application services that orchestrate domain entities). In hexagonal, this is implicit or folded into "application layer."
- **Onion Architecture** is a close relative — same concentric dependency rule, slightly different layer naming.

**Strengths**: Explicit Use Case layer makes application workflows visible. Well-documented (books, talks, large community). Clear dependency rule: source code dependencies point inward only.

**Trade-offs**: The four-layer naming can feel rigid. In practice, the difference from hexagonal is cosmetic — choose based on team familiarity, not technical merit.

**Choose when**: Team already thinks in Clean Architecture terms. Java/Kotlin/C# ecosystem where Clean Architecture conventions dominate. You want explicit Use Case objects as the primary API surface.

**When not**: anywhere the team isn't already invested in its vocabulary — the delta from hexagonal is cosmetic, so migrating an existing hexagonal codebase to it re-pays the rename everywhere and buys nothing. Same cost shape as hexagonal plus one more named layer.

**Who uses it**: Many Android/iOS teams (Google's recommended app architecture — UI/Domain/Data layers with an optional Use Case layer — follows Clean principles); Java/Kotlin/C# backend teams commonly adopt it.

---

## Vertical Slice Architecture

Organize by **feature**, not by layer. Each feature (or use case) owns its complete stack: handler -> business logic -> data access. No shared service or repository layers — each slice is independent.

```
src/
+-- features/
|   +-- create-order/
|   |   +-- handler          # HTTP endpoint
|   |   +-- command          # Input validation
|   |   +-- logic            # Business rules
|   |   +-- repository       # Data access
|   +-- get-order/
|   |   +-- handler
|   |   +-- query
|   |   +-- repository       # Can use different DB/cache
|   +-- cancel-order/
|       +-- handler
|       +-- command
|       +-- logic
|       +-- repository
+-- shared/                   # Only truly cross-cutting code
    +-- auth/
    +-- middleware/
```

**Strengths**: Each feature is self-contained — easy to understand, modify, and delete without affecting others. No "god service" or "god repository" classes. Natural fit with CQRS. Low coupling between features.

**Trade-offs**: Code duplication between slices (intentional — independence over DRY). Shared concerns still need a cross-cutting solution. Can feel scattered when the domain has deep cross-feature interactions.

**Choose when**: CQRS architecture (each command/query maps to a slice). Features are genuinely independent. You value feature isolation over code reuse. Team (or a fleet of agents) works on features independently.

**When not**: deep cross-feature invariants — one domain rule spanning many slices turns a rule change into an N-slice shotgun edit; or when infra/provider churn outweighs feature churn, since each slice's own data access re-pays every provider migration N times. Cost shape: the mirror of layer-first — feature changes have spread ≈ 1 slice (the smallest context load per edit), cross-cutting changes have spread ≈ N slices. Pick by which churn axis actually dominates.

**Who uses it**: Many .NET teams (Jimmy Bogard's MediatR pattern popularized this). Works well in event-driven systems where each event handler is a natural slice.

---

## Functional Core, Imperative Shell

Separate **pure business logic** (functional core) from **side effects** (imperative shell). The core is a collection of pure functions: given input, return output, no I/O. The shell handles all I/O (HTTP, database, file system) and feeds data into the core.

```
+-------------------------------------+
|         Imperative Shell             |
|  (HTTP handlers, DB queries, I/O)    |
|                                      |
|    input --> +----------------+      |
|              | Functional     |      |
|              |   Core         |      |
|              | (pure logic)   |      |
|    output <--+----------------+      |
|                                      |
|  (write results, send responses)     |
+-------------------------------------+
```

**Strengths**: Core logic is trivially testable (pure functions — no mocks, no setup, just input/output assertions). Side effects are contained and explicit. Reasoning about business logic is easier when it can't secretly talk to a database.

**Trade-offs**: Requires rethinking workflows that naturally interleave I/O and logic. Can lead to "data shuttle" patterns where the shell fetches everything upfront.

**Choose when**: Rust (ownership model naturally separates data from I/O — this pattern is idiomatic). Complex business rules that benefit from pure-function testing. The domain can be modeled as "gather data -> compute -> persist results" without mid-computation I/O.

**When not**: workflows that genuinely need mid-computation I/O (conditional fetches driven by intermediate results force a fetch-everything-upfront data shuttle), or CRUD with no rules worth isolating. Cost shape: buys the cheapest verification loop available — a pure core needs table-driven tests, no mocks, which is also the best fit for agent self-verification — paid for with shell complexity wherever I/O and logic truly interleave.

**Who uses it**: Elm (the Elm Architecture forces pure update functions with effects at the boundary), many Rust and Haskell projects. Gary Bernhardt's "Boundaries" talk (2012) codified the pattern. (Rust's ownership model makes the data-vs-I/O split natural for hot-path services — e.g., Discord moved its Read States hot path to Rust.)

---

## Service Architecture Decision Guide

```
Do you have significant business logic beyond CRUD?
+-- NO  -> Hexagonal (still default — keeps structure clean for when logic grows)
|         or Vertical Slice (if it's many independent endpoints)
+-- YES ->
    Is the team already using Clean Architecture conventions?
    +-- YES -> Clean Architecture (don't force a migration — same principles)
    +-- NO  ->
        Are features genuinely independent (minimal cross-feature logic)?
        +-- YES -> Vertical Slice (especially with CQRS)
        +-- NO  ->
            Is the domain modeled as pure computation?
            +-- YES -> Functional Core, Imperative Shell
            +-- NO  -> Hexagonal (default)
```

**Combining patterns** — these are not mutually exclusive:
- **Hexagonal + DDD**: Hexagonal structure with DDD tactical patterns (Aggregates, Value Objects, Domain Events) for complex domains.
- **Vertical Slice + CQRS**: Each command/query is a slice. Natural fit.
- **Hexagonal + Functional Core**: Domain layer in hexagonal *is* the functional core. Adapters = shell.
- **Vertical Slice + Hexagonal per slice**: Each slice internally follows hexagonal structure when the slice has complex logic.

**Agentic-development weights.** When the code's primary writers and maintainers are AI agents, the decision inputs above stay the same but two coefficients grow, because every agent session starts context-empty and reloads what a human would remember:

- **Context cost per edit becomes a first-order term.** The style choice sets how many files (≈ tokens) an agent must load to make one change: a slice localizes a feature edit to one directory; layer-first spreads it across L layers; pass-through ceremony multiplies it for nothing. Formally, prefer the decomposition minimizing E[cost] = Σ P(change) × spread(change) along the axis that *actually churns* — features churning → slices; adapters/providers churning → hexagonal ports.
- **The verification loop is part of the architecture.** Agents converge by iterating against fast deterministic feedback; a structure where each module/slice carries its own runnable test boundary (pure functional core, slice-scoped tests) multiplies effective agent capability, while whole-app-only verification starves it.

Two consequences, whatever you choose: **declare it** — record the style in `docs/arch/system.md` and the consuming project's agent context file, since an undeclared choice is re-guessed by every future session (and reviewers judge diffs against the *declared* style, not their own default); and **hold it consistently within the project** — agents induce conventions from neighboring code, so consistency is itself part of the prompt. Deviations are fine with an ADR.

---

## Cross-Cutting Patterns

### In-Process Domain Events

When side effects grow within a service, direct calls raise coupling. Refactor so the service emits domain events and independent handlers react — adding side effects no longer touches the originating service.

**Trade-off**: Flow spreads across files (harder to trace). Use sparingly — direct calls are fine for 1-2 side effects. Switch to events when adding a side effect requires modifying the originating service.

**Distinct from system-level events**: These are in-process, within a single service. Not Kafka/Queues — just an internal event bus or simple pub/sub pattern. For system-level event-driven architecture, see `system-architecture.md`.

### DDD Tactical Patterns

Domain-Driven Design tactical patterns can be applied **with any service architecture**. Use when the domain has complex business rules, invariants to protect, or rich behavior beyond data manipulation.

| Pattern | What | When |
|---|---|---|
| **Aggregate** | Cluster of entities treated as a single unit for data changes. Enforces invariants. | Data has complex consistency rules (e.g., Order + OrderItems must be consistent) |
| **Value Object** | Immutable object defined by its attributes, not identity | Money, Email, DateRange — anywhere equality is by value, not by reference |
| **Domain Event** | Record of something significant that happened in the domain | Other parts of the system need to react to domain state changes |
| **Repository** | Abstraction over data access, returns domain objects | Always — this is just the "driven port" in hexagonal terms |
| **Domain Service** | Logic that doesn't belong to a single entity | Cross-entity operations (e.g., transfer money between two accounts) |

**Don't over-apply DDD**: For simple CRUD domains, DDD tactical patterns add unnecessary abstraction. Use when the domain warrants it — complex rules, many invariants, rich behavior. "Is this entity just a data bag? Then skip Aggregate."

### Strategic Context Mapping

Tactical patterns structure code *inside* a context; **context mapping** governs the relationship *between* contexts — and those relationships are where change is absorbed or propagated, so name them explicitly when two contexts integrate. Canon: Evans (DDD), Vernon (IDDD).

| Relationship | What it means | Use when |
|---|---|---|
| **Anti-Corruption Layer (ACL)** | A translation layer keeping a foreign/legacy model from leaking into yours | Integrating a vendor or legacy system whose model you don't control |
| **Open-Host Service (OHS)** | A published, stable protocol many consumers integrate against | You are upstream to several consumers and want one contract, not N |
| **Published Language** | A shared, versioned schema (events/DTOs) at the boundary | Multiple contexts exchange data and must evolve compatibly |
| **Conformist** | Downstream adopts upstream's model as-is | Upstream won't negotiate and an ACL isn't worth the cost |
| **Shared Kernel** | A small shared model two teams co-own | Two contexts genuinely share a core concept and coordinate tightly |
| **Customer/Supplier** | Downstream's needs prioritized in upstream's planning | Upstream can flex; the dependency is a negotiated partnership |

ACL and OHS are the load-bearing boundary-protection patterns: an ACL stops upstream churn from forcing changes on you; an OHS lets you change internals without breaking consumers.

---

## Anti-Patterns

**Anemic Domain Model**: Domain entities are just data holders with getters/setters. All logic lives in services. You get the ceremony of domain modeling without the benefit — the domain can't protect its own invariants.

**Big Ball of Mud**: No discernible architecture. Everything imports everything. Starts as "move fast," ends as "can't change anything without breaking something else."

**Leaky Abstractions**: Domain layer imports infrastructure types (e.g., domain service takes a DB pool directly instead of a repository port). Defeats the purpose of architecture boundaries.

**Premature Abstraction**: Creating ports/adapters for things that will never change. YAGNI applies to architecture too.

**Shared Kernel Bloat**: The `shared/` or `common/` package grows to contain half the codebase. If everything is shared, nothing is isolated.
