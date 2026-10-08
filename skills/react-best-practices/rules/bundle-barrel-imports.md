---
title: Fix Barrel Imports Where the Analyzer Shows Unused Modules
tags: bundle, imports, barrel-files, tree-shaking
---

A barrel file (an `index.js` of `export * from './x'`) makes the bundler, or Node for unbundled server dependencies, load every re-exported module unless it can prove them unused and side-effect free. Icon and component libraries re-export thousands of modules; the cost lands on dev boot, HMR, builds and server cold starts more often than on client bytes. Act when the analyzer or a dev-boot profile shows it.

**Next.js:** `optimizePackageImports` rewrites barrel imports into direct ones at build time, and Next already applies it to a default list of common icon, UI and utility libraries (`lucide-react`, `@mui/material`, `date-fns`, `lodash-es` and more). Don't repeat those (check the current list in the docs); add only other true re-export barrels. The option is still under `experimental`.

```js
// next.config.js
module.exports = { experimental: { optimizePackageImports: ['my-icon-kit'] } }
```

**Elsewhere:** import from the package's subpath, such as `import Button from '@mui/material/Button'`.

- Some libraries (notably `lucide-react`) ship no type declarations for deep import paths, so a deep import is an implicit `any` under `strict`. Prefer the framework option, or check that the package exports types for its subpaths.
- CommonJS `lodash` is not a barrel: its entry is one monolithic file that `optimizePackageImports` can't split. Use per-method imports (`lodash/debounce`), `lodash-es`, or a native equivalent.

Source: https://nextjs.org/docs/app/api-reference/config/next-config-js/optimizePackageImports
