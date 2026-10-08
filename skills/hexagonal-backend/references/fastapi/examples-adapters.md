# FastAPI Examples: Adapters

Outbound: PostgreSQL 18 through SQLAlchemy Core and psycopg 3. Inbound: FastAPI and a signed webhook. Each block is a complete file.

## Contents

1. [Schema and migration](#schema-and-migration)
2. [Table mirror](#table-mirror)
3. [Engine and driver errors](#engine-and-driver-errors)
4. [Article repository and inbox](#article-repository-and-inbox)
5. [Unit of work](#unit-of-work)
6. [Outbox and relay](#outbox-and-relay)
7. [Idempotency store](#idempotency-store)
8. [Clock and ids](#clock-and-ids)
9. [Problem documents](#problem-documents)
10. [Middleware](#middleware)
11. [Services and dependencies](#services-and-dependencies)
12. [Authentication](#authentication)
13. [Idempotency wrapper](#idempotency-wrapper)
14. [Article routes](#article-routes)
15. [Moderation webhook](#moderation-webhook)
16. [App factory and probes](#app-factory-and-probes)

## Schema and migration

```sql file=db/migrations/0001_publishing.sql
CREATE TABLE articles (
    id           uuid PRIMARY KEY,
    tenant_id    uuid NOT NULL,
    author_id    text NOT NULL,
    slug         text NOT NULL,
    title        text NOT NULL,
    body         text NOT NULL,
    status       text NOT NULL,
    version      integer NOT NULL,
    created_at   timestamptz NOT NULL,
    updated_at   timestamptz NOT NULL,
    published_at timestamptz,
    CONSTRAINT articles_tenant_slug_key UNIQUE (tenant_id, slug),
    CONSTRAINT articles_slug_check CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug) <= 100),
    CONSTRAINT articles_title_check CHECK (char_length(title) BETWEEN 1 AND 200),
    CONSTRAINT articles_body_check CHECK (char_length(body) <= 20000),
    CONSTRAINT articles_status_check CHECK (status IN ('draft', 'published', 'archived'))
);
CREATE INDEX articles_tenant_id_id_idx ON articles (tenant_id, id);

CREATE TABLE outbox (
    id               uuid PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        uuid NOT NULL,
    aggregate_type   text NOT NULL,
    aggregate_id     uuid NOT NULL,
    aggregate_seq    integer NOT NULL,
    event_type       text NOT NULL,
    event_version    integer NOT NULL,
    payload          jsonb NOT NULL,
    headers          jsonb NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    published_at     timestamptz,
    attempts         integer NOT NULL DEFAULT 0,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    last_error       text,
    dead_lettered_at timestamptz,
    CONSTRAINT outbox_aggregate_seq_key UNIQUE (aggregate_id, aggregate_seq)
);
CREATE INDEX outbox_pending_idx ON outbox (next_attempt_at)
    WHERE published_at IS NULL AND dead_lettered_at IS NULL;

CREATE TABLE idempotency_keys (
    scope        text NOT NULL,
    key          text NOT NULL,
    request_hash text NOT NULL,
    lease_token  uuid NOT NULL,
    locked_until timestamptz NOT NULL,
    expires_at   timestamptz NOT NULL,
    status       integer,
    headers      jsonb,
    body         bytea,
    completed_at timestamptz,
    PRIMARY KEY (scope, key)
);
CREATE INDEX idempotency_keys_expires_at_idx ON idempotency_keys (expires_at);

CREATE TABLE inbox (
    consumer    text NOT NULL,
    message_id  text NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (consumer, message_id)
);
```

```sql file=db/migrations/0001_publishing.rollback.sql
DROP TABLE inbox;
DROP TABLE idempotency_keys;
DROP TABLE outbox;
DROP TABLE articles;
```

## Table mirror

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

metadata = MetaData()

articles = Table(
    "articles",
    metadata,
    Column("id", Uuid, primary_key=True),
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
    UniqueConstraint("tenant_id", "slug", name="articles_tenant_slug_key"),
    Index("articles_tenant_id_id_idx", "tenant_id", "id"),
)

outbox = Table(
    "outbox",
    metadata,
    Column("id", Uuid, primary_key=True, server_default=text("uuidv7()")),
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
    UniqueConstraint("aggregate_id", "aggregate_seq", name="outbox_aggregate_seq_key"),
    Index(
        "outbox_pending_idx",
        "next_attempt_at",
        postgresql_where=text("published_at IS NULL AND dead_lettered_at IS NULL"),
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
    PrimaryKeyConstraint("scope", "key"),
    Index("idempotency_keys_expires_at_idx", "expires_at"),
)

inbox = Table(
    "inbox",
    metadata,
    Column("consumer", Text, nullable=False),
    Column("message_id", Text, nullable=False),
    Column("received_at", DateTime(timezone=True), nullable=False),
    PrimaryKeyConstraint("consumer", "message_id"),
)
```

## Engine and driver errors

```python file=src/newsroom/outbound/postgres/database.py
import asyncio
from dataclasses import dataclass

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError, InterfaceError, OperationalError
from sqlalchemy.exc import TimeoutError as PoolTimeout
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

RETRYABLE = frozenset({"40001", "40P01"})  # serialization failure, deadlock
TRANSIENT = (OperationalError, InterfaceError, PoolTimeout)  # down, too slow, pool exhausted


@dataclass(frozen=True, slots=True)
class DatabaseConfig:
    url: str
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
    return async_sessionmaker(engine, expire_on_commit=False)


async def ping(engine: AsyncEngine) -> None:
    async with asyncio.timeout(5), engine.connect() as connection:
        await connection.execute(text("SELECT 1"))


def sqlstate(error: DBAPIError) -> str | None:
    return getattr(error.orig, "sqlstate", None)


def constraint_name(error: DBAPIError) -> str | None:
    return getattr(getattr(error.orig, "diag", None), "constraint_name", None)
```

## Article repository and inbox

```python file=src/newsroom/outbound/postgres/articles.py
import base64
import binascii
import dataclasses
from typing import Any
from uuid import UUID

from sqlalchemy import ColumnElement, RowMapping, Update, insert, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from newsroom.domain.kernel import AlreadyExists, InvalidCursor, Page
from newsroom.domain.publishing.article import Article, Status
from newsroom.outbound.postgres.database import constraint_name
from newsroom.outbound.postgres.tables import articles, inbox


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


def _article(row: RowMapping) -> Article:
    return Article(**{**row, "status": Status(row["status"])})


def _values(article: Article) -> dict[str, Any]:
    return {**dataclasses.asdict(article), "status": article.status.value}


def _update(article: Article, condition: ColumnElement[bool]) -> Update:
    return update(articles).where(
        articles.c.tenant_id == article.tenant_id, articles.c.id == article.id, condition
    )


class PostgresArticles:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add(self, article: Article) -> None:
        try:
            await self._session.execute(insert(articles).values(_values(article)))
        except IntegrityError as error:
            if constraint_name(error) == "articles_tenant_slug_key":
                raise AlreadyExists(f"the slug '{article.slug}' is already taken") from error
            raise

    async def get(self, tenant_id: UUID, article_id: UUID) -> Article | None:
        query = select(articles).where(articles.c.tenant_id == tenant_id, articles.c.id == article_id)
        row = (await self._session.execute(query)).mappings().one_or_none()
        return None if row is None else _article(row)

    async def page(self, tenant_id: UUID, *, cursor: str | None, limit: int) -> Page[Article]:
        query = (
            select(articles)
            .where(articles.c.tenant_id == tenant_id)
            .order_by(articles.c.id.desc())
            .limit(limit + 1)
        )
        if cursor is not None:
            query = query.where(articles.c.id < decode_cursor(cursor))
        rows = (await self._session.execute(query)).mappings().all()
        items = [_article(row) for row in rows[:limit]]
        more = len(rows) > limit
        return Page(items=items, next_cursor=encode_cursor(items[-1].id) if more else None)

    async def update(self, article: Article, *, expected_version: int) -> bool:
        query = (
            _update(article, articles.c.version == expected_version)
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
            _update(article, articles.c.status == from_status.value)
            .values(
                status=article.status.value,
                published_at=article.published_at,
                updated_at=article.updated_at,
                version=articles.c.version + 1,
            )
            .returning(*articles.c)
        )
        row = (await self._session.execute(query)).mappings().one_or_none()
        return None if row is None else _article(row)


class PostgresInbox:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def record(self, consumer: str, message_id: str) -> bool:
        query = (
            pg_insert(inbox)
            .values(consumer=consumer, message_id=message_id)
            .on_conflict_do_nothing()
            .returning(inbox.c.message_id)
        )
        return (await self._session.execute(query)).scalar_one_or_none() is not None
```

## Unit of work

```python file=src/newsroom/outbound/postgres/uow.py
import asyncio
import random
from collections.abc import Awaitable, Callable
from contextvars import ContextVar

from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from newsroom.domain.kernel import Unavailable
from newsroom.domain.publishing.ports import Transaction
from newsroom.outbound.postgres.articles import PostgresArticles, PostgresInbox
from newsroom.outbound.postgres.database import RETRYABLE, TRANSIENT, sqlstate
from newsroom.outbound.postgres.idempotency import PostgresIdempotencyLedger
from newsroom.outbound.postgres.outbox import PostgresOutbox

_current: ContextVar[Transaction | None] = ContextVar("newsroom_transaction", default=None)


def bind(session: AsyncSession) -> Transaction:
    return Transaction(
        articles=PostgresArticles(session),
        outbox=PostgresOutbox(session),
        inbox=PostgresInbox(session),
        idempotency=PostgresIdempotencyLedger(session),
    )


class PostgresUnitOfWork:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        *,
        binder: Callable[[AsyncSession], Transaction] = bind,
        attempts: int = 3,
    ) -> None:
        self._sessions, self._bind, self._attempts = sessions, binder, attempts

    async def run[T](self, work: Callable[[Transaction], Awaitable[T]]) -> T:
        if (outer := _current.get()) is not None:
            return await work(outer)
        attempt = 1
        while True:
            try:
                async with self._sessions.begin() as session:
                    tx = self._bind(session)
                    token = _current.set(tx)
                    try:
                        return await work(tx)
                    finally:
                        _current.reset(token)
            except DBAPIError as error:
                if sqlstate(error) in RETRYABLE and attempt < self._attempts:
                    await asyncio.sleep(random.uniform(0, 0.05 * 2**attempt))  # noqa: S311
                    attempt += 1
                    continue
                if isinstance(error, TRANSIENT):
                    raise Unavailable("the database is unavailable") from error
                raise
            except TRANSIENT as error:  # pool timeout is not a DBAPIError
                raise Unavailable("the database is unavailable") from error
```

## Outbox and relay

```python file=src/newsroom/outbound/postgres/outbox.py
import asyncio
import contextlib
import logging
import random
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any, Protocol
from uuid import UUID

from opentelemetry import propagate
from sqlalchemy import insert, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from newsroom.domain.kernel import DomainEvent
from newsroom.outbound.postgres.database import TRANSIENT
from newsroom.outbound.postgres.tables import outbox

log = logging.getLogger(__name__)


class PostgresOutbox:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def append(self, event: DomainEvent) -> None:
        headers = {"tenant_id": str(event.tenant_id)}
        propagate.inject(headers)
        values = {name: getattr(event, name) for name in event.__dataclass_fields__}
        await self._session.execute(
            insert(outbox).values(values | {"payload": dict(event.payload), "headers": headers})
        )


@dataclass(frozen=True, slots=True, kw_only=True)
class OutboxMessage:
    id: UUID
    aggregate_id: UUID
    aggregate_seq: int
    event_type: str
    event_version: int
    payload: Mapping[str, Any]
    headers: Mapping[str, str]
    attempts: int


class EventPublisher(Protocol):
    async def publish(self, message: OutboxMessage) -> None: ...


class LogPublisher:  # a stand-in for your broker's client
    async def publish(self, message: OutboxMessage) -> None:
        log.info("event published", extra={"event_id": str(message.id), "event_type": message.event_type})


# Only a head is claimable (no earlier row of its aggregate pending): a failing row blocks its
# successors until dead-lettered.
_CLAIM = text("""
WITH heads AS (
    SELECT o.id FROM outbox o
    WHERE o.published_at IS NULL AND o.dead_lettered_at IS NULL AND o.next_attempt_at <= now()
      AND NOT EXISTS (
          SELECT 1 FROM outbox e
          WHERE e.aggregate_id = o.aggregate_id AND e.aggregate_seq < o.aggregate_seq
            AND e.published_at IS NULL AND e.dead_lettered_at IS NULL)
    ORDER BY o.created_at, o.id
    LIMIT :batch
    FOR UPDATE SKIP LOCKED)
UPDATE outbox SET next_attempt_at = now() + make_interval(secs => :lease)
FROM heads WHERE outbox.id = heads.id
RETURNING outbox.id, aggregate_id, aggregate_seq, event_type, event_version, payload, headers, attempts
""")
_PUBLISHED = text("UPDATE outbox SET published_at = now(), last_error = NULL WHERE id = :id")
_FAILED = text("""
UPDATE outbox SET attempts = attempts + 1, last_error = :error,
    next_attempt_at = now() + make_interval(secs => :delay),
    dead_lettered_at = CASE WHEN attempts + 1 >= :max_attempts THEN now() END
WHERE id = :id
""")
_OLDEST = text("""
SELECT extract(epoch FROM now() - min(created_at)) FROM outbox
WHERE published_at IS NULL AND dead_lettered_at IS NULL
""")


class OutboxRelay:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        publisher: EventPublisher,
        *,
        batch: int = 50,
        lease_s: float = 30.0,
        max_attempts: int = 10,
        backoff_base_s: float = 1.0,
    ) -> None:
        self.sessions, self.publisher, self.batch = sessions, publisher, batch
        self.lease_s, self.max_attempts, self.backoff_base_s = lease_s, max_attempts, backoff_base_s
        self.oldest_pending_age_s = 0.0  # freshness: alert on it

    async def run_once(self) -> int:
        async with self.sessions.begin() as session:
            rows = await session.execute(_CLAIM, {"batch": self.batch, "lease": self.lease_s})
            claimed = [OutboxMessage(**row) for row in rows.mappings()]
        for message in claimed:
            try:
                await self.publisher.publish(message)
            except Exception as error:  # noqa: BLE001 - retried, then dead-lettered
                ceiling = min(300.0, self.backoff_base_s * 2**message.attempts)
                delay = random.uniform(0, ceiling)  # noqa: S311 - full jitter
                failed = {
                    "id": message.id,
                    "error": repr(error)[:500],
                    "delay": delay,
                    "max_attempts": self.max_attempts,
                }
                log.warning("outbox publish failed", extra={"event_id": str(message.id)})
                async with self.sessions.begin() as session:
                    await session.execute(_FAILED, failed)
            else:
                async with self.sessions.begin() as session:
                    await session.execute(_PUBLISHED, {"id": message.id})
        return len(claimed)

    async def run(self, stop: asyncio.Event, *, idle_s: float = 1.0) -> None:
        """Claim until stopped; the batch in hand finishes first. An outage pauses it, never ends it."""
        outage = 0
        while not stop.is_set():
            try:
                claimed = await self.run_once()
                async with self.sessions() as session:
                    self.oldest_pending_age_s = float(await session.scalar(_OLDEST) or 0)
                outage, pause = 0, idle_s
            except TRANSIENT:
                outage = min(outage + 1, 10)  # capped: 2.0**1024 overflows
                claimed, pause = 0, random.uniform(0, min(30.0, idle_s * 2**outage))  # noqa: S311
                log.warning("outbox relay backing off", exc_info=True)
            if not claimed:
                with contextlib.suppress(TimeoutError):
                    await asyncio.wait_for(stop.wait(), pause)
```

## Idempotency store

```python file=src/newsroom/outbound/postgres/idempotency.py
import datetime as dt
from uuid import UUID

from sqlalchemy import ColumnElement, delete, func, literal, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from newsroom.domain.idempotency import (
    Acquired,
    InFlight,
    LeaseLost,
    Mismatch,
    NewExecution,
    Replay,
    StoredResponse,
)
from newsroom.outbound.postgres.tables import idempotency_keys as keys

LEASE = dt.timedelta(seconds=30)  # > the request deadline
TTL = dt.timedelta(hours=24)  # > the longest client retry horizon


def _key(scope: str, key: str) -> tuple[ColumnElement[bool], ColumnElement[bool]]:
    return (keys.c.scope == scope, keys.c.key == key)


class PostgresIdempotencyStore:
    def __init__(self, sessions: async_sessionmaker[AsyncSession]) -> None:
        self._sessions = sessions

    async def acquire(self, scope: str, key: str, request_hash: str) -> Acquired:
        claim = (
            insert(keys)
            .values(
                scope=scope,
                key=key,
                request_hash=request_hash,
                lease_token=func.gen_random_uuid(),
                locked_until=func.now() + LEASE,
                expires_at=func.now() + TTL,
            )
            .on_conflict_do_nothing()
            .returning(keys.c.lease_token)
        )
        takeover = (  # execution is granted only by a write: our INSERT, or this on an expired lease
            update(keys)
            .where(*_key(scope, key), keys.c.completed_at.is_(None), keys.c.locked_until < func.now())
            .values(lease_token=func.gen_random_uuid(), locked_until=func.now() + LEASE)
            .returning(keys.c.lease_token)
        )
        for _ in range(3):  # the row can vanish (release, purge) between INSERT and SELECT
            async with self._sessions.begin() as session:
                if (lease := await session.scalar(claim)) is not None:
                    return NewExecution(lease)
                row = (await session.execute(select(keys).where(*_key(scope, key)))).one_or_none()
                if row is None:
                    continue
                if row.request_hash != request_hash:
                    return Mismatch()
                if row.completed_at is not None:  # not `if row.body`: b"" is a valid body
                    return Replay(StoredResponse(row.status, row.headers, row.body))
                lease = await session.scalar(takeover)
                return InFlight() if lease is None else NewExecution(lease)
        return InFlight()

    async def release(self, scope: str, key: str, lease: UUID) -> None:
        async with self._sessions.begin() as session:
            await session.execute(
                delete(keys).where(
                    *_key(scope, key), keys.c.lease_token == lease, keys.c.completed_at.is_(None)
                )
            )

    async def purge_expired(self) -> int:
        async with self._sessions.begin() as session:
            purged = delete(keys).where(keys.c.expires_at < func.now()).returning(keys.c.key).cte()
            return await session.scalar(select(func.count()).select_from(purged)) or 0


class PostgresIdempotencyLedger:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def complete(self, scope: str, key: str, lease: UUID, response: StoredResponse) -> None:
        query = (
            update(keys)
            .where(*_key(scope, key), keys.c.lease_token == lease, keys.c.completed_at.is_(None))
            .values(
                status=response.status,
                headers=dict(response.headers),
                body=response.body,
                completed_at=func.now(),
            )
            .returning(literal(1))
        )
        if await self._session.scalar(query) is None:
            raise LeaseLost(key)
```

## Clock and ids

```python file=src/newsroom/outbound/system.py
import datetime as dt
import uuid


class SystemClock:
    def now(self) -> dt.datetime:
        return dt.datetime.now(dt.UTC)


class Uuid7Ids:
    def new_id(self) -> uuid.UUID:
        return uuid.uuid7()  # 3.14+; time-ordered: the keyset sorts on it
```

## Problem documents

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
_HTTP = {  # what the framework raises; other statuses keep their phrase
    400: "malformed-request",
    401: "unauthenticated",
    404: "not-found",
    413: "payload-too-large",
    429: "rate-limited",
    500: "internal",
    503: "unavailable",
}
_DOMAIN: dict[type[kernel.DomainError], str] = {
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
        status: int | None = None,  # a status outside the registry
    ) -> None:
        super().__init__(detail)
        self.slug, self.detail, self.errors, self.headers = slug, detail, errors, headers
        self.status = status or REGISTRY[slug]


def render(base_uri: str, path: str, problem: Problem) -> JSONResponse:
    registered = problem.slug in REGISTRY  # an unregistered framework status: about:blank + its phrase
    content: dict[str, Any] = {
        "type": base_uri + problem.slug if registered else "about:blank",
        "title": _TITLES.get(problem.slug, problem.slug.replace("-", " ").capitalize())
        if registered
        else HTTPStatus(problem.status).phrase,
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
        case kernel.DomainError() if type(error) in _DOMAIN:
            return Problem(_DOMAIN[type(error)], str(error))
        case StarletteHTTPException():
            return _from_http(request, error)
    raise error  # Unknown: the edge middleware logs it once and answers 500


def _from_http(request: Request, error: StarletteHTTPException) -> Problem:
    status = error.status_code
    if status == HTTPStatus.METHOD_NOT_ALLOWED:  # Starlette's Allow names one route only
        routes = iter_route_contexts(request.app.routes)
        allowed = {m for r in routes if r.matches(request.scope)[0] is Match.PARTIAL for m in r.methods or ()}
        return Problem("method-not-allowed", str(error.detail), headers={"Allow": ", ".join(sorted(allowed))})
    slug = _HTTP.get(status) or HTTPStatus(status).phrase.lower().replace(" ", "-")
    return Problem(slug, str(error.detail), headers=error.headers, status=status)


def respond(request: Request, error: Exception) -> JSONResponse:
    return render(request.app.state.problem_base_uri, request.url.path, from_exception(request, error))


async def _handle(request: Request, error: Exception) -> JSONResponse:
    return respond(request, error)


def install(app: FastAPI, base_uri: str) -> None:
    app.state.problem_base_uri = base_uri
    for kind in (Problem, kernel.DomainError, RequestValidationError, StarletteHTTPException):
        app.add_exception_handler(kind, _handle)
```

## Middleware

```python file=src/newsroom/inbound/http/middleware.py
import asyncio
import logging
import re
import uuid

from opentelemetry import trace
from starlette.datastructures import Headers, MutableHeaders
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.types import ASGIApp, Message, Receive, Scope, Send
from structlog.contextvars import bound_contextvars

from newsroom.inbound.http.problems import RETRY_SOON, Problem, render

log = logging.getLogger(__name__)
_REQUEST_ID = re.compile(r"[A-Za-z0-9._:-]{1,128}")
SECURITY_HEADERS = (
    ("cache-control", "no-store"),
    ("strict-transport-security", "max-age=63072000; includeSubDomains"),
    ("x-content-type-options", "nosniff"),
    ("content-security-policy", "frame-ancestors 'none'"),
    ("referrer-policy", "no-referrer"),
)


class RequestIdMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        inbound = Headers(scope=scope).get("x-request-id", "")
        request_id = inbound if _REQUEST_ID.fullmatch(inbound) else uuid.uuid4().hex

        async def send_with_id(message: Message) -> None:
            if message["type"] == "http.response.start":
                MutableHeaders(scope=message)["x-request-id"] = request_id
            await send(message)

        with bound_contextvars(request_id=request_id):
            await self.app(scope, receive, send_with_id)


class EdgeMiddleware:
    def __init__(self, app: ASGIApp, *, base_uri: str, max_body: int, deadline_s: float) -> None:
        self.app, self.base_uri, self.max_body, self.deadline_s = app, base_uri, max_body, deadline_s

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:  # noqa: C901
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        started = False

        async def send_secured(message: Message) -> None:
            nonlocal started
            if message["type"] == "http.response.start":
                started = True
                headers = MutableHeaders(scope=message)
                for name, value in SECURITY_HEADERS:
                    headers.setdefault(name, value)
            await send(message)

        declared = Headers(scope=scope).get("content-length", "")
        if declared.isdigit() and int(declared) > self.max_body:
            too_large = Problem("payload-too-large", f"The body exceeds {self.max_body} bytes")
            await render(self.base_uri, scope["path"], too_large)(scope, receive, send_secured)
            return
        received = 0

        async def limited() -> Message:
            nonlocal received
            message = await receive()
            received += len(message.get("body", b""))
            if received > self.max_body:  # chunked bodies declare no length
                raise StarletteHTTPException(413, f"The body exceeds {self.max_body} bytes")
            return message

        try:
            async with asyncio.timeout(self.deadline_s):
                await self.app(scope, limited, send_secured)
        except TimeoutError:
            if started:
                raise
            late = Problem("unavailable", "The request deadline passed", headers=RETRY_SOON)
            await render(self.base_uri, scope["path"], late)(scope, receive, send_secured)
        except Exception as error:
            log.exception("unhandled error")  # logged once, with the request id
            trace.get_current_span().record_exception(error)
            if started:
                raise
            unknown = Problem("internal", "An unexpected error occurred")
            await render(self.base_uri, scope["path"], unknown)(scope, receive, send_secured)
```

## Services and dependencies

```python file=src/newsroom/inbound/http/context.py
from dataclasses import dataclass
from typing import TYPE_CHECKING, Annotated

from fastapi import Depends, Request

from newsroom.domain.idempotency import IdempotencyStore
from newsroom.domain.publishing.ports import UnitOfWork
from newsroom.domain.publishing.use_cases import Articles

if TYPE_CHECKING:  # annotations are lazy on 3.14: no import cycle at runtime
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

## Authentication

```python file=src/newsroom/inbound/http/auth.py
from typing import Annotated
from uuid import UUID

import anyio
import jwt
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ValidationError

from newsroom.domain.kernel import Actor, Unavailable
from newsroom.inbound.http.context import get_services
from newsroom.inbound.http.problems import Problem

bearer = HTTPBearer(auto_error=False)


class Claims(BaseModel):  # a malformed claim in a signed token is a 401
    sub: str
    tid: UUID
    roles: tuple[str, ...] = ()


def unauthenticated(detail: str, *, invalid: bool) -> Problem:
    challenge = 'Bearer error="invalid_token"' if invalid else "Bearer"
    return Problem("unauthenticated", detail, headers={"WWW-Authenticate": challenge})


class Authenticator:
    def __init__(
        self, *, issuer: str, audience: str, jwks_url: str | None = None, hs256_secret: str | None = None
    ) -> None:
        self._issuer, self._audience = issuer, audience
        self._jwks = None if jwks_url is None else jwt.PyJWKClient(jwks_url, lifespan=300, timeout=3)
        self._secret = hs256_secret or ""
        self._algorithms = ["HS256"] if self._jwks is None else ["ES256", "EdDSA"]

    async def actor(self, token: str) -> Actor:
        try:
            key = (
                self._secret
                if self._jwks is None
                else (await anyio.to_thread.run_sync(self._jwks.get_signing_key_from_jwt, token))
            )
            decoded = jwt.decode(
                token,
                key,
                algorithms=self._algorithms,
                issuer=self._issuer,
                audience=self._audience,
                leeway=30,
                options={"require": ["exp", "iss", "aud", "sub"]},
            )
            claims = Claims.model_validate(decoded)
        except jwt.PyJWKClientConnectionError as error:
            raise Unavailable("the signing keys could not be fetched") from error
        except (jwt.PyJWTError, ValidationError) as error:
            raise unauthenticated("The access token is invalid or expired", invalid=True) from error
        return Actor(claims.tid, claims.sub, frozenset(claims.roles))


async def authenticate(request: Request, credentials: HTTPAuthorizationCredentials | None) -> Actor:
    if isinstance(cached := request.scope.get("newsroom.actor"), Actor):
        return cached
    if credentials is None:
        raise unauthenticated("Send a bearer access token", invalid=False)
    actor = await get_services(request).authenticator.actor(credentials.credentials)
    request.scope["newsroom.actor"] = actor
    return actor


async def current_actor(
    request: Request, credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]
) -> Actor:
    return await authenticate(request, credentials)


ActorDep = Annotated[Actor, Depends(current_actor)]
```

## Idempotency wrapper

```python file=src/newsroom/inbound/http/idempotency.py
import hashlib
import json
import re
from collections.abc import Callable, Coroutine
from http import HTTPStatus
from typing import Any

from fastapi import Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.routing import APIRoute
from starlette.exceptions import HTTPException as StarletteHTTPException

from newsroom.domain.idempotency import InFlight, Mismatch, Replay, StoredResponse
from newsroom.domain.kernel import DomainError
from newsroom.domain.publishing.ports import Transaction
from newsroom.inbound.http.auth import authenticate, bearer
from newsroom.inbound.http.context import get_services
from newsroom.inbound.http.problems import RETRY_SOON, Problem, respond

_KEY = re.compile(r"[\x21-\x7e]{1,255}")  # 1-255 visible ASCII
_REPLAYED = ("content-type", "location", "etag")
type Handler = Callable[[Request], Coroutine[Any, Any, Response]]


def _stored(response: Response) -> StoredResponse:
    headers = {name: response.headers[name] for name in _REPLAYED if name in response.headers}
    return StoredResponse(response.status_code, headers, bytes(response.body))


class IdempotentRoute(APIRoute):
    def get_route_handler(self) -> Handler:  # noqa: C901
        handler = super().get_route_handler()

        async def idempotent(request: Request) -> Response:  # noqa: C901
            key = request.headers.get("idempotency-key")
            if key is None or request.method != "POST":
                return await handler(request)
            if not _KEY.fullmatch(key):
                raise Problem("malformed-request", "Idempotency-Key must be 1-255 visible ASCII characters")
            actor = await authenticate(request, await bearer(request))  # before reading the body
            try:
                canonical = json.dumps(json.loads(await request.body() or b"null"), sort_keys=True)
            except ValueError, RecursionError:  # unreadable or too deep: no key; the handler rejects it
                return await handler(request)
            services = get_services(request)
            scope = f"{actor.tenant_id}:{actor.subject}"
            fingerprint = f"{request.method} {request.url.path}\n{canonical}"
            digest = hashlib.sha256(fingerprint.encode()).hexdigest()
            acquired = await services.idempotency.acquire(scope, key, digest)
            if isinstance(acquired, Replay):
                replayed = {**acquired.response.headers, "idempotent-replayed": "true"}
                return Response(acquired.response.body, acquired.response.status, replayed)
            if isinstance(acquired, Mismatch):
                raise Problem("idempotency-key-mismatch", "The key was used for a different request")
            if isinstance(acquired, InFlight):
                raise Problem(
                    "idempotency-in-flight", "The first request is still running", headers=RETRY_SOON
                )
            lease = acquired.lease

            async def run_and_complete(tx: Transaction) -> Response:
                response = await handler(request)  # the use case's uow.run joins tx
                await tx.idempotency.complete(scope, key, lease, _stored(response))
                return response

            try:
                try:
                    return await services.uow.run(run_and_complete)
                except (DomainError, Problem, RequestValidationError, StarletteHTTPException) as error:
                    failed = respond(request, error)  # rolled back; a 4xx is stored and replayed
                    if failed.status_code >= HTTPStatus.INTERNAL_SERVER_ERROR:
                        raise
                    await services.uow.run(
                        lambda tx: tx.idempotency.complete(scope, key, lease, _stored(failed))
                    )
                    return failed
            except BaseException:  # 5xx, deadline, LeaseLost: a retry may run again
                await services.idempotency.release(scope, key, lease)
                raise

        return idempotent
```

## Article routes

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
    new: ArticleIn, actor: ActorDep, articles: ArticlesDep, response: Response
) -> ArticleEnvelope:
    article = await articles.create(actor, NewArticle(new.slug, new.title, new.body))
    response.headers["Location"] = f"/v1/articles/{article.id}"
    return _envelope(response, article)


@router.get("/{article_id}")
async def get_article(
    article_id: UUID, actor: ActorDep, articles: ArticlesDep, response: Response
) -> ArticleEnvelope:
    return _envelope(response, await articles.get(actor, article_id))


@router.get("")
async def list_articles(
    actor: ActorDep,
    articles: ArticlesDep,
    limit: Annotated[int, Query(ge=1)] = 20,
    cursor: Annotated[str | None, Query()] = None,  # undecodable: 400 from the adapter
) -> ArticlePage:
    used = min(limit, PAGE_MAX)  # clamped; meta.limit reports it
    page = await articles.page(actor, cursor=cursor, limit=used)
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
    if_match: Annotated[str | None, Header()] = None,
) -> ArticleEnvelope:
    body = (patch.body or "") if "body" in patch.model_fields_set else None
    expected = _if_match(if_match)
    article = await articles.update(actor, article_id, title=patch.title, body=body, if_match=expected)
    return _envelope(response, article)


@router.post("/{article_id}/publish")
async def publish_article(
    article_id: UUID, actor: ActorDep, articles: ArticlesDep, response: Response
) -> ArticleEnvelope:
    return _envelope(response, await articles.publish(actor, article_id))
```

## Moderation webhook

```python file=src/newsroom/inbound/webhooks/moderation.py
import base64
import hashlib
import hmac
import logging
import re
import time
from collections.abc import Mapping, Sequence
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Request, Response
from pydantic import BaseModel, ValidationError

from newsroom.domain.kernel import Actor
from newsroom.domain.publishing.use_cases import SYSTEM
from newsroom.inbound.http.context import get_services
from newsroom.inbound.http.problems import Problem

log = logging.getLogger(__name__)
TOLERANCE_S = 300
_SECONDS = re.compile(r"[0-9]{1,12}")  # bounded ASCII before int(): isdigit() accepts "²"
router = APIRouter(prefix="/internal/webhooks", include_in_schema=False)


class ModerationVerdict(BaseModel):
    tenant_id: UUID
    article_id: UUID
    verdict: Literal["approved", "rejected"]


def verify(headers: Mapping[str, str], body: bytes, secrets: Sequence[bytes], now: float) -> str:
    message_id = headers.get("webhook-id", "")
    timestamp = headers.get("webhook-timestamp", "")
    if message_id and _SECONDS.fullmatch(timestamp) and abs(now - int(timestamp)) <= TOLERANCE_S:  # both ways
        signed = f"{message_id}.{timestamp}.".encode() + body
        expected = [base64.b64encode(hmac.digest(s, signed, hashlib.sha256)) for s in secrets]
        for candidate in headers.get("webhook-signature", "").split():  # several during rotation
            version, _, signature = candidate.partition(",")
            if version == "v1" and any(hmac.compare_digest(signature.encode(), e) for e in expected):
                return message_id
    challenge = {"WWW-Authenticate": 'Signature realm="webhooks"'}
    raise Problem("unauthenticated", "The webhook signature is missing, invalid or stale", headers=challenge)


@router.post("/moderation", status_code=204)
async def moderation(request: Request) -> Response:
    services = get_services(request)
    body = await request.body()
    message_id = verify(request.headers, body, services.webhook_secrets, time.time())
    try:
        event = ModerationVerdict.model_validate_json(body)
    except ValidationError:  # permanent: a retry cannot fix it
        log.warning("malformed moderation event acknowledged", extra={"message_id": message_id})
        return Response(status_code=204)
    if event.verdict == "rejected":
        moderator = Actor(event.tenant_id, "system:moderation", frozenset({SYSTEM}))
        outcome = await services.articles.archive(moderator, event.article_id, message_id=message_id)
        log.info("moderation verdict applied", extra={"message_id": message_id, "outcome": outcome})
    return Response(status_code=204)  # after the inbox row and the effect committed
```

## App factory and probes

```python file=src/newsroom/inbound/http/app.py
from collections.abc import AsyncIterator, Callable, Sequence
from contextlib import AbstractAsyncContextManager, asynccontextmanager
from dataclasses import dataclass
from http import HTTPStatus
from typing import Any

from fastapi import APIRouter, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from newsroom.inbound.http import articles, problems
from newsroom.inbound.http.context import Services
from newsroom.inbound.http.middleware import EdgeMiddleware, RequestIdMiddleware
from newsroom.inbound.http.problems import RETRY_SOON, Problem
from newsroom.inbound.webhooks import moderation

type ServicesFactory = Callable[[], AbstractAsyncContextManager[Services]]
PROBES = frozenset({"/healthz", "/readyz"})


@dataclass(frozen=True, slots=True)
class HttpConfig:
    problem_base_uri: str
    cors_origins: Sequence[str]
    request_timeout_s: float
    max_body_bytes: int = 64 * 1024


@dataclass
class Readiness:
    ready: bool = False
    draining: bool = False


probes = APIRouter(include_in_schema=False)  # before any auth dependency


@probes.get("/healthz")
async def liveness() -> dict[str, str]:
    return {"status": "ok"}


@probes.get("/readyz")
async def readiness(request: Request) -> dict[str, str]:
    latch: Readiness = request.app.state.readiness
    if not latch.ready or latch.draining:
        raise Problem("unavailable", "Starting or draining", headers=RETRY_SOON)
    return {"status": "ready"}


class NewsroomAPI(FastAPI):
    def openapi(self) -> dict[str, Any]:
        if self.openapi_schema is None:
            schema = super().openapi()
            for operation in (op for path in schema["paths"].values() for op in path.values()):
                for status, response in operation.get("responses", {}).items():
                    content = response.get("content", {})
                    if int(status) >= HTTPStatus.BAD_REQUEST and "application/json" in content:
                        response["content"] = {"application/problem+json": content.pop("application/json")}
        return super().openapi()


def create_app(config: HttpConfig, services: ServicesFactory, readiness: Readiness) -> FastAPI:
    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[dict[str, Services]]:
        async with services() as built:
            readiness.ready = True
            yield {"services": built}

    app = NewsroomAPI(
        title="Newsroom",
        version="1",
        lifespan=lifespan,
        docs_url=None,  # newsroom-openapi exports it
        redoc_url=None,
        openapi_url=None,
        telemetry={"auto_configure": False, "exclude": lambda scope: scope.get("path") in PROBES},
    )
    app.state.readiness = readiness
    problems.install(app, config.problem_base_uri)
    # add_middleware prepends: the last added runs first.
    app.add_middleware(
        EdgeMiddleware,
        base_uri=config.problem_base_uri,
        max_body=config.max_body_bytes,
        deadline_s=config.request_timeout_s,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(config.cors_origins),
        allow_methods=["GET", "POST", "PATCH"],
        allow_headers=["Authorization", "Content-Type", "Idempotency-Key", "If-Match", "X-Request-Id"],
        expose_headers=["Location", "ETag", "Retry-After", "X-Request-Id"],
        max_age=600,
    )
    app.add_middleware(RequestIdMiddleware)
    app.include_router(probes)
    app.include_router(articles.router)
    app.include_router(moderation.router)
    return app
```
