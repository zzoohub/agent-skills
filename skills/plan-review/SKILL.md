---
name: plan-review
description: |
  Pre-build plan review: a verdict and the decisions due before work starts.
  Scope mode (CEO/founder lens), while scope is negotiable: premise, evidence,
  riskiest assumption; cut, hold or expand a brief, PRD or spec. Execution
  mode (eng-manager lens), once a design doc locks scope: build order,
  one-way doors, rollout, failure handling, tests.
  Use when: "review my plan", "poke holes in this plan", "are we building
  the right thing", "should we scope this up or down", "find the 10x
  version", "is this ready to implement".
  Do NOT use for: a document's own quality (product-brief, prd-craft,
  feature-spec), architecture critique (software-architecture) or code
  (review-checklists, reviewer agent).
---

# Plan Review (scope mode · execution mode)

**Scope mode** (CEO/founder lens) asks whether this is the right thing, at the right size, now; **execution mode** (eng-manager lens), whether a locked plan will survive the build and work can start.

**Read-only**, enforced by this rule, not the host: don't edit files, rewrite the plan or start implementing; use the shell only to read, never to stash, check out, commit or write.

**Return; don't ask.** In one pass, return to the caller a verdict, the few changes that must come first, and the decisions only the owner can make; the caller relays them. Follow-ups are proposed, never recorded or tracked.

**Not this skill** (route there if available): a document's own quality → its authoring skill (product-brief, prd-craft, feature-spec); architecture quality or docs↔code drift → software-architecture's Review mode; code → review-checklists or the reviewer agent; pricing or go-to-market plans → the marketing skills (e.g. pricing).

## 1. Locate and classify

**Mode follows the question, not the repo.** Read only that mode's file.

| The request | Mode | Read |
|---|---|---|
| Whether, what, how much: premise, scope up or down, commit or cut | scope | `references/scope-mode.md` |
| How, ready, what breaks, on scope already decided; a hotfix or incident follow-up | execution | `references/execution-mode.md` |
| Neutral ("review my plan") | execution if a design doc or implementation plan was written for this change, else scope | that mode's file |

Unsure → pick one.

**The plan.** The one the caller names or pastes; else the plan in the conversation or the host's plan file; else, by mode, the PRD (default `docs/prd/prd.md`, with `features/*.md` and `product-brief.md` beside it) or the design doc (default `docs/arch/system.md`). The caller may redirect any path. Two candidates → the one closest to the request, named. No plan → ask the caller for one, naming who writes it (product-brief or prd-craft for scope, software-architecture for execution, if available); never invent one.

**First questions.** Answer from the docs and code, never by pausing to ask; where nothing readable answers, apply the default and list it under Assumed. A default that could flip a Blocker is also an unresolved decision.

| Question | Default |
|---|---|
| What is the requester deciding, by when, and what worries them? | Go or no-go on the whole plan |
| The goal, how we'd know it worked, and the non-goals? | No goal → the first finding, and maybe the only one worth making. No measure its altitude calls for (below) → a finding |
| What is already settled? | ADRs, mandates, an earlier review's owner decisions and, for a spec, its PRD; in execution mode, also the scope and premise the design locks |
| Capacity: people × weeks, and any hard date? | The plan's own estimate; none → say so once |
| Load and data volume, where a migration, hot path or cost depends on it? | An `est.` figure with its inputs |

**Altitude.** Judge the plan at its own level of detail.

| Altitude | Can be held to |
|---|---|
| Brief | problem, evidence, riskiest assumptions, a Success Signal (no target or date), the Decision and its next test (pass and kill numbers); never features, a cut line or a timeline |
| PRD or feature spec | outcomes, each with a number and a date (mandated or parity work: its acceptance gate; a personal tool: one observable behavior); users; scope and its cut line; the one-way doors the scope implies |
| Design doc | components, data, contracts, rollout, failure handling |
| Implementation plan | the same, plus files and steps, checked against the code |

Never demand detail below the plan's altitude: a PRD has no error types or `file:line`. A missing level is one finding naming who produces it, not invented precision. A broken premise one level up is raised once, labeled *new information*; then stop reviewing the detail it invalidates.

**Depth comes from what can't be undone, not from size.** A trigger fires when the plan changes it, not when it reads or displays it: persisted data (a new table, a changed meaning, a destructive migration; not an added nullable column); money; who can do what; personal data collected, kept longer or shared outward; a public or partner contract; an irreversible user-visible action; a new external dependency, an LLM or agent included; config, prompts or data pushed to everyone at once; another legal duty (accessibility, a regulated domain). None → light; one → standard; two or more, or a one-way door (§ 4) on [Said] or [Assumed] evidence → deep. A 20-file rename is light; a one-line change to refund math is standard. Size and the caller's question add checks, never depth: the check that answers the question always runs; the mode file says what size adds. *Break:* a quick look or a near deadline → the light budget, but every fired trigger still gets a line.

## 2. Gather evidence

Read in this order; stop when the next source can't change the verdict.

