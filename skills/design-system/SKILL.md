---
name: design-system
description: |
  Design token architecture, component patterns, React component composition, and cross-platform UI for web and React Native.
  Use when: building UI components, defining design tokens, creating themed interfaces, setting up dark mode or theming, configuring Tailwind with design tokens, setting up typography or motion systems, choosing component API patterns (flat vs compound vs explicit variants), designing reusable component APIs, refactoring boolean-prop proliferation, building compound components, render props vs children, context providers, adding shadows or elevation, or any task involving consistent styling across components. Use this skill whenever the user mentions design tokens, theming, dark mode toggle, component variants, compound components, or cross-platform styling — even if they don't explicitly say "design system".
  Do not use for: UX research or user journey decisions (use ux-design), single-screen specs (use screen-design), business logic, data fetching, backend/HTTP API design.
---

# Design System

## Philosophy

A design system exists to make the next UI decision faster than the last one. Every token, pattern, and component should reduce future decision cost. When you find yourself hesitating on a color, spacing, or animation value — the system has a gap. Fill it.

Consistency comes from making the right choice the easiest choice, not from enforcing rules. If a pattern is being bypassed, the pattern is wrong — fix it instead of fighting it.

## Token Architecture

Tokens are the single source of truth. Components never hardcode visual values.

```
Primitive   →  Raw values (gray.500, spacing.4). Never use in components.
Semantic    →  Intent (color.bg.primary, spacing.component.md). USE THIS.
Component   →  Override only when a component must deviate from semantic.
```

Why three tiers: Primitive gives a bounded palette. Semantic gives meaning so themes work (dark mode swaps semantic, not every component). Component tier exists for rare exceptions — most components should only need semantic.

→ Full token definitions, dark theme, and W3C DTCG format: `references/tokens.md`

## Typography

A type scale, not ad-hoc font sizes. Every text in the UI maps to a named style.

| Style | Size | Line Height | Weight | Use |
|-------|------|-------------|--------|-----|
| `display` | 30px | 36px | bold | Hero sections |
| `heading.lg` | 24px | 32px | semibold | Page titles |
| `heading.md` | 20px | 28px | semibold | Section titles |
| `heading.sm` | 16px | 24px | semibold | Card titles |
| `body.lg` | 18px | 28px | normal | Long-form |
| `body.md` | 16px | 24px | normal | Default body |
| `body.sm` | 14px | 20px | normal | Secondary text |
| `caption` | 12px | 16px | medium | Labels, metadata |
| `code` | 14px | 20px | normal | Code snippets (mono) |

Why fixed scale: Prevents the "is this 15px or 16px?" decision. Every text element picks from the scale. If nothing fits, the scale needs a new entry — not a one-off value.

The scale's line-heights are Latin-calibrated. Shipping CJK (ko/ja/zh)? Body
line-height needs to loosen (~1.7×) and the font stack needs per-script
families (Inter has no CJK coverage); translated strings run 30–40% longer
than English, so avoid fixed-width buttons. Locale routing, formatting, and
expansion testing belong to the i18n skill, if available — the tokens that
absorb them belong here.

→ Full type tokens, responsive scaling, font stack: `references/typography.md`

## Motion

Consistent timing and easing across all animations.

| Token | Value | Use |
|-------|-------|-----|
| `duration.instant` | 100ms | Micro-interactions (toggle, checkbox) |
| `duration.fast` | 200ms | Hovers, fades, small transitions |
| `duration.normal` | 300ms | Modals, drawers, page transitions |
| `duration.slow` | 500ms | Complex choreography, emphasis |
| `easing.default` | cubic-bezier(0.4, 0, 0.2, 1) | Most transitions |
| `easing.enter` | cubic-bezier(0, 0, 0.2, 1) | Elements entering view |
| `easing.exit` | cubic-bezier(0.4, 0, 1, 1) | Elements leaving view |

Always respect `prefers-reduced-motion`. When reduced, skip animation entirely — don't just shorten duration.

→ Motion tokens and usage table: `references/motion.md`. Platform reduced-motion implementation lives in `references/platform-web.md` and `references/react-native/platform.md`.

This skill owns motion **tokens** (durations/easings), reduced-motion policy, and the engine-agnostic implementation rules any choreography that consumes these tokens — scroll reveals, parallax, gestures, page transitions — must follow (`references/motion.md` § Implementation Rules). For React route and shared-element transitions, see the react-view-transitions skill, if available.

## Shadow & Elevation

Shadows communicate depth and hierarchy. Like colors and spacing, shadow values come from tokens — not ad-hoc `box-shadow` strings.

