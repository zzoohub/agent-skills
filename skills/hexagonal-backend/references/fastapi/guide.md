# FastAPI guide

How to build and change a FastAPI service so that it keeps the rules in `SKILL.md`: the decisions this stack forces, where it breaks a rule silently, and its traps. The code is one project, the publishing slice, split across `slice.md`, `reliability.md`, `service.md` and `tests.md`. Verified means that on the baseline below it passed every `ruff` rule, `mypy --strict`, the boundary check, `alembic check` and its tests on real PostgreSQL, and that its API and relay processes ran, drained and stopped.

## 0. Baseline

Verified 2026-11-18 against PyPI. Versions appear only here and in trap rows bound to a version.

| Package | Version | Note |
|---|---|---|
| CPython | 3.15.2 | Every dependency has a cp315 wheel for macOS arm64 and Linux. Not run on 3.14. |
| PostgreSQL | 18.7 | |
| fastapi | 0.163.1, pinned `<0.164` | Minors change behavior: read the release notes before moving the bound. |
| starlette | 1.10.0 | |
| uvicorn, uvloop, httptools | 0.54.0 pinned `<0.55`, 0.23.0, 0.9.0 | `DrainingServer` overrides uvicorn internals. Not `uvicorn[standard]`: it pulls PyYAML 6.0.3, which has no cp315 wheel. |
| pydantic, pydantic-settings | 2.14.3, 2.16.3 | |
| sqlalchemy[asyncio], psycopg[binary] | 2.1.9, 3.3.9 | |
| alembic | 1.20.1 | A runtime dependency: the release step runs from the service's image. |
| pyjwt[crypto], structlog | 2.15.1, 26.1.0 | |
| opentelemetry-sdk and -exporter-otlp-proto-http, -instrumentation-sqlalchemy | 1.45.2, 0.66b2 | |
| pytest, pytest-asyncio, httpx2, asgi-lifespan | 9.2.0, 1.5.0, 2.16.2, 2.1.0 | |
| ruff, mypy, import-linter (grimp), uv | 0.17.5, 2.4.1, 2.16 (3.20), 0.13.8 | |

Watch list: PostgreSQL 19. A SQLAlchemy instrumentation that declares 2.1 support. An OpenTelemetry instrumentation for httpx2.

FastAPI's wheel ships an agent skill (`fastapi/.agents/skills/fastapi/SKILL.md`). It wins on API details, and this guide on architecture. Skip its SQLModel, because one class as table, schema and model is the coupling the hexagon removes. Skip its `def` routes, `fastapi run` and auto-configured telemetry too (§ 1, § 9).

## 1. Decisions

- **Async end to end, offload on purpose.** A blocking call goes through `anyio.to_thread.run_sync`. *Why:* one blocking call in `async def` stalls every request, and each `def` dependency takes one of AnyIO's 40 thread tokens. *Break when* a sync-only library is the whole route: a `def` route is then the offload.
- **The use case owns the transaction.** `uow.run(actor, work)` runs in the use case, and a nested run for the same tenant joins through a `ContextVar`. *Why:* a yield dependency's exit code runs after the response is sent, so a commit failing there still answers 201.
- **A deadlock answers 503, and nothing retries in the server.** *Why:* constraints and guarded writes decide every race under READ COMMITTED, so serialization-class errors are rare. The client retries under its idempotency key. A retry loop in the unit of work would rerun the HTTP handler inside the idempotency wrapper. *Break when* database.md chooses SERIALIZABLE: retry the outermost run whole, bounded and jittered.
- **One error pipeline.** Handlers for `Problem`, `DomainError`, `RequestValidationError` and Starlette's `HTTPException`, and a pure-ASGI middleware for the rest. *Why:* only a middleware inside the request id and CORS can answer an unknown error with both (§ 9).
- **The lifespan owns resources, and each role is its own process.** *Why:* uvicorn runs the lifespan shutdown on SIGTERM and then re-raises the signal, so neither a `finally` around `run()` nor the line after it executes. `--workers N` multiplies pools. *Break when* one small VM hosts everything: own the signals, as `bootstrap/relay.py` does.
- **SQLAlchemy Core, mapped by hand.** *Why:* the writes that matter are SQL (guarded updates, `ON CONFLICT`, `SKIP LOCKED`), and the ORM's `version_id_col` checks the version the session loaded, not the one the client sent. *Break when* aggregates are deep: ORM classes in `outbound/`, `lazy="raise"`.

