---
name: nestjs-hexagonal
description: |
  NestJS with hexagonal architecture patterns in TypeScript.
  Use when: building TypeScript APIs with NestJS — for modular backends with built-in dependency injection.
  Covers: API design (@nestjs/swagger), domain modeling, ports & adapters (abstract class injection tokens), NestJS module wiring, Zod validation via nestjs-zod (createZodDto), exception filters (RFC 9457), @nestjs/testing patterns, TypeORM (PostgreSQL) persistence, cursor pagination, @nestjs/terminus healthcheck endpoints.
  Do not use for: database schema design (use database-design skill). Use hono-hexagonal for lightweight multi-runtime APIs. Use fastapi-hexagonal for Python-only APIs. Use axum-hexagonal for Rust APIs.
---

# NestJS + Hexagonal Architecture

**For latest NestJS/TypeORM/Zod/nestjs-zod APIs, verify against the official docs with a doc-lookup tool if one is available.**

## Core Philosophy

Separate **business domain** from **infrastructure**. Domain defines *what*; adapters decide *how*.

```
[Inbound Adapter: NestJS Controller] -> [Port: Service abstract class] -> [Domain Logic]
    -> [Port: Repository abstract class] -> [Outbound Adapter: TypeORM/etc.]
```

**Dependencies always point inward.** Domain code never imports NestJS, TypeORM, or any infrastructure package (single `@Injectable()` concession aside — see § Service).

---

## Project Structure

```
src/
├── domain/
│   └── authors/
│       ├── models.ts            # Author, AuthorName, CreateAuthorRequest
│       ├── errors.ts            # DuplicateAuthorError, UnknownAuthorError
│       ├── ports.ts             # abstract AuthorRepository, abstract AuthorService
│       └── service.ts           # AuthorServiceImpl (plain class — no @Injectable)
├── inbound/
│   └── http/
│       ├── authors/
│       │   ├── authors.controller.ts   # Parse -> call service -> map response
│       │   ├── request.dto.ts          # createZodDto classes + toDomain()
│       │   └── response.dto.ts         # fromDomain() + Swagger decorators
│       ├── filters/
│       │   └── domain-exception.filter.ts  # Domain errors -> RFC 9457
│       ├── pipes/
│       │   └── zod-validation.pipe.ts      # nestjs-zod pipe -> RFC 9457 errors
│       └── health/
│           └── health.controller.ts        # @nestjs/terminus
├── outbound/
│   ├── typeorm/                # PostgreSQL adapter
│   │   ├── typeorm.module.ts   #   @Global, TypeOrmModule.forRootAsync + forFeature
│   │   ├── entities/
│   │   │   └── author.entity.ts #  @Entity class — outbound only, NEVER imported in domain
│   │   ├── author.repository.ts #  Implements domain port; @InjectRepository(AuthorEntity)
│   │   └── mapper.ts            #  AuthorEntity <-> Author (domain) translation
│   └── noop.ts                 # NoOp metrics/notifier for dev
├── authors.module.ts           # Feature module: wires controller + service
├── app.module.ts               # Root module: imports persistence module + config
├── config.ts                   # Typed config validated with Zod
└── main.ts                     # Bootstrap — NestFactory, global middleware
data-source.ts                  # TypeORM CLI DataSource (entities + migrations path)
migrations/                     # TypeORM-generated migration files
tests/
├── helpers.ts                  # Test module factory
└── mocks.ts                    # Stub, Saboteur, Spy, NoOp
```

**Rule:** `domain/` never imports from `inbound/` or `outbound/`. Domain may import a **single** `@nestjs/common` symbol — `@Injectable()` — on the service implementation only, as a DI-metadata concession (see § Service below). Everything else (`HttpException`, decorators, modules) stays out of `domain/`.

---

## Domain Layer

### Models
- Validate on construction (value object pattern). Classes with private constructors or factory functions.
- **No TypeORM entities in domain** — those live in `outbound/` only. Domain `Author` and outbound `AuthorEntity` are *different types*.
- Domain models are plain TypeScript. No decorators, no framework dependencies.
- Separate `CreateAuthorRequest` from `Author` — they WILL diverge as app grows.

