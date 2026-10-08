# FastAPI Examples: Bootstrap and Tests

Settings, wiring, processes, migrations, CI and tests; each block is a complete file. The tests need `TEST_DATABASE_URL`: a PostgreSQL 18 role that may create databases. `scripts/ci.sh` also needs `DATABASE_URL` for its migration gates.

## Contents

1. [Manifest and packages](#manifest-and-packages)
2. [Settings](#settings)
3. [Logging and telemetry](#logging-and-telemetry)
4. [Composition root](#composition-root)
5. [API process](#api-process)
6. [Relay worker](#relay-worker)
7. [Migration runner](#migration-runner)
8. [CI gates](#ci-gates)
9. [Test harness](#test-harness)
10. [PostgreSQL adapter tests](#postgresql-adapter-tests)
11. [HTTP tests](#http-tests)

## Manifest and packages

The package markers are empty files.

```toml file=pyproject.toml
[project]
name = "newsroom"
version = "0.1.0"
requires-python = ">=3.14"
dependencies = [
    "fastapi>=0.142.2,<0.143",
    "uvicorn[standard]>=0.54,<0.55",
    "pydantic>=2.13",
    "pydantic-settings>=2.15",
    "sqlalchemy[asyncio]>=2.1.4,<2.2",
    "psycopg[binary]>=3.3",
    "alembic>=1.20",  # runtime: the release step migrates from this image
    "pyjwt[crypto]>=2.15",
    "structlog>=26.1",
    "opentelemetry-sdk>=1.45",
    "opentelemetry-exporter-otlp-proto-http>=1.45",
    "opentelemetry-instrumentation-sqlalchemy>=0.66b1",
]

[project.scripts]
newsroom-api = "newsroom.bootstrap.main:serve"
newsroom-openapi = "newsroom.bootstrap.main:openapi"
newsroom-relay = "newsroom.bootstrap.relay:main"

[build-system]
requires = ["uv_build>=0.12.23,<0.13"]
build-backend = "uv_build"

[dependency-groups]
dev = [
    "pytest>=9.1",
    "pytest-asyncio>=1.4",
    "httpx2>=2.13",
    "asgi-lifespan>=2.1",
    "mypy>=2.4",
    "ruff>=0.16.10",
    "import-linter>=2.15",
]

[tool.alembic]
script_location = "%(here)s/migrations"

[tool.pytest]
minversion = "9.0"
testpaths = ["tests"]
addopts = ["--strict-markers"]
filterwarnings = ["error"]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
asyncio_default_test_loop_scope = "function"

[tool.mypy]
strict = true
plugins = ["pydantic.mypy"]
files = ["src", "tests", "migrations"]

[tool.ruff]
line-length = 110
src = ["src", "tests"]

[tool.ruff.lint]
select = ["ALL"]
ignore = [
    "D", "CPY", "COM812",  # docstrings and headers by judgment; COM812 fights the formatter
    "TC",  # FastAPI and Pydantic evaluate annotations at runtime: imports must stay real
    "N818", "TRY003", "EM101", "EM102",  # error kinds are named NotFound and carry a message
    "PLR0913", "PLR0917",  # FastAPI declares request inputs as parameters
]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101", "S105", "PLR2004", "INP001", "ARG002"]
"migrations/**" = ["INP001"]

[tool.importlinter]
root_packages = ["newsroom"]
include_external_packages = true

[[tool.importlinter.contracts]]
name = "Hexagonal layers"
type = "layers"
layers = [
    "newsroom.bootstrap",
    "newsroom.inbound | newsroom.outbound",
    "newsroom.domain",
]

[[tool.importlinter.contracts]]
name = "Domain imports no framework, ORM, driver or SDK"
type = "forbidden"
source_modules = ["newsroom.domain"]
forbidden_modules = [
    "fastapi", "starlette", "pydantic", "pydantic_settings", "sqlalchemy", "psycopg", "alembic",
    "jwt", "structlog", "opentelemetry", "uvicorn",
]
```

```python file=src/newsroom/__init__.py
```

```python file=src/newsroom/domain/__init__.py
```

```python file=src/newsroom/domain/publishing/__init__.py
```

```python file=src/newsroom/inbound/__init__.py
```

```python file=src/newsroom/inbound/http/__init__.py
```

```python file=src/newsroom/inbound/webhooks/__init__.py
```

```python file=src/newsroom/outbound/__init__.py
```

```python file=src/newsroom/outbound/postgres/__init__.py
```

```python file=src/newsroom/bootstrap/__init__.py
```

## Settings

```python file=src/newsroom/bootstrap/config.py
import base64
import binascii
from typing import Annotated, Literal, Self

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

from newsroom.outbound.postgres.idempotency import LEASE


class DatabaseSettings(BaseSettings):
    model_config = SettingsConfigDict(frozen=True)

    app_env: Literal["development", "test", "production"] = "development"
    database_url: SecretStr  # postgresql+psycopg://...
    db_pool_size: int = Field(10, ge=1)
    db_max_overflow: int = Field(5, ge=0)


class ApiSettings(DatabaseSettings):
    port: int = 8080
    jwt_mode: Literal["jwks", "hs256"]
    jwt_jwks_url: str | None = None
    jwt_issuer: str
    jwt_audience: str
    jwt_hs256_secret: SecretStr | None = None
    problem_base_uri: Annotated[str, Field(pattern=r"^https?://[^/\s]+(/\S*)?/$")]  # type = base + slug
    cors_origins: Annotated[tuple[str, ...], NoDecode] = ()  # CSV, not JSON
    request_timeout_ms: int = Field(5_000, gt=0)
    webhook_secrets: Annotated[tuple[SecretStr, ...], NoDecode] = ()  # whsec_<base64>, CSV
    shutdown_drain_s: float = Field(0.0, ge=0)
    shutdown_timeout_s: int = Field(6, gt=0)

    @field_validator("cors_origins", "webhook_secrets", mode="before")
    @classmethod
    def _csv(cls, value: object) -> object:
        return tuple(v.strip() for v in value.split(",") if v.strip()) if isinstance(value, str) else value

    @model_validator(mode="after")
    def _consistent(self) -> Self:
        if self.jwt_mode == "hs256":
            if self.app_env == "production":
                raise ValueError("JWT_MODE=hs256 is refused in production; use jwks")
            if self.jwt_hs256_secret is None or len(self.jwt_hs256_secret.get_secret_value()) < 32:  # noqa: PLR2004
                raise ValueError("JWT_HS256_SECRET must be at least 32 characters")
        elif not self.jwt_jwks_url:
            raise ValueError("JWT_JWKS_URL is required when JWT_MODE=jwks")
        if self.request_timeout_ms >= LEASE.total_seconds() * 1000:
            raise ValueError("REQUEST_TIMEOUT_MS must stay below the idempotency lease")
        self.webhook_keys()
        return self

    def webhook_keys(self) -> tuple[bytes, ...]:
        try:
            return tuple(
                base64.b64decode(s.get_secret_value().removeprefix("whsec_"), validate=True)
                for s in self.webhook_secrets
            )
        except binascii.Error as error:
            raise ValueError("WEBHOOK_SECRETS must be whsec_<base64> values") from error
```

## Logging and telemetry

```python file=src/newsroom/bootstrap/observability.py
import logging
import os
from collections.abc import MutableMapping
from typing import Any

import structlog
from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from sqlalchemy.ext.asyncio import AsyncEngine

REDACTED = frozenset({"authorization", "cookie", "password", "secret", "token", "idempotency_key"})
type EventDict = MutableMapping[str, Any]


def _trace_ids(_: object, __: str, event: EventDict) -> EventDict:
    context = trace.get_current_span().get_span_context()
    if context.is_valid:
        event["trace_id"], event["span_id"] = f"{context.trace_id:032x}", f"{context.span_id:016x}"
    return event


def _redact(_: object, __: str, event: EventDict) -> EventDict:
    return {k: "[redacted]" if k.lower() in REDACTED else v for k, v in event.items() if k != "color_message"}


def configure_logging(level: str = "INFO") -> None:
    chain: list[Any] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.ExtraAdder(),
        _trace_ids,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        _redact,
    ]
    handler = logging.StreamHandler()
    handler.setFormatter(
        structlog.stdlib.ProcessorFormatter(
            foreign_pre_chain=chain,
            processors=[
                structlog.stdlib.ProcessorFormatter.remove_processors_meta,
                structlog.processors.format_exc_info,
                structlog.processors.JSONRenderer(),
            ],
        )
    )
    logging.basicConfig(handlers=[handler], level=level, force=True)
    structlog.configure(
        processors=[*chain, structlog.stdlib.ProcessorFormatter.wrap_for_formatter],
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


class Telemetry:
    def __init__(self, service_name: str) -> None:
        resource = Resource.create({"service.name": service_name})
        self.tracing = TracerProvider(resource=resource)
        self.tracing.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(timeout=1)))
        reader = PeriodicExportingMetricReader(OTLPMetricExporter(timeout=1))
        self.metering = MeterProvider(resource=resource, metric_readers=[reader])
        trace.set_tracer_provider(self.tracing)
        metrics.set_meter_provider(self.metering)

    def instrument(self, engine: AsyncEngine) -> None:
        SQLAlchemyInstrumentor().instrument(engine=engine.sync_engine, skip_dep_check=True)

    def shutdown(self) -> None:
        self.tracing.shutdown()
        self.metering.shutdown()


def configure_telemetry(service_name: str) -> Telemetry | None:
    if not os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT"):
        return None
    return Telemetry(service_name)
```

## Composition root

```python file=src/newsroom/bootstrap/container.py
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from newsroom.bootstrap.config import ApiSettings, DatabaseSettings
from newsroom.bootstrap.observability import Telemetry
from newsroom.domain.publishing.use_cases import Articles
from newsroom.inbound.http.app import HttpConfig, Readiness, create_app
from newsroom.inbound.http.auth import Authenticator
from newsroom.inbound.http.context import Services
from newsroom.outbound.postgres import database
from newsroom.outbound.postgres.idempotency import PostgresIdempotencyStore
from newsroom.outbound.postgres.uow import PostgresUnitOfWork
from newsroom.outbound.system import SystemClock, Uuid7Ids


def database_config(settings: DatabaseSettings, application_name: str) -> database.DatabaseConfig:
    return database.DatabaseConfig(
        url=settings.database_url.get_secret_value(),
        application_name=application_name,
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        log_parameters=settings.app_env == "development",
    )


@asynccontextmanager
async def services(settings: ApiSettings, telemetry: Telemetry | None) -> AsyncIterator[Services]:
    engine = database.create_engine(database_config(settings, "newsroom-api"))
    try:
        if telemetry is not None:
            telemetry.instrument(engine)
        await database.ping(engine)  # the readiness latch's one round-trip
        sessions = database.sessionmaker(engine)
        uow = PostgresUnitOfWork(sessions)
        secret = settings.jwt_hs256_secret
        yield Services(
            articles=Articles(uow, SystemClock(), Uuid7Ids()),
            uow=uow,
            idempotency=PostgresIdempotencyStore(sessions),
            authenticator=Authenticator(
                issuer=settings.jwt_issuer,
                audience=settings.jwt_audience,
                jwks_url=settings.jwt_jwks_url if settings.jwt_mode == "jwks" else None,
                hs256_secret=secret.get_secret_value() if secret is not None else None,
            ),
            webhook_secrets=settings.webhook_keys(),
        )
    finally:  # after the drain: close the pool, then flush telemetry
        await engine.dispose()
        if telemetry is not None:
            telemetry.shutdown()


def build_app(
    settings: ApiSettings, readiness: Readiness | None = None, telemetry: Telemetry | None = None
) -> FastAPI:
    config = HttpConfig(
        problem_base_uri=settings.problem_base_uri,
        cors_origins=settings.cors_origins,
        request_timeout_s=settings.request_timeout_ms / 1000,
    )
    return create_app(config, lambda: services(settings, telemetry), readiness or Readiness())
```

## API process

```python file=src/newsroom/bootstrap/main.py
import json
import signal
import sys
import time
from types import FrameType

import uvicorn

from newsroom.bootstrap.config import ApiSettings
from newsroom.bootstrap.container import build_app
from newsroom.bootstrap.observability import configure_logging, configure_telemetry
from newsroom.inbound.http.app import Readiness


class DrainingServer(uvicorn.Server):
    """SIGTERM: readiness 503, serve on for drain_s, then stop. Overrides uvicorn internals."""

    def __init__(self, config: uvicorn.Config, readiness: Readiness, drain_s: float) -> None:
        super().__init__(config)
        self.readiness, self.drain_s = readiness, drain_s
        self.exit_at: float | None = None
        self.drain_signal = signal.SIGTERM

    def handle_exit(self, sig: int, frame: FrameType | None) -> None:
        self.readiness.draining = True
        if self.exit_at is None and self.drain_s > 0:
            self.exit_at, self.drain_signal = time.monotonic() + self.drain_s, signal.Signals(sig)
            return
        super().handle_exit(sig, frame)  # no drain delay, or a second signal

    async def on_tick(self, counter: int) -> bool:
        if self.exit_at is not None and time.monotonic() >= self.exit_at and not self.should_exit:
            super().handle_exit(self.drain_signal, None)
        return await super().on_tick(counter)


def serve() -> None:
    settings = ApiSettings()
    configure_logging()
    readiness = Readiness()
    app = build_app(settings, readiness, configure_telemetry("newsroom-api"))
    config = uvicorn.Config(
        app,
        host="0.0.0.0",  # noqa: S104
        port=settings.port,
        log_config=None,
        timeout_graceful_shutdown=settings.shutdown_timeout_s,
        timeout_keep_alive=75,
        server_header=False,
    )
    # uvicorn re-raises SIGTERM once stopped: nothing after this line runs.
    DrainingServer(config, readiness, settings.shutdown_drain_s).run()


def openapi() -> None:
    # The contract comes from code alone: no environment, secrets or database.
    app = build_app(ApiSettings.model_construct(problem_base_uri="https://problems.invalid/"))
    json.dump(app.openapi(), sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
```

## Relay worker

```python file=src/newsroom/bootstrap/relay.py
import asyncio
import signal

from opentelemetry import metrics
from opentelemetry.metrics import CallbackOptions, Observation

from newsroom.bootstrap.config import DatabaseSettings
from newsroom.bootstrap.container import database_config
from newsroom.bootstrap.observability import configure_logging, configure_telemetry
from newsroom.outbound.postgres import database
from newsroom.outbound.postgres.outbox import EventPublisher, LogPublisher, OutboxRelay


async def relay_until_stopped(settings: DatabaseSettings, publisher: EventPublisher) -> None:
    stop = asyncio.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):  # no uvicorn here: we own the signals
        asyncio.get_running_loop().add_signal_handler(sig, stop.set)
    engine = database.create_engine(database_config(settings, "newsroom-relay"))
    relay = OutboxRelay(database.sessionmaker(engine), publisher)

    def oldest_pending(_: CallbackOptions) -> list[Observation]:
        return [Observation(relay.oldest_pending_age_s)]

    meter = metrics.get_meter("newsroom.outbox")
    meter.create_observable_gauge("outbox.oldest_pending.age", [oldest_pending], unit="s")
    try:
        await relay.run(stop)
    finally:
        await engine.dispose()


def main() -> None:
    settings = DatabaseSettings()
    configure_logging()
    telemetry = configure_telemetry("newsroom-relay")
    try:
        asyncio.run(relay_until_stopped(settings, LogPublisher()))
    finally:  # runs on SIGTERM too
        if telemetry is not None:
            telemetry.shutdown()
```

## Migration runner

```python file=migrations/env.py
import asyncio

from alembic import context
from sqlalchemy import Connection
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from newsroom.bootstrap.config import DatabaseSettings
from newsroom.outbound.postgres.tables import metadata


def migrate(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=metadata, transaction_per_migration=True)
    with context.begin_transaction():
        context.run_migrations()


async def main() -> None:
    url = DatabaseSettings().database_url.get_secret_value()
    # Fail fast on locks instead of queueing live traffic behind DDL.
    session = {"options": "-c lock_timeout=2s -c statement_timeout=15min -c timezone=UTC"}
    engine = create_async_engine(url, poolclass=NullPool, connect_args=session)
    async with engine.connect() as connection:
        await connection.run_sync(migrate)
    await engine.dispose()


asyncio.run(main())
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

## CI gates

```bash file=scripts/ci.sh
#!/usr/bin/env bash
set -euo pipefail
uv sync --locked
uv run ruff format --check .
uv run ruff check .
uv run mypy
uv run lint-imports
uv run alembic upgrade head
uv run alembic check                      # tables.py still mirrors the SQL migrations
uv run pytest
uv run newsroom-openapi > openapi.json    # committed: a contract change shows in review
git ls-files --error-unmatch openapi.json > /dev/null  # an untracked file would diff clean
git diff --exit-code -- openapi.json
```

## Test harness

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
from sqlalchemy import make_url
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from newsroom.bootstrap.config import ApiSettings
from newsroom.bootstrap.container import build_app, database_config
from newsroom.outbound.postgres import database
from support import JWT_SECRET, WEBHOOK_KEY

ADMIN_URL = make_url(os.environ.get("TEST_DATABASE_URL", "postgresql+psycopg://postgres@127.0.0.1/postgres"))


@pytest.fixture(scope="session")
def database_url() -> Iterator[str]:
    name = f"newsroom_test_{uuid.uuid4().hex[:12]}"
    admin = ADMIN_URL.set(drivername="postgresql").render_as_string(hide_password=False)
    with psycopg.connect(admin, autocommit=True) as connection:
        connection.execute(f'CREATE DATABASE "{name}"')
        connection.execute(f"ALTER DATABASE \"{name}\" SET timezone = 'Asia/Seoul'")  # proves the UTC pin
    url = ADMIN_URL.set(database=name).render_as_string(hide_password=False)
    migrate = [sys.executable, "-m", "alembic", "upgrade", "head"]
    subprocess.run(migrate, env=os.environ | {"DATABASE_URL": url}, check=True)  # noqa: S603
    yield url
    with psycopg.connect(admin, autocommit=True) as connection:
        connection.execute(f'DROP DATABASE "{name}" WITH (FORCE)')


@pytest.fixture
def settings(database_url: str) -> ApiSettings:
    return ApiSettings(
        app_env="test",
        database_url=database_url,
        jwt_mode="hs256",
        jwt_hs256_secret=JWT_SECRET,
        jwt_issuer="https://issuer.test",
        jwt_audience="newsroom",
        problem_base_uri="https://problems.test/",
        cors_origins=("https://app.test",),
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
    async with LifespanManager(app) as manager:
        transport = httpx2.ASGITransport(app=manager.app)
        async with httpx2.AsyncClient(transport=transport, base_url="http://test") as client:
            yield client
```

```python file=tests/support.py
import time
from uuid import UUID

import jwt

JWT_SECRET = "test-only-hs256-secret-of-32-bytes!"
WEBHOOK_KEY = b"test-only-webhook-signing-key-32b"


def bearer(tenant: UUID, subject: str = "ada") -> dict[str, str]:
    claims = {
        "sub": subject,
        "tid": str(tenant),
        "roles": [],
        "iss": "https://issuer.test",
        "aud": "newsroom",
    }
    token = jwt.encode(claims | {"exp": int(time.time()) + 3600}, JWT_SECRET, algorithm="HS256")
    return {"Authorization": f"Bearer {token}"}
```

## PostgreSQL adapter tests

```python file=tests/test_postgres.py
import asyncio
import dataclasses
import uuid

import pytest
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from doubles import SaboteurOutbox
from newsroom.domain.kernel import Actor, DomainEvent, NotFound
from newsroom.domain.publishing.article import Article, Body, Slug, Status, Title
from newsroom.domain.publishing.ports import Transaction
from newsroom.domain.publishing.use_cases import Articles, NewArticle
from newsroom.outbound.postgres.outbox import OutboxMessage, OutboxRelay, PostgresOutbox
from newsroom.outbound.postgres.tables import outbox
from newsroom.outbound.postgres.uow import PostgresUnitOfWork, bind
from newsroom.outbound.system import SystemClock, Uuid7Ids

type Sessions = async_sessionmaker[AsyncSession]


def articles(sessions: Sessions, uow: PostgresUnitOfWork | None = None) -> Articles:
    return Articles(uow or PostgresUnitOfWork(sessions), SystemClock(), Uuid7Ids())


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

    await PostgresUnitOfWork(sessions).run(seed)
    for limit in (1, 2):
        walked, cursor = [], None
        while True:
            page = await articles(sessions).page(ada, cursor=cursor, limit=limit)
            walked += [a.id for a in page.items]
            if (cursor := page.next_cursor) is None:
                break
        assert walked == sorted((a.id for a in rows), reverse=True)


async def test_concurrent_duplicate_creates_have_one_winner(sessions: Sessions, ada: Actor) -> None:
    attempts = [articles(sessions).create(ada, NewArticle("same", "T")) for _ in range(5)]
    results = await asyncio.gather(*attempts, return_exceptions=True)
    assert sorted(type(r).__name__ for r in results) == ["AlreadyExists"] * 4 + ["Article"]


async def test_publish_writes_one_outbox_row_or_nothing(sessions: Sessions, ada: Actor) -> None:
    article = await articles(sessions).create(ada, NewArticle("hello", "Hello"))
    broken = PostgresUnitOfWork(
        sessions, binder=lambda s: dataclasses.replace(bind(s), outbox=SaboteurOutbox())
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


class Broker:
    def __init__(self, failing: uuid.UUID) -> None:
        self.failing, self.seen = failing, list[tuple[uuid.UUID, int]]()

    async def publish(self, message: OutboxMessage) -> None:
        if message.aggregate_id == self.failing:
            raise RuntimeError("broker down")
        self.seen.append((message.aggregate_id, message.aggregate_seq))


async def test_relay_publishes_heads_in_order_and_dead_letters(sessions: Sessions) -> None:
    healthy, poisoned = uuid.uuid4(), uuid.uuid4()
    event = DomainEvent(
        tenant_id=healthy,
        aggregate_type="article",
        aggregate_id=healthy,
        aggregate_seq=1,
        event_type="article.published",
        event_version=1,
        payload={},
    )
    async with sessions.begin() as session:
        await session.execute(text("TRUNCATE outbox"))
        for aggregate, last in ((healthy, 3), (poisoned, 2)):
            for seq in range(1, last + 1):
                await PostgresOutbox(session).append(
                    dataclasses.replace(event, aggregate_id=aggregate, aggregate_seq=seq)
                )
    broker = Broker(failing=poisoned)
    relay = OutboxRelay(sessions, broker, max_attempts=2, backoff_base_s=0)
    while await relay.run_once():
        pass
    assert broker.seen == [(healthy, 1), (healthy, 2), (healthy, 3)]
    dead = select(outbox.c.aggregate_seq, outbox.c.attempts).where(outbox.c.dead_lettered_at.is_not(None))
    async with sessions() as session:
        assert sorted(tuple(row) for row in await session.execute(dead)) == [(1, 2), (2, 2)]


async def test_the_relay_outlives_a_database_outage(caplog: pytest.LogCaptureFixture) -> None:
    engine = create_async_engine("postgresql+psycopg://postgres@127.0.0.1:1/down")  # refused
    relay, stop = OutboxRelay(async_sessionmaker(engine), Broker(failing=uuid.uuid4())), asyncio.Event()
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
from fastapi import FastAPI, Request

from newsroom.domain.kernel import Actor
from newsroom.domain.publishing.article import Article
from newsroom.domain.publishing.use_cases import NewArticle
from newsroom.inbound.http.context import get_articles, get_services
from newsroom.inbound.http.problems import REGISTRY
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


@pytest.mark.parametrize(("failure", "status"), [(RuntimeError("secret SQL"), 500), (TimeoutError(), 503)])
async def test_unknown_errors_and_deadlines(
    app: FastAPI, client: httpx2.AsyncClient, failure: Exception, status: int
) -> None:
    class Broken:
        async def get(self, actor: Actor, article_id: uuid.UUID) -> NoReturn:
            raise failure

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
```
