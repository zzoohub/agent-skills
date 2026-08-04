---
name: tanstack-start
description: |
  TanStack Start full-stack framework (React) — file-based routing, server functions, middleware, SSR.
  Use when: building full-stack apps with TanStack Start, using TanStack Router file-based routing,
  writing createServerFn or createMiddleware, deploying TanStack Start apps.
  Also use when user mentions TanStack Start or TanStack Router.
  Do not use for: Next.js (use react-best-practices). For SolidJS apps,
  prefer SolidStart or TanStack Start's Solid adapter — this skill covers React patterns only.
  For React-specific patterns, also read `references/react.md`.
---

# TanStack Start

Explicit over magic. End-to-end type safety. URL as first-class state.

**Package manager**: `bun`.
**Packages**: `@tanstack/react-start` + `@tanstack/react-router` (+ `react`, `react-dom`). Add `@tanstack/react-query` + `@tanstack/react-router-ssr-query` for Query integration. `@tanstack/zod-adapter` + `zod` are optional — only needed for `zodValidator` on route `validateSearch` (under Zod v4 you can pass the schema directly).

> For latest APIs, verify against the official TanStack Start / Router docs with a doc-lookup tool if one is available.

---

## Project Structure (FSD)

Route files are thin wrappers — routing concerns only (loader, beforeLoad, head).
UI goes in `views/`. Server functions live in the slice that owns the data.

```
src/
├── routes/                     # File-based routing (thin wrappers)
│   ├── __root.tsx              # Root layout
│   ├── index.tsx               # / → imports from views/
│   ├── posts.$postId.tsx       # Dynamic route → imports from views/
│   ├── _auth.tsx               # Pathless layout guard
│   └── api/
│       └── users.$id.ts        # API route (external consumers only)
├── views/                      # Page layouts (compose widgets + features)
├── widgets/                    # Composite UI blocks
├── features/
│   └── [feature]/
│       ├── ui/
│       ├── model/
│       └── api/                # Server functions (createServerFn)
├── entities/
│   └── [entity]/
│       ├── ui/
│       ├── model/
│       └── api/
├── shared/                     # ui/, api/, lib/, config/
├── router.tsx                  # Router creation + type registration
└── routeTree.gen.ts            # Auto-generated (DO NOT EDIT)
```

**Rules**: Layers only import downward. Routes are thin glue. `createServerFn` lives in owning slice's `api/`.

---

## Routing

### File Conventions

| File | URL | Notes |
|------|-----|-------|
| `__root.tsx` | — | Root layout |
| `index.tsx` | `/` | |
| `about.tsx` | `/about` | |
| `posts.tsx` | — | Layout for `/posts/*` |
| `posts.index.tsx` | `/posts` | Index under layout |
| `posts.$postId.tsx` | `/posts/:postId` | Dynamic segment |
| `posts/route.tsx` | — | Directory form of the `posts.tsx` layout |
| `_auth.tsx` | — | Pathless layout (no URL segment) |
| `_auth/dashboard.tsx` | `/dashboard` | Under pathless layout |
| `posts_.tsx` | — | Trailing `_` = non-nested (un-nest from parent) |
| `(group)/page.tsx` | `/page` | `()` = organizational group, no URL segment |
| `-components/` | — | Leading `-` = excluded from route generation |
| `$.tsx` | `/*` | Catch-all (splat); remainder at `params._splat` |

`.` in filenames = nesting. `posts.$postId.tsx` ≡ `posts/$postId/index.tsx`.

### Route Definition

```tsx
export const Route = createFileRoute('/posts/$postId')({
  component: PostComponent,
  loader: async ({ params }) => fetchPost(params.postId),
  beforeLoad: async ({ context }) => {
    if (!context.user) throw redirect({ to: '/login' })
  },
  // Zod v4 / Valibot / ArkType implement Standard Schema → pass directly.
  // For Zod v3, wrap with zodValidator from '@tanstack/zod-adapter'.
  validateSearch: z.object({
    tab: z.enum(['info', 'comments']).default('info'),
  }),
  pendingComponent: () => <Spinner />,
  errorComponent: ({ error }) => <ErrorView error={error} />,
  ssr: true,
  head: ({ loaderData }) => ({ meta: [{ title: loaderData.title }] }),
})
```

### Navigation

