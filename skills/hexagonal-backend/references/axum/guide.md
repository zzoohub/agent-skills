# Axum guide

How to build and change a hexagonal Axum service so that it honors the contract in `SKILL.md`. This file is the judgment; the code it describes is the publishing slice in `examples-domain.md`, `examples-adapters.md` and `examples-bootstrap.md`, which compiles, passes `clippy -D warnings` and runs its tests on PostgreSQL 18.

## 0. Version baseline

Verified 2026-10-08 against crates.io. Check newer releases with a doc-lookup tool if one is available, and read docs.rs for axum 0.8: GitHub `main` is the unreleased 0.9.

| Crate | Version | Why it matters / floor |
|---|---|---|
| axum | 0.8.9 | `/{id}` paths (`/:id` panics), `Sync` handlers, `Option<T>` extractors need `OptionalFromRequestParts`, native `async fn` extractors |
| tower-http | 0.7.1 | No implicit `tokio` feature: list features. `TimeoutLayer::new` (408) is deprecated: `with_status_code` |
| tower | 0.5.3 | `ServiceBuilder`; `ServiceExt::oneshot` in tests |
| tokio | `~1.53` | LTS until September 2027; `~` stays on the LTS line, `1.53` would float past it |
| tokio-util | 0.7.19 | `CancellationToken`, `TaskTracker` |
| sqlx | 0.9.0 | MSRV 1.94. Runtime and TLS features are separate (`runtime-tokio`, `tls-rustls-aws-lc-rs`); queries take `SqlSafeStr`: literals pass, dynamic SQL goes through `QueryBuilder` |
| utoipa, utoipa-axum | 6.0.0, 0.3.0 | OpenAPI 3.1 by default; `routes!` accepts generic handlers, not turbofish (`routes!(h::<S>)` fails) |
| jsonwebtoken | 11.1.0 | No default crypto backend: enable exactly one (`aws_lc_rs` or `rust_crypto`) or verification panics |
| opentelemetry, opentelemetry_sdk, -otlp, -http | 0.33.0 | Upgrade as one set with tracing-opentelemetry 0.34.0, or the graph holds two `opentelemetry` versions |
| tracing, tracing-subscriber | 0.1.44, 0.3.23 | Features `env-filter`, `json` |
| reqwest | 0.13.5 | `rustls` now means rustls on aws-lc-rs |
| hmac, sha2 | 0.13.0, 0.11.0 | The digest 0.11 pair: move them together |
| serde_path_to_error | 0.1.20 | Paths for 422 JSON Pointers |
| secrecy | 0.10.3 | Redacted `Debug` for secrets |
| uuid, chrono, base64 | 1.27, 0.4.45, 0.23.1 | `now_v7` (uuid MSRV 1.89); sqlx has no jiff feature |

Runtime: Rust ≥ 1.94 (sqlx), CI on 1.99.0, edition 2024 (resolver 3 picks versions that fit `rust-version`), PostgreSQL 18 (`uuidv7()`). One crypto provider, aws-lc-rs, serves sqlx TLS, reqwest and jsonwebtoken; it needs a C compiler, not cmake.

## 1. Approach a change in Axum

Answer SKILL.md Step 3 first. These decisions are where Axum services go wrong.

**1. A cancelled request is a dropped future.** *Rule:* treat every `.await` in a handler as possibly the last; anything that must happen is written before the commit, in the same transaction (outbox row, idempotency completion, inbox row). *Why:* hyper drops the handler future when the client disconnects and `TimeoutLayer` drops it at the deadline; the code after that await never runs, with no error and no log. A dropped `sqlx::Transaction` rolls back, which is what makes this safe, but the server-side statement keeps running until it ends or the connection closes, hence `statement_timeout` below the request deadline. *Break it* only to make work outlive the request: spawn it on a `TaskTracker` that shutdown drains; that survives disconnects, not crashes.

