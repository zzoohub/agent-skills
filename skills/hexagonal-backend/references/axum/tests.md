# Axum examples: tests

The proof: a harness on real PostgreSQL with the application's role, use cases and adapters tested together, and the HTTP risk set through the app factory. Every `file=` block is a complete file of the project in `slice.md`. The model tests sit at the end of `domain/src/model.rs` in `slice.md`. Three unit tests sit beside the code they guard: the request hash in `idempotency.rs`, the bare-error rendering in `problem.rs` and the startup refusals in `config.rs`. `guide.md` § 8 says how each risk is forced.

## Contents

1. [Harness](#harness)
2. [Use cases and adapters on PostgreSQL](#use-cases-and-adapters-on-postgresql)
3. [HTTP tests](#http-tests)

## Harness

One test binary, so one link step. Each test gets its own database from `#[sqlx::test(migrations = false)]`, and `db` builds it the way production does: the cluster role, the release step as the owner, then a `PgStore` connected as `app_rw` through the production `connect`. `owner` sees past the policies and is used only to seed rows and inspect them.

```rust file=tests/api/main.rs
//! One integration-test binary (one link step). Every test gets its own database from
//! `#[sqlx::test]`; DATABASE_URL must point at a PostgreSQL 18 server as a role that may create
//! databases and roles.
mod http;
mod postgres;
mod support;
```

```rust file=tests/api/support.rs
use std::sync::Arc;
use std::time::Duration;

use articles::config::{Database, Jwt, JwtKeys};
use articles::inbound::http::{self, Deps, auth::Authenticator, probes::Readiness};
use articles::outbound::postgres::{self, PgStore};
use articles::outbound::{SystemClock, UuidV7};
use axum::Router;
use axum::body::Body;
use axum::http::{HeaderMap, HeaderValue, Request, StatusCode, request::Builder};
use base64::Engine as _;
use domain::{Actor, NewArticle, Publishing, TenantId};
use hmac::{Hmac, KeyInit, Mac};
use http_body_util::BodyExt as _;
use jsonwebtoken::EncodingKey;
use serde_json::{Value, json};
use sqlx::PgPool;
use tower::ServiceExt as _;
use uuid::Uuid;

pub const TENANT_A: Uuid = Uuid::from_u128(0xA);
pub const TENANT_B: Uuid = Uuid::from_u128(0xB);
pub const PROBLEMS: &str = "https://api.example.com/problems/";
pub const WEBHOOK_KEY: &[u8] = b"test-webhook-key";
const JWT_SECRET: &str = "test-jwt-secret";

/// One database per test, built the way production builds it: the cluster role, then the
/// release step as the owner, then a pool connected as `app_rw`, the role the service runs as.
pub struct Db {
    /// The superuser `#[sqlx::test]` connected as: for setup, and for looking past the policies.
    pub owner: PgPool,
    pub store: PgStore,
}

pub async fn db(owner: PgPool) -> Db {
    db_with(owner, 5).await
}

pub async fn db_with(owner: PgPool, max_connections: u32) -> Db {
    sqlx::raw_sql(include_str!("../../db/dev-roles.sql")).execute(&owner).await.unwrap();
    postgres::run_migrations(&mut owner.acquire().await.unwrap()).await.unwrap(); // forward, from empty
    let options = owner.connect_options();
    let (host, port, name) = (options.get_host(), options.get_port(), options.get_database().unwrap());
    let database = Database {
        url: format!("postgres://app_rw:app_rw@{host}:{port}/{name}").into(),
        max_connections,
        statement_timeout: Duration::from_secs(5),
        idle_in_transaction_timeout: Duration::from_secs(5),
    };
    Db { store: PgStore::connect(&database, Duration::from_secs(4)).await.unwrap(), owner }
}

pub fn publishing(db: &Db) -> Publishing<PgStore> {
    Publishing::new(db.store.clone(), SystemClock, UuidV7)
}

pub struct TestApp {
    pub router: Router,
    pub readiness: Readiness,
    pub openapi: utoipa::openapi::OpenApi,
}

/// The production app factory over the test database (HS256 tokens, 2 s request deadline).
pub fn app(db: &Db) -> TestApp {
    app_with(db, Duration::from_secs(2))
}

pub fn app_with(db: &Db, request_timeout: Duration) -> TestApp {
    build(db, request_timeout, JwtKeys::Hs256 { secret: JWT_SECRET.to_owned().into() })
}

/// The same app, verifying tokens with the key set served at `url`.
pub fn app_with_jwks(db: &Db, url: String) -> TestApp {
    build(db, Duration::from_secs(2), JwtKeys::Jwks { url })
}

fn build(db: &Db, request_timeout: Duration, keys: JwtKeys) -> TestApp {
    let jwt = Jwt { issuer: "https://id.example.com/".into(), audience: "articles".into(), keys };
    let readiness = Readiness::default();
    let (router, openapi) = http::app(Deps {
        publishing: Arc::new(publishing(db)),
        idempotency: Arc::new(db.store.clone()),
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
    let key = EncodingKey::from_secret(JWT_SECRET.as_bytes()).unwrap();
    sign(&jsonwebtoken::Header::default(), &key, tenant, subject, roles)
}

pub fn sign(header: &jsonwebtoken::Header, key: &EncodingKey, tenant: Uuid, subject: &str, roles: &[&str]) -> String {
    let exp = chrono::Utc::now().timestamp() + 300;
    let claims = json!({ "sub": subject, "tid": tenant, "roles": roles, "exp": exp,
        "iss": "https://id.example.com/", "aud": "articles" });
    jsonwebtoken::encode(header, &claims, key).unwrap()
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

## Use cases and adapters on PostgreSQL

The only doubles are event publishers and a clock. The saboteur is the database: a conflicting outbox row makes the append fail.

```rust file=tests/api/postgres.rs
use std::sync::{Arc, Mutex};
use std::time::Duration;

use articles::config::Database;
use articles::outbound::postgres::{PgStore, Relay, RelayConfig};
use articles::outbound::publisher::{EventPublisher, OutboxEvent};
use articles::outbound::{SystemClock, UuidV7};
use chrono::{DateTime, Utc};
use domain::{
    Acquire, ArticleError, ArticlePatch, ArticleRepository, Clock, IdempotencyStore, Moderation, PageRequest, PageSize,
    Publishing, Status, Tx, UnitOfWork,
};
use sqlx::PgPool;
use tokio::task::JoinSet;
use uuid::Uuid;

use crate::support::*;

/// Every article gets the same instant: a keyset that leaned on a timestamp would tie.
struct OneInstant;

impl Clock for OneInstant {
    fn now(&self) -> DateTime<Utc> {
        DateTime::UNIX_EPOCH
    }
}

#[sqlx::test(migrations = false)]
async fn keyset_walk_visits_each_article_once(owner: PgPool) {
    let db = db(owner).await;
    let app = Publishing::new(db.store.clone(), OneInstant, UuidV7);
    let ann = actor(TENANT_A, "ann", &[]);
    let mut newest_first = Vec::new();
    for n in 0..7 {
        newest_first.insert(0, app.create(&ann, input(&format!("a-{n}")), None).await.unwrap().id());
    }
    app.create(&actor(TENANT_B, "zed", &[]), input("theirs"), None).await.unwrap();
    for size in [1, 2, 100] {
        let (mut seen, mut cursor) = (Vec::new(), None);
        loop {
            let page = app.list(&ann, PageRequest { cursor, size: PageSize::new(size).unwrap() }).await.unwrap();
            seen.extend(page.items.iter().map(|a| a.id()));
            cursor = page.next_cursor;
            if cursor.is_none() {
                break;
            }
        }
        assert_eq!(seen, newest_first, "page size {size}");
    }
    // A position is not a permission: another tenant walking from A's cursor still sees only its own rows.
    let first = app.list(&ann, PageRequest { cursor: None, size: PageSize::new(1).unwrap() }).await.unwrap();
    let page = PageRequest { cursor: first.next_cursor, size: PageSize::new(100).unwrap() };
    assert!(app.list(&actor(TENANT_B, "zed", &[]), page).await.unwrap().items.is_empty());
}

#[sqlx::test(migrations = false)]
async fn concurrent_duplicate_creates_have_exactly_one_winner(owner: PgPool) {
    let db = db(owner).await;
    let app = Arc::new(publishing(&db));
    let mut tasks = JoinSet::new();
    for n in 0..8 {
        let app = app.clone();
        tasks.spawn(async move { app.create(&actor(TENANT_A, &format!("u{n}"), &[]), input("same"), None).await });
    }
    let results = tasks.join_all().await;
    assert_eq!(results.iter().filter(|r| r.is_ok()).count(), 1);
    assert!(results.iter().filter_map(|r| r.as_ref().err()).all(|e| matches!(e, ArticleError::SlugTaken)));
    app.create(&actor(TENANT_B, "zed", &[]), input("same"), None).await.expect("a slug is unique per tenant");
}

#[sqlx::test(migrations = false)]
async fn concurrent_publishes_have_one_winner_and_one_event(owner: PgPool) {
    let db = db(owner).await;
    let app = Arc::new(publishing(&db));
    let ann = actor(TENANT_A, "ann", &[]);
    let id = app.create(&ann, input("hello"), None).await.unwrap().id();
    let mut tasks = JoinSet::new();
    for _ in 0..8 {
        let (app, ann) = (app.clone(), ann.clone());
        tasks.spawn(async move { app.publish(&ann, id, None).await });
    }
    let results = tasks.join_all().await;
    let won: Vec<_> = results.iter().filter_map(|r| r.as_ref().ok()).collect();
    assert_eq!((won.len(), won[0].status(), won[0].version()), (1, Status::Published, 2));
    let lost = results.iter().filter_map(|r| r.as_ref().err());
    assert!(lost.into_iter().all(|e| matches!(e, ArticleError::InvalidTransition { needs: Status::Draft, .. })));
    let events: Vec<(Uuid, i32)> =
        sqlx::query_as("SELECT aggregate_id, aggregate_seq FROM app.outbox").fetch_all(&db.owner).await.unwrap();
    assert_eq!(events, [(id.0, 2)], "the event's sequence is the stored version");
}

#[sqlx::test(migrations = false)]
async fn a_write_against_a_stale_version_is_refused(owner: PgPool) {
    let db = db(owner).await;
    let app = publishing(&db);
    let ann = actor(TENANT_A, "ann", &[]);
    let article = app.create(&ann, input("hello"), None).await.unwrap();
    let edited = article.edit(ArticlePatch { title: Some("Edited".into()), body: None }, SystemClock.now()).unwrap();
    // Two writers that both read version 1: the second finds no row to change.
    let mut tx = db.store.begin(&ann).await.unwrap();
    let first = tx.articles().update(&edited, 1).await.unwrap();
    let second = tx.articles().update(&edited, 1).await.unwrap();
    assert_eq!((first.map(|a| a.version()), second.map(|a| a.version())), (Some(2), None));
    tx.commit().await.unwrap();
    // The use case names the lost race by what the client sent.
    let patch = || ArticlePatch { title: Some("Late".into()), body: None };
    let conditional = app.update(&ann, edited.id(), patch(), Some(&[1])).await;
    assert!(matches!(conditional, Err(ArticleError::PreconditionFailed)));
    assert_eq!(app.update(&ann, edited.id(), patch(), Some(&[2])).await.unwrap().version(), 3);
}

#[sqlx::test(migrations = false)]
async fn publish_appends_one_outbox_row_or_rolls_back(owner: PgPool) {
    let db = db(owner).await;
    let app = publishing(&db);
    let ann = actor(TENANT_A, "ann", &[]);
    let first = app.create(&ann, input("one"), None).await.unwrap();
    app.publish(&ann, first.id(), None).await.unwrap();
    let rows: Vec<(Uuid, i32, String)> =
        sqlx::query_as("SELECT aggregate_id, aggregate_seq, event_type FROM app.outbox")
            .fetch_all(&db.owner)
            .await
            .unwrap();
    assert_eq!(rows, [(first.id().0, 2, "article.published".to_owned())]);

    // Saboteur: a row already holding (aggregate_id, 2) makes the outbox insert fail.
    let second = app.create(&ann, input("two"), None).await.unwrap();
    sqlx::query("INSERT INTO app.outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload)
                 VALUES ($1, 'article', $2, 2, 'blocker', 1, '{}')")
        .bind(TENANT_A)
        .bind(second.id().0)
        .execute(&db.owner)
        .await
        .unwrap();
    assert!(app.publish(&ann, second.id(), None).await.is_err());
    let after = app.get(&ann, second.id()).await.unwrap();
    assert_eq!((after.status(), after.version()), (Status::Draft, 1), "the article rolled back with the outbox write");
}

#[sqlx::test(migrations = false)]
async fn another_tenant_can_neither_see_nor_change_an_article(owner: PgPool) {
    let db = db(owner).await;
    let app = publishing(&db);
    let article = app.create(&actor(TENANT_A, "ann", &[]), input("mine"), None).await.unwrap();
    let outsider = actor(TENANT_B, "ann", &["editor", "moderator"]); // same subject, every role, another tenant
    assert!(matches!(app.get(&outsider, article.id()).await, Err(ArticleError::NotFound)));
    assert!(matches!(app.publish(&outsider, article.id(), None).await, Err(ArticleError::NotFound)));
    let ignored = app.archive(&outsider, article.id(), "m1").await.unwrap();
    assert_eq!(ignored, Moderation::Ignored("article not found"));
    let page = app.list(&outsider, PageRequest { cursor: None, size: PageSize::new(100).unwrap() }).await.unwrap();
    assert!(page.items.is_empty());
}

#[sqlx::test(migrations = false)]
async fn row_level_security_holds_when_a_query_forgets_its_tenant(owner: PgPool) {
    let db = db_with(owner, 1).await; // one connection: every statement below shares it
    let count = "SELECT count(*) FROM app.articles"; // no tenant predicate: only the policy filters
    let unset = "SELECT current_setting('app.current_tenant', true)";
    let pool = db.store.pool();
    // A session that never opened a unit of work has no tenant, and sees nothing.
    assert_eq!(sqlx::query_scalar::<_, Option<String>>(unset).fetch_one(pool).await.unwrap(), None);
    assert_eq!(sqlx::query_scalar::<_, i64>(count).fetch_one(pool).await.unwrap(), 0);

    let app = publishing(&db);
    let (ann, zed) = (actor(TENANT_A, "ann", &[]), actor(TENANT_B, "zed", &[]));
    for (who, slug) in [(&ann, "a-1"), (&ann, "a-2"), (&zed, "b-1")] {
        app.create(who, input(slug), None).await.unwrap();
    }
    // Inside A's transaction the policy shows A's rows only, and refuses a row written for B.
    let mut tx = db.store.begin(&ann).await.unwrap();
    assert_eq!(sqlx::query_scalar::<_, i64>(count).fetch_one(tx.connection()).await.unwrap(), 2);
    let planted = sqlx::query(
        "INSERT INTO app.articles (id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at)
         VALUES (uuidv7(), $1, 'ann', 'planted', 'T', '', 'draft', 1, now(), now())",
    );
    let refused = planted.bind(TENANT_B).execute(tx.connection()).await.unwrap_err();
    assert_eq!(refused.as_database_error().and_then(|e| e.code()).as_deref(), Some("42501"));
    drop(tx); // rolled back: the refused insert aborted it

    // The tenant does not outlive its transaction: the same connection, afterwards, sees nothing.
    db.store.begin(&ann).await.unwrap().commit().await.unwrap();
    assert_eq!(sqlx::query_scalar::<_, i64>(count).fetch_one(pool).await.unwrap(), 0);
    // Once set, the setting reads as empty, not NULL: the policy's NULLIF covers both.
    assert_eq!(sqlx::query_scalar::<_, Option<String>>(unset).fetch_one(pool).await.unwrap().as_deref(), Some(""));
    // What the service would see if it connected as the wrong role: every tenant's rows.
    assert_eq!(sqlx::query_scalar::<_, i64>(count).fetch_one(&db.owner).await.unwrap(), 3);
}

#[tokio::test]
async fn the_store_refuses_a_role_that_bypasses_row_level_security() {
    let database = Database {
        url: std::env::var("DATABASE_URL").unwrap().into(), // the cluster's superuser
        max_connections: 1,
        statement_timeout: Duration::from_secs(5),
        idle_in_transaction_timeout: Duration::from_secs(5),
    };
    let refused = PgStore::connect(&database, Duration::from_secs(4)).await.err().expect("a superuser must be refused");
    assert!(refused.to_string().contains("bypasses row-level security"), "{refused:#}");
}

#[sqlx::test(migrations = false)]
async fn moderation_applies_each_message_once(owner: PgPool) {
    let db = db(owner).await;
    let app = publishing(&db);
    let ann = actor(TENANT_A, "ann", &[]);
    let id = app.create(&ann, input("hello"), None).await.unwrap().id();
    let moderator = actor(TENANT_A, "system:moderation", &["moderator"]);
    assert_eq!(app.archive(&moderator, id, "m1").await.unwrap(), Moderation::Ignored("article is not published"));
    app.publish(&ann, id, None).await.unwrap();
    assert_eq!(app.archive(&moderator, id, "m2").await.unwrap(), Moderation::Archived);
    assert_eq!(app.archive(&moderator, id, "m2").await.unwrap(), Moderation::Duplicate);
    assert!(matches!(app.archive(&ann, id, "m3").await, Err(ArticleError::Forbidden)));
    let recorded: i64 = sqlx::query_scalar("SELECT count(*) FROM app.inbox").fetch_one(&db.owner).await.unwrap();
    assert_eq!(recorded, 2, "an ignored verdict is recorded too; a refused caller is not");
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

/// While it publishes, another relay claims the same row: this relay's lease has run out.
struct Overtaken(PgPool);

impl EventPublisher for Overtaken {
    async fn publish(&self, event: &OutboxEvent) -> anyhow::Result<()> {
        sqlx::query("UPDATE app.outbox SET attempts = attempts + 1 WHERE id = $1")
            .bind(event.id)
            .execute(&self.0)
            .await?;
        Ok(())
    }
}

async fn enqueue(pool: &PgPool, aggregate: Uuid, seq: i32) {
    sqlx::query("INSERT INTO app.outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload)
                 VALUES ($1, 'article', $2, $3, 'article.published', 1, '{}')")
        .bind(TENANT_A)
        .bind(aggregate)
        .bind(seq)
        .execute(pool)
        .await
        .unwrap();
}

#[sqlx::test(migrations = false)]
async fn relay_publishes_each_aggregate_in_order_and_dead_letters(owner: PgPool) {
    let db = db(owner).await;
    let (a, b, c, d) = (Uuid::now_v7(), Uuid::now_v7(), Uuid::now_v7(), Uuid::now_v7());
    for (aggregate, seq) in [(a, 1), (a, 2), (a, 3), (b, 1)] {
        enqueue(&db.owner, aggregate, seq).await;
    }
    let recorder = Recorder::default();
    let relay = Relay::new(db.store.clone(), recorder.clone(), RelayConfig::default());
    let claimed: Vec<usize> =
        [relay.run_once().await.unwrap(), relay.run_once().await.unwrap(), relay.run_once().await.unwrap()].into();
    assert_eq!(claimed, [2, 1, 1], "only each aggregate's head is claimable");
    let published = recorder.published.lock().unwrap().clone();
    let sequence =
        |aggregate| published.iter().filter(|(id, _)| *id == aggregate).map(|(_, seq)| *seq).collect::<Vec<_>>();
    assert_eq!((sequence(a), sequence(b)), (vec![1, 2, 3], vec![1])); // across aggregates: any order

    for seq in [1, 2] {
        enqueue(&db.owner, c, seq).await;
    }
    let config = RelayConfig { max_attempts: 2, backoff_base: Duration::ZERO, ..RelayConfig::default() };
    let failing = Relay::new(db.store.clone(), Recorder { broker_down: true, ..Recorder::default() }, config);
    failing.run_once().await.unwrap();
    failing.run_once().await.unwrap();
    let state = "SELECT attempts, dead_lettered_at IS NOT NULL, published_at IS NOT NULL FROM app.outbox
                 WHERE aggregate_id = $1 AND aggregate_seq = 1";
    let dead: (i32, bool, bool) = sqlx::query_as(state).bind(c).fetch_one(&db.owner).await.unwrap();
    assert_eq!(dead, (2, true, false));
    relay.run_once().await.unwrap(); // the dead letter no longer blocks its aggregate
    assert_eq!(recorder.published.lock().unwrap().last(), Some(&(c, 2)));

    // The fence: an outcome is written only under the claim that produced it.
    enqueue(&db.owner, d, 1).await;
    Relay::new(db.store.clone(), Overtaken(db.owner.clone()), RelayConfig::default()).run_once().await.unwrap();
    let overtaken: (i32, bool, bool) = sqlx::query_as(state).bind(d).fetch_one(&db.owner).await.unwrap();
    assert_eq!(overtaken, (2, false, false), "the newer claim, not this relay, decides the row");
}

#[sqlx::test(migrations = false)]
async fn a_relay_pass_claims_at_most_its_batch_whatever_the_plan(owner: PgPool) {
    let db = db_with(owner, 1).await; // one connection: the planner settings below reach the relay
    sqlx::query("INSERT INTO app.outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload)
                 SELECT $1, 'article', uuidv7(), 1, 'article.published', 1, '{}' FROM generate_series(1, 200)")
        .bind(TENANT_A)
        .execute(&db.owner)
        .await
        .unwrap();
    // The plan that runs a claim subquery again for every outer row.
    let rescan = "SET enable_hashagg = off; SET enable_hashjoin = off; SET enable_mergejoin = off;
                  SET enable_sort = off; SET enable_material = off";
    sqlx::raw_sql(rescan).execute(db.store.pool()).await.unwrap();
    let relay = Relay::new(db.store.clone(), Recorder::default(), RelayConfig { batch: 5, ..RelayConfig::default() });
    assert_eq!(relay.run_once().await.unwrap(), 5);
}

#[sqlx::test(migrations = false)]
async fn an_idempotency_key_has_one_winner_and_a_live_lease_survives_the_purge(owner: PgPool) {
    let db = db(owner).await;
    let mut tasks = JoinSet::new();
    for _ in 0..10 {
        let store = db.store.clone();
        tasks.spawn(async move { store.acquire("tenant:ann", "k", "hash").await.unwrap() });
    }
    let outcomes = tasks.join_all().await;
    assert_eq!(outcomes.iter().filter(|o| matches!(o, Acquire::Execute(_))).count(), 1);
    assert!(outcomes.iter().all(|o| matches!(o, Acquire::Execute(_) | Acquire::InFlight)));

    // Lease and TTL both expired: a retry takes the key over, and the purge must spare it.
    sqlx::query("UPDATE app.idempotency_keys SET locked_until = now() - interval '1 second', expires_at = now() - interval '1 second'")
        .execute(&db.owner)
        .await
        .unwrap();
    assert!(matches!(db.store.acquire("tenant:ann", "k", "hash").await.unwrap(), Acquire::Execute(_)));
    assert_eq!(db.store.purge_expired().await.unwrap(), 0);
}
```

## HTTP tests

```rust file=tests/api/http.rs
use std::sync::{Arc, atomic::AtomicBool, atomic::Ordering::SeqCst};
use std::time::Duration;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::{Json, Router, routing::get};
use base64::Engine as _;
use jsonwebtoken::{Algorithm, EncodingKey};
use serde_json::{Value, json};
use sqlx::PgPool;

use crate::support::*;

async fn create(app: &TestApp, token: &str, slug: &str) -> Reply {
    send(app, Request::post("/v1/articles").bearer(token).json_body(&json!({ "slug": slug, "title": "Hello" }))).await
}

#[sqlx::test(migrations = false)]
async fn every_error_is_a_problem_document(owner: PgPool) {
    let app = app(&db(owner).await);
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
    let nul_subject = token(TENANT_A, "ann\0", &[]); // signed, but its subject could not be stored
    problem(Request::get(articles).bearer(&nul_subject).empty(), 401, "unauthenticated", articles).await;
    let publish = format!("{path}/publish");
    problem(Request::post(&publish).bearer(&bob).empty(), 403, "forbidden", &publish).await;
    let outsider = token(TENANT_B, "ann", &["editor"]); // same subject and an editor, another tenant
    problem(Request::get(&path).bearer(&outsider).empty(), 404, "not-found", &path).await;
    // A precondition is judged after the 404: it must not reveal that the article exists.
    let stale = Request::patch(&path).bearer(&outsider).header("if-match", "\"9\"").json_body(&json!({}));
    problem(stale, 404, "not-found", &path).await;
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
    problem(create_request(&ann, "hello"), 409, "already-exists", articles).await;

    let invalid =
        problem(post().json_body(&json!({ "slug": "Bad Slug", "title": " " })), 422, "validation-failed", articles);
    let invalid = invalid.await.body["errors"].clone();
    assert_eq!((invalid[0]["pointer"].as_str(), invalid[1]["pointer"].as_str()), (Some("#/slug"), Some("#/title")));
    assert_eq!(invalid[1]["code"], "required");
    let mass_assignment = json!({ "slug": "a", "title": "T", "tenant_id": TENANT_B });
    let unknown = problem(post().json_body(&mass_assignment), 422, "validation-failed", articles).await;
    assert_eq!(
        (&unknown.body["errors"][0]["pointer"], &unknown.body["errors"][0]["code"]),
        (&json!("#/tenant_id"), &json!("unknown_field"))
    );
    for (query, parameter) in [("limit=0", "limit"), ("limit=abc", "limit"), ("sort=title", "sort")] {
        let req = Request::get(format!("/v1/articles?{query}")).bearer(&ann).empty();
        let reply = problem(req, 422, "validation-failed", articles).await;
        assert_eq!(reply.body["errors"][0]["parameter"], parameter, "{query}");
    }
}

fn create_request(token: &str, slug: &str) -> Request<Body> {
    Request::post("/v1/articles").bearer(token).json_body(&json!({ "slug": slug, "title": "Hello" }))
}

/// An Ed25519 key made once with `openssl genpkey -algorithm ed25519 -outform DER` (PKCS#8), and
/// its public half as the JWK's `x`.
const ED25519_PKCS8: &str = "MC4CAQAwBQYDK2VwBCIEIBiRcOIxYUpobWOX/KhlvZIwfCqskoMDLB7sNfzwFpIO";
const ED25519_X: &str = "xxy1guxzeuR0496z4RJ9lynVQxrfEVYMxAPGiTOoYB4";

/// A key set endpoint on a local port that answers 503 while `up` is false.
async fn jwks_endpoint(up: Arc<AtomicBool>) -> String {
    let set = json!({ "keys": [{ "kty": "OKP", "crv": "Ed25519", "alg": "EdDSA", "kid": "k1", "x": ED25519_X }] });
    let serve = move || {
        let reply = if up.load(SeqCst) { Ok(Json(set.clone())) } else { Err(StatusCode::SERVICE_UNAVAILABLE) };
        async move { reply }
    };
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/jwks", listener.local_addr().unwrap());
    tokio::spawn(axum::serve(listener, Router::new().route("/jwks", get(serve))).into_future());
    url
}

#[sqlx::test(migrations = false)]
async fn jwks_keys_are_cached_and_an_unreachable_source_is_a_503(owner: PgPool) {
    let db = db(owner).await;
    let up = Arc::new(AtomicBool::new(false));
    let url = jwks_endpoint(up.clone()).await;
    let der = base64::engine::general_purpose::STANDARD.decode(ED25519_PKCS8).unwrap();
    let signed = |kid: &str| {
        let mut header = jsonwebtoken::Header::new(Algorithm::EdDSA);
        header.kid = Some(kid.into());
        sign(&header, &EncodingKey::from_ed_der(&der), TENANT_A, "ann", &[])
    };
    let list = |token: &str| Request::get("/v1/articles").bearer(token).empty();
    // No key was ever fetched: the service's dependency failed, not the caller's token.
    let cold = send(&app_with_jwks(&db, url.clone()), list(&signed("k1"))).await;
    cold.assert_problem(503, "unavailable", "/v1/articles");
    assert_eq!(cold.header("retry-after"), "1");
    up.store(true, SeqCst);
    let app = app_with_jwks(&db, url);
    assert_eq!(send(&app, list(&signed("k1"))).await.status.as_u16(), 200);
    send(&app, list(&signed("k2"))).await.assert_problem(401, "unauthenticated", "/v1/articles");
    up.store(false, SeqCst);
    assert_eq!(send(&app, list(&signed("k1"))).await.status.as_u16(), 200, "cached keys outlive the source");
}

#[sqlx::test(migrations = false)]
async fn request_ids_and_the_cors_preflight(owner: PgPool) {
    let app = app(&db(owner).await);
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

#[sqlx::test(migrations = false)]
async fn create_read_and_conditional_update(owner: PgPool) {
    let app = app(&db(owner).await);
    let (ann, editor) = (token(TENANT_A, "ann", &[]), token(TENANT_A, "ed", &["editor"]));
    let created = create(&app, &ann, "hello").await;
    assert_eq!((created.status.as_u16(), created.header("etag")), (201, "\"1\""));
    let location = created.header("location").to_owned();
    let read = send(&app, Request::get(&location).bearer(&ann).empty()).await;
    assert_eq!(read.body, created.body, "same representation, microseconds included");
    let patch = |who: &str, if_match: &str, body: Value| {
        Request::patch(&location).bearer(who).header("if-match", if_match).json_body(&body)
    };
    let patched = send(&app, patch(&ann, "\"1\"", json!({ "title": "Hi", "body": null }))).await;
    assert_eq!((patched.header("etag"), &patched.body["data"]["title"]), ("\"2\"", &json!("Hi")));
    // Stale, weak and malformed tags never match; a list matches if one of its strong tags does.
    for stale in ["\"1\"", "W/\"2\"", "2", "\"+2\""] {
        let reply = send(&app, patch(&ann, stale, json!({ "title": "Late" }))).await;
        reply.assert_problem(412, "precondition-failed", &location);
    }
    let by_editor = send(&app, patch(&editor, "\"1\", \"2\"", json!({ "title": "Edited" }))).await;
    assert_eq!((by_editor.status.as_u16(), by_editor.header("etag")), (200, "\"3\""));
    let null_title = send(&app, patch(&ann, "*", json!({ "title": null }))).await;
    null_title.assert_problem(422, "validation-failed", &location);
    assert_eq!(null_title.body["errors"][0]["pointer"], "#/title");
}

#[sqlx::test(migrations = false)]
async fn list_pages_newest_first_with_a_clamped_limit(owner: PgPool) {
    let app = app(&db(owner).await);
    let ann = token(TENANT_A, "ann", &[]);
    for slug in ["one", "two", "three"] {
        create(&app, &ann, slug).await;
    }
    create(&app, &token(TENANT_B, "zed", &[]), "theirs").await;
    let first = send(&app, Request::get("/v1/articles?limit=2").bearer(&ann).empty()).await;
    assert_eq!(
        (first.body["data"][0]["slug"].as_str(), first.body["meta"]["has_more"].as_bool()),
        (Some("three"), Some(true))
    );
    let cursor = first.body["meta"]["next_cursor"].as_str().unwrap();
    let last = send(&app, Request::get(format!("/v1/articles?limit=2&cursor={cursor}")).bearer(&ann).empty()).await;
    assert_eq!(last.body["data"].as_array().map(Vec::len), Some(1), "another tenant's article is never listed");
    assert_eq!(last.body["meta"], json!({ "limit": 2, "next_cursor": null, "has_more": false }));
    let clamped = send(&app, Request::get("/v1/articles?limit=500").bearer(&ann).empty()).await;
    assert_eq!(clamped.body["meta"]["limit"], 100);
}

#[sqlx::test(migrations = false)]
async fn idempotency_keys_replay_reject_mismatches_and_report_in_flight(owner: PgPool) {
    let db = db(owner).await;
    let app = app(&db);
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
        "UPDATE app.idempotency_keys SET completed_at = NULL, locked_until = now() + interval '1 minute' WHERE key = 'k2'",
    )
    .execute(&db.owner)
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

    // A 4xx decided by the body is stored and replayed; one decided by a header outside the hash
    // is not, so the corrected retry runs.
    let taken = send(&app, post("k4", json!({ "slug": "a", "title": "Again" }))).await;
    taken.assert_problem(409, "already-exists", "/v1/articles");
    let replayed = send(&app, post("k4", json!({ "slug": "a", "title": "Again" }))).await;
    assert_eq!((replayed.status.as_u16(), replayed.header("idempotent-replayed")), (409, "true"));
    let wrong_type = Request::post("/v1/articles").bearer(&ann).header("idempotency-key", "k5");
    let body = json!({ "slug": "d", "title": "D" }).to_string();
    let wrong_type = wrong_type.header("content-type", "text/plain").body(Body::from(body)).unwrap();
    send(&app, wrong_type).await.assert_problem(415, "unsupported-media-type", "/v1/articles");
    for _ in 0..50 {
        let held = sqlx::query("SELECT 1 FROM app.idempotency_keys WHERE key = 'k5'").fetch_optional(&db.owner);
        if held.await.unwrap().is_none() {
            break; // released by the guard's spawned task
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    assert_eq!(send(&app, post("k5", json!({ "slug": "d", "title": "D" }))).await.status.as_u16(), 201);
}

#[sqlx::test(migrations = false)]
async fn moderation_webhook_verifies_dedups_and_acknowledges(owner: PgPool) {
    let app = app(&db(owner).await);
    let ann = token(TENANT_A, "ann", &[]);
    let location = create(&app, &ann, "hello").await.header("location").to_owned();
    send(&app, Request::post(format!("{location}/publish")).bearer(&ann).empty()).await;
    let id = location.rsplit('/').next().unwrap();
    let verdict = json!({ "tenant_id": TENANT_A, "article_id": id, "verdict": "rejected" });
    let now = chrono::Utc::now().timestamp();
    let path = "/internal/webhooks/moderation";
    send(&app, webhook("msg_1", &verdict, now, b"forged")).await.assert_problem(401, "unauthenticated", path);
    send(&app, webhook("msg_1", &verdict, now - 301, WEBHOOK_KEY)).await.assert_problem(401, "unauthenticated", path);
    let oversized =
        Request::post(path).header("content-type", "application/json").body(Body::from(vec![b'x'; 70 * 1024]));
    send(&app, oversized.unwrap()).await.assert_problem(413, "payload-too-large", path);
    // Signed for another tenant: the transaction is scoped to that tenant, so nothing is found.
    let foreign = json!({ "tenant_id": TENANT_B, "article_id": id, "verdict": "rejected" });
    assert_eq!(send(&app, webhook("msg_0", &foreign, now, WEBHOOK_KEY)).await.status.as_u16(), 204);
    let untouched = send(&app, Request::get(&location).bearer(&ann).empty()).await;
    assert_eq!(untouched.body["data"]["status"], "published");
    for _ in 0..2 {
        assert_eq!(send(&app, webhook("msg_1", &verdict, now, WEBHOOK_KEY)).await.status.as_u16(), 204);
    }
    let article = send(&app, Request::get(&location).bearer(&ann).empty()).await;
    assert_eq!((article.body["data"]["status"].as_str(), article.header("etag")), (Some("archived"), "\"3\""));
}

#[sqlx::test(migrations = false)]
async fn readiness_is_latched_and_drops_while_draining(owner: PgPool) {
    let app = app(&db(owner).await);
    let ready = || send(&app, Request::get("/ready").empty());
    ready().await.assert_problem(503, "unavailable", "/ready");
    app.readiness.mark_ready();
    assert_eq!(ready().await.status.as_u16(), 200);
    app.readiness.start_draining();
    ready().await.assert_problem(503, "unavailable", "/ready");
    assert_eq!(send(&app, Request::get("/health").empty()).await.status.as_u16(), 200);
}

#[sqlx::test(migrations = false)]
async fn a_deadline_cancels_the_handler_rolls_back_and_frees_the_key(owner: PgPool) {
    let db = db(owner).await;
    let app = app_with(&db, Duration::from_millis(300));
    let ann = token(TENANT_A, "ann", &[]);
    let location = create(&app, &ann, "hello").await.header("location").to_owned();
    let publish = || {
        let req = Request::post(format!("{location}/publish")).header("origin", "https://app.example.com");
        req.header("idempotency-key", "k1").bearer(&ann).empty()
    };
    // Another transaction holds the row lock that the guarded transition needs.
    let mut blocker = db.owner.begin().await.unwrap();
    sqlx::query("SELECT 1 FROM app.articles FOR UPDATE").execute(&mut *blocker).await.unwrap();
    let timed_out = send(&app, publish()).await;
    timed_out.assert_problem(503, "unavailable", &format!("{location}/publish"));
    assert_eq!(timed_out.header("access-control-allow-origin"), "https://app.example.com");
    blocker.rollback().await.unwrap();
    // The dropped handler committed nothing; its guard releases the key from a spawned task.
    for _ in 0..50 {
        let key = sqlx::query("SELECT 1 FROM app.idempotency_keys").fetch_optional(&db.owner).await.unwrap();
        if key.is_none() {
            break;
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    let retried = send(&app, publish()).await;
    assert_eq!((retried.status.as_u16(), retried.header("etag")), (200, "\"2\""));
}

#[sqlx::test(migrations = false)]
async fn openapi_document_matches_the_committed_snapshot(owner: PgPool) {
    let generated = app(&db(owner).await).openapi.to_pretty_json().unwrap();
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
