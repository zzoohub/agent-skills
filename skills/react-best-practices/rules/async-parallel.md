---
title: Start Independent Work Together and Join Every Promise
tags: async, parallelization, promises, waterfalls
---

Awaiting independent calls one after another makes latency the sum of the calls; starting them together makes it the slowest one. Confirm with Server-Timing or a trace.

Join every promise you start in one `Promise.all` in the same tick, chain partial dependencies with `.then` inside it, bound the fan-out over lists ([server-parallel-fetching](./server-parallel-fetching.md)), and reset a module-level promise when it rejects ([server-hoist-static-io](./server-hoist-static-io.md)). A promise started early and awaited after another `await` has no rejection handler in between: if it rejects then, Node reports an unhandled rejection, which by default crashes the process.

**Incorrect (sequential; then started early and awaited late):**

```ts
const user = await fetchUser()
const config = await fetchConfig()            // waits for fetchUser for no reason

const sessionP = auth()
const configP = fetchConfig()
const session = await sessionP                // configP rejecting now is unhandled
```

**Correct (one join; dependent work chains on its input):**

```ts
const sessionP = auth()                      // null for a signed-out caller
const [session, config, data] = await Promise.all([
  sessionP,
  fetchConfig(),
  sessionP.then(s => (s ? fetchData(s.userId) : null)),   // starts as soon as the session resolves
])
if (!session) return new Response('Unauthorized', { status: 401 })
```

Use `Promise.allSettled` when one failure shouldn't fail the whole response.

On the client the same waterfall hides in render: a child's query starts only after its parent's data renders it, or a lazy component fetches only after its code loads. Start both requests in the route loader, or together from the parent.

*Break:* stay sequential when a call needs the previous result, when side effects must happen in order, or when the calls compete for a scarce resource (a small connection pool, a rate-limited API). Never start a write or a tenant-scoped read before authentication resolves; chain it on the session, as above.
