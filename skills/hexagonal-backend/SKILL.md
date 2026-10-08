---
name: hexagonal-backend
description: |
  Hexagonal (ports & adapters) backend implementation: one shared contract plus stack guides for Axum (Rust), FastAPI (Python), Hono (TypeScript on Node, Bun, Deno or Cloudflare Workers) and NestJS (TypeScript).
  Use when: building or changing a backend API, domain logic, DB adapters, queue / webhook / cron handlers or workers in these stacks — domain invariants, ports & adapters, transactions, authorization and tenant scoping, RFC 9457 errors, OpenAPI, cursor pagination, outbox, idempotency keys, timeouts and retries, health probes and shutdown, migration wiring, tests. Picks the stack from build files.
  Do not use for: system architecture or technology selection (use software-architecture), schema design or lock-safe migration execution (use database-design), or pre-landing code review (use review-checklists).
---

# Hexagonal Backend

One contract for every backend this library builds, plus a guide per stack with the mechanics and traps the contract leaves out. **The contract alone is not enough to write code: Step 3 is mandatory.**

## Step 1 — Read the binding inputs

The architecture doc is binding (default `docs/arch/system.md`; caller may redirect): §1 Service Pattern, §2 Core Technology and Published Contracts, §3 Data and Tenancy, §4 Release Model, §5 Cross-cutting (Write-path Integrity, Observability Contract, Security, Resilience). Also read `docs/arch/database.md` and the feature spec. Anything absent: apply this skill's defaults and list the assumptions.

**Existing code and published contracts win.** Mirror the project's conventions (paths, envelopes, error shape, versioning); these defaults apply only to new surfaces. Changing a published contract is a versioned change, never a cleanup.

## Step 2 — Select the stack

The manifest of the package being changed decides; never add a second web framework to a service.

| Manifest signal | Stack | Guide |
|---|---|---|
| `Cargo.toml` depends on `axum` | Axum (Rust) | `references/axum/guide.md` |
| `pyproject.toml` depends on `fastapi` | FastAPI (Python) | `references/fastapi/guide.md` |
| `package.json` depends on `hono` | Hono (TypeScript) | `references/hono/guide.md` |
| `package.json` depends on `@nestjs/core` | NestJS (TypeScript) | `references/nestjs/guide.md` |

A framework without a guide (Express, Actix, Django, …): apply this contract in its idiom.

**Greenfield**, first match wins: the arch doc's Core Technology row and ADRs → explicit caller or organization constraints, runtime target included → the adopted house profile (software-architecture's `references/house-stack.md`, if available) → fallback: Workers or edge → Hono; a core on the Python ML / data stack → FastAPI; other container services → Axum (NestJS when the team asks for framework DI and modules). Still open → ask; a subagent takes the fallback and reports it as an open question.

## Step 3 — Plan the change, then load the guide

Answer in the change summary before writing code — plain answers, not a template:

1. **Contract** — which published surfaces (routes, events, schemas) change: additive, or versioned?
2. **Invariants** — each rule, and where it is enforced (§ Domain).
3. **Write path** per command — transaction, concurrency control, idempotency, must-happen vs best-effort effects, actor and tenant scope.
4. **Dependencies** — deadline, the one retry layer, behavior when slow or down.
5. **Data** — expand-contract steps; code that works on both schema versions.
6. **Proof** — tests and telemetry that show it works (§ Testing).
7. **Rollout and rollback.**

Then read `references/<stack>/guide.md` in full and load example sections by task from each file's table of contents: domain and use cases → `examples-domain.md`; routes, error mapping, auth, persistence, transactions, outbox, idempotency, webhooks → `examples-adapters.md`; config, middleware order, probes, shutdown, telemetry, tests, CI → `examples-bootstrap.md`. The guides hold the traps this contract leaves out — e.g. Axum extractor rejections bypassing your error type, FastAPI's catch-all handler running outside your middleware, D1 having no interactive transactions, NestJS built-in exceptions carrying Nest's own body. For routes, also consult `references/api-design.md` (conventions, problem types) and `references/api-patterns.md` (worked exchanges).

---

## Structure

