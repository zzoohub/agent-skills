# FastAPI Stack Guide

How to build a hexagonal FastAPI service under this skill's contract (`SKILL.md`): the decisions this stack forces, how FastAPI, Starlette, uvicorn and SQLAlchemy fail, and the traps. The three `examples-*.md` files are one tenant-scoped publishing slice that passes `ruff` (all rules), `mypy --strict`, the import-linter boundary and its tests on PostgreSQL 18. Copy its shape; this file explains why.

## 0. Version baseline (verified 2026-10-08)

| Package | Version | Why it matters |
|---|---|---|
| CPython | 3.14.8; floor 3.14 here | the examples use `uuid.uuid7()`, deferred annotations (PEP 649) and `except A, B:` (PEP 758, ruff's 3.14 format); for 3.12–3.13, lower `requires-python`, parenthesize those `except` types, add `from __future__ import annotations` and a UUIDv7 package. Hold 3.15 until wheels land (httptools has no cp315 wheel) |
| fastapi | 0.142.4, `>=0.142.2,<0.143` | 0.142.0–.1 abort startup when `OTEL_EXPORTER_OTLP_ENDPOINT` is set without the OTel extra. Native OpenTelemetry since 0.142; JSON parsed only for JSON Content-Types since 0.132; yield-dependency exit after the response since 0.118 |
| starlette | 1.7.0 | 1.0 removed `on_event`; `max_body_size` (1.6) is not a FastAPI parameter |
| uvicorn[standard] | 0.54.0, `<0.55` | re-raises SIGTERM after its graceful stop; exit code 3 on startup failure; `DrainingServer` overrides its internals, so pin the minor |
| pydantic / pydantic-settings | 2.13.5 / 2.15.0 | `NoDecode` reads CSV lists from the environment |
| sqlalchemy[asyncio] | 2.1.4 (2026-10-07) | 2.1: Python ≥ 3.11, greenlet only through `[asyncio]`, psycopg 3 as the default PostgreSQL driver, `Result.tuples()` deprecated. 2.1.4 fixes a pooled connection leaked when the rollback inside `Connection.close()` fails |
| psycopg[binary] | 3.3.6 | the driver (`psycopg[c]` in production images); asyncpg 0.32 only by measured choice |
| alembic | 1.20.0; floor 1.18 | SQLAlchemy 2.1 support from 1.18; `[tool.alembic]` in pyproject |
| pyjwt[crypto] | 2.15.1 | 2026 security fixes in 2.12–2.14; refuses non-HTTP JWKS URIs; warns on HMAC keys under 32 bytes |
| structlog / opentelemetry-sdk / -exporter-otlp-proto-http / -instrumentation-sqlalchemy | 26.1.0 / 1.45.1 / 1.45.1 / 0.66b1 | JSON logs and the SDK the bootstrap owns; the SQLAlchemy instrumentation declares `sqlalchemy < 2.1` |
| pytest / pytest-asyncio | 9.1.1 / 1.4.0 | native `[tool.pytest]`; set the loop scope explicitly |
| httpx2 / asgi-lifespan | 2.13.1 / 2.1.0 | the test client; Starlette's TestClient prefers httpx2 since 1.2 |
| ruff / mypy / import-linter / uv | 0.16.10 / 2.4.0 / 2.15 / 0.12.23 | the gates |

Watch list: ty (beta), granian 2.8, free-threaded 3.14t, an OTel instrumentation for httpx2. FastAPI minors break: read their release notes, and verify against the registry or a doc-lookup tool if one is available. FastAPI ships an agent skill in its wheel (`fastapi/.agents/skills/fastapi/SKILL.md`); it wins on API minutiae, this guide on architecture: no SQLModel (one class as table, schema and domain is the coupling hexagonal removes), `async def` with explicit offload instead of `def` by default, and uvicorn run programmatically instead of `fastapi run`.

## 1. Approach a change in FastAPI

Answer SKILL.md Step 3 first. These are the decisions this stack adds.

- **Async end to end; offload on purpose.** Rule: routes, dependencies, use cases and adapters are `async def` on async drivers; a blocking or CPU-bound call goes to `anyio.to_thread.run_sync` (AnyIO's 40-token limiter) or a process pool behind a semaphore. Why: one blocking call in `async def` stalls every request on the loop (an argon2 verify takes about 30 ms), and every `def` dependency hops to the 40-thread pool, competing with real blocking work. Break when: a sync-only library is the whole route, so `def` is the offload; heavy inference belongs in its own worker or service.
- **The use case owns the transaction.** Rule: `uow.run(work)` inside the use case; repositories use the session it supplies and never commit. Why: since 0.118 a yield dependency's exit runs after the response is sent, so a commit failing there still answered 201, and the session stays checked out while a response streams. Break when: never for writes.
- **One error pipeline.** Rule: FastAPI handlers for `Problem`, `DomainError`, `RequestValidationError` and Starlette's `HTTPException`; a pure-ASGI middleware for the rest. Why: a handler for `Exception` lands in `ServerErrorMiddleware`, outside your middleware, so the 500 loses `X-Request-Id` and CORS, and Starlette re-raises after answering. Break when: never.
- **The lifespan owns resources.** Rule: build the engine and clients in the lifespan, hand them over as lifespan state, close them after `yield`. Why: uvicorn runs the lifespan shutdown on SIGTERM and then re-raises the signal: code after `server.run()`, or in a hand-rolled orchestrator's `finally`, never runs. Break when: process-wide caches that need no cleanup.
- **One process per role.** Rule: the API (one uvicorn worker per container, scaled by replicas), the outbox relay and scheduled jobs run as separate processes. Why: `--workers N` multiplies pools and model memory, and uvicorn's signal handling cuts co-located background tasks off. Break when: one small VM; then own the signals as the relay entrypoint does.
- **SQLAlchemy Core with explicit mapping.** Rule: Core tables mirror the SQL migrations; repositories map rows to the domain dataclass. Why: the writes that matter are SQL (version-guarded update, status-guarded transition, `ON CONFLICT`, `SKIP LOCKED`), and the ORM's `version_id_col` compares the version the session loaded, not the one the client sent. Break when: deep aggregates with relationships: ORM classes in `outbound/`, `lazy="raise"`, `selectinload`.

Failure semantics to keep in mind while coding:

- **Cancellation.** The request deadline cancels the task at its current `await`. `async with sessionmaker.begin()` still rolls back and returns the connection (SQLAlchemy shields that cleanup); a deadline never undoes a commit, so must-happen work goes through the outbox, not after the commit.
- **Transaction propagation.** A nested `uow.run` joins the outer transaction through a `ContextVar`; only the outermost run commits, retries 40001/40P01 and turns driver failures into `Unavailable` (503). The idempotency wrapper relies on this.
- **Lifecycle order.** `add_middleware` prepends: the last one added runs first.

## 2. Layout and composition

```text
src/newsroom/  domain/ (kernel, idempotency, publishing/{article, ports, use_cases})
               inbound/http/ (app factory and probes, problems, middleware, auth, context,
                              idempotency, articles)   inbound/webhooks/moderation
               outbound/postgres/ (tables, database, articles, uow, outbox, idempotency)   outbound/system
               bootstrap/ (config, observability, container, main: API, relay: worker)
db/migrations/*.sql   migrations/ (Alembic env and one revision per SQL file)   tests/
```

- One package (`uv_build`): without a build backend, uv installs neither the package nor its scripts (`[tool.uv] package = true` is the smallest fix for an existing project).
- Dependency injection: the lifespan yields `{"services": Services(...)}`; `async def` providers read `request.state.services`, and `Annotated` aliases (`ArticlesDep`) keep signatures short. `app.dependency_overrides` is the per-test seam. What must answer before the lifespan has run (the readiness latch, the problem base URI) lives on `app.state`.
- Never write per-request data to `request.state`: under asgi-lifespan it is the lifespan's dict itself, shared by every request (uvicorn copies it per request). Use the ASGI scope, as `authenticate()` does. Never annotate a dependency with `Request[State]`: FastAPI rejects it.
- `bootstrap/container.py` is the only module that sees every layer; `build_app(settings)` serves production and the tests alike.

## 3. HTTP edge

Middleware, outermost first:

| Layer | Why there |
|---|---|
| FastAPI telemetry, `ServerErrorMiddleware` | built in; the last-resort 500 lives outside your middleware |
| `RequestIdMiddleware` | outermost of yours: CORS preflights and synthesized 500s carry `X-Request-Id`; binds `request_id` for every log line |
| `CORSMiddleware` | wraps every layer that can answer; exposes `Location`, `ETag`, `Retry-After`, `X-Request-Id` |
| `EdgeMiddleware` | body limit (413), deadline (503), security headers and `Cache-Control: no-store`, the catch-all 500 |
| `ExceptionMiddleware` | FastAPI's handlers: every error becomes a problem document here |

Write middleware as pure ASGI. `BaseHTTPMiddleware` runs the app in another task and never sees a 500 rendered outside it.

**Error pipeline.** `RequestValidationError` splits by cause: `json_invalid` or a `path` location → 400; a body error at `("body",)` whose Content-Type FastAPI does not parse (it parses only `application/json` and `application/*+json`) → 415; anything else → 422 with `errors[]`, `pointer` for the body and `parameter` for query and headers. Starlette's `HTTPException` carries the router's 404 and 405, FastAPI's 400 for an unreadable body and our 413: map the known statuses, let any other keep its status and phrase, keep the headers, and recompute `Allow` across all routes, since Starlette lists only the first matching route's methods. Domain errors map by kind; `Unavailable` adds `Retry-After`. The one plain-text error left is Starlette's 400 to a disallowed CORS preflight; browsers never expose its body. For OpenAPI, declare the problem model for every error status on the router: that replaces FastAPI's `HTTPValidationError`, and an `openapi()` override moves the schema to `application/problem+json`, where FastAPI never files a `model`.

**Validation.** Write models use `extra="forbid"`; lengths sit in the schema for documentation and DoS bounds, the rule itself in the domain. JSON Merge Patch reads `model_fields_set` to tell absent from `null`. `limit` is `Query(ge=1)` (0 → 422 on `parameter`), clamped to the domain's `PAGE_MAX`, and `meta.limit` reports the value used. Sort and field selectors are `Literal` query types mapped to columns in the adapter; the cursor's version prefix names the sort it was issued for.

**Body limit and deadline.** FastAPI reads the whole body into memory and has no size limit, and Starlette's `RequestBodyLimitMiddleware` answers `text/plain`. `EdgeMiddleware` rejects a large `Content-Length` up front and counts chunked bytes in `receive`, raising Starlette's `HTTPException(413)`: FastAPI re-raises that from body parsing, while any other exception there becomes a 400. uvicorn has no request timeout, so the middleware wraps the app in `asyncio.timeout`, shorter than the idempotency lease (checked at startup).

## 4. Authentication and the Actor

- `HTTPBearer(auto_error=False)` documents the scheme; the code raises the 401 itself, with `WWW-Authenticate: Bearer`, plus `error="invalid_token"` when a token was sent.
- `jwt.decode` pins the algorithms (HS256, or ES256 and EdDSA with JWKS) and lists `exp`, `iss`, `aud` and `sub` under `options={"require": …}`: PyJWT checks `exp` only when present, and `iss` and `aud` only when you pass them.
- `PyJWKClient` caches the key set (`lifespan=300`) but fetches with blocking `urllib` on a miss: call it through `anyio.to_thread.run_sync`, with a timeout. A failed fetch is a 503 (`Unavailable`), not a 401.
- HS256 is for development and tests; settings refuse it in production. Secrets are `SecretStr`, 32 characters or more.
- The actor (`tid`, `sub`, `roles`) is decoded once per request and cached in the scope, because the idempotency wrapper needs it before the route's dependencies run.
- Passwords, if you hold them: pwdlib's `PasswordHash.recommended()` (argon2), verified off the loop, with a dummy-hash verify for unknown users.

## 5. Persistence

- **Engine.** Name the driver (`postgresql+psycopg://`). `pool_timeout` bounds only the wait for a pooled connection; `connect_timeout` bounds a hung connect. Session `options` set `statement_timeout`, `idle_in_transaction_session_timeout` and `timezone=UTC`; set `application_name`. Size `(pool_size + max_overflow) × processes × replicas` against the database budget, and remember that `max_overflow` defaults to 10. Set `hide_parameters=True` outside development, or SQLAlchemy's error text puts bound values in your logs. Behind PgBouncer in transaction mode, psycopg needs `prepare_threshold=None`; asyncpg needs a unique `prepared_statement_name_func` plus `NullPool`.
- **Unit of work.** `async with sessionmaker.begin()` commits or rolls back and always returns the connection, even when COMMIT fails or the task is cancelled. Retry 40001/40P01 in the outermost run only, bounded and jittered.
- **Constraint mapping.** Catch `IntegrityError` and map it by constraint name (psycopg: `error.orig.diag.constraint_name`; asyncpg: `error.orig.__cause__.constraint_name`). Map only the named unique constraint to `AlreadyExists`: a CHECK violation is a bug, so it stays a 500.
- **Concurrency.** Parse `If-Match` into the versions it lists (strong tags only). The use case compares them with the version it read, after its 404 and 403 checks, then writes `UPDATE … WHERE version = :read RETURNING`. A transition guards on status and takes `version = version + 1` from the row, so the event's `aggregate_seq` is the stored version.
- **Cursor.** The ids are UUIDv7, so newest-first is `id < :cursor ORDER BY id DESC` on `(tenant_id, id)`: exact, with no timestamp precision to lose. The cursor is unpadded base64url of `v1:<uuid>`, decoded with `validate=True`; a failure is `InvalidCursor` (400).
- **JSONB.** Pass dicts. A `json.dumps` string is stored as a JSON string, so `payload->>'slug'` is NULL.
- **Migrations.** The SQL files are the source of truth (database-design owns their content and lock-safe execution, if available). Alembic (start from `alembic init -t pyproject_async`) runs them with `exec_driver_sql`, which lets psycopg run a multi-statement file, one transaction per revision (`transaction_per_migration=True`), with `lock_timeout` and `statement_timeout` set in the connect options; a `CREATE INDEX CONCURRENTLY` revision runs inside `op.get_context().autocommit_block()`. Alembic is a runtime dependency: the release job runs `alembic upgrade head` once per release, never each replica at startup. `alembic check` against the migrated database fails CI when `tables.py` drifts from the SQL in tables, columns, types, nullability or indexes; it compares neither CHECK constraints nor server defaults. Autogenerate against a metadata that lacks a table proposes dropping it.

## 6. Reliability recipes

- **Idempotency.** `IdempotentRoute`, a custom `APIRoute`, is the one wrapper: it sees the request before the route's dependencies and the `Response` after them, for every route of its router. It validates the key (1–255 visible ASCII) → authenticates (scope = tenant + subject) → hashes method, path and canonical JSON → `acquire()` in its own transaction → replays (status, body, `Content-Type`, `Location`, `ETag`, `Idempotent-Replayed: true`), or answers 422 (mismatch) or 409 with `Retry-After: 1` (in flight) → otherwise runs the handler and `complete()` in one `uow.run`, which the use case joins. A 4xx rolls back and is stored in a fresh transaction; a 5xx, the deadline or `LeaseLost` releases the key. The lease (30 s) outlives the deadline; schedule `purge_expired()` from the platform scheduler.
- **Outbox relay.** It runs as its own process (`newsroom-relay`) that owns its signals. It claims each aggregate's head row with `FOR UPDATE SKIP LOCKED` in a short transaction, publishes outside it, then marks the row published or backs off with full jitter and dead-letters after N attempts. The bumped `next_attempt_at` is the claim's lease. A transient database error pauses the loop with the same capped, jittered backoff: an exit would turn a failover into a crash loop. The oldest pending age is an observable gauge; trace context enters the row through `propagate.inject` at insert.
- **Webhooks and push tasks.** Mount them on an internal router (`include_in_schema=False`, no bearer). Read the raw bytes before parsing: a Pydantic body parameter discards them, and senders such as Cloud Tasks set no Content-Type, which FastAPI rejects with a 422 that the queue retries until dead-letter. Verify the Standard Webhooks HMAC in constant time against every configured secret, within ±300 s (else 401). Insert the inbox row in the effect's transaction; duplicates and permanent outcomes acknowledge with 2xx and a log line; `Unavailable` answers 503 so the sender backs off.
- **AI and ML work.** Load models in the lifespan; never run inference inside `async def`. Bound the executor with a semaphore and shed load when it saturates. Long jobs return 202 with a job row; streams use `EventSourceResponse` and stop when the client disconnects.

## 7. Operability

- **Readiness.** The latch lives on `app.state`. The lifespan pings the database once under `asyncio.timeout`; a failure aborts startup (uvicorn exits with code 3, a visible crash loop). After that, `/readyz` reports only local state; `/healthz` checks nothing. Both are excluded from telemetry and sit outside auth.
- **Shutdown.** SIGTERM → `DrainingServer.handle_exit` sets readiness to 503 and keeps serving for `SHUTDOWN_DRAIN_S` (about 5 s on Kubernetes; 0 on Cloud Run, which stops routing at SIGTERM) → uvicorn stops accepting and drains in-flight requests within `timeout_graceful_shutdown` → the lifespan closes the pool, then flushes telemetry → uvicorn re-raises SIGTERM. Keep the drain delay plus the graceful timeout plus cleanup under the platform grace (Cloud Run 10 s, Kubernetes 30 s by default); with the defaults, a request at its 5 s deadline plus a flush to a hung collector ends in about 8 s. A second signal stops at once. Start the server with `run()`: only `run()` and the CLI install uvloop, and `serve()` under your own `asyncio.run` never uses it.
- **Network.** Set `timeout_keep_alive` above the load balancer's idle timeout (uvicorn's default of 5 s causes sporadic 502s), and `FORWARDED_ALLOW_IPS` to the proxy's addresses.
- **Logs.** structlog's `ProcessorFormatter` renders stdlib loggers (domain, SQLAlchemy, uvicorn with `log_config=None`) as JSON with `request_id`, `trace_id` and `span_id`, after a redaction step.
- **Traces and metrics.** FastAPI's native telemetry with `auto_configure=False` uses the providers the bootstrap installs; without an SDK it records nothing, silently. Do not add `opentelemetry-instrumentation-fastapi` on top. `SQLAlchemyInstrumentor` 0.66b1 instruments nothing on SQLAlchemy 2.1 (it logs an error): pass `skip_dep_check=True`, then check that spans appear. Give the OTLP exporters a short `timeout`: against an unreachable collector, the default retries stretched the final flush to 13.6 s, past Cloud Run's grace. `EdgeMiddleware` records each unhandled exception on the server span, message included: keep values out of exception text (`hide_parameters`), or redact in the collector.

## 8. Testing and CI

- **Database.** The session fixture creates a database on PostgreSQL 18, with a non-UTC default zone, and migrates it with `alembic upgrade head` in a subprocess: the release step itself. Each test uses a fresh tenant instead of truncating; only the relay test, whose claim spans tenants, empties `outbox`.
- **HTTP.** `LifespanManager(app)` plus `httpx2.ASGITransport(app=manager.app)`: ASGITransport alone never sends lifespan events, so no services exist. Hold a request inside its transaction with a gated `dependency_overrides` entry to test "in flight" deterministically.
- **pytest.** Set `asyncio_default_fixture_loop_scope` (pytest-asyncio warns when it is unset); `filterwarnings = ["error"]` turns leaked connections, deprecated APIs and short HMAC keys into failures.
- **Risk set.** Keyset walk, concurrent creates, outbox rollback, cross-tenant access and the relay run against the adapters; the problem matrix, `If-Match`, idempotency (replay, mismatch, in flight), the webhook and readiness run through HTTP, also on PostgreSQL.
- **Boundary.** import-linter with `root_packages` and `include_external_packages = true`; a layers contract whose sibling separator is `|` (with `:` the siblings may import each other); a `forbidden` contract keeping the domain off frameworks, ORMs, drivers and SDKs. A `root_package` pointing at `src` analyses zero imports and always passes.
- **Gates.** `scripts/ci.sh`: format, lint, `mypy --strict`, the boundary, `alembic upgrade` and `alembic check`, the tests, then the OpenAPI document, regenerated from code alone (no settings or secrets), diffed against the committed one.

## 9. Traps

| Symptom | Cause | Fix |
|---|---|---|
| Every handler test fails: no attribute `services` | `ASGITransport` never runs the lifespan | wrap the app in `LifespanManager` |
| A request sees the previous request's actor in tests | asgi-lifespan passes the lifespan state dict uncopied, so `request.state` writes leak | per-request data in the scope |
| 500 without `X-Request-Id` or CORS | the `Exception` handler runs in `ServerErrorMiddleware` | catch-all in pure-ASGI middleware inside both |
| 401, 404, 405 answer `{"detail": …}` | handlers only for FastAPI's `HTTPException` | handle Starlette's `HTTPException` |
| `Allow` lists one method | Starlette takes the first partially matching route | recompute across `iter_route_contexts` |
| Malformed JSON or a text body → 422 | one handler for every `RequestValidationError` | split 400 / 415 / 422 |
| Cleanup skipped on SIGTERM | uvicorn re-raises the signal after its graceful stop | resources in the lifespan; workers in their own processes |
| Requests hang while the database is unreachable | `pool_timeout` does not bound connecting | `connect_timeout` in `connect_args` |
| Pool slots vanish after failed commits | a hand-rolled unit of work skips `close()` | `async with sessionmaker.begin()` |
| A concurrent edit is lost despite `If-Match` | `version_id_col` checks the session's version; a `WHERE` on the client's number writes an edit derived from an older read | compare `If-Match` with the version read, then `UPDATE … WHERE version = :read` |
| GET answers `+09:00`, POST `Z` | psycopg returns `timestamptz` in the session's zone | `-c timezone=UTC` in the connect options |
| Autogenerate wants to drop tables | tables missing from the metadata | mirror every table; `alembic check` in CI |
| uvloop installed but unused | `Server.serve()` under `asyncio.run` | `Server.run()` |
| Startup aborts when the OTLP endpoint is set | FastAPI 0.142.0–.1 without the OTel extra | ≥ 0.142.2; bootstrap-owned providers |
| Boundary gate green with violations | `root_package = src`; `:` between siblings | `root_packages`, the `\|` separator, a `forbidden` contract |
| A JSONB column holds a string | `json.dumps` output passed as the value | pass dicts |
| Task or webhook pushes rejected 422, retried forever | strict Content-Type plus a Pydantic body | read and verify the raw bytes |
| A commit failure still answers 201 | a yield dependency exits after the response | commit inside the use case |
| A CHECK violation answers 409 "already exists" | every `IntegrityError` mapped to conflict | map by constraint name |
| No database spans | instrumentation-sqlalchemy 0.66b1 skips SQLAlchemy 2.1 | `instrument(..., skip_dep_check=True)` |
| Shutdown overruns the grace when the collector is down | OTLP exporters retry for seconds per signal while flushing | a short exporter `timeout` |
