---
name: arch-decision
description: |
  Record one Architecture Decision Record (ADR) on an existing system and
  patch the architecture docs only where it makes them stale.
  Use for "record an ADR", "we decided to X", "should we switch from X to
  Y", "X or Y for this component", "document why we chose X", "review
  this ADR", or an `ADR owed` from database-design (key strategy,
  partition key, tenancy-model change).
  Do NOT use for: a new system, a multi-decision re-architecture or
  migration, or AI feature design (software-architecture); table,
  column, index or schema-migration design (database-design); feature
  requirements (feature-spec).
---

# Arch Decision — One ADR

Done: a newcomer a year on, from the ADR and its links alone, can say what was chosen, where it applies, which driver decided it and how to tell it still holds; today, whoever must decide or act on its risks knows what, by when.

## Inputs & scope

Docs root (`context.md`, `system.md`, `risks.md`, `adr/`): default `docs/arch/`; caller may redirect.
- **Code, no `context.md`**: recover only what this decision touches (containers, stores, integrations, their consumers) into its Context (method: `software-architecture/references/evolution.md`, if available); write `context.md` or `system.md` only on request.
- **Neither**: answer inline in ADR shape, as a file only if a docs root exists or the caller asks.
- **One log**: `adr/`, else an existing decision log (e.g. `doc/adr/`, `docs/decisions/`), whose location, numbering and format win, plus whichever of Drivers, Door, Confirmation and Revisit when it lacks.
- **Writes**: only ADRs (step 7) and step 8 edits.

## Method

**1. Inspect**: the spec, finding or `ADR owed` line that raised it; ADR titles, reading in full those on its component, its driver or a limit it shares; `context.md` §2 Scale Envelope, §3 ASR & Utility Tree, §5 Constraints, §6 Assumptions; `risks.md` Open Questions; the `system.md` lines, code and config it touches, and their consumers; its evidence, at peak.

**2. Classify.**

| Situation | Status | Treatment |
|---|---|---|
| **Open**: "should we", "X or Y", a review finding | Proposed | Recommend |
| **Made**: "we decided" | Accepted | Record it as weighed; never re-litigate; still stress-test it (step 6) |
| **Gap-fill**: settled in a design doc or code, never recorded | Accepted, per that doc or code | As Made, never duplicating an ADR; unconfirmed rationale is *inferred* |
| **A Proposed ADR on it exists** | Accepted once decided | Update it in place; a declined recommendation moves to Rejected |
| **Review** of an ADR | Unchanged | Verdict (Sound, Sound after fixes, Re-decide), then findings with fixes, most severe first, in ~250 words: decision defects (steps 2–6) before record defects (Self-Review); edits on request only (Accepted: step 7) |

Accepted needs a named decider; a caller who delegates the call is one (for a one-way door, only explicitly).

**Door = what undoing it touches**, not its category: one-way if reversal must migrate persisted data or formats, change a contract others bind to (shapes, IDs, addresses, defaults, error text) or other teams' code, un-leak what a shared cache or index exposed, exit a signed commitment, or cost more than building it did (a library whose types leak into the domain). A choice an Accepted policy ADR governs needs no ADR: cite it. A two-way choice earns one only if it moves a driver's measure or a newcomer will ask "why?" within a year (else "no ADR needed", unless the caller insists), and weighs keep-current against one real alternative.

**One decision per ADR**: write the one the others depend on and return the rest as follow-ups; a two-way choice existing only because of another is a clause in its Decision; coupled one-way decisions still open → software-architecture, if available.

**Ask once**, only what a one-way door needs and reading can't answer: who decides (else Proposed); what forces it now (else assumption-driven); what it binds (else new work only); who operates it (else its `system.md` §2 Key Modules owner).

**3. Frame** (Made, gap-fill: steps 3–5 record what was weighed; missing evidence, staging or spikes go to the report). Restate the question without its answer: "switch to Y" → "bring {metric} from {now} to {target} within {constraints} by {date}"; a missing capability → "provide {it} for {whom} by {date}", keep-current priced in what it loses. Rank the drivers before naming options: `context.md` §3's order, else the trigger's driver first, as an assumption. Performance, scale or cost reasons need the measured trigger (metric at peak, breached threshold, bill); evolvability or skills reasons, the change record (lead time and defects in recent comparable changes); else an assumption naming the number a time-boxed spike would settle. "We expect growth" earns a Scaling Ladder entry, not an architecture change. Before replacing X, learn why it exists (its ADR, commit or owner); if nobody knows, say so and check before the point of no return. *Break when* the force is external (law, end of support, license, mandate, vendor exit): keep-current is one line naming it and its deadline.

