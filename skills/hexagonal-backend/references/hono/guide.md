# Hono stack guide

The SKILL.md contract on Hono: the decisions this stack forces, how they fail, and the traps. The three `examples-*.md` files hold one verified project (typecheck, type-aware lint, boundary gate, tests on PostgreSQL 18; the Node and Workers entries smoke-tested).

## 0. Version baseline

Verified against the npm registry on 2026-10-08; verify again with a doc-lookup tool if one is available. Floors are the versions the examples need.

| Package | Version | Why it matters / floor |
|---|---|---|
| Node.js | 24 LTS (24.21) | Runs the `.ts` sources natively (type stripping); tooling needs ≥ 22. Node 26 becomes LTS on 2026-10-28. |
| hono | 4.13.13 | `methodNotAllowed` since 4.13.0; JWT `alg` mandatory since 4.11.4. |
| @hono/zod-openapi | 1.6.3 | Sub-apps inherit the root `defaultHook` (1.5.0); unknown media type → 415 (1.6.3). |
| zod | 4.6.5 | 4.4 and 4.6 changed validation and error behavior: pin the minor (`~4.6.5`). |
| @hono/node-server | 2.1.3 | Node ≥ 20; `serve()` returns a `node:http` server. |
| drizzle-orm / drizzle-kit | 0.45.3 / 0.31.11 | Stable line; 1.0 (a release candidate) changes migrations and relations — do not float onto `@rc`. |
| pg | 8.23.1 | Named ESM exports (`import { Pool } from "pg"`); Hyperdrive needs ≥ 8.13. |
| jose | 6.2.12 | Remote JWKS with cache, cooldown and timeout. |
| pino | 10.4.0 | JSON logs, redaction, `mixin` for trace ids. |
| @opentelemetry/sdk-node | 0.223.0 | With api 1.9.1, instrumentation-pg 0.75.0, instrumentation-undici 0.33.0. |
| @hono/otel | 1.2.0 | Server spans named by route template, HTTP server metrics. |
| TypeScript | `tsc` 7.0.2 + `typescript` 6.0.2 alias | TS 7 has no TS 5/6-compatible compiler API (only experimental `typescript/unstable/*`); API tools get `@typescript/typescript6` as `typescript` (npm and Bun ≥ 1.4 install the pair, Bun 1.3 does not). |
| oxlint + oxlint-tsgolint | 1.87.0 + 7.0.2003 | Type-aware rules on the TS 7 engine. |
| dependency-cruiser | 18.5.0 | Boundary gate; needs the TS 6 API (see Traps). |
| vitest | 5.0.3 | Node ^22.12 or ^24. |
| PostgreSQL | 18 | `uuidv7()`; `transaction_timeout` (≥ 17). |
| wrangler | 4.148.0 | Local workerd ran the Worker entry (local Hyperdrive) and the D1 guard batch. |
| Bun / Deno | 1.4.2 / 2.9.7 | Alternative runtimes; not run for these examples. |

Watch list, not adopted: Hono v5 (ESM-only; runtime adapters move to `@hono/*`); Drizzle 1.0; TypeScript 7.1's API (lets tools drop the TS 6 alias); `@hono/structured-logger` (no contract request-id rule); `@cloudflare/vitest-plugin` 1.3 (still on Vitest 4.1); Workers native tracing (beta).

## 1. Approach a change in Hono

Hono gives routing, middleware and adapters; every other contract rule is code you own, so decide these before writing a handler.