**2. The use case owns the transaction through a port.** *Rule:* `UnitOfWork { type Tx; begin; commit }`, with `Tx = sqlx::Transaction<'static, Postgres>` named by the adapter; repositories, outbox, inbox and idempotency store take `&mut Self::Tx` and never commit. *Why:* one command is one transaction while sqlx stays out of `domain`, and `?` anywhere rolls back. A closure runner (`uow.run(async |tx| …)`) reads better, but stable Rust cannot promise its future is `Send` (`AsyncFnOnce::CallOnceFuture` is not nameable; rustc 1.99 rejects it). *Break it* when database.md chooses SERIALIZABLE: loop `begin..commit` in the use case on 40001/40P01, bounded and jittered.

**3. Read-modify-write locks the row, then writes conditionally.** *Rule:* load the aggregate `FOR UPDATE` in the transaction, change it through its methods, write `… WHERE version = $read AND status = $from`. *Why:* the in-memory aggregate stays the truth for the response, the `ETag` and the outbox payload (`aggregate_seq` = new version); the condition is the guarded transition and the backstop; `If-Match` compares against the locked version (412). *Break it* for hot rows: drop the lock, write optimistically and re-read on conflict.

**4. Static dispatch; state generic over the driving port.** *Rule:* ports are traits returning `impl Future + Send`; handlers are generic over `A: Articles` through `AppState<A>` with a hand-written `Clone`; ports carry no `Clone` supertrait. *Why:* no boxing; `derive(Clone)` would demand `A: Clone`; `Clone` makes a trait non-dyn-compatible; tests can serve any `Articles`. `#[axum::debug_handler]` rejects generic handlers: put it on a temporary concrete copy when a handler error is unreadable. *Break it* for runtime-swappable adapters: `dynosaur` or boxed futures, since async methods are not dyn-compatible on stable.

**5. One error type, rendered by one layer.** *Rule:* every failure is an `ApiError`; `IntoResponse` only records the problem in a response extension; `render_problems` writes the RFC 9457 body. *Why:* `IntoResponse` sees no request and no config, but `type` needs the configured base and `instance` the path; extractor rejections, fallbacks, the panic hook and the deadline all reach that layer. Box the payload: a large `Err` trips clippy's `result_large_err` in every handler.

## 2. Layout and composition

```
Cargo.toml          service crate + [workspace] with domain as a member
domain/             model, errors, ports, use cases: the boundary crate
migrations/         plain SQL, outside every hex layer
src/inbound/http/   app factory, problems, extractors, auth, routes, idempotency, probes
src/inbound/webhooks.rs
src/outbound/       PostgreSQL store and relay, event publisher, clock, ids
src/config.rs  src/telemetry.rs  src/main.rs
tests/api/          one integration-test binary
```

The domain crate's `Cargo.toml` is the boundary: the compiler rejects a `use` of an unlisted crate, and the CI gate rejects listing one. Inside the service crate `inbound` never names `outbound`; only `main` composes concrete types. One image runs three commands: `serve`, `worker` (outbox relay and key purge) and `migrate` (the release step).

## 3. The HTTP edge

**Layer order**, outer to inner, as `Router::layer` applies it to every route and to the fallback (so `MatchedPath` exists for the trace span):

1. drop an unsafe inbound `X-Request-Id`, then `SetRequestId`: the id exists before anything can answer;
2. `SetSensitiveRequestHeaders` (the redaction list) and `Trace` (INFO span, route template, request id, parent trace);
3. `PropagateRequestId`: stamps every response, including those synthesized below;
4. security headers (`if_not_present`, with `Cache-Control: no-store`);
5. CORS — and no in-process compression: tower-http 0.7's `CompressionLayer` answers 406 *after* the handler ran when a client refuses every coding (`Accept-Encoding: identity;q=0`), so a committed write reads as a failure; compress at the proxy or CDN;
6. `render_problems`;
7. `TimeoutLayer::with_status_code(503)`: drops the handler future;
8. `CatchPanicLayer::custom`: a panic becomes a 500 problem instead of a closed connection;
9. routes: `/v1` behind `route_layer(authenticate)`, idempotency layered per route, `DefaultBodyLimit` of 64 KiB.

