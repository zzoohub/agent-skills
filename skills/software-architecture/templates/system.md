# Architecture

**Date**: {date} · **Context**: `docs/arch/context.md`
**State**: greenfield | as-is recovered YYYY-MM-DD | target (transition: §4)

<!-- Budget below this header, tables included, diagram source excluded: Small ≈ 900 · Standard ≈ 2,500 · Large ≈ 4,500 words. The budget sizes the record, never the analysis.
     Binding on implementation. Keep every numbered § (other skills read them by number); write `n/a — reason` where one does not apply. Subsections are a menu: write those where something was decided and omit the rest, heading included.
     Tables hold decisions, not inventory: state the default once as a rule line, add rows only for departures and product decisions, keep each cell to a phrase. -->

---

## 1. Patterns

### System Pattern

**Chosen**: [shape] — [why, citing driver ids]

### Decisions

Every one-way door, and each default worth knowing; one line each.

| Decision | Door | Why (driver or default) | Revisit when | ADR |
|---|---|---|---|---|
| e.g. Modular monolith, one PostgreSQL primary | two-way | default at class S | writes > 30% of one primary's measured capacity | — |
| e.g. Pooled tenancy with row-level policies | one-way | D-05; 2,000 small tenants | a tenant demands a dedicated store by contract | ADR-003 |

### Driver Coverage

| Driver | Decisions | Most sensitive to | Evidence | Holds unless |
|---|---|---|---|---|
| D-01 | … | parameter and its setting | analysis shown · measurement · spike SP-nn · precedent with matching conditions | … (or: at risk → `risks.md`) |

### Service Pattern

**Per context**: core [style]; supporting and generic [style]; exceptions [context → style].

### AI Platform
<!-- If AI features exist. Only what features share. -->

**Model access**: [port, gateway?] · **Providers & exit path**: […] · **AI cost ceiling**: […] · **Feature docs**: `docs/arch/ai-features/{feature}.md` (written) · {feature} (owed)

---

## 2. Components

### Core Technology

| Concern | Choice | Why | Rejected (only if contested) | Baseline or ADR |
|---|---|---|---|---|

### Container Diagram
<!-- If more than one deployable or trust zone. -->

Containers, protocols, external integrations, trust boundaries, as code.

### Key Modules

<!-- One team: say so here once and leave Owner out of the rows. -->

| Module | Owns | Owner | Hides |
|---|---|---|---|

### Published Contracts
<!-- If anything outside the deployable depends on it. -->

| Surface | Consumers | Compatibility policy | Guard (CI check) |
|---|---|---|---|

**Error contract, pagination default**: [RFC 9457 or equivalent; cursor]

---

## 3. Data

### Stores

| Store | Holds | Why | Consistency (per operation) | Replication & read path | RPO / RTO, restore test |
|---|---|---|---|---|---|

### Data Inventory

<!-- One row per personal or regulated data set, and per set with an unusual duty; one last row for everything else. -->

| Data set | Writer (single) | Class | Every copy (backups, logs, caches, indexes, processors, non-prod) | Retention & erasure | Residency |
|---|---|---|---|---|---|

### Tenancy
<!-- If multi-tenant. -->

**Isolation model per resource** · **enforcement points (≥ 2)** · **tenant lifecycle** · **cross-tenant tests**: […]

### Partitioning
<!-- If a partition key shapes the architecture. -->

**Key per scaling dimension** · **hot partitions** · **rebalancing**: […]

### Key Scenarios

<!-- The main journey, plus any driver that depends on order or timing. One or two. -->

**[Scenario]** (D-..):

| Hop | Sync / async | Latency budget | Idempotency / ordering | On failure |
|---|---|---|---|---|

### Caching
<!-- If anything is cached. -->

**What · staleness bound · key (incl. tenant) · invalidation · who shares it**: […]

---

## 4. Deployment & Cost

### Deployment & Topology

| Unit | Runs where (region, site, device, client) | Failure domain | Trust zone | Scaling (fixed / autoscaled / to zero; cold start) |
|---|---|---|---|---|

