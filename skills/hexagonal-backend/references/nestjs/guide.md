# NestJS guide

How to build and change a NestJS service so that it keeps the rules in `SKILL.md`: the decisions this stack forces, where it breaks a rule silently, and its traps. The code is one project, the publishing slice, split by need across `slice.md`, `reliability.md`, `service.md` and `tests.md`. Verified means that on the baseline below it passed typecheck, type-aware lint, the boundary check and its tests on PostgreSQL as the application's role, built, migrated from empty, and ran its API and worker as real processes.

## 0. Baseline

Verified 2026-11-18 against the npm registry. Check newer releases with a doc-lookup tool.

| Package | Version | Note |
|---|---|---|
| Node.js | 26.13.1 | `engines` starts where in-thread loader hooks exist: 22.22.3, 24.11.1, 26.0.0 (§ 7). Also passed on 22.23.4. |
| PostgreSQL | 18.7 | `uuidv7()`, `transaction_timeout`. |
| @nestjs/common, core, platform-express, testing | 12.5.1 | ESM-only. Express 5.3.0 underneath. |
| @nestjs/config, @nestjs/swagger | 12.1.1, 12.1.2 | Config validates with Zod and keeps its output. Swagger reads Standard Schemas. |
| @nestjs/typeorm, typeorm, pg | 12.0.3, 1.1.3, 8.23.1 | TypeORM throws on `undefined` or `null` in a `where` and on an empty `where` in `update`. |
| zod | 4.6.7 | Its issue codes are the `errors[].code` of every 422. |
| jose, nestjs-pino, pino, pino-http | 6.2.17, 5.3.2, 10.4.0, 11.0.0 | |
| uuid | 14.0.3 | Monotonic v7 within a process. Node 22 lacks `crypto.randomUUIDv7()`, and Node 26's is unordered within a millisecond. |
| @opentelemetry/sdk-node | 0.301.2 | With api 1.10.0 and the http 0.301.2, express 0.73.0, pg 0.78.0 and pino 0.71.0 instrumentations. All three signals export to OTLP by default. |
| import-in-the-middle | 3.6.0 | Its in-thread loader hook. |
| typescript | 6.0.3, pinned `~6.0.3` | 7.0 has no compiler API (§ 9), and Swagger peers 5 or 6. |
| dependency-cruiser, oxlint, oxlint-tsgolint | 18.8.0, 1.94.0, 7.0.2007 | |
| vitest, vite, supertest | 5.1.0, 8.3.8, 7.3.2 | Vite emits decorator metadata, so tests need no SWC plugin. |
| npm | 11.20.0 | Install scripts need approval. None is needed here. |

Not used: `nestjs-cls` (the transaction is handed over), `@nestjs/terminus` (probes check no dependency), the Nest OpenTelemetry instrumentation (§ 9), `nestjs-zod`, `helmet` and `ts-node` (Nest and the compiled release step replace them).

Watch list: `@nestjs/idempotency` and `@nestjs/outbox` (0.x), usable only if they complete inside the caller's transaction. A Nest 12 instrumentation. TypeScript 7.1. PostgreSQL 19.

## 1. Decisions