| Token | Use |
|-------|-----|
| `shadow.card` | Subtle lift — cards, inputs |
| `shadow.dropdown` | Moderate elevation — dropdowns, popovers |
| `shadow.modal` | High elevation — modals, dialogs |
| `shadow.toast` | Max elevation — toasts, command palette |

Dark mode shadows use higher opacity so they stay visible against an already-dark surface — subtle shadows disappear on dark backgrounds. The semantic shadow tokens remap automatically per theme.

> Full shadow definitions and dark theme overrides: `references/tokens.md`. Platform implementation: `references/platform-web.md` / `references/react-native/platform.md`.

## Z-Index

Layering tokens prevent z-index wars. Every layer has a named token.

| Token | Value | Use |
|-------|-------|-----|
| `zIndex.base` | 0 | Default content |
| `zIndex.dropdown` | 100 | In-flow dropdowns (not portaled) |
| `zIndex.sticky` | 200 | Sticky headers, navbars |
| `zIndex.overlay` | 300 | Overlay backdrops |
| `zIndex.modal` | 400 | Modals, dialogs |
| `zIndex.popover` | 450 | Portaled floating layers — menus, selects, popovers, tooltips |
| `zIndex.toast` | 500 | Toast notifications |

Floating layers portaled to the document root (Select, Menu, Popover, Tooltip) can open from inside a modal, so they need `zIndex.popover` above `zIndex.modal` — on `zIndex.dropdown` they would render underneath the modal. Keep `zIndex.dropdown` for in-flow dropdowns that never escape their stacking context.

If you need a z-index not on this list, add a new token — don't use a magic number.

## Component Patterns

### Core Principle: Composition Over Boolean Props

Never add boolean props to customize component behavior or appearance. Instead, use composition: children, compound sub-components, or explicit variant components. Boolean props create combinatorial explosions and ambiguous states. Never fork behavior with flags like `isReply`/`isEditing`/`showX`: each use case gets its own variant component that takes only domain ids/data and composes the shared compound parts.

```
// ❌ Boolean prop proliferation
Button(primary, large, outline, disabled, loading)

// ✅ Composition — children for content, explicit variant for behavior
OutlineButton(size="lg", disabled) → [Spinner, "Saving…"]
```

Always prefer `children` over render props (`renderX`). Render props should only be used when the parent must pass computed data down.

### Choosing the Right API

Pick the pattern based on how much the component's behavior and layout vary:

| Complexity | Pattern | Example |
|------------|---------|---------|
| Simple, few visual variations | **Flat** — constrained props | `<Button size="md">` |
| Distinct behavioral modes | **Explicit variants** — separate components | `<IconButton>`, `<LinkButton>` |
| Flexible internal layout | **Compound** — sub-components + structured context | `<Card><Card.Header>…` |
| Complex, reusable behavior | **Headless + Styled** | `useDialog()` hook + styled wrapper |

When a component adds a prop that changes **behavior** (not just appearance), split into an explicit variant component. When a component grows past ~5 configuration props for **layout**, go compound. Export compound parts in one namespace (`X.Frame`/`X.Input`/`X.Submit`); parts read state and actions from context, never from per-call-site props.

### Architecture

Mount point varies by project architecture:

```
2D Web/Mobile  → src/shared/ui/
3D / WebXR     → src/shared/ui/           (DOM overlay outside Canvas)
2D + 3D        → src/site/shared/ui/      (2D design system)
                  + src/platform/ui/        (cross-layer UI primitives)
```

Internal structure is always the same:

```
<mount>/
├── tokens/          # primitive, semantic, themes
├── headless/        # useButton, useToggle, useDialog (behavior + a11y)
├── styled/          # Button, Toggle, Dialog (headless + tokens = UI)
├── primitives/      # Box, Text, Stack (layout atoms)
└── patterns/        # FormField, ConfirmDialog (compositions)
```

When using shadcn, `styled/` is replaced by `ui/` (shadcn CLI target) and `headless/` is unnecessary (Radix is bundled). Full shadcn + cva + Radix Primitives integration (cn helper, Slot/asChild, Tailwind v4 token wiring): `references/shadcn.md`.

Headless hooks own behavior: ARIA, keyboard, focus, state. Styled components own appearance: tokens, variants, sizing. This separation means a Button's click/keyboard/focus logic is written once and reused whether it looks like a primary button, ghost button, or icon button.

→ Framework-agnostic patterns: `references/components.md`
→ React implementations (JSX, hooks, Context): `references/react/components.md`
→ React 19 API changes: `references/react/react-19.md`
→ shadcn/ui + cva + Radix: `references/shadcn.md`

### Component Composition (React)