**4. Options**: the real contenders (usually 2–3) plus keep-current. A switch adds **fix-in-place**, the cheapest change to X that moves the metric, which the new option must beat, migration included. New technology names the gap the running stack can't close; cost counts migration, coexistence and blast radius (components touched), not just run. **Research the documented, spike the workload-specific**: price, license, quotas, support dates and maintenance health from a current primary source, dated in the ADR (none reachable: an assumption naming it); behavior under this workload, from a time-boxed spike with a numeric pass/fail.

**5. Decide.**
- **The deciding driver** is the highest-ranked one the winner meets and the runner-up fails; margin past a target decides nothing. All pass → cost and door decide (reversibility is worth what being wrong would cost); a preference neither explains is a missing driver: name it. None meets the top driver → Proposed, naming the spike or relaxed target that would settle it.
- **One-way: name the point of no return, then make it two-way first**: decide the reversible step that buys the missing evidence (a contract or format: expand-contract; a store or service: one tenant, region or service behind the existing port, or a shadow copy fed by change-data-capture or an outbox, not a dual write, the old path authoritative and reconciled in Confirmation); the full commitment's trigger goes in `Revisit when`. *Break when* staging costs more than being wrong, or a deadline or mandate forces the whole move.
- **Supersede on evidence**: replacing or narrowing an Accepted ADR needs a fired `Revisit when`, a premise proved false or a new force. Without one, an Open request stays Proposed; a Made one is recorded, noting "no new evidence since ADR-NNN".

**6. Stress-test the winner** against the running system; the ADR's budget limits the record, never this step. Run each probe or say why it does not apply (two-way, in one team's code: often just the first and last).
- **Worst case, computed**: capacity and availability at the worst realistic input, never the average: what outsiders control (largest tenant, payload, fan-out), the peak (incl. the backlog after an outage), each shared limit's headroom after others' reservations (quota, pool, rate limit); synchronous hops multiply availabilities. Hold its added load against the thresholds other ADRs, the `system.md` §4 Scaling Ladder and `context.md` §6 record: one it crosses is a follow-up ADR, one it nears a Tradeoff line.
- **Consumers on day one**: what each (teams, partners, clients, jobs) sees change (shape, timing, order, duplicates, addresses, errors), and its gate: shadow or observe-only first, staged cutover with the most sensitive (external, contractual, money) last, a kill switch, advance notice; whoever must agree, a dated Open Question. *Break when* that consumer is why you are changing: it goes first.
- **Requirement conflicts**: one the winner cannot meet (spec, SLO, contract, ADR) returns to its owner with a concrete replacement and the reason ("exactly once" → "at least once, deduped on event id"), never silently weakened.
- **Obligations**: a new vendor, processor, region, data flow, outbound address or license may trigger data-processing terms (sub-processor notice), contract notices, residency or compliance duties, and break what third parties pinned (allowlisted IPs or domains, certificates, dedicated infrastructure): gates dated back from the step they block.
- **Hazards in the code on its path**, changed or not: check-then-act races, events published before commit, calls without deadlines, retries without idempotency, redirects followed into internal addresses or downgrading POST, unbounded inputs, keys or queues, secrets at rest or in logs: a gate if the decision relies on or worsens one, else a risk row.

Findings land once (Decision gate, Tradeoff, Confirmation, `risks.md` row, dated Open Question); any needing a decision also leads the report. Open: one the winner cannot absorb sends you back to step 5. Made, gap-fill: the decision stands, added gates are *(proposed)*, a finding that would change it goes to the decider as a question.

**7. Write** one file, default `docs/arch/adr/ADR-NNN-{slug}.md`: NNN = highest existing + 1, three digits, never restarting at 001; on a collision the later writer renumbers and fixes every reference. An Accepted ADR's decision never changes: its successor changes only its Status (`Superseded by ADR-NNN`, or append `; narrowed by ADR-NNN ({where})`), and a record defect is amended on request, appended in its own field as `(amended YYYY-MM-DD: …)`. A retroactive ADR carries its decision date, else today plus "decided ~{when}" in Context.