| Location | Holds |
|---|---|
| `domain/<context>/` | models, errors, ports, use cases |
| `inbound/http/`, `inbound/tasks/`, `inbound/webhooks/` | routes, mappers, error handler, auth, probes; non-HTTP triggers |
| `outbound/<store>/` | ORM models, mappers, repositories, unit of work, outbox, idempotency store; broker and HTTP clients |
| bootstrap (`main` / `app`) | config validation, wiring, start, shutdown |
| migrations | outside every hex layer |

**Dependencies point inward.** `domain/` never imports `inbound/` or `outbound/`, nor a web framework, ORM, driver or telemetry SDK.

**Shape follows the declared style** (system.md §1 Service Pattern). Full hexagonal — domain model, ports, use cases — for core contexts and anything that moves money, decides authorization or has irreversible effects. Supporting CRUD gets the lite shape: handler → use-case function → repository, reads through a query port, no per-feature metrics or notifier ports. Both keep the non-negotiables: dependency direction, actor and tenant scoping, one transaction per command, the error contract. Upgrade to full when a second adapter, real business rules or a second consumer appears.

## Domain

- **Invariants live in the narrowest place that can hold them**: the type (value objects validated on construction); an aggregate method (transitions such as `publish()`, never setters); a DB constraint or conditional write for anything two requests can race on; reconciliation across services.
- **Boundary value types**: money as integer minor units or decimal, never float; instants in UTC; 64-bit ids and amounts as JSON strings (JavaScript rounds above 2^53); text without U+0000 (PostgreSQL rejects it), lengths in code points.
- **Errors** are a closed set of kinds — not found, conflict, invalid, forbidden, precondition failed — plus Unknown wrapping the cause. The domain never raises transport errors; adapters translate infrastructure errors. Stored rows rehydrate through a trusted path, not creation-time validation.
- **Ports are shaped by use cases.** Every use case takes an explicit `Actor` (tenant, subject, roles) from the inbound auth adapter — never ambient state. Clock and id generation enter through ports.
- **Side effects**: one that must happen is written in the command's transaction (outbox or job row). A direct call after commit only where losing it is acceptable — in its own try-and-log, never changing the result.
- **Boundaries**: entities that change atomically share a domain; cross-domain operations are never atomic (calls or events); start large, split on observed friction.

## Inbound adapters

- **Handlers parse → call the use case → map the result.** No SQL, no ORM, no domain models or entities on the wire; OpenAPI derives from inbound types only. An app factory wraps the framework, with a test builder that serves the app without binding a port.
- **Input boundary**: an explicit body limit per route; max items, length and depth in schemas; write schemas and query strings reject unknown members (422), so owner, tenant and role never come from the request; sort and filter fields are allowlisted and map to indexed columns; PATCH is JSON Merge Patch (RFC 7396: absent = unchanged, `null` = clear).
- **Authentication** builds the `Actor` at the edge. **Authorization** is decided in the use case (a policy port when it depends on resource state), and the repository filters by tenant / owner inside every query as the second enforcement point (plus RLS where database.md chose it) — by-id, lists, search, export, bulk, sub-resources, job payloads (the worker re-establishes the tenant) and cache keys. Foreign resources return 404.
- **Non-HTTP triggers** (queues, webhooks, cron, streams) are inbound adapters on an internal router, outside public auth and OpenAPI:
  - verify the caller cryptographically — a signature with a timestamp window, or an OIDC token with an audience check; queue headers are not identity;
  - ack (2xx) only after the effect, or its inbox / job row, has committed; transient failure → 429 / 503 so the sender backs off; permanent (including a signed payload that fails its schema) → record and ack, or dead-letter; third-party payload schemas tolerate unknown fields;
  - dedup by message id (an inbox row in the same transaction, or an idempotent upsert), so a redelivery acks 2xx;
  - webhooks: a quick effect commits with its inbox row; a slow one is recorded and processed asynchronously, so the sender's timeout never decides the outcome; scheduled jobs: one instance at a time, explicit timezone, lease above p99 run time (software-architecture `operational-patterns.md` § Background Jobs, § Webhook Reliability, if available).

## HTTP contract

