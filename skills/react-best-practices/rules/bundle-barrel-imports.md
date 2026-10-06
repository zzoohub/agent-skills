---
title: Avoid Barrel File Imports
impact: CRITICAL
impactDescription: 200-800ms import cost, slow builds
tags: bundle, imports, tree-shaking, barrel-files, performance
---

## Avoid Barrel File Imports

Import directly from source files instead of barrel files to avoid loading thousands of unused modules. **Barrel files** are entry points that re-export multiple modules (e.g., `index.js` that does `export * from './module'`).

Popular icon and component libraries can have **up to 10,000 re-exports** in their entry file. For many React packages, **it takes 200-800ms just to import them**, affecting both development speed and production cold starts. (Figures in this rule are from Vercel's October 2023 measurements of unoptimized imports; re-measure for your own stack.)

**Why tree-shaking doesn't help:** When a library is marked as external (not bundled), the bundler can't optimize it. If you bundle it to enable tree-shaking, builds become substantially slower analyzing the entire module graph.

**Incorrect (imports entire library, when nothing optimizes the barrel):**

```tsx
import { Check, X, Menu } from 'lucide-react'
// Loads 1,583 modules, takes ~2.8s extra in dev
// Runtime cost: 200-800ms on every cold start

import { Button, TextField } from '@mui/material'
// Loads 2,225 modules, takes ~4.2s extra in dev
```

**Correct - Next.js (`optimizePackageImports`):**

Next.js already optimizes a built-in default list of popular barrel packages — including `lucide-react`, `@mui/material`, `@mui/icons-material`, `@tabler/icons-react`, `react-icons/*`, `@headlessui/react`, `date-fns`, `lodash-es`, `ramda`, `rxjs` and `react-use` — so do not list those yourself (check the current default list in the Next.js `optimizePackageImports` docs). Add only other true re-export barrels; the option is still under `experimental` (as of Next.js 16):

```js
// next.config.js - optimizes barrel imports of the listed packages at build time
module.exports = {
  experimental: {
    optimizePackageImports: ['my-icon-kit']
  }
}
```

```tsx
// Keep the standard imports - Next.js transforms them to direct imports
import { Check, X, Menu } from 'lucide-react'
// Full TypeScript support, no manual path wrangling
```

When available, this is the preferred approach because it preserves TypeScript type safety and editor autocompletion while still eliminating the barrel import cost.

**Correct - Direct imports (non-Next.js projects):**

```tsx
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
// Loads only what you use
```

> **TypeScript warning:** Some libraries (notably `lucide-react`) don't ship `.d.ts` files for their deep import paths. Importing from `lucide-react/dist/esm/icons/check` resolves to an implicit `any` type, causing errors under `strict` or `noImplicitAny`. Prefer `optimizePackageImports` when available, or verify the library exports types for its subpaths before using direct imports.

In Vercel's October 2023 measurements, these optimizations gave 15-70% faster dev boot, 28% faster builds, 40% faster cold starts, and significantly faster HMR.

Libraries commonly affected: `lucide-react`, `@mui/material`, `@mui/icons-material`, `@tabler/icons-react`, `react-icons`, `@headlessui/react`, `@radix-ui/react-*`, `ramda`, `date-fns`, `rxjs`, `react-use`.

> **CommonJS `lodash` is not a barrel:** its entry is one monolithic file that `optimizePackageImports` cannot split. Use per-method subpath imports (`import debounce from 'lodash/debounce'`), `lodash-es`, or a native equivalent.
