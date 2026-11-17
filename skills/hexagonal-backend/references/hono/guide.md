# Hono guide

How to build and change a Hono service so that it keeps the rules in `SKILL.md`: the decisions this stack forces, where it breaks a rule without saying so, and its traps. The code is one project, the publishing slice, split by need across `slice.md`, `reliability.md`, `service.md` and `tests.md`. Verified means that on the baseline below it passed typecheck, type-aware lint, the boundary check and its tests on real PostgreSQL, and that its Node, Bun and Workers entries served requests against that database.

## 0. Baseline

Verified 2026-11-18 against the npm registry. Version numbers live only here. Check newer releases with a doc-lookup tool if one is available.

| Package | Version | Note |
|---|---|---|
| Node.js | 26.13.1 | Runs the `.ts` sources directly by stripping types, so the code uses erasable syntax only. `engines` allows 24. |
| PostgreSQL | 18.7 | `uuidv7()`, `transaction_timeout`. |
| hono | 4.13.19 | |
| @hono/zod-openapi, @hono/node-server, @hono/otel | 1.6.3, 2.1.9, 1.3.0 | |
| zod | 4.6.7 | Pinned to the minor: its issue codes and messages are the `errors[]` of every 422. |
| drizzle-orm, drizzle-kit | 0.45.4, 0.31.11 | The stable line, pinned to the minor. |
| pg, jose, pino | 8.23.1, 6.2.17, 10.4.0 | Hyperdrive needs pg 8.16.3 or later. |
| @opentelemetry/sdk-node | 0.301.2 | With api 1.10.0, instrumentation-pg 0.78.0, instrumentation-undici 0.35.1. |
| typescript | 7.0.2 as `tsc`, 6.0.2 as the `typescript` package | 7.0 ships no compiler API. Tools that import `typescript` get `@typescript/typescript6` through an npm alias. |
| dependency-cruiser | 18.8.0 | Supports TypeScript below 7.0 and from 7.1 (§ 9). |
| oxlint, oxlint-tsgolint | 1.94.0, 7.0.2007 | List `node_modules` in `ignorePatterns`, or it lints that too. |
| vitest | 5.1.0 | |
| wrangler | 4.164.0, workerd 1.20261117.1 | Ran the Workers entry over a local Hyperdrive connection, and the D1 batch in § 5. |
| Bun | 1.4.4 | Ran the Node entry: boot, create, list, drain. |
| npm | 11.20.0 | Runs no dependency install script until it is approved. Nothing here needs one. |

Watch list, none adopted: Hono 5 (a release candidate on the `next` tag). Drizzle 1.0 (on the `rc` tag). TypeScript 7.1 (beta), whose compiler API would let the alias go. `@cloudflare/vitest-pool-workers`, which still requires Vitest 4, so the Workers entry is exercised with `wrangler dev` and not in the suite. PostgreSQL 19.

## 1. Decisions

Hono gives routing, middleware and runtime adapters. Every other rule in `SKILL.md` is code you own, so settle these before the first handler.

- **One app factory serves every runtime.** `createApp(deps)` builds the app once, and a `provide` middleware hands each request its services. *Why:* the same app runs on Node with one pool, on Workers with a client per request, and in tests through `app.request()` with no port. Building it per request rebuilds the router and the OpenAPI registry on every call. A long-lived Node process is the canonical runtime: it keeps a warm pool, runs the relay loop and answers probes. Workers is a delta (§ 2).
- **The use case owns the transaction, and a nested `run` joins it.** `uow.run(actor, work)` opens one transaction for the actor's tenant, and `AsyncLocalStorage` carries it. *Why:* the idempotency middleware and the webhook open the unit, and the use case joins it without knowing about either. A nested run for another tenant is refused. *Break when* the store has no interactive transactions (D1, § 5): the unit becomes one batch.
- **A read of a tenant's rows runs in a unit of work too.** *Why:* row-level security shows a query nothing until its transaction names a tenant. The price is three more round trips per read. *Break when* the table carries no policy: the idempotency store and the relay work on the bare pool.
- **READ COMMITTED, and a deadlock answers 503.** *Why:* guards and constraints decide every race (§ 5), so the one serialization-class error left is a deadlock, and the client retries it under its idempotency key. A loop in the server would hold a pooled connection and retry blind. *Break when* database.md chooses SERIALIZABLE: retry the outermost transaction whole, bounded and jittered, never a joined unit.
- **Shape is checked at the edge, rules in the domain, and every failure leaves through one `onError`.** *Why:* a rule lives in one place, the 422 carries `errors[]` either way, and Hono's own 404, 413 and validation responses are not problem documents until you make them so (§ 3).
- **The database bounds the work, not the HTTP timeout.** *Why:* `hono/timeout` answers 503 and cannot cancel the handler, so the write may still commit. `statement_timeout` and `transaction_timeout` do stop it, and the idempotency lease, three times the deadline, outlives both, so the retry replays. *Break when* the work leaves the database: an outbound call takes an `AbortSignal` with the remaining budget.

