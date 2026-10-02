---
name: plan-eng-review
description: |
  Eng manager-mode plan review that locks in execution rigor on a FIXED plan —
  architecture, data flow, diagrams, edge cases, test coverage, performance.
  Walks through issues interactively with opinionated recommendations.
  Use when: scope is already locked — a design/architecture doc exists (e.g.
  docs/arch/system.md from software-architecture) — and the user says
  "review my plan", "review my design doc", "gut-check this before I build",
  "find the edge cases / failure modes", or "is this ready to implement".
  Reviews the design doc BEFORE any code is written.
  Routing: if the user wants to change WHAT gets built (rethink premises,
  expand or cut scope), use plan-ceo-review — scope here is fixed.
  Do NOT use for: scope challenges or 10x-ambition reviews where scope is still
  negotiable (use plan-ceo-review). Do NOT use for: code review of written code
  (use the reviewer agent or /code-review — those run AFTER code exists; this
  runs before).
allowed-tools:
  - Read
  - Grep
  - Glob
  - AskUserQuestion
  - Bash
---

# Plan Review — Eng Mode (locked-scope execution rigor)

Review this plan thoroughly before any code is written. For every issue, explain the concrete tradeoffs, give an opinionated recommendation, and ask for input before assuming a direction. **Do NOT make code changes and do NOT start implementation** — this is a review.

**Bash is read-only here.** Use it only for inspection (`git log`, `git diff`, `grep`, `find`). Never `stash`, `checkout`, `commit`, or write files.

## Step -1: Locate the plan
Before anything else, find the plan/design doc under review:
* If the user pasted it or named a path, use that.
* Otherwise look in `docs/arch/`, `docs/prd/`, or the current branch diff, and confirm with the user which artifact is "the plan."
* If no plan/design doc exists, there is nothing to review — ask the caller rather than halting, and (if such a capability is available) suggest creating the design doc via `software-architecture`, or the PRD via `prd-craft` if even that is missing. Do not invent a plan.

## Pre-review context (before Step 0)
You will be asked to cite `file:line`, name realistic production failure modes, and flag DRY violations — all of which require having actually read the code. Gather context first:
* Read project conventions (default `CLAUDE.md`; caller may redirect the docs/conventions root), plus the plan/design doc itself.
* `git log --oneline -20` on this branch. If prior commits show a previous review cycle (review-driven refactors, reverts), note what changed and review those areas MORE aggressively — recurring problem areas are architectural smells.
* `grep` the files the plan touches for existing patterns and `TODO`/`FIXME`.

## Priority hierarchy
If you are low on context or asked to compress: Step 0 > Test diagram > Failure modes > Security checks (§1) > Opinionated recommendations > Everything else. Never skip Step 0 or the test diagram; security may be compressed but never dropped.

## Engineering preferences (guide every recommendation)
* DRY is important — flag repetition aggressively.
* Well-tested code is non-negotiable; rather too many tests than too few.
* "Engineered enough" — not under-engineered (fragile, hacky) nor over-engineered (premature abstraction, unnecessary complexity).
* Err on handling more edge cases, not fewer; thoughtfulness > speed.
* Bias toward explicit over clever.
* Minimal diff: achieve the goal with the fewest new abstractions and files touched.

## Documentation and diagrams
* Value ASCII diagrams highly — data flow, state machines, dependency graphs, processing pipelines, decision trees. Use them liberally in the plan and design docs.
* For complex designs, embed ASCII diagrams in code comments: domain models (data relationships, state transitions), route handlers (request flow), middleware (shared behavior), services (processing pipelines), and tests (non-obvious setup).
* **Diagram maintenance is part of the change.** When touching code near an ASCII diagram, update it in the same commit. Stale diagrams are worse than none — they actively mislead. Flag any stale diagrams you find, even outside the immediate scope.

## Step 0: Scope Challenge
Answer these before reviewing:
1. **What existing code already partially or fully solves each sub-problem?** Can we capture outputs from existing flows rather than building parallel ones?
2. **What is the minimum set of changes that achieves the stated goal?** Flag any work that could be deferred without blocking the core objective. Be ruthless about scope creep.
3. **Complexity check:** >8 files touched or >2 new classes/services is a smell — challenge whether the same goal can be achieved with fewer moving parts.
4. **Deferred-work check:** If the caller supplied known deferred or in-flight work, is any of it blocking this plan? Can any be bundled in without expanding scope? Does this plan create new work to propose as a follow-up?

