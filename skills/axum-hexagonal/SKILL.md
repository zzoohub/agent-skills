---
name: axum-hexagonal
description: |
  Axum 0.8+ with hexagonal architecture patterns in Rust.
  Use when: building any Rust API — this is the default backend implementation skill.
  Covers: API design (utoipa-axum + OpenApiRouter), domain modeling, ports & adapters, service layer, error handling, testing, sqlx migrations, cursor pagination, healthcheck endpoints.
  Do not use for: database schema design (use database-design skill); non-Rust stacks (use hono/fastapi/nestjs-hexagonal).
---

# Axum + Hexagonal Architecture

**For latest Axum/SQLx APIs, verify against the official docs with a doc-lookup tool if one is available.**

> **SQLx version (0.8/0.9):** `sqlx 0.9.0` is now current; this skill's patterns target **0.8/0.9** and work unchanged on both. The `query!`/`query_as!` macros and `&mut **tx` still apply — string-literal queries satisfy 0.9's new `SqlSafeStr` bound automatically. What 0.9 adds: `SqlSafeStr` (dynamic / non-`'static` query strings must now be wrapped in `AssertSqlSafe(...)`), an optional `sqlx.toml` config file, `sqlx::raw_sql()` for running a string directly against an `Executor`, and removal of the `TransactionManager` re-export. The `.sqlx/` offline-prepare workflow is unchanged.

## Core Philosophy

Separate **business domain** from **infrastructure**. Domain defines *what*; adapters decide *how*.

```
[Inbound Adapter: HTTP handler] → [Port: Service trait] → [Domain Logic]
    → [Port: Repository trait] → [Outbound Adapter: SQLx/Redis/etc.]
```

**Dependencies always point inward.** Domain code never imports axum, sqlx, or any infrastructure crate.

---

## Project Structure

```
src/
├── bin/server/main.rs           # Bootstrap only — no axum/sqlx imports
├── config.rs                    # Config struct, from_env()
├── composition.rs               # `pub type AppAuthorService = ...` aliases
├── domain/
│   └── authors/
│       ├── models.rs            # Author, AuthorName, CreateAuthorRequest
│       ├── error.rs             # CreateAuthorError
│       ├── ports.rs             # AuthorRepository, AuthorService traits
│       └── service.rs           # Service<R, M, N> impl
├── inbound/http/
│   ├── server.rs                # HttpServer wrapper around axum
│   ├── error.rs                 # ApiError → RFC 9457
│   ├── response.rs              # ApiSuccess (data envelope + Location), NoContent
│   └── authors/
│       ├── handlers.rs          # Parse → call service → map response
│       ├── request.rs           # CreateAuthorHttpRequestBody
│       └── response.rs          # AuthorResponseData
└── outbound/
    ├── sqlite.rs                # impl AuthorRepository for Sqlite
    ├── postgres.rs              # impl AuthorRepository for Postgres
    ├── prometheus.rs            # impl AuthorMetrics
    └── email_client.rs          # impl AuthorNotifier
.sqlx/                 # Commit this (one file per query in SQLx 0.8/0.9)
```

**Rule:** `domain/` never imports from `inbound/` or `outbound/`.

---

## Domain Layer

### Models
- Validate on construction (newtype pattern). Private fields, public getters.
- Implement `Display` for newtypes that need `.to_string()` — derive won't work on newtypes.
- No `serde::Deserialize` — Serde bypasses constructors, creating invalid objects.
  Exception: Serde is OK if the model performs no validation (any field value is valid).
- Separate `CreateAuthorRequest` from `Author` — they WILL diverge as app grows.

### Errors
- Exhaustive enum: one variant per business rule violation + `Unknown(anyhow::Error)`.
- Don't panic on unexpected errors — poisons mutexes, surprises other devs. Return errors.
- Domain errors = complete description of what can go wrong in an operation.
- **Domain ports return `Result<T, E>` exclusively — never panic on business errors.** Adapters map infrastructure errors (e.g. sqlx) into domain error types before returning.

### Ports (Traits)

All port traits require: `Clone + Send + Sync + 'static`

```rust
fn method(&self, ...) -> impl Future<Output = Result<T, E>> + Send;
```

> `async fn` in traits doesn't auto-add `Send`. Spell it out for web apps.

Three categories: **Repository** (data), **Metrics** (observability), **Notifier** (side effects).

