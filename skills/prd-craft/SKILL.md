---
name: prd-craft
description: |
  Write a complete Product Requirements Document (PRD) for a new product, using
  proven frameworks (Jobs-to-be-Done, MoSCoW, value/usability/feasibility/viability
  risk quadrant). Creates the full vision PRD (problem, target users, success
  metrics, feature overview, dev order, scope) PLUS feature specs for every
  feature listed in the PRD.
  Use when: user asks to "write a PRD", "create a product requirements
  document", "draft product specs", "define product requirements", "create a
  product proposal", "spec out a product". Also when the user describes a new
  product and needs structured requirements.
  Also use to "review a PRD", "improve my PRD", "audit my PRD".
  Do NOT use for: a single feature on an existing product (use feature-spec
  instead — it's lighter and won't rewrite the vision PRD; adding one feature is
  not a PRD review). Never re-run on an existing PRD to add features — run
  feature-spec once per feature. Do NOT use for user stories, sprint tickets,
  API documentation, or architecture decision records.
---

# PRD Craft — Vision PRD for a New Product

Builds the **vision PRD** (the PRD, default `docs/prd/prd.md`; the caller may redirect the `docs/prd/` root) plus a feature spec for every
feature the PRD lists. Use when you're defining a new product from scratch.

## Core Philosophy

A PRD answers **WHAT are we building** and **WHY**. It does NOT answer HOW
(that belongs in technical specs and design docs).

### The 5 Qualities of an Excellent PRD

1. **Problem-obsessed** — The problem drives everything. A missing feature is never the problem; the pain caused by its absence is.
2. **Quantified** — Every problem and goal has numbers. "Slow" → "takes 10 minutes of manual work per run."
3. **User-centered** — Every requirement maps back to a real need. Requirements without evidence get challenged.
4. **Complete yet focused** — Covers the full vision with explicit scope boundaries.
5. **Stands the test of time** — Focused on problems and functional needs, not implementation.

## Output Structure

```
docs/prd/
 ├─ product-brief.md       # Upstream strategic one-pager (if present)
 ├─ prd.md                 # Vision + requirements + dev order (target ~300, max 400 lines)
 └─ features/
     └─ [feature].md       # Feature spec: requirements, journeys, decisions
```

**Every file is a single source of truth (SSOT).** If a file already exists, update it in place — never create duplicates. The file should always reflect the latest state. Note: when `prd.md` already exists, "update in place" is honored by the `feature-spec` skill (which patches it) or Review Mode — not by re-running prd-craft to rewrite the vision (see Phase 0).

### Role of Each File

| File | Contains | When Read | When Modified |
|------|----------|-----------|---------------|
| `prd.md` | Vision, constraints, dev order, success metrics, scope | Every session start | When direction, scope, or priorities change |
| `features/*.md` | Feature-level requirements, user journeys, technical decisions | When working on that feature | When requirements change |

## Complexity Calibration

Scale document depth to your product's complexity.

**Signals:** users (yourself / team / external), scope (single feature / multi-feature), state (local / distributed), longevity (experiment / long-term)

- **Lightweight** (personal tool, single-purpose CLI, experiment): prd.md 100-150 lines, feature specs optional, success signal 1-2 sentences
- **Moderate** (team tool, multi-feature app): prd.md 200-300 lines, feature specs per feature, bullet-point metrics
- **Large** (external users, complex state, many features): prd.md 300-400 lines, full feature specs, metrics table with targets and timeframes

These are writing **targets**. The hard cap before consolidation is 400 lines (see Line Limits).

## Step-by-Step PRD Creation Process

### Phase 0: Check for Existing Context

Before discovery, check if a product brief already exists at
`docs/prd/product-brief.md` — also `product-brief-*.md` variants: multiple
briefs mean multiple explored directions, so confirm which one this PRD builds
on. If a brief exists, use it as a starting point to accelerate discovery.

