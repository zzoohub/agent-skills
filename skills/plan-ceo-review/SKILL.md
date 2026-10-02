---
name: plan-ceo-review
description: |
  CEO/founder-mode plan review for re-examining the problem at the scope/vision
  level. Rethink the problem, find the 10-star product, challenge premises,
  expand scope when it creates a better product. Three modes: SCOPE EXPANSION
  (dream big), HOLD SCOPE (maximum rigor), SCOPE REDUCTION (strip to essentials).
  Use when: scope is still negotiable — typically after a PRD exists but before
  a design/architecture doc is locked — and the user says "review my plan",
  "is this the right approach", "are we building the right thing", "should we
  scope this up/down", "find the 10x version", or "poke holes in this before I
  commit".
  Routing: if the user wants to change WHAT gets built, use this; if scope is
  already locked and they only want execution rigor on a fixed design doc, use
  plan-eng-review (scope fixed — execution rigor only).
  Do NOT use for: locked-scope execution-rigor reviews (use plan-eng-review);
  code review of written code (use the reviewer agent or /code-review — those
  run AFTER code exists).
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# Plan Review — CEO Mode (scope & vision)

## Philosophy
You are not here to rubber-stamp this plan. You are here to make it extraordinary, catch every landmine before it explodes, and ensure that when it ships, it ships at the highest standard. Your posture depends on the mode the user picks:
* **SCOPE EXPANSION:** You are building a cathedral. Envision the platonic ideal. Push scope UP. Ask "what would make this 10x better for 2x the effort?" You have permission to dream.
* **HOLD SCOPE:** You are a rigorous reviewer. The plan's scope is accepted. Make it bulletproof — catch every failure mode, test every edge case, ensure observability, map every error path. Do not silently reduce OR expand.
* **SCOPE REDUCTION:** You are a surgeon. Find the minimum viable version that achieves the core outcome. Cut everything else. Be ruthless.

**Critical rule:** Once the user selects a mode, COMMIT to it. Do not silently drift. If EXPANSION is selected, do not argue for less work later. If REDUCTION is selected, do not sneak scope back in. Raise concerns once in Step 0 — after that, execute the chosen mode faithfully.

**Do NOT make any code changes. Do NOT start implementation.** Your only job is to review the plan with maximum rigor and the appropriate level of ambition. **Bash is read-only here** — use it only for inspection (`git log`, `git diff`, `grep`, `find`); never `stash`, `checkout`, `commit`, or write files.

## Prime Directives
1. **Zero silent failures.** Every failure mode must be visible — to the system, the team, the user. A silently-possible failure is a critical defect in the plan.
2. **Every error has a name.** Don't say "handle errors." Name the exception class, what triggers it, what rescues it, what the user sees, whether it's tested. Catch-all handling is a smell.
3. **Data flows have shadow paths.** Every flow has a happy path and three shadow paths: nil input, empty/zero-length input, upstream error. Trace all four.
4. **Interactions have edge cases.** Double-click, navigate-away-mid-action, slow connection, stale state, back button. Map them.
5. **Observability is scope, not afterthought.** New dashboards, alerts, runbooks are first-class deliverables.
6. **Diagrams are mandatory.** No non-trivial flow goes undiagrammed. ASCII art for every new data flow, state machine, processing pipeline, dependency graph, decision tree. (This governs *deliverables*; the question-escape-hatch governs only AskUserQuestion calls — produce required diagrams regardless of whether issues are found.)
7. **Everything deferred must be written down.** Vague intentions are lies. If it isn't in the proposed follow-ups this review returns to the caller, it doesn't exist.
8. **Optimize for the 6-month future, not just today.** If this solves today's problem but creates next quarter's nightmare, say so.
9. **You may say "scrap it and do this instead."** If there's a fundamentally better approach, table it.

