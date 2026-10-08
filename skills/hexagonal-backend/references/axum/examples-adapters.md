# Axum examples — adapters

Outbound: the schema, the PostgreSQL store behind every persistence port, the outbox relay and the idempotency store. Inbound: problem documents, extractors, authentication, the article routes, the idempotency wrapper and the moderation webhook. Judgment behind the code: `guide.md`.

## Contents

1. [Schema](#schema)
2. [PostgreSQL store](#postgresql-store)
3. [Article repository](#article-repository)
4. [Outbox and relay](#outbox-and-relay)
5. [Idempotency store](#idempotency-store)
6. [Problem documents](#problem-documents)
7. [Extractors](#extractors)
8. [Authentication](#authentication)
9. [Article routes](#article-routes)
10. [Idempotency wrapper](#idempotency-wrapper)
11. [Moderation webhook](#moderation-webhook)

## Schema

Plain SQL is the source of truth; `sqlx::migrate!` embeds these files and `articles migrate` applies them as the release step.

```sql file=migrations/0001_articles.sql
-- The adapter maps the named UNIQUE constraint to `SlugTaken`; CHECKs back the domain rules.
CREATE TABLE articles (
    id           uuid        PRIMARY KEY,
    tenant_id    uuid        NOT NULL,
    author_id    text        NOT NULL CHECK (char_length(author_id) BETWEEN 1 AND 255),
    slug         text        NOT NULL CHECK (char_length(slug) <= 100 AND slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    title        text        NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
    body         text        NOT NULL CHECK (char_length(body) <= 20000),
    status       text        NOT NULL CHECK (status IN ('draft', 'published', 'archived')),
    version      integer     NOT NULL CHECK (version >= 1),
    created_at   timestamptz NOT NULL,
    updated_at   timestamptz NOT NULL,
    published_at timestamptz,
    CONSTRAINT articles_tenant_slug_key UNIQUE (tenant_id, slug),
    CONSTRAINT articles_published_at_check CHECK ((status = 'draft') = (published_at IS NULL))
);

-- Keyset pages: WHERE tenant_id = $1 AND id < $2 ORDER BY id DESC (a backward index scan).
CREATE INDEX articles_tenant_id_id_idx ON articles (tenant_id, id);
```

```sql file=migrations/0002_outbox.sql
CREATE TABLE outbox (
    id               uuid        PRIMARY KEY DEFAULT uuidv7(),
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
    CONSTRAINT outbox_aggregate_seq_key UNIQUE (aggregate_id, aggregate_seq)
);

-- The relay's claim scan and the oldest-pending-age metric read only pending rows.
CREATE INDEX outbox_pending_idx ON outbox (created_at) WHERE published_at IS NULL AND dead_lettered_at IS NULL;
CREATE INDEX outbox_dead_letter_idx ON outbox (dead_lettered_at) WHERE dead_lettered_at IS NOT NULL;
```

```sql file=migrations/0003_idempotency_keys.sql
-- scope = tenant + principal; the response columns fill when the leased command commits.
CREATE TABLE idempotency_keys (
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
    PRIMARY KEY (scope, key)
);

CREATE INDEX idempotency_keys_expires_at_idx ON idempotency_keys (expires_at);
```

```sql file=migrations/0004_inbox.sql
-- Delivered messages, recorded in the same transaction as their effect.
CREATE TABLE inbox (
    consumer    text        NOT NULL,
    message_id  text        NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (consumer, message_id)
);
```

## PostgreSQL store

`PgStore` is a pool handle implementing every port; `db` sorts driver errors into retryable and not.

```rust file=src/outbound/mod.rs
//! Driven adapters: PostgreSQL persistence, the event publisher, the clock and ids.
pub mod postgres;
pub mod publisher;

use chrono::{DateTime, SubsecRound, Utc};
use domain::{Clock, IdGenerator};
use uuid::Uuid;

/// Truncated to the microseconds PostgreSQL stores, so a command's response and a later
/// read show the same instant.
pub struct SystemClock;

impl Clock for SystemClock {
    fn now(&self) -> DateTime<Utc> {
        Utc::now().trunc_subsecs(6)
    }
}

/// UUIDv7: time-ordered, so the primary key is also the newest-first keyset.
pub struct UuidV7;

impl IdGenerator for UuidV7 {
    fn new_id(&self) -> Uuid {
        Uuid::now_v7()
    }
}
```

```rust file=src/outbound/postgres/mod.rs
mod articles;
mod idempotency;
mod outbox;

use std::time::Duration;

use anyhow::Context as _;
use domain::{Inbox, Unavailable, UnitOfWork};
use secrecy::ExposeSecret;
use sqlx::postgres::{PgConnectOptions, PgPool, PgPoolOptions};

pub use outbox::{Relay, RelayConfig};

pub type PgTx = sqlx::Transaction<'static, sqlx::Postgres>;

pub static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!();

/// One cheap handle (a pool) implementing every persistence port: the use case begins and
/// commits through `UnitOfWork`; the other ports only run statements in its `PgTx`.
#[derive(Clone)]
pub struct PgStore {
    pool: PgPool,
    lease: Duration, // idempotency lease: longer than the request deadline
}

impl PgStore {
    pub fn new(pool: PgPool, lease: Duration) -> Self {
        Self { pool, lease }
    }

    pub async fn connect(db: &crate::config::Database, lease: Duration) -> anyhow::Result<Self> {
        let ms = |d: Duration| format!("{}ms", d.as_millis());
        let options: PgConnectOptions =
            db.url.expose_secret().parse().context("DATABASE_URL is not a PostgreSQL URL")?;
        let options = options.application_name("articles").options([
            ("statement_timeout", ms(db.statement_timeout)),
            ("idle_in_transaction_session_timeout", ms(db.idle_in_transaction_timeout)),
        ]);
        tracing::info!(host = options.get_host(), database = options.get_database(), "connecting"); // never the URL
        let pool = PgPoolOptions::new()
            .max_connections(db.max_connections)
            .acquire_timeout(Duration::from_secs(2)) // also bounds connecting: sqlx has no separate connect timeout
            .connect_with(options) // the one database round trip readiness waits for
            .await
            .context("connecting to PostgreSQL")?;
        Ok(Self::new(pool, lease))
    }

    pub fn pool(&self) -> &PgPool {
        &self.pool
    }
}

/// Tags the failures a retry can fix, so callers answer 503 + Retry-After instead of 500.
pub(crate) fn db(e: sqlx::Error) -> anyhow::Error {
    let transient = match &e {
        sqlx::Error::PoolTimedOut | sqlx::Error::PoolClosed | sqlx::Error::Io(_) => true,
        // connection lost, serialization failure, deadlock, statement_timeout, admin shutdown, too many connections
        sqlx::Error::Database(d) => d
            .code()
            .is_some_and(|c| c.starts_with("08") || ["40001", "40P01", "57014", "57P01", "53300"].contains(&&*c)),
        _ => false,
    };
    if transient { anyhow::Error::new(e).context(Unavailable) } else { e.into() }
}

impl UnitOfWork for PgStore {
    type Tx = PgTx;

    async fn begin(&self) -> anyhow::Result<PgTx> {
        self.pool.begin().await.map_err(db)
    }

    async fn commit(&self, tx: PgTx) -> anyhow::Result<()> {
        tx.commit().await.map_err(db)
    }
}

impl Inbox for PgStore {
    async fn record(&self, tx: &mut PgTx, consumer: &str, id: &str) -> anyhow::Result<bool> {
        let inserted = sqlx::query!(
            "INSERT INTO inbox (consumer, message_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
            consumer,
            id
        )
        .execute(&mut **tx) // `tx: &mut Transaction`, so `**tx` is the connection
        .await
        .map_err(db)?;
        Ok(inserted.rows_affected() == 1)
    }
}
```

## Article repository

Compile-time-checked queries (`query_as!` into one named row type), the tenant in every `WHERE`, the unique violation mapped by constraint name, and a keyset that needs no first-page branch.

```rust file=src/outbound/postgres/articles.rs
use chrono::{DateTime, Utc};
use domain::{Article, ArticleError, ArticleId, ArticleRecord, ArticleRepository, Page, PageRequest, Status, TenantId};
use uuid::Uuid;

use super::{PgStore, PgTx, db};

struct Row {
    id: Uuid,
    tenant_id: Uuid,
    author_id: String,
    slug: String,
    title: String,
    body: String,
    status: String,
    version: i32,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    published_at: Option<DateTime<Utc>>,
}

impl Row {
    fn into_article(self) -> anyhow::Result<Article> {
        let status = Status::parse(&self.status).ok_or_else(|| anyhow::anyhow!("unknown status {:?}", self.status))?;
        Ok(Article::rehydrate(ArticleRecord {
            id: self.id,
            tenant_id: self.tenant_id,
            author_id: self.author_id,
            slug: self.slug,
            title: self.title,
            body: self.body,
            status,
            version: self.version,
            created_at: self.created_at,
            updated_at: self.updated_at,
            published_at: self.published_at,
        }))
    }
}

impl ArticleRepository for PgStore {
    async fn insert(&self, tx: &mut PgTx, a: &Article) -> Result<(), ArticleError> {
        sqlx::query!(
            "INSERT INTO articles (id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)",
            a.id().0,
            a.tenant_id().0,
            a.author_id(),
            a.slug(),
            a.title(),
            a.body(),
            a.status().as_str(),
            a.version(),
            a.created_at(),
            a.updated_at(),
        )
        .execute(&mut **tx)
        .await
        .map_err(|e| match &e {
            // Map by constraint name: another UNIQUE (or the PK) must not read as "slug taken".
            sqlx::Error::Database(d) if d.constraint() == Some("articles_tenant_slug_key") => ArticleError::SlugTaken,
            _ => db(e).into(),
        })?;
        Ok(())
    }

    async fn find(&self, tenant: TenantId, id: ArticleId) -> anyhow::Result<Option<Article>> {
        sqlx::query_as!(
            Row,
            "SELECT id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at, published_at
             FROM articles WHERE tenant_id = $1 AND id = $2",
            tenant.0,
            id.0
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(db)?
        .map(Row::into_article)
        .transpose()
    }

    async fn find_for_update(&self, tx: &mut PgTx, tenant: TenantId, id: ArticleId) -> anyhow::Result<Option<Article>> {
        sqlx::query_as!(
            Row,
            "SELECT id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at, published_at
             FROM articles WHERE tenant_id = $1 AND id = $2 FOR UPDATE",
            tenant.0,
            id.0
        )
        .fetch_optional(&mut **tx)
        .await
        .map_err(db)?
        .map(Row::into_article)
        .transpose()
    }

    async fn list(&self, tenant: TenantId, page: PageRequest) -> anyhow::Result<Page<Article>> {
        let size = usize::from(page.size.get());
        // No branch for the first page: every UUID sorts below the max UUID.
        let before = page.after.map_or(Uuid::max(), |a| a.0);
        let mut rows = sqlx::query_as!(
            Row,
            "SELECT id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at, published_at
             FROM articles WHERE tenant_id = $1 AND id < $2 ORDER BY id DESC LIMIT $3",
            tenant.0,
            before,
            i64::from(page.size.get()) + 1
        )
        .fetch_all(&self.pool)
        .await
        .map_err(db)?;
        let has_more = rows.len() > size;
        rows.truncate(size);
        Ok(Page { items: rows.into_iter().map(Row::into_article).collect::<anyhow::Result<_>>()?, has_more })
    }

    async fn save(&self, tx: &mut PgTx, a: &Article, version: i32, status: Status) -> Result<(), ArticleError> {
        let updated = sqlx::query!(
            "UPDATE articles SET title = $3, body = $4, status = $5, version = $6, updated_at = $7, published_at = $8
             WHERE tenant_id = $1 AND id = $2 AND version = $9 AND status = $10",
            a.tenant_id().0,
            a.id().0,
            a.title(),
            a.body(),
            a.status().as_str(),
            a.version(),
            a.updated_at(),
            a.published_at(),
            version,
            status.as_str(),
        )
        .execute(&mut **tx)
        .await
        .map_err(db)?;
        if updated.rows_affected() == 0 {
            return Err(ArticleError::VersionConflict);
        }
        Ok(())
    }
}
```

## Outbox and relay

`append` writes in the command's transaction; the relay claims only each aggregate's head row, publishes outside any transaction, and retries with jittered backoff until it dead-letters.

```rust file=src/outbound/postgres/outbox.rs
use std::collections::HashMap;
use std::time::Duration;

use domain::{ArticleEvent, Outbox};
use opentelemetry::metrics::Gauge;
use serde_json::json;
use tokio_util::sync::CancellationToken;
use tracing_opentelemetry::OpenTelemetrySpanExt;

use super::{PgStore, PgTx, db};
use crate::outbound::publisher::{EventPublisher, OutboxEvent};

impl Outbox for PgStore {
    async fn append(&self, tx: &mut PgTx, event: &ArticleEvent) -> anyhow::Result<()> {
        // A new variant makes this `let` refutable: the compiler sends you here.
        let ArticleEvent::Published { article_id, tenant_id, slug, version, published_at } = event;
        let payload = json!({ "article_id": article_id.0, "slug": slug, "published_at": published_at });
        // Captured at insert, so the consumer's span links back to this request.
        let mut headers = HashMap::from([("tenant_id".to_owned(), tenant_id.0.to_string())]);
        let context = tracing::Span::current().context();
        opentelemetry::global::get_text_map_propagator(|p| p.inject_context(&context, &mut headers));
        sqlx::query!(
            "INSERT INTO outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload, headers)
             VALUES ($1, 'article', $2, $3, 'article.published', 1, $4, $5)",
            tenant_id.0,
            article_id.0,
            version, // aggregate_seq = the aggregate's new version
            payload,
            json!(headers),
        )
        .execute(&mut **tx)
        .await
        .map_err(db)?;
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
        // One short statement: SKIP LOCKED splits rows between relays, NOT EXISTS claims only an
        // aggregate's head, the lease (next_attempt_at) hides the row while it is published.
        let claimed = sqlx::query_as!(
            OutboxEvent,
            "UPDATE outbox SET attempts = attempts + 1, next_attempt_at = now() + make_interval(secs => $2)
             WHERE id IN (
                 SELECT id FROM outbox o
                 WHERE published_at IS NULL AND dead_lettered_at IS NULL AND next_attempt_at <= now()
                   AND NOT EXISTS (SELECT 1 FROM outbox e WHERE e.aggregate_id = o.aggregate_id
                       AND e.aggregate_seq < o.aggregate_seq AND e.published_at IS NULL AND e.dead_lettered_at IS NULL)
                 ORDER BY created_at LIMIT $1 FOR UPDATE SKIP LOCKED)
             RETURNING id, tenant_id, aggregate_id, aggregate_seq, event_type, event_version, payload, headers, attempts",
            self.config.batch,
            self.config.lease.as_secs_f64(),
        )
        .fetch_all(self.store.pool())
        .await
        .map_err(db)?;
        for event in &claimed {
            let published = tokio::time::timeout(self.config.lease / 2, self.publisher.publish(event)).await;
            match published.unwrap_or_else(|_| Err(anyhow::anyhow!("publish timed out"))) {
                Ok(()) => {
                    sqlx::query!("UPDATE outbox SET published_at = now() WHERE id = $1", event.id)
                        .execute(self.store.pool())
                        .await
                        .map_err(db)?;
                }
                Err(e) => self.retry_later(event, &e).await?,
            }
        }
        Ok(claimed.len())
    }

    async fn retry_later(&self, event: &OutboxEvent, error: &anyhow::Error) -> anyhow::Result<()> {
        let dead = event.attempts >= self.config.max_attempts;
        // Exponential backoff, full jitter.
        sqlx::query!(
            "UPDATE outbox SET last_error = $2,
                 next_attempt_at = now() + make_interval(secs => random() * least(300, $3 * 2 ^ (attempts - 1))),
                 dead_lettered_at = CASE WHEN $4 THEN now() END
             WHERE id = $1",
            event.id,
            format!("{error:#}"),
            self.config.backoff_base.as_secs_f64(),
            dead,
        )
        .execute(self.store.pool())
        .await
        .map_err(db)?;
        if dead {
            tracing::error!(event_id = %event.id, error = format!("{error:#}"), "outbox event dead-lettered");
        }
        Ok(())
    }

    async fn record_lag(&self) -> anyhow::Result<()> {
        let lag = sqlx::query!(
            r#"SELECT
                 (SELECT EXTRACT(EPOCH FROM now() - min(created_at))::float8 FROM outbox
                  WHERE published_at IS NULL AND dead_lettered_at IS NULL) AS "oldest_pending_secs",
                 (SELECT count(*) FROM outbox WHERE dead_lettered_at IS NOT NULL) AS "dead_letters!""#
        )
        .fetch_one(self.store.pool())
        .await
        .map_err(db)?;
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

## Idempotency store

Execution is granted by a write, never a read; completion runs in the command's transaction and fails if the lease was lost.

```rust file=src/outbound/postgres/idempotency.rs
use std::time::Duration;

use anyhow::Context as _;
use domain::{Acquire, IdempotencyStore, Lease, StoredResponse};
use uuid::Uuid;

use super::{PgStore, PgTx, db};

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
                "INSERT INTO idempotency_keys (scope, key, request_hash, lease_token, locked_until, expires_at)
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
            .map_err(db)?;
            if won.is_some() {
                return Ok(Acquire::Execute(lease()));
            }
            // 2. The key is held: this read decides mismatch / replay / in-flight, never execution.
            let held = sqlx::query!(
                r#"SELECT request_hash, completed_at IS NOT NULL AS "completed!", response_status, response_headers, response_body
                   FROM idempotency_keys WHERE scope = $1 AND key = $2"#,
                scope,
                key
            )
            .fetch_optional(self.pool())
            .await
            .map_err(db)?;
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
                "UPDATE idempotency_keys SET lease_token = $4, locked_until = now() + make_interval(secs => $5),
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
            .map_err(db)?;
            return Ok(if taken.is_some() { Acquire::Execute(lease()) } else { Acquire::InFlight });
        }
        Ok(Acquire::InFlight)
    }

    async fn complete(&self, tx: &mut PgTx, lease: &Lease, response: &StoredResponse) -> anyhow::Result<()> {
        let completed = sqlx::query!(
            "UPDATE idempotency_keys SET response_status = $4, response_headers = $5, response_body = $6, completed_at = now()
             WHERE scope = $1 AND key = $2 AND lease_token = $3 AND completed_at IS NULL",
            lease.scope,
            lease.key,
            lease.token,
            i32::from(response.status),
            serde_json::to_value(&response.headers)?,
            response.body,
        )
        .execute(&mut **tx)
        .await
        .map_err(db)?;
        anyhow::ensure!(completed.rows_affected() == 1, "idempotency lease lost (taken over after expiry)");
        Ok(())
    }

    async fn release(&self, lease: &Lease) -> anyhow::Result<()> {
        sqlx::query!(
            "DELETE FROM idempotency_keys WHERE scope = $1 AND key = $2 AND lease_token = $3 AND completed_at IS NULL",
            lease.scope,
            lease.key,
            lease.token
        )
        .execute(self.pool())
        .await
        .map_err(db)?;
        Ok(())
    }

    async fn purge_expired(&self) -> anyhow::Result<u64> {
        let purged = sqlx::query!(
            "DELETE FROM idempotency_keys WHERE expires_at < now() AND (completed_at IS NOT NULL OR locked_until < now())"
        )
        .execute(self.pool())
        .await
        .map_err(db)?;
        Ok(purged.rows_affected())
    }
}
```

## Problem documents

One registry, one `ApiError`, one renderer. Extractors, handlers, fallbacks, the panic handler and the deadline all end here.

```rust file=src/inbound/http/problem.rs
use std::sync::Arc;

use axum::body::{Body, HttpBody as _};
use axum::extract::{Request, State};
use axum::http::{HeaderMap, HeaderName, HeaderValue, StatusCode, header};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use domain::ArticleError;
use serde::Serialize;
use utoipa::ToSchema;

/// The problem registry (api-design.md § Problem Types).
#[derive(Clone, Copy, Debug)]
pub enum ProblemType {
    MalformedRequest,
    Unauthenticated,
    Forbidden,
    NotFound,
    MethodNotAllowed,
    AlreadyExists,
    InvalidTransition,
    VersionConflict,
    IdempotencyInFlight,
    PreconditionFailed,
    PayloadTooLarge,
    UnsupportedMediaType,
    ValidationFailed,
    IdempotencyKeyMismatch,
    Internal,
    Unavailable,
}

impl ProblemType {
    fn meta(self) -> (StatusCode, &'static str, &'static str) {
        use StatusCode as S;
        match self {
            Self::MalformedRequest => (S::BAD_REQUEST, "malformed-request", "Malformed request"),
            Self::Unauthenticated => (S::UNAUTHORIZED, "unauthenticated", "Unauthenticated"),
            Self::Forbidden => (S::FORBIDDEN, "forbidden", "Forbidden"),
            Self::NotFound => (S::NOT_FOUND, "not-found", "Not found"),
            Self::MethodNotAllowed => (S::METHOD_NOT_ALLOWED, "method-not-allowed", "Method not allowed"),
            Self::AlreadyExists => (S::CONFLICT, "already-exists", "Already exists"),
            Self::InvalidTransition => (S::CONFLICT, "invalid-transition", "Invalid transition"),
            Self::VersionConflict => (S::CONFLICT, "version-conflict", "Version conflict"),
            Self::IdempotencyInFlight => (S::CONFLICT, "idempotency-in-flight", "Request in progress"),
            Self::PreconditionFailed => (S::PRECONDITION_FAILED, "precondition-failed", "Precondition failed"),
            Self::PayloadTooLarge => (S::PAYLOAD_TOO_LARGE, "payload-too-large", "Payload too large"),
            Self::UnsupportedMediaType => {
                (S::UNSUPPORTED_MEDIA_TYPE, "unsupported-media-type", "Unsupported media type")
            }
            Self::ValidationFailed => (S::UNPROCESSABLE_ENTITY, "validation-failed", "Validation failed"),
            Self::IdempotencyKeyMismatch => {
                (S::UNPROCESSABLE_ENTITY, "idempotency-key-mismatch", "Idempotency key mismatch")
            }
            Self::Internal => (S::INTERNAL_SERVER_ERROR, "internal", "Internal error"),
            Self::Unavailable => (S::SERVICE_UNAVAILABLE, "unavailable", "Service unavailable"),
        }
    }
}

/// One invalid input: a JSON Pointer into the body, or a query or path parameter.
#[derive(Clone, Debug, Serialize, ToSchema)]
pub struct FieldError {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pointer: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parameter: Option<String>,
    pub detail: String,
    pub code: String,
}

/// RFC 9457 document; also the OpenAPI schema of every 4xx and 5xx.
#[derive(Serialize, ToSchema)]
pub struct Problem {
    #[serde(rename = "type")]
    pub kind: String,
    pub title: &'static str,
    pub status: u16,
    pub detail: String,
    pub instance: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub errors: Vec<FieldError>,
}

#[derive(utoipa::IntoResponses)]
pub enum Problems {
    #[response(status = "4XX", description = "Client error", content_type = "application/problem+json")]
    Client(Problem),
    #[response(status = "5XX", description = "Server error or deadline", content_type = "application/problem+json")]
    Server(Problem),
}

/// Every failure at the HTTP edge. `into_response` records the problem in a response
/// extension and `render_problems` writes the body: only a layer knows the `type` base and
/// the request path (`instance`). Boxed, because every handler returns it in a `Result`.
#[derive(Debug)]
pub struct ApiError(Box<(Pending, HeaderMap)>);

#[derive(Clone, Debug)]
struct Pending {
    kind: ProblemType,
    detail: String,
    errors: Vec<FieldError>,
}

impl ApiError {
    pub fn new(kind: ProblemType, detail: impl Into<String>) -> Self {
        Self(Box::new((Pending { kind, detail: detail.into(), errors: Vec::new() }, HeaderMap::new())))
    }

    pub fn with_header(mut self, name: HeaderName, value: &'static str) -> Self {
        self.0.1.insert(name, HeaderValue::from_static(value));
        self
    }

    pub fn validation(errors: Vec<FieldError>) -> Self {
        let mut error = Self::new(ProblemType::ValidationFailed, "The request has invalid fields");
        error.0.0.errors = errors;
        error
    }

    pub fn invalid_parameter(name: &str, detail: &str, code: &str) -> Self {
        let error =
            FieldError { pointer: None, parameter: Some(name.into()), detail: detail.into(), code: code.into() };
        Self::validation(vec![error])
    }

    pub fn malformed(detail: &str) -> Self {
        Self::new(ProblemType::MalformedRequest, detail)
    }

    pub fn unauthenticated(detail: &str, challenge: &'static str) -> Self {
        Self::new(ProblemType::Unauthenticated, detail).with_header(header::WWW_AUTHENTICATE, challenge)
    }

    /// Never carries the cause: that is logged once, with the request id, where it is known.
    pub fn internal() -> Self {
        Self::new(ProblemType::Internal, "An unexpected error occurred")
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (pending, headers) = *self.0;
        let mut res = (pending.kind.meta().0, headers).into_response();
        res.extensions_mut().insert(pending);
        res
    }
}

impl From<ArticleError> for ApiError {
    fn from(e: ArticleError) -> Self {
        use ProblemType as P;
        let detail = e.to_string();
        match e {
            ArticleError::NotFound => Self::new(P::NotFound, detail),
            ArticleError::Forbidden => Self::new(P::Forbidden, detail),
            ArticleError::Invalid(violations) => Self::validation(
                violations
                    .into_iter()
                    .map(|v| FieldError {
                        pointer: Some(format!("#/{}", v.field)),
                        parameter: None,
                        detail: v.detail.into(),
                        code: v.code.into(),
                    })
                    .collect(),
            ),
            ArticleError::SlugTaken => Self::new(P::AlreadyExists, detail),
            ArticleError::InvalidTransition { .. } => Self::new(P::InvalidTransition, detail),
            ArticleError::VersionConflict => Self::new(P::VersionConflict, detail),
            ArticleError::PreconditionFailed { .. } => Self::new(P::PreconditionFailed, detail),
            ArticleError::Unavailable(cause) => {
                tracing::warn!(error = format!("{cause:#}"), "dependency unavailable");
                Self::new(P::Unavailable, "Temporarily unable to complete the request")
            }
            ArticleError::Unknown(cause) => {
                tracing::error!(error = format!("{cause:#}"), "unhandled error");
                Self::internal()
            }
        }
    }
}

/// Renders every pending problem, and turns an empty error response from a layer (the
/// timeout's bare 503) into a problem too.
pub async fn render_problems(State(base): State<Arc<str>>, req: Request, next: Next) -> Response {
    let instance = req.uri().path().to_owned();
    finalize(next.run(req).await, &base, &instance)
}

pub fn finalize(mut res: Response, base: &str, instance: &str) -> Response {
    let bare = res.status().as_u16() >= 400 && res.body().size_hint().exact() == Some(0);
    let pending = match res.extensions_mut().remove::<Pending>() {
        Some(pending) => pending,
        None if bare && res.status() == StatusCode::SERVICE_UNAVAILABLE => {
            Pending { kind: ProblemType::Unavailable, detail: "The request deadline passed".into(), errors: Vec::new() }
        }
        None if bare => Pending { kind: ProblemType::Internal, detail: "Request failed".into(), errors: Vec::new() },
        None => return res,
    };
    let (status, slug, title) = pending.kind.meta();
    let (mut parts, _) = res.into_parts();
    let (detail, errors, instance) = (pending.detail, pending.errors, instance.to_owned());
    let problem = Problem { kind: format!("{base}{slug}"), title, status: status.as_u16(), detail, instance, errors };
    parts.status = status;
    parts.headers.remove(header::CONTENT_LENGTH);
    parts.headers.insert(header::CONTENT_TYPE, HeaderValue::from_static("application/problem+json"));
    if status == StatusCode::SERVICE_UNAVAILABLE {
        parts.headers.entry(header::RETRY_AFTER).or_insert(HeaderValue::from_static("1"));
    }
    Response::from_parts(parts, Body::from(serde_json::to_vec(&problem).unwrap_or_default()))
}
```

## Extractors

Handlers use only these, never axum's `Json`, `Path` or `Query`.

```rust file=src/inbound/http/extract.rs
//! Extractors whose rejections are problems: axum's own `Json`, `Path` and `Query` reject with
//! text/plain bodies that never pass through `ApiError`.
use axum::body::Bytes;
use axum::extract::rejection::{PathRejection, QueryRejection};
use axum::extract::{FromRequest, FromRequestParts, Request};
use axum::http::{StatusCode, header, request::Parts};
use domain::Actor;
use serde::de::DeserializeOwned;
use serde_path_to_error::Segment;

use super::problem::{ApiError, FieldError, ProblemType};

#[derive(FromRequestParts)]
#[from_request(via(axum::extract::Path), rejection(ApiError))]
pub struct AppPath<T>(pub T);

impl From<PathRejection> for ApiError {
    fn from(r: PathRejection) -> Self {
        match r.status() {
            StatusCode::BAD_REQUEST => ApiError::malformed("A path parameter is not a valid identifier"),
            _ => ApiError::internal(), // route and handler disagree: a bug, not the client's fault
        }
    }
}

#[derive(FromRequestParts)]
#[from_request(via(axum::extract::Query), rejection(ApiError))]
pub struct AppQuery<T>(pub T);

impl From<QueryRejection> for ApiError {
    fn from(_: QueryRejection) -> Self {
        ApiError::malformed("The query string could not be parsed")
    }
}

/// JSON body: not JSON → 415, over the limit → 413, unparseable → 400, the wrong shape
/// (types, unknown or missing members) → 422 with a JSON Pointer.
pub struct AppJson<T>(pub T);

impl<S: Send + Sync, T: DeserializeOwned> FromRequest<S> for AppJson<T> {
    type Rejection = ApiError;

    async fn from_request(req: Request, state: &S) -> Result<Self, ApiError> {
        let mime = req.headers().get(header::CONTENT_TYPE).and_then(|v| v.to_str().ok()).unwrap_or_default();
        let mime = mime.split(';').next().unwrap_or_default().trim().to_ascii_lowercase();
        if !(mime == "application/json" || (mime.starts_with("application/") && mime.ends_with("+json"))) {
            return Err(ApiError::new(ProblemType::UnsupportedMediaType, "Send Content-Type: application/json"));
        }
        let bytes = Bytes::from_request(req, state).await.map_err(|r| match r.status() {
            StatusCode::PAYLOAD_TOO_LARGE => {
                ApiError::new(ProblemType::PayloadTooLarge, "The request body is too large")
            }
            _ => ApiError::malformed("The request body could not be read"),
        })?;
        let de = &mut serde_json::Deserializer::from_slice(&bytes);
        match serde_path_to_error::deserialize(&mut *de) {
            Ok(value) if de.end().is_ok() => Ok(Self(value)),
            Err(e) if e.inner().is_data() => Err(ApiError::validation(vec![field_error(&e)])),
            _ => Err(ApiError::malformed("The request body is not valid JSON")),
        }
    }
}

fn field_error(e: &serde_path_to_error::Error<serde_json::Error>) -> FieldError {
    let message = e.inner().to_string();
    let detail = message.split(" at line ").next().unwrap_or_default().to_owned();
    let mut pointer = String::from("#");
    for segment in e.path().iter() {
        let token = match segment {
            Segment::Seq { index } => index.to_string(),
            Segment::Map { key } | Segment::Enum { variant: key } => key.replace('~', "~0").replace('/', "~1"),
            Segment::Unknown => "-".into(),
        };
        pointer = format!("{pointer}/{token}");
    }
    // serde reports a missing member at its parent: point at the member itself.
    let missing = detail.strip_prefix("missing field `").and_then(|rest| rest.split('`').next());
    let code = match missing {
        Some(field) => {
            pointer = format!("{pointer}/{field}");
            "required"
        }
        None if detail.starts_with("unknown field") => "unknown_field",
        None => "invalid_type",
    };
    FieldError { pointer: Some(pointer), parameter: None, detail, code: code.into() }
}

/// The actor `auth::authenticate` put in the request extensions. A route mounted outside that
/// layer fails closed with 401.
pub struct Caller(pub Actor);

impl<S: Send + Sync> FromRequestParts<S> for Caller {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, ApiError> {
        let actor = parts.extensions.get::<Actor>().cloned();
        actor.map(Self).ok_or_else(|| ApiError::unauthenticated("Authentication required", "Bearer"))
    }
}
```

## Authentication

A `route_layer` on the `/v1` router builds the `Actor`; `Caller` reads it and fails closed.

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
            JwtKeys::Hs256 { secret } => Keys::Hs256(DecodingKey::from_secret(secret.expose_secret().as_bytes())),
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

## Article routes

Handlers parse, call the driving port and map the result. Success responses are built as `StoredResponse`, the exact bytes an idempotent replay returns.

```rust file=src/inbound/http/articles.rs
use axum::extract::State;
use axum::http::{HeaderMap, header};
use axum::response::Response;
use axum::{Extension, Json};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use chrono::{DateTime, Utc};
use domain::{
    Article, ArticleId, ArticlePatch, Articles, Idempotency, Lease, NewArticle, PageRequest, PageSize, StoredResponse,
};
use serde::{Deserialize, Deserializer, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use super::AppState;
use super::extract::{AppJson, AppPath, AppQuery, Caller};
use super::idempotency::respond;
use super::problem::{ApiError, FieldError, ProblemType, Problems};

#[derive(Deserialize, ToSchema)]
#[serde(deny_unknown_fields)] // owner, tenant and role never come from a body
pub struct CreateArticle {
    slug: String,
    title: String,
    #[serde(default)]
    body: String,
}

/// JSON Merge Patch: absent = unchanged; `null` clears `body` and is invalid for `title`.
#[derive(Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct UpdateArticle {
    #[serde(default, deserialize_with = "present")]
    #[schema(value_type = Option<String>)]
    title: Option<Option<String>>,
    #[serde(default, deserialize_with = "present")]
    #[schema(value_type = Option<String>)]
    body: Option<Option<String>>,
}

/// A present member, `null` included, becomes `Some`: a plain `Option` would read `null` as absent.
fn present<'de, D: Deserializer<'de>, T: Deserialize<'de>>(d: D) -> Result<Option<T>, D::Error> {
    T::deserialize(d).map(Some)
}

/// Strings, checked by hand, so a bad value is a 422 naming the parameter.
#[derive(Deserialize, IntoParams)]
#[into_params(parameter_in = Query)]
pub struct ListParams {
    /// 1 to 100, default 20; larger values are clamped.
    #[param(value_type = Option<u32>, minimum = 1)]
    limit: Option<String>,
    cursor: Option<String>,
}

#[derive(Serialize, ToSchema)]
pub struct ArticleData {
    id: Uuid,
    slug: String,
    title: String,
    body: String,
    status: &'static str,
    author_id: String,
    version: i32,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    published_at: Option<DateTime<Utc>>,
}

impl From<&Article> for ArticleData {
    fn from(a: &Article) -> Self {
        Self {
            id: a.id().0,
            slug: a.slug().into(),
            title: a.title().into(),
            body: a.body().into(),
            status: a.status().as_str(),
            author_id: a.author_id().into(),
            version: a.version(),
            created_at: a.created_at(),
            updated_at: a.updated_at(),
            published_at: a.published_at(),
        }
    }
}

#[derive(Serialize, ToSchema)]
pub struct ArticleBody {
    data: ArticleData,
}

#[derive(Serialize, ToSchema)]
pub struct ArticlePage {
    data: Vec<ArticleData>,
    meta: PageMeta,
}

#[derive(Serialize, ToSchema)]
pub struct PageMeta {
    limit: u8,
    #[schema(required = true)] // always present: null on the last page
    next_cursor: Option<String>,
    has_more: bool,
}

#[utoipa::path(post, path = "/v1/articles", request_body = CreateArticle, params(("Idempotency-Key" = Option<String>, Header)),
    responses((status = 201, body = ArticleBody, headers(("Location"), ("ETag"))), Problems), security(("bearer" = [])))]
pub async fn create_article<A: Articles>(
    State(state): State<AppState<A>>,
    Caller(actor): Caller,
    lease: Option<Extension<Lease>>,
    AppJson(input): AppJson<CreateArticle>,
) -> Result<Response, ApiError> {
    let input = NewArticle { slug: input.slug, title: input.title, body: input.body };
    let article = state.articles.create(&actor, input, idempotency(lease.as_ref(), created)).await?;
    Ok(respond(created(&article)))
}

#[utoipa::path(get, path = "/v1/articles/{id}", params(("id" = Uuid, Path)),
    responses((status = 200, body = ArticleBody, headers(("ETag"))), Problems), security(("bearer" = [])))]
pub async fn get_article<A: Articles>(
    State(state): State<AppState<A>>,
    Caller(actor): Caller,
    AppPath(id): AppPath<Uuid>,
) -> Result<Response, ApiError> {
    Ok(respond(ok(&state.articles.get(&actor, ArticleId(id)).await?)))
}

#[utoipa::path(get, path = "/v1/articles", params(ListParams),
    responses((status = 200, body = ArticlePage), Problems), security(("bearer" = [])))]
pub async fn list_articles<A: Articles>(
    State(state): State<AppState<A>>,
    Caller(actor): Caller,
    AppQuery(params): AppQuery<ListParams>,
) -> Result<Json<ArticlePage>, ApiError> {
    let size = page_size(params.limit.as_deref())?;
    let after = params.cursor.as_deref().map(decode_cursor).transpose()?;
    let page = state.articles.list(&actor, PageRequest { after, size }).await?;
    let next_cursor = page.items.last().filter(|_| page.has_more).map(|a| encode_cursor(a.id()));
    let meta = PageMeta { limit: size.get(), next_cursor, has_more: page.has_more };
    Ok(Json(ArticlePage { data: page.items.iter().map(ArticleData::from).collect(), meta }))
}

#[utoipa::path(patch, path = "/v1/articles/{id}", request_body = UpdateArticle, params(("id" = Uuid, Path), ("If-Match" = Option<String>, Header)),
    responses((status = 200, body = ArticleBody, headers(("ETag"))), Problems), security(("bearer" = [])))]
