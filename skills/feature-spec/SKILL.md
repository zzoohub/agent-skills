---
name: feature-spec
description: |
  Write, revise or review the spec for one feature, on a live product or in
  a PRD's planned release: the problem behind the request, requirements with
  acceptance criteria a tester can run, the product decisions a builder
  would otherwise guess, and what happens to existing data. Keeps the PRD's
  scope list in step without rewriting its vision. Use when: "spec out a
  feature", "write requirements for X", "acceptance criteria for X", "a PRD
  for one feature", "add a feature to the PRD", "review this feature spec".
  Never re-run prd-craft to add features. Do NOT use for: a new product's
  PRD (prd-craft); a spec's premise or scope (plan-review).
---

# Feature Spec

## Premise

**A spec is every product decision a builder would otherwise guess.** The builder, often an agent, reads it cold, doesn't ask, and fills each gap with something plausible. Code has become cheap to regenerate, so a wrong guess about a label costs an hour. A wrong guess about existing data, money, or what other people were promised can't be regenerated. So the spec says nothing about how to build, decides everything a user would notice, and puts its depth where a mistake can't be undone.

Five rules follow:

1. **The request is a guessed solution.** Find the problem behind it and who receives the result. The job to finish is theirs.
2. **The first draft covers one person on a good day.** The lenses find everyone and everything else.
3. **Decide, don't defer.** Where a builder could build it two ways and a user would notice, the spec chooses. Open questions are for missing facts and for calls above the spec's authority.
4. **Every requirement has a check a stranger can run.** Acceptance criteria are the test oracle: concrete values in, an observable result out.
5. **Existing data is a one-way door.** What happens to records, users and work that predate the feature is a decision, never an afterthought.

Done means a builder can build it and a tester can test it without asking you anything, and whoever receives the result can finish their job with the first delivery.

## Route

Defaults (the caller may redirect): PRD `docs/prd/prd.md`, specs `docs/prd/features/{feature}.md`, brief `docs/prd/product-brief.md`. Sibling skills named here are used if available. Every route runs steps 1 and 2 in full.

- **A PRD exists:** steps 1–5, one feature at a time, dependencies first. A spec has its own outcome and could ship or be killed alone.
- **An unshipped spec for this feature exists:** revise it in place, keeping its key and REQ IDs.
- **A shipped behavior changes:** a new spec with its own key that `Depends on` the shipped one, plus one line under each REQ it changes there, `Changed by {feature}#REQ-NNN (date)`. Never rewrite a shipped spec.
- **One behavior, no product decision** (a tweak, a bug fix): its REQ and ACs and a line per trap found, in the owning spec or inline.
- **No PRD:** on a live product, ask where requirements live, else write a standalone spec and offer a PRD (`prd-craft`). With nothing built, the PRD comes first, after a brief (`product-brief`) if there is none.
- **The PRD lists it under Never, or under Later with its trigger unmet, or it would replace the PRD's problem, target users or primary metric:** stop and return it to the caller. A new direction needs a brief first.
- **Review a spec:** Review, below.

## 1. Frame

Read the PRD, the specs this touches, today's behavior, roles and records (the code, else ask), and any thread, ticket or data cited.

- **The problem.** Who has it, who else has it, and who receives the result: whoever imports, approves or acts on what the feature produces. A cheaper fix (a setting, documentation, an existing feature) is the first Decision. A request the target segment wouldn't use unchanged is custom work: spec it behind a per-account switch and flag it.
- **The job must finish.** Scope is the recipient's whole job, from trigger to result in use. When the problem reaches past the request (another feature, a part the recipient needs, a wrong premise), spec what closes it or hand it off with requirement-level detail. Split only when the first part alone finishes a job; otherwise keep every part, behind a named cut line if the caller may want less. Journeys that could ship months apart, each finishing its own job, are separate specs: propose the split and write the first.

Ask in one batch only what the documents and the request leave open. Unanswered, the default applies, marked [Assumed]:

1. What triggered this, who hits it, how often, and what do they do today? *As stated; frequency unknown.*
2. Who receives the result, and what must they do with it? *Their whole job, trigger to result in use.*
3. What would show it worked, and what must not get worse? *The problem solved; the PRD's counter-metrics.*
4. Is there a hard date or a required sign-off, and what binds it (a legal clock, a contract, a promise to users)? *None; the PRD's owner approves.*

## 2. Walk the lenses

Every finding becomes a requirement, an AC, an edge case, a Decision or an Open Question: one line at least, never left implicit.