```tsx
<Link to="/posts/$postId" params={{ postId: '123' }}>View</Link>
<Link to="/posts" search={{ tab: 'comments' }} preload="intent">Comments</Link>

const navigate = useNavigate()
navigate({ to: '/posts', search: { tab: 'info' } })

// Route-scoped accessors are type-safe (Route = the file's createFileRoute export).
const params = Route.useParams()   // typed: { postId: string }
const search = Route.useSearch()   // typed from validateSearch
// From a non-route component: useSearch({ from: '/posts/$postId' })
```

**URL-as-state**: `validateSearch` + `Route.useSearch()` gives type-safe, validated search params. Prefer over client state for shareable/bookmarkable data.

---

## Server Functions

Run only on server. Build replaces with RPC stubs on client. Use for all internal data access.

```tsx
import { z } from 'zod'

// GET — no input
const getUsers = createServerFn({ method: 'GET' })
  .handler(async () => db.query('SELECT * FROM users'))

// POST — Zod validated (pass the schema directly to .inputValidator)
const createPost = createServerFn({ method: 'POST' })
  .inputValidator(z.object({
    title: z.string().min(1),
    content: z.string(),
  }))
  .handler(async ({ data }) => db.insert('posts', data))

// With middleware
const getMyPosts = createServerFn({ method: 'GET' })
  .middleware([authMiddleware])
  .handler(async ({ context }) => db.query('...', [context.user.id]))
```

Call from loaders, components, or other server functions:

```tsx
// In loader
export const Route = createFileRoute('/users')({
  loader: () => getUsers(),
})

// In component — direct call works; useServerFn() (from '@tanstack/react-start')
// is preferred so the call participates in router context
const createPostFn = useServerFn(createPost)
await createPostFn({ data: { title: 'Hello', content: '...' } })
```

Server functions may `throw redirect({ to: '/login' })` or `throw notFound()` (both from `@tanstack/react-router`) — these integrate with the route lifecycle.

**Rule: server functions are the data seam — at one of two altitudes.** When Start *is* the whole backend (no separate API service), they own data access directly (`db.*` as above). When the system has a dedicated backend (e.g. a hexagonal `apps/api`), server functions are a thin BFF: forward auth, call the API, shape the response — domain logic stays in the backend; don't grow a second one inside `features/*/api/`. Either way, server routes (below) exist only for webhooks/external consumers.

### Server Routes (webhooks / external consumers)

```tsx
// src/routes/api/stripe-webhook.ts
export const Route = createFileRoute('/api/stripe-webhook')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const sig = request.headers.get('stripe-signature')
        // verify the signature against the RAW body, before parsing
        const event = verifyStripeSignature(await request.text(), sig)
        await handleEvent(event)
        return new Response(null, { status: 200 })
      },
    },
  },
})
```

Raw `Request` in, raw `Response` out — no RPC envelope, callable by anything. Webhook handlers verify the signature first and return 200 fast (queue heavy work).

---

## Security Model

**Every server function is a public endpoint.** The build compiles each `createServerFn` into an HTTP-reachable RPC route — anyone can invoke it with crafted input, whether or not your UI calls it. Design each one as you would a public API endpoint:

- **Route guards are UX, not security.** `beforeLoad` / `_auth.tsx` gate *navigation*; they do not protect the functions a page calls. Enforcement lives on the function: attach auth middleware to every sensitive or mutating server function. A function without it is deliberately public — name it so (`publicSearch`, not `search`).
- **Authenticated ≠ authorized.** A valid session proves who's calling, not whether they may touch this row. Check ownership/policy inside the handler (`WHERE id = ? AND user_id = ?`) or any by-id server function is an IDOR.
- **Validate every input** — `.inputValidator(schema)` on any function that takes data. The schema is the trust boundary.
- **Thrown errors serialize to the client.** `throw new Error(dbError.message)` ships internals to the browser. Throw generic messages, log details server-side. (`redirect()` / `notFound()` are control flow, not errors.)
- **Expected failures are values, not throws** — return a discriminated union (`{ ok: false, code: 'limit_reached' }`) for domain outcomes the UI must handle; reserve throws for redirects and the exceptional.

### Server/Client Boundary

- Loaders are isomorphic (see Data Loading) — server-only work goes in server functions.
- **`serverOnly()` / `clientOnly()`** (from `@tanstack/react-start`) wrap functions so importing them on the wrong side fails at build time instead of silently leaking.
- **Env vars**: only `VITE_`-prefixed vars reach the client bundle — and all of them do, statically inlined. A secret in a `VITE_*` var ships to every browser. Server secrets stay unprefixed and are read only inside server functions/middleware.