pub async fn update_article<A: Articles>(
    State(state): State<AppState<A>>,
    Caller(actor): Caller,
    AppPath(id): AppPath<Uuid>,
    headers: HeaderMap,
    AppJson(patch): AppJson<UpdateArticle>,
) -> Result<Response, ApiError> {
    let if_match = if_match(&headers)?;
    let title = match patch.title {
        Some(None) => {
            let null = FieldError {
                pointer: Some("#/title".into()),
                parameter: None,
                detail: "must not be null".into(),
                code: "null".into(),
            };
            return Err(ApiError::validation(vec![null]));
        }
        title => title.flatten(),
    };
    let patch = ArticlePatch { title, body: patch.body.map(Option::unwrap_or_default) };
    Ok(respond(ok(&state.articles.update(&actor, ArticleId(id), patch, if_match).await?)))
}

#[utoipa::path(post, path = "/v1/articles/{id}/publish", params(("id" = Uuid, Path), ("Idempotency-Key" = Option<String>, Header)),
    responses((status = 200, body = ArticleBody, headers(("ETag"))), Problems), security(("bearer" = [])))]
pub async fn publish_article<A: Articles>(
    State(state): State<AppState<A>>,
    Caller(actor): Caller,
    lease: Option<Extension<Lease>>,
    AppPath(id): AppPath<Uuid>,
) -> Result<Response, ApiError> {
    Ok(respond(ok(&state.articles.publish(&actor, ArticleId(id), idempotency(lease.as_ref(), ok)).await?)))
}

