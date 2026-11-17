# Tokens

The role map, how a brand color enters it, the scales beside color, and the scopes a theme can take. Values are in `examples.md`'s token file and ratios come from the token test (`lib.md`); neither is restated here.

## Table of Contents

1. [Color roles](#color-roles)
2. [Traps the pairs avoid](#traps-the-pairs-avoid)
3. [From a brand color](#from-a-brand-color)
4. [Other scales](#other-scales)
5. [Type](#type)
6. [Scopes beyond light and dark](#scopes-beyond-light-and-dark)

## Color roles

Three categories, and a utility or style property takes roles from one of them only.

| Role | For |
|---|---|
| `bg.base` | The page |
| `bg.raised` | Cards, popovers, dialogs, inputs. In a dark theme it is lighter than the page, and that carries elevation |
| `bg.subtle` | Hover and pressed surfaces, wells. `fg.muted` fails on it |
| `bg.accent`, `bg.accentHover` | The primary action's fill; the same fill under the pointer or a press |
| `bg.danger`, `bg.dangerHover`, `bg.dangerSubtle` | The destructive fill; a tint behind danger text |
| `bg.overlay` | The scrim behind a dialog. Not part of any pair |
| `fg.default`, `fg.muted` | Body text; secondary text and placeholders |
| `fg.link` | Links in running text, underlined |
| `fg.danger` | Error text and icons, on a surface or on `bg.dangerSubtle` |
| `fg.onAccent`, `fg.onDanger` | Text and icons on the fill each is named for, and nowhere else |
| `border.default` | Dividers. About 1.2:1, so never the only boundary of an input |
| `border.input`, `border.danger` | A control's boundary, at 3:1 |
| `border.focus` | The focus outline |

Success and warning take danger's shape when the product needs them: a fill, its on-color, a subtle tint and a text color. A role with no consumer is not added.

## Traps the pairs avoid

- **A dark theme's fills get lighter, so their on-colors get darker.** White on the dark accent fill is 3.68:1; near-black is 5.47:1. A navy brand color kept exact as a dark-mode fill sits at 1.42:1 against the raised surface and reads as an outline.
- **A fill is not a text color.** The accent fill used as link text is 3.99:1 on the dark raised surface, and the danger fill as error text is 3.90:1. `fg.link` and `fg.danger` exist for this, and the typed bridge keeps the fill out of `text-`.
- **Hover and pressed states are pairs.** `hover:bg-accent/90` puts white text on a lighter fill at about 4.3:1; at `/80` it is 3.6:1. The hover token was gated; the alpha was not.
- **Translucent fills change with what is under them.** The dark danger tint is 15% red: the test lays it over each surface before measuring. Ship the composited opaque value when a tint must sit on something unknown.
- **`fg.muted` passes on the page and on raised surfaces only.** On `bg.subtle` it is 4.39:1 in light and 4.06:1 in dark.

## From a brand color

A supplied value is a requirement, not a seed.

1. **Test the exact value per role and per theme first.** As a fill, either white or black always passes on it: their two ratios multiply to 21, so the better one is at least 4.58:1. In a dark theme the fill also needs 3:1 against the surfaces it sits on. As text, a ring or an icon, test it against every surface.
2. **A failing role takes the smallest lightness shift that passes,** hue held and chroma lowered only to stay displayable: `nearestPassing(color, against, min)` in `lib.md`. Search for it; never take the next step of a ramp. Among mid-tone brand fills under white text, those at 3.5–4.5:1 pass after a shift of 0.003–0.06 in OKLCH lightness, which most eyes read as the same color. Those at 2.1–2.8:1 need 0.12–0.2, a different color, and there the exact fill with a dark on-color is the smaller change.
3. **Ship the smaller change as provisional, and put the choice to the owner.** A brand usually arrives as two requirements, a color and the text on it, and when the pair fails one of them has to give. Three options keep the pair legal: the shifted fill under the requested text; the exact fill under the other on-color (black passes wherever white fails); the exact pair kept for large text only (3:1 from 24px, or 18.66px bold). Ship the one that changes least on screen, mark it provisional in the token file, and report it first: role, theme, old → new value, the change in lightness, the ratio, and the options not taken. If the brand's rules forbid altered values, the exact fill under the other on-color is the default. For a text, ring or edge role the option that alters nothing is a neutral one: links in `fg.default` and underlined, a neutral focus ring, a 3:1 edge around the exact fill.

Hover, pressed and subtle tones come from a ramp around the brand value, built in OKLCH with one lightness target per step across hues so that a step's pairs nearly hold in every hue. The brand's exact value stays one of the steps, unchanged. A brand fill never doubles as a status fill: a red brand is not `danger`.

## Other scales

These keep the engine's names. The system's part is choosing which steps the product uses, and keeping literals out.

- **Space,** on a 4px grid: steps 1–6 (4–24px) inside a group, 4–16 (16–64px) between groups. A gap inside a component is never larger than the gap around it.
- **Radius:** one step per kind of component (controls, cards, dialogs), `full` for pills and avatars.
- **Elevation:** one shadow step per layer (card, dropdown, dialog, toast). Shadows mark layers, never emphasis, and nearly vanish in a dark theme, where the raised surface does the work.
- **Opacity:** disabled is 0.5. Nothing else fades text, because only disabled controls are exempt from contrast.
- **Layers:** named, not numbered: sticky 200, overlay 300, modal 400, toast 500. They order portals and in-flow elements only. A native modal `<dialog>` or a `popover` renders in the top layer, above every z-index, so keep all overlays in one system: a z-indexed toast shows beneath a top-layer dialog, and inert.
- **Targets:** 24×24 CSS px for a pointer; 44pt (iOS) or 48dp (Android) under a finger. A small icon keeps its drawn size and gains the rest as padding or `hitSlop`.

## Type

- **A scale is a ratio snapped to whole pixels:** about 1.2 for dense apps, 1.25–1.333 for content. Seven steps cover most products. A size the scale lacks goes through token admission, never `text-[13px]`.
- **Sizes are in `rem`,** so the user's font setting scales them. Each size carries its own line height: tight for display sizes (1.2), about 1.5 for body.
- **Tracking is its own value, in `em`:** slightly negative for headings, slightly positive for small caps and captions.
- **Fluid sizes are for display and headings only.** `clamp(1.5rem, 1.2rem + 1.5vw, 1.875rem)` keeps a `rem` term in the middle so zoom still works; keep the maximum within 2.5× the minimum, or 200% zoom no longer doubles the text.
- **Inputs are at least 16px on touch devices,** or iOS zooms the page on focus.
- **Each script gets its own family and line height,** set per language in the token layer (`:root:lang(ja) { … }`), never per component. A Latin font has no CJK glyphs, so each shipped language names its family after it (Pretendard, Noto Sans JP, Noto Sans SC); one shared CJK fallback draws Japanese with Chinese glyph forms, or the reverse. CJK body text wants a looser line height (1.5–2.0), and CJK fonts have no true italics: emphasize with weight.

## Scopes beyond light and dark

A theme is a block of roles on an attribute, so anything that changes the look of a region is one.

**An inverted band** (a dark footer, a highlighted plan) is `data-theme` on that element. Every primitive inside follows, with no extra class on any of them.

**An art-directed page** (a campaign, a product with its own identity) is a theme of its own. It defines every role, so the system's primitives take the page's look and its pairs are tested like any other theme's. What only that page uses is a variable in the same block, not a new role:

```css
/* src/screens/summer-sale/ui/summer-sale.theme.css (shape) */
[data-theme='summer-sale'] {
  color-scheme: light;
  --ds-bg-base: #fff7ed;
  --ds-bg-accent: #c2410c;
  --ds-fg-on-accent: #ffffff;
  /* …every other role */
  --sale-sunburst: #fdba74; /* this page's alone: used as bg-(--sale-sunburst) */
}
```

The file sits with its screen, imports there, and is a token source: add it to the token test's `SOURCES`, and the literal test already skips `*.theme.css`. A page with one odd value does not need a theme; that is a `token-exempt` line.

**A brand or tenant** is a second attribute, `data-brand`, with one block per brand × theme, and the full pair list runs for each. Render the attribute from the server when the tenant is known from the request. A brand that arrives later (after login, from remote config) is set once on arrival and stored, so the first-paint script replays it; clear it at logout, or a shared device shows the last tenant's brand on the login page. Brand surfaces outside the token file follow the theme or are listed as not following: favicon, `theme-color`, the manifest, splash and status bar, emails, charts and canvas, SVG logos, third-party widgets.

**Density** remaps spacing on `data-density`. Targets never shrink below the floor.
