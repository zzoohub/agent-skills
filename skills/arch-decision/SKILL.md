---
name: arch-decision
description: |
  Record a single Architecture Decision Record (ADR) for an existing system.
  Creates one ADR file at `docs/arch/adr/ADR-NNN-{slug}.md`.
  Patches `docs/arch/system.md` only when the decision changes the architecture
  surface (new component, swapped pattern).
  Use when: you need to record one architectural choice on an existing system —
  swapping a pattern, adding a component, choosing a library, migrating a piece
  of infrastructure. Trigger phrases: "record an ADR", "we decided to X",
  "make an architecture decision about X", "let's switch from X to Y".
  Do NOT use for: a new system from scratch (use software-architecture — it
  produces the full design doc plus initial ADRs). Do NOT use for: schema
  decisions (use database-design). Do NOT use for: writing feature requirements
  (use feature-spec). Do NOT use for: pure code refactors that don't shift
  architecture (no ADR needed).
---

# Arch Decision — Single ADR

Record one decision, tied to the existing system's ASRs, without rewriting
`context.md` or `system.md`.

## Prerequisites

The architecture docs root defaults to `docs/arch/` (caller may redirect).
`docs/arch/context.md` and `docs/arch/system.md` are the inputs; if either is
absent, ask the caller rather than halting — you can still record an ADR
against a missing context, but flag the gap. If there is no `context.md` and the
request is really a new system, it is greenfield: run a full design pass (the
`software-architecture` skill, if available) instead.

Write only under the architecture docs root — read the PRD/feature specs, never
edit them or any other owner's docs.

## What This Skill Does

1. Reads existing `docs/arch/context.md` (problem, ASRs, domain) and
   `docs/arch/system.md` (current patterns, components) for context.
2. Frames the decision — one decision per ADR. If multiple unrelated decisions
   surface, split into separate ADRs (one per decision).
3. Captures 2-4 realistic options including "do nothing / keep current."
4. States the choice with reasoning tied to an ASR or constraint from
   `context.md` §3.
5. Records consequences — enables, costs, risks, affected components.
6. Writes the ADR as a new file at `docs/arch/adr/ADR-NNN-{slug}.md` (one
   decision per file).
7. Patches the affected section of `system.md` ONLY if the decision changes
   the surface (new component, new pattern). Otherwise leaves `system.md` alone.
8. Reconciles `docs/arch/risks.md` when the decision resolves an Open Question
   or accepts a risk — the Open-Question → ADR promotion loop closes here.

## What This Skill Does NOT Do