| Lens | Ask |
|---|---|
| **People** | Who does this touch besides whoever starts it: the other party to a shared record, the recipient, support, the approver, someone on an old app version or holding a link already sent? Each gets a journey. |
| **States** | For each thing it creates or changes: which states, who moves it between them, who repairs a stuck one, and what deleting it does to what depends on it? |
| **Limits** | Empty, one, the limit, one past it. Expiry and day boundaries. The plan, role or region that grants it, and what happens to a user's work when they lose it. |
| **Failure** | The same action twice, or two at once. A dependency that is slow or down. An action half done: what the user sees, and what is kept, retried or undone. What a hostile user does with it. |
| **Totals** | What must still add up afterwards: balances, counts, stock, seats. These become ACs. |
| **Copies** | Where each value comes from and how far to trust it (a user, a third party, a calculation). Every copy it makes (vendors, sent files and messages, exports, logs, backups), how long each lives against any binding deadline, and which nobody can recall. |
| **Values that leave** | For each value leaving the product: its unit (minor currency units too), precision and rounding, sign, time zone and date basis, locale format, snapshot or live, and what the receiving tool does with it (spreadsheets run formulas). Fields the recipient doesn't need stay out. |
| **Before and during** | Records that predate the feature, and the features that read them. Work in flight: pending transactions, open refund or dispute windows, queued or overdue requests, today's workarounds. Anything at risk now gets a do-now step. |

- **Changing existing data is a Decision.** Another feature whose behavior changes gets its `Changed by` line (Route), never a rewrite; with no spec for it, Rollout names it.
- **Inherited constraints** become requirements with ACs: each PRD constraint and duty it touches (default §6; with no PRD, the code and config, else ask); each law, its binding date checked at the source; retention and erasure for personal data; the feature's own bars for volume, waiting time, accuracy and data loss. A constraint it must break is never edited: spec the behavior needed and flag it for its owner's sign-off.
- **A model in the loop** adds what the PRD's AI line lacks: tolerated error by failure type (wrong vs harmful), how users notice and recover, the cost ceiling per successful task, interactive or deferred, what it may do without a person's approval. Its ACs are pass rates per failure type on 3–5 seed inputs, each with acceptable and unacceptable outputs; must-never cases pass on every run.

## 3. Decide

Decide data semantics too: the retention period, how strict validation is, default formats, which date counts. One default beats a setting, unless two groups provably need opposite behavior, or a law, a region or accessibility requires the choice. Open Questions hold only missing facts (numbers, a legal reading, a contract) and calls above the spec's authority (a price or plan, a non-goal, a new segment). More than five means discovery isn't finished: say so.

**WHAT, never HOW.** No screens, layouts, components, tables or endpoints. A technical proposal in the request gets a Decisions row: adopted, rejected with a reason its owner would accept, or rewritten as what a user would notice ("cache the totals" becomes "totals may be up to 5 minutes old, and say so"), the mechanism left to architecture. For developer users, the API they call is the product.

## 4. Write

Read `references/examples.md` while drafting: weak lines next to better ones. Where the project's existing specs use another shape, follow theirs and add only the headings they lack. Write plain sentences a newcomer reads cold. The key is the user's capability in kebab-case (`team-workspaces`, not `add-teams` or `invite-service`), and it is the filename.