- **ESM, declared in the manifest.** `"type": "module"`, `nodenext`, `.js` suffixes, top-level `await` in entrypoints. *Why:* every `@nestjs/*` package is ESM-only.
- **The domain is plain TypeScript, wired by factories.** A port that Nest injects is an abstract class (`UnitOfWork`, `Clock`, `IdGenerator`, `IdempotencyStore`), because an interface leaves no runtime token. A port the unit of work hands over is an interface. Use cases are built with `useFactory`. *Why:* the domain imports nothing from `@nestjs/*`, so the boundary rule is an allow-list and the `import type` trap cannot bite there. Adapters use `@Injectable()` with value imports of every token.
- **The transaction is handed over, never ambient.** `uow.run(actor, work)` opens a transaction, sets the tenant first and passes `work` a `tx` bound to both. A nested `run` joins through an `AsyncLocalStorage` private to the adapter, and one for another tenant is refused. Reads use a unit of work too, because row-level security shows nothing until the transaction names a tenant. *Why:* a handed-over `tx` cannot run without a tenant or after its transaction. An ambient manager falls back to the pool, where a read sees no row and a write commits alone. *Break when* a context-based transaction library is already in use: set the tenant first in every transaction and make queries outside one fail.
- **The outermost unit retries 40001 and 40P01.** Three attempts with full jitter, then `unavailable`. A joined run never retries. *Why:* only the whole transaction is safe to repeat. Under the idempotency interceptor, the retry re-runs the handler.
- **Errors are a closed set, rendered once.** `DomainError.kind` maps to a problem type through `satisfies Record<ErrorKind, ProblemSlug>`, and one `renderProblem()` serves the filter and the idempotency interceptor. *Why:* Nest's exceptions, body-parser's errors and the router's 404 each arrive in their own shape (§ 3).
- **Background work runs in its own process.** `worker.ts` builds an application context on the same `CoreModule`. *Why:* it scales alone and leaves the pool to requests. *Break when* the service is small: run the loops in the API, stopped in `onModuleDestroy`.

Failure semantics:

- **Nothing is cancelled.** The deadline stops waiting, and the handler and its transaction run on. `statement_timeout` cancels the statement at the deadline, `transaction_timeout` ends a longer transaction, and the 60 s idempotency lease outlasts both.
- **Work must not outlive its unit.** Using `tx` after `run()` resolved fails with `Query runner already released`.

## 2. Layout and composition

```text
src/domain/{shared,publishing}/  errors, Actor, ports, model, use cases
src/inbound/http/                routes, problems, auth, interceptors, probes
src/inbound/webhooks/            the moderation receiver, on the internal router
src/outbound/postgres/           unit of work, repository, outbox, relay, idempotency store
src/migrations/                  SQL, outside every layer
src/*.ts                         config, modules, entrypoints, shutdown, telemetry
```

`CoreModule.forProcess(name)` is global and serves both processes. `PublishingModule` binds ports to adapters and exports nothing. The global filter, guard, pipe and interceptor are `APP_*` providers, so testing modules include them. `configureApp()` serves `main.ts` and the test builder. Migrations live in `src/` because the release step runs them compiled.

The boundary check keeps `src/domain` free of outside imports, `node:` included, keeps `inbound` and `outbound` apart and refuses cycles. Nest wires at runtime, so only this check catches a leaked import.

## 3. Edge

| # | Layer | Why here |
|---|---|---|
| 1 | `assignRequestId` | Every response carries `X-Request-Id`, and pino-http reads `req.id`. |
| 2 | `useSecurityHeaders()`, `enableCors()` | Before anything that can fail, so a browser can read the problem. |
| 3 | `requireJsonBody` | 415. The parser would skip a non-JSON body and the pipe would answer 422. |
| 4 | `useBodyParser("json", { limit: "64kb" })` | 413 and 400. `rawBody: true` keeps the bytes for the webhook guard. |
| 5 | pino-http, guards, `DeadlineInterceptor`, route interceptors, pipe, handler | Nest's order. The deadline (503 at `REQUEST_TIMEOUT_MS`, at most 30 s) wraps idempotency. |

**Error pipeline.** The filter catches everything and returns on `headersSent`. A Nest `HttpException` or an exposed `http-errors` error keeps its status, never its body. A status with exactly one registry type renders that type, any other `about:blank` (`http-api.md` § Problem types). Express has no 405, so a 404 that no route serves asks the route table for the path's methods. The filter logs every 5xx once, except a probe's.

**400 or 422.** The pipe's exception factory sees only the issues, so the subclass adds the source in `transform()`. A path parameter that is not an id, malformed JSON and a foreign cursor are 400. Body and query values are 422, with `errors[].pointer` or `errors[].parameter`. Schemas are strict, so `tenant_id` in a body is a 422. They carry upper bounds only, and the domain owns trimming, formats and exact lengths, so every inbound adapter gets them.

