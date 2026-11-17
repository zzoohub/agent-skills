# Stack Notes

Dated facts about the tools the examples use. The rules in SKILL.md do not depend on them; the syntax does.

**Last verified 2026-11-17** by build and browser on tailwindcss 4.3, tailwind-merge 3.7, `@base-ui/react` 1.9, shadcn 4.23 (`base-nova`), Next.js 16.4, React 19.3 and react-native 0.86. Re-check a note against the installed version before relying on it, and prefer the vendor's version-matched docs where they ship with the package: `node_modules/next/dist/docs/` (its guide on preventing flash before hydration covers the theme script), `node_modules/@base-ui/react/docs/`.

## Tailwind v4

- **Typed color namespaces.** `bg-*` reads `--background-color-*` before `--color-*`; `text-*` reads `--text-color-*`, `border-*` reads `--border-color-*`, `outline-*` reads `--outline-color-*`. The same exists for `ring`, `divide`, `fill`, `stroke`, `placeholder`, `caret`, `accent` and `decoration`. The engine reads them and its maintainers point people to them, but the docs' namespace table does not list them. If an upgrade drops one, its utilities stop compiling, which is loud. The fallback is `--color-*` with the category in the name (`--color-fg-default`, `--color-on-accent`) plus a check that no fill is used as text.
- **Confirm the closure after wiring the bridge:** compile, and check that `text-accent`, `bg-red-500` and `text-white` produce no rule.
- **After `--color-*: initial`,** `transparent`, `current` and `inherit` still work; `black` and `white` do not. `ring-*` and `divide-*` have no colors unless their namespaces are given some; the base rule that sets every element's border color makes a bare `border` or `divide-y` draw `border.default`.
- **`@theme inline`** for every bridge line. Without `inline` the utility reads a variable that was resolved on `:root`, so a theme on `<html>` works and a theme on any other element keeps the outer colors.
- **Focus:** `outline-none` removes the outline, and forced colors drops box-shadow rings, so the two together leave no focus indicator. `outline-hidden` keeps a transparent outline that forced colors shows. The base `:focus-visible` rule in the token file needs neither.
- **Class merging** (`tailwind-merge`): role colors beside the engine's size names merge correctly with no configuration. A custom size or shadow name (`text-body-md`, `shadow-card`) must be registered with the merger, or `cn('text-body-md', 'text-muted')` keeps only the color. One more reason to keep the engine's names.
- **From v3:** after the upgrade tool, compare meaning and not only syntax. Borders and rings default to `currentColor`, a bare `ring` is 1px, `outline-none` changed as above, and the `shadow`, `rounded` and `blur` scales moved one step (`shadow-sm` became `shadow-xs`). Each silently changes a pair or a focus indicator. On v3, or a JS config loaded with `@config`, put the role names under `theme` itself: under `theme.extend` the default palette survives.

## shadcn/ui

Generated code is copied into the repo, so it is the system's to edit and to hold to the floor.

- **Its vocabulary is the repo's vocabulary.** Keep `primary` and `primary-foreground`, `muted`, `destructive`, `border`, `input` and `ring`: generated code depends on them, and they already pair a fill with its text. Two things differ from the examples here: `accent` is a subtle hover surface, not the brand, and themes switch on a `.dark` class (with `next-themes`), so that class is the scope.
- **Placement:** `aliases.ui` in `components.json` decides where components land. Point it at the system folder, or the system splits in two. The `style` field names the headless base (`base-*`, `radix-*`, `aria-*`; a legacy `new-york` or `default` is Radix); new projects have defaulted to Base UI since July 2026. Follow the repo's and never mix two.
- **Review each component as it lands.** Measured on the default neutral theme:
  - Focus is `outline-none` plus a `ring-ring/50` shadow: 1.5:1 in light, and nothing at all in forced colors. The full `ring` color is 2.6:1 in light until it is retuned.
  - An input's only boundary is `border-input`, at 1.3:1.
  - Alpha states are pairs nobody gated: `hover:bg-primary/80`, and the destructive button's `bg-destructive/10 text-destructive` at 4.1:1 in light. With a mid-tone brand `primary`, the hover fails.
  - Fills used as text: `text-primary` in the link variant, `text-destructive`.
  - `muted-foreground` on `muted` is 4.3:1.
  - `dark:` overrides on most components bypass the remap: delete each, or gate it as a pair.
  - Arbitrary values (`text-[0.8rem]`), `z-50`, and built-in English (`<span className="sr-only">Close</span>`).
- **`cn`:** generated components import it from the `cn` package directly. If the system configures its own merger, import that one and restrict the bare import.
- **The token test** reads `:root` and `.dark` and takes shadcn's names in its pair list (`lib.md`).

## Headless libraries

| | Base UI | Radix | React Aria Components |
|---|---|---|---|
| Your element under its behavior | `render={<Button />}` | `asChild` | a `render` function of DOM props |
| Enter and exit styles | `data-starting-style`, `data-ending-style` for transitions; `data-open`, `data-closed` for keyframes | `data-state`, keyframes only: a transition is cut at unmount | `data-entering`, `data-exiting` |

- **No library yet:** adopt one before the first widget that needs it. React Aria when RTL, many locales, date widgets or screen-reader parity are core; otherwise Base UI. One library per system, and one composition mechanism.
- **Base UI** wants an isolated app root (`isolation: isolate`) so popups stack above the page, and its Button refuses to render a link: style the `<a>` instead, as `buttonVariants` does.
- **A native `<dialog>` or `popover`** needs `@starting-style` for its entry, and `display` and `overlay` in the transition with `allow-discrete`, or its exit is cut.
- **A styled kit** (MUI, Mantine, Chakra, Ant) is the component layer: tokens enter through its theme API, never through a second styling engine beside it.

## Symptoms

| Symptom | Cause | Check |
|---|---|---|
| The wrong theme flashes on reload | The theme is applied in an effect, after hydration | The served HTML's `<head>` holds the inline script |
| A theme on an inner element keeps the page's colors | A bridge line without `inline`, or an alias variable declared only on `:root` | The compiled utility reads `var(--ds-…)` |
| Scrollbars and form controls stay light in a dark theme | No `color-scheme` in the theme block | The element's computed `color-scheme` |
| Buttons fade while the page jumps on a theme change | Color transitions run during the switch | Transitions are off while the attribute changes |
| No focus indicator in forced colors | `outline-none` with a box-shadow ring | Emulate forced colors |
| `cn()` drops a size or a shadow class | A custom scale name the merger does not know | `cn('text-body-md', 'text-muted')` keeps both |
| A color utility stopped compiling after an upgrade | A typed namespace changed | Compile a probe with one utility per namespace |

## React and Next.js

- The examples use React 19: `ref` as a prop, `<Context value>`, `use(Context)`. On React 18 these are `forwardRef`, `<Context.Provider>` and `useContext`.
- A Server Component cannot dot into an object exported from a client module, and cannot call a function exported from one. Hence parts exported by name and imported as a namespace, and `buttonVariants` in its own file with no `'use client'`.
- A Server Component passed to a headless part's `render` is rendered before the part can hand it children. If it wraps its children, as a button with a label slot does, it comes out with an empty label and no error. Components meant for `render` are Client Components.
- The theme script is rendered by a Server Component in `<head>`, with `suppressHydrationWarning` on `<html>`. Rendered from a Client Component, React warns about the script tag in development.
