---
name: design-system
description: |
  Design tokens, themes and `shared/ui` component APIs for React web and React Native: build UI on a design system, or extend, establish, theme, refresh or audit one.
  Use for visual styling, color roles and contrast pairs; dark mode, scoped and brand themes; Tailwind or shadcn wired to tokens; variants, parts and boolean-prop sprawl; UI animation (hover, open/close, CSS 3D, view transitions) and reduced motion: "design tokens", "add dark mode", "hardcoded colors", "looks dated", "build a Button component", "set up a design system".
  Do NOT use for: screen logic, hooks or headless blocks (react-architecture); app IA, flows or UX review (ux-design); one screen's spec (screen-design).
---

# Design System

Decide once. Tokens hold every value, `shared/ui` holds every component that knows nothing about the business, and screens compose the two. A literal or a one-off component is a decision made a second time, a little differently, and a rule that no check enforces is guessed again in every session.

This skill fixes the vocabulary (roles, pairs, themes) and the shape of component APIs. Styling engines and headless libraries change between releases, so check their APIs in version-matched sources: `node_modules/next/dist/docs/`, the `docs/` folder inside `@base-ui/react`, the Tailwind and shadcn docs. `references/stack.md` holds the dated facts the examples rest on.

**The floor outranks the look.** Contrast, focus, target size and reduced motion hold for every brand value on every screen. Where a design fails one, the floor wins and the report says what changed.

