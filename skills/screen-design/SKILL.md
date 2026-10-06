---
name: screen-design
description: |
  Design a single screen (or modify an existing one) on a product that already
  has an application-level UX. Creates or updates one
  `docs/ux/screens/{screen}.md` with screen purpose, layout, all 7 states,
  interactions, and UX copy. Touches `docs/ux/ux-design.md` ONLY when IA or
  global patterns genuinely change.
  Use when: `docs/ux/ux-design.md` exists and you are designing or redesigning
  one screen on that app; several new screens → one run per screen (may run
  in parallel). Triggers: "design the X screen", "redesign the X page", "spec
  out the X modal", "fix the X flow".
  This skill owns structural layout, states, and copy. Do NOT use for: a new
  product's app structure, or when ux-design.md is absent (use ux-design);
  conversion/funnel-driven flow optimization (use cro — it diagnoses, this
  skill specs the resulting screen); 3D/XR/spatial screens (use ux-design);
  animation polish, visual styling, color palettes, design tokens (use
  design-system); or frontend/UI implementation code.
---

# Screen Design — Single Screen on Existing App

Designs one screen against an existing app-level UX without rewriting
`docs/ux/ux-design.md`.

## Prerequisites

The app-level UX (default `docs/ux/ux-design.md`; caller may redirect the
`docs/ux/` root) defines IA, global patterns, and shared interactions. If it is
absent, this is greenfield — do not design the screen here; ask the caller to
run an app-level UX capability (e.g. `ux-design`) first rather than halting.
3D/XR/spatial screens also belong to that capability, whatever the file state.

**Methodology lives in the `ux-design` skill.** This skill is lean by design and
has no reference files of its own. For the depth behind each quality bar —
JTBD framing, the 7-state state-machine table, undo/feedback patterns,
error/empty-state copy formulas, and contrast/touch-target/safe-area specs —
consult `skills/ux-design/references/{design-process, interaction-patterns,
ux-writing, ergonomics, cognitive-principles}.md` if available (loaded on
demand, not duplicated here); otherwise apply the quality bar below directly.

## What This Skill Does

Produces one `docs/ux/screens/{screen}.md` covering:

- Screen purpose (JTBD)
- Layout and content hierarchy (1 primary action)
- All 7 states: empty, loading, loaded, error, partial, refreshing, offline
- Interactions specific to this screen
- UX copy (labels, errors, empty states, tooltips)
- Accessibility notes

It updates `docs/ux/ux-design.md` ONLY if IA changes (e.g., new nav entry, new
route); otherwise it leaves that file alone. A **brand-new screen is always an
IA change** — at minimum its route and the ToC link to the new screen file
(patch those entries, nothing else). The app-level ToC links each section and
each screen file; if it currently lists sections only, add (or extend) a
**Screens** group at the end of the ToC and link the new file there — don't
add a numbered section or renumber existing ones. A redesign of an existing screen touches
nothing app-level. See **Workflow** below for the procedure.

## What This Skill Does NOT Do

- Does not rewrite app-level UX
- Does not redesign navigation unless the new screen demands it
- Does not produce visual designs, tokens, motion, or component code

**Next:** routing hints, not steps this skill performs — once the screen spec is
approved, it returns to the caller for implementation, and a design-token
capability (e.g. `design-system`) covers visual tokens, components, and motion
guidance, if available.

## Workflow

1. **Read app UX** — `docs/ux/ux-design.md` for IA, conventions, accessibility
2. **Read feature spec** (if applicable) — `docs/prd/features/{feature}.md`. If
   no feature spec exists, source requirements from the discovery questions in
   step 3 and the relevant `docs/ux/ux-design.md` flows.
3. **Discover the screen** — minimum questions:
   - What is the user's ONE goal on this screen?
   - Where do they arrive from? Where do they go next?
   - What data appears, and what is its worst case (none / slow / partially
     failed / stale / huge)? — the answer drives the 7 states.
   - Any platform-specific constraints (mobile vs desktop)?
4. **Design with all 7 states** — empty, loading, loaded, error, partial,
   refreshing, offline
5. **Write UX copy** — specific verbs for buttons, "what + how to fix" for
   errors, explanation + CTA for empty states
6. **Patch `ux-design.md` if needed** — only when global IA or conventions
   change. When several screens are designed in parallel, keep each patch to
   its own entries so the edits don't collide

## Quality Bar

`ux-design`'s Quick Checklist (its Screen Design, Interaction, Copy,
Platform & Ergonomics, and Accessibility sections) is canonical. The list below is a convenience copy of that
subset — if the two ever diverge, defer to `ux-design`.

- [ ] User's ONE goal stated as JTBD
- [ ] Primary action is ONE and visually dominant
- [ ] All 7 states designed (empty, loading, loaded, error, partial, refreshing, offline)
- [ ] Feedback exists for every user action
- [ ] Destructive actions confirmed (stating what will happen); reversible actions offer undo
- [ ] Loading pattern matches expected wait time
- [ ] Gestures (swipe, pull-to-refresh, long-press) have visible alternatives
- [ ] Button labels are specific verbs (not "OK", "Submit", "Yes")
- [ ] Error messages: what happened + how to fix
- [ ] Empty states: explanation + actionable CTA
- [ ] Accessibility: contrast, focus, keyboard, screen reader labels
- [ ] Color is not the sole indicator of state (pair it with text or an icon)
- [ ] Mobile: primary actions in thumb zone, safe areas respected

## Output

- the screen spec (default `docs/ux/screens/{screen}.md`; caller may redirect) — new or updated file
- the app-level UX file — patched only if IA/conventions change

**Line limit:** the screen spec — 300 lines. If exceeded, split
into child screens (e.g., `settings-profile.md`, `settings-billing.md`).

**Naming:** kebab-case matching the screen name. Modals, drawers, and sheets
that belong to a screen live in that screen's file.
