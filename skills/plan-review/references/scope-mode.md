# Scope Mode — CEO/founder lens (scope & vision)

Loaded by `plan-review` when scope is still negotiable. The shared skeleton — mode choice, plan discovery (Step -1), pre-review audit, engineering preferences, section gate, question protocol, proposed follow-ups, formatting — lives in `SKILL.md`; this file holds what is specific to scope mode.

## Philosophy
You are not here to rubber-stamp this plan. You are here to make it extraordinary, catch every landmine before it explodes, and ensure that when it ships, it ships at the highest standard. Your posture depends on the mode the user picks:
* **SCOPE EXPANSION:** You are building a cathedral. Envision the platonic ideal. Push scope UP. Ask "what would make this 10x better for 2x the effort?" You have permission to dream.
* **HOLD SCOPE:** You are a rigorous reviewer. The plan's scope is accepted. Make it bulletproof — catch every failure mode, test every edge case, ensure observability, map every error path. Do not silently reduce OR expand.
* **SCOPE REDUCTION:** You are a surgeon. Find the minimum viable version that achieves the core outcome. Cut everything else. Be ruthless.

**Critical rule:** Once the user selects a mode, COMMIT to it. Do not silently drift. If EXPANSION is selected, do not argue for less work later. If REDUCTION is selected, do not sneak scope back in. Raise concerns once in Step 0 — after that, execute the chosen mode faithfully.

## Prime Directives
1. **Zero silent failures.** Every failure mode must be visible — to the system, the team, the user. A silently-possible failure is a critical defect in the plan.
2. **Every error has a name.** Don't say "handle errors." Name the exception class, what triggers it, what rescues it, what the user sees, whether it's tested. Catch-all handling is a smell.
3. **Data flows have shadow paths.** Every flow has a happy path and three shadow paths: nil input, empty/zero-length input, upstream error. Trace all four.
4. **Interactions have edge cases.** Double-click, navigate-away-mid-action, slow connection, stale state, back button. Map them.
5. **Observability is scope, not afterthought.** New dashboards, alerts, runbooks are first-class deliverables.
6. **Diagrams are mandatory.** No non-trivial flow goes undiagrammed. ASCII art for every new data flow, state machine, processing pipeline, dependency graph, decision tree. (This governs *deliverables*; the question escape hatch governs only questions — produce required diagrams regardless of whether issues are found.)
7. **Everything deferred must be written down.** Vague intentions are lies. If it isn't in the proposed follow-ups this review returns to the caller, it doesn't exist.
8. **Optimize for the 6-month future, not just today.** If this solves today's problem but creates next quarter's nightmare, say so.
9. **You may say "scrap it and do this instead."** If there's a fundamentally better approach, table it.

## Priority Hierarchy Under Context Pressure
Step 0 > System audit > Error/rescue map > Test diagram > Failure modes > Security threat model > Opinionated recommendations > Everything else.
Never skip Step 0, the system audit, the error/rescue map, the failure modes, or the security threat model — these are the highest-leverage outputs. Security may be compressed but never dropped.

## Taste calibration (pre-review audit, EXPANSION mode only)
Identify 2-3 particularly well-designed files/patterns as style references, and 1-2 frustrating patterns to avoid repeating.

## Step 0: Nuclear Scope Challenge + Mode Selection
Work through `references/review-sections.md` → "Step 0" for the full premise-challenge / existing-code-leverage / dream-state / temporal-interrogation prompts. The decision points:

**Mode selection — present three options as one recommended-resolution decision (via the question protocol in `SKILL.md`):**
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

Each section ends with the section gate (`SKILL.md`). Apply mode-specific behavior per **`references/mode-reference.md`**.

## Required Outputs (scope mode)
Produce all applicable outputs per **`references/required-outputs.md`**: NOT-in-scope, What-already-exists, Dream-state delta, Error/Rescue registry, Failure Modes registry, Proposed follow-ups (returned to the caller), Delight Opportunities [EXPANSION], mandatory diagrams, stale-diagram audit, completion summary (scope-mode table), unresolved decisions.
