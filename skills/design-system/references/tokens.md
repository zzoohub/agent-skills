# Tokens

The example system. Hex values are placeholders (Tailwind v3 steps): swap in the brand's, then recompute every ratio.

## Format and Files

Token files are DTCG-style JSON (`$type`, `$value`, `{group.token}` references, CSS-string values, arrays for `cubicBezier` and `fontFamily`). DTCG 2025.10 is a W3C Community Group report, not a W3C standard; convert to its strict object forms only for a tool that enforces them. Write alpha as `rgba(r, g, b, a)` (`pipeline.md`).

Files live in the repo's UI folder (default `src/shared/ui/tokens/`, or a shared package once two or more apps consume them; caller may redirect):

```
tokens/
├── primitive.tokens.json   # raw scales; referenced, never emitted
├── semantic.tokens.json    # theme-independent: space, size, radius, opacity, type, motion, z-index
└── themes/
    ├── light.tokens.json   # every themed key: bg, fg, border, elevation
    └── dark.tokens.json    # the same keys, remapped
```

`themes/light.tokens.json` (excerpt; dark maps the same keys):

```json
{
  "bg": { "accent": { "$type": "color", "$value": "{color.blue.600}" } },
  "fg": { "onAccent": { "$type": "color", "$value": "{color.white}" } }
}
```

## Palette

| Hue | Steps |
|---|---|
| gray | 50 `#f9fafb`, 100 `#f3f4f6`, 200 `#e5e7eb`, 400 `#9ca3af`, 500 `#6b7280`, 700 `#374151`, 800 `#1f2937`, 900 `#111827`, 950 `#030712` |
| blue | 400 `#60a5fa`, 500 `#3b82f6`, 600 `#2563eb`, 700 `#1d4ed8` |
| red | 50 `#fef2f2`, 400 `#f87171`, 500 `#ef4444`, 600 `#dc2626`, 700 `#b91c1c` |
| amber | 50 `#fffbeb`, 400 `#fbbf24`, 500 `#f59e0b`, 700 `#b45309` |
| green | 50 `#f0fdf4`, 400 `#4ade80`, 500 `#22c55e`, 700 `#15803d` |

Plus `white` `#ffffff`.

**From a supplied brand color** (a requirement: SKILL.md § Theming):
1. The exact hex becomes, unchanged, the step nearest its OKLCH lightness. Build the other steps in OKLCH with one lightness target per step across hues, so a step's pairs nearly hold in every hue; lower chroma where a step leaves sRGB, and re-space only the brand's neighbors if they crowd it.
2. Test the exact value per role and mode first. As a fill: against pure white and pure black (one always passes 4.5:1; a near-black on-token such as `gray.950` can miss, at worst 4.49:1) and, in dark mode, against `bg.base` and `bg.raised` (≥3:1). As text, a ring or an icon: against every surface it sits on.
3. A failing role takes the smallest OKLCH lightness shift that passes, hue held, chroma lowered only to stay in gamut. Search for it; never take the next step. Measured on Tailwind v3's 500 fills against white: those at 3.6–4.5:1 pass after a ΔL of 0.003–0.055, while the next step sits 0.06–0.08 away; those at 2.1–2.8:1 need 0.12–0.2, a different color, so the exact fill with a dark on-color is the smaller change. A dark-mode fill searches against `bg.raised` with `min` 3, then re-picks its on-color.

A design-time helper, run where culori is installed or can be a dev dependency; code that derives themes at runtime (on a server or device) ports the conversions it uses (OKLCH ↔ sRGB, chroma clamp, WCAG luminance) rather than add a dependency.

```js
import { clampChroma, converter, formatHex, wcagContrast } from 'culori';
const toOklch = converter('oklch');

// The color nearest `hex` in OKLCH lightness, hue held, that reaches `min` against `against`.
export function smallestPassingShift(hex, against, min = 4.5) {
  const base = toOklch(hex);
  for (let d = 0; d <= 1; d += 0.0025) {
    for (const l of [base.l - d, base.l + d]) {
      if (l < 0 || l > 1) continue;
      const candidate = formatHex(clampChroma({ ...base, l }, 'oklch'));
      if (wcagContrast(candidate, against) >= min) return { hex: candidate, deltaL: l - base.l };
    }
  }
  return null; // nothing reaches `min` against this surface
}
```

