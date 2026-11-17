# FastAPI examples: tests

The proof: a harness on real PostgreSQL with the application's role, model tests without doubles, use cases and adapters tested together, and the HTTP risk set through the app factory. Every `file=` block is a complete file of the project in `slice.md`. `guide.md` § 8 says how each risk is forced.

## Contents

1. [Harness](#harness)
2. [Model tests](#model-tests)
3. [Use cases and adapters on PostgreSQL](#use-cases-and-adapters-on-postgresql)
4. [HTTP tests](#http-tests)
5. [Edge and configuration tests](#edge-and-configuration-tests)

## Harness

The test run gets one database, migrated from empty by the release step in a subprocess. The application's pool connects as `app_rw`, so every test runs under row-level security. Each test uses a fresh tenant instead of truncating.

```python file=tests/conftest.py
import base64
import os
import subprocess
import sys
import uuid
from collections.abc import AsyncIterator, Iterator

import httpx2
import psycopg
import pytest
from asgi_lifespan import LifespanManager
from fastapi import FastAPI
from sqlalchemy import URL, make_url
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from newsroom.bootstrap.config import ApiSettings
from newsroom.bootstrap.container import build_app, database_config
from newsroom.outbound.postgres import database
from support import AUDIENCE, ISSUER, JWT_SECRET, WEBHOOK_KEY

ADMIN_URL = make_url(os.environ.get("TEST_DATABASE_URL", "postgresql+psycopg://postgres@127.0.0.1/postgres"))
# Cluster bootstrap, tolerant of a role that already exists. Production creates it outside the migrations.
APP_ROLE = """
DO $$ BEGIN CREATE ROLE app_rw LOGIN PASSWORD 'app_rw';
EXCEPTION WHEN duplicate_object THEN NULL; END $$
"""


@pytest.fixture(scope="session")
def owner_url() -> Iterator[URL]:
    """A fresh database, migrated from empty by the release step, as the owning role."""
    name = f"newsroom_test_{uuid.uuid4().hex[:12]}"
    admin = ADMIN_URL.set(drivername="postgresql").render_as_string(hide_password=False)
    with psycopg.connect(admin, autocommit=True) as connection:
        connection.execute(APP_ROLE)
        connection.execute(f'CREATE DATABASE "{name}"')
        connection.execute(f"ALTER DATABASE \"{name}\" SET timezone = 'Asia/Seoul'")  # proves the UTC pin
    owner = ADMIN_URL.set(database=name)
    migrate = [sys.executable, "-m", "alembic", "upgrade", "head"]
    env = os.environ | {"MIGRATION_DATABASE_URL": owner.render_as_string(hide_password=False)}
    subprocess.run(migrate, env=env, check=True)  # noqa: S603
    yield owner
    with psycopg.connect(admin, autocommit=True) as connection:
        connection.execute(f'DROP DATABASE "{name}" WITH (FORCE)')


@pytest.fixture
def settings(owner_url: URL) -> ApiSettings:
    app_rw = owner_url.set(username="app_rw", password="app_rw")  # noqa: S106 - what production connects as
    return ApiSettings(
        app_env="test",
        database_url=app_rw.render_as_string(hide_password=False),
        jwt_mode="hs256",
        jwt_hs256_secret=JWT_SECRET,
        jwt_issuer=ISSUER,
        jwt_audience=AUDIENCE,
        problem_base_uri="https://problems.test/",
        cors_origins=("https://app.test",),
        request_timeout_ms=1_000,  # short, so the deadline test waits one second
        webhook_secrets=("whsec_" + base64.b64encode(WEBHOOK_KEY).decode(),),
    )


@pytest.fixture
async def sessions(settings: ApiSettings) -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    engine = database.create_engine(database_config(settings, "newsroom-tests"))
    yield database.sessionmaker(engine)
    await engine.dispose()


@pytest.fixture
def app(settings: ApiSettings) -> FastAPI:
    return build_app(settings)


@pytest.fixture
async def client(app: FastAPI) -> AsyncIterator[httpx2.AsyncClient]:
    async with LifespanManager(app) as manager:  # ASGITransport alone never runs the lifespan
        transport = httpx2.ASGITransport(app=manager.app)
        async with httpx2.AsyncClient(transport=transport, base_url="http://test") as client:
            yield client
```

The only doubles: a saboteur outbox, the identity provider's key endpoint, and token helpers. The event publisher is faked in `test_postgres.py`, where the relay tests need it.

```python file=tests/support.py
import http.server
import threading
import time
from collections.abc import Iterator
from contextlib import contextmanager
from uuid import UUID

import jwt

from newsroom.domain.kernel import DomainEvent

JWT_SECRET = "test-only-hs256-secret-of-32-bytes!"
WEBHOOK_KEY = b"test-only-webhook-signing-key-32b"
ISSUER, AUDIENCE = "https://issuer.test", "newsroom"


def claims(tenant: UUID, subject: str = "ada") -> dict[str, object]:
    return {
        "sub": subject,
        "tid": str(tenant),
        "iss": ISSUER,
        "aud": AUDIENCE,
        "exp": int(time.time()) + 3600,
    }


def bearer(tenant: UUID, subject: str = "ada") -> dict[str, str]:
    return {"Authorization": f"Bearer {jwt.encode(claims(tenant, subject), JWT_SECRET, algorithm='HS256')}"}


class SaboteurOutbox:
    """Stands in for the real outbox inside a real transaction and fails the one call."""

    async def append(self, event: DomainEvent) -> None:
        raise ConnectionError("outbox write failed")


@contextmanager
def key_endpoint(status: int, body: bytes) -> Iterator[str]:
    """The identity provider's key set, as it answers on a good day and on a bad one."""

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            self.send_response(status)
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: object) -> None: ...  # noqa: A002

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        yield f"http://127.0.0.1:{server.server_address[1]}/jwks"
    finally:
        server.shutdown()
        server.server_close()
```

## Model tests

```python file=tests/test_model.py
import dataclasses
import datetime as dt
import uuid

import pytest

from newsroom.domain.kernel import Actor, InvalidTransition, ValidationFailed
from newsroom.domain.publishing.article import (
    Article,
    Body,
    Slug,
    Status,
    Title,
    parse_body,
    parse_slug,
    parse_title,
)

T0 = dt.datetime(2026, 11, 18, 12, tzinfo=dt.UTC)
ADA = Actor(uuid.uuid4(), "ada")
DRAFT = Article.draft(
    article_id=uuid.uuid7(), author=ADA, slug=Slug("hi"), title=Title("Hello"), body=Body(""), now=T0
)


@pytest.mark.parametrize("raw", ["a", "v2-launch", "x" * 100])
def test_accepts_lowercase_kebab_slugs(raw: str) -> None:
    assert parse_slug(raw) == raw


@pytest.mark.parametrize("raw", ["", "Hello", "a--b", "-a", "a b", "a\0b", "x" * 101])
def test_rejects_other_slugs(raw: str) -> None:
    with pytest.raises(ValidationFailed):
        parse_slug(raw)


@pytest.mark.parametrize(
    ("parse", "raw", "parsed"),
    [
        (parse_title, "  Hello  ", "Hello"),  # trimmed, then bounded
        (parse_title, "😀" * 200, "😀" * 200),  # code points, as the CHECK's char_length counts
        (parse_title, "   ", None),
        (parse_title, "x" * 201, None),
        (parse_title, "a\0b", None),  # PostgreSQL text cannot store U+0000
        (parse_body, "", ""),
        (parse_body, "x" * 20_001, None),
        (parse_body, "\0", None),
    ],
)
def test_text_rules(parse: object, raw: str, parsed: str | None) -> None:
    assert callable(parse)
    if parsed is None:
        with pytest.raises(ValidationFailed):
            parse(raw)
    else:
        assert parse(raw) == parsed


def test_transitions_bump_the_version_and_are_guarded() -> None:
    published = DRAFT.publish(T0)
    assert (published.status, published.version, published.published_at) == (Status.PUBLISHED, 2, T0)
    assert published.archive(T0).status is Status.ARCHIVED
    for illegal in (published.publish, DRAFT.archive):
        with pytest.raises(InvalidTransition):
            illegal(T0)


def test_the_event_carries_the_version_as_its_sequence() -> None:
    event = DRAFT.publish(T0).published_event()
    assert (event.event_type, event.aggregate_id, event.aggregate_seq) == ("article.published", DRAFT.id, 2)
    assert event.payload["published_at"] == T0.isoformat()


def test_only_the_author_or_an_editor_may_change_it() -> None:
    assert DRAFT.can_be_changed_by(ADA)
    assert not DRAFT.can_be_changed_by(Actor(ADA.tenant_id, "bob"))
    assert DRAFT.can_be_changed_by(Actor(ADA.tenant_id, "bob", frozenset({"editor"})))


def test_rehydration_does_not_revalidate() -> None:  # rows stored under older rules must still load
    assert dataclasses.replace(DRAFT, title=Title("x" * 500)).title == "x" * 500
```

## Use cases and adapters on PostgreSQL

The races are forced: a barrier holds every writer after its read, and a planner setting forces the plan under which a claim would take too much.

```python file=tests/test_postgres.py
import asyncio
import dataclasses
import uuid
from collections.abc import Awaitable, Callable

import pytest
from sqlalchemy import select, text
from sqlalchemy.exc import InvalidRequestError, ProgrammingError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from newsroom.bootstrap.config import ApiSettings
from newsroom.bootstrap.container import database_config
from newsroom.domain.idempotency import InFlight, LeaseLost, Mismatch, NewExecution, Replay, StoredResponse
from newsroom.domain.kernel import Actor, DomainEvent, NotFound
from newsroom.domain.publishing.article import Article, Body, Slug, Status, Title
from newsroom.domain.publishing.ports import Transaction
from newsroom.domain.publishing.use_cases import Articles, NewArticle
from newsroom.outbound.postgres import database
from newsroom.outbound.postgres.articles import PostgresArticles
from newsroom.outbound.postgres.idempotency import PostgresIdempotencyStore
from newsroom.outbound.postgres.outbox import OutboxMessage, OutboxRelay, PostgresOutbox
from newsroom.outbound.postgres.tables import outbox
from newsroom.outbound.postgres.uow import PostgresUnitOfWork, bind
from newsroom.outbound.system import SystemClock, Uuid7Ids
from support import SaboteurOutbox

type Sessions = async_sessionmaker[AsyncSession]
COUNT = text("SELECT count(*) FROM app.articles")  # no tenant predicate: only the policy stands


def articles(sessions: Sessions, uow: PostgresUnitOfWork | None = None) -> Articles:
    return Articles(uow or PostgresUnitOfWork(sessions), SystemClock(), Uuid7Ids())


def spying(sessions: Sessions) -> tuple[PostgresUnitOfWork, list[AsyncSession]]:
    """A unit of work that also hands the test its session, for SQL no repository would send."""
    seen: list[AsyncSession] = []

    def binder(session: AsyncSession, tenant_id: uuid.UUID) -> Transaction:
        seen.append(session)
        return bind(session, tenant_id)

    return PostgresUnitOfWork(sessions, binder=binder), seen


@pytest.fixture
def ada() -> Actor:
    return Actor(uuid.uuid4(), "ada")  # a fresh tenant per test


async def test_keyset_walk_has_no_duplicates_or_gaps(sessions: Sessions, ada: Actor) -> None:
    now, title, body = SystemClock().now(), Title("T"), Body("")
    rows = [
        Article.draft(
            article_id=uuid.uuid7(), author=ada, slug=Slug(f"a-{i}"), title=title, body=body, now=now
        )
        for i in range(7)
    ]

    async def seed(tx: Transaction) -> None:  # one transaction: every row shares one timestamp
        for row in rows:
            await tx.articles.add(row)

    await PostgresUnitOfWork(sessions).run(ada, seed)
    for limit in (1, 2):
        walked, cursor = [], None
        for _ in range(len(rows) + 1):  # bounded: a cursor that does not advance would loop forever
            page = await articles(sessions).page(ada, cursor=cursor, limit=limit)
            walked += [a.id for a in page.items]
            if (cursor := page.next_cursor) is None:
                break
        assert walked == sorted((a.id for a in rows), reverse=True)


async def test_concurrent_duplicate_creates_have_one_winner(sessions: Sessions, ada: Actor) -> None:
    attempts = [articles(sessions).create(ada, NewArticle("same", "T")) for _ in range(5)]
    results = await asyncio.gather(*attempts, return_exceptions=True)
    assert sorted(type(r).__name__ for r in results) == ["AlreadyExists"] * 4 + ["Article"]


def racing(sessions: Sessions, writers: int) -> PostgresUnitOfWork:
    """Every writer has read the row before any of them writes: the race, not a lucky interleaving."""
    all_have_read = asyncio.Barrier(writers)

    class ReadThenWait(PostgresArticles):
        async def get(self, article_id: uuid.UUID) -> Article | None:
            found = await super().get(article_id)
            await all_have_read.wait()
            return found

    return PostgresUnitOfWork(
        sessions, binder=lambda s, t: dataclasses.replace(bind(s, t), articles=ReadThenWait(s, t))
    )


async def test_concurrent_edits_and_publishes_have_one_winner(sessions: Sessions, ada: Actor) -> None:
    article = await articles(sessions).create(ada, NewArticle("contested", "T"))
    edits = articles(sessions, racing(sessions, 2))
    results = await asyncio.gather(
        *(edits.update(ada, article.id, title=t, body=None, if_match=None) for t in ("A", "B")),
        return_exceptions=True,
    )
    assert sorted(type(r).__name__ for r in results) == ["Article", "VersionConflict"]

    publishes = articles(sessions, racing(sessions, 3))
    results = await asyncio.gather(
        *(publishes.publish(ada, article.id) for _ in range(3)), return_exceptions=True
    )
    assert sorted(type(r).__name__ for r in results) == ["Article", "InvalidTransition", "InvalidTransition"]
    events = select(outbox.c.aggregate_seq).where(outbox.c.aggregate_id == article.id)
    async with sessions() as session:
        assert (await session.scalars(events)).all() == [3]  # one event, numbered by the stored version


async def test_a_deadlock_is_unavailable_not_retried(sessions: Sessions, ada: Actor) -> None:
    left = await articles(sessions).create(ada, NewArticle("left", "L"))
    right = await articles(sessions).create(ada, NewArticle("right", "R"))
    both_hold_one = asyncio.Barrier(2)

    def crossing(first: Article, second: Article) -> Callable[[Transaction], Awaitable[bool]]:
        async def work(tx: Transaction) -> bool:
            await tx.articles.update(first, expected_version=1)  # holds the row lock to the end
            await both_hold_one.wait()
            return await tx.articles.update(second, expected_version=1)  # PostgreSQL picks a victim

        return work

    uow = PostgresUnitOfWork(sessions)
    results = await asyncio.gather(
        uow.run(ada, crossing(left, right)), uow.run(ada, crossing(right, left)), return_exceptions=True
    )
    assert sorted(type(r).__name__ for r in results) == ["Unavailable", "bool"]  # a 503 the client retries


async def test_publish_writes_one_outbox_row_or_nothing(sessions: Sessions, ada: Actor) -> None:
    article = await articles(sessions).create(ada, NewArticle("hello", "Hello"))
    broken = PostgresUnitOfWork(
        sessions, binder=lambda s, t: dataclasses.replace(bind(s, t), outbox=SaboteurOutbox())
    )
    with pytest.raises(ConnectionError):
        await articles(sessions, broken).publish(ada, article.id)
    assert (await articles(sessions).get(ada, article.id)).status is Status.DRAFT  # rolled back

    published = await articles(sessions).publish(ada, article.id)
    async with sessions() as session:
        rows = (await session.execute(select(outbox).where(outbox.c.aggregate_id == article.id))).all()
    assert [(r.aggregate_seq, r.payload["slug"], r.headers["tenant_id"]) for r in rows] == [
        (published.version, "hello", str(ada.tenant_id))
    ]


async def test_other_tenants_cannot_see_or_change(sessions: Sessions, ada: Actor) -> None:
    article = await articles(sessions).create(ada, NewArticle("hello", "Hello"))
    intruder = Actor(uuid.uuid4(), "ada")
    for attempt in (articles(sessions).get, articles(sessions).publish):
        with pytest.raises(NotFound):
            await attempt(intruder, article.id)
    assert not (await articles(sessions).page(intruder, cursor=None, limit=20)).items


async def test_row_level_security_holds_where_a_query_forgot_the_tenant(
    sessions: Sessions, ada: Actor
) -> None:
    eve = Actor(uuid.uuid4(), "eve")
    await articles(sessions).create(ada, NewArticle("mine", "Mine"))
    theirs = await articles(sessions).create(eve, NewArticle("theirs", "Theirs"))
    uow, seen = spying(sessions)

    async def forgetful(tx: Transaction) -> tuple[int | None, int | None]:
        by_id = text("SELECT count(*) FROM app.articles WHERE id = :id")
        counts = await seen[-1].scalar(COUNT), await seen[-1].scalar(by_id, {"id": theirs.id})
        with pytest.raises(ProgrammingError, match="row-level security"):  # writes are checked too
            await tx.articles.add(dataclasses.replace(theirs, id=uuid.uuid7(), slug=Slug("planted")))
        return counts

    assert await uow.run(ada, forgetful) == (1, 0)
    async with sessions() as outside:  # no unit of work, so no tenant: the policy matches no row
        assert await outside.scalar(COUNT) == 0


async def test_the_tenant_ends_with_its_transaction(settings: ApiSettings, ada: Actor) -> None:
    one = dataclasses.replace(database_config(settings, "one-connection"), pool_size=1, max_overflow=0)
    engine = database.create_engine(one)
    sessions = database.sessionmaker(engine)
    uow, seen = spying(sessions)
    await articles(sessions, uow).create(ada, NewArticle("mine", "Mine"))
    backend = await uow.run(ada, lambda _: seen[-1].scalar(text("SELECT pg_backend_pid()")))
    leftover = text("SELECT pg_backend_pid(), current_setting('app.current_tenant', true)")
    async with sessions() as reused:  # the same pooled connection, after the commit
        assert tuple((await reused.execute(leftover)).one()) == (backend, "")
        assert await reused.scalar(COUNT) == 0
    await engine.dispose()


async def test_a_nested_run_joins_its_tenant_and_refuses_another(sessions: Sessions, ada: Actor) -> None:
    uow = PostgresUnitOfWork(sessions)

    async def outer(tx: Transaction) -> bool:
        async def inner(joined: Transaction) -> bool:
            return joined is tx

        with pytest.raises(RuntimeError, match="another tenant"):
            await uow.run(Actor(uuid.uuid4(), "eve"), inner)
        return await uow.run(ada, inner)

    assert await uow.run(ada, outer)


async def test_work_that_outlives_its_unit_of_work_is_refused(sessions: Sessions, ada: Actor) -> None:
    uow, seen = spying(sessions)
    await uow.run(ada, lambda _: seen[-1].scalar(COUNT))
    with pytest.raises(InvalidRequestError, match="permanently closed"):  # a detached task, a kept reference
        await seen[-1].scalar(COUNT)


async def test_an_expired_lease_is_taken_over_and_fences_its_old_holder(
    sessions: Sessions, ada: Actor
) -> None:
    store, uow, scope = (
        PostgresIdempotencyStore(sessions),
        PostgresUnitOfWork(sessions),
        f"{ada.tenant_id}:ada",
    )
    stored = StoredResponse(201, {}, b"{}")
    first = await store.acquire(scope, "k", "hash")
    assert isinstance(first, NewExecution)
    assert isinstance(await store.acquire(scope, "k", "hash"), InFlight)  # a read never grants execution
    lapsed = text("""UPDATE app.idempotency_keys SET locked_until = now() - interval '1 s',
        expires_at = now() - interval '1 s' WHERE scope = :scope""")
    async with sessions.begin() as session:  # the lease and the key's lifetime have both run out
        await session.execute(lapsed, {"scope": scope})
    second = await store.acquire(scope, "k", "hash")
    assert isinstance(second, NewExecution)
    await store.purge_expired()  # the takeover extended the key's life: the purge spares it
    with pytest.raises(LeaseLost):  # the first holder finishes late: its result must not commit
        await uow.run(ada, lambda tx: tx.idempotency.complete(scope, "k", first.lease, stored))
    await uow.run(ada, lambda tx: tx.idempotency.complete(scope, "k", second.lease, stored))
    assert isinstance(await store.acquire(scope, "k", "hash"), Replay)
    assert isinstance(await store.acquire(scope, "k", "other"), Mismatch)


async def test_the_purge_removes_expired_keys_only(sessions: Sessions) -> None:
    store, scope = PostgresIdempotencyStore(sessions), f"{uuid.uuid4()}:ada"
    for key in ("old", "live"):
        assert isinstance(await store.acquire(scope, key, "hash"), NewExecution)
    expire = text("UPDATE app.idempotency_keys SET expires_at = now() - interval '1 s' WHERE key = 'old'")
    async with sessions.begin() as session:
        await session.execute(expire)
    assert await store.purge_expired() >= 1
    assert isinstance(await store.acquire(scope, "old", "hash"), NewExecution)  # gone: a fresh execution
    assert isinstance(await store.acquire(scope, "live", "hash"), InFlight)


class Broker:
    def __init__(self, failing: uuid.UUID | None = None) -> None:
        self.failing, self.seen = failing, list[tuple[uuid.UUID, int]]()

    async def publish(self, message: OutboxMessage) -> None:
        if message.aggregate_id == self.failing:
            raise RuntimeError("broker down")
        self.seen.append((message.aggregate_id, message.aggregate_seq))


async def pending(sessions: Sessions, *aggregates: tuple[uuid.UUID, int]) -> None:
    """Empty the outbox (the relay claims across tenants), then append `last` events per aggregate."""
    async with sessions.begin() as session:
        await session.execute(text("DELETE FROM app.outbox"))
        for aggregate, last in aggregates:
            for seq in range(1, last + 1):
                await PostgresOutbox(session).append(
                    DomainEvent(
                        tenant_id=aggregate,
                        aggregate_type="article",
                        aggregate_id=aggregate,
                        aggregate_seq=seq,
                        event_type="article.published",
                        event_version=1,
                        payload={},
                    )
                )


async def test_relay_publishes_heads_in_order_and_dead_letters(sessions: Sessions) -> None:
    healthy, poisoned = uuid.uuid4(), uuid.uuid4()
    await pending(sessions, (healthy, 3), (poisoned, 2))
    broker = Broker(failing=poisoned)
    relay = OutboxRelay(sessions, broker, max_attempts=2, backoff_base_s=0)
    while await relay.run_once():
        pass
    assert broker.seen == [(healthy, 1), (healthy, 2), (healthy, 3)]
    dead = select(outbox.c.aggregate_seq, outbox.c.attempts).where(outbox.c.dead_lettered_at.is_not(None))
    async with sessions() as session:
        assert sorted(tuple(row) for row in await session.execute(dead)) == [(1, 2), (2, 2)]
    await relay.measure()
    assert (relay.dead_letters, relay.oldest_pending_age_s) == (2, 0)  # nothing pending, two to alert on


# Forces the plan that runs an `IN` subquery again for each outer row. Under it, `id IN (SELECT ... LIMIT n
# FOR UPDATE SKIP LOCKED)` skips the rows this statement already updated, and claims every pending row.
REPLANNED = "-c enable_hashagg=off -c enable_hashjoin=off -c enable_material=off -c enable_sort=off"


async def test_one_claim_takes_one_batch_whatever_the_plan(settings: ApiSettings) -> None:
    url = settings.database_url.get_secret_value()
    engine = create_async_engine(url, connect_args={"options": REPLANNED})
    sessions = async_sessionmaker(engine)
    await pending(sessions, *((uuid.uuid4(), 1) for _ in range(200)))
    assert await OutboxRelay(sessions, Broker(), batch=5).run_once() == 5
    await engine.dispose()


async def test_a_relay_that_lost_its_lease_cannot_overwrite_the_newer_outcome(sessions: Sessions) -> None:
    await pending(sessions, (uuid.uuid4(), 1))
    winner = OutboxRelay(sessions, Broker())

    class Overtaken:  # its lease is zero: the other relay claims and delivers while this one publishes
        async def publish(self, message: OutboxMessage) -> None:
            assert await winner.run_once() == 1
            raise RuntimeError("timed out")

    assert await OutboxRelay(sessions, Overtaken(), lease_s=0, max_attempts=1).run_once() == 1
    state = select(outbox.c.published_at.is_not(None), outbox.c.dead_lettered_at, outbox.c.attempts)
    async with sessions() as session:
        assert tuple((await session.execute(state)).one()) == (True, None, 2)  # the failure wrote nothing


async def test_the_relay_outlives_a_database_outage(caplog: pytest.LogCaptureFixture) -> None:
    engine = create_async_engine("postgresql+psycopg://postgres@127.0.0.1:1/down")  # refused
    relay, stop = OutboxRelay(async_sessionmaker(engine), Broker()), asyncio.Event()
    task = asyncio.create_task(relay.run(stop, idle_s=0.01))
    await asyncio.sleep(0.3)
    stop.set()
    await asyncio.wait_for(task, 2)  # neither crashed nor deaf to the stop
    assert sum(r.message == "outbox relay backing off" for r in caplog.records) > 1
```

## HTTP tests

```python file=tests/test_http.py
import asyncio
import base64
import hashlib
import hmac
import time
import uuid
from typing import NoReturn

import httpx2
import pytest
from asgi_lifespan import LifespanManager
from fastapi import FastAPI, Request
from pydantic import SecretStr
from sqlalchemy import URL

from newsroom.bootstrap.config import ApiSettings
from newsroom.bootstrap.container import build_app
from newsroom.domain import kernel
from newsroom.domain.kernel import Actor
from newsroom.domain.publishing.article import Article
from newsroom.domain.publishing.use_cases import NewArticle
from newsroom.inbound.http.context import get_articles, get_services
from newsroom.inbound.http.problems import BY_KIND, REGISTRY
from support import WEBHOOK_KEY, bearer

NEW = {"slug": "hello-world", "title": "Hello", "body": "First post"}
JSON = {"Content-Type": "application/json"}
HOOK = "/internal/webhooks/moderation"
TENANT = uuid.uuid4()
AUTH = bearer(TENANT)


async def created(client: httpx2.AsyncClient) -> str:
    response = await client.post("/v1/articles", json=NEW | {"slug": f"a-{uuid.uuid4().hex}"}, headers=AUTH)
    assert response.status_code == 201
    return response.headers["location"]


@pytest.mark.parametrize(
    ("method", "url", "body", "headers", "slug", "evidence"),
    [
        ("GET", "/v1/articles", None, {"Authorization": ""}, "unauthenticated", "www-authenticate: Bearer"),
        (
            "GET",
            "/v1/articles",
            None,
            {"Authorization": "Bearer x.y"},
            "unauthenticated",
            'error="invalid_token"',
        ),
        ("GET", "/v1/nope", None, {}, "not-found", ""),
        ("DELETE", "/v1/articles", None, {}, "method-not-allowed", "allow: GET, POST"),
        ("POST", "/v1/articles", b'{"slug": ', JSON, "malformed-request", "not valid JSON"),
        ("POST", "/v1/articles", b"[" * 65_000, JSON | {"Idempotency-Key": "k"}, "malformed-request", ""),
        ("GET", "/v1/articles/42", None, {}, "malformed-request", "'article_id'"),
        ("GET", "/v1/articles?cursor=bm90LWEtY3Vyc29y", None, {}, "malformed-request", "cursor"),
        ("POST", "/v1/articles", b"x" * 70_000, JSON, "payload-too-large", ""),
        ("POST", "/v1/articles", b"{}", {"Content-Type": "text/json"}, "unsupported-media-type", ""),
        ("POST", HOOK, b"{}", {"webhook-id": "m", "webhook-timestamp": "9" * 5_000}, "unauthenticated", ""),
        (
            "POST",
            "/v1/articles",
            b'{"slug": "a", "title": " ", "x": 1}',
            JSON,
            "validation-failed",
            '"pointer":"#/x"',
        ),
        ("GET", "/v1/articles?limit=0", None, {}, "validation-failed", '"parameter":"limit"'),
        ("GET", "/v1/articles?sort=title", None, {}, "validation-failed", '"parameter":"sort"'),
        (
            "POST",
            "/v1/articles",
            b'{"slug": "nul", "title": "a\\u0000b"}',
            JSON,
            "validation-failed",
            '"pointer":"#/title"',
        ),
    ],
)
async def test_errors_are_problem_documents(
    client: httpx2.AsyncClient,
    method: str,
    url: str,
    body: bytes | None,
    headers: dict[str, str],
    slug: str,
    evidence: str,
) -> None:
    response = await client.request(method, url, content=body, headers=AUTH | headers)
    problem = response.json()
    assert (response.status_code, problem["status"]) == (REGISTRY[slug], REGISTRY[slug])
    assert (problem["type"], problem["instance"]) == (f"https://problems.test/{slug}", url.partition("?")[0])
    assert response.headers["content-type"] == "application/problem+json"
    assert evidence in response.text + "".join(f"{k}: {v}" for k, v in response.headers.items())
    assert response.headers["x-request-id"]


def test_every_error_kind_has_a_problem_type() -> None:  # a new kind fails here, not as a 500 in production
    rendered = {kernel.ValidationFailed, kernel.Unavailable, *BY_KIND}
    assert set(kernel.DomainError.__subclasses__()) <= rendered


async def test_request_ids_are_echoed_or_replaced(client: httpx2.AsyncClient) -> None:
    echoed = await client.get("/v1/articles", headers=AUTH | {"X-Request-Id": "abc-123"})
    assert (echoed.status_code, echoed.headers["x-request-id"]) == (200, "abc-123")
    replaced = await client.get("/v1/articles", headers=AUTH | {"X-Request-Id": "no spaces allowed"})
    assert replaced.headers["x-request-id"] != "no spaces allowed"
    preflight = {"Origin": "https://app.test", "Access-Control-Request-Method": "POST"}
    assert (await client.options("/v1/articles", headers=preflight)).headers["x-request-id"]


async def test_conditional_writes_and_authorization(client: httpx2.AsyncClient) -> None:
    url = await created(client)
    fetched = await client.get(url, headers=AUTH)
    assert (fetched.headers["etag"], fetched.json()["data"]["created_at"][-1]) == ('"1"', "Z")  # UTC
    patch = AUTH | {"If-Match": '"1"', "Content-Type": "application/merge-patch+json"}
    updated = await client.patch(url, content=b'{"title": "Edited", "body": null}', headers=patch)
    assert (updated.headers["etag"], updated.json()["data"]["body"]) == ('"2"', "")
    stale = await client.patch(url, content=b'{"title": "Late"}', headers=patch)
    assert stale.json()["type"] == "https://problems.test/precondition-failed"
    listed = await client.patch(url, json={"title": "L"}, headers=AUTH | {"If-Match": f'"{"9" * 30}", "2"'})
    assert listed.headers["etag"] == '"3"'  # any strong tag in the list may match; none reaches SQL
    assert (await client.patch(url, json={"title": None}, headers=AUTH)).status_code == 422
    assert (await client.post(f"{url}/publish", headers=bearer(TENANT, "bob"))).status_code == 403
    assert (await client.get(url, headers=bearer(uuid.uuid4()))).status_code == 404


async def test_idempotent_create_replays_and_rejects_reuse(client: httpx2.AsyncClient) -> None:
    headers = AUTH | {"Idempotency-Key": str(uuid.uuid4())}
    body = NEW | {"slug": "idempotent"}
    first = await client.post("/v1/articles", json=body, headers=headers)
    again = await client.post("/v1/articles", json=dict(reversed(body.items())), headers=headers)
    assert (again.status_code, again.headers["location"], again.content) == (
        201,
        first.headers["location"],
        first.content,
    )
    assert again.headers["idempotent-replayed"] == "true"
    reused = await client.post("/v1/articles", json=body | {"title": "Other"}, headers=headers)
    assert reused.json()["type"] == "https://problems.test/idempotency-key-mismatch"
    assert (
        await client.post("/v1/articles", json=body, headers=AUTH | {"Idempotency-Key": "a b"})
    ).status_code == 400


async def test_an_outcome_decided_by_a_header_is_not_stored(client: httpx2.AsyncClient) -> None:
    headers = AUTH | {"Idempotency-Key": str(uuid.uuid4())}
    body = b'{"slug": "retyped", "title": "T"}'
    wrong = await client.post("/v1/articles", content=body, headers=headers | {"Content-Type": "text/plain"})
    fixed = await client.post("/v1/articles", content=body, headers=headers | JSON)
    assert (wrong.status_code, fixed.status_code) == (415, 201)  # the corrected retry ran, not a replay


async def test_a_key_still_in_flight_answers_409(app: FastAPI, client: httpx2.AsyncClient) -> None:
    entered, release = asyncio.Event(), asyncio.Event()

    class Gated:  # holds the first request inside its transaction
        def __init__(self, request: Request) -> None:
            self.real = get_services(request).articles

        async def create(self, actor: Actor, new: NewArticle) -> Article:
            entered.set()
            await release.wait()
            return await self.real.create(actor, new)

    app.dependency_overrides[get_articles] = Gated
    headers = AUTH | {"Idempotency-Key": str(uuid.uuid4())}
    first = asyncio.create_task(client.post("/v1/articles", json=NEW | {"slug": "slow"}, headers=headers))
    await entered.wait()
    second = await client.post("/v1/articles", json=NEW | {"slug": "slow"}, headers=headers)
    release.set()
    assert (second.status_code, second.headers["retry-after"]) == (409, "1")
    assert (await first).status_code == 201


@pytest.mark.parametrize(("failure", "status"), [(RuntimeError("secret SQL"), 500), (None, 503)])
async def test_unknown_errors_and_the_deadline(
    app: FastAPI, client: httpx2.AsyncClient, failure: Exception | None, status: int
) -> None:
    class Broken:
        async def get(self, actor: Actor, article_id: uuid.UUID) -> NoReturn:
            if failure is None:  # outlives the one-second deadline, which cancels it
                await asyncio.sleep(5)
            raise failure or RuntimeError("the deadline never fired")

    app.dependency_overrides[get_articles] = Broken
    response = await client.get(f"/v1/articles/{uuid.uuid4()}", headers=AUTH | {"Origin": "https://app.test"})
    assert (response.status_code, response.headers["access-control-allow-origin"]) == (
        status,
        "https://app.test",
    )
    assert response.headers["x-request-id"]
    assert "SQL" not in response.text


def signed(body: bytes, message_id: str, age_s: int = 0) -> dict[str, str]:
    stamp = str(int(time.time()) - age_s)
    digest = hmac.digest(WEBHOOK_KEY, f"{message_id}.{stamp}.".encode() + body, hashlib.sha256)
    signature = f"v1,{base64.b64encode(digest).decode()}"
    return {"webhook-id": message_id, "webhook-timestamp": stamp, "webhook-signature": signature}


async def test_moderation_webhook_is_verified_and_deduplicated(client: httpx2.AsyncClient) -> None:
    url = await created(client)
    await client.post(f"{url}/publish", headers=AUTH)
    body = (
        f'{{"tenant_id": "{TENANT}", "article_id": "{url.rsplit("/")[-1]}", "verdict": "rejected"}}'.encode()
    )
    assert (await client.post(HOOK, content=body, headers=signed(b"{}", "m1"))).status_code == 401
    assert (await client.post(HOOK, content=body, headers=signed(body, "m1", age_s=301))).status_code == 401
    for _ in range(2):  # the redelivery is acknowledged without a second effect
        assert (await client.post(HOOK, content=body, headers=signed(body, "m1"))).status_code == 204
        archived = (await client.get(url, headers=AUTH)).json()["data"]
        assert (archived["status"], archived["version"]) == ("archived", 3)


async def test_readiness_is_a_local_latch(app: FastAPI, client: httpx2.AsyncClient) -> None:
    assert (await client.get("/readyz")).status_code == 200
    app.state.readiness.draining = True
    assert (await client.get("/readyz")).headers["retry-after"] == "1"
    assert (await client.get("/healthz")).status_code == 200


async def test_not_ready_before_the_lifespan_latches(app: FastAPI) -> None:  # no LifespanManager
    async with httpx2.AsyncClient(transport=httpx2.ASGITransport(app=app), base_url="http://t") as client:
        assert (await client.get("/readyz")).status_code == 503


async def test_startup_refuses_a_role_that_bypasses_row_level_security(
    settings: ApiSettings, owner_url: URL
) -> None:
    owner = SecretStr(owner_url.render_as_string(hide_password=False))
    with pytest.raises(RuntimeError, match="bypasses row-level security"):
        async with LifespanManager(build_app(settings.model_copy(update={"database_url": owner}))):
            pass
```

## Edge and configuration tests

The key source's failure modes, the body limit without a declared length, and each startup refusal that would otherwise fail in production.

```python file=tests/test_edge.py
import json
import uuid
from collections.abc import AsyncIterator

import httpx2
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from pydantic import ValidationError

from newsroom.bootstrap.config import ApiSettings
from newsroom.domain.kernel import Actor, Unavailable
from newsroom.inbound.http.auth import Authenticator
from newsroom.inbound.http.problems import Problem
from support import AUDIENCE, ISSUER, bearer, claims, key_endpoint

SIGNING_KEY = ec.generate_private_key(ec.SECP256R1())
KEY_SET = json.dumps(
    {"keys": [json.loads(jwt.algorithms.ECAlgorithm.to_jwk(SIGNING_KEY.public_key())) | {"kid": "k1"}]}
).encode()


@pytest.mark.parametrize(
    ("status", "body", "kid", "outcome"),
    [
        (200, KEY_SET, "k1", Actor),
        (200, KEY_SET, "rotated-away", Problem),  # the key set arrived and has no such key: the token's fault
        (503, b"down", "k1", Unavailable),
        (200, b"<html>maintenance</html>", "k1", Unavailable),
        (200, b'{"keys": []}', "k1", Unavailable),
    ],
)
async def test_a_failing_key_source_is_unavailable_not_unauthenticated(
    status: int, body: bytes, kid: str, outcome: type
) -> None:
    token = jwt.encode(claims(uuid.uuid4()), SIGNING_KEY, algorithm="ES256", headers={"kid": kid})
    with key_endpoint(status, body) as url:
        authenticator = Authenticator(issuer=ISSUER, audience=AUDIENCE, jwks_url=url)
        if outcome is Actor:
            assert (await authenticator.actor(token)).subject == "ada"
        else:
            with pytest.raises(outcome):
                await authenticator.actor(token)


async def test_a_body_without_a_declared_length_is_counted_too(client: httpx2.AsyncClient) -> None:
    async def chunks() -> AsyncIterator[bytes]:
        for _ in range(70):
            yield b"x" * 1024

    headers = bearer(uuid.uuid4()) | {"Content-Type": "application/json"}
    response = await client.post("/v1/articles", content=chunks(), headers=headers)
    assert (response.status_code, response.json()["type"]) == (413, "https://problems.test/payload-too-large")


@pytest.mark.parametrize(
    ("change", "refusal"),
    [
        ({"app_env": "production"}, "hs256 is refused in production"),
        ({"app_env": None}, "app_env"),  # unset must not mean development
        ({"request_timeout_ms": 6_000}, "must stay below SHUTDOWN_TIMEOUT_S"),
        ({"shutdown_drain_s": 5}, "must fit SHUTDOWN_GRACE_S"),
        ({"webhook_secrets": "whsec_not base64"}, "whsec_<base64>"),
    ],
)
def test_settings_refuse_at_startup_what_would_fail_later(
    settings: ApiSettings, change: dict[str, object], refusal: str
) -> None:
    values = {k: v for k, v in (settings.model_dump() | change).items() if v is not None}
    with pytest.raises(ValidationError, match=refusal) as refused:
        ApiSettings(**values)
    assert "input_value" not in str(refused.value)  # the error is logged: it must not quote a secret
```
