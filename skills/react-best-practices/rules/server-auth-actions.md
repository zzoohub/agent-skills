---
title: Server Functions Are Public Endpoints; Check Everything Inside the Handler
tags: server, security, server-functions, tenancy
---

After the Server boundary order (authenticate, validate, load tenant-scoped, authorize): write, still scoped; invalidate; return `{ ok } | { error }` with a generic message, logging the details. Input never carries the caller's identity, tenant or role; a target user's id is a resource id, tenant-scoped like any other.

**Incorrect:** `deleteUser(userId)` that allows `role === 'admin' || session.userId === userId`, then deletes by `userId` alone. An admin of org A deletes a user of org B.

**Correct (a shared core, then a thin adapter per framework):**

```ts
// lib/members.server.ts: server-only (Next: import 'server-only'). Never a 'use server'
// file, whose exports are endpoints that would take `session` from the caller.
export const Input = z.object({ memberId: z.uuid(), email: z.email() })
export type Result = { ok: true } | { error: string; fields?: Record<string, string> }

export async function changeMemberEmail(session: Session, input: z.infer<typeof Input>): Promise<Result> {
  const member = await db.member.findFirst({ where: { id: input.memberId, orgId: session.orgId } })
  if (!member) return { error: 'Not found' }
  if (session.role !== 'admin' && member.userId !== session.userId) return { error: 'Forbidden' }
  await db.member.update({ where: { id: member.id, orgId: session.orgId }, data: { email: input.email } })
  return { ok: true }
}
```

```ts
// Next.js, called through useActionState
'use server'
export async function updateMemberEmail(_prev: Result | null, form: FormData): Promise<Result> {
  const session = await getSession()
  if (!session) return { error: 'Sign in again' }
  const raw = Object.fromEntries(form)
  const input = Input.safeParse(raw)
  // React resets the form even on this error: send back what to re-render as defaultValue
  if (!input.success) return { error: 'Invalid input', fields: { email: String(raw.email ?? '') } }
  const result = await changeMemberEmail(session, input.data)
  if ('ok' in result) revalidatePath('/members')
  return result
}

// TanStack Start; on { ok } the client calls router.invalidate() or its query invalidation
const authMiddleware = createMiddleware({ type: 'function' }).server(async ({ next }) => {
  const session = await getSession()
  if (!session) throw new Error('Sign in again')   // thrown errors reach the client
  return next({ context: { session } })
})

export const updateMemberEmail = createServerFn({ method: 'POST' })
  .middleware([authMiddleware])   // runs inside this call, unlike a route's beforeLoad
  .validator(Input)               // .inputValidator() in some 1.x releases
  .handler(({ data, context }) => changeMemberEmail(context.session, data))
```

TanStack Start adds its CSRF middleware automatically only when the app has no `src/start.ts`; with one, register `createCsrfMiddleware()` in its `requestMiddleware`. CSRF protection is not authorization.

**Prove it** with one test per check, calling the function directly rather than through the UI: no session; another tenant's id (the same not-found as a missing one); a role below the one required; malformed input; the same submit twice (one effect). Rate-limit functions that send, charge or enumerate, by actor and by IP.

Sources: https://nextjs.org/docs/app/guides/authentication · https://tanstack.com/start/latest/docs/framework/react/guide/server-functions · https://zod.dev/v4/changelog
