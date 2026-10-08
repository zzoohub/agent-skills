---
title: Avoid Server Waterfalls and Hidden N+1 Queries
tags: server, rsc, waterfalls, n-plus-one, data-loading
---

A component that awaits delays its children; sibling components, and a route's layouts and page, render in parallel. So a parent that awaits before rendering its children turns their fetches into a waterfall.

**Incorrect (Sidebar can't start until Page's fetch finishes):**

```tsx
export default async function Page() {
  const header = await fetchHeader()
  return <div><div>{header}</div><Sidebar /></div>
}
```

**Correct (siblings fetch at the same time):**

```tsx
export default function Page() {
  return <div><Header /><Sidebar /></div>
}

async function Header() {
  return <div>{await fetchHeader()}</div>
}
```

TanStack Router runs `beforeLoad` serially from parent to child and route `loader`s in parallel, so keep data loading out of `beforeLoad`.

**Lists:** `Promise.all` over per-item queries is an N+1 that queues on the connection pool and starves other requests (100 chats with an author lookup each is 200 queries). Batch first: one `IN` query, a join, or a per-request DataLoader. Otherwise bound the concurrency. Chain per item only when batching is impossible, such as a third-party API with no batch endpoint.

**Incorrect:**

```ts
const authors = await Promise.all(chatIds.map(id => getChat(id).then(c => getUser(c.authorId))))
```

**Correct:**

```ts
const chats = await db.chat.findMany({
  where: { id: { in: chatIds }, orgId: session.orgId },
  include: { author: true },
})
```

Source: https://nextjs.org/docs/app/getting-started/fetching-data