### Service
- Trait declaring business API + struct `Service<R, M, N>` implementing it.
- Constructor takes all dependencies: `fn new(repo: R, metrics: M, notifier: N) -> Self`.
- Orchestrates: repo → metrics → notifications → return result.
- Handlers call Service, never Repository directly.
- **Evolution path:** Direct calls (repo → metrics → notifier) keep the flow visible in one place — good for simple apps. As side effects grow, the service has to know about every consequence, raising coupling. When this becomes a pain, refactor to domain events: the service emits `AuthorCreatedEvent`, independent handlers react. Adding a new side effect no longer requires touching the service. Trade-off: flow is spread across files, harder to trace.

→ Full domain examples (models, errors, ports, service): `references/examples-domain.md`

---

## Inbound Layer

- **HttpServer wrapper** — use `utoipa_axum::router::OpenApiRouter` instead of `axum::Router`.
  `main` never imports axum. Expose `build_router()` for tests.
  ```rust
  // Each domain module returns its own OpenApiRouter
  pub fn router() -> OpenApiRouter<AppState> {
      OpenApiRouter::new()
          .routes(routes!(list_authors, create_author))
          .routes(routes!(get_author, update_author, delete_author))
  }

  // Top-level composes modules and splits for axum.
  // Mount under exactly `/v1` (the API spec standardizes on `/v1/...` —
  // no extra `/api` segment) so wire paths are `/v1/authors`, `/v1/posts`.
  let (router, api) = OpenApiRouter::with_openapi(ApiDoc::openapi())
      .nest("/v1/authors", authors::router())
      .nest("/v1/posts", posts::router())
      .split_for_parts();
  ```
- **Path params use `{id}` syntax** (not `:id`). Axum 0.8 changed this.
  Wildcards: `{*path}` (not `*path`). Literal braces: `{{` / `}}`.
- **DI via State** — services wrapped in `Arc<AppXService>` inside `AppState`, where `AppXService` is a composition-root type alias (`pub type AppAuthorService = AuthorServiceImpl<Sqlite, Prometheus, EmailClient>;`). Concrete (not `dyn`) because (a) port traits use RPITIT which isn't dyn-compatible in stable Rust, (b) `routes!()` needs concrete handler items, (c) a binary has one production composition — type erasure earns nothing here.
  - **1-2 services:** `AppState { author_service: Arc<AppAuthorService>, ... }`.
  - **3+ services:** same `AppState`, plus `FromRef` impls so each handler extracts only the alias it needs.
  - **When native `dyn` async stabilizes** (in flight): switch the alias to `dyn AuthorService` in one place — handlers don't change.
- **Handlers** annotated with `#[utoipa::path]` for OpenAPI generation. Do three things only: parse input → call service → map response. No SQL.
- **Request types** decoupled from domain — `try_into_domain()` validates into domain type. Derive `ToSchema` + `Deserialize`.
- **Response types** built via `From<&Author>` — never expose domain structs. Derive `ToSchema` + `Serialize`.
- **`ToSchema` / `IntoParams`** are inbound-layer concerns only. Domain models never derive utoipa traits.
- **API errors** mapped manually from domain errors. Never leak domain strings to users.
  `Unknown` → log server-side, return generic message. Use RFC 9457 `ProblemDetail`.
- **API docs** — `utoipa-axum` generates OpenAPI from code via `OpenApiRouter` + `routes!` + `split_for_parts()`. Serve with `utoipa-swagger-ui` or `utoipa-scalar`. Consult `references/api-design.md` for conventions and `references/api-patterns.md` for HTTP patterns.
- **Middleware (Tower layers)** — lives in inbound layer, invisible to domain.
  Layers wrap services: `TraceLayer → TimeoutLayer → CompressionLayer → CorsLayer`.
- **Health checks** live in the inbound layer (not domain), registered outside auth middleware.
  `/health` (liveness) returns 200 unconditionally — **never check dependencies there**: a liveness
  probe that touches a flaky DB cascade-restarts every replica. `/ready` (readiness) acquires from
  the DB pool and returns **503** (not 500) so the load balancer sheds traffic; the pool's
  `acquire_timeout` bounds the probe, so a hung DB fails fast.

### Non-HTTP Inbound Adapters

The inbound layer isn't limited to REST API routes. Any external trigger that drives the domain is an inbound adapter:

| Trigger | Examples | Still HTTP? |
|---------|----------|-------------|
| Task/Job queue | Cloud Tasks, SQS, RabbitMQ | Yes (HTTP callback) or No (consumer) |
| Webhook | Stripe, GitHub, external service callback | Yes |
| Cron/Scheduler | Cloud Scheduler, cron | Yes (HTTP) or No (direct invoke) |
| Event stream | NATS, Kafka, Redis Streams | No (pull/push consumer) |

All follow the same pattern: **parse input → call service → respond.**

Key differences from REST routes:
- Verify caller identity (task queue headers, webhook signatures) instead of user auth.
- Return simple ack (200 OK) — no user-facing response body.
- Must be idempotent — task queues retry on failure.
- Register in HttpServer alongside REST routes.

```
src/inbound/
├── http/            # User-facing REST API
├── tasks/           # Task queue handlers
└── webhooks/        # External service callbacks
```

All three are wired into the same HttpServer. Domain doesn't know which triggered it.

→ Full inbound examples (HttpServer, handlers, request/response, auth, task handlers, API errors): `references/examples-adapters.md`

---

## Outbound Layer

- Wrap connection pool in own type (`Sqlite`, `Postgres`).
- Expose `from_pool()` constructor for tests.
- **Transactions encapsulated in adapter**, invisible to callers.
- Keep transactions short. **No external calls (HTTP, queues) inside tx.**
- **SQLx 0.8/0.9**: `Transaction` and `PoolConnection` no longer implement `Executor` directly.
  Use `&mut **tx` when executing queries inside a transaction. The `query!`/`query_as!`
  macros and `&mut **tx` work identically on both versions — string-literal queries
  satisfy 0.9's new `SqlSafeStr` requirement automatically.
- Map DB-specific errors (e.g. unique constraint codes) to domain error variants.
- Unknown DB errors wrapped with `anyhow` context.
- For complex row types or ORM (diesel, sea-orm), use explicit `to_domain()` mapper in outbound.
  For simple `sqlx::query!` rows, inline mapping in the adapter is fine.

→ Full outbound examples (SQLite, Postgres adapters, row mapper): `references/examples-adapters.md`

### Pagination

**Default to cursor-based pagination.** The pattern flows through all three layers:
- **Domain port**: `list_authors(&self, cursor: Option<&str>, limit: usize) -> Result<CursorPage<Author>, anyhow::Error>`
- **Outbound adapter**: `WHERE (created_at, id) > ($1, $2) ORDER BY created_at, id LIMIT $3`
- **Inbound handler**: return `CursorPageResponse<T>` = `{ data: [...], meta: { limit, next_cursor, has_more } }` (nested `meta`, per the API spec)

Cap `limit` at the handler level (e.g. clamp to 1..100, default 20). The domain doesn't care about max page size — that's a transport concern.

#### Cursor vs Offset

**Cursor** (default) — `WHERE (created_at, id) > ($1, $2) ORDER BY created_at, id LIMIT $3`.
Consistent performance regardless of dataset size. Ideal for feeds, timelines, and large/mutable data. Always use a **composite cursor** `(sort_field, id)`. Cursor is an opaque base64-encoded string in the API; decode in the adapter only.

**Offset** — `LIMIT` / `OFFSET` + `COUNT(*)`.
Use for admin panels and small/static datasets. Provides `total` count for page number UIs. Downside: deeper pages get slower, and row mutations between requests cause duplicates or skips.

### Query Method

| Situation | Method |
|-----------|--------|
| Must exist | `fetch_one` |
| May not exist | `fetch_optional` → map to domain `Option` or error |
| List | `fetch_all` |

### Pool Config

```rust
PgPoolOptions::new()
    .max_connections(10)
    .acquire_timeout(Duration::from_secs(3))  // Always set this
```

---

## Migrations (sqlx)

Migrations are infrastructure — they live in `migrations/` at the crate root, not in any hex layer.

```bash
sqlx migrate add -r create_authors   # migrations/<ts>_create_authors.{up,down}.sql
sqlx migrate run                     # apply via CLI
```

- **Embedded vs CLI — pick one path**: single-binary deploys run `sqlx::migrate!().run(&pool).await?` at startup (the binary carries its migrations); orchestrated platforms run the CLI as a release step before rollout.
- Re-run `cargo sqlx prepare` after every query change; CI verifies with `cargo sqlx prepare --check`.
- Schema *design* belongs to a database-design capability; lock-safe execution against live traffic to a migration capability (e.g. the `postgresql` skill) — this skill only wires the mechanism.

