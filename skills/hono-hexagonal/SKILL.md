---
name: hono-hexagonal
description: |
  Hono with hexagonal architecture patterns in TypeScript.
  Use when: building TypeScript/JavaScript APIs with Hono — for multi-runtime backends (Bun, Node.js, Cloudflare Workers, Deno).
  Covers: API design (@hono/zod-openapi), domain modeling, ports & adapters, service layer, Zod validation, error handling, DI via context variables, testing, Drizzle ORM migrations, pagination, healthcheck endpoints.
  Do not use for: database schema design (use database-design skill). Use nestjs-hexagonal for modular NestJS apps with built-in DI. Use fastapi-hexagonal for Python-only APIs. Use axum-hexagonal for Rust APIs.
---

# Hono + Hexagonal Architecture

**For latest Hono/Drizzle/Zod APIs, verify against the official docs with a doc-lookup tool if one is available.**

## Core Philosophy

Separate **business domain** from **infrastructure**. Domain defines *what*; adapters decide *how*.

```
[Inbound Adapter: Hono route] -> [Port: Service interface] -> [Domain Logic]
    -> [Port: Repository interface] -> [Outbound Adapter: Drizzle/Postgres/etc.]
```

**Dependencies always point inward.** Domain code never imports Hono, Drizzle, or any infrastructure package.

---

## Project Structure

```
src/
├── app/
│   ├── server.ts               # Bootstrap only — no Hono/Drizzle imports
│   └── config.ts               # Typed config from env
├── domain/
│   └── authors/
│       ├── models.ts            # Author, AuthorName, CreateAuthorRequest
│       ├── errors.ts            # DuplicateAuthorError, AuthorNotFoundError, UnknownAuthorError
│       ├── ports.ts             # AuthorRepository, AuthorService (interfaces)
│       └── service.ts           # AuthorServiceImpl
├── inbound/
│   └── http/
│       ├── app.ts               # createApp() — wraps Hono, owns middleware stack
│       ├── errors.ts            # app.onError → RFC 9457
│       ├── middleware.ts         # DI middleware, auth middleware
│       ├── health.ts            # /healthz, /readyz — no domain involvement
│       ├── response.ts          # ApiSuccess, Created, PaginatedList helpers
│       └── authors/
│           ├── routes.ts        # Parse → call service → map response
│           ├── request.ts       # CreateAuthorBody (Zod schema + toDomain)
│           └── response.ts      # AuthorResponse (fromDomain)
├── outbound/
│   ├── drizzle/
│   │   ├── repository.ts       # impl AuthorRepository with Drizzle ORM
│   │   ├── schema.ts           # Drizzle table definitions (outbound only)
│   │   └── mapper.ts           # DB row ↔ domain translation
│   └── sqlite/
│       └── repository.ts       # impl AuthorRepository with raw SQL
├── drizzle/                     # DB migrations — infrastructure, not a hex layer
│   └── migrations/
tests/
├── helpers.ts                   # Test app factory, test config
└── mocks.ts                     # Stub, Saboteur, Spy, NoOp
```

**Rule:** `domain/` never imports from `inbound/` or `outbound/`.

---

## Domain Layer

### Models
- Validate on construction (value object pattern). Classes with private constructors or factory functions.
- **No Drizzle schemas in domain** — table definitions live in `outbound/` only.
- Domain models are plain TypeScript. No decorators, no framework dependencies.
- Separate `CreateAuthorRequest` from `Author` — they WILL diverge as app grows.

### Errors
- Exhaustive hierarchy: one class per business rule violation + generic `UnknownAuthorError`.
- **Never throw `HTTPException` in domain** — that leaks transport concerns.
- Use custom error classes extending `Error` with a `readonly tag` discriminant for exhaustive matching.

### Ports (Interfaces)

Use TypeScript `interface` for structural typing — no class inheritance required from implementors.

Three categories: **Repository** (data), **Metrics** (observability), **Notifier** (side effects).

### Service
- `interface` declaring business API + class `AuthorServiceImpl` implementing it.
- Constructor takes all dependencies: `new AuthorServiceImpl(repo, metrics, notifier)`.
- Orchestrates: repo -> metrics -> notifications -> return Result.
- Handlers call Service, never Repository directly.
- **Evolution path:** Direct calls (repo -> metrics -> notifier) keep the flow visible in one place — good for simple apps. As side effects grow, the service has to know about every consequence, raising coupling. When this becomes a pain, refactor to domain events: the service emits `AuthorCreatedEvent`, independent handlers react. Adding a new side effect no longer requires touching the service. Trade-off: flow is spread across files, harder to trace.