Failure semantics to keep in mind while coding:

- **Cancellation.** The deadline cancels the task at its current `await`. psycopg cancels the running statement on the server, and `sessionmaker.begin()` rolls back and returns the connection. A deadline never undoes a commit.
- **Propagation.** Only the outermost `run` begins and commits. A run for another tenant inside it raises.
- **Order.** `add_middleware` prepends: the last one added runs first.
- **Work must not outlive its unit.** With `close_resets_only=False`, a session used after its unit ended raises instead of quietly opening a new transaction.

## 2. Layout and composition

```text
src/newsroom/domain/             kernel (errors, Actor, events, Clock), idempotency port, publishing/
src/newsroom/inbound/            http/ (app, middleware, problems, auth, idempotency, routes), webhooks/
src/newsroom/outbound/postgres/  schema mirror, engine, unit of work, repository, outbox, inbox, keys
src/newsroom/bootstrap/          config, observability, composition, API and relay entrypoints
db/migrations/                   SQL, the source of truth
migrations/                      Alembic: env.py and one revision per SQL file
```

The package is built by `uv_build`, because without a build backend uv installs neither the package nor its scripts. `bootstrap/container.py` alone names concrete adapters. The lifespan yields `{"services": …}`, providers read it from `request.state`, and `app.dependency_overrides` is the test seam.

Against `SKILL.md` § Shape: the model is a frozen dataclass whose methods decide, and a use case passes a nested `async def work(tx)` to `uow.run`, because a lambda holds no statements. An edit bumps `version` in memory and writes it guarded on the version read. A transition takes `version + 1` from the row and returns the stored row, so an event's sequence is the stored version.

## 3. Edge

| # | Layer | Why here |
|---|---|---|
| 1 | FastAPI telemetry, `ServerErrorMiddleware` | Built in. |
| 2 | `RequestIdMiddleware` | Outermost of yours, so preflights and synthesized 500s carry `X-Request-Id`. |
| 3 | `CORSMiddleware` | Wraps every layer that can answer. |
| 4 | `EdgeMiddleware` | Body limit (413), deadline (503), security headers, the catch-all 500. |
| 5 | `ExceptionMiddleware` | FastAPI's handlers render known errors as problem documents. |
| 6 | routes | Probes first, without authentication. |

**Error pipeline.** `RequestValidationError` splits by cause into 400, 415 and 422. Starlette's `HTTPException` carries the router's 404 and 405, FastAPI's 400 for an unreadable body and our 413. It keeps its status and headers and takes the registry type when exactly one type has that status, `about:blank` otherwise (`http-api.md` § Problem types). A 429 or 503 gains `Retry-After`. Domain errors map by kind through `BY_KIND`, and a test fails when a kind is missing. An `openapi()` override files the problem model under `application/problem+json`.

**400 or 422.** A path parameter that is not a UUID, malformed JSON and a cursor this API did not issue are 400. A body FastAPI does not parse as JSON (only `application/json` and `application/*+json` are) is 415. Values that fail validation are 422 with `errors[]`: `pointer` for the body, `#` for all of it, a JSON `null` included, and `parameter` for query and headers. Every route declares a query model with `extra="forbid"`, the empty `NoQuery` when it takes none. Merge patch reads `model_fields_set` to tell absent from `null`.