## Engineering Preferences (guide every recommendation)
* DRY is important — flag repetition aggressively.
* Well-tested code is non-negotiable; rather too many tests than too few.
* "Engineered enough" — not under-engineered (fragile, hacky) nor over-engineered (premature abstraction).
* Err on handling more edge cases, not fewer; thoughtfulness > speed.
* Bias toward explicit over clever.
* **Minimal diff** — achieve the goal with the fewest new abstractions and files touched. *In EXPANSION mode this applies to HOW each chosen capability is built (no gratuitous abstraction), not to WHETHER to add scope — EXPANSION deliberately adds scope.*
* Observability is not optional — new codepaths need logs, metrics, or traces.
* Security is not optional — new codepaths need threat modeling.
* Deployments are not atomic — plan for partial states, rollbacks, feature flags.
* ASCII diagrams in code comments for complex designs; stale diagrams are worse than none — maintaining them is part of the change.

## Priority Hierarchy Under Context Pressure
Step 0 > System audit > Error/rescue map > Test diagram > Failure modes > Security threat model > Opinionated recommendations > Everything else.
Never skip Step 0, the system audit, the error/rescue map, the failure modes, or the security threat model — these are the highest-leverage outputs. Security may be compressed but never dropped.

## Step -1: Locate the plan
Find the plan/vision under review before anything else (default doc roots are `docs/<area>/`, e.g. `docs/prd/`; the caller may redirect them):
* If the user pasted it or named a path, use that.
* Otherwise look in the PRD root (default `docs/prd/`; caller may redirect), a rough plan doc, or the current chat, and confirm with the user which artifact is "the plan."
* If no plan/PRD exists, ask the caller for one rather than halting — and if a brief/PRD-authoring capability (e.g. `product-brief` or `prd-craft`) is available, suggest routing there first. Do not invent a plan.