> Full domain examples (models, errors, ports, service): `references/examples-domain.md`

---

## Inbound Layer

- **`createApp()` function** — wraps Hono instance creation so `server.ts` never imports Hono.
  Expose `createTestApp()` for tests — returns Hono app without binding a port.
- **DI via context variables** — middleware sets services on `c.set('authorService', service)`,
  handlers access via `c.var.authorService`. Type-safe with `Variables` generic on Hono.
- **Use `createMiddleware()` from `hono/factory`** for type-safe DI middleware.
- **Handlers** do three things only: parse input -> call service -> map response. No SQL. No ORM.
- **Request schemas** decoupled from domain — Zod schema + `toDomain()` method to convert.
  Use `zValidator('json', schema)` inline in route definitions for validation.
- **Response types** built via `fromDomain()` static method — never expose domain models directly.
- **API errors** mapped via `app.onError()`. Never leak domain strings to users.
  `UnknownAuthorError` -> log server-side, return generic message. Use RFC 9457 ProblemDetails.
- **API docs** — use `@hono/zod-openapi` for route definitions with automatic OpenAPI generation. Consult `references/api-design.md` for conventions and `references/api-patterns.md` for HTTP patterns.
- **Middleware ordering** — register global middleware before routes (order matters for CORS).
- **Request-ID middleware** — `requestId()` from `hono/request-id`, typed into `Variables`; echo `X-Request-Id` on every response and stamp it into error logs (correlation lives in the header, not the body).
- **Sub-applications** — use `app.route('/prefix', subApp)` to mount feature-specific Hono instances.

### Non-HTTP Inbound Adapters

The inbound layer isn't limited to REST API routes. Any external trigger that drives the domain is an inbound adapter:

| Trigger | Examples | Still HTTP? |
|---------|----------|-------------|
| Task/Job queue | Cloud Tasks, SQS, BullMQ | Yes (HTTP callback) or No (consumer) |
| Webhook | Stripe, GitHub, external service callback | Yes |
| Cron/Scheduler | Cloudflare Cron Triggers, cron | Yes (HTTP) or No (scheduled) |
| Event stream | Pub/Sub, Kafka, CloudFlare Queues | No (pull/push consumer) |

All follow the same pattern: **parse input -> call service -> respond.**

Key differences from REST routes:
- Verify caller identity (task queue headers, webhook signatures) instead of user auth.
- Return simple ack (200 OK) — no user-facing response body.
- Must be idempotent — task queues retry on failure.
- Mount in `createApp()` alongside REST routes.

```
src/inbound/
├── http/            # User-facing REST API
├── tasks/           # Task queue handlers
└── webhooks/        # External service callbacks
```

All three are wired into the same Hono app. Domain doesn't know which triggered it.

> Full inbound examples (createApp, handlers, request/response, auth, error handler): `references/examples-adapters.md`

---

## Outbound Layer

- Wrap database client in own class (`DrizzleAuthorRepository`).
- Expose `static fromClient()` constructor for tests.
- **Transactions encapsulated in adapter**, invisible to callers.
- Keep transactions short. **No external calls (HTTP, queues) inside tx.**
- Map DB-specific errors (e.g. unique constraint codes) to domain error types.
- Drizzle schemas live in `outbound/`. Use explicit mapper (`AuthorMapper.toDomain()`) to translate.
  For raw SQL adapters, inline mapping is fine.

> Full outbound examples (Drizzle, SQLite adapters, row mapper): `references/examples-adapters.md`

### Drizzle ORM

| Setting | Value | Why |
|---------|-------|-----|
| Mode | `drizzle(client)` | Pass your own client for control |
| Transactions | `db.transaction(async (tx) => ...)` | Scoped, auto-rollback on throw |
| Relations | `db.query.authors.findMany({ with: { posts: true } })` | Eager load to prevent N+1 |

### Pool Config (Node.js with postgres.js)

```typescript
import postgres from "postgres";
const sql = postgres(url, { max: 10, idle_timeout: 20, connect_timeout: 3 });
```

---

## Validation

Zod schemas define the contract at the transport boundary. Domain models validate business rules separately.

```
[HTTP body] → [Zod schema validates shape] → [toDomain() validates business rules] → [Domain model]
```

