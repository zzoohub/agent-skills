# Token Pipeline

## When to Set This Up

Worth it with two or more platforms, several themes or brands, or values that change more than monthly; one web app can hand-write its variables. Choose the source of truth first, code by default; if a design tool is the source, verify that composite tokens (typography, shadow) survive a round trip, or the sync quietly forks the system.

## Style Dictionary

Check the Node version the current `style-dictionary` major requires (5.x: Node 22+). Run one build per theme: primitives in `include` (referenced, never emitted), the theme file in `source`, each build emitting its source tokens under its own selector. One `source` glob over both themes makes their keys collide: the last file wins and no dark block is emitted.

```js
// build-tokens.mjs
import StyleDictionary from 'style-dictionary';

// React Native wants numbers: "16px" → 16, "200ms" → 200. Em tracking stays a string (multiply by the font size where used).
const toNumber = {
  type: 'value',
  filter: (t) => /^-?[\d.]+(px|ms)$/.test(t.$value ?? t.value),
  transform: (t) => parseFloat(t.$value ?? t.value),
};
// React Native wants absolute line heights and one family name.
const rnType = {
  type: 'value',
  transitive: true,
  filter: (t) => (t.$type ?? t.type) === 'typography',
  transform: (t) => {
    const v = t.$value ?? t.value;
    const size = parseFloat(v.fontSize) * 16; // rem source
    return { fontFamily: v.fontFamily[0], fontWeight: String(v.fontWeight), fontSize: size, lineHeight: Math.round(size * v.lineHeight) };
  },
};

const builds = [
  { name: 'base', source: 'tokens/semantic.tokens.json', selector: ':root' },
  { name: 'light', source: 'tokens/themes/light.tokens.json', selector: ':root, [data-theme="light"]' },
  { name: 'dark', source: 'tokens/themes/dark.tokens.json', selector: '[data-theme="dark"]' },
];

for (const { name, source, selector } of builds) {
  await new StyleDictionary({
    include: ['tokens/primitive.tokens.json'], // referenced, never emitted
    source: [source],
    hooks: { transforms: { 'size/toNumber': toNumber, 'typography/rn': rnType } },
    platforms: {
      css: {
        transformGroup: 'css',
        prefix: 'ds',
        expand: { include: ['typography'] }, // size, line-height, weight as separate variables
        buildPath: 'src/shared/ui/generated/',
        files: [{ destination: `${name}.css`, format: 'css/variables', filter: (t) => t.isSource, options: { selector } }],
      },
      rn: {
        transforms: ['color/css', 'size/toNumber', 'typography/rn'],
        buildPath: 'src/shared/ui/generated/',
        files: [{ destination: `${name}.js`, format: 'javascript/esm', filter: (t) => t.isSource, options: { minify: true } }],
      },
    },
  }).buildAllPlatforms();
}
```

Paths are defaults (caller may redirect). Run the script before `dev` and `build`; never edit generated files.

## Traps This Config Avoids

- **Alpha colors.** `color/css` has turned `rgb(239 68 68 / 0.15)` into an opaque `#ef4444`. Write `rgba(r, g, b, a)` or a DTCG color object, and check that alpha survives the build.
- **React Native shape.** No built-in group fits: `js` leaves strings (`"16px"`), `react-native` turns sizes into objects. Hence `toNumber`, and `javascript/esm` with `minify: true` for the nested values-only object the theme hook reads (without it, full token objects).
- **Composites.** Built-in transforms don't reach inside composite tokens, hence `rnType`. On the web, `expand` splits typography into the variables Tailwind's `--text-*` triples map; without it, a composite compiles to one `font` shorthand. Tailwind needs no other output.
