# Typography

## Families and Weights

- `fontFamily.sans` `["Inter", "system-ui", "sans-serif"]`; `fontFamily.mono` `["JetBrains Mono", "ui-monospace", "Menlo", "monospace"]` (arrays, so tools quote each name).
- `fontWeight` (`$type: fontWeight`): normal 400, medium 500, semibold 600, bold 700.

A brand font replaces Inter without changing the scale. Inter has no CJK glyphs: each shipped language gets its family after Inter (`Pretendard`, `Noto Sans JP`, `Noto Sans SC`) and a looser body line-height (1.5–2.0×, per JLREQ), set per language in the theme layer (`:root:lang(ja) { … }`), never per component. One shared CJK fallback renders Japanese with Chinese glyph forms, or the reverse. CJK fonts carry no true italics; emphasize with weight.

## Scale

| Style | rem (px) | Line height | Weight | Use |
|---|---|---|---|---|
| `display` | 1.875 (30) | 1.2 | bold | hero |
| `heading.lg` | 1.5 (24) | 1.333 | semibold | page title |
| `heading.md` | 1.25 (20) | 1.4 | semibold | section title |
| `heading.sm` | 1 (16) | 1.5 | semibold | card title |
| `body.lg` | 1.125 (18) | 1.556 | normal | long-form |
| `body.md` | 1 (16) | 1.5 | normal | default |
| `body.sm` | 0.875 (14) | 1.429 | normal | secondary |
| `caption` | 0.75 (12) | 1.333 | medium | labels, metadata |
| `code` | 0.875 (14) | 1.429 | normal, mono | code |

Each style is one composite token; rem sizes follow the user's font setting.

```json
{
  "type": {
    "heading": {
      "lg": {
        "$type": "typography",
        "$value": {
          "fontFamily": "{fontFamily.sans}",
          "fontSize": "1.5rem",
          "fontWeight": "{fontWeight.semibold}",
          "lineHeight": 1.333
        }
      }
    }
  }
}
```

Tracking is its own token (`tracking.tight` −0.02em for headings, `tracking.wide` 0.02em for captions): em scales with the size, and strict DTCG allows only px or rem inside a typography composite. React Native receives the em string; multiply it by the style's font size. A new scale picks its ratio by density (about 1.2 for dense apps, 1.25–1.333 for content) and snaps each step to whole pixels at a 16px root; a missing size goes through token admission, never a one-off.

## Fluid Sizes

Only display and heading styles scale with the viewport. The web overrides the generated size after importing it; React Native keeps the token size.

```css
:root { --ds-type-display-font-size: clamp(1.5rem, 1.2rem + 1.5vw, 1.875rem); }
```

Rem bounds follow the user's font setting, and the rem term keeps the middle responsive to zoom, which pure `vw` is not. Keep the maximum at or under 2.5× the minimum so 200% zoom still doubles the text (WCAG 1.4.4).
