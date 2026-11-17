# Axum guide

How to build and change an Axum service so that it keeps the rules in `SKILL.md`: the decisions this stack forces, where it breaks a rule silently, and its traps. The code is one workspace, split by need across `slice.md`, `reliability.md`, `service.md` and `tests.md`. Verified means that on the baseline below it passed every gate in § 8 on real PostgreSQL, and that its release binary served, relayed and shut down against that database.

## 0. Baseline

Verified 2026-11-18 against crates.io, on macOS (aarch64). Version numbers live only here. Check newer releases with a doc-lookup tool if one is available.

| Package | Version | Note |
|---|---|---|
| Rust | 1.100.0, edition 2024 | `rust-version = "1.94"` is sqlx's floor, so resolver 3 picks versions that build on it. |
| PostgreSQL | 18.7 | |
| axum, tower, tower-http | 0.8.9, 0.5.3, 0.7.1 | tower-http enables no layer by default, so list each one as a feature. |
| tokio, tokio-util | 1.53.3 as `~1.53`, 0.7.20 | `~` stays on a long-term-support line, here until September 2027. |
| sqlx, sqlx-cli | 0.9.0 | A query string is a literal or comes from `QueryBuilder`. |
| utoipa, utoipa-axum | 6.0.0, 0.3.0 | Emits OpenAPI 3.1. |
| jsonwebtoken | 12.0.0 | `default-features = false` and exactly one backend, here `aws_lc_rs`. |
| opentelemetry, `_sdk`, `-otlp`, `-http`, tracing-opentelemetry | 0.33.1, 0.34.0 | Move them together, or the graph holds two `opentelemetry` versions. |
| reqwest, aws-lc-rs | 0.13.5, 1.19.0 | aws-lc-rs is the one crypto provider: sqlx TLS, reqwest, jsonwebtoken. It needs a C compiler, not cmake. |
| hmac, sha2 | 0.13.0, 0.11.1 | Move together: both are on digest 0.11. |
| tracing, tracing-subscriber, serde, serde_json, serde_path_to_error | 0.1.44, 0.3.23, 1.0.229, 1.0.154, 0.1.20 | |
| uuid, chrono, base64, secrecy, thiserror, anyhow | 1.29.3, 0.4.45, 0.23.1, 0.10.3, 2.0.21, 1.0.104 | sqlx has no jiff feature, so time is chrono. |
| oasdiff | `tufin/oasdiff` b535e77 | |

Watch list, none adopted: axum 0.9, unreleased. tokio 1.54, not a long-term-support line. A stable `async_fn_traits`, which would allow a closure unit of work (§ 1). PostgreSQL 19.

## 1. Decisions

- **What must happen is written before the commit, in the same transaction.** *Why:* hyper drops the handler future when the client disconnects, and `TimeoutLayer` drops it at the deadline. The code after the pending `.await` never runs, and nothing logs it. The transaction rolls back. Its statement keeps running on the server, so `statement_timeout` sits below the deadline. *Break when* work must outlive the request: spawn it on a `TaskTracker` that shutdown drains.
- **The use case owns the transaction through `begin(&actor)` and `commit()`.** `begin` sets the tenant and returns a `Tx` whose accessors hand out repositories that borrow it. *Why:* stable Rust cannot give a closure runner, `uow.run(actor, async |tx| …)`, a `Send` future: the future of an `AsyncFnOnce` cannot be named or bounded. Dropping an uncommitted `Tx` rolls it back, so every `?` is a rollback. *Break when* database.md chooses SERIALIZABLE: loop from `begin` to `commit` on 40001 and 40P01, bounded and jittered.
- **A write is conditional, and the database increments the version.** `update(&next, read)` and `transition(&next, from)` return the stored row from `RETURNING`, and `None` is the lost race. *Why:* the stored row is the truth for the response, the `ETag` and the event's sequence. A version computed in memory would let a concurrent edit and a transition produce the same `ETag`. *Break when* the write depends on other rows (`SKILL.md` § Write path).
- **Static dispatch, generic over the unit of work.** Async ports return `impl Future + Send`, and handlers are generic over `U: UnitOfWork` through `AppState<U>`, whose `Clone` is written by hand. *Why:* no boxed futures on the request path, and `inbound` never names an adapter. *Break when* an async adapter is chosen at runtime: box its futures, because a trait with async methods is not dyn-compatible.
- **Every failure is an `ApiError`, rendered by one layer.** `IntoResponse` only records the problem in a response extension, and `render_problems` writes the body. *Why:* `type` needs the configured base and `instance` the request path, and `IntoResponse` sees neither.

