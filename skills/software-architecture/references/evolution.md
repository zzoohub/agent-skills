# Evolving an Existing System

Read whenever work starts from a running system: Build Mode on an existing system, or any request that must first recover the as-is from code without docs. Routing, stage re-entry and patch-never-regenerate live in `SKILL.md` § Modes & Routing.

## As-is Recovery

**Forcing question**: what is actually running, how does it behave under real load, and why is each structure the way it is?

**Scope it to the request.** One decision, one AI feature or an extension: recover the containers, stores and integrations it touches, plus C4 L1. A re-architecture, modernization, system migration, or a review with no docs: recover the whole system. When docs exist, drift-check their load-bearing claims first (the drift check in `SKILL.md` § Review / Diagnose Mode) and recover only what drifted; never design from stale docs.

| Source | What it shows |
|---|---|
| Build and deploy config | Deployment units, runtimes, environments, scheduled jobs, secret wiring |
| Schema and its migration history | Stores, entities, which code writes which tables, access clusters |
| Source and its dependency graph | Containers, modules, integrations, call paths, cycles |
| Version history | Co-change clusters (the real boundaries) and churn hotspots |
| Telemetry | Rates, volumes, per-hop latency and errors, queue ages, data growth |
| Incident history and runbooks | Fragile paths, manual operations, failures already paid for |
| Knowledge holders | Intent, undocumented constraints, why each structure exists |

**Record**, at the scope above:
- **Containers, deployment units and integrations** — inbound feeds, partner calls, batch and scheduled jobs, and every published contract with its consumers (the consumer inventory for `design-flow.md` § Published Contracts).
- **Stores and their writers** — each data set with its writers, readers and copies; more than one writer is already a finding.
- **Module dependencies** — cycles and cross-context table access mark the seams that will resist; co-change and access clusters are Stage 3's evidence for contexts.
- **Measured envelope** — from telemetry, not estimates (`design-flow.md` § Quantitative Envelope), plus the per-hop latency and error breakdown of each [H,H] path, so the design attacks the measured bottleneck instead of a guessed one. Where telemetry cannot answer, a measurement spike is the first step.
- **Hotspots** — where incidents and co-change concentrate; they order the transition.
- **Violations to fix first** — unguarded read-modify-write, non-idempotent consumers, calls without deadlines, enqueue-before-commit, several writers per data set, and time-window assumptions (a nightly batch, a maintenance window) that a new region or round-the-clock operation removes. They seed the Transition Plan's first steps.

**Rules**:
- Tag every claim *observed* (seen in code, config or telemetry) or *inferred* (deduced; confirm it before a one-way door rests on it).
- **Chesterton's fence** — know why a structure exists before removing it: ask the knowledge holders or find the incident or constraint behind it. Unknown → an Open Question, not a deletion.
- Drivers the code cannot show (business goals, contractual targets, regulatory duties, team plans) → `A-nn` assumptions in `context.md` §6 or Open Questions in `risks.md`.
- Foundational decisions found in code that the target **keeps** → retroactive ADRs via arch-decision's gap-fill, if available. Decisions the target **reverses** get none: record "as-is: X since …" in the Context of the ADR that supersedes them.
- A review of recovered code sets rigor and perspective depth from the recovered facts (`design-flow.md` § Perspectives).

## Where the As-is Lives

- **Extension** (no structural change): the recovered as-is becomes `context.md` and `system.md` (header `State: as-is recovered YYYY-MM-DD`, claims tagged observed or inferred) and is then patched like any existing doc.
- **Re-architecture, modernization or system migration**: write the as-is once to the as-is doc (default `docs/arch/as-is.md`; caller may redirect), headed `State: as-is recovered YYYY-MM-DD`: C4 L1/L2 plus the Record items above, each claim tagged. `context.md` and `system.md` describe the **target**; the Transition Plan in `system.md` §4 links the as-is doc and names the live step. During the transition, the drift check compares the code with the live step, not with the target. When the decommission step exits, retire the as-is doc and collapse the plan to one line plus its ADR links.
- **One decision or one AI feature**: carry the recovered slice in the ADR's Context or the feature doc's §1–§2 (claims tagged); write `context.md` and `system.md` from it only when the caller asks.
- **Review**: return the as-is with the findings; write it only on request.

## Transition Plan

**Forcing question**: what is true today (measured), what must be true after, and which releasable stable states lie between?