CORS and request id must wrap every layer that can answer by itself; with timeout or panic handling outside CORS, a browser reports a CORS failure instead of the 503. Rate limit at the gateway; an in-process `tower_governor` layer goes below CORS, renders its 429 in `error_handler`, and keys by principal or a trusted proxy header (its default peer-IP key needs `into_make_service_with_connect_info`).

**Errors.** Handlers use `AppJson`, `AppPath` and `AppQuery`, never axum's `Json`, `Path`, `Query`, whose rejections are text/plain. `AppJson` is hand-written because the 422 needs a JSON Pointer that axum only renders into text: `serde_path_to_error` gives the path, and `Deserializer::end` rejects trailing bytes. `fallback` and `method_not_allowed_fallback` make 404 and 405 problems (axum still adds `Allow`). The timeout's empty 503 becomes a problem with `Retry-After` in the renderer.

**400 or 422.** Unreadable input is 400: bad JSON syntax, a path id that is not a UUID, an undecodable cursor, a malformed `Idempotency-Key`. Readable but wrong is 422 with `errors[]`: wrong types, unknown members (`deny_unknown_fields` blocks mass assignment), missing members (serde reports those at the parent; the extractor points at the member), domain violations. Query parameters arrive as strings and are parsed by hand so `limit=abc` is a 422 naming `limit`. A Merge Patch field is `Option<Option<T>>` with `deserialize_with`: a plain `Option` reads `null` as absent.

**Limits and deadline.** `DefaultBodyLimit` binds axum's extractors only; middleware that reads the body passes the same limit to `to_bytes`. The budget is one inequality, checked by `Config`: statement timeout (¾ of the deadline) < request deadline (8 s) < idempotency lease (2×), and shutdown delay + drain (deadline + 1 s) < the platform's grace.

## 4. Authentication and the Actor

Authenticate in a `route_layer` on the `/v1` router: every route is protected by default, unknown paths stay 404 (route layers run only on matched routes), and inner layers see the actor. The `Caller` extractor reads the `Actor` from the extensions and fails closed with 401 on a route mounted outside the layer. Every use case takes `&Actor`; the repository filters by tenant in every query (foreign → 404) and the use case decides author-or-editor (403).

`jsonwebtoken` requires only `exp` by default and allows 60 s of leeway: require `exp`, `iss`, `aud`, `sub`, and set the leeway. In JWKS mode pin the algorithm from the matched key (EC → ES256, OKP → EdDSA), never from the token, and never list two families in one `Validation`. Fetch keys with connect and total timeouts, cache them, refetch on an unknown `kid` at most every 30 s, keep stale keys when the provider is down, and answer 503 while no key was ever fetched. HS256 is for local runs and tests; `Config` refuses it in production. Hash passwords with argon2 0.6 inside `spawn_blocking`.

## 5. Persistence with sqlx

- **Transactions.** An owned transaction executes on `&mut *tx`; a `tx: &mut Transaction` parameter on `&mut **tx`.
- **Queries.** `query!`/`query_as!` check SQL against the schema at compile time; map rows into one named struct (two `query!` calls in `if`/`else` produce different anonymous types). Commit `.sqlx/` from `cargo sqlx prepare --workspace -- --all-targets`; `prepare --check` in CI needs a live database.
- **Dynamic SQL.** Allowlist sort and filter names as enums and build with `QueryBuilder::push_bind`; formatting input into SQL, or reaching for `AssertSqlSafe`, is a review finding.
- **Errors.** Map 23505 by constraint name (`articles_tenant_slug_key` → `SlugTaken`), never by code alone: the primary key and the idempotency table raise 23505 too. Tag pool timeouts, I/O errors and SQLSTATE 08xxx, 40001, 40P01, 57014, 57P01, 53300 as `Unavailable`: those become 503 + `Retry-After`, everything else 500.
- **Cursor.** Newest first by UUIDv7 id: `WHERE tenant_id = $1 AND id < $2 ORDER BY id DESC LIMIT size + 1`, with `Uuid::max()` for the first page so there is no branch. sqlx binds `timestamptz` as whole microseconds while chrono keeps nanoseconds, so the `Clock` truncates (`trunc_subsecs(6)`) or a POST and a later GET disagree; macOS clocks tick in microseconds and hide this until Linux CI.
- **Sessions and pool.** `PgConnectOptions::options` sets `statement_timeout`, `idle_in_transaction_session_timeout` and `application_name`; log host and database, never the URL. `acquire_timeout` also bounds opening a connection: sqlx has no separate connect timeout. Pool size × instances must fit the connection budget; a transaction-mode pooler must support prepared statements (PgBouncer ≥ 1.21 with `max_prepared_statements`).
- **Migrations.** Plain SQL, embedded by `sqlx::migrate!`, applied by `articles migrate` as a release step. sqlx holds an advisory lock while migrating, so concurrent runs wait; a file starting with `-- no-transaction` may use `CONCURRENTLY`; migrations are forward-only. Lock-safe execution: database-design, if available.