- **One Node or Bun process per container is the canonical runtime; Workers is a delta (§ 9).** *Why:* a long-lived process keeps a warm pool, runs the relay loop and answers probes. *Break when* the edge is the requirement — Hyperdrive keeps PostgreSQL and every adapter; D1 changes the write path.
- **Write erasable TypeScript and run it without a build** (`erasableSyntaxOnly`, `.ts` import suffixes). *Why:* Node 24, Bun, Deno and wrangler run the same sources; no `dist/` to drift. *Break when* you need decorators, enums or parameter properties — Hono needs none.
- **One `createApp(deps)`; per-request services through a `provide` middleware.** *Why:* the same app serves Node (a singleton), Workers (a client per request) and tests (`app.request()`, no port). *Break never:* building the app per request multiplies router and OpenAPI cost on every call.
- **The use case owns the transaction; a nested `uow.run` joins the open one** (`AsyncLocalStorage`). *Why:* the idempotency middleware and the webhook inbox commit in the use case's transaction without the use case knowing about either. *Break when* the store has no interactive transactions (D1): the unit becomes one batch.
- **READ COMMITTED; a deadlock answers 503 and the server never loops.** *Why:* guards and constraints decide every race (§ 5), so the one serialization-class error left is a deadlock (`40P01`); it maps to 503 + `Retry-After` and the client retries the request under its idempotency key, while a server loop would hold a pooled connection and retry blind. *Break when* database.md chooses SERIALIZABLE: retry the outermost `db.transaction(…, { isolationLevel: "serializable" })` whole — bounded, jittered — never a joined unit.
- **Every failure goes through one `onError`.** *Why:* Hono's default 404, 413 and validation responses are not problem documents. *Break never.*
- **Validate shape at the edge, rules in the domain.** Zod schemas are strict; slug, title and body rules live in the aggregate, and the schemas only document them. *Why:* one rule, one place, and 422 `errors[]` either way. *Break when* the client benefits from an OpenAPI constraint: document it there, still enforce it in the domain.
- **The database, not the HTTP timeout, bounds the work.** *Why:* `hono/timeout` cannot cancel the handler (Traps); `statement_timeout` and `transaction_timeout` can, and the idempotency lease (3 × deadline) outlives both. *Break when* the work leaves the database: an outbound call takes an `AbortSignal` with the remaining budget.

Failure semantics to keep in mind while coding: `await next()` never throws — a failed handler leaves `c.error` set and the problem response in `c.res`; middleware after `next()` sees both. Only `Error` instances reach `onError` in v4, so adapters translate everything they throw.

## 2. Layout and composition

SKILL.md's layout under `src/` (`app/` is the bootstrap), plus `migrations/`, `worker/` (the Workers program) and `test/`. The boundary gate forbids `domain` → anything outside `domain` (packages and `node:` built-ins included, type-only imports counted), `inbound` ↔ `outbound`, and cycles.

Composition is plain functions: `buildServices(db)` builds the use cases and stores; `createApp(deps)` receives them through `provide`; entrypoints only wire. `c.var` carries `log`, `actor` and `services`, typed by one `AppEnv`. The typed RPC client (`hc`) needs route types, which separate `app.openapi()` statements do not carry: chain them or use `app.openapiRoutes([...] as const)`.

## 3. HTTP edge

Registration order is execution order, and a route sees only middleware registered before it.

| # | Middleware | Why here |
|---|---|---|
| 1 | `@hono/otel` | The server span covers everything; logs inherit its trace id. |
| 2 | request id + request logger | Every response carries `X-Request-Id` (and, while draining, `Connection: close` — § 7), every log line `request_id`. `hono/request-id` accepts `[\w\-=]{1,255}`, not the contract's `[A-Za-z0-9._:-]{1,128}`. |
| 3 | `cors` | Decorates preflights and problem responses; `exposeHeaders` defaults to none. |
| 4 | `secureHeaders` | `X-Frame-Options: DENY`, CSP `default-src 'none'` (its default is SAMEORIGIN). |
| 5 | `methodNotAllowed` | Rewrites Hono's 404 for a known path into 405 + `Allow`. |
| 6 | probes | Before the deadline, limits and auth. |
| 7 | `timeout` → 503 | Before `bodyLimit`, so a slow upload meets the deadline (Traps); its default status is 504. |
| 8 | `bodyLimit` (64 KiB) | Before anything reads the body; a stream without `Content-Length` is counted too. |
| 9 | `provide` | Services for this request. |
| 10 | auth on `/v1/*` | Unknown `/v1` routes answer 401 before 404: no route discovery without a token. |
| 11 | route `middleware` → validators → handler | zod-openapi runs route middleware (idempotency) before its validators. |