Paths are defaults (`src/shared/ui/`, alias `@/`); the caller may redirect them, and a repo that already has a UI folder (`components/ui`, shadcn's `aliases.ui`) keeps its system there. A repo with its own vocabulary keeps that too: shadcn's names, a styled kit's theme API, an existing token set. Add to it by these rules, and rename or restructure only when asked, as a migration that reaches every call site. The examples use Tailwind and Base UI on the web; the rules hold on any engine, and React Native carries them in a theme module (`references/react-native.md`).

---

## Where It Lives

```
src/shared/
├── ui/                   # The system. One file per component, no barrel: import @/shared/ui/button
│   ├── tokens.css        # Every value: scales, one block of roles per theme, the bridge to utilities
│   ├── tokens.test.ts    # Every theme has every role; every allowed pair passes
│   ├── theme.tsx         # The theme at first paint, setTheme
│   ├── button.tsx        # Button, IconButton; their styles in button-variants.ts
│   └── dialog.tsx        # Parts exported by name: import * as Dialog from '@/shared/ui/dialog'
└── lib/
    ├── cn.ts             # The one class merger
    └── color.ts          # Contrast math for the test
```

| UI | Lives in | Its props speak |
|---|---|---|
| Knows nothing about the business: Button, Dialog, Field, Card | `shared/ui` | UI: `variant`, `size`, `label`, `open` |
| Knows a business object or one screen: a product card, a plan badge, a checkout summary | Outside the system: its screen first, then the entity or block that owns it | The domain: `product`, `plan` |

Everything outside `shared/ui` follows react-architecture, if available, else the app's own structure.

**Rule: `shared/ui` speaks UI, never the domain.** No `product`, `user` or `plan` in a prop or a file name; no fetching, no store, no route. Text arrives as props, labels included, so the system holds no copy to translate.

**Rule: Search before creating.** Look in `shared/ui` and the token file for what already covers the intent, by role and not by name. A component moves into `shared/ui` when a second slice needs it. A second Button beside the first is never the answer.

**Rule: App code imports UI only from `shared/ui`.** The headless library is imported nowhere else, so its behavior and its look change in one place.

---

## Tokens

**Rule: Components read roles, and only token files hold values.** A role is a category and an intent, with an optional prominence and state: `bg.accent`, `bg.accentHover`, `bg.dangerSubtle`, `fg.onAccent`, `border.input`. A name says what a color is for, never its hue (`blue` breaks on a rebrand) or its rank (`tertiary` says nothing about use).

```css
/* src/shared/ui/tokens.css (shape) */
:root,
[data-theme='light'] {
  color-scheme: light;
  --ds-bg-accent: #2563eb;
  --ds-fg-on-accent: #ffffff;
}

[data-theme='dark'] {
  color-scheme: dark;
  --ds-bg-accent: #3b82f6;
  --ds-fg-on-accent: #030712; /* a dark theme's fill is lighter, so its text turns dark */
}

@theme inline {
  --color-*: initial; /* the default palette no longer compiles */
  --background-color-accent: var(--ds-bg-accent); /* bg-accent */
  --text-color-on-accent: var(--ds-fg-on-accent); /* text-on-accent */
}
```

**Rule: The vocabulary is closed.** A utility's prefix is its token's category: `bg-` takes `bg` roles, `text-` takes `fg` roles, `border-` and `outline-` take `border` roles. So `bg-red-500`, `text-white` and `text-accent` (a fill used as text) do not compile. Color is the only scale the system renames. Type, spacing, radius and shadow keep the engine's names (`text-sm`, `p-4`, `rounded-md`), so every tool that knows the engine keeps working. A product whose sizes sit off that scale moves the scale, not the class: `--text-sm: 0.8125rem` in the token file, never `text-[13px]` in a component.

**Rule: Pairs pass or fail, not colors.** Every fill ships with the text that goes on it (`bg.accent` with `fg.onAccent`) and is used only with it. A test gates each pair in each theme, on every surface it can sit on: text at 4.5:1 (3:1 from 24px, or 18.66px bold); icons, focus rings, an input's only boundary and the cue that marks a state at 3:1. Hover and translucent fills are pairs too, which is why `hover:bg-accent/90` is a bypass: it is a new fill that nothing gated. Never judge a color by eye.

**Rule: A value the system lacks becomes a token, or the line is marked.** Add a role only for an intent no role covers, with a value in every theme and its pairs in the test. A real one-off stays a literal on a line marked `token-exempt: reason`. Two bypasses with one intent mean the system has a gap: extend it.

**Rule: A supplied brand value stays exact wherever its pairs pass.** Where a pair fails, ship the change that shows least (the smallest lightness shift that passes, or the exact fill under the other on-color) as provisional, and put the choice to the owner first in the report. Never snap to another color silently. With no brand input, keep the product's values and flag the placeholders. Don't invent a palette.

**Rule: Hierarchy comes from size, weight and text role before boxes, borders or color.** One accent fill per region, on its primary action. Status colors mean status only. Shadows mark layers, not emphasis. Space is tight inside a group and loose between groups.

→ `references/tokens.md`, `references/lib.md`.

---

## Themes

**Rule: A theme remaps roles at a scope, and components never ask which theme is on.** The scope is an attribute on any element, and every theme defines every role. No `dark:` utilities, no theme branches in components.

| Scope | How |
|---|---|
| Light and dark | `data-theme` on `<html>` |
| An inverted band, a dark footer | The same attribute on that element; the primitives inside follow it |
| An art-directed page: a campaign, a product with its own look | Its own theme block, plus variables for what only that page uses |
| A brand or tenant; density | A second attribute, one block per combination |

**Rule: The themes are the product's decision.** One theme is a complete system: set `color-scheme` to it and stop. Add a theme when asked; roles make it a remap, and every pair is gated again.

**Rule: The right theme at first paint, and at once on every later change.** A stored choice applies while the HTML is parsed. The OS setting, the toggle and another tab apply live, with no reload and no transition: a theme change is not an animation.

→ `references/examples.md` § Theme at first paint, `references/tokens.md` § Scopes beyond light and dark.

---

## Components

**Rule: Choose the API by what varies.**

| What varies | API |
|---|---|
| The look: emphasis, color, size | One `variant` union of the designed looks, plus `size` |
| A state the component owns: `disabled`, `loading`, `open` | A boolean. State the parent may drive takes the controlled trio: `open`, `defaultOpen`, `onOpenChange` |
| The element, the role or the interaction: it navigates, it toggles, it has no text | Another component over the same styles |
| Library behavior on your element: a dialog trigger that is your Button | The library's composition prop (`render`, `asChild`) |
| The arrangement: parts reordered, left out, inserted | Parts exported by name (`Card.Header`), never `showHeader` props |

**Rule: A look never carries behavior.** A flag that changes what an element is or does leaves its ARIA to every call site. The component that owns the behavior renders the ARIA and styles from it.

```tsx
// ❌ Flags on one component: each call site has to remember the rest
<Button iconOnly aria-label="Close"><CloseIcon /></Button>
<Button selected={isFavorited} aria-pressed={isFavorited}>Favorite</Button>
<Button asLink href="/pricing">Pricing</Button>

// ✅ Separate contracts over one set of styles
<IconButton label="Close"><CloseIcon /></IconButton>
<ToggleButton pressed={isFavorited} onPressedChange={toggle}>Favorite</ToggleButton>
<Link href="/pricing" className={buttonVariants({ variant: 'ghost' })}>Pricing</Link>
```

**Rule: Buy behavior, build the look.** Reach for a native element first (`<button>`, `<dialog>`, `<details>`, a checkbox with `accent-color`), then the repo's headless library, wrapped once in `shared/ui`: dialog, menu, select, combobox, tabs, tooltip, popover, toast, date picker. Hand-roll a widget only when neither has it, and ship its keyboard map as tests. A styled kit in the repo (MUI, Mantine, Chakra) is the component layer: tokens enter through its theme API, never a second styling layer.

**Rule: `className` on a system component carries layout only:** margin, width, grid placement. Color, radius, type and state go through a variant or a token, and an override that repeats is a missing variant.

**Rule: State comes in through props.** A primitive owns only what it can: open, pressed, focused. Everything else arrives as props, so a hook's value plugs straight in:

```tsx
<FavoriteToggle productId={card.id}>
  {({ isFavorited, isPending, toggle }) => (
    <ToggleButton aria-label="Favorite" pressed={isFavorited} loading={isPending} onPressedChange={toggle}>
      <HeartIcon filled={isFavorited} />
    </ToggleButton>
  )}
</FavoriteToggle>
```

Where that logic lives and how it reaches markup (hooks, render props, compound blocks over contexts, HoCs) follows react-architecture, if available.

**Rule: The floor is built into the primitive, so no screen can forget it.**

- **Focus** is a real outline, 2px at 3:1, defined once for every focusable element. A box-shadow ring disappears in forced colors. Nothing sticky may cover it (`scroll-padding-top`).
- **Targets** are at least 24×24 CSS px, and 44pt (iOS) or 48dp (Android) under a finger.
- **Names:** an icon-only control cannot be written without a label, nor a dialog without a title.
- **Never color alone:** errors add an icon and text; selected, pressed and current add a border, a check or weight; links in running text are underlined.
- **Unavailable:** native `disabled` when the reason is obvious; `aria-disabled`, still focusable, when the user must learn why. Loading keeps the width, the name and the focus.
- **Text grows:** at 200% text and 320 CSS px wide, labels wrap and nothing clips. Size to content, with logical properties (`ps-`, `ms-`): translation flips direction and doubles lengths.

**Rule: Components answer to their container, pages to the viewport.** A card styled by viewport breakpoints breaks when it moves into a sidebar.

→ `references/examples.md`.

---

## Motion

**Rule: Durations, distances and scales come from tokens.** Movement is built on the motion tokens, so reduced motion is decided once: under it the distance is zero and the scale is one, and what was a slide becomes a fade.

**Rule: Reduced motion removes movement, not feedback.** Translation, rotation, scaling, parallax and scroll-linked motion go. Color and opacity changes stay, and so do spinners and progress. Never a global `*` reset: it freezes every spinner, and a loading app looks hung.

**Rule: Motion explains a change, or it is optional.** Animate `transform` and `opacity`. Exits run one step shorter than entrances.

→ `references/motion.md`.

---

## Changing a Live System

**Rule: A changed default changes every call site.** Before touching a component others use, record what each call site renders today, in each theme: element and `type`, look, ARIA, behavior, `className` overrides, accidents included (an implicit form submit, an unstyled combination). In one app, change every call site in the same change and list each delta as intended or fixed. A system shared by several apps takes an alias and a deprecation first.

**Rule: Retrofit by intent, not by value.** The property and its context pick the token: `#fff` behind a card is `bg.raised`, and as a label on a fill it is `fg.onAccent`. Codemod only the unambiguous cases, triage the rest by hand, and list each near-miss you snapped to a scale step. Never snap a brand value.

**Rule: "Looks dated" is mostly inconsistency.** Count the distinct values behind each property first: font sizes, grays, radii, shadows, spacing. Collapse them onto the scales, then retune the scales in the token file (type ratio, neutral ramp, radius, elevation). Never restyle screen by screen.

**Rule: A rule without a guard decays.** Three checks hold the system without a reviewer: the closed vocabulary (off-system utilities do not compile), the token test (every theme has every role, every pair passes) and the literal test (a count per kind that only goes down).

→ `references/lib.md`.

---

## Sizing the Work

Read first: where the values live (CSS variables, a Tailwind theme, theme objects, `components.json`), the styling engine, the headless library or styled kit, and the component nearest to what you need. Then split the request into its parts, classify each by the repo and not by its wording, and do no more than that part's row.

| The part | Do | Never |
|---|---|---|
| Build or change a screen | Compose the tokens and components that exist. A gap goes through the next row | Tokens, folders or components "for later" |
| The system lacks a value, a look or a component | Add the token, variant or component by the rules above | A literal, a `className` override, a near-copy |
| A component's API or default changes | Call-site deltas, in the same change | A silent default |
| A new theme | Over literal colors, make them roles first, and size that job from the literal count: what isn't a role can't be remapped. Then one block and its pairs. Sizes and spacing can wait | `dark:` utilities |
| "Looks dated", "polish this" | Census, collapse, retune; before and after screenshots per theme | A new look on top of the old spread |
| Asked to set up a system | In order: census of literals and of components by call sites → roles and pairs, tested → themes → bridge and guards at today's counts → primitives, most-called first | A primitive nobody calls; a token pipeline |
| Audit | Read-only and ranked: literal counts and distinct values, failing pairs, hand-rolled widgets, duplicate primitives, `className` overrides | Fixes mixed into findings |

Ask once, and only what the repo cannot answer. Otherwise assume and say so: one app, the themes it has today, WCAG 2.2 AA (or the floors in the UX doc, default `docs/ux/ux-design.md`), code as the source of truth.

Report in this order: the decisions the owner must make (every changed brand value is one), call-site deltas, tokens and props added or renamed, then one line per finding outside the task (a pair that already fails, a call site that relies on an accident). Say what changed on screen, not what you did. A theme script never loaded in a browser, or a native build never run, is reported as unverified, with its risk. Don't quote these rules in comments or reports.

---

## Anti-Patterns

- **`bg-blue-600`, `text-[#111]`, `text-[13px]`, `z-50`, `style={{ color: '#111' }}`** → a role or a scale step; a value the system lacks is added as a token
- **`text-[15px]` or `rounded-[10px]` because the product's size is off the engine's scale** → retune the step in the token file (`--radius-lg: 0.625rem`), then use `rounded-lg`
- **`dark:bg-gray-900` in app code** → the role remaps in the theme block
- **`text-white` on a fill, or a fill as text (`text-primary` on a link, `text-destructive` on an error)** → the fill's on-color; an `fg` role
- **`hover:bg-accent/90`, `opacity-80` as a hover** → the hover token: an alpha fill is a pair nobody gated
- **`<Button iconOnly>`, `<Button asLink>`, `<Button selected>` with `aria-*` at the call site** → `IconButton`, a link styled by `buttonVariants`, `ToggleButton`
- **`<Card showHeader showFooter headerAction={…}>`** → parts the screen arranges
- **`<Button className="rounded-full bg-red-600">`** → a variant; `className` carries layout only
- **`Button2`, `NewButton`, a second Typography** → a variant of the first, or a migration that ends with one
- **`ProductCard`, `CouponDialog` or a fetching component in `shared/ui`** → with its entity, in a block or in the screen
- **A hand-rolled dialog, menu or combobox; `<div onClick>`** → the headless library's, or a native element
- **`"Close"`, `"Loading…"` or `"Required"` written inside a primitive** → a prop; the screen holds the copy
- **`outline-none` with a box-shadow ring** → a real outline
- **`@media (prefers-reduced-motion) { * { animation: none } }`** → distances from the motion tokens; spinners keep turning
- **A theme applied in an effect, or a fade when the theme changes** → the inline script; transitions off for that frame
- **A color judged by eye, or checked in light only** → the token test, in every theme
- **A new default (`type`, a variant's look) shipped without reading call sites** → record first, list the deltas
- **A token JSON pipeline, Storybook or thirty primitives on day one** → what today's call sites use

---

## Checklist

### Tokens and themes
- [ ] No literal added outside the token sources, new system files included; the literal test's counts did not rise from before the change
- [ ] Every new role has a value in every theme and its pairs in the token test; the test passes
- [ ] No `dark:` utility and no theme branch in a component; the theme is right at first paint and after each live change
- [ ] Supplied brand values are exact wherever they pass; each shift is the smallest that passes and is offered to its owner

### Components
- [ ] Nothing new duplicates what `shared/ui` had; nothing in `shared/ui` names the domain, fetches or holds copy
- [ ] One look union plus size; behavior differences are separate components that own their ARIA
- [ ] `className` at call sites is layout only
- [ ] Bought behavior is wrapped once in `shared/ui`, and app code imports UI from nowhere else

### Floor
- [ ] Focus is a visible outline in every theme and in forced colors; targets meet the floor
- [ ] No state relies on color alone; icon-only controls and dialogs have names
- [ ] Each new interactive part names its native element or ARIA pattern and its keys, and answers every row of the states table
- [ ] Under reduced motion nothing moves, and spinners still turn
- [ ] At 200% text and 320 CSS px, labels wrap and nothing clips

### Change
- [ ] Every call site a change reaches renders as recorded, per theme, or its delta is listed
- [ ] The footprint matches the task's row: no token, component or pipeline without a consumer
- [ ] Nothing unverified is reported as verified

---

## References

Read the one the task needs.

| File | Read when | Contents |
|---|---|---|
| `references/examples.md` | Writing a token file, a theme script or a component | One system, file by file: tokens, first-paint theme, Button family, Field, Dialog, Card, a screen and a form built from them, the states table |
| `references/tokens.md` | Choosing a role, a brand color, a scale or a scope | The role map, traps the pairs avoid, a brand color's path into the system, space, type and layers, art-directed, brand and density scopes |
| `references/lib.md` | Adding a guard | `color.ts`, the token test, the literal test, the import rule |
| `references/motion.md` | Any animation | Motion tokens, the reduced-motion mechanism, rules, view transitions |
| `references/react-native.md` | React Native | The theme module and provider, Button, the pair test's lookup, type, accessibility |
| `references/stack.md` | Wiring Tailwind, shadcn or a headless library; a symptom after an upgrade | Dated notes: typed namespaces, shadcn's vocabulary and generated-code review, library attributes, React and Next.js |

Siblings, if available: react-architecture (structure, hooks, headless and compound blocks), ux-design and screen-design (flows, a screen's states and copy, the floors a product commits to), i18n (locale logic), Expo's official skills (native lists, gestures, performance), web3d (3D engines).
