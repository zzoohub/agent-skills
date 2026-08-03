# Context

**Date**: {date}
**PRD**: {link or title}

---

## 1. Problem

**What problem, for whom, why now** (one paragraph).

### Core Behaviors

Verb-centric list extracted from the PRD:
- [Actor] **searches** for [thing]
- [Actor] **creates** [thing]
- [System] **processes** [thing]

### Success Criteria

| Path | Target | Drives |
|---|---|---|
| e.g., API response (main flow) | p99 < 500ms | Caching? Query optimization? |
| e.g., Uptime | 99.5% (3.6h downtime/month) | Health checks, alerting, redundancy |
| e.g., Memory usage | < 50MB resident | Data structure choices, streaming |

---

## 2. System Boundary

What this system does and does not do.

- **Does**: [core capabilities — verb-centric]
- **Does not**: [explicit exclusions — prevents scope creep]
- **External connections**: [systems this integrates with]

D2 system context diagram (C4 Level 1) — the system as a black box showing actors, external systems, and data flows.

### Scale Envelope

Back-of-envelope, derivation shown so the arithmetic is checkable:

| Metric | Value | Derivation |
|---|---|---|
| Peak RPS (read / write) | ... | DAU × actions/day ÷ 86,400 × peak factor |
| Data growth | .../year | rows/day × bytes/row |
| Working set | ... | hot data actually queried |
| Largest payload | ... | ... |
| **Scale class** | S / M / L | gates pattern legitimacy in Stage 4 |

---

## 3. ASR & Utility Tree

### Architecturally Significant Requirements

| # | ASR | Filter | Rationale |
|---|---|---|---|
| 1 | ... | Business risk | ... |
| 2 | ... | Unusual quality | ... |

### Utility Tree

```
System Utility
+-- [Quality Attribute]
|   +-- "[Scenario]" [Importance, Difficulty]
|   +-- "[Scenario]" [Importance, Difficulty]
+-- [Quality Attribute]
    +-- "[Scenario]" [Importance, Difficulty]
```

**Architecture drivers** ([H,H] items):
1. ...
2. ...

### AI ASR
<!-- Include only if PRD involves AI/LLM features -->

| Question | Answer | Drives |
|---|---|---|
| Streaming required? | ... | ... |
| RAG needed? | ... | ... |
| Agent capabilities? | ... | ... |
| Cost ceiling? | ... | ... |
| Hallucination tolerance? | ... | ... |

---

## 4. Domain Model

### Domain Events

Past-tense verbs extracted from PRD:
- UserRegistered
- [Event]
- [Event]

### Bounded Contexts

D2 context map showing bounded contexts and their relationships.

| Context | Type | Owns | Key Entities | Sourcing |
|---|---|---|---|---|
| e.g., Matching | Core | Ranking, recommendation rules | Match, Score | Build — invest (hexagonal rigor) |
| e.g., Identity | Generic | Auth, sessions, profiles | User, Session | Self-host — audited auth library, our DB |
| e.g., Notifications | Generic | In-app feed, preferences | Notification | Build — plain CRUD, in-repo |
| e.g., Billing | Generic | Subscriptions, payments | Subscription, Invoice | Buy — Stripe + webhook adapter (PCI scope; ADR-00N) |

### Ubiquitous Language

| Term | Definition | Code Mapping |
|---|---|---|
| ... | ... | `EntityName`, `field_name` |

---

## 5. Constraints

- **Resource constraints**: [budget, infrastructure limits, team size]
- **Regulatory requirements**: [compliance, data residency]
- **Integration constraints**: [must integrate with X, must support protocol Y]
- **Deployment constraints**: [target platform, distribution method]

---

## 6. Assumptions

What the architecture depends on being true. If any assumption is invalidated, revisit the affected design decisions.

- ...
- ...
