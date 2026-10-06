# Token Pipeline

Single source of truth → platform-specific outputs. Define once, transform per platform.

## Table of Contents

1. [Architecture](#architecture)
2. [Style Dictionary Setup](#style-dictionary-setup)
3. [Workflow](#workflow)
4. [Dark Theme Pipeline](#dark-theme-pipeline)
5. [Figma Sync (Optional)](#figma-sync-optional)
6. [Tailwind Config Generation](#tailwind-config-generation)
7. [When to Set This Up](#when-to-set-this-up)

## Architecture

```
tokens/                          ← Source (JSON, W3C DTCG format)
├── primitive.tokens.json
├── semantic.tokens.json
└── themes/
    ├── light.tokens.json
    └── dark.tokens.json
         │
         ▼
   Style Dictionary              ← Transform engine
         │
         ├──→  web/variables.css       (CSS custom properties)
         ├──→  rn/tokens.ts            (TypeScript const object)
         ├──→  web/tailwind.config.js  (optional — legacy JS config: Tailwind v3, or v4 via @config; v4 normally reuses variables.css via @theme)
         └──→  figma/tokens.json       (optional — Figma Variables import)
```

## Style Dictionary Setup

```bash
npm install -D style-dictionary
```

### Config: `style-dictionary.config.mjs`

Style Dictionary v4+ is ESM-only, so write the config as an ES module (`export default`, `.mjs`) and load the package with `import`, not `require()`. The CLI auto-loads only `./config.json` or `./config.js`; pass any other file name with `--config`.

```javascript
export default {
  source: ['tokens/**/*.tokens.json'],
  platforms: {
    web: {
      transformGroup: 'css',
      buildPath: 'src/shared/ui/generated/',
      files: [{
        destination: 'variables.css',
        format: 'css/variables',
        options: { outputReferences: true }, // keeps alias chain readable
      }],
    },
    rn: {
      transformGroup: 'js',
      buildPath: 'src/shared/ui/generated/',
      files: [{
        destination: 'tokens.ts',
        format: 'javascript/es6',
      }],
    },
  },
};
```

### Build

```bash
npx style-dictionary build --config style-dictionary.config.mjs
```

Run this after any token file change. Add to build script:

```json
{
  "scripts": {
    "tokens:build": "style-dictionary build --config style-dictionary.config.mjs",
    "dev": "npm run tokens:build && next dev",
    "build": "npm run tokens:build && next build"
  }
}
```

## Workflow

1. **Edit**: Change value in `semantic.tokens.json`
2. **Build**: `npm run tokens:build`
3. **Result**: CSS variables and TS tokens update automatically
4. **Components**: Already reference variables/tokens — no code changes needed

This means a color change is a one-file edit that propagates everywhere.

## Dark Theme Pipeline

Dark theme is just another token file that overrides semantic values:

```javascript
// Style Dictionary resolves theme overrides
// Input:  semantic.tokens.json + themes/dark.tokens.json
// Output: dark mode CSS variables or TS token overrides
```

For web, generate a separate `[data-theme="dark"]` block.
For RN, generate a dark override object that merges at runtime.

## Figma Sync (Optional)

If using Figma for design, keep tokens in sync:

**Option A: Tokens Studio (Figma plugin)**
- Point plugin at your `tokens/` directory in git
- Push/pull tokens between Figma and code
- Works with Style Dictionary format

**Option B: Manual export**
- Export Figma Variables as JSON
- Transform to DTCG format
- Run Style Dictionary build

Option A is recommended if you iterate frequently in Figma. Option B is fine for code-first workflows where Figma is documentation rather than source of truth.

## Tailwind Config Generation

If using Tailwind, add a pipeline output that generates Tailwind theme config from your tokens. This keeps Tailwind utilities in sync with your design tokens automatically.

For Tailwind v4 (CSS-based), the CSS custom properties output already works — just reference them in `@theme`. No extra pipeline step needed.

For a JS Tailwind config (v3, or v4 loading it via `@config`), register a custom format first — `tailwind/theme` is **not** a built-in Style Dictionary format, so referencing it without registering it fails the build with "format not found":

```javascript
// style-dictionary.config.mjs — ESM (v4+ has no CommonJS entry)
import StyleDictionary from 'style-dictionary';

// Register the custom format BEFORE building
// (or declare it in the config under hooks: { formats: { 'tailwind/theme': fn } }).
StyleDictionary.registerFormat({
  name: 'tailwind/theme',
  format: ({ dictionary }) => {
    const theme = {}; // build a nested theme.extend object from token.path (omitted for brevity)
    for (const token of dictionary.allTokens) {
      // e.g. set theme[token.attributes.category]?.[token.attributes.type] = token.value
    }
    return `module.exports = ${JSON.stringify(theme, null, 2)};`;
  },
});

// ...then reference the registered format from a platform:
platforms: {
  // ...existing platforms...
  tailwind: {
    transformGroup: 'js',
    buildPath: 'src/shared/ui/generated/',
    files: [{
      destination: 'tailwind-tokens.js',
      format: 'tailwind/theme', // the custom format registered above
    }],
  },
}
```

Then import in `tailwind.config.js`:

```javascript
const tokens = require('./src/shared/ui/generated/tailwind-tokens');
module.exports = { theme: { extend: tokens } };
```

This way, a token change flows through the pipeline to update both CSS variables and Tailwind config in one build step.

## When to Set This Up

This pipeline pays off when:
- You have 2+ platform targets (web + RN)
- You change token values more than once a month
- You want dark mode to "just work" from one source

For a single-platform project that rarely changes tokens, directly writing CSS variables or TS tokens is simpler. Don't add infrastructure you don't need yet.