### Errors & Result Type
- Exhaustive hierarchy: one class per business rule violation + generic `UnknownAuthorError`.
- **Never throw NestJS `HttpException` in domain** — that leaks transport concerns.
- Use custom error classes extending `Error` with a `readonly tag` discriminant for exhaustive matching in exception filters.

### Ports (Abstract Classes)

Use abstract classes as both interface contract AND DI injection token. The abstract class works directly in NestJS module `providers` without needing symbols or `@Inject()` — this is the idiomatic NestJS approach.

Three categories: **Repository** (data), **Metrics** (observability), **Notifier** (side effects).

Abstract classes in the domain layer have zero NestJS imports — they're plain TypeScript.

### Service
- Abstract class `AuthorService` declaring business API + class `AuthorServiceImpl` extending it.
- Constructor takes all dependencies: `new AuthorServiceImpl(repo, metrics, notifier)`.
- **`@Injectable()` on `AuthorServiceImpl` is allowed.** Wire with `{ provide: AuthorService, useClass: AuthorServiceImpl }` in the feature module. The decorator is metadata-only — one `@nestjs/common` import in `service.ts` in exchange for half the wiring code. If you want zero NestJS imports anywhere in `domain/`, drop the decorator and use `useFactory` instead (see `references/examples-bootstrap.md`); both patterns are supported.
- Orchestrates: repo -> metrics -> notifications -> return result.
- Controllers call Service, never Repository directly.
- **Evolution path:** Direct calls keep the flow visible in one place. As cross-cutting side effects multiply, refactor to in-process events via `@nestjs/event-emitter` (`@OnEvent` handlers); when handler logic gets heavy, move to commands/queries via `@nestjs/cqrs` (`CommandHandler`, `QueryHandler`, `Saga`). For cross-process / cross-service events, use the Outbox port (see "Reliability & Observability Ports" below) — `EventEmitter2` is in-process only and won't survive a crash between the DB write and the publish.

> Full domain examples (models, errors, ports, service): `references/examples-domain.md`

---

## Inbound Layer

- **Controllers** annotated with `@Controller('v1/authors')`. Each method: parse input -> call service -> map response. No TypeORM. No ORM. **Never** return entities directly — always go through the response DTO.
- **DI** — Controllers inject the abstract service class directly. NestJS resolves it to the concrete implementation registered in the feature module.
- **Request DTOs** decoupled from domain — `createZodDto(schema)` classes (from `nestjs-zod`) + `toDomain()` function. The controller takes the DTO class directly (`@Body() body: CreateAuthorDto`); the global pipe validates it and `@nestjs/swagger` reads its schema for OpenAPI.
- **Response DTOs** built via `fromDomain()` static method — never expose domain models directly. Add `@ApiProperty()` decorators for Swagger.
- **Exception Filters** map domain errors to RFC 9457 ProblemDetails. Register globally via `APP_FILTER` in `AppModule` (the filter injects `ClsService` for the `X-Request-Id` correlation header, so it must be DI-resolved, not `new`-ed in `main.ts`). Match on `error.tag` for exhaustive handling.
- **API docs** — `@nestjs/swagger` with `@ApiOperation()`, `@ApiResponse()`. Consult `references/api-design.md` for conventions and `references/api-patterns.md` for HTTP patterns.
- **Guards** — Auth via `@UseGuards(JwtAuthGuard)`. Domain never handles tokens.
- **Pipes** — `nestjs-zod`'s `ZodValidationPipe`, registered once via `APP_PIPE`. It validates every `@Body()`/`@Query()`/`@Param()` typed with a `createZodDto` class. Built with `createZodValidationPipe({ createValidationException })` so failures emit the RFC 9457 ProblemDetails body — see `pipes/zod-validation.pipe.ts`.
- **NestJS execution order**: Guards -> Interceptors -> Pipes -> Handler -> Interceptors -> Filters.

### Non-HTTP Inbound Adapters

Any external trigger that drives the domain is an inbound adapter:

| Trigger | NestJS Pattern | Still HTTP? |
|---------|---------------|-------------|
| Task/Job queue | `@nestjs/bullmq` processor | No (consumer) |
| Webhook | Controller with signature verification guard | Yes |
| Cron/Scheduler | `@nestjs/schedule` `@Cron()` service | No |
| Event stream | `@nestjs/microservices` `@MessagePattern()` | No |

All follow the same pattern: **parse input -> call service -> respond.**