---

## Middleware

Composable typed context chains. Context propagates through `.middleware([parent])`.

```tsx
const authMiddleware = createMiddleware({ type: 'function' })
  .server(async ({ next }) => {
    const session = await getSession()
    if (!session?.user) throw new Error('Unauthorized')
    return next({ context: { user: session.user } })
  })

// Compose — inherits auth context
const adminMiddleware = createMiddleware({ type: 'function' })
  .middleware([authMiddleware])
  .server(async ({ next, context }) => {
    if (context.user.role !== 'admin') throw new Error('Forbidden')
    return next({ context: { isAdmin: true } })
  })
```

Client → server context (e.g., sending tokens from client storage). `.client()` exists only on `type: 'function'` middleware — the default `'request'` type has `.server()` only:

```tsx
const tokenMiddleware = createMiddleware({ type: 'function' })
  .client(async ({ next }) => next({ sendContext: { token: getToken() } }))
  .server(async ({ next, context }) => {
    verify(context.token)
    return next()
  })
```

Register middleware globally in `src/start.ts`:

```tsx
import { createStart } from '@tanstack/react-start'

export const startInstance = createStart(() => ({
  requestMiddleware: [loggingMiddleware],   // global request middleware
  functionMiddleware: [authMiddleware],     // global server-function middleware
}))
```

Server-function middleware can also validate input via `.inputValidator(schema)` (not `.validator`).

---

## Data Loading

```tsx
export const Route = createFileRoute('/dashboard')({
  beforeLoad: async ({ context }) => {
    const user = await fetchUser()
    if (!user) throw redirect({ to: '/login' })
    return { user }  // adds to context for this route and children
  },
  loader: async ({ context }) => fetchDashboard(context.user.id),
})
```

**Execution order**: `beforeLoad` runs parent → child (sequential). `loader` runs all matched routes in parallel.

Use `beforeLoad` for auth guards and context setup. Use `loader` for data fetching.

Loaders are **isomorphic** — they run on both server (SSR) and client (navigation). Never read secrets / `process.env` directly in a loader; wrap server-only work in a `createServerFn()` and call it from the loader. Loaders also cache: default `staleTime: 0` (revalidates in background on re-entry), default `gcTime: 30min` — set a route `staleTime` before reaching for TanStack Query.

### Selective SSR

| Option | Behavior |
|--------|----------|
| `ssr: true` (default) | Loaders + rendering on server |
| `ssr: 'data-only'` | Loaders on server, rendering on client |
| `ssr: false` | Everything on client |
| `ssr: ({ params, search }) => true \| false \| 'data-only'` | Dynamic per-request (runs server-only, stripped from client bundle) |

Children can only become **more** restrictive. Allowed transitions: `true → data-only`/`false`, `data-only → false`.

Per-route `ssr` needs no global flag. To flip the app-wide default, set `defaultSsr` on the `createStart` instance (`createStart(() => ({ defaultSsr: false }))`). Full SPA mode is a Vite-plugin option: `tanstackStart({ spa: { enabled: true } })`.

---

## Mutations

```tsx
const deletePost = createServerFn({ method: 'POST' })
  .inputValidator(z.object({ id: z.string() }))
  .handler(async ({ data }) => db.delete('posts', data.id))

// In component — invalidate router cache after mutation
const router = useRouter()
await deletePost({ data: { id } })
router.invalidate()
```

For TanStack Query: use `useMutation` with `queryClient.invalidateQueries()`.

---

## State Management

| Need | Solution |
|------|----------|
| Server data (route level) | Route `loader` + `useLoaderData()` |
| Server data (dynamic/cached) | TanStack Query |
| URL state (filters, tabs, pagination) | `validateSearch` + `Route.useSearch()` |
| Form validation | Server function + Zod |
| Complex form (dynamic fields) | TanStack Form → server function |
| Global client state | Zustand |
| Local UI | useState |

---

## Auth Pattern

Session via server function + pathless layout guard. TanStack Start ships a built-in session helper — `useSession` from `@tanstack/react-start/server` (HTTP-only cookie sessions). `getSession()` and `db.*` below are placeholders — wire them to your actual auth and ORM stack.

**Common stacks for the placeholders:**
- Auth: `better-auth`, `clerk`, `workos`, `auth.js`, or your own session store on top of `useSession`
- DB: `drizzle-orm`, `prisma`, `kysely`

