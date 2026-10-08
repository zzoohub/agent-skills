# Web Platform

## Token Variables

Names are `--ds-` plus the kebab-case token path (`fg.onAccent` → `--ds-fg-on-accent`): `base.css` holds theme-independent tokens, then one block per theme (`:root, [data-theme="light"]` and `[data-theme="dark"]`, so any element can carry a theme) holds every semantic key, generated (`pipeline.md`) or hand-written.

## Theme Application

```css
:root, [data-theme="light"] { color-scheme: light; }
[data-theme="dark"] { color-scheme: dark; }
```

`color-scheme` makes native controls, scrollbars and form fields follow the theme. Set `data-theme` before first paint with a blocking script early in `<head>`:

```html
<script>
  (function () {
    var root = document.documentElement;
    var serverBrand = root.dataset.brand; // a server-rendered brand always wins
    var media = matchMedia('(prefers-color-scheme: dark)');
    function apply() {
      var choice = null, brand = root.dataset.brand; // kept if storage is unreadable
      try { choice = localStorage.getItem('theme'); brand = serverBrand || localStorage.getItem('brand'); } catch (e) {}
      root.dataset.theme = choice === 'light' || choice === 'dark' ? choice : media.matches ? 'dark' : 'light';
      if (brand) root.dataset.brand = brand; else delete root.dataset.brand;
    }
    apply();
    media.addEventListener('change', apply); // the OS setting, live
    addEventListener('storage', apply); // another tab's theme, brand or logout
  })();
</script>
```

The toggle stores `light` or `dark` (or removes the key for system) and sets `data-theme` the same way. React frameworks that render `<html>` need `suppressHydrationWarning` on it; render the toggle's icon only after mount. A server-read cookie can render explicit choices; system still resolves in the script. Under a strict CSP the script needs a nonce or hash. To follow the system without JS, also emit the dark block, with `color-scheme: dark`, under `@media (prefers-color-scheme: dark)` for `:root:not([data-theme])` (Style Dictionary's `css/variables` takes the two as a selector array). `light-dark()` can replace the dark block only while light and dark are the only modes; it resolves from the `color-scheme` these blocks set.

**Brands** apply the same way on `data-brand`, one generated block per brand × mode. Render the attribute from the server when the tenant is known (domain, session). A brand that arrives after first paint (fetched after login, remote config) is set once on arrival and stored, so the head script replays it and only a first visit shows the default brand. Clear the stored brand and the attribute at logout, and replace both on a tenant switch, or a shared device shows the last tenant's brand wherever the server cannot brand the page (a shared login page). Canvas, charts, maps and third-party widgets that copy colors at init re-read them on every theme or brand change.

## Tailwind v4 Bridge