The refactoring playbook for React component APIs (formerly the separate
composition-patterns skill): avoiding boolean props, compound components,
lifting state into providers, explicit variants, children over render props,
and React 19 APIs. Two rules carry most of the weight:

- **Provider ≠ Frame.** The Provider injects state; the Frame is only a layout
  wrapper. Anything inside the provider — a preview or dialog button outside the
  Frame — can read state and call `submit`, with no `useEffect` upward sync or
  imperative refs.
- **One generic contract.** Context is `{ state, actions, meta }` with a small
  generic action set (`update`, `submit`, optional `cancel`); each state source
  (local state, store, server sync) is its own provider implementing it, and the
  provider is the only code that knows the source.

→ Overview and rule index: `references/composition/guide.md`
→ Rules with incorrect/correct examples: `references/composition/rules/`

## Icons

Use one icon library per project and enforce it. Mixing libraries causes visual inconsistency (different stroke widths, sizing, metaphors) and bundle bloat.

Recommended: `lucide` — available for all frameworks (`lucide-react`, `@lucide/vue`, `@lucide/svelte`, `lucide-solid`, `lucide-react-native`; the older `lucide-vue-next` / `lucide-svelte` packages are deprecated). These are lightweight and tree-shakeable. But if the project has an existing icon set, use that — the principle is consistency, not a specific library.

Decorative icons are hidden from the a11y tree. Meaningful icons get `aria-label` (web) or `accessibilityLabel` (RN).

## Accessibility

Built into every component from the start. Not a review step after implementation.

| Requirement | Minimum | Why |
|-------------|---------|-----|
| Text contrast | 4.5:1 | WCAG AA readability |
| UI contrast | 3:1 | Controls must be distinguishable |
| Focus indicator | 2px visible outline, 3:1 contrast | Keyboard users need to see focus |
| Touch targets | 44×44pt | Fingers are imprecise |

Color is never the sole indicator of state. Error states use color + icon + text. Disabled states use opacity + cursor change.

## Quick Decision Guide

- **Picking a color?** → Find it in semantic tokens. If it doesn't exist, add to semantic first, then use.
- **Spacing a component?** → `spacing.component.*`. Between sections → `spacing.layout.*`.
- **Sizing text?** → Pick from type scale. If nothing fits, extend the scale.
- **Adding depth/elevation?** → Use semantic shadow tokens (`shadow.card`, `shadow.dropdown`, `shadow.modal`, `shadow.toast`). Never inline box-shadow values.
- **Layering elements?** → Use z-index tokens. Never use magic numbers.
- **Animating?** → Use motion tokens. Respect reduced motion.
- **Building a simple component?** → Flat API with constrained props (size, colorScheme). No boolean modes.
- **Component has behavioral modes?** → Split into explicit variant components (`<IconButton>`, `<SubmitButton>`).
- **Building a complex layout component?** → Compound API with structured `{ state, actions, meta }` context.
- **Need custom behavior?** → Headless hook first, styled wrapper on top.
- **Passing content to a component?** → Use `children`. Avoid render props unless parent must pass computed data.
- **Framework-specific patterns?** → See `references/react/` or `references/react-native/` for implementation details.
- **Using Tailwind?** → For Tailwind v4, wire tokens via CSS `@theme` (the current default); for legacy v3 (or a v4 project still loading a JS config via `@config`), map them in `tailwind.config.js`. See `references/platform-web.md`.
- **Cross-platform?** → Tokens defined once, transformed per platform. See `references/pipeline.md`.

## Standing Guards (keep the system enforced)

"Never hardcode" rules decay without automation — wire these once, then the
system defends itself:

- **Stylelint** (web): `declaration-strict-value` for `color`, `background-color`,
  `border-color`, `fill`, `box-shadow`, `z-index`, `font-size` — values must be
  `var(--*)` / theme tokens, not literals.
- **Grep gate** (any stack, CI): hex literals (`#[0-9a-fA-F]{3,8}\b`), raw
  `z-index: [0-9]`, inline `box-shadow:` with lengths, and raw `transition`
  durations are allowed **only** under the tokens directory — fail the build
  elsewhere.
- **Escape hatch with a trail**: a justified exception gets a
  `/* token-exempt: reason */` comment the gate whitelists — silent exceptions
  are how drift starts.

## Platform References

→ Web (CSS custom properties, dark mode, responsive): `references/platform-web.md`
→ React Native (TS tokens, color scheme, a11y): `references/react-native/platform.md`
→ Token pipeline (Style Dictionary, single-source workflow): `references/pipeline.md`
→ React components & React 19: `references/react/`
→ React Native typography: `references/react-native/typography.md`