**PATCH** is a merge patch, and `If-Match` is checked in the use case after the 404 and 403 decisions.

## 4. Authentication and the Actor

`BearerAuthGuard` is the global `APP_GUARD`, and `@Public()` exempts probes and webhooks. jose pins the algorithms (ES256 and EdDSA against a JWKS, HS256 only in `hs256` mode, which config refuses in production), the issuer and the audience, and requires `exp` and `sub`. Zod then bounds `sub`, which is stored, and refuses U+0000 in it.

A key source that cannot be reached answers 503, because the service's dependency failed, not the token. jose reports that failure like a bad token (§ 9), so the guard wraps the resolver and treats only `JWKSNoMatchingKey`, `JWKSMultipleMatchingKeys` and `JOSENotSupported` as token faults (401).

The guard sets `Cache-Control: no-store` and attaches the `Actor`, and `@CurrentActor()` passes it to the use case. Nothing ambient carries it, because a queue, a webhook or a test has no request to read.

## 5. Persistence

**Two roles.** The release step connects as the owner through `MIGRATION_DATABASE_URL`, which only `data-source.ts` reads. The application connects as `app_rw`, a login role created outside the migrations that neither owns the tables nor has BYPASSRLS. The migrations create schema `app`, the tables, the policy and only the grants the code uses. Readiness refuses a SUPERUSER or BYPASSRLS role, which would switch row-level security off without an error. TypeORM keeps its `migrations` table in the default schema (§ 9), so the owner needs `CREATE` there and `app_rw` gets `SELECT` on it.

**The tenant is set per transaction.** `inTenantTransaction()` first runs `SELECT set_config('app.current_tenant', $1, true)`. It takes a bind parameter, which `SET LOCAL` cannot, and is transaction-local, so a pooled connection keeps nothing. The policy reads it through `NULLIF(…, '')`, because a used connection reads it back as an empty string. The repository still puts `tenant_id` in every query, since the `(tenant_id, id)` index needs it.

**Error translation.** A `23505` is `already-exists` only on `uq_articles_tenant_slug`, because primary keys raise it too. Classes 08 and 53, `57P0x`, `57014`, `55P03`, `25P03`, `25P04`, `40001`, `40P01`, socket errors and the pool's connect timeout become `unavailable`. Anything else stays a 500, a `42501` included.

**Concurrency.** Writes are conditional and the database increments `version`, guarded on `version` for an edit and on `status` for a transition, and the repository re-reads the row in the same transaction. A version computed in memory would give a concurrent edit and transition the same ETag.

**Cursor.** Newest first is a keyset on the UUIDv7 id, `base64url("v1:" + id)`, decoded only in the adapter.

**Pool and session.** `connectTimeoutMS` bounds the connect and the wait for a free client. Startup parameters set `statement_timeout` to the deadline, `idle_in_transaction_session_timeout`, `TimeZone=UTC` and `transaction_timeout` at 1.5 times the deadline (§ 9). Behind a transaction-mode pooler, set them on the role.

**Migrations.** Hand-written SQL in classes listed in `postgresOptions()`. `migrationsTransactionMode: "each"` lets a class with `transaction = false` build an index `CONCURRENTLY`. Run the release step once per release, from one job. `migrate:check` proves the entity matches the SQL, within its blind spots (§ 9). Lock-safe execution: database-design `references/migration-patterns.md`, if available.

## 6. Reliability

**Idempotency** is one interceptor per route, after the auth guard and inside the deadline. It hashes the method, `originalUrl` and the canonical body, and acquires on the pool. Then it runs the handler and `complete()` in one `uow.run()` that the use case joins, so the stored response commits with the writes. A thrown 4xx rolls back and is stored in a fresh transaction, so it replays. A 5xx releases the key. A takeover of an expired lease extends its expiry, so the purge cannot delete it. The interceptor returns through `from()`, so the deadline's unsubscribe cannot skip completion or release. Nest sets the route's status before interceptors run, so a replay sets its own. A route that also takes `If-Match` must release on 412 and 428, or the corrected retry gets the stored refusal.