- New APIs mount under `/v1`. Single resource `{ "data": {...} }`; collection `{ "data": [...], "meta": { "limit", "next_cursor", "has_more" } }`.
- POST create → 201 + `Location`; DELETE → 204; async work → 202 + `Location`.
- **`X-Request-Id`** on every response, 2xx and 204 included: echo an inbound value only if it is a bounded token (1–128 chars of `[A-Za-z0-9._:-]`), else generate one; log it beside the trace id; never in success bodies.
- CORS from configured origins (no wildcard with credentials), exposing `Location`, `ETag`, `Retry-After`, `X-Request-Id`; CORS and request id wrap every layer that can synthesize a response. Security headers via middleware; authenticated responses default to `Cache-Control: no-store`.

## Errors — RFC 9457

- Every error — domain, validation and framework-generated (401, 404, 405, 413, 415, 429) — is `application/problem+json` with `type` (an absolute URI from the API's problem registry), `title`, `status`, `detail`, `instance` (the request path, no query string). Validation adds `errors: [{ detail, pointer | parameter, code }]` (`pointer` is a JSON Pointer into the body in fragment form: `#/title`; `#` for the whole body). A framework-raised status takes its registry type when exactly one type has that status; otherwise it keeps its code with `type` `about:blank` and the status phrase as `title`. Only protocol-level rejections before the app sees the request (malformed HTTP, a refused CORS preflight) are exempt.
- **One** error handler maps: malformed JSON, a path id that cannot be an id, an undecodable cursor, a malformed or missing required `Idempotency-Key` → **400**; wrong media type → **415**; oversize → **413**; well-formed input failing validation → **422** with `errors[]`; unauthenticated → **401** + `WWW-Authenticate`; visible but forbidden → **403**; missing or not visible to this actor → **404**; conflict with current state (uniqueness, invalid transition, version) → **409**, or **412** under `If-Match`; rate limited → **429** + `Retry-After`; dependency unavailable or deadline exceeded → **503** + `Retry-After`.
- **Unknown** → log once with the request id; generic 500 ("An unexpected error occurred"), never exception text or SQL.

## Pagination

- **Cursor by default.** The port takes `(cursor, limit)` and returns `{ items, next_cursor, has_more }`; the adapter runs a keyset query for `limit + 1` rows; `next_cursor` points at the last returned row, `null` on the last page.
- **The cursor carries every sort key at full DB precision** — a JavaScript `Date` drops PostgreSQL's microseconds, and pages repeat or loop. Creation order: keyset on a unique time-ordered id (UUIDv7) alone. Other orders: `(sort_key, id)` with a row-value predicate whose operator and index follow the sort direction (database-design query patterns, if available).
- The cursor is an opaque base64url token bound to its sort and filters, decoded only in the adapter; one that fails to decode → 400.
- `limit` defaults to 20; any larger integer is clamped to 100 (`meta.limit` reports the value used); below 1 or not an integer → 422; the port enforces a hard maximum too. A decodable cursor is only a position — the tenant filter still applies.
- Offset (`page`, `total`) only for admin views over small data. A list cursor is not a change feed: sync consumers follow commit order (software-architecture `reliability-patterns.md` § 3 Ordering, if available).

## Write path (binding: the arch doc's Write-path Integrity rows win)

Method: software-architecture `reliability-patterns.md` §§ 1–4, if available.

- **One command = one transaction, owned by the use case** through a unit-of-work port typed on an adapter-defined transaction; repositories, the outbox and the idempotency store run inside it and never begin or commit. No external calls inside. Isolation per database.md; where it runs SERIALIZABLE, the runner retries the whole unit on 40001 / 40P01, bounded, with jittered backoff; elsewhere they map to 503 + `Retry-After`. Reads that must see the write go to the primary.
- **Concurrency, by the shape of the write**: uniqueness → a UNIQUE constraint, its violation (Postgres `23505`) mapped by constraint name to the matching domain conflict; new value from old (counter, balance, stock) → a conditional atomic update; state change → a guarded transition (`… AND status = 'draft'`; 0 rows = conflict); read-modify-write of an aggregate → a `version` column, conditional on the version the client saw (`If-Match`: strong tags or `*`, evaluated after the 404 / 403 decision); invariant across rows → a constraint, a lock on the invariant's rows, or serializable with retry. App-side check-then-insert alone is a race.
- **Outbox**: domain events become outbox rows in the aggregate's transaction, carrying `aggregate_seq`, trace context and attempts; a relay claims pending rows (`FOR UPDATE SKIP LOCKED`, one owner per aggregate, in `aggregate_seq` order), publishes outside the transaction, backs off and dead-letters. Event payloads are published contracts: additive changes only; a breaking change ships as a new event type or version beside the old.
- **Idempotency keys**: a row per `(scope, key)` — scope = tenant + principal — with a hash of method, path with query string, and canonical body, a lease longer than the request deadline and an expiry longer than any client's retry horizon. Malformed key (not 1–255 visible ASCII), or required and missing → **400**; completed (2xx, or a 4xx decided by the body or state) → replay the stored status, body and defining headers (`Location`, `Content-Type`, `ETag`) — outcomes decided by headers outside the hash (e.g. 415, 406, 412, 428) are never stored; different hash → **422** with its own problem `type`; live lease → **409** + `Retry-After` (the expected completion, ~1–2 s, not the remaining lease). Only this request's insert or a conditional takeover of an expired lease grants execution — never a read; the result commits in the use case's transaction under the lease; a failure before commit releases the key. One wrapper applies it, never per-handler code (external side effects: `reliability-patterns.md` § 2).
- **Bounded work**: every list, include and bulk path has a hard limit in the port contract; related data loads in batches (JOIN, `IN`, a dataloader), never per item; includes are capped and authorized per item; bulk declares max items and atomic vs per-item semantics.

## Dependencies and overload (binding: the arch doc's Resilience rows win)

- Each request gets a deadline at the edge, below the idempotency lease; outbound calls get connect and total timeouts inside the remaining budget. A deadline never undoes a commit, so must-happen work after commit goes through the outbox.
- DB sessions carry `statement_timeout`, `idle_in_transaction_session_timeout` and `TimeZone` UTC; pools set acquire and connect timeouts; pool size (overflow included) × instances fits the DB's connection budget.
- Retry in exactly one layer, idempotent operations only — exponential backoff, full jitter, a retry budget, `Retry-After` honored — never inside an open transaction.
- Cap concurrency per dependency; shed early with 429 / 503 + `Retry-After` (software-architecture `operational-patterns.md` § Dependency Protection & Overload, if available).

## Probes and shutdown

- **Liveness** (`/health`, `/healthz` or `/health/live`): 200 if the process can answer — no dependency checks.
- **Readiness** (`/ready`, `/readyz` or `/health/ready`) is instance-local: at startup validate config and make one DB round-trip (plus any schema-version check), then latch ready; afterwards report only local state — initialized, not draining — with **503** from shutdown onward. Shared-dependency health feeds metrics, alerts and degraded mode, never probes (software-architecture `observability.md` § Health Checks, if available). Without probes (Workers, other serverless): no readiness route; dependency metrics plus an external synthetic check that touches the DB.
- Probes live in the inbound layer, bypass the domain, and are registered before auth and rate limiting.
- **Shutdown** on SIGTERM / SIGINT: mark draining (readiness 503) → keep serving through load-balancer deregistration where it is asynchronous (Kubernetes) → stop accepting and close idle keep-alive connections (or answer `Connection: close`) → drain in-flight requests under the deadline → stop workers and relays (finish or release leases) → close pools → flush telemetry → exit. Deadline + drain + pool close + flush stays below the platform's grace period (Cloud Run 10 s; Kubernetes default 30 s).

## Migrations

Outside every hex layer. One source of truth: database-design's SQL migrations win when they exist, ORM models mirror them, and autogeneration is a drafting aid whose diff must be empty in CI. Run them as a release step before the code that needs them (at startup only for single-instance or dev), with per-migration no-transaction support for `CONCURRENTLY`. Code works on both schema versions; the contract step waits until all code has moved; backfills run as batched jobs. Schema design and lock-safe execution: database-design, if available.

## Observability

Day one: instrumentation libraries for server spans (route template, never the raw path), DB and HTTP-client spans and RED metrics, the SDK and exporter configured once in bootstrap; JSON logs with `request_id`, `trace_id`, `span_id` as fields and a redaction list at the logger; freshness metrics per async path (oldest pending outbox row, queue lag, DLQ depth); trace context through the outbox; audit events through their own port and store, never the log pipeline; telemetry flushed at shutdown. The domain records business events only through a port (or the stack's standard facade — `tracing` in Rust). Sampling, cardinality, SLOs: the arch doc's Observability Contract (software-architecture `observability.md`, if available).

## Security

Pin JWT algorithms; validate `iss`, `aud`, `exp`; HS256 only when one service both issues and verifies, else ES256 / EdDSA via a cached JWKS with a fetch timeout — a key source that cannot be fetched is a dependency failure (503 + `Retry-After`), never a 401. Short-lived access tokens with a revocation path; refresh tokens opaque, hashed, rotated, with reuse detection (a replayed token revokes its family), idle and absolute expiry, a short grace window for concurrent refreshes. Cookies → HttpOnly, Secure, SameSite plus CSRF defense. Hash passwords with argon2id off the request thread. Validate config and secrets at startup and fail loud — no placeholder secret outside dev. Lifetimes are arch-doc policy; checklist: review-checklists `security/auth.md`, `security/api.md`, if available. The domain never sees raw tokens.

## Enforce the boundary (CI)

"Domain never imports infrastructure" is a fitness function on every PR: a separate domain crate (Rust); import-linter (Python); dependency-cruiser counting type-only imports, with a no-circular rule, failing on zero cruised modules (TypeScript). Commit the generated OpenAPI document; fail on breaking diffs. Configs in each guide.

## Testing

Write each test before the behavior it proves; choose the level by risk.

- **Layers**: domain tests on invariants and transitions; use-case tests with hand-rolled port doubles — Stub, Saboteur (always fails), Spy, NoOp — where a fake repository enforces the DB's constraints; adapter tests on real PostgreSQL with real migrations (an embedded substitute with millisecond timestamps hides precision bugs); HTTP tests through the test builder; a few end-to-end paths.
- **Risk set per write path**: concurrent duplicate creates (one 201, one 409); version conflict (409 / 412); idempotency replay, mismatch, in-flight; a Saboteur at each side-effect step (the outbox row rolls back with the aggregate); cross-tenant (foreign id → 404, never listed); a cursor walk over rows that tie on the sort key; the problem+json matrix, framework 401 / 404 / 405 included; migrations forward from empty.

## Hand-off checklist

- [ ] Change plan answered; published contracts unchanged or versioned; boundary gate green
- [ ] Every use case takes an Actor; every query tenant / owner-scoped; foreign → 404
- [ ] One transaction per command, owned by the use case; must-happen effects through the outbox; concurrency control fits each write; idempotency on retried creates
- [ ] Every error RFC 9457, framework errors included; `X-Request-Id` on every response
- [ ] Cursor exact at DB precision; limit clamped and bounded in the port
- [ ] Deadline, DB and pool timeouts set; retries in one layer
- [ ] Liveness dependency-free; readiness latched and instance-local; drain inside the platform grace
- [ ] Risk-set tests green on real PostgreSQL; OpenAPI diff clean

## Reference files

| File | Contents |
|---|---|
| `references/api-design.md` | REST conventions: naming, envelopes, status codes, problem types, filtering, security, caching, versioning |
| `references/api-patterns.md` | Worked exchanges: CRUD, errors, idempotency, `If-Match`, uploads, transitions, search, async jobs, bulk, SSE, webhooks |
| `references/<stack>/guide.md` | Axum · FastAPI · Hono · NestJS: version baseline, decisions, edge, persistence, operability, testing, traps |
| `references/<stack>/examples-{domain,adapters,bootstrap}.md` | One tenant-scoped vertical slice per stack that compiles and passes its tests |

Library APIs drift: each guide opens with a dated version baseline; verify against the official docs with a doc-lookup tool if one is available.