**Limits and the deadline.** FastAPI reads the whole body into memory with no limit. `EdgeMiddleware` refuses a large `Content-Length` before reading and counts the bytes of a body that declares none, raising Starlette's `HTTPException(413)` from `receive`. uvicorn has no request timeout, so the middleware wraps the app in `asyncio.timeout`, which config keeps below the idempotency lease and the shutdown timeout. `Depends(max_concurrency=n)` queues callers and never sheds, so a shed is a 503 you raise.

## 4. Authentication and the Actor

`HTTPBearer(auto_error=False)` documents the scheme, and the code raises its own 401 with `WWW-Authenticate`. `jwt.decode` pins the algorithms and passes `options={"require": ["exp", "iss", "aud", "sub"]}`, because PyJWT accepts a token without them otherwise. HS256 is for development and tests, and config refuses it in production.

`PyJWKClient` caches the key set but fetches with blocking `urllib`, so it runs through `anyio.to_thread.run_sync` with a timeout. A key source that fails in any shape is a 503 (§ 9). An unknown `kid` on a healthy source stays a 401.

The `Actor` is decoded once per request and cached in the ASGI scope, because the idempotency wrapper needs it before the route's dependencies run. `sub` is stored, so it may not contain U+0000.

## 5. Persistence

**Two roles.** The release step connects as the owning role through `MIGRATION_DATABASE_URL`, which only `migrations/env.py` reads. The application connects as `app_rw` through `DATABASE_URL`, a login role that owns nothing and lacks BYPASSRLS, created outside the migrations. Startup refuses a role with SUPERUSER or BYPASSRLS, because row-level security does not apply to it and nothing says so. `alembic_version` stays in `public`, so the first revision can create schema `app`. That needs CREATE on `public`.

**The tenant per transaction.** The unit of work's first statement is `SELECT set_config('app.current_tenant', :tenant, true)`. It takes a bind parameter, which `SET LOCAL` cannot, and `true` makes it transaction-local: the session-level form leaks a tenant into the next checkout. The policy reads `NULLIF(current_setting(…, true), '')`, so a connection without a tenant sees no row. The repository is bound to the session and tenant and puts `tenant_id = :t` in every statement, which the planner needs. Reads run in a unit of work too, at one more round trip. Only the idempotency store, the relay and the startup ping use the bare pool.

**Error translation.** `IntegrityError` maps by constraint name (`error.orig.diag.constraint_name`): only `uq_articles_tenant_slug` becomes `AlreadyExists`, and a CHECK violation stays a 500. `OperationalError`, `InterfaceError` and the pool's `TimeoutError` become `Unavailable`: down, too slow, exhausted, past `statement_timeout`, or a deadlock victim. `hide_parameters=True` keeps bound values out of SQLAlchemy's error text, though a server message can still quote one.

**Concurrency and cursor.** The use case compares `If-Match` with the version it read, after the 404 and 403 decisions, and writes `UPDATE … WHERE version = :read`. Ids are UUIDv7, so newest first is `id < :cursor ORDER BY id DESC`, with no timestamp precision to lose.

**Pool and session.** `connect_timeout` bounds a hung connect, which `pool_timeout` does not. Startup `options` set `statement_timeout`, `idle_in_transaction_session_timeout` and `timezone=UTC`. Keep `(pool_size + max_overflow) × processes × replicas` within budget. Behind PgBouncer in transaction mode, set the timeouts on the role (§ 9), which reaches only server connections opened afterwards, and pass `prepare_threshold=None` if it tracks no prepared statements.

**Migrations.** The SQL files are the source of truth, and lock-safe execution belongs to database-design (`references/migration-patterns.md`, if available). Alembic runs each file through `exec_driver_sql`, one transaction per revision, with `lock_timeout` set. `alembic check` fails CI when `tables.py` drifts in tables, columns, types, nullability, or index and unique names. It ignores CHECK constraints and server defaults, so those live only in the SQL and the tests prove them.

## 6. Reliability

