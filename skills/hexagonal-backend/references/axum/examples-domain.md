# Examples: Domain Layer

Models, errors, ports, and service implementation.

## Table of Contents

1. [Domain Models](#domain-models)
2. [Domain Errors](#domain-errors)
3. [Ports](#ports)
4. [Pagination (Domain Types)](#pagination-domain-types)
5. [Service Implementation](#service-implementation)

---

## Domain Models

```rust
// src/domain/authors/models.rs
use std::fmt;
use thiserror::Error;
use uuid::Uuid;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Author {
    id: Uuid,
    name: AuthorName,
}

impl Author {
    pub fn new(id: Uuid, name: AuthorName) -> Self { Self { id, name } }
    pub fn id(&self) -> &Uuid { &self.id }
    pub fn name(&self) -> &AuthorName { &self.name }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AuthorName(String);

#[derive(Clone, Debug, Error)]
#[error("author name cannot be empty")]
pub struct AuthorNameEmptyError;

impl AuthorName {
    pub fn new(raw: &str) -> Result<Self, AuthorNameEmptyError> {
        let trimmed = raw.trim();
        if trimmed.is_empty() { Err(AuthorNameEmptyError) }
        else { Ok(Self(trimmed.to_string())) }
    }
}

// Display needed — .to_string() is called in adapters and error messages.
// Derive won't work on newtypes; implement manually.
impl fmt::Display for AuthorName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}

// AsRef<str> for zero-cost access to the inner string
impl AsRef<str> for AuthorName {
    fn as_ref(&self) -> &str { &self.0 }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CreateAuthorRequest { name: AuthorName }

impl CreateAuthorRequest {
    pub fn new(name: AuthorName) -> Self { Self { name } }
    pub fn name(&self) -> &AuthorName { &self.name }
}
```

## Domain Errors

```rust
// src/domain/authors/error.rs
use thiserror::Error;
use super::models::AuthorName;

#[derive(Debug, Error)]
pub enum CreateAuthorError {
    #[error("author with name {name} already exists")]
    Duplicate { name: AuthorName },
    #[error(transparent)]
    Unknown(#[from] anyhow::Error),
}
```

## Ports

```rust
// src/domain/authors/ports.rs
use std::future::Future;
use uuid::Uuid;
use super::error::CreateAuthorError;
use super::models::{Author, CreateAuthorRequest};
use crate::domain::pagination::CursorPage;

pub trait AuthorRepository: Clone + Send + Sync + 'static {
    fn create_author(
        &self, req: &CreateAuthorRequest,
    ) -> impl Future<Output = Result<Author, CreateAuthorError>> + Send;

    fn find_author(
        &self, id: &Uuid,
    ) -> impl Future<Output = Result<Option<Author>, anyhow::Error>> + Send;

    fn list_authors(
        &self, cursor: Option<&str>, limit: usize,
    ) -> impl Future<Output = Result<CursorPage<Author>, anyhow::Error>> + Send;
}

pub trait AuthorMetrics: Clone + Send + Sync + 'static {
    fn record_creation_success(&self) -> impl Future<Output = ()> + Send;
    fn record_creation_failure(&self) -> impl Future<Output = ()> + Send;
}

pub trait AuthorNotifier: Clone + Send + Sync + 'static {
    fn author_created(&self, author: &Author) -> impl Future<Output = ()> + Send;
}

pub trait AuthorService: Clone + Send + Sync + 'static {
    fn create_author(
        &self, req: &CreateAuthorRequest,
    ) -> impl Future<Output = Result<Author, CreateAuthorError>> + Send;

    fn find_author(
        &self, id: &Uuid,
    ) -> impl Future<Output = Result<Option<Author>, anyhow::Error>> + Send;

    fn list_authors(
        &self, cursor: Option<&str>, limit: usize,
    ) -> impl Future<Output = Result<CursorPage<Author>, anyhow::Error>> + Send;
}
```

## Pagination (Domain Types)

```rust
// src/domain/pagination.rs — shared across all domains
#[derive(Clone, Debug)]
pub struct CursorPage<T> {
    pub items: Vec<T>,
    pub next_cursor: Option<String>,
    pub has_more: bool,
}
```

## Service Implementation

```rust
// src/domain/authors/service.rs
use uuid::Uuid;
use super::error::CreateAuthorError;
use super::models::{Author, CreateAuthorRequest};
use super::ports::{AuthorMetrics, AuthorNotifier, AuthorRepository, AuthorService};
use crate::domain::pagination::CursorPage;

#[derive(Debug, Clone)]
pub struct AuthorServiceImpl<R: AuthorRepository, M: AuthorMetrics, N: AuthorNotifier> {
    repo: R, metrics: M, notifier: N,
}

impl<R: AuthorRepository, M: AuthorMetrics, N: AuthorNotifier>
    AuthorServiceImpl<R, M, N>
{
    pub fn new(repo: R, metrics: M, notifier: N) -> Self {
        Self { repo, metrics, notifier }
    }
}

impl<R: AuthorRepository, M: AuthorMetrics, N: AuthorNotifier>
    AuthorService for AuthorServiceImpl<R, M, N>
{
    async fn create_author(&self, req: &CreateAuthorRequest) -> Result<Author, CreateAuthorError> {
        let result = self.repo.create_author(req).await;
        match &result {
            Ok(author) => {
                self.metrics.record_creation_success().await;
                self.notifier.author_created(author).await;
            }
            Err(_) => self.metrics.record_creation_failure().await,
        }
        result
    }

    async fn find_author(&self, id: &Uuid) -> Result<Option<Author>, anyhow::Error> {
        self.repo.find_author(id).await
    }

    async fn list_authors(&self, cursor: Option<&str>, limit: usize) -> Result<CursorPage<Author>, anyhow::Error> {
        self.repo.list_authors(cursor, limit).await
    }
}
```
