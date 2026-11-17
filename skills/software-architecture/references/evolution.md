# Evolving an Existing System

Read whenever work starts from a running system: Build Mode on an existing system, or any request that must first recover the as-is from code without docs.

## As-is Recovery

*What is actually running, how does it behave under real load, and why is each structure the way it is?*

**Scope it to the request.** One decision, one AI feature or an extension: recover the containers, stores and integrations it touches, plus the system context. A re-architecture, a migration, or a review with no docs: the whole system. When docs exist, drift-check their load-bearing claims first and recover only what drifted; never design from stale docs.

| Source | What it shows |
|---|---|
| Build and deploy config | Deployment units, runtimes, environments, scheduled jobs, secret wiring |
| Schema and migration history | Stores, entities, which code writes which tables |
| Source and its dependency graph | Modules, integrations, call paths, cycles |
| Version history | Co-change clusters (the real boundaries) and churn hotspots |
| Telemetry | Rates, volumes, per-hop latency and errors, queue ages, data growth |
| Incidents and runbooks | Fragile paths, manual operations, failures already paid for |
| The people who know | Intent, undocumented constraints, why each structure exists |

**Record**:

- Containers, deployment units and integrations, with every published contract and its consumers.
- Stores and their writers; more than one writer for a data set is already a finding.
- Module dependencies; cycles and cross-context table access mark the seams that will resist.
- The measured envelope, plus the per-hop latency and error breakdown of each driver's path, so the design attacks the measured bottleneck. Where telemetry cannot answer, a measurement spike comes first.
- Hotspots, where incidents and co-change concentrate; they order the transition.
- Violations to fix first: unguarded read-modify-write, non-idempotent consumers, calls without deadlines, enqueue before commit, several writers per data set, and assumptions about time windows (a nightly batch, a maintenance window) that round-the-clock operation removes.

**Rules**:

- Tag every claim *observed* (seen in code, config or telemetry) or *inferred* (confirm before a one-way door rests on it).
- **Know why a structure exists before removing it.** Find the incident or constraint behind it, or ask. Unknown → an Open Question, not a deletion.
- Drivers the code cannot show (business goals, contractual targets, regulatory duties) become assumptions or Open Questions.
- Foundational decisions the target keeps get retroactive ADRs via `arch-decision`, if available. Decisions the target reverses get none: the superseding ADR's Context says "as-is: X since …".

## Where the As-is Lives

- **Extension**: the recovered as-is becomes `context.md` and `system.md` (header `State: as-is recovered YYYY-MM-DD`) and is then patched like any existing doc.
- **Re-architecture or migration**: write it once to the as-is doc (default `docs/arch/as-is.md`). `context.md` and `system.md` describe the target; the Transition Plan links the as-is and names the live step. During the transition the drift check compares code with the live step, not with the target. When the decommission step exits, retire the as-is doc and collapse the plan to one line plus its ADR links.
- **One decision or one AI feature**: carry the recovered slice in the ADR's Context or the feature doc's §1–§2.
- **Review**: return the as-is with the findings; write it only on request.

## Transition Plan

*What is true today (measured), what must be true after, and which releasable stable states lie between?*

One row per step in `system.md` §4; each one-way step is also an ADR. Add to the Stage 0 questions what a transition cannot assume: downtime tolerance per cutover unit, the date the old platform must be gone, and which consumers can be asked to change.

1. **Gap and disposition** per component: retain, rehost, replatform, refactor, replace or retire. Moving everything is not the goal.
2. **Order by value × risk, and prove the riskiest assumption first**: fix the violations that threaten data or money, then spike what the target rests on most (the target store at the measured envelope), before slices that only move code.
3. **Each step is a releasable stable state**, shippable and reversible alone, behind a named coexistence seam: strangler routing at an edge facade, branch by abstraction, a parallel run with outputs compared, or store sync fed by change data capture or an outbox. The link between old and new is a new trust boundary and failure domain.
4. **One writer per data set at every step.** No shared writable database between old and new, and no dual writes without an ADR.
5. **Data mechanics**: mechanism (bulk copy plus catch-up, change data capture, backfill), cutover unit (tenant, region, entity, route), reconciliation (counts, checksums, sampled comparison), rollback window. Rolling back after cutover needs a way back for data written since; without one, the cutover is a one-way door.
6. **Driver levels held**: per driver, the level each step holds (never worse than the as-is without an ADR accepting a time-boxed regression). Re-check coverage for every interim topology: a tier moved while its store stays behind changes latency, egress and failure domains.
7. **Capture behavior before cutover**: characterization tests, traffic replay or shadow comparison per slice. The legacy behavior, bugs included, is the spec until a step changes it on purpose.
8. **Exit and rollback**: each step exits on a guard or SLO and rolls back on a metric with a threshold; the rollback path is rehearsed.
9. **Dual-run cost**: both systems' run cost, licenses, egress, sync infrastructure and people, for each step's duration.
10. **Decommission is a step**: zero traffic on the old path for a stated window; data archived or erased per its retention; credentials, network paths and jobs removed.
11. **Finish what you start**: prove the approach on the hardest consumer, automate the easy majority, block new use of the old path as soon as the new one can take it, then turn the old one off. *Break when* the old path is frozen and cheap to keep: it stays, with a dated sunset in an ADR.

## Red Flags

- 🔴 **Dual writes**: application code writing old and new stores with no outbox, change data capture or reconciliation check, or a shared writable database between them.
- 🟠 **Big-bang rewrite**: one cutover, no releasable intermediate state, no rollback path.
- 🟠 **Second-system effect**: the target carries every deferred wish while the old system keeps changing.
- 🟠 **Unfinished migration**: a step with no exit check or decommission criterion, or an old path that still accepts new use.
- 🟠 **Unchecked interim topology**: a tier moved away from its store, or a new link between old and new, with latency, egress and failure domains never re-examined.