```markdown
# [Feature Name]
PRD: [the §1 problem or §4 metric it serves] · Status: Draft | Approved | Shipped | Retired (date): reason · Owner: [who approves it] · Updated: [YYYY-MM-DD] · Depends on: [keys | none]
<!-- Comments are rules for you, not file content. Words size the file, not the analysis: about 700 for one actor and no existing data touched; 1,400 with a new entity or role, or existing data touched; 2,400 for a lifecycle with permissions, a migration or other features changed; one step up for money, law, an external recipient or other people's data (3,500 at most). Never past 200 lines. State each fact once. Over the size, cut restatement and HOW, never a trap; never split one job across specs to fit. Keep every section (`n/a — reason`). -->

## Problem & Outcome
[The problem and its size here: who hits it, how often, at what cost; what they do today; who receives the result and what they do with it. Evidence, with its source.]
Outcome: [signal] · baseline · target by [date] · guardrail · measured by [event or query] · if missed: [next step]
<!-- The target is the problem solved for those who have it, never the share a cut-down scope reaches; adoption is only a leading signal. Each number shows its source or arithmetic; an unknown baseline is measured by a named milestone; an event nobody tracks yet makes instrumenting it a REQ. Compliance, contract or parity work: name the driver; done when the ACs pass. -->

## User Journeys
[For each affected actor, whether or not they start it: trigger → each step → what the system does → what they end with. Alternates only where behavior differs.]

## Requirements
- **REQ-001** [Must] A client can cancel a booking from the link in their confirmation text.
  - AC: Given a booking for a class that starts in 5 hours, when the client opens the link and cancels, then the roster shows the spot as open and the client gets a text confirming it.
  - AC: Given a link whose booking was already cancelled, when it is opened again, then nothing changes and the page says the booking was cancelled, and when.
<!-- One behavior per REQ. [Must] only if the outcome fails without it; a part the caller may cut sits below `Cut line: [what the recipient loses without what follows]`, its REQs [Should]. Anything gated by role or taking input adds a negative AC. When one rule has many cases (roles × actions, boundaries, rounding), write them as a table of cases. IDs are append-only: dropped → `REQ-004 — removed (date): reason`; changed after ship → a new REQ, the old one `superseded by REQ-0NN`. -->

## Edge Cases
- [a condition no AC states] → [behavior; what the user sees] → REQ-00N

## Decisions
| Decision | Chosen | Rejected (why) | Reversible? |
|---|---|---|---|
<!-- Choices a user would notice and data semantics, plus a row for each proposal in the request or its thread. `(proposed)` where the owner should confirm. Not reversible: what is kept so it can be recovered, or `no, accepted because …`. -->

## Rollout & Existing Data
- **Existing:** [records, users, integrations and old app versions: backfill rule | unchanged; who notices, and how they learn]
- **In flight:** [item → behavior; do now: …]
- **Rollout:** [everyone | opt-in | flagged: cohort] · **Off switch:** [how; what remains]
- **Stages**, if a date binds: [stage — deadline, who checks — REQs]
- **Features changed:** [{feature}#REQ-NNN → new behavior]
<!-- Evidence that is only asks or [Assumed]: a flagged cohort until the outcome is read. A change users rely on: announced, staged, the off switch tested. With a binding date, the first stage meets the earliest deadline and builds nothing a later stage redoes. -->

## Out of Scope
- [An adjacent capability readers will expect] — why — revisit when [signal]
<!-- Never a part the recipient's job needs: that stays in, below the cut line. -->

## Open Questions
- [ ] [Question] — blocks: REQ-00N · owner: [who] · default if unanswered by [milestone]: [value]
```

## 5. Update the PRD and report

**The PRD's scope list stays true.** Add or update this feature's one line in the PRD's Scope (default §5), link the spec and bump Updated. The line goes under Now when it is to be built next (in an open release: above the cut line only if the release fails without it, otherwise below, marked `(proposed)`), else under Later with what it waits for. A line already there is only linked. Change nothing else: whatever more the feature implies for the PRD is a proposal in the report. A PRD of another shape is patched where it lists features, in its own format; with no such list, ask where. When other specs are being written in parallel, leave the PRD alone and return the line for the caller to apply.

**Report back** in 200 words or fewer, not the spec, with each material finding on a line even past the budget. Flags first: scope left unsolved, custom work, discovery not finished, a constraint awaiting sign-off. Then the files written or patched, the `(proposed)` decisions, Open Questions and [Assumed] defaults to relay, and findings beyond this spec with who should act. Give no time estimate the spec can't support. Next, if available: `arch-decision` (one architecture decision) or `software-architecture` (several; its AI Feature Mode for a model in the loop); `database-design` (new or changed data); `ux-design` (a new multi-screen flow) or `screen-design` (other UI).

## Review

A critique, never a rewrite; a spec's premise or scope goes to `plan-review`, scope mode. Judge function, not format: any shape a builder and a tester could work from passes. Report only what fails the Self-Review, in 400 words or fewer (every Critical and High, whatever the budget), verdict first: **ready to build**, **ready after the Critical fixes**, or **not ready** (no problem or outcome). Give patch text, REQ IDs kept, for Critical and High. Asked to fix, apply those patches.

## Self-Review

Run before returning, and fix what fails.

- **Critical:** a builder must guess what users see (an undecided fork, a REQ with no AC, data changed with no way back, a contradicted Never); the recipient's job can't finish and no cut line or hand-off says so; a fact is invented.
- **High:** an AC a tester can't run (an unset limit, no concrete values); a missing negative AC; a stuck state nobody repairs; an outcome nobody measures; a lens skipped (an actor with no journey, work in flight, a copy or a leaving value's semantics unstated); a proposal with no Decision; a binding date with no stages; a renumbered or reused REQ ID.
- **Medium:** the problem names a solution; technology nobody imposed, or screens; an outcome that is an output; a fact stated twice; over the template's size for no material finding; anything that narrates this method.
- **The kickoff test.** List the first five questions the builder, the recipient and whoever signs off would ask. Each lands on a REQ, a Decision or an Open Question. Walk two ACs, one negative, as test steps: neither needs a question.
- **Joins.** The header ties back to the PRD. The PRD line exists, or is returned. The key is the filename. `Depends on` targets exist. The project's spec shape is kept.