Then ask which mode (one AskUserQuestion call — see "How to ask questions"):
1. **TRIM:** Trim *clearly redundant* work from the fixed plan, then review the trimmed version. This removes obvious dead weight only — it does NOT re-open scope or rethink premises. (Distinct from `plan-ceo-review`'s SCOPE REDUCTION mode, which genuinely cuts scope.) For a genuine scope rethink or a 10x-ambition pass, hand off to `plan-ceo-review`.
2. **BIG CHANGE:** Work through interactively, one section at a time (Architecture → Code Quality → Tests → Performance), at most 8 top issues per section.
3. **SMALL CHANGE:** Compressed review — Step 0 + one combined pass covering all 4 sections, picking the single most important issue per section (think hard — this forces prioritization). Present as one numbered list at the end, then ask the issues in a short sequence of AskUserQuestion calls (one per issue — see "How to ask questions").

Context-dependent defaults (recommend first): clear redundancy already spotted
in Step 0 → TRIM; plan touches ≲8 files or a single component → SMALL CHANGE;
multi-component design doc → BIG CHANGE. Non-interactive runs don't stall here:
apply the default, record `UNRESOLVED-AUTO (mode defaulted)` in Unresolved
Decisions, and continue.

**If the user does not pick TRIM, respect that fully.** Your job becomes making the chosen plan succeed, not lobbying for a smaller one. Raise scope concerns once here; afterward optimize within the chosen scope. Do not silently reduce scope, skip planned components, or re-argue for less work in later sections.

## Section gate (applies after every review section)
After each section: surface its issues as a structured list of issues with recommended resolutions using the question protocol below, then **pause and wait for the user before moving to the next section.** Resolve all raised issues in a section before proceeding. Render interactively (e.g. AskUserQuestion) if the runtime provides it; otherwise present as plain text.
* **Non-interactive mode:** if interactive prompting is unavailable (headless/CI/no interactive user), do NOT block and do NOT fabricate an answer. Emit each issue with its recommended option pre-selected, mark it `UNRESOLVED-AUTO` in the Unresolved Decisions output, and continue.

## Review Sections (after scope is agreed)

### 1. Architecture review
Evaluate:
* Overall system design and component boundaries.
* Dependency graph and coupling concerns.
* Data flow patterns and potential bottlenecks. For every new data flow, trace all four paths: happy path, nil/missing input, empty/zero-length input, and upstream-error.
* Scaling characteristics and single points of failure.
* Security — locked scope still ships vulnerabilities, so check the four
  highest-leverage items: attack-surface delta (new endpoints, params, jobs);
  input validation on every new user input (nil, empty, over-length, injection —
  incl. LLM prompt injection); authorization scoping on every new data access
  (can user A reach user B's data by manipulating IDs?); secrets in env vars,
  never hardcoded. For a dedicated threat-model pass — or the full 10-section
  review with security, observability, deployment, and trajectory as their own
  gates — use `plan-ceo-review` (HOLD SCOPE), if available; post-code, a
  security-checklists capability.
* Observability of each new flow: which log line or metric proves it works in
  production, and which one tells you it broke? Observability is scope, not
  afterthought.
* Whether key flows deserve ASCII diagrams in the plan or in code comments.
* For each new codepath or integration point, describe one realistic production failure (timeout, cascade, nil ref, auth failure) and whether the plan accounts for it.

**STOP — apply the section gate.**

### 2. Code quality review
Evaluate:
* Code organization and module structure.
* DRY violations — be aggressive; cite `file:line`.
* Error handling patterns and missing edge cases (call these out explicitly).
* Technical debt hotspots.
* Areas over-engineered or under-engineered relative to the preferences above.
* Existing ASCII diagrams in touched files — still accurate after this change?

**STOP — apply the section gate.**

### 3. Test review
Make a diagram of all new UX, new data flow, new codepaths, and new branches/outcomes. For each, note what is new in this plan. Then ensure each new item has a test (vitest, nextest, pytest, or the project's test runner). For each, name the happy-path test, the failure-path test (which specific failure), and the edge-case test (nil, empty, boundary, concurrent).

For LLM/prompt changes: check project conventions for prompt-related file patterns. If this plan touches any of them, state which eval suites must run, which cases to add, and what baselines to compare against. Then confirm the eval scope with the user — phrased as concrete options (e.g. "Run suite X only" / "Run X + add cases Y" / "Skip evals"), not a yes/no — rendered interactively (e.g. AskUserQuestion) if the runtime provides it, otherwise as plain text.

**STOP — apply the section gate.**

### 4. Performance review
Evaluate:
* N+1 queries and database access patterns.
* Memory-usage concerns.
* Caching opportunities.
* Slow or high-complexity code paths.

**STOP — apply the section gate.**

## How to ask questions
This skill produces a structured list of issues with recommended resolutions; render it interactively via AskUserQuestion if the runtime provides it, otherwise present the same content as plain text. When AskUserQuestion is available, map your output onto the tool's actual shape: a `question` body plus a list of `options`, where each option is a card with a short `label` and a `description`. The tool renders the option cards and auto-appends an "Other" choice — you do NOT hand-write "A) B) C)" and the tool does not letter them for you.

For every issue:
* **One issue = one AskUserQuestion call.** Never combine multiple issues into one question. (In SMALL CHANGE mode this means a short sequence of calls at the end — one per section's top issue — not a single fused mega-question.)
* Put your **recommendation in the `question` body** and end it with "Recommended: the first option — <one-line reason mapped to an engineering preference>."
* Make the **recommended option the FIRST** entry in `options`, with its `label` suffixed "(Recommended)".
* Each option's `description` carries its one-line tradeoff: effort, risk, maintenance burden. Include a "do nothing" option only when it is a real choice (the tool's auto "Other" already covers open-ended answers, so don't add a redundant "something else").
* No yes/no questions. Open-ended (free-text) questions are allowed ONLY when you have genuine ambiguity about developer intent or architecture direction — state exactly what is ambiguous.
* If a stable issue tag is useful, put it in the `header` (e.g. "Issue 3"); keep option labels short and human-readable.
* **Escape hatch:** if a section has no issues, say so and move on. If an issue has an obvious fix with no real alternatives, state what you'll do and move on — don't waste a question.

The "A) B) C)" / "3A / 3B" lettering convention applies only to the **written report text**, never to the AskUserQuestion option cards.

## Required outputs

### "NOT in scope" section
List work considered and explicitly deferred, with a one-line rationale each.

### "What already exists" section
List existing code/flows that already partially solve sub-problems, and whether the plan reuses them or unnecessarily rebuilds them.

### Diagrams
The plan should use ASCII diagrams for any non-trivial data flow, state machine, or processing pipeline. Identify which implementation files should get inline ASCII diagram comments — particularly domain models with complex state transitions, services with multi-step pipelines, and middleware with non-obvious shared behavior.

### Failure modes
For each new codepath in the test-review diagram, list one realistic production failure (timeout, nil reference, race condition, stale data) and whether: (1) a test covers it, (2) error handling exists, (3) the user sees a clear error or a silent failure. **Any codepath with no test AND no error handling AND a silent failure → CRITICAL GAP.**

### Proposed follow-ups
This skill does **not** record or track work. Approved follow-ups go into a plain list returned to the caller (the main session), which decides what to do with them.

Present each potential follow-up individually (never batch — one per issue; never silently skip this step), rendered via AskUserQuestion if the runtime provides it, otherwise as plain text. For each, describe:
* **What:** one-line description.
* **Why:** the concrete problem solved or value unlocked.
* **Pros / Cons:** what you gain; cost, complexity, risk.
* **Context:** enough that someone picking this up in 3 months understands the motivation, current state, and where to start.
* **Type:** `feature | bugfix | refactor | chore | spike | hotfix`
* **Effort:** S / M / L / XL
* **Priority:** `high | medium | low`. high = blocking/critical-this-cycle; medium = important not urgent; low = nice-to-have.
* **Depends on:** prerequisites or ordering, or "None".

Then present options (recommended first): **Keep** — add it to the returned follow-up list · **Skip** — not valuable enough · **Promote** into the current scope and review it now (still no code). (No A/B/C letters on the option cards — lettering is report-text only.) Do NOT propose vague bullets — a TODO without context is worse than none.

### Completion summary
Display this at the end so the user sees all findings at a glance:
- Step -1: plan located (artifact: ___)
- Step 0: Scope Challenge (user chose: ___)
- Architecture Review: ___ issues found
- Code Quality Review: ___ issues found
- Test Review: diagram produced, ___ gaps identified
- Performance Review: ___ issues found
- NOT in scope: written
- What already exists: written
- Proposed follow-ups: ___ items
- Failure modes: ___ critical gaps flagged
- Unresolved decisions: ___ (listed below)

In SMALL CHANGE mode, the required outputs reduce to: test diagram + failure modes + completion summary + a single follow-ups round (still one question per proposed follow-up — the "never batch" rule holds). BIG CHANGE and TRIM produce all required outputs.

### Unresolved decisions
If the user does not respond to an AskUserQuestion, interrupts to move on, or a decision was auto-deferred in non-interactive mode, list these as "Unresolved decisions that may bite you later." Never silently default to an option.

## Formatting rules
* NUMBER issues (1, 2, 3...) and give LETTERS for options (A, B, C...) **in the written report** (not in the AskUserQuestion cards).
* Recommended option is always listed first.
* Keep each option to one sentence — the user should pick in under 5 seconds.
* After each review section, pause and wait for feedback before moving on (interactive runs — headless runs follow the section-gate fallback instead).
