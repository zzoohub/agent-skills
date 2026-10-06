---
name: hexagonal-backend
description: |
  Hexagonal (ports & adapters) backend implementation: one shared contract plus stack guides for Axum (Rust, utoipa-axum, sqlx), FastAPI (Python, Pydantic, SQLAlchemy, Alembic), Hono (TypeScript, @hono/zod-openapi, Zod, Drizzle; Bun/Node/Cloudflare Workers/Deno) and NestJS (@nestjs/*, TypeORM, nestjs-zod, @nestjs/swagger, @nestjs/terminus).
  Use when: building or modifying a backend API, domain logic, DB adapters or workers in any of these stacks — domain modeling, ports & adapters, service layer, RFC 9457 errors, OpenAPI, cursor pagination, outbox/idempotency, healthchecks, migrations, testing. Picks the stack from build files; greenfield default: Axum for container services, Hono for Workers/edge/multi-runtime, FastAPI only when Python-only libraries are required (LangGraph, PyTorch, transformers), NestJS for modular DI teams.
  Do not use for: database schema design or lock-safe migration execution (use database-design).
---

# Hexagonal Backend

One contract for every backend this library builds — layers, errors, pagination, reliability, probes, testing — plus a stack guide per framework that carries the framework-specific mechanics and traps. **The contract alone is not enough to write code: Step 3 is mandatory.**

## Step 1 — Read the binding inputs

**The project's architecture doc is binding** (default `docs/arch/system.md`; caller may redirect): read its cross-cutting / reliability / observability rules, not just the stack line, and apply them in the reliability and observability sections below. If absent, apply this skill's defaults.

## Step 2 — Select the stack (from build files, not docs)

**Confirm the stack from the build files**, not from docs alone — on an existing project the framework is already fixed.

| Build-file signal | Stack | Guide |
|---|---|---|
| `Cargo.toml` depends on `axum` | Axum (Rust) | `references/axum/guide.md` |
| `pyproject.toml` depends on `fastapi` | FastAPI (Python) | `references/fastapi/guide.md` |
| `package.json` depends on `hono` or `@hono/*` | Hono (TypeScript) | `references/hono/guide.md` |
| `package.json` depends on `@nestjs/*` | NestJS (TypeScript) | `references/nestjs/guide.md` |

If the build files show a framework with no guide here (Express, Actix, Django, …), apply this contract and mirror the project's existing conventions. If no stack can be determined and nothing below decides it, ask the caller.

**Greenfield** (no build files yet): follow the architecture doc's stack line. If it names none and the caller states no preference:

- **Container service → Axum** (the default backend).
- **Cloudflare Workers, edge, or multi-runtime (Bun / Node / Deno) → Hono.**
- **Python-only libraries required** (LangGraph, PyTorch, transformers, PydanticAI, …) **→ FastAPI**; otherwise default to Axum.
- **A team that wants a modular framework with built-in DI → NestJS.**

(The house stack — the software-architecture skill's `references/house-stack.md`, if available — lists Hono for Workers and Axum / FastAPI for containers.)

## Step 3 — Load the stack guide (mandatory, before writing any code)

Read `references/<stack>/guide.md` in full, then that stack's examples — `references/<stack>/examples-domain.md`, `examples-adapters.md` and `examples-bootstrap.md` — before writing code. The guide holds the traps this contract deliberately leaves out: e.g. Axum `/{id}` paths, owned-transaction `&mut *tx` and concrete `Arc<AppXService>` state; FastAPI lifespan DI and async safety; per-instance `defaultHook` on OpenAPIHono; NestJS abstract-class DI tokens and the TypeORM 1.0 rules. When defining routes, also consult `references/api-design.md` (REST conventions) and `references/api-patterns.md` (HTTP request/response patterns).

---

## Layers, ports and adapters

Separate **business domain** from **infrastructure**. Domain defines *what*; adapters decide *how*.

```
[Inbound adapter: HTTP route / task / webhook] → [Port: service] → [Domain logic]
    → [Port: repository / metrics / notifier] → [Outbound adapter: DB / broker / HTTP client]
```

| Location | Holds |
|---|---|
| `domain/<feature>/` | models, errors, ports, service |
| `inbound/http/` | app factory, routes, request/response mappers, error mapping, health |
| `inbound/tasks/`, `inbound/webhooks/` | non-HTTP triggers (below) |
| `outbound/<db>/` | client, schema / ORM models, mapper, repository; plus broker, metrics, notifier adapters |
| bootstrap (`main` / `server`) | construct adapters → assemble service → start; no framework / ORM imports where the stack wraps them |
| migrations | outside every hex layer |

**Rule:** `domain/` never imports from `inbound/` or `outbound/` — nor any web framework, ORM, DB driver or OTel SDK. Dependencies always point inward. (NestJS's single `@Injectable()` concession is spelled out in its guide.)

## Domain modeling

- **Models** validate on construction (value objects / newtypes) so invalid states can't exist. Separate `CreateAuthorRequest` from `Author` — they WILL diverge as app grows.
- **Errors**: one error type per business-rule violation plus a generic Unknown error wrapping the cause. The domain never raises transport exceptions or status codes; adapters translate infrastructure errors into domain errors before returning.
- **Ports** are shaped by use cases. Three categories: **Repository** (data), **Metrics** (observability), **Notifier** (side effects). Cross-cutting ports are listed under Reliability.
- **Service** orchestrates repo → metrics → notifications → result. Handlers call Service, never Repository directly.
- **Evolution path:** Direct calls (repo → metrics → notifier) keep the flow visible in one place — good for simple apps. As side effects grow, the service has to know about every consequence, raising coupling. When this becomes a pain, refactor to domain events: the service emits `AuthorCreatedEvent`, independent handlers react. Adding a new side effect no longer requires touching the service. Trade-off: flow is spread across files, harder to trace.

### Domain boundaries

1. **Domain = tangible arm of your business** (blogging, billing, identity)
2. **Entities that change atomically → same domain**
3. **Cross-domain operations are never atomic** — service calls or async events
4. **Start large, decompose when friction is observed**

> If you leak transactions into business logic for cross-domain atomicity, your boundaries are wrong.

## Inbound adapters

- **Handlers do three things only**: parse input → call service → map response. No SQL, no ORM.
- **Request types** are decoupled from domain and convert via `try_into_domain()` / `toDomain()`; **responses** are built via `from_domain()` / `From<&T>` — never expose domain models or ORM entities. OpenAPI / schema derives live on inbound types only.
- **Wrap the framework** in an app factory or server type so bootstrap never imports it, and expose a test builder that returns the app without binding a port.

**Non-HTTP inbound adapters.** The inbound layer isn't limited to REST API routes. Any external trigger that drives the domain is an inbound adapter — task / job queues, webhooks, cron / schedulers, event streams (each guide lists its stack's options). All follow the same pattern: **parse input → call service → respond.**

Key differences from REST routes:
- Verify caller identity (task queue headers, webhook signatures) instead of user auth.
- Return simple ack (200 OK) — no user-facing response body.
- Must be idempotent — task queues retry on failure.

```
src/inbound/
├── http/            # User-facing REST API
├── tasks/           # Task queue handlers
└── webhooks/        # External service callbacks
```

Domain doesn't know which triggered it.

## HTTP mapping (inbound only)

- Mount routes under exactly **`/v1`** — no extra `/api` segment.
- Envelopes: single resource `{ "data": {...} }`; collection `{ "data": [...], "meta": { "limit", "next_cursor", "has_more" } }`.
- POST create → **201 + `Location`**; DELETE → 204; async work → 202 + `Location`.
- **`X-Request-Id`**: echo the inbound value or generate one, return it as a response header and stamp it into logs — never in the body.
- **CORS**: explicit origins from config, no wildcard (and never with credentials). Security headers (HSTS, `nosniff`, frame-deny) via the stack's middleware.
- Full conventions (naming, status codes, ETag, versioning, rate-limit headers): `references/api-design.md`; worked HTTP exchanges: `references/api-patterns.md`.

## Errors — RFC 9457

- Every error is `application/problem+json` with `type`, `title`, `status`, `detail`, `instance` (request path). Field-level validation adds the `errors: [{ field, code, message }]` extension member.
- Map in **one inbound error handler** / filter: unparseable input the framework rejects before the handler (malformed JSON, a path segment that isn't a valid id) → **400**; validation that parsed but failed → **422** with `errors[]`; missing or other-tenant resource → **404**; unique violation, version conflict or invalid state transition → **409** (**412** under `If-Match`).
- **Unknown** errors → log server-side with the request id, return a generic 500 ("An unexpected error occurred"). Never leak domain strings or exception text to users.
- The limiter's **429** is a problem document too, with `Retry-After`.

## Pagination

**Default to cursor-based pagination.** The pattern flows through all three layers: the domain port takes `(cursor, limit)` and returns a `CursorPage` (items, next_cursor, has_more); the adapter runs the keyset query; the handler returns the collection envelope.

- Keyset on **`(created_at, id)`** with a row-value predicate — `WHERE (created_at, id) > ($1, $2) ORDER BY created_at, id LIMIT $3` — fetching **`limit + 1`** to compute `has_more`; `next_cursor` points at the last *returned* row.
- The cursor is an **opaque base64(url) string** in the API; decode it in the adapter only.
- Clamp `limit` at the transport boundary (1..100, default 20). The domain doesn't care about max page size — that's a transport concern.

### Cursor vs Offset

**Cursor** (default) — `WHERE (created_at, id) > ($1, $2) ORDER BY created_at, id LIMIT $3`.
Consistent performance regardless of dataset size. Ideal for feeds, timelines, and large/mutable data. Always use a **composite cursor** `(sort_field, id)`. Cursor is an opaque base64-encoded string in the API; decode in the adapter only.

**Offset** — `LIMIT` / `OFFSET` + `COUNT(*)`.
Use for admin panels and small/static datasets. Provides `total` count for page number UIs. Downside: deeper pages get slower, and row mutations between requests cause duplicates or skips.

## Reliability (binding: the architecture doc's rules win)

Cross-cutting infrastructure that must not leak into the domain. Define each as a port; implement as adapters. The architecture-level pattern lives in the software-architecture skill's references (`reliability-patterns.md`, `observability.md`) if installed; otherwise apply standard patterns — outbox, idempotency keys, retry/backoff, structured logging, RED/USE — inline.

| Port | Purpose |
|---|---|
| **UnitOfWork** | Scopes one transaction across several repositories (where the stack shares a session / entity manager) |
| **Outbox** | Atomic state change + message publish — outbox row written in the **same** transaction as the aggregate |
| **IdempotencyStore** | Replay safe responses for `Idempotency-Key`-bearing requests |
| **Tracer** / **Meter** | Span / metric emission; the domain depends on the port, not on OTel packages |

- **Transactions** are encapsulated in the adapter (or the UnitOfWork), invisible to callers. Keep them short. **No external calls (HTTP, queues) inside tx.**
- **Uniqueness** is enforced by a DB `UNIQUE` constraint (the race-safe backstop); the adapter maps the unique-violation (Postgres `23505`, SQLite `UNIQUE constraint failed`) to a domain conflict → 409. An app-side check-then-insert alone is TOCTOU.
- **Outbox**: the domain emits typed domain events; the adapter writes them as outbox rows in the aggregate's transaction; a separate relay publishes them with retry/backoff and dead-letters after N attempts. Never publish to a broker inside the transaction or "right after commit".
- **Idempotency keys**: unique `(scope, key)` plus a request hash. Same key + same hash → replay the stored response; different hash → 409; same key still in flight → 409 (never re-run it).
- **Optimistic concurrency (lost-update protection)**: any aggregate two clients can update concurrently carries a `version` column; writes are conditional (`… WHERE id = $id AND version = $expected`, setting `version = version + 1`); 0 rows affected → domain conflict → **409** (or **412** with `If-Match` / ETag). Idempotency keys cover the *same* client retrying; the version column covers *different* clients racing — you usually need both.
- **Authorization ≠ authentication.** Every by-id read and write is scoped to the caller's tenant / ownership (a policy port, or an owner/org filter in the repository); foreign resources return 404. Otherwise `GET /v1/{resource}/{id}` is an IDOR.
- **Pools** always set an acquire / connect timeout.

## Healthchecks and shutdown

- **Liveness** (`/health`, `/healthz` or `/health/live`) returns 200 unconditionally — **never check dependencies there**: a liveness probe that touches a flaky DB cascade-restarts every replica.
- **Readiness** (`/ready`, `/readyz` or `/health/ready`) pings the DB under a short timeout (~1 s, or the pool's acquire timeout) and returns **503** (not 500) so the load balancer sheds traffic.
- Both live in the inbound layer, bypass the domain, and are registered before auth / throttling.
- **Graceful shutdown**: handle SIGTERM and SIGINT, drain in-flight requests, then close the pool — paired with a request timeout or failsafe timer so a hung request can't stall the drain.

## Migrations

Migrations are infrastructure. They sit alongside the app, not inside any hex layer; the migration tool reads schema definitions from `outbound/`. Pick one path — embedded at startup or a CLI release step before rollout. Schema *design* and lock-safe execution against live traffic belong to the database-design skill (including its PostgreSQL operations), if available — this skill only wires the mechanism.

## Observability

- Structured logs — fields, not formatted strings — JSON in production; the correlation id on every line.
- Logger / exporter / OTel SDK setup happens once in bootstrap; the domain emits spans and metrics only through the Tracer / Meter ports.
- Apply the architecture doc's observability rules (sampling, cardinality, RED/USE).

## Security baseline

| Item | Value |
|------|-------|
| JWT signing | **ES256/EdDSA** (asymmetric) when multiple services verify; `HS256` only for a single service that both issues and verifies |
| JWT verification | Pin the algorithm on verify — never trust the token's `alg` header |
| JWT access token | 15 min |
| JWT refresh (web) | 90 days |
| JWT refresh (mobile) | 1 year |
| Refresh token rotation | **Required** — issue new refresh token on each use, revoke old immediately |
| Refresh token storage | DB table with `jti`, user id, revoked-at, expires-at |
| Secrets | Never sign with a dev placeholder secret outside dev |
| Rate limiting | Terminate at the gateway / LB, or in-process with a 429 problem document |

Auth middleware lives in the inbound layer. Domain never handles raw tokens. Password hashing and the JWT library are stack choices (see the guide).

## Enforce the boundary (CI)

"Domain never imports infrastructure" is a fitness function, not an honor system — guard it on every PR (if the `software-architecture` skill is installed, this is its Stage-8 fitness functions at code level). Stack tools: a separate domain crate or grep gate (Rust), `import-linter` (Python), dependency-cruiser or eslint-plugin-boundaries plus `madge --circular` and `tsc --noEmit` (TypeScript) — configs in each guide.

## Testing approach

**TDD**: Write all tests first as a spec, then implement, then verify all pass. (Tests → Impl → Green)

- **Layer split**: handler tests against a mock service (parsing, status codes, error format); service tests against mock ports (orchestration, side-effect ordering); adapter tests against a real DB (SQL, error mapping, transactions); a few E2E happy paths with nothing mocked.
- **Hand-rolled port doubles**: Stub (configured results), Saboteur (always fails), Spy (counts side effects), NoOp (side effects don't matter). A fake repository must replicate DB constraints such as uniqueness, or tests pass against behavior production doesn't have.
- Build the app through the test builder (no bound port).

## Shared checklist

- [ ] Stack confirmed from build files; `references/<stack>/guide.md` and its examples loaded before coding
- [ ] Architecture doc's cross-cutting rules applied (or this skill's defaults, if absent)
- [ ] Domain imports no framework / ORM / driver; boundary enforced in CI
- [ ] Handlers: parse → service → map; DTOs ↔ domain via explicit mappers
- [ ] Every error is RFC 9457 problem+json; Unknown → logged + generic 500
- [ ] `/v1` mount, `{data}` / `{data, meta}` envelopes, 201 + Location, `X-Request-Id` header
- [ ] Lists use keyset cursor pagination with `limit + 1` and a clamped limit
- [ ] By-id reads and writes tenant / ownership-scoped (404 for foreign resources)
- [ ] Transactions short and in adapters; outbox for events; version column on racing aggregates; idempotency for retried POSTs
- [ ] Liveness without dependencies, readiness 503 under timeout, graceful SIGTERM / SIGINT drain
- [ ] Tests written first; adapter tests hit a real DB

## Reference files

| File | Contents |
|---|---|
| `references/api-design.md` | REST conventions: naming, envelopes, status codes, pagination, security headers, caching, versioning |
| `references/api-patterns.md` | HTTP exchanges: CRUD, RFC 9457 errors, ETag / `If-Match`, uploads, state transitions, async, bulk, SSE, webhooks |
| `references/axum/guide.md` + `examples-{domain,adapters,bootstrap}.md` | Axum 0.8 + sqlx + utoipa-axum |
| `references/fastapi/guide.md` + `examples-{domain,adapters,bootstrap}.md` | FastAPI + Pydantic + SQLAlchemy async + Alembic |
| `references/hono/guide.md` + `examples-{domain,adapters,bootstrap}.md` | Hono + @hono/zod-openapi + Drizzle, multi-runtime |
| `references/nestjs/guide.md` + `examples-{domain,adapters,bootstrap}.md` | NestJS + TypeORM 1.x + nestjs-zod + terminus |

Library APIs drift: each guide carries a dated version baseline; verify against the official docs with a doc-lookup tool if one is available.
