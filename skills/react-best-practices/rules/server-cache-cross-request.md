---
title: Pick a Cross-Request Cache by Who Shares the Data and What Invalidates It
tags: server, cache, invalidation, tenancy, cache-components, lru
---

Before streaming around a slow query, ask who shares its result, how stale it may be, and which write changes it. Streaming hides the wait; caching at the sharing scope removes it for every reader after the first.

| Shared by | Cache | Key | Invalidated by |
|---|---|---|---|
| Everyone (public) | HTTP/CDN (`Cache-Control`), or the framework's cache | URL or arguments | a TTL, or the write's tag |
| A tenant (org settings, plan, members, dashboard aggregates) | The framework's tagged cache, or a shared store | the tenant id from the session, never from input | the write in that tenant (`org:<id>:<thing>`) |
| One user | Per-request dedup ([server-cache-react](./server-cache-react.md)), or a user-keyed cache | the user id from the session | the user's writes |
| Nobody (immutable reference data) | An in-process LRU | the value's id | a deploy |

- Authorize before the cached call; a cache does no access control. Never cache authorization inputs (sessions, roles, memberships): a revoked role must take effect on the next request.
- Instances share no memory: in-process caches disagree, and an in-process invalidation reaches one instance only.

**Next.js mechanics** (they changed between 14, 15 and 16: check your version's caching docs):
- *Cache Components* (`cacheComponents: true`, Next 16+): a `'use cache'` function with `cacheTag` and `cacheLife`; arguments and captured variables join the key; read `cookies()` or `headers()` outside and pass values in (`'use cache: private'` only where the function must read them itself). `await connection()` before a `Date.now()` or random value that must differ per request.
- *Without it:* `fetch(url, { next: { tags } })`, or `unstable_cache(fn, keyParts, { tags })` (replaced by `'use cache'` in 16), whose key ignores captured variables: a tenant id read from a closure shares one entry across tenants, so pass it as an argument or in `keyParts`.
- *Invalidate:* in the Server Action that writes, `updateTag` (16+; the next read waits for fresh data); elsewhere `revalidateTag(tag, 'max')` (16+; stale-while-revalidate); before 16, `revalidateTag(tag)`.
- *Where it runs:* on serverless, the default in-memory cache rarely survives between requests; on several self-hosted instances it is per instance. Use `'use cache: remote'` with a shared `cacheHandlers` entry whose `refreshTags()` syncs tag state, or `revalidateTag` clears one instance.

**Elsewhere** (TanStack Start, Vite SSR): a shared store that reads its own writes (Redis, read from the primary), keyed as above, which the write deletes before returning. An eventually consistent KV can keep serving the old value for a while after the delete: use one only where that staleness is acceptable. On the client, the query cache keyed by tenant and invalidated by the mutation.

```ts
import { cacheLife, cacheTag } from 'next/cache'

// The page authorizes the session, then calls getOrgDashboard(session.orgId)
async function getOrgDashboard(orgId: string) {
  'use cache'
  cacheTag(`org:${orgId}:dashboard`)
  cacheLife('minutes')
  return db.report.aggregate({ where: { orgId } })   // the slow query: once per tenant per change
}
// In the Server Action that writes in this org: updateTag(`org:${session.orgId}:dashboard`)
```

**Incorrect:** a per-instance LRU of users with a five-minute TTL. It ignores role changes, instances disagree, concurrent misses all hit the database, and `if (cached)` reads a cached falsy value as a miss.

**Correct (immutable reference data; cache the promise, evict it on rejection):**

```ts
import { LRUCache } from 'lru-cache'

const countries = new LRUCache<string, Promise<Country | null>>({ max: 500 })

export function getCountry(code: string) {
  if (!countries.has(code)) {
    const p = db.country.findUnique({ where: { code } })
    p.catch(() => countries.delete(code))   // never cache a failure
    countries.set(code, p)                  // concurrent misses share one query
  }
  return countries.get(code)!
}
```

Sources: https://nextjs.org/docs/app/api-reference/directives/use-cache · https://nextjs.org/docs/app/api-reference/functions/updateTag · https://nextjs.org/docs/app/api-reference/functions/unstable_cache · https://nextjs.org/docs/app/guides/self-hosting#multi-instance-cache-coordination · https://github.com/isaacs/node-lru-cache