Map each semantic variable once, under a name that reads as its role, and reset the namespaces the system owns (a shadcn project keeps shadcn's names: `shadcn.md`):

```css
@import "tailwindcss";
@import "./generated/base.css";
@import "./generated/light.css";
@import "./generated/dark.css";

/* For `dark:` classes in generated components only. */
@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));

@theme inline {
  --color-*: initial;
  --color-base: var(--ds-bg-base);
  --color-raised: var(--ds-bg-raised);
  --color-subtle: var(--ds-bg-subtle);
  --color-accent: var(--ds-bg-accent);
  --color-accent-hover: var(--ds-bg-accent-hover);
  --color-danger-subtle: var(--ds-bg-danger-subtle);
  --color-fg: var(--ds-fg-default);
  --color-fg-muted: var(--ds-fg-muted);
  --color-link: var(--ds-fg-accent);
  --color-on-accent: var(--ds-fg-on-accent);
  --color-danger-strong: var(--ds-fg-danger-strong);
  --color-line: var(--ds-border-default);
  --color-input: var(--ds-border-input);
  --color-focus: var(--ds-border-focus);
  /* …one line per remaining semantic color */
  --shadow-*: initial;
  --shadow-card: var(--ds-elevation-card);
  /* …dropdown, modal, toast */
  --radius-*: initial;
  --radius-md: var(--ds-radius-md);
  /* …sm, lg, full */
  --text-*: initial;
  --text-body-md: var(--ds-type-body-md-font-size);
  --text-body-md--line-height: var(--ds-type-body-md-line-height);
  --text-body-md--font-weight: var(--ds-type-body-md-font-weight);
  /* …one triple per type style */
  --default-transition-duration: var(--ds-duration-fast);
  --default-transition-timing-function: var(--ds-easing-default);
}
```

- Utilities read as roles (`bg-accent text-on-accent`, `text-link`, `border-input`, `outline-focus`). After the resets, `text-white`, `bg-red-500` and `text-sm` no longer generate; `transparent` and `current` still do.
- One namespace serves every property, so `text-accent` still generates: the fill misused as link text (3.99:1 on dark `bg.raised`). Text tokens get their own stems (`fg`, `link`, `on-*`, `*-strong`), and the role gate below catches the crossover.
- `inline` makes utilities emit `var(--ds-…)` directly, so theme overrides reach them; keep the two names distinct.
- Spacing keeps Tailwind's numeric scale (the same 4px grid). Its utilities read `--spacing` where used, so density remaps that one variable on `[data-density]`, never below `0.1875rem`, where `h-8` reaches the 24px target floor. z-index has no namespace: `z-(--ds-z-index-modal)`; `z-50` and `z-[60]` count as literals.
- Tailwind v3, or a JS config loaded with `@config`: map the same names under `theme` itself for the namespaces the system owns; under `theme.extend` the default palette survives.

## Class Merging

Register token-named sizes and shadows, or `cn('text-body-md', 'text-fg-muted')` keeps only the color, because the merger reads both as text colors:

```ts
import { clsx, type ClassValue } from 'clsx';
import { extendTailwindMerge } from 'tailwind-merge';

const twMerge = extendTailwindMerge({
  extend: {
    theme: {
      text: ['caption', 'body-sm', 'body-md', 'body-lg', 'heading-sm', 'heading-md', 'heading-lg', 'display', 'code'],
      shadow: ['card', 'dropdown', 'modal', 'toast'],
    },
  },
});

export const cn = (...inputs: ClassValue[]) => twMerge(clsx(inputs));
```

On the `cn` package (shadcn's replacement for `clsx` plus `tailwind-merge`), `createCn` from `cn/config` takes the same options; `cn build` (its CLI, Vite plugin or Next.js wrapper) registers the `@theme` scales itself, into tables the helper loads with `createCn` from `cn/engine`. Every component imports this one helper.

## Guards

- **Literal count** (any stack, React Native included). First add one `-g '!<path>'` per file that only defines tokens (`tailwind.config.*`, theme objects, a CSS file of `:root` blocks), then read a sample of matches: definitions, generated output and vendored CSS are not literals, and a count that includes them misleads. In a mixed file, subtract its definition lines.
  ```sh
  rg -n -g '*.{css,scss,ts,tsx,js,jsx}' -g '!**/{tokens,generated}/**' \
    -e '#[0-9a-fA-F]{3,8}\b' -e '\b(rgba?|hsla?|oklch|oklab|lab|lch|color)\(' \
    -e '\b(bg|text|border|ring|outline|fill|stroke|shadow|from|via|to|divide|placeholder|caret|decoration)-([a-z]+-)*([a-z]+-(50|[1-9]00|950)|white|black)\b' \
    -e '\b[a-z]+(-[a-z]+)*-\[([^\[\]]|\[[^\]]*\])*\]([^\]:/]|$)' -e '\bz-\d+\b|z-?[iI]ndex:\s*-?\d' \
    -e '\b(duration|delay)(-\d+\b|\s*:\s*\d)' -e '(transition|animation)[-A-Za-z]*\s*:[^;]*[^\w.-]\.?\d+(\.\d+)?m?s\b' \
    . | grep -vc token-exempt
  ```
- **Tailwind:** the bridge's namespace resets keep off-system utilities from generating.
- **Stylelint** (package `stylelint-declaration-strict-value`). `ignoreFunctions: false` catches `rgb()` and `oklch()` literals; `expandShorthand` checks only the color inside `border: 1px solid var(--ds-…)`. A gradient in the `background` shorthand still fails: make it a token.
  ```json
  "scale-unlimited/declaration-strict-value": [
    ["/color$/", "fill", "stroke", "box-shadow", "z-index", "font-size"],
    { "ignoreFunctions": false, "expandShorthand": true,
      "ignoreValues": ["transparent", "/^currentcolor$/i", "inherit", "none", "auto"] }
  ]
  ```
- **Role gate** (expect no matches): a fill used as text, or a text token used as a fill, in this bridge's names or shadcn's. An on-token drawn as a graphic on its own fill (a radio dot, a switch thumb) is a pair: mark the line `token-exempt: graphic on its fill`.
  ```sh
  rg -n -g '*.{ts,tsx,js,jsx}' \
    -e '\btext-(accent|danger|warning|success|raised|subtle|primary|secondary|destructive|muted)(-hover|-subtle)?([^\w-]|$)' \
    -e '\bbg-(fg|link|on-[a-z]+|[a-z]+-strong|[a-z]+-foreground)\b' . | grep -v token-exempt
  ```

## Upgrading from v3

After `npx @tailwindcss/upgrade` (check its Node requirement), diff meaning, not only syntax: borders and rings default to `currentColor`, a bare `ring` is 1px, `outline-none` removes the outline (the old behavior is `outline-hidden`), and the `shadow`, `rounded` and `blur` scales moved a step (`shadow-sm` → `shadow-xs`). Each silently changes a pair or a focus indicator.

## Focus

```css
:focus-visible {
  outline: 2px solid var(--ds-border-focus);
  outline-offset: 2px;
}
html {
  scroll-padding-top: 4rem; /* token-exempt: sticky header height, so focus is never hidden under it */
}
```

## Layering

Modal `<dialog>` (`showModal()`) and `popover` render in the top layer, above any z-index. z-index tokens order only in-flow and portal layers, where a menu, select or tooltip inside a modal needs `zIndex.popover` above `zIndex.modal`. Keep all overlays in one system: a z-indexed toast renders beneath a top-layer modal, inert.

## Responsive

Components respond to their container, pages to the viewport: a card styled by viewport breakpoints breaks when it moves into a sidebar. Mark the container (`@container`) and style parts with `@md:` variants or `@container (width >= 28rem)`.

## Diagnosis

| Symptom | Cause | Check |
|---|---|---|
| Wrong theme flashes on reload | theme applied after hydration | served HTML or the `<head>` script sets `data-theme` |
| The default brand shows after login, or until a reload | brand applied in an effect after paint, or only server-rendered | the attribute is set on arrival, stored, and replayed by the `<head>` script |
| Another open tab keeps the old theme or brand | no `storage` listener, or a brand set once and never updated | change it in one tab, watch the other |
| A utility ignores a theme override | `@theme` without `inline`, or a default-palette class | the compiled rule reads `var(--ds-…)` |
| A nested theme keeps the outer colors | an alias such as `--background: var(--ds-bg-base)` declared only on `:root`, where it resolves | the alias's computed value inside the band (declare it on `:root, [data-theme]`) |
| `cn()` drops a size or shadow class | names not registered with the merger, or a bare `cn` import | `cn('text-body-md', 'text-fg-muted')` keeps both |
| No focus indicator in forced colors | box-shadow ring plus `outline-none` | emulate forced colors |
| Native controls stay light in dark mode | no `color-scheme` on the themed element | computed `color-scheme` |
