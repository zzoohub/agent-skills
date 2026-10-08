# FastAPI Examples: Domain

Plain Python 3.14: no framework, ORM or SDK imports. Each block is a complete file.

## Contents

1. [Shared kernel](#shared-kernel)
2. [Article aggregate](#article-aggregate)
3. [Ports](#ports)
4. [Use cases](#use-cases)
5. [Idempotency port](#idempotency-port)
6. [Tests and doubles](#tests-and-doubles)

## Shared kernel

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

## Article aggregate

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

SLUG_MAX, TITLE_MAX, BODY_MAX = 100, 200, 20_000
EDITOR = "editor"
_SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")


def parse_slug(raw: str) -> Slug:
    if len(raw) > SLUG_MAX or not _SLUG.fullmatch(raw):
        msg = f"must be lowercase kebab-case, 1-{SLUG_MAX} characters"
        raise ValidationFailed(FieldError("slug", "invalid_format", msg))
    return Slug(raw)


def parse_title(raw: str) -> Title:
    value = raw.strip()
    if not 1 <= len(value) <= TITLE_MAX:
        msg = f"must be 1-{TITLE_MAX} characters after trimming"
        raise ValidationFailed(FieldError("title", "invalid_length", msg))
    return Title(value)


def parse_body(raw: str) -> Body:
    if len(raw) > BODY_MAX:
        raise ValidationFailed(FieldError("body", "too_long", f"must be at most {BODY_MAX} characters"))
    return Body(raw)


class Status(StrEnum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


@dataclass(frozen=True, slots=True, kw_only=True)
class Article:
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

## Ports

```python file=src/newsroom/domain/publishing/ports.py
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Protocol
from uuid import UUID

from newsroom.domain.idempotency import IdempotencyLedger
from newsroom.domain.kernel import DomainEvent, Page
from newsroom.domain.publishing.article import Article, Status


class ArticleRepository(Protocol):  # every query filters by tenant
    async def add(self, article: Article) -> None: ...  # AlreadyExists on a taken slug
    async def get(self, tenant_id: UUID, article_id: UUID) -> Article | None: ...
    async def page(self, tenant_id: UUID, *, cursor: str | None, limit: int) -> Page[Article]: ...
    async def update(self, article: Article, *, expected_version: int) -> bool: ...
    async def transition(self, article: Article, *, from_status: Status) -> Article | None: ...


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
    async def run[T](self, work: Callable[[Transaction], Awaitable[T]]) -> T: ...
```

## Use cases

Authorization is decided here (403 for a visible article); the repository's tenant filter is the second enforcement point (404).

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

        await self._uow.run(lambda tx: tx.articles.add(article))  # the UNIQUE constraint decides a race
        return article

    async def get(self, actor: Actor, article_id: UUID) -> Article:
        return await self._uow.run(lambda tx: self._visible(tx, actor, article_id))

    async def page(self, actor: Actor, *, cursor: str | None, limit: int) -> Page[Article]:
        bounded = max(1, min(limit, PAGE_MAX))
        return await self._uow.run(lambda tx: tx.articles.page(actor.tenant_id, cursor=cursor, limit=bounded))

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

        return await self._uow.run(work)

    async def publish(self, actor: Actor, article_id: UUID) -> Article:
        async def work(tx: Transaction) -> Article:
            current = await self._changeable(tx, actor, article_id)
            stored = await tx.articles.transition(
                current.publish(self._clock.now()), from_status=Status.DRAFT
            )
            if stored is None:
                raise InvalidTransition("the article is no longer a draft")
            await tx.outbox.append(stored.published_event())  # same transaction as the change
            return stored

        return await self._uow.run(work)

    async def archive(self, actor: Actor, article_id: UUID, *, message_id: str) -> ArchiveOutcome:
        if SYSTEM not in actor.roles:
            raise Forbidden("only the moderation system archives articles")

        async def work(tx: Transaction) -> ArchiveOutcome:
            if not await tx.inbox.record("moderation", message_id):
                return ArchiveOutcome.DUPLICATE
            current = await tx.articles.get(actor.tenant_id, article_id)
            if current is None:
                return ArchiveOutcome.NOT_FOUND  # permanent: the inbox row still commits
            if current.status is not Status.PUBLISHED:
                return ArchiveOutcome.NOT_PUBLISHED
            stored = await tx.articles.transition(
                current.archive(self._clock.now()), from_status=Status.PUBLISHED
            )
            return ArchiveOutcome.NOT_PUBLISHED if stored is None else ArchiveOutcome.ARCHIVED

        return await self._uow.run(work)

    @staticmethod
    async def _visible(tx: Transaction, actor: Actor, article_id: UUID) -> Article:
        article = await tx.articles.get(actor.tenant_id, article_id)
        if article is None:
            raise NotFound(f"article {article_id} not found")
        return article

    async def _changeable(self, tx: Transaction, actor: Actor, article_id: UUID) -> Article:
        article = await self._visible(tx, actor, article_id)
        if not article.can_be_changed_by(actor):
            raise Forbidden("only the author or an editor can change this article")
        return article
```

## Idempotency port

```python file=src/newsroom/domain/idempotency.py
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Protocol
from uuid import UUID


@dataclass(frozen=True, slots=True)
class StoredResponse:
    status: int
    headers: Mapping[str, str]  # Content-Type, Location, ETag
    body: bytes


@dataclass(frozen=True, slots=True)
class NewExecution:
    lease: UUID


@dataclass(frozen=True, slots=True)
class Replay:
    response: StoredResponse


class Mismatch: ...


class InFlight: ...


type Acquired = NewExecution | Replay | Mismatch | InFlight


class LeaseLost(Exception): ...  # complete() found the lease taken over: roll back


class IdempotencyStore(Protocol):  # each call is its own short transaction
    async def acquire(self, scope: str, key: str, request_hash: str) -> Acquired: ...
    async def release(self, scope: str, key: str, lease: UUID) -> None: ...
    async def purge_expired(self) -> int: ...


class IdempotencyLedger(Protocol):  # bound to the use case's transaction
    async def complete(self, scope: str, key: str, lease: UUID, response: StoredResponse) -> None: ...
```

## Tests and doubles

The fake repository enforces the unique slug and the fake unit of work rolls back, so a Saboteur outbox proves the command fails as a whole.

```python file=tests/doubles.py
import dataclasses
import datetime as dt
from collections.abc import Awaitable, Callable
from typing import Any, cast
from uuid import UUID

from newsroom.domain.kernel import AlreadyExists, DomainEvent, Page
from newsroom.domain.publishing.article import Article, Status
from newsroom.domain.publishing.ports import Outbox, Transaction

T0 = dt.datetime(2026, 10, 8, 12, tzinfo=dt.UTC)


class FixedClock:
    def now(self) -> dt.datetime:
        return T0


@dataclasses.dataclass
class Tables:
    articles: dict[UUID, Article] = dataclasses.field(default_factory=dict)
    events: list[DomainEvent] = dataclasses.field(default_factory=list)


class FakeArticles:
    def __init__(self, tables: Tables) -> None:
        self.rows = tables.articles

    async def add(self, article: Article) -> None:
        if any((a.tenant_id, a.slug) == (article.tenant_id, article.slug) for a in self.rows.values()):
            raise AlreadyExists(f"the slug '{article.slug}' is already taken")  # the UNIQUE constraint
        self.rows[article.id] = article

    async def get(self, tenant_id: UUID, article_id: UUID) -> Article | None:
        article = self.rows.get(article_id)
        return article if article and article.tenant_id == tenant_id else None

    async def page(self, tenant_id: UUID, *, cursor: str | None, limit: int) -> Page[Article]:
        raise NotImplementedError  # keyset paging is proven on PostgreSQL only

    async def update(self, article: Article, *, expected_version: int) -> bool:
        if self.rows[article.id].version != expected_version:
            return False
        self.rows[article.id] = article
        return True

    async def transition(self, article: Article, *, from_status: Status) -> Article | None:
        if self.rows[article.id].status is not from_status:
            return None
        self.rows[article.id] = article
        return article


class FakeOutbox:
    def __init__(self, tables: Tables) -> None:
        self.events = tables.events

    async def append(self, event: DomainEvent) -> None:
        self.events.append(event)


class SaboteurOutbox:
    async def append(self, event: DomainEvent) -> None:
        raise ConnectionError("outbox write failed")


class FakeUnitOfWork:
    def __init__(self, tables: Tables, outbox: Outbox | None = None) -> None:
        self.tables, self.outbox = tables, outbox

    async def run[T](self, work: Callable[[Transaction], Awaitable[T]]) -> T:
        before = dict(self.tables.articles), list(self.tables.events)
        unused = cast("Any", None)  # inbox and ledger: these use cases never touch them
        tx = Transaction(FakeArticles(self.tables), self.outbox or FakeOutbox(self.tables), unused, unused)
        try:
            return await work(tx)
        except BaseException:  # roll back, as the real transaction would
            self.tables.articles, self.tables.events = before
            raise
```

```python file=tests/test_domain.py
import dataclasses
import uuid

import pytest

from doubles import T0, FakeUnitOfWork, FixedClock, SaboteurOutbox, Tables
from newsroom.domain.kernel import Actor, AlreadyExists, InvalidTransition, ValidationFailed
from newsroom.domain.publishing.article import Article, Body, Slug, Status, Title, parse_slug, parse_title
from newsroom.domain.publishing.ports import Outbox
from newsroom.domain.publishing.use_cases import Articles, NewArticle
from newsroom.outbound.system import Uuid7Ids

AUTHOR = Actor(uuid.uuid4(), "ada")


def draft() -> Article:
    title = Title("Hello")
    return Article.draft(
        article_id=uuid.uuid7(), author=AUTHOR, slug=Slug("hi"), title=title, body=Body(""), now=T0
    )


@pytest.mark.parametrize("raw", ["a", "v2-launch", "x" * 100])
def test_accepts_lowercase_kebab_slugs(raw: str) -> None:
    assert parse_slug(raw) == raw


@pytest.mark.parametrize("raw", ["", "Hello", "a--b", "-a", "a b", "x" * 101])
def test_rejects_other_slugs(raw: str) -> None:
    with pytest.raises(ValidationFailed):
        parse_slug(raw)


def test_title_is_trimmed_then_bounded() -> None:
    assert parse_title("  Hello  ") == "Hello"
    for raw in ("   ", "x" * 201):
        with pytest.raises(ValidationFailed):
            parse_title(raw)


def test_transitions_bump_the_version_and_are_guarded() -> None:
    published = draft().publish(T0)
    assert (published.status, published.version, published.published_at) == (Status.PUBLISHED, 2, T0)
    assert published.archive(T0).status is Status.ARCHIVED
    with pytest.raises(InvalidTransition):
        published.publish(T0)
    with pytest.raises(InvalidTransition):
        draft().archive(T0)


def test_rehydration_does_not_revalidate() -> None:  # rows stored under older rules must still load
    assert dataclasses.replace(draft(), title=Title("x" * 500)).title == "x" * 500


def articles(tables: Tables, outbox: Outbox | None = None) -> Articles:
    return Articles(FakeUnitOfWork(tables, outbox), FixedClock(), Uuid7Ids())


async def test_a_taken_slug_is_a_conflict() -> None:
    tables = Tables()
    await articles(tables).create(AUTHOR, NewArticle("hello", "Hello"))
    with pytest.raises(AlreadyExists):
        await articles(tables).create(AUTHOR, NewArticle("hello", "Again"))


async def test_publish_appends_its_event_in_the_same_unit() -> None:
    tables = Tables()
    draft = await articles(tables).create(AUTHOR, NewArticle("hello", "Hello"))
    published = await articles(tables).publish(AUTHOR, draft.id)
    assert [(e.event_type, e.aggregate_seq) for e in tables.events] == [
        ("article.published", published.version)
    ]


async def test_a_failing_outbox_fails_the_whole_command() -> None:
    tables = Tables()
    draft = await articles(tables).create(AUTHOR, NewArticle("hello", "Hello"))
    with pytest.raises(ConnectionError):
        await articles(tables, SaboteurOutbox()).publish(AUTHOR, draft.id)
    assert tables.articles[draft.id].status is Status.DRAFT  # the transition rolled back too
```