> Full inbound examples (controller, DTOs, exception filter, auth guard, pipes): `references/examples-adapters.md`

---

## Outbound Layer

### TypeORM (PostgreSQL)

- `@Injectable()` repositories that extend the abstract port class from domain.
- Inject the per-entity `Repository<AuthorEntity>` via `@InjectRepository(AuthorEntity)`.
- **Transactions encapsulated in adapter** via `repo.manager.transaction()` (or an injected `DataSource`), invisible to callers.
- Map TypeORM-specific errors (`QueryFailedError` with driver code `23505` on Postgres) to domain error types.
- Entities live in `outbound/typeorm/entities/*.entity.ts`. Use **Data Mapper** style only (`repo.save(entity)`); never Active Record (`entity.save()`). The mapper translates `AuthorEntity <-> Author`.

| Setting | Value | Why |
|---------|-------|-----|
| Module | `TypeOrmModule.forRootAsync` + `forFeature([AuthorEntity])` | Async config from `ConfigService`, per-feature repository wiring |
| Repository style | Data Mapper only (`@InjectRepository`) | Active Record leaks persistence into domain |
| Transactions | `repo.manager.transaction(async (m) => ...)` | Scoped, auto-rollback on throw |
| Relations | `repo.find({ relations: { posts: true } })` or QueryBuilder `leftJoinAndSelect` | Eager join to prevent N+1; never lazy `Promise<Related>` |
| Migrations | TypeORM CLI `migration:generate` + `migration:run` | Schema-driven SQL migrations from entity diff |
| `synchronize` | **`false`** in every environment except local sandbox | Auto-altering production schemas is a foot-gun |

> Full outbound examples (TypeORM repository, mapper, module): `references/examples-adapters.md`

---

## TypeORM + Hex: Pragmatic Rules

TypeORM doesn't fight hexagonal — but its convenience features can. Sort each feature into one of three tiers; the tier tells you whether it's a hard rule, a default with criteria, or just style.

1. **Non-negotiable** — break these and hex is gone
2. **Default off, deliberate on** — fine in narrow cases that match the criteria
3. **Style preference** — not a hex rule, pick what your team likes

### Tier 1: Non-negotiable

| Rule | What hex loses if you don't |
|------|------------------------------|
| Domain never imports TypeORM types | Domain couples to ORM. Swapping ORM = rewriting domain. |
| Entity ≠ Domain model (mapper in outbound) | Renaming a DB column = breaking the domain. |
| Controller never returns Entity | Response shape leaks DB layout to API consumers. |
| Map `QueryFailedError` → `DomainError` at the adapter boundary | Domain catches see ORM exceptions = leaky abstraction. |
| Data Mapper only (`repo.save(entity)`, not `entity.save()`) | Active Record means entities know about persistence. |

### Tier 2: Default off, deliberate on

| Feature | Default | When it's OK to enable |
|---------|---------|------------------------|
| `cascade: true` on relations | off | **Inside a single aggregate** (Order ↔ OrderLines, User ↔ UserProfile). **Never across an aggregate boundary**. Test: would deleting the parent ever mean "the child still has its own life"? Yes → separate aggregates → no cascade. |
| Lifecycle hooks (`@BeforeInsert`, `@BeforeUpdate`, `@AfterLoad`) | none | **Pure technical persistence concerns** only: uuid generation, `updated_at` stamping, soft-delete `deleted_at`. **Never** business invariants (price calculation, permission checks). Test: would this hook still make sense if the table were stored in DynamoDB / Mongo? Yes → persistence concern, OK. No → business logic, move to the domain service. |
| TypeORM Subscribers / EventSubscribers | none | **Cross-cutting persistence concerns** only: audit log writer that observes inserts/updates, `created_by` / `updated_by` stamping from CLS. **Never for domain events** — subscribers fire per row, not per transaction, and miss the tx context. Domain events go through the Outbox port. |
| Lazy relations (`Promise<Related>`) | eager join | Not really a hex concern — performance concern. OK when: (a) the relation is conditionally needed, (b) the mapper resolves the Promise before returning so domain never sees it, (c) you've verified no N+1 on hot paths. Eager joins (`relations: { ... }` or QueryBuilder `leftJoinAndSelect`) are the safer default. |

### Tier 3: Style preference (not hex rules)

