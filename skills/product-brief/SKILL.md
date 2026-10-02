---
name: product-brief
description: |
  Creates lean product briefs — one-pagers that define the problem, direction, and
  success signal for a NEW product or direction. Sits upstream of the PRD; focuses
  on "what" and "why", not features.
  Use when: the user asks to "write a product brief", "create a product one-pager",
  "product pitch", "product concept", or wants to validate/explore whether to build
  a NEW product idea before requirements exist. Also trigger on "I have an idea for
  a new product", "I want to build a new product/app X", or a described concept
  without a named doc type. Also use when reviewing or improving an existing
  product brief.
  Do NOT use for: a single feature on an existing product (use feature-spec); a full
  PRD, detailed success metrics with timeframes, scope boundaries, feature specs,
  user journeys, timelines, or reviewing/auditing a PRD (use prd-craft); UI/UX
  design (use ux-design); technical architecture (use software-architecture);
  investor decks, business plans, market sizing (TAM-SAM-SOM), or GTM docs.
---

# Product Brief — Strategic One-Pager

A product brief answers one question: **"Should I build this, and why?"**

It sits upstream of the PRD. The brief defines the problem and direction; the PRD
specifies requirements, user journeys, scope, risks, and metrics in detail.
Keep the brief lean — anything the PRD covers in depth does not belong here.

## When to skip the brief

A brief is a discovery tool for *new product directions*, not for incremental
feature work on an existing product. For one feature on a product that already has
a PRD (default `docs/prd/prd.md`; caller may redirect the `docs/<area>/` root),
hand off to a feature-spec capability if available — once per feature, never a
PRD rewrite; when a brief already exists and the user wants the full PRD, hand
off to a PRD-authoring capability (e.g. prd-craft) if available.

When **neither a brief nor a PRD** exists, start here — even if the user asked
for a PRD outright: write the brief first, then hand off to PRD authoring, which
reads it. If it's unclear which applies, ask the caller.

## What a Product Brief Is (and Is Not)

- **Product Brief**: Problem, direction, success signal. One page. A discovery tool, not a commitment to build.
- **PRD**: Requirements, user journeys, detailed metrics, scope, non-goals, risks. Created *after* the brief crystallizes the direction.

Readable in under 3 minutes. If it takes longer, it's too long.

### What Does NOT Belong in the Brief

These belong in the PRD or feature specs:

- Detailed success metrics with counter-metrics and timeframes
- Non-goals and scope boundaries
- Feature lists, acceptance criteria, user stories
- Timeline, milestones, dev order
- UI/UX design, wireframes
- Technical implementation, architecture, tech stack

## Core Principles

1. **Problem-first.** The brief exists to articulate a problem worth solving.
2. **Brief means brief.** One page. Detail belongs downstream (see above).
3. **No jargon.** Write it so anyone can understand — direct, confident, active
   voice, short sentences; match the user's formality, lean conversational.
4. **Living document.** Evolves through discovery. Never "done."

## Process

### Step 1: Gather Context

Ask clarifying questions only for what is genuinely missing. Three questions max, then draft.

- **Rich context** (paragraph+): Draft the full brief in one pass; ask at most one
  question, and only if a load-bearing fact (target user, core problem) is genuinely
  ambiguous — otherwise flag gaps with "[Assumption — verify]".
- **Thin prompt** (e.g., "product brief for a todo app"): Ask 2-3 targeted questions — problem, audience, success — then draft.
- **Unstructured dump** (meeting notes, braindumps): Synthesize into the brief structure.
- **Always present a complete draft**, not section-by-section.

### Step 2: Draft the Brief

Use this template. All four sections — Problem, Direction, Success Signal, Open
Questions — are always present.

```markdown
# [Product Name] — Product Brief

**Date:** [today's actual date, e.g. 2026-05-30] | **Status:** [Discovery / In Progress / Approved]
**Tagline:** One sentence that captures what this does.

---

## Problem

**What:** [2-4 sentences. Ground in observed pain — your own, your team's, or your users'. Include how it's handled today and why that's inadequate.]

**Target user:** [Who specifically has this problem, and in what situation? Name a concrete segment, not "everyone".]

**Why now:** [What changed? New capability, pain threshold crossed, opportunity window.]

**Size of prize:** [One line: how many are affected, how often, or what solving it is worth — enough to judge if it deserves a team's time.]

---

## Direction

[1-2 paragraphs. The direction, not the detailed solution. "What experience we want to create" not "what features we will build".]

**Core bet:** [What insight makes this worth building?]

**Alternatives:** [What exists today — tools, competitors, workarounds — and why building beats adopting them?]

---

## Success Signal

[2-3 sentences. The observable change that tells you it's working — WITHOUT a numeric target, counter-metric, or timeframe (those are the PRD's job). E.g. "engineers stop skipping post-deploy checks", not "cut check time 50% by Q3".]

---

## Open Questions

- [ ] [e.g., Which input format to support first?]
- [ ] [e.g., Build or buy for X component?]
```

### Step 3: Quality Check

Before presenting, verify:

- [ ] Problem is grounded in evidence, not assumption; target user is specific
- [ ] Direction describes the experience, not a feature list; Core bet names the insight
- [ ] Success signal is an observable change, not a metric with a target/timeframe
- [ ] The whole brief fits on one page (≲60 markdown lines)
- [ ] Open questions are honest — gaps flagged, not papered over

## Calibration: Weak vs. Strong

**Problem — Weak:**
> We need a dashboard for our analytics data. Users want better visibility into their metrics.

A solution masquerading as a problem. "Better visibility" is vague.

**Problem — Strong:**
> Engineers spend 10-15 minutes after every deploy manually checking three separate dashboards to confirm nothing broke. Most skip it when rushed, and problems get caught hours later by users.

Grounded in evidence, names a specific situation, quantifies the pain.

**Direction — Weak:** "Build a dashboard with charts, alerts, and a settings page." (a feature list)
**Direction — Strong:** "Make 'is the deploy healthy?' answerable in one glance, so no one skips the check." (an experience/outcome)

**Success Signal — Weak:** "D1 retention hits 40% by Q3." (a metric with a timeframe — belongs in the PRD)
**Success Signal — Strong:** "Engineers check deploy health unprompted, and users stop reporting breakages first."

## Graduating to the PRD

Hand off to PRD authoring when the problem and target user have evidence and
the core bet has survived the open questions — the validation method itself
(interviews, smoke tests) is outside this skill. Once the PRD exists it owns
scope, metrics, and feature detail; the brief remains the one-page context
downstream readers (e.g. marketing) consume — on a vision pivot, refresh the
brief's Problem and Direction too, or it quietly poisons those readers.

## When Reviewing an Existing Brief

1. Is there a clear, evidence-based problem with a specific target user — or did they jump to features?
2. Does Direction describe an experience and a Core bet, not a feature list?
3. Is the success signal an observable change (not a PRD metric)?
4. Is it concise? If it reads like a PRD, suggest moving detail downstream.

## Output

Save to the brief (default `docs/prd/product-brief.md`; caller may redirect),
updating that file in place — if no file-write capability is present, return the
brief inline. When the user explicitly explores a second, distinct direction, use
`docs/prd/product-brief-{slug}.md` so a new direction does not overwrite a prior one.

<!-- Author housekeeping: keep this skill under ~175 lines and keep description
≤1024 chars. If it grows past that, consolidate — tighten wording, merge redundant
content, remove resolved questions. -->