---

## Logging & Tracing

- The `tracing` facade is Rust's stdlib-logging equivalent — macros (`info!`, `warn!`, `error!`) are fine in any layer, domain included. What stays out of the domain is the *subscriber/exporter* (`tracing-subscriber`, OTel pipeline) — that is infrastructure, initialized once in bootstrap.
- Production: `tracing_subscriber` with `EnvFilter` (`RUST_LOG`) + JSON formatter to stdout. Dev: human-readable `fmt`.
- Log **fields, not formatted strings**: `info!(author.id = %id, "author created")` — the string form is unqueryable.
- Correlation: `SetRequestIdLayer`/`PropagateRequestIdLayer` assign and echo `X-Request-Id`; `TraceLayer` spans every request (see the layer stack in `references/examples-adapters.md`).
- Span/metric emission the *domain* needs goes through the `Tracer`/`Meter` ports (below) — keeps OTel crates out of `domain/`.

---

## Security

| Item | Value |
|------|-------|
| Password hashing | `argon2` crate (RustCrypto) |
| JWT library | `jsonwebtoken` crate |
| JWT signing | **ES256/EdDSA** (asymmetric) when multiple services verify; `HS256` only for a single service that both issues and verifies (see `api-design.md`) |
| JWT access token | 15 min |
| JWT refresh (web) | 90 days |
| JWT refresh (mobile) | 1 year |
| Refresh token rotation | **Required** — issue new refresh token on each use, revoke old immediately |
| Refresh token storage | DB table with `jti`, `user_id`, `revoked_at`, `expires_at` |
| CORS | Explicit origins only |

Auth middleware lives in the inbound layer. Domain never handles raw tokens.

- **Document the bearer scheme in OpenAPI.** Register a `SecurityScheme::Http(Bearer, "JWT")` via an `OpenApi` modifier (`#[openapi(modifiers(&SecurityAddon))]`) and apply it to protected operations with `security(("bearer_auth" = []))` in `#[utoipa::path]`. See the `SecurityAddon` example in `references/examples-adapters.md`.
- **Authorization ≠ authentication.** A valid JWT proves *who* is calling, not *whether they may touch this resource*. Add a resource-ownership / policy check (a **policy port**, e.g. `Policy::can_access(user, resource)`) before returning or mutating, or `GET /v1/{resource}/{id}` is an IDOR.
- **Rate limiting** is cross-cutting: terminate it at the API gateway / load balancer, or — if you must enforce it in-process — add a `tower_governor::GovernorLayer` to the `ServiceBuilder`. Its 429 is emitted as `application/problem+json`, like every other error.

---

## Bootstrap (main.rs)

Construct adapters → assemble service → start server. **No axum/sqlx imports.**
Include graceful shutdown with `SIGINT`/`SIGTERM` handling.

```rust
// Construct the pool once — used by both the repository AND the readiness probe.
let pool = SqlitePoolOptions::new().connect(&config.database_url).await?;
let sqlite = Sqlite::from_pool(pool.clone());
// Type inferred as Arc<AppAuthorService> — the composition-root alias.
let service = Arc::new(AuthorServiceImpl::new(sqlite, metrics, notifier));
let server = HttpServer::new(service, pool, HttpServerConfig {
    port: &config.server_port,
    cors_origin: &config.cors_origin,
}).await?;
server.run().await
```

→ Full bootstrap, config, graceful shutdown, and CI examples: `references/examples-bootstrap.md`

---

## Graceful Shutdown

- Use `axum::serve(...).with_graceful_shutdown(signal)`.
- **Always pair with `TimeoutLayer`** — without it, in-flight requests hang forever during drain.
- Handle both `SIGINT` (Ctrl+C) and `SIGTERM` (container orchestration).
- Shutdown logic lives in `HttpServer::run()` — invisible to domain.

→ Full shutdown signal example: `references/examples-bootstrap.md`

---

## Scaling to Multiple Domains

`AppState` holds one concrete composition-root alias per service. When the struct grows beyond ~2 services, add `FromRef` impls so each handler extracts only what it needs:

```rust
// src/composition.rs
pub type AppAuthorService  = AuthorServiceImpl<Sqlite, Prometheus, EmailClient>;
pub type AppBillingService = BillingServiceImpl<Postgres, Prometheus, StripeClient>;

// src/inbound/http/server.rs
#[derive(Clone)]
struct AppState {
    author_service:  Arc<AppAuthorService>,
    billing_service: Arc<AppBillingService>,
}

// Each handler extracts only what it needs via FromRef
impl FromRef<AppState> for Arc<AppAuthorService>  { ... }
impl FromRef<AppState> for Arc<AppBillingService> { ... }
```

**Rules:**
- All merged/nested routers must share the same `AppState` type.
- Handlers extract substates via `State<Arc<AppAuthorService>>` — still hides adapter combination behind one alias name.
- Add `FromRef` impls when you have 3+ services or want per-handler state isolation.
- Reach for `Arc<dyn Trait>` only when you genuinely need type erasure (runtime adapter swap, plugin systems). Until native dyn-async lands, that costs `async-trait`/`trait_variant`. Don't pay it without reason.

→ Full multi-domain example: `references/examples-adapters.md`

---

## Domain Boundaries

1. **Domain = tangible arm of your business** (blogging, billing, identity)
2. **Entities that change atomically → same domain**
3. **Cross-domain operations are never atomic** — service calls or async events
4. **Start large, decompose when friction is observed**

> If you leak transactions into business logic for cross-domain atomicity, your boundaries are wrong.

---

## Enforce the Boundary (CI)

"Domain never imports infrastructure" is a fitness function, not an honor system — guard it on every PR (if the `software-architecture` skill is installed, this is its Stage-8 fitness functions at code level):

- **Compiler as guard (best)**: when the project outgrows one crate, split `domain/` into its own workspace crate whose `Cargo.toml` lists no axum/sqlx/tower deps — violating the boundary becomes a compile error.
- **Until then**, a crude grep gate is honest and sufficient:
  `! grep -rE 'use (axum|sqlx|tower|utoipa)' src/domain/`
- **Baseline CI**: `cargo fmt --check` → `cargo clippy --all-targets -- -D warnings` → `cargo sqlx prepare --check` → `SQLX_OFFLINE=true cargo test`.

→ CI snippet: `references/examples-bootstrap.md`

---

## Reliability & Observability Ports

Cross-cutting infrastructure that must not leak into the domain. Define each as a port; implement as adapters. The architecture-level pattern lives in the software-architecture skill's references (`reliability-patterns.md`, `observability.md`) if installed; otherwise apply standard patterns — outbox, idempotency keys, retry/backoff, structured logging, RED/USE — inline.

| Port | Purpose | Where it lives |
|---|---|---|
| **Outbox** | Atomic state change + message publish — outbox row written in the **same** sqlx transaction as the aggregate | Outbound (combined with the repository adapter) |
| **IdempotencyStore** | Replay safe responses for `Idempotency-Key`-bearing requests | Outbound; called by inbound middleware or application service |
| **Tracer** / **Meter** | OTel span / metric emission. Domain depends on the trait, not on `opentelemetry` crates | Outbound (OTel adapter); no-op adapter for tests |

**Architectural rule**: domain emits **typed domain events** (e.g. an `AuthorEvent` enum — plain data, no `serde_json`); the outbound adapter persists the aggregate AND the outbox rows in a single `sqlx::Transaction` (`&mut **tx`), serializing each event to the JSON payload column in the adapter. A separate **outbox relay** binary polls `outbox` and publishes asynchronously — this is the only safe way to pair a DB write with a broker publish.

**Why not split outbox into its own port?** sqlx's `Transaction` is not `Send` across multiple owners cleanly, and exposing it across two ports either leaks the type or forces a heavyweight `UnitOfWork` abstraction. The pragmatic Rust answer is: the repository adapter is responsible for both writes within its own tx, and a *typed domain event* (e.g. `AuthorEvent`) is what crosses the port boundary — JSON serialization stays in the adapter, keeping `domain/` free of serde-shaped payloads.

**Optimistic concurrency (lost-update protection)**: any aggregate two clients can update concurrently carries a `version` column. Writes are conditional — `UPDATE authors SET name = $1, version = version + 1 WHERE id = $2 AND version = $3`; `rows_affected() == 0` means someone else won the race → return a domain `VersionConflict` error → **409** (or **412** when the client sent `If-Match`/ETag, per `api-design.md`). Idempotency keys protect against the *same* client retrying; the version column protects against *different* clients racing — payments-grade endpoints need both.

