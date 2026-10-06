# Examples: Bootstrap & Testing

App orchestrator, main.py, config, pyproject.toml, and hex-specific test mocks.

## Table of Contents

1. [App Orchestrator](#app-orchestrator)
2. [Bootstrap](#bootstrap)
3. [Configuration](#configuration)
4. [pyproject.toml](#pyprojecttoml)
5. [Testing: Hex-Specific Mocks](#testing-hex-specific-mocks)
6. [Alembic Migrations](#alembic-migrations)
7. [Graceful Shutdown](#graceful-shutdown)

---

## App Orchestrator

```python
# src/app/application.py
"""Owns the event loop. Runs Shell + background workers as cooperative tasks.
For HTTP-only apps, skip this and call Shell.run() directly in main.py.
"""
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from app.config import AppConfig
from domain.authors.service import AuthorServiceImpl
from inbound.http.shell import Shell
from outbound.postgres.repository import PostgresAuthorRepository
from outbound.prometheus import PrometheusMetrics
from outbound.email_client import EmailNotifier


class Application:
    def __init__(self, config: AppConfig) -> None:
        self.config = config

    async def run(self) -> None:
        # The engine is owned here and threaded into both the repository
        # (via from_engine) and the Shell (for the /readyz healthcheck).
        engine = create_async_engine(
            self.config.database_url,
            pool_size=10,
            pool_timeout=3,
            pool_pre_ping=True,
        )
        repo = PostgresAuthorRepository.from_engine(engine)
        metrics = PrometheusMetrics()
        notifier = EmailNotifier()
        service = AuthorServiceImpl(repo, metrics, notifier)

        try:
            # TaskGroup cancels siblings on failure
            async with asyncio.TaskGroup() as tg:
                shell = Shell(self.config, service, engine=engine)
                tg.create_task(shell.run())
                # tg.create_task(scheduler.run())       # batch workers
                # tg.create_task(periodic_cleanup())     # periodic tasks
        finally:
            await engine.dispose()

    def shutdown(self) -> None:
        pass
```

## Bootstrap

```python
# src/app/main.py — no FastAPI, no SQLAlchemy imports
import asyncio
from app.config import AppConfig
from app.application import Application


def main() -> None:
    config = AppConfig()
    app = Application(config)
    try:
        asyncio.run(app.run())
    except KeyboardInterrupt:
        app.shutdown()


if __name__ == "__main__":
    main()
```

```bash
uv run python -m app.main
# Or with project script:
uv run serve
```

### Alternative: Simple HTTP-only (no orchestrator)

```python
# src/app/main.py
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from app.config import AppConfig
from domain.authors.service import AuthorServiceImpl
from inbound.http.shell import Shell
from outbound.sqlite.repository import SqliteAuthorRepository
from outbound.prometheus import PrometheusMetrics
from outbound.email_client import EmailNotifier


async def serve(config: AppConfig) -> None:
    engine = create_async_engine(config.database_url, pool_timeout=3)
    repo = SqliteAuthorRepository.from_engine(engine)
    service = AuthorServiceImpl(repo, PrometheusMetrics(), EmailNotifier())
    shell = Shell(config, service, engine=engine)
    try:
        await shell.run()
    finally:
        await engine.dispose()


def main() -> None:
    asyncio.run(serve(AppConfig()))


if __name__ == "__main__":
    main()
```

## Configuration

```python
# src/app/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict


class AppConfig(BaseSettings):
    database_url: str = "sqlite+aiosqlite:///./db.sqlite"
    # A dev default is provided here, so the app DOES start without SECRET_KEY.
    # The real safety net is not at the config level: create_access_token refuses
    # to sign a JWT while this placeholder is in effect (see auth.py guard).
    # Override via env in every non-dev environment.
    secret_key: str = "dev-only-change-me"
    port: int = 8080
    # CORS: explicit, non-wildcard defaults. Driven into the middleware from config.
    cors_origins: list[str] = ["http://localhost:3000"]
    cors_allow_methods: list[str] = ["GET", "POST", "PATCH", "DELETE", "OPTIONS"]
    cors_allow_headers: list[str] = ["Authorization", "Content-Type", "X-Request-Id"]
    cors_allow_credentials: bool = True
    access_token_expire_minutes: int = 15

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )
```

## pyproject.toml

```toml
[project]
name = "myapp"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115",
    "uvicorn[standard]>=0.34",
    "sqlalchemy[asyncio]>=2.0",
    "aiosqlite>=0.20",  # SQLite async driver (dev/test)
    "asyncpg>=0.30",    # Postgres async driver (production); or use "psycopg[binary]>=3.2" instead
    "pydantic-settings>=2.7",
    "PyJWT>=2.9",
    "pwdlib[argon2]>=0.2",
    "httpx>=0.28",
]

[dependency-groups]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.25",
    "alembic>=1.14",
]

[project.scripts]
serve = "app.main:main"
```

> These are floors, not pins. As of 2026-10 the current releases are well above them (fastapi 0.142, SQLAlchemy 2.1, alembic 1.20, pytest-asyncio 1.x — 1.0 removed the deprecated `event_loop` fixture, so don't copy older conftest snippets that override it). `uv.lock` records what you actually run.

```bash
uv sync                    # install all deps from uv.lock
uv run serve               # run via project script
uv run pytest              # run tests
uv add some-package        # add dependency
uv add --dev some-tool     # add dev dependency
```

---

## Testing: Hex-Specific Mocks

### Strategy

| Layer | Mock | What to test |
|-------|------|--------------|
| Handler | Mock service | HTTP parsing, status codes, error format |
| Service | Mock repo/metrics/notifier | Orchestration, side-effect ordering |
| Adapter | Real DB | SQL, error mapping, transactions |
| E2E | Nothing mocked | Critical happy paths |

### Mocks (Protocol-compatible, no framework needed)

```python
# tests/mocks.py
from uuid import UUID
from domain.authors.errors import CreateAuthorError, DuplicateAuthorError, UnknownAuthorError
from domain.authors.models import Author, CreateAuthorRequest, CursorPage


class MockAuthorRepository:
    """Stub — returns configured results.

    The real port contract says ``create_author`` MUST raise
    ``DuplicateAuthorError`` when the name already exists. The DB adapter gets
    this for free from a UNIQUE constraint (a race-safe backstop — an app-side
    check-then-insert would be TOCTOU). The mock has no DB, so it replicates the
    constraint in memory; otherwise service tests pass against behavior the
    production adapter doesn't have.
    """
    def __init__(self, create_result: Author | CreateAuthorError | None = None):
        self._create_result = create_result
        self.create_calls: list[CreateAuthorRequest] = []
        self._seen_names: set[str] = set()

    async def create_author(self, req: CreateAuthorRequest) -> Author:
        self.create_calls.append(req)
        if isinstance(self._create_result, Exception):
            raise self._create_result
        if req.name.value in self._seen_names:
            raise DuplicateAuthorError(name=req.name)
        self._seen_names.add(req.name.value)
        return self._create_result

    async def find_author(self, author_id: UUID) -> Author | None:
        return None

    async def list_authors(self, cursor: str | None, limit: int) -> CursorPage[Author]:
        return CursorPage(items=[], next_cursor=None, has_more=False)


class SaboteurRepository:
    """Saboteur — always raises to test error paths."""
    def __init__(self, error: Exception | None = None):
        self._error = error or UnknownAuthorError(RuntimeError("db on fire"))

    async def create_author(self, req: CreateAuthorRequest) -> Author:
        raise self._error

    async def find_author(self, author_id: UUID) -> Author | None:
        raise self._error

    async def list_authors(self, cursor: str | None, limit: int) -> CursorPage[Author]:
        raise self._error


class SpyMetrics:
    def __init__(self):
        self.successes = 0
        self.failures = 0
    async def record_creation_success(self) -> None: self.successes += 1
    async def record_creation_failure(self) -> None: self.failures += 1


class SpyNotifier:
    def __init__(self):
        self.notifications: list[Author] = []
    async def author_created(self, author: Author) -> None:
        self.notifications.append(author)


class NoOpMetrics:
    async def record_creation_success(self) -> None: pass
    async def record_creation_failure(self) -> None: pass

class NoOpNotifier:
    async def author_created(self, author: Author) -> None: pass
```

### Test app helpers

```python
# Use Shell.build_test_app() for handler/E2E tests (engine powers /readyz):
engine = create_async_engine("sqlite+aiosqlite:///:memory:")
app = Shell.build_test_app(service, test_config, engine=engine)
async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
    response = await client.post("/v1/authors", json={"name": "Test"})
    assert response.status_code == 201
    assert response.headers["Location"] == f"/v1/authors/{response.json()['data']['id']}"
    assert response.headers["X-Request-Id"]  # echoed/generated by middleware

# GET collection — pagination metadata is nested under `meta` (shared spec):
list_resp = await client.get("/v1/authors?limit=20")
body = list_resp.json()
assert isinstance(body["data"], list)
assert body["meta"]["limit"] == 20
assert "next_cursor" in body["meta"]
assert "has_more" in body["meta"]

# Use SqliteAuthorRepository.from_engine() for integration tests:
repo = SqliteAuthorRepository.from_engine(engine)
```

### conftest.py

```python
# tests/conftest.py
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine

from app.config import AppConfig
from domain.authors.service import AuthorServiceImpl
from inbound.http.shell import Shell
from outbound.postgres.models import Base  # ORM metadata for create_all
from outbound.sqlite.repository import SqliteAuthorRepository
from tests.mocks import NoOpMetrics, NoOpNotifier


@pytest.fixture
def test_config() -> AppConfig:
    return AppConfig(database_url="sqlite+aiosqlite:///:memory:", secret_key="test")


@pytest.fixture
async def db_engine():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
async def repo(db_engine):
    return SqliteAuthorRepository.from_engine(db_engine)


@pytest.fixture
async def service(repo):
    return AuthorServiceImpl(repo, NoOpMetrics(), NoOpNotifier())


@pytest.fixture
async def client(service, test_config, db_engine):
    # Engine threaded in so /readyz can probe the DB (mirrors production wiring).
    app = Shell.build_test_app(service, test_config, engine=db_engine)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
```

```ini
# pyproject.toml — pytest-asyncio config
[tool.pytest.ini_options]
asyncio_mode = "auto"
```

---

## Alembic Migrations

Migrations are infrastructure — they live outside the hex layers alongside config.

```
src/
├── alembic/
│   ├── env.py
│   ├── versions/
│   └── script.py.mako
├── alembic.ini
```

### Setup

```bash
uv run alembic init src/alembic
```

### env.py (async)

```python
# src/alembic/env.py
import asyncio
from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine
from app.config import AppConfig
from outbound.postgres.models import Base  # ORM metadata lives in outbound

config = context.config
target_metadata = Base.metadata


def run_migrations_offline():
    context.configure(url=AppConfig().database_url, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online():
    engine = create_async_engine(AppConfig().database_url)
    async with engine.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
```

### Usage

```bash
uv run alembic revision --autogenerate -m "add authors table"
uv run alembic upgrade head
uv run alembic downgrade -1
```

---

## Graceful Shutdown

```python
# src/app/application.py — improved with cleanup
from sqlalchemy.ext.asyncio import create_async_engine


class Application:
    def __init__(self, config: AppConfig) -> None:
        self.config = config
        self._engine = None

    async def run(self) -> None:
        self._engine = create_async_engine(
            self.config.database_url,
            pool_size=10,
            pool_timeout=3,
            pool_pre_ping=True,
        )
        repo = PostgresAuthorRepository.from_engine(self._engine)
        metrics = PrometheusMetrics()
        notifier = EmailNotifier()
        service = AuthorServiceImpl(repo, metrics, notifier)

        try:
            async with asyncio.TaskGroup() as tg:
                # Engine threaded into Shell so /readyz can probe the DB.
                shell = Shell(self.config, service, engine=self._engine)
                tg.create_task(shell.run())
        finally:
            await self._engine.dispose()
```
