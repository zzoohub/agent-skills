# System Architecture Patterns

System architecture defines **what components exist and how they connect** — service communication, infrastructure topology, data flow between components, and cross-cutting infrastructure decisions.

For internal service structure (layers, domain isolation, code organization), see `service-architecture.md`.

## Table of Contents
- **Communication Patterns** — Request-Response, EDA, CQRS, Event Sourcing, Saga, Modular Monolith
- **Composition Decision Flowchart** + Real-World Architecture Compositions
- **Additional Patterns** — Strangler Fig, BFF, Cell-based, Event Lakehouse
- **Anti-Patterns**
- **Cross-Cutting Architecture Decisions** — Multi-Tenancy, Real-Time, API Versioning, Event Schema Evolution, Feature Flags

---

## Communication Patterns

### Request-Response (Synchronous)

The default. Service A calls Service B, waits for the answer, continues.

```
Client -> API Gateway -> Service A -> Service B -> DB
                                    <- response <-
```

**Strengths**: Simple to reason about, easy to debug, straightforward error handling, strong consistency natural.
**Trade-offs**: Temporal coupling (caller blocks), cascading failures, harder to scale independently.
**Choose when**: CRUD-dominant apps, simple data flows, small number of services, strong consistency required everywhere.
**When not**: one action must fan out to several independent reactions — each new side effect edits the calling chain (the coupling EDA removes) — or traffic is spiky enough that synchronous back-pressure cascades failures downstream.

**Who uses it**: Most startups, early-stage products. Stripe's core payment flow is synchronous by design — money movement needs strong consistency.

### Event-Driven Architecture (EDA)

Services communicate by producing and consuming events asynchronously. No service waits for another.

```
Service A --publishes--> Event Broker --delivers--> Service B
                        (Kafka/NATS)  --delivers--> Service C
```

**Strengths**: Loose coupling, services scale independently, natural fault isolation, excellent for fan-out (one event -> many consumers), handles traffic spikes via buffering.
**Trade-offs**: Eventual consistency, harder to debug (distributed tracing essential), event ordering complexity, requires message broker infrastructure.
**Choose when**: Multiple consumers need to react to the same event, traffic is spiky, you need async processing (notifications, analytics, ML pipelines), or services must evolve independently.
**When not**: read-after-write consistency is required at most boundaries, or the system is small enough that broker infrastructure plus eventual-consistency debugging costs more than the decoupling returns. Cost shape: adding a consumer costs zero producer edits, but every flow becomes distributed — trace spread replaces call-stack locality.

**Who uses it**:
- **Netflix**: Kafka processes trillions of events/day — playback telemetry, recommendations, A/B test results, analytics all flow as events.
- **Uber**: Real-time pricing, fraud detection, trip state management all event-driven via Kafka + Flink.
- **Slack**: Message delivery, indexing, and notifications propagated as events through Kafka.

### CQRS (Command Query Responsibility Segregation)

Separate the write model (commands that change state) from the read model (queries that return data). Each can be independently optimized.

```
             +-- Command Model --> Write DB (normalized)
User Input --+                         |
             |                    sync/async projection
             |                         v
             +-- Query Model  <-- Read DB (denormalized, optimized)
```

**Strengths**: Read and write sides scale independently, read models optimized per use case, natural fit for read-heavy systems.
**Trade-offs**: Increased complexity (two models to maintain), eventual consistency between read and write sides, more infrastructure.
**Choose when**: Read/write ratio is heavily skewed (10:1+), different consumers need different views of the same data, or you need to optimize read performance without compromising write consistency.
**When not**: read and write shapes are essentially the same — two models make every schema change a double edit plus projection upkeep, with no read-side win to pay for it.

