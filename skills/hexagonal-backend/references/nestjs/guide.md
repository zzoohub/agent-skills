# NestJS 12 stack guide

Read with `SKILL.md`, the contract: this file holds only what NestJS changes about it. The code is one tenant-scoped slice in `examples-domain.md`, `examples-adapters.md` and `examples-bootstrap.md`; every `file=` block there is a complete file of one project that compiles, lints and passes its tests on PostgreSQL 18.

## 0. Version baseline

Verified against the npm registry on 2026-10-08. APIs drift: check the official docs with a doc-lookup tool if one is available.

| Package | Version | Why it matters |
|---|---|---|
| Node.js | 24 LTS; `engines: ^22.13.0 \|\| >=24.11.0` | TypeORM 1.1's floor. `nest new` and generators need 22.22.3+ or 24.15+; a CommonJS app's Jest loads the ESM-only packages from 24.9 |
| TypeScript | `~6.0.3` | 7.0 ships no compiler API (Swagger CLI plugin, dependency-cruiser). 6.0 rejects `baseUrl` (TS5101) and defaults `types` to `[]` |
| `@nestjs/{core,common,platform-express,testing}` | 12.1.2 | ESM-only; Standard Schema params; `useSecurityHeaders()` (12.1); Express drains on close |
| `@nestjs/config` | 12.0.1 | `validationSchema` takes Zod and keeps its parsed output; there is no 11.x |
| `@nestjs/swagger` | 12.0.2 | Converts Standard Schemas; `@ApiResponse({ standardSchema })` |
| `@nestjs/terminus` | 12.1.0 | `shutting_down` + `gracefulShutdownTimeoutMs`; 12.0.x leaks with `withTimeout` |
| `@nestjs/typeorm` + `typeorm` + `pg` | 12.0.2 + 1.1.1 + 8.23.1 | 1.1 throws on `null`/`undefined` in `where` (reads and writes) and on an empty `where` in update/delete |
| `nestjs-cls` + `@nestjs-cls/transactional` + `-adapter-typeorm` | 7.0.1 + 4.0.1 + 2.0.1 | nestjs-cls 5.x peers Nest ≤ 11 |
| `nestjs-pino` + `pino` + `pino-http` | 5.3.1 + 10.4.0 + 11.0.0 | 4.x peers stop at Nest 11 |
| `zod` | 4.6.5 | ≥ 4.2 for Standard JSON Schema (OpenAPI); string lengths count code points, like `char_length` |
| `jose` | 6.2.12 | ESM-only |
| `uuid` | 14.0.2 | Monotonic v7; `crypto.randomUUIDv7()` needs Node ≥ 24.16 |
| `@opentelemetry/sdk-node` | 0.223.0, with instrumentation http 0.223, express 0.71, nestjs-core 0.69, pg 0.75, pino 0.69 | Instrumentations release with the SDK; the ESM loader hook ships in `@opentelemetry/instrumentation` |
| `vitest` + `vite` + `supertest` | 5.0.3 + 8.3.3 + 7.3.1 | Vite 8 (Oxc) emits decorator metadata: no SWC plugin |
| `oxlint` + `oxlint-tsgolint` + `dependency-cruiser` | 1.87.0 + 7.0.2003 + 18.5.0 | oxlint is Nest 12's default linter; tsgolint runs its type-aware rules |

Not used: `nestjs-zod` (peers Nest ≤ 11; the native Standard Schema path replaces it), `ts-node` (unmaintained; migrations run compiled), `madge` (does not install beside TS 6; `no-circular` replaces it), `typeorm-transactional` (last release 2023), `helmet` (`useSecurityHeaders()` sets its defaults). Watch list only: `@nestjs/{idempotency,outbox,locks,resilience,workflows,webhooks,authentication,drizzle}` (0.0.x–0.1.0, first published September–October 2026; `@nestjs/idempotency` writes outside your transaction) and `@nestjs/observe` (a hosted service, not OpenTelemetry). Drizzle 0.45 is the alternative ORM.

