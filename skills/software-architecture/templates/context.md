# Context

**Date**: {date} · **PRD**: {link or title}
**State**: greenfield | target | as-is recovered YYYY-MM-DD (claims tagged *observed* / *inferred*)
**Rigor**: Lite | Full — {why} · **Units**: {deployable}: {type}, operated | shipped | fleet

<!-- Keep every numbered § (other skills read them by number); write `n/a — reason` where one does not apply. Subsections are a menu: write those a non-skipped perspective or one-way door needs and omit the rest, heading included; light perspectives get one line. -->

---

## 1. Problem

**What problem, for whom, why now** (one paragraph). **Core behaviors**: [verbs from the PRD].

**Stakeholders & concerns**: [one line each: operators, compliance, integrators, ...]

### Success Criteria

| Path | Target | Drives |
|---|---|---|
| e.g., main read path | p99 < 500 ms | caching? query shape? |

---

## 2. System Boundary

- **Does**: [core capabilities — verbs]
- **Does not**: [explicit exclusions]
- **External connections**: [systems this integrates with]

System context diagram (C4 Level 1) as code: actors, external systems, data flows, trust boundaries.

### Scale Envelope

<!-- Existing system: measured from telemetry, source cited. -->

| Metric | Value | Derivation |
|---|---|---|
| Peak load, binding unit (read / write) | ... | Σ load sources × rate × peak factor |
| Burst shape, hottest-partition share | ... | ramp vs scale-out lead time; largest tenant or key |
| Provider quota headroom | ... | peak vs quota, in the provider's units |
| Unit cost at the p95/p99 user (if usage-priced) | ... | price × calls per successful task |
| Data growth, working set, largest payload | ... | ... |
| **Scale class** | S / M / L | vs one node's measured capacity (anchor, source) |

<!-- Software others run: rows become input size (typical / worst), start + process latency, memory / storage ceiling, platform matrix; no scale class. -->

- **Placement constraints**: [residency, on-prem, edge / offline — or none]
- **Top risks**: [three failure scenarios, with numbers]
- **Lifespan & phase**: [prototype, product or platform; expected life]
- **Calibration** (one line each; unknown → A-nn): exposure, criticality, data sensitivity, tenancy, run model, teams, external consumers, reach, hazard, usage-priced dependencies, AI

---

## 3. ASR & Utility Tree

```
System Utility
+-- Performance
|   +-- QA-01 "When 500 users search concurrently at peak, results return in < 1 s p99" [H,H] · filter: unusual quality · serves: {goal}
+-- Evolvability (change scenarios)
    +-- QA-02 "When a second payment provider is added, at most one module changes" [H,M] · filter: cross-cutting
```

**Drivers** ([H,H]): QA-01, ... · **Top attributes, ranked**: [...] · **Conflicts**: [A vs B → ADR-NNN]

<!-- AI: write its drivers as scenarios here (tolerated error, cost per successful task, latency, authority), not mechanisms. -->

---

## 4. Domain Model

### Bounded Contexts

| Context | Type | Owns | Owner | Hides | Sourcing |
|---|---|---|---|---|---|
| e.g., Matching | Core | Match, Score | team A | ranking rules | Build — invest |
| e.g., Billing | Generic | Invoice | team B | provider | Buy — payment processor + webhook adapter (liability transfer; ADR-00N) |

<!-- Event-stormed contexts: events → aggregates → commands → external triggers, under the context map. -->

Context map as code; label each edge with its relationship (`references/service-architecture.md` § Strategic Context Mapping) and sync / async.

### Ubiquitous Language

| Context | Term | Definition | Code Mapping |
|---|---|---|---|

---

## 5. Constraints

- **C-01 Technology baseline**: [mandate, incumbent stack, house profile (name, last verified) or none] + the adopted profile's context fields
- **C-02 Team & resources**: [skills, on-call limits, budget, infrastructure]
- **C-03 Regulatory**: [regimes the caller names, residency, audit duties]
- **C-04 Integration**: [must integrate with X, support protocol Y]
- **C-05 Deployment**: [target platforms, distribution channel]

<!-- One C-nn per constraint; add C-06+ as needed. -->

---

## 6. Assumptions

| A-nn | Assumption | Confidence (H / M / L) | Validation (spike, measurement, ask) | Dependent ADRs | Decide-by |
|---|---|---|---|---|---|
