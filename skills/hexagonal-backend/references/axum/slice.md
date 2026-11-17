# Axum examples: the slice

What any command or query needs: the publishing context's domain crate, its PostgreSQL adapter with the tenant wiring, and the HTTP routes with their problem rendering. Every `file=` block is a complete file of one workspace that passes its gates on the baseline in `guide.md` § 0. Idempotency, the outbox relay and the webhook are in `reliability.md`, the app factory, authentication and entrypoints in `service.md`, the tests in `tests.md`.

## Contents

1. [Domain crate](#domain-crate)
2. [Errors](#errors)
3. [Model](#model)
4. [Ports](#ports)
5. [Use cases](#use-cases)
6. [Roles and migration](#roles-and-migration)
7. [Connection and unit of work](#connection-and-unit-of-work)
8. [Repository](#repository)
9. [Problem documents](#problem-documents)
10. [Extractors](#extractors)
11. [Routes](#routes)

## Domain crate

The domain is its own crate. The compiler rejects a `use` of any crate its manifest does not list, and the boundary check in `service.md` rejects listing one that is not allowed.

```toml file=domain/Cargo.toml
# The dependency list is the boundary: scripts/check-boundary.sh fails on any crate not allowed there.
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

[lints]
workspace = true
```

```rust file=domain/src/lib.rs
//! The publishing context: model, errors, ports and use cases. It depends on no web framework,
//! driver or telemetry SDK; `tracing` is the one facade.
mod error;
mod model;
mod ports;
mod use_cases;

pub use error::*;
pub use model::*;
pub use ports::*;
pub use use_cases::*;
```

## Errors

`ArticleError` is the closed set of kinds. `From<ArticleError> for ApiError` in `problem.rs` matches it exhaustively, so a new kind does not compile until it is mapped. An adapter marks a failure that a retry can fix by attaching `Unavailable` as context.

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

/// The closed set of outcomes. A new kind does not compile until the HTTP adapter maps it.
#[derive(Debug, thiserror::Error)]
pub enum ArticleError {
    #[error("article not found")]
    NotFound,
    #[error("not allowed to change this article")]
    Forbidden,
    #[error("{} invalid field(s)", .0.len())]
    Invalid(Vec<Violation>),
    #[error("the cursor is not valid for this list")]
    InvalidCursor,
    #[error("an article with this slug already exists")]
    SlugTaken,
    #[error("cannot {action} an article that is not in status '{}'", needs.as_str())]
    InvalidTransition { action: &'static str, needs: Status },
    #[error("the article changed concurrently; re-read and retry")]
    VersionConflict,
    #[error("the article changed since the ETag you sent; re-fetch and retry")]
    PreconditionFailed,
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

## Model

Data plus functions that decide. Each takes the current state by value and returns the next state or an error. Time and ids arrive as arguments, so the tests at the end of the file need no doubles.

```rust file=domain/src/model.rs
use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::error::{ArticleError, Violation};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ArticleId(pub Uuid);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TenantId(pub Uuid);

/// Who is acting. An inbound adapter builds it; every use case takes it as its first argument.
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

// Value objects: a value that exists is valid. Lengths count code points, as PostgreSQL's
// char_length does, and text carries no U+0000, which PostgreSQL cannot store.
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
        let title = raw.trim();
        match title.chars().count() {
            _ if title.contains('\0') => Err(Violation::new("title", "invalid_character", "must not contain U+0000")),
            0 => Err(Violation::new("title", "required", "must not be blank")),
            201.. => Err(Violation::new("title", "too_long", "must be at most 200 characters")),
            _ => Ok(Self(title.to_owned())),
        }
    }
}

impl Body {
    fn parse(raw: &str) -> Result<Self, Violation> {
        match raw.chars().count() {
            _ if raw.contains('\0') => Err(Violation::new("body", "invalid_character", "must not contain U+0000")),
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

/// Fields are private: an `Article` comes from `create` (validated) or `rehydrate` (trusted),
/// and changes only through the functions below. Each takes the current state and returns the
/// next one or an error; none reads the clock, makes an id or touches a port.
#[derive(Clone, Debug)]
pub struct Article {
    id: ArticleId,
    tenant_id: TenantId,
    author_id: String,
    slug: Slug,
    title: Title,
    body: Body,
    status: Status,
    version: i32, // assigned by the store on every write: the ETag and the event sequence
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    published_at: Option<DateTime<Utc>>,
}

/// Domain events; the outbox adapter serializes them (no serde here).
#[derive(Clone, Debug)]
pub enum ArticleEvent {
    Published { article_id: ArticleId, tenant_id: TenantId, slug: String, version: i32, published_at: DateTime<Utc> },
}

impl ArticleEvent {
    /// From the stored article, whose version is the event's sequence within the aggregate.
    pub fn published(saved: &Article, at: DateTime<Utc>) -> Self {
        let (article_id, tenant_id, slug) = (saved.id, saved.tenant_id, saved.slug.0.clone());
        Self::Published { article_id, tenant_id, slug, version: saved.version, published_at: at }
    }
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

    pub fn edit(mut self, patch: ArticlePatch, now: DateTime<Utc>) -> Result<Self, ArticleError> {
        match (patch.title.as_deref().map(Title::parse).transpose(), patch.body.as_deref().map(Body::parse).transpose())
        {
            (Ok(title), Ok(body)) => {
                self.title = title.unwrap_or(self.title);
                self.body = body.unwrap_or(self.body);
                self.updated_at = now;
                Ok(self)
            }
            (t, b) => Err(ArticleError::Invalid([t.err(), b.err()].into_iter().flatten().collect())),
        }
    }

    pub fn publish(self, now: DateTime<Utc>) -> Result<Self, ArticleError> {
        let mut next = self.moved(Status::Draft, Status::Published, "publish", now)?;
        next.published_at = Some(now);
        Ok(next)
    }

    pub fn archive(self, now: DateTime<Utc>) -> Result<Self, ArticleError> {
        self.moved(Status::Published, Status::Archived, "archive", now)
    }

    fn moved(
        mut self,
        from: Status,
        to: Status,
        action: &'static str,
        now: DateTime<Utc>,
    ) -> Result<Self, ArticleError> {
        if self.status != from {
            return Err(ArticleError::InvalidTransition { action, needs: from });
        }
        self.status = to;
        self.updated_at = now;
        Ok(self)
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

/// Newest first. The cursor is opaque here: the store adapter makes it and reads it.
pub struct PageRequest {
    pub cursor: Option<String>,
    pub size: PageSize,
}

/// `next_cursor` is `None` on the last page.
pub struct Page<T> {
    pub items: Vec<T>,
    pub next_cursor: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    const T0: DateTime<Utc> = DateTime::UNIX_EPOCH;

    fn actor(subject: &str, roles: &[&str]) -> Actor {
        Actor {
            tenant_id: TenantId(Uuid::nil()),
            subject: subject.into(),
            roles: roles.iter().map(|r| (*r).into()).collect(),
        }
    }

    fn draft(slug: &str, title: &str, body: &str) -> Result<Article, ArticleError> {
        let input = NewArticle { slug: slug.into(), title: title.into(), body: body.into() };
        Article::create(ArticleId(Uuid::nil()), &actor("ann", &[]), &input, T0)
    }

    fn violations(result: Result<Article, ArticleError>) -> Vec<(&'static str, &'static str)> {
        match result {
            Err(ArticleError::Invalid(v)) => v.iter().map(|v| (v.field, v.code)).collect(),
            other => panic!("expected violations, got {other:?}"),
        }
    }

    #[test]
    fn create_validates_every_field_and_reports_them_together() {
        let ok = draft("hello-2026", "  Hello ", "").unwrap();
        assert_eq!((ok.title(), ok.status(), ok.version(), ok.published_at()), ("Hello", Status::Draft, 1, None));
        assert_eq!(violations(draft("Not Kebab", " ", "")), [("slug", "invalid_format"), ("title", "required")]);
        for slug in ["", "-a", "a-", "a--b", "a_b", "é", &"a".repeat(101)] {
            assert_eq!(violations(draft(slug, "T", "")).len(), 1, "{slug:?}");
        }
        // Code points, not bytes or UTF-16 units: 200 emoji fit, 201 do not.
        assert!(draft("a", &"😀".repeat(200), "").is_ok());
        assert_eq!(violations(draft("a", &"😀".repeat(201), "")), [("title", "too_long")]);
        assert_eq!(
            violations(draft("a", "T\0", &"b\0".repeat(2))),
            [("title", "invalid_character"), ("body", "invalid_character")]
        );
    }

    #[test]
    fn edit_changes_only_what_the_patch_names() {
        let a = draft("a", "Old", "text").unwrap();
        let edited = a.clone().edit(ArticlePatch { title: Some(" New ".into()), body: None }, T0).unwrap();
        assert_eq!((edited.title(), edited.body(), edited.version()), ("New", "text", 1));
        assert!(matches!(
            a.edit(ArticlePatch { title: Some(" ".into()), body: None }, T0),
            Err(ArticleError::Invalid(_))
        ));
    }

    #[test]
    fn only_draft_to_published_to_archived() {
        let a = draft("a", "T", "").unwrap();
        let needs = |result: Result<Article, ArticleError>| match result {
            Err(ArticleError::InvalidTransition { needs, .. }) => needs,
            other => panic!("expected an invalid transition, got {other:?}"),
        };
        assert_eq!(needs(a.clone().archive(T0)), Status::Published);
        let published = a.publish(T0).unwrap();
        assert_eq!((published.status(), published.published_at()), (Status::Published, Some(T0)));
        assert_eq!(needs(published.clone().publish(T0)), Status::Draft);
        let archived = published.archive(T0).unwrap();
        assert_eq!((archived.status(), archived.published_at()), (Status::Archived, Some(T0)));
    }

    #[test]
    fn the_author_or_an_editor_may_write() {
        let a = draft("a", "T", "").unwrap();
        let may = [actor("ann", &[]), actor("ed", &["editor"]), actor("bob", &[]), actor("mo", &["moderator"])];
        assert_eq!(may.map(|who| a.editable_by(&who)), [true, true, false, false]);
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
        assert_eq!((a.slug(), a.title().len(), a.version()), ("Legacy_Slug", 300, 7));
    }
}
```

## Ports

`UnitOfWork::begin(&actor)` opens a transaction scoped to the actor's tenant, and `Tx` is the only way to a repository. The idempotency and event ports that `reliability.md` implements are declared here too.

```rust file=domain/src/ports.rs
use std::future::Future;

use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::{Actor, Article, ArticleError, ArticleEvent, ArticleId, Page, PageRequest, Status};

pub trait Clock: Send + Sync + 'static {
    fn now(&self) -> DateTime<Utc>;
}

pub trait IdGenerator: Send + Sync + 'static {
    fn new_id(&self) -> Uuid;
}

/// Opens the one transaction of a command or query, scoped to the actor's tenant.
pub trait UnitOfWork: Send + Sync + 'static {
    type Tx: Tx;
    fn begin(&self, actor: &Actor) -> impl Future<Output = anyhow::Result<Self::Tx>> + Send;
}

/// An open transaction. Its accessors are the only way to a repository, so no query runs
/// outside a transaction or outside the tenant it was opened for. Dropping it rolls back.
pub trait Tx: Send {
    fn articles(&mut self) -> impl ArticleRepository + Send;
    fn outbox(&mut self) -> impl Outbox + Send;
    fn inbox(&mut self) -> impl Inbox + Send;
    fn idempotency(&mut self) -> impl IdempotencyCompletion + Send;
    fn commit(self) -> impl Future<Output = anyhow::Result<()>> + Send;
}

/// Bound to its transaction's tenant: another tenant's article reads as missing.
pub trait ArticleRepository {
    fn insert(&mut self, article: &Article) -> impl Future<Output = Result<(), ArticleError>> + Send;
    fn get(&mut self, id: ArticleId) -> impl Future<Output = anyhow::Result<Option<Article>>> + Send;
    /// At most `page.size` items; a cursor this list did not issue is `InvalidCursor`.
    fn list(&mut self, page: &PageRequest) -> impl Future<Output = Result<Page<Article>, ArticleError>> + Send;
    /// Writes the editable fields if the stored version is still `read`. `None`: it moved.
    fn update(&mut self, next: &Article, read: i32) -> impl Future<Output = anyhow::Result<Option<Article>>> + Send;
    /// Writes the new status if the stored one is still `from`. `None`: it moved.
    fn transition(
        &mut self,
        next: &Article,
        from: Status,
    ) -> impl Future<Output = anyhow::Result<Option<Article>>> + Send;
}

pub trait Outbox {
    fn append(&mut self, event: &ArticleEvent) -> impl Future<Output = anyhow::Result<()>> + Send;
}

pub trait Inbox {
    /// `false` if the message was already recorded.
    fn record(&mut self, consumer: &str, message_id: &str) -> impl Future<Output = anyhow::Result<bool>> + Send;
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

/// Outside any transaction: the edge acquires a key before the command runs.
pub trait IdempotencyStore: Send + Sync + 'static {
    /// `Execute` only when this call's insert, or its takeover of an expired lease, won.
    fn acquire(&self, scope: &str, key: &str, hash: &str) -> impl Future<Output = anyhow::Result<Acquire>> + Send;
    /// Stores an outcome that committed nothing else (a 4xx worth replaying).
    fn complete(&self, lease: &Lease, response: &StoredResponse) -> impl Future<Output = anyhow::Result<()>> + Send;
    fn release(&self, lease: &Lease) -> impl Future<Output = anyhow::Result<()>> + Send;
    fn purge_expired(&self) -> impl Future<Output = anyhow::Result<u64>> + Send;
}

/// Inside the command's transaction: the response commits with the state change.
pub trait IdempotencyCompletion {
    /// Fails, rolling the command back, if the lease was lost.
    fn complete(&mut self, lease: &Lease, response: &StoredResponse)
    -> impl Future<Output = anyhow::Result<()>> + Send;
}

/// Rust has no ambient transaction, so the wrapper's completion travels as an argument: the
/// use case stores `render(&output)` under the lease in its own transaction.
pub struct Idempotency<'a, T> {
    pub lease: &'a Lease,
    pub render: fn(&T) -> StoredResponse,
}
```

## Use cases

Each takes the `Actor` first and owns its transaction from `begin` to `commit`. Dropping an uncommitted `Tx` rolls it back, so every `?` is a rollback. Reads run in a transaction too, because row-level security shows a query nothing until the transaction names its tenant.

```rust file=domain/src/use_cases.rs
use crate::{
    Actor, Article, ArticleError, ArticleEvent, ArticleId, ArticlePatch, ArticleRepository, Clock, IdGenerator,
    Idempotency, IdempotencyCompletion, Inbox, NewArticle, Outbox, Page, PageRequest, Status, Tx, UnitOfWork,
};

#[derive(Debug, PartialEq, Eq)]
pub enum Moderation {
    Archived,
    Duplicate,
    Ignored(&'static str),
}

/// The use cases of the context: what every inbound adapter calls. Each takes the actor first
/// and owns its transaction, from `begin` to `commit`.
pub struct Publishing<U> {
    uow: U,
    clock: Box<dyn Clock>,
    ids: Box<dyn IdGenerator>,
}

impl<U: UnitOfWork> Publishing<U> {
    pub fn new(uow: U, clock: impl Clock, ids: impl IdGenerator) -> Self {
        Self { uow, clock: Box::new(clock), ids: Box::new(ids) }
    }

    #[tracing::instrument(skip_all, fields(tenant = %actor.tenant_id.0))]
    pub async fn create(
        &self,
        actor: &Actor,
        input: NewArticle,
        idem: Option<Idempotency<'_, Article>>,
    ) -> Result<Article, ArticleError> {
        let article = Article::create(ArticleId(self.ids.new_id()), actor, &input, self.clock.now())?;
        let mut tx = self.uow.begin(actor).await?;
        tx.articles().insert(&article).await?; // a taken slug is the constraint's verdict, not a prior check
        finish(tx, idem, &article).await?;
        Ok(article)
    }

    pub async fn get(&self, actor: &Actor, id: ArticleId) -> Result<Article, ArticleError> {
        let mut tx = self.uow.begin(actor).await?;
        let article = tx.articles().get(id).await?.ok_or(ArticleError::NotFound)?;
        tx.commit().await?;
        Ok(article)
    }

    pub async fn list(&self, actor: &Actor, page: PageRequest) -> Result<Page<Article>, ArticleError> {
        let mut tx = self.uow.begin(actor).await?;
        let page = tx.articles().list(&page).await?;
        tx.commit().await?;
        Ok(page)
    }

    /// `if_match` holds the versions the client's `If-Match` lists; `None` is unconditional.
    #[tracing::instrument(skip_all, fields(article = %id.0))]
    pub async fn update(
        &self,
        actor: &Actor,
        id: ArticleId,
        patch: ArticlePatch,
        if_match: Option<&[i32]>,
    ) -> Result<Article, ArticleError> {
        let mut tx = self.uow.begin(actor).await?;
        let current = editable(&mut tx, actor, id).await?;
        let read = current.version();
        // Judged after the 404 and 403 decisions: a precondition must not reveal what exists.
        if if_match.is_some_and(|versions| !versions.contains(&read)) {
            return Err(ArticleError::PreconditionFailed);
        }
        let next = current.edit(patch, self.clock.now())?;
        let lost = if if_match.is_some() { ArticleError::PreconditionFailed } else { ArticleError::VersionConflict };
        let saved = tx.articles().update(&next, read).await?.ok_or(lost)?;
        tx.commit().await?;
        Ok(saved)
    }

    #[tracing::instrument(skip_all, fields(article = %id.0))]
    pub async fn publish(
        &self,
        actor: &Actor,
        id: ArticleId,
        idem: Option<Idempotency<'_, Article>>,
    ) -> Result<Article, ArticleError> {
        let mut tx = self.uow.begin(actor).await?; // one transaction, scoped to the actor's tenant
        let current = editable(&mut tx, actor, id).await?; // another tenant's row is invisible: NotFound
        let now = self.clock.now();
        let next = current.publish(now)?;
        let lost = ArticleError::InvalidTransition { action: "publish", needs: Status::Draft };
        let saved = tx.articles().transition(&next, Status::Draft).await?.ok_or(lost)?; // the database decided the race
        tx.outbox().append(&ArticleEvent::published(&saved, now)).await?; // commits with the state change, or not at all
        finish(tx, idem, &saved).await?;
        Ok(saved)
    }

    /// The moderation consumer's command: `message_id` is recorded in the same transaction as the
    /// effect, so a redelivery finds it and changes nothing.
    #[tracing::instrument(skip_all, fields(article = %id.0))]
    pub async fn archive(&self, actor: &Actor, id: ArticleId, message_id: &str) -> Result<Moderation, ArticleError> {
        if !actor.has_role("moderator") {
            return Err(ArticleError::Forbidden);
        }
        let mut tx = self.uow.begin(actor).await?;
        if !tx.inbox().record("moderation", message_id).await? {
            return Ok(Moderation::Duplicate);
        }
        let found = tx.articles().get(id).await?; // bound first: a scrutinee's temporary would hold `tx` across the arms
        let outcome = match found {
            None => Moderation::Ignored("article not found"),
            Some(article) => match article.archive(self.clock.now()) {
                Err(ArticleError::InvalidTransition { .. }) => Moderation::Ignored("article is not published"),
                Err(e) => return Err(e),
                Ok(next) => match tx.articles().transition(&next, Status::Published).await? {
                    Some(_) => Moderation::Archived,
                    None => Moderation::Ignored("article is not published"),
                },
            },
        };
        tx.commit().await?; // the inbox row commits even when the verdict is ignored
        Ok(outcome)
    }
}

/// Loads for a write. Missing comes before forbidden, so an id never reveals that it exists.
async fn editable(tx: &mut impl Tx, actor: &Actor, id: ArticleId) -> Result<Article, ArticleError> {
    let article = tx.articles().get(id).await?.ok_or(ArticleError::NotFound)?;
    if !article.editable_by(actor) {
        return Err(ArticleError::Forbidden);
    }
    Ok(article)
}

/// Commits, storing the idempotent response first when the request carried a key.
async fn finish(mut tx: impl Tx, idem: Option<Idempotency<'_, Article>>, output: &Article) -> Result<(), ArticleError> {
    if let Some(idem) = idem {
        tx.idempotency().complete(idem.lease, &(idem.render)(output)).await?;
    }
    Ok(tx.commit().await?)
}
```

## Roles and migration

The application's role is created outside the migrations, because a role belongs to the cluster and outlives any database. The migration creates schema `app`, the table, its policy and the grants. The release step applies it as the owning role.

```sql file=db/dev-roles.sql
-- Development and test clusters only. Roles belong to the cluster and outlive any one database,
-- so creating them is bootstrap, not a migration; production creates app_rw through its own
-- provisioning, with a real secret. The application connects as app_rw: it owns nothing and
-- cannot bypass row-level security. Migrations connect as the role that owns the schema.
DO $$ BEGIN
    CREATE ROLE app_rw LOGIN PASSWORD 'app_rw';
EXCEPTION WHEN duplicate_object OR unique_violation THEN NULL; -- a concurrent creator raises 23505, not 42710
END $$;
```

```sql file=migrations/0001_articles.sql
CREATE SCHEMA app;
GRANT USAGE ON SCHEMA app TO app_rw;

-- The adapter maps uq_articles_tenant_slug to `SlugTaken`; the CHECKs back the domain rules.
CREATE TABLE app.articles (
    id           uuid        CONSTRAINT pk_articles PRIMARY KEY,
    tenant_id    uuid        NOT NULL,
    author_id    text        NOT NULL CONSTRAINT chk_articles_author_id CHECK (char_length(author_id) BETWEEN 1 AND 255),
    slug         text        NOT NULL CONSTRAINT chk_articles_slug CHECK (char_length(slug) <= 100 AND slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    title        text        NOT NULL CONSTRAINT chk_articles_title CHECK (char_length(title) BETWEEN 1 AND 200),
    body         text        NOT NULL CONSTRAINT chk_articles_body CHECK (char_length(body) <= 20000),
    status       text        NOT NULL CONSTRAINT chk_articles_status CHECK (status IN ('draft', 'published', 'archived')),
    version      integer     NOT NULL CONSTRAINT chk_articles_version CHECK (version >= 1),
    created_at   timestamptz NOT NULL,
    updated_at   timestamptz NOT NULL,
    published_at timestamptz,
    CONSTRAINT uq_articles_tenant_slug UNIQUE (tenant_id, slug),
    CONSTRAINT chk_articles_published_at CHECK ((status = 'draft') = (published_at IS NULL))
);

-- Keyset pages: WHERE tenant_id = $1 AND id < $2 ORDER BY id DESC (a backward index scan).
CREATE INDEX idx_articles_tenant_id ON app.articles (tenant_id, id);

-- The second enforcement point. FORCE covers the owner too; the policy names the application's
-- role, and reads the tenant the unit of work sets as each transaction's first statement. An
-- unset or empty setting matches no row. With no WITH CHECK, USING also judges written rows.
ALTER TABLE app.articles ENABLE ROW LEVEL SECURITY, FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON app.articles TO app_rw
    USING (tenant_id = (SELECT NULLIF(current_setting('app.current_tenant', true), '')::uuid));
GRANT SELECT, INSERT, UPDATE ON app.articles TO app_rw;
```

## Connection and unit of work

`PgStore::connect` sets the session bounds and refuses a role that bypasses row-level security. `db_error` tags the failures a retry can fix. `begin` sets the tenant as the transaction's first statement and hands out repositories that borrow the transaction. `PgInbox` is here because it is a few lines. The webhook that uses it is in `reliability.md`.

```rust file=src/outbound/postgres/mod.rs
mod articles;
mod idempotency;
mod outbox;

use std::time::Duration;

use anyhow::Context as _;
use domain::{Actor, ArticleRepository, IdempotencyCompletion, Inbox, Outbox, Tx, Unavailable, UnitOfWork};
use secrecy::ExposeSecret;
use sqlx::postgres::{PgConnectOptions, PgConnection, PgPool, PgPoolOptions};
use sqlx::{ConnectOptions as _, Postgres, Transaction};
use uuid::Uuid;

pub use outbox::{Relay, RelayConfig};

static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!();

/// One cheap handle (a pool). The use case opens a transaction through `UnitOfWork`; every
/// repository hangs off that transaction, so nothing tenant-owned is reachable from the pool.
#[derive(Clone)]
pub struct PgStore {
    pool: PgPool,
    lease: Duration, // idempotency lease: longer than the request deadline
}

impl PgStore {
    pub async fn connect(db: &crate::config::Database, lease: Duration) -> anyhow::Result<Self> {
        let ms = |d: Duration| format!("{}ms", d.as_millis());
        let options: PgConnectOptions =
            db.url.expose_secret().parse().context("DATABASE_URL is not a PostgreSQL URL")?;
        let options = options.application_name("articles").options([
            ("statement_timeout", ms(db.statement_timeout)),
            ("idle_in_transaction_session_timeout", ms(db.idle_in_transaction_timeout)),
            ("TimeZone", "UTC".to_owned()),
        ]);
        tracing::info!(host = options.get_host(), database = options.get_database(), "connecting"); // never the URL
        let pool = PgPoolOptions::new()
            .max_connections(db.max_connections)
            .acquire_timeout(Duration::from_secs(2)) // also bounds connecting: sqlx has no separate connect timeout
            .connect_with(options) // the one database round trip readiness waits for
            .await
            .context("connecting to PostgreSQL")?;
        // A superuser or BYPASSRLS role skips every tenant policy without an error: refuse to serve as one.
        let bypasses = sqlx::query_scalar!(
            r#"SELECT rolsuper OR rolbypassrls AS "bypasses!" FROM pg_roles WHERE rolname = current_user"#
        )
        .fetch_one(&pool)
        .await
        .map_err(db_error)?;
        anyhow::ensure!(!bypasses, "DATABASE_URL connects as a role that bypasses row-level security; use app_rw");
        Ok(Self { pool, lease })
    }

    pub fn pool(&self) -> &PgPool {
        &self.pool
    }
}

/// The release step. It connects through its own URL as the role that owns the schema: the
/// application's role can neither run DDL nor read past the tenant policies.
pub async fn migrate(url: &str) -> anyhow::Result<()> {
    let options: PgConnectOptions = url.parse().context("MIGRATION_DATABASE_URL is not a PostgreSQL URL")?;
    let mut conn = options.application_name("articles-migrate").connect().await.context("connecting to PostgreSQL")?;
    run_migrations(&mut conn).await
}

/// Forward from whatever is applied, under an advisory lock: concurrent runs wait, never race.
pub async fn run_migrations(conn: &mut PgConnection) -> anyhow::Result<()> {
    Ok(MIGRATOR.run(conn).await?)
}

/// Tags the failures a retry can fix, so callers answer 503 + Retry-After instead of 500.
pub(crate) fn db_error(e: sqlx::Error) -> anyhow::Error {
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

/// An open transaction and the tenant it was opened for.
pub struct PgTx {
    tx: Transaction<'static, Postgres>,
    tenant: Uuid,
}

impl PgTx {
    /// For adapters in this crate and for tests: SQL run here is inside the tenant's transaction.
    pub fn connection(&mut self) -> &mut PgConnection {
        &mut self.tx
    }
}

impl UnitOfWork for PgStore {
    type Tx = PgTx;

    async fn begin(&self, actor: &Actor) -> anyhow::Result<PgTx> {
        let tenant = actor.tenant_id.0;
        let mut tx = self.pool.begin().await.map_err(db_error)?;
        // The first statement. Transaction-local (`true`), so a pooled connection cannot carry one
        // request's tenant into the next; a bind parameter, which `SET LOCAL` cannot take.
        sqlx::query!("SELECT set_config('app.current_tenant', $1, true)", tenant.to_string())
            .fetch_one(&mut *tx)
            .await
            .map_err(db_error)?;
        Ok(PgTx { tx, tenant })
    }
}

impl Tx for PgTx {
    fn articles(&mut self) -> impl ArticleRepository + Send {
        articles::PgArticles(self)
    }

    fn outbox(&mut self) -> impl Outbox + Send {
        outbox::PgOutbox(self)
    }

    fn inbox(&mut self) -> impl Inbox + Send {
        PgInbox(self)
    }

    fn idempotency(&mut self) -> impl IdempotencyCompletion + Send {
        idempotency::PgCompletion(self)
    }

    async fn commit(self) -> anyhow::Result<()> {
        self.tx.commit().await.map_err(db_error)
    }
}

struct PgInbox<'t>(&'t mut PgTx);

impl Inbox for PgInbox<'_> {
    async fn record(&mut self, consumer: &str, message_id: &str) -> anyhow::Result<bool> {
        let inserted = sqlx::query!(
            "INSERT INTO app.inbox (consumer, message_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
            consumer,
            message_id
        )
        .execute(self.0.connection())
        .await
        .map_err(db_error)?;
        Ok(inserted.rows_affected() == 1)
    }
}
```

## Repository

Bound to its transaction's tenant: no method takes a tenant, and every statement still carries one. Writes are conditional and let the database increment `version`.

```rust file=src/outbound/postgres/articles.rs
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use chrono::{DateTime, Utc};
use domain::{Article, ArticleError, ArticleId, ArticleRecord, ArticleRepository, Page, PageRequest, Status};
use uuid::Uuid;

use super::{PgTx, db_error};

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

/// Every statement carries the transaction's tenant: the planner needs the predicate to use
/// the index, and the row-level policy is there for the statement that forgets it.
pub(super) struct PgArticles<'t>(pub(super) &'t mut PgTx);

impl ArticleRepository for PgArticles<'_> {
    async fn insert(&mut self, a: &Article) -> Result<(), ArticleError> {
        sqlx::query!(
            "INSERT INTO app.articles (id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)",
            a.id().0,
            a.tenant_id().0, // the policy refuses a row for any tenant but the transaction's
            a.author_id(),
            a.slug(),
            a.title(),
            a.body(),
            a.status().as_str(),
            a.version(),
            a.created_at(),
            a.updated_at(),
        )
        .execute(self.0.connection())
        .await
        .map_err(|e| match &e {
            // By constraint name: another UNIQUE (or the primary key) must not read as "slug taken".
            sqlx::Error::Database(d) if d.constraint() == Some("uq_articles_tenant_slug") => ArticleError::SlugTaken,
            _ => db_error(e).into(),
        })?;
        Ok(())
    }

    async fn get(&mut self, id: ArticleId) -> anyhow::Result<Option<Article>> {
        sqlx::query_as!(
            Row,
            "SELECT id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at, published_at
             FROM app.articles WHERE tenant_id = $1 AND id = $2",
            self.0.tenant,
            id.0
        )
        .fetch_optional(self.0.connection())
        .await
        .map_err(db_error)?
        .map(Row::into_article)
        .transpose()
    }

    async fn list(&mut self, page: &PageRequest) -> Result<Page<Article>, ArticleError> {
        let size = usize::from(page.size.get());
        // No branch for the first page: every UUID sorts below the max UUID.
        let before = match &page.cursor {
            Some(cursor) => decode_cursor(cursor).ok_or(ArticleError::InvalidCursor)?,
            None => Uuid::max(),
        };
        let mut rows = sqlx::query_as!(
            Row,
            "SELECT id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at, published_at
             FROM app.articles WHERE tenant_id = $1 AND id < $2 ORDER BY id DESC LIMIT $3",
            self.0.tenant,
            before,
            i64::from(page.size.get()) + 1 // one extra row answers "is there more?"
        )
        .fetch_all(self.0.connection())
        .await
        .map_err(db_error)?;
        let more = rows.len() > size;
        rows.truncate(size);
        let next_cursor = rows.last().filter(|_| more).map(|last| encode_cursor(last.id));
        Ok(Page { items: rows.into_iter().map(Row::into_article).collect::<anyhow::Result<_>>()?, next_cursor })
    }

    async fn update(&mut self, next: &Article, read: i32) -> anyhow::Result<Option<Article>> {
        // The database increments the version: one computed in memory would let a concurrent
        // edit and a transition both produce the same ETag.
        sqlx::query_as!(
            Row,
            "UPDATE app.articles SET title = $3, body = $4, updated_at = $5, version = version + 1
             WHERE tenant_id = $1 AND id = $2 AND version = $6
             RETURNING id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at, published_at",
            self.0.tenant,
            next.id().0,
            next.title(),
            next.body(),
            next.updated_at(),
            read,
        )
        .fetch_optional(self.0.connection())
        .await
        .map_err(db_error)?
        .map(Row::into_article)
        .transpose()
    }

    async fn transition(&mut self, next: &Article, from: Status) -> anyhow::Result<Option<Article>> {
        sqlx::query_as!(
            Row,
            "UPDATE app.articles SET status = $3, published_at = $4, updated_at = $5, version = version + 1
             WHERE tenant_id = $1 AND id = $2 AND status = $6
             RETURNING id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at, published_at",
            self.0.tenant,
            next.id().0,
            next.status().as_str(),
            next.published_at(),
            next.updated_at(),
            from.as_str(),
        )
        .fetch_optional(self.0.connection())
        .await
        .map_err(db_error)?
        .map(Row::into_article)
        .transpose()
    }
}

// The cursor is this adapter's business: unpadded base64url of a versioned position, bound to
// the only sort (id descending). A UUIDv7 id is the whole keyset, so no timestamp loses precision.
fn encode_cursor(id: Uuid) -> String {
    URL_SAFE_NO_PAD.encode(format!("v1:{id}"))
}

fn decode_cursor(raw: &str) -> Option<Uuid> {
    let text = String::from_utf8(URL_SAFE_NO_PAD.decode(raw).ok()?).ok()?;
    Uuid::parse_str(text.strip_prefix("v1:")?).ok()
}
```

The clock truncates to the microseconds PostgreSQL stores, and ids are UUIDv7.

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

## Problem documents

`ApiError` records a pending problem in a response extension, and the `render_problems` layer writes the RFC 9457 body, because only a layer knows the `type` base and the request path. The same layer gives a body to a bare error that another layer answered by itself.

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

/// The problem registry (http-api.md § Problem types).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ProblemType {
    MalformedRequest,
    Unauthenticated,
    Forbidden,
    NotFound,
    MethodNotAllowed,
    NotAcceptable,
    AlreadyExists,
    InvalidTransition,
    VersionConflict,
    IdempotencyInFlight,
    PreconditionFailed,
    PayloadTooLarge,
    UnsupportedMediaType,
    ValidationFailed,
    IdempotencyKeyMismatch,
    PreconditionRequired,
    RateLimited,
    Internal,
    Unavailable,
}

impl ProblemType {
    const ALL: [Self; 19] = [
        Self::MalformedRequest,
        Self::Unauthenticated,
        Self::Forbidden,
        Self::NotFound,
        Self::MethodNotAllowed,
        Self::NotAcceptable,
        Self::AlreadyExists,
        Self::InvalidTransition,
        Self::VersionConflict,
        Self::IdempotencyInFlight,
        Self::PreconditionFailed,
        Self::PayloadTooLarge,
        Self::UnsupportedMediaType,
        Self::ValidationFailed,
        Self::IdempotencyKeyMismatch,
        Self::PreconditionRequired,
        Self::RateLimited,
        Self::Internal,
        Self::Unavailable,
    ];

    fn meta(self) -> (StatusCode, &'static str, &'static str) {
        use StatusCode as S;
        match self {
            Self::MalformedRequest => (S::BAD_REQUEST, "malformed-request", "Malformed request"),
            Self::Unauthenticated => (S::UNAUTHORIZED, "unauthenticated", "Unauthenticated"),
            Self::Forbidden => (S::FORBIDDEN, "forbidden", "Forbidden"),
            Self::NotFound => (S::NOT_FOUND, "not-found", "Not found"),
            Self::MethodNotAllowed => (S::METHOD_NOT_ALLOWED, "method-not-allowed", "Method not allowed"),
            Self::NotAcceptable => (S::NOT_ACCEPTABLE, "not-acceptable", "Not acceptable"),
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
            Self::PreconditionRequired => (S::PRECONDITION_REQUIRED, "precondition-required", "Precondition required"),
            Self::RateLimited => (S::TOO_MANY_REQUESTS, "rate-limited", "Too many requests"),
            Self::Internal => (S::INTERNAL_SERVER_ERROR, "internal", "Internal error"),
            Self::Unavailable => (S::SERVICE_UNAVAILABLE, "unavailable", "Service unavailable"),
        }
    }

    /// The type for a status a layer raised by itself, when exactly one type has that status.
    fn only_for(status: StatusCode) -> Option<Self> {
        let mut matching = Self::ALL.into_iter().filter(|kind| kind.meta().0 == status);
        let first = matching.next();
        first.filter(|_| matching.next().is_none())
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
            ArticleError::InvalidCursor => Self::new(P::MalformedRequest, detail),
            ArticleError::SlugTaken => Self::new(P::AlreadyExists, detail),
            ArticleError::InvalidTransition { .. } => Self::new(P::InvalidTransition, detail),
            ArticleError::VersionConflict => Self::new(P::VersionConflict, detail),
            ArticleError::PreconditionFailed => Self::new(P::PreconditionFailed, detail),
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

/// Renders every pending problem, and gives a body to an error a layer answered by itself
/// (the deadline's bare 503, a rate limiter's 429).
pub async fn render_problems(State(base): State<Arc<str>>, req: Request, next: Next) -> Response {
    let instance = req.uri().path().to_owned();
    finalize(next.run(req).await, &base, &instance)
}

pub fn finalize(mut res: Response, base: &str, instance: &str) -> Response {
    let raised = res.status();
    let bare = (raised.is_client_error() || raised.is_server_error()) && res.body().size_hint().exact() == Some(0);
    let (kind, detail, errors) = match res.extensions_mut().remove::<Pending>() {
        Some(pending) => (Some(pending.kind), pending.detail, pending.errors),
        None if bare && raised == StatusCode::SERVICE_UNAVAILABLE => {
            (Some(ProblemType::Unavailable), "The request deadline passed".to_owned(), Vec::new())
        }
        // The registry type when exactly one has this status; otherwise the status keeps its
        // code as `about:blank`, titled by its phrase (RFC 9457 § 4.2.1).
        None if bare => {
            (ProblemType::only_for(raised), raised.canonical_reason().unwrap_or("Error").to_owned(), Vec::new())
        }
        None => return res,
    };
    let (status, kind, title) = match kind {
        Some(kind) => {
            let (status, slug, title) = kind.meta();
            (status, format!("{base}{slug}"), title)
        }
        None => (raised, "about:blank".to_owned(), raised.canonical_reason().unwrap_or("Error")),
    };
    let (mut parts, _) = res.into_parts();
    let problem = Problem { kind, title, status: status.as_u16(), detail, instance: instance.to_owned(), errors };
    parts.status = status;
    parts.headers.remove(header::CONTENT_LENGTH);
    parts.headers.insert(header::CONTENT_TYPE, HeaderValue::from_static("application/problem+json"));
    if status == StatusCode::SERVICE_UNAVAILABLE {
        parts.headers.entry(header::RETRY_AFTER).or_insert(HeaderValue::from_static("1"));
    }
    Response::from_parts(parts, Body::from(serde_json::to_vec(&problem).unwrap_or_default()))
}

#[tokio::test]
async fn a_bare_error_from_a_layer_becomes_a_problem_and_keeps_its_status() {
    let render = async |status: StatusCode| {
        let mut res = Response::new(Body::empty());
        *res.status_mut() = status;
        res.headers_mut().insert(header::RETRY_AFTER, HeaderValue::from_static("30"));
        let res = finalize(res, "https://api.example.com/problems/", "/v1/articles");
        let retry_after = res.headers()[header::RETRY_AFTER].to_str().unwrap().to_owned();
        let body = axum::body::to_bytes(res.into_body(), 4096).await.unwrap();
        let body: serde_json::Value = serde_json::from_slice(&body).unwrap();
        (body["type"].as_str().unwrap().to_owned(), body["title"].as_str().unwrap().to_owned(), retry_after)
    };
    let problem = |kind: &str, title: &str| (kind.to_owned(), title.to_owned(), "30".to_owned());
    // One registry type has 429: the layer's answer takes it, and keeps the layer's headers.
    assert_eq!(
        render(StatusCode::TOO_MANY_REQUESTS).await,
        problem("https://api.example.com/problems/rate-limited", "Too many requests")
    );
    // Several types share 409 and none has 410: the status stays, as about:blank.
    assert_eq!(render(StatusCode::CONFLICT).await, problem("about:blank", "Conflict"));
    assert_eq!(render(StatusCode::GONE).await, problem("about:blank", "Gone"));
}
```

## Extractors

Use these instead of axum's `Json`, `Path` and `Query`, whose rejections are text/plain and never pass through `ApiError`.

```rust file=src/inbound/http/extract.rs
//! Extractors whose rejections are problems: axum's own `Json`, `Path` and `Query` reject with
//! text/plain bodies that never pass through `ApiError`.
use axum::body::Bytes;
use axum::extract::rejection::{BytesRejection, PathRejection, QueryRejection};
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
    fn from(r: QueryRejection) -> Self {
        // A parameter the route does not take is a 422 naming it: an ignored filter would read
        // as an applied one. serde only says so in its message.
        let text = r.body_text();
        match text.split("unknown field `").nth(1).and_then(|rest| rest.split('`').next()) {
            Some(name) => ApiError::invalid_parameter(name, "is not a parameter of this route", "unknown_parameter"),
            None => ApiError::malformed("The query string could not be parsed"),
        }
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
        let bytes = Bytes::from_request(req, state).await.map_err(body_rejection)?;
        let de = &mut serde_json::Deserializer::from_slice(&bytes);
        match serde_path_to_error::deserialize(&mut *de) {
            Ok(value) if de.end().is_ok() => Ok(Self(value)),
            Err(e) if e.inner().is_data() => Err(ApiError::validation(vec![field_error(&e)])),
            _ => Err(ApiError::malformed("The request body is not valid JSON")),
        }
    }
}

/// The raw body, for a signature that covers the bytes as sent (webhooks): its rejections are
/// problems too, before any signature check runs.
pub struct RawBody(pub Bytes);

impl<S: Send + Sync> FromRequest<S> for RawBody {
    type Rejection = ApiError;

    async fn from_request(req: Request, state: &S) -> Result<Self, ApiError> {
        Bytes::from_request(req, state).await.map(Self).map_err(body_rejection)
    }
}

fn body_rejection(r: BytesRejection) -> ApiError {
    match r.status() {
        StatusCode::PAYLOAD_TOO_LARGE => ApiError::new(ProblemType::PayloadTooLarge, "The request body is too large"),
        _ => ApiError::malformed("The request body could not be read"),
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

## Routes

Handlers parse, call one use case and map the result. Every success body is built by `ok` or `created`, so an idempotent replay is byte-identical to the first response.

```rust file=src/inbound/http/articles.rs
use axum::extract::State;
use axum::http::{HeaderMap, header};
use axum::response::Response;
use axum::{Extension, Json};
use chrono::{DateTime, Utc};
use domain::{
    Article, ArticleId, ArticlePatch, Idempotency, Lease, NewArticle, PageRequest, PageSize, StoredResponse, UnitOfWork,
};
use serde::{Deserialize, Deserializer, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use super::AppState;
use super::extract::{AppJson, AppPath, AppQuery, Caller};
use super::idempotency::respond;
use super::problem::{ApiError, FieldError, Problems};

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
#[serde(deny_unknown_fields)]
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
pub async fn create_article<U: UnitOfWork>(
    State(state): State<AppState<U>>,
    Caller(actor): Caller,
    lease: Option<Extension<Lease>>,
    AppJson(input): AppJson<CreateArticle>,
) -> Result<Response, ApiError> {
    let input = NewArticle { slug: input.slug, title: input.title, body: input.body };
    let article = state.publishing.create(&actor, input, idempotency(lease.as_ref(), created)).await?;
    Ok(respond(created(&article)))
}

#[utoipa::path(get, path = "/v1/articles/{id}", params(("id" = Uuid, Path)),
    responses((status = 200, body = ArticleBody, headers(("ETag"))), Problems), security(("bearer" = [])))]
pub async fn get_article<U: UnitOfWork>(
    State(state): State<AppState<U>>,
    Caller(actor): Caller,
    AppPath(id): AppPath<Uuid>,
) -> Result<Response, ApiError> {
    Ok(respond(ok(&state.publishing.get(&actor, ArticleId(id)).await?)))
}

#[utoipa::path(get, path = "/v1/articles", params(ListParams),
    responses((status = 200, body = ArticlePage), Problems), security(("bearer" = [])))]
pub async fn list_articles<U: UnitOfWork>(
    State(state): State<AppState<U>>,
    Caller(actor): Caller,
    AppQuery(params): AppQuery<ListParams>,
) -> Result<Json<ArticlePage>, ApiError> {
    let size = page_size(params.limit.as_deref())?;
    let page = state.publishing.list(&actor, PageRequest { cursor: params.cursor, size }).await?;
    let meta = PageMeta { limit: size.get(), has_more: page.next_cursor.is_some(), next_cursor: page.next_cursor };
    Ok(Json(ArticlePage { data: page.items.iter().map(ArticleData::from).collect(), meta }))
}

#[utoipa::path(patch, path = "/v1/articles/{id}", request_body = UpdateArticle, params(("id" = Uuid, Path), ("If-Match" = Option<String>, Header)),
    responses((status = 200, body = ArticleBody, headers(("ETag"))), Problems), security(("bearer" = [])))]
pub async fn update_article<U: UnitOfWork>(
    State(state): State<AppState<U>>,
    Caller(actor): Caller,
    AppPath(id): AppPath<Uuid>,
    headers: HeaderMap,
    AppJson(patch): AppJson<UpdateArticle>,
) -> Result<Response, ApiError> {
    let if_match = if_match(&headers);
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
    Ok(respond(ok(&state.publishing.update(&actor, ArticleId(id), patch, if_match.as_deref()).await?)))
}

#[utoipa::path(post, path = "/v1/articles/{id}/publish", params(("id" = Uuid, Path), ("Idempotency-Key" = Option<String>, Header)),
    responses((status = 200, body = ArticleBody, headers(("ETag"))), Problems), security(("bearer" = [])))]
pub async fn publish_article<U: UnitOfWork>(
    State(state): State<AppState<U>>,
    Caller(actor): Caller,
    lease: Option<Extension<Lease>>,
    AppPath(id): AppPath<Uuid>,
) -> Result<Response, ApiError> {
    Ok(respond(ok(&state.publishing.publish(&actor, ArticleId(id), idempotency(lease.as_ref(), ok)).await?)))
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

/// RFC 9110 § 13.1.1. Absent or `*` is unconditional. Otherwise the versions named by the
/// strong tags this API issues, compared as exact strings: a weak or malformed tag names no
/// version, so the precondition fails, and it fails in the use case, after the 404 and 403
/// decisions.
fn if_match(headers: &HeaderMap) -> Option<Vec<i32>> {
    let value = headers.get(header::IF_MATCH)?.to_str().unwrap_or_default().trim();
    if value == "*" {
        return None;
    }
    let version = |tag: &str| {
        let text = tag.trim().strip_prefix('"')?.strip_suffix('"')?;
        text.parse::<i32>().ok().filter(|version| version.to_string() == text)
    };
    Some(value.split(',').filter_map(version).collect())
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
```