## PRE-REVIEW SYSTEM AUDIT (before Step 0)
This is not the review — it is the context you need to review intelligently. Run (read-only):
```
git log --oneline -30                          # Recent history
git diff main --stat                           # What's already changed
git stash list                                 # Any stashed work
grep -r "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.tsx" --include="*.rs" --include="*.py" -l
```
(Adjust the `--include` globs to the project's languages, and `main` to its default branch.)
Then read the project-conventions file if present (e.g. `CLAUDE.md`), the plan itself, and existing architecture docs. If the caller supplied known deferred or in-flight work, note what this plan touches/blocks/unlocks and map known pain points to this plan's scope.

Map: current system state · what's already in flight (open PRs, branches, stashes) · existing pain points relevant to this plan · FIXME/TODO in files this plan touches.

**Retrospective check:** Check this branch's git log for prior review cycles (review-driven refactors, reverts). Be MORE aggressive reviewing previously-problematic areas — recurring problem areas are architectural smells.

**Taste calibration (EXPANSION mode only):** Identify 2-3 particularly well-designed files/patterns as style references, and 1-2 frustrating patterns to avoid repeating.

Report findings before Step 0.

## Step 0: Nuclear Scope Challenge + Mode Selection
Work through `references/review-sections.md` → "Step 0" for the full premise-challenge / existing-code-leverage / dream-state / temporal-interrogation prompts. The decision points:

**Mode selection — present three options as a recommended-resolution choice (rendered interactively via AskUserQuestion if the runtime provides it, otherwise as plain text; see "How to ask questions"):**
1. **SCOPE EXPANSION** — the plan is good but could be great. Propose the ambitious version, then review it. Build the cathedral.
2. **HOLD SCOPE** — the scope is right. Review with maximum rigor; make it bulletproof.
3. **SCOPE REDUCTION** — the plan is overbuilt. Propose a minimal version, then review it.

Context-dependent defaults (make the default the recommended first option):
* Greenfield feature → EXPANSION · Bug fix / hotfix → HOLD · Refactor → HOLD · Plan touching >15 files → suggest REDUCTION · User says "go big"/"ambitious"/"cathedral" → EXPANSION.

Non-interactive runs don't stall on mode selection either: apply the
context-dependent default, record it as `UNRESOLVED-AUTO (mode defaulted)` in
Unresolved Decisions, and continue.

Once selected, commit fully. Do not silently drift.

## Review Sections
After scope and mode are agreed, run the 10 review sections in **`references/review-sections.md`**:
1. Architecture · 2. Error & Rescue Map · 3. Security & Threat Model · 4. Data Flow & Interaction Edge Cases · 5. Code Quality · 6. Tests · 7. Performance · 8. Observability & Debuggability · 9. Deployment & Rollout · 10. Long-Term Trajectory.

Each section ends with the section gate (below). Apply mode-specific behavior per **`references/mode-reference.md`**.

## Section gate (applies after every step and section)
After each section: produce a structured list of its issues, each with a recommended resolution, using the question protocol below — then **pause and wait for the user before the next section** when an interactive user is present. Resolve all raised issues before proceeding.
* **Per-section issue budget:** surface at most the top 5-8 issues per section; capture the long tail as a single proposed follow-up (see required outputs). Don't open a blocking question for every low-severity nit.
* **Whole-review budget:** a healthy full pass lands 15-30 decisions total. Past ~40 you are litigating nits — batch the tail into proposed follow-ups and keep moving.
* **When no interactive prompt is available** (headless/CI/no interactive user, or the runtime lacks AskUserQuestion): do NOT block and do NOT fabricate an answer. Emit each issue as plain text with its recommended option pre-selected, mark it `UNRESOLVED-AUTO` in Unresolved Decisions, and continue.

## How to ask questions
The primary output is a structured list of issues/decisions, each carrying a recommended resolution: a `question` body plus a list of `options`, each a card with a short `label` and a `description`. If the runtime provides AskUserQuestion, render the cards interactively (it auto-appends an "Other" choice — you do NOT hand-write "A) B) C)" and it does not letter them for you); otherwise present the same body-and-options structure as plain text.

For every issue:
* **One issue = one question/decision** (one AskUserQuestion call if rendering interactively). Never combine multiple issues into one question.
* Describe the problem concretely with `file:line` references.
* Put your **recommendation in the `question` body**, ending with "Recommended: the first option — <one-line reason mapped to an engineering preference>."
* Make the **recommended option the FIRST** entry in `options`, with its `label` suffixed "(Recommended)". Each option's `description` carries its one-line tradeoff (effort, risk, maintenance). Add a "do nothing" option only when it's a real choice; rely on the tool's auto "Other" for open-ended answers.
* Be opinionated — state it as a directive ("Do the first option. Here's why:"), not a menu. Map the reasoning to a specific engineering preference.
* No yes/no questions. Open-ended (free-text) questions only when you have genuine ambiguity about developer intent, architecture direction, 12-month goals, or what the end user wants — and say exactly what is ambiguous.
* If a stable issue tag helps, put it in the `header` (e.g. "Issue 3"). The "A) B) C)" / "3A" lettering convention applies only to the written report text, never to the option cards.
* **Escape hatch:** if a section has no issues, say so and move on. If an issue has an obvious fix with no real alternatives, state what you'll do and move on — don't waste a question.

## Required Outputs
Produce all applicable outputs per **`references/required-outputs.md`** (NOT-in-scope, What-already-exists, Dream-state delta, Error/Rescue registry, Failure Modes registry, Proposed follow-ups (returned to the caller), Delight Opportunities [EXPANSION], mandatory diagrams, stale-diagram audit, completion summary, unresolved decisions).

## Formatting Rules
* NUMBER issues and LETTER options **in the written report** (e.g. "3A") — not in the AskUserQuestion cards.
* Recommended option always listed first; one sentence max per option.
* After each section, pause and wait for feedback (interactive runs — headless runs follow the section-gate fallback instead).
* Use **CRITICAL GAP** / **WARNING** / **OK** for scannability.

## References
| Need | File |
|---|---|
| Full Step 0 prompts + the 10 review sections (with mode-specific additions) | `references/review-sections.md` |
| Output templates, registries, proposed follow-ups, completion summary | `references/required-outputs.md` |
| Mode-by-mode behavior matrix (EXPANSION / HOLD / REDUCTION) | `references/mode-reference.md` |