Failure semantics to keep in mind:

- **A dropped future still runs its destructors.** The transaction rolls back, and a drop guard can release a lease. A destructor cannot await, so `ReleaseOnDrop` spawns the release.
- **Layer order.** In a `ServiceBuilder` the first layer is the outermost. `Router::layer` runs after routing, on every route and the fallback, so `MatchedPath` exists for the trace span.

## 2. Layout and composition

```text
domain/                 model, errors, ports, use cases: a crate of its own
db/dev-roles.sql        the app_rw login, for development and tests
migrations/             SQL, outside every layer
src/inbound/http/       app factory, problems, extractors, auth, idempotency, routes, probes
src/inbound/webhooks.rs the moderation receiver
src/outbound/postgres/  connection, unit of work, repository, outbox relay, idempotency store
src/outbound/           clock, ids, event publisher
src/main.rs             bootstrap with config.rs and telemetry.rs: serve, worker, migrate
tests/api/              one integration-test binary
```

**The domain crate's manifest is the boundary.** The compiler refuses a `use` of a crate it does not list. `scripts/check-boundary.sh` refuses listing one outside its allow-list, and greps `src/inbound` and `src/outbound` for each other's paths. A path built by a macro or re-exported through a third module escapes the grep, so review still looks.

**Composition is in `main`.** It connects one `PgStore`, which implements `UnitOfWork` and `IdempotencyStore`, builds the use cases with `Publishing::new`, and hands both to `http::app`.

**Where the shape differs from `SKILL.md` § Shape.** `begin` and `commit` stand in for `run` (§ 1). The idempotency completion travels as an argument, `Option<Idempotency<'_, Article>>`, because there is no ambient transaction for a middleware to open and a use case to join.

## 3. Edge

Outer to inner:

| # | Layer | Why here |
|---|---|---|
| 1 | drop an unsafe `X-Request-Id`, then `SetRequestId` | The id exists before anything can answer. |
| 2 | `SetSensitiveRequestHeaders`, `TraceLayer` | One span per request, named by route template. `on_failure(())`: a 5xx is logged where its cause is known. |
| 3 | `PropagateRequestId` | Stamps every response, synthesized ones included. |
| 4 | security headers, `if_not_present` | `Cache-Control: no-store` and the rest on every answer. |
| 5 | `CorsLayer` | Decorates every answer below it. |
| 6 | `render_problems` | Writes every problem body. |
| 7 | `TimeoutLayer::with_status_code(503)` | Drops the handler future at the deadline. |
| 8 | `CatchPanicLayer::custom` | A panic becomes a 500 problem. Without it, the connection closes with no bytes. |
| 9 | routes | Probes and webhooks outside authentication. `/v1` behind `route_layer(authenticate)`, idempotency per route, a 64 KiB `DefaultBodyLimit`. |

Compression and rate limits belong at the proxy, for the reasons in § 9.

**Error pipeline.** Handlers take `AppJson`, `AppPath`, `AppQuery` and `RawBody`, never axum's own extractors, whose rejections are text/plain. `fallback` and `method_not_allowed_fallback` make the 404 and 405 problems, and axum still adds `Allow`. `finalize` gives a bare error from a layer a body: the deadline's 503 with `Retry-After`, any other status with the registry type when exactly one type has it, else `about:blank` (`http-api.md` § Problem types).