If **neither a brief nor a PRD** exists, the idea is unvalidated: write the brief
first via a product-brief capability, if available (e.g. the `product-brief`
skill, default `docs/prd/product-brief.md`), then continue here — this phase
reads it. Do this even when the user asked for a PRD outright. If no such
capability is available, ask the caller whether to go straight to discovery.

Also check if `docs/prd/prd.md` already exists. If yes, do **not** rewrite it
blindly — branch:

- The user asked to **review / audit / improve** the PRD → go to **Review /
  Audit Mode** (below). Do not run the creation flow.
- The product has **genuinely pivoted** — the problem, target users, or success
  metric have changed, not just the feature set → run the creation flow to
  rewrite the vision in place. Confirm the pivot scope with the user first so
  you don't discard a still-valid vision. A pivot rewrite also refreshes the
  brief's Problem/Direction (`product-brief.md`) — marketing-side work reads
  the brief, not the PRD, as product context, and a stale brief poisons it.
- Otherwise it's probably a **feature add** → return to the user and
  suggest a single-feature-spec capability if available (e.g. the `feature-spec`
  skill), which patches the PRD in place without rewriting the vision. For
  several features ("add X, Y, Z"), run it once per feature — never re-run this
  skill to add them. Adding a feature is not a pivot, no matter how big the
  feature.

A bare "regenerate / redo / rewrite the PRD" request is not by itself a pivot.
Ask what changed: if the problem, users, and success metric still hold, route to
Review / Audit Mode or per-feature specs instead of discarding the vision.

### Phase 1: Discovery Interview

Gather context conversationally, not as a question dump. Adapt based on what's
already known.

**How to conduct discovery:**

Start with the problem — it's the foundation everything else builds on. Based
on the user's answer, follow the thread naturally:

1. **Open with the problem:** "What's the specific problem here? What evidence do you have?" If they describe a solution instead of a problem, gently redirect: "That sounds like a potential solution — what's the underlying pain point driving it?"
2. **Quantify the pain:** "How often does this happen, how much time or money does it cost today, and how many people hit it?" The PRD demands numbers in §1 and §4 — elicit them now rather than inventing them later. If exact figures don't exist, capture an estimate with its assumption.
3. **Understand the user:** "Who experiences this problem most acutely? What are they trying to accomplish?"
4. **Map the current state:** "How is this handled today? What's painful about that?"
5. **Define success:** "If we nail this, what changes? How would we know it's working?"
6. **Surface the riskiest assumption:** "What has to be true for this to work that we're least sure of?" Note it — it should drive both the §8 Risks section and the Dev Order (sequence the riskiest assumption first).
7. **Scope and constraints:** "What's explicitly out of scope? Any hard constraints — regulatory, performance, compatibility? Existing systems this must work with?"

Don't ask all of these if answers are already clear from context. Skip what you
know, dig deeper on what's vague.

**If the user says "just write it" without context:**

Write now — don't hold the draft hostage to an interview. Answer the
**Problem-User-Success** core from whatever context exists:

1. What specific problem are we solving, and for whom?
2. How is this handled today?
3. What does success look like?

Label every inferred answer (and any invented number) as an assumption in the
draft, and carry each unknown into the §9 Open Questions checkbox list so the
user can correct it after reading.

### Phase 2: Write the PRD (`docs/prd/prd.md`)

The PRD is the **vision document** — concise enough to read every session,
comprehensive enough to guide all feature work. Target ~300 lines (400 hard
cap; scale down for lightweight products per Complexity Calibration).

Read `references/examples.md` for concrete good/bad examples.

---

## PRD Template (`docs/prd/prd.md`)

