---
title: Fix Slow Re-renders by Structure First, Then Memoize
tags: rerender, memo, useMemo, useCallback, context, react-compiler
---

Find the slow commits in the React Profiler (over ~16 ms while typing, scrolling or animating, on the target device) and what re-rendered, then fix in this order:

1. **Compiler on:** confirm the component was compiled (the ✨ badge in React DevTools). A Rules-of-React violation the hooks lint reports, `'use no memo'`, or `compilationMode: 'annotation'` without `'use memo'` leaves it uncompiled: fix that first. Compiled and still slow: read what the slow value's scope is keyed on in the compiled output; a slow scope keyed on a fast-changing input reruns on every change (split it, below).
2. **Move state down** into the components that read it, and pass static subtrees as `children`, so less of the tree re-renders with it.
3. **Split a context by update rate,** or move a fast-changing value into an external store read through a selector: every consumer re-renders when a context value changes, compiled or not.
4. **Memoize by hand** where it prevents real work:
   - compiler off: props passed to a `memo` child, including its non-primitive default props (hoist them to module scope); context provider values; computations of 1 ms or more (time them with `console.time` under CPU throttling);
   - compiler on or off: work a fix must skip ([rerender-use-deferred-value](./rerender-use-deferred-value.md)), and a value whose identity an Effect or an identity-comparing library (charts, maps) depends on.

**Split derivations by input.** One `useMemo`, or a compiled scope that spans both steps, reruns the filter whenever only the sort order changes. Key each step on its own inputs, with the fastest-changing input last:

```tsx
const filtered = useMemo(() => products.filter(p => p.category === category), [products, category])
const sorted = useMemo(() => filtered.toSorted(byPrice(sortOrder)), [filtered, sortOrder])
```

**Incorrect:** `memo(function UserAvatar({ onClick = () => {} }) { ... })`: the default is a new function every render, so `memo` never skips. **Correct:** `const NOOP = () => {}` at module scope, then `onClick = NOOP`.

To skip expensive work behind an early return, move it into a memoized child rather than a `useMemo` above the return:

```tsx
if (loading) return <Skeleton />
return <UserAvatar user={user} />   // memo(UserAvatar) computes the avatar only when it renders
```

Don't subscribe to a value only a handler reads; read it in the handler (`new URLSearchParams(location.search)` rather than a search-params hook).

Sources: https://react.dev/reference/react/useMemo · https://react.dev/learn/react-compiler/introduction · https://react.dev/learn/react-compiler/debugging
