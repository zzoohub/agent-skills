---
name: feature-spec
description: |
  Write, revise or review one feature spec for an existing product and patch
  the PRD's Feature Overview row and Dev Order without rewriting its vision;
  also deepens `Depth: stub` specs. Use when: "spec out a feature", "write
  requirements for X", "acceptance criteria for X", "a PRD for one feature",
  "add a feature to the PRD", "review this feature spec". Never re-run
  prd-craft to add features. Do NOT use for: a new product's PRD
  (prd-craft, which calls this for its specs); a spec's premise or scope
  (plan-review).
---

# Feature Spec

A feature spec is the build contract for one change to a live product: it settles product calls, never HOW. Done: whoever receives the result can finish their job with the first delivery, and an engineer can estimate it and a tester test it without asking you.

## Routing

Defaults, all caller-redirectable: PRD `docs/prd/prd.md`; specs `docs/prd/features/{feature}.md`; brief `docs/prd/product-brief.md` or a `product-brief-*.md` variant. Named siblings are used if available. Every route runs steps 1–2's checks in full.

- **PRD exists** → steps 1–5, once per feature, dependencies first.
- **One behavior, no product decision** (a tweak, a bug fix) → its REQ, ACs and a line per trap found, in the owning spec or inline.
- **Batch call from a full-PRD pass** → `[Assumed]` defaults; no questions, splits or renames (propose them); step 4 only verifies row, entry and filename.
- **Review a spec** → Review Mode.
- **No PRD**: live product → ask where requirements live, else a standalone spec without step 4, offering a PRD (`prd-craft`); nothing built → `prd-craft`, after a brief (`product-brief`) if none exists.
- **Contradicts a `[never]` or unfired `[later]` non-goal, or replaces the PRD's problem, target users or success metric** → stop for the caller (a new direction: `product-brief` first); a fired `[later]` proceeds, its §7 line reported.

## 1 · Frame

**Read** the PRD, the specs this touches and their shape, today's behavior, roles and records (the code, else ask), and any thread, ticket or data cited.

**The request is a guessed solution.** Find the problem behind it, who else has it, and who receives the result (whoever imports, approves or acts on its output). When the problem reaches past the request (another feature, a part the recipient needs, a wrong premise), spec what closes it or hand it off with REQ-level detail. A cheaper fix (a setting, docs, an existing feature) is the first Decision; a request the target segment wouldn't use unchanged is custom work, specced behind a per-account flag and flagged.