**Idempotency.** `IdempotentRoute` authenticates, hashes the method, the path with its query and the canonical body, and acquires in its own short transaction. It runs inside FastAPI's exception handlers, so it sees an error before it is rendered. The handler and `complete()` share one `uow.run`, which the use case joins. A 4xx rolls the writes back and is stored in a fresh transaction, so it replays. A 5xx, the deadline, a lost lease, or a status decided by a header outside the hash (406, 412, 415, 428) releases the key. `complete()` is fenced on the lease token. Taking over an expired lease extends the key's expiry, so the hourly purge cannot delete a key that is running again.

**Outbox relay.** A separate process. The claim is a `MATERIALIZED` CTE (§ 9) taking only each aggregate's head, with `FOR UPDATE SKIP LOCKED`, and moving `next_attempt_at` forward as the lease. Each publish runs outside any transaction under `asyncio.timeout`, and the lease must exceed the batch times that timeout. `attempts` counts deliveries, the current one included, and fences both outcome statements, so a relay whose lease ran out cannot overwrite a newer claim. Failures back off with full jitter and dead-letter. An outage pauses the loop, because an exit turns a failover into a crash loop. The relay exports the oldest pending age and the dead-letter depth. The trace context enters the row through `propagate.inject`.

**Webhooks.** An internal router, outside the schema and bearer authentication, that reads the raw bytes (§ 9). The Standard Webhooks HMAC is compared in constant time against every configured secret, within ±300 s. The timestamp must match `[0-9]{1,12}` before `int()`, because `isdigit()` accepts characters that `int()` rejects. The inbox row commits with the effect, so a duplicate, an unknown article, a wrong state and a payload that fails its schema are logged and acknowledged with 204. `Unavailable` answers 503 so the sender backs off.

**Scheduled work.** The relay purges expired keys hourly, which is safe on every replica because it is idempotent. A job that must not overlap takes an advisory lock.

## 7. Operability

**Readiness.** The lifespan pings the database once under a timeout and latches. A failure aborts startup with exit code 3. Afterwards `/readyz` reports only local state, and `/healthz` checks nothing.

**Shutdown.** SIGTERM → `DrainingServer` sets readiness to 503 and keeps serving for `SHUTDOWN_DRAIN_S` (0 where the platform stops routing first) → uvicorn stops accepting and drains requests within `timeout_graceful_shutdown`, which is unbounded by default → the lifespan closes the pool, then flushes telemetry → uvicorn re-raises SIGTERM, exit 143. Config refuses a grace below drain + shutdown timeout + 3 s of cleanup. Set `timeout_keep_alive` above the load balancer's idle timeout, because uvicorn's default of 5 s closes connections the balancer may reuse.

**Logs and telemetry.** structlog renders every stdlib logger, uvicorn's included with `log_config=None`, as JSON with `request_id`, `trace_id` and `span_id`, after a redaction step. The bootstrap installs the providers, and FastAPI's native telemetry uses them with `auto_configure: False`. It never records the exception on its spans, so `EdgeMiddleware` does, message included: keep values out of exception text.

## 8. Tests and gates

**Harness.** One database per session, with a non-UTC default zone that proves the UTC pin, migrated by `alembic upgrade head` in a subprocess. The application's pool connects as `app_rw`, so row-level security is on. Each test uses a fresh tenant, and only the relay tests empty `outbox`, because their claims cross tenants. `filterwarnings = ["error"]` turns leaked connections into failures.

**How each risk is forced.**

- Races: a repository whose `get` waits at an `asyncio.Barrier`, so every writer reads before any writes. A deadlock: two units lock one row each, meet at a barrier, then reach across.
- An in-flight key: a `dependency_overrides` entry holds the first request inside its transaction. A dead lease: age the row, take it over, let the first holder complete late.
- Tenant isolation: a count with no predicate sees one tenant inside a unit of work, none on the bare pool, none after the commit on the same connection.
- The relay's claim: planner settings that force a re-run subquery, a batch of 5 over 200 rows.
- A failed outbox write: the unit of work's `binder` swaps in a saboteur inside a real transaction.
- The deadline: a use case that sleeps past a one-second deadline.