## 6. Reliability recipes

**Idempotency.** `routes!(handler).layer(idempotent)` puts the wrapper on idempotent routes only, inside authentication. It validates the key, buffers the body (it can be read once), hashes method, path (not the route template: a key must not replay another resource) and canonical JSON, then acquires. A `Value` round trip sorts keys only while serde_json's `preserve_order` is off everywhere in the graph; a unit test guards it. The handler passes `Idempotency { lease, render }` to the use case, which stores the rendered response in its own transaction; handlers return the same `StoredResponse`, so replays are byte-identical. A deterministic 4xx is stored in its own transaction; a 5xx or a dropped future releases the key through a drop guard. The purge job never deletes a live lease: a takeover extends `expires_at`.

**Outbox relay.** One statement claims: `UPDATE … SET next_attempt_at = now() + lease WHERE id IN (SELECT … FOR UPDATE SKIP LOCKED) RETURNING …`, where `NOT EXISTS` an earlier pending row of the same aggregate makes only heads claimable. Publishing happens outside any transaction under a timeout; failures back off with full jitter computed in SQL and dead-letter after N attempts, which unblocks the aggregate. `RETURNING` does not follow the subquery's `ORDER BY`, which is fine because a pass holds at most one row per aggregate. The relay records the oldest pending age and the dead-letter count as gauges, and stops claiming on shutdown.

**Webhooks.** Take `Bytes`, verify before parsing: HMAC-SHA256 over `id.timestamp.body` through `Mac::verify_slice` (constant time), every configured secret (rotation), and `abs_diff(now, ts) ≤ 300` (no overflow on hostile input). The inbox row commits with the effect inside the use case; a duplicate, an unknown article or a wrong status is a recorded permanent outcome and gets 204; only `Unavailable` gets 503 so the sender retries. Processing is synchronous here because the effect is one guarded update; record and process later when the handler calls out.

**Scheduled work.** The worker purges expired keys with an idempotent `DELETE`, so overlapping replicas are harmless; a job that must not overlap takes an advisory lock or uses the platform scheduler.

## 7. Operability

**Readiness** is a latch: the pool's `connect_with` is the startup round trip, then `/ready` reads two flags and never touches the database. **Liveness** answers 200. Both sit outside authentication.

**Shutdown** (`main.rs`): SIGTERM → readiness 503 → sleep `SHUTDOWN_DELAY_MS` (Kubernetes, while endpoints deregister; 0 on Cloud Run, which already routes elsewhere) → cancel the token that `with_graceful_shutdown` awaits → bound the drain with `tokio::time::timeout` → close the pool → flush telemetry with a timeout. Cloud Run kills 10 s after SIGTERM, Kubernetes after 30 s by default. The worker cancels its relay and purge loops and waits on its `TaskTracker`. axum 0.8's `serve` has no header-read timeout, so keep it behind a proxy that enforces one.

**Logging and tracing.** `tracing` is the tracer port; the domain only adds `#[instrument]` spans. Bootstrap installs a JSON `fmt` layer with an explicit `info` default (with `env-filter` and no `RUST_LOG`, `fmt::init` prints errors only), and the OTel layer and exporters only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set, so tests export nothing. With OTel on, the request span records `trace_id`, so every log line carries it beside `request_id`. `on_failure(())` keeps the trace layer from logging a 5xx that `ApiError` already logged with its cause.