Two-layer validation is intentional: Zod catches malformed input (missing fields, wrong types) before it reaches domain code. Domain constructors enforce business invariants (non-empty names, valid ranges). This keeps domain pure and gives callers clear, context-appropriate error messages.

---

## Pagination

List endpoints need pagination. **Default to cursor-based pagination.** The pattern flows through all three layers:
- **Domain port**: `listAuthors(cursor: string | null, limit: number) => Promise<CursorPage<Author>>`
- **Outbound adapter**: `WHERE (created_at, id) > (:cursor) ORDER BY created_at, id LIMIT :limit`
- **Inbound handler**: return `CursorPageResponse<T>` — `{ data, meta: { limit, next_cursor, has_more } }`

Cap `limit` at the handler level via Zod (e.g. `z.number().min(1).max(100).default(20)`). The domain doesn't care about max page size — that's a transport concern.

### Cursor vs Offset

**Cursor** (default) — `WHERE (created_at, id) > (:cursor) ORDER BY created_at, id LIMIT :limit`.
Consistent performance regardless of dataset size. Ideal for feeds, timelines, and large/mutable data. Always use a **composite cursor** `(sortField, id)`. Cursor is an opaque base64-encoded string in the API; decode in the adapter only.

**Offset** — `LIMIT / OFFSET` + `COUNT(*)`.
Use for admin panels and small/static datasets. Provides `total` count for page number UIs. Downside: deeper pages get slower, and row mutations between requests cause duplicates or skips.

> Full pagination examples (port, adapter, handler): `references/examples-adapters.md`

---

## Healthcheck

Healthcheck endpoints are infrastructure — they bypass the domain entirely. Wire them directly in `createApp()`.

- `/healthz` — always returns 200 (liveness, "is the process alive?"). **Never check dependencies here** — a liveness probe that touches a flaky DB cascade-restarts every replica.
- `/readyz` — checks DB connectivity (readiness, "can it serve traffic?"). Returns **503** (not 500) on failure so the load balancer sheds traffic.

**Register health routes BEFORE auth/DI middleware** so a global `requireAuth` doesn't 401 the probes, and wrap the readiness `ping()` in a timeout (`Promise.race`) so a hung DB returns a fast 503 instead of stalling the probe.

> Healthcheck example: `references/examples-adapters.md`

---

## Migrations (Drizzle Kit)

Migrations are infrastructure. They sit alongside the app, not inside any hex layer. Drizzle Kit reads schema definitions from `outbound/` to generate migrations.

```
drizzle/
├── migrations/      # Generated SQL migration files
drizzle.config.ts    # Points to outbound/drizzle/schema.ts
```

Use `drizzle-kit generate` to create migrations, `drizzle-kit migrate` to apply.

> Full migration setup: `references/examples-bootstrap.md`

---

## Logging

Use a structured logger (e.g. `pino`, `consola`) throughout. Import a shared logger instance.

- **Domain**: log business events at info, wrap unexpected exceptions at error
- **Inbound**: `app.onError` logs server errors before returning generic messages
- **Outbound**: log DB errors, slow queries

For simple apps, `console.log` is fine — Hono's built-in `hono/logger` middleware covers request logging.

---

## Security

| Item | Value |
|------|-------|
| Password hashing | `@node-rs/argon2` (default), `bcrypt` (fallback) |
| JWT library | `hono/jwt` middleware or `jose` |
| JWT signing | **ES256/EdDSA** (asymmetric) when multiple services verify; `HS256` only for a single service that both issues and verifies (see `api-design.md`) |
| JWT access token | 15 min |
| JWT refresh (web) | 90 days |
| JWT refresh (mobile) | 1 year |
| Refresh token rotation | **Required** — issue new refresh token on each use, revoke old immediately |
| Refresh token storage | DB table with `jti`, `userId`, `revokedAt`, `expiresAt` |
| CORS | `hono/cors` with explicit origins (no wildcard) |
| Security headers | `hono/secure-headers` middleware |
| CSRF | `hono/csrf` middleware for cookie-based auth |

Auth middleware lives in the inbound layer. Domain never handles raw tokens.

---

## Bootstrap (server.ts)

Construct adapters -> assemble service -> start. **No Hono/Drizzle imports.**

The entry point varies by runtime:

| Runtime | Pattern |
|---------|---------|
| Bun | `export default { fetch: app.fetch, port }` |
| Node.js | `serve({ fetch: app.fetch, port })` from `@hono/node-server` |
| Cloudflare Workers | `export default app` |
| Deno | `Deno.serve({ port }, app.fetch)` |

