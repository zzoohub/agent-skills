---
title: Use a Transition to Keep the Current UI Interactive During a Heavy Update
tags: rerender, useTransition, startTransition, async
---

A Transition marks an update as non-urgent: React renders it in the background, keeps the current UI interactive and reports `isPending`, which replaces a hand-managed loading flag. Use it after a discrete choice (a tab, a filter, a navigation) whose render or data is slow.

**Incorrect (a manual loading flag; a slow older response can overwrite a newer one):**

```tsx
async function applyFilter(filter: Filter) {
  setIsLoading(true)
  setResults(await fetchResults(filter))
  setIsLoading(false)
}
```

**Correct:**

```tsx
const [isPending, startTransition] = useTransition()
const latest = useRef(0)

function selectTab(next: Tab) {
  startTransition(() => setTab(next))         // the old tab stays interactive while the new one renders
}

function applyFilter(filter: Filter) {
  const request = ++latest.current
  startTransition(async () => {
    const data = await fetchResults(filter).catch(() => null)   // null renders "Couldn't load", not the Error Boundary
    if (request !== latest.current) return                       // a newer filter won
    startTransition(() => setResults(data))                     // updates after an await need their own startTransition
  })
}
```

- A throw or a rejected promise inside it reaches the nearest Error Boundary; return expected failures as state.
- Async Transitions don't guarantee order: drop stale responses as above, or use `useActionState` or a form action, which handle ordering.
- For typed input, use `useDeferredValue` ([rerender-use-deferred-value](./rerender-use-deferred-value.md)); the input itself must stay urgent.
- Never route high-frequency streams through a Transition: `startTransition(() => setScrollY(window.scrollY))` restarts the render on every scroll event, so nothing commits until scrolling stops ([rerender-use-ref-transient-values](./rerender-use-ref-transient-values.md)).

Source: https://react.dev/reference/react/useTransition
