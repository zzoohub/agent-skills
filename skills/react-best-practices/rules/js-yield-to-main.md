---
title: Yield to the Main Thread After the Visible Update
tags: javascript, inp, long-tasks, scheduling, layout
---

INP measures from an input to the next paint. Work that runs before the browser can paint delays the user's feedback, and any task over 50 ms blocks input.

- Make the visible update first, then yield before non-urgent work: `scheduler.yield()` where it exists, else `setTimeout`. Neither `scheduler.yield()` nor `requestIdleCallback` is Baseline, so feature-detect both.
- Split long loops into chunks of about 50 ms (check `performance.now()` against a deadline), yielding between them.
- Run background work (analytics, prefetching, cache writes) through an idle shim.
- In DOM code, do the layout reads (`offsetWidth`, `getBoundingClientRect()`) before the writes: the browser batches consecutive style writes, but each read between writes forces a synchronous layout.

**Incorrect (the results paint only after storage and analytics finish):**

```ts
function handleSearch(query: string) {
  setResults(searchItems(query))
  saveRecentSearch(query)
  analytics.track('search', { query })
}
```

**Correct:**

```ts
const yieldToMain = (): Promise<void> =>
  globalThis.scheduler?.yield?.() ?? new Promise(resolve => setTimeout(resolve, 0))

const onIdle = globalThis.requestIdleCallback ?? ((cb: IdleRequestCallback) =>
  setTimeout(() => {
    const start = Date.now()
    cb({ didTimeout: false, timeRemaining: () => Math.max(0, 50 - (Date.now() - start)) })
  }, 1))

async function handleSearch(query: string) {
  setResults(searchItems(query))   // the visible update first
  await yieldToMain()              // let the browser paint
  saveRecentSearch(query)
  onIdle(() => analytics.track('search', { query }))
}
```

Sources: https://web.dev/articles/inp · https://developer.chrome.com/blog/use-scheduler-yield · https://caniuse.com/requestidlecallback