Report each shift as role, mode, old → new hex, ΔL and ratio, beside its neutral fallback, which never alters a supplied value: links in `fg.default`, underlined; a neutral focus ring; a ≥3:1 edge around the exact fill. The owner decides (SKILL.md § Theming).

## Allowed Pairs

The complete semantic color map; a pair not listed is not allowed. Ratios are WCAG 2 contrast on the worst listed surface.

| Pair (fg / bg) | Light | Dark | Worst, light / dark |
|---|---|---|---|
| `fg.default` / `bg.base`, `bg.raised`, `bg.subtle`, any `bg.{status}Subtle` | gray.900 on gray.50, white, gray.100 | gray.50 on gray.900, gray.800, gray.700 | 16.1 / 9.86 |
| `fg.muted` / `bg.base`, `bg.raised` (never `bg.subtle`: 4.39 / 4.06) | gray.500 | gray.400 | 4.63 / 5.78 |
| `fg.accent` (links) / `bg.base`, `bg.raised` | blue.600 | blue.400 | 4.95 / 5.77 |
| `fg.onAccent` / `bg.accent`, `bg.accentHover` | white on blue.600, blue.700 | gray.950 on blue.500, blue.400 | 5.17 / 5.47 |
| `fg.onDanger` / `bg.danger`, `bg.dangerHover` | white on red.600, red.700 | gray.950 on red.500, red.400 | 4.83 / 5.35 |
| `fg.onWarning` / `bg.warning` | gray.950 on amber.500 | the same | 9.37 / 9.37 |
| `fg.{status}Strong` / its `bg.{status}Subtle`, `bg.base`, `bg.raised` | `.700`; subtle fill `.50` | `.400`; subtle fill `.500` at 15% alpha | red 5.91 / 4.63, amber 4.81 / 6.69, green 4.79 / 6.48 |
| `border.input` / `bg.base`, `bg.raised` | gray.500 | gray.500 | 4.63 / 3.04 |
| `border.focus` / `bg.base`, `bg.raised` | blue.500 | blue.400 | 3.52 / 5.77 |

Not pairs: `bg.overlay` (scrim) `rgba(0, 0, 0, 0.5)` / `rgba(0, 0, 0, 0.7)`; `border.default` gray.200 / gray.700, for decorative dividers only, never an input's only boundary (1.18:1).

Traps the table already avoids:
- **Alpha fills change with what sits under them.** Gate them on every surface they can sit on (the dark status tints were), or ship the composited opaque value.
- **Dark fills get lighter, so dark on-tokens get darker.** The dark accent fill, blue.500, is 3.99:1 on `bg.raised`; a navy brand kept exact there (blue.900) is 1.42:1 and reads as an outline. White on blue.500 is 3.68:1; `gray.950` is 5.47:1.
- **Hover and pressed fills are pairs too.** An opacity hover such as `bg-accent/90` lightens the fill under white text to 4.32:1; use the hover token.

## Other Scales

- **Space** (semantic, 4px grid): `space.component` xs 4, sm 8, md 12, lg 16, xl 24; `space.layout` xs 16, sm 24, md 32, lg 48, xl 64.
- **Touch target:** `size.touchTarget` 48, which meets Android's 48dp and iOS's 44pt.
- **Radius:** none 0, sm 4, md 8, lg 12, xl 16, 2xl 24, full 9999.
- **Elevation** (semantic shadows): `elevation.card`, `.dropdown`, `.modal`, `.toast` are the Tailwind v3 shadow steps sm, md, lg, xl; dark raises their alpha to 0.2–0.4, but `bg.raised` carries the dark elevation cue.
- **Opacity:** `opacity.disabled` 0.5; disabled controls are contrast-exempt, so nothing else may fade text.
- **z-index** (in-flow and portal layers only; the top layer ignores it): base 0, dropdown 100 (in-flow, never portaled), sticky 200, overlay 300, modal 400, popover 450, toast 500.
- **Component tokens** (tier 3), only for a deliberate deviation or a white-label styling API: `button.radius` → `{radius.md}`, `button.paddingX.md` → `{space.component.lg}`. Version them like props.