**Who uses it**:
- **Netflix**: their personalization pipeline is CQRS-like — viewing events feed a write path, while reads serve pre-computed recommendation lists per device type (Netflix's own term for this is offline/nearline/online computation; its explicitly-documented CQRS system is Tudum, the companion content site).
- Financial systems where audit trails (write side) and reporting dashboards (read side) have completely different performance characteristics.

### Event Sourcing

Instead of storing current state, store the sequence of events that led to the current state. State is derived by replaying events.

```
Event Store: [OrderCreated] -> [ItemAdded] -> [PaymentProcessed] -> [Shipped]
Current state = replay all events (or read from snapshot + recent events)
```

**Strengths**: Complete audit trail for free, time-travel debugging (reconstruct state at any point), natural fit for domains where history matters.
**Trade-offs**: Complexity spike (snapshots needed for performance, schema evolution is hard, querying current state requires projections), high learning curve, significantly more infrastructure.
**Choose when**: Audit trail is a regulatory requirement, the domain is inherently event-based (finance, logistics, collaborative editing), or you need time-travel/undo capabilities.
**When not**: nothing in the domain requires history — the complexity floor is permanent (every schema change becomes event versioning forever); see the warning below.

**Who uses it**:
- **Stripe**: Payment state transitions stored as events — enables dispute resolution, audit compliance, and exact state reconstruction.
- Banking and fintech where every state change must be auditable and reversible.

**Warning**: Event sourcing is powerful but adds substantial complexity. Don't adopt it just because it sounds elegant. Most applications are better served by EDA + a good audit log table.

### Saga Pattern (Distributed Transactions)

Coordinates multi-service transactions through a sequence of local transactions, each publishing events for the next step. If a step fails, compensating transactions undo previous steps.

```
Order Service --> Payment Service --> Inventory Service
    |                  |                     |
    <-- compensate <-- compensate <--- (on failure)
```

**Two variants**:
- **Choreography**: Each service listens for events and knows what to do next. Simpler but harder to track overall flow.
- **Orchestration**: A central coordinator tells each service what to do. More explicit control but introduces a single point of coordination.

**Choose when**: You have distributed transactions across multiple services that need to be eventually consistent. Alternative: if you can avoid distributed transactions by keeping data in one service, always prefer that.
**When not**: the data can live in one service (a local transaction has none of the compensation state-space), or the flow's value doesn't justify designing and testing N compensating paths — each saga step multiplies the failure states that need coverage.

**Who uses it**:
- **Uber**: Trip lifecycle (match rider -> assign driver -> process payment -> rate) is an orchestrated saga.
- Any e-commerce checkout flow that spans order, payment, and inventory services.

### Modular Monolith

One deployable unit, but internally organized into strictly isolated modules with clear boundaries. Modules communicate through well-defined interfaces (function calls, internal events), not direct database access.

```
+------------------------------------------+
|              Single Deployment            |
|  +------+  +------+  +------+           |
|  | Auth |  |Orders|  |Notify|           |
|  |Module|  |Module|  |Module|           |
|  +--+---+  +--+---+  +--+---+           |
|     +----internal API----+               |
|              Shared DB (schema-separated) |
+------------------------------------------+
```

**Strengths**: Simple deployment and ops, no network overhead between modules, easy local development, can extract to microservices later if needed.
**Trade-offs**: Must enforce module boundaries with discipline (easy to cheat), scales as a whole unit, shared database can become a coupling point.
**Choose when**: Small team (1-5 engineers) — or a solo founder driving agents — you want domain separation without microservice overhead, or you're at a stage where operational simplicity matters more than independent scaling. Module boundaries contain a bad edit (human or agent) the same way service boundaries do, at zero network cost.
**When not**: modules genuinely need independent scaling or deploy cadence (the single deploy train becomes the bottleneck), or org size makes one release queue untenable.

**Who uses it**:
- **Shopify**: Started as a monolith, evolved to a modular monolith (Rails + Packwerk enforcing module boundaries) before selective extraction to services.
- **GitHub**: A large Rails monolith that invested in internal modular boundaries rather than splitting into microservices.

---

## Composition Decision Flowchart

```
Is this a single-purpose service or product?
+-- YES -> Modular Monolith or Single Service
|         Does it need async processing (notifications, analytics, ML)?
|         +-- YES -> Add event-driven for those flows (Hybrid)
|         +-- NO  -> Request-Response is fine
+-- NO (multiple services) ->
    Do services need to react to shared events?
    +-- YES -> Event-Driven (with Saga for distributed transactions)
    +-- NO  -> Request-Response between services

    Is read/write ratio heavily skewed (10:1+)?
    +-- YES -> Consider CQRS for read-heavy paths
    +-- NO  -> Standard data access

    Is full audit trail / state history a hard requirement?
    +-- YES -> Event Sourcing for that domain
    +-- NO  -> Don't add it
```

---

## Real-World Architecture Compositions

| Company | System Architecture | Code Structure | Key Insight |
|---|---|---|---|
| **Netflix** | Microservices + Event-Driven (Kafka) + CQRS-like read paths (e.g., Tudum) | Varies per service; some teams (e.g., Studio Engineering) use ports-and-adapters/hexagonal | Different patterns per domain. Playback is sync; analytics is event-driven; some read-heavy domains use CQRS-style read/write separation. |
| **Uber** | Microservices organized by domain (DOMA) + Event-Driven + Saga (trip lifecycle) | Domain-driven internally | Organize services by business domain, not technical layer. Orchestrated sagas for multi-service transactions. |
| **Stripe** | SOA + Event Sourcing (payment state) + Request-Response (API surface) | Clean/hexagonal per service | Synchronous API surface, event-sourced internals for audit. Design docs before code. |
| **Toss** (Toss Bank) | Microservices (MSA) + Event-Driven (Kafka) | Spring Boot/Kotlin per service | Migrated core banking from a monolith to MSA for independent scaling and fault isolation. |
| **Discord** | Microservices + hybrid sync/async | Rust for hot paths, Elixir for real-time | Choose language per service based on performance profile. |
| **Shopify** | Modular Monolith -> selective extraction | Rails conventions | Start monolithic, extract only when data proves the boundary. |
| **Airbnb** | Monolith -> SOA by domain boundary | Service-specific | Split only when natural domain boundaries are clear. |

---

## Additional Patterns

### Strangler Fig (Legacy Migration)

Incrementally replace a legacy system by routing traffic through a facade that delegates to either old or new code per feature.

```
Client --> Facade/Router
             |-- /new-feature --> New Service
             |-- /old-feature --> Legacy System
             (gradually migrate routes from legacy to new)
```

**Strengths**: Zero big-bang risk, ship incremental value, old system keeps running during migration.
**Trade-offs**: Facade adds complexity and latency, two systems to maintain in parallel.
**Choose when**: Replacing an existing system that can't be rewritten from scratch. This is almost always the right approach for legacy migration.

**Who uses it**: Shopify (monolith extraction), Amazon (from monolith to SOA), Airbnb (SOA migration).

### Backend-for-Frontend (BFF)

A dedicated backend service per frontend client type. Each BFF aggregates, transforms, and serves data in the shape its client needs.

```
Web App    --> Web BFF    --> Backend Services
Mobile App --> Mobile BFF --> Backend Services
```

**Strengths**: Each client gets an API tailored to its needs, frontend teams can iterate independently.
**Trade-offs**: Code duplication across BFFs, more services to maintain.
**Choose when**: Web and mobile clients have significantly different data needs, or you want to decouple frontend release cycles from backend.

**Who uses it**: Netflix (per-device BFFs), SoundCloud (pioneered the pattern), Spotify.

### Cell-based Architecture

Partition the system into independent, self-contained cells. Each cell serves a subset of users/tenants and contains a full copy of the service stack.

```
+--- Cell A (users 1-1000) ---+  +--- Cell B (users 1001-2000) --+
|  API -> Service -> DB        |  |  API -> Service -> DB          |
+------------------------------+  +--------------------------------+
         Router / Cell Gateway
```

**Strengths**: Blast radius limited to one cell, scales horizontally by adding cells.
**Trade-offs**: Data isolation means cross-cell queries are hard, operational overhead of managing many cells.
**Choose when**: You need to limit blast radius (regulatory or high-availability requirements), or you're at a scale where a single deployment unit is a risk.

**Who uses it**: AWS (cell-based architecture is a core AWS resilience pattern, used internally by many of its highest-availability services), DoorDash, Slack.

### Event Lakehouse

Replace traditional data warehouses with an object-storage-native analytics pipeline.

```
App events -> Queue/Stream -> Transform -> Object Storage (Parquet/Iceberg) -> SQL Engine
                                                 |
                                           Dashboard / BI tool
```

**Strengths**: Pay-per-query, storage and compute scale independently, open formats (no vendor lock-in).
**Trade-offs**: Query latency higher than a dedicated warehouse (seconds, not milliseconds). Not for real-time dashboards.
**Choose when**: You need analytics beyond what simple aggregation queries provide, or data volume grows past what a single database handles comfortably.

---

## Anti-Patterns

**Distributed Monolith**: Microservices that can't deploy independently because they share a database or have synchronous call chains. Worse than a monolith — all the complexity, none of the benefits.

**Event Sourcing Everywhere**: Using event sourcing for domains where a simple audit log table would suffice. Reserve it for domains where state history is a core requirement.

**Premature CQRS**: Adding read/write separation when your read/write ratio is 2:1 and a single database handles both fine. CQRS adds operational overhead — justify it with data.

**Pattern Resume-Driven Development**: Choosing microservices + event sourcing + CQRS + Kubernetes for a todo app because the tech stack looks impressive. Match complexity to the problem.

---

## Cross-Cutting Architecture Decisions

### Multi-Tenancy

How to isolate data and compute between tenants (customers, organizations, workspaces).

| Model | Isolation Level | Complexity | Cost | Choose When |
|---|---|---|---|---|
| **Shared everything** (tenant_id column) | Logical | Low | Lowest | Early stage, < 100 tenants, no compliance requirements |
| **Schema-per-tenant** | Schema | Medium | Medium | Stronger isolation needed without separate databases |
| **Database-per-tenant** | Physical | High | Highest | Regulatory requirements (data residency), enterprise customers demanding full isolation |

**Default**: Shared everything with `tenant_id` on every table + Row-Level Security (RLS). This covers 90% of SaaS products. RLS enforces isolation at the database level — application bugs can't leak data across tenants.

**Who uses it**: Slack (workspace-per-tenant, shared infrastructure), Salesforce (shared database with org isolation), Neon (purpose-built to make database-per-tenant cheap for its customers via scale-to-zero).

### Real-Time Communication

Patterns for bidirectional or push-based communication beyond LLM streaming (for LLM-specific streaming, see `references/ai-architecture.md` § Streaming Architecture).

| Protocol | Direction | Use Case | Complexity |
|---|---|---|---|
| **SSE (Server-Sent Events)** | Server -> Client | Notifications, live feeds, status updates | Low |
| **WebSocket** | Bidirectional | Chat, collaborative editing, gaming, live dashboards | Medium |
| **WebTransport** | Bidirectional | Low-latency, multiplexed streams (next-gen WebSocket) | High |

**Architecture decision**: SSE handles most "real-time" needs. Use WebSocket only when the client needs to send frequent messages to the server. Don't use WebSocket just because "it's real-time."

**Connection management**: WebSocket connections are stateful. Plan for: reconnection with message replay, heartbeat/ping-pong for dead connection detection, graceful connection draining during deployments, and connection limits per instance.

### API Versioning Strategy

How to evolve APIs without breaking existing clients.

| Strategy | Mechanism | Trade-off |
|---|---|---|
| **URL path versioning** (`/v1/users`) | Version in URL | Simple and explicit. But proliferates endpoints. |
| **Header versioning** (`Accept: application/vnd.api+json;version=2`) | Version in header | Cleaner URLs. But less visible, harder to test. |
| **Query parameter** (`/users?version=2`) | Version in query | Easy to default. But mixes concerns. |
| **No versioning (additive only)** | Never break, only add | Zero overhead. Requires discipline. |

**Default for most products**: **Additive changes only**. Add new fields, never remove or rename existing ones. This eliminates versioning complexity entirely.

**When to version**: Breaking changes to core resources, fundamental data model changes, or when supporting enterprise clients with long upgrade cycles.

### Event Schema Evolution

When using event-driven architecture, event schemas will change over time.

| Strategy | How It Works | When |
|---|---|---|
| **Additive only** | Never remove or rename fields, only add new ones | Default. Covers 90% of cases. |
| **Versioned events** | `OrderCreatedV1`, `OrderCreatedV2` as separate event types | Breaking changes to event structure |
| **Schema envelope** | Wrap payload in `{ version, schema, data }` | Multiple consumers at different versions |

**Key rules**:
- **Producers** must be backward compatible — old consumers should still work with new events
- **Consumers** must be forward compatible — ignore unknown fields
- **Never delete fields** that consumers might depend on. Deprecate first, remove after all consumers are updated.

### Feature Flag Architecture

Decouple deployment from release. Ship code to production without exposing it to users until ready.

**Use cases**:
- **Gradual rollout**: Release to 1% -> 10% -> 50% -> 100% of users
- **Kill switch**: Instantly disable a broken feature without redeployment
- **A/B testing**: Route users to different feature variants
- **Entitlements**: Gate features by plan tier (free, pro, enterprise)

**Architecture**:
```
Client/Server --> Flag evaluation (local SDK) --> Flag configuration store
```

**Key decisions**:
- **Server-side vs client-side evaluation**: Server-side for security-sensitive flags. Client-side for UI experiments where latency matters.
- **Flag lifecycle**: Every flag should have an owner and an expiration date. Permanent flags (entitlements) are fine; temporary flags (rollouts) that linger become tech debt.
- **Default values**: Always define a safe default (typically `false` / control variant) for when the flag service is unreachable.
