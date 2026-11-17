# FastAPI examples: the service

What a new service needs: the app factory with its layer order, the edge middleware, authentication, configuration, logging and telemetry, the composition root, the entrypoints for the API, the relay and the release step, the manifest and the boundary check. Every `file=` block is a complete file of the project in `slice.md`.

## Contents

1. [App factory, probes and layer order](#app-factory-probes-and-layer-order)
2. [Edge middleware](#edge-middleware)
3. [Authentication](#authentication)
4. [Configuration](#configuration)
5. [Logging and telemetry](#logging-and-telemetry)
6. [Composition](#composition)
7. [Entrypoints](#entrypoints)
8. [Release step](#release-step)
9. [Manifest and tool configuration](#manifest-and-tool-configuration)
10. [Boundary check](#boundary-check)

## App factory, probes and layer order

`add_middleware` prepends, so the last one added runs first (`guide.md` § 3). The lifespan builds the services and latches readiness. Tests build the same app and serve it in process.

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

## Edge middleware

Pure ASGI, because the body limit must wrap `receive` and the request id must wrap `send`. The catch-all 500 lives here, inside the request id and CORS, and not in an exception handler for `Exception`, which Starlette runs outside every middleware.

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

## Authentication

The actor is decoded once per request and cached in the ASGI scope, because the idempotency wrapper needs it before the route's dependencies run.

```python file=src/newsroom/inbound/http/auth.py
from typing import Annotated, Any
from uuid import UUID

import anyio
import jwt
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, StringConstraints, ValidationError

from newsroom.domain.kernel import Actor, Unavailable
from newsroom.inbound.http.context import get_services
from newsroom.inbound.http.problems import Problem

bearer = HTTPBearer(auto_error=False)


class Claims(BaseModel):  # a malformed claim in a signed token is a 401
    # `sub` is stored as the author, and PostgreSQL text cannot hold U+0000.
    sub: Annotated[str, StringConstraints(min_length=1, max_length=255, pattern=r"^[^\x00]+$")]
    tid: UUID
    roles: tuple[str, ...] = ()


def unauthenticated(detail: str, *, invalid: bool) -> Problem:
    challenge = 'Bearer error="invalid_token"' if invalid else "Bearer"
    return Problem("unauthenticated", detail, headers={"WWW-Authenticate": challenge})


class KeySource(jwt.PyJWKClient):
    """Whatever keeps a key set from arriving is the key source's failure, never the token's."""

    def fetch_data(self) -> Any:  # noqa: ANN401 - the signature it overrides
        try:
            return super().fetch_data()
        except jwt.PyJWKClientConnectionError:
            raise
        except Exception as error:  # an HTML page, a JSON array, an empty key set
            raise jwt.PyJWKClientConnectionError("the key set is unusable") from error


class Authenticator:
    def __init__(
        self, *, issuer: str, audience: str, jwks_url: str | None = None, hs256_secret: str | None = None
    ) -> None:
        self._issuer, self._audience = issuer, audience
        self._jwks = None if jwks_url is None else KeySource(jwks_url, lifespan=300, timeout=3)
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

## Configuration

Validated once at startup. The checks keep the deadline below the shutdown timeout and the idempotency lease, and drain delay, shutdown timeout and cleanup inside the platform's grace period.

```python file=src/newsroom/bootstrap/config.py
import base64
import binascii
from typing import Annotated, Literal, Self

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

from newsroom.outbound.postgres.idempotency import LEASE

CLEANUP_S = 3.0  # pool close plus one telemetry flush per signal, each bounded at about a second
_SECRET_SAFE = SettingsConfigDict(frozen=True, hide_input_in_errors=True)  # a startup error quotes no input


class MigrationSettings(BaseSettings):
    """Read by migrations/env.py alone: the owning role's URL never reaches a serving process."""

    model_config = _SECRET_SAFE

    migration_database_url: SecretStr


class DatabaseSettings(BaseSettings):
    model_config = _SECRET_SAFE

    app_env: Literal["development", "test", "production"]  # no default: unset must not mean development
    database_url: SecretStr  # postgresql+psycopg://app_rw:...: the role row-level security applies to
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
    shutdown_drain_s: float = Field(0.0, ge=0)  # serve on while the load balancer deregisters
    shutdown_timeout_s: int = Field(6, gt=0)  # then in-flight requests get this long
    shutdown_grace_s: float = Field(10.0, gt=0)  # what the platform allows after SIGTERM

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
        deadline_s = self.request_timeout_ms / 1000
        if not deadline_s < min(self.shutdown_timeout_s, LEASE.total_seconds()):
            raise ValueError(
                "REQUEST_TIMEOUT_MS must stay below SHUTDOWN_TIMEOUT_S and the idempotency lease"
            )
        if self.shutdown_drain_s + self.shutdown_timeout_s + CLEANUP_S > self.shutdown_grace_s:
            raise ValueError(
                "SHUTDOWN_DRAIN_S + SHUTDOWN_TIMEOUT_S + 3 s of cleanup must fit SHUTDOWN_GRACE_S"
            )
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

The bootstrap owns the OpenTelemetry providers, and FastAPI's own telemetry is told not to configure any (`guide.md` § 7).

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

## Composition

The only module that names concrete adapters. `build_app` serves production and the tests alike.

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

## Entrypoints

The API process. uvicorn runs the lifespan shutdown on SIGTERM and then re-raises the signal, so nothing after `run()` executes.

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

The relay and the key purge, as a separate process that owns its signals.

```python file=src/newsroom/bootstrap/relay.py
import asyncio
import contextlib
import logging
import signal
from collections.abc import Awaitable, Callable

from opentelemetry import metrics
from opentelemetry.metrics import CallbackOptions, Observation

from newsroom.bootstrap.config import DatabaseSettings
from newsroom.bootstrap.container import database_config
from newsroom.bootstrap.observability import configure_logging, configure_telemetry
from newsroom.outbound.postgres import database
from newsroom.outbound.postgres.idempotency import PostgresIdempotencyStore
from newsroom.outbound.postgres.outbox import EventPublisher, LogPublisher, OutboxRelay

log = logging.getLogger(__name__)
PURGE_EVERY_S = 3600.0


async def every(period_s: float, job: Callable[[], Awaitable[object]], stop: asyncio.Event) -> None:
    """A periodic job that is safe on every replica because it is idempotent. One that must not
    overlap takes an advisory lock or moves to the platform's scheduler."""
    while not stop.is_set():
        try:
            await job()
        except database.TRANSIENT:
            log.warning("periodic job skipped: database unavailable", exc_info=True)
        with contextlib.suppress(TimeoutError):
            await asyncio.wait_for(stop.wait(), period_s)


async def work_until_stopped(settings: DatabaseSettings, publisher: EventPublisher) -> None:
    stop = asyncio.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):  # no uvicorn here: this process owns its signals
        asyncio.get_running_loop().add_signal_handler(sig, stop.set)
    engine = database.create_engine(database_config(settings, "newsroom-relay"))
    sessions = database.sessionmaker(engine)
    relay = OutboxRelay(sessions, publisher)

    def oldest_pending(_: CallbackOptions) -> list[Observation]:
        return [Observation(relay.oldest_pending_age_s)]

    def dead_letters(_: CallbackOptions) -> list[Observation]:
        return [Observation(relay.dead_letters)]

    meter = metrics.get_meter("newsroom.outbox")
    meter.create_observable_gauge("outbox.oldest_pending.age", [oldest_pending], unit="s")
    meter.create_observable_gauge("outbox.dead_letters", [dead_letters], unit="{event}")
    try:
        async with asyncio.TaskGroup() as tasks:
            tasks.create_task(relay.run(stop))
            tasks.create_task(every(PURGE_EVERY_S, PostgresIdempotencyStore(sessions).purge_expired, stop))
    finally:
        await engine.dispose()


def main() -> None:
    settings = DatabaseSettings()
    configure_logging()
    telemetry = configure_telemetry("newsroom-relay")
    try:
        asyncio.run(work_until_stopped(settings, LogPublisher()))
    finally:  # runs on SIGTERM too
        if telemetry is not None:
            telemetry.shutdown()
```

## Release step

Alembic runs the SQL files as the owning role, through a URL that no serving process reads.

```python file=migrations/env.py
import asyncio

from alembic import context
from sqlalchemy import Connection
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from newsroom.bootstrap.config import MigrationSettings
from newsroom.outbound.postgres.tables import metadata


def only_our_schema(name: str | None, type_: str, _parents: object) -> bool:
    return type_ != "schema" or name == metadata.schema


def migrate(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=metadata,
        transaction_per_migration=True,
        include_schemas=True,  # `alembic check` must reflect schema app, and only it
        include_name=only_our_schema,
    )
    with context.begin_transaction():
        context.run_migrations()


async def main() -> None:
    url = MigrationSettings().migration_database_url.get_secret_value()  # the owning role, never app_rw
    # Fail fast on locks instead of queueing live traffic behind DDL.
    session = {"options": "-c lock_timeout=2s -c statement_timeout=15min -c timezone=UTC"}
    engine = create_async_engine(url, poolclass=NullPool, connect_args=session)
    async with engine.connect() as connection:
        await connection.run_sync(migrate)
    await engine.dispose()


asyncio.run(main())
```

## Manifest and tool configuration

```toml file=pyproject.toml
[project]
name = "newsroom"
version = "0.1.0"
requires-python = ">=3.15"
dependencies = [
    "fastapi>=0.163.1,<0.164",  # minors break: read the release notes before moving the bound
    "uvicorn>=0.54,<0.55",  # DrainingServer overrides its internals
    "uvloop>=0.23",
    "httptools>=0.9",
    "pydantic>=2.14.3",
    "pydantic-settings>=2.16.3",
    "sqlalchemy[asyncio]>=2.1.9,<2.2",
    "psycopg[binary]>=3.3.9",
    "alembic>=1.20.1",  # runtime: the release step migrates from this image
    "pyjwt[crypto]>=2.15.1",
    "structlog>=26.1",
    "opentelemetry-sdk>=1.45.2",
    "opentelemetry-exporter-otlp-proto-http>=1.45.2",
    "opentelemetry-instrumentation-sqlalchemy>=0.66b2",
]

[project.scripts]
newsroom-api = "newsroom.bootstrap.main:serve"
newsroom-openapi = "newsroom.bootstrap.main:openapi"
newsroom-relay = "newsroom.bootstrap.relay:main"

[build-system]
requires = ["uv_build>=0.13.9,<0.14"]
build-backend = "uv_build"

[dependency-groups]
dev = [
    "pytest>=9.2",
    "pytest-asyncio>=1.5",
    "httpx2>=2.16.2",
    "asgi-lifespan>=2.1",
    "mypy>=2.4.1",
    "ruff>=0.17.5",
    "import-linter>=2.16",
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
files = ["src", "tests", "migrations", "scripts"]

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
"scripts/**" = ["INP001", "T201"]

[tool.importlinter]
root_packages = ["newsroom"]
include_external_packages = true

[[tool.importlinter.contracts]]
name = "Dependencies point inward"
type = "layers"
layers = [
    "newsroom.bootstrap",
    "newsroom.inbound | newsroom.outbound",  # `|`: siblings may not import each other; `:` would let them
    "newsroom.domain",
]
broken_contract_guidance = """\
Fix: the importing module reaches outward or sideways. Declare what it needs as a Protocol in \
newsroom.domain, implement it under newsroom.outbound, and pass the instance in from \
newsroom.bootstrap.container, the only module that may name concrete adapters."""

[[tool.importlinter.contracts]]
name = "The domain imports nothing that does I/O"
type = "forbidden"
source_modules = ["newsroom.domain"]
forbidden_modules = [
    "fastapi", "starlette", "pydantic", "pydantic_settings", "sqlalchemy", "psycopg", "alembic",
    "jwt", "structlog", "opentelemetry", "uvicorn", "httpx2", "anyio",
]
broken_contract_guidance = """\
Fix: keep frameworks, drivers and SDKs out of newsroom.domain. Put the call behind a Protocol the \
domain owns (ports.py), implement it under newsroom.outbound, and let the use case receive it. \
Time, ids and parsed input reach the model as arguments."""
```

## Boundary check

Run as `python scripts/boundary.py`. It runs the import-linter contracts in `pyproject.toml`, prints what to do about each violation, and fails when the graph is missing code that is on disk.

```python file=scripts/boundary.py
"""The boundary gate: the contracts in pyproject.toml, and proof that they were not kept vacuously.

import-linter keeps a contract on a graph that is missing the code it should judge. A wrong
`root_packages` leaves no internal import in the graph. A package directory without `__init__.py`
still imports, as a namespace package, but grimp leaves it and everything under it out.
So compare what the graph holds with what is on disk before trusting a green run.
"""

import sys
from pathlib import Path

import grimp
from importlinter import api, cli

roots = api.read_configuration()["session_options"]["root_packages"]
graph = grimp.build_graph(*roots, cache_dir=None)
domain = {m for m in graph.modules if m.startswith("newsroom.domain.")}
importers = {i for m in domain for i in graph.find_modules_that_directly_import(m)} - domain
if not domain or not importers:
    sys.exit(
        f"boundary: {len(domain)} domain modules, imported from {len(importers)} modules outside the domain. "
        "The contracts would pass on anything: point root_packages in [tool.importlinter] at the "
        "importable package (newsroom), not at a directory."
    )
on_disk = {".".join(p.relative_to("src").with_suffix("").parts) for p in Path("src").rglob("*.py")}
if unseen := sorted({m.removesuffix(".__init__") for m in on_disk} - graph.modules):
    sys.exit(
        f"boundary: {len(unseen)} modules are on disk but not in the graph, the first {unseen[0]}. "
        "The contracts never read them: add an empty __init__.py to every package directory."
    )
print(f"boundary: {len(graph.modules)} modules, {len(domain)} in the domain, imported from {len(importers)}")
sys.exit(cli.lint_imports())
```

Every package directory holds an `__init__.py`. Without one the package still imports, but the boundary check would not read it (`guide.md` § 9).

```python file=src/newsroom/__init__.py
"""The publishing service. Imports point inward: bootstrap, then inbound and outbound, then domain."""
```

```python file=src/newsroom/bootstrap/__init__.py
"""Configuration, wiring and entrypoints: the only package that names concrete adapters."""
```

```python file=src/newsroom/domain/__init__.py
"""The rules. No framework, driver or SDK is imported here, and scripts/boundary.py fails if one is."""
```

```python file=src/newsroom/domain/publishing/__init__.py
"""The publishing context: the article model, its ports and its use cases."""
```

```python file=src/newsroom/inbound/__init__.py
"""Adapters that call the use cases. They never import newsroom.outbound."""
```

```python file=src/newsroom/inbound/http/__init__.py
"""The public API: parsing, authentication, idempotency and problem documents."""
```

```python file=src/newsroom/inbound/webhooks/__init__.py
"""Routes for signed senders, outside bearer authentication and the OpenAPI document."""
```

```python file=src/newsroom/outbound/__init__.py
"""Adapters the use cases reach through ports. They never import newsroom.inbound."""
```

```python file=src/newsroom/outbound/postgres/__init__.py
"""PostgreSQL: the schema mirror, the unit of work, the repository and the infrastructure stores."""
```