| Choice | Recommendation |
|--------|---------------|
| `repo.save()` vs `repo.insert()/update()` | `save()` is the fine default — TypeORM infers insert vs update from id presence. Use explicit `insert`/`update` when the intent matters: audit trail, optimistic concurrency, or "this MUST be a create and reject an existing id" semantics. |
| Cross-repo transactions: `UnitOfWork` vs `@Transactional` | **Default: `UnitOfWork` port** (see "Reliability & Observability Ports" below) — tx boundary visible at the service call site, no third-party dep. **Acceptable opt-in: `@Transactional`** (`typeorm-transactional`) — same atomicity, less wiring per call site, but the boundary moves into a decorator and you take on a third-party lib's maintenance risk. Pick one and use it consistently; don't mix. |

> **TypeORM 1.0 cheatsheet** (verified against TypeORM 1.0.0 released 2026-05-19 — migration from 0.3.x):
> - **Node 20+ required.** Build target ≥ ES2023.
> - **`null`/`undefined` in `where` now throws** on high-level APIs (`findOneBy`, `findBy`, `repo.update`). Omit the field, or use `IsNull()` for SQL NULL. (Raw `QueryBuilder.where(...)` still passes values through.)
> - **String-form `relations` / `select` removed.** Use object syntax: `relations: { posts: true }`, `select: { id: true, name: true }`.
> - **Removed methods** (with replacements): `repo.findByIds([...])` → `repo.findBy({ id: In([...]) })`; `repo.findOneById(id)` → `repo.findOneBy({ id })`; `repo.exist(...)` → `repo.exists(...)`; `qb.printSql()` → `qb.getSql()` / `qb.getQueryAndParameters()`; `qb.onConflict()` → `qb.orIgnore()` / `qb.orUpdate(...)`.
> - **Removed types**: `Connection`/`ConnectionOptions` → `DataSource`/`DataSourceOptions` (already the case in 0.3.x; aliases now gone); `WhereExpression` → `WhereExpressionBuilder`.
> - **Removed globals**: `getConnection()`, `getRepository()`, `createConnection()`, `getCustomRepository()`, `@EntityRepository`, `AbstractRepository`. Custom repos via `Repository.extend(...)`.
> - **Removed env-var loaders**: `TYPEORM_*` env vars / `ormconfig.env` / auto `dotenv` no longer supported. Build `DataSourceOptions` from your own validated config (we do this with Zod in `config.ts`).
> - **Non-nullable relations now `INNER JOIN`** instead of `LEFT JOIN` — double-check filter behaviour on optional relation joins.
> - **CLI bins unchanged**: `typeorm-ts-node-commonjs` and `typeorm-ts-node-esm` are still distributed.

> **One-liner:** *TypeORM isn't incompatible with hex — its conveniences make hex discipline easy to erode unless you know which ones to allow and which to refuse.*

---

## Validation

Zod schemas define the contract at the transport boundary, wrapped as DTO classes via `nestjs-zod`'s `createZodDto`. Domain models validate business rules separately.

```
[HTTP body] -> [global ZodValidationPipe validates the createZodDto schema] -> [toDomain() validates business rules] -> [Domain model]
```

Two-layer validation is intentional: Zod catches malformed input (missing fields, wrong types) before it reaches domain code. Domain constructors enforce business invariants (non-empty names, valid ranges).

**Why `nestjs-zod`, not a hand-rolled pipe:** `createZodDto(schema)` is one class carrying the compile-time type, the runtime schema, AND the OpenAPI schema. A bare Zod schema gives `@nestjs/swagger` no metadata — request bodies vanish from the generated docs. `createZodDto` keeps requests and responses equally documented.

- Register `ZodValidationPipe` once via `APP_PIPE` (see `examples-bootstrap.md`); it validates every parameter typed with a `createZodDto` class.
- Build it with `createZodValidationPipe({ createValidationException })` so failures return the RFC 9457 ProblemDetails body the rest of the API uses.
- In `main.ts`, wrap the Swagger document with `cleanupOpenApiDoc()` so `createZodDto` schemas render correctly in OpenAPI.
- Use `z.coerce` for query-string params (`z.coerce.number()` for `limit`) — every query value arrives as a string.

> createZodDto, request DTO, and pipe examples: `references/examples-adapters.md`; Swagger + pipe wiring: `references/examples-bootstrap.md`

---