- Does not rewrite `context.md` (the problem and ASRs don't change)
- Does not rewrite `system.md` from scratch
- Does not produce diagrams unless the decision adds a new container
- Does not produce database schema changes

## ADR Template (MADR/Nygard-style — extends the `software-architecture` ADR format)

```markdown
## ADR-{NNN}: {Title} — YYYY-MM-DD

- **Status:** Accepted | Proposed | Superseded by ADR-{NNN}
- **Door:** One-way (irreversible) | Two-way (reversible)
- **Context:** Issue motivating this decision. Cite ASRs from `docs/arch/context.md` §3, and the feature spec at `docs/prd/features/{feature}.md` if feature-driven. For performance/scale/cost-driven decisions, include the **measured trigger** (observed metric, breached threshold, bill).
- **Options:**
  1. **{Option A}** — pros / cons
  2. **{Option B}** — pros / cons
  3. **Keep current / do nothing** — pros / cons (always include)
- **Decision:** Chose {X}.
- **Why:** Reason tied to ASR or constraint.
- **Rejected:** Why other options were rejected.
- **Tradeoff:** Positive and negative consequences. Affected components from `system.md` §2 (or "none").
- **Revisit when:** Trigger conditions that should prompt reconsideration. Scale/cost triggers name a **metric + threshold** that is (or now becomes) observable on a dashboard — a revisit trigger nobody can see never fires.
```

This aligns with the standard `software-architecture` ADR template (in that skill's
templates if installed; otherwise the format above is self-sufficient): it shares
`Status` / Door / Context / Decision / Why / Rejected / Tradeoff / Revisit-when, **adds**
an explicit `Options` list, and **omits** `Stage` (a standalone decision has no
design-flow stage). `Rejected` states why each *other* option lost the comparison —
not a restatement of its cons. ADRs authored here sit in the same `docs/arch/adr/`
directory as ones authored by `software-architecture`; that mixed field shape across
files is expected.

**One-way doors** (analyze carefully): database choice, primary language, auth architecture, core domain model.
**Two-way doors** (decide fast): library choice, caching strategy, log format, CI tool.

When options differ in reversibility, weigh it explicitly: a cheaply-reversible option beats an otherwise-equal one-way option — optionality is part of the payoff, not a tiebreaker.

**Retroactive ADRs (gap-fill):** when recording a decision the design doc already settled but never recorded (e.g. an audit against the `software-architecture` Minimum-ADRs list found a gap), reconstruct the options and rationale *as they were actually weighed* — record history faithfully rather than re-litigating a settled decision. If the original rationale can't be reconstructed, say so in Context and record the current best understanding.

## Workflow

1. **Read context** — `docs/arch/context.md` and `docs/arch/system.md`. If
   either is missing, flag the gap to the user; you can still proceed.
2. **Get the next ADR number** — Find the highest existing `ADR-NNN` in
   `docs/arch/adr/` and add 1. NNN is zero-padded to 3 digits (`ADR-001`). If
   `docs/arch/adr/` doesn't exist yet, start at `ADR-001`. If two writers grab
   the same number in parallel, the later writer renumbers.
3. **Frame one decision** — If multiple decisions surface, record the most
   foundational one first (the one the others depend on) and return the
   deferred decisions as text in your summary for the caller to sequence as
   follow-up ADRs — don't block on asking inline.
4. **Draft 2-4 options** — Include "keep current" as one option. Weigh each on
   the driving quality attributes, cost delta (infra **and** migration effort),
   reversibility (note each option's door if they differ), and blast radius
   (affected components).
5. **Tie the choice to an ASR — with evidence** — If you can't tie it, the
   decision probably isn't ready, or the ASR list is incomplete (raise that).
   Performance/scale/cost-driven decisions additionally cite a **measured
   number** — the observed metric, the breached ASR threshold, the monthly
   bill — or are explicitly labeled assumption-driven, naming the number a
   time-boxed spike would validate. "We expect growth" justifies a Scaling
   Ladder entry, not an architecture change.
6. **Write the ADR** — Create a new `docs/arch/adr/ADR-NNN-{slug}.md` file.
7. **Patch system.md if needed** — Only when surface changes (new component,
   new pattern, etc.). A surface change usually moves the guards too: update
   the affected fitness-function / SLO rows in `system.md` §5 (where the doc
   tracks them) so the new decision is guarded like the old one was, and
   reconcile the Scaling Ladder in §4 — if this ADR executes a deferred
   escalation, mark that ladder row done; if it defers one, add the trigger
   metric there.
8. **Reconcile `docs/arch/risks.md`** (if present) — if this decision resolves
   an Open Question, close it with a pointer to the ADR; if the decision
   *accepts* a risk (a known gap, a deferred mitigation), append it to the Risk
   Register. The Open-Question → ADR promotion loop only works if this step
   actually closes it.

## Quality Bar

- [ ] One decision, clearly named
- [ ] 2-4 realistic options considered, including "keep current"
- [ ] Decision tied to a specific ASR or constraint from `context.md`
- [ ] Scale/cost claims carry a measured number — or an explicit assumption plus
      the spike that would validate it
- [ ] Revisit-when names an observable metric + threshold for scale/cost triggers
- [ ] Consequences spelled out (enables / costs / risks / affected components)
- [ ] ADR number is unique and monotonically increasing
- [ ] If the decision changes architecture surface, `system.md` is patched in
      the affected section — including its fitness-function / SLO / Scaling
      Ladder entries where the doc tracks them
- [ ] `risks.md` reconciled, if applicable (resolved Open Question closed;
      accepted risk appended)
- [ ] Status is valid (`Accepted`, or `Proposed` if pending review; if this ADR
      replaces an existing one, mark that older ADR `Superseded by ADR-{NNN}`)

## Output

- the new ADR file (default `docs/arch/adr/ADR-NNN-{slug}.md`) — created
- `docs/arch/system.md` — patched if architecture surface changed (including
  guard / Scaling Ladder entries where tracked)
- `docs/arch/risks.md` — touched only to close a resolved Open Question or
  append an accepted risk

**Superseding:** ADRs are one file per decision — there is no aggregate line cap.
When a new decision replaces an older one, set the older ADR's `Status` to
`Superseded by ADR-{NNN}` in its file rather than deleting it.