**Outbox relay.** The claim is a `MATERIALIZED` CTE (§ 9) over each aggregate's head row, with `FOR UPDATE SKIP LOCKED`. It increments `attempts` and moves `next_attempt_at` forward as the lease, so publishing runs outside any transaction. Outcomes are fenced on `attempts`, so a relay whose lease ran out cannot overwrite a newer claim. Consumers dedupe by id. Failures back off with full jitter and dead-letter after `maxAttempts`, and on stop the relay hands its claims back. Gauges report the oldest pending age and the dead-letter depth. Each row keeps the `traceparent` of its insert for the broker adapter.

**Webhooks.** A guard verifies the signature over `req.rawBody` within 300 s, against every configured secret for rotation. Body-parser has already parsed, so malformed JSON is a 400 before the check. The schema is not strict, because senders add fields. A refused payload is logged and acknowledged, since a 4xx would be retried. The inbox claim and the effect share one unit of work under the tenant the signed payload names. A duplicate, an unknown article or a wrong state answers 204, and a transient failure 503. The router skips bearer auth and OpenAPI, so block it at the ingress.

**Scheduled work** runs as loops in the worker, not as `@Cron` in the API, which fires on every replica. Each job is idempotent or takes an advisory lock.

## 7. Operability

**Readiness** has three states: starting, ready, draining. Its `onApplicationBootstrap` is the startup round-trip: it refuses pending migrations and a bypassing role, then latches. Liveness checks nothing.

**Shutdown.** `shutDownOnSignal()` replaces `enableShutdownHooks()` and passes the signal that `close()`'s interface omits. `close(signal)` runs `onModuleDestroy` (the worker stops claiming), `beforeApplicationShutdown` (readiness 503, then `SHUTDOWN_DELAY_MS` of traffic), the HTTP close, which lets in-flight requests finish, and `onApplicationShutdown` (TypeORM closes the pool). The telemetry flush is last, bounded at 1 s. A failsafe timer exits 1 when the drain overruns. Config refuses a grace below delay + deadline + 3 s. The delay is the time the platform needs to stop routing, 0 where it stops before SIGTERM.

**Logs.** nestjs-pino logs `req.id` as `request_id`, redacts credentials and the webhook signature, and skips probes. `bufferLogs` and `app.useLogger()` route Nest's logger to pino. The pino instrumentation adds `trace_id` and `span_id`.

**Telemetry.** `node --import ./dist/telemetry.js` starts the SDK before the application loads, with import-in-the-middle's in-thread loader hook, which the Express instrumentation needs to patch what the ESM Nest packages import. The server span is named by route, with Express and pg spans beneath it. Tests never load the SDK.

## 8. Tests and gates

**Harness.** The test config derives the application's URL as `app_rw` from the owner's. The global setup creates the role if missing, recreates the database and runs the release step. Every suite connects as `app_rw`, because on the owner most tenant tests still pass and prove nothing. Files run one at a time and isolate by random tenant ids. The test builder serves the production modules through supertest without a port.

**How each risk is forced.**

- A deadlock: work rejecting once with `code: "40P01"`.
- An in-flight key: `LOCK TABLE app.articles IN SHARE MODE` in a second transaction holds the first request.
- Tenant isolation: unfiltered counts inside and outside a tenant transaction, the repository as the owner, a pool of one.
- The relay: a second relay overtaking inside the first one's publish, and a pool of one with the planner settings that re-run a subquery.
- The key source: a local server that answers 503, serves HTML, refuses connections or lacks the key.

**Gates**, in CI order: `npm ci` → `npm run typecheck` → `npm run lint` → `npm run boundaries` → `npm test`, which rewrites `openapi.json` → `git diff --exit-code openapi.json` → `oasdiff breaking <base>/openapi.json openapi.json --fail-on ERR` → `npm run build` → `npm run migrate` on an empty database → `npm run migrate:check`.

## 9. Traps

Each row was reproduced on this baseline.