**400 or 422.** Unreadable is 400: bad JSON, trailing bytes, a path id that is not a UUID, an undecodable cursor, a malformed `Idempotency-Key`. Readable but wrong is 422 with `errors[]`, which point into the body through `serde_path_to_error`. serde reports a missing member at its parent, so the extractor points at the member. `deny_unknown_fields` on every body and query struct makes an unknown name a 422, and the query rejection reads that name from serde's message. Query values are strings parsed by hand, so `limit=abc` is a 422 naming `limit`.

**PATCH** is JSON Merge Patch, with `Option<Option<T>>` fields (§ 9). `If-Match` becomes the versions of its strong tags by exact string comparison, and the use case judges it after the 404 and 403 decisions.

**Limits and deadline.** `DefaultBodyLimit` binds axum's extractors only, so the idempotency middleware passes the same limit to `to_bytes`. From the deadline, 8 s by default, follow `statement_timeout` (three quarters), the idempotency lease (twice) and the drain (one second more).

## 4. Authentication and the Actor

`authenticate` is a `route_layer` on `/v1`, so every route there is protected by default and an unknown path stays 404. It puts the `Actor` in the request extensions, and the `Caller` extractor fails closed with 401 where the layer is missing.

jsonwebtoken's `Validation::new` requires only `exp`, so a token with no `iss` or `aud` passes it. Set the issuer and audience, require `exp`, `iss`, `aud` and `sub`, and set the leeway. `Config` refuses HS256 in production. In JWKS mode the algorithm comes from the matched key's family (EC is ES256, OKP is EdDSA), never from the token.

A key source that cannot be reached answers 503 with `Retry-After`, never 401, because the service's dependency failed, not the token. Keys are fetched with a connect and a total timeout and cached for ten minutes. An unknown `kid` refetches at most every 30 s, and a failed fetch keeps the cached keys.

`sub` is stored and scopes idempotency keys, so an empty one, one over 255 code points or one containing U+0000 is refused.

## 5. Persistence

**Two roles.** The release step connects through `MIGRATION_DATABASE_URL` as the owner of schema `app`. The application connects through `DATABASE_URL` as `app_rw`, a login that owns nothing and cannot bypass RLS. `db/dev-roles.sql` creates it outside the migrations, because a role belongs to the cluster. `PgStore::connect` refuses a SUPERUSER or BYPASSRLS role, to which policies do not apply (§ 9).

**The tenant is set per transaction.** `begin`'s first statement is `SELECT set_config('app.current_tenant', $1, true)`. It takes a bind parameter, which `SET LOCAL` cannot, and it is transaction-local, so a pooled connection carries nothing to its next user. Afterwards the setting reads as `''`, not NULL, so the policy uses `NULLIF(…, '')`. Repositories put the tenant from `PgTx` in every statement, which the planner needs for the `(tenant_id, id)` index. The policy is the backstop, and it refuses an insert for another tenant with 42501. Reads run in a transaction too. Only the idempotency store and the relay use the bare pool, on tables without a policy.

**Queries.** `query!` and `query_as!` check SQL at compile time, against `DATABASE_URL` or the committed `.sqlx/`. Dynamic SQL goes through `QueryBuilder::push_bind`, with sort and filter names from allow-listed enums.

**Error translation.** `db_error` tags a pool timeout, a closed pool, an I/O error and SQLSTATE class 08, 40001, 40P01, 57014, 57P01 and 53300 as `Unavailable`, which answers 503 with `Retry-After`. A unique violation is mapped by constraint name (`uq_articles_tenant_slug`), never by code alone, because the primary key raises 23505 too. Names follow database-design: `{pk,fk,uq,chk}_{table}_{columns}` and `idx_{table}_{columns}`.

**Concurrency.** Each write carries its guard (§ 1), and a lost race is an answer, never a retry.

**Cursor.** Newest first is a keyset on the UUIDv7 id alone. The cursor is base64url of `v1:<id>`, made and decoded only in the store adapter, and a bad one is a 400.

**Pool and session.** Every session sets `statement_timeout`, the idle-in-transaction timeout and `TimeZone=UTC`. `acquire_timeout` also bounds opening a connection, because sqlx has no separate connect timeout. A transaction-mode pooler must support prepared statements.