1. Upstream intent: the outcome the plan serves (the brief behind a PRD, the PRD behind a design doc).
2. The project conventions file (e.g. `AGENTS.md` or `CLAUDE.md`; follow its imports). It may redirect doc roots.
3. With a repo: the code the plan changes, its consumers, and the existing pattern new work should copy.
4. The touched paths' history: reverts and churn, which earn more scrutiny; work in flight on them in any branch, open PR or the working tree (`git log --oneline --all --not <default branch> -- <paths>`, as of the last fetch; `git status --short`); TODO and FIXME debt where the plan lands; how long the last comparable change took, for capacity.

Cite `path:line` for every claim about code. With no repo, say so and review the documents alone.

## 3. Review

Run the mode file's checks at step 1's depth, under these rules:

- **A finding is a failure scenario**: what breaks, for whom, when, traced to a plan line or its absence. Without one it is at most Minor; a preference is not a finding. Zero Blockers is a valid result.
- **Proportion**: rigor goes where being wrong is silent, irreversible, or costs money or trust; a visible, reversible risk ships with a signal that would show it. *Break:* regulated or safety-critical domains, where the duty sets the bar.
- **Leave to the owner** (as an unresolved decision) only what changes scope, a one-way door or a commitment, when nothing readable answers it; decide the rest yourself, in one line with the reason.
- **Settled stays settled**: don't re-argue what's settled on the same information. Raise a reversal once, labeled *new information*, with the evidence the decision lacked. A re-review covers only what changed and what it touches; a new finding on unchanged text must be Major or worse, labeled *missed earlier*.
- **Grade evidence** as the product brief does, with a source: [Committed] money, an LOI or a pilot; [Observed] behavior seen or recorded; [Said] an account of a specific past instance; [Assumed] the rest, including future intent and applied defaults. Tag numbers as the PRD does: measured, est., target or unknown.
- **Diagram only** an async flow with three or more parties, or four or more states (show the illegal transitions).

## 4. Severity

- **Blocker** (Critical in sibling reviews; change the plan before work starts):
  - data loss or corruption, a security or privacy exposure, or a money error;
  - a failure nobody would notice (the user sees nothing, no signal fires) on a critical path: money, data, auth or a must-not-lose write;
  - a retried or replayed side effect without idempotency;
  - an LLM or agent holding untrusted input, private data or systems, and the power to act or send outward in one session, with no person approving;
  - a one-way door that closes before anything in the plan tests the [Said] or [Assumed] assumption it rests on;
  - a plan that can't reach its stated goal, or states none;
  - in scope mode, what drives a Stop, Test first or Re-scope verdict.
- **Major** (High): likely a week or more of rework, or an incident, unless settled before or early in the build.
- **Minor** (Medium): fix during the build.

**One-way door**: once users or systems depend on it, undoing it needs others' cooperation, loses data or trust, or costs more than building it did. One-way: identity and cardinality in the data model, deletions, sent messages, data shared outward, and anything published (price, API, event or file format, SLA). Two-way: flagged, expand/contract and additive internal changes.

## 5. Output

**Budget, registry and diagrams excluded: ≤400 words light, ≤800 standard, ≤1,400 deep.** Each Blocker ≤60 words, each Major ≤40; ≤5 decisions (more → keep those that block the earliest work, the rest become defaults under Assumed); ≤7 Minors, one line each. Sections are a menu: omit any that would be empty, heading included.

```
**Verdict: <the mode's verdict>.** <One sentence why, answering any named worry even when the bigger risk lies elsewhere.>
Reviewed: <plan path> (<brief | PRD | spec | design doc | implementation plan>), <mode> mode (<why, if a judgment call>), <depth> depth (<triggers fired>). Goal as read: <one line>. Assumed: <defaults applied, or none>.
Since the last review: <each earlier Blocker and decision: resolved (where) or open>

**Blockers**
- <plan location>: <what breaks, for whom, when> → <required change, or the decision it needs>
**Majors**
- <same shape>
**Unresolved decisions** (for the owner)
- <question> Options (2–4), recommended first: <option>, because <reason> / <option>: <one-line trade-off> … Blocks: <what>.
**Fix during build**
- <one line each>
**Failure registry** (design doc or implementation plan; gap rows, plus an incident's own failure)
BOUNDARY | FAILURE | POLICY | USER SEES | SIGNAL → OWNER | TEST
**Proposed follow-ups**
- <what> · <why> · due when <trigger> · <S/M/L>
**What's sound** (≤3 lines, plus one per fired trigger with no finding)
- <what is right and must stay, so nobody "fixes" it>
```

Over budget, cut in order: What's sound to its trigger lines, follow-ups to what · trigger, Minors, Majors to one line each; never the verdict, Blockers, decisions, or a follow-up holding deferred scope. Unanswered decisions: the recommended option stands provisionally and stays listed.

## Self-Review

- [ ] The verdict leads with its reason, answers any named worry, and is the first rung of the mode's ladder that applies; whatever drives it is a Blocker (none → Ready or Commit).
- [ ] Every Blocker and Major has a plan location, a failure scenario and a change; one without a scenario drops to Minor or goes. Every fired trigger has a finding or a What's sound line.
- [ ] Nothing sits below the plan's altitude, and no finding would fit any plan: tie each to a plan line or cut it.
- [ ] No unresolved decision is answerable from the docs or the code (answer it yourself), and nothing settled is re-argued without new information.
- [ ] **Footprint**: count the words against the depth's budget; ≤5 decisions; ≤7 fix lines; no method narration (steps run, checks walked, counts).
