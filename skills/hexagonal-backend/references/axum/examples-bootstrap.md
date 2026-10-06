# Examples: Bootstrap & Testing

Config, main.rs, graceful shutdown, CI, and hex-specific test mocks.

## Table of Contents

1. [Config](#config)
2. [Bootstrap](#bootstrap)
3. [CI/CD](#cicd)
4. [Testing: Hex-Specific Mocks](#testing-hex-specific-mocks)

---

## Config

```rust
// src/config.rs
use anyhow::Context;

#[derive(Debug, Clone)]
pub struct Config {
    pub database_url: String,
    pub server_port: String,
    pub cors_origin: String,
}

impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        Ok(Self {
            database_url: std::env::var("DATABASE_URL")
                .context("DATABASE_URL must be set")?,
            server_port: std::env::var("PORT")
                .unwrap_or_else(|_| "3000".to_string()),
            cors_origin: std::env::var("CORS_ORIGIN")
                .unwrap_or_else(|_| "http://localhost:3000".to_string()),
        })
    }
}
```

## Bootstrap

```rust
// src/bin/server/main.rs — `sqlx` import is allowed in bootstrap because
// the pool is the one infrastructure handle the readiness probe needs.
// Domain code never sees it.
use std::sync::Arc;
use sqlx::sqlite::SqlitePoolOptions;

use myapp::config::Config;
use myapp::domain::authors::service::AuthorServiceImpl;
use myapp::inbound::http::{HttpServer, HttpServerConfig};
use myapp::outbound::{sqlite::Sqlite, prometheus::Prometheus, email_client::EmailClient};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = Config::from_env()?;
    tracing_subscriber::fmt::init();

    // Construct the pool once so we can reuse it for both the repository
    // adapter AND the readiness probe.
    let pool = SqlitePoolOptions::new()
        .max_connections(10)
        .acquire_timeout(std::time::Duration::from_secs(3))
        .connect(&config.database_url).await?;

    let sqlite = Sqlite::from_pool(pool.clone());
    // `Arc<AppAuthorService>` is the composition-root type alias defined in
    // `src/composition.rs`. No `dyn`, no generics — static dispatch.
    let service = Arc::new(
        AuthorServiceImpl::new(sqlite, Prometheus::new(), EmailClient::new()),
    );
    HttpServer::new(service, pool, HttpServerConfig {
        port: &config.server_port,
        cors_origin: &config.cors_origin,
    }).await?.run().await
}
```

## CI/CD

```bash
# SQLx 0.7+: one file per query (not merged). Commit .sqlx/ directory.
cargo sqlx prepare && git add .sqlx/        # generate offline query data (local)

# CI pipeline — every PR:
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo sqlx prepare --check                  # .sqlx/ in sync with queries
SQLX_OFFLINE=true cargo test                # build + tests without a DB

# Boundary fitness function — domain must stay infrastructure-free.
# (Compiler-enforced once domain/ is its own workspace crate; until then:)
! grep -rE 'use (axum|sqlx|tower|utoipa)' src/domain/ \
  || { echo "domain imports infrastructure"; exit 1; }
```

---

## Testing: Hex-Specific Mocks

### Strategy

| Layer | Mock | What to test |
|-------|------|--------------|
| Handler | Mock service | HTTP parsing, status codes, error format |
| Service | Mock repo/metrics/notifier | Orchestration, side-effect ordering |
| Adapter | Real DB | SQL, error mapping, transactions |
| E2E | Nothing mocked | Critical happy paths |

### Stub — returns configured results

`Arc<Mutex<Result>>` needed because `Clone` bound + `anyhow::Error` isn't `Clone`.

```rust
#[derive(Clone)]
struct MockAuthorService {
    create_result: Arc<Mutex<Result<Author, CreateAuthorError>>>,
}

impl AuthorService for MockAuthorService {
    async fn create_author(&self, _: &CreateAuthorRequest) -> Result<Author, CreateAuthorError> {
        let mut guard = self.create_result.lock().await;
        let mut result = Err(CreateAuthorError::Unknown(anyhow!("placeholder")));
        mem::swap(guard.deref_mut(), &mut result);
        result
    }
    async fn find_author(&self, _: &Uuid) -> Result<Option<Author>, anyhow::Error> {
        Ok(None)
    }
    async fn list_authors(&self, _: Option<&str>, _: usize) -> Result<CursorPage<Author>, anyhow::Error> {
        Ok(CursorPage { items: vec![], next_cursor: None, has_more: false })
    }
}
```

### Saboteur — always fails

```rust
#[derive(Clone)]
struct SaboteurRepository;

impl AuthorRepository for SaboteurRepository {
    async fn create_author(&self, _: &CreateAuthorRequest) -> Result<Author, CreateAuthorError> {
        Err(anyhow!("db on fire").into())
    }
    async fn find_author(&self, _: &Uuid) -> Result<Option<Author>, anyhow::Error> {
        Err(anyhow!("db on fire"))
    }
    async fn list_authors(&self, _: Option<&str>, _: usize) -> Result<CursorPage<Author>, anyhow::Error> {
        Err(anyhow!("db on fire"))
    }
}
```

### Spy — side-effect counting

```rust
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

#[derive(Clone, Default)]
struct SpyMetrics { success: Arc<AtomicU32>, failure: Arc<AtomicU32> }

impl AuthorMetrics for SpyMetrics {
    async fn record_creation_success(&self) { self.success.fetch_add(1, Ordering::SeqCst); }
    async fn record_creation_failure(&self) { self.failure.fetch_add(1, Ordering::SeqCst); }
}
```

### NoOp — for E2E tests

```rust
#[derive(Clone)]
struct NoOpMetrics;
impl AuthorMetrics for NoOpMetrics {
    async fn record_creation_success(&self) {}
    async fn record_creation_failure(&self) {}
}

#[derive(Clone)]
struct NoOpNotifier;
impl AuthorNotifier for NoOpNotifier {
    async fn author_created(&self, _: &Author) {}
}
```

### Test app helper

Tests use a different concrete composition (NoOp adapters) than production. The test helper must actually type-check, so `build_router` has to accept the test service type. There are two ways to make that work — pick one:

**Option A — `cfg(test)` alias (no signature change).** The `AppAuthorService` alias *is* the seam. Define it per build profile so `AppState`/`build_router` stay concrete and handler code is untouched; tests just swap the adapters behind the same alias name:

```rust
// src/composition.rs
#[cfg(not(test))]
pub type AppAuthorService = AuthorServiceImpl<Sqlite, Prometheus, EmailClient>;
#[cfg(test)]
pub type AppAuthorService = AuthorServiceImpl<Sqlite, NoOpMetrics, NoOpNotifier>;
```

```rust
// Under #[cfg(test)], `AppAuthorService` already names the NoOp composition,
// so `build_router` accepts it directly — no generics needed.
async fn test_app() -> Router {
    let pool = setup_test_db().await;
    let service: Arc<AppAuthorService> = Arc::new(
        AuthorServiceImpl::new(Sqlite::from_pool(pool.clone()), NoOpMetrics, NoOpNotifier),
    );
    let cfg = HttpServerConfig {
        port: "0",                          // unused — we don't bind a listener
        cors_origin: "http://localhost",
    };
    HttpServer::build_router(service, pool, &cfg).unwrap()  // Pool shared with readiness probe.
}
```

**Option B — generic `build_router` (one signature change).** Make `AppState` and `build_router` generic over `S: AuthorService`. Then any concrete service composition type-checks, production and test alike:

```rust
// src/inbound/http/server.rs
#[derive(Clone)]
pub struct AppState<S: AuthorService> {
    pub author_service: Arc<S>,
    pub db_pool: sqlx::SqlitePool,
}

impl HttpServer {
    pub fn build_router<S: AuthorService>(
        author_service: Arc<S>,
        db_pool: sqlx::SqlitePool,
        config: &HttpServerConfig<'_>,
    ) -> anyhow::Result<Router> { /* ... as before, State<AppState<S>> in handlers ... */ }
}

// Test then names its own composition and it just works:
type TestAuthorService = AuthorServiceImpl<Sqlite, NoOpMetrics, NoOpNotifier>;

async fn test_app() -> Router {
    let pool = setup_test_db().await;
    let service: Arc<TestAuthorService> = Arc::new(
        AuthorServiceImpl::new(Sqlite::from_pool(pool.clone()), NoOpMetrics, NoOpNotifier),
    );
    let cfg = HttpServerConfig { port: "0", cors_origin: "http://localhost" };
    HttpServer::build_router(service, pool, &cfg).unwrap()
}
```

Option A keeps handler signatures (`State<AppState>`) unchanged and is the lighter touch for a single binary; Option B is better if you genuinely want one router builder reused across multiple compositions. Either way the canonical `test_app` compiles — note that passing `Arc<TestAuthorService>` into a `build_router` hardcoded to `Arc<AppAuthorService>` does NOT type-check, which is exactly why the test composition must flow through the same alias (Option A) or a generic signature (Option B).

```rust
// Pattern 1: oneshot — single request per test
let app = test_app().await;
let res = app.oneshot(
    Request::post("/v1/authors")        // routes are nested under /v1
        .header("Content-Type", "application/json")
        .body(Body::from(r#"{"name":"Test"}"#)).unwrap(),
).await.unwrap();
assert_eq!(res.status(), StatusCode::CREATED);
// 201 carries the created resource's URI in the Location header.
let location = res.headers()["location"].to_str().unwrap().to_string();
assert!(location.starts_with("/v1/authors/"));

// Read response body — single resource is wrapped: `{ "data": { ... } }`.
let body = res.into_body().collect().await.unwrap().to_bytes();
let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
assert_eq!(json["data"]["name"], "Test");
```

### Multiple requests in one test

```rust
// Pattern 2: ready().call() — reuse the same service for multiple requests
use tower::{Service, ServiceExt};

let mut app = test_app().await.into_service();

// First request
let req = Request::post("/v1/authors")
    .header("Content-Type", "application/json")
    .body(Body::from(r#"{"name":"Alice"}"#)).unwrap();
let res = ServiceExt::<Request<Body>>::ready(&mut app)
    .await.unwrap().call(req).await.unwrap();
assert_eq!(res.status(), StatusCode::CREATED);

// Second request on same service
let req = Request::get("/v1/authors").body(Body::empty()).unwrap();
let res = ServiceExt::<Request<Body>>::ready(&mut app)
    .await.unwrap().call(req).await.unwrap();
assert_eq!(res.status(), StatusCode::OK);
```

### Integration test with `#[sqlx::test]`

```rust
#[sqlx::test]
async fn sqlite_duplicate_returns_domain_error(pool: SqlitePool) {
    let repo = Sqlite::from_pool(pool);
    let req = CreateAuthorRequest::new(AuthorName::new("Dup").unwrap());
    repo.create_author(&req).await.unwrap();
    let err = repo.create_author(&req).await.unwrap_err();
    assert!(matches!(err, CreateAuthorError::Duplicate { .. }));
}
```