**Migrations.** Plain SQL, embedded by `sqlx::migrate!` and applied by `articles migrate` as a release step, under sqlx's advisory lock. A file whose first line is `-- no-transaction` may use `CONCURRENTLY`. Lock-safe execution on a live table belongs to database-design `references/migration-patterns.md`, if available.

## 6. Reliability

**Idempotency** is a middleware layered on each idempotent route, inside authentication and scoped to tenant and subject. It buffers the body and hashes the method, the path with its query, and canonical JSON, which a unit test keeps canonical (§ 9). Only this request's insert, or its takeover of an expired lease, grants execution. The handler passes `Idempotency { lease, render }`, and the use case stores the rendered `StoredResponse` in its own transaction, so a replay is byte-identical. A 4xx decided by the body or the state is stored alone afterwards, so a retry replays it. A 5xx, a 408 or 429, and a status decided by a header outside the hash (406, 412, 415, 428) release the key, because a corrected retry must run. A drop guard releases it when the future is dropped. A takeover extends the key's expiry, so the purge spares a live lease.

**Outbox relay.** The `worker` claims with one statement. A `MATERIALIZED` CTE selects pending rows with `LIMIT $1 FOR UPDATE SKIP LOCKED`, and an `UPDATE … FROM` it counts the attempt and pushes `next_attempt_at` forward as the lease. `NOT EXISTS` an earlier pending row of the aggregate makes only heads claimable, so a pass holds one row per aggregate. Publishing runs outside any transaction under half the lease. Both outcomes are fenced on the claim's `attempts`, so a relay whose lease lapsed cannot overwrite a newer claim. Delivery is at least once, and consumers dedupe by event id. Failures back off with full jitter and dead-letter after `max_attempts`, which unblocks the aggregate. The relay records the oldest pending age and the dead-letter count as gauges, and on shutdown stops claiming.

**Webhooks.** The receiver verifies `RawBody` before parsing: HMAC-SHA256 over `id.timestamp.body`, checked by `verify_slice` in constant time against every configured secret, and a timestamp within 300 s by `abs_diff`, which cannot overflow. `Config` refuses a secret under 24 bytes, because an empty key decodes without error and anyone could sign with it. The use case runs as a system actor in the payload's tenant and commits the inbox row with the effect. An unknown article or a wrong state is recorded and answers 204, as a duplicate does. So does a signed payload that does not parse, because a retry cannot fix it. Only `Unavailable` answers 503. The router sits outside `/v1` authentication and OpenAPI. Block it at the ingress.

**Scheduled work.** The worker purges expired keys with an idempotent `DELETE`, so replicas may overlap. A job that must not overlap takes an advisory lock.

## 7. Operability

**Readiness** latches after `PgStore::connect`, the startup round trip, and drops while draining. It never queries, and liveness checks nothing.

**Shutdown** in `serve`: SIGTERM → readiness 503 → sleep `SHUTDOWN_DELAY_MS` while endpoints deregister (0 where the platform stops routing first) → cancel the token `with_graceful_shutdown` awaits → wait at most the deadline plus one second, by which `TimeoutLayer` has ended every request → close the pool → flush telemetry. `Config` refuses a delay plus drain that does not fit `SHUTDOWN_GRACE_MS`. The telemetry flush runs after that budget and was not exercised against an unreachable collector, so leave room for it in the grace period when an exporter is set. The `worker` cancels its loops and waits on their `TaskTracker` under the same bound. axum's `serve` has no timeout for reading a request head, so a proxy must enforce one.

**Logs and telemetry.** `tracing` is the domain's only facade. Logs are JSON. OpenTelemetry layers and exporters are installed only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. The request span takes its parent from the W3C headers and records `trace_id` beside `request_id`. Outbox rows carry the trace context. Only runs without an exporter were verified.

## 8. Tests and gates

**Harness.** One test binary, so one link step. `#[sqlx::test(migrations = false)]` gives each test a database, and `db(owner)` builds it as production does: `db/dev-roles.sql`, the migrations as the owner, and a pool as `app_rw` through the production `PgStore::connect`. On the owner every tenant test would pass without exercising RLS, so `owner` only seeds and inspects. HTTP tests drive the production `app` with `oneshot`.

