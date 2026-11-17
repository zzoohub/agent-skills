# In-House Code

The guards that hold the system without a reviewer. Copy into the project only what it uses; these are not a package, and none needs a dependency beyond the test runner. Paths are defaults; the caller may redirect them.

## Table of Contents

1. [color.ts](#colorts)
2. [Token test](#token-test)
3. [Literal test](#literal-test)
4. [Import rule](#import-rule)

## color.ts

Contrast math for the token test, and the search a failing brand color needs (`tokens.md` § From a brand color). It reads the formats token files are written in: hex, `rgb()` and `oklch()`. An `oklch()` value outside sRGB is brought in by lowering its chroma; a browser may clip it differently, so write token values sRGB can show.

```ts
// src/shared/lib/color.ts
/** [r, g, b, alpha], each 0–1, in gamma-encoded sRGB */
export type Rgba = [number, number, number, number]

const toLinear = (c: number) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)
const toGamma = (c: number) => (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055)
const clamp = (v: number) => Math.min(1, Math.max(0, v))

const oklchToLinear = (l: number, c: number, h: number) => {
  const a = c * Math.cos((h * Math.PI) / 180)
  const b = c * Math.sin((h * Math.PI) / 180)
  const [l3, m3, s3] = [
    l + 0.3963377774 * a + 0.2158037573 * b,
    l - 0.1055613458 * a - 0.0638541728 * b,
    l - 0.0894841775 * a - 1.291485548 * b,
  ].map((v) => v ** 3) as [number, number, number]
  return [
    4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
    -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
    -0.0041960863 * l3 - 0.7034186147 * m3 + 1.707614701 * s3,
  ]
}

const toOklch = ([r, g, b]: Rgba) => {
  const [lr, lg, lb] = [toLinear(r), toLinear(g), toLinear(b)]
  const [l, m, s] = [
    0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb,
    0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb,
    0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb,
  ].map(Math.cbrt) as [number, number, number]
  const a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s
  const b2 = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s
  return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, Math.hypot(a, b2), (Math.atan2(b2, a) * 180) / Math.PI] as const
}

const fits = (linear: number[]) => linear.every((v) => v >= -1e-4 && v <= 1 + 1e-4)

/** Lightness and hue held, chroma lowered until sRGB can show it */
const fromOklch = (l: number, c: number, h: number): Rgba => {
  let [low, high] = fits(oklchToLinear(l, c, h)) ? [c, c] : [0, c]
  for (let i = 0; i < 20 && low !== high; i++) {
    const mid = (low + high) / 2
    if (fits(oklchToLinear(l, mid, h))) low = mid
    else high = mid
  }
  const [r, g, b] = oklchToLinear(l, low, h).map((v) => toGamma(clamp(v))) as [number, number, number]
  return [r, g, b, 1]
}

const amount = (token = '1', scale = 1) => (token.endsWith('%') ? (parseFloat(token) / 100) * scale : parseFloat(token))

/** Reads '#rgb', '#rrggbb', '#rrggbbaa', 'rgb()', 'rgba()' and 'oklch()' */
export const parseColor = (css: string): Rgba => {
  const value = css.trim().toLowerCase()
  if (value.startsWith('#')) {
    const hex = value.length < 6 ? [...value.slice(1)].map((digit) => digit + digit).join('') : value.slice(1)
    const [r = 0, g = 0, b = 0, a = 255] = (hex.match(/../g) ?? []).map((pair) => parseInt(pair, 16))
    return [r / 255, g / 255, b / 255, a / 255]
  }
  const [, fn, body = ''] = value.match(/^(rgba?|oklch)\((.+)\)$/) ?? []
  const [x, y, z, alpha] = body.split(/[\s,/]+/).filter(Boolean)
  if (fn === 'oklch') {
    const [r, g, b] = fromOklch(amount(x), amount(y, 0.4), parseFloat(z ?? '0'))
    return [r, g, b, amount(alpha)]
  }
  if (fn) return [amount(x, 255) / 255, amount(y, 255) / 255, amount(z, 255) / 255, amount(alpha)]
  throw new Error(`Unsupported color: ${css}`)
}

export const toHex = ([r, g, b]: Rgba) =>
  `#${[r, g, b].map((v) => Math.round(clamp(v) * 255).toString(16).padStart(2, '0')).join('')}`

/** What shows when a translucent color sits on an opaque one */
export const over = ([r, g, b, a]: Rgba, [br, bg, bb]: Rgba): Rgba => [
  r * a + br * (1 - a),
  g * a + bg * (1 - a),
  b * a + bb * (1 - a),
  1,
]

const luminance = ([r, g, b]: Rgba) => 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b)

/** WCAG 2 contrast ratio of `fg` on an opaque `bg`. A translucent `fg` is composited first */
export const contrast = (fg: Rgba, bg: Rgba) => {
  const [a, b] = [luminance(over(fg, bg)), luminance(bg)]
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
}

/** The color nearest `color` in OKLCH lightness, hue held, that reaches `min` against `against` */
export const nearestPassing = (color: Rgba, against: Rgba, min = 4.5) => {
  const [l, c, h] = toOklch(color)
  for (let delta = 0; delta <= 1; delta += 0.0025) {
    for (const lightness of [l - delta, l + delta]) {
      if (lightness < 0 || lightness > 1) continue
      const hex = toHex(fromOklch(lightness, c, h)) // the 8-bit value that ships is the one that must pass
      if (contrast(parseColor(hex), against) >= min) return { hex, deltaL: lightness - l }
    }
  }
  return null
}
```

## Token test

Two properties, per theme: every theme defines every role, and every allowed pair passes. The pair list is the system's contrast contract: a pair that is not in it is not allowed in a component, and a new role enters the system by entering this list.

```ts
// src/shared/ui/tokens.test.ts
import { readFileSync } from 'node:fs'
import { expect, it } from 'vitest' // Jest: drop this line

import { contrast, over, parseColor } from '@/shared/lib/color'

const TEXT = 4.5 // 3 for text at 24px, or 18.66px bold, and up
const SHAPE = 3 // icons, focus rings, an input's only boundary, the cue that marks a state

/** Every pair the system allows: [foreground, the backgrounds it may sit on, minimum]. A pair not listed is not allowed */
const PAIRS: [string, string[], number][] = [
  ['fg-default', ['bg-base', 'bg-raised', 'bg-subtle', 'bg-danger-subtle'], TEXT],
  ['fg-muted', ['bg-base', 'bg-raised'], TEXT], // never on bg-subtle: it fails there
  ['fg-link', ['bg-base', 'bg-raised'], TEXT],
  ['fg-danger', ['bg-base', 'bg-raised', 'bg-danger-subtle'], TEXT],
  ['fg-on-accent', ['bg-accent', 'bg-accent-hover'], TEXT],
  ['fg-on-danger', ['bg-danger', 'bg-danger-hover'], TEXT],
  ['border-input', ['bg-base', 'bg-raised'], SHAPE],
  ['border-danger', ['bg-base', 'bg-raised'], SHAPE],
  ['border-focus', ['bg-base', 'bg-raised'], SHAPE],
  ['bg-accent', ['bg-base', 'bg-raised'], SHAPE], // a fill must stand out from its surface, or the button reads as an outline
  ['bg-danger', ['bg-base', 'bg-raised'], SHAPE],
]
/** What a translucent background is composited over before it is measured */
const SURFACES = ['bg-base', 'bg-raised']

/** The token file, plus each scoped theme file the app adds */
const SOURCES = ['./tokens.css']

const css = SOURCES.map((file) => readFileSync(new URL(file, import.meta.url), 'utf-8')).join('\n')
const themes = Object.fromEntries(
  [...css.matchAll(/\[data-theme=['"](\w+)['"]\]\s*\{([^}]*)\}/g)].map(([, name = '', block = '']) => [
    name,
    Object.fromEntries([...block.matchAll(/--ds-([\w-]+):\s*([^;]+);/g)].map(([, role = '', value = '']) => [role, value])),
  ]),
)

it('every theme defines every role', () => {
  const [first = [], ...rest] = Object.values(themes).map((roles) => Object.keys(roles).sort())
  rest.forEach((roles) => expect(roles).toEqual(first))
})

it.each(Object.keys(themes))('every allowed pair passes in the %s theme', (theme) => {
  const color = (role: string) => {
    const value = themes[theme]?.[role]
    if (!value) throw new Error(`${theme} has no --ds-${role}`)
    return parseColor(value)
  }
  const failures = PAIRS.flatMap(([fg, backgrounds, min]) =>
    backgrounds.flatMap((bg) => {
      const fill = color(bg)
      const opaque = fill[3] < 1 ? SURFACES.map((surface) => over(fill, color(surface))) : [fill]
      const ratio = Math.min(...opaque.map((background) => contrast(color(fg), background)))
      return ratio < min ? [`${fg} on ${bg}: ${ratio.toFixed(2)} < ${min}`] : []
    }),
  )
  expect(failures).toEqual([])
})
```

- **The list is the example system's.** Keep the rows whose roles the product has, and add a row with each new role.
- **Themes are discovered,** so a theme block added to a source is tested without touching the test. Add each scoped theme file to `SOURCES`.
- **A translucent background** is laid over each surface first and the worst result counts, because an alpha fill changes with what is under it.
- **Shown to fail:** a white `fg.onAccent` in the dark theme fails at 3.68:1, a role deleted from one theme fails the first test, and a stronger dark tint under `fg.danger` fails at 2.47:1.
- **Other vocabularies** change only the names and the block pattern: a shadcn repo reads `:root` and `.dark`, and its pairs are `primary-foreground` on `primary`, `muted-foreground` on `background` and `card`, and so on. React Native reads theme objects (`react-native.md`).

## Literal test

A count per kind of bypass that only goes down. The closed vocabulary already stops `bg-red-500`; this catches what still compiles (arbitrary values, inline styles, `z-50`, alpha fills, `dark:`) and, in a repo that has no closed vocabulary yet, everything.

```ts
// src/test/literals.test.ts
import { readdirSync, readFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { expect, it } from 'vitest' // Jest: drop this line

const SRC = resolve('src')
/** Files that only define tokens: values belong there. Scoped theme files (*.theme.css) count too */
const TOKEN_SOURCES = ['shared/ui/tokens.css', 'shared/ui/theme.ts']

/** What one line can hold in place of a token. A line marked `token-exempt: reason` is skipped */
const KINDS = {
  color: /(?<![&\w])#(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})(?![\w-])|(?<![a-z])(?:rgba?|hsla?|oklch|oklab|lab|lch)\(/gi,
  palette: /\b(?:bg|text|border|ring|outline|fill|stroke|shadow|from|via|to|divide|placeholder|caret|accent|decoration)-(?:[a-z]+-(?:50|[1-9]00|950)|white|black)\b/g,
  arbitrary: /\b[a-z][a-z-]*-\[-?\d*\.?\d+[a-z%]*\]/g, // text-[13px], w-[327px], z-[60]
  layer: /\bz-\d+\b/g,
  alpha: /\b(?:bg|text|border|outline|ring|fill|stroke)-[a-z][a-z-]*\/\d+\b/g, // bg-accent/90: a fill no pair was gated for
  dark: /\bdark:/g, // the theme block remaps roles; a dark: utility bypasses it
  style: /\b(?:font-?size|line-?height|letter-?spacing|border-?radius|z-?index|gap|padding[\w-]*|margin[\w-]*)\s*:\s*['"]?-?[1-9]/gi,
}
type Kind = keyof typeof KINDS

/** Today's count per kind: run the test once and copy what it reports. It only goes down, in the change that removes a literal */
const BASELINE: Record<Kind, number> = { color: 0, palette: 0, arbitrary: 0, layer: 0, alpha: 0, dark: 0, style: 0 }

const isTokenSource = (path: string) =>
  path.endsWith('.theme.css') || TOKEN_SOURCES.some((source) => path.replaceAll('\\', '/').endsWith(source))

const sourceFiles = (dir: string): string[] =>
  readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) return sourceFiles(path)
    return /\.(tsx?|css)$/.test(entry.name) && !/\.(test|spec)\./.test(entry.name) && !isTokenSource(path) ? [path] : []
  })

const isCode = (line: string) => !/^\s*(\/\/|\/\*|\*)/.test(line) && !line.includes('token-exempt:')

const lines = sourceFiles(SRC).flatMap((file) => readFileSync(file, 'utf-8').split('\n').filter(isCode))
const found = (kind: Kind) => lines.flatMap((line) => line.match(KINDS[kind]) ?? [])
const kinds = Object.keys(KINDS) as Kind[]

it('no literal is added outside the token sources', () => {
  expect(Object.fromEntries(kinds.map((kind) => [kind, found(kind).length]))).toEqual(BASELINE)
})

// A refresh or an audit starts from the spread: how many different values stand where one scale should
// console.table(Object.fromEntries(kinds.map((kind) => [kind, new Set(found(kind)).size])))
```

- **A brownfield repo starts at today's counts.** Run the test once before your own change and copy what it reports into `BASELINE`; each cleanup then lowers them in the same change. `toEqual` fails in both directions on purpose: a count that drops without the baseline following leaves room for the next literal.
- **`TOKEN_SOURCES`** lists the repo's own token files, wherever they live.
- **Read a sample before trusting a number.** A file of definitions missing from that list inflates `color`; vendored or generated CSS does too. Comment lines are skipped, so an issue number is not a color.
- **`arbitrary` counts one bare number** (`text-[13px]`, `w-[327px]`), not layout math (`grid-cols-[auto_1fr]`, `w-[calc(100%-2rem)]`).
- **`token-exempt: reason`** on the line is the way to keep a real one-off: a brand's fixed logo color, a third party's required style.
- **The distinct count is where a refresh starts.** A product with eighty font sizes needs seven before it needs a new look.

## Import rule

App code takes UI from the system, and only the system imports the headless library, so its behavior and its look change in one place. The rule is ESLint's own; list the libraries the repo uses.

```js
// eslint.config.mjs (shape)
{
  files: ['src/**'],
  ignores: ['src/shared/ui/**'],
  rules: {
    'no-restricted-imports': [
      'error',
      { patterns: [{ group: ['@base-ui/*', 'radix-ui', '@radix-ui/*', 'react-aria-components'], message: 'Import UI from @/shared/ui.' }] },
    ],
  },
},
```

On React Native, restrict the primitives the system wraps the same way, by name (`paths: [{ name: 'react-native', importNames: ['Pressable', 'TextInput'] }]`).