Failure semantics to keep in mind while coding:

- **`await next()` does not throw when a handler throws an `Error`.** Hono runs `onError` and leaves the error in `c.error` and the rendered response in `c.res`. The idempotency middleware reads both to decide what to store.
- **Throw only `Error`s.** A thrown string makes `next()` itself reject and surfaces as an unrelated "Context is not finalized" error.
- **Nothing is cancelled.** After a client disconnect or a passed deadline, the handler and its transaction run to the end.
- **Work must not outlive its unit.** Transaction-bound ports reach the connection through an accessor that throws once the transaction has ended, so a detached promise fails loudly instead of writing on a connection that went back to the pool.
- **Registration order is execution order**, and a route sees only the middleware registered before it.

## 2. Layout and composition

```text
src/domain/shared/       errors, the Actor and shared ports, event and idempotency ports
src/domain/publishing/   model, ports, use cases
src/inbound/http/        app factory, problems, auth, idempotency middleware, routes, probes
src/inbound/webhooks/    the moderation receiver, on the internal router
src/outbound/postgres/   schema mirror, connection, unit of work, repository, outbox, idempotency store
src/outbound/            clock and ids, the HTTP event publisher
src/app/                 bootstrap: config, logger, telemetry, services; entries main, relay, migrate
worker/                  the Workers program
migrations/              SQL and its journal, outside every layer
```

Composition is plain functions. `buildServices(db)` builds the use cases and stores, `createApp(deps)` receives them through `provide`, and the entrypoints only wire. `c.var` carries `log`, `actor` and `services`, typed by one `AppEnv`. The boundary check lets `src/domain` import nothing outside itself, packages and `node:` built-ins included, counts type-only imports, and keeps `inbound` and `outbound` apart.

**Workers with Hyperdrive** keeps PostgreSQL and every adapter (`worker/index.ts`, `wrangler.jsonc`). The app is built once at module scope, and `provide` creates a `pg` client per request and closes it with `waitUntil`. Hyperdrive pools in transaction mode, which a transaction-local tenant setting is safe under. Use a configuration with query caching disabled: by default it caches reads for a minute and does not invalidate them on a write, and the idempotency lookup is a read. Its origin user must be `app_rw`, which nothing checks at startup there. The client sets no session timeouts, so set them on the role (`ALTER ROLE app_rw SET statement_timeout = …`). There is no readiness route, and the relay pass and the key purge run from `scheduled()`.

## 3. Edge

| # | Layer | Why here |
|---|---|---|
| 1 | `@hono/otel` | The server span covers everything. |
| 2 | request id and request log | Every response carries `X-Request-Id`, synthesized ones included. While draining it adds `Connection: close` (§ 7). |
| 3 | `cors`, `secureHeaders` | CORS decorates preflights and problem responses, and exposes only the headers you list. |
| 4 | `methodNotAllowed` | Turns Hono's 404 for a known path into a 405 with `Allow`. |
| 5 | probes | Before the deadline, the limits and authentication. |
| 6 | `timeout` → 503 | Before `bodyLimit`, so a slow upload meets the deadline (§ 9). |
| 7 | `bodyLimit`, 64 KiB | Before anything reads the body. A stream without `Content-Length` is counted too. |
| 8 | `provide`, then authentication on `/v1/*` | An unknown `/v1` route answers 401 before 404, so routes cannot be probed without a token. |
| 9 | route middleware, validators, handler | zod-openapi runs route middleware, such as idempotency, before its validators. |

