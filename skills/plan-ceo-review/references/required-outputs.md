# Required Outputs

Loaded by `plan-ceo-review`. Produce all that apply. Each is mandatory regardless of whether issues were found (the question escape-hatch governs AskUserQuestion calls, not deliverables).

## "NOT in scope" section
Work considered and explicitly deferred, with a one-line rationale each.

## "What already exists" section
Existing code/flows that partially solve sub-problems and whether the plan reuses them.

## "Dream state delta" section
Where this plan leaves us relative to the 12-month ideal (from Step 0C).

## Error & Rescue Registry (from Section 2)
Complete table of every method that can fail, every exception class, rescued status, rescue action, user impact.

## Failure Modes Registry
```
  CODEPATH | FAILURE MODE   | RESCUED? | TEST? | USER SEES?     | LOGGED?
  ---------|----------------|----------|-------|----------------|--------
```
**Any row with RESCUED=N AND TEST=N AND USER SEES=Silent → CRITICAL GAP.** (This deterministic gate is the load-bearing output — never soften it.)

## Proposed follow-ups
This skill does **not** record or track work — it only proposes; with no write tools pinned, it cannot write anything even by accident. Approved follow-ups go into a plain list returned to the caller (the main session), which decides what to do with them.

Present each potential follow-up as its own individual AskUserQuestion (never batch — one per question; never silently skip this step). For each, describe:
* **What:** one-line description of the work.
* **Why:** the concrete problem solved or value unlocked.
* **Pros / Cons:** what you gain; cost, complexity, risk.
* **Context:** enough that someone picking this up in 3 months understands the motivation, current state, and where to start.
* **Type:** `feature | bugfix | refactor | chore | spike | hotfix`
* **Effort:** S / M / L / XL
* **Priority:** `high | medium | low`. high = blocking/critical-this-cycle; medium = important not urgent; low = nice-to-have.
* **Depends on:** prerequisites or ordering constraints, or "None".

Then present options (recommended first): **Keep** — add it to the returned follow-up list · **Skip** — not valuable enough · **Promote** into the current scope and review it now (still no code). (No A/B/C letters on the option cards — lettering is report-text only.)

## Delight Opportunities (EXPANSION mode only)
Identify at least 5 "bonus chunk" opportunities (<30 min each) that would make users think "oh nice, they thought of that." Present each as its own individual AskUserQuestion (never batch). For each: what it is, why it would delight, effort estimate. Options: **Keep** — add it to the returned follow-up list as a vision item · **Skip** · **Promote** into the current scope and review it now (still no code).

## Diagrams (mandatory, produce all that apply)
1. System architecture · 2. Data flow (including shadow paths) · 3. State machine · 4. Error flow · 5. Deployment sequence · 6. Rollback flowchart.

## Stale Diagram Audit
List every ASCII diagram in files this plan touches. Still accurate?

## Completion Summary
Display this compact table at the end:

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

## Unresolved Decisions
If any AskUserQuestion goes unanswered (including non-interactive `UNRESOLVED-AUTO` deferrals), list it here. Never silently default.