```tsx
// features/auth/api/session.ts
const fetchUser = createServerFn({ method: 'GET' })
  .handler(async () => {
    const session = await getSession() // TODO: wire to your auth (better-auth, clerk, workos, ...)
    return session?.user ?? null
  })

// __root.tsx — user in context for all routes
export const Route = createRootRoute({
  beforeLoad: async () => ({ user: await fetchUser() }),
})

// _auth.tsx — pathless guard, all children require auth
export const Route = createFileRoute('/_auth')({
  beforeLoad: ({ context, location }) => {
    // capture the destination so login can send the user back
    if (!context.user) throw redirect({ to: '/login', search: { redirect: location.href } })
  },
  component: () => <Outlet />,
})
```

This guard is navigation UX. The *enforcement* is the auth middleware on each server function the guarded pages call — see Security Model.

---

## Deployment

Most targets build through the **Nitro Vite plugin** — `tanstackStart()` takes no preset args:

```ts
// vite.config.ts
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { nitro } from 'nitro/vite'
import viteReact from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [tanstackStart(), nitro(), viteReact()],
})
```

| Platform | Configuration |
|----------|---------------|
| Node.js | Add the `nitro()` plugin, then `vite build` → `node .output/server/index.mjs` |
| Bun | `nitro({ preset: 'bun' })`; optional Bun-native server (`bun run server.ts`) |
| Vercel | Nitro plugin (auto-detected preset) + one-click deploy. Optionally pin `nitro({ preset: 'vercel' })` |
| Railway / others | Follow the Nitro instructions |
| Cloudflare | `cloudflare({ viteEnvironment: { name: 'ssr' } })` as the **first** plugin + `wrangler.jsonc` (`"main": "@tanstack/react-start/server-entry"`, `"compatibility_flags": ["nodejs_compat"]`). Not Nitro |
| Netlify | `import netlify from '@netlify/vite-plugin-tanstack-start'` → `netlify()`. Not Nitro |

> **Cloudflare = Vite plugin, not Nitro.** Do **not** hand-write an `assets` block in `wrangler.jsonc` —
> the `cloudflare()` plugin wires static-asset serving automatically. `.output/public` is the **Nitro**
> output dir and does **not** apply to the Cloudflare build. A complete basic `wrangler.jsonc` is just
> `$schema`, `name`, `compatibility_date`, `compatibility_flags: ["nodejs_compat"]`,
> `main: "@tanstack/react-start/server-entry"` (optionally `observability.enabled`) — nothing else.

---

## Anti-Patterns

- **Trusting a route guard to protect a server function** → guards gate navigation only; the function is still a public endpoint — put auth middleware on the function itself
- **API routes for internal data** → server functions (type-safe, no HTTP overhead)
- **Data fetching in `beforeLoad`** → use `loader` (beforeLoad is sequential; loaders are parallel)
- **Skipping `validateSearch`** → always validate search params for type safety
- **Business logic in route files** → routes are thin. Logic in FSD feature/entity layers
- **Client state for URL-worthy data** → `validateSearch` + `Route.useSearch()`
- **`.validator()` / `tanstackStart({ server: { preset } })`** → renamed/removed: use `.inputValidator()` and the Nitro Vite plugin
- **Router factory exported as `createRouter`** → the default server/client entries import `getRouter`; export the factory as `getRouter` (build error otherwise)

---

## Checklist

### Architecture
- [ ] FSD layers: no upward imports
- [ ] Route files are thin (import from views/)
- [ ] Server functions in owning slice's api/

### Data
- [ ] Server data via loaders or server functions
- [ ] URL state via validateSearch + Route.useSearch
- [ ] Zod validation on all server function inputs
- [ ] Mutations invalidate router

### SSR
- [ ] Appropriate `ssr` option per route
- [ ] No browser APIs during server render
- [ ] `head()` for SEO on content routes

### Security
- [ ] Every sensitive/mutating server function carries auth middleware (route guards don't protect functions)
- [ ] Ownership/policy check inside handlers for user/tenant-scoped rows
- [ ] No internals in thrown error messages; expected failures returned as typed values
- [ ] No secrets in `VITE_*` env vars; server-only code behind `serverOnly()` or server functions

### Guards (CI)
- [ ] `tsc --noEmit` passes; `routeTree.gen.ts` is current (regenerate + `git diff --exit-code`)
- [ ] Production build runs in CI against the actual deploy target (Nitro preset / CF plugin)

### Framework-Specific
→ React: `references/react.md`