## Pagination

List endpoints need pagination. **Default to cursor-based pagination.** The pattern flows through all three layers:
- **Domain port**: `listAuthors(cursor: string | null, limit: number) => Promise<CursorPage<Author>>`
- **TypeORM adapter**: QueryBuilder `where("(author.created_at, author.id) > (:cursorAt, :cursorId)", ...).orderBy({ "author.created_at": "ASC", "author.id": "ASC" }).limit(:limit)`
- **Inbound controller**: return `CursorPageResponse<T>` with `data`, `limit`, `next_cursor`, `has_more`

Cap `limit` at the controller level via Zod on the query schema (e.g. `z.coerce.number().int().min(1).max(100).default(20)` — `coerce` handles query-string coercion).

### Cursor vs Offset

**Cursor** (default) — Consistent performance regardless of dataset size. Use composite cursor `(sortField, id)`. Cursor is an opaque base64-encoded string in the API; decode in the adapter only.

**Offset** — Use for admin panels and small/static datasets. Provides `total` count for page number UIs.

---

## Healthcheck

Use `@nestjs/terminus` for structured health checks. These bypass the domain entirely.

- `/health/live` — always 200 (liveness). **No indicators here** — a liveness probe that touches a flaky DB cascade-restarts every replica.
- `/health/ready` — checks DB connectivity (readiness) via `TypeOrmHealthIndicator.pingCheck("database", { timeout: 1000 })`. Terminus returns **503** automatically on a failed indicator; the timeout keeps a hung DB from stalling the probe.
- If a global guard/throttler is registered, exempt the health controller (`@SkipThrottle()`, public-route metadata) so probes don't 401/429.

> Healthcheck example: `references/examples-adapters.md`

---

## Migrations

TypeORM CLI reads `data-source.ts` (with `entities` + `migrations` paths) and generates migrations from the entity-vs-DB diff.

```
data-source.ts          # DataSource: entities + migrations path + DB connection
migrations/             # Generated TypeScript migration files (run via CLI)
```

```bash
# Generate migration from current entity diff
bunx typeorm-ts-node-commonjs migration:generate -d ./data-source.ts ./migrations/CreateAuthors

# Apply pending migrations
bunx typeorm-ts-node-commonjs migration:run -d ./data-source.ts

# Revert the most recent migration
bunx typeorm-ts-node-commonjs migration:revert -d ./data-source.ts
```

`synchronize: false` in every environment except a throw-away local sandbox — migrations are the only sanctioned schema mutation path.

---

## Logging & Request Context

NestJS has a built-in `Logger` class. For structured logging, use `nestjs-pino` — JSON output, low overhead, native trace context support.

- **Domain**: log business events at info, wrap unexpected exceptions at error
- **Inbound**: exception filters log server errors before returning generic messages
- **Outbound**: TypeORM query logging via `logging: ["query", "error"]` (or `"all"` in dev)

For **request-scoped correlation** (request_id, tenant_id, userId) without threading values through every constructor, use **`nestjs-cls`** (AsyncLocalStorage wrapper). Bind it once as a middleware, populate the store from auth guard / request_id middleware, and read from the CLS store inside adapters. Pair `nestjs-cls` with `nestjs-pino`'s `customProps` to stamp every log line with the active correlation IDs automatically.

> Wiring: `references/examples-bootstrap.md`.

---

## Security

| Item | Value |
|------|-------|
| Password hashing | `@node-rs/argon2` (default), `bcrypt` (fallback) |
| JWT library | **`jose`** (default — modern, EdDSA/ES256 first-class, ESM/CJS, JWK support, no CVE backlog). Use `@nestjs/passport` + `passport-jwt` only when you also need session / OAuth strategies in the same app. **Do not use `jsonwebtoken`** — CJS-only, slow-to-patch security history (e.g. CVE-2022-23529), no native ES module support. |
| JWT algorithm | **Asymmetric ES256/EdDSA** (canonical — verifiers hold only the public key via JWKS; validate `aud`/`iss`). HS256 symmetric secret only for a single-service / dev setup that both issues and verifies. See the guard in `references/examples-adapters.md`. |
| JWT access token | 15 min |
| JWT refresh (web) | 90 days |
| JWT refresh (mobile) | 1 year |
| Refresh token rotation | **Required** — issue new refresh token on each use, revoke old immediately |
| Refresh token storage | DB table/collection with `jti`, `userId`, `revokedAt`, `expiresAt` |
| CORS | `app.enableCors({ origin: [...] })` in main.ts |
| Security headers | `helmet` middleware |
| Rate limiting | `@nestjs/throttler` |

