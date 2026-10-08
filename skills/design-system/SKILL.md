---
name: design-system
description: |
  Design tokens, theming and component APIs for web and React Native: use, extend, establish, theme, migrate or audit a design system.
  Use for visual styling, palettes and contrast pairs; tokens (color, type, spacing, shadow, z-index, motion); dark mode and brand themes; Tailwind or shadcn wired to tokens; variants, compound parts and boolean-prop sprawl; UI animation (hover, open/close, CSS 3D) and reduced motion: "design tokens", "add dark mode", "hardcoded colors", "looks dated", "build a Button component", "set up a design system".
  Do NOT use for: app IA, flows or UX review (ux-design); one screen's spec (screen-design); route or shared-element transitions (react-view-transitions).
---

# Design System

## Premise

A design system exists to make the next UI decision faster than the last one. Tokens and props are public API: reuse beats extension, a rename is a migration, and a changed default changes every call site. Accessibility is decided at the color pair and the component contract, not in review.

## Stage 0: Frame, Classify, Inspect

**Frame by the outcome.** Solve for the end users and the engineers calling the system: when the evidence puts the problem beyond the request (the same defect in a sibling, a part the consumer lacks, a wrong premise), solve it or hand it off specified well enough to act on.

| Class | Inspect first | Deliver |
|---|---|---|
| **Use** | nearest component and its tokens | code on existing tokens; gaps listed, not filled |
| **Extend**: token, variant, component | would-be consumers; nearest existing token | the addition, via admission; aliases for renames |
| **Refactor**: any change that can alter an existing call site's output (API, variants, a default, a merge or split) | each call site's output today, per theme: element and `type`, look, ARIA, behavior, `className` overrides, accidents included (an implicit submit; conflicting utilities, where stylesheet order picks the winner; an unstyled combination) | the new API; old → new per call site; each delta, marked intended or fixed |
| **Establish** | brand input; existing literals and components | foundations, in the order below |
| **Theme**: dark, brand, density | each semantic key per theme and brand; when theme input arrives; brand surfaces outside tokens; pairs failing today | remap; full pair table per brand × mode; right theme at every arrival |
| **Refresh**: "looks dated", "polish this" | distinct values per property (font sizes, grays, radii, shadows, spacing) | values collapsed onto each scale first (inconsistency is most of "dated"), then foundations retuned in tokens (type ratio, radius, neutral ramp, elevation); before/after screenshots per theme |
| **Migrate**: rename, Tailwind v3→v4, library swap, literal retrofit | literals by frequency; consumers per token; screenshots per theme | alias → deprecate → codemod → remove, then a gate |
| **Audit** (read-only) | literal and distinct-value counts; pairs (the pair table, else axe per theme on key screens); hand-rolled widgets outside the system folder (`role` dialog, menu, listbox or tab; `onClick` on a `div`); duplicate primitives; `className` overrides | ranked findings |

**Classify by the repo, not the request.** Dark mode over raw literals is a Migrate first (retrofit, then remap), sized from the literal count. App code never carries `dark:` utilities: each bypasses the remap and adds a pair to gate.

**Inspect before proposing:** where tokens and their pair table live (CSS variables, Tailwind theme, theme objects, `components.json`, Figma via its capability, if available); the headless library or styled kit, styling engine, icon set and platforms; the UX doc's accessibility requirements: conformance target, floors, text scaling (default `docs/ux/ux-design.md`; caller may redirect).

**Ask once, only what the repo cannot answer**; otherwise assume and report these defaults:
- one consuming app, in-repo, unversioned;
- light and dark themes following the system, with a persisted override;
- WCAG 2.2 AA;
- code is the source of truth; Figma mirrors it;
- no brand input: keep existing scales, mark brand values as placeholders, never invent a palette. Brand input given: its values are requirements (Theming).