fn idempotency(
    lease: Option<&Extension<Lease>>,
    render: fn(&Article) -> StoredResponse,
) -> Option<Idempotency<'_, Article>> {
    lease.map(|Extension(lease)| Idempotency { lease, render })
}

fn created(article: &Article) -> StoredResponse {
    let mut response = ok(article);
    response.status = 201;
    response.headers.push(("location".into(), format!("/v1/articles/{}", article.id().0)));
    response
}

fn ok(article: &Article) -> StoredResponse {
    let headers =
        vec![("content-type".into(), "application/json".into()), ("etag".into(), format!("\"{}\"", article.version()))];
    let body = serde_json::to_vec(&ArticleBody { data: article.into() }).unwrap_or_default();
    StoredResponse { status: 200, headers, body }
}

/// `If-Match: "<version>"`, a strong ETag; `*` matches any current version.
fn if_match(headers: &HeaderMap) -> Result<Option<i32>, ApiError> {
    let Some(value) = headers.get(header::IF_MATCH) else { return Ok(None) };
    let value = value.to_str().unwrap_or_default().trim();
    if value == "*" {
        return Ok(None);
    }
    let version = value.strip_prefix('"').and_then(|v| v.strip_suffix('"')).and_then(|v| v.parse().ok());
    version
        .map(Some)
        .ok_or_else(|| ApiError::new(ProblemType::PreconditionFailed, "If-Match must be an ETag from this API"))
}

