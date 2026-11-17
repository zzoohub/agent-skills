# Axum examples: reliability

What a trigger calls for (`SKILL.md` § Size the change): the idempotency wrapper and its store, the outbox with its relay and publisher, and the inbox behind the webhook receiver. Every `file=` block is a complete file of the project in `slice.md`. The ports these adapters implement are in `domain/src/ports.rs`, and `PgInbox` is in `src/outbound/postgres/mod.rs`, both in `slice.md`.

## Contents

1. [Tables](#tables)
2. [Idempotency](#idempotency)
3. [Outbox and relay](#outbox-and-relay)
4. [Webhook receiver](#webhook-receiver)

## Tables

Infrastructure tables carry no row-level security. The relay and the purge work across tenants, and no request queries them by anything a caller supplies.

```sql file=migrations/0002_outbox.sql
-- Infrastructure tables carry no row-level security: the relay reads across tenants, and no
-- request path queries them by anything a caller supplies.
CREATE TABLE app.outbox (
    id               uuid        CONSTRAINT pk_outbox PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        uuid        NOT NULL,
    aggregate_type   text        NOT NULL,
    aggregate_id     uuid        NOT NULL,
    aggregate_seq    integer     NOT NULL,
    event_type       text        NOT NULL,
    event_version    smallint    NOT NULL,
    payload          jsonb       NOT NULL,
    headers          jsonb       NOT NULL DEFAULT '{}',
    created_at       timestamptz NOT NULL DEFAULT now(),
    published_at     timestamptz,
    attempts         integer     NOT NULL DEFAULT 0,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    last_error       text,
    dead_lettered_at timestamptz,
    CONSTRAINT uq_outbox_aggregate_seq UNIQUE (aggregate_id, aggregate_seq)
);

-- The relay's claim scan and the oldest-pending-age metric read only pending rows.
CREATE INDEX idx_outbox_pending ON app.outbox (created_at) WHERE published_at IS NULL AND dead_lettered_at IS NULL;
CREATE INDEX idx_outbox_dead_letter ON app.outbox (dead_lettered_at) WHERE dead_lettered_at IS NOT NULL;
GRANT SELECT, INSERT, UPDATE ON app.outbox TO app_rw;
```

```sql file=migrations/0003_idempotency_keys.sql
-- scope = tenant + principal; the response columns fill when the leased command commits.
CREATE TABLE app.idempotency_keys (
    scope            text        NOT NULL,
    key              text        NOT NULL,
    request_hash     text        NOT NULL,
    lease_token      uuid        NOT NULL,
    locked_until     timestamptz NOT NULL,
    response_status  integer,
    response_headers jsonb,
    response_body    bytea,
    completed_at     timestamptz,
    expires_at       timestamptz NOT NULL,
    CONSTRAINT pk_idempotency_keys PRIMARY KEY (scope, key)
);

CREATE INDEX idx_idempotency_keys_expires_at ON app.idempotency_keys (expires_at);
GRANT SELECT, INSERT, UPDATE, DELETE ON app.idempotency_keys TO app_rw;
```

```sql file=migrations/0004_inbox.sql
-- Delivered messages, recorded in the same transaction as their effect.
CREATE TABLE app.inbox (
    consumer    text        NOT NULL,
    message_id  text        NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_inbox PRIMARY KEY (consumer, message_id)
);
GRANT SELECT, INSERT ON app.inbox TO app_rw;
```

## Idempotency

A middleware layered onto each idempotent route acquires the key on the pool, before any transaction opens. The handler passes `Idempotency { lease, render }` to the use case as an argument, because Rust has no ambient transaction, and the use case stores the rendered response in its own transaction.

```rust file=src/inbound/http/idempotency.rs
use std::sync::Arc;

use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::{HeaderMap, HeaderName, HeaderValue, Method, StatusCode, header};
use axum::middleware::Next;
use axum::response::Response;
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use domain::{Acquire, ArticleError, IdempotencyStore, StoredResponse};
use sha2::{Digest, Sha256};

use super::MAX_BODY;
use super::extract::Caller;
use super::problem::{self, ApiError, ProblemType};

pub struct IdempotencyState<I> {
    pub store: Arc<I>,
    pub problem_base: Arc<str>,
}

impl<I> Clone for IdempotencyState<I> {
    fn clone(&self) -> Self {
        Self { store: self.store.clone(), problem_base: self.problem_base.clone() }
    }
}

/// Layered onto each idempotent route, inside `authenticate` (scope = tenant + principal).
pub async fn idempotent<I: IdempotencyStore>(
    State(state): State<IdempotencyState<I>>,
    Caller(actor): Caller,
    req: Request,
    next: Next,
) -> Result<Response, ApiError> {
    let Some(key) = req.headers().get("idempotency-key") else { return Ok(next.run(req).await) };
    let valid = |k: &&str| (1..=255).contains(&k.len()) && k.bytes().all(|b| b.is_ascii_graphic());
    let key = key
        .to_str()
        .ok()
        .filter(valid)
        .ok_or_else(|| ApiError::malformed("Idempotency-Key must be 1-255 visible ASCII"))?;
    let key = key.to_owned();
    // The body can be read once: buffer it, hash it, rebuild the request.
    let (parts, body) = req.into_parts();
    let too_large = |_| ApiError::new(ProblemType::PayloadTooLarge, "The request body is too large");
    let bytes = to_bytes(body, MAX_BODY).await.map_err(too_large)?;
    let target = parts.uri.path_and_query().map_or(parts.uri.path(), |target| target.as_str());
    let hash = request_hash(&parts.method, target, &bytes);
    let scope = format!("{}:{}", actor.tenant_id.0, actor.subject);
    let lease = match state.store.acquire(&scope, &key, &hash).await.map_err(ArticleError::from)? {
        Acquire::Execute(lease) => lease,
        Acquire::Replay(stored) => {
            let mut res = respond(stored);
            res.headers_mut().insert("idempotent-replayed", HeaderValue::from_static("true"));
            return Ok(res);
        }
        Acquire::Mismatch => {
            return Err(ApiError::new(ProblemType::IdempotencyKeyMismatch, "The key was used for a different request"));
        }
        Acquire::InFlight => {
            let running = ApiError::new(ProblemType::IdempotencyInFlight, "A request with this key is running");
            return Err(running.with_header(header::RETRY_AFTER, "1"));
        }
    };
    let instance = parts.uri.path().to_owned();
    let mut req = Request::from_parts(parts, Body::from(bytes));
    req.extensions_mut().insert(lease.clone());
    // Dropped (client gone, deadline) or failed: the guard frees the key.
    let mut guard = ReleaseOnDrop(Some((state.store.clone(), lease.clone())));
    let res = next.run(req).await;
    let status = res.status();
    if status.is_success() {
        guard.0 = None; // completed inside the use case's transaction
        return Ok(res);
    }
    // Not replayable: a 5xx, a transient 4xx, and an outcome decided by a header outside the hash
    // (a stored 415 would answer the corrected retry). The guard frees the key.
    use StatusCode as S;
    let header_decided =
        [S::NOT_ACCEPTABLE, S::PRECONDITION_FAILED, S::UNSUPPORTED_MEDIA_TYPE, S::PRECONDITION_REQUIRED];
    let transient = [S::REQUEST_TIMEOUT, S::TOO_MANY_REQUESTS];
    if !status.is_client_error() || header_decided.contains(&status) || transient.contains(&status) {
        return Ok(res);
    }
    // A 4xx decided by the body or the state committed nothing: store it alone so a retry replays it.
    let (parts, body) = problem::finalize(res, &state.problem_base, &instance).into_parts();
    let body = to_bytes(body, MAX_BODY).await.unwrap_or_default();
    let stored =
        StoredResponse { status: status.as_u16(), headers: defining_headers(&parts.headers), body: body.to_vec() };
    match state.store.complete(&lease, &stored).await {
        Ok(()) => guard.0 = None,
        Err(e) => tracing::warn!(error = format!("{e:#}"), "could not store a 4xx outcome; key released"),
    }
    Ok(Response::from_parts(parts, Body::from(body)))
}

struct ReleaseOnDrop<I: IdempotencyStore>(Option<(Arc<I>, domain::Lease)>);

impl<I: IdempotencyStore> Drop for ReleaseOnDrop<I> {
    fn drop(&mut self) {
        if let Some((store, lease)) = self.0.take() {
            // Deletes only an uncompleted row under this lease.
            tokio::spawn(async move {
                if let Err(e) = store.release(&lease).await {
                    tracing::warn!(error = format!("{e:#}"), "idempotency release failed; the lease will lapse");
                }
            });
        }
    }
}

/// Method, path with query (not the route template: a key must not replay another resource) and
/// canonical JSON. A `Value` round trip sorts keys unless a dependency enables serde_json's
/// `preserve_order`; the test below catches that.
fn request_hash(method: &Method, target: &str, body: &[u8]) -> String {
    let canonical = serde_json::from_slice::<serde_json::Value>(body).ok().and_then(|v| serde_json::to_vec(&v).ok());
    let mut hasher = Sha256::new();
    for part in [method.as_str().as_bytes(), b"\n", target.as_bytes(), b"\n", canonical.as_deref().unwrap_or(body)] {
        hasher.update(part);
    }
    URL_SAFE_NO_PAD.encode(hasher.finalize())
}

fn defining_headers(headers: &HeaderMap) -> Vec<(String, String)> {
    [header::CONTENT_TYPE, header::LOCATION, header::ETAG]
        .iter()
        .filter_map(|name| Some((name.to_string(), headers.get(name)?.to_str().ok()?.to_owned())))
        .collect()
}

/// Handlers answer with this too: a replay is byte-identical.
pub fn respond(stored: StoredResponse) -> Response {
    let mut res = Response::new(Body::from(stored.body));
    *res.status_mut() = StatusCode::from_u16(stored.status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
    for (name, value) in stored.headers {
        if let (Ok(name), Ok(value)) = (HeaderName::try_from(name), HeaderValue::try_from(value)) {
            res.headers_mut().append(name, value);
        }
    }
    res
}

#[test]
fn hash_ignores_key_order_but_not_the_target() {
    let hash = |target, body: &str| request_hash(&Method::POST, target, body.as_bytes());
    assert_eq!(
        hash("/v1/a", r#"{"x":1,"y":2}"#),
        hash("/v1/a", r#"{ "y": 2, "x": 1 }"#),
        "serde_json preserve_order is on"
    );
    assert_ne!(hash("/v1/a", "{}"), hash("/v1/b", "{}"));
    assert_ne!(hash("/v1/a", "{}"), hash("/v1/a?dry_run=true", "{}"));
}
```

Only the insert, or the takeover of an expired lease, grants execution. The completion runs inside the use case's transaction for a success, and on the pool for a stored 4xx.

```rust file=src/outbound/postgres/idempotency.rs
use std::time::Duration;

use anyhow::Context as _;
use domain::{Acquire, IdempotencyCompletion, IdempotencyStore, Lease, StoredResponse};
use sqlx::PgExecutor;
use uuid::Uuid;

use super::{PgStore, PgTx, db_error};

/// Longer than any client's retry horizon.
const TTL: Duration = Duration::from_secs(24 * 60 * 60);

impl IdempotencyStore for PgStore {
    async fn acquire(&self, scope: &str, key: &str, request_hash: &str) -> anyhow::Result<Acquire> {
        let (lease_secs, ttl_secs) = (self.lease.as_secs_f64(), TTL.as_secs_f64());
        // Bounded: the row can vanish (release, purge) between the INSERT and the SELECT.
        for _ in 0..3 {
            let token = Uuid::now_v7();
            let lease = || Lease { scope: scope.to_owned(), key: key.to_owned(), token };
            // 1. Execution is granted only by this INSERT's returned row (or the takeover below).
            let won = sqlx::query_scalar!(
                "INSERT INTO app.idempotency_keys (scope, key, request_hash, lease_token, locked_until, expires_at)
                 VALUES ($1, $2, $3, $4, now() + make_interval(secs => $5), now() + make_interval(secs => $6))
                 ON CONFLICT (scope, key) DO NOTHING RETURNING lease_token",
                scope,
                key,
                request_hash,
                token,
                lease_secs,
                ttl_secs,
            )
            .fetch_optional(self.pool())
            .await
            .map_err(db_error)?;
            if won.is_some() {
                return Ok(Acquire::Execute(lease()));
            }
            // 2. The key is held: this read decides mismatch, replay or in-flight, never execution.
            let held = sqlx::query!(
                r#"SELECT request_hash, completed_at IS NOT NULL AS "completed!", response_status, response_headers, response_body
                   FROM app.idempotency_keys WHERE scope = $1 AND key = $2"#,
                scope,
                key
            )
            .fetch_optional(self.pool())
            .await
            .map_err(db_error)?;
            let Some(held) = held else { continue };
            if held.request_hash != request_hash {
                return Ok(Acquire::Mismatch);
            }
            if held.completed {
                return Ok(Acquire::Replay(StoredResponse {
                    status: u16::try_from(held.response_status.context("completed key without a status")?)?,
                    headers: serde_json::from_value(held.response_headers.unwrap_or_default())?,
                    body: held.response_body.unwrap_or_default(),
                }));
            }
            // 3. Take over an expired, uncompleted lease: a conditional write. It also extends
            //    `expires_at`, so the purge job cannot delete a row whose lease is live.
            let taken = sqlx::query_scalar!(
                "UPDATE app.idempotency_keys SET lease_token = $4, locked_until = now() + make_interval(secs => $5),
                     expires_at = greatest(expires_at, now() + make_interval(secs => $6))
                 WHERE scope = $1 AND key = $2 AND request_hash = $3 AND completed_at IS NULL AND locked_until < now()
                 RETURNING lease_token",
                scope,
                key,
                request_hash,
                token,
                lease_secs,
                ttl_secs,
            )
            .fetch_optional(self.pool())
            .await
            .map_err(db_error)?;
            return Ok(if taken.is_some() { Acquire::Execute(lease()) } else { Acquire::InFlight });
        }
        Ok(Acquire::InFlight)
    }

    async fn complete(&self, lease: &Lease, response: &StoredResponse) -> anyhow::Result<()> {
        complete(self.pool(), lease, response).await
    }

    async fn release(&self, lease: &Lease) -> anyhow::Result<()> {
        sqlx::query!(
            "DELETE FROM app.idempotency_keys WHERE scope = $1 AND key = $2 AND lease_token = $3 AND completed_at IS NULL",
            lease.scope,
            lease.key,
            lease.token
        )
        .execute(self.pool())
        .await
        .map_err(db_error)?;
        Ok(())
    }

    async fn purge_expired(&self) -> anyhow::Result<u64> {
        let purged = sqlx::query!(
            "DELETE FROM app.idempotency_keys WHERE expires_at < now() AND (completed_at IS NOT NULL OR locked_until < now())"
        )
        .execute(self.pool())
        .await
        .map_err(db_error)?;
        Ok(purged.rows_affected())
    }
}

pub(super) struct PgCompletion<'t>(pub(super) &'t mut PgTx);

impl IdempotencyCompletion for PgCompletion<'_> {
    async fn complete(&mut self, lease: &Lease, response: &StoredResponse) -> anyhow::Result<()> {
        complete(self.0.connection(), lease, response).await
    }
}

/// Only under this request's live lease: zero rows means another request took it over.
async fn complete(db: impl PgExecutor<'_>, lease: &Lease, response: &StoredResponse) -> anyhow::Result<()> {
    let completed = sqlx::query!(
        "UPDATE app.idempotency_keys SET response_status = $4, response_headers = $5, response_body = $6, completed_at = now()
         WHERE scope = $1 AND key = $2 AND lease_token = $3 AND completed_at IS NULL",
        lease.scope,
        lease.key,
        lease.token,
        i32::from(response.status),
        serde_json::to_value(&response.headers)?,
        response.body,
    )
    .execute(db)
    .await
    .map_err(db_error)?;
    anyhow::ensure!(completed.rows_affected() == 1, "idempotency lease lost (taken over after expiry)");
    Ok(())
}
```

## Outbox and relay

`PgOutbox` runs inside the unit of work. The relay runs on the bare pool in the `worker` process (`src/main.rs` in `service.md`). It claims in a materialized CTE and fences every outcome on the claim's `attempts`.

```rust file=src/outbound/postgres/outbox.rs
use std::collections::HashMap;
use std::time::Duration;

use domain::{ArticleEvent, Outbox};
use opentelemetry::metrics::Gauge;
use serde_json::json;
use tokio_util::sync::CancellationToken;
use tracing_opentelemetry::OpenTelemetrySpanExt;

use super::{PgStore, PgTx, db_error};
use crate::outbound::publisher::{EventPublisher, OutboxEvent};

pub(super) struct PgOutbox<'t>(pub(super) &'t mut PgTx);

impl Outbox for PgOutbox<'_> {
    async fn append(&mut self, event: &ArticleEvent) -> anyhow::Result<()> {
        // A new variant makes this `let` refutable: the compiler sends you here.
        let ArticleEvent::Published { article_id, tenant_id, slug, version, published_at } = event;
        let payload = json!({ "article_id": article_id.0, "slug": slug, "published_at": published_at });
        // Captured at insert, so the consumer's span links back to this request.
        let mut headers = HashMap::from([("tenant_id".to_owned(), tenant_id.0.to_string())]);
        let context = tracing::Span::current().context();
        opentelemetry::global::get_text_map_propagator(|p| p.inject_context(&context, &mut headers));
        sqlx::query!(
            "INSERT INTO app.outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload, headers)
             VALUES ($1, 'article', $2, $3, 'article.published', 1, $4, $5)",
            tenant_id.0,
            article_id.0,
            version, // aggregate_seq = the aggregate's stored version
            payload,
            json!(headers),
        )
        .execute(self.0.connection())
        .await
        .map_err(db_error)?;
        Ok(())
    }
}

#[derive(Clone, Debug)]
pub struct RelayConfig {
    pub batch: i64,
    /// A claimed row stays hidden this long; a publish gets half of it.
    pub lease: Duration,
    pub max_attempts: i32,
    pub backoff_base: Duration,
    pub poll: Duration,
}

impl Default for RelayConfig {
    fn default() -> Self {
        let (lease, backoff_base, poll) = (Duration::from_secs(30), Duration::from_secs(1), Duration::from_secs(1));
        Self { batch: 50, lease, max_attempts: 10, backoff_base, poll }
    }
}

pub struct Relay<P> {
    store: PgStore,
    publisher: P,
    config: RelayConfig,
    oldest_pending: Gauge<f64>,
    dead_letters: Gauge<u64>,
}

impl<P: EventPublisher> Relay<P> {
    pub fn new(store: PgStore, publisher: P, config: RelayConfig) -> Self {
        let meter = opentelemetry::global::meter("articles");
        Self {
            store,
            publisher,
            config,
            oldest_pending: meter.f64_gauge("outbox.oldest_pending_age").with_unit("s").build(),
            dead_letters: meter.u64_gauge("outbox.dead_letters").build(),
        }
    }

    /// Stops claiming on shutdown; a pass in progress finishes, or its leases lapse.
    pub async fn run(self, shutdown: CancellationToken) {
        let mut tick = tokio::time::interval(self.config.poll);
        while shutdown.run_until_cancelled(tick.tick()).await.is_some() {
            while !shutdown.is_cancelled() {
                match self.run_once().await {
                    Ok(claimed) if i64::try_from(claimed) == Ok(self.config.batch) => {} // a full batch: more waiting
                    Ok(_) => break,
                    Err(e) => {
                        tracing::error!(error = format!("{e:#}"), "outbox relay pass failed");
                        break;
                    }
                }
            }
            if let Err(e) = self.record_lag().await {
                tracing::warn!(error = format!("{e:#}"), "outbox lag query failed");
            }
        }
    }

    /// One pass; returns the rows claimed.
    pub async fn run_once(&self) -> anyhow::Result<usize> {
        // One short statement. The CTE is MATERIALIZED so the claim runs exactly once: as an
        // `IN (subquery)` the planner may re-evaluate it and claim more than the limit.
        // SKIP LOCKED splits rows between relays, NOT EXISTS makes only an aggregate's oldest
        // pending row claimable, and the pushed next_attempt_at is the claim's lease.
        let claimed = sqlx::query_as!(
            OutboxEvent,
            "WITH claim AS MATERIALIZED (
                 SELECT o.id FROM app.outbox o
                 WHERE o.published_at IS NULL AND o.dead_lettered_at IS NULL AND o.next_attempt_at <= now()
                   AND NOT EXISTS (SELECT 1 FROM app.outbox e WHERE e.aggregate_id = o.aggregate_id
                       AND e.aggregate_seq < o.aggregate_seq AND e.published_at IS NULL AND e.dead_lettered_at IS NULL)
                 ORDER BY o.created_at LIMIT $1 FOR UPDATE SKIP LOCKED)
             UPDATE app.outbox o SET attempts = o.attempts + 1, next_attempt_at = now() + make_interval(secs => $2)
             FROM claim WHERE o.id = claim.id
             RETURNING o.id, o.tenant_id, o.aggregate_id, o.aggregate_seq, o.event_type, o.event_version, o.payload,
                 o.headers, o.attempts",
            self.config.batch,
            self.config.lease.as_secs_f64(),
        )
        .fetch_all(self.store.pool())
        .await
        .map_err(db_error)?;
        for event in &claimed {
            let published = tokio::time::timeout(self.config.lease / 2, self.publisher.publish(event)).await;
            match published.unwrap_or_else(|_| Err(anyhow::anyhow!("publish timed out"))) {
                // Fenced on the claim's `attempts`: a relay whose lease ran out cannot overwrite a newer claim.
                Ok(()) => {
                    sqlx::query!(
                        "UPDATE app.outbox SET published_at = now() WHERE id = $1 AND attempts = $2",
                        event.id,
                        event.attempts
                    )
                    .execute(self.store.pool())
                    .await
                    .map_err(db_error)?;
                }
                Err(e) => self.retry_later(event, &e).await?,
            }
        }
        Ok(claimed.len())
    }

    async fn retry_later(&self, event: &OutboxEvent, error: &anyhow::Error) -> anyhow::Result<()> {
        let dead = event.attempts >= self.config.max_attempts;
        // Exponential backoff with full jitter, computed where the clock is.
        sqlx::query!(
            "UPDATE app.outbox SET last_error = $3,
                 next_attempt_at = now() + make_interval(secs => random() * least(300, $4 * 2 ^ (attempts - 1))),
                 dead_lettered_at = CASE WHEN $5 THEN now() END
             WHERE id = $1 AND attempts = $2",
            event.id,
            event.attempts,
            format!("{error:#}"),
            self.config.backoff_base.as_secs_f64(),
            dead,
        )
        .execute(self.store.pool())
        .await
        .map_err(db_error)?;
        if dead {
            tracing::error!(event_id = %event.id, error = format!("{error:#}"), "outbox event dead-lettered");
        }
        Ok(())
    }

    async fn record_lag(&self) -> anyhow::Result<()> {
        let lag = sqlx::query!(
            r#"SELECT
                 (SELECT EXTRACT(EPOCH FROM now() - min(created_at))::float8 FROM app.outbox
                  WHERE published_at IS NULL AND dead_lettered_at IS NULL) AS "oldest_pending_secs",
                 (SELECT count(*) FROM app.outbox WHERE dead_lettered_at IS NOT NULL) AS "dead_letters!""#
        )
        .fetch_one(self.store.pool())
        .await
        .map_err(db_error)?;
        self.oldest_pending.record(lag.oldest_pending_secs.unwrap_or(0.0), &[]);
        self.dead_letters.record(u64::try_from(lag.dead_letters).unwrap_or(0), &[]);
        Ok(())
    }
}
```

```rust file=src/outbound/publisher.rs
use std::future::Future;

use uuid::Uuid;

/// A claimed outbox row, as the relay hands it to the broker.
#[derive(Clone, Debug)]
pub struct OutboxEvent {
    pub id: Uuid,
    pub tenant_id: Uuid,
    pub aggregate_id: Uuid,
    pub aggregate_seq: i32,
    pub event_type: String,
    pub event_version: i16,
    pub payload: serde_json::Value,
    pub headers: serde_json::Value,
    pub attempts: i32,
}

/// The broker port. `id` is the consumers' dedup key: delivery is at-least-once.
pub trait EventPublisher: Send + Sync + 'static {
    fn publish(&self, event: &OutboxEvent) -> impl Future<Output = anyhow::Result<()>> + Send;
}

/// Stand-in until a broker client (Pub/Sub, Kafka, NATS) implements `EventPublisher`.
pub struct LogPublisher;

impl EventPublisher for LogPublisher {
    async fn publish(&self, event: &OutboxEvent) -> anyhow::Result<()> {
        tracing::info!(event_id = %event.id, event_type = %event.event_type, seq = event.aggregate_seq, "event published");
        Ok(())
    }
}
```

## Webhook receiver

The signature is verified over the raw bytes before anything is parsed. The use case records the inbox row and applies the effect in one transaction, scoped to the tenant the signed payload names.

```rust file=src/inbound/webhooks.rs
//! Moderation webhook (Standard Webhooks): 2xx for every permanent outcome, 5xx only for transient ones.
use std::sync::Arc;

use axum::http::{HeaderMap, StatusCode, header};
use axum::{Router, extract::DefaultBodyLimit, extract::State, routing::post};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use domain::{Actor, ArticleId, Publishing, TenantId, UnitOfWork};
use hmac::{Hmac, KeyInit, Mac};
use secrecy::{ExposeSecret, SecretSlice};
use serde::Deserialize;
use uuid::Uuid;

use super::http::{MAX_BODY, extract::RawBody, problem::ApiError, problem::ProblemType};

struct WebhookState<U> {
    publishing: Arc<Publishing<U>>,
    secrets: Arc<[SecretSlice<u8>]>,
}

impl<U> Clone for WebhookState<U> {
    fn clone(&self) -> Self {
        Self { publishing: self.publishing.clone(), secrets: self.secrets.clone() }
    }
}

pub fn router<U: UnitOfWork>(publishing: Arc<Publishing<U>>, secrets: Vec<SecretSlice<u8>>) -> Router {
    Router::new()
        .route("/internal/webhooks/moderation", post(moderation::<U>))
        .layer(DefaultBodyLimit::max(MAX_BODY))
        .with_state(WebhookState { publishing, secrets: secrets.into() })
}

#[derive(Deserialize)]
struct Verdict {
    tenant_id: Uuid,
    article_id: Uuid,
    verdict: String,
}

async fn moderation<U: UnitOfWork>(
    State(state): State<WebhookState<U>>,
    headers: HeaderMap,
    RawBody(body): RawBody, // the raw bytes: the signature covers them exactly as sent
) -> Result<StatusCode, ApiError> {
    let message_id = verify(&state.secrets, &headers, &body, chrono::Utc::now().timestamp())?;
    let event = match serde_json::from_slice::<Verdict>(&body) {
        Ok(event) if event.verdict == "rejected" => event,
        Ok(_) => return Ok(StatusCode::NO_CONTENT), // approved: nothing to do
        Err(_) => {
            tracing::warn!(message_id, "unreadable moderation payload acknowledged: a retry cannot fix it");
            return Ok(StatusCode::NO_CONTENT);
        }
    };
    // The consumer acts as a system actor in the payload's tenant: the transaction is scoped to it.
    let system = Actor {
        tenant_id: TenantId(event.tenant_id),
        subject: "system:moderation".into(),
        roles: vec!["moderator".into()],
    };
    // Unavailable → 503 + Retry-After so the sender retries; every recorded outcome → 204.
    let outcome = state.publishing.archive(&system, ArticleId(event.article_id), message_id).await?;
    tracing::info!(message_id, ?outcome, "moderation verdict handled");
    Ok(StatusCode::NO_CONTENT)
}

/// Space-separated `v1,<base64 HMAC-SHA256(id.timestamp.body)>`; any secret may match (rotation).
fn verify<'h>(secrets: &[SecretSlice<u8>], headers: &'h HeaderMap, body: &[u8], now: i64) -> Result<&'h str, ApiError> {
    let reject = || {
        ApiError::new(ProblemType::Unauthenticated, "Invalid webhook signature")
            .with_header(header::WWW_AUTHENTICATE, "Signature")
    };
    let get = |name: &str| headers.get(name).and_then(|v| v.to_str().ok()).ok_or_else(reject);
    let (id, timestamp, signatures) = (get("webhook-id")?, get("webhook-timestamp")?, get("webhook-signature")?);
    if timestamp.parse::<i64>().map_or(true, |sent| now.abs_diff(sent) > 300) {
        return Err(reject());
    }
    let signed = [id.as_bytes(), b".", timestamp.as_bytes(), b".", body].concat();
    let matches = |signature: &[u8], secret: &SecretSlice<u8>| {
        Hmac::<sha2::Sha256>::new_from_slice(secret.expose_secret()).is_ok_and(|mut mac| {
            mac.update(&signed);
            mac.verify_slice(signature).is_ok() // constant-time
        })
    };
    let mut candidates = signatures.split(' ').filter_map(|s| STANDARD.decode(s.strip_prefix("v1,")?).ok());
    if candidates.any(|signature| secrets.iter().any(|secret| matches(&signature, secret))) {
        Ok(id)
    } else {
        Err(reject())
    }
}
```
