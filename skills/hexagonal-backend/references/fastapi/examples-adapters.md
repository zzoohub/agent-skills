# Examples: Adapters

Inbound (Shell, handlers, task handlers, webhooks, auth, errors) and outbound (DB, ORM mapper, eager loading).

## Table of Contents

1. [Outbound: ORM Model + Mapper](#outbound-orm-model--mapper)
2. [Outbound: Postgres Adapter (ORM + mapper)](#outbound-postgres-adapter-orm--mapper)
3. [Outbound: SQLite Adapter (raw SQL, no ORM)](#outbound-sqlite-adapter-raw-sql-no-orm)
4. [Outbound: Eager Loading (N+1 Prevention)](#outbound-eager-loading-n1-prevention)
5. [Inbound: Task Handler (non-HTTP inbound adapter)](#inbound-task-handler-non-http-inbound-adapter)
6. [Inbound: Shell (wraps FastAPI + uvicorn)](#inbound-shell-wraps-fastapi--uvicorn)
7. [Inbound: Dependency Injection](#inbound-dependency-injection)
8. [Inbound: Auth Dependency](#inbound-auth-dependency)
9. [Inbound: Request / Response Schemas](#inbound-request--response-schemas)
10. [Inbound: Handler (Router)](#inbound-handler-router)
11. [Inbound: API Error (RFC 9457)](#inbound-api-error-rfc-9457)
12. [Inbound: Response Wrappers](#inbound-response-wrappers)
13. [Inbound: Pagination (cursor-based)](#inbound-pagination-cursor-based)
14. [Inbound: Healthcheck](#inbound-healthcheck)
15. [Outbound: UnitOfWork + Outbox Adapter (transactional, SQLAlchemy)](#outbound-unitofwork--outbox-adapter-transactional-sqlalchemy)
16. [Outbound: Idempotency Store](#outbound-idempotency-store)
17. [Outbound: Tracer Port (OTel)](#outbound-tracer-port-otel)

---

## Outbound: ORM Model + Mapper

```python
# src/outbound/postgres/models.py
from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, String, Uuid, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class AuthorModel(Base):
    """SQLAlchemy ORM model — outbound only. Never import in domain."""
    __tablename__ = "authors"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True)
    name: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    # Required by composite cursor pagination — index on (created_at, id).
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True,
    )


# src/outbound/postgres/mapper.py
from domain.authors.models import Author, AuthorName
from outbound.postgres.models import AuthorModel


class AuthorMapper:
    """ORM ↔ domain translation. Keeps domain free from SQLAlchemy."""

    @staticmethod
    def to_domain(row: AuthorModel) -> Author:
        return Author(id=row.id, name=AuthorName(row.name))

    @staticmethod
    def to_orm(author: Author) -> dict:
        return {"id": author.id, "name": author.name.value}
```

## Outbound: Postgres Adapter (ORM + mapper)

The repository is **session-based**: it never creates its own session in `__init__`. The session is supplied — that is what lets a `UnitOfWork` share one transaction across repos. For standalone wiring (no UoW), use the `from_engine` factory, which wraps each call in its own short-lived session + transaction.

```python
# src/outbound/postgres/repository.py
import uuid
import logging

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
)

from domain.authors.errors import DuplicateAuthorError, UnknownAuthorError
from domain.authors.models import Author, CreateAuthorRequest
from outbound.postgres.mapper import AuthorMapper
from outbound.postgres.models import AuthorModel

logger = logging.getLogger(__name__)


class PostgresAuthorRepository:
    """Operates on a supplied AsyncSession. Commit/rollback is owned by the
    caller (a UnitOfWork or the engine-backed factory below) — never here.
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @classmethod
    def from_engine(cls, engine: AsyncEngine) -> "EngineBackedAuthorRepository":
        """Standalone wiring (no UoW): each call runs in its own session + tx.

        Used by bootstrap (main.py / Application) and integration tests where
        there is no surrounding UnitOfWork to provide a session.
        """
        return EngineBackedAuthorRepository(engine)

    async def create_author(self, req: CreateAuthorRequest) -> Author:
        author_id = uuid.uuid4()
        try:
            model = AuthorModel(id=author_id, name=req.name.value)
            self._session.add(model)
            await self._session.flush()
        except IntegrityError:
            # UNIQUE(name) is the race-safe backstop; an app-side
            # check-then-insert would be TOCTOU. Let the constraint decide.
            raise DuplicateAuthorError(name=req.name)
        except Exception as exc:
            raise UnknownAuthorError(exc) from exc
        return Author(id=author_id, name=req.name)

    async def find_author(self, author_id: uuid.UUID) -> Author | None:
        result = await self._session.execute(
            select(AuthorModel).where(AuthorModel.id == author_id)
        )
        row = result.scalar_one_or_none()
        if row is None:
            return None
        return AuthorMapper.to_domain(row)


class EngineBackedAuthorRepository:
    """Wraps PostgresAuthorRepository with a per-call session + transaction.

    For standalone use outside a UnitOfWork. Same port (AuthorRepository),
    so the service/handlers don't know which one they got.
    """

    def __init__(self, engine: AsyncEngine) -> None:
        self._session_factory = async_sessionmaker(engine, expire_on_commit=False)

    async def create_author(self, req: CreateAuthorRequest) -> Author:
        async with self._session_factory() as session, session.begin():
            return await PostgresAuthorRepository(session).create_author(req)

    async def find_author(self, author_id: uuid.UUID) -> Author | None:
        async with self._session_factory() as session:
            return await PostgresAuthorRepository(session).find_author(author_id)

    async def list_authors(self, cursor: str | None, limit: int):
        async with self._session_factory() as session:
            return await PostgresAuthorRepository(session).list_authors(cursor, limit)
```

## Outbound: SQLite Adapter (raw SQL, no ORM)

```python
# src/outbound/sqlite/repository.py
import uuid
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from domain.authors.errors import DuplicateAuthorError, UnknownAuthorError
from domain.authors.models import Author, AuthorName, CreateAuthorRequest


class SqliteAuthorRepository:
    """Raw SQL — demonstrates adapters choose their own strategy.

    Engine-backed (this adapter is used standalone, not inside a UoW): each
    call opens its own short-lived session + transaction.
    """

    def __init__(self, engine: AsyncEngine) -> None:
        self._session_factory = async_sessionmaker(engine, expire_on_commit=False)

    @classmethod
    def from_engine(cls, engine: AsyncEngine) -> "SqliteAuthorRepository":
        """Mirror the Postgres adapter's wiring API."""
        return cls(engine)

    async def create_author(self, req: CreateAuthorRequest) -> Author:
        author_id = uuid.uuid4()
        async with self._session_factory() as session:
            async with session.begin():
                try:
                    await session.execute(
                        text("INSERT INTO authors (id, name) VALUES (:id, :name)"),
                        {"id": str(author_id), "name": req.name.value},
                    )
                except IntegrityError:
                    raise DuplicateAuthorError(name=req.name)
                except Exception as exc:
                    raise UnknownAuthorError(exc) from exc
        return Author(id=author_id, name=req.name)

    async def find_author(self, author_id: uuid.UUID) -> Author | None:
        async with self._session_factory() as session:
            result = await session.execute(
                text("SELECT id, name FROM authors WHERE id = :id"),
                {"id": str(author_id)},
            )
            row = result.fetchone()
            if row is None:
                return None
            return Author(id=uuid.UUID(row[0]), name=AuthorName(row[1]))
```

## Outbound: Eager Loading (N+1 Prevention)

> **Illustrative.** This snippet assumes a `Post` ORM model, a `posts`
> relationship on `AuthorModel`, and an `AuthorMapper.to_domain_with_posts()`
> method — none of which exist in the running example above. Treat `posts` /
> `to_domain_with_posts` as placeholders for your own related entity. The point
> is the pattern: in async SQLAlchemy, lazy loading raises, so eager-load
> relationships with `selectinload()`. The method is session-based like the rest
> of the repository (it runs against `self._session`).

```python
from sqlalchemy import select
from sqlalchemy.orm import selectinload

# Additional method on PostgresAuthorRepository (session-based).
# Indent this `async def` into the class body shown above — it is a method of
# PostgresAuthorRepository, not a module-level function.
async def find_author_with_posts(self, author_id: uuid.UUID) -> Author | None:
    result = await self._session.execute(
        select(AuthorModel)
        .options(selectinload(AuthorModel.posts))  # ✅ eager load (placeholder relation)
        .where(AuthorModel.id == author_id)
    )
    row = result.scalar_one_or_none()
    if row is None:
        return None
    return AuthorMapper.to_domain_with_posts(row)  # placeholder mapper method
```

---

## Inbound: Task Handler (non-HTTP inbound adapter)

```python
# src/inbound/tasks/handler.py
"""Task queue handler — inbound adapter.
Same pattern as HTTP: typed payload → try_into_domain() → service → ack.
"""
from pydantic import BaseModel
from fastapi import APIRouter, Depends

from domain.authors.models import CreateAuthorRequest, AuthorName
from domain.authors.ports import AuthorService
# Shared DI provider lives in a neutral module so one inbound adapter (tasks)
# doesn't reach into another's internals (inbound.http).
from inbound.shared.dependencies import with_author_service


class SyncAuthorTaskPayload(BaseModel):
    """Task-specific schema — decoupled from domain, same as HTTP request bodies."""
    author_name: str
    source: str

    def try_into_domain(self) -> CreateAuthorRequest:
        return CreateAuthorRequest(name=AuthorName(self.author_name))


def task_routes() -> APIRouter:
    router = APIRouter()

    @router.post("/tasks/sync-author")
    async def handle_sync_author(
        payload: SyncAuthorTaskPayload,
        service: AuthorService = Depends(with_author_service),
    ):
        domain_req = payload.try_into_domain()
        await service.create_author(domain_req)
        return {"status": "ok"}

    return router


# In Shell._build_app() — wire alongside REST routes:
# app.include_router(author_routes(), prefix="/v1/authors")  # user-facing
# app.include_router(task_routes())                          # task queue
# app.include_router(webhook_routes())                       # webhooks
```

---

## Inbound: Shell (wraps FastAPI + uvicorn)

```python
# src/inbound/http/shell.py
import uuid
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncEngine

from domain.authors.ports import AuthorService
from inbound.http.authors.router import author_routes
from inbound.http.errors import register_exception_handlers
from inbound.http.health import health_routes

REQUEST_ID_HEADER = "X-Request-Id"


class Shell:
    """HTTP interface. Wraps FastAPI so main.py never imports it."""

    def __init__(
        self, config, author_service: AuthorService, engine: AsyncEngine
    ) -> None:
        self.config = config
        # Engine is threaded in (not built here) so /readyz can probe the DB
        # using the same engine the repositories use.
        self.app = self._build_app(author_service, config, engine)

    async def run(self) -> None:
        server_config = uvicorn.Config(
            self.app, host="0.0.0.0", port=self.config.port, log_level="info",
        )
        server = uvicorn.Server(server_config)
        await server.serve()

    @staticmethod
    def _build_app(
        author_service: AuthorService, config, engine: AsyncEngine
    ) -> FastAPI:
        @asynccontextmanager
        async def lifespan(app: FastAPI):
            # Config goes into ASGI state so inbound deps (e.g. auth) read it
            # via request.state — no module-level singletons.
            yield {"author_service": author_service, "config": config}

        app = FastAPI(lifespan=lifespan)

        # Correlation id: echo an inbound X-Request-Id or generate one, expose
        # it on request.state for handlers/logs, and echo it on the response.
        # Registered before routers so it wraps every request. Per the shared
        # spec the id lives in the header, not the body.
        @app.middleware("http")
        async def request_id_middleware(request: Request, call_next):
            request_id = request.headers.get(REQUEST_ID_HEADER) or str(uuid.uuid4())
            request.state.request_id = request_id
            response = await call_next(request)
            response.headers[REQUEST_ID_HEADER] = request_id
            return response

        # CORS before routers (order matters). Methods/headers/credentials are
        # driven from config — no wildcards (a wildcard origin can't be combined
        # with credentials anyway).
        app.add_middleware(
            CORSMiddleware,
            allow_origins=config.cors_origins,
            allow_methods=config.cors_allow_methods,
            allow_headers=config.cors_allow_headers,
            allow_credentials=config.cors_allow_credentials,
        )
        app.include_router(author_routes(), prefix="/v1/authors")
        app.include_router(health_routes(engine))
        register_exception_handlers(app)
        return app

    @staticmethod
    def build_test_app(
        author_service: AuthorService, config, engine: AsyncEngine
    ) -> FastAPI:
        """For tests: returns ASGI app without uvicorn."""
        return Shell._build_app(author_service, config, engine)
```

## Inbound: Dependency Injection

The provider reads `request.state` (set in the Shell lifespan), so it works for
ANY inbound adapter — HTTP, tasks, webhooks. It therefore lives in a neutral
`inbound/shared/` module rather than under `inbound/http/`, so the tasks adapter
doesn't have to import from the HTTP adapter's internals.

```python
# src/inbound/shared/dependencies.py
from fastapi import Request
from domain.authors.ports import AuthorService


def with_author_service(request: Request) -> AuthorService:
    """ASGI lifespan state — framework-agnostic. Shared by all inbound adapters."""
    return request.state.author_service
```

```python
# src/inbound/http/dependencies.py
# HTTP-specific deps live here; re-export the shared provider for convenience
# so existing `from inbound.http.dependencies import with_author_service`
# call sites keep working.
from inbound.shared.dependencies import with_author_service  # noqa: F401
```

## Inbound: Auth Dependency

> **JWT algorithm.** Per the shared API spec, user-facing auth verified by
> *multiple* services should use an **asymmetric** algorithm (ES256/EdDSA): the
> issuer holds the private key, verifiers hold only the public key/JWKS. The
> `HS256` (symmetric) example below is the *single-service / dev* fallback —
> fine when one service both issues and verifies. To go asymmetric, sign with
> the private key (`algorithm="ES256"`) and decode with the public key. Either
> way, the algorithm is pinned on decode (never trust the token's `alg` header).
>
> The signing secret must be real. The example raises if it detects the
> dev-only placeholder so an HS256 service can never sign with `change-me`
> silently.

```python
# src/inbound/http/auth.py
"""Auth lives entirely in the inbound layer. Domain never handles tokens.
Config flows in via lifespan state — no module-level singletons (untestable)."""
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher

from app.config import AppConfig

# Single-service / dev fallback. For multi-service auth switch to ES256/EdDSA.
_ALGORITHM = "HS256"
_oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")
_oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)
_hasher = PasswordHash((Argon2Hasher(),))


def get_config(request: Request) -> AppConfig:
    """Read AppConfig set in Shell lifespan state — overridable in tests."""
    return request.state.config


def hash_password(password: str) -> str:
    return _hasher.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return _hasher.verify(password=plain, hash=hashed)

def create_access_token(user_id: int, secret_key: str, expires_minutes: int = 15) -> str:
    if not secret_key or secret_key == "dev-only-change-me":
        # Never sign real tokens with the placeholder secret.
        raise RuntimeError("SECRET_KEY is unset/placeholder; refusing to sign a JWT")
    expire = datetime.now(timezone.utc) + timedelta(minutes=expires_minutes)
    return jwt.encode(
        {"sub": str(user_id), "exp": expire},
        secret_key,
        algorithm=_ALGORITHM,
    )

def _decode_token(token: str, secret_key: str) -> int | None:
    try:
        payload = jwt.decode(token, secret_key, algorithms=[_ALGORITHM])
        return int(payload.get("sub"))
    except (jwt.InvalidTokenError, ValueError, TypeError):
        return None

async def get_current_user(
    token: str = Depends(_oauth2_scheme),
    config: AppConfig = Depends(get_config),
) -> int:
    user_id = _decode_token(token, config.secret_key)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user_id

async def get_current_user_optional(
    token: str | None = Depends(_oauth2_scheme_optional),
    config: AppConfig = Depends(get_config),
) -> int | None:
    if token is None:
        return None
    return _decode_token(token, config.secret_key)
```

## Inbound: Request / Response Schemas

```python
# src/inbound/http/authors/request.py
from pydantic import BaseModel
from domain.authors.models import AuthorName, CreateAuthorRequest


class CreateAuthorHttpRequestBody(BaseModel):
    """HTTP request body — decoupled from domain."""
    name: str

    def try_into_domain(self) -> CreateAuthorRequest:
        return CreateAuthorRequest(name=AuthorName(self.name))


# src/inbound/http/authors/response.py
from pydantic import BaseModel
from domain.authors.models import Author


class AuthorResponseData(BaseModel):
    """Public API representation — never expose domain models directly."""
    id: str
    name: str

    @classmethod
    def from_domain(cls, author: Author) -> "AuthorResponseData":
        return cls(id=str(author.id), name=author.name.value)
```

## Inbound: Handler (Router)

The router is mounted under `/v1/authors` in the Shell, so route paths here are
relative (`""`, `/{author_id}`). 201 responses set a `Location` header pointing
at the new resource (per the shared spec).

```python
# src/inbound/http/authors/router.py
from fastapi import APIRouter, Depends, Response
from domain.authors.ports import AuthorService
from inbound.http.authors.request import CreateAuthorHttpRequestBody
from inbound.http.authors.response import AuthorResponseData
from inbound.shared.dependencies import with_author_service
from inbound.http.response import Created


def author_routes() -> APIRouter:
    router = APIRouter()

    @router.post("", status_code=201)
    async def create_author(
        body: CreateAuthorHttpRequestBody,
        response: Response,
        service: AuthorService = Depends(with_author_service),
    ) -> Created[AuthorResponseData]:
        domain_req = body.try_into_domain()
        author = await service.create_author(domain_req)
        # Mounted at /v1/authors, so the resource URI is /v1/authors/{id}.
        response.headers["Location"] = f"/v1/authors/{author.id}"
        return Created(data=AuthorResponseData.from_domain(author))

    return router
```

## Inbound: API Error (RFC 9457)

Every error is `application/problem+json` (RFC 9457). The `instance` member
carries the request path; the correlation id lives in the `X-Request-Id`
response header (set by middleware), not the body. 422 responses map each
validation failure into the `errors` extension array.

```python
# src/inbound/http/errors.py
import logging
from typing import Any
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from domain.authors.errors import AuthorNameEmptyError, DuplicateAuthorError, UnknownAuthorError

logger = logging.getLogger(__name__)


def _problem(
    request: Request,
    type_slug: str,
    title: str,
    status: int,
    detail: str,
    errors: list[dict[str, Any]] | None = None,
) -> JSONResponse:
    body: dict[str, Any] = {
        "type": f"https://api.example.com/errors/{type_slug}",
        "title": title,
        "status": status,
        "detail": detail,
        "instance": request.url.path,
    }
    if errors is not None:
        body["errors"] = errors
    return JSONResponse(
        status_code=status,
        content=body,
        media_type="application/problem+json",
    )


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(DuplicateAuthorError)
    async def handle_duplicate(request: Request, exc: DuplicateAuthorError):
        return _problem(request, "duplicate-author", "Conflict", 409,
                        f"author with name {exc.name.value} already exists")

    @app.exception_handler(AuthorNameEmptyError)
    async def handle_empty_name(request: Request, exc: AuthorNameEmptyError):
        return _problem(request, "validation-error", "Unprocessable Entity", 422,
                        "author name cannot be empty")

    @app.exception_handler(UnknownAuthorError)
    async def handle_unknown(request: Request, exc: UnknownAuthorError):
        logger.error("Unexpected error: %s", exc.cause, exc_info=exc.cause)
        return _problem(request, "internal-error", "Internal Server Error", 500,
                        "An unexpected error occurred")

    @app.exception_handler(RequestValidationError)
    async def handle_validation(request: Request, exc: RequestValidationError):
        # Map FastAPI/Pydantic errors to the RFC 9457 `errors` extension array.
        errors = [
            {
                # loc is like ("body", "name"); the last element is the field.
                "field": ".".join(str(p) for p in err["loc"][1:]) or str(err["loc"][-1]),
                "code": err["type"],
                "message": err["msg"],
            }
            for err in exc.errors()
        ]
        return _problem(request, "validation-error", "Validation Failed", 422,
                        "One or more fields failed validation", errors=errors)

    @app.exception_handler(Exception)
    async def handle_generic(request: Request, exc: Exception):
        logger.error("Unhandled exception: %s", exc, exc_info=exc)
        return _problem(request, "internal-error", "Internal Server Error", 500,
                        "An unexpected error occurred")
```

## Inbound: Response Wrappers

```python
# src/inbound/http/response.py
from typing import Generic, TypeVar
from pydantic import BaseModel

T = TypeVar("T")

class ApiSuccess(BaseModel, Generic[T]):
    data: T

class Created(ApiSuccess[T]):
    pass

class Ok(ApiSuccess[T]):
    pass

class NoContent(BaseModel):
    pass

class CursorMeta(BaseModel):
    """Pagination metadata. Nested under `meta` per the shared API spec."""
    limit: int
    next_cursor: str | None
    has_more: bool

class CursorPageResponse(BaseModel, Generic[T]):
    # Collection shape: { "data": [...], "meta": { limit, next_cursor, has_more } }
    data: list[T]
    meta: CursorMeta
```

## Inbound: Pagination (cursor-based)

```python
# src/domain/authors/ports.py — add to AuthorRepository
class AuthorRepository(Protocol):
    async def list_authors(self, cursor: str | None, limit: int) -> CursorPage[Author]: ...

# src/outbound/postgres/cursor.py — composite cursor (created_at, id) opaque base64
import base64
import uuid
from datetime import datetime


def encode_cursor(created_at: datetime, id_: uuid.UUID) -> str:
    raw = f"{created_at.isoformat()}|{id_}"
    return base64.urlsafe_b64encode(raw.encode()).decode()


def decode_cursor(raw: str) -> tuple[datetime, uuid.UUID]:
    decoded = base64.urlsafe_b64decode(raw.encode()).decode()
    ts, id_str = decoded.split("|", 1)
    return datetime.fromisoformat(ts), uuid.UUID(id_str)


# src/outbound/postgres/repository.py — cursor pagination (method on the
# session-based PostgresAuthorRepository; runs against self._session).
# Indent this `async def` into the PostgresAuthorRepository class body — it is a
# method, not a module-level function.
from sqlalchemy import select, tuple_

async def list_authors(self, cursor: str | None, limit: int) -> CursorPage[Author]:
    # Order by (created_at, id) — single-column `id > X` skips/duplicates rows
    # when timestamps tie or rows are inserted between requests.
    query = select(AuthorModel).order_by(
        AuthorModel.created_at.asc(), AuthorModel.id.asc(),
    )
    if cursor:
        cursor_at, cursor_id = decode_cursor(cursor)
        query = query.where(
            tuple_(AuthorModel.created_at, AuthorModel.id) > (cursor_at, cursor_id)
        )
    # Fetch limit+1 to detect whether more rows exist.
    result = await self._session.execute(query.limit(limit + 1))
    rows = list(result.scalars().all())
    has_more = len(rows) > limit
    # Drop overflow row; cursor points at the LAST RETURNED row so the
    # next page resumes AFTER it (no duplicates, no skips).
    page_rows = rows[:limit]
    items = [AuthorMapper.to_domain(r) for r in page_rows]
    next_cursor = (
        encode_cursor(page_rows[-1].created_at, page_rows[-1].id)
        if has_more and page_rows else None
    )
    return CursorPage(items=items, next_cursor=next_cursor, has_more=has_more)

# src/inbound/http/authors/router.py — handler (FastAPI 0.95+ Annotated style)
# Add to the imports at the top of the router module:
#   from typing import Annotated
#   from fastapi import APIRouter, Depends, Query, Response
#   from inbound.http.response import Created, CursorMeta, CursorPageResponse
@router.get("")
async def list_authors(
    cursor: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    service: AuthorService = Depends(with_author_service),
) -> CursorPageResponse[AuthorResponseData]:
    page = await service.list_authors(cursor, limit)
    # Pagination metadata nested under `meta` per the shared API spec.
    return CursorPageResponse(
        data=[AuthorResponseData.from_domain(a) for a in page.items],
        meta=CursorMeta(
            limit=limit,
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )
```

## Inbound: Healthcheck

```python
# src/inbound/http/health.py
"""Healthcheck is infrastructure — not a domain concern.
Wire directly in Shell, no service needed. The engine is supplied by Shell."""
import logging

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

logger = logging.getLogger(__name__)


def health_routes(engine: AsyncEngine) -> APIRouter:
    router = APIRouter(tags=["health"])

    @router.get("/healthz")
    async def healthz():
        return {"status": "ok"}

    @router.get("/readyz")
    async def readyz():
        # DB unreachable → 503 (not ready), not a 500. A 503 tells the load
        # balancer to stop routing traffic until the dependency recovers.
        try:
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
        except Exception as exc:
            logger.warning("readiness probe failed: %s", exc)
            return JSONResponse(
                status_code=503,
                content={
                    "type": "https://api.example.com/errors/not-ready",
                    "title": "Service Unavailable",
                    "status": 503,
                    "detail": "database not reachable",
                },
                media_type="application/problem+json",
            )
        return {"status": "ready"}

    return router


# In Shell._build_app():
# app.include_router(health_routes(engine))
```

---

## Outbound: UnitOfWork + Outbox Adapter (transactional, SQLAlchemy)

Aggregate write and outbox row must commit atomically. SQLAlchemy's `AsyncSession` *is* the unit of work, so the cleanest pattern is a `UnitOfWork` port that scopes a session across multiple repositories.

```python
# src/domain/shared/events.py — plain data, no infra deps
from dataclasses import dataclass
from typing import Any

@dataclass(frozen=True)
class DomainEvent:
    aggregate_type: str
    aggregate_id: str
    event_type: str
    payload: dict[str, Any]
```

```python
# src/domain/shared/uow.py — port
from typing import Any, Protocol, Self
from domain.shared.events import DomainEvent
from domain.authors.ports import AuthorRepository

class OutboxRepository(Protocol):
    async def enqueue(self, events: list[DomainEvent]) -> None: ...

class UnitOfWork(Protocol):
    authors: AuthorRepository
    outbox: OutboxRepository
    session: Any  # opaque tx handle for ports that must join it (IdempotencyStore.complete)

    async def __aenter__(self) -> Self: ...
    async def __aexit__(self, exc_type, exc, tb) -> None: ...
```

```python
# src/outbound/postgres/uow.py — one AsyncSession shared across repos
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from outbound.postgres.repository import PostgresAuthorRepository
from outbound.postgres.outbox import PostgresOutboxRepository

class PostgresUnitOfWork:
    """Application service uses this to scope a tx across multiple repos."""

    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory
        self._session: AsyncSession | None = None

    async def __aenter__(self) -> "PostgresUnitOfWork":
        self._session = self._session_factory()
        await self._session.__aenter__()
        await self._session.begin()
        # Both repos take the SAME session = same transaction. This is exactly
        # why PostgresAuthorRepository.__init__ accepts a session rather than
        # building its own engine/session.
        self.authors = PostgresAuthorRepository(self._session)
        self.outbox = PostgresOutboxRepository(self._session)
        self.session = self._session  # what IdempotencyStore.complete() joins
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        assert self._session is not None
        if exc_type is not None:
            await self._session.rollback()
        else:
            await self._session.commit()
        await self._session.__aexit__(exc_type, exc, tb)
```

```python
# src/outbound/postgres/outbox.py
import json, uuid
from sqlalchemy import insert
from sqlalchemy.ext.asyncio import AsyncSession

from domain.shared.events import DomainEvent
from outbound.postgres.schema import outbox_table  # SQLAlchemy core Table


def current_traceparent() -> str | None:
    """Best-effort W3C traceparent for the active OTel span; None if untraced.

    Kept here so the outbox row captures trace context at write time. If you
    don't run OpenTelemetry, return None (or drop the column).
    """
    try:
        from opentelemetry import trace
        from opentelemetry.trace import format_span_id, format_trace_id

        span = trace.get_current_span()
        ctx = span.get_span_context()
        if not ctx.is_valid:
            return None
        return (
            f"00-{format_trace_id(ctx.trace_id)}-"
            f"{format_span_id(ctx.span_id)}-{ctx.trace_flags:02x}"
        )
    except Exception:
        return None


class PostgresOutboxRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def enqueue(self, events: list[DomainEvent]) -> None:
        if not events:
            return
        # Trace context captured at write time, not at relay time.
        traceparent = current_traceparent()
        rows = [{
            "id": uuid.uuid4(),
            "aggregate_type": e.aggregate_type,
            "aggregate_id": e.aggregate_id,
            "event_type": e.event_type,
            "payload": json.dumps(e.payload),
            "traceparent": traceparent,
        } for e in events]
        await self._session.execute(insert(outbox_table), rows)
```

```python
# Application service uses the UoW — tx boundary visible at the call site. A UoW holds
# per-tx state, so one per call, never shared: inject partial(PostgresUnitOfWork, sessions).
async def create_author(self, req: CreateAuthorRequest) -> Author:
    async with self._new_uow() as uow:
        author = await uow.authors.create_author(req)
        await uow.outbox.enqueue([DomainEvent(
            aggregate_type="author",
            aggregate_id=str(author.id),
            event_type="AuthorCreated",
            payload={"name": str(author.name)},
        )])
        # commit happens in __aexit__ on success
    await self._metrics.record_creation_success()
    return author
```

**Outbox relay** is a separate worker (started in lifespan, or a separate process). It polls `WHERE published_at IS NULL` and publishes asynchronously. Failures move to a `outbox_dead` table after N attempts.

### Common gotchas

- Don't let `AuthorRepository` create its own session in `__init__`. The session must be supplied — that's how UoW shares the tx.
- Don't call `await session.commit()` inside a repo method. Commit is owned by the UoW.
- `expire_on_commit=False` on the session factory — otherwise the entities you return become unusable after commit.

---

## Outbound: Idempotency Store

One row per `(scope, key)`: a lease while the first request runs, then its stored status and body. Only a write grants execution — this request's insert or a conditional takeover of an expired lease, never a read — and the result commits in the use case's transaction under the lease. Inbound mapping: a missing required key → **400**; `Replay` → its status and body (store `Location` beside the body if the route sets one); `Mismatch` → **422** problem, `type` `…/idempotency-key-mismatch`, no `errors[]`; `InFlight` → **409** problem, `type` `…/idempotency-in-flight`, plus `Retry-After`.

```python
# src/domain/shared/idempotency.py
from dataclasses import dataclass
from typing import Protocol
from uuid import UUID

@dataclass(frozen=True)
class NewExecution:
    lease: UUID  # proves ownership to complete() / release()
@dataclass(frozen=True)
class Replay:
    status: int
    body: bytes
@dataclass(frozen=True)
class Mismatch: ...  # same key, different request_hash — 422, never re-run
@dataclass(frozen=True)
class InFlight:
    retry_after_seconds: int  # live lease — 409 + Retry-After, never re-run
class LeaseLostError(Exception): ...  # complete() found its lease taken over — roll back

Acquire = NewExecution | Replay | Mismatch | InFlight

class IdempotencyStore[Tx](Protocol):  # Tx: the unit of work's session type (AsyncSession)
    async def acquire(self, scope: str, key: str, request_hash: str) -> Acquire: ...
    async def complete(  # inside the use case's transaction, under the lease
        self, session: Tx, scope: str, key: str, lease: UUID, status: int, body: bytes) -> None: ...
    async def release(self, scope: str, key: str, lease: UUID) -> None: ...  # failed before commit
    async def purge_expired(self) -> None: ...  # scheduled job
```

```python
# src/outbound/postgres/idempotency.py — migration: idempotency(scope, key, request_hash text,
# lease_token uuid, locked_until, expires_at timestamptz NOT NULL; status int, response bytea,
# completed_at timestamptz NULL), PRIMARY KEY (scope, key), index on expires_at
from datetime import timedelta
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from domain.shared.idempotency import Acquire, InFlight, LeaseLostError, Mismatch, NewExecution, Replay

# LEASE > the longest a handler holds the key. uvicorn has no request timeout: callers bound the
# use case with asyncio.timeout(REQUEST_TIMEOUT); timeout_graceful_shutdown only bounds the drain.
LEASE = timedelta(seconds=60)
TTL = timedelta(hours=24)  # >= the longest client retry horizon

_INSERT = text("""INSERT INTO idempotency (scope, key, request_hash, lease_token, locked_until,
    expires_at) VALUES (:s, :k, :h, gen_random_uuid(), now() + :lease, now() + :ttl)
    ON CONFLICT (scope, key) DO NOTHING RETURNING lease_token""")
_SELECT = text("""SELECT request_hash, completed_at, status, response,
    greatest(1, ceil(extract(epoch FROM locked_until - now())))::int AS retry_after
    FROM idempotency WHERE scope = :s AND key = :k""")
_TAKEOVER = text("""UPDATE idempotency SET lease_token = gen_random_uuid(),
    locked_until = now() + :lease WHERE scope = :s AND key = :k
    AND completed_at IS NULL AND locked_until < now() RETURNING lease_token""")
_COMPLETE = text("""UPDATE idempotency SET status = :st, response = :b, completed_at = now()
    WHERE scope = :s AND key = :k AND lease_token = :l AND completed_at IS NULL RETURNING 1""")
_RELEASE = text("""DELETE FROM idempotency
    WHERE scope = :s AND key = :k AND lease_token = :l AND completed_at IS NULL""")


class PostgresIdempotencyStore:
    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._sessions = session_factory

    async def acquire(self, scope: str, key: str, request_hash: str) -> Acquire:
        p = {"s": scope, "k": key, "h": request_hash, "lease": LEASE, "ttl": TTL}
        for _ in range(3):  # bounded: the row can vanish (release, purge) between INSERT and SELECT
            async with self._sessions.begin() as session:
                # Execution comes only from a write: this INSERT's returned row, or the takeover.
                lease = (await session.execute(_INSERT, p)).scalar_one_or_none()
                if lease is not None:
                    return NewExecution(lease)
                row = (await session.execute(_SELECT, p)).one_or_none()
                if row is None:
                    continue
                if row.request_hash != request_hash:
                    return Mismatch()
                if row.completed_at is not None:  # not `if row.response`: b"" is a valid body
                    return Replay(row.status, bytes(row.response))
                lease = (await session.execute(_TAKEOVER, p)).scalar_one_or_none()
                return NewExecution(lease) if lease is not None else InFlight(row.retry_after)
        return InFlight(1)

    async def complete(
        self, session: AsyncSession, scope: str, key: str, lease: UUID, status: int, body: bytes
    ) -> None:  # the use case's session: commits or rolls back with the business write
        p = {"s": scope, "k": key, "l": lease, "st": status, "b": body}
        if (await session.execute(_COMPLETE, p)).first() is None:
            raise LeaseLostError(key)  # taken over after the lease expired

    async def release(self, scope: str, key: str, lease: UUID) -> None:
        async with self._sessions.begin() as session:
            await session.execute(_RELEASE, {"s": scope, "k": key, "l": lease})

    async def purge_expired(self) -> None:
        async with self._sessions.begin() as session:
            await session.execute(text("DELETE FROM idempotency WHERE expires_at < now()"))
```

```python
# Application service, after acquire() → NewExecution(lease); `render` is the inbound serializer.
# No external call in the tx: record intent, derive the downstream key (reliability-patterns.md § 2).
try:
    try:
        async with asyncio.timeout(REQUEST_TIMEOUT), self._new_uow() as uow:  # timeout < LEASE
            status, body = render(await uow.authors.create_author(req))
            await self._idem.complete(uow.session, scope, key, lease, status, body)
    except DuplicateAuthorError as exc:  # deterministic 4xx: complete in a fresh tx (first aborted)
        status, body = render(exc)
        async with self._new_uow() as uow:
            await self._idem.complete(uow.session, scope, key, lease, status, body)
except BaseException:  # exception / 5xx / timeout / LeaseLostError, either branch: free the key
    await self._idem.release(scope, key, lease)
    raise
```

---

## Outbound: Tracer Port (OTel)

Don't import `opentelemetry.*` into the domain. Define a minimal `Protocol`; the OTel adapter implements it. Tests use a no-op or capturing implementation.

```python
# src/domain/shared/tracing.py
from typing import Protocol, Self

class Span(Protocol):
    def add_event(self, name: str, attrs: dict[str, str]) -> None: ...
    def record_error(self, err: BaseException) -> None: ...
    def __enter__(self) -> Self: ...
    def __exit__(self, *exc) -> None: ...

class Tracer(Protocol):
    def start_span(self, name: str, attrs: dict[str, str]) -> Span: ...
```

The OTel adapter (`src/outbound/otel.py`) wraps `opentelemetry.trace.get_tracer(...)`. The application service depends on the `Tracer` protocol, never on the SDK. This makes vendor swap a one-file change and lets tests run with zero observability cost.

For sampling, cardinality budgets, and span attribute conventions, see `software-architecture/references/observability.md`.
