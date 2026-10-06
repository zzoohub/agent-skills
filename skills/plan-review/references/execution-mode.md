# Execution Mode — eng-manager lens (locked-scope execution rigor)

Loaded by `plan-review` when a design/architecture doc has locked scope. The shared skeleton — mode choice, plan discovery (Step -1), pre-review audit, engineering preferences, documentation and diagrams, section gate, question protocol, proposed follow-ups, formatting — lives in `SKILL.md`; this file holds what is specific to execution mode.

Review this plan thoroughly before any code is written. Scope is fixed: no premise challenge, dream-state mapping or temporal interrogation. Raise scope concerns once, in Step 0; afterward optimize within the chosen scope. For a genuine scope rethink or a 10x-ambition pass, switch to scope mode (`references/scope-mode.md`) explicitly.

## Priority hierarchy
If you are low on context or asked to compress: Step 0 > Test diagram > Failure modes > Security checks (§1) > Opinionated recommendations > Everything else. Never skip Step 0 or the test diagram; security may be compressed but never dropped.

## Step 0: Scope Challenge
Answer these before reviewing:
1. **What existing code already partially or fully solves each sub-problem?** Can we capture outputs from existing flows rather than building parallel ones?
2. **What is the minimum set of changes that achieves the stated goal?** Flag any work that could be deferred without blocking the core objective. Be ruthless about scope creep.
3. **Complexity check:** >8 files touched or >2 new classes/services is a smell — challenge whether the same goal can be achieved with fewer moving parts. (Distinct from scope mode's >15-file REDUCTION trigger.)
4. **Deferred-work check:** If the caller supplied known deferred or in-flight work, is any of it blocking this plan? Can any be bundled in without expanding scope? Does this plan create new work to propose as a follow-up?

Then ask which sub-mode (one decision — see "How to ask questions" in `SKILL.md`):
1. **TRIM:** Trim *clearly redundant* work from the fixed plan, then review the trimmed version. This removes obvious dead weight only — it does NOT re-open scope or rethink premises. (Distinct from scope mode's SCOPE REDUCTION, which genuinely cuts scope.) For a genuine scope rethink or a 10x-ambition pass, switch to scope mode.
2. **BIG CHANGE:** Work through interactively, one section at a time (Architecture → Code Quality → Tests → Performance), at most 8 top issues per section.
3. **SMALL CHANGE:** Compressed review — Step 0 + one combined pass covering all 4 sections, picking the single most important issue per section (think hard — this forces prioritization). Present as one numbered list at the end, then ask the issues as a short sequence of decisions (one per section's top issue — never a single fused mega-question).

Context-dependent defaults (recommend first): clear redundancy already spotted
in Step 0 → TRIM; plan touches ≲8 files or a single component → SMALL CHANGE;
multi-component design doc → BIG CHANGE. Non-interactive runs don't stall here:
apply the default, record `UNRESOLVED-AUTO (mode defaulted)` in Unresolved
Decisions, and continue.

**If the user does not pick TRIM, respect that fully.** Your job becomes making the chosen plan succeed, not lobbying for a smaller one. Raise scope concerns once here; afterward optimize within the chosen scope. Do not silently reduce scope, skip planned components, or re-argue for less work in later sections.

## Review Sections (after scope is agreed)
Each section ends with the section gate (`SKILL.md`).

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
  gates — switch to scope mode's HOLD SCOPE (`references/review-sections.md`);
  post-code, the security pass of a review-checklists capability, if available.
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
* Areas over-engineered or under-engineered relative to the engineering preferences.
* Existing ASCII diagrams in touched files — still accurate after this change?

**STOP — apply the section gate.**

### 3. Test review
Make a diagram of all new UX, new data flow, new codepaths, and new branches/outcomes. For each, note what is new in this plan. Then ensure each new item has a test (vitest, nextest, pytest, or the project's test runner). For each, name the happy-path test, the failure-path test (which specific failure), and the edge-case test (nil, empty, boundary, concurrent).

For LLM/prompt changes: check project conventions for prompt-related file patterns. If this plan touches any of them, state which eval suites must run, which cases to add, and what baselines to compare against. Then confirm the eval scope with the user — phrased as concrete options (e.g. "Run suite X only" / "Run X + add cases Y" / "Skip evals"), not a yes/no — via the question protocol.

**STOP — apply the section gate.**

### 4. Performance review
Evaluate:
* N+1 queries and database access patterns.
* Memory-usage concerns.
* Caching opportunities.
* Slow or high-complexity code paths.

**STOP — apply the section gate.**

## Required outputs (execution mode)
Per **`references/required-outputs.md`**: "NOT in scope", "What already exists", Diagrams, Failure modes (one realistic failure per codepath in the test-review diagram), Proposed follow-ups (`SKILL.md`), the execution-mode completion summary, and Unresolved decisions. BIG CHANGE and TRIM produce all of them.

In SMALL CHANGE mode, the required outputs reduce to: test diagram + failure modes + completion summary + a single follow-ups round (still one question per proposed follow-up — the "never batch" rule holds).
