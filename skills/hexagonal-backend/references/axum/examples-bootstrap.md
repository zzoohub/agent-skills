# Axum examples — bootstrap, tests and CI

The workspace manifest, configuration, the app factory with its layer order, probes, telemetry, the three entrypoints with their shutdown sequences, the test harness, the HTTP and adapter tests, and the CI gates. Judgment behind the code: `guide.md`.

## Contents

1. [Workspace](#workspace)
2. [Configuration](#configuration)
3. [App factory and layer order](#app-factory-and-layer-order)
4. [Probes](#probes)
5. [Telemetry](#telemetry)
6. [Entrypoints and shutdown](#entrypoints-and-shutdown)
7. [Test harness](#test-harness)
8. [HTTP tests](#http-tests)
9. [Adapter tests](#adapter-tests)
10. [CI gates](#ci-gates)

## Workspace

The service crate at the root, `domain` as a member. Generated and committed beside these: `Cargo.lock`, `.sqlx/` (`cargo sqlx prepare --workspace -- --all-targets`) and `openapi.json` (`UPDATE_OPENAPI=1 cargo test openapi`).

```toml file=Cargo.toml
[workspace]
members = [".", "domain"]
resolver = "3"

[workspace.package]
edition = "2024"
rust-version = "1.94"

[workspace.dependencies]
anyhow = "1.0.104"
chrono = { version = "0.4.45", default-features = false, features = ["std"] }
thiserror = "2.0.21"
tokio = { version = "~1.53", features = ["macros", "net", "rt-multi-thread", "signal", "time"] }
tracing = "0.1.44"
uuid = { version = "1.27", features = ["v7"] }

[workspace.lints.rust]
unsafe_code = "forbid"

[workspace.lints.clippy]
dbg_macro = "deny"
todo = "deny"
unimplemented = "deny"

[package]
name = "articles"
version = "0.1.0"
edition.workspace = true
rust-version.workspace = true
publish = false

[dependencies]
domain = { path = "domain" }
anyhow.workspace = true
axum = { version = "0.8.9", features = ["macros"] }
base64 = "0.23.1"
chrono = { workspace = true, features = ["clock", "serde"] }
hmac = "0.13.0"
jsonwebtoken = { version = "11.1.0", default-features = false, features = ["aws_lc_rs"] }
opentelemetry = "0.33.0"
opentelemetry-http = "0.33.0"
opentelemetry-otlp = { version = "0.33.0", default-features = false, features = ["http-proto", "metrics", "reqwest-blocking-client", "trace"] }
opentelemetry_sdk = "0.33.0"
reqwest = { version = "0.13.5", default-features = false, features = ["json", "rustls"] }
secrecy = "0.10.3"
serde = { version = "1.0.229", features = ["derive"] }
serde_json = "1.0.151"
serde_path_to_error = "0.1.20"
sha2 = "0.11.0"
sqlx = { version = "0.9.0", default-features = false, features = ["chrono", "json", "macros", "migrate", "postgres", "runtime-tokio", "tls-rustls-aws-lc-rs", "uuid"] }
thiserror.workspace = true
tokio.workspace = true
tokio-util = { version = "0.7.19", features = ["rt"] }
tower = { version = "0.5.3", features = ["util"] }
tower-http = { version = "0.7.1", features = ["catch-panic", "cors", "request-id", "sensitive-headers", "set-header", "timeout", "trace"] }
tracing.workspace = true
tracing-opentelemetry = "0.34.0"
tracing-subscriber = { version = "0.3.23", features = ["env-filter", "json"] }
utoipa = { version = "6.0.0", features = ["chrono", "uuid"] }
utoipa-axum = "0.3.0"
uuid = { workspace = true, features = ["serde"] }

[dev-dependencies]
http-body-util = "0.1.5"

[lints]
workspace = true
```

```toml file=rustfmt.toml
max_width = 120
use_small_heuristics = "Max"
```

```rust file=src/lib.rs
//! The articles service: adapters and bootstrap around the `domain` crate.
pub mod config;
pub mod inbound;
pub mod outbound;
pub mod telemetry;
```

## Configuration

Read once, validated, and refused loudly: HS256 in production, a shutdown budget that does not fit the platform's grace period.

```rust file=src/config.rs
use std::time::Duration;

use anyhow::{Context as _, bail, ensure};
use axum::http::HeaderValue;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use secrecy::{SecretSlice, SecretString};

/// Parsed and validated at startup: a bad value stops the process before it serves.
/// Secrets are `secrecy` types, so `{:?}` never prints them.
#[derive(Debug)]
pub struct Config {
    pub port: u16,
    pub database: Database,
    pub jwt: Jwt,
    pub problem_base_uri: String,
    pub cors_origins: Vec<HeaderValue>,
    pub request_timeout: Duration,
    pub webhook_secrets: Vec<SecretSlice<u8>>,
    /// Kubernetes: keep serving while endpoints deregister. Cloud Run: 0 (traffic already moved).
    pub shutdown_delay: Duration,
}

#[derive(Debug)]
pub struct Database {
    pub url: SecretString,
    pub max_connections: u32,
    pub statement_timeout: Duration,
    pub idle_in_transaction_timeout: Duration,
}

#[derive(Debug)]
pub struct Jwt {
    pub issuer: String,
    pub audience: String,
    pub keys: JwtKeys,
}

#[derive(Debug)]
pub enum JwtKeys {
    Jwks { url: String },
    Hs256 { secret: SecretString },
}

impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        Self::load(|name| std::env::var(name).ok())
    }

    pub fn load(var: impl Fn(&str) -> Option<String>) -> anyhow::Result<Self> {
        let required = |name: &str| var(name).filter(|v| !v.is_empty()).with_context(|| format!("{name} must be set"));
        let number = |name: &str, default: u64| {
            var(name).map_or(Ok(default), |v| v.parse().with_context(|| format!("{name}: not an integer")))
        };
        let millis = |name: &str, default: u64| number(name, default).map(Duration::from_millis);
        let production = match var("APP_ENV").as_deref() {
            Some("production") => true,
            None | Some("development" | "test") => false,
            Some(other) => bail!("APP_ENV={other:?} is not production, development or test"),
        };
        let keys = match required("JWT_MODE")?.as_str() {
            "jwks" => JwtKeys::Jwks { url: required("JWT_JWKS_URL")? },
            "hs256" if production => bail!("JWT_MODE=hs256 is refused when APP_ENV=production"),
            "hs256" => JwtKeys::Hs256 { secret: required("JWT_HS256_SECRET")?.into() },
            other => bail!("JWT_MODE={other:?} is not jwks or hs256"),
        };
        let request_timeout = millis("REQUEST_TIMEOUT_MS", 8_000)?;
        let config = Self {
            port: u16::try_from(number("PORT", 8080)?)?,
            database: Database {
                url: required("DATABASE_URL")?.into(),
                max_connections: u32::try_from(number("DB_MAX_CONNECTIONS", 10)?)?,
                statement_timeout: request_timeout * 3 / 4, // the database gives up before the edge does
                idle_in_transaction_timeout: request_timeout,
            },
            jwt: Jwt { issuer: required("JWT_ISSUER")?, audience: required("JWT_AUDIENCE")?, keys },
            problem_base_uri: required("PROBLEM_BASE_URI")?,
            cors_origins: var("CORS_ORIGINS")
                .unwrap_or_default()
                .split(',')
                .filter(|o| !o.trim().is_empty())
                .map(|o| HeaderValue::from_str(o.trim()).with_context(|| format!("CORS_ORIGINS: {o:?}")))
                .collect::<anyhow::Result<_>>()?,
            request_timeout,
            webhook_secrets: required("WEBHOOK_SECRETS")?
                .split(',')
                .map(webhook_secret)
                .collect::<anyhow::Result<_>>()?,
            shutdown_delay: millis("SHUTDOWN_DELAY_MS", 0)?,
        };
        let grace = millis("SHUTDOWN_GRACE_MS", 10_000)?; // Cloud Run 10 s; Kubernetes default 30 s
        ensure!(config.problem_base_uri.ends_with('/'), "PROBLEM_BASE_URI must end with '/'");
        ensure!(
            config.shutdown_delay + config.drain_timeout() < grace,
            "shutdown delay + drain must fit SHUTDOWN_GRACE_MS"
        );
        Ok(config)
    }

    /// In-flight requests end by their deadline; one more second covers writing the response.
    pub fn drain_timeout(&self) -> Duration {
        self.request_timeout + Duration::from_secs(1)
    }

    /// A won idempotency key stays locked longer than any request can hold it.
    pub fn idempotency_lease(&self) -> Duration {
        self.request_timeout * 2
    }
}

/// Standard Webhooks format: `whsec_` + base64. Several during a rotation.
fn webhook_secret(raw: &str) -> anyhow::Result<SecretSlice<u8>> {
    let encoded = raw.trim().strip_prefix("whsec_").context("WEBHOOK_SECRETS entries start with whsec_")?;
    Ok(STANDARD.decode(encoded).context("WEBHOOK_SECRETS entry is not base64")?.into())
}

#[test]
fn refuses_unsafe_configuration() {
    let env = "DATABASE_URL=postgres://db/a JWT_MODE=hs256 JWT_HS256_SECRET=dev-secret JWT_ISSUER=i JWT_AUDIENCE=a \
        PROBLEM_BASE_URI=https://api.example.com/problems/ WEBHOOK_SECRETS=whsec_c2VjcmV0";
    let load = |extra: &str| {
        let vars: Vec<_> = format!("{extra} {env}")
            .split_whitespace()
            .filter_map(|kv| kv.split_once('='))
            .map(|(k, v)| (k.to_owned(), v.to_owned()))
            .collect();
        Config::load(|name| vars.iter().find(|(k, _)| k == name).map(|(_, v)| v.clone()))
    };
    assert!(!format!("{:?}", load("").unwrap()).contains("dev-secret"));
    assert!(load("APP_ENV=production").is_err(), "HS256 in production");
    assert!(load("SHUTDOWN_DELAY_MS=5000").is_err(), "5 s + 9 s drain > Cloud Run's 10 s");
    assert!(load("SHUTDOWN_DELAY_MS=5000 SHUTDOWN_GRACE_MS=30000").is_ok());
}
```

## App factory and layer order

```rust file=src/inbound/http/mod.rs
//! The HTTP adapter: the app factory, its layer stack and the OpenAPI document.
pub mod articles;
pub mod auth;
pub mod extract;
pub mod idempotency;
pub mod probes;
pub mod problem;

use std::{any::Any, sync::Arc, time::Duration};

use axum::Router;
use axum::extract::{DefaultBodyLimit, MatchedPath, Request};
use axum::http::{HeaderName, HeaderValue, Method, StatusCode, header};
use axum::middleware::{from_fn_with_state, map_request};
use axum::response::{IntoResponse, Response};
use domain::{Articles, IdempotencyStore};
use opentelemetry::trace::{TraceContextExt, TraceId};
use secrecy::SecretSlice;
use tower::ServiceBuilder;
use tower_http::{
    catch_panic::CatchPanicLayer, cors::CorsLayer, request_id::*,
    sensitive_headers::SetSensitiveRequestHeadersLayer, set_header::response::SetMultipleResponseHeadersLayer,
    timeout::TimeoutLayer, trace::DefaultOnResponse, trace::TraceLayer,
};
use tracing_opentelemetry::OpenTelemetrySpanExt;
use utoipa::openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme};
use utoipa::{Modify, OpenApi};
use utoipa_axum::{router::OpenApiRouter, router::UtoipaMethodRouterExt, routes};

use self::problem::{ApiError, ProblemType};
use crate::inbound::webhooks;

/// Every JSON body, the idempotency buffer and the webhook included.
pub const MAX_BODY: usize = 64 * 1024;

/// Generic over the driving port, so a test can serve any `Articles`.
pub struct AppState<A> {
    pub articles: Arc<A>,
}

// derive(Clone) would demand `A: Clone`; the use cases are shared through the Arc.
impl<A> Clone for AppState<A> {
    fn clone(&self) -> Self {
        Self { articles: self.articles.clone() }
    }
}

pub struct Deps<A, I> {
    pub articles: Arc<A>,
    pub idempotency: Arc<I>,
    pub auth: Arc<auth::Authenticator>,
    pub readiness: probes::Readiness,
    pub webhook_secrets: Vec<SecretSlice<u8>>,
    pub problem_base: Arc<str>,
    pub cors_origins: Vec<HeaderValue>,
    pub request_timeout: Duration,
}

#[derive(OpenApi)]
#[openapi(info(title = "Articles API", version = "1.0.0"), components(schemas(problem::Problem)), modifiers(&BearerAuth))]
struct ApiDoc;

struct BearerAuth;

impl Modify for BearerAuth {
    fn modify(&self, api: &mut utoipa::openapi::OpenApi) {
        let bearer = HttpBuilder::new().scheme(HttpAuthScheme::Bearer).bearer_format("JWT").build();
        api.components.get_or_insert_default().add_security_scheme("bearer", SecurityScheme::Http(bearer));
    }
}

/// The app factory: `main` serves it, tests drive it with `oneshot` (no port bound).
pub fn app<A: Articles, I: IdempotencyStore>(deps: Deps<A, I>) -> (Router, utoipa::openapi::OpenApi) {
    let idempotency =
        idempotency::IdempotencyState { store: deps.idempotency, problem_base: deps.problem_base.clone() };
    let idempotent = from_fn_with_state(idempotency, idempotency::idempotent::<I>);
    let (v1, api) = OpenApiRouter::with_openapi(ApiDoc::openapi())
        .routes(routes!(articles::create_article).layer(idempotent.clone()))
        .routes(routes!(articles::list_articles))
        .routes(routes!(articles::get_article, articles::update_article))
        .routes(routes!(articles::publish_article).layer(idempotent))
        // route_layer: matched routes only (unknown paths stay 404), outside per-route layers.
        .route_layer(from_fn_with_state(deps.auth, auth::authenticate))
        .layer(DefaultBodyLimit::max(MAX_BODY))
        .with_state(AppState { articles: deps.articles.clone() })
        .split_for_parts();

    let router = Router::new()
        .merge(v1)
        .merge(webhooks::router(deps.articles, deps.webhook_secrets)) // internal: own auth, not in OpenAPI
        .merge(probes::router(deps.readiness)) // before auth and any rate limit
        .fallback(|| async { ApiError::new(ProblemType::NotFound, "No route matches this path") })
        .method_not_allowed_fallback(|| async {
            ApiError::new(ProblemType::MethodNotAllowed, "Method not allowed here")
        })
        // Outer to inner. Request id and CORS wrap every layer that can answer by itself
        // (problem renderer, timeout, panic), so those answers carry both.
        .layer(
            ServiceBuilder::new()
                .layer(map_request(drop_unsafe_request_id))
                .layer(SetRequestIdLayer::x_request_id(MakeRequestUuid))
                .layer(SetSensitiveRequestHeadersLayer::new([header::AUTHORIZATION, header::COOKIE]))
                .layer(
                    TraceLayer::new_for_http()
                        .make_span_with(request_span)
                        .on_response(DefaultOnResponse::new().level(tracing::Level::INFO))
                        .on_failure(()), // a 5xx is logged once, where its cause is known
                )
                .layer(PropagateRequestIdLayer::x_request_id())
                .layer(SetMultipleResponseHeadersLayer::if_not_present(vec![
                    (header::CACHE_CONTROL, HeaderValue::from_static("no-store")).into(),
                    (header::X_CONTENT_TYPE_OPTIONS, HeaderValue::from_static("nosniff")).into(),
                    (header::X_FRAME_OPTIONS, HeaderValue::from_static("DENY")).into(),
                    (header::CONTENT_SECURITY_POLICY, HeaderValue::from_static("default-src 'none'")).into(),
                    (header::STRICT_TRANSPORT_SECURITY, HeaderValue::from_static("max-age=63072000")).into(),
                ]))
                .layer(cors(deps.cors_origins))
                .layer(from_fn_with_state(deps.problem_base, problem::render_problems))
                // Drops the handler future at the deadline: work after a commit must be in the outbox.
                .layer(TimeoutLayer::with_status_code(StatusCode::SERVICE_UNAVAILABLE, deps.request_timeout))
                .layer(CatchPanicLayer::custom(on_panic)),
        );
    (router, api)
}

fn cors(origins: Vec<HeaderValue>) -> CorsLayer {
    let request_id = HeaderName::from_static("x-request-id");
    let idempotency_key = HeaderName::from_static("idempotency-key");
    CorsLayer::new()
        .allow_origin(origins)
        .allow_methods([Method::GET, Method::POST, Method::PATCH])
        .allow_headers([
            header::AUTHORIZATION,
            header::CONTENT_TYPE,
            header::IF_MATCH,
            idempotency_key,
            request_id.clone(),
        ])
        .expose_headers([header::LOCATION, header::ETAG, header::RETRY_AFTER, request_id])
        .max_age(Duration::from_secs(600))
}

/// An inbound id is echoed only if it is a bounded token; otherwise a fresh one is generated.
async fn drop_unsafe_request_id(mut req: Request) -> Request {
    let safe = |v: &HeaderValue| {
        v.len() <= 128 && v.as_bytes().iter().all(|b| b.is_ascii_alphanumeric() || b"._:-".contains(b))
    };
    if !req.headers().get("x-request-id").is_some_and(safe) {
        req.headers_mut().remove("x-request-id");
    }
    req
}

/// One span per request: route template (never the raw path), request id, the caller's W3C
/// trace as parent, and the trace id as a field so JSON logs carry it.
fn request_span(req: &Request) -> tracing::Span {
    let route = req.extensions().get::<MatchedPath>().map_or("unmatched", MatchedPath::as_str);
    let request_id = req.headers().get("x-request-id").and_then(|v| v.to_str().ok()).unwrap_or_default();
    let span =
        tracing::info_span!("request", method = %req.method(), route, request_id, trace_id = tracing::field::Empty);
    let headers = opentelemetry_http::HeaderExtractor(req.headers());
    let _ = span.set_parent(opentelemetry::global::get_text_map_propagator(|p| p.extract(&headers))); // no-op in tests
    let trace_id = span.context().span().span_context().trace_id();
    if trace_id != TraceId::INVALID {
        span.record("trace_id", tracing::field::display(trace_id));
    }
    span
}

fn on_panic(panic: Box<dyn Any + Send + 'static>) -> Response {
    let message = panic.downcast_ref::<&str>().copied().or_else(|| panic.downcast_ref::<String>().map(String::as_str));
    tracing::error!(panic = message.unwrap_or("non-string payload"), "handler panicked");
    ApiError::internal().into_response()
}
```

## Probes

```rust file=src/inbound/http/probes.rs
use std::sync::{Arc, atomic::AtomicBool, atomic::Ordering::SeqCst};

use axum::{Json, Router, extract::State, http::header, routing::get};
use serde_json::{Value, json};

use super::problem::{ApiError, ProblemType};

/// Instance-local: false until startup checks pass, false again from SIGTERM. It never touches
/// the database: a shared dependency failing must not take every replica out of rotation.
#[derive(Clone, Default)]
pub struct Readiness(Arc<[AtomicBool; 2]>); // [started, draining]

impl Readiness {
    pub fn mark_ready(&self) {
        self.0[0].store(true, SeqCst);
    }

    pub fn start_draining(&self) {
        self.0[1].store(true, SeqCst);
    }
}

pub fn router(readiness: Readiness) -> Router {
    Router::new()
        .route("/health", get(|| async { Json(json!({ "status": "ok" })) })) // liveness: no dependencies
        .route("/ready", get(ready))
        .with_state(readiness)
}

async fn ready(State(Readiness(flags)): State<Readiness>) -> Result<Json<Value>, ApiError> {
    if flags[0].load(SeqCst) && !flags[1].load(SeqCst) {
        return Ok(Json(json!({ "status": "ready" })));
    }
    Err(ApiError::new(ProblemType::Unavailable, "Not ready").with_header(header::RETRY_AFTER, "1"))
}
```

## Telemetry

```rust file=src/telemetry.rs
use std::time::Duration;

use opentelemetry::global;
use opentelemetry::trace::TracerProvider as _;
use opentelemetry_sdk::Resource;
use opentelemetry_sdk::metrics::SdkMeterProvider;
use opentelemetry_sdk::propagation::TraceContextPropagator;
use opentelemetry_sdk::trace::SdkTracerProvider;
use tracing_subscriber::EnvFilter;
use tracing_subscriber::layer::SubscriberExt as _;
use tracing_subscriber::util::SubscriberInitExt as _;

/// Owns the OTel providers so shutdown can flush them. Without
/// `OTEL_EXPORTER_OTLP_ENDPOINT` (tests, local runs) nothing is exported.
pub struct Telemetry {
    tracer: Option<SdkTracerProvider>,
    meter: Option<SdkMeterProvider>,
}

/// JSON logs (span fields carry `request_id` and `trace_id`) plus OTel traces and metrics.
/// `RUST_LOG` overrides the `info` default.
pub fn init(service: &'static str) -> anyhow::Result<Telemetry> {
    global::set_text_map_propagator(TraceContextPropagator::new());
    let (tracer, meter) = if std::env::var_os("OTEL_EXPORTER_OTLP_ENDPOINT").is_some() {
        let resource = Resource::builder().with_service_name(service).build();
        let spans = opentelemetry_otlp::SpanExporter::builder().with_http().build()?;
        let metrics = opentelemetry_otlp::MetricExporter::builder().with_http().build()?;
        let tracer = SdkTracerProvider::builder().with_resource(resource.clone()).with_batch_exporter(spans).build();
        let meter = SdkMeterProvider::builder().with_resource(resource).with_periodic_exporter(metrics).build();
        global::set_meter_provider(meter.clone());
        (Some(tracer), Some(meter))
    } else {
        (None, None)
    };
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(tracing_subscriber::fmt::layer().json().flatten_event(true).with_span_list(false))
        .with(tracer.as_ref().map(|p| tracing_opentelemetry::layer().with_tracer(p.tracer(service))))
        .try_init()?;
    Ok(Telemetry { tracer, meter })
}

impl Telemetry {
    /// The last shutdown step: flush what is buffered, within the platform's grace period.
    pub fn shutdown(self) {
        if let Some(tracer) = self.tracer
            && let Err(e) = tracer.shutdown_with_timeout(Duration::from_millis(500))
        {
            eprintln!("trace flush failed: {e}");
        }
        if let Some(meter) = self.meter
            && let Err(e) = meter.shutdown()
        {
            eprintln!("metric flush failed: {e}");
        }
    }
}
```

## Entrypoints and shutdown

```rust file=src/main.rs
use std::{sync::Arc, time::Duration};

use articles::inbound::http::{self, Deps, auth::Authenticator, probes::Readiness};
use articles::outbound::postgres::{MIGRATOR, PgStore, Relay, RelayConfig};
use articles::outbound::{SystemClock, UuidV7, publisher::LogPublisher};
use articles::{config::Config, telemetry};
use domain::{IdempotencyStore, Publishing};
use tokio::signal::unix::{SignalKind, signal};
use tokio_util::{sync::CancellationToken, task::TaskTracker};

/// One image, three processes: `serve` (HTTP), `worker` (outbox relay and key purge) and
/// `migrate` (the release step, run once before a new version starts).
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = Config::from_env()?;
    let telemetry = telemetry::init("articles")?;
    let result = match std::env::args().nth(1).as_deref() {
        None | Some("serve") => serve(config).await,
        Some("worker") => worker(config).await,
        Some("migrate") => migrate(config).await,
        Some(other) => Err(anyhow::anyhow!("unknown command {other:?}: use serve, worker or migrate")),
    };
    if let Err(e) = &result {
        tracing::error!(error = format!("{e:#}"), "exiting");
    }
    telemetry.shutdown(); // last: flush spans and metrics
    result
}

async fn serve(mut config: Config) -> anyhow::Result<()> {
    let store = PgStore::connect(&config.database, config.idempotency_lease()).await?;
    let readiness = Readiness::default();
    let (app, _) = http::app(Deps {
        articles: Arc::new(Publishing::new(store.clone(), SystemClock, UuidV7)),
        idempotency: Arc::new(store.clone()),
        auth: Arc::new(Authenticator::new(&config.jwt)?),
        readiness: readiness.clone(),
        webhook_secrets: std::mem::take(&mut config.webhook_secrets),
        problem_base: config.problem_base_uri.as_str().into(),
        cors_origins: std::mem::take(&mut config.cors_origins),
        request_timeout: config.request_timeout,
    });
    let mut terminate = signal(SignalKind::terminate())?;
    let listener = tokio::net::TcpListener::bind(("0.0.0.0", config.port)).await?;
    let stop = CancellationToken::new();
    let server =
        tokio::spawn(axum::serve(listener, app).with_graceful_shutdown(stop.clone().cancelled_owned()).into_future());
    readiness.mark_ready();

    tokio::select! {
        _ = terminate.recv() => {}
        _ = tokio::signal::ctrl_c() => {}
    }
    readiness.start_draining(); // 503 from now on
    tokio::time::sleep(config.shutdown_delay).await; // Kubernetes: endpoints deregister asynchronously
    stop.cancel(); // stop accepting; in-flight requests finish by their deadline
    match tokio::time::timeout(config.drain_timeout(), server).await {
        Ok(joined) => joined??,
        Err(_) => tracing::warn!("drain deadline passed; dropping open connections"),
    }
    store.pool().close().await;
    Ok(())
}

async fn worker(config: Config) -> anyhow::Result<()> {
    let store = PgStore::connect(&config.database, config.idempotency_lease()).await?;
    let mut terminate = signal(SignalKind::terminate())?;
    let (stop, tasks) = (CancellationToken::new(), TaskTracker::new());
    tasks.spawn(Relay::new(store.clone(), LogPublisher, RelayConfig::default()).run(stop.clone()));
    tasks.spawn(purge_expired_keys(store.clone(), stop.clone()));
    tasks.close();

    tokio::select! {
        _ = terminate.recv() => {}
        _ = tokio::signal::ctrl_c() => {}
    }
    stop.cancel(); // stop claiming; a relay pass in progress finishes, or its leases lapse
    if tokio::time::timeout(config.drain_timeout(), tasks.wait()).await.is_err() {
        tracing::warn!("background tasks outlived the drain deadline");
    }
    store.pool().close().await;
    Ok(())
}

/// Idempotent DELETE: every worker replica may run it.
async fn purge_expired_keys(store: PgStore, stop: CancellationToken) {
    let mut tick = tokio::time::interval(Duration::from_secs(300));
    while stop.run_until_cancelled(tick.tick()).await.is_some() {
        if let Err(e) = store.purge_expired().await {
            tracing::warn!(error = format!("{e:#}"), "idempotency purge failed");
        }
    }
}

async fn migrate(mut config: Config) -> anyhow::Result<()> {
    config.database.statement_timeout = Duration::from_secs(15 * 60); // long DDL; each file sets its lock_timeout
    let store = PgStore::connect(&config.database, config.idempotency_lease()).await?;
    MIGRATOR.run(store.pool()).await?; // under an advisory lock: concurrent runs wait, never race
    Ok(())
}
```

## Test harness

One integration-test binary; each `#[sqlx::test]` runs on a fresh database migrated from empty.

```rust file=tests/api/main.rs
//! One integration-test binary (one link step). Every `#[sqlx::test]` gets a fresh database
//! with ./migrations applied from empty; DATABASE_URL must point at a PostgreSQL 18 server.
mod http;
mod postgres;
mod support;
```

```rust file=tests/api/support.rs
use std::sync::Arc;
use std::time::Duration;

use articles::config::{Jwt, JwtKeys};
use articles::inbound::http::{self, Deps, auth::Authenticator, probes::Readiness};
use articles::outbound::postgres::PgStore;
use articles::outbound::{SystemClock, UuidV7};
use axum::Router;
use axum::body::Body;
use axum::http::{HeaderMap, HeaderValue, Request, StatusCode, request::Builder};
use base64::Engine as _;
use domain::{Actor, Articles, NewArticle, Publishing, TenantId};
use hmac::{Hmac, KeyInit, Mac};
use http_body_util::BodyExt as _;
use serde_json::{Value, json};
use sqlx::PgPool;
use tower::ServiceExt as _;
use uuid::Uuid;

pub const TENANT_A: Uuid = Uuid::from_u128(0xA);
pub const TENANT_B: Uuid = Uuid::from_u128(0xB);
pub const PROBLEMS: &str = "https://api.example.com/problems/";
pub const WEBHOOK_KEY: &[u8] = b"test-webhook-key";
const JWT_SECRET: &str = "test-jwt-secret";

pub fn store(pool: &PgPool) -> PgStore {
    PgStore::new(pool.clone(), Duration::from_secs(4))
}

pub fn publishing(pool: &PgPool) -> Publishing<PgStore, SystemClock, UuidV7> {
    Publishing::new(store(pool), SystemClock, UuidV7)
}

pub struct TestApp {
    pub router: Router,
    pub readiness: Readiness,
    pub openapi: utoipa::openapi::OpenApi,
}

/// The production app factory over the test database (HS256 tokens, 2 s request deadline).
pub fn app(pool: &PgPool) -> TestApp {
    app_with(Arc::new(publishing(pool)), pool, Duration::from_secs(2))
}

/// Same factory, any `Articles` implementation: the generic state is the test seam.
pub fn app_with<A: Articles>(articles: Arc<A>, pool: &PgPool, request_timeout: Duration) -> TestApp {
    let jwt = Jwt {
        issuer: "https://id.example.com/".into(),
        audience: "articles".into(),
        keys: JwtKeys::Hs256 { secret: JWT_SECRET.to_owned().into() },
    };
    let readiness = Readiness::default();
    let (router, openapi) = http::app(Deps {
        articles,
        idempotency: Arc::new(store(pool)),
        auth: Arc::new(Authenticator::new(&jwt).unwrap()),
        readiness: readiness.clone(),
        webhook_secrets: vec![WEBHOOK_KEY.to_vec().into()],
        problem_base: PROBLEMS.into(),
        cors_origins: vec![HeaderValue::from_static("https://app.example.com")],
        request_timeout,
    });
    TestApp { router, readiness, openapi }
}

pub fn actor(tenant: Uuid, subject: &str, roles: &[&str]) -> Actor {
    Actor { tenant_id: TenantId(tenant), subject: subject.into(), roles: roles.iter().map(|r| (*r).into()).collect() }
}

pub fn input(slug: &str) -> NewArticle {
    NewArticle { slug: slug.into(), title: "Title".into(), body: String::new() }
}

pub fn token(tenant: Uuid, subject: &str, roles: &[&str]) -> String {
    let exp = chrono::Utc::now().timestamp() + 300;
    let claims = json!({ "sub": subject, "tid": tenant, "roles": roles, "exp": exp,
        "iss": "https://id.example.com/", "aud": "articles" });
    let key = jsonwebtoken::EncodingKey::from_secret(JWT_SECRET.as_bytes());
    jsonwebtoken::encode(&jsonwebtoken::Header::default(), &claims, &key).unwrap()
}

/// A Standard Webhooks delivery signed with `key`.
pub fn webhook(id: &str, payload: &Value, timestamp: i64, key: &[u8]) -> Request<Body> {
    let body = payload.to_string();
    let mut mac = Hmac::<sha2::Sha256>::new_from_slice(key).unwrap();
    mac.update(format!("{id}.{timestamp}.{body}").as_bytes());
    let signature = base64::engine::general_purpose::STANDARD.encode(mac.finalize().into_bytes());
    Request::post("/internal/webhooks/moderation")
        .header("webhook-id", id)
        .header("webhook-timestamp", timestamp.to_string())
        .header("webhook-signature", format!("v1,{signature}"))
        .json_body(payload)
}

pub trait RequestExt {
    fn bearer(self, token: &str) -> Builder;
    fn json_body(self, body: &Value) -> Request<Body>;
    fn empty(self) -> Request<Body>;
}

impl RequestExt for Builder {
    fn bearer(self, token: &str) -> Builder {
        self.header("authorization", format!("Bearer {token}"))
    }
    fn json_body(self, body: &Value) -> Request<Body> {
        self.header("content-type", "application/json").body(Body::from(body.to_string())).unwrap()
    }
    fn empty(self) -> Request<Body> {
        self.body(Body::empty()).unwrap()
    }
}

pub struct Reply {
    pub status: StatusCode,
    pub headers: HeaderMap,
    pub body: Value,
}

impl Reply {
    pub fn header(&self, name: &str) -> &str {
        self.headers.get(name).and_then(|v| v.to_str().ok()).unwrap_or_default()
    }

    /// An RFC 9457 document of the registry type `slug`, for `instance`.
    pub fn assert_problem(&self, status: u16, slug: &str, instance: &str) {
        assert_eq!(self.status.as_u16(), status, "{}", self.body);
        assert_eq!(self.header("content-type"), "application/problem+json");
        assert_eq!(self.body["type"], format!("{PROBLEMS}{slug}"));
        assert_eq!(
            (self.body["status"].as_u64(), self.body["instance"].as_str()),
            (Some(status.into()), Some(instance))
        );
        assert!(!self.header("x-request-id").is_empty());
    }
}

/// Serves one request through the full stack, without binding a port.
pub async fn send(app: &TestApp, req: Request<Body>) -> Reply {
    let (parts, body) = app.router.clone().oneshot(req).await.unwrap().into_parts();
    let bytes = body.collect().await.unwrap().to_bytes();
    Reply { status: parts.status, headers: parts.headers, body: serde_json::from_slice(&bytes).unwrap_or(Value::Null) }
}
```

## HTTP tests

The problem matrix, request ids, conditional writes, pagination, idempotency, the webhook, readiness, cancellation at the deadline and the OpenAPI snapshot, all through the production app factory.

```rust file=tests/api/http.rs
use std::sync::Arc;
use std::time::Duration;

use axum::body::Body;
use axum::http::Request;
use serde_json::{Value, json};
use sqlx::PgPool;

use crate::support::*;

async fn create(app: &TestApp, token: &str, slug: &str) -> Reply {
    send(app, Request::post("/v1/articles").bearer(token).json_body(&json!({ "slug": slug, "title": "Hello" }))).await
}

#[sqlx::test]
async fn every_error_is_a_problem_document(pool: PgPool) {
    let app = app(&pool);
    let (ann, bob) = (token(TENANT_A, "ann", &[]), token(TENANT_A, "bob", &[]));
    let path = create(&app, &ann, "hello").await.header("location").to_owned();
    let problem = async |req: Request<Body>, status: u16, slug: &str, instance: &str| {
        let reply = send(&app, req).await;
        reply.assert_problem(status, slug, instance);
        reply
    };
    let articles = "/v1/articles";
    let post = || Request::post(articles).bearer(&ann);

    let no_token = problem(Request::get("/v1/articles?limit=5").empty(), 401, "unauthenticated", articles).await;
    assert_eq!(no_token.header("www-authenticate"), "Bearer"); // and `instance` dropped the query
    problem(Request::get(articles).bearer("not-a-jwt").empty(), 401, "unauthenticated", articles).await;
    let publish = format!("{path}/publish");
    problem(Request::post(&publish).bearer(&bob).empty(), 403, "forbidden", &publish).await;
    problem(Request::get(&path).bearer(&token(TENANT_B, "ann", &[])).empty(), 404, "not-found", &path).await;
    problem(Request::get("/v1/nothing-here").empty(), 404, "not-found", "/v1/nothing-here").await;
    let delete = problem(Request::delete(articles).bearer(&ann).empty(), 405, "method-not-allowed", articles).await;
    assert_eq!(delete.header("allow"), "POST,GET,HEAD");

    let unparseable = post().header("content-type", "application/json").body(Body::from("{")).unwrap();
    problem(unparseable, 400, "malformed-request", articles).await;
    problem(Request::get("/v1/articles/42").bearer(&ann).empty(), 400, "malformed-request", "/v1/articles/42").await;
    problem(Request::get("/v1/articles?cursor=bm9wZQ").bearer(&ann).empty(), 400, "malformed-request", articles).await;
    let bad_key = post().header("idempotency-key", "").json_body(&json!({}));
    problem(bad_key, 400, "malformed-request", articles).await;
    let oversized = json!({ "slug": "big", "title": "Big", "body": "x".repeat(70_000) });
    problem(post().json_body(&oversized), 413, "payload-too-large", articles).await;
    let text = post().header("content-type", "text/plain").body(Body::from("x")).unwrap();
    problem(text, 415, "unsupported-media-type", articles).await;

    let invalid =
        problem(post().json_body(&json!({ "slug": "Bad Slug", "title": " " })), 422, "validation-failed", articles);
    let invalid = invalid.await.body["errors"].clone();
    assert_eq!((invalid[0]["pointer"].as_str(), invalid[1]["pointer"].as_str()), (Some("#/slug"), Some("#/title")));
    assert_eq!(invalid[1]["code"], "required");
    let mass_assignment = json!({ "slug": "a", "title": "T", "owner": "mallory" });
    let unknown = problem(post().json_body(&mass_assignment), 422, "validation-failed", articles).await;
    assert_eq!(
        (&unknown.body["errors"][0]["pointer"], &unknown.body["errors"][0]["code"]),
        (&json!("#/owner"), &json!("unknown_field"))
    );
    let limit =
        problem(Request::get("/v1/articles?limit=0").bearer(&ann).empty(), 422, "validation-failed", articles).await;
    assert_eq!(limit.body["errors"][0]["parameter"], "limit");
}

#[sqlx::test]
async fn request_ids_and_the_cors_preflight(pool: PgPool) {
    let app = app(&pool);
    let echoed = send(&app, Request::get("/health").header("x-request-id", "edge-7f3c.2").empty()).await;
    assert_eq!((echoed.status.as_u16(), echoed.header("x-request-id")), (200, "edge-7f3c.2"));
    let replaced = send(&app, Request::get("/health").header("x-request-id", "<script>").empty()).await;
    assert!(uuid::Uuid::parse_str(replaced.header("x-request-id")).is_ok());
    let preflight = Request::options("/v1/articles")
        .header("origin", "https://app.example.com")
        .header("access-control-request-method", "POST")
        .header("access-control-request-headers", "authorization,content-type,idempotency-key");
    let preflight = send(&app, preflight.empty()).await;
    assert_eq!(preflight.header("access-control-allow-origin"), "https://app.example.com");
    assert!(preflight.header("access-control-allow-headers").contains("idempotency-key"));
    assert!(!preflight.header("x-request-id").is_empty());
}

#[sqlx::test]
async fn create_read_and_conditional_update(pool: PgPool) {
    let app = app(&pool);
    let ann = token(TENANT_A, "ann", &[]);
    let created = create(&app, &ann, "hello").await;
    assert_eq!((created.status.as_u16(), created.header("etag")), (201, "\"1\""));
    let location = created.header("location").to_owned();
    let read = send(&app, Request::get(&location).bearer(&ann).empty()).await;
    assert_eq!(read.body, created.body, "same representation, microseconds included");
    let patch = |if_match: &str, body: Value| {
        Request::patch(&location).bearer(&ann).header("if-match", if_match).json_body(&body)
    };
    let patched = send(&app, patch("\"1\"", json!({ "title": "Hi", "body": null }))).await;
    assert_eq!((patched.header("etag"), &patched.body["data"]["title"]), ("\"2\"", &json!("Hi")));
    send(&app, patch("\"1\"", json!({ "title": "Late" }))).await.assert_problem(412, "precondition-failed", &location);
    let null_title = send(&app, patch("*", json!({ "title": null }))).await;
    null_title.assert_problem(422, "validation-failed", &location);
    assert_eq!(null_title.body["errors"][0]["pointer"], "#/title");
}

#[sqlx::test]
async fn list_pages_newest_first_with_a_clamped_limit(pool: PgPool) {
    let app = app(&pool);
    let ann = token(TENANT_A, "ann", &[]);
    for slug in ["one", "two", "three"] {
        create(&app, &ann, slug).await;
    }
    let first = send(&app, Request::get("/v1/articles?limit=2").bearer(&ann).empty()).await;
    assert_eq!(
        (first.body["data"][0]["slug"].as_str(), first.body["meta"]["has_more"].as_bool()),
        (Some("three"), Some(true))
    );
    let cursor = first.body["meta"]["next_cursor"].as_str().unwrap();
    let last = send(&app, Request::get(format!("/v1/articles?limit=2&cursor={cursor}")).bearer(&ann).empty()).await;
    assert_eq!(last.body["data"].as_array().map(Vec::len), Some(1));
    assert_eq!(last.body["meta"], json!({ "limit": 2, "next_cursor": null, "has_more": false }));
    let clamped = send(&app, Request::get("/v1/articles?limit=500").bearer(&ann).empty()).await;
    assert_eq!(clamped.body["meta"]["limit"], 100);
}

#[sqlx::test]
async fn idempotency_keys_replay_reject_mismatches_and_report_in_flight(pool: PgPool) {
    let app = app(&pool);
    let ann = token(TENANT_A, "ann", &[]);
    let post = |key: &str, body: Value| {
        Request::post("/v1/articles").bearer(&ann).header("idempotency-key", key).json_body(&body)
    };
    let first = send(&app, post("k1", json!({ "slug": "a", "title": "A" }))).await;
    let replay = send(&app, post("k1", json!({ "title": "A", "slug": "a" }))).await; // same body, keys reordered
    assert_eq!(
        (first.status.as_u16(), replay.status.as_u16(), replay.header("idempotent-replayed")),
        (201, 201, "true")
    );
    assert_eq!((replay.header("location"), &replay.body), (first.header("location"), &first.body));
    send(&app, post("k1", json!({ "slug": "b", "title": "B" }))).await.assert_problem(
        422,
        "idempotency-key-mismatch",
        "/v1/articles",
    );

    send(&app, post("k2", json!({ "slug": "c", "title": "C" }))).await;
    sqlx::query(
        "UPDATE idempotency_keys SET completed_at = NULL, locked_until = now() + interval '1 minute' WHERE key = 'k2'",
    )
    .execute(&pool)
    .await
    .unwrap(); // as if the first request were still running
    let in_flight = send(&app, post("k2", json!({ "slug": "c", "title": "C" }))).await;
    in_flight.assert_problem(409, "idempotency-in-flight", "/v1/articles");
    assert_eq!(in_flight.header("retry-after"), "1");

    // The completion committed with the publish: a retry replays 200 instead of a 409 transition error.
    let publish = format!("{}/publish", first.header("location"));
    let once = send(&app, Request::post(&publish).bearer(&ann).header("idempotency-key", "k3").empty()).await;
    let twice = send(&app, Request::post(&publish).bearer(&ann).header("idempotency-key", "k3").empty()).await;
    assert_eq!((once.status.as_u16(), twice.status.as_u16(), twice.header("etag")), (200, 200, "\"2\""));
}

#[sqlx::test]
async fn moderation_webhook_verifies_dedups_and_acknowledges(pool: PgPool) {
    let app = app(&pool);
    let ann = token(TENANT_A, "ann", &[]);
    let location = create(&app, &ann, "hello").await.header("location").to_owned();
    send(&app, Request::post(format!("{location}/publish")).bearer(&ann).empty()).await;
    let id = location.rsplit('/').next().unwrap();
    let verdict = json!({ "tenant_id": TENANT_A, "article_id": id, "verdict": "rejected" });
    let now = chrono::Utc::now().timestamp();
    let path = "/internal/webhooks/moderation";
    send(&app, webhook("msg_1", &verdict, now, b"forged")).await.assert_problem(401, "unauthenticated", path);
    send(&app, webhook("msg_1", &verdict, now - 301, WEBHOOK_KEY)).await.assert_problem(401, "unauthenticated", path);
    for _ in 0..2 {
        assert_eq!(send(&app, webhook("msg_1", &verdict, now, WEBHOOK_KEY)).await.status.as_u16(), 204);
    }
    let article = send(&app, Request::get(&location).bearer(&ann).empty()).await;
    assert_eq!((article.body["data"]["status"].as_str(), article.header("etag")), (Some("archived"), "\"3\""));
}

#[sqlx::test]
async fn readiness_is_latched_and_drops_while_draining(pool: PgPool) {
    let app = app(&pool);
    let ready = || send(&app, Request::get("/ready").empty());
    ready().await.assert_problem(503, "unavailable", "/ready");
    app.readiness.mark_ready();
    assert_eq!(ready().await.status.as_u16(), 200);
    app.readiness.start_draining();
    ready().await.assert_problem(503, "unavailable", "/ready");
    assert_eq!(send(&app, Request::get("/health").empty()).await.status.as_u16(), 200);
}

#[sqlx::test]
async fn a_deadline_cancels_the_handler_rolls_back_and_frees_the_key(pool: PgPool) {
    let app = app_with(Arc::new(publishing(&pool)), &pool, Duration::from_millis(300));
    let ann = token(TENANT_A, "ann", &[]);
    let location = create(&app, &ann, "hello").await.header("location").to_owned();
    let publish = || {
        let req = Request::post(format!("{location}/publish")).header("origin", "https://app.example.com");
        req.header("idempotency-key", "k1").bearer(&ann).empty()
    };
    // Another transaction holds the row lock that publish needs.
    let mut blocker = pool.begin().await.unwrap();
    sqlx::query("SELECT 1 FROM articles FOR UPDATE").execute(&mut *blocker).await.unwrap();
    let timed_out = send(&app, publish()).await;
    timed_out.assert_problem(503, "unavailable", &format!("{location}/publish"));
    assert_eq!(timed_out.header("access-control-allow-origin"), "https://app.example.com");
    blocker.rollback().await.unwrap();
    // The dropped handler committed nothing; its guard releases the key from a spawned task.
    for _ in 0..50 {
        let key = sqlx::query("SELECT 1 FROM idempotency_keys").fetch_optional(&pool).await.unwrap();
        if key.is_none() {
            break;
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    let retried = send(&app, publish()).await;
    assert_eq!((retried.status.as_u16(), retried.header("etag")), (200, "\"2\""));
}

#[sqlx::test]
async fn openapi_document_matches_the_committed_snapshot(pool: PgPool) {
    let generated = app(&pool).openapi.to_pretty_json().unwrap();
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/openapi.json");
    if std::env::var_os("UPDATE_OPENAPI").is_some() {
        std::fs::write(path, &generated).unwrap();
    }
    let committed = std::fs::read_to_string(path).unwrap_or_default();
    assert!(
        committed == generated,
        "openapi.json is stale: run `UPDATE_OPENAPI=1 cargo test openapi` and review the diff"
    );
    let doc: Value = serde_json::from_str(&generated).unwrap();
    let client_error = &doc["paths"]["/v1/articles"]["post"]["responses"]["4XX"]["content"]["application/problem+json"];
    assert_eq!(client_error["schema"]["$ref"], "#/components/schemas/Problem");
    assert!(doc["components"]["schemas"]["Problem"].is_object(), "the $ref must resolve");
    assert!(doc["paths"].get("/internal/webhooks/moderation").is_none());
}
```

## Adapter tests

Real PostgreSQL: the keyset walk, races, stale writes, outbox atomicity, tenant isolation, relay ordering and dead-lettering, and the idempotency store's one winner and purge rule.

```rust file=tests/api/postgres.rs
use std::sync::{Arc, Mutex};
use std::time::Duration;

use articles::outbound::SystemClock;
use articles::outbound::postgres::{Relay, RelayConfig};
use articles::outbound::publisher::{EventPublisher, OutboxEvent};
use domain::{
    Acquire, Article, ArticleError, ArticleId, ArticlePatch, ArticleRepository, Articles, Clock, IdempotencyStore,
    PageRequest, PageSize, Status, UnitOfWork,
};
use sqlx::PgPool;
use tokio::task::JoinSet;
use uuid::Uuid;

use crate::support::*;

#[sqlx::test]
async fn keyset_walk_has_no_gaps_or_duplicates(pool: PgPool) {
    let store = store(&pool);
    let ann = actor(TENANT_A, "ann", &[]);
    let now = SystemClock.now(); // one instant for every row, as in one transaction
    let mut tx = store.begin().await.unwrap();
    let mut newest_first = Vec::new();
    for n in 0..7 {
        let article = Article::create(ArticleId(Uuid::now_v7()), &ann, &input(&format!("a-{n}")), now).unwrap();
        store.insert(&mut tx, &article).await.unwrap();
        newest_first.insert(0, article.id());
    }
    store.commit(tx).await.unwrap();
    for size in [1, 2] {
        let (mut seen, mut after) = (Vec::new(), None);
        loop {
            let page =
                store.list(ann.tenant_id, PageRequest { after, size: PageSize::new(size).unwrap() }).await.unwrap();
            seen.extend(page.items.iter().map(Article::id));
            if !page.has_more {
                break;
            }
            after = page.items.last().map(Article::id);
        }
        assert_eq!(seen, newest_first, "page size {size}");
    }
}

#[sqlx::test]
async fn concurrent_duplicate_creates_have_exactly_one_winner(pool: PgPool) {
    let app = Arc::new(publishing(&pool));
    let mut tasks = JoinSet::new();
    for n in 0..8 {
        let app = app.clone();
        tasks.spawn(async move { app.create(&actor(TENANT_A, &format!("u{n}"), &[]), input("same"), None).await });
    }
    let results = tasks.join_all().await;
    assert_eq!(results.iter().filter(|r| r.is_ok()).count(), 1);
    assert!(results.iter().filter_map(|r| r.as_ref().err()).all(|e| matches!(e, ArticleError::SlugTaken)));
}

#[sqlx::test]
async fn a_write_against_a_stale_version_is_rejected(pool: PgPool) {
    let (store, app) = (store(&pool), publishing(&pool));
    let ann = actor(TENANT_A, "ann", &[]);
    let mut article = app.create(&ann, input("hello"), None).await.unwrap();
    article.edit(ArticlePatch { title: Some("Edited".into()), body: None }, SystemClock.now()).unwrap();
    let mut tx = store.begin().await.unwrap();
    store.save(&mut tx, &article, 1, Status::Draft).await.unwrap();
    store.commit(tx).await.unwrap();
    let mut tx = store.begin().await.unwrap();
    let stale = store.save(&mut tx, &article, 1, Status::Draft).await;
    assert!(matches!(stale, Err(ArticleError::VersionConflict)));
}

#[sqlx::test]
async fn publish_appends_one_outbox_row_or_rolls_back(pool: PgPool) {
    let app = publishing(&pool);
    let ann = actor(TENANT_A, "ann", &[]);
    let first = app.create(&ann, input("one"), None).await.unwrap();
    app.publish(&ann, first.id(), None).await.unwrap();
    let rows: Vec<(Uuid, i32, String)> =
        sqlx::query_as("SELECT aggregate_id, aggregate_seq, event_type FROM outbox").fetch_all(&pool).await.unwrap();
    assert_eq!(rows, [(first.id().0, 2, "article.published".to_owned())]);

    // Saboteur: a row already holding (aggregate_id, 2) makes the outbox insert fail.
    let second = app.create(&ann, input("two"), None).await.unwrap();
    sqlx::query("INSERT INTO outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload)
                 VALUES ($1, 'article', $2, 2, 'blocker', 1, '{}')")
        .bind(TENANT_A)
        .bind(second.id().0)
        .execute(&pool)
        .await
        .unwrap();
    assert!(app.publish(&ann, second.id(), None).await.is_err());
    assert_eq!(
        app.get(&ann, second.id()).await.unwrap().status(),
        Status::Draft,
        "the article rolled back with the outbox write"
    );
}

#[sqlx::test]
async fn other_tenants_can_neither_see_nor_change_an_article(pool: PgPool) {
    let app = publishing(&pool);
    let article = app.create(&actor(TENANT_A, "ann", &[]), input("mine"), None).await.unwrap();
    let outsider = actor(TENANT_B, "ann", &["editor"]); // same subject and an editor, other tenant
    assert!(matches!(app.get(&outsider, article.id()).await, Err(ArticleError::NotFound)));
    assert!(matches!(app.publish(&outsider, article.id(), None).await, Err(ArticleError::NotFound)));
    let page = app.list(&outsider, PageRequest { after: None, size: PageSize::new(100).unwrap() }).await.unwrap();
    assert!(page.items.is_empty());
}

#[derive(Clone, Default)]
struct Recorder {
    published: Arc<Mutex<Vec<(Uuid, i32)>>>,
    broker_down: bool,
}

impl EventPublisher for Recorder {
    async fn publish(&self, event: &OutboxEvent) -> anyhow::Result<()> {
        anyhow::ensure!(!self.broker_down, "broker unavailable");
        self.published.lock().unwrap().push((event.aggregate_id, event.aggregate_seq));
        Ok(())
    }
}

async fn enqueue(pool: &PgPool, aggregate: Uuid, seq: i32) {
    sqlx::query("INSERT INTO outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload)
                 VALUES ($1, 'article', $2, $3, 'article.published', 1, '{}')")
        .bind(TENANT_A)
        .bind(aggregate)
        .bind(seq)
        .execute(pool)
        .await
        .unwrap();
}

#[sqlx::test]
async fn relay_publishes_each_aggregate_in_order_and_dead_letters(pool: PgPool) {
    let (a, b, c) = (Uuid::now_v7(), Uuid::now_v7(), Uuid::now_v7());
    for (aggregate, seq) in [(a, 1), (a, 2), (a, 3), (b, 1)] {
        enqueue(&pool, aggregate, seq).await;
    }
    let recorder = Recorder::default();
    let relay = Relay::new(store(&pool), recorder.clone(), RelayConfig::default());
    let claimed: Vec<usize> =
        [relay.run_once().await.unwrap(), relay.run_once().await.unwrap(), relay.run_once().await.unwrap()].into();
    assert_eq!(claimed, [2, 1, 1], "only each aggregate's head is claimable");
    let published = recorder.published.lock().unwrap().clone();
    let sequence =
        |aggregate| published.iter().filter(|(id, _)| *id == aggregate).map(|(_, seq)| *seq).collect::<Vec<_>>();
    assert_eq!((sequence(a), sequence(b)), (vec![1, 2, 3], vec![1])); // across aggregates: any order

    for seq in [1, 2] {
        enqueue(&pool, c, seq).await;
    }
    let config = RelayConfig { max_attempts: 2, backoff_base: Duration::ZERO, ..RelayConfig::default() };
    let failing = Relay::new(store(&pool), Recorder { broker_down: true, ..Recorder::default() }, config);
    failing.run_once().await.unwrap();
    failing.run_once().await.unwrap();
    let (attempts, dead): (i32, bool) = sqlx::query_as(
        "SELECT attempts, dead_lettered_at IS NOT NULL FROM outbox WHERE aggregate_id = $1 AND aggregate_seq = 1",
    )
    .bind(c)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!((attempts, dead), (2, true));
    relay.run_once().await.unwrap(); // the dead letter no longer blocks its aggregate
    assert_eq!(recorder.published.lock().unwrap().last(), Some(&(c, 2)));
}

#[sqlx::test]
async fn an_idempotency_key_has_one_winner_and_a_live_lease_survives_the_purge(pool: PgPool) {
    let store = store(&pool);
    let mut tasks = JoinSet::new();
    for _ in 0..10 {
        let store = store.clone();
        tasks.spawn(async move { store.acquire("tenant:ann", "k", "hash").await.unwrap() });
    }
    let outcomes = tasks.join_all().await;
    assert_eq!(outcomes.iter().filter(|o| matches!(o, Acquire::Execute(_))).count(), 1);
    assert!(outcomes.iter().all(|o| matches!(o, Acquire::Execute(_) | Acquire::InFlight)));

    // Lease and TTL both expired: a retry takes the key over, and the purge must spare it.
    sqlx::query("UPDATE idempotency_keys SET locked_until = now() - interval '1 second', expires_at = now() - interval '1 second'")
        .execute(&pool)
        .await
        .unwrap();
    assert!(matches!(store.acquire("tenant:ann", "k", "hash").await.unwrap(), Acquire::Execute(_)));
    assert_eq!(store.purge_expired().await.unwrap(), 0);
}
```

## CI gates

Each step is a gate; `prepare --check` and the tests need the PostgreSQL service.

```sh file=scripts/check-boundary.sh
#!/bin/sh
# Boundary fitness function. The compiler already rejects a `use` of any crate missing from
# domain/Cargo.toml; this gate rejects adding one there (allow-list, so new crates need review)
# and adapters importing each other inside the service crate.
set -eu
allowed="anyhow chrono thiserror tracing uuid"
deps=$(cargo tree -p domain --edges normal --depth 1 --prefix none --format '{p}' | tail -n +2 | cut -d' ' -f1 | sort -u)
[ -n "$deps" ] || { echo "boundary: cargo tree listed nothing"; exit 1; }
for dep in $deps; do
  case " $allowed " in *" $dep "*) ;; *) echo "boundary: domain must not depend on $dep"; exit 1 ;; esac
done
if grep -rnE 'outbound::|crate::outbound' src/inbound; then echo "boundary: inbound imports outbound"; exit 1; fi
echo "boundary ok: domain -> $(echo $deps)"
```

```yaml file=.github/workflows/ci.yml
name: ci
on: [push, pull_request]
jobs:
  verify:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:18
        env: { POSTGRES_PASSWORD: postgres }
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 2s --health-retries 30
    env:
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/articles # superuser: #[sqlx::test] creates databases
    steps:
      - uses: actions/checkout@v5
        with: { fetch-depth: 0 }
      - uses: dtolnay/rust-toolchain@master
        with: { toolchain: "1.99.0", components: "clippy, rustfmt" }
      - run: cargo install sqlx-cli --version 0.9.0 --no-default-features --features postgres,rustls
      - run: cargo fmt --all --check
      - run: sh scripts/check-boundary.sh
      - run: sqlx database create && sqlx migrate run # migrations apply forward from empty
      - run: cargo sqlx prepare --workspace --check -- --all-targets # committed .sqlx matches the queries
      - run: SQLX_OFFLINE=true cargo clippy --workspace --all-targets -- -D warnings
      - run: cargo test --workspace # includes the openapi.json snapshot test
      - name: OpenAPI breaking-change check
        if: github.event_name == 'pull_request'
        run: |
          git show "origin/${{ github.base_ref }}:openapi.json" > /tmp/base.json
          docker run --rm -v /tmp:/base -v "$PWD:/head" tufin/oasdiff breaking /base/base.json /head/openapi.json --fail-on ERR
```