> Full bootstrap, config, and multi-runtime examples: `references/examples-bootstrap.md`

---

## Graceful Shutdown

Bare `process.exit(0)` drops in-flight requests and leaks pool connections. Drain first, then close the pool:

| Runtime | Pattern |
|---------|---------|
| Node.js | capture `const server = serve(...)`; on SIGTERM/SIGINT: `server.close()` → `closeDb(db)` → exit, with a `setTimeout(…, 10_000).unref()` failsafe if the drain hangs |
| Bun | `const server = Bun.serve(...)`; signal handler: `await server.stop()` → `closeDb(db)` |
| Deno | `Deno.addSignalListener("SIGTERM", ...)` → `closeDb(db)` |
| Cloudflare Workers | platform-managed — nothing to do |

`closeDb` lives next to `createDb` in `outbound/drizzle/client.ts` (pg `pool.end()`, postgres.js `sql.end()`, bun:sqlite `close()`) so driver imports stay out of `server.ts`.

> Full shutdown example: `references/examples-bootstrap.md`

---

## RPC Type Safety

Hono's RPC client (`hc`) provides end-to-end type safety without code generation. When using it:

- Chain route definitions for type inference: `app.get(...).post(...)`
- Export the route type: `export type AppType = typeof routes`
- Client infers request/response types from Zod validators and `c.json()` returns

This is optional but powerful — particularly useful for monorepo setups where frontend and backend share types.

---

## Domain Boundaries

1. **Domain = tangible arm of your business** (blogging, billing, identity)
2. **Entities that change atomically -> same domain**
3. **Cross-domain operations are never atomic** — service calls or async events
4. **Start large, decompose when friction is observed**

> If you leak transactions into business logic for cross-domain atomicity, your boundaries are wrong.

---

## Enforce the Boundary (CI)

"Domain never imports infrastructure" is a fitness function, not an honor system — guard it on every PR (if the `software-architecture` skill is installed, this is its Stage-8 fitness functions at code level):

```js
// .dependency-cruiser.cjs (excerpt)
forbidden: [
  { name: "domain-stays-pure", severity: "error",
    from: { path: "^src/domain" },
    to: { path: "^src/(inbound|outbound)|^node_modules/(hono|drizzle-orm|postgres|pg)" } },
],
```

Run `depcruise src` in CI next to `tsc --noEmit`, lint, and tests; add `madge --circular src` to keep the import graph acyclic. (`eslint-plugin-boundaries` is an equivalent alternative if the rule should live in ESLint.)

Cross-cutting infrastructure that must not leak into the domain. Define each as a TS interface; implement as adapters. The architecture-level pattern lives in the software-architecture skill's references (`reliability-patterns.md`, `observability.md`) if installed; otherwise apply the standard patterns inline — outbox, idempotency keys, retry/backoff, structured logging, RED/USE metrics.

| Port | Purpose | Where it lives |
|---|---|---|
| **Outbox** | Atomic state change + message publish — outbox row written inside the same `db.transaction(...)` callback as the aggregate write | Outbound (combined with the repository adapter) |
| **IdempotencyStore** | Replay safe responses for `Idempotency-Key`-bearing requests | Outbound; called by inbound middleware or application service |
| **Tracer** / **Meter** | OTel span / metric emission. Domain depends on the interface, not on `@opentelemetry/*` packages | Outbound (OTel adapter); no-op for tests |

**Architectural rule**: domain emits **`DomainEvent`** plain objects; the outbound adapter persists the aggregate AND the outbox rows inside one Drizzle `db.transaction(async (tx) => ...)` callback. A separate **outbox relay** (background task or worker) publishes rows asynchronously.

**Edge runtime constraint**: on Cloudflare Workers + D1, `db.transaction` is locally scoped to one request and the standard OTel JS SDK does not run (Node-only deps). The `Tracer` port abstraction lets you swap to manual `traceparent` propagation + a Workers-friendly exporter (e.g., otel-cf-workers) without changing application code. If you target Node only (Bun, Deno-compat), this constraint doesn't apply.

**Optimistic concurrency (lost-update protection)**: any aggregate two clients can update concurrently carries a `version` column. Writes are conditional — `` .update(authors).set({ ...changes, version: sql`${authors.version} + 1` }).where(and(eq(authors.id, id), eq(authors.version, expected))) `` — then check the affected count (`.returning()` length or driver `rowCount`); zero rows means someone else won → domain conflict error → **409** (or **412** with `If-Match`/ETag, per `api-design.md`). Idempotency keys cover the *same* client retrying; the version column covers *different* clients racing — you usually need both.