```markdown
<!-- ~250 words two-way, ~500 one-way; the budget limits this record, never the analysis (overflow: risks.md and the report). software-architecture's ADR fields minus Stage (its ADRs keep it): keep each ("none — {why}" if n/a), add none. Link evidence and design, never restate; no pros/cons lists, scores, "industry standard" reasons or method narration. -->
## ADR-NNN: {the decision, stated as a choice} — YYYY-MM-DD

- **Status**: Proposed — decider {role}, decide-by {when an option disappears: a renewal, a new format's first write} | Accepted — {decider}, {date} | Superseded by ADR-NNN
- **Drivers**: {in rank order: QA / C ids from context.md §3 / §5; no context doc: the forces, with numbers}
- **Door**: One-way — {what undoing touches}; no return after {step} | Two-way — {how it is undone}
- **Context**: {the question without its answer; measured trigger and source, or the assumption (A-nn) and what settles it; the doc or finding it answers; recovered facts tagged observed / inferred; "Supersedes (or narrows) ADR-NNN: {what changed}"}
- **Decision**: {Chose (Proposed: Recommend) X for {scope}; gates before {step}; rollout {shadow → stages, most sensitive last; kill switch}; existing {…} migrates by {…} or stays until {…}; {old path} removed when {condition}}
- **Why**: {the deciding driver, with its number (all pass: the cost or door)}
- **Rejected**: {one line each: the driver it fails or the cost it adds, as its advocate would concede. Open: keep-current, and fix-in-place for a switch; Made, gap-fill: only what was weighed, else "not recorded" plus at most one *inferred*}
- **Tradeoff**: {what gets worse and who pays, with the worst-case number; the new obligation (who operates, upgrades, is paged; notices owed); how it fails; affected components and consumers; requirements not met, pending their owners}
- **Confirmation**: {one-way: the outcome (metric, target, by when) plus the system.md §5 guard that fails on a bypass; two-way: the outcome, or "none — {why}"; plus a signal per stress-test risk left open}
- **Revisit when**: {a variable and threshold observable today or made so by this ADR, or a dated event; a trigger nobody sees never fires}
```

**8. Reconcile** (Accepted only), never renumbering, renaming or consolidating sections.
- `system.md`: patch each line this decision makes false (search for what it replaces) or incomplete (each table or diagram inventorying what it adds), incl. Security and Resilience rows for a new store, vendor or remote dependency, the §5 guard Confirmation names (a swap re-targets the old guards, never drops them) and a §4 Scaling Ladder row it executes or defers; nothing else.
- `context.md`, only §6: add this ADR to the Dependent ADRs of each A-nn it rests on; a new assumption is a new row.
- `risks.md`, if present (else the report carries these): close the Open Question it answers, with a link; append the risks it accepts, step 6's included, to the Risk Register, and findings awaiting another's decision to Open Questions (who decides, by when).

## Report back

At most ~250 words, not the ADR, no step or probe names. **First, what needs the user's decision or action**, most consequential first, each with the number behind it, owner and decide-by: risks, requirement conflicts with the proposed replacement, gates owed (notices, sign-offs, fixes, spikes with pass/fail), a driver the decision fails, a reversal without new evidence and, for a Made decision, findings that would change it, as questions. Then: id, title, status and decider (Proposed: whom to consult); door; files patched; follow-ups; defaults applied; gaps, incl. stale lines you may not edit; what you checked and found clear, in one line; for a new log, a conventions-file pointer.

## Self-Review

- Done (top) holds; Status names a decider; Proposed has a decide-by and patched nothing.
- Drivers ranked; Why names what separates the winner from the runner-up. One-way: each assumption beneath it has a spike or check in the report (Made, gap-fill: recorded, not reopened).
- **Stress test**: each step 6 probe has findings or a reason it does not apply; capacity and availability claims show worst-case arithmetic; each consumer that sees a change has a gate; each finding sits in one place, decisions owed first in the report.
- Every field meets its placeholder, above all Rejected, a one-way Door and Confirmation, the old path's end; numbers and vendor facts sourced.
- No two Accepted ADRs disagree; Accepted made every step 8 edit it owes, nothing more.
- **Footprint**: ADR within its door's budget (~250 / ~500 words), one line per alternative, design linked not restated, no finding dropped to fit; report ≤ ~250 words; review ≤ ~250.
