---
title: Keep Import and File Paths Statically Analyzable
tags: bundle, dynamic-import, file-tracing
---

Bundlers and file tracers decide what to include from the paths they can read at build time. A path hidden in a variable makes them include a broad set of files, warn, or fail: bigger server bundles, slower builds, worse cold starts.

**Incorrect (the bundler can't tell what may be imported):**

```ts
const PAGES = { home: './pages/home', settings: './pages/settings' } as const
const Page = await import(PAGES[pageName])
```

**Correct (an explicit map of allowed modules):**

```ts
const PAGES = {
  home: () => import('./pages/home'),
  settings: () => import('./pages/settings'),
} as const
if (!Object.hasOwn(PAGES, pageName)) throw notFound()   // `in` would also match 'toString'
const Page = await PAGES[pageName as keyof typeof PAGES]()
```

**Incorrect (even a two-value variable hides the final file path):**

```ts
const baseDir = path.join(process.cwd(), 'content/' + contentKind)
```

**Correct (each final path is a literal at the call site):**

```ts
const baseDir = contentKind === 'blog'
  ? path.join(process.cwd(), 'content/blog')
  : path.join(process.cwd(), 'content/docs')
```

Next's output file tracing reads `import`, `require` and `fs` calls the same way to decide which files ship with each route.

References: [Next.js output](https://nextjs.org/docs/app/api-reference/config/next-config-js/output) · [Next.js lazy loading](https://nextjs.org/docs/app/guides/lazy-loading)