```markdown
# [Product Name] — PRD

**Status:** [Draft | In Review | Approved]
**Author:** [Name]
**Last Updated:** [Date]

---

## Table of Contents
(linked to each section)

---

## 1. Problem / Opportunity

**The Problem** — State from the USER's perspective. Quantify impact.
Show evidence: observed pain, time wasted, errors encountered, existing
tool limitations.

**Why Now** — What has changed? New capability, pain threshold crossed,
dependency unblocked, opportunity window.

---

## 2. Target Users

Who has this problem, and in what situation?

For personal/team tools, a sentence or two is enough.
For products with multiple user types, define personas with context and needs.

**Jobs-to-be-Done:**
> "When [situation], I want to [motivation], so I can [expected outcome]."

---

## 3. Proposed Solution

**Elevator pitch:** 2-3 sentence plain-English description.

**Core value propositions:** Top 3 benefits, each mapped to a problem.

**Alternatives considered** (moderate/large products): The main solution
approaches you weighed, with a one-line "why not" for each. Keeps the chosen
direction from reading as a foregone conclusion. Lightweight products can skip.

---

## 4. Success Metrics

Scale to complexity:

Lightweight — a sentence or two:
> "I reach for this instead of the manual process at least 3x/week."

Moderate — bullet points:
> - Processes files in under 5 seconds for typical inputs
> - Zero silent data loss — every error reported with location
> - Adopted by 3+ team members within first month

Large — full table:
| Goal | Metric | Counter-metric | Target | Timeframe |
|------|--------|----------------|--------|-----------|
| ... | ... | ... | ... | ... |

---

## 5. Feature Overview

List all features with one-line descriptions. Each has a detailed spec
in `docs/prd/features/`.

Feature names are **kebab-case** (e.g. `file-parser`). The same token is the
Feature Overview key, the Dev Order entry, and the `docs/prd/features/{feature}.md`
filename — keep it identical across all three so downstream skills can join on it.

| Feature | Description | Spec |
|---------|-------------|------|
| file-parser | Read and validate input files | [features/file-parser.md](features/file-parser.md) |
| transform-engine | Apply transformation rules to parsed data | [features/transform-engine.md](features/transform-engine.md) |

---

## 6. Dev Order

Features ordered by dependency and priority. State **why** this order, don't just
assert it — one rationale line per version bucket, or one global ordering
principle (riskiest-assumption-first, core-value-first, unblocks-the-most). For moderate/large products, tag each
feature Must / Should / Could (MoSCoW) or note its value-vs-effort. Annotate
cross-feature dependencies inline (`depends on: file-parser`) so downstream
planning can consume the graph rather than re-deriving it.

### v0.1 — Core (minimum usable state) — core value first
1. file-parser — everything depends on parsed input [Must]
2. transform-engine — core value of the tool [Must] (depends on: file-parser)

### v0.2 — Workflow — unblocks daily use
3. config-loader — user-defined rules [Should] (depends on: transform-engine)
4. output-formatter — multiple output formats [Should] (depends on: transform-engine)

### v0.3 — Polish — friction cuts, nothing load-bearing
5. error-reporting — detailed diagnostics [Could]
6. watch-mode — re-run on file changes [Could] (depends on: file-parser)

---

## 7. Scope & Non-Goals

- **In scope:** The full product vision (brief list)
- **Out of scope:** What this product will NOT do, with reasoning

---

## 8. Assumptions, Constraints & Risks

- **Assumptions:** Things believed true but not yet validated
- **Constraints:** Hard limits (performance, compatibility, platform). For
  external-user products, state non-functional requirements explicitly here —
  performance targets, security/compliance, accessibility level, reliability/SLA.
- **Risks:** What could go wrong, with severity and mitigation. Cover more than
  technical risk — weigh **value** (will users want it?), **usability**,
  **feasibility**, and **viability** (does it work for the business / who pays?).
  Naming a value or viability risk is not pessimism; it's what keeps the PRD from
  being a one-sided coin.

---

## 9. Open Questions

Vision-level unknowns still being resolved (a home for open questions that
graduate up from the product brief). Use a checkbox list; remove items as they
resolve — don't let it become a changelog.

- [ ] [e.g., Build or buy for the X component?]
- [ ] [e.g., Which input format ships first?]

---

## 10. Appendix

Links to supporting materials (don't inline them).
```

### Phase 3: Extract Features into Specs

For each feature in the PRD's Feature Overview table, create a feature spec
under the PRD's `features/` directory (default `docs/prd/features/{feature}.md`;
kebab-case filename matching the §5 name). Lightweight products may skip specs
(per Complexity Calibration) — then omit the §5 Spec column entirely rather
than leaving dead links.