/// Default 20, clamped to 100; below 1 or not an integer → 422.
fn page_size(raw: Option<&str>) -> Result<PageSize, ApiError> {
    let requested = raw.map_or(Ok(20), str::parse::<i64>);
    let requested =
        requested.map_err(|_| ApiError::invalid_parameter("limit", "must be an integer", "invalid_type"))?;
    let clamped = u8::try_from(requested.min(i64::from(PageSize::MAX))).ok();
    clamped
        .and_then(PageSize::new)
        .ok_or_else(|| ApiError::invalid_parameter("limit", "must be at least 1", "too_small"))
}

// Opaque cursor: unpadded base64url of a versioned position, bound to the only sort
// (id descending). Anything that does not decode is a 400.
fn encode_cursor(id: ArticleId) -> String {
    URL_SAFE_NO_PAD.encode(format!("v1:{}", id.0))
}

fn decode_cursor(raw: &str) -> Result<ArticleId, ApiError> {
    let text = URL_SAFE_NO_PAD.decode(raw).ok().and_then(|bytes| String::from_utf8(bytes).ok());
    let id = text.and_then(|t| Uuid::parse_str(t.strip_prefix("v1:")?).ok());
    id.map(ArticleId).ok_or_else(|| ApiError::malformed("The cursor is not valid"))
}
```

## Idempotency wrapper

One middleware, layered onto the idempotent routes only: it validates the key, buffers the body for the hash, acquires, and hands the `Lease` to the handler.

```rust file=src/inbound/http/idempotency.rs
use std::sync::Arc;