**Proportion sizes the change and the report, never the inspection.** A Use or small Extend changes only what it touches, yet reports each material finding in a line (a pair already failing, a call site relying on accidental behavior). A scope cut states its reason and leaves something that works for its consumers. Only Establish creates structure, in this order: inventory literals and components (by call sites) → semantic map and pair table, gated per theme and committed beside the tokens → flash-free themes → bridge and guards at today's count → primitives in call-site order. **Done** means the Self-Review passes.

**Out of scope** (via that capability, if available): app IA, flows, UX review (ux-design); one screen's spec (screen-design); route transitions (react-view-transitions); React or RN performance (react-best-practices, react-native-skills); locale logic (i18n); 3D engines and XR input (web3d, ux-design).

## Tokens

**Tiers and names:** primitive (`gray.500`) → semantic (`bg.accent`) → component (a rare override or a white-label API); components never read primitives, so retheming never touches one. Names run category, role, then optional prominence and state (`bg.dangerSubtle`, `bg.accentHover`); roles name intent, never hue (`blue` breaks on rebrand) or rank (`tertiary` says nothing about use).

**Pairs, not colors, pass or fail.** Every fill ships with its on-token (`bg.accent`/`fg.onAccent`), and components pair it only with that: never `text-white`, a primitive, or another fill used as text. Gate each pair in each theme, on every surface it can sit on:
- text ≥4.5:1, or ≥3:1 at ≥24px (≥18.66px bold);
- icons, focus indicators, input borders that are the field's only boundary, and the cue that marks a state (selected, pressed): ≥3:1 against what they touch.

Compute ratios with a WCAG 2 script, never by eye. Exempt: decorative fills, disabled controls, logos.

**Admission.** Add a semantic token only when no existing token covers the intent, it has ≥2 consumers or is a deliberate theming seam, it has a value in every theme, and its pairs pass; otherwise reuse the nearest. A bypass is evidence, not a verdict: a gap (extend), a discoverability problem (document when to pick it over its nearest sibling), a one-off (`token-exempt`) or a wrong abstraction (change the component API). Two bypasses with one intent mean extend.

**Composing:** hierarchy from size, weight and `fg` role before boxes, borders or color; one accent fill per region (its primary action); `space.component` within groups, `space.layout` between them; shadows for layers, not emphasis; status colors for status only.

## Theming

- Themes remap semantic variables on `[data-theme]` (any element: an inverted band is a theme, not literals) and set `color-scheme`. Every theme defines every semantic key; components never read the theme in JS.
- **Theme input arrives at first paint, later and live:** a stored or server-known choice; a tenant brand after login or a preference from native storage; an OS change, the toggle, another tab. Each arrival applies once, with no reload and no flash (`references/platform-web.md` § Theme Application).
- **Brand values are requirements, not seeds.** A supplied value stays exact wherever it passes: as a fill, white or black always reaches ≥4.58:1 on it (their ratios multiply to 21), and in dark mode the fill also needs ≥3:1 against its surfaces, or the primary action reads as an outline. A failing role takes the smallest OKLCH lightness shift that passes in that mode, never a snap to a ramp step. Each change, or a brand-fixed on-color that fails, is the owner's decision between that shift and a neutral fallback with a non-color cue (`references/tokens.md` § Palette); the shift ships as provisional unless the brand's rules forbid altered values.
- Brand ramps supply hover, pressed and subtle tones. Gate the full pair table for every brand × mode, not only the pairs you touched, and keep brand fills distinct from status fills (a red brand never doubles as `danger`).
- **Brand surfaces outside tokens** (favicon, `theme-color`, manifest, splash and status bar, emails, charts and canvas, SVG logos, third-party widgets): inventory them; each follows the theme or is listed.
- **Density** remaps the space scale on `[data-density]`; targets never shrink below the floor.

## Components

**Choose the API by what varies, with the fewest public concepts:**

