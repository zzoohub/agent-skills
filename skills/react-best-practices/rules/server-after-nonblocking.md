---
title: Use after() Only for Work You Can Afford to Lose
tags: server, next, after, waitUntil, side-effects
---

Next's `after()` runs a callback once the response is sent, so logging and analytics add no latency. It is best-effort: bounded by the route's max duration, run even after errors, `notFound()` and `redirect()`, and in a static route run at build or revalidation time. On serverless adapters it needs the platform's `waitUntil`, which has the same limits on any host; static export doesn't support it.

- Durable work (audit logs, emails, webhooks): write an outbox row in the request's transaction, and ship the worker that delivers it in the same change: it claims rows, sends with the row id as the idempotency key, retries with backoff and parks failures for review. A row nobody consumes is a side effect that never happens. Deploy the table, then the worker, then the code that writes rows.
- Invalidate before returning, never in `after()`, or the user's next read can be stale.
- `await` everything inside the callback; an unawaited promise can be cut off when the instance stops.

**Incorrect (after the write, in a Server Action):**

```ts
await db.org.update({ where: { id: org.id }, data: { plan } })
after(() => {
  revalidateTag(`org:${org.id}`, 'max')     // the next read may still be stale
  auditLog.write({ orgId: org.id, plan })   // not awaited; lost if the instance stops
})
```

**Correct:**

```ts
await db.$transaction([
  db.org.update({ where: { id: org.id }, data: { plan } }),
  db.outbox.create({ data: { type: 'plan.changed', orgId: org.id, plan } }),   // a worker delivers it
])
updateTag(`org:${org.id}`)
after(async () => {
  await analytics.track('plan_changed', { orgId: org.id })   // losable
})
```

In Server Components, read `headers()` and `cookies()` before calling `after()` and pass the values in; calling them inside the callback throws there.

Source: https://nextjs.org/docs/app/api-reference/functions/after