**Error pipeline.** The `defaultHook` throws a `ProblemError` for a failed validation. `onError` renders that, a `DomainError` (through a `satisfies Record<ErrorCode, …>` map, so a new kind does not compile until mapped), an `HTTPException`, and anything else as a logged, generic 500. `notFound` and `methodNotAllowed` render the same documents, where Hono's default for both is a text/plain 404. An `HTTPException` keeps its status and headers, with the registry type when exactly one type has that status and `about:blank` otherwise (`http-api.md` § Problem types). Two answers never reach the pipeline: Node rejects a malformed or oversized request head with a plain 400 or 431 before Hono runs, and `cors` answers a refused preflight with a bare 204.

**400 or 422.** A path parameter that cannot be an id is 400, and so is malformed JSON. A content type the route does not declare is 415. Body and query values that fail validation are 422, with `errors[].pointer` (`#` for the whole body) or `errors[].parameter`. Every route declares a strict query object, `z.strictObject({})` when it takes none, so an unknown parameter is a 422 and never silently ignored. `limit` accepts decimal digits only and is then clamped.

**PATCH** declares `application/json` and `application/merge-patch+json`. `null` clears a clearable member and is a type error for a required one. `If-Match` is evaluated in the use case, after the 404 and 403 decisions, and matches only an equal strong tag or `*`.

## 4. Authentication and the Actor

The middleware verifies with jose and pins `algorithms`, `issuer`, `audience` and `requiredClaims: ["exp", "sub"]`. HS256 is for development and tests, and config refuses it in production. `createRemoteJWKSet` caches the key set and bounds each fetch.

A key source that cannot be reached is the service's dependency failing, not the caller's token: it answers 503 with `Retry-After`, never 401. jose reports that failure in several shapes (§ 9), so the middleware maps those to 503 and every other `JOSEError` to 401 with `WWW-Authenticate: Bearer`.

The `Actor` is built from `sub`, `tid` and `roles`. `sub` is stored, so it may not contain NUL. The middleware sets `Cache-Control: no-store`, and every use case receives the actor as its first argument.

## 5. Persistence

**Two roles.** The release step connects as the owning role through `MIGRATION_DATABASE_URL`. The application connects as `app_rw` through `DATABASE_URL`: a login role that neither owns the tables nor has BYPASSRLS, created outside the migrations. The first migration creates schema `app`, the tables, the policy and the grants, and grants only what the code uses. The API's startup round-trip refuses a role with SUPERUSER or BYPASSRLS, because such a role switches row-level security off without an error.

**The tenant is set per transaction.** The unit of work's first statement is `SELECT set_config('app.current_tenant', $1, true)`. It takes a bind parameter, which `SET LOCAL` cannot, and its third argument makes it transaction-local, so a pooled connection carries nothing to its next user. The repository the unit hands out is bound to that tenant and puts `tenant_id = $n` in every query, which the planner needs for the `(tenant_id, id)` index. The policy is the backstop for the query that forgot. The infrastructure tables (`outbox`, `inbox`, `idempotency_keys`) carry no policy.

**Error translation.** `translate` walks the cause chain, because Drizzle wraps pg's error, and maps by SQLSTATE and constraint name. `23505` on `uq_articles_tenant_slug` becomes `already_exists`. Classes 08 and 53, `57P0x`, `57014`, `25P03`, `25P04`, `40001`, `40P01` and socket errors become `unavailable`. Anything else becomes a `DatabaseError` with the code and constraint only, never Drizzle's message, which embeds the SQL and its parameters.

**Concurrency.** Writes are conditional and let the database increment `version` (`SET version = version + 1 … RETURNING *`), guarded on `version` for an edit and on `status` for a transition. A version computed in memory would let a concurrent edit and transition produce the same ETag.

**Cursor.** Newest first is a keyset on the UUIDv7 id (`WHERE tenant_id = $1 AND id < $2 ORDER BY id DESC LIMIT n + 1`). The cursor is `base64url("v1:" + id)`, decoded only in the adapter.

**Pool and session.** `connectionTimeoutMillis` bounds both the wait for a client and the connect. A pool without an `error` listener turns an idle socket failure into an uncaught exception. Every session carries `statement_timeout`, `idle_in_transaction_session_timeout`, `transaction_timeout` (the request deadline) and `TimeZone=UTC` as startup options. The statement bound stays below the transaction bound, because `transaction_timeout` ends the session and not the statement.

