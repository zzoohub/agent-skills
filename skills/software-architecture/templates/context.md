# Context

**Date**: {date} · **Requirements**: {link or title} · **Size**: Small | Standard | Large — {why}
**State**: greenfield | target | as-is recovered YYYY-MM-DD (claims tagged *observed* / *inferred*)
**Units**: {deployable}: {type}, operated | shipped | fleet — {its forcing question answered in one clause}
**Built and run by**: people | agents | both

**Summary** (≤ 100 words): the shape in one sentence · the two or three facts that decide it · what must be proven first · what the caller still owes.

<!-- Budget below this header, tables included, diagram source excluded: Small ≈ 600 · Standard ≈ 1,500 · Large ≈ 2,500 words. The budget sizes the record, never the analysis.
     Keep every numbered § (other skills read them by number); write `n/a — reason` where one does not apply. Subsections are a menu: write those a decision needs and omit the rest, heading included. -->

---

## 1. Problem

**What problem, for whom, why now** (one paragraph). **Core behaviors**: [verbs from the requirements].

**Stakeholders & concerns**: [one line each, only those whose concern changes the design]

### Success Criteria

| Path | Target | Drives |
|---|---|---|
| e.g. main read path | p99 < 500 ms | caching? query shape? |

---

## 2. System Boundary

- **Does**: [core capabilities, as verbs]
- **Does not**: [explicit exclusions]
- **External connections**: [systems this integrates with]

System context diagram as code: actors, external systems, data flows, trust boundaries.

### Scale Envelope

<!-- Say once whether the numbers are measured (source), derived (inputs shown) or assumed. -->

| Metric | Value | Derivation |
|---|---|---|
| Peak load, binding unit (read / write) | … | Σ sources × rate × peak factor |
| Burst shape, hottest-partition share | … | ramp vs scale-out lead time; largest tenant or key |
| Provider quota headroom | … | peak vs quota, in the provider's units |
| Unit cost for the p95 user vs price (if usage-priced) | … | price × calls per successful task |
| Data growth, working set, largest payload | … | … |
| **Scale class** (per tier where they differ) | S / M / L | vs one node's capacity in the binding unit (anchor, source) |

<!-- Software others run: rows become input size (typical / worst), start + process latency, memory ceiling, platform matrix; no class. -->

- **Placement**: [residency, on-prem, edge, offline clients — or none]
- **Top risks**: [three failure scenarios, with numbers]
- **Lifespan & phase**: [prototype, product or platform; expected life]
- **Profile** (a few words each; "none" is an answer; unknown → A-nn): exposure · criticality · data sensitivity · tenancy · run model · teams · external consumers · reach · hazard · usage-priced dependencies · AI

---

## 3. Drivers

Three to seven, ranked; each forces a structural decision.

| D-nn | Scenario (one sentence, with its number) | Source | Serves |
|---|---|---|---|
| D-01 | When 500 users search concurrently at peak, results return in < 1 s p99 | unusual quality level | {goal} |
| D-02 | When a second payment provider is added, at most one module changes | change scenario | {goal} |
| D-03 | When the payment provider is slow for 10 min, checkout degrades to queued orders with no double charge | failure scenario | {goal} |

**Conflicts**: [D-01 vs D-04 → ADR-NNN]

<!-- AI: write its drivers as scenarios here (tolerated error, cost per successful task, latency, authority), never as mechanisms. -->

---

## 4. Domain Model

### Bounded Contexts

| Context | Type | Owns (data) | Owner | Hides | Sourcing |
|---|---|---|---|---|---|
| e.g. Matching | Core | Match, Score | team A | ranking rules | Build — invest |
| e.g. Billing | Generic | Invoice | team B | provider | Buy — payment processor behind an adapter (liability transfer; ADR-00N) |

Context map as code; label each edge with its relationship and sync / async.

### Ubiquitous Language

<!-- Only terms a newcomer would get wrong, or that mean different things in two contexts. -->

| Context | Term | Definition | Code mapping |
|---|---|---|---|

---

## 5. Constraints

- **C-01 Technology baseline**: [mandate, incumbent stack, house profile (name, last reviewed) or none]
- **C-02 Team & resources**: [skills, on-call limits, budget]
- **C-03 Regulatory**: [regimes the caller names, residency, audit duties]
- **C-04 Integration**: [must integrate with X, support protocol Y]
- **C-05 Deployment**: [target platforms, distribution channel]

<!-- One C-nn per constraint; add C-06+ as needed. -->

---

## 6. Assumptions

<!-- Only what a one-way door, a driver's number or the cost model rests on. Anything else is a default the implementer may change. -->

| A-nn | Assumption | Confidence (H / M / L) | Validation (spike, measurement, ask) | Dependent ADRs | Decide-by |
|---|---|---|---|---|---|