→ Adapter examples: `references/examples-adapters.md`

---

## Common Gotchas

| Problem | Cause | Fix |
|---------|-------|-----|
| Validation returns raw Zod errors | No validation hook wired | For `OpenAPIHono` + `app.openapi()`, the hook is the constructor `defaultHook` (there is no 3rd-arg slot). For plain Hono + `zValidator`, pass the 3rd-arg hook. Both convert failures to RFC 9457. |
| CORS not working | Middleware order | Register `cors()` before routes |
| `c.var.service` is undefined | Middleware not applied to route | Ensure DI middleware is `app.use()`'d before routes |
| Domain imports Hono | Leaky boundary | Move to inbound layer |
| `HTTPException` in domain | Transport leak | Use domain error classes |
| Drizzle schema in handler | Missing mapper | Translate in adapter via mapper |
| `c.env` is empty in Node.js | Node.js doesn't use env bindings | Use `process.env` or config module for Node |
| RPC types don't flow | Routes not chained | Chain `.get().post()` or use `app.route()` + export type |
| `testClient` types broken | `strict: true` missing | Set `"strict": true` in tsconfig.json |
| Handler returns wrong type | Missing explicit status code | Use `c.json(data, 201)` with explicit status for RPC |

---

## Quick Reference

| Question | Answer |
|----------|--------|
| Transactions? | Adapter (repository impl) via `db.transaction()` |
| Lost updates? | `version` column + conditional update; 0 rows affected → 409/412 |
| Validation? | Zod at transport boundary, domain constructors for business rules |
| Error mapping? | `app.onError()` in inbound |
| Business orchestration? | Service impl |
| Handler responsibility? | Parse -> service -> response |
| server.ts responsibility? | Construct adapters -> assemble -> start |
| DI mechanism? | `createMiddleware()` + `c.set()` / `c.var` |
| DB row <-> domain? | `AuthorMapper.toDomain()` in outbound |
| Test app? | `createTestApp(service)` + `app.request()` |
| Background workers? | Separate process or Cloudflare Cron Triggers |
| Migrations? | Drizzle Kit, lives alongside app (not in hex layers) |
| Healthcheck? | `/healthz` + `/readyz` in inbound, no domain |
| Pagination? | `CursorPageResponse<T>` wrapper, cursor in adapter |
| JWT / passwords? | `hono/jwt` + `@node-rs/argon2` |
| Multi-runtime? | Same app code, different entry point per runtime |

---

## Checklist

### Architecture
- [ ] Domain never imports from inbound/ or outbound/
- [ ] Ports as `interface`, services orchestrate
- [ ] All handlers (HTTP, tasks, webhooks): parse -> service -> respond
- [ ] Transactions in adapters only, DB row <-> domain mapper in outbound
- [ ] Errors: domain hierarchy -> `app.onError()` -> RFC 9457
- [ ] Racing aggregates carry a `version` column; 0-rows-affected writes map to 409/412
- [ ] Boundary enforced in CI: dependency-cruiser (or eslint-plugin-boundaries) rule (see Enforce the Boundary)

### Framework
- [ ] Hono wrapped in `createApp()`, `createTestApp()` for tests
- [ ] DI via `createMiddleware()` + `c.var` with typed `Variables`
- [ ] Zod validation via `zValidator()` on routes
- [ ] CORS middleware before routes
- [ ] `requestId()` middleware; `X-Request-Id` echoed and logged
- [ ] `/healthz` and `/readyz` endpoints
- [ ] Graceful shutdown on Node/Bun: drain the server, then `closeDb()`
- [ ] `hono/secure-headers` middleware enabled

### Database
- [ ] Drizzle Kit configured, schema in outbound/
- [ ] Migrations in `drizzle/migrations/`
- [ ] `fromClient()` on adapters for test injection

### Testing
**TDD**: Write all tests first as a spec, then implement, then verify all pass. (Tests -> Impl -> Green)
- [ ] Test helpers: `createTestApp()`, test config
- [ ] Mock strategy: Stub, Saboteur, Spy, NoOp
> Test mocks and test app helper: `references/examples-bootstrap.md`

### Setup
- [ ] `server.ts` has no Hono/Drizzle imports
- [ ] `bun.lock` / `package-lock.json` committed
- [ ] Config module reads env once, typed with Zod