**How each risk is forced.**

- Duplicate creates and publishes: eight tasks in a `JoinSet`. An in-flight or a dead key: the owner rewrites the key row.
- A deadline: the owner holds the row lock past a 300 ms deadline, and then the retry publishes.
- Tenant isolation: a one-connection pool counts rows with no predicate inside A's transaction, outside any, and after a commit.
- A failed outbox write: a pre-inserted row with the same `(aggregate_id, aggregate_seq)`, so the database is the saboteur.
- The relay: a publisher that bumps `attempts` mid-publish tests the fence. Planner settings that force a subquery rescan, with a batch of 5 over 200 rows, test the claim.
- A key-source outage: a local JWKS endpoint that answers 503.

**Gates**, in CI order, against a PostgreSQL service: `cargo fmt --all --check` → `sh scripts/check-boundary.sh` → `db/dev-roles.sql` and `sqlx migrate run` on an empty database → `cargo sqlx prepare --workspace --check -- --all-targets` → `SQLX_OFFLINE=true cargo clippy --workspace --all-targets -- -D warnings` → `cargo test --workspace`, which fails on a stale `openapi.json` (`UPDATE_OPENAPI=1` rewrites it) → `oasdiff breaking` against the base branch's `openapi.json`, with `--fail-on ERR`.

## 9. Traps

Each row was reproduced on this baseline.

| Symptom | Cause | Fix |
|---|---|---|
| A 400 or 415 is text/plain, and a 404 or 405 is empty | axum's extractors reject outside your error type, and there are no fallbacks | The `App*` extractors and both fallbacks |
| A browser reports a CORS error instead of a 503 | `TimeoutLayer` or `CatchPanicLayer` sits outside `CorsLayer` | CORS outside both |
| A create committed, the client got 503, and its retry got 409 | Work awaited after the commit was dropped at the deadline | Everything that must happen goes in the transaction |
| A committed write answers 406 (tower-http 0.7) | `CompressionLayer` refuses `Accept-Encoding: identity;q=0` after the handler ran | Compress at the proxy |
| Every request answers 500 "Unable To Extract Key!" (tower_governor 0.8) | Its default key is the peer IP, which needs `ConnectInfo` | A principal key, and a bare 429 from `error_handler` for `render_problems` to fill |
| A query without a tenant predicate returns every tenant's rows, with no error | The service connects as a superuser or a BYPASSRLS role | `PgStore::connect` refuses such a role |
| Policies never apply in `#[sqlx::test]`, or its migration fails on a `GRANT` | It migrates as the `DATABASE_URL` role, before the test body | `migrations = false` and the harness |
| One relay pass claims the whole backlog | `id IN (SELECT … LIMIT n FOR UPDATE SKIP LOCKED)`: a plan that runs the subquery per row skips the rows this statement claimed, and the window slides | A `MATERIALIZED` CTE |
| A create and a later read show different timestamps, on Linux only | chrono keeps nanoseconds and sqlx binds microseconds. macOS clocks tick in microseconds | Truncate in the `Clock` |
| A retry with the same members in another order is a key mismatch | A crate in the graph enables serde_json's `preserve_order` | Keep the hash test |
| `null` in a PATCH leaves the field unchanged | `Option<T>` reads `null` as absent | `Option<Option<T>>` with `deserialize_with` |
| Every JWKS token is refused with `InvalidAlgorithm` | `Validation.algorithms` spans two key families | One algorithm, from the key's family |
| jsonwebtoken panics at the first verification: no process-level `CryptoProvider` (12.0) | `default-features = false` and no backend feature | Exactly one of `aws_lc_rs` and `rust_crypto` |
| The database password appears in logs | `PgConnectOptions` derives `Debug` | `secrecy` for the URL, and log host and database |
| No request logs, only errors | `fmt::init` with `env-filter` and no `RUST_LOG` defaults to ERROR | An explicit `EnvFilter` default |
