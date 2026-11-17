---
name: arch-decision
description: |
  Record one architecture decision as a one-screen ADR: the decision, the
  fact that decided it, what was rejected, its cost and when to reopen it.
  Also decides an open X-or-Y question on an existing system, reviews or
  tightens an ADR, and patches the docs it makes stale.
  Use for "record an ADR", "we decided to X", "should we switch from X to
  Y", "document why we chose X", "review this ADR", "this ADR is too
  long", or an `ADR owed` from database-design.
  Do NOT use for: a new system, a multi-decision re-architecture or
  migration (software-architecture); AI feature design (ai-architecture);
  table, column, index or schema-migration design (database-design);
  feature requirements (feature-spec).
---

# Arch Decision — One ADR

## Premise

**An ADR holds what the code cannot say.** The code shows what was built, the tests what is enforced, the plan and the pull request how it got there. Only the ADR says why this and not the alternative, what was given up, and what would change the answer. Its reader arrives cold a year later, a person or an agent about to change or question the thing, and within a minute should know the rule, the reason, and whether the reason still holds.

Five rules:

1. **Record the decision, not the work.** Keep what stays true as long as the decision stands. The rollout, the proof, the design detail and the file lists are true for a few weeks: they live where the work lives, and the ADR links to them.
2. **One screen.** One or two sentences per field, in any language. In English that is 150 to 200 words, 250 at most. The limit binds the record, never the analysis. What does not fit has another home ([What stays out](#what-stays-out)), not a longer ADR.
3. **The title is the decision.** "Background jobs run on a Postgres table, not SQS", never "Queue selection". The titles of the log, read alone, are the project's rules.
4. **One reason, one price.** Why is the single fact that separates the winner from the runner-up, with its number. A list of benefits means the reason has not been found, and a decision with no cost was not a decision.
5. **Supersede, never rewrite.** An accepted decision does not change. A new ADR replaces it, and the old one changes only its status line.

## When an ADR is owed

Write one when a later reader would otherwise undo the decision by accident or argue it again:

- a one-way door that had a live alternative;
- a departure from the default, the technology baseline or an accepted ADR;
- a trade between two drivers;
- a rule the code cannot show and contributors would otherwise break ("every LLM call goes through `generateText`").

Nothing else gets one: a default taken for its stated reason, a two-way choice inside one module, a choice an accepted ADR already governs (cite it), a plan, a bug fix. Say "no ADR needed" and why in one line, unless the caller insists.

**A door is typed by what undoing touches**, not by its category: one-way when reversal means migrating stored data or formats, changing a contract others bind to (shapes, ids, addresses, defaults, error text), exiting a signed commitment, or spending more than the build did.

**One decision per ADR.** When several arrive together, write the one the others depend on and return the rest as follow-ups. Several coupled one-way decisions, all still open, are a redesign: use the software-architecture capability, if available.

## Route the request

| Situation | Do | Status |
|---|---|---|
| **Open**: "should we", "X or Y", a review finding | Decide it ([below](#deciding-an-open-question)) and recommend. Write the ADR only if one is owed | `Proposed` until the caller decides |
| **Made**: "we decided X" | Record it as it was weighed. Never reopen it: a concern that could change it goes to the report as a question | `Accepted` |
| **Unrecorded**: settled in code or a design doc, never written down | Record what is there. A reason nobody can confirm is marked *inferred*; unknown alternatives are "not recorded" | `Accepted`, with "decided ~{when}" in Context |
| **A Proposed ADR exists** | Update it in place once decided. A recommendation the caller declined becomes a Rejected line | `Accepted` |
| **Review or tighten an ADR** | [Review](#review) | unchanged |

`Accepted` means the caller says the decision is made, or hands you the call in so many words. Your own recommendation is `Proposed`.

**Read first** (defaults; caller may redirect): what raised the question (a spec, a finding, an `ADR owed` line); the titles of the existing ADRs, and in full those on the same component or driver; `docs/arch/context.md` §3 Drivers, §5 Constraints and §6 Assumptions, and the `system.md` lines it touches; the code and config on its path. With code and no docs, recover only what this decision touches: the facts the decision rests on go in Context, the rest in the report.

Ask the caller only what reading cannot answer and a one-way door depends on, once, each question with the default you will otherwise assume. A subagent that cannot ask applies the defaults and lists them in its report.

## Deciding an open question

1. **Ask the question without its answer.** "Switch to Y" becomes "bring {metric} from {now} to {target} by {date}". A performance, scale or cost reason needs the measured trigger; a maintainability reason needs the record of recent comparable changes. Without either it is an assumption: name the measurement that would settle it. Expected growth is not a trigger.
2. **Keep-current is always an option, and a switch adds fix-in-place**: the cheapest change to what exists that moves the metric. The new option must beat it with migration and coexistence counted. Before replacing something, find out why it exists.
3. **The reason is the highest-ranked driver the winner meets and the runner-up fails**, ranked as `context.md` §3 ranks them, else with the trigger's driver first. Margin past a target decides nothing. If every option passes, cost and door decide. If none does, stay `Proposed` and name the spike or the relaxed target that would settle it.
4. **Source the facts.** Price, quota, license and support dates come from a current primary source, with its date. Behavior under this workload comes from a time-boxed spike with a pass or fail number. Anything else is named as an assumption.
5. **Check the winner against the running system** before recommending it. Compute the worst case, never the average: the peak, the largest tenant or payload, each shared limit's headroom, and any other ADR's Revisit trigger it would cross. List who sees a change on day one: consumers (shape, timing, order, addresses, errors) and commitments (contracts, data-processing terms, residency, allowlists). A requirement it cannot meet goes back to its owner with a concrete replacement, never silently weakened. A finding the winner cannot absorb sends you back to step 3.
6. **Make a one-way door two-way first.** Decide the reversible step that buys the missing evidence (one tenant, a shadow copy, expand-contract) and put the full commitment's trigger in Revisit when. *Break when* staging costs more than being wrong, or a deadline forces the whole move.
7. **Reversing an accepted ADR takes evidence**: its Revisit trigger fired, a premise proved false, or a new force appeared. Without one the accepted ADR stands: answer "no ADR needed" and cite it with its trigger. A reversal the caller has already made is still recorded, with "no new evidence since ADR-NNN" in Context.

## Writing the ADR

One file per decision, default `docs/arch/adr/ADR-NNN-{slug}.md` (caller may redirect). NNN is the highest existing number plus one, three digits, never restarting at 001. An existing log (`docs/adr/`, `docs/decisions/`, …) keeps its location, numbering, language and headings: map the fields below onto its headings without adding one, a field the log has no heading for becoming a labeled line under the nearest (Why under Decision; Door, Rejected, Tradeoff and Revisit when under Consequences). The five rules still apply. With no docs root and none asked for, answer inline in this shape.

```markdown
# ADR-NNN: {the decision, as a rule or a choice}

- **Status**: Accepted · {the day it was decided, YYYY-MM-DD} · {who decided, or the PR or issue that records it}
- **Door**: One-way — {what undoing touches} | Two-way — {how it is undone}
- **Context**: {the problem, and the number or event that forced a decision now}
- **Decision**: {the rule or choice, its scope and its exceptions; the check that enforces it}
- **Why**: {the one fact that separates it from the runner-up, with its number}
- **Rejected**: {each real alternative and why it lost, one line each}
- **Tradeoff**: {what gets worse, and who pays}
- **Revisit when**: {a metric and threshold someone can see today, or a dated event}
```

Other statuses: `Proposed · YYYY-MM-DD · settled by {the spike, fact or person}, by {the date an option disappears}` and `Superseded by ADR-NNN`.

A whole ADR, at the size to aim for:

```markdown
# ADR-012: Background jobs run on a Postgres table, not SQS

- **Status**: Accepted · 2026-03-02 · backend lead (PR #412)
- **Door**: Two-way — jobs sit behind the `JobQueue` port; leaving means a new adapter and draining the table.
- **Context**: A crash between committing an order and enqueueing its job loses the job: three incidents last quarter (D-02, no lost work). Peak is 40 jobs/s.
- **Decision**: All async work in `apps/worker` runs from a `jobs` table in the primary database, claimed with `FOR UPDATE SKIP LOCKED`. A lint rule bans broker SDK imports.
- **Why**: The enqueue commits with the state change, so D-02 holds without an outbox. Measured capacity is 2,000 jobs/s, 50 times the peak.
- **Rejected**:
  - SQS: needs an outbox and a relay to meet D-02, and puts a second system on a one-person on-call.
  - Redis (BullMQ): needs the same outbox, and a failover can lose acknowledged jobs.
- **Tradeoff**: Queue writes share the primary's write budget, and a long job holds its transaction open and delays vacuum.
- **Revisit when**: load stays above 500 jobs/s for a week.
```

- **Context** cites driver and constraint ids (D-nn, C-nn) where the project has them. A superseding ADR opens it with "Supersedes ADR-NNN:" and what changed since.
- **Decision** reads "Recommend …" while `Proposed`. A convention may be two or three rule lines. Name the check that fails when the decision is bypassed (a test, a lint rule, an alert) only if it exists or ships with the work, and without its schedule. A one-way door without one is work owed, in the report.
- **Rejected** is written so that the option's advocate would agree, and lists keep-current when it was a live option. No pros-and-cons lists, scores or "industry standard".
- **Revisit when** holds only a condition someone can observe. A one-way door always has one; elsewhere, leave the line out instead of inventing a trigger nobody watches.
- When the reasoning already lives in another doc (an AI feature doc, `database.md`), keep Status, Door, Decision and Revisit when, and link the section for the rest.

### What stays out

| It is… | It lives in |
|---|---|
| The rollout: steps, order, PR units, gates, cutover, rollback drill | The plan: an issue, a PR, a plan doc, or `system.md` §4 Transition Plan |
| The proof: test strategy, coverage, benchmark tables, spike logs | The tests, the spike or the PR. The ADR quotes only the number that decided |
| The design: paths, names, shapes, code, diagrams | The code and `system.md` |
| Inventory: files, routes, call sites, exceptions one by one | A search, or the allowlist of the check. The Decision names the kind of exception |
| Risks, open questions, follow-ups | `risks.md` or the tracker, and the report |
| History: who argued what, amendments | The PR and version control |
| Background: what the technology is, generic pros and cons | Nowhere |

Test any line: *will the reader still need it a year after the work has landed?* Content the caller gave you that has no home yet is named in the report with the place it belongs, and an offer to write it there. It never goes into the ADR for safekeeping.

**After acceptance** the decision's text is frozen. To reverse or narrow it, write a new ADR and change only the old one's Status (`Superseded by ADR-NNN`, or append `; narrowed by ADR-NNN ({where})`). A typo, a wrong number or a dead link is fixed in place, since version control keeps the history. Never append amendments.

## Reconcile

Only for `Accepted`. A `Proposed` ADR and a "no ADR needed" answer patch nothing: what they owe (a spike, a measurement) goes in the report. Search the docs for what the decision replaces and patch each line it makes false, nothing more:

- `system.md`: the §1 Decisions row (decision, door, why, revisit trigger, ADR link); the components, stores, contracts and guards that changed; the §4 Transition Plan or Scaling Ladder row it starts or defers.
- `context.md`, §6 only: add the ADR to the Dependent ADRs of each assumption it rests on. A new assumption is a new row.
- `risks.md`: close the Open Question it answers, with a link; add the risks it accepts and the spikes it owes.
- The project conventions file (`AGENTS.md`, `CLAUDE.md`) and docs outside the architecture root are not yours to edit. Give the caller the replacement line in the report: for a rule contributors must follow, one line with the ADR number.

Never renumber or rename a section there: other skills read them by number.

## Review

For "review this ADR": the verdict first (Sound, Sound after fixes, Re-decide), then the findings, most severe first, each with its fix, in about 200 words. Edit only on request.

- **Decision defects**: the question contains its answer; keep-current or fix-in-place was never weighed; Why does not separate the winner from the runner-up; a one-way door rests on an unverified assumption; an accepted ADR is reversed without evidence.
- **Record defects**: a topic for a title; Why as a list; no Tradeoff; a Revisit trigger nobody can observe; content from [What stays out](#what-stays-out); over budget.

**Tightening** an ADR that grew too long is a record edit, done on request: the decision, its scope and its exceptions keep their meaning. The rest moves to its home first and is dropped only when the caller confirms the work has landed; report what moved where. Where the log freezes accepted text, do not edit it: return the tightened text as a proposal and ask the owner to allow the edit. Never supersede for length alone, since the decision has not changed. If the text holds several decisions, propose the split instead of making it.

## Report back

About 150 words beside an ADR, not the ADR again. An answer with no ADR behind it ("no ADR needed", or inline) is the whole answer and may run to 300. First what needs the caller's decision or action, most consequential first, each with its number, and a decide-by where an option expires: a recommendation awaiting a decision and what would settle it; a requirement the decision cannot meet, with the proposed replacement; a concern about a decision already made, as a question. Then: the ADR's id, title, status and door; files patched; what was kept out of the ADR and where it went; follow-up decisions; defaults assumed.

## Self-check

- The title states the decision, and the ADR is under 250 words with no field past two sentences (Rejected: one line per option).
- Nothing from [What stays out](#what-stays-out) is in it.
- Why names one separating fact with its number, Tradeoff a real loss, and each Rejected line a reason its advocate would accept.
- The status is honest: `Accepted` has a decider, `Proposed` says what settles it and patched nothing.
- No accepted ADR had its decision edited, and every doc line an `Accepted` decision made false is patched or reported.
