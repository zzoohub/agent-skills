# shadcn/ui

shadcn copies component source into the repo: the code is yours to edit and to hold to this system. Skip it for a design language far from its interaction model.

## Detect Before Generating

- **Headless library:** the `style` in `components.json` names it: `base-*` (Base UI, `@base-ui/react`), `radix-*` (Radix, `radix-ui`; also a legacy `new-york` or `default`) or `aria-*` (React Aria Components). Base UI composes with `render`, Radix with `asChild`, React Aria with a `render` function (`components.md`). New projects have defaulted to Base UI since July 2026 (`shadcn init -b radix` or `-b aria` picks another). Follow the repo; never mix two.
- **Migrations:** prefer `shadcn migrate radix` (per-primitive `@radix-ui/react-*` imports to `radix-ui`) and `shadcn migrate cn` (`clsx` and `tailwind-merge` to the `cn` package) over hand edits, then re-run the merge check (`platform-web.md` § Class Merging).
- **Base UI setup:** follow its quick start, including the isolated app root (`isolation: isolate`), or popups stack under page content.
- **Placement:** `aliases.ui` (for example `"@/shared/ui"`) decides where components land; without it, the CLI writes to its default folder and the system splits in two. With two or more consuming apps, point it at the shared UI package.

## Point shadcn's Variables at the Tokens

Generated code depends on shadcn's vocabulary (`primary` and `primary-foreground`; `accent`, a subtle hover surface, not the brand; `destructive`; `input`; `ring`), so it is the project's Tailwind vocabulary: keep shadcn's `@theme inline` block, with `--color-*: initial;` added first, instead of `platform-web.md`'s names, which would give `accent` two meanings. Replace shadcn's `:root` and `.dark` value blocks with one mapping; the `--ds-*` variables already switch per theme. Declare it on every themed element: an alias resolves where it is declared, so on `:root` alone a nested theme keeps the outer colors.

```css
:root, [data-theme] {
  --background: var(--ds-bg-base);
  --foreground: var(--ds-fg-default);
  --primary: var(--ds-bg-accent);
  --primary-foreground: var(--ds-fg-on-accent);
  --accent: var(--ds-bg-subtle);
  --accent-foreground: var(--ds-fg-default);
  --destructive: var(--ds-bg-danger);
  --input: var(--ds-border-input);
  --ring: var(--ds-border-focus);
}
```

Map every variable your components reference, plus what the fixes below need in `@theme inline` (`--color-primary-hover: var(--ds-bg-accent-hover)`, `--color-link: var(--ds-fg-accent)`, then `danger-subtle` and `danger-strong` the same way; legacy `--color-destructive-foreground: var(--ds-fg-on-danger)`), and point the `dark:` variant at the theme attribute (`platform-web.md`).

## Fix Generated Components

Review each component as it lands; defaults break the floor:
- **`outline-none` → `outline-hidden`.** In Tailwind v4, `outline-none` removes the outline and forced-colors mode drops the box-shadow ring, so focus disappears; `outline-hidden` keeps a transparent outline that forced colors reveal.
- **Alpha modifiers change the pair.** With the example palette, `ring-ring/50` gives the focus ring 1.81:1, and `hover:bg-primary/80` drops the on-token to 3.63:1 in light and 4.04:1 in dark (legacy `new-york`'s `/90`: 4.32:1); use the full `ring` and the hover token (`hover:bg-primary-hover`).
- **Destructive is a tint** (`bg-destructive/10 text-destructive`): the fill read as text, at 2.84–4.13:1 across states and themes. Restyle it from the pair table: the danger ghost (`text-danger-strong hover:bg-danger-subtle`), or `bg-danger-subtle text-danger-strong` with an admitted hover token. Legacy `new-york` puts `text-white` on a solid `bg-destructive`: use `text-destructive-foreground`.
- **Fills used as text:** `text-primary` (the `link` variant) and `text-destructive` (error messages) read fills, at 3.99:1 and 3.90:1 on dark `bg.raised`: use `text-link` and `text-danger-strong`; the role gate (`platform-web.md` § Guards) finds the rest.
- **`dark:` overrides** (`dark:bg-destructive/20`) bypass the token remap; delete them, or gate each one as a pair.
- **`import { cn } from "cn"` → the system's helper.** Since September 2026, generated components import the `cn` package directly, and its default tables drop a token-named size next to a text color; import the configured helper (`platform-web.md`) and ban bare `cn` imports with `no-restricted-imports`.
- **Bare `<button>` elements submit their form;** default `type="button"`.

## Forms

Compose the `Field` family (`Field`, `FieldLabel`, `FieldDescription`, `FieldError`) with the project's form library. The system owns layout and the description and error slots (`aria-describedby`, `aria-invalid`); validation belongs to the feature.
