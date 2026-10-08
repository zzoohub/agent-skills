---
title: Await Only on the Path That Needs the Value
tags: async, await, conditional, waterfalls
---

An `await` placed before a branch makes every path wait, including paths that return without the value.

**Incorrect:** `const data = await fetchUserData(id)`, then `if (skip) return { skipped: true }`: the skip path waits for data it never uses. **Correct:** return on `skip` first, then await.

When a condition combines an awaited flag with a cheap synchronous check, test the cheap one first: `if (isBetaUser && (await getFlag('new-editor')))`. Keep the original order when the "cheap" check is expensive, depends on the flag, or side effects must run in a fixed order.

Never reorder an authorization check to save a call: load tenant-scoped, then authorize on the loaded row ([server-auth-actions](./server-auth-actions.md)).

*Break:* if most paths need the value, start it early alongside other work instead ([async-parallel](./async-parallel.md)); deferring it would only serialize it.