| Symptom | Cause | Fix |
|---|---|---|
| A 401, the router's 404 or malformed JSON answers `{ message, error, statusCode }` | Nest's exceptions carry Nest's body | Render from the status alone |
| A handler's 404 becomes a 405, or a 410 a 500 | Every 404 taken for the router's, only registry statuses known | Router's 404 only when no route serves the method. Other statuses as `about:blank` |
| A wrong method answers 404 though the path exists | Module middleware is a route accepting every method | Skip such routes when listing `Allow` |
| Valid tokens answer 401 while the identity provider is down | jose reports a 503 or HTML reply as `JOSEError`, a non-key-set as `JWKSInvalid`, a hang as `JWKSTimeout`, a refusal as `TypeError` | Wrap the resolver. Only key-matching errors are token faults |
| `\u0000` in valid JSON answers 500 (22021, or 22P05 in `jsonb`) | PostgreSQL text cannot hold U+0000 | Refuse it in the domain |
| 150 emoji are too long for the model but fit the column | `String.length` counts UTF-16 units. Zod and `char_length` count code points | `Array.from(value).length` |
| Anyone can sign a webhook | A mistyped secret decodes leniently, `"!!!!"` to zero bytes | Check base64 and length at startup |
| `Nest can't resolve dependencies of the NeedsConfig (?)` | `import type` of a DI token | Value imports, or `useFactory` |
| `findOneBy` returns `null` for an existing article, `insert` fails with 42501 | A `Repository<T>` or the `DataSource` runs outside any tenant transaction | Go through the unit of work |
| Pages repeat or never end | A cursor through a `Date` drops the microseconds | Keyset on the UUIDv7 id |
| A loop over `query()` results sees `[rows, count]` | TypeORM returns that pair for `UPDATE` or `DELETE … RETURNING` | Destructure `[rows]` |
| One relay pass claims 201 rows for a batch of 5 | `id IN (SELECT … LIMIT n FOR UPDATE SKIP LOCKED)` re-run per row skips the rows already updated | A `MATERIALIZED` CTE |
| After one slow statement, the next request gets `Connection terminated unexpectedly` | `transaction_timeout` equal to `statement_timeout` ends the session (25P04) | `transaction_timeout` above `statement_timeout` |
| Startup fails with `permission denied for schema public` | `showMigrations()` tries to create TypeORM's table as `app_rw` on an unmigrated database | Run the release step first |
| The first migration fails with the DataSource's `schema` set to `app` | TypeORM puts its table there and never creates the schema | Keep the default schema |
| The drift check passes after a `CHECK` or an index's column order changed | TypeORM compares checks by name and index columns as a set | Review the SQL. Rename what changes meaning |
| The drift check wants a one-column index | A property-level `@Index` ignores its column list | Class-level `@Index` |
| `Cannot access 'AuthorEntity' before initialization` | ESM and decorator metadata on a circular relation | `Relation<AuthorEntity>` |
| `Nest could not find Missing element` | `overrideProvider()` replaces only declared providers | Declare the token first |
| Every request gets 503 `text/html` during the drain delay | `return503OnClosing` flips before any hook | Leave it off |
| Shutdown ends in the failsafe `exit(1)` without a collector | sdk-node 0.301 exports all signals to OTLP, and `shutdown()` waits about 8 s, rejecting when a span exists | Race the flush against 1 s and swallow its rejection |
| Every log record is also exported | The pino instrumentation sends records to the Logs SDK | `disableLogSending: true` |
| No Nest spans | instrumentation-nestjs-core 0.72 skips `@nestjs/core` 12 silently | Rely on HTTP, Express and pg spans |
| The server span is `GET` with no route, or each start prints `DEP0205` on Node 26 | No ESM loader hook, or the deprecated `module.register()` | `register()` from `import-in-the-middle/register-hooks.mjs` |
| The boundary check misses a type-only import | Type imports are erased before the check | `tsPreCompilationDeps: true` |
| The boundary check reports 0 modules | TypeScript 7.0 has no compiler API | Pin TypeScript 6. The script fails on 0 |