Auth guard lives in the inbound layer. Domain never handles raw tokens.

---

## Bootstrap (main.ts)

NestJS bootstrap creates the application from the root module and configures global middleware. Keep it focused — no business logic.

Key setup: CORS -> helmet -> Swagger -> shutdown hooks -> listen. The global exception filter is registered via `APP_FILTER` in `AppModule` (it injects `ClsService`), not `app.useGlobalFilters(new ...)` in `main.ts`.

> Full bootstrap and config examples: `references/examples-bootstrap.md`

---

## Module Organization

NestJS modules are the wiring layer — they connect ports to adapters.

### Persistence Module

In `app.module.ts`, import the persistence module:

```typescript
imports: [
  TypeOrmPersistenceModule,    // PostgreSQL
  AuthorsModule,
]
```

The persistence module provides `AuthorRepository` — the feature module and controllers depend only on the abstract port.

### Feature Module Pattern

Each domain gets a **feature module** that wires its controller, service, and repository. Default wiring: `{ provide: AuthorService, useClass: AuthorServiceImpl }` with `@Injectable()` on the impl; `useFactory` for a NestJS-import-free `domain/` (see § Service).

### Scaling

| App size | Pattern |
|----------|---------|
| 1-3 features | Feature modules at `src/*.module.ts` |
| 4+ features | Feature modules in `src/modules/*.module.ts` |
| 10+ bounded contexts | **NestJS monorepo** (`nest g app <name>`, `nest g library <name>`) — one Nest application per bounded context, shared `libs/` for cross-cutting code (auth, observability, common DTOs). Each app can deploy independently. |
| Cross-domain | Import another feature module, inject its exported service |

### Global Modules

Mark with `@Global()` when the module should be available everywhere without explicit imports:
- Persistence module (TypeORM) — every feature needs DB access
- `ConfigModule.forRoot({ isGlobal: true })` — config everywhere

---

## Domain Boundaries

1. **Domain = tangible arm of your business** (blogging, billing, identity)
2. **Entities that change atomically -> same domain**
3. **Cross-domain operations are never atomic** — service calls or async events
4. **Start large, decompose when friction is observed**

> If you need transactions across modules for cross-domain atomicity, your boundaries are wrong.

---

## Enforce the Boundary (CI)

"Domain never imports infrastructure" is a fitness function, not an honor system — and NestJS raises the stakes: DI resolves wiring at runtime, so a leaked import compiles and runs fine. A static rule must catch it (if the `software-architecture` skill is installed, this is its Stage-8 fitness functions at code level):

```js
// .dependency-cruiser.cjs (excerpt)
forbidden: [
  { name: "domain-stays-pure", severity: "error",
    from: { path: "^src/domain" },
    to: { path: "^src/(inbound|outbound)|^node_modules/(@nestjs|typeorm)",
          pathNot: "^node_modules/@nestjs/common" } },  // the @Injectable() concession (§ Service)
],
```

Run `depcruise src` in CI next to `tsc --noEmit`, lint, and tests; add `madge --circular src` — circular module imports are NestJS's most common architecture failure (`forwardRef` is the smell, the cycle is the disease).

Cross-cutting infrastructure that must not leak into the domain. Define each as an abstract class (the same DI-token pattern used for repositories); implement as outbound adapters. The architecture-level pattern lives in the software-architecture skill's references (`reliability-patterns.md`, `observability.md`) if installed; otherwise apply the standard patterns inline — outbox, idempotency keys, retry/backoff, structured logging, RED/USE.

| Port | Purpose | Where it lives |
|---|---|---|
| **UnitOfWork** | Scopes a database transaction across multiple repositories. Service composes `authorRepo` + `outboxRepo` (+ ...) inside one `uow.run(...)` callback — all writes commit or roll back together. CLS-scoped `EntityManager` propagation invisible to callers. | Outbound (TypeORM adapter); domain depends only on the abstract `UnitOfWork` class |
| **Outbox** | Atomic state change + message publish — outbox row written inside the same `uow.run(...)` callback as the aggregate write | Outbound (`OutboxRepository`, participates in UoW via CLS-scoped `EntityManager`) |
| **IdempotencyStore** | Replay safe responses for `Idempotency-Key`-bearing requests | Outbound; called by an interceptor or application service |
| **Tracer** / **Meter** | OTel span / metric emission. Domain depends on the abstract class, not on `@opentelemetry/*` | Outbound (OTel adapter); no-op for tests |