One row per step in `system.md` §4 Transition Plan; each one-way step is also an ADR (`design-flow.md` § Minimum ADRs). Add the inputs a transition cannot assume to the Stage 0 question batch (`SKILL.md` § Stage 0 — Classification & Calibration): downtime tolerance per cutover unit, the date the old platform must be gone (end of support, contract, site exit), and which consumers can be asked to change.

1. **Gap and disposition** — per component, as-is → target and one disposition: retain / rehost / replatform / refactor / replace / retire. Retain and retire are answers too; moving everything is not the goal.
2. **Order by value × risk; prove the riskiest assumption first** — fix the violations that threaten data or money, then spike the assumption the target rests on most (e.g. the target store at the measured envelope), before slices that only move code.
3. **Each step is a releasable stable state** — shippable and reversible alone, behind a named coexistence seam: strangler routing at an edge facade (per route or entity), branch by abstraction, parallel run with outputs compared, or sync between stores fed by change-data-capture or an outbox. The link between old and new is a new trust boundary and failure domain: put it in the threat model and the resilience table.
4. **One writer per data set at every step** — name each data set's source of truth per step. No shared writable database between old and new, and no dual writes without an ADR (prefer change-data-capture or an outbox).
5. **Data mechanics** — mechanism (bulk copy plus catch-up, change-data-capture, backfill), cutover unit (tenant, region, entity, route), reconciliation (counts, checksums, sampled record comparison), rollback window and coexistence period. Rolling back after cutover needs a way back for data written since (reverse sync or a replayable change log); without one, the cutover is a one-way door. Lock-safe execution → a database-design capability, if available.
6. **Driver levels held** — per [H,H] driver, the level each step holds (never worse than the as-is unless an ADR accepts a time-boxed regression) and the step where the target level is reached. Re-run the driver's ATAM row for every interim topology: a tier moved while its store stays behind changes latency, egress and failure domains.
7. **Capture behavior before cutover** — characterization tests, traffic replay or shadow comparison for each slice; the legacy behavior, bugs included, is the spec until a step changes it on purpose. Published contracts keep their compatibility policy across steps; contract tests are exit checks.
8. **Exit and rollback** — each step's exit criterion is a fitness function or SLO (`design-flow.md` § Fitness Functions); its rollback trigger is a metric with a threshold, and the rollback path is rehearsed.
9. **Dual-run cost** — both systems' run cost, licenses, egress, sync infrastructure and people for each step's duration, carried into `design-flow.md` § Cost & Unit Economics.
10. **Decommission is a step** — criteria: zero traffic on the old path for a stated window; data archived or erased per its retention; credentials, network paths and jobs removed; consumers moved.
11. **Finish what you start** — prove the approach on the hardest consumer, automate the easy majority, block new use of the old path as soon as the new one can take it, then turn the old one off. *Break when* the old path is frozen and cheap to keep: it may stay, with a dated sunset recorded in an ADR.

Seed the Risk Register (`design-flow.md` § Risk Register) with: cutover data loss; store features that do not port (stored procedures, triggers, engine-specific types); knowledge held by few people; old and new drifting apart during coexistence.

## Strangler Fig

**Forcing question**: can the old system's behavior be preserved slice by slice while traffic moves?

- **Choose when**: replacing a running system whose behavior must be preserved; per entity, record the items of Transition Plan steps 4, 5, 7 and 10 (sync may run behind an anti-corruption layer — `service-architecture.md` § Strategic Context Mapping).
- **When not**: the legacy data can't be kept in sync, or a flag-gated rewrite is cheaper. Cost shape: a facade hop on every request, and two systems to run, staff and keep in parity until the last slice moves; the cost grows with the length of the tail.
- **Failure mode**: a long tail that never finishes. Set the decommission criterion up front.
- **Standing guard**: a parity check per slice while both paths run, then a zero-traffic check on the legacy route before it is removed.

## Red Flags

Default severities on the `SKILL.md` rubric; general flags live in `review-lens.md`.

- 🟠 **Big-bang rewrite** — the target replaces the as-is in one cutover, with no releasable intermediate state or rollback path.
- 🟠 **Second-system effect** — the target carries every deferred wish while the old system keeps changing; scope runs past the drivers.
- 🟠 **Unfinished migration** — a step with no exit fitness function or decommission criterion, or an old path that still accepts new use.
- 🔴 **Dual writes** — application code writing old and new stores with no outbox, change-data-capture or ADR-accepted reconciliation check, or a shared writable database between them: silent divergence.
- 🟠 **Unchecked interim topology** — a tier moved away from its store, or a new link between old and new, with no ATAM re-run for latency, egress and failure domains.