**Migrations.** Hand-written SQL under `migrations/` is the source of truth, and `drizzle-kit generate --custom --name=…` creates the empty file and its journal entry. `src/app/migrate.ts` refuses an unset URL, sets `lock_timeout` and takes an advisory lock, because Drizzle's migrator takes none and two release steps at once collide. The Drizzle schema mirrors columns, keys and indexes for typed queries, and a test compares the catalog the SQL built with the one the mirror generates. CHECK constraints, policies and grants live only in the SQL. Lock-safe execution on a live table: database-design `references/migration-patterns.md`, if available.

**D1 changes the write path.** It refuses `BEGIN`, and `batch()` is its only atomic unit. Decide in memory, send one batch whose statements carry their own guards, and let a failed guard abort the batch through a guard row:

```sql
CREATE TABLE batch_guard (kind TEXT NOT NULL, ok INTEGER NOT NULL,
  CONSTRAINT transition CHECK (kind <> 'transition' OR ok = 1));
-- after each guarded statement in the batch:
INSERT INTO batch_guard (kind, ok) SELECT 'transition', changes() WHERE changes() <> 1;
```

The error names the failed constraint (`CHECK constraint failed: transition`), so the adapter can map it, and every statement of the batch rolls back, those before the guard included. The examples ship no D1 adapter.

## 6. Reliability

**Idempotency** is one route-level middleware, after authentication. It validates the key (400), hashes the method, the path with its query and the canonical body, and acquires on the pool. Then it opens the unit of work around `next()`, so the use case joins it and a 2xx is stored in the same transaction as the writes. A thrown 4xx rolls the writes back and is stored in a fresh transaction, so it replays. A 5xx, a lost lease, or an outcome decided by a header outside the hash (406, 412, 415, 428) releases the key: a stored 415 would be replayed to the corrected retry. Taking over an expired lease extends the key's expiry, so the purge cannot delete a key that is running again.

**Outbox relay.** A separate process, any number of them. The claim is a `MATERIALIZED` CTE (§ 9). It takes only the head of each aggregate (`NOT EXISTS` an earlier pending row) with `FOR UPDATE SKIP LOCKED`, and moves `next_attempt_at` forward as the lease, so publishing runs outside any transaction. Outcomes are fenced on the claim's `attempts`: a relay whose lease ran out cannot overwrite a newer claim, the event may go out twice, and consumers dedupe by id. On SIGTERM the relay stops claiming and hands its unpublished claims back. It records the oldest pending age and the dead-letter depth as gauges. The publisher makes the trace context stored with the row active and lets the fetch instrumentation inject `traceparent`. Setting the header by hand as well sends two values.

**Webhooks.** Verify `c.req.bytes()` before parsing. Hono caches the body, so `c.req.json()` still works afterwards. The inbox claim and the effect share one unit of work, scoped to the tenant the signed payload names. A duplicate, an unknown article or a wrong state is a recorded outcome and is acknowledged. A signed payload that fails its schema is logged and acknowledged, because the sender would retry a 4xx until it gave up on the endpoint. Config refuses a secret that is not `whsec_` plus base64 of at least 24 bytes: base64 decoding is lenient, and a mistyped secret would become a short or empty HMAC key. The router sits outside `/v1` authentication and OpenAPI. Block it at the ingress too.

## 7. Operability

**Readiness.** The startup round-trip latches the `Readiness` object, and SIGTERM flips it to draining (503). Liveness answers 200 and checks nothing.

**Shutdown** must fit the platform's grace period, and config refuses a grace that does not exceed drain delay + request deadline + pool close + telemetry flush. The order on Node: readiness 503 and `Connection: close` on every response → the drain delay (endpoint propagation on Kubernetes; 0 where the platform stops routing first) → `server.close()` → wait for the server for at most one deadline → `pool.end()` and the telemetry flush, at most 500 ms each → exit, with a failsafe `process.exit(1)` just inside the grace. Each step is bounded, because a collector that does not answer would hold the flush and a kept-alive socket would hold `server.close()` (§ 9).

**Logs and telemetry.** pino writes JSON lines with `request_id`, `trace_id` and `span_id` and a redaction list. The OpenTelemetry SDK is preloaded with `node --import ./src/app/telemetry.ts`, so the pg and fetch instrumentations patch those modules before the application loads them. `@hono/otel` names server spans by route template. Tests never load the SDK, so the API is a no-op there.

## 8. Tests and gates

**Harness.** Each test file creates its own database and migrates it from empty through the release step, so files run in parallel. Its pool connects as `app_rw`: on the owner or a superuser every tenant test would pass without exercising row-level security. An `owner` pool seeds rows and inspects them. Create fixtures at module scope, because an `afterAll` registered inside a running test never fires.