use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::{HeaderMap, HeaderName, HeaderValue, Method, StatusCode, header};
use axum::middleware::Next;
use axum::response::Response;
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use domain::{Acquire, ArticleError, IdempotencyStore, Lease, StoredResponse};
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
    let hash = request_hash(&parts.method, parts.uri.path(), &bytes);
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
    if !status.is_client_error() || matches!(status, StatusCode::REQUEST_TIMEOUT | StatusCode::TOO_MANY_REQUESTS) {
        return Ok(res);
    }
    // A deterministic 4xx committed nothing: store it on its own so a retry replays it.
    let (parts, body) = problem::finalize(res, &state.problem_base, &instance).into_parts();
    let body = to_bytes(body, MAX_BODY).await.unwrap_or_default();
    let stored =
        StoredResponse { status: status.as_u16(), headers: defining_headers(&parts.headers), body: body.to_vec() };
    match complete_alone(state.store.as_ref(), &lease, &stored).await {
        Ok(()) => guard.0 = None,
        Err(e) => tracing::warn!(error = format!("{e:#}"), "could not store a 4xx outcome; key released"),
    }
    Ok(Response::from_parts(parts, Body::from(body)))
}

async fn complete_alone<I: IdempotencyStore>(store: &I, lease: &Lease, stored: &StoredResponse) -> anyhow::Result<()> {
    let mut tx = store.begin().await?;
    store.complete(&mut tx, lease, stored).await?;
    store.commit(tx).await
}