## 1. Approach a change in NestJS

Plan with SKILL.md Step 3, then settle these; each is rule → why → when to break.

- **ESM, declared in the manifest.** `"type": "module"`, `nodenext`, `.js` suffixes on relative imports, top-level `await` in entrypoints, `import.meta.dirname` for `__dirname`. *Why:* every `@nestjs/*` 12 package is ESM, and a non-interactive `nest new` scaffolds ESM. *Break:* an existing CommonJS app stays CommonJS (`nest upgrade` does not convert it; `require(esm)` loads Nest 12).
- **The domain is plain TypeScript, wired by factories.** Ports are abstract classes, contract and DI token at once; use cases have no decorators and are built with `useFactory` + `inject`. *Why:* no reflection metadata, so no `import type` trap, and `domain/` imports nothing from `@nestjs/*`, which lets the boundary rule be an allow-list. *Break:* adapters use `@Injectable()` constructor injection, with value imports of every token.
- **One unit of work per command, owned by the use case.** `UnitOfWork.run()` wraps `TransactionHost.withTransaction()` (propagation Required: a nested `run()` joins), retries the whole unit on `40001`/`40P01` and turns transient failures into `unavailable`. Request-path adapters reach the database only through `Db`: `read()` joins the active transaction, `write()` refuses to run without one, `outside()` commits on its own. *Why:* `TransactionHost.tx` falls back to the autocommit `dataSource.manager` whenever no transaction is active, so a write that outlives its unit of work silently commits alone. *Break:* reads may run outside a transaction; the relay and the readiness latch, which never run inside a unit of work, use the `DataSource`.
- **Errors are a closed set, mapped exhaustively, rendered once.** `DomainError.kind` maps to a problem slug through `satisfies Record<ErrorKind, …>`, so a new kind does not compile until mapped; one `renderProblem()` serves the filter and the idempotency interceptor. *Why:* Nest's built-in exceptions carry Nest's body, body-parser errors are `http-errors` objects, and the router's 404 is a `NotFoundException`. *Break:* never.
- **The edge checks shape; the domain owns the rules.** `@Body/@Query/@Param({ schema })` with Zod: `z.strictObject` for our write bodies (`z.object` for a sender's webhook payload, § 6), upper bounds only. Trimming, formats and exact lengths live in the domain, so every inbound adapter gets them. *Why:* one schema validates, types the handler parameter and feeds OpenAPI. *Break:* class-validator DTOs remain supported; keep one style per module.
- **The actor travels explicitly.** A global guard verifies the token and attaches the `Actor`; handlers pass it to the use case with `@CurrentActor()`. *Why:* a principal read from CLS hides the dependency and breaks callers that are not HTTP requests. *Break:* never; CLS carries only the request id and the transaction.
- **Background work runs in its own process.** The relay and the purge run in `worker.ts` (`createApplicationContext`) on the same `CoreModule`. *Why:* independent scaling; batch work never competes with requests for the pool. *Break:* a small service may run the loops in the API process; stop them in `onModuleDestroy` either way.

Failure semantics behind those rules:
- **Nothing is cancelled.** An rxjs `timeout` stops waiting; the handler and its transaction run on. `statement_timeout` bounds each query, the idempotency lease (longer than the deadline) fences a late completion, and work that must happen after commit goes through the outbox.
- **Transactions propagate through AsyncLocalStorage.** Work started inside `run()` keeps that context after `run()` resolves; only the `Db.write` guard stops it reaching the fallback manager. `repo.manager` and an injected `Repository<T>` escape the transaction entirely.
- **Errors leave by throwing.** Guards, interceptors, pipes and handlers throw; middleware calls `next(error)`; Nest routes both to the global filter.
- **Shutdown follows Nest's hook order** (§7): release what requests use only in `onApplicationShutdown`.

| Failure | Response | Logged | Client |
|---|---|---|---|
| Domain rule, state or authorization | 4xx problem | access log only | fixes the request |
| `40001` / `40P01` | the unit of work retries (3 attempts, full jitter), then 503 | yes | retries |
| Connection loss, pool wait, `statement_timeout`, key set unavailable | 503 + `Retry-After` | yes | retries |
| Deadline passed | 503 + `Retry-After`; the handler runs on | yes | retries with the same `Idempotency-Key` |
| Lease lost or key in flight | 409 `idempotency-in-flight` + `Retry-After: 1` | no | retries |
| Anything else | 500, generic detail | once, with `request_id` | reports it |

## 2. Layout and composition

```
src/
  domain/{shared,publishing}/  errors, ports, aggregate, use cases; no framework imports
  inbound/http/                controller, schemas, problem renderer, filter, pipe, guard, interceptors, probes
  inbound/webhooks/            signature guard and webhook controller (internal router)
  outbound/postgres/           entity, repository, Db, unit of work, outbox, inbox, idempotency, relay
  migrations/                  SQL migrations, outside every hex layer
  core.module.ts               config, logging, CLS, DataSource, UoW, clock, ids: global, both processes
  app.module.ts                PublishingModule (ports → adapters, use-case factories) and AppModule
  worker.module.ts, main.ts, worker.ts, configure-app.ts, shutdown.ts, telemetry.ts, config.ts, data-source.ts
```

- `CoreModule.forProcess(name)` is global, like config and logging. A feature module exports nothing, so no feature can inject another's repository; never export `TypeOrmModule`.
- The global filter, guard, pipe and interceptor are `APP_*` providers, not `app.useGlobal*()`: resolved by DI and present in testing modules.
- `configureApp()` is shared by `main.ts` and the test builder, so HTTP tests run the production edge.

## 3. HTTP edge

`configureApp()` order; each layer wraps everything registered after it, including the responses those layers synthesize:
1. `assignRequestId`: echoes a safe `X-Request-Id` or mints one, sets the header, stores `req.id` — the one source pino-http and nestjs-cls read.
2. `useSecurityHeaders()`: Helmet's defaults.
3. `enableCors()`: before anything that can fail, or browsers hide the problem document.
4. `requireJsonBody`: 415 for a non-JSON body, which the parser would skip and the pipe answer with a confusing 422.
5. `useBodyParser("json", { limit: "64kb" })`, with `bodyParser: false` and `rawBody: true` in the factory options: 413 and 400.

Then module middleware (pino-http, CLS), then Nest's chain: guards (auth) → interceptors (deadline, then idempotency) → pipes → handler → filter.

**Error pipeline.** `@Catch()` everything, write through `HttpAdapterHost`, return early on `headersSent`. A Nest `HttpException` or an exposed `http-errors` error keeps its status (`getStatus()`, never its body): a status with exactly one registry slug renders that slug, any other (409, 410, 502, …) an `about:blank` problem titled by the status. Every 401 carries `WWW-Authenticate`, every 503 `Retry-After`. Express has no 405: a 404 that no route took asks Express's route table for the path's methods, while a handler's own `NotFoundException` stays a 404. Log once, in the filter: every 5xx except a probe's.

**400 vs 422.** `StandardSchemaValidationPipe`'s exception factory sees only the issues, so the subclass records the source in `transform()`: a path parameter that cannot be an id is 400; body and query values are 422 with `errors[].pointer` or `errors[].parameter`.

**Deadline.** The global `DeadlineInterceptor` wraps per-route interceptors and answers 503 + `Retry-After` at `REQUEST_TIMEOUT_MS`, below the 60 s idempotency lease.

## 4. Auth and the Actor

- `BearerAuthGuard` is the global `APP_GUARD`; `@Public()` (`Reflector.createDecorator`) exempts probes and webhooks, which verify a signature instead.
- `jose` pins algorithms (`ES256`/`EdDSA` for JWKS; `HS256` only when `JWT_MODE=hs256`, which config refuses in production) and requires `iss`, `aud`, `exp`, `sub`; Zod parses the claims after the signature check. `sub` is bounded: it becomes part of the idempotency scope.
- No `Bearer` credentials get the bare `Bearer` challenge; anything presented goes to jose, and a refusal is 401 with `WWW-Authenticate: Bearer error="invalid_token"`.
- `createRemoteJWKSet` caches keys and refetches on an unknown `kid`, each fetch bounded by `timeoutDuration`. Failing to obtain the key set (timeout, network, non-200, not a key set) is 503: our dependency failed, not the token. jose reports both kinds as `JOSEError`, so the guard wraps the resolver and lets through only the errors raised while matching the token to the keys.
- The guard sets `Cache-Control: no-store` on authenticated responses.

## 5. Persistence

- **TypeORM for the aggregate, SQL for infrastructure tables.** `ArticleEntity` (Data Mapper, never Active Record) serves `findOneBy`, the keyset query and conditional `update`; outbox, inbox, idempotency and relay statements are parameterized SQL, where conditional writes and `SKIP LOCKED` read plainly.
- **Concurrency by the shape of the write.** Unique slug: `23505` mapped by constraint name. Edit: `update(…, { version: expected })`, `affected === 0` → 412 under `If-Match`, else 409 `version-conflict`. Publish and archive: an update guarded by `status = from` that sets `version = version + 1`, then a re-read in the same transaction for the stored truth.
- **Cursor precision.** Keyset on the UUIDv7 id alone (`id < :after ORDER BY id DESC`, index `(tenant_id, id)`); the cursor is `base64url("v1:" + id)`.
- **Pool and session.** `connectTimeoutMS` (pg-pool's `connectionTimeoutMillis`, which also bounds the wait for a free client), `poolSize` × instances within the database's budget, `statement_timeout` (= the request deadline) and `idle_in_transaction_session_timeout` as startup parameters through `extra`, `applicationName` per process.
- **Migrations.** Hand-written SQL in migration classes listed explicitly (globs fail under Vitest); `migrationsTransactionMode: "each"`, so a class with `transaction = false` can build an index `CONCURRENTLY`. The release step runs them compiled before rollout: `node node_modules/typeorm/cli.js migration:run -d dist/data-source.js`, so `data-source.ts` and `migrations/` live in `src/`. `migration:generate --check` in CI proves the entity still matches the SQL, except `CHECK` expressions and index column order (§ 9). Lock-safe execution: database-design.

## 6. Reliability recipes

- **Idempotency** is one interceptor, on the routes that accept a key, after the auth guard (scope = tenant + subject) and inside the deadline. It acquires outside any transaction, then runs the handler and `complete()` in one `uow.run()` that the use case joins, so the stored response commits with the writes. A thrown 4xx is stored in its own transaction; anything else releases the key. It returns a promise through `from()`, so the deadline's unsubscribe cannot skip `complete()` or `release()`; when the deadline answered first, nothing is stored and the transaction rolls back. Nest sets the route status before interceptors run and never after, so a replay can set its own.
- **Outbox relay.** One statement claims each aggregate's head row with `FOR UPDATE SKIP LOCKED` and pushes `next_attempt_at` forward as a lease; publishing happens outside any transaction; failures get a jittered backoff and dead-letter after `maxAttempts`. The worker stops claiming in `onModuleDestroy`, before the pool closes; `outbox.oldest_pending.age` is an observable gauge.
- **Webhooks.** A guard verifies the signature over the raw bytes (`rawBody: true`) before validation; body-parser has already parsed them, so malformed JSON is a 400 before any signature check. The use case claims the `webhook-id` in the inbox inside the effect's transaction. Permanent outcomes are acknowledged, a payload the schema refuses included (logged as a warning): a 4xx would be retried until the sender disables the endpoint. The schema strips unknown members, because senders add fields. A transient failure is 503 so the sender retries.
- **Scheduled jobs** are loops in the worker, not `@Cron` in the API, which fires on every replica: make each job idempotent (the purge is) or take an advisory lock.

## 7. Operability

- **Readiness latch.** `onApplicationBootstrap()` makes one round-trip (`showMigrations()` refuses to open while migrations are pending), then reports local state. Terminus marks `shutting_down` in `beforeApplicationShutdown`, right after `onModuleDestroy`, so readiness answers 503 before the delay starts. Liveness is a plain handler: through `health.check()` it would turn 503 while draining.
- **Shutdown.** `shutDownOnSignal()` replaces `enableShutdownHooks()`: `close(signal)` runs `onModuleDestroy` (stop claiming), `beforeApplicationShutdown` (readiness 503, then `gracefulShutdownTimeoutMs` on SIGTERM while traffic still flows), the HTTP drain (no deadline of its own) and `onApplicationShutdown` (TypeORM closes the pool); telemetry flushes last, under an unref'd failsafe timer. Kubernetes (30 s default grace): `SHUTDOWN_DELAY_MS` ≈ 5000. Cloud Run (10 s grace, traffic stopped before SIGTERM): 0. Delay + deadline + 3 s must fit the grace. Leave `return503OnClosing` off: it flips before the delay and answers live traffic with a non-problem 503.
- **Logging.** nestjs-pino reads `req.id` (`customAttributeKeys.reqId: "request_id"`, `quietReqLogger`), redacts credentials and skips probes; `@opentelemetry/instrumentation-pino` adds `trace_id` and `span_id`, with `disableLogSending` so stdout stays the only log pipeline. `bufferLogs` + `app.useLogger()` route Nest's `Logger` to pino.
- **OpenTelemetry.** `telemetry.ts` is preloaded with `node --import`: it registers the ESM loader hook before the app's modules load (the ESM-only `@nestjs/*` packages are otherwise never patched) and starts `NodeSDK`; exporters come from `OTEL_*` variables. Tests never load it.

## 8. Testing and CI

- **Real PostgreSQL.** `globalSetup` recreates the database and migrates it forward from empty; suites share it sequentially and isolate by random tenant ids. PGlite stores milliseconds and hides precision bugs.
- **The test builder** is `Test.createTestingModule({ imports: [AppModule] })` + `configureApp()` + `init()`: production wiring, no port. Swap adapters with `overrideProvider(Token)`, which replaces only providers the graph already declares.
- **Risk-set mechanics.** Concurrent creates through `Promise.allSettled`; an in-flight key by locking `articles` in an open transaction, so the first request blocks inside its own; a late write after `run()` resolved; a deadlock simulated with `code: "40P01"`; draining by `close("SIGTERM")` on a listening app while polling readiness; a test-only controller that throws Nest's built-in exceptions.
- **Lint.** oxlint `--type-aware --deny-warnings` with correctness, suspicious and perf as errors; each exception carries its reason.
- **Boundary gate.** An allow-list for the domain; `tsPreCompilationDeps` makes `import type` count; CI also fails when zero modules were cruised, which a TypeScript 7 install or a bad config causes silently:

```js file=.dependency-cruiser.cjs
/** Dependencies point inward. DI resolves wiring at runtime, so only this gate catches a leaked import. */
module.exports = {
  forbidden: [
    {
      name: "domain-imports-only-domain",
      comment: "An allow-list: no framework, ORM, driver, SDK or Node built-in; a deny-list always misses one.",
      severity: "error",
      from: { path: "^src/domain/" },
      to: { pathNot: "^src/domain/" },
    },
    {
      name: "adapters-meet-only-through-ports",
      severity: "error",
      from: { path: "^src/(inbound|outbound)/" },
      to: { path: "^src/(inbound|outbound)/", pathNot: "^src/$1/" },
    },
    { name: "no-circular", severity: "error", from: {}, to: { circular: true } },
  ],
  options: {
    tsPreCompilationDeps: true, // `import type` counts: a type-only import of an ORM type is still a leak
    tsConfig: { fileName: "tsconfig.json" },
    doNotFollow: { path: "node_modules" },
  },
};
```

- **OpenAPI.** The HTTP suite writes `openapi.json`; CI fails when it differs from the committed copy, and `oasdiff breaking` compares it with `main`.

## 9. Traps

Each row was reproduced on this baseline.

| Symptom | Cause | Fix |
|---|---|---|
| A guard's 401, the router's 404 or malformed JSON become a 500, even text/html | The filter took an `HttpException` body for a problem document; Nest's is `{ statusCode, message, error }` | Status from `getStatus()`; one renderer normalizes every error |
| A handler's `NotFoundException` becomes a 405; a `ConflictException` an unlogged 500 | The renderer took every 404 for the router's and knew only the registry's statuses | A 404 is the router's only when no route serves the method; other statuses stay, as `about:blank` |
| An identity-provider outage answers 401, and clients drop valid tokens | jose raises a non-200 or unparsable key set as a plain `JOSEError`, like a bad token | Wrap the key resolver: a failed fetch is 503 |
| Valid JSON with `\u0000` answers 500 (SQLSTATE 22021) | `text` cannot store U+0000; `jsonb` refuses it too (22P05) | Refuse it in the domain's value rules |
| A 150-emoji title is "too long" | `String.length` counts UTF-16 units; Zod, JSON Schema and `char_length` count code points | Count `Array.from(value).length` |
| Anyone can sign a webhook | A mistyped `whsec_` secret decodes leniently, even to an empty HMAC key | Check the base64 and length at startup |
| "Nest can't resolve dependencies of X (?, …)" | `import type` of a DI token: the metadata says `Object` | Value imports, or build the class with `useFactory` |
| A write commits though its use case rolled back | `TransactionHost.tx` is the autocommit manager outside a transaction (late work, `repo.manager`, `Repository<T>`) | Every write through a guard that refuses without a transaction |
| Pages repeat or never end on real PostgreSQL | Cursor through a JS `Date` (ms) over `timestamptz` (µs) | Keyset on a UUIDv7 id, or the DB's text value |
| A loop over `query()` results sees `[rows, rowCount]` | TypeORM returns that pair for `UPDATE`/`DELETE … RETURNING` | Destructure `[rows]` |
| An index covers one column only | Property-level `@Index` ignores its column list | Class-level `@Index(name, [columns])` |
| A 405 lists every HTTP method | Nest mounts module middleware with `app.all()` | Skip routes that accept every method |
| Live traffic gets a non-problem 503 (text/html) during the deregistration delay | `return503OnClosing` flips before `beforeApplicationShutdown` | Leave it off; readiness uses Terminus `shutting_down` |
| The drift check stays green after a `CHECK` expression or an index's column order changed | TypeORM compares `CHECK` constraints by name and index columns as a set | Review both in the SQL; rename the constraint or index when its meaning changes |
| Shutdown overruns the drain and exits 1 when no OTLP collector answers | `instrumentation-pino` also sends every record to the Logs SDK, whose default OTLP exporter retries at shutdown until its timeout | `disableLogSending: true`; a stalled trace export is bounded by the failsafe |
| No SIGTERM delay though `gracefulShutdownTimeoutMs` is set | `close()` called without the signal (`INestApplicationContext` declares none) | `close("SIGTERM")` |
| `TS2416` on a `StandardSchemaValidationPipe` subclass | Nest 12's generic `transform` | `override async transform<T>(value: T, metadata): Promise<T>` |
| `SyntaxError` at a decorator in a test file | Vite 8 applies tsconfig decorator settings only to included files | Include `test/` |
| `Cannot access 'X' before initialization` between entities | ESM + decorator metadata on a relation property | Type relations as `Relation<T>` |
| Requests hang when the pool is exhausted | No `connectTimeoutMS`: pg-pool waits forever | Set it |
| `overrideProvider()` cannot supply a missing provider | It replaces only declared providers | Declare the token in a test module, or `overrideModule()` |
| The boundary gate misses a type import | Type-only imports are erased before cruising | `tsPreCompilationDeps: true` |