**How each risk is forced.**

- Concurrent creates and publishes: `Promise.allSettled`, then one winner and one outbox row.
- An in-flight key: hold the row with `SELECT … FOR UPDATE` on the owner pool, start the request, wait for its key row, send the duplicate.
- A dead lease: age the key row through the owner and race three takers.
- A deadlock: two units each lock one row, meet at a latch, then reach for the other's.
- Tenant isolation: a unit of work bound to a raw executor counts rows with no predicate, and a single-connection pool shows that no tenant survives the transaction.
- The relay's claim: a pool whose planner settings force the plan that re-runs a subquery, with a batch of 5 over 200 rows.
- A failed outbox write: wrap the real unit of work and replace `tx.outbox` with a saboteur.
- A key-source outage: a local endpoint that answers 503, serves HTML, hangs or is closed.

**Gates**, in the order CI runs them: `npm run typecheck` (both programs) → `npm run lint` → `npm run boundaries` → `CI=true npm test`, under which a stale `openapi.json` snapshot fails instead of being rewritten → `oasdiff breaking <base>/openapi.json openapi.json --fail-on ERR` against the base branch.

## 9. Traps

Each row was reproduced on this baseline.

| Symptom | Cause | Fix |
|---|---|---|
| The boundary check passes and reports 0 modules | dependency-cruiser reads TypeScript through the compiler API, which 7.0 lacks | `typescript` aliased to `@typescript/typescript6`; the script fails on a zero count |
| A query with no tenant fails with 22P02 on a used connection | A transaction-local setting reads back as an empty string afterwards, and the policy casts it to `uuid` | `NULLIF(current_setting(…, true), '')` in the policy |
| The schema mirror test fails: schema "app" does not exist | drizzle-kit generates `CREATE SCHEMA` only for a `pgSchema` it finds among the exports | Export it |
| One relay pass claims the whole backlog | `id IN (SELECT … LIMIT n FOR UPDATE SKIP LOCKED)`: when the planner re-runs the subquery per row, each run skips the rows this statement already updated, and the window slides | Claim in a `MATERIALIZED` CTE |
| A bodiless POST reaches the handler as `{}` | zod-openapi validates a body only when the route marks it `required: true` | `required: true` on every body |
| Valid tokens answer 401 while the identity provider is down | jose reports a non-200 or non-JSON key-set reply as a generic `JOSEError`, and a refused connection as a `TypeError` | `ERR_JOSE_GENERIC`, `ERR_JWKS_TIMEOUT`, `ERR_JWKS_INVALID` and every non-JOSE error → 503 |
| An identity-provider blip becomes a run of 500s | `hono/jwk` with `jwks_uri` fetches per request, and a failed fetch is a plain `Error` | jose `createRemoteJWKSet` |
| A slow upload outlives the deadline | `bodyLimit` registered before `timeout` reads the chunked body before the deadline starts | Register `timeout` first |
| Shutdown takes six more seconds, or ends in the failsafe `exit(1)` | A socket that was busy at `server.close()` stays open for the keep-alive timeout after its response | `Connection: close` while draining |
| Pages repeat forever or skip rows | A cursor carried through a `Date` keeps milliseconds of a microsecond `timestamptz` | Keyset on the UUIDv7 id, or read the timestamp as text |
| `CREATE INDEX CONCURRENTLY cannot run inside a transaction block` | Drizzle's migrator runs all pending files in one transaction | Ship that statement as its own release step |
| A merged migration never runs, and nothing fails | The migrator skips a journal entry whose `when` is older than the last one applied | A `when` later than every earlier entry; migrate from empty in CI |
| Node code stops type-checking once Workers types are added | Workers types replace Node's globals, and `URL` no longer matches `node:url` | A separate `worker/tsconfig.json` program |
| The Worker fails to start: Disallowed operation called within global scope | A binding such as `env.DB.connectionString` read at module scope | Read bindings inside handlers |
| The Worker fails to load though it typechecks | `node:crypto` on workerd exports no `randomUUIDv7` | UUIDv7 on Web Crypto (`system.ts`) |
| `.openapi is not a function` at startup, typecheck green | A schema module that calls `.openapi()` took `z` from `zod` and loaded before `@hono/zod-openapi` | Import `z` from `@hono/zod-openapi` wherever `.openapi()` is called |