**Ask in one batch** only what the docs and request leave open; unanswered → the default, marked `[Assumed]`.
1. What triggered this, who hits it, how often, and what do they do today? *(as stated; frequency unknown)*
2. Who receives the result, and what must they do with it, end to end? *(their whole job, trigger to result in use)*
3. What would show it worked, and what must not get worse? *(the problem solved; the PRD's guardrails)*
4. A hard date or required sign-off, and what binds it (a gatekeeper, a legal clock, a contract, a promise to users)? *(none; the PRD's approver)*

**Split only when the first part alone completes the recipient's job**; otherwise keep every part the job needs, behind a named cut line if the caller may want less. Journeys that could ship months apart, each completing its own job → propose the split (`depends on:`), writing the first.

**Patch or new.** An unshipped spec with the same entity and journey, or this feature's `Depth: stub`, is revised in place, keeping its key and REQ IDs (a stub rebuilt in the house shape, minus its marker). A change to a shipped capability is a new spec and key (`depends on:` the shipped key), with `Changed by` lines in the shipped spec. A new spec needs its own outcome and could ship or be killed alone.

## 2 · Settle

**Walk every lens**; each finding becomes a REQ, AC, edge case, Decision or Open Question, one line at least, never left implicit.
- **Actors**: everyone the change touches, not only who starts it (other parties to a shared record, the recipient, support, the approver, anyone on stale state: an old app version, a link already sent), each with a journey.
- **Entities** it creates, changes or reads: states (who moves one, who repairs a stuck one, deletion and dependents); empty, invalid, 1, the limit, limit + 1; expiry and day boundaries; entitlement (plan, role, region) and users' work after losing it; a repeated or concurrent action; a slow or failed dependency and a half-done action (what users see; what is kept, retried or rolled back); a hostile user; what must hold before and after (totals, balances, counts), as ACs.
- **Data**: each value's source and how far to trust it (user, third party, computed); every copy (vendors, sent files and messages, exports, logs, backups, text inside other records), its retention checked against any binding deadline, and which copies nobody can recall. For each value leaving the product, state its unit (currency minor units too), precision and rounding, sign, time zone and date basis, locale format, snapshot or live, and what the receiving tool does with it (spreadsheets run formulas); fields the recipient doesn't need stay out.
- **Cutover**: records that predate the feature; other features that read them; work in flight (pending transactions, open refund or dispute windows, queued or overdue requests, today's workarounds), with a do-now step for anything at risk now.

**Existing data is a one-way door**: changing it is a Decision. Another feature whose behavior changes gets one line under its affected REQ, `Changed by {feature}#REQ-NNN (date)`, never a rewrite; no spec → Rollout names it.

**Decide, don't defer.** Where an engineer could build it two ways and a user would notice, decide, data semantics included (retention period, validation strictness, default formats, which date counts). One default beats a setting unless two groups provably need opposite behavior or law, region or accessibility requires one. Open Questions are only missing facts (numbers, legal, contracts) and calls above the spec's authority (price or plan, a non-goal, a new segment). More than five: discovery isn't done; flag it.

**Inherited constraints** become REQs with ACs: each PRD constraint it touches (default §8 envelope; no PRD: the code and config, else ask); each law, its binding date checked at the source (unknown → an Open Question); personal data's retention and erasure; the feature's own bars for volume (typical and limit per account), waiting time, accuracy and data loss. A constraint it must break is never edited: spec the needed behavior and flag it for its owner's sign-off. A model in the loop adds the AI tolerances the PRD lacks (tolerated error by failure type, wrong vs harmful; how users notice and recover; cost ceiling per successful task; interactive or deferred; actions without a person's approval), with ACs as pass rates per failure type on 3–5 seed inputs, each with acceptable and unacceptable outputs; must-never cases pass every run.

## 3 · Write — Feature Spec Template

**House shape first**: where sibling specs exist, map this content into their headings, header fields and requirement format, adding a heading only where they lack one; otherwise use the template. Plain sentences a newcomer reads cold, no coined labels or shorthand. Key: the user capability in kebab-case (`team-workspaces`, not `add-teams` or `invite-service`). Comments are rules for you, not file content.

```markdown
# [Feature Name]
PRD: [§1 problem or §4 metric served] · Status: Draft | Approved | Shipped | Retired (date): reason · Owner: [who approves it] · Last Updated: [YYYY-MM-DD] · Depends on: [keys | none]
<!-- Words size the file, not the analysis: S ≤ 700 (one actor, no new entity, existing data untouched) · M ≤ 1,400 (a new entity or role, or existing data touched) · L ≤ 2,400 (a lifecycle with permissions, a migration or other features changed); money, law, an external recipient or others' data: one class up (above L ≤ 3,500); all ≤ 200 lines. State each fact once. Over either cap, cut restatement, narration and HOW, never a trap, then run over and say why in the report; never split a job across specs to fit. Every section stays (`n/a — reason`). -->

## Problem & Outcome
[The PRD problem this serves and its size here: who hits it, how often, at what cost; what they do today; who receives the result and what they do with it; evidence, with its source.]
Outcome: [signal] · baseline · target by [date] · guardrail · measured by [event or query] · if missed: [next step]
<!-- Target the problem solved for those who have it, never the share a cut-down scope reaches; partial scope is a named gap. The PRD's metric only if this feature alone moves it; adoption is a leading signal, not the outcome. Compliance, contract or parity work: name the driver; done when ACs pass. Each number shows its source or arithmetic; an unknown baseline is measured by a named milestone; an untracked event → instrumenting it is a REQ. -->

## User Journeys
[Per affected actor, initiator or not: trigger → each step → what the system does → what they end with. Alternates only where behavior differs.]
<!-- No screens, layouts or controls. -->

## Requirements
- **REQ-001** [Must] An admin can export the current report view as CSV.
  - AC: Given a filtered view of 1,200 rows, when the admin exports, then the file holds exactly those rows in view order, timestamps in the workspace time zone.
  - AC: Given a member without the admin role, when they try to export, then no export is offered and a direct request is refused.
<!-- One behavior per REQ. [Must] only if the outcome fails without it. Each AC ends in an observable result a tester who never spoke to you can run; role-gated or input-taking REQs add a negative AC. A part the caller may cut sits below `Cut line: [what the recipient loses without what follows]`, its REQs [Should]. IDs are append-only: dropped → `REQ-004 — removed (date): reason`; changed after ship → a new REQ, the old one `superseded by REQ-0NN` once it ships. -->

## Edge Cases & Error States
- [condition no AC states] → [behavior; what the user sees] → REQ-00N

## Decisions
| Decision | Chosen | Rejected (why) | Reversible? |
|---|---|---|---|
<!-- Product-visible choices (for developer users, the API they call) and data semantics, plus a row per proposal in the request or its thread, technical ones included: adopted, reframed as its user-visible meaning ("cache the totals" → "totals up to 5 minutes old, labeled"; its mechanism goes to architecture), or rejected with a reason its owner would accept. `(proposed)` where the caller should confirm. Not reversible: what is kept to recover, or `no, accepted because …`. -->

## Rollout & Existing Data
Existing records, users, integrations, old app versions: [backfill rule | unchanged]; who notices, how they learn. In flight: [item → behavior; do now: …]. Rollout: [all | opt-in | flagged: cohort]. Off switch: [how; what remains]. Stages, if a date binds: [stage — deadline, who checks — REQs — what later stages keep]. Features changed: [{feature}#REQ-NNN → new behavior].
<!-- Stages: the first meets the earliest deadline and builds nothing later stages redo. Weak evidence (asks only, or [Assumed]) → a flagged cohort until the outcome check; a change users rely on → announced, staged, off switch tested. -->

## Out of Scope
- [Adjacent capability readers will expect] — why — revisit when [signal].
<!-- Never a part the recipient's job needs: that stays in, below the cut line. -->

## Open Questions
- [ ] [Question] — blocks: REQ-00N · owner: [who] · default if unanswered by [milestone]: [value]
```

## 4 · Patch the PRD

Find both sections by role (default §5 Feature Overview, §6 Dev Order) and patch in place, never duplicating; either missing → ask the caller where.
- **Row**: `| {feature} | what the user can do, one line | [features/{feature}.md](features/{feature}.md) |`; no Spec column → link from the description.
- **Entry**: `N. {feature} — why here [Must] (depends on: x)`, after its dependencies and shipped work, in the release its deadline or rationale fits (else the last planned); renumber what follows; moving ahead of other planned work is a proposal, in the report. Tag it only where that release's entries are tagged (prd-craft: the release holding the cut line), else propose a tag in the report: [Must] only if the release can't ship or the outcome fails without it, above the cut line with the builder's `([estimate range])` or `(estimate owed)`, the report flagging the Musts total as stale; else [Should] or [Could], below it; `(proposed)` after the tag unless the caller set it.
- **Last Updated** bumped. **Nothing else** but one reported Target Users line for an additive change (a secondary role within the segment). Never consolidate or reword others' sections; past the 400-line cap, keep both to one line and report it.

## 5 · Report Back

A summary, ≤ 200 words, not the spec, each material finding on a line, kept even past the budget: flags first (partial scope and what stays unsolved, custom work, discovery not done, a constraint awaiting sign-off, an overrun and why); files written or patched, `Changed by` lines included; size and PRD tag; `(proposed)` decisions, Open Questions and `[Assumed]` defaults to relay; findings beyond this spec, with who should act; no time estimate the spec can't support. Next, if available: `arch-decision` (one architecture decision) or `software-architecture` (several; AI Feature Mode for a model in the loop); `database-design` (new or changed data); `ux-design` (a new multi-screen flow) or `screen-design` (other UI).

## Review Mode

A critique, never a rewrite (premise or scope: plan-review's scope mode); asked to fix, apply its Critical and High patches. Judge function, not format: any shape an engineer and a tester could work from passes. Report Quality Bar failures only, ≤ 400 words (every Critical and High, whatever the budget), verdict first: ready to build · ready after the Critical fixes · not ready (no problem or outcome); patch text, REQ IDs kept, for Critical and High.

## Quality Bar

Run before returning and fix what fails.
- **Critical**: an engineer must guess what users see (an undecided fork, a REQ without an AC, data changed with no recovery, a contradicted non-goal); the recipient's job can't complete and no cut line or hand-off says so; a fact is invented.
- **High**: an AC a tester can't run (an unset limit); a missing negative AC; a stuck state nobody repairs; an unmeasured outcome; a step 2 lens skipped (an actor without a journey, work in flight, a copy or an exported value's semantics unstated); a proposal without a Decision; a binding date without stages; a renumbered or reused REQ ID.
- No Solution Masquerading as a Problem, Technical Spec or Design Document in Disguise (technology only where imposed) or Output-Metric Trap (e.g. `prd-craft/references/anti-patterns.md`, if available).
- Kickoff test: list the first five questions the engineer, the recipient and whoever signs off would ask; each lands on a REQ, Decision or Open Question. Two ACs, one negative, walked as test steps, need no question.
- Footprint: within the class's word budget and 200 lines, or over only for material findings, reported; no fact stated twice; nothing narrates this method.
- PRD: the header ties back; step 4 holds, tag written or proposed; key = filename; `depends on:` targets exist; sibling specs' shape kept (when writing).
