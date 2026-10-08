# Axum examples — domain

The `domain` crate of the publishing slice: model, errors, ports, use cases and their tests. Its `Cargo.toml` is the hexagonal boundary: the compiler rejects any import of a crate not listed there, and `scripts/check-boundary.sh` (examples-bootstrap.md) rejects adding one. Judgment behind the code: `guide.md`.

## Contents

1. [Crate](#crate)
2. [Model](#model)
3. [Errors](#errors)
4. [Ports](#ports)
5. [Use cases](#use-cases)
6. [Use-case tests](#use-case-tests)

## Crate

Five dependencies: no web framework, driver, serializer or telemetry SDK. `tracing` stays, because in Rust the facade is the tracer port.

```toml file=domain/Cargo.toml
# Allowed dependencies are the boundary: scripts/check-boundary.sh fails on any other.
[package]
name = "domain"
version = "0.1.0"
edition.workspace = true
rust-version.workspace = true
publish = false

[dependencies]
anyhow.workspace = true
chrono.workspace = true
thiserror.workspace = true
tracing.workspace = true
uuid.workspace = true

[dev-dependencies]
tokio.workspace = true

[lints]
workspace = true
```

```rust file=domain/src/lib.rs
//! Publishing context. No web framework, driver or telemetry SDK: `tracing` is the one facade.
mod error;
mod model;
mod ports;
mod use_cases;

pub use error::*;
pub use model::*;
pub use ports::*;
pub use use_cases::*;
```

## Model

Value objects with private fields, transitions as methods (`publish`, `archive`; no status setter), all violations reported at once, and a trusted `rehydrate` that never re-validates stored rows. Time arrives as a parameter, never from the clock.

```rust file=domain/src/model.rs
use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::error::{ArticleError, Violation};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ArticleId(pub Uuid);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TenantId(pub Uuid);

/// Who is acting; built by an inbound adapter and passed to every use case.
#[derive(Clone, Debug)]
pub struct Actor {
    pub tenant_id: TenantId,
    pub subject: String,
    pub roles: Vec<String>,
}

impl Actor {
    pub fn has_role(&self, role: &str) -> bool {
        self.roles.iter().any(|r| r == role)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Status {
    Draft,
    Published,
    Archived,
}

impl Status {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Draft => "draft",
            Self::Published => "published",
            Self::Archived => "archived",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        [Self::Draft, Self::Published, Self::Archived].into_iter().find(|v| v.as_str() == s)
    }
}

// Value objects: a value that exists is valid.
#[derive(Clone, Debug)]
struct Slug(String);
#[derive(Clone, Debug)]
struct Title(String);
#[derive(Clone, Debug)]
struct Body(String);

impl Slug {
    fn parse(raw: &str) -> Result<Self, Violation> {
        let kebab =
            raw.split('-').all(|p| !p.is_empty() && p.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit()));
        match raw.chars().count() {
            0 => Err(Violation::new("slug", "required", "must not be empty")),
            101.. => Err(Violation::new("slug", "too_long", "must be at most 100 characters")),
            _ if !kebab => Err(Violation::new("slug", "invalid_format", "must be lowercase kebab-case")),
            _ => Ok(Self(raw.to_owned())),
        }
    }
}

impl Title {
    fn parse(raw: &str) -> Result<Self, Violation> {
        match raw.trim().chars().count() {
            0 => Err(Violation::new("title", "required", "must not be blank")),
            201.. => Err(Violation::new("title", "too_long", "must be at most 200 characters")),
            _ => Ok(Self(raw.trim().to_owned())),
        }
    }
}

impl Body {
    fn parse(raw: &str) -> Result<Self, Violation> {
        match raw.chars().count() {
            20_001.. => Err(Violation::new("body", "too_long", "must be at most 20000 characters")),
            _ => Ok(Self(raw.to_owned())),
        }
    }
}

/// Raw create input; `Article::create` reports every violation at once.
pub struct NewArticle {
    pub slug: String,
    pub title: String,
    pub body: String,
}

/// JSON Merge Patch of the editable fields: `None` leaves a field unchanged.
pub struct ArticlePatch {
    pub title: Option<String>,
    pub body: Option<String>,
}

/// A stored row: trusted, so a rule tightened later cannot break reading old rows.
pub struct ArticleRecord {
    pub id: Uuid,
    pub tenant_id: Uuid,
    pub author_id: String,
    pub slug: String,
    pub title: String,
    pub body: String,
    pub status: Status,
    pub version: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub published_at: Option<DateTime<Utc>>,
}

#[derive(Clone, Debug)]
pub struct Article {
    id: ArticleId,
    tenant_id: TenantId,
    author_id: String,
    slug: Slug,
    title: Title,
    body: Body,
    status: Status,
    version: i32,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    published_at: Option<DateTime<Utc>>,
}

/// Domain events; the outbox adapter serializes them (no serde here).
#[derive(Clone, Debug)]
pub enum ArticleEvent {
    Published { article_id: ArticleId, tenant_id: TenantId, slug: String, version: i32, published_at: DateTime<Utc> },
}

impl Article {
    pub fn create(id: ArticleId, actor: &Actor, input: &NewArticle, now: DateTime<Utc>) -> Result<Self, ArticleError> {
        match (Slug::parse(&input.slug), Title::parse(&input.title), Body::parse(&input.body)) {
            (Ok(slug), Ok(title), Ok(body)) => Ok(Self {
                id,
                tenant_id: actor.tenant_id,
                author_id: actor.subject.clone(),
                slug,
                title,
                body,
                status: Status::Draft,
                version: 1,
                created_at: now,
                updated_at: now,
                published_at: None,
            }),
            (s, t, b) => Err(ArticleError::Invalid([s.err(), t.err(), b.err()].into_iter().flatten().collect())),
        }
    }

    pub fn rehydrate(r: ArticleRecord) -> Self {
        Self {
            id: ArticleId(r.id),
            tenant_id: TenantId(r.tenant_id),
            author_id: r.author_id,
            slug: Slug(r.slug),
            title: Title(r.title),
            body: Body(r.body),
            status: r.status,
            version: r.version,
            created_at: r.created_at,
            updated_at: r.updated_at,
            published_at: r.published_at,
        }
    }

    /// The write rule: the author, or an editor.
    pub fn editable_by(&self, actor: &Actor) -> bool {
        self.author_id == actor.subject || actor.has_role("editor")
    }

    pub fn edit(&mut self, patch: ArticlePatch, now: DateTime<Utc>) -> Result<(), ArticleError> {
        match (patch.title.as_deref().map(Title::parse).transpose(), patch.body.as_deref().map(Body::parse).transpose())
        {
            (Ok(title), Ok(body)) => {
                self.title = title.unwrap_or_else(|| self.title.clone());
                self.body = body.unwrap_or_else(|| self.body.clone());
                self.touch(now);
                Ok(())
            }
            (t, b) => Err(ArticleError::Invalid([t.err(), b.err()].into_iter().flatten().collect())),
        }
    }

    pub fn publish(&mut self, now: DateTime<Utc>) -> Result<ArticleEvent, ArticleError> {
        self.transition(Status::Draft, Status::Published, "publish", now)?;
        self.published_at = Some(now);
        let (article_id, tenant_id, slug, version) = (self.id, self.tenant_id, self.slug.0.clone(), self.version);
        Ok(ArticleEvent::Published { article_id, tenant_id, slug, version, published_at: now })
    }

    pub fn archive(&mut self, now: DateTime<Utc>) -> Result<(), ArticleError> {
        self.transition(Status::Published, Status::Archived, "archive", now)
    }

    fn transition(
        &mut self,
        from: Status,
        to: Status,
        action: &'static str,
        now: DateTime<Utc>,
    ) -> Result<(), ArticleError> {
        if self.status != from {
            return Err(ArticleError::InvalidTransition { from: self.status, action });
        }
        self.status = to;
        self.touch(now);
        Ok(())
    }

    fn touch(&mut self, now: DateTime<Utc>) {
        self.version += 1;
        self.updated_at = now;
    }

    pub fn id(&self) -> ArticleId {
        self.id
    }
    pub fn tenant_id(&self) -> TenantId {
        self.tenant_id
    }
    pub fn author_id(&self) -> &str {
        &self.author_id
    }
    pub fn slug(&self) -> &str {
        &self.slug.0
    }
    pub fn title(&self) -> &str {
        &self.title.0
    }
    pub fn body(&self) -> &str {
        &self.body.0
    }
    pub fn status(&self) -> Status {
        self.status
    }
    pub fn version(&self) -> i32 {
        self.version
    }
    pub fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }
    pub fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
    pub fn published_at(&self) -> Option<DateTime<Utc>> {
        self.published_at
    }
}

/// 1..=100: the port's own bound, whatever a caller asks for.
#[derive(Clone, Copy, Debug)]
pub struct PageSize(u8);

impl PageSize {
    pub const MAX: u8 = 100;

    pub fn new(n: u8) -> Option<Self> {
        (1..=Self::MAX).contains(&n).then_some(Self(n))
    }

    pub fn get(self) -> u8 {
        self.0
    }
}

/// Newest first, strictly older than `after`.
pub struct PageRequest {
    pub after: Option<ArticleId>,
    pub size: PageSize,
}

pub struct Page<T> {
    pub items: Vec<T>,
    pub has_more: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    const T0: DateTime<Utc> = DateTime::UNIX_EPOCH;

    fn draft(slug: &str, title: &str) -> Result<Article, ArticleError> {
        let actor = Actor { tenant_id: TenantId(Uuid::nil()), subject: "ann".into(), roles: vec![] };
        let input = NewArticle { slug: slug.into(), title: title.into(), body: String::new() };
        Article::create(ArticleId(Uuid::nil()), &actor, &input, T0)
    }

    #[test]
    fn create_validates_every_field() {
        assert_eq!(draft("hello-2026", "  Hello ").unwrap().title(), "Hello");
        let Err(ArticleError::Invalid(v)) = draft("Not Kebab", " ") else { panic!("expected violations") };
        assert_eq!(
            v.iter().map(|v| (v.field, v.code)).collect::<Vec<_>>(),
            [("slug", "invalid_format"), ("title", "required")]
        );
        for slug in ["-a", "a-", "a--b", "a_b", "é"] {
            assert!(draft(slug, "T").is_err(), "{slug}");
        }
        assert!(draft(&"a".repeat(101), "T").is_err() && draft("a", &"t".repeat(201)).is_err());
    }

    #[test]
    fn only_draft_to_published_to_archived() {
        let mut a = draft("a", "T").unwrap();
        assert!(matches!(a.archive(T0), Err(ArticleError::InvalidTransition { from: Status::Draft, .. })));
        let ArticleEvent::Published { version, .. } = a.publish(T0).unwrap();
        assert_eq!((a.status(), a.version(), version, a.published_at()), (Status::Published, 2, 2, Some(T0)));
        assert!(a.publish(T0).is_err());
        a.archive(T0).unwrap();
        assert_eq!((a.status(), a.version()), (Status::Archived, 3));
    }

    #[test]
    fn rehydration_does_not_revalidate() {
        let a = Article::rehydrate(ArticleRecord {
            id: Uuid::nil(),
            tenant_id: Uuid::nil(),
            author_id: "ann".into(),
            slug: "Legacy_Slug".into(),
            title: "t".repeat(300),
            body: String::new(),
            status: Status::Published,
            version: 7,
            created_at: T0,
            updated_at: T0,
            published_at: Some(T0),
        });
        assert_eq!((a.slug(), a.title().len()), ("Legacy_Slug", 300));
    }
}
```

## Errors

A closed set of outcomes. `From<anyhow::Error>` sorts adapter failures into `Unavailable` (retryable, 503) and `Unknown` (500) by the `Unavailable` context the adapter attaches.

```rust file=domain/src/error.rs
use crate::Status;

/// One invalid input field; `code` is stable for clients.
#[derive(Clone, Debug)]
pub struct Violation {
    pub field: &'static str,
    pub code: &'static str,
    pub detail: &'static str,
}

impl Violation {
    pub fn new(field: &'static str, code: &'static str, detail: &'static str) -> Self {
        Self { field, code, detail }
    }
}

/// Context an adapter attaches to a failure a retry can fix (pool timeout, lost connection,
/// statement timeout, serialization failure).
#[derive(Debug, thiserror::Error)]
#[error("dependency unavailable")]
pub struct Unavailable;

#[derive(Debug, thiserror::Error)]
pub enum ArticleError {
    #[error("article not found")]
    NotFound,
    #[error("not allowed to change this article")]
    Forbidden,
    #[error("{} invalid field(s)", .0.len())]
    Invalid(Vec<Violation>),
    #[error("an article with this slug already exists")]
    SlugTaken,
    #[error("cannot {action} an article in status '{}'", from.as_str())]
    InvalidTransition { from: Status, action: &'static str },
    #[error("the article changed concurrently; re-read and retry")]
    VersionConflict,
    #[error("the article is at version {current}")]
    PreconditionFailed { current: i32 },
    #[error("dependency unavailable")]
    Unavailable(#[source] anyhow::Error),
    #[error(transparent)]
    Unknown(anyhow::Error),
}

impl From<anyhow::Error> for ArticleError {
    fn from(e: anyhow::Error) -> Self {
        if e.is::<Unavailable>() { Self::Unavailable(e) } else { Self::Unknown(e) }
    }
}
```

## Ports

`UnitOfWork` names the transaction type the adapter chooses; every other persistence port takes `&mut Self::Tx`, so one adapter type implements them all and a command's writes share one transaction. No `Clone` supertrait: it would make the traits non-dyn-compatible, and `Arc` shares them anyway.

```rust file=domain/src/ports.rs
use std::future::Future;

use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::{Article, ArticleError, ArticleEvent, ArticleId, Page, PageRequest, Status, TenantId};

pub trait Clock: Send + Sync + 'static {
    fn now(&self) -> DateTime<Utc>;
}

pub trait IdGenerator: Send + Sync + 'static {
    fn new_id(&self) -> Uuid;
}

/// The adapter names `Tx`; dropping it without `commit` rolls back.
pub trait UnitOfWork: Send + Sync + 'static {
    type Tx: Send;
    fn begin(&self) -> impl Future<Output = anyhow::Result<Self::Tx>> + Send;
    fn commit(&self, tx: Self::Tx) -> impl Future<Output = anyhow::Result<()>> + Send;
}

/// Every query filters by tenant: a foreign article reads as missing.
pub trait ArticleRepository: UnitOfWork {
    fn insert(&self, tx: &mut Self::Tx, a: &Article) -> impl Future<Output = Result<(), ArticleError>> + Send;
    fn find(&self, tenant: TenantId, id: ArticleId) -> impl Future<Output = anyhow::Result<Option<Article>>> + Send;
    /// Locks the row until the transaction ends.
    fn find_for_update(
        &self,
        tx: &mut Self::Tx,
        tenant: TenantId,
        id: ArticleId,
    ) -> impl Future<Output = anyhow::Result<Option<Article>>> + Send;
    fn list(&self, tenant: TenantId, page: PageRequest) -> impl Future<Output = anyhow::Result<Page<Article>>> + Send;
    /// Conditional on the row still being at `version` and `status`, else `VersionConflict`.
    fn save(
        &self,
        tx: &mut Self::Tx,
        a: &Article,
        version: i32,
        status: Status,
    ) -> impl Future<Output = Result<(), ArticleError>> + Send;
}

pub trait Outbox: UnitOfWork {
    fn append(&self, tx: &mut Self::Tx, event: &ArticleEvent) -> impl Future<Output = anyhow::Result<()>> + Send;
}

pub trait Inbox: UnitOfWork {
    /// `false` if the message was already recorded.
    fn record(&self, tx: &mut Self::Tx, consumer: &str, id: &str) -> impl Future<Output = anyhow::Result<bool>> + Send;
}

#[derive(Clone, Debug)]
pub struct StoredResponse {
    pub status: u16,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
}

#[derive(Clone, Debug)]
pub struct Lease {
    pub scope: String,
    pub key: String,
    pub token: Uuid,
}

pub enum Acquire {
    Execute(Lease),
    Replay(StoredResponse),
    Mismatch,
    InFlight,
}

pub trait IdempotencyStore: UnitOfWork {
    fn acquire(&self, scope: &str, key: &str, hash: &str) -> impl Future<Output = anyhow::Result<Acquire>> + Send;
    /// Fails, rolling the command back, if the lease was lost.
    fn complete(
        &self,
        tx: &mut Self::Tx,
        lease: &Lease,
        response: &StoredResponse,
    ) -> impl Future<Output = anyhow::Result<()>> + Send;
    fn release(&self, lease: &Lease) -> impl Future<Output = anyhow::Result<()>> + Send;
    fn purge_expired(&self) -> impl Future<Output = anyhow::Result<u64>> + Send;
}

/// The use case stores `render(&output)` under the lease in its own transaction.
pub struct Idempotency<'a, T> {
    pub lease: &'a Lease,
    pub render: fn(&T) -> StoredResponse,
}
```

## Use cases

`Articles` is the driving port the HTTP and webhook adapters depend on. Each command begins, writes and commits through the ports; `publish` holds the row lock, writes the guarded transition and the outbox row, and stores the idempotent response, all in one transaction.

```rust file=domain/src/use_cases.rs
use std::future::Future;

use crate::{
    Actor, Article, ArticleError, ArticleId, ArticlePatch, ArticleRepository, Clock, IdGenerator, Idempotency,
    IdempotencyStore, Inbox, NewArticle, Outbox, Page, PageRequest, Status,
};

#[derive(Debug, PartialEq, Eq)]
pub enum Moderation {
    Archived,
    Duplicate,
    Ignored(&'static str),
}

/// The driving port.
pub trait Articles: Send + Sync + 'static {
    fn create(
        &self,
        actor: &Actor,
        input: NewArticle,
        idem: Option<Idempotency<'_, Article>>,
    ) -> impl Future<Output = Result<Article, ArticleError>> + Send;
    fn get(&self, actor: &Actor, id: ArticleId) -> impl Future<Output = Result<Article, ArticleError>> + Send;
    fn list(
        &self,
        actor: &Actor,
        page: PageRequest,
    ) -> impl Future<Output = Result<Page<Article>, ArticleError>> + Send;
    fn update(
        &self,
        actor: &Actor,
        id: ArticleId,
        patch: ArticlePatch,
        if_match: Option<i32>,
    ) -> impl Future<Output = Result<Article, ArticleError>> + Send;
    fn publish(
        &self,
        actor: &Actor,
        id: ArticleId,
        idem: Option<Idempotency<'_, Article>>,
    ) -> impl Future<Output = Result<Article, ArticleError>> + Send;
    fn archive(
        &self,
        actor: &Actor,
        id: ArticleId,
        message_id: &str,
    ) -> impl Future<Output = Result<Moderation, ArticleError>> + Send;
}

/// One command, one transaction, begun and committed here.
pub struct Publishing<S, C, G> {
    store: S,
    clock: C,
    ids: G,
}

impl<S, C, G> Publishing<S, C, G> {
    pub fn new(store: S, clock: C, ids: G) -> Self {
        Self { store, clock, ids }
    }
}

impl<S, C, G> Articles for Publishing<S, C, G>
where
    S: ArticleRepository + Outbox + Inbox + IdempotencyStore,
    C: Clock,
    G: IdGenerator,
{
    #[tracing::instrument(skip_all, fields(tenant = %actor.tenant_id.0))]
    async fn create(
        &self,
        actor: &Actor,
        input: NewArticle,
        idem: Option<Idempotency<'_, Article>>,
    ) -> Result<Article, ArticleError> {
        let article = Article::create(ArticleId(self.ids.new_id()), actor, &input, self.clock.now())?;
        let mut tx = self.store.begin().await?;
        self.store.insert(&mut tx, &article).await?;
        commit(&self.store, tx, idem, &article).await?;
        Ok(article)
    }

    async fn get(&self, actor: &Actor, id: ArticleId) -> Result<Article, ArticleError> {
        self.store.find(actor.tenant_id, id).await?.ok_or(ArticleError::NotFound)
    }

    async fn list(&self, actor: &Actor, page: PageRequest) -> Result<Page<Article>, ArticleError> {
        Ok(self.store.list(actor.tenant_id, page).await?)
    }

    #[tracing::instrument(skip_all, fields(article = %id.0))]
    async fn update(
        &self,
        actor: &Actor,
        id: ArticleId,
        patch: ArticlePatch,
        if_match: Option<i32>,
    ) -> Result<Article, ArticleError> {
        let mut tx = self.store.begin().await?;
        let mut article = self.load_for_write(&mut tx, actor, id).await?;
        let read = article.version();
        if if_match.is_some_and(|v| v != read) {
            return Err(ArticleError::PreconditionFailed { current: read });
        }
        article.edit(patch, self.clock.now())?;
        self.store.save(&mut tx, &article, read, article.status()).await?;
        self.store.commit(tx).await?;
        Ok(article)
    }

    #[tracing::instrument(skip_all, fields(article = %id.0))]
    async fn publish(
        &self,
        actor: &Actor,
        id: ArticleId,
        idem: Option<Idempotency<'_, Article>>,
    ) -> Result<Article, ArticleError> {
        let mut tx = self.store.begin().await?;
        let mut article = self.load_for_write(&mut tx, actor, id).await?;
        let read = article.version();
        let event = article.publish(self.clock.now())?;
        self.store.save(&mut tx, &article, read, Status::Draft).await?; // the guarded transition
        self.store.append(&mut tx, &event).await?;
        commit(&self.store, tx, idem, &article).await?;
        Ok(article)
    }

    #[tracing::instrument(skip_all, fields(article = %id.0))]
    async fn archive(&self, actor: &Actor, id: ArticleId, message_id: &str) -> Result<Moderation, ArticleError> {
        if !actor.has_role("moderator") {
            return Err(ArticleError::Forbidden);
        }
        let mut tx = self.store.begin().await?;
        if !self.store.record(&mut tx, "moderation", message_id).await? {
            return Ok(Moderation::Duplicate);
        }
        let outcome = match self.store.find_for_update(&mut tx, actor.tenant_id, id).await? {
            None => Moderation::Ignored("article not found"),
            Some(mut article) => {
                let read = article.version();
                match article.archive(self.clock.now()) {
                    Err(ArticleError::InvalidTransition { .. }) => Moderation::Ignored("article is not published"),
                    Err(e) => return Err(e),
                    Ok(()) => {
                        self.store.save(&mut tx, &article, read, Status::Published).await?;
                        Moderation::Archived
                    }
                }
            }
        };
        self.store.commit(tx).await?; // the inbox row commits even when the verdict is ignored
        Ok(outcome)
    }
}

impl<S: ArticleRepository, C, G> Publishing<S, C, G> {
    /// Row-locked: the in-memory article stays the truth for the response and the event.
    async fn load_for_write(&self, tx: &mut S::Tx, actor: &Actor, id: ArticleId) -> Result<Article, ArticleError> {
        let article = self.store.find_for_update(tx, actor.tenant_id, id).await?.ok_or(ArticleError::NotFound)?;
        if !article.editable_by(actor) {
            return Err(ArticleError::Forbidden);
        }
        Ok(article)
    }
}

async fn commit<S: IdempotencyStore, T>(
    store: &S,
    mut tx: S::Tx,
    idem: Option<Idempotency<'_, T>>,
    output: &T,
) -> Result<(), ArticleError> {
    if let Some(idem) = idem {
        store.complete(&mut tx, idem.lease, &(idem.render)(output)).await?;
    }
    Ok(store.commit(tx).await?)
}
```

## Use-case tests

Hand-rolled doubles: a fake store whose transaction is a copy of the state (so a failed command leaves nothing behind) and which enforces the unique slug; `fail_outbox` turns it into the Saboteur that proves `publish` fails as a whole.

```rust file=domain/tests/use_cases.rs
use std::collections::HashSet;
use std::sync::{Arc, Mutex};

use chrono::{DateTime, Utc};
use domain::*;
use uuid::Uuid;

#[derive(Clone, Default)]
struct State {
    articles: Vec<Article>,
    outbox: Vec<ArticleEvent>,
    inbox: HashSet<String>,
    responses: Vec<StoredResponse>,
}

/// A transaction is a copy of the state that replaces it on commit, so a command that fails
/// before committing leaves nothing behind. Enforces the database's unique (tenant, slug);
/// `fail_outbox` makes it a Saboteur.
#[derive(Clone, Default)]
struct FakeStore {
    state: Arc<Mutex<State>>,
    fail_outbox: bool,
}

impl FakeStore {
    fn snapshot(&self) -> State {
        self.state.lock().unwrap().clone()
    }
}

impl UnitOfWork for FakeStore {
    type Tx = State;
    async fn begin(&self) -> anyhow::Result<State> {
        Ok(self.snapshot())
    }
    async fn commit(&self, tx: State) -> anyhow::Result<()> {
        *self.state.lock().unwrap() = tx;
        Ok(())
    }
}

impl ArticleRepository for FakeStore {
    async fn insert(&self, tx: &mut State, a: &Article) -> Result<(), ArticleError> {
        if tx.articles.iter().any(|x| x.tenant_id() == a.tenant_id() && x.slug() == a.slug()) {
            return Err(ArticleError::SlugTaken);
        }
        tx.articles.push(a.clone());
        Ok(())
    }
    async fn find(&self, tenant: TenantId, id: ArticleId) -> anyhow::Result<Option<Article>> {
        Ok(self.snapshot().articles.into_iter().find(|a| a.tenant_id() == tenant && a.id() == id))
    }
    async fn find_for_update(
        &self,
        tx: &mut State,
        tenant: TenantId,
        id: ArticleId,
    ) -> anyhow::Result<Option<Article>> {
        Ok(tx.articles.iter().find(|a| a.tenant_id() == tenant && a.id() == id).cloned())
    }
    async fn list(&self, _: TenantId, _: PageRequest) -> anyhow::Result<Page<Article>> {
        anyhow::bail!("not used here")
    }
    async fn save(&self, tx: &mut State, a: &Article, version: i32, status: Status) -> Result<(), ArticleError> {
        let row = tx.articles.iter_mut().find(|x| x.id() == a.id() && x.version() == version && x.status() == status);
        *row.ok_or(ArticleError::VersionConflict)? = a.clone();
        Ok(())
    }
}

impl Outbox for FakeStore {
    async fn append(&self, tx: &mut State, event: &ArticleEvent) -> anyhow::Result<()> {
        anyhow::ensure!(!self.fail_outbox, "outbox write failed");
        tx.outbox.push(event.clone());
        Ok(())
    }
}

impl Inbox for FakeStore {
    async fn record(&self, tx: &mut State, _: &str, id: &str) -> anyhow::Result<bool> {
        Ok(tx.inbox.insert(id.to_owned()))
    }
}

impl IdempotencyStore for FakeStore {
    async fn acquire(&self, _: &str, _: &str, _: &str) -> anyhow::Result<Acquire> {
        anyhow::bail!("acquired by the HTTP adapter, not by use cases")
    }
    async fn complete(&self, tx: &mut State, _: &Lease, response: &StoredResponse) -> anyhow::Result<()> {
        tx.responses.push(response.clone());
        Ok(())
    }
    async fn release(&self, _: &Lease) -> anyhow::Result<()> {
        Ok(())
    }
    async fn purge_expired(&self) -> anyhow::Result<u64> {
        Ok(0)
    }
}

struct FixedClock;
impl Clock for FixedClock {
    fn now(&self) -> DateTime<Utc> {
        DateTime::UNIX_EPOCH
    }
}

struct V7Ids;
impl IdGenerator for V7Ids {
    fn new_id(&self) -> Uuid {
        Uuid::now_v7()
    }
}

fn setup(store: &FakeStore) -> Publishing<FakeStore, FixedClock, V7Ids> {
    Publishing::new(store.clone(), FixedClock, V7Ids)
}

fn actor(tenant: u128, subject: &str, roles: &[&str]) -> Actor {
    Actor {
        tenant_id: TenantId(Uuid::from_u128(tenant)),
        subject: subject.into(),
        roles: roles.iter().map(|r| (*r).into()).collect(),
    }
}

fn input(slug: &str) -> NewArticle {
    NewArticle { slug: slug.into(), title: "Title".into(), body: String::new() }
}

fn render(_: &Article) -> StoredResponse {
    StoredResponse { status: 200, headers: vec![], body: b"{}".to_vec() }
}

#[tokio::test]
async fn slugs_are_unique_per_tenant() {
    let app = setup(&FakeStore::default());
    app.create(&actor(1, "ann", &[]), input("hello"), None).await.unwrap();
    assert!(matches!(app.create(&actor(1, "bob", &[]), input("hello"), None).await, Err(ArticleError::SlugTaken)));
    app.create(&actor(2, "cy", &[]), input("hello"), None).await.unwrap();
}

#[tokio::test]
async fn publish_commits_event_and_response_together_or_not_at_all() {
    let lease = Lease { scope: "t:ann".into(), key: "k".into(), token: Uuid::nil() };
    for fail_outbox in [false, true] {
        let store = FakeStore { fail_outbox, ..FakeStore::default() };
        let (app, ann) = (setup(&store), actor(1, "ann", &[]));
        let id = app.create(&ann, input("hello"), None).await.unwrap().id();
        let published = app.publish(&ann, id, Some(Idempotency { lease: &lease, render })).await;
        let state = store.snapshot();
        assert_eq!(published.is_ok(), !fail_outbox);
        assert_eq!(state.articles[0].status(), if fail_outbox { Status::Draft } else { Status::Published });
        assert_eq!((state.outbox.len(), state.responses.len()), if fail_outbox { (0, 0) } else { (1, 1) });
    }
}

#[tokio::test]
async fn writes_need_the_author_or_an_editor_and_respect_if_match() {
    let app = setup(&FakeStore::default());
    let id = app.create(&actor(1, "ann", &[]), input("hello"), None).await.unwrap().id();
    let patch = || ArticlePatch { title: Some("New".into()), body: None };
    assert!(matches!(app.update(&actor(1, "bob", &[]), id, patch(), None).await, Err(ArticleError::Forbidden)));
    assert!(matches!(app.update(&actor(2, "ann", &["editor"]), id, patch(), None).await, Err(ArticleError::NotFound)));
    let editor = actor(1, "ed", &["editor"]);
    assert!(matches!(
        app.update(&editor, id, patch(), Some(7)).await,
        Err(ArticleError::PreconditionFailed { current: 1 })
    ));
    assert_eq!(app.update(&editor, id, patch(), Some(1)).await.unwrap().version(), 2);
}

#[tokio::test]
async fn moderation_applies_each_message_once() {
    let store = FakeStore::default();
    let (app, ann) = (setup(&store), actor(1, "ann", &[]));
    let id = app.create(&ann, input("hello"), None).await.unwrap().id();
    let moderator = actor(1, "system:moderation", &["moderator"]);
    assert_eq!(app.archive(&moderator, id, "m1").await.unwrap(), Moderation::Ignored("article is not published"));
    app.publish(&ann, id, None).await.unwrap();
    assert_eq!(app.archive(&moderator, id, "m2").await.unwrap(), Moderation::Archived);
    assert_eq!(app.archive(&moderator, id, "m2").await.unwrap(), Moderation::Duplicate);
    assert!(matches!(app.archive(&ann, id, "m3").await, Err(ArticleError::Forbidden)));
    assert_eq!(store.snapshot().inbox.len(), 2);
}
```