**Architectural rule**: domain emits **`DomainEvent`** plain objects; the application service opens a `UnitOfWork` and calls the aggregate repository + `OutboxRepository` inside the same `uow.run(...)` callback. Both writes commit together. A separate **outbox relay** (a `@nestjs/bullmq` worker, a `@Cron` task, or a separate process) publishes rows asynchronously.

**`UnitOfWork` over `@Transactional` — but both work**: `UnitOfWork` is the default. The `uow.run(async () => ...)` boundary is visible at the service call site, the implementation is a thin adapter that uses `nestjs-cls` to propagate the scoped `EntityManager`, and there's no third-party dependency. `@Transactional` (`typeorm-transactional`) is an acceptable opt-in trade-off if your team is already invested — same atomicity guarantee, less wiring per call site, but the tx boundary moves into decorator metadata and you take on the lib's maintenance risk. Pick one and stay consistent; don't mix.

For **single-repo transactions** (no cross-repo orchestration), inline `repo.manager.transaction(...)` inside the adapter is still fine — UoW is only needed when multiple repositories must share a tx.

**Optimistic concurrency (lost-update protection)**: any aggregate two clients can update concurrently carries `@VersionColumn()` on its entity. Do conditional updates — `em.update(AuthorEntity, { id, version: expected }, { ...changes, version: expected + 1 })` — and treat `affected === 0` as the conflict: domain conflict error → **409** (or **412** with `If-Match`/ETag, per `api-design.md`). (TypeORM's built-in optimistic check only fires on `save` with a `lock` option — the explicit conditional update is simpler and the boundary stays visible.) Idempotency keys cover the *same* client retrying; the version column covers *different* clients racing — you usually need both.

→ Adapter examples: `references/examples-adapters.md`

---

## Common Gotchas

| Problem | Cause | Fix |
|---------|-------|-----|
| Circular dependency error | Module A imports B, B imports A | Use `forwardRef(() => ModuleB)` or rethink boundaries |
| Service is `undefined` | Not provided in module | Add to `providers` with correct abstract class token |
| `HttpException` in domain | Transport leak | Use domain error classes, map in exception filter |
| TypeORM types in domain | ORM leak | Use mapper in outbound, domain has own types |
| Entity returned to controller / used as domain model | Hex boundary collapse | Always map `Entity -> Author -> Response DTO` |
| `@BeforeInsert` / Subscribers carry **business** logic | Business rule hides inside the adapter | Hooks/Subscribers are OK for *technical* concerns (uuid, timestamps, audit log). Move *business* logic to the domain service. |
| `cascade: true` reaches across aggregates | Auto-writes outside the aggregate root | OK within one aggregate (Order ↔ OrderLines). Off across aggregate boundaries — orchestrate via `UnitOfWork`. |
| `synchronize: true` in any deployed env | Auto-altering production schema | Keep `false`; use `migration:run` |
| `@InjectRepository(AuthorEntity)` undefined | `TypeOrmModule.forFeature([AuthorEntity])` missing in module | Add it to the persistence module's imports |
| `enableShutdownHooks()` missing | DB disconnect not called | Add in `main.ts` before `app.listen()` |
| Tests share DB state | Missing cleanup | Reset in `beforeEach` or use transaction rollback |

---

## Quick Reference

| Question | Answer |
|----------|--------|
| Single-repo transaction? | `repo.manager.transaction(async (em) => ...)` inside the adapter |
| Cross-repo transaction? | `UnitOfWork` port — `await this.uow.run(async () => { ... })` in the service. CLS propagates the scoped `EntityManager`. Don't open nested transactions. |
| Lost updates? | `@VersionColumn()` + conditional `em.update(..., { id, version })`; `affected === 0` → 409/412 |
| Validation? | `nestjs-zod` `createZodDto` + global `ZodValidationPipe` at transport boundary, domain constructors for business rules |
| Error mapping? | `@Catch()` exception filter in inbound |
| Business orchestration? | Service impl |
| Controller responsibility? | Parse -> service -> response |
| main.ts responsibility? | Create app, global middleware, Swagger, listen |
| DI mechanism? | Abstract classes as tokens; `useClass` (default) — switch to `useFactory` only to keep `domain/` NestJS-import-free |
| Entity <-> domain? | `AuthorMapper.toDomain(entity)` / `toEntity(domain)` in outbound |
| Test runner / app? | Vitest + `@nestjs/testing` `Test.createTestingModule().overrideProvider()` |
| Background workers? | `@nestjs/bullmq` or `@nestjs/schedule` |
| Migrations? | TypeORM CLI (`migration:generate` + `migration:run`) |
| Healthcheck? | `@nestjs/terminus` in inbound |
| JWT / passwords? | `jose` + `@node-rs/argon2` |

---

## Checklist

### Architecture
- [ ] Domain never imports from inbound/, outbound/, or @nestjs/* (domain service may import `@Injectable()` only, see "Service" above)
- [ ] Ports as abstract classes, services orchestrate
- [ ] All handlers (HTTP, jobs, events): parse -> service -> respond
- [ ] Single-repo tx via `repo.manager.transaction()` inside adapter; cross-repo tx via `UnitOfWork` port composed in the service
- [ ] Repositories read the active `EntityManager` from CLS (`this.em()`) so they participate in any active `UnitOfWork`
- [ ] Entity <-> domain mapper in outbound
- [ ] Errors: domain hierarchy (`DomainError` base) -> exception filter -> RFC 9457
- [ ] Racing aggregates carry `@VersionColumn()`; `affected === 0` writes map to 409/412
- [ ] Boundary enforced in CI: dependency-cruiser rule + `madge --circular` (see Enforce the Boundary)

### Framework
- [ ] Controllers in inbound/ with `@Controller()` decorators
- [ ] Services wired via `useClass` with `@Injectable()` on the impl (or `useFactory`, see § Service)
- [ ] Validation via `createZodDto` classes + `ZodValidationPipe` registered through `APP_PIPE` (returns **422** on failure, matching api-design.md); Swagger doc wrapped with `cleanupOpenApiDoc()`
- [ ] Global `DomainExceptionFilter` registered via `APP_FILTER` in AppModule (DI-resolved — it injects `ClsService` for the `X-Request-Id` header); filter matches on `instanceof DomainError` (base class), not on a loose `"tag" in error` check; re-maps `ThrottlerException` 429 to `application/problem+json`
- [ ] `enableShutdownHooks()` called in main.ts
- [ ] `helmet()` middleware enabled
- [ ] `@nestjs/throttler` wired as `APP_GUARD` (global rate limit)
- [ ] CORS configured with explicit origins
- [ ] `nestjs-pino` set as the app logger; `nestjs-cls` middleware populates request-scoped correlation IDs

### Database (TypeORM + PostgreSQL)
- [ ] Entities in `outbound/typeorm/entities/*.entity.ts` (NEVER imported from domain)
- [ ] `TypeOrmPersistenceModule` is `@Global()` and registers `forFeature([...entities])`
- [ ] `synchronize: false` in every env; migrations run via TypeORM CLI
- [ ] Data Mapper only — no `entity.save()`, no `@BeforeInsert`/Subscribers, no `cascade: true`, no lazy `Promise<Related>`
- [ ] Repository extends domain port; `QueryFailedError` driver code mapped to domain errors
- [ ] Mapper handles `Entity <-> Author` in both directions

### Testing
**TDD**: Write all tests first as a spec, then implement, then verify all pass. (Tests -> Impl -> Green)
- [ ] **Vitest** as the test runner (faster startup than Jest, native ESM, better with Bun)
- [ ] Test helpers: `createTestModule()` factory
- [ ] Mock strategy: Stub, Saboteur, Spy, NoOp (hand-rolled abstract-class extensions). As the port surface grows, hybrid with `vi.fn()` to avoid spy-class boilerplate explosion.
- [ ] `overrideProvider()` for swapping adapters in tests
> Test mocks and test module helper: `references/examples-bootstrap.md`

### Setup
- [ ] `main.ts` has minimal business logic
- [ ] `bun.lock` committed
- [ ] Config validated with Zod at startup