| What varies | API |
|---|---|
| Look only: emphasis, color, size | one `variant` union of the designed looks, plus `size`. Break: separate axes (`tone` × `emphasis`) only when most cells are designed and chosen independently |
| A state the element or component owns (`disabled`, `invalid`, a disclosure's `open`) | a boolean; owned state takes the controlled trio (`open`/`defaultOpen`/`onOpenChange`). Break: two flags that can form an impossible state become one enum |
| The element, ARIA role, required attributes or interaction model (navigates, toggles, selects, icon-only) | a separate component that owns its state and ARIA, on a shared styling base: a link stays `<a>`; IconButton requires `label`; a toggle owns `pressed`; a single choice is the library's toggle group or a radio group. Break: native attributes (`type="submit"`) pass through |
| Library behavior on your element (a dialog trigger that is your Button) | the library's `render` or `asChild` |
| Consumers reorder, omit or insert parts (`showHeader`-style props) | compound parts. Break: a component that indexes its collection (virtualization, typeahead) takes `items` plus a render function |

- **A look never carries behavior:** no boolean mode (`iconOnly`, `asLink`, `selected`) with ARIA added at call sites; the owning component renders the ARIA and styles from it (`aria-pressed:`, the library's `data-*` state).
- **The common call stays unchanged:** keep the repo's prop names and values; a bare `<Button>` renders today's default.

**Govern the surface.** A pattern joins the system at its third independent use (its second, once copies diverge in behavior or accessibility). A new look value needs two call sites with one intent; a behavior difference is a component at any count. `className` on a system component carries layout only (margin, width, placement); color, radius and type go through a variant or token.

**Buy behavior, build the look.** Dialog, menu, listbox, select, combobox, tabs, toggle group, tooltip, popover, toast and date picker come from the repo's headless library (none yet: `references/components.md` picks one). A styled kit in the repo (MUI, Mantine, Chakra, Ant) is the component layer: tokens enter through its theme API, never a second styling layer.

**Feature components** with several call sites and state sources (a composer, an editor) follow `references/composition/guide.md`; primitives do not. **Provider ≠ Frame:** one provider per state source injects `{ state, actions, meta }`; the frame only lays out, so siblings need no `useEffect` sync or refs.

## Accessibility Floor

- **Focus:** a real outline (forced-colors mode drops box-shadow rings), ≥3:1 against adjacent colors, 2px as the house standard; never hidden under a sticky header (`scroll-padding-top`, WCAG 2.4.11).
- **Targets:** ≥24×24 CSS px for pointer input (WCAG 2.5.8); touch components 44pt on iOS, 48dp on Android. Break: links in running text. Floors: the UX doc, or ux-design's ergonomics reference, if available.
- **Disabled:** native `disabled` when the reason is obvious; `aria-disabled`, still focusable, when users must learn why, and inside menus, toolbars and tabs (APG).
- **Never color alone, in any state:** errors pair color with an icon and text; selected, pressed, current and required states add a border, check, weight or text cue; links in running text are underlined (break: navigation and link lists, where position identifies them).

## Motion

This skill owns motion tokens, the reduced-motion policy and engine-agnostic animation rules (`references/motion.md` § Implementation Rules); durations and easings come from tokens.

**Reduced motion removes spatial motion:** translation, rotation (3D flips, tilts), scaling, parallax, blur, and scroll-linked or autoplay movement, replaced by a fade or the end state. Keep color and opacity feedback (≤200ms) and essential indicators (spinners, progress). Implement it with tokens, never a global `*` reset, which freezes spinners. Break: a small user-triggered change (a switch thumb) may keep ≤100ms.

## Guards and Change Management

- **Literal count** (Establish, Migrate, Refresh, Audit, or adding the gate): lines with a raw literal outside the token sources, minus lines marked `/* token-exempt: reason */` (command and sanity check: `references/platform-web.md` § Guards). CI fails when it rises; a changed command starts a new baseline.
- **Imports:** app code takes UI only from the system folder (default `src/shared/ui/`; caller may redirect); `no-restricted-imports` bans the headless library and wrapped React Native primitives elsewhere.
- **Retrofit by intent, not value:** the property and its context pick the token (`#fff` behind a card is `bg.raised`; as a label on a fill, `fg.onAccent`). Codemod only unambiguous property-value pairs, triage the rest by hand, and list each near-miss snapped to its nearest step (never a brand value).
- **Call-site deltas** (Refactor): a fixed default is a delta too. Once `<Button>` defaults to `type="button"`, implicit form submits stop: give the intended ones `type="submit"` and list the call sites that relied on the old behavior. In one app, update every call site in the same change.
- **Breaking changes** (systems shared by ≥2 apps): a removed or renamed token or prop, or a changed default, element, role or DOM structure consumers select on. Each ships as alias plus deprecation lint, then codemod, then removal in the next major.

## References (Read When…)

- `references/tokens.md`: any token value, color pair, brand color or palette.
- `references/typography.md`: type scale, font stacks, fluid type, CJK.
- `references/motion.md`: any animation.
- `references/components.md`: writing or refactoring a component; a toggle, link or icon-only control.
- `references/composition/guide.md`: refactoring a feature component's API.
- `references/platform-web.md`: CSS variables, theme and brand scripts, Tailwind, overlays, focus, web symptoms, guards.
- `references/shadcn.md`: the repo has a `components.json`.
- `references/react-native/platform.md`: React Native.
- `references/pipeline.md`: two or more platforms, or frequent token changes.

## Report Back (≤250 words, tables included; an Audit ≤500)

Lead with decisions needed (each with its options and the default shipped; every changed brand value is one) and decisions taken, then call-site deltas, then, as they apply: tokens and props added, renamed or deprecated (old → new); defaults assumed; unverified changes and their risk; every other material finding, a line each, in scope or not. A metric or table appears only when the task changed or concerns what it measures, sanity-checked first. An Audit returns ranked findings (call sites × severity). Items are a menu: omit what does not apply. Never narrate this skill's rules in comments or reports.

## Self-Review

Check each item that applies to what the change touched; 7 and 9 apply whenever call sites or runtime behavior can change.
1. No raw literal added outside token sources (`token-exempt: reason` where needed); where a count is kept, it did not rise.
2. Every pair the change adds or touches passes per brand × mode by script, hover, pressed and alpha fills included; the full table is run, and each failure already in place is fixed or reported; the role gate is clean; no state relies on color alone.
3. Themes share identical semantic keys; the theme is right, without a flash, at every arrival listed under Theming (a reload in each non-default theme included); brand surfaces outside tokens follow it or are listed.
4. Each new interactive part names its native element or APG pattern, keyboard map and accessible-name source; axe (web) passes in each state; focus shows in forced colors; targets meet the floor; at 200% text and 320 CSS px width, labels wrap, never clip or overlap.
5. Under reduced motion nothing translates, rotates, scales or parallaxes beyond the switch-thumb break; spinners and progress still animate.
6. Fewest concepts: one look union plus size unless a split is justified (every cell then styled or excluded in the type); behavior differences are components owning their state and ARIA; admission passed; renames aliased (shared systems) or applied at every call site; no two booleans form an impossible state; the typecheck passes.
7. Each call site the change reaches renders and behaves as recorded, per theme, or its delta is reported (a changed default counts).
8. Supplied brand values stay exact wherever they pass, dark-mode fills checked against their surfaces; each shift is the smallest passing one per mode, offered to its owner beside the neutral fallback.
9. Nothing unverified (a theme script without a browser, a native build, a live brand API) is reported as verified: it ships flagged or with a named verification step, risk stated.
10. **Footprint:** Use and Extend add no folder, pipeline or headless layer; Establish adds no component without a consumer; the report fits its budget, tables included, or says why, and drops no material finding.
