# FastAPI examples: reliability

What a trigger calls for (`SKILL.md` § Size the change): the idempotency wrapper and its store, the outbox with its relay, and the inbox behind the webhook receiver. Every `file=` block is a complete file of the project in `slice.md`.

## Contents

1. [Tables](#tables)
2. [Idempotency](#idempotency)
3. [Outbox and relay](#outbox-and-relay)
4. [Webhook receiver and inbox](#webhook-receiver-and-inbox)

## Tables

A second revision, so a service without these triggers ships without these tables. Infrastructure tables carry no row-level security, because the relay and the purge work across tenants.

```sql file=db/migrations/0002_reliability.sql
-- No row-level security on these: the relay and the purge work across tenants, and no request path
-- exposes them.
CREATE TABLE app.outbox (
    id               uuid        DEFAULT uuidv7() CONSTRAINT pk_outbox PRIMARY KEY,
    tenant_id        uuid        NOT NULL,
    aggregate_type   text        NOT NULL,
    aggregate_id     uuid        NOT NULL,
    aggregate_seq    integer     NOT NULL,
    event_type       text        NOT NULL,
    event_version    integer     NOT NULL,
    payload          jsonb       NOT NULL,
    headers          jsonb       NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    published_at     timestamptz,
    attempts         integer     NOT NULL DEFAULT 0,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    last_error       text,
    dead_lettered_at timestamptz,
    CONSTRAINT uq_outbox_aggregate_seq UNIQUE (aggregate_id, aggregate_seq)
);
-- The relay's claim and the oldest-pending-age metric read only pending rows.
CREATE INDEX idx_outbox_pending ON app.outbox (created_at)
    WHERE published_at IS NULL AND dead_lettered_at IS NULL;
-- The dead-letter depth, counted every pass without reading the published history.
CREATE INDEX idx_outbox_dead_lettered_at ON app.outbox (dead_lettered_at)
    WHERE dead_lettered_at IS NOT NULL;

CREATE TABLE app.idempotency_keys (
    scope        text        NOT NULL,
    key          text        NOT NULL,
    request_hash text        NOT NULL,
    lease_token  uuid        NOT NULL,
    locked_until timestamptz NOT NULL,
    expires_at   timestamptz NOT NULL,
    status       integer,
    headers      jsonb,
    body         bytea,
    completed_at timestamptz,
    CONSTRAINT pk_idempotency_keys PRIMARY KEY (scope, key)
);
CREATE INDEX idx_idempotency_keys_expires_at ON app.idempotency_keys (expires_at);

CREATE TABLE app.inbox (
    consumer    text        NOT NULL,
    message_id  text        NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_inbox PRIMARY KEY (consumer, message_id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.outbox, app.idempotency_keys, app.inbox TO app_rw;
```

```sql file=db/migrations/0002_reliability.rollback.sql
DROP TABLE app.inbox, app.idempotency_keys, app.outbox;
```

```python file=migrations/versions/0002_reliability.py
from pathlib import Path

from alembic import op

revision = "0002"
down_revision: str | None = "0001"
SQL = Path(__file__).parents[2] / "db" / "migrations"


def upgrade() -> None:
    op.get_bind().exec_driver_sql((SQL / "0002_reliability.sql").read_text())


def downgrade() -> None:
    op.get_bind().exec_driver_sql((SQL / "0002_reliability.rollback.sql").read_text())
```

## Idempotency

The port separates acquiring a key, which runs in its own short transaction before the work, from completing it, which runs inside the use case's transaction.

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

`IdempotentRoute` is the one wrapper. As a custom `APIRoute` it runs inside FastAPI's exception handlers: it sees the request before the route's dependencies, and an error before it is rendered, so a failed request rolls its writes back. A middleware would see only the rendered response, after the unit of work had committed.

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
# Decided by a header outside the hash (Accept, If-Match, Content-Type): stored, it would be replayed
# to the corrected retry.
_HEADER_DECIDED = frozenset({406, 412, 415, 428})
type Handler = Callable[[Request], Coroutine[Any, Any, Response]]


def _stored(response: Response) -> StoredResponse:
    headers = {name: response.headers[name] for name in _REPLAYED if name in response.headers}
    return StoredResponse(response.status_code, headers, bytes(response.body))


def _storable(status: int) -> bool:
    return status < HTTPStatus.INTERNAL_SERVER_ERROR and status not in _HEADER_DECIDED


class IdempotentRoute(APIRoute):
    """The one wrapper: it sees the request before the route's dependencies and the response after them."""

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
            target = f"{request.url.path}?{request.url.query}"
            digest = hashlib.sha256(f"{request.method} {target}\n{canonical}".encode()).hexdigest()
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
                    return await services.uow.run(actor, run_and_complete)
                except (DomainError, Problem, RequestValidationError, StarletteHTTPException) as error:
                    failed = respond(request, error)  # the handler's writes rolled back
                    if not _storable(failed.status_code):
                        raise
                    await services.uow.run(  # a 4xx decided by the body or the state replays too
                        actor, lambda tx: tx.idempotency.complete(scope, key, lease, _stored(failed))
                    )
                    return failed
            except BaseException:  # 5xx, header-decided, deadline, LeaseLost: the retry runs again
                await services.idempotency.release(scope, key, lease)
                raise

        return idempotent
```

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
            .values(
                lease_token=func.gen_random_uuid(),
                locked_until=func.now() + LEASE,
                # Extended too, or the purge deletes a key that is running again.
                expires_at=func.greatest(keys.c.expires_at, func.now() + TTL),
            )
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

## Outbox and relay

`PostgresOutbox` runs inside the unit of work. `OutboxRelay` runs on the bare pool, in its own process (`bootstrap/relay.py` in `service.md`), and publishes outside any transaction.

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
        propagate.inject(headers)  # traceparent: the relay's publish continues this trace
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
    attempts: int  # this delivery included; it fences the outcome


class EventPublisher(Protocol):
    async def publish(self, message: OutboxMessage) -> None: ...


class LogPublisher:  # a stand-in for your broker's client
    async def publish(self, message: OutboxMessage) -> None:
        log.info("event published", extra={"event_id": str(message.id), "event_type": message.event_type})


# Only a head is claimable (no earlier row of its aggregate pending), so a failing row holds its
# successors back until it is published or dead-lettered. MATERIALIZED runs the locking SELECT
# exactly once; as `WHERE id IN (SELECT ...)` it may be evaluated again and claim more than the batch.
_CLAIM = text("""
WITH c AS MATERIALIZED (
    SELECT o.id FROM app.outbox o
    WHERE o.published_at IS NULL AND o.dead_lettered_at IS NULL AND o.next_attempt_at <= now()
      AND NOT EXISTS (
          SELECT 1 FROM app.outbox e
          WHERE e.aggregate_id = o.aggregate_id AND e.aggregate_seq < o.aggregate_seq
            AND e.published_at IS NULL AND e.dead_lettered_at IS NULL)
    ORDER BY o.created_at, o.id
    LIMIT :batch
    FOR UPDATE SKIP LOCKED)
UPDATE app.outbox o
SET attempts = o.attempts + 1, next_attempt_at = now() + make_interval(secs => :lease)
FROM c WHERE o.id = c.id
RETURNING o.id, o.aggregate_id, o.aggregate_seq, o.event_type, o.event_version, o.payload, o.headers,
    o.attempts
""")
# Outcomes are fenced on the claim's attempts: a relay whose lease ran out cannot overwrite a newer claim.
_PUBLISHED = text("""
UPDATE app.outbox SET published_at = now(), last_error = NULL WHERE id = :id AND attempts = :attempts
""")
_FAILED = text("""
UPDATE app.outbox SET last_error = :error, next_attempt_at = now() + make_interval(secs => :delay),
    dead_lettered_at = CASE WHEN attempts >= :max_attempts THEN now() END
WHERE id = :id AND attempts = :attempts
""")
_OLDEST = text("""
SELECT extract(epoch FROM now() - min(created_at)) FROM app.outbox
WHERE published_at IS NULL AND dead_lettered_at IS NULL
""")
_DEAD = text("SELECT count(*) FROM app.outbox WHERE dead_lettered_at IS NOT NULL")


class OutboxRelay:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        publisher: EventPublisher,
        *,
        batch: int = 20,
        publish_timeout_s: float = 2.0,
        lease_s: float = 60.0,  # > batch x publish timeout, or a slow batch is claimed twice
        max_attempts: int = 10,
        backoff_base_s: float = 1.0,
    ) -> None:
        self.sessions, self.publisher, self.batch = sessions, publisher, batch
        self.publish_timeout_s, self.lease_s = publish_timeout_s, lease_s
        self.max_attempts, self.backoff_base_s = max_attempts, backoff_base_s
        self.oldest_pending_age_s, self.dead_letters = 0.0, 0  # alert on both: neither drains by itself

    async def run_once(self) -> int:
        async with self.sessions.begin() as session:  # the claim commits before anything is published
            rows = await session.execute(_CLAIM, {"batch": self.batch, "lease": self.lease_s})
            claimed = [OutboxMessage(**row) for row in rows.mappings()]
        for message in claimed:
            outcome: dict[str, Any] = {"id": message.id, "attempts": message.attempts}
            try:
                async with asyncio.timeout(self.publish_timeout_s):
                    await self.publisher.publish(message)
            except Exception as error:  # noqa: BLE001 - retried, then dead-lettered
                ceiling = min(300.0, self.backoff_base_s * 2**message.attempts)
                outcome |= {
                    "error": repr(error)[:500],
                    "delay": random.uniform(0, ceiling),  # noqa: S311 - full jitter
                    "max_attempts": self.max_attempts,
                }
                log.warning("outbox publish failed", extra={"event_id": str(message.id)})
                async with self.sessions.begin() as session:
                    await session.execute(_FAILED, outcome)
            else:
                async with self.sessions.begin() as session:
                    await session.execute(_PUBLISHED, outcome)
        return len(claimed)

    async def measure(self) -> None:
        async with self.sessions() as session:
            self.oldest_pending_age_s = float(await session.scalar(_OLDEST) or 0)
            self.dead_letters = int(await session.scalar(_DEAD) or 0)

    async def run(self, stop: asyncio.Event, *, idle_s: float = 1.0) -> None:
        """Claim until stopped; the batch in hand finishes first. An outage pauses it, never ends it."""
        outage = 0
        while not stop.is_set():
            try:
                claimed = await self.run_once()
                await self.measure()
                outage, pause = 0, idle_s
            except TRANSIENT:
                outage = min(outage + 1, 10)  # capped: 2.0**1024 overflows
                claimed, pause = 0, random.uniform(0, min(30.0, idle_s * 2**outage))  # noqa: S311
                log.warning("outbox relay backing off", exc_info=True)
            if not claimed:
                with contextlib.suppress(TimeoutError):
                    await asyncio.wait_for(stop.wait(), pause)
```

## Webhook receiver and inbox

The signature is verified over the raw bytes before anything is parsed. The inbox row and the effect share one unit of work, scoped to the tenant the signed payload names.

```python file=src/newsroom/outbound/postgres/inbox.py
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from newsroom.outbound.postgres.tables import inbox


class PostgresInbox:
    """Runs inside the unit of work, so a redelivery and the effect it would repeat share one commit."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def record(self, consumer: str, message_id: str) -> bool:
        query = (
            insert(inbox)
            .values(consumer=consumer, message_id=message_id)
            .on_conflict_do_nothing()
            .returning(inbox.c.message_id)
        )
        return (await self._session.execute(query)).scalar_one_or_none() is not None
```

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
