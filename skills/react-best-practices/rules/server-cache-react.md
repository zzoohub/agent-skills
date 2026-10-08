---
title: Deduplicate Per-Request Work with React.cache
tags: server, rsc, cache, deduplication
---

In one server render pass, GET `fetch` calls with the same URL and options, and functions wrapped in `React.cache`, run once, so every component can call `getCurrentUser()` instead of drilling props. The cache lives for one request and works only in Server Components. Server Actions and Route Handlers are not part of a render pass and dedupe neither; pass the value down there.

Define the cached function at module scope and export it: each `cache()` call creates its own cache, so calling it inside a component dedupes nothing.

```ts
// lib/user.ts
import { cache } from 'react'

export const getCurrentUser = cache(async () => {
  const session = await auth()
  if (!session) return null
  return db.user.findUnique({ where: { id: session.userId } })
})
```

Arguments are compared with `Object.is`: pass primitives or the same object reference; an object literal (`getUser({ uid: 1 })`) misses on every call.

For data shared across requests, see [server-cache-cross-request](./server-cache-cross-request.md).

Sources: https://react.dev/reference/react/cache · https://nextjs.org/docs/app/api-reference/functions/fetch
