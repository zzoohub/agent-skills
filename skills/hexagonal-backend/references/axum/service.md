# Axum examples: the service

What a new service needs: the app factory with its layer order, authentication, probes, configuration, logging and telemetry, the entrypoints, the manifest and the boundary check. Every `file=` block is a complete file of the project in `slice.md`.

## Contents

1. [App factory and layer order](#app-factory-and-layer-order)
2. [Authentication](#authentication)
3. [Probes](#probes)
4. [Configuration](#configuration)
5. [Logging and telemetry](#logging-and-telemetry)
6. [Entrypoints](#entrypoints)
7. [Manifest](#manifest)
8. [Boundary check](#boundary-check)

## App factory and layer order

In a `ServiceBuilder` the first layer is the outermost (`guide.md` § 3). Tests build the same router and drive it with `oneshot`, without binding a port.

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
use domain::{IdempotencyStore, Publishing, UnitOfWork};
use opentelemetry::trace::{TraceContextExt, TraceId};
use secrecy::SecretSlice;
use tower::ServiceBuilder;
use tower_http::{
    catch_panic::CatchPanicLayer, cors::CorsLayer, request_id::*, sensitive_headers::SetSensitiveRequestHeadersLayer,
    set_header::response::SetMultipleResponseHeadersLayer, timeout::TimeoutLayer, trace::DefaultOnResponse,
    trace::TraceLayer,
};
use tracing_opentelemetry::OpenTelemetrySpanExt;
use utoipa::openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme};
use utoipa::{Modify, OpenApi};
use utoipa_axum::{router::OpenApiRouter, router::UtoipaMethodRouterExt, routes};

use self::problem::{ApiError, ProblemType};
use crate::inbound::webhooks;

/// Every JSON body, the idempotency buffer and the webhook included.
pub const MAX_BODY: usize = 64 * 1024;

/// Generic over the unit of work, so this adapter never names a concrete store.
pub struct AppState<U> {
    pub publishing: Arc<Publishing<U>>,
}

// derive(Clone) would demand `U: Clone`; the use cases are shared through the Arc.
impl<U> Clone for AppState<U> {
    fn clone(&self) -> Self {
        Self { publishing: self.publishing.clone() }
    }
}

pub struct Deps<U, I> {
    pub publishing: Arc<Publishing<U>>,
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
pub fn app<U: UnitOfWork, I: IdempotencyStore>(deps: Deps<U, I>) -> (Router, utoipa::openapi::OpenApi) {
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
        .with_state(AppState { publishing: deps.publishing.clone() })
        .split_for_parts();

    let router = Router::new()
        .merge(v1)
        .merge(webhooks::router(deps.publishing, deps.webhook_secrets)) // internal: own auth, not in OpenAPI
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

## Authentication

A `route_layer` on the `/v1` router, so it runs on matched routes only. It puts the `Actor` in the request extensions, and the `Caller` extractor in `slice.md` takes it out.

```rust file=src/inbound/http/auth.rs
use std::{sync::Arc, time::Duration, time::Instant};

use axum::{extract::Request, extract::State, http::header, middleware::Next, response::Response};
use domain::{Actor, TenantId};
use jsonwebtoken::{Algorithm, AlgorithmFamily, DecodingKey, Validation, decode, decode_header, jwk::JwkSet};
use secrecy::ExposeSecret;
use serde::Deserialize;
use tokio::sync::RwLock;
use uuid::Uuid;

use super::problem::{ApiError, ProblemType};
use crate::config::{Jwt, JwtKeys};

/// Authenticates every `/v1` route and puts the `Actor` in the request extensions.
pub async fn authenticate(
    State(auth): State<Arc<Authenticator>>,
    mut req: Request,
    next: Next,
) -> Result<Response, ApiError> {
    let header = req.headers().get(header::AUTHORIZATION).and_then(|v| v.to_str().ok());
    let token = header.and_then(|v| v.split_once(' ')).filter(|(scheme, _)| scheme.eq_ignore_ascii_case("bearer"));
    let (_, token) = token.ok_or_else(|| ApiError::unauthenticated("A bearer token is required", "Bearer"))?;
    let actor = auth.verify(token.trim()).await?;
    req.extensions_mut().insert(actor);
    Ok(next.run(req).await)
}

#[derive(Deserialize)]
struct Claims {
    sub: String,
    tid: Uuid,
    #[serde(default)]
    roles: Vec<String>,
}

/// JWT verification: one pinned algorithm per key; `exp`, `iss`, `aud` and `sub` required.
pub struct Authenticator {
    validation: Validation,
    keys: Keys,
}

enum Keys {
    Hs256(DecodingKey),
    Jwks(Jwks),
}

impl Authenticator {
    pub fn new(cfg: &Jwt) -> anyhow::Result<Self> {
        let keys = match &cfg.keys {
            JwtKeys::Hs256 { secret } => Keys::Hs256(DecodingKey::from_secret(secret.expose_secret().as_bytes())?),
            JwtKeys::Jwks { url } => {
                let http =
                    reqwest::Client::builder().connect_timeout(Duration::from_secs(1)).timeout(Duration::from_secs(2));
                Keys::Jwks(Jwks { url: url.clone(), http: http.build()?, cache: RwLock::default() })
            }
        };
        let mut validation = Validation::new(Algorithm::HS256); // the algorithm is pinned per key in `verify`
        validation.set_issuer(&[&cfg.issuer]);
        validation.set_audience(&[&cfg.audience]);
        validation.set_required_spec_claims(&["exp", "iss", "aud", "sub"]);
        validation.leeway = 30;
        Ok(Self { validation, keys })
    }

    pub async fn verify(&self, token: &str) -> Result<Actor, ApiError> {
        let (key, algorithm) = match &self.keys {
            Keys::Hs256(key) => (key.clone(), Algorithm::HS256),
            Keys::Jwks(jwks) => {
                let key = jwks.key(&decode_header(token).ok().and_then(|h| h.kid).ok_or_else(invalid_token)?).await?;
                // One algorithm per key: jsonwebtoken rejects a Validation whose algorithms span families.
                match key.family() {
                    AlgorithmFamily::Ec => (key, Algorithm::ES256),
                    AlgorithmFamily::Ed => (key, Algorithm::EdDSA),
                    _ => return Err(invalid_token()),
                }
            }
        };
        let mut validation = self.validation.clone();
        validation.algorithms = vec![algorithm];
        let claims = decode::<Claims>(token, &key, &validation).map_err(|_| invalid_token())?.claims;
        // The subject is stored and is part of the idempotency scope: bounded, and no U+0000.
        if !(1..=255).contains(&claims.sub.chars().count()) || claims.sub.contains('\0') {
            return Err(invalid_token());
        }
        Ok(Actor { tenant_id: TenantId(claims.tid), subject: claims.sub, roles: claims.roles })
    }
}

fn invalid_token() -> ApiError {
    ApiError::unauthenticated("The access token is invalid or expired", r#"Bearer error="invalid_token""#)
}

/// Refetched when a token names an unknown `kid` or the set is 10 minutes old, at most once per
/// 30 seconds; a failed fetch keeps the cached keys rather than rejecting every token.
struct Jwks {
    url: String,
    http: reqwest::Client,
    cache: RwLock<Cache>,
}

#[derive(Default)]
struct Cache {
    set: Option<JwkSet>,
    fetched: Option<Instant>,
    attempted: Option<Instant>,
}

impl Jwks {
    async fn key(&self, kid: &str) -> Result<DecodingKey, ApiError> {
        let jwk = |c: &Cache| c.set.as_ref().and_then(|set| set.find(kid)).map(DecodingKey::from_jwk);
        {
            let cache = self.cache.read().await;
            if cache.fetched.is_some_and(|at| at.elapsed() < Duration::from_secs(600))
                && let Some(key) = jwk(&cache)
            {
                return key.map_err(|_| invalid_token());
            }
        }
        let mut cache = self.cache.write().await;
        if cache.attempted.is_none_or(|at| at.elapsed() > Duration::from_secs(30)) {
            cache.attempted = Some(Instant::now());
            match self.fetch().await {
                Ok(set) => (cache.set, cache.fetched) = (Some(set), Some(Instant::now())),
                Err(e) => tracing::warn!(error = format!("{e:#}"), "JWKS fetch failed; keeping cached keys"),
            }
        }
        match jwk(&cache) {
            Some(key) => key.map_err(|_| invalid_token()),
            None if cache.set.is_none() => Err(ApiError::new(ProblemType::Unavailable, "Signing keys are unavailable")),
            None => Err(invalid_token()),
        }
    }

    async fn fetch(&self) -> anyhow::Result<JwkSet> {
        Ok(self.http.get(&self.url).send().await?.error_for_status()?.json().await?)
    }
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

## Configuration

Validated once at startup. Secrets are `secrecy` types, so `Debug` never prints them. The budget check keeps the shutdown delay and the drain inside the platform's grace period.

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

/// Standard Webhooks format: `whsec_` + base64 of at least 24 bytes. Several during a rotation.
/// An empty key decodes without error, and anyone could sign with it.
fn webhook_secret(raw: &str) -> anyhow::Result<SecretSlice<u8>> {
    let encoded = raw.trim().strip_prefix("whsec_").context("WEBHOOK_SECRETS entries start with whsec_")?;
    let key = STANDARD.decode(encoded).context("WEBHOOK_SECRETS entry is not base64")?;
    ensure!(key.len() >= 24, "WEBHOOK_SECRETS entries must decode to at least 24 bytes");
    Ok(key.into())
}

#[test]
fn refuses_unsafe_configuration() {
    let env = "DATABASE_URL=postgres://db/a JWT_MODE=hs256 JWT_HS256_SECRET=dev-secret JWT_ISSUER=i JWT_AUDIENCE=a \
        PROBLEM_BASE_URI=https://api.example.com/problems/ WEBHOOK_SECRETS=whsec_MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=";
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
    assert!(load("WEBHOOK_SECRETS=whsec_").is_err(), "an empty webhook key");
    assert!(load("SHUTDOWN_DELAY_MS=5000").is_err(), "5 s + 9 s drain > Cloud Run's 10 s");
    assert!(load("SHUTDOWN_DELAY_MS=5000 SHUTDOWN_GRACE_MS=30000").is_ok());
}
```

## Logging and telemetry

JSON logs always. Traces and metrics only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set, so tests and local runs export nothing.

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

## Entrypoints

One binary with three commands: `serve`, `worker` (the outbox relay and the key purge) and `migrate` (the release step, which connects through its own URL as the owning role).

```rust file=src/main.rs
use std::{sync::Arc, time::Duration};

use anyhow::Context as _;
use articles::inbound::http::{self, Deps, auth::Authenticator, probes::Readiness};
use articles::outbound::postgres::{self, PgStore, Relay, RelayConfig};
use articles::outbound::{SystemClock, UuidV7, publisher::LogPublisher};
use articles::{config::Config, telemetry};
use domain::{IdempotencyStore, Publishing};
use tokio::signal::unix::{SignalKind, signal};
use tokio_util::{sync::CancellationToken, task::TaskTracker};

/// One image, three processes: `serve` (HTTP), `worker` (outbox relay and key purge) and
/// `migrate` (the release step, run once before a new version starts).
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let telemetry = telemetry::init("articles")?;
    let result = match std::env::args().nth(1).as_deref() {
        None | Some("serve") => serve().await,
        Some("worker") => worker().await,
        Some("migrate") => migrate().await,
        Some(other) => Err(anyhow::anyhow!("unknown command {other:?}: use serve, worker or migrate")),
    };
    if let Err(e) = &result {
        tracing::error!(error = format!("{e:#}"), "exiting");
    }
    telemetry.shutdown(); // last: flush spans and metrics
    result
}

async fn serve() -> anyhow::Result<()> {
    let mut config = Config::from_env()?;
    let store = PgStore::connect(&config.database, config.idempotency_lease()).await?;
    let readiness = Readiness::default();
    let (app, _) = http::app(Deps {
        publishing: Arc::new(Publishing::new(store.clone(), SystemClock, UuidV7)),
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

async fn worker() -> anyhow::Result<()> {
    let config = Config::from_env()?;
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

/// Its own URL and role: the owner of the schema, never the application's role.
async fn migrate() -> anyhow::Result<()> {
    let url = std::env::var("MIGRATION_DATABASE_URL").context("MIGRATION_DATABASE_URL must be set")?;
    postgres::migrate(&url).await
}
```

```rust file=src/lib.rs
//! The articles service: adapters and bootstrap around the `domain` crate.
pub mod config;
pub mod inbound;
pub mod outbound;
pub mod telemetry;
```

```rust file=src/inbound/mod.rs
pub mod http;
pub mod webhooks;
```

## Manifest

A workspace of two crates: the service and the domain. Shared versions and lints live in the workspace.

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
uuid = { version = "1.29", features = ["v7"] }

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
jsonwebtoken = { version = "12.0.0", default-features = false, features = ["aws_lc_rs"] }
opentelemetry = "0.33.1"
opentelemetry-http = "0.33.1"
opentelemetry-otlp = { version = "0.33.1", default-features = false, features = ["http-proto", "metrics", "reqwest-blocking-client", "trace"] }
opentelemetry_sdk = "0.33.1"
reqwest = { version = "0.13.5", default-features = false, features = ["json", "rustls"] }
secrecy = "0.10.3"
serde = { version = "1.0.229", features = ["derive"] }
serde_json = "1.0.154"
serde_path_to_error = "0.1.20"
sha2 = "0.11.1"
sqlx = { version = "0.9.0", default-features = false, features = ["chrono", "json", "macros", "migrate", "postgres", "runtime-tokio", "tls-rustls-aws-lc-rs", "uuid"] }
thiserror.workspace = true
tokio.workspace = true
tokio-util = { version = "0.7.20", features = ["rt"] }
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

## Boundary check

Run as `sh scripts/check-boundary.sh` from the workspace root. It says what to do about each violation, and it fails when it examined nothing.

```sh file=scripts/check-boundary.sh
#!/bin/sh
# The boundary check. The compiler already rejects a `use` of any crate that domain/Cargo.toml
# does not list. This rejects listing one (an allow-list, so a new dependency of the rules is a
# reviewed decision) and adapters that import each other inside the service crate.
set -eu
allowed="anyhow chrono thiserror tracing uuid"

deps=$(cargo tree -p domain --edges normal --depth 1 --prefix none --format '{p}' | tail -n +2 | cut -d' ' -f1 | sort -u)
files=$(find src/inbound src/outbound -name '*.rs' 2>/dev/null | wc -l | tr -d ' ')
if [ -z "$deps" ] || [ "$files" -eq 0 ]; then
  echo "boundary: nothing was examined (domain dependencies: $(echo $deps | wc -w | tr -d ' '); adapter files: $files)."
  echo "  Run this from the workspace root. A check that looks at nothing must not pass."
  exit 1
fi

for dep in $deps; do
  case " $allowed " in *" $dep "*) continue ;; esac
  echo "boundary: domain/Cargo.toml depends on '$dep'. The domain may use only: $allowed."
  echo "  If '$dep' does I/O (a driver, an HTTP client, a framework, an SDK), remove it: declare a port in"
  echo "  domain/src/ports.rs for what the use case needs and implement it under src/outbound/."
  echo "  If the rules need it as a pure library, add it to 'allowed' in this script in the same change."
  exit 1
done

fail() {
  echo "$1"
  echo "boundary: $2 must not import $3. Both depend on the domain, and only src/main.rs names both."
  echo "  Move what they share into a port or a type in domain/, or pass it in from main.rs."
  exit 1
}
if found=$(grep -rnE '(crate::)?outbound::' src/inbound); then fail "$found" src/inbound src/outbound; fi
if found=$(grep -rnE '(crate::)?inbound::' src/outbound); then fail "$found" src/outbound src/inbound; fi
echo "boundary ok: domain -> $(echo $deps); $files adapter files examined"
```
