# Required Outputs

Loaded by `plan-review` (both modes). Produce all that apply to the selected mode — items marked *(scope mode)* are scope-mode only. Each is mandatory regardless of whether issues were found (the question escape hatch governs questions, not deliverables).

## "NOT in scope" section
Work considered and explicitly deferred, with a one-line rationale each.

## "What already exists" section
Existing code/flows that already partially solve sub-problems, and whether the plan reuses them or unnecessarily rebuilds them.

## "Dream state delta" section *(scope mode)*
Where this plan leaves us relative to the 12-month ideal (from Step 0C).

## Error & Rescue Registry (from Section 2) *(scope mode)*
Complete table of every method that can fail, every exception class, rescued status, rescue action, user impact.

## Failure Modes Registry
```
  CODEPATH | FAILURE MODE   | RESCUED? | TEST? | USER SEES?     | LOGGED?
  ---------|----------------|----------|-------|----------------|--------
```
**Any row with RESCUED=N AND TEST=N AND USER SEES=Silent → CRITICAL GAP.** (This deterministic gate is the load-bearing output — never soften it.)

Execution mode: for each new codepath in the test-review diagram, list one realistic production failure (timeout, nil reference, race condition, stale data) and whether (1) a test covers it, (2) error handling exists, (3) the user sees a clear error or a silent failure — the same gate applies: no test AND no error handling AND a silent failure → CRITICAL GAP.

## Proposed follow-ups
Returned to the caller, never recorded or tracked by this skill — the per-follow-up contract (What / Why / Pros-Cons / Context / Type / Effort / Priority / Depends on, then Keep / Skip / Promote) is in `SKILL.md` → "Proposed follow-ups".

## Delight Opportunities *(scope mode, EXPANSION only)*
Identify at least 5 "bonus chunk" opportunities (<30 min each) that would make users think "oh nice, they thought of that." Present each as its own individual decision via the question protocol (never batch). For each: what it is, why it would delight, effort estimate. Options: **Keep** — add it to the returned follow-up list as a vision item · **Skip** · **Promote** into the current scope and review it now (still no code).

## Diagrams
Use ASCII diagrams for any non-trivial data flow, state machine, or processing pipeline. Identify which implementation files should get inline ASCII diagram comments — particularly domain models with complex state transitions, services with multi-step pipelines, and middleware with non-obvious shared behavior.

Scope mode — mandatory, produce all that apply: 1. System architecture · 2. Data flow (including shadow paths) · 3. State machine · 4. Error flow · 5. Deployment sequence · 6. Rollback flowchart.

## Stale Diagram Audit *(scope mode)*
List every ASCII diagram in files this plan touches. Still accurate?

## Completion Summary
Display this at the end so the user sees all findings at a glance.

**Scope mode** — compact table:

| Item | Result |
|---|---|
| Mode selected | EXPANSION / HOLD / REDUCTION |
| Plan located | [artifact path] |
| System Audit | [key findings] |
| Step 0 | [mode + key decisions] |
| Section 1 (Arch) | ___ issues |
| Section 2 (Errors) | ___ paths mapped, ___ GAPS |
| Section 3 (Security) | ___ issues, ___ High severity |
| Section 4 (Data/UX) | ___ edge cases, ___ unhandled |
| Section 5 (Quality) | ___ issues |
| Section 6 (Tests) | diagram produced, ___ gaps |
| Section 7 (Perf) | ___ issues |
| Section 8 (Observ) | ___ gaps |
| Section 9 (Deploy) | ___ risks |
| Section 10 (Future) | Reversibility _/5, debt items ___ |
| NOT in scope | written (___ items) |
| What already exists | written |
| Dream state delta | written |
| Error/rescue registry | ___ methods, ___ CRITICAL GAPS |
| Failure modes | ___ total, ___ CRITICAL GAPS |
| Proposed follow-ups | ___ items |
| Delight opportunities | ___ (EXPANSION only) |
| Diagrams produced | ___ (list types) |
| Stale diagrams found | ___ |
| Unresolved decisions | ___ (listed below) |

**Execution mode:**
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

## Unresolved Decisions
If the user does not respond to a question, interrupts to move on, or a decision was auto-deferred in non-interactive mode (`UNRESOLVED-AUTO`, including `mode defaulted`), list it here as "Unresolved decisions that may bite you later." Never silently default to an option.