A dedicated feature-spec capability (e.g. the `feature-spec` skill) owns the
canonical template, field guidance, and quality bar — use it per feature if
available, or generate inline from the same template if batch-generating. Read
`references/feature-spec.md` for the batch-generation flow and how it differs
from standalone use. Do not maintain a second copy of the template here.

---

## Review / Audit Mode

Use this when the user asks to **review, audit, or improve an existing PRD**
(Phase 0 routes here). Do **not** run the creation flow and do **not** rewrite
the document.

1. **Read** the existing `docs/prd/prd.md` (and its feature specs if relevant).
2. **Score** it against two rubrics:
   - The **5 Qualities of an Excellent PRD** (above).
   - The **anti-patterns** in `references/anti-patterns.md` — treat each as a
     checklist item.
3. **Check structural integrity:** Feature Overview ↔ `features/*.md` ↔ Dev
   Order agree one-to-one — no spec-less rows (unless the lightweight tier
   skipped specs), no orphan spec files, no feature missing from Dev Order;
   names kebab-case and matching filenames; every `depends on:` target exists;
   Last Updated present and recent enough to believe (anti-pattern #9).
4. **Report** a prioritized findings list: for each issue, name the section, quote
   the problem, and give a concrete section-level fix. Lead with the highest-impact
   gaps (missing/weak problem evidence, no metrics, scope undefined).
5. **Do not edit unless asked.** Offer to apply fixes section-by-section; if the
   user accepts, follow Iteration & Feedback below.

Output a critique, not a rewritten PRD.

---

## Anti-Patterns

Before finalizing, check against common failure modes.
Read `references/anti-patterns.md` for the full list.

The most critical to catch:
1. **Solution masquerading as a problem** — "We need to build X" is not a problem
2. **The metrics-free zone** — No numbers anywhere
3. **The technical spec in disguise** — Names specific libraries or frameworks in requirements (tech stack belongs in the architecture design doc)
4. **The design document in disguise** — Contains wireframes or UI specs

## Quality Gate (before presenting)

- [ ] §1 problem is quantified with evidence — baselines and frequencies, not adjectives
- [ ] §4 metrics match the complexity tier; large products pair every goal with a counter-metric
- [ ] §5 names are kebab-case; §5 ↔ §6 ↔ `features/*.md` agree one-to-one (lightweight: Spec column omitted, never dead links)
- [ ] §6 states an ordering rationale and annotates `depends on:` inline
- [ ] §7 names specific out-of-scope temptations, each with a reason
- [ ] §8 weighs value/usability/feasibility/viability — not only technical risk
- [ ] No tech stack in requirements, no wireframes (the critical anti-patterns above)
- [ ] Line limits hold: prd.md ≤ 400, each feature spec ≤ 200

## Line Limits

Before updating, check the file's line count. If it exceeds the limit,
consolidate — merge redundant sections, tighten wording, remove resolved
questions — then apply changes.

- `prd.md`: aim for ~300, **400 lines** hard cap — consolidate before exceeding it
- `features/*.md`: **200 lines** per feature

## Iteration & Feedback

After presenting the initial draft:

- Iterate **section-by-section** rather than rewriting the entire document
- When the user provides feedback, update the specific section and confirm
- If feedback reveals a gap in discovery, update Problem and Target Users
  first — then cascade through downstream sections
- When requirements change, update the feature spec

## Next Steps

Once the PRD + feature specs are approved, the PRD is an input — not the finish
line. Hand off to the next stages of the planning pipeline if such capabilities
are available (routing hints, not inline reads):

1. **Architecture** — `software-architecture` for a new system, or `arch-decision`
   for a brownfield change → `docs/arch/`
2. **UX** — `ux-design` for app-wide design, or `screen-design` for a single
   screen → `docs/ux/`

This skill stays at the WHAT/WHY altitude and does not produce any of those
artifacts itself.