## 8. Testing and CI

`#[sqlx::test]` creates a database per test and applies `migrations/` from empty; it needs `DATABASE_URL` with CREATEDB at run time, even when compiling offline. Keep integration tests in one binary (`tests/api/main.rs` with modules): one link step, one harness. HTTP tests call the production `app` factory with `oneshot`. Force failures with the database rather than mocks: `JoinSet` races for uniqueness and key acquisition, a row lock held by another transaction to push a request past its deadline, a conflicting outbox row as the Saboteur.

CI runs fmt, the boundary gate, migrations from empty, `cargo sqlx prepare --check`, `clippy --all-targets -D warnings` offline, the tests, and `oasdiff breaking` against the base branch's `openapi.json`. The boundary gate allow-lists the domain's direct dependencies through `cargo tree` and greps `src/inbound` for `outbound::`; the grep misses a path built by a macro or re-exported through a third module, which code review must catch. The OpenAPI snapshot test fails on any drift; regenerate with `UPDATE_OPENAPI=1 cargo test openapi` and review the diff.

## 9. Traps

| Symptom | Cause | Fix |
|---|---|---|
| A 400, 415 or 422 arrives as text/plain; 404/405 have empty bodies | axum's `Json`, `Path`, `Query` reject outside your error type; no fallbacks | Wrapped extractors, `fallback`, `method_not_allowed_fallback` |
| A browser sees a CORS error instead of a 503 or 500 | Timeout or panic handling sits outside `CorsLayer` | Order in § 3 |
| A handler panic closes the connection with 0 bytes | No `CatchPanicLayer` | `CatchPanicLayer::custom` → problem |
| A create committed, the client got 503, its retry got 409 | Must-happen work awaited after the commit; the future was dropped | Everything inside the transaction or the outbox |
| A cancelled request still holds a row lock | Dropping the future does not cancel the server-side statement | `statement_timeout` below the deadline |
| Every JWKS token is rejected with `InvalidAlgorithm` | `Validation::algorithms` lists two families (ES256 and EdDSA) | Pin one algorithm per key |
| `jsonwebtoken` panics on the first verification | No crypto backend feature | Enable exactly one |
| POST and GET return different timestamps on Linux only | chrono nanoseconds vs sqlx's microseconds | Truncate in the `Clock` |
| A retry with the same body gets 422 mismatch | `preserve_order` enabled in the graph | Keep the hash test |
| `if`/`else` has incompatible types `Record` | Each `query!` makes an anonymous struct | `query_as!` into one named struct |
| A conflict on another unique index reads as "slug taken" | 23505 mapped by code only | Map by constraint name |
| `null` in a PATCH leaves the field unchanged | `Option<T>` reads `null` as absent | `Option<Option<T>>` + `deserialize_with` |
| Every request answers 500 once `tower_governor` is added | Its peer-IP key needs `ConnectInfo` | `into_make_service_with_connect_info`, or a principal key |
| Readiness flaps on every replica under load | The probe acquires from the shared pool | Latch at startup |
| The DSN with its password appears in logs | Formatting the URL or `Debug` on config | `secrecy`; log host and database |
| `#[sqlx::test]` panics: `DATABASE_URL must be set` | PostgreSQL test databases need a server | A service container in CI |
| No request logs; only errors | `fmt::init` with `env-filter` defaults to ERROR | Explicit `EnvFilter` default |
| `the trait … is not dyn compatible` | `Clone` supertrait on a port | No `Clone` on ports; `Arc` them |
| `debug_handler` "doesn't support generic functions" | Generic handlers | Use it on a concrete copy |
| Errors name a 152-byte `Err` variant | Large `ApiError` in every `Result` | Box its payload |
| The relay publishes rows in an unexpected order within a pass | `RETURNING` ignores the subquery's `ORDER BY` | One row per aggregate per pass |
