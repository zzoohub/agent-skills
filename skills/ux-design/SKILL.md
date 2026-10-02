---
name: ux-design
description: |
  Senior-level UX design for a NEW product — app-wide information architecture,
  global navigation, shared interaction conventions, and accessibility standards.
  Produces `docs/ux/ux-design.md` plus per-screen specs for every screen in the
  initial design.
  Use when: no `docs/ux/ux-design.md` exists yet — starting UX for a new web,
  mobile, or native product; designing the app structure (IA, navigation,
  onboarding, dashboards, wireframes) or global patterns / accessibility
  standards; an app-wide IA restructure explicitly asked for; or 3D/XR/spatial
  UX (AR, VR, MR, visionOS, Quest) — always here, even one screen (web3d is
  engine implementation only). Also use to review or diagnose an existing
  app's UX — read-only findings unless the caller asks for changes.
  Do NOT use for: a single screen on an existing app (use screen-design, once
  per screen — doesn't rewrite ux-design.md); visual styling, color palettes,
  component implementation, design tokens (use design-system); or
  frontend/UI implementation code.
---

# UX Design — Full App Pass

Produces the **application-level UX** (the UX design doc, default
`docs/ux/ux-design.md`; the caller may redirect the `docs/ux/` root) plus
per-screen specs for every screen in the initial design.

## Context Check

If the PRD or feature specs exist (default `docs/prd/prd.md` or
`docs/prd/features/*.md`), read them first. Use as input, not constraint.

**If the UX design doc already exists**, this is not a fresh greenfield
pass — do not rewrite it blindly. Branch:
- Single screen to add or change → hand off to a single-screen design
  capability (e.g. `screen-design`) if available. Several new screens → one
  single-screen run per screen (they may run in parallel), never a rerun of
  this skill — it would rewrite the app-level doc.
- Audit/critique request ("review my UX", "what's wrong with this flow") → run
  **Review / Diagnose Mode** (below).
- Genuine app-wide restructure the user explicitly asked for → proceed, but
  consolidate rather than regenerate from scratch.
- 3D / XR / spatial work → stays in this skill regardless of file state (even a
  single screen); the single-screen capability carries no 3D/XR methodology,
  and `web3d`, if available, covers engine implementation only.

---

## First Principles (Every Task)

Before designing anything, answer in order:

1. **What is the user's ONE goal?** (Not features, not business metrics — their actual intent)
2. **What is the minimum needed to achieve it?** (Screens, information, actions)
3. **What can be removed?** (If removing it doesn't block the goal, remove it)

**Rule: If #1 is unclear, stop and clarify before proceeding. Use JTBD framing from `references/design-process.md`.**

---

## Quick Diagnosis

When something "feels wrong" or needs improvement:

| Problem | Primary Principle | Action | Reference |
|---------|------------------|--------|-----------|
| User hesitates | Hick's Law | Reduce choices, progressive disclosure | `references/cognitive-principles.md` |
| User misses targets | Fitts's Law | Increase size, reduce distance | `references/cognitive-principles.md` |
| User overwhelmed | Cognitive Load | Show only essentials, chunk into steps | `references/cognitive-principles.md` |
| User abandons midway | Goal Gradient | Show progress, visible milestones | `references/cognitive-principles.md` |
| User remembers negatively | Peak-End Rule | Fix worst moment and final state | `references/cognitive-principles.md` |
| User confused by custom UI | Jakob's Law | Use platform-standard patterns | `references/cognitive-principles.md` |
| User can't find content | IA failure | Restructure navigation, validate with tree test | `references/information-architecture.md` |
| User doesn't know what happened | Feedback gap | Add system feedback (toast, inline, state change) | `references/interaction-patterns.md` |
| User doesn't know what to do | Copy failure | Rewrite labels, add guidance, fix empty states | `references/ux-writing.md` |
| System feels slow | Doherty Threshold | Optimistic UI, skeleton screens, background processing | `references/cognitive-principles.md` (threshold) + `references/interaction-patterns.md` (loading patterns) |
| 3D/XR issue | See dedicated reference | Load the appropriate reference for diagnosis | `references/3d-design.md` / `references/xr-design.md` |
| AI feature issue | See dedicated reference | Streaming, citations, agent transparency, AI error states | `references/ai-feature-ux.md` |

---

## Anti-patterns (Never Include)

These fail the "Does this help the user complete their goal?" test:

- Marketing copy, taglines, promotional language inside product flows
- Hero sections with vague value propositions in app screens
- Decorative sections without functional purpose
- Unnecessary onboarding or splash screens (if UI is self-explanatory, skip it)
- Confirmation dialogs for non-destructive or reversible actions (use undo instead)
- Elements that exist "because other apps have it" (violates First Principles)
- Color as the only indicator of state (accessibility failure)
- Placeholder text as labels (disappears on focus)
- "Are you sure?" without specifying what will happen
- Custom patterns for standard tasks (violates Jakob's Law)
- Hover-only interactions on touch devices
- Org-chart navigation (structure matches company, not user mental model)
- 3D/XR/AI anti-patterns: see `references/3d-design.md`, `references/xr-design.md`, and `references/ai-feature-ux.md` for domain-specific lists

**Rule: If adding something "just in case" — don't. If unsure, mark it for user testing.**

---

## Core Philosophy

> The best UX is one the user doesn't notice. They should remember what they accomplished, not how the interface worked.

- **Efficiency**: Minimum steps, minimum time, minimum cognitive effort
- **Clarity**: One primary action per screen, clear hierarchy, no ambiguity
- **Consistency**: Platform-standard patterns for standard tasks (Jakob's Law)
- **Forgiveness**: Every action is reversible or confirmed before irreversible
- **Accessibility**: Not an afterthought — built into every decision from the start

**Rule: If a design needs explanation, it's not clear enough. If it needs a tutorial, simplify first.**

---

## Design Domains

This skill covers nine interconnected domains. Each has a dedicated reference file:

### 1. Design Process
How to go from problem to validated solution in 5 steps.
→ `references/design-process.md`

### 2. Cognitive Principles
12 behavioral science principles that explain why users struggle and how to fix it.
→ `references/cognitive-principles.md`

### 3. Information Architecture
How to structure navigation, organize content, and design findability.
→ `references/information-architecture.md`

### 4. Interaction Patterns
State machines, system feedback, gestures, loading, undo/redo, transitions.
→ `references/interaction-patterns.md`

### 5. UX Writing
Button labels, error messages, empty states, onboarding copy, microcopy.
→ `references/ux-writing.md`

### 6. Ergonomics & Accessibility
Sizing, spacing, platform-specific specs, responsive design, WCAG compliance.
→ `references/ergonomics.md`

### 7. 3D Interface Design
Camera interaction, object interaction, depth as hierarchy, product configurator UX, photorealistic scene UX (Gaussian splatting), scroll-driven 3D storytelling, loading experience, discoverability, progressive experience levels, accessibility.
→ `references/3d-design.md`

### 8. XR Spatial Design
Comfort zones, interaction models (gaze, hand, voice, controller), text input, passthrough MR design, content persistence, spatial UI patterns, multi-user/social XR, cybersickness prevention, onboarding, privacy, platform design languages (visionOS 26, Quest, Android XR), accessibility.
→ `references/xr-design.md`

### 9. AI Feature UX
Streaming output, citations/provenance, agent transparency (action logs, confirmation gates), trust calibration, AI-specific error states (refusal, hallucinated tool, RAG miss), regeneration UX, accessibility for streaming and live regions.
→ `references/ai-feature-ux.md`

---

## Feature-Aware Design

When feature specs exist in `docs/prd/features/*.md`, read the relevant feature
specs for the screens you're designing. Reference the dev order in
`docs/prd/prd.md` to understand dependencies between features.

---

## Workflow (greenfield pass)

Run the 5 steps of `references/design-process.md` at app scale:

1. **Research & define** — read the PRD + feature specs; write the JTBD per
   persona (First Principles #1).
2. **Map the critical paths** — one entry→goal flow per JTBD. These flows are
   the app's spine; design them before any individual screen.
3. **Derive the screen inventory** — every critical-path step lands on a
   screen; every PRD feature maps to ≥1 screen or an explicit "no UI" note.
   This list becomes `docs/ux/screens/`. Then structure it into the IA
   (validate: ≤3 taps to core content; ≤5 top-level items on mobile).
4. **Design each screen** — all 7 states, per the Output format below.
5. **Remove, then validate** — strip what doesn't serve the goal; run the
   Quick Checklist as the gate before writing files.

---

## Quick Checklist

Before finalizing any UX decision:

### Goal & Structure
- [ ] User's ONE goal clearly identified (JTBD statement written)
- [ ] Every element passes "does this help the goal?" test
- [ ] Information architecture validated (≤3 taps to core content)
- [ ] Navigation pattern appropriate for content type
- [ ] Every PRD feature maps to ≥1 screen, or carries an explicit "no UI" note
- [ ] `ux-design.md`'s ToC links every screen file — no orphan files, no dead links

### Screen Design
- [ ] Primary action is ONE and visually dominant per screen
- [ ] Information shown is only what's needed for current decision
- [ ] All 7 screen states designed (empty, loading, loaded, error, partial, refreshing, offline — defined in `references/interaction-patterns.md`)
- [ ] Content hierarchy: most important first

### Interaction
- [ ] Feedback exists for every user action (visual + optional haptic)
- [ ] Destructive actions require confirmation; reversible actions offer undo
- [ ] Loading pattern matches expected wait time
- [ ] Gestures have visible alternatives

### Copy
- [ ] Button labels are specific verbs (not "OK", "Submit", "Yes")
- [ ] Error messages: what happened + how to fix
- [ ] Empty states: explanation + actionable CTA
- [ ] No jargon, no technical language

### Platform & Ergonomics
- [ ] Mobile: primary actions in thumb zone
- [ ] Safe areas respected (notch, Dynamic Island, home indicator)
- [ ] Platform conventions followed (iOS patterns on iOS, Material on Android)
- [ ] Responsive: tested at 320px minimum

### Accessibility
- [ ] Contrast ratios passing (4.5:1 text, 3:1 UI components)
- [ ] Color not sole indicator of state
- [ ] Focus states visible, keyboard navigation complete
- [ ] Screen reader labels on all interactive elements
- [ ] Dynamic Type / scalable text supported
- [ ] `prefers-reduced-motion` respected

### Anti-patterns
- [ ] Checked against Anti-patterns list above — none present
- [ ] Cognitive principles cited for key design decisions

### 3D / XR / AI (if applicable)
- [ ] Run validation checklist from `references/3d-design.md`, `references/xr-design.md`, and/or `references/ai-feature-ux.md`

---

## Review / Diagnose Mode

When the request is to **review, audit, or diagnose** an existing app's UX
("review my UX", "what's wrong with this flow") — not to build — operate
read-only:

1. **Read, don't write.** Load the existing `docs/ux/ux-design.md` and any
   relevant `docs/ux/screens/*.md`. Do **not** regenerate or overwrite them.
2. **Score against the rubric.** Walk the flow against the Quick Diagnosis
   table, the Anti-patterns list, and the Quick Checklist above. For 3D/XR/AI
   surfaces, also run the relevant reference's validation checklist.
   Also check **structural drift** — where these docs rot: ToC ↔
   `docs/ux/screens/` bijection (orphan files, dead links); sitemap nodes with
   no screen spec; screen files missing any of the 7 states; screen-local
   patterns contradicting the global conventions (e.g. inline errors where the
   app standard is toast).
3. **Output a prioritized critique, not a rewritten doc.** Produce a findings
   list: each finding = location + the principle it violates (cite the
   reference) + severity + a concrete fix. Lead with the highest-impact issues.
4. **Edit only if explicitly asked.** If the caller then asks to "apply the
   fixes", make the minimal targeted edits — still no full-doc rewrite unless
   they ask for a restructure. A fix scoped to building one screen goes to the
   single-screen capability (e.g. `screen-design`) instead.

This mirrors the standard Review / Audit pattern (as in `prd-craft` if
available): a critique by default, edits only on request.

---

## Output

Split output into two levels:

### `docs/ux/ux-design.md` (default) — Application-Level Design

The single source of truth for app-wide UX decisions. Covers:

- Information architecture (sitemap, navigation structure)
- Global navigation patterns and routing logic
- Common interaction rules (toast, modal, error handling conventions)
- Shared state patterns (auth states, offline, loading)
- Platform-specific conventions (iOS vs Android vs Web)
- Accessibility standards applied globally
- Phase Implementation Summary, if the PRD's Dev Order defines version buckets
  (tag each screen with the bucket it belongs to, matching the PRD vocabulary —
  e.g. `[v0.1]`, `[v0.2]` — not an invented "Phase" numbering)

Start with a **Table of Contents** linking to each section and to individual screen files.

### `docs/ux/screens/<screen-name>.md` — Screen-Level Design

One file per screen or distinct view. Each screen file covers:

- Screen purpose and user goal (JTBD)
- Screen layout and content hierarchy
- All 7 states (empty, loading, loaded, error, partial, refreshing, offline — defined in `references/interaction-patterns.md`)
- User flows and decision points within the screen
- Interaction details specific to this screen
- UX copy (labels, errors, empty states, tooltips)
- Dev Order tag matching the PRD's version buckets (e.g., `[v0.1]`), if the PRD defines them

**Naming:** Use kebab-case matching the screen name (e.g., `account-settings.md`, `project-dashboard.md`, `onboarding-welcome.md`).

**When to create a new file vs. add to an existing one:** Each independently navigable screen gets its own file. Modals, drawers, and sheets that belong to a specific screen go in that screen's file. If a flow spans multiple screens, each screen still gets its own file — cross-reference between them.

### Line Limits

Before updating, check the file's line count. If it exceeds the limit, first consolidate — tighten wording, merge redundant content, collapse outdated details — then apply changes. Line counts are guidance, not hard truncation points.

- `docs/ux/ux-design.md`: **500 lines** — if consolidation can't get it under, extract a section (e.g. accessibility standards or platform conventions) into `docs/ux/<topic>.md` and link it from the Table of Contents.
- `docs/ux/screens/<screen-name>.md`: **300 lines** — if a screen file exceeds this, split into child screens (e.g., `settings-profile.md`, `settings-billing.md`)

### Next

Routing hints, not steps this skill performs: once the UX is approved, hand
visual styling, design tokens, and motion to a design-system capability (e.g.
`design-system`), if available, and return the screen inventory to the caller
for implementation.
