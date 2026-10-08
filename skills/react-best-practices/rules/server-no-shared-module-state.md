---
title: Never Keep Request Data in Module Scope
tags: server, rsc, ssr, concurrency, security
---

Module scope on the server is process-wide memory. Concurrent renders and requests in the same instance share it, so a value one request writes can appear in another user's response; on a warm serverless instance it also outlives the request. Separate instances share nothing, so module state can't serve as a shared cache either.

**Incorrect (request data leaks across concurrent renders):**

```tsx
let currentUser: User | null = null

export default async function Page() {
  currentUser = await auth()
  return <Dashboard />
}

async function Dashboard() {
  return <div>{currentUser?.name}</div>   // can render another request's user
}
```

**Correct (request data stays in the render tree):**

```tsx
export default async function Page() {
  const user = await auth()
  return <Dashboard user={user} />
}
```

To share a per-request value without prop drilling, wrap its getter in `React.cache` ([server-cache-react](./server-cache-react.md)) or use the framework's request context.

Safe exceptions:
- Immutable static assets or config loaded once ([server-hoist-static-io](./server-hoist-static-io.md))
- Caches designed for cross-request reuse and keyed correctly ([server-cache-cross-request](./server-cache-cross-request.md))
- Process-wide singletons that hold no request- or user-specific mutable data (a DB pool, an SDK client)
