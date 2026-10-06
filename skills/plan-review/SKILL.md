---
name: plan-review
description: |
  Pre-implementation plan review, two modes. Scope mode (CEO/founder lens),
  while scope is still negotiable — typically after a PRD exists but before a
  design/architecture doc is locked: challenge premises, find the 10-star
  product, then SCOPE EXPANSION (dream big), HOLD SCOPE (maximum rigor) or
  SCOPE REDUCTION (strip to essentials). Execution mode (eng-manager lens),
  once a design/architecture doc (e.g. docs/arch/system.md) locks scope:
  architecture, data flow, diagrams, edge cases, failure modes, tests,
  performance — no premise re-litigation.
  Use when: "review my plan", "is this the right approach", "are we building
  the right thing", "should we scope this up/down", "find the 10x version",
  "poke holes in this before I commit" (scope mode); "review my design doc",
  "gut-check this before I build", "find the edge cases / failure modes",
  "is this ready to implement" (execution mode).
  Do NOT use for: code review of written code (use the reviewer agent or
  /code-review — those run AFTER code exists).
---

# Plan Review (scope mode · execution mode)

Review the plan before any code is written. For every issue, explain the concrete tradeoffs, give an opinionated recommendation, and ask for input before assuming a direction.

**Do NOT make any code changes. Do NOT start implementation.** Your only job is to review the plan. **Bash is read-only here** — use it only for inspection (`git log`, `git diff`, `grep`, `find`); never `stash`, `checkout`, `commit`, or write files. Nothing in the runtime enforces this for you; this rule is the only guard.

## Choose the mode
Pick one mode, say which and why, then load **only** that mode's references (scope mode's file points on to `references/review-sections.md` and `references/mode-reference.md`; both modes use `references/required-outputs.md`).

| Situation | Mode | Load |
|---|---|---|
| Scope is still negotiable (a PRD or rough plan, no locked design doc) and the user wants to change WHAT gets built: rethink premises, scope up/down, find the 10x version | **Scope mode** — SCOPE EXPANSION / HOLD SCOPE / SCOPE REDUCTION | `references/scope-mode.md` |
| A design/architecture doc (default `docs/arch/system.md`; caller may redirect) has locked scope and the user wants execution rigor on that fixed plan | **Execution mode** — TRIM / BIG CHANGE / SMALL CHANGE | `references/execution-mode.md` |

* **Execution mode never re-litigates premises:** no premise challenge, dream-state mapping or temporal interrogation. Scope concerns are raised once, in its Step 0; afterward it optimizes within the chosen scope.
* **TRIM ≠ SCOPE REDUCTION.** Execution-mode TRIM removes only clearly redundant work from a fixed plan and never re-opens scope; scope-mode SCOPE REDUCTION genuinely cuts scope.
* **HOLD SCOPE vs execution mode:** choose scope mode's HOLD SCOPE for maximum rigor on the accepted scope AND a premise/dream-state challenge alongside it (the full 10-section review, with security, observability, deployment and trajectory as their own gates). If scope is fully locked and only execution rigor is wanted, use execution mode.
* If the user asks for a genuine scope rethink or a 10x-ambition pass mid-review in execution mode, switch to scope mode explicitly — never drift into it.
* Unclear which applies: ask once (question protocol below). Non-interactive: a locked design doc exists → execution mode, otherwise scope mode; record `UNRESOLVED-AUTO (mode defaulted)` in Unresolved Decisions and continue.

## Step -1: Locate the plan
Find the plan under review before anything else (default doc roots are `docs/<area>/`, e.g. `docs/prd/`, `docs/arch/`; the caller may redirect them):
* If the user pasted it or named a path, use that.
* Otherwise look in the PRD root (default `docs/prd/`) for scope mode, or the architecture root (default `docs/arch/`), then `docs/prd/`, for execution mode — or a rough plan doc, the current branch diff, or the current chat — and confirm with the user which artifact is "the plan."
* If no plan exists, there is nothing to review — ask the caller for one rather than halting. If an authoring capability is available, suggest routing there first: a brief/PRD (e.g. `product-brief` or `prd-craft`) for scope mode; the design doc via `software-architecture` (or the PRD via `prd-craft` if even that is missing) for execution mode. Do not invent a plan.