→ Adapter examples: `references/examples-adapters.md`

---

## Common Gotchas

| Problem | Cause | Fix |
|---------|-------|-----|
| `Future is not Send` | Async trait method missing `+ Send` | Use `impl Future<Output = ...> + Send` |
| `T is not Clone` | Port trait needs `Clone` bound | Wrap in `Arc` or derive `Clone` |
| `anyhow::Error` not `Clone` | Used in mock results | Wrap mock result in `Arc<Mutex<R>>` |
| Compile error on `sqlx::query!` | Missing `.sqlx/` offline data | Run `cargo sqlx prepare` |
| Handler can't extract `State` | Missing `.with_state(state)` | Add state to router |
| Middleware not running | Layer order wrong | `route_layer` for per-route, `layer` for global |
| Mutex poisoned | Panic while holding lock | Never panic — return errors |
| DB pool exhausted | No acquire timeout | Set `acquire_timeout(Duration::from_secs(3))` |
| `execute(tx)` won't compile | SQLx 0.8/0.9 removed `Executor` on `Transaction` | Use `execute(&mut **tx)` |
| Path `/:id` panics | Axum 0.8 changed syntax | Use `/{id}` (and `{*path}` for wildcards) |
| Handlers not `Sync` | Axum 0.8 requires `Sync` on all handlers | Ensure all captured state is `Sync` |
| `Option<T>` extracts always `None` | Axum 0.8 stricter `Option` extraction | Inner type must impl `OptionalFromRequestParts` |

---

## Quick Reference

| Question | Answer |
|----------|--------|
| Transactions? | Adapter (repository impl), use `&mut **tx` |
| Lost updates? | `version` column + conditional UPDATE; `rows_affected() == 0` → 409/412 |
| Validation? | Domain model constructors |
| Error mapping? | `From<DomainError> for ApiError` in inbound |
| Business orchestration? | Service impl |
| Handler responsibility? | Parse → service → response |
| main responsibility? | Construct adapters → assemble → start |
| DI (1-2 services)? | `State<AppState>` with `Arc<AppXService>` (concrete type alias) fields |
| DI (3+ services)? | `AppState` + `FromRef` impls per service |
| DB row ↔ domain? | `to_domain()` mapper in outbound |
| Test app? | `HttpServer::build_router()` + `tower::oneshot` |
| Health checks? | Inbound layer, not domain |
| Graceful shutdown? | `with_graceful_shutdown()` + `TimeoutLayer` |
| OpenAPI generation? | `utoipa-axum`: `OpenApiRouter` + `routes!` + `split_for_parts()` |
| ToSchema/IntoParams? | Inbound request/response types only, never domain models |

---

## Checklist

### Architecture
- [ ] Domain never imports from inbound/ or outbound/
- [ ] Port traits: `Clone + Send + Sync + 'static`, futures `+ Send`
- [ ] All handlers (HTTP, tasks, webhooks): parse → service → respond
- [ ] Transactions in adapters only, `&mut **tx` for SQLx 0.8/0.9
- [ ] Errors: domain enum → `From<DomainError> for ApiError` → RFC 9457
- [ ] Racing aggregates carry a `version` column; 0-rows-affected writes map to 409/412
- [ ] Boundary enforced in CI: workspace-crate split or grep gate (see Enforce the Boundary)

### Framework
- [ ] Axum wrapped in `HttpServer`, `build_router()` for tests
- [ ] Path params use `{id}` syntax (not `:id`)
- [ ] DI via `State<AppState>` with `Arc<AppXService>` (concrete alias) fields (add `FromRef` for 3+ services)
- [ ] Tower layers: trace, timeout, compression, CORS
- [ ] `acquire_timeout` set on pool
- [ ] Graceful shutdown with `SIGINT`/`SIGTERM` + `TimeoutLayer`
- [ ] Health check endpoint (readiness probe checks DB)

### Testing
**TDD**: Write all tests first as a spec, then implement, then verify all pass. (Tests → Impl → Green)
→ Test mocks (stub, saboteur, spy, noop) and test app helper: `references/examples-bootstrap.md`

### Setup
- [ ] `main.rs` has no axum/sqlx imports
- [ ] `.sqlx/` committed (one file per query in SQLx 0.8/0.9)
- [ ] `Config` struct with `from_env()` in `config.rs`
