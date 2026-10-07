# Architecture

**Date**: {date} · **Context**: `docs/arch/context.md`
**State**: greenfield | as-is recovered YYYY-MM-DD | target (transition: §4)

<!-- Keep every numbered § (other skills read them by number); write `n/a — reason` where one does not apply. Subsections are a menu: write those a non-skipped perspective or one-way door needs and omit the rest, heading included; light perspectives get one line. -->

---

## 1. Patterns

### System Pattern

**Chosen**: [pattern] — [why, citing QA ids]

**ATAM** ([H,H] drivers):

| QA id | Decisions / tactics (ADR) | Sensitivity / trade-off point | Evidence | Risk / non-risk |
|---|---|---|---|---|
| QA-01 | ... (ADR-NNN) | ... | analysis, measurement, spike, precedent (conditions) | non-risk because ...; breaks if ... |

### Service Pattern

**Per context class**: core [style]; supporting and generic [style]; exceptions [context → style].

### AI Platform
<!-- If AI features exist. -->

**Model access**: [port, gateway?] · **Providers & exit path**: [...] · **AI cost ceiling**: [...] · **Feature docs**: `docs/arch/ai-features/{feature}.md`

---

## 2. Components

### Core Technology

| Concern | Choice | Why | Rejected | Baseline (default / ADR) |
|---|---|---|---|---|

### Container Diagram

<!-- If Full rigor. AI containers: `references/ai/protocol.md` § Build-mode hooks. -->

C4 Level 2 as code: containers, protocols, external integrations, trust boundaries.

### Key Modules

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

| Store | Holds | Why | Consistency (per op) | Replication & read path | RPO/RTO, restore test |
|---|---|---|---|---|---|

### Data Inventory

| Data set | Writer (single) | Class | Every copy (incl. backups, logs, caches, indexes, processors, non-prod) | Retention & erasure | Residency | Consumers & read boundary |
|---|---|---|---|---|---|---|

### Tenancy
<!-- If multi-tenant. -->

**Isolation model per resource** · **enforcement points (≥ 2)** · **tenant lifecycle** · **cross-tenant tests**: [...]

### Partitioning
<!-- If a partition key shapes the architecture. -->

**Key per scaling dimension** · **hot partitions** · **rebalancing**: [...]

### Key Scenarios

**[Scenario]** (QA-..):

| Hop | Sync / async | Latency budget | Idempotency / ordering | On failure |
|---|---|---|---|---|

### Caching
<!-- If anything is cached. -->

**What · staleness bound · key (incl. tenant) · invalidation · sharing scope**: [...]

---

## 4. Deployment & Cost

### Deployment & Topology

| Unit | Runs where (region, site, device, client) | Failure domain | Trust zone | Scaling |
|---|---|---|---|---|

**Partition contracts** (each partition-prone link, per design-flow § Deployment View & Topology): [... — or none]

### Release Model

- **Operated**: [rollout, abort condition, rollback or roll-forward, flags, expand-contract, config releases]
- **Shipped / fleet**: [versioning, support and version-skew windows; rings, atomic update with fallback, kill switch]
- **Pipeline**: [gates, provenance, signing, dependency policy]

### Scaling Model

[scale-to-zero, autoscale or fixed; why; cold start]

### Scaling Ladder
<!-- If operated. -->

| Load | First bottleneck | Trigger metric (on a §5 dashboard) | Planned response |
|---|---|---|---|
| 10x | ... | ... | ... |
| 100x | ... | ... | One honest sentence is enough |

### Cost & Unit Economics

| Item | Baseline | Growth |
|---|---|---|
| Fixed floor | | |
| Per [demand unit] | | |
| At peak, incl. egress | | |
| **Unit cost vs target** | | |

**Idle** (money or energy at zero traffic): [list or "none"] · **cost guard**: [alert]
<!-- AI: one roll-up row per feature, its envelope vs the AI cost ceiling. -->

### Transition Plan
<!-- If re-architecture, modernization or system migration. -->

**As-is**: `docs/arch/as-is.md` · **Live step**: [n]

| Step | Components & disposition | Coexistence seam | Data mechanics | Driver levels held | Exit fitness function | Rollback trigger | Dual-run cost |
|---|---|---|---|---|---|---|---|

---

## 5. Cross-cutting

### Perspective Coverage

**Deep**: [perspective (QA ids); …] · **Light**: [perspective; …] · **Skipped**: [perspective (reason); …]

### Fitness Functions

| Property | QA id | Check | Cadence / where |
|---|---|---|---|
| Module boundaries | QA-.. | no access past a module's public interface or into its tables | per commit, CI |

Every [H,·] QA id has a guard here or in the SLO table.

### SLOs & Error Budgets
<!-- If operated. Burn-rate starting parameters: references/observability.md. AI: add the AI SLI set (references/ai/production.md), targets from the feature docs. -->

| SLI | QA id | Target | Budget | Page | Ticket | Owner | Runbook |
|---|---|---|---|---|---|---|---|
| `<from ASR>` | QA-.. | `<from ASR>` | `<1 − target>` | `<fast burn>` | `<slow burn>` | ... | ... |

### Write-path Integrity
<!-- If a write must not be lost, duplicated or interleaved. Binding on implementation. -->

| Command / consumer | Tx boundary | Outbox? | Idempotency (key / event id) | Concurrency control |
|---|---|---|---|---|

Rows answered "no" or "later" go to the Risk Register.

### Observability Contract
<!-- If operated; binding on implementation; checklist: references/observability.md. Software others run: diagnosability instead (same file). -->

**Signal per question** · **sampling** · **cardinality budget** · **redaction rule** · **semantic conventions (pinned version)** · **day-1 basics**: [...]

### Security
<!-- AI: include model-mediated flows. Deep: expand into the tables in references/security-privacy.md. -->

| Boundary / flow | Threat (STRIDE / LINDDUN) | Control | Guard |
|---|---|---|---|

**Authn / authz model per principal type**: [source, model, enforcement point]

**Secrets & keys**: [owner, rotation, revocation] · **compliance → evidence**: [if deep]

### Resilience

| Dependency | Deadline | Retry budget (one layer) | Isolation | If slow / down | Exercised |
|---|---|---|---|---|---|

**Overload policy**: [admission, shedding order, buffer bounds, client retry and reconnect contract]
<!-- Availability deep: add Detection and Blast radius columns and a DR posture line per tier. -->

### AI Authority
<!-- If AI takes actions. Cross-feature items only; per-action rows live in the feature docs. -->

**Agent identities · policy-enforcement points · approval queue · kill switch**: [... → feature doc links]