## Pre-review audit (before Step 0)
This is not the review — it is the context you need to review intelligently. You will be asked to cite `file:line`, name realistic production failure modes, and flag DRY violations — all of which require having actually read the code. Run (read-only):
```
git log --oneline -30                          # Recent history
git diff main --stat                           # What's already changed
git stash list                                 # Any stashed work
grep -r "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.tsx" --include="*.rs" --include="*.py" -l
```
(Adjust the `--include` globs to the project's languages, and `main` to its default branch.)
Then read the project-conventions file if present (default `CLAUDE.md`; caller may redirect the docs/conventions root), the plan itself, and existing architecture docs; `grep` the files the plan touches for existing patterns and `TODO`/`FIXME`. If the caller supplied known deferred or in-flight work, note what this plan touches/blocks/unlocks and map known pain points to this plan's scope.

Map: current system state · what's already in flight (open PRs, branches, stashes) · existing pain points relevant to this plan · FIXME/TODO in files this plan touches.

**Retrospective check:** Check this branch's git log for prior review cycles (review-driven refactors, reverts). Note what changed and be MORE aggressive reviewing previously-problematic areas — recurring problem areas are architectural smells.

Scope mode adds a taste-calibration step here (EXPANSION only — see `references/scope-mode.md`). Report findings before Step 0.

## Engineering preferences (guide every recommendation)
* DRY is important — flag repetition aggressively.
* Well-tested code is non-negotiable; rather too many tests than too few.
* "Engineered enough" — not under-engineered (fragile, hacky) nor over-engineered (premature abstraction, unnecessary complexity).
* Err on handling more edge cases, not fewer; thoughtfulness > speed.
* Bias toward explicit over clever.
* **Minimal diff** — achieve the goal with the fewest new abstractions and files touched. *In scope mode's EXPANSION this applies to HOW each chosen capability is built (no gratuitous abstraction), not to WHETHER to add scope — EXPANSION deliberately adds scope.*
* Observability is not optional — new codepaths need logs, metrics, or traces.
* Security is not optional — new codepaths need threat modeling.
* Deployments are not atomic — plan for partial states, rollbacks, feature flags.

## Documentation and diagrams
* Value ASCII diagrams highly — data flow, state machines, dependency graphs, processing pipelines, decision trees. Use them liberally in the plan and design docs.
* For complex designs, embed ASCII diagrams in code comments: domain models (data relationships, state transitions), route handlers (request flow), middleware (shared behavior), services (processing pipelines), and tests (non-obvious setup).
* **Diagram maintenance is part of the change.** When touching code near an ASCII diagram, update it in the same commit. Stale diagrams are worse than none — they actively mislead. Flag any stale diagrams you find, even outside the immediate scope.

## Section gate (applies after every step and section)
After each section: produce a structured list of its issues, each with a recommended resolution, using the question protocol below — then **pause and wait for the user before the next section** when an interactive user is present. Resolve all raised issues before proceeding.
* **Per-section issue budget:** surface at most the top 5-8 issues per section; capture the long tail as a single proposed follow-up. Don't open a blocking question for every low-severity nit.
* **Whole-review budget:** a healthy full pass lands 15-30 decisions total. Past ~40 you are litigating nits — batch the tail into proposed follow-ups and keep moving.
* **Non-interactive runs** (headless/CI/no interactive user to answer): do NOT block and do NOT fabricate an answer. Emit each issue as plain text with its recommended option pre-selected, mark it `UNRESOLVED-AUTO` in Unresolved Decisions, and continue. Mode and sub-mode selection follow the same rule: apply the context default and record `UNRESOLVED-AUTO (mode defaulted)`.

## How to ask questions
The primary output is a structured list of issues/decisions, each carrying a recommended resolution: a `question` body plus a list of `options`, each with a short `label` and a one-line `description`. How it is rendered depends on the runtime:
* **The runtime has an interactive question tool** (e.g. Claude Code's AskUserQuestion): render each decision with it. Such tools render the option cards and typically auto-append an "Other"/free-text choice — do NOT hand-write "A) B) C)" into the cards; the tool does not letter them for you. Respect the tool's field limits (AskUserQuestion: `header` at most 12 characters, 2-4 options per question).
* **No question tool, but a user is present:** present the same content as numbered questions in plain text — issue number, the body, then lettered options with the recommended one first — and stop for the user's answers before continuing.
* **No user at all:** follow the section gate's non-interactive rule.

For every issue:
* **One issue = one question/decision.** Never combine multiple issues into one question.
* Describe the problem concretely with `file:line` references.
* Put your **recommendation in the `question` body**, ending with "Recommended: the first option — <one-line reason mapped to an engineering preference>."
* Make the **recommended option the FIRST** entry in `options`, with its `label` suffixed "(Recommended)". Each option's `description` carries its one-line tradeoff (effort, risk, maintenance burden). Add a "do nothing" option only when it's a real choice; rely on the free-text/"Other" answer for open-ended responses rather than adding a redundant "something else".
* Be opinionated — state it as a directive ("Do the first option. Here's why:"), not a menu. Map the reasoning to a specific engineering preference.
* No yes/no questions. Open-ended (free-text) questions only when you have genuine ambiguity about developer intent, architecture direction, 12-month goals, or what the end user wants — and say exactly what is ambiguous.
* If a stable issue tag helps, put it in the `header` (e.g. "Issue 3" — keep it short); keep option labels short and human-readable.
* **Escape hatch:** if a section has no issues, say so and move on. If an issue has an obvious fix with no real alternatives, state what you'll do and move on — don't waste a question.

## Proposed follow-ups (returned to the caller)
This skill does **not** record or track work — it only proposes. Approved follow-ups go into a plain list returned to the caller (the main session), which decides what to do with them.

Present each potential follow-up as its own decision via the question protocol (never batch — one per follow-up; never silently skip this step). For each, describe:
* **What:** one-line description of the work.
* **Why:** the concrete problem solved or value unlocked.
* **Pros / Cons:** what you gain; cost, complexity, risk.
* **Context:** enough that someone picking this up in 3 months understands the motivation, current state, and where to start.
* **Type:** `feature | bugfix | refactor | chore | spike | hotfix`
* **Effort:** S / M / L / XL
* **Priority:** `high | medium | low`. high = blocking/critical-this-cycle; medium = important not urgent; low = nice-to-have.
* **Depends on:** prerequisites or ordering constraints, or "None".

Then present options (recommended first): **Keep** — add it to the returned follow-up list · **Skip** — not valuable enough · **Promote** into the current scope and review it now (still no code). (No A/B/C letters on interactive option cards — lettering is report-text only.) Do NOT propose vague bullets — a follow-up without context is worse than none.

## Required outputs
Produce all applicable outputs per **`references/required-outputs.md`** — each is mandatory regardless of whether issues were found (the escape hatch governs questions, not deliverables). It marks which outputs are scope-mode-only and gives each mode's completion summary. Return to the caller: the resolved issue list, the proposed follow-ups, and the Unresolved Decisions list.

## Formatting rules
* NUMBER issues (1, 2, 3...) and LETTER options (A, B, C...) **in the written report** (e.g. "3A") — not in interactive option cards.
* Recommended option always listed first; one sentence max per option — the user should pick in under 5 seconds.
* After each section, pause and wait for feedback (interactive runs — headless runs follow the section-gate fallback instead).
* Use **CRITICAL GAP** / **WARNING** / **OK** for scannability.

## References
| Need | File |
|---|---|
| Scope mode: philosophy, prime directives, Step 0 + mode selection, priority hierarchy | `references/scope-mode.md` |
| Scope mode: full Step 0 prompts + the 10 review sections (with mode-specific additions) | `references/review-sections.md` |
| Scope mode: behavior matrix (EXPANSION / HOLD / REDUCTION) | `references/mode-reference.md` |
| Execution mode: Step 0, TRIM / BIG / SMALL, the 4 review sections, priority hierarchy | `references/execution-mode.md` |
| Output templates, registries, completion summaries (both modes) | `references/required-outputs.md` |