**Gates**, in CI order: `uv sync --locked` → `ruff format --check .` → `ruff check .` → `mypy` → `python scripts/boundary.py` → `alembic upgrade head` and `alembic check` on an empty database → `pytest` → `newsroom-openapi > openapi.json` with no settings, then `git diff --exit-code openapi.json` and `oasdiff breaking` against the base branch.

## 9. Traps

Each row was reproduced on this baseline.

| Symptom | Cause | Fix |
|---|---|---|
| Handler tests fail: no attribute `services` | `ASGITransport` never runs the lifespan | `LifespanManager` |
| A test request sees the previous request's actor | asgi-lifespan hands every request the lifespan's state dict, so a `request.state` write leaks | Per-request data in the ASGI scope |
| A 500 without `X-Request-Id` or CORS headers | A handler for `Exception` runs in `ServerErrorMiddleware`, outside every middleware | The catch-all in a middleware inside both |
| 401, 404 and 405 answer `{"detail": …}` | The router raises Starlette's `HTTPException`, not FastAPI's | Handle Starlette's |
| `Allow` lists one method | Starlette names the methods of the first matching route | Recompute across `iter_route_contexts` |
| Malformed JSON or a text body answers 422 | One handler for every `RequestValidationError` | Split 400, 415 and 422 by cause (§ 3) |
| An unknown filter answers 200, unfiltered | FastAPI ignores undeclared query parameters | A query model with `extra="forbid"` |
| uvloop installed but unused | `Server.serve()` under your own `asyncio.run` | `Server.run()` |
| Requests hang while the database is unreachable | `pool_timeout` does not bound connecting | `connect_timeout` |
| GET answers `+09:00`, POST `Z` | psycopg returns `timestamptz` in the session's zone | `-c timezone=UTC` |
| Text with U+0000 answers 500 | psycopg refuses NUL in text, without a SQLSTATE | A model rule, so it is a 422 |
| One relay pass claims the whole backlog | `id IN (SELECT … LIMIT n FOR UPDATE SKIP LOCKED)`, re-run per row, skips the rows already updated, so the window slides | A `MATERIALIZED` CTE |
| A JSONB column holds a string | `json.dumps` output passed as the value | Pass dicts |
| `alembic check` wants to add every table | Schema `app` without `include_schemas=True` | `include_schemas`, `include_name` limited to `app` |
| Valid tokens answer 500 or 401 when the key source misbehaves | PyJWT raises `JSONDecodeError` for HTML, `PyJWKSetError` for an empty set | `KeySource.fetch_data` makes both a 503 |
| A settings error in the log shows part of a secret | Pydantic quotes the input | `hide_input_in_errors=True` |
| Webhook pushes rejected 422, retried forever | A sender without `Content-Type` meets a Pydantic body | Verify and parse the raw bytes |
| PgBouncer refuses the connection: unsupported startup parameter | Transaction pooling refuses `options` | Timeouts as role settings |
| The tracer provider gains a second span processor | `FASTAPI_OTEL_AUTO_CONFIGURE=true` with `auto_configure` unset | `auto_configure: False` in code |
| No database spans | instrumentation-sqlalchemy 0.66b2 declares SQLAlchemy below 2.1 and instruments nothing | `skip_dep_check=True` |
| Shutdown overruns the grace when the collector is down | OTLP exporters retry for 14 to 20 s while flushing | `timeout=1` per exporter |
| A sideways import passes the boundary check | `:` between siblings in a layers contract allows it | `\|` |
| The boundary check passes on code it never read | `root_packages` names a directory, or a package lacks `__init__.py`, which imports but which grimp skips | `boundary.py` compares the graph with the disk |