**Partition contracts** (each partition-prone link: on disconnect, buffer bound, expiry, dedup key): [… — or none]

### Release Model

- **Operated**: [rollout unit, abort condition, rollback or roll-forward, flags, expand-contract, config releases]
- **Shipped / fleet**: [versioning, support and version-skew windows; rings, atomic update with fallback, kill switch]
- **Pipeline**: [gates, provenance, signing, dependency policy]

### Scaling Ladder
<!-- If operated. -->

| Load | First bottleneck | Trigger metric (on a dashboard) | Planned response |
|---|---|---|---|
| 10× | … | … | … |
| 100× | … | … | One honest sentence is enough |

### Cost & Unit Economics

<!-- Say once whether the amounts are measured, derived from list prices (source, date) or targets. -->

| Item | Baseline | Growth |
|---|---|---|
| Fixed floor | | |
| Per [demand unit] | | |
| At peak, incl. egress | | |
| **Unit cost vs target** | | |

**Idle** (money or energy at zero traffic): [list or "none"] · **cost guard**: [alert]
<!-- AI: one roll-up row per feature, its envelope vs the AI cost ceiling. -->

### Transition Plan
<!-- If re-architecture or system migration. -->

**As-is**: `docs/arch/as-is.md` · **Live step**: [n]

| Step | Components & disposition | Coexistence seam | Data mechanics | Driver levels held | Exit check | Rollback trigger | Dual-run cost |
|---|---|---|---|---|---|---|---|

---

## 5. Cross-cutting

### Concerns

**Deep**: [concern (driver ids); …] · **Light**: [concern: its one line; …] · **Skipped**: [concern (reason); …]

### Guards

| Property | Driver | Check and threshold | Cadence / where |
|---|---|---|---|
| Module boundaries | D-.. | no import past a module's public interface, no access to its tables | per commit, CI |

Every driver has a guard here or in the SLO table.

### SLOs & Error Budgets
<!-- If operated. Only what users feel, tied to a driver. Burn-rate parameters: references/observability.md. AI: add the indicators each AI feature doc names. -->

| SLI | Driver | Target | Page (fast burn) | Ticket (slow burn) | Owner (role) | Runbook |
|---|---|---|---|---|---|---|

### Write-path Integrity
<!-- If a write must not be lost, duplicated or interleaved. -->

**Default** (every command not listed): [e.g. one transaction in the use case; client idempotency key; version column on the aggregate root; side effects through the outbox]

| Command / consumer with an invariant at stake | Tx boundary | Outbox? | Idempotency (key / event id) | Concurrency control |
|---|---|---|---|---|

Anything answered "later" goes to the Risk Register.

### Observability Contract
<!-- If operated. Software others run: diagnosability instead (references/observability.md). -->

**Signal per question** · **sampling** · **cardinality budget** · **redaction rule** · **semantic conventions (pinned version)** · **day-1 basics**: […]

### Security
<!-- Material crossings only: those that defeat a driver, cross a tenant boundary, touch money or regulated data, or cannot be undone. AI: include model-mediated flows. -->

| Boundary / flow | Threat | Control | Guard |
|---|---|---|---|

**Authn / authz per principal type**: [source, model, enforcement point]

**Secrets & keys**: [owner, rotation, revocation] · **compliance → evidence**: [if deep]

### Resilience

**Default** (every dependency not listed): [e.g. deadline from the request budget; one retry on timeout or throttling, in the adapter; concurrency cap per dependency]

| Dependency with a designed degraded mode | Deadline | If slow / down (what the user sees) | Exercised by (drill, cadence) |
|---|---|---|---|

**Overload policy**: [admission, shedding order, buffer bounds, client retry and reconnect contract]

### AI Authority
<!-- If AI takes actions. Cross-feature items only; per-action rows live in the feature docs. -->

**Agent identities · policy-enforcement points · approval queue · kill switch**: [… → feature doc links]
