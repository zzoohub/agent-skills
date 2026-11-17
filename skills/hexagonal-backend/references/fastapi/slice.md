# FastAPI examples: the slice

What any command or query needs: the publishing context's domain, its PostgreSQL adapter with the tenant wiring, and the HTTP routes with their problem rendering. Every `file=` block is a complete file of one project that passes its gates on the baseline in `guide.md` § 0. Idempotency, the outbox relay and the webhook are in `reliability.md`, the app factory and entrypoints in `service.md`, the tests in `tests.md`.

## Contents

1. [Kernel: errors, Actor and shared ports](#kernel-errors-actor-and-shared-ports)
2. [Model](#model)
3. [Ports and use cases](#ports-and-use-cases)
4. [Migration and schema mirror](#migration-and-schema-mirror)
5. [Connection and error translation](#connection-and-error-translation)
6. [Unit of work and repository](#unit-of-work-and-repository)
7. [Routes](#routes)
8. [Problem documents](#problem-documents)

## Kernel: errors, Actor and shared ports

The error kinds are a closed set of subclasses. `problems.py` maps each one by type, and a test fails when a new kind has no problem type, because Python cannot make that a type error.

```python file=src/newsroom/domain/kernel.py
import datetime as dt
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Protocol
from uuid import UUID


@dataclass(frozen=True, slots=True)
class Actor:
    tenant_id: UUID
    subject: str
    roles: frozenset[str] = frozenset()


class DomainError(Exception):
    """A closed set of kinds; any other exception is Unknown (500)."""


class NotFound(DomainError): ...


class Forbidden(DomainError): ...


class AlreadyExists(DomainError): ...


class InvalidTransition(DomainError): ...


class VersionConflict(DomainError): ...


class PreconditionFailed(DomainError): ...


class InvalidCursor(DomainError): ...


class Unavailable(DomainError): ...  # down or too slow: retryable, unlike Unknown


@dataclass(frozen=True, slots=True)
class FieldError:
    field: str
    code: str
    detail: str


class ValidationFailed(DomainError):
    def __init__(self, *errors: FieldError) -> None:
        super().__init__("; ".join(f"{e.field}: {e.detail}" for e in errors))
        self.errors = errors


@dataclass(frozen=True, slots=True)
class Page[T]:
    items: Sequence[T]
    next_cursor: str | None

    @property
    def has_more(self) -> bool:
        return self.next_cursor is not None


@dataclass(frozen=True, slots=True, kw_only=True)
class DomainEvent:
    tenant_id: UUID
    aggregate_type: str
    aggregate_id: UUID
    aggregate_seq: int
    event_type: str
    event_version: int
    payload: Mapping[str, str | int | None]


class Clock(Protocol):
    def now(self) -> dt.datetime: ...


class IdGenerator(Protocol):
    def new_id(self) -> UUID: ...
```

## Model

Data plus methods that decide. Time and ids arrive as arguments, so the tests in `tests.md` need no doubles. Calling a `NewType` directly is the trusted cast that rehydration uses, and the `parse_*` functions are the checked path for new input.

```python file=src/newsroom/domain/publishing/article.py
import datetime as dt
import re
from dataclasses import dataclass, replace
from enum import StrEnum
from typing import NewType
from uuid import UUID

from newsroom.domain.kernel import Actor, DomainEvent, FieldError, InvalidTransition, ValidationFailed

# parse_* validate; calling the NewType itself is the trusted cast that rehydration uses.
Slug = NewType("Slug", str)
Title = NewType("Title", str)
Body = NewType("Body", str)

SLUG_MAX, TITLE_MAX, BODY_MAX = 100, 200, 20_000  # code points, as char_length() counts them
EDITOR = "editor"
_SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")


def _invalid(field: str, code: str, detail: str) -> ValidationFailed:
    return ValidationFailed(FieldError(field, code, detail))


def parse_slug(raw: str) -> Slug:
    if len(raw) > SLUG_MAX or not _SLUG.fullmatch(raw):
        raise _invalid("slug", "invalid_format", f"must be lowercase kebab-case, 1-{SLUG_MAX} characters")
    return Slug(raw)


def parse_title(raw: str) -> Title:
    value = raw.strip()
    if not 1 <= len(value) <= TITLE_MAX or "\0" in value:  # PostgreSQL text cannot store U+0000
        raise _invalid("title", "invalid_text", f"must be 1-{TITLE_MAX} characters after trimming, no NUL")
    return Title(value)


def parse_body(raw: str) -> Body:
    if len(raw) > BODY_MAX or "\0" in raw:
        raise _invalid("body", "invalid_text", f"must be at most {BODY_MAX} characters, no NUL")
    return Body(raw)


class Status(StrEnum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


@dataclass(frozen=True, slots=True, kw_only=True)
class Article:
    """Every method returns a new value from its arguments alone: no clock, no ids, no I/O."""

    id: UUID
    tenant_id: UUID
    author_id: str
    slug: Slug
    title: Title
    body: Body
    status: Status
    version: int
    created_at: dt.datetime
    updated_at: dt.datetime
    published_at: dt.datetime | None = None

    @classmethod
    def draft(
        cls, *, article_id: UUID, author: Actor, slug: Slug, title: Title, body: Body, now: dt.datetime
    ) -> Article:
        return cls(
            id=article_id,
            tenant_id=author.tenant_id,
            author_id=author.subject,
            slug=slug,
            title=title,
            body=body,
            status=Status.DRAFT,
            version=1,
            created_at=now,
            updated_at=now,
        )

    def can_be_changed_by(self, actor: Actor) -> bool:
        return actor.subject == self.author_id or EDITOR in actor.roles

    def edit(self, *, title: Title | None, body: Body | None, now: dt.datetime) -> Article:
        return replace(
            self,
            title=self.title if title is None else title,
            body=self.body if body is None else body,
            version=self.version + 1,
            updated_at=now,
        )

    def publish(self, now: dt.datetime) -> Article:
        self._require(Status.DRAFT, "publish")
        return replace(
            self, status=Status.PUBLISHED, published_at=now, updated_at=now, version=self.version + 1
        )

    def archive(self, now: dt.datetime) -> Article:
        self._require(Status.PUBLISHED, "archive")
        return replace(self, status=Status.ARCHIVED, updated_at=now, version=self.version + 1)

    def published_event(self) -> DomainEvent:
        return DomainEvent(
            tenant_id=self.tenant_id,
            aggregate_type="article",
            aggregate_id=self.id,
            aggregate_seq=self.version,
            event_type="article.published",
            event_version=1,
            payload={
                "article_id": str(self.id),
                "slug": self.slug,
                "title": self.title,
                "author_id": self.author_id,
                "version": self.version,
                "published_at": self.published_at.isoformat() if self.published_at else None,
            },
        )

    def _require(self, status: Status, action: str) -> None:
        if self.status is not status:
            raise InvalidTransition(f"cannot {action} an article in status '{self.status}'")
```

## Ports and use cases

The repository port has no tenant parameter: the unit of work hands out one already bound to the actor's tenant. `IdempotencyLedger` is declared in `reliability.md`.

```python file=src/newsroom/domain/publishing/ports.py
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Protocol
from uuid import UUID

from newsroom.domain.idempotency import IdempotencyLedger
from newsroom.domain.kernel import Actor, DomainEvent, Page
from newsroom.domain.publishing.article import Article, Status


class ArticleRepository(Protocol):
    """Bound to one transaction and one tenant: no method takes a tenant, and none can skip it."""

    async def add(self, article: Article) -> None: ...  # AlreadyExists on a taken slug
    async def get(self, article_id: UUID) -> Article | None: ...
    async def page(self, *, cursor: str | None, limit: int) -> Page[Article]: ...  # newest first
    async def update(self, article: Article, *, expected_version: int) -> bool: ...  # False: lost the race
    async def transition(
        self, article: Article, *, from_status: Status
    ) -> Article | None: ...  # None: lost it


class Outbox(Protocol):
    async def append(self, event: DomainEvent) -> None: ...


class Inbox(Protocol):
    async def record(self, consumer: str, message_id: str) -> bool: ...  # False: a redelivery


@dataclass(frozen=True, slots=True)
class Transaction:
    articles: ArticleRepository
    outbox: Outbox
    inbox: Inbox
    idempotency: IdempotencyLedger


class UnitOfWork(Protocol):
    """One transaction, scoped to the actor's tenant. A nested run for the same tenant joins it."""

    async def run[T](self, actor: Actor, work: Callable[[Transaction], Awaitable[T]]) -> T: ...
```

Each use case takes the `Actor` first and owns its transaction. Reads run in a unit of work too, because row-level security shows a query nothing until the transaction names its tenant.

```python file=src/newsroom/domain/publishing/use_cases.py
from dataclasses import dataclass
from enum import StrEnum
from uuid import UUID

from newsroom.domain.kernel import (
    Actor,
    Clock,
    Forbidden,
    IdGenerator,
    InvalidTransition,
    NotFound,
    Page,
    PreconditionFailed,
    VersionConflict,
)
from newsroom.domain.publishing.article import Article, Status, parse_body, parse_slug, parse_title
from newsroom.domain.publishing.ports import Transaction, UnitOfWork

PAGE_MAX = 100  # the port's own bound
SYSTEM = "system"


@dataclass(frozen=True, slots=True)
class NewArticle:
    slug: str
    title: str
    body: str = ""


class ArchiveOutcome(StrEnum):
    ARCHIVED = "archived"
    DUPLICATE = "duplicate"
    NOT_FOUND = "not_found"
    NOT_PUBLISHED = "not_published"


class Articles:
    def __init__(self, uow: UnitOfWork, clock: Clock, ids: IdGenerator) -> None:
        self._uow, self._clock, self._ids = uow, clock, ids

    async def create(self, actor: Actor, new: NewArticle) -> Article:
        article = Article.draft(
            article_id=self._ids.new_id(),
            author=actor,
            slug=parse_slug(new.slug),
            title=parse_title(new.title),
            body=parse_body(new.body),
            now=self._clock.now(),
        )
        # No check for a taken slug first: two creates would both pass it. The UNIQUE constraint decides.
        await self._uow.run(actor, lambda tx: tx.articles.add(article))
        return article

    async def get(self, actor: Actor, article_id: UUID) -> Article:
        return await self._uow.run(actor, lambda tx: self._visible(tx, article_id))

    async def page(self, actor: Actor, *, cursor: str | None, limit: int) -> Page[Article]:
        bounded = max(1, min(limit, PAGE_MAX))
        return await self._uow.run(actor, lambda tx: tx.articles.page(cursor=cursor, limit=bounded))

    async def update(
        self,
        actor: Actor,
        article_id: UUID,
        *,
        title: str | None,
        body: str | None,
        if_match: frozenset[int] | None,
    ) -> Article:
        new_title = None if title is None else parse_title(title)
        new_body = None if body is None else parse_body(body)

        async def work(tx: Transaction) -> Article:
            current = await self._changeable(tx, actor, article_id)  # 404 and 403 before 412
            edited = current.edit(title=new_title, body=new_body, now=self._clock.now())
            # Check and write on the version read, never the client's: the edit derives from it.
            matched = if_match is None or current.version in if_match
            if not (matched and await tx.articles.update(edited, expected_version=current.version)):
                error = VersionConflict if if_match is None else PreconditionFailed
                raise error("the article changed; re-read it and retry")
            return edited

        return await self._uow.run(actor, work)

    async def publish(self, actor: Actor, article_id: UUID) -> Article:
        async def work(tx: Transaction) -> Article:
            current = await self._changeable(tx, actor, article_id)
            stored = await tx.articles.transition(
                current.publish(self._clock.now()), from_status=Status.DRAFT
            )
            if stored is None:  # another request moved it first: the database decided the race
                raise InvalidTransition("the article is no longer a draft")
            await tx.outbox.append(stored.published_event())  # commits with the change, or not at all
            return stored

        return await self._uow.run(actor, work)

    async def archive(self, actor: Actor, article_id: UUID, *, message_id: str) -> ArchiveOutcome:
        if SYSTEM not in actor.roles:
            raise Forbidden("only the moderation system archives articles")

        async def work(tx: Transaction) -> ArchiveOutcome:
            if not await tx.inbox.record("moderation", message_id):
                return ArchiveOutcome.DUPLICATE
            current = await tx.articles.get(article_id)
            if current is None:
                return ArchiveOutcome.NOT_FOUND  # permanent: the inbox row still commits
            if current.status is not Status.PUBLISHED:
                return ArchiveOutcome.NOT_PUBLISHED
            stored = await tx.articles.transition(
                current.archive(self._clock.now()), from_status=Status.PUBLISHED
            )
            return ArchiveOutcome.NOT_PUBLISHED if stored is None else ArchiveOutcome.ARCHIVED

        return await self._uow.run(actor, work)

    @staticmethod
    async def _visible(tx: Transaction, article_id: UUID) -> Article:
        article = await tx.articles.get(article_id)  # another tenant's row is invisible: 404
        if article is None:
            raise NotFound(f"article {article_id} not found")
        return article

    async def _changeable(self, tx: Transaction, actor: Actor, article_id: UUID) -> Article:
        article = await self._visible(tx, article_id)
        if not article.can_be_changed_by(actor):
            raise Forbidden("only the author or an editor can change this article")
        return article
```

## Migration and schema mirror

Hand-written SQL is the source of truth, one Alembic revision per file. The release step applies it as the owning role, and the application connects as `app_rw`.

```sql file=db/migrations/0001_publishing.sql
-- Runs as the owning role (MIGRATION_DATABASE_URL). The application connects as app_rw, which owns
-- nothing and cannot bypass row-level security; creating that role is cluster bootstrap, not a migration.
CREATE SCHEMA app;
GRANT USAGE ON SCHEMA app TO app_rw;

CREATE TABLE app.articles (
    id           uuid        CONSTRAINT pk_articles PRIMARY KEY,
    tenant_id    uuid        NOT NULL,
    author_id    text        NOT NULL,
    slug         text        NOT NULL,
    title        text        NOT NULL,
    body         text        NOT NULL,
    status       text        NOT NULL,
    version      integer     NOT NULL,
    created_at   timestamptz NOT NULL,
    updated_at   timestamptz NOT NULL,
    published_at timestamptz,
    CONSTRAINT uq_articles_tenant_slug UNIQUE (tenant_id, slug),
    CONSTRAINT chk_articles_slug CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug) <= 100),
    CONSTRAINT chk_articles_title CHECK (char_length(title) BETWEEN 1 AND 200),
    CONSTRAINT chk_articles_body CHECK (char_length(body) <= 20000),
    CONSTRAINT chk_articles_status CHECK (status IN ('draft', 'published', 'archived'))
);
-- Keyset pages: WHERE tenant_id = $1 AND id < $2 ORDER BY id DESC.
CREATE INDEX idx_articles_tenant_id ON app.articles (tenant_id, id);

-- The second tenant check. FORCE covers the owner too; the unit of work sets app.current_tenant
-- per transaction, and an unset or empty value matches no row.
ALTER TABLE app.articles ENABLE ROW LEVEL SECURITY, FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON app.articles TO app_rw
    USING (tenant_id = (SELECT NULLIF(current_setting('app.current_tenant', true), '')::uuid));

-- Granted by name, so a table added later is granted on purpose.
GRANT SELECT, INSERT, UPDATE, DELETE ON app.articles TO app_rw;
```

```sql file=db/migrations/0001_publishing.rollback.sql
DROP TABLE app.articles;
DROP SCHEMA app;
```

```python file=migrations/versions/0001_publishing.py
from pathlib import Path

from alembic import op

revision = "0001"
down_revision: str | None = None
SQL = Path(__file__).parents[2] / "db" / "migrations"


def upgrade() -> None:
    op.get_bind().exec_driver_sql((SQL / "0001_publishing.sql").read_text())


def downgrade() -> None:
    op.get_bind().exec_driver_sql((SQL / "0001_publishing.rollback.sql").read_text())
```

The Core tables mirror every table for typed queries, and `alembic check` fails the build when they drift. Policies, grants and CHECK constraints live only in the SQL.

```python file=src/newsroom/outbound/postgres/tables.py
from sqlalchemy import (
    Column,
    DateTime,
    Index,
    Integer,
    LargeBinary,
    MetaData,
    PrimaryKeyConstraint,
    Table,
    Text,
    UniqueConstraint,
    Uuid,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB

# A mirror of db/migrations/*.sql, the source of truth. Policies, grants and CHECKs live there only.
metadata = MetaData(schema="app")

articles = Table(
    "articles",
    metadata,
    Column("id", Uuid, nullable=False),
    Column("tenant_id", Uuid, nullable=False),
    Column("author_id", Text, nullable=False),
    Column("slug", Text, nullable=False),
    Column("title", Text, nullable=False),
    Column("body", Text, nullable=False),
    Column("status", Text, nullable=False),
    Column("version", Integer, nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
    Column("published_at", DateTime(timezone=True)),
    PrimaryKeyConstraint("id", name="pk_articles"),
    UniqueConstraint("tenant_id", "slug", name="uq_articles_tenant_slug"),
    Index("idx_articles_tenant_id", "tenant_id", "id"),
)

outbox = Table(
    "outbox",
    metadata,
    Column("id", Uuid, nullable=False, server_default=text("uuidv7()")),
    Column("tenant_id", Uuid, nullable=False),
    Column("aggregate_type", Text, nullable=False),
    Column("aggregate_id", Uuid, nullable=False),
    Column("aggregate_seq", Integer, nullable=False),
    Column("event_type", Text, nullable=False),
    Column("event_version", Integer, nullable=False),
    Column("payload", JSONB, nullable=False),
    Column("headers", JSONB, nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False),
    Column("published_at", DateTime(timezone=True)),
    Column("attempts", Integer, nullable=False),
    Column("next_attempt_at", DateTime(timezone=True), nullable=False),
    Column("last_error", Text),
    Column("dead_lettered_at", DateTime(timezone=True)),
    PrimaryKeyConstraint("id", name="pk_outbox"),
    UniqueConstraint("aggregate_id", "aggregate_seq", name="uq_outbox_aggregate_seq"),
    Index(
        "idx_outbox_pending",
        "created_at",
        postgresql_where=text("published_at IS NULL AND dead_lettered_at IS NULL"),
    ),
    Index(
        "idx_outbox_dead_lettered_at",
        "dead_lettered_at",
        postgresql_where=text("dead_lettered_at IS NOT NULL"),
    ),
)

idempotency_keys = Table(
    "idempotency_keys",
    metadata,
    Column("scope", Text, nullable=False),
    Column("key", Text, nullable=False),
    Column("request_hash", Text, nullable=False),
    Column("lease_token", Uuid, nullable=False),
    Column("locked_until", DateTime(timezone=True), nullable=False),
    Column("expires_at", DateTime(timezone=True), nullable=False),
    Column("status", Integer),
    Column("headers", JSONB),
    Column("body", LargeBinary),
    Column("completed_at", DateTime(timezone=True)),
    PrimaryKeyConstraint("scope", "key", name="pk_idempotency_keys"),
    Index("idx_idempotency_keys_expires_at", "expires_at"),
)

inbox = Table(
    "inbox",
    metadata,
    Column("consumer", Text, nullable=False),
    Column("message_id", Text, nullable=False),
    Column("received_at", DateTime(timezone=True), nullable=False),
    PrimaryKeyConstraint("consumer", "message_id", name="pk_inbox"),
)
```

## Connection and error translation

Session options bound every statement and pin UTC. `ping` is the startup round trip, and it refuses a role that would switch row-level security off without an error.

```python file=src/newsroom/outbound/postgres/database.py
import asyncio
from dataclasses import dataclass

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError, InterfaceError, OperationalError
from sqlalchemy.exc import TimeoutError as PoolTimeout
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

# Down, too slow, pool exhausted, deadlocked, cancelled by statement_timeout: the request may be retried.
TRANSIENT = (OperationalError, InterfaceError, PoolTimeout)
_BYPASSES_RLS = text("SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user")


@dataclass(frozen=True, slots=True)
class DatabaseConfig:
    url: str  # the app_rw role: it owns no table and cannot bypass row-level security
    application_name: str
    pool_size: int = 10
    max_overflow: int = 5
    pool_timeout_s: float = 3.0
    connect_timeout_s: int = 5
    statement_timeout_ms: int = 5_000
    idle_in_transaction_timeout_ms: int = 10_000
    log_parameters: bool = False


def create_engine(config: DatabaseConfig) -> AsyncEngine:
    options = (
        f"-c statement_timeout={config.statement_timeout_ms}"
        f" -c idle_in_transaction_session_timeout={config.idle_in_transaction_timeout_ms}"
        " -c timezone=UTC"
    )
    return create_async_engine(
        config.url,
        pool_size=config.pool_size,
        max_overflow=config.max_overflow,
        pool_timeout=config.pool_timeout_s,
        pool_pre_ping=True,
        hide_parameters=not config.log_parameters,
        connect_args={
            "connect_timeout": config.connect_timeout_s,
            "application_name": config.application_name,
            "options": options,
        },
    )


def sessionmaker(engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    # close_resets_only=False: a session used after its unit of work ended raises. By default it would
    # quietly open a transaction that nothing commits, on a connection that nothing returns.
    return async_sessionmaker(engine, expire_on_commit=False, close_resets_only=False)


async def ping(engine: AsyncEngine) -> None:
    """The startup round trip. It also refuses a role for which the tenant policies would be decoration."""
    async with asyncio.timeout(5), engine.connect() as connection:
        bypasses = await connection.scalar(_BYPASSES_RLS)
    if bypasses:
        raise RuntimeError("DATABASE_URL connects as a role that bypasses row-level security; use app_rw")


def constraint_name(error: DBAPIError) -> str | None:
    return getattr(getattr(error.orig, "diag", None), "constraint_name", None)
```

## Unit of work and repository

`run(actor, work)` opens the transaction, sets the tenant as its first statement and binds the ports to that session and tenant. A nested `run` for the same tenant joins through a `ContextVar`, which the idempotency wrapper relies on.

```python file=src/newsroom/outbound/postgres/uow.py
from collections.abc import Awaitable, Callable
from contextvars import ContextVar
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from newsroom.domain.kernel import Actor, Unavailable
from newsroom.domain.publishing.ports import Transaction
from newsroom.outbound.postgres.articles import PostgresArticles
from newsroom.outbound.postgres.database import TRANSIENT
from newsroom.outbound.postgres.idempotency import PostgresIdempotencyLedger
from newsroom.outbound.postgres.inbox import PostgresInbox
from newsroom.outbound.postgres.outbox import PostgresOutbox

# Transaction-local (the `true`): it ends with COMMIT or ROLLBACK, so a pooled connection never
# carries one request's tenant into the next. set_config takes a bind parameter; SET LOCAL cannot.
_SET_TENANT = text("SELECT set_config('app.current_tenant', :tenant, true)")
_current: ContextVar[tuple[UUID, Transaction] | None] = ContextVar("newsroom_transaction", default=None)


def bind(session: AsyncSession, tenant_id: UUID) -> Transaction:
    return Transaction(
        articles=PostgresArticles(session, tenant_id),
        outbox=PostgresOutbox(session),
        inbox=PostgresInbox(session),
        idempotency=PostgresIdempotencyLedger(session),
    )


class PostgresUnitOfWork:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        *,
        binder: Callable[[AsyncSession, UUID], Transaction] = bind,  # tests swap one port for a saboteur
    ) -> None:
        self._sessions, self._bind = sessions, binder

    async def run[T](self, actor: Actor, work: Callable[[Transaction], Awaitable[T]]) -> T:
        if (outer := _current.get()) is not None:
            tenant_id, tx = outer
            if tenant_id != actor.tenant_id:
                raise RuntimeError("a unit of work cannot join another tenant's transaction")
            return await work(tx)
        try:
            async with self._sessions.begin() as session:
                await session.execute(_SET_TENANT, {"tenant": str(actor.tenant_id)})
                tx = self._bind(session, actor.tenant_id)
                token = _current.set((actor.tenant_id, tx))
                try:
                    return await work(tx)
                finally:
                    _current.reset(token)
        except TRANSIENT as error:  # deadlocks included: the client retries under its idempotency key
            raise Unavailable("the database is unavailable") from error
```

```python file=src/newsroom/outbound/postgres/articles.py
import base64
import binascii
import dataclasses
from typing import Any
from uuid import UUID

from sqlalchemy import ColumnElement, RowMapping, Update, insert, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from newsroom.domain.kernel import AlreadyExists, InvalidCursor, Page
from newsroom.domain.publishing.article import Article, Status
from newsroom.outbound.postgres.database import constraint_name
from newsroom.outbound.postgres.tables import articles


def encode_cursor(article_id: UUID) -> str:
    return base64.urlsafe_b64encode(f"v1:{article_id}".encode()).rstrip(b"=").decode()


def decode_cursor(cursor: str) -> UUID:
    try:
        raw = base64.b64decode(cursor + "=" * (-len(cursor) % 4), altchars=b"-_", validate=True)
        version, _, value = raw.decode().partition(":")
        if version != "v1":
            raise InvalidCursor("unsupported cursor version")
        return UUID(value)
    except (binascii.Error, UnicodeDecodeError, ValueError) as error:
        raise InvalidCursor("the cursor is not one this API issued") from error


def _article(row: RowMapping) -> Article:  # the trusted path: stored rows are not re-validated
    return Article(**{**row, "status": Status(row["status"])})


def _values(article: Article) -> dict[str, Any]:
    return {**dataclasses.asdict(article), "status": article.status.value}


class PostgresArticles:
    """Every statement carries the tenant predicate. The planner needs it; the policy is the backstop."""

    def __init__(self, session: AsyncSession, tenant_id: UUID) -> None:
        self._session, self._mine = session, articles.c.tenant_id == tenant_id

    async def add(self, article: Article) -> None:
        try:
            await self._session.execute(insert(articles).values(_values(article)))
        except IntegrityError as error:
            if constraint_name(error) == "uq_articles_tenant_slug":
                raise AlreadyExists(f"the slug '{article.slug}' is already taken") from error
            raise  # a CHECK or the primary key: a bug, so it stays a 500

    async def get(self, article_id: UUID) -> Article | None:
        query = select(articles).where(self._mine, articles.c.id == article_id)
        row = (await self._session.execute(query)).mappings().one_or_none()
        return None if row is None else _article(row)

    async def page(self, *, cursor: str | None, limit: int) -> Page[Article]:
        query = select(articles).where(self._mine).order_by(articles.c.id.desc()).limit(limit + 1)
        if cursor is not None:
            query = query.where(articles.c.id < decode_cursor(cursor))
        rows = (await self._session.execute(query)).mappings().all()
        items = [_article(row) for row in rows[:limit]]
        more = len(rows) > limit
        return Page(items=items, next_cursor=encode_cursor(items[-1].id) if more else None)

    async def update(self, article: Article, *, expected_version: int) -> bool:
        query = (
            self._guarded(article, articles.c.version == expected_version)
            .values(
                title=article.title,
                body=article.body,
                version=article.version,
                updated_at=article.updated_at,
            )
            .returning(articles.c.id)
        )
        return (await self._session.execute(query)).scalar_one_or_none() is not None

    async def transition(self, article: Article, *, from_status: Status) -> Article | None:
        query = (
            self._guarded(article, articles.c.status == from_status.value)
            .values(
                status=article.status.value,
                published_at=article.published_at,
                updated_at=article.updated_at,
                version=articles.c.version + 1,  # from the row: the stored version is the event's sequence
            )
            .returning(*articles.c)
        )
        row = (await self._session.execute(query)).mappings().one_or_none()
        return None if row is None else _article(row)

    def _guarded(self, article: Article, guard: ColumnElement[bool]) -> Update:
        return update(articles).where(self._mine, articles.c.id == article.id, guard)
```

```python file=src/newsroom/outbound/system.py
import datetime as dt
import uuid


class SystemClock:
    def now(self) -> dt.datetime:
        return dt.datetime.now(dt.UTC)


class Uuid7Ids:
    def new_id(self) -> uuid.UUID:
        return uuid.uuid7()  # time-ordered: the keyset sorts on it
```

## Routes

Handlers parse, call one use case and map the result. Every route declares its query model with `extra="forbid"`, an empty one when it takes none, because FastAPI ignores unknown query parameters.

```python file=src/newsroom/inbound/http/context.py
from dataclasses import dataclass
from typing import TYPE_CHECKING, Annotated

from fastapi import Depends, Request

from newsroom.domain.idempotency import IdempotencyStore
from newsroom.domain.publishing.ports import UnitOfWork
from newsroom.domain.publishing.use_cases import Articles

if TYPE_CHECKING:  # annotations are evaluated lazily (PEP 649), so this import makes no cycle
    from newsroom.inbound.http.auth import Authenticator


@dataclass(frozen=True, slots=True)
class Services:
    articles: Articles
    uow: UnitOfWork
    idempotency: IdempotencyStore
    authenticator: Authenticator
    webhook_secrets: tuple[bytes, ...]


def get_services(request: Request) -> Services:
    services: Services = request.state.services
    return services


async def get_articles(request: Request) -> Articles:
    return get_services(request).articles


ArticlesDep = Annotated[Articles, Depends(get_articles)]
```

```python file=src/newsroom/inbound/http/articles.py
import datetime as dt
import re
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Header, Query, Response
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator

from newsroom.domain.publishing.article import BODY_MAX, SLUG_MAX, TITLE_MAX, Article, Status
from newsroom.domain.publishing.use_cases import PAGE_MAX, NewArticle
from newsroom.inbound.http.auth import ActorDep
from newsroom.inbound.http.context import ArticlesDep
from newsroom.inbound.http.idempotency import IdempotentRoute
from newsroom.inbound.http.problems import ProblemDocument

TitleIn = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=TITLE_MAX)]
BodyIn = Annotated[str, Field(max_length=BODY_MAX)]
_ETAG = re.compile(r'"([1-9][0-9]{0,9})"')  # a strong tag as issued: "01" or 11 digits match none
_ERRORS = (400, 401, 403, 404, 409, 412, 413, 415, 422, 500, 503)

router = APIRouter(
    prefix="/v1/articles",
    tags=["articles"],
    route_class=IdempotentRoute,
    responses={status: {"model": ProblemDocument} for status in _ERRORS},
)


class ArticleIn(BaseModel):
    model_config = ConfigDict(extra="forbid")  # tenant, author, status never come from a body

    slug: Annotated[str, Field(min_length=1, max_length=SLUG_MAX)]
    title: TitleIn
    body: BodyIn = ""


class ArticlePatch(BaseModel):
    """JSON Merge Patch: absent = unchanged; "body": null clears it; "title": null is a 422."""

    model_config = ConfigDict(extra="forbid")

    title: TitleIn | None = None
    body: BodyIn | None = None

    @field_validator("title")
    @classmethod
    def _title_not_null(cls, value: str | None) -> str:
        if value is None:
            raise ValueError("title cannot be null")
        return value


class NoQuery(BaseModel):
    """FastAPI ignores unknown query parameters, and a client reads an ignored filter as an applied one."""

    model_config = ConfigDict(extra="forbid")


class ListQuery(NoQuery):
    limit: Annotated[int, Field(ge=1)] = 20
    cursor: str | None = None  # undecodable: 400 from the adapter


class ArticleOut(BaseModel):
    id: UUID
    slug: str
    title: str
    body: str
    status: Status
    author_id: str
    version: int
    created_at: dt.datetime
    updated_at: dt.datetime
    published_at: dt.datetime | None


class ArticleEnvelope(BaseModel):
    data: ArticleOut


class PageMeta(BaseModel):
    limit: int
    next_cursor: str | None
    has_more: bool


class ArticlePage(BaseModel):
    data: list[ArticleOut]
    meta: PageMeta


Strict = Annotated[NoQuery, Query()]  # a route that takes no query parameter says so


def _envelope(response: Response, article: Article) -> ArticleEnvelope:
    response.headers["ETag"] = f'"{article.version}"'
    return ArticleEnvelope(data=ArticleOut.model_validate(article, from_attributes=True))


def _if_match(header: str | None) -> frozenset[int] | None:
    """RFC 9110 strong comparison: `*` or no header sets no condition; weak or foreign tags match none."""
    if header is None or header.strip() == "*":
        return None
    return frozenset(int(m[1]) for tag in header.split(",") if (m := _ETAG.fullmatch(tag.strip())))


@router.post("", status_code=201)
async def create_article(
    new: ArticleIn, actor: ActorDep, articles: ArticlesDep, response: Response, _: Strict
) -> ArticleEnvelope:
    article = await articles.create(actor, NewArticle(new.slug, new.title, new.body))
    response.headers["Location"] = f"/v1/articles/{article.id}"
    return _envelope(response, article)


@router.get("/{article_id}")
async def get_article(
    article_id: UUID, actor: ActorDep, articles: ArticlesDep, response: Response, _: Strict
) -> ArticleEnvelope:
    return _envelope(response, await articles.get(actor, article_id))


@router.get("")
async def list_articles(
    actor: ActorDep, articles: ArticlesDep, query: Annotated[ListQuery, Query()]
) -> ArticlePage:
    used = min(query.limit, PAGE_MAX)  # clamped; meta.limit reports it
    page = await articles.page(actor, cursor=query.cursor, limit=used)
    meta = PageMeta(limit=used, next_cursor=page.next_cursor, has_more=page.has_more)
    return ArticlePage(
        data=[ArticleOut.model_validate(a, from_attributes=True) for a in page.items], meta=meta
    )


@router.patch("/{article_id}")
async def update_article(
    article_id: UUID,
    patch: ArticlePatch,
    actor: ActorDep,
    articles: ArticlesDep,
    response: Response,
    _: Strict,
    if_match: Annotated[str | None, Header()] = None,
) -> ArticleEnvelope:
    body = (patch.body or "") if "body" in patch.model_fields_set else None
    expected = _if_match(if_match)
    article = await articles.update(actor, article_id, title=patch.title, body=body, if_match=expected)
    return _envelope(response, article)


@router.post("/{article_id}/publish")
async def publish_article(
    article_id: UUID, actor: ActorDep, articles: ArticlesDep, response: Response, _: Strict
) -> ArticleEnvelope:
    return _envelope(response, await articles.publish(actor, article_id))
```

## Problem documents

One renderer serves domain errors, validation failures, Starlette's `HTTPException` and our own `Problem`. Anything else is re-raised for the edge middleware in `service.md`, which logs it once and answers a generic 500.

```python file=src/newsroom/inbound/http/problems.py
import logging
from collections.abc import Mapping, Sequence
from http import HTTPStatus
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import iter_route_contexts
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.routing import Match

from newsroom.domain import kernel

log = logging.getLogger(__name__)
REGISTRY = {  # slug -> status; the title is the capitalized slug unless _TITLES says otherwise
    "malformed-request": 400,
    "unauthenticated": 401,
    "forbidden": 403,
    "not-found": 404,
    "method-not-allowed": 405,
    "already-exists": 409,
    "invalid-transition": 409,
    "version-conflict": 409,
    "idempotency-in-flight": 409,
    "precondition-failed": 412,
    "payload-too-large": 413,
    "unsupported-media-type": 415,
    "validation-failed": 422,
    "idempotency-key-mismatch": 422,
    "rate-limited": 429,
    "internal": 500,
    "unavailable": 503,
}
_TITLES = {  # registry titles that are not the capitalized slug
    "idempotency-in-flight": "Request in progress",
    "rate-limited": "Too many requests",
    "internal": "Internal error",
    "unavailable": "Service unavailable",
}
# A status the framework or a library raises takes its registry type when exactly one type has it.
_BY_STATUS = {status: slug for slug, status in REGISTRY.items() if list(REGISTRY.values()).count(status) == 1}
BY_KIND: dict[type[kernel.DomainError], str] = {  # a test fails when a new kind is missing here
    kernel.NotFound: "not-found",
    kernel.Forbidden: "forbidden",
    kernel.AlreadyExists: "already-exists",
    kernel.InvalidTransition: "invalid-transition",
    kernel.VersionConflict: "version-conflict",
    kernel.PreconditionFailed: "precondition-failed",
    kernel.InvalidCursor: "malformed-request",
}
RETRY_SOON = {"Retry-After": "1"}


class ProblemItem(BaseModel):
    pointer: str | None = None
    parameter: str | None = None
    detail: str
    code: str


class ProblemDocument(BaseModel):
    type: str
    title: str
    status: int
    detail: str
    instance: str
    errors: list[ProblemItem] | None = None


class Problem(Exception):
    def __init__(
        self,
        slug: str,
        detail: str,
        *,
        errors: Sequence[Mapping[str, str]] = (),
        headers: Mapping[str, str] | None = None,
        status: int | None = None,  # with slug "about:blank": a status outside the registry
    ) -> None:
        super().__init__(detail)
        self.slug, self.detail, self.errors, self.headers = slug, detail, errors, headers
        self.status = status or REGISTRY[slug]


def render(base_uri: str, path: str, problem: Problem) -> JSONResponse:
    registered = problem.slug in REGISTRY
    content: dict[str, Any] = {
        "type": base_uri + problem.slug if registered else "about:blank",
        "title": _TITLES.get(problem.slug, problem.slug.replace("-", " ").capitalize())
        if registered
        else HTTPStatus(problem.status).phrase,  # RFC 9457: about:blank is titled by its status phrase
        "status": problem.status,
        "detail": problem.detail,
        "instance": path,  # never the query string
    }
    if problem.errors:
        content["errors"] = list(problem.errors)
    return JSONResponse(content, problem.status, problem.headers, "application/problem+json")


def _pointer(path: Sequence[str | int]) -> str:  # RFC 6901, as a URI fragment
    return "#" + "".join("/" + str(p).replace("~", "~0").replace("/", "~1") for p in path)


def _parsed_as_json(content_type: str) -> bool:  # FastAPI's rule: application/json or application/*+json
    media = content_type.partition(";")[0].strip().lower()
    return media.startswith("application/") and (media == "application/json" or media.endswith("+json"))


def from_validation(request: Request, error: RequestValidationError) -> Problem:
    """Unreadable -> 400, not JSON -> 415, read but wrong -> 422 with errors[]."""
    issues = error.errors()
    for issue in issues:
        if issue["type"] == "json_invalid":
            return Problem("malformed-request", "The body is not valid JSON")
        if issue["loc"][0] == "path":
            return Problem("malformed-request", f"Path parameter '{issue['loc'][-1]}' is not valid")
        if issue["loc"] == ("body",) and not _parsed_as_json(request.headers.get("content-type", "")):
            return Problem("unsupported-media-type", "Send the body as application/json")
    items = [
        {"pointer": _pointer(i["loc"][1:]), "detail": i["msg"], "code": i["type"]}
        if i["loc"][0] == "body"
        else {"parameter": str(i["loc"][-1]), "detail": i["msg"], "code": i["type"]}
        for i in issues
    ]
    return Problem("validation-failed", f"{len(items)} input value(s) failed validation", errors=items)


def from_exception(request: Request, error: Exception) -> Problem:
    match error:
        case Problem():
            return error
        case RequestValidationError():
            return from_validation(request, error)
        case kernel.ValidationFailed():
            items = [{"pointer": f"#/{e.field}", "detail": e.detail, "code": e.code} for e in error.errors]
            return Problem("validation-failed", str(error), errors=items)
        case kernel.Unavailable():
            log.warning("dependency unavailable", exc_info=error)
            return Problem("unavailable", "Temporarily unable to complete the request", headers=RETRY_SOON)
        case kernel.DomainError() if type(error) in BY_KIND:
            return Problem(BY_KIND[type(error)], str(error))
        case StarletteHTTPException():
            return _from_http(request, error)
    raise error  # Unknown: the edge middleware logs it once and answers 500


def _from_http(request: Request, error: StarletteHTTPException) -> Problem:
    status = error.status_code
    if status == HTTPStatus.METHOD_NOT_ALLOWED:  # Starlette's Allow names one route only
        routes = iter_route_contexts(request.app.routes)
        allowed = {m for r in routes if r.matches(request.scope)[0] is Match.PARTIAL for m in r.methods or ()}
        return Problem("method-not-allowed", str(error.detail), headers={"Allow": ", ".join(sorted(allowed))})
    retry = RETRY_SOON if status in {HTTPStatus.TOO_MANY_REQUESTS, HTTPStatus.SERVICE_UNAVAILABLE} else {}
    slug = _BY_STATUS.get(status, "about:blank")  # a 409, a 410, a 422: several types or none
    return Problem(slug, str(error.detail), headers={**retry, **(error.headers or {})}, status=status)


def respond(request: Request, error: Exception) -> JSONResponse:
    return render(request.app.state.problem_base_uri, request.url.path, from_exception(request, error))


async def _handle(request: Request, error: Exception) -> JSONResponse:
    return respond(request, error)


def install(app: FastAPI, base_uri: str) -> None:
    app.state.problem_base_uri = base_uri
    for kind in (Problem, kernel.DomainError, RequestValidationError, StarletteHTTPException):
        app.add_exception_handler(kind, _handle)
```
