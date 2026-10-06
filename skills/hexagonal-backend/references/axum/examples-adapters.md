# Examples: Adapters

Inbound (HttpServer, handlers, task handlers, webhooks, auth, errors) and outbound (SQLite, Postgres, mapper).

## Table of Contents

1. [Outbound: SQLite Adapter](#outbound-sqlite-adapter)
2. [Outbound: Postgres Adapter (same trait, swap in main)](#outbound-postgres-adapter-same-trait-swap-in-main)
3. [Outbound: Row ↔ Domain Mapper (for complex rows or ORM)](#outbound-row--domain-mapper-for-complex-rows-or-orm)
4. [Inbound: Task Handler (non-HTTP inbound adapter)](#inbound-task-handler-non-http-inbound-adapter)
5. [Composition Root](#composition-root)
6. [Inbound: HttpServer Wrapper](#inbound-httpserver-wrapper)
7. [Inbound: Multi-Service AppState with FromRef](#inbound-multi-service-appstate-with-fromref)
8. [Inbound: Auth Middleware](#inbound-auth-middleware)
9. [Inbound: Request / Response](#inbound-request--response)
10. [Inbound: Handlers](#inbound-handlers)
11. [Inbound: API Error (RFC 9457)](#inbound-api-error-rfc-9457)
12. [Inbound: Response Wrappers](#inbound-response-wrappers)
13. [Outbound: Outbox Adapter (transactional, sqlx)](#outbound-outbox-adapter-transactional-sqlx)
14. [Outbound: Idempotency Store](#outbound-idempotency-store)
15. [Outbound: Tracer Port (OTel)](#outbound-tracer-port-otel)

---

## Outbound: SQLite Adapter

**Schema contract** (the adapter relies on these column shapes):
- `created_at` is `TEXT` holding an RFC 3339 / ISO 8601 UTC timestamp at **fixed precision** (e.g. always `.NNNNNN` microseconds). Fixed precision matters because TEXT comparison is lexicographic — variable-width timestamps would sort incorrectly.
- `id` is `TEXT` holding a **canonical lowercase** UUID (hyphenated). Generated host-side, never by the DB.
- A composite index on `(created_at, id)` backs the keyset scan. The row-value comparison `(created_at, id) > ($1, $2)` is evaluated lexicographically over TEXT, which is exactly why both columns must be stored in sortable canonical form.

```rust
// src/outbound/sqlite.rs
use std::str::FromStr;
use anyhow::{anyhow, Context};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use chrono::{DateTime, SecondsFormat, Utc};
use sqlx::sqlite::SqliteConnectOptions;
use uuid::Uuid;
use crate::domain::authors::error::CreateAuthorError;
use crate::domain::authors::models::{Author, AuthorName, CreateAuthorRequest};
use crate::domain::authors::ports::AuthorRepository;
use crate::domain::pagination::CursorPage;

/// Composite cursor `(created_at, id)` encoded as opaque base64.
/// Stable under concurrent inserts — single-column `id > X` skips/duplicates rows.
fn encode_cursor(created_at: &DateTime<Utc>, id: &Uuid) -> String {
    URL_SAFE_NO_PAD.encode(format!("{}|{}", created_at.to_rfc3339_opts(SecondsFormat::Micros, true), id))
}

fn decode_cursor(raw: &str) -> anyhow::Result<(DateTime<Utc>, Uuid)> {
    let decoded = String::from_utf8(URL_SAFE_NO_PAD.decode(raw)?)?;
    let (ts, id) = decoded.split_once('|').context("invalid cursor")?;
    Ok((DateTime::parse_from_rfc3339(ts)?.with_timezone(&Utc), Uuid::parse_str(id)?))
}

#[derive(Debug, Clone)]
pub struct Sqlite { pool: sqlx::SqlitePool }

impl Sqlite {
    pub async fn new(path: &str) -> anyhow::Result<Self> {
        let pool = sqlx::SqlitePool::connect_with(
            SqliteConnectOptions::from_str(path)?
                .pragma("foreign_keys", "ON"),
        ).await.with_context(|| format!("failed to open db at {}", path))?;
        Ok(Self { pool })
    }
    pub fn from_pool(pool: sqlx::SqlitePool) -> Self { Self { pool } }
}

impl AuthorRepository for Sqlite {
    async fn create_author(&self, req: &CreateAuthorRequest) -> Result<Author, CreateAuthorError> {
        // SQLx 0.7+: Transaction no longer implements Executor itself; it derefs
        // to the connection, so pass &mut *tx (&mut **tx only for a `&mut Transaction` param).
        let mut tx = self.pool.begin().await.context("failed to start tx")?;
        let id = Uuid::new_v4();
        sqlx::query!("INSERT INTO authors (id, name) VALUES ($1, $2)",
            id.to_string(), req.name().to_string())
            .execute(&mut *tx).await  // owned tx: &mut *tx (&mut **tx does not compile here)
            .map_err(|e| {
                // is_unique_violation() abstracts over the backend's native code
                // (SQLite 2067, Postgres 23505) — same call works for both adapters.
                if e.as_database_error().map_or(false, |d| d.is_unique_violation()) {
                    return CreateAuthorError::Duplicate { name: req.name().clone() };
                }
                anyhow!(e).context(format!("failed to save author {:?}", req.name())).into()
            })?;
        tx.commit().await.context("failed to commit tx")?;
        Ok(Author::new(id, req.name().clone()))
    }

    async fn find_author(&self, id: &Uuid) -> Result<Option<Author>, anyhow::Error> {
        let id_str = id.to_string();
        let row = sqlx::query!("SELECT id, name FROM authors WHERE id = $1", id_str)
            .fetch_optional(&self.pool).await.context("failed to query author")?;
        match row {
            Some(r) => Ok(Some(Author::new(
                Uuid::parse_str(&r.id)?,
                AuthorName::new(&r.name).map_err(|e| anyhow!(e))?,
            ))),
            None => Ok(None),
        }
    }

    async fn list_authors(&self, cursor: Option<&str>, limit: usize) -> Result<CursorPage<Author>, anyhow::Error> {
        // Fetch limit+1 to detect whether more rows exist beyond the page boundary.
        let fetch_limit = (limit + 1) as i64;

        // `created_at` is TEXT in SQLite; the `as "created_at: DateTime<Utc>"`
        // override tells SQLx to decode it into a typed `DateTime<Utc>` rather
        // than a bare String. Bind the cursor in the schema contract's fixed
        // format (microseconds, `Z` suffix) so the bound value matches the stored
        // TEXT for the lexicographic compare — plain `to_rfc3339()` varies the
        // fraction width and emits `+00:00`, which mis-sorts against `...Z`.
        let rows = if let Some(raw) = cursor {
            let (cursor_at, cursor_id) = decode_cursor(raw)?;
            let cursor_at_str = cursor_at.to_rfc3339_opts(SecondsFormat::Micros, true);
            let cursor_id_str = cursor_id.to_string();
            sqlx::query!(
                r#"SELECT id, name, created_at as "created_at: DateTime<Utc>"
                   FROM authors
                   WHERE (created_at, id) > ($1, $2)
                   ORDER BY created_at ASC, id ASC LIMIT $3"#,
                cursor_at_str, cursor_id_str, fetch_limit,
            )
            .fetch_all(&self.pool).await.context("failed to list authors")?
        } else {
            sqlx::query!(
                r#"SELECT id, name, created_at as "created_at: DateTime<Utc>"
                   FROM authors
                   ORDER BY created_at ASC, id ASC LIMIT $1"#,
                fetch_limit,
            )
            .fetch_all(&self.pool).await.context("failed to list authors")?
        };

        // Boundary: if we got the extra row, there are more pages.
        // Drop the overflow row; cursor points at the LAST RETURNED row so
        // the next page starts AFTER it (no duplicate, no skip).
        let has_more = rows.len() > limit;
        let truncated: Vec<_> = rows.into_iter().take(limit).collect();

        let next_cursor = if has_more {
            truncated.last().and_then(|r| {
                let id = Uuid::parse_str(&r.id).ok()?;
                Some(encode_cursor(&r.created_at, &id))
            })
        } else {
            None
        };

        let items: Vec<Author> = truncated
            .into_iter()
            .map(|r| Ok(Author::new(
                Uuid::parse_str(&r.id)?,
                AuthorName::new(&r.name).map_err(|e| anyhow!(e))?,
            )))
            .collect::<Result<Vec<_>, anyhow::Error>>()?;

        Ok(CursorPage { items, next_cursor, has_more })
    }
}
```

## Outbound: Postgres Adapter (same trait, swap in main)

```rust
// src/outbound/postgres.rs
use std::time::Duration;
use anyhow::{anyhow, Context};
use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;
use crate::domain::authors::error::CreateAuthorError;
use crate::domain::authors::models::{Author, CreateAuthorRequest};
use crate::domain::authors::ports::AuthorRepository;

#[derive(Debug, Clone)]
pub struct Postgres { pool: sqlx::PgPool }

impl Postgres {
    pub async fn new(url: &str) -> anyhow::Result<Self> {
        let pool = PgPoolOptions::new()
            .max_connections(10)
            .acquire_timeout(Duration::from_secs(3))
            .connect(url).await
            .with_context(|| format!("failed to connect to {}", url))?;
        Ok(Self { pool })
    }
    pub fn from_pool(pool: sqlx::PgPool) -> Self { Self { pool } }
}

impl AuthorRepository for Postgres {
    async fn create_author(&self, req: &CreateAuthorRequest) -> Result<Author, CreateAuthorError> {
        let id = Uuid::new_v4();
        sqlx::query!("INSERT INTO authors (id, name) VALUES ($1, $2)",
            id, req.name().to_string())
            .execute(&self.pool).await
            .map_err(|e| {
                if e.as_database_error().map_or(false, |d| d.is_unique_violation()) {
                    CreateAuthorError::Duplicate { name: req.name().clone() }
                } else {
                    anyhow!(e).into()
                }
            })?;
        Ok(Author::new(id, req.name().clone()))
    }
    // find_author, list_authors omitted — same pattern as SQLite
}
```

## Outbound: Row ↔ Domain Mapper (for complex rows or ORM)

```rust
// src/outbound/mapper.rs — use when rows have many fields or when using diesel/sea-orm
#[derive(Debug, sqlx::FromRow)]
pub struct AuthorRow { pub id: String, pub name: String }

impl AuthorRow {
    pub fn to_domain(self) -> Result<Author, anyhow::Error> {
        Ok(Author::new(
            Uuid::parse_str(&self.id)?,
            AuthorName::new(&self.name).map_err(|e| anyhow!(e))?,
        ))
    }
}

// Usage in adapter:
let row: Option<AuthorRow> = sqlx::query_as!(AuthorRow,
    "SELECT id, name FROM authors WHERE id = $1", id_str)
    .fetch_optional(&self.pool).await?;
row.map(|r| r.to_domain()).transpose()
```

---

## Inbound: Task Handler (non-HTTP inbound adapter)

```rust
// src/inbound/tasks/handler.rs
/// Task queue handler — inbound adapter.
/// Same pattern as HTTP: typed payload → try_into_domain() → service → ack.

#[derive(Debug, Deserialize)]
pub struct SyncAuthorTaskPayload {
    pub author_name: String,
    pub source: String,
}

impl SyncAuthorTaskPayload {
    pub fn try_into_domain(self) -> Result<CreateAuthorRequest, AuthorNameEmptyError> {
        Ok(CreateAuthorRequest::new(AuthorName::new(&self.author_name)?))
    }
}

pub async fn handle_sync_author(
    State(state): State<AppState>,
    Json(payload): Json<SyncAuthorTaskPayload>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let domain_req = payload.try_into_domain()?;
    state.author_service.create_author(&domain_req).await
        .map_err(ApiError::from)?;
    Ok(Json(serde_json::json!({"status": "ok"})))
}

// In HttpServer::build_router() — wire alongside REST routes via routes!():
// .routes(routes!(handlers::create_author))         // user-facing
// .routes(routes!(tasks::handle_sync_author))       // task queue
```

---

## Composition Root

```rust
// src/composition.rs
// The single place that names the concrete adapter combination. Domain ports
// stay generic (RPITIT, zero-cost static dispatch); only this alias spells
// out which adapters the production binary uses. When native dyn-async lands
// in stable Rust, swap to `dyn AuthorService` here without touching anything else.
pub type AppAuthorService = AuthorServiceImpl<Sqlite, Prometheus, EmailClient>;
```

## Inbound: HttpServer Wrapper

```rust
// src/inbound/http/server.rs
use std::sync::Arc;
use std::time::Duration;
use axum::extract::State;
use axum::http::HeaderValue;
use axum::routing::get;
use axum::Router;
use http::{header, StatusCode};
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use tower_http::compression::CompressionLayer;
use tower_http::cors::CorsLayer;
use tower_http::request_id::{MakeRequestUuid, PropagateRequestIdLayer, SetRequestIdLayer};
use tower_http::timeout::TimeoutLayer;
use tower_http::trace::TraceLayer;
use utoipa::OpenApi;
use utoipa::openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme};
use utoipa::Modify;
use utoipa_axum::router::OpenApiRouter;
use utoipa_axum::routes;
use crate::composition::AppAuthorService;
use super::authors::handlers;

#[derive(OpenApi)]
#[openapi(
    info(title = "MyApp API", version = "1.0.0"),
    modifiers(&SecurityAddon),
)]
pub struct ApiDoc;

/// Registers a bearer (JWT) security scheme on the generated OpenAPI doc.
/// Apply it per-operation with `security(("bearer_auth" = []))` inside
/// `#[utoipa::path(...)]` on protected handlers. Note: this documents
/// *authentication*; resource-ownership *authorization* is a separate
/// concern enforced by a policy port (see Security note below).
struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        let components = openapi.components.get_or_insert_with(Default::default);
        components.add_security_scheme(
            "bearer_auth",
            SecurityScheme::Http(
                HttpBuilder::new()
                    .scheme(HttpAuthScheme::Bearer)
                    .bearer_format("JWT")
                    .build(),
            ),
        );
    }
}

pub struct HttpServer { router: Router, listener: TcpListener }

/// `routes!()` collects concrete handler items, so `AppState` must be a single
/// concrete type. We use `Arc<AppAuthorService>` (the composition-root alias)
/// rather than `Arc<dyn AuthorService>` because:
/// 1. The domain port uses RPITIT (`fn -> impl Future + Send`) which is not
///    dyn-compatible in stable Rust today.
/// 2. A binary has one production composition — type erasure earns nothing.
/// 3. Static dispatch: no vptr, no boxed futures.
#[derive(Clone)]
pub struct AppState {
    pub author_service: Arc<AppAuthorService>,
    /// Held by the readiness probe to ping the DB. For Postgres, change to `sqlx::PgPool`.
    pub db_pool: sqlx::SqlitePool,
}

#[derive(Debug, Clone)]
pub struct HttpServerConfig<'a> {
    pub port: &'a str,
    pub cors_origin: &'a str,
}

impl HttpServer {
    pub async fn new(
        author_service: Arc<AppAuthorService>,
        db_pool: sqlx::SqlitePool,
        config: HttpServerConfig<'_>,
    ) -> anyhow::Result<Self> {
        let router = Self::build_router(author_service, db_pool, &config)?;
        let listener = TcpListener::bind(format!("0.0.0.0:{}", config.port)).await?;
        Ok(Self { router, listener })
    }

    /// For tests: returns Router without binding a port.
    /// `OpenApiRouter` collects route metadata; `split_for_parts()` yields the
    /// runtime `Router` plus an `OpenApi` document for swagger/scalar serving.
    pub fn build_router(
        author_service: Arc<AppAuthorService>,
        db_pool: sqlx::SqlitePool,
        config: &HttpServerConfig<'_>,
    ) -> anyhow::Result<Router> {
        let state = AppState { author_service, db_pool };
        let origin = config.cors_origin.parse::<HeaderValue>()?;

        // Axum 0.8+: path params use {id} (not :id), wildcards {*path}.
        // Routes are nested under `/v1` so the wire paths match the API spec
        // (`/v1/authors`, `/v1/authors/{id}`); handler `#[utoipa::path]` values
        // are relative to that nest prefix.
        let (router, _api) = OpenApiRouter::with_openapi(ApiDoc::openapi())
            .nest(
                "/v1",
                OpenApiRouter::new()
                    .routes(routes!(handlers::create_author, handlers::list_authors))
                    .routes(routes!(handlers::get_author)),
            )
            .route("/health", get(|| async { StatusCode::OK }))
            .route("/ready", get(Self::readiness_check))
            .layer(
                ServiceBuilder::new()
                    // Request-id layers bracket the stack: assign an id on the way
                    // in (honoring an inbound X-Request-Id, else a fresh UUID),
                    // then copy it onto the response on the way out. The
                    // ApiError/ApiSuccess responders read it from extensions.
                    .layer(SetRequestIdLayer::x_request_id(MakeRequestUuid))
                    .layer(TraceLayer::new_for_http())
                    // `TimeoutLayer::new` is deprecated since tower-http 0.6.7.
                    .layer(TimeoutLayer::with_status_code(StatusCode::REQUEST_TIMEOUT, Duration::from_secs(10)))
                    .layer(CompressionLayer::new())
                    .layer(CorsLayer::new().allow_origin([origin]))
                    .layer(PropagateRequestIdLayer::x_request_id()),
            )
            .with_state(state)
            .split_for_parts();

        // To serve OpenAPI docs, merge a swagger/scalar router with `_api`:
        //   .merge(utoipa_swagger_ui::SwaggerUi::new("/swagger").url("/api-docs/openapi.json", _api))
        // or use `utoipa-scalar` for a lighter UI.
        Ok(router)
    }

    pub async fn run(self) -> anyhow::Result<()> {
        axum::serve(self.listener, self.router)
            .with_graceful_shutdown(Self::shutdown_signal())
            .await?;
        Ok(())
    }

    async fn shutdown_signal() {
        let ctrl_c = async {
            tokio::signal::ctrl_c().await.expect("failed to install Ctrl+C handler");
        };
        #[cfg(unix)]
        let terminate = async {
            tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
                .expect("failed to install SIGTERM handler")
                .recv().await;
        };
        #[cfg(not(unix))]
        let terminate = std::future::pending::<()>();
        tokio::select! { _ = ctrl_c => {}, _ = terminate => {} }
    }
}

// Health check — readiness probe (lives in inbound, not domain)
impl HttpServer {
    // Acquiring a connection exercises the pool (checkout + liveness) rather
    // than just running an unchecked `SELECT 1` against an already-open handle.
    async fn readiness_check(State(state): State<AppState>) -> StatusCode {
        match state.db_pool.acquire().await {
            Ok(_) => StatusCode::OK,
            Err(e) => {
                tracing::warn!(error = ?e, "readiness check failed");
                StatusCode::SERVICE_UNAVAILABLE
            }
        }
    }
}
```

## Inbound: Multi-Service AppState with FromRef

For 3+ services, split the state via `FromRef` so each handler depends on only what it needs. Each service gets its own composition-root type alias — same principle as the single-service case:

```rust
// src/composition.rs — one alias per bounded context
pub type AppAuthorService  = AuthorServiceImpl<Sqlite, Prometheus, EmailClient>;
pub type AppBillingService = BillingServiceImpl<Postgres, Prometheus, StripeClient>;
```

```rust
// src/inbound/http/server.rs — multi-domain variant
use axum::extract::{FromRef, Path, State};
use axum::Json;
use crate::composition::{AppAuthorService, AppBillingService};

#[derive(Clone)]
struct AppState {
    author_service: Arc<AppAuthorService>,
    billing_service: Arc<AppBillingService>,
    // Same pool the single-service variant holds — the readiness probe needs it
    // regardless of how many services share the state. For Postgres use `PgPool`.
    db_pool: sqlx::SqlitePool,
}

// Each handler extracts only the service it needs
impl FromRef<AppState> for Arc<AppAuthorService> {
    fn from_ref(state: &AppState) -> Self { state.author_service.clone() }
}
impl FromRef<AppState> for Arc<AppBillingService> {
    fn from_ref(state: &AppState) -> Self { state.billing_service.clone() }
}
// The probe extracts the pool the same way — so `readiness_check` can take
// `State(pool): State<sqlx::SqlitePool>` instead of the whole `AppState`.
impl FromRef<AppState> for sqlx::SqlitePool {
    fn from_ref(state: &AppState) -> Self { state.db_pool.clone() }
}

// Handlers depend on the concrete service alias — still hides adapter combination
// behind a single name in `composition.rs`. State-extraction rule for this skill:
// 1-2 services → extract `State<AppState>` and reach through it (the single-service
// `Handlers` section above does this). 3+ services → add `FromRef` impls and extract
// only the needed alias, `State<Arc<AppAuthorService>>` (NOT the whole `AppState`),
// as both handlers below do.
async fn create_author(
    State(service): State<Arc<AppAuthorService>>,
    Json(body): Json<CreateAuthorHttpRequestBody>,
) -> Result<ApiSuccess<AuthorResponseData>, ApiError> {
    let domain_req = body.try_into_domain()?;
    let author = service.create_author(&domain_req).await
        .map_err(ApiError::from)?;
    Ok(ApiSuccess::created((&author).into(), author.id()))
}

async fn get_author(
    State(service): State<Arc<AppAuthorService>>,
    Path(id): Path<Uuid>,
) -> Result<ApiSuccess<AuthorResponseData>, ApiError> {
    let author = service.find_author(&id).await
        .map_err(ApiError::from)?
        .ok_or_else(ApiError::not_found)?;
    Ok(ApiSuccess::new(StatusCode::OK, (&author).into()))
}

// All routers share the same AppState
fn build_router(state: AppState) -> Router {
    // Each domain module owns its `OpenApiRouter`; the top level merges them
    // and calls `split_for_parts()` to recover the runtime `Router`.
    // `/ready` is inherited here too — it extracts the pool via FromRef above.
    let (router, _api) = OpenApiRouter::with_openapi(ApiDoc::openapi())
        .nest("/v1/authors", authors::router())
        .nest("/v1/billing", billing::router())
        .route("/ready", get(readiness_check))
        .with_state(state)
        .split_for_parts();
    router
}

async fn readiness_check(State(pool): State<sqlx::SqlitePool>) -> StatusCode {
    match pool.acquire().await {
        Ok(_) => StatusCode::OK,
        Err(e) => {
            tracing::warn!(error = ?e, "readiness check failed");
            StatusCode::SERVICE_UNAVAILABLE
        }
    }
}

// Inside each domain module:
mod authors {
    use super::*;
    pub fn router() -> OpenApiRouter<AppState> {
        OpenApiRouter::new()
            .routes(routes!(create_author, get_author))
    }
}
```

> **When to switch:** the single-service `AppState` (above) is simpler for 1-2 services. Add `FromRef` impls when you have 3+ services so each handler extracts only the alias it needs. Type erasure (`Arc<dyn ...>`) is only worth it once native dyn-async stabilizes or you genuinely need runtime swapping.

## Inbound: Auth Middleware

```rust
// src/inbound/http/middleware.rs
// Auth middleware: takes the same AppState as handlers. If auth needs its
// own service (e.g. a session repository), add a field to AppState — keep
// this layer agnostic of token verification details.
pub async fn require_auth(
    State(_state): State<AppState>,
    mut req: Request,
    next: Next,
) -> Result<Response, ApiError> {
    let token = req.headers()
        .get("Authorization")
        .and_then(|h| h.to_str().ok())
        .and_then(|h| h.strip_prefix("Bearer "))
        .ok_or_else(ApiError::unauthorized)?;
    let user = verify_token(token).await?.ok_or_else(ApiError::unauthorized)?;
    req.extensions_mut().insert(user);
    Ok(next.run(req).await)
}

// `User` and `verify_token` are app-specific — stubbed here. In a real app
// `verify_token` validates the JWT (signature, expiry, claims) and loads the
// principal, returning `Result<Option<User>, ApiError>`.
#[derive(Clone)]
pub struct User { pub id: Uuid }

async fn verify_token(_token: &str) -> Result<Option<User>, ApiError> {
    // Decode + verify JWT, look up the user. App-specific.
    unimplemented!("validate JWT and load the principal")
}

// NOTE: authentication (above) only proves *who* is calling. Before returning
// or mutating a resource, also run an authorization/ownership check — a policy
// port such as `Policy::can_access(user, resource) -> bool` — or
// `GET /v1/authors/{id}` becomes an IDOR. Rate limiting is a separate cross-cutting
// concern: terminate it at the API gateway/load balancer, or add a
// `tower_governor::GovernorLayer` to the `ServiceBuilder` if you must enforce it
// in-process (it returns 429 as `application/problem+json` like every other error).

// Apply per-route — Axum 0.8+: {id} syntax
OpenApiRouter::new()
    .routes(routes!(create_author))
    .route_layer(middleware::from_fn_with_state(state.clone(), require_auth))
```

## Inbound: Request / Response

```rust
// src/inbound/http/authors/request.rs
use serde::Deserialize;
use utoipa::{IntoParams, ToSchema};
use crate::domain::authors::models::{AuthorName, AuthorNameEmptyError, CreateAuthorRequest};

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateAuthorHttpRequestBody { pub name: String }

impl CreateAuthorHttpRequestBody {
    pub fn try_into_domain(self) -> Result<CreateAuthorRequest, AuthorNameEmptyError> {
        Ok(CreateAuthorRequest::new(AuthorName::new(&self.name)?))
    }
}

#[derive(Debug, Deserialize, IntoParams)]
pub struct ListParams {
    pub cursor: Option<String>,
    #[serde(default = "default_limit")]
    pub limit: usize,
}
fn default_limit() -> usize { 20 }

impl ListParams {
    pub fn validated(self) -> (Option<String>, usize) {
        (self.cursor, self.limit.clamp(1, 100))
    }
}

// src/inbound/http/authors/response.rs
use serde::Serialize;
use utoipa::ToSchema;
use crate::domain::authors::models::Author;

#[derive(Debug, Serialize, ToSchema)]
pub struct AuthorResponseData { pub id: String, pub name: String }

impl From<&Author> for AuthorResponseData {
    fn from(a: &Author) -> Self {
        Self { id: a.id().to_string(), name: a.name().to_string() }
    }
}

// Documents the single-resource envelope `{ "data": {...} }` that
// `ApiSuccess::into_response` emits. Used as the `body =` in `#[utoipa::path]`
// for 200/201 single-author responses so the OpenAPI doc matches the wire shape.
#[derive(Debug, Serialize, ToSchema)]
pub struct AuthorEnvelope { pub data: AuthorResponseData }

// Collection envelope: `{ "data": [...], "meta": { limit, next_cursor, has_more } }`.
// `meta` is nested (matches the shared API spec) and always carries `limit`.
// utoipa 5+ supports real generics: derive `ToSchema` on the generic type and
// reference the concrete instantiation in `#[utoipa::path]` (the old
// `#[aliases(...)]` attribute was removed in utoipa 5).
#[derive(Debug, Serialize, ToSchema)]
pub struct CursorPageResponse<T: Serialize + ToSchema> {
    pub data: Vec<T>,
    pub meta: PageMeta,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct PageMeta {
    pub limit: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub next_cursor: Option<String>,
    pub has_more: bool,
}
```

## Inbound: Handlers

```rust
// src/inbound/http/authors/handlers.rs
// `#[utoipa::path]` annotations let `routes!()` collect each handler into the
// generated OpenAPI document. Path values are RELATIVE to the `/v1` nest in
// `server.rs`, so they read `/authors` here but serve at `/v1/authors`
// (Axum 0.8 `{id}` syntax).
use axum::extract::{Path, Query, State};
use axum::Json;
use http::StatusCode;
use uuid::Uuid;
use super::super::error::ApiError;
use super::super::response::ApiSuccess;
use super::request::{CreateAuthorHttpRequestBody, ListParams};
use super::response::{AuthorResponseData, CursorPageResponse, PageMeta};
use super::super::server::AppState;

// The 201 body is the single-resource envelope `{ "data": {...} }`
// (see `ApiSuccess::into_response`). `AuthorEnvelope` is the documented schema
// for that wrapped shape. The Location header carries `/v1/authors/{id}`.
#[utoipa::path(
    post,
    path = "/authors",
    request_body = CreateAuthorHttpRequestBody,
    responses(
        (status = 201, description = "Author created", body = AuthorEnvelope,
         headers(("Location" = String, description = "URI of the created author"))),
        (status = 400, description = "Malformed request body", body = ProblemDetail),
        (status = 409, description = "Duplicate", body = ProblemDetail),
        (status = 422, description = "Validation failed", body = ProblemDetail),
    ),
    tag = "authors",
)]
pub async fn create_author(
    State(state): State<AppState>,
    Json(body): Json<CreateAuthorHttpRequestBody>,
) -> Result<ApiSuccess<AuthorResponseData>, ApiError> {
    let domain_req = body.try_into_domain()?;
    let author = state.author_service.create_author(&domain_req).await
        .map_err(ApiError::from)?;
    // `created` emits 201 + `Location: /v1/authors/{id}` from `author.id()`,
    // wrapping the body as `{ "data": {...} }`.
    Ok(ApiSuccess::created((&author).into(), author.id()))
}

#[utoipa::path(
    get,
    path = "/authors/{id}",
    params(("id" = Uuid, Path, description = "Author ID")),
    responses(
        (status = 200, description = "Author", body = AuthorEnvelope),
        (status = 404, description = "Not found", body = ProblemDetail),
    ),
    tag = "authors",
)]
pub async fn get_author(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<ApiSuccess<AuthorResponseData>, ApiError> {
    let maybe = state.author_service.find_author(&id).await
        .map_err(ApiError::from)?;
    let author = maybe.ok_or_else(ApiError::not_found)?;
    Ok(ApiSuccess::new(StatusCode::OK, (&author).into()))
}

#[utoipa::path(
    get,
    path = "/authors",
    params(ListParams),
    responses(
        (status = 200, description = "Author page", body = CursorPageResponse<AuthorResponseData>),
    ),
    tag = "authors",
)]
pub async fn list_authors(
    State(state): State<AppState>,
    Query(params): Query<ListParams>,
) -> Result<ApiSuccess<CursorPageResponse<AuthorResponseData>>, ApiError> {
    let (cursor, limit) = params.validated();
    let page = state.author_service.list_authors(cursor.as_deref(), limit).await
        .map_err(ApiError::from)?;
    Ok(ApiSuccess::new(StatusCode::OK, CursorPageResponse {
        data: page.items.iter().map(AuthorResponseData::from).collect(),
        meta: PageMeta {
            limit,
            next_cursor: page.next_cursor,
            has_more: page.has_more,
        },
    }))
}
```

## Inbound: API Error (RFC 9457)

**400 vs 422.** `400 Bad Request` is for *syntactic* failures the framework catches before your handler runs — malformed JSON, a query string that won't deserialize, a path segment that isn't a valid UUID. `422 Unprocessable Entity` is for *semantic* failures: the request parsed fine, but a value violates a business rule (empty author name, invalid state transition). The `From<*Rejection>` impls below map Axum's extractor rejections to 400; domain validation errors map to 422 with a populated `errors` array.

```rust
// src/inbound/http/error.rs
use std::fmt;
use axum::extract::rejection::{JsonRejection, PathRejection, QueryRejection};
use axum::extract::Request;
use axum::http::{header, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::{Extension, Json};
use serde::Serialize;
use utoipa::ToSchema;
use crate::domain::authors::error::CreateAuthorError;
use crate::domain::authors::models::AuthorNameEmptyError;

// `ApiError` is a struct, not a bare enum, so it can carry the `instance`
// (request path) that RFC 9457 puts in the problem body. `kind` selects the
// status/title; `instance` is stamped from the request URI (see `OriginalUri`
// below) before `into_response` serializes the body.
#[derive(Debug)]
pub struct ApiError {
    pub kind: ApiErrorKind,
    pub instance: Option<String>,
}

#[derive(Debug)]
pub enum ApiErrorKind {
    /// 400 — request could not be parsed (malformed JSON, bad query/path).
    BadRequest(String),
    InternalServerError(String),
    /// 422 — parsed but semantically invalid; carries field-level detail.
    UnprocessableEntity { detail: String, errors: Vec<FieldError> },
    Conflict(String),
    NotFound,
    Unauthorized,
}

impl ApiError {
    pub fn new(kind: ApiErrorKind) -> Self { Self { kind, instance: None } }

    /// Stamp the request path so it lands in the problem body's `instance`.
    pub fn with_instance(mut self, path: impl Into<String>) -> Self {
        self.instance = Some(path.into());
        self
    }

    /// 422 from a single field violation.
    pub fn unprocessable(field: &str, code: &str, message: &str) -> Self {
        Self::new(ApiErrorKind::UnprocessableEntity {
            detail: message.to_string(),
            errors: vec![FieldError {
                field: field.to_string(),
                code: code.to_string(),
                message: message.to_string(),
            }],
        })
    }

    // Convenience constructors used by handlers.
    pub fn not_found() -> Self { Self::new(ApiErrorKind::NotFound) }
    pub fn unauthorized() -> Self { Self::new(ApiErrorKind::Unauthorized) }
}

impl From<ApiErrorKind> for ApiError {
    fn from(kind: ApiErrorKind) -> Self { Self::new(kind) }
}

impl fmt::Display for ApiErrorKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadRequest(msg) => write!(f, "{}", msg),
            Self::InternalServerError(msg) => write!(f, "{}", msg),
            Self::UnprocessableEntity { detail, .. } => write!(f, "{}", detail),
            Self::Conflict(msg) => write!(f, "{}", msg),
            Self::NotFound => write!(f, "Not Found"),
            Self::Unauthorized => write!(f, "Unauthorized"),
        }
    }
}

impl From<CreateAuthorError> for ApiError {
    fn from(e: CreateAuthorError) -> Self {
        match e {
            CreateAuthorError::Duplicate { name } =>
                ApiErrorKind::Conflict(format!("author with name {} already exists", name)).into(),
            CreateAuthorError::Unknown(cause) => {
                tracing::error!(error = ?cause, "unhandled domain error");
                ApiErrorKind::InternalServerError("An unexpected error occurred".into()).into()
            }
        }
    }
}

impl From<AuthorNameEmptyError> for ApiError {
    fn from(_: AuthorNameEmptyError) -> Self {
        Self::unprocessable("name", "required", "author name cannot be empty")
    }
}

// Extractor rejections → 400 (syntactic). These fire before the handler body
// runs, so the request never reached domain validation.
impl From<JsonRejection> for ApiError {
    fn from(r: JsonRejection) -> Self { ApiErrorKind::BadRequest(r.body_text()).into() }
}
impl From<QueryRejection> for ApiError {
    fn from(r: QueryRejection) -> Self { ApiErrorKind::BadRequest(r.body_text()).into() }
}
impl From<PathRejection> for ApiError {
    fn from(r: PathRejection) -> Self { ApiErrorKind::BadRequest(r.body_text()).into() }
}

// Generic anyhow → ISE (for list operations that return anyhow::Error)
impl From<anyhow::Error> for ApiError {
    fn from(e: anyhow::Error) -> Self {
        tracing::error!(error = ?e, "unhandled error");
        ApiErrorKind::InternalServerError("An unexpected error occurred".into()).into()
    }
}

// Singular `ProblemDetail` (RFC 9457). The correlation id is NOT in the body —
// it travels in the `X-Request-Id` response header set by the request-id layer.
#[derive(Serialize, ToSchema)]
pub struct ProblemDetail {
    /// URL identifying the problem type
    #[serde(rename = "type")]
    pub problem_type: String,
    pub title: String,
    pub status: u16,
    pub detail: String,
    /// Path of the request that failed
    #[serde(skip_serializing_if = "Option::is_none")]
    pub instance: Option<String>,
    /// Field-level validation errors (RFC 9457 extension)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub errors: Option<Vec<FieldError>>,
}

#[derive(Serialize, ToSchema)]
pub struct FieldError {
    pub field: String,
    pub code: String,
    pub message: String,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, problem, title) = match &self.kind {
            ApiErrorKind::BadRequest(_) =>
                (StatusCode::BAD_REQUEST, "bad-request", "Bad Request"),
            ApiErrorKind::NotFound => (StatusCode::NOT_FOUND, "not-found", "Not Found"),
            ApiErrorKind::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized", "Unauthorized"),
            ApiErrorKind::UnprocessableEntity { .. } =>
                (StatusCode::UNPROCESSABLE_ENTITY, "unprocessable-entity", "Unprocessable Entity"),
            ApiErrorKind::Conflict(_) =>
                (StatusCode::CONFLICT, "conflict", "Conflict"),
            ApiErrorKind::InternalServerError(_) =>
                (StatusCode::INTERNAL_SERVER_ERROR, "internal-error", "Internal Server Error"),
        };
        let detail = match &self.kind {
            ApiErrorKind::InternalServerError(_) => "An unexpected error occurred".into(),
            other => other.to_string(),
        };
        let errors = match self.kind {
            ApiErrorKind::UnprocessableEntity { errors, .. } if !errors.is_empty() => Some(errors),
            _ => None,
        };
        let body = ProblemDetail {
            problem_type: format!("https://api.example.com/errors/{}", problem),
            title: title.into(),
            status: status.as_u16(),
            detail,
            instance: self.instance,  // request path, stamped by the handler/extractor
            errors,
        };
        (
            status,
            [(header::CONTENT_TYPE, "application/problem+json")],
            Json(body),
        ).into_response()
    }
}
```

**Populating `instance`.** `IntoResponse::into_response` has no access to the request, so the path is stamped onto the error before it bubbles out. Two idiomatic options:

```rust
// (a) In the handler — extract the path with `OriginalUri` and stamp on the way out:
use axum::extract::OriginalUri;

pub async fn create_author(
    State(state): State<AppState>,
    OriginalUri(uri): OriginalUri,
    body: Result<Json<CreateAuthorHttpRequestBody>, JsonRejection>,
) -> Result<ApiSuccess<AuthorResponseData>, ApiError> {
    let path = uri.path().to_string();
    // `Result<Json<_>, JsonRejection>` lets the handler convert a 400 itself
    // (rather than Axum returning its default text/plain rejection) — this is
    // how the `From<JsonRejection>` impl above gets exercised.
    let Json(body) = body.map_err(|r| ApiError::from(r).with_instance(&path))?;
    let domain_req = body.try_into_domain().map_err(|e| ApiError::from(e).with_instance(&path))?;
    let author = state.author_service.create_author(&domain_req).await
        .map_err(|e| ApiError::from(e).with_instance(&path))?;
    Ok(ApiSuccess::created((&author).into(), author.id()))
}
```

```rust
// (b) Centralize it — a `map_response` layer reads `req.uri().path()` and patches
// `instance` on any `application/problem+json` body. Less per-handler noise.
```

> The contract is fixed: `instance` = request path in the body; correlation id = `X-Request-Id` response header (set by the request-id layer, present even on 204/304). Handlers in the worked examples above use the bare `ApiError::from(...)?` form for brevity — add `.with_instance(path)` (option a) or a layer (option b) to populate `instance` in production.

## Inbound: Response Wrappers

```rust
// src/inbound/http/response.rs
use axum::http::{header, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde::Serialize;
use uuid::Uuid;

/// Wraps a single resource as `{ "data": ... }` (the API spec's single-resource
/// envelope). `location` is set on 201 responses so clients learn the new URI.
pub struct ApiSuccess<T: Serialize> {
    status: StatusCode,
    data: T,
    location: Option<HeaderValue>,
}

/// The single-resource envelope: `{ "data": {...} }`.
#[derive(Serialize)]
struct DataEnvelope<T: Serialize> { data: T }

impl<T: Serialize> ApiSuccess<T> {
    pub fn new(status: StatusCode, data: T) -> Self {
        Self { status, data, location: None }
    }

    /// 201 Created with `Location: /v1/authors/{id}`. The id comes from the
    /// freshly-created aggregate (`author.id()`), so the header always points
    /// at the canonical resource URI.
    pub fn created(data: T, id: &Uuid) -> Self {
        let location = HeaderValue::from_str(&format!("/v1/authors/{}", id)).ok();
        Self { status: StatusCode::CREATED, data, location }
    }
}

impl<T: Serialize> IntoResponse for ApiSuccess<T> {
    fn into_response(self) -> Response {
        let body = Json(DataEnvelope { data: self.data });
        match self.location {
            Some(loc) => (self.status, [(header::LOCATION, loc)], body).into_response(),
            None => (self.status, body).into_response(),
        }
    }
}

pub struct NoContent;

impl IntoResponse for NoContent {
    fn into_response(self) -> Response { StatusCode::NO_CONTENT.into_response() }
}
```

> `ApiSuccess` is the single response carrier — don't add separate `Created<T>` / `Ok<T>` marker types. A bare-body marker (no `data` wrapper) that skips `Location` would conflict with the envelope contract. Use `ApiSuccess::created(data, id)` for 201 (sets `Location`), `ApiSuccess::new(StatusCode::OK, data)` for 200, `NoContent` for 204. The `Location` path is hardcoded to `/v1/authors/{id}` for the worked example — generalize it (pass the full path, or a `resource: &str` segment) when you have more than one resource.

---

## Outbound: Outbox Adapter (transactional, sqlx)

The outbox row must be inserted in the **same** transaction as the aggregate write — otherwise a crash between commit and publish drops the event silently. In Rust + sqlx the cleanest pattern is to keep both writes inside one repository method; the domain passes events as **typed** data.

> **This is an ALTERNATE `AuthorRepository`.** The canonical port (in `examples-domain.md`) is `create_author(&self, req: &CreateAuthorRequest)`. The variant below adds an `events: &[AuthorEvent]` parameter so the adapter can persist the outbox rows in the same transaction. Adopt this signature *only* when you need the transactional outbox; otherwise keep the canonical two-arg method.

**Domain purity.** The domain emits a **typed event enum** — no `serde_json::Value`, no `json!()`, no infra types. Serialization to the outbox JSON column happens in the adapter, which is allowed to know about JSON. This keeps `domain/` free of serde-shaped payloads.

```rust
// src/domain/authors/events.rs — typed domain event, no infra deps
use uuid::Uuid;

#[derive(Debug, Clone)]
pub enum AuthorEvent {
    Created { id: Uuid, name: String },
}

impl AuthorEvent {
    pub fn aggregate_type(&self) -> &'static str { "author" }
    pub fn aggregate_id(&self) -> String {
        match self { Self::Created { id, .. } => id.to_string() }
    }
    pub fn event_type(&self) -> &'static str {
        match self { Self::Created { .. } => "AuthorCreated" }
    }
}
```

```rust
// src/outbound/events.rs — adapter-layer serialization (serde lives HERE, not in domain)
use serde_json::{json, Value};
use crate::domain::authors::events::AuthorEvent;

fn payload_json(ev: &AuthorEvent) -> Value {
    match ev {
        AuthorEvent::Created { name, .. } => json!({ "name": name }),
    }
}
```

```rust
// src/domain/authors/ports.rs — ALTERNATE port: carries the events to persist atomically
pub trait AuthorRepository: Clone + Send + Sync + 'static {
    // NOTE: `id` is generated by the caller (service) and passed in, so the
    // aggregate id, the row id, and the event's aggregate_id all agree.
    fn create_author(
        &self,
        id: Uuid,
        req: &CreateAuthorRequest,
        events: &[AuthorEvent],
    ) -> impl Future<Output = Result<Author, CreateAuthorError>> + Send;
    // ... other methods
}
```

```rust
// src/outbound/postgres.rs — both writes in one owned tx, executed on &mut *tx
impl AuthorRepository for Postgres {
    async fn create_author(
        &self,
        id: Uuid,
        req: &CreateAuthorRequest,
        events: &[AuthorEvent],
    ) -> Result<Author, CreateAuthorError> {
        let mut tx = self.pool.begin().await.context("begin tx")?;

        sqlx::query!(
            "INSERT INTO authors (id, name) VALUES ($1, $2)",
            id, req.name().to_string(),
        )
        .execute(&mut *tx).await
        .map_err(|e| {
            // Same idiom as the canonical adapters: as_database_error().map_or(...).
            if e.as_database_error().map_or(false, |d| d.is_unique_violation()) {
                CreateAuthorError::Duplicate { name: req.name().clone() }
            } else {
                anyhow!(e).context("insert author").into()
            }
        })?;

        // Trace context captured at write time, not at relay time —
        // so consumers can stitch the producing request to downstream work.
        let traceparent = current_traceparent();

        for ev in events {
            sqlx::query!(
                "INSERT INTO outbox \
                   (id, aggregate_type, aggregate_id, event_type, payload, traceparent) \
                 VALUES ($1, $2, $3, $4, $5, $6)",
                Uuid::new_v4(),
                ev.aggregate_type(),
                ev.aggregate_id(),     // = id.to_string() for AuthorEvent::Created
                ev.event_type(),
                payload_json(ev),      // adapter serializes the typed event to JSON
                traceparent.as_deref(),
            )
            .execute(&mut *tx).await
            .context("insert outbox row")?;
        }

        tx.commit().await.context("commit tx")?;
        Ok(Author::new(id, req.name().clone()))
    }
}
```

**Service composes it**: the service generates the id, builds the typed events, and records success/failure with the same pattern as the canonical `create_author` (the `AuthorMetrics` port declares `record_creation_success()` / `record_creation_failure()` — there is no `record_creation()`).

```rust
// src/domain/authors/service.rs — uses the ALTERNATE events-carrying repository
async fn create_author(&self, req: &CreateAuthorRequest)
    -> Result<Author, CreateAuthorError>
{
    // Generate the id here so the aggregate id and the event's aggregate_id
    // are the same value (the repo INSERTs this id; it does not mint its own).
    let id = Uuid::new_v4();
    let events = vec![AuthorEvent::Created {
        id,
        name: req.name().to_string(),
    }];
    let result = self.repo.create_author(id, req, &events).await;
    match &result {
        Ok(author) => {
            self.metrics.record_creation_success().await;
            self.notifier.author_created(author).await;
        }
        Err(_) => self.metrics.record_creation_failure().await,
    }
    result
}
```

**Outbox relay** is a separate binary (`bin/outbox_relay`), not an inbound HTTP handler. It polls `WHERE published_at IS NULL` in insertion order (`ORDER BY` a `created_at`/sequence column — random v4 UUID ids don't sort by insertion) `LIMIT N`, publishes to the broker, and updates `published_at` on success. Failures move to a `outbox_dead` table after N attempts.

### Common gotchas

- Owned tx (`pool.begin()`): `&mut *tx`, not `&mut **tx` (that form is only for a `&mut Transaction` parameter). SQLx 0.7 removed `Executor` from `Transaction`.
- Don't make `Outbox` a separate port that takes a `Transaction` — leaks sqlx into the domain. Keep both writes in the same adapter method.
- Don't publish to the broker inside the tx. Outbox relay is the only thing that talks to the broker.
- Keep `serde_json::Value` / `json!()` out of `domain/`. The domain emits a typed `AuthorEvent`; the adapter serializes it to the outbox JSON column.

---

## Outbound: Idempotency Store

A KV-shaped table keyed by `(scope, key)` with a unique constraint. The application service (or an inbound middleware) wraps the use case.

```rust
// src/domain/shared/idempotency.rs
pub trait IdempotencyStore: Clone + Send + Sync + 'static {
    fn acquire(
        &self,
        scope: &str,
        key: &str,
        request_hash: &str,
    ) -> impl Future<Output = Result<Acquire, anyhow::Error>> + Send;

    fn store(
        &self,
        scope: &str,
        key: &str,
        response_bytes: &[u8],
    ) -> impl Future<Output = Result<(), anyhow::Error>> + Send;
}

pub enum Acquire {
    NewExecution,
    Replay(Vec<u8>),
    Conflict, // same key, different request_hash
    InFlight, // same key, first request still executing — return 409 (retry later), never re-run
}
```

```rust
// src/outbound/postgres.rs
impl IdempotencyStore for Postgres {
    async fn acquire(&self, scope: &str, key: &str, hash: &str) -> Result<Acquire, anyhow::Error> {
        // Insert-or-fetch — unique constraint collapses races to one winner.
        let inserted = sqlx::query!(
            "INSERT INTO idempotency (scope, key, request_hash) \
             VALUES ($1, $2, $3) ON CONFLICT (scope, key) DO NOTHING",
            scope, key, hash,
        ).execute(&self.pool).await?;

        if inserted.rows_affected() == 1 {
            return Ok(Acquire::NewExecution);
        }
        let row = sqlx::query!(
            "SELECT request_hash, response FROM idempotency WHERE scope = $1 AND key = $2",
            scope, key,
        ).fetch_one(&self.pool).await?;

        if row.request_hash != hash {
            return Ok(Acquire::Conflict);
        }
        match row.response {
            Some(bytes) => Ok(Acquire::Replay(bytes)),
            // No stored response yet: the first request is still running. Re-running
            // it here would double-execute (double charge) — report it instead.
            None => Ok(Acquire::InFlight),
        }
    }
    // store(...) updates the row.
}
```

---

## Outbound: Tracer Port (OTel)

Don't import `opentelemetry::*` types into the domain. Define a minimal port; the OTel adapter implements it. Tests use a no-op or capturing adapter.

```rust
// src/domain/shared/tracing.rs
pub trait Tracer: Clone + Send + Sync + 'static {
    type Span: Span;
    fn start_span(&self, name: &str, attrs: &[(&str, &str)]) -> Self::Span;
}
pub trait Span: Send {
    fn add_event(&self, name: &str, attrs: &[(&str, &str)]);
    fn record_error(&self, err: &(dyn std::error::Error + 'static));
    fn end(self);
}
```

The OTel adapter (`src/outbound/otel.rs`) wraps `opentelemetry_sdk::trace::Tracer`. The application service depends on the `Tracer` trait, never on the SDK directly. This keeps domain compile times low, lets tests run with zero observability cost, and makes vendor swap a one-file change.

For sampling, span attributes, and the broader strategy, see `software-architecture/references/observability.md`.
