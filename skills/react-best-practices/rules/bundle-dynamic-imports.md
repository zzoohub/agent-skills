---
title: Cut First-Load JS by Moving Code to the Server, Then Lazy-Loading Heavy Dependencies
tags: bundle, code-splitting, react-lazy, next-dynamic, preload
---

JavaScript the first view doesn't need delays LCP and hydration and adds main-thread work (TBT in the lab, INP in the field). Routers already split by route; for heavy code inside a route, read the route's first-load JS in the bundle analyzer, then in this order:

1. Move non-interactive code to the server: a Server Component, or a loader that returns results instead of shipping the library that computes them.
2. Lazy-load heavy dependencies the first view doesn't use (editors, charts, maps), preloading on intent: `pointerdown` and `focus`, since touch has no hover.
3. Replace bloated dependencies with lighter ones or the platform.
4. Fix barrels only where the analyzer shows unused modules ([bundle-barrel-imports](./bundle-barrel-imports.md)).

**Incorrect:** a static `import CodeEditor from './code-editor'` in a panel few users open.

**Correct:**

```tsx
const CodeEditor = lazy(() => import('./code-editor'))   // needs a default export
const preload = () => { import('./code-editor').catch(() => {}) }   // lazy() reuses the request

function CodePanel({ code }: { code: string }) {
  const [open, setOpen] = useState(false)
  if (!open) return <button onPointerDown={preload} onFocus={preload} onClick={() => setOpen(true)}>Edit</button>
  return <Suspense fallback={<EditorSkeleton />}><CodeEditor value={code} /></Suspense>
}
```

In Next.js, `next/dynamic` works the same way; pass `{ ssr: false }` only from a `'use client'` file, since it throws in a Server Component.

A `typeof window` check inside `useEffect` or a handler does nothing, because those never run on the server; don't count on bundlers stripping such branches either.

*Break:* code most users need at their first interaction stays in the initial load, or is preloaded right after it.

Source: https://nextjs.org/docs/app/guides/lazy-loading