**Error pipeline.** The `defaultHook` throws a `ProblemError`; `onError` renders it, a `DomainError` (an exhaustive `satisfies Record<ErrorCode, …>` map), an `HTTPException` or anything else (a logged, generic 500) as `application/problem+json` with the registry's fixed title; `notFound` and `methodNotAllowed` render the same documents. An `HTTPException` keeps its status and headers (`WWW-Authenticate`, `Retry-After`): it takes the registry type when exactly one has that status (a 403 from `hono/csrf`, a 406, a rate limiter's 429), else `about:blank` with the `node:http` status phrase (a 410, a 504, a library's 409). Exempt protocol-level answers: Node rejects a malformed or oversized request head before Hono runs (plain 400 or 431), and `cors` answers a refused preflight with a 204 lacking `Access-Control-Allow-Origin`. The slice has one representation, ignores `Accept` and registers no compression, so nothing rewrites a response after the handler.

**400 vs 422.** zod-openapi validates query → param → header → media type → body. A param failure is 400 (the path cannot be an id); malformed JSON is Hono's `HTTPException(400)`; an undeclared `Content-Type` is 415; body and query values are 422 with `errors[].pointer` (`#` for the whole body) or `errors[].parameter`. Every route declares a strict query object (`z.strictObject({})` when it takes none), so an unknown parameter is 422, not ignored; `limit` accepts decimal digits only, then clamps.

**PATCH** declares `application/json` and `application/merge-patch+json`; `null` for a clearable member is accepted, `null` for a required one is a type error. `If-Match` — `*` or strong tags compared as exact strings; weak or malformed never match — is evaluated in the use case, after the 404 and 403 decisions (RFC 9110 § 13.2.1).

## 4. Auth and the Actor

Verify with jose in both modes — `algorithms`, `issuer`, `audience` and `requiredClaims: ["exp", "sub"]` pinned; `hs256` refused in production by config. `createRemoteJWKSet` caches keys and bounds the fetch. A key-source failure — a timeout, a refused connection, a malformed key set, a non-200 or non-JSON reply — is 503 + `Retry-After`, never 401 (Traps); any other `JOSEError` is 401 with `WWW-Authenticate: Bearer`. Prefer jose: `hono/jwt` checks `exp` only when present. The middleware builds the `Actor` from `sub` (no NUL: it is stored), `tid` and `roles`, sets `Cache-Control: no-store`, and the use case receives it explicitly.

## 5. Persistence

**Transactions.** `PgUnitOfWork.run` opens `db.transaction` (READ COMMITTED), stores the transaction-bound repositories in `AsyncLocalStorage`, and lets nested runs join. Repositories get an accessor that throws once the transaction finished, so a detached promise fails loudly instead of running on a connection back in the pool.

**Errors.** `translate` walks the cause chain (Drizzle wraps pg's error in `DrizzleQueryError`) and maps by SQLSTATE and constraint name: `23505` on `articles_tenant_slug_key` → `already_exists`; classes 08, 53, 57P0x, `57014`, `25P03`/`25P04`, `40001`/`40P01` and socket errors → `unavailable` (503 + `Retry-After`); anything else → a `DatabaseError` with code and constraint only.

**Concurrency.** Writes are conditional and let the database increment `version` (`SET version = version + 1 … RETURNING *`): a guard on `version` for edits, on `status` for transitions. Writing a version computed in memory would let a concurrent edit and transition both produce the same ETag.

**Cursor precision.** Newest-first is a keyset on the UUIDv7 id (`WHERE id < $cursor ORDER BY id DESC LIMIT n + 1`) — no timestamp in the cursor (Traps).

**Pool and session.** `connectionTimeoutMillis` bounds acquire and connect; a pool `error` listener keeps an idle socket failure from crashing the process; every session carries `statement_timeout`, `idle_in_transaction_session_timeout`, `transaction_timeout` (= request deadline) and `TimeZone=UTC`. Instants leave as `toISOString()`, UTC either way; the pin keeps SQL-rendered text (`mode: "string"`) UTC too. Where a pooler or the Worker's client (§ 9) carries no startup options, set them as role defaults (`ALTER ROLE … SET`).

**Migrations.** Hand-written SQL in `migrations/` is the source of truth; `drizzle-kit generate --custom` only appends the journal entry. The release step (`src/app/migrate.ts`) refuses an unset `DATABASE_URL` — `pg` would fall back to the `PG*` defaults — and takes an advisory lock and sets `lock_timeout`, because Drizzle's migrator takes no lock (its transaction and ordering traps are in § 10). The Drizzle schema mirrors columns, keys, indexes and defaults; CI compares the catalog built from the SQL with the catalog built from `generateMigration(generateDrizzleJson(schema))`.

## 6. Reliability recipes

**Idempotency.** One route-level middleware after auth: validate the key (400), hash method, path with query and canonical body, `acquire`, then open the unit of work around `next()` so the use case joins it. A 2xx completes inside that transaction. A thrown 4xx — validation or domain — rolls the handler's writes back and completes in a fresh transaction, so it replays. A 5xx, a lost lease, or an outcome decided by a header outside the hash (406, 412, 415, 428) releases the key: a stored 415 would be replayed to the corrected retry. `purgeExpired` runs on the relay's schedule.

**Outbox relay.** A separate process (any number). One statement claims the aggregate heads (`NOT EXISTS` an earlier pending row, `FOR UPDATE SKIP LOCKED`) and moves `next_attempt_at` forward as the claim lease, so publishing runs outside any transaction with no extra column. Outcomes are fenced on the claim's `attempts`, so a relay whose lease ran out mid-batch cannot overwrite a newer claim (the event may go out twice; consumers dedupe by id). On SIGTERM it stops claiming and hands its unpublished claims back. Gauges: oldest pending age, dead-letter depth.

**Webhooks, queues, cron.** Verify `c.req.bytes()` (Standard Webhooks, ±300 s) before parsing — Hono caches the body, so `c.req.json()` still works afterwards. The inbox claim and the effect share one unit of work; a duplicate, an unknown article, a wrong state or a payload failing its tolerant schema is recorded and acked. Config stops on a secret that is not `whsec_` + base64 of ≥ 24 bytes. The router is registered outside `/v1` auth and OpenAPI; block it at the ingress too. On Workers, queues and cron are `queue()` and `scheduled()` handlers.

## 7. Operability

**Readiness.** One `select 1` at startup latches the `Readiness` object; SIGTERM flips it to draining (503).

**Shutdown** must fit the platform grace (Cloud Run 10 s, Kubernetes 30 s by default); config requires a grace above drain delay + request deadline + pool close + telemetry flush (500 ms each). Node: readiness 503 and `Connection: close` on every response → drain delay (Kubernetes endpoint propagation; 0 on Cloud Run) → `server.close()` → wait for the server at most one deadline, then `pool.end()` and `sdk.shutdown()` at most 500 ms each → exit, with a failsafe `process.exit(1)` just inside the grace. *Why bound each step:* a socket kept alive past its response holds `server.close()` (Traps), and a collector that does not answer holds the flush for the batch exporter's 30 s timeout. Bun: `Bun.serve()` + `await server.stop()` (set `idleTimeout`; it defaults to 10 s). Deno: `await server.shutdown()` before closing the pool. Workers: nothing to drain.

**Logs and telemetry.** pino JSON lines with `request_id`, `trace_id` and `span_id` fields and a redaction list, from a small request-logger middleware. The OpenTelemetry SDK is preloaded with `node --import ./src/app/telemetry.ts` so the pg and undici instrumentations patch modules before they load. Tests never load the SDK, so the API is a no-op.

## 8. Testing and CI

**Harness.** Each test file creates its own database and migrates it from empty through the release step, so files run in parallel on real PostgreSQL. HTTP tests go through a test builder over `app.request()` with real adapters and HS256 tokens.

**Risk-set mechanics.** Concurrent creates and publishes: `Promise.allSettled` — one wins, one outbox row. In-flight idempotency: hold the row with `SELECT … FOR UPDATE` on a pool client, start the request, `vi.waitFor` its key row, send the duplicate. Deadlock: two units each lock one row, meet at a latch, then reach for the other's. Keyset: insert rows in one statement so they share `now()`. Saboteur: wrap the real unit of work and replace `tx.outbox`. Key-source outage: a local key endpoint that answers 503, serves HTML, hangs or is closed.

**Gates.** `tsc` and `tsc -p worker`; `oxlint --type-aware --deny-warnings` with correctness, suspicious, pedantic and perf as errors (off: `prefer-readonly-parameter-types`, as library types like `Context` are mutable; `no-await-in-loop`, as the relay loops in order; size and count rules); `scripts/boundaries.ts`, which fails unless the compiler API is TS 6 and modules were cruised; Vitest; a file snapshot of the OpenAPI document plus `oasdiff breaking` against the base branch.

## 9. Workers + D1 delta

**Workers with Hyperdrive** keeps every PostgreSQL adapter (`worker/index.ts`; wrangler config: `nodejs_compat`, compatibility date ≥ 2025-04-01 so vars reach `process.env`, a Hyperdrive binding `DB`, a cron trigger). Build the app once at module scope; create a `pg` client per request in `provide` and close it with `waitUntil` after the response. Use a Hyperdrive configuration with caching disabled — cached reads ignore writes, so a create followed by a read can 404 and an idempotency lookup can be stale. No readiness route; relay and purge run in `scheduled()`. Tracing is Workers' native (beta) export, not the Node SDK.

**D1 changes the write path.** It has no interactive transactions — `db.transaction()` fails; `batch()` is the only atomic unit. Decide in memory, then send one batch whose statements carry their own guards, and abort the whole batch when a guard fails with a guard row:

```sql
CREATE TABLE batch_guard (kind TEXT NOT NULL, ok INTEGER NOT NULL,
  CONSTRAINT lease CHECK (kind <> 'lease' OR ok = 1),
  CONSTRAINT transition CHECK (kind <> 'transition' OR ok = 1));
-- after each guarded statement in the batch:
INSERT INTO batch_guard (kind, ok) SELECT 'transition', changes() WHERE changes() <> 1;
```

The error names the failed constraint (`CHECK constraint failed: transition`), so the adapter maps it (`transition` → 409, `lease` → lease lost), and every statement of the batch rolls back, including those before the guard. Keep `ON CONFLICT` for uniqueness; with D1 read replication, consistency-sensitive reads use `withSession("first-primary")`. The examples do not ship a D1 adapter.

## 10. Traps

| Symptom | Cause | Fix |
|---|---|---|
| Boundary gate green, nothing checked ("0 modules, 0 dependencies cruised") | dependency-cruiser under TS 7 (no compatible compiler API) | `typescript` aliased to `@typescript/typescript6`; the gate asserts TS 6 and > 0 modules |
| Bodiless POST reaches the handler as `{}` and fails with a 500 | zod-openapi skips body validation unless `required: true` | `required: true` on every body |
| Malformed path id answers 422 | One hook status for every target | 400 when `result.target === "param"` |
| Unknown route or wrong method answers text/plain 404 | Hono defaults | `app.notFound` + `methodNotAllowed`, both rendering problems |
| Valid tokens answer 401 while the identity provider is down | jose throws a plain `JOSEError` for a non-200 or non-JSON key-set reply | `ERR_JOSE_GENERIC`, `ERR_JWKS_TIMEOUT`, `ERR_JWKS_INVALID` and non-JOSE errors → 503 |
| IdP blip turns into a 500 storm | `jwk({ jwks_uri })` fetches per request; a fetch failure is a plain `Error` | jose `createRemoteJWKSet` |
| Client got 503, the write still committed | `hono/timeout` races, it does not cancel | Bound work with `statement_timeout` / `transaction_timeout`; lease > deadline; retries replay |
| A slow upload outlives the deadline | `bodyLimit` registered before `timeout` reads a chunked body before the deadline starts | Register `timeout` first |
| Shutdown ends in the failsafe `exit(1)`, telemetry lost | `server.close()` leaves a socket busy at SIGTERM open for the keep-alive timeout after its response | `Connection: close` while draining |
| Keyset pages repeat rows or never end | Cursor through a millisecond `Date` over microsecond `timestamptz` | Keyset on UUIDv7, or `mode: "string"` timestamps |
| Tampered cursor answers 500 | Unvalidated decode | Decode in the adapter, `malformed` → 400 |
| `CREATE INDEX CONCURRENTLY cannot run inside a transaction block` | Drizzle's migrator runs all pending files in one transaction | Ship `CONCURRENTLY` as a separate release step |
| A merged migration never runs | The migrator skips entries older than the last applied one | Regenerate the entry on top of `main`; test migrations from empty in CI |
| Drift check fails with "there is no parameter $1", or flaps on UNIQUE constraints | drizzle-kit's `pushSchema` drops query parameters and reads constraint columns unordered | Compare catalogs instead (`test/postgres.test.ts`) |
| Logs contain SQL parameters | `DrizzleQueryError` message embeds them | Log the translated `DatabaseError` only |
| Receiver gets two `traceparent` values | Header set by hand and injected by the fetch instrumentation | Make the captured context active; let the instrumentation inject |
| `oxlint --type-aware` uses tens of GB and is killed | No `.gitignore`, `node_modules` not in `ignorePatterns` | List `node_modules` in `ignorePatterns` |
| Node code stops type-checking after adding Workers types | Workers types replace Node's globals (`URL` stops matching `node:url`) | A separate `worker/tsconfig.json` program |
| Worker fails to start: "Disallowed operation called within global scope" | A binding such as `env.DB.connectionString` read at module scope | Read bindings inside handlers (`provide`, `scheduled`) |
| Worker fails to load though it typechecks | `node:crypto` on workerd has no `randomUUIDv7` | UUIDv7 on Web Crypto (`crypto.getRandomValues`) |
| Every Worker request logs "idle database client failed: This socket has been closed" | workerd reports the socket close at `pool.end()` as a pool error | Ignore pool errors once `pool.ending` |
| Request logs are colored text without ids | `hono/logger` | A JSON request-logger middleware |
| "`.openapi` is not a function" at startup, typecheck green | A schema module calling `.openapi()` took `z` from `zod` and loaded before `@hono/zod-openapi` | Import `z` from `@hono/zod-openapi` wherever `.openapi()` is called |