struct ReleaseOnDrop<I: IdempotencyStore>(Option<(Arc<I>, Lease)>);

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

/// Method, path (not the route template) and canonical JSON: a `Value` round trip sorts keys
/// unless a dependency enables serde_json's `preserve_order` (the test catches that).
fn request_hash(method: &Method, path: &str, body: &[u8]) -> String {
    let canonical = serde_json::from_slice::<serde_json::Value>(body).ok().and_then(|v| serde_json::to_vec(&v).ok());
    let mut hasher = Sha256::new();
    for part in [method.as_str().as_bytes(), b"\n", path.as_bytes(), b"\n", canonical.as_deref().unwrap_or(body)] {
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
fn hash_ignores_key_order_but_not_the_path() {
    let hash = |path, body: &str| request_hash(&Method::POST, path, body.as_bytes());
    assert_eq!(
        hash("/v1/a", r#"{"x":1,"y":2}"#),
        hash("/v1/a", r#"{ "y": 2, "x": 1 }"#),
        "serde_json preserve_order is on"
    );
    assert_ne!(hash("/v1/a", "{}"), hash("/v1/b", "{}"));
}
```

## Moderation webhook

An internal router outside public auth and OpenAPI: signature first, then the use case, whose inbox row commits with the effect.

```rust file=src/inbound/webhooks.rs
//! Moderation webhook (Standard Webhooks): 2xx for every permanent outcome, 5xx only for transient ones.
use std::sync::Arc;

use axum::http::{HeaderMap, StatusCode, header};
use axum::{Router, body::Bytes, extract::DefaultBodyLimit, extract::State, routing::post};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use domain::{Actor, ArticleId, Articles, TenantId};
use hmac::{Hmac, KeyInit, Mac};
use secrecy::{ExposeSecret, SecretSlice};
use serde::Deserialize;
use uuid::Uuid;

use super::http::{MAX_BODY, problem::ApiError, problem::ProblemType};

struct WebhookState<A> {
    articles: Arc<A>,
    secrets: Arc<[SecretSlice<u8>]>,
}

impl<A> Clone for WebhookState<A> {
    fn clone(&self) -> Self {
        Self { articles: self.articles.clone(), secrets: self.secrets.clone() }
    }
}

pub fn router<A: Articles>(articles: Arc<A>, secrets: Vec<SecretSlice<u8>>) -> Router {
    Router::new()
        .route("/internal/webhooks/moderation", post(moderation::<A>))
        .layer(DefaultBodyLimit::max(MAX_BODY))
        .with_state(WebhookState { articles, secrets: secrets.into() })
}

#[derive(Deserialize)]
struct Verdict {
    tenant_id: Uuid,
    article_id: Uuid,
    verdict: String,
}

async fn moderation<A: Articles>(
    State(state): State<WebhookState<A>>,
    headers: HeaderMap,
    body: Bytes, // the raw bytes: the signature covers them exactly as sent
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
    let system = Actor {
        tenant_id: TenantId(event.tenant_id),
        subject: "system:moderation".into(),
        roles: vec!["moderator".into()],
    };
    // Unavailable → 503 + Retry-After so the sender retries; every recorded outcome → 204.
    let outcome = state.articles.archive(&system, ArticleId(event.article_id), message_id).await?;
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

```rust file=src/inbound/mod.rs
pub mod http;
pub mod webhooks;
```
