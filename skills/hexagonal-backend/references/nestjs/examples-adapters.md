# Examples: Adapters

Inbound (controller, DTOs, exception filter, auth guard, pipes, healthcheck) and outbound (TypeORM + PostgreSQL repository, mapper).

## Table of Contents

1. [Outbound: TypeORM — Entity](#outbound-typeorm--entity)
2. [Outbound: TypeORM — Module](#outbound-typeorm--module)
3. [Outbound: Cursor Helpers (composite + base64)](#outbound-cursor-helpers-composite--base64)
4. [Outbound: TypeORM — Mapper + Repository](#outbound-typeorm--mapper--repository)
5. [Outbound: TypeORM — Inline Single-Repo Transaction](#outbound-typeorm--inline-single-repo-transaction)
6. [Inbound: ZodValidationPipe](#inbound-zodvalidationpipe)
7. [Inbound: Request DTOs](#inbound-request-dtos)
8. [Inbound: Response DTOs](#inbound-response-dtos)
9. [Inbound: Controller](#inbound-controller)
10. [Inbound: Exception Filter (RFC 9457)](#inbound-exception-filter-rfc-9457)
11. [Inbound: Auth Guard (JWT with `jose`)](#inbound-auth-guard-jwt-with-jose)
12. [Inbound: Healthcheck](#inbound-healthcheck)
13. [Inbound: Job Handler (non-HTTP inbound adapter)](#inbound-job-handler-non-http-inbound-adapter)
14. [Outbound: UnitOfWork Adapter (TypeORM + nestjs-cls)](#outbound-unitofwork-adapter-typeorm--nestjs-cls)
15. [Outbound: Outbox via UoW](#outbound-outbox-via-uow)
16. [Outbound: Idempotency Store](#outbound-idempotency-store)
17. [Inbound: Rate Limiting (`@nestjs/throttler`)](#inbound-rate-limiting-nestjsthrottler)
18. [Outbound: Tracer Port (OTel)](#outbound-tracer-port-otel)

---

## Outbound: TypeORM — Entity

```typescript
// src/outbound/typeorm/entities/author.entity.ts
import {
  Entity, Column, PrimaryGeneratedColumn,
  CreateDateColumn, UpdateDateColumn, Index,
} from "typeorm";

/**
 * TypeORM entity — outbound only. NEVER imported in domain.
 * This is a persistence representation of `Author`, not the domain model itself.
 */
@Entity({ name: "authors" })
export class AuthorEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Index({ unique: true })
  @Column({ type: "text" })
  name!: string;

  @CreateDateColumn({ name: "created_at", type: "timestamptz" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at", type: "timestamptz" })
  updatedAt!: Date;
}
```

```typescript
// src/outbound/typeorm/entities/outbox.entity.ts
import {
  Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, Index,
} from "typeorm";

/**
 * Outbox row — written inside the same UoW as the aggregate. A relay worker
 * reads `published_at IS NULL ORDER BY id LIMIT N`, publishes, then updates
 * `published_at`. `traceparent` carries the originating request's trace.
 */
@Entity({ name: "outbox" })
export class OutboxEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Column({ name: "aggregate_type", type: "text" })
  aggregateType!: string;

  @Column({ name: "aggregate_id", type: "text" })
  aggregateId!: string;

  @Column({ name: "event_type", type: "text" })
  eventType!: string;

  @Column({ type: "jsonb" })
  payload!: Record<string, unknown>;

  @Column({ type: "text", nullable: true })
  traceparent!: string | null;

  @CreateDateColumn({ name: "created_at", type: "timestamptz" })
  createdAt!: Date;

  // Index covers the relay's "find next batch" query.
  @Index("idx_outbox_unpublished", ["publishedAt", "id"])
  @Column({ name: "published_at", type: "timestamptz", nullable: true })
  publishedAt!: Date | null;
}
```

## Outbound: TypeORM — Module

```typescript
// src/outbound/typeorm/typeorm.module.ts
import { Global, Module } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { AuthorEntity } from "./entities/author.entity";
import { OutboxEntity } from "./entities/outbox.entity";
import { TypeOrmAuthorRepository } from "./author.repository";
import { TypeOrmOutboxRepository } from "./typeorm-outbox.repository";
import { TypeOrmUnitOfWork } from "./typeorm-unit-of-work";
import { AuthorRepository } from "../../domain/authors/ports";
import { OutboxRepository } from "../../domain/shared/outbox";
import { UnitOfWork } from "../../domain/shared/unit-of-work";
import type { AppConfig } from "../../config";

@Global()
@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppConfig, true>) => ({
        type: "postgres",
        url: config.get("DATABASE_URL"),
        entities: [AuthorEntity, OutboxEntity],
        migrations: ["dist/migrations/*.js"],
        // synchronize MUST stay false in every deployed env — migrations only.
        synchronize: false,
        logging: config.get("NODE_ENV") === "development" ? ["query", "error"] : ["error"],
        poolSize: 10,
      }),
    }),
    TypeOrmModule.forFeature([AuthorEntity, OutboxEntity]),
  ],
  providers: [
    // Repository implementations — each bound to its domain port.
    { provide: AuthorRepository, useClass: TypeOrmAuthorRepository },
    { provide: OutboxRepository, useClass: TypeOrmOutboxRepository },
    // UnitOfWork — wraps DataSource.transaction + CLS propagation.
    { provide: UnitOfWork, useClass: TypeOrmUnitOfWork },
  ],
  exports: [AuthorRepository, OutboxRepository, UnitOfWork, TypeOrmModule],
})
export class TypeOrmPersistenceModule {}
```

> The persistence module depends on `ClsModule` (registered in `AppModule`) for the CLS-scoped `EntityManager`. CLS is set up via middleware on the request, then `TypeOrmUnitOfWork.run()` nests its own frame on top.

## Outbound: Cursor Helpers (composite + base64)

```typescript
// src/outbound/cursor.ts
// Composite cursor (createdAt, id) encoded as opaque base64.
// Single-column `id > X` cursors skip/duplicate rows under concurrent inserts;
// composite (createdAt, id) is stable.
export function encodeCursor(createdAt: Date, id: string): string {
  return Buffer.from(`${createdAt.toISOString()}|${id}`).toString("base64url");
}

export function decodeCursor(raw: string): { createdAt: Date; id: string } {
  const [ts, id] = Buffer.from(raw, "base64url").toString("utf8").split("|", 2);
  return { createdAt: new Date(ts), id };
}
```

## Outbound: TypeORM — Mapper + Repository

```typescript
// src/outbound/typeorm/mapper.ts
import { AuthorName } from "../../domain/authors/models";
import type { Author, CreateAuthorRequest } from "../../domain/authors/models";
import { AuthorEntity } from "./entities/author.entity";

/**
 * Maps in BOTH directions so the entity stays sealed inside the adapter.
 * Domain code only ever sees `Author`.
 */
export class AuthorMapper {
  static toDomain(entity: AuthorEntity): Author {
    return { id: entity.id, name: AuthorName.create(entity.name) };
  }

  static toEntity(req: CreateAuthorRequest): AuthorEntity {
    const entity = new AuthorEntity();
    entity.name = req.name.value;
    return entity;
  }
}
```

```typescript
// src/outbound/typeorm/author.repository.ts
import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { ClsService } from "nestjs-cls";
import { EntityManager, QueryFailedError, Repository } from "typeorm";
import { AuthorEntity } from "./entities/author.entity";
import { AuthorMapper } from "./mapper";
import { TYPEORM_EM_KEY } from "./typeorm-unit-of-work";
import { decodeCursor, encodeCursor } from "../cursor";
import { AuthorRepository } from "../../domain/authors/ports";
import type { Author, CreateAuthorRequest, CursorPage } from "../../domain/authors/models";
import {
  DuplicateAuthorError,
  UnknownAuthorError,
} from "../../domain/authors/errors";

const PG_UNIQUE_VIOLATION = "23505";

@Injectable()
export class TypeOrmAuthorRepository extends AuthorRepository {
  constructor(
    @InjectRepository(AuthorEntity)
    private readonly repo: Repository<AuthorEntity>,
    private readonly cls: ClsService,
  ) {
    super();
  }

  /**
   * Pick the active EntityManager — CLS-scoped if we're inside `uow.run(...)`,
   * otherwise the repository's default manager. Every read/write goes through
   * this helper so the same code participates in any active transaction
   * without each caller threading an `em` parameter.
   */
  private em(): EntityManager {
    return this.cls.get<EntityManager>(TYPEORM_EM_KEY) ?? this.repo.manager;
  }

  async createAuthor(req: CreateAuthorRequest): Promise<Author> {
    const entity = AuthorMapper.toEntity(req);
    try {
      // Data Mapper style: em.save(EntityClass, entity), never entity.save().
      const saved = await this.em().save(AuthorEntity, entity);
      return AuthorMapper.toDomain(saved);
    } catch (error) {
      if (this.isUniqueConstraintError(error)) {
        throw new DuplicateAuthorError(req.name.value);
      }
      throw new UnknownAuthorError(error);
    }
  }

  async findAuthor(authorId: string): Promise<Author | null> {
    const entity = await this.em().findOneBy(AuthorEntity, { id: authorId });
    return entity ? AuthorMapper.toDomain(entity) : null;
  }

  async listAuthors(
    cursor: string | null,
    limit: number,
  ): Promise<CursorPage<Author>> {
    // QueryBuilder for tuple comparison `(created_at, id) > (cursorAt, cursorId)`.
    // Plain `find({ where })` doesn't support tuple predicates.
    const qb = this.em()
      .createQueryBuilder(AuthorEntity, "author")
      .orderBy("author.created_at", "ASC")
      .addOrderBy("author.id", "ASC")
      .limit(limit + 1);

    if (cursor) {
      const { createdAt, id } = decodeCursor(cursor);
      qb.where(
        "(author.created_at, author.id) > (:createdAt, :id)",
        { createdAt, id },
      );
    }

    const entities = await qb.getMany();
    const hasMore = entities.length > limit;
    // Drop overflow row; cursor is the LAST RETURNED row so the next page
    // resumes AFTER it (no duplicates, no skips).
    const pageEntities = entities.slice(0, limit);
    const items = pageEntities.map(AuthorMapper.toDomain);
    // `last` is the ENTITY row, not the mapped domain model — the cursor needs
    // created_at, which the entity carries and domain Author deliberately omits.
    const last = pageEntities[pageEntities.length - 1];
    const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

    return { items, nextCursor, hasMore };
  }

  private isUniqueConstraintError(error: unknown): boolean {
    return (
      error instanceof QueryFailedError &&
      (error as QueryFailedError & { driverError?: { code?: string } }).driverError?.code === PG_UNIQUE_VIOLATION
    );
  }
}
```

> **Why `this.em()` everywhere?** Without it, `this.repo.save(...)` always uses the data source's *default* manager — never the UoW's scoped one. The result: `uow.run(...)` opens a tx, but the repo writes outside it. Silent atomicity failure. Making every read/write go through `this.em()` is the only safe default.

## Outbound: TypeORM — Inline Single-Repo Transaction

For a transaction confined to **one repository** (writing two entities the
adapter already knows about), inline `manager.transaction(...)` is the simplest
path — no UoW needed.

```typescript
async createAuthorWithProfile(req: CreateAuthorWithProfileRequest): Promise<Author> {
  try {
    // Use the active EM as the *transaction root*. If we're already inside
    // `uow.run(...)`, this nests via SAVEPOINT (be aware). If not, it opens
    // a fresh tx for just this method.
    const saved = await this.em().transaction(async (manager) => {
      const author = await manager.save(AuthorEntity, { name: req.name.value });
      await manager.save(ProfileEntity, { authorId: author.id, bio: req.bio });
      return author;
    });
    return AuthorMapper.toDomain(saved);
  } catch (error) {
    if (this.isUniqueConstraintError(error)) throw new DuplicateAuthorError(req.name.value);
    throw new UnknownAuthorError(error);
  }
}
```

For atomicity that spans multiple repositories (aggregate write + outbox enqueue, or two aggregates touched together), use the `UnitOfWork` port instead — the service composes the repos inside one `uow.run(...)` callback.

---

## Inbound: ZodValidationPipe

`nestjs-zod` ships the `ZodValidationPipe`; register it once via `APP_PIPE` (see `examples-bootstrap.md`). Build it with `createZodValidationPipe` so a failed parse returns the RFC 9457 ProblemDetails body — `DomainExceptionFilter` already serves `HttpException` bodies as `application/problem+json`, so this shape flows through unchanged. Without the custom factory, `nestjs-zod` emits its own `{ statusCode, message, errors }` body, which breaks the API's error contract.

```typescript
// src/inbound/http/pipes/zod-validation.pipe.ts
import { UnprocessableEntityException } from "@nestjs/common";
import { createZodValidationPipe } from "nestjs-zod";
import type { ZodError, ZodIssue } from "zod";

/**
 * nestjs-zod's pipe, customized so validation failures match the API's
 * RFC 9457 ProblemDetails error shape instead of nestjs-zod's default body.
 * The object thrown here IS a ProblemDetails body — `DomainExceptionFilter`
 * passes it through verbatim (only stamping `instance`), so the validation
 * shape and the filter's `problem()` shape can't drift apart.
 *
 * Status: 422 Unprocessable Entity (matches api-design.md — schema parsed,
 * semantic validation failed). Use 400 only for malformed transport
 * (unparseable JSON, missing Content-Type, etc.).
 */

/**
 * For z.discriminatedUnion / nested unions the failing issue can carry an
 * empty (root) path → `field: ""`, which names nothing. Recurse into the
 * union's sub-issues and prefer one with a non-empty path so `errors[]`
 * always names a meaningful field. (Zod 4 also offers `z.treeifyError` /
 * `z.flattenError`; this keeps the flat `errors[]` contract.)
 */
function fieldOf(issue: ZodIssue): string {
  if (issue.path.length > 0) return issue.path.join(".");
  // Zod 4: an invalid_union issue carries `errors` — one issue list per union
  // option (Zod 3 called it `unionErrors: ZodError[]`; that field no longer exists).
  if (issue.code === "invalid_union" && Array.isArray(issue.errors)) {
    for (const optionIssues of issue.errors) {
      const named = optionIssues.find((i) => i.path.length > 0);
      if (named) return named.path.join(".");
    }
  }
  return "";
}

export const ZodValidationPipe = createZodValidationPipe({
  createValidationException: (error: ZodError) =>
    new UnprocessableEntityException({
      type: "https://api.example.com/errors/validation-failed",
      title: "Validation Failed",
      status: 422,
      detail: "Request body failed validation",
      errors: error.issues.map((e) => ({
        field: fieldOf(e),
        code: e.code,
        message: e.message,
      })),
    }),
});
```

## Inbound: Request DTOs

`createZodDto(schema)` turns a Zod schema into a class that is three things at once: the compile-time type, the runtime validation schema, and the OpenAPI schema `@nestjs/swagger` reads. `toDomain()` translates the validated DTO into the domain request.

```typescript
// src/inbound/http/authors/request.dto.ts
import { createZodDto } from "nestjs-zod";
import { z } from "zod";
import { AuthorName, type CreateAuthorRequest } from "../../../domain/authors/models";

export const createAuthorSchema = z.object({
  name: z.string().min(1, "name is required"),
});
export class CreateAuthorDto extends createZodDto(createAuthorSchema) {}

export function toDomain(body: CreateAuthorDto): CreateAuthorRequest {
  return { name: AuthorName.create(body.name) };
}

export const paginationSchema = z.object({
  cursor: z.string().nullish().transform((v) => v ?? null),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});
export class PaginationQueryDto extends createZodDto(paginationSchema) {}
```

> `z.coerce.number()` is required for query-string params — every query value arrives as a string. For nested objects just nest `z.object(...)`; for tagged unions use `z.discriminatedUnion("type", [...])`.

## Inbound: Response DTOs

```typescript
// src/inbound/http/authors/response.dto.ts
import { ApiProperty } from "@nestjs/swagger";
import type { Author } from "../../../domain/authors/models";

export class AuthorResponse {
  // Definite-assignment `!` — fields are populated by fromDomain(), never the
  // constructor, so `strict: true` (strictPropertyInitialization) is satisfied.
  // Matches the entity style, which uses `!` for the same reason.
  @ApiProperty({ example: "550e8400-e29b-41d4-a716-446655440000" })
  id!: string;

  @ApiProperty({ example: "Alice" })
  name!: string;

  static fromDomain(author: Author): AuthorResponse {
    const dto = new AuthorResponse();
    dto.id = author.id;
    dto.name = author.name.value;
    return dto;
  }
}

/**
 * Cursor pagination response shape — matches api-design.md:
 *   { data: [...], meta: { limit, next_cursor, has_more } }
 * Keep cursor metadata inside `meta`, never flat on the top level.
 */
export class CursorPageMeta {
  @ApiProperty({ example: 20 })
  limit!: number;

  // base64url of `<isoDate>|<uuid>` — see encodeCursor/decodeCursor in cursor.ts.
  @ApiProperty({
    nullable: true,
    example: "MjAyNi0wNS0yOVQxMjowMDowMC4wMDBafDU1MGU4NDAwLWUyOWItNDFkNC1hNzE2LTQ0NjY1NTQ0MDAwMA",
  })
  next_cursor!: string | null;

  @ApiProperty()
  has_more!: boolean;
}

export class CursorPageResponse {
  @ApiProperty({ type: [AuthorResponse] })
  data!: AuthorResponse[];

  @ApiProperty({ type: CursorPageMeta })
  meta!: CursorPageMeta;
}
```

## Inbound: Controller

```typescript
// src/inbound/http/authors/authors.controller.ts
import {
  Controller, Get, Post, Param, Body, Query, Res,
  HttpCode, HttpStatus,
} from "@nestjs/common";
import { ApiTags, ApiOperation, ApiResponse } from "@nestjs/swagger";
import type { Response } from "express";
import { AuthorService } from "../../../domain/authors/ports";
import { CreateAuthorDto, PaginationQueryDto, toDomain } from "./request.dto";
import { AuthorResponse, CursorPageResponse } from "./response.dto";
import { ProblemDetail } from "../filters/problem-detail.dto";
import { AuthorNotFoundError } from "../../../domain/authors/errors";

@ApiTags("authors")
@Controller("v1/authors")
export class AuthorsController {
  constructor(private readonly authorService: AuthorService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: "Create an author" })
  @ApiResponse({ status: 201, type: AuthorResponse })
  @ApiResponse({ status: 409, type: ProblemDetail })
  @ApiResponse({ status: 422, type: ProblemDetail })
  async create(
    // passthrough: true → we set headers but still return a body Nest serialises.
    @Res({ passthrough: true }) res: Response,
    @Body() body: CreateAuthorDto,
  ): Promise<{ data: AuthorResponse }> {
    const author = await this.authorService.createAuthor(toDomain(body));
    // 201 responses carry a Location header pointing at the new resource.
    res.header("Location", `/v1/authors/${author.id}`);
    return { data: AuthorResponse.fromDomain(author) };
  }

  @Get()
  @ApiOperation({ summary: "List authors" })
  async list(
    @Query() query: PaginationQueryDto,
  ): Promise<CursorPageResponse> {
    const page = await this.authorService.listAuthors(query.cursor, query.limit);
    return {
      data: page.items.map(AuthorResponse.fromDomain),
      meta: {
        limit: query.limit,
        next_cursor: page.nextCursor,
        has_more: page.hasMore,
      },
    };
  }

  @Get(":id")
  @ApiOperation({ summary: "Get an author by ID" })
  @ApiResponse({ status: 200, type: AuthorResponse })
  @ApiResponse({ status: 404, type: ProblemDetail })
  async findOne(@Param("id") id: string): Promise<{ data: AuthorResponse }> {
    const author = await this.authorService.findAuthor(id);
    if (!author) {
      throw new AuthorNotFoundError(id);
    }
    return { data: AuthorResponse.fromDomain(author) };
  }
}
```

> **Not-found semantics note:** `findAuthor()` returns `Author | null` and the
> controller maps `null → AuthorNotFoundError`. That's fine for a single inbound
> adapter. With multiple adapters (controller + job + gRPC), prefer a
> `getAuthor(id): Promise<Author>` use case in the service that throws
> `AuthorNotFoundError` itself, so every adapter inherits identical semantics
> instead of re-implementing the null check.

## Inbound: Exception Filter (RFC 9457)

Every error response — domain errors, `HttpException` bodies (incl. the
`ZodValidationPipe` output and the throttler's 429) — flows through ONE
`problem()` builder, so the shape can't diverge field-to-field. The body
always carries `type`/`title`/`status` and optionally `detail`, `instance`,
and the `errors[]` validation extension. The correlation id is set on the
`X-Request-Id` **response header** (the CLS/pino id), never in the body, so
it survives bodiless 204/304 responses too.

```typescript
// src/inbound/http/filters/domain-exception.filter.ts
//
// Note (Express coupling): this filter writes directly through Express's
// Response object (status/header/json). If you swap to Fastify
// (@nestjs/platform-fastify), replace these calls with the Fastify reply
// API or use NestJS's platform-agnostic HttpAdapterHost.
import {
  Catch, ExceptionFilter, ArgumentsHost, Logger, HttpException, HttpStatus,
} from "@nestjs/common";
import { ThrottlerException } from "@nestjs/throttler";
import { ClsService } from "nestjs-cls";
import type { Request, Response } from "express";
import { DomainError } from "../../../domain/shared/errors";
import { UnknownAuthorError } from "../../../domain/authors/errors";

/**
 * RFC 9457 ProblemDetails. `detail`, `instance`, and the `errors[]` extension
 * are all optional — but every body is built by `problem()` so the field set
 * is uniform regardless of which branch produced it.
 */
interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  errors?: Array<{ field: string; code: string; message: string }>;
}

interface ProblemInput {
  slug: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  errors?: ProblemDetails["errors"];
}

function problem(input: ProblemInput): ProblemDetails {
  const { slug, title, status, detail, instance, errors } = input;
  return {
    type: `https://api.example.com/errors/${slug}`,
    title,
    status,
    ...(detail !== undefined ? { detail } : {}),
    ...(instance !== undefined ? { instance } : {}),
    ...(errors !== undefined ? { errors } : {}),
  };
}

@Catch()
export class DomainExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(DomainExceptionFilter.name);

  constructor(private readonly cls: ClsService) {}

  private send(res: Response, body: ProblemDetails): void {
    res.status(body.status).header("Content-Type", "application/problem+json");
    // Correlation id → response header (CLS/pino request id), never the body.
    // getId() is set per request by ClsModule's middleware (generateId: true);
    // guard for setups without it so we never write an `undefined` header.
    const requestId = this.cls.getId();
    if (requestId) res.header("X-Request-Id", requestId);
    res.json(body);
  }

  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<Request>();
    const instance = request.url;

    // 429 from @nestjs/throttler: its default body is NOT problem+json. Re-map
    // it here so even rate-limit responses honour the error contract.
    if (exception instanceof ThrottlerException) {
      this.send(response, problem({
        slug: "rate-limited",
        title: "Too Many Requests",
        status: HttpStatus.TOO_MANY_REQUESTS,
        detail: "Rate limit exceeded; retry after the Retry-After interval",
        instance,
      }));
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const raw = exception.getResponse();
      // A string response → wrap it. An object response is assumed to already
      // be a ProblemDetails-shaped body (e.g. ZodValidationPipe, Conflict
      // exceptions thrown with a problem body); normalise `instance` onto it.
      const body: ProblemDetails =
        typeof raw === "string"
          ? problem({ slug: "error", title: raw, status, detail: raw, instance })
          : { ...(raw as ProblemDetails), instance };
      this.send(response, body);
      return;
    }

    // `instanceof DomainError` rules out third-party Error objects that
    // might happen to carry a `tag` field. Switch on the string-literal
    // discriminant; unmapped tags fall through to the 500 below.
    //
    // Domain-agnostic note: this switch is author-specific by design (it's the
    // illustration). In a multi-domain app a new feature's DomainError tag would
    // fall through to 500. Scale this one of three ways:
    //   (a) give `DomainError` an abstract `toProblem(): { slug; title; status }`
    //       so each error maps itself and the filter never switches on tags;
    //   (b) a tag→problem registry each feature module contributes to at boot;
    //   (c) keep per-domain filters. Pick one before you have a second domain.
    if (exception instanceof DomainError) {
      switch (exception.tag) {
        case "DuplicateAuthorError":
          this.send(response, problem({
            slug: "duplicate-author", title: "Conflict", status: 409,
            detail: exception.message, instance,
          }));
          return;
        case "AuthorNameEmptyError":
          this.send(response, problem({
            slug: "validation-error", title: "Unprocessable Entity", status: 422,
            detail: exception.message, instance,
          }));
          return;
        case "AuthorNotFoundError":
          this.send(response, problem({
            slug: "not-found", title: "Not Found", status: 404,
            detail: exception.message, instance,
          }));
          return;
        case "UnknownAuthorError":
          this.logger.error("Unexpected error:", (exception as UnknownAuthorError).cause);
          break;
        default:
          // New domain errors fall through here. Add a case above (or adopt
          // toProblem()) before shipping; the request gets a 500 meanwhile.
          this.logger.error(`Unhandled domain error tag "${exception.tag}":`, exception);
      }
    } else {
      this.logger.error("Unhandled error:", exception);
    }

    this.send(response, problem({
      slug: "internal-error", title: "Internal Server Error", status: 500,
      detail: "An unexpected error occurred", instance,
    }));
  }
}
```

> **DomainExceptionFilter now depends on `ClsService`** for the request id, so
> register it via DI (`{ provide: APP_FILTER, useClass: DomainExceptionFilter }`)
> rather than `new DomainExceptionFilter()` — see `examples-bootstrap.md`.

### ProblemDetail OpenAPI DTO

A documentation-only class so `@ApiResponse({ status, type: ProblemDetail })`
renders the RFC 9457 error shape in the generated OpenAPI. It is never
constructed at runtime — the filter emits plain objects via `problem()`.

```typescript
// src/inbound/http/filters/problem-detail.dto.ts
import { ApiProperty } from "@nestjs/swagger";

class ProblemErrorItem {
  @ApiProperty({ example: "name" })
  field!: string;

  @ApiProperty({ example: "too_small" })
  code!: string;

  @ApiProperty({ example: "name is required" })
  message!: string;
}

export class ProblemDetail {
  @ApiProperty({ example: "https://api.example.com/errors/not-found" })
  type!: string;

  @ApiProperty({ example: "Not Found" })
  title!: string;

  @ApiProperty({ example: 404 })
  status!: number;

  @ApiProperty({ required: false, example: 'author with id "123" not found' })
  detail?: string;

  @ApiProperty({ required: false, example: "/v1/authors/123" })
  instance?: string;

  @ApiProperty({ required: false, type: [ProblemErrorItem] })
  errors?: ProblemErrorItem[];
}
```

## Inbound: Auth Guard (JWT with `jose`)

```typescript
// src/inbound/http/guards/jwt-auth.guard.ts
//
// `jose` (https://github.com/panva/jose) is the modern JWT/JOSE library:
// EdDSA/ES256 first-class, ESM/CJS, JWK/JWKS, no CVE backlog. Prefer it
// over `jsonwebtoken` (CJS-only, no native ES module support).
//
// Canonical example below is ASYMMETRIC (ES256 over a JWKS) — matches
// api-design.md ("prefer ES256/EdDSA once multiple services verify"):
// only the issuer holds the private key; verifiers fetch the public key
// from the issuer's JWKS endpoint. `aud` and `iss` are validated so a
// token minted for another audience can't be replayed here.
import {
  CanActivate, ExecutionContext, Injectable, UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import type { Request } from "express";
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";
import { z } from "zod";
import type { AppConfig } from "../../../config";

/**
 * Validate the decoded payload — never trust the JWT body just because
 * the signature checks out. Refuse anything we don't recognise.
 */
const JwtPayload = z.object({
  sub: z.string().min(1),
  exp: z.number(),
});

// Augment Express's Request locally so we don't sprinkle `as any` everywhere.
interface AuthedRequest extends Request {
  userId?: string;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  private readonly jwks: JWTVerifyGetKey;
  private readonly audience: string;
  private readonly issuer: string;

  constructor(config: ConfigService<AppConfig, true>) {
    // createRemoteJWKSet caches keys and refreshes on unknown `kid` rotation.
    this.jwks = createRemoteJWKSet(new URL(config.get("JWT_JWKS_URL")));
    this.audience = config.get("JWT_AUDIENCE");
    this.issuer = config.get("JWT_ISSUER");
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const authHeader = request.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      throw new UnauthorizedException("Missing token");
    }

    try {
      const { payload } = await jwtVerify(authHeader.slice(7), this.jwks, {
        // Pin asymmetric algorithms — never accept "none" or symmetric HS*.
        algorithms: ["ES256"], // or ["EdDSA"]
        audience: this.audience,
        issuer: this.issuer,
      });
      const validated = JwtPayload.parse(payload);
      request.userId = validated.sub;
      return true;
    } catch {
      throw new UnauthorizedException("Invalid token");
    }
  }
}
```

For OAuth / multiple strategies in the same app, layer `@nestjs/passport` on top — the guard above stays as the JWT case.

### Single-service / dev fallback: HS256 symmetric secret

When **one** service both issues and verifies tokens (no JWKS to publish),
a symmetric secret is acceptable — see api-design.md. Note `createSecretKey`
and `KeyObject` are exported by **`node:crypto`**, not `jose`; the simplest
form skips the key object entirely and passes the encoded secret to
`jwtVerify`:

```typescript
import { jwtVerify } from "jose";
// Option A — encode the secret inline (simplest):
const secret = new TextEncoder().encode(config.get("JWT_SECRET"));
// Option B — a reusable KeyObject (from node:crypto, NOT jose):
//   import { createSecretKey, type KeyObject } from "node:crypto";
//   const secret: KeyObject = createSecretKey(config.get("JWT_SECRET"), "utf-8");

const { payload } = await jwtVerify(authHeader.slice(7), secret, {
  algorithms: ["HS256"], // symmetric — single-service / dev only
});
```

Prefer the asymmetric guard above for anything multi-service.

### Applying the guard to a protected route

`addBearerAuth()` in `main.ts` only *registers* the scheme — Swagger won't mark
any operation as protected until you decorate it. Apply `@UseGuards(JwtAuthGuard)`
(enforcement) **and** `@ApiBearerAuth()` (documentation) together on each
protected handler. The author CRUD routes in this skill are intentionally public;
a mutation that must be authenticated looks like this:

```typescript
import { UseGuards } from "@nestjs/common";
import { ApiBearerAuth } from "@nestjs/swagger";
import { JwtAuthGuard } from "../guards/jwt-auth.guard";

@Post()
@UseGuards(JwtAuthGuard)   // enforce: 401 without a valid bearer token
@ApiBearerAuth()           // document: shows the lock icon + 401 in OpenAPI
async create(/* ... */) { /* ... */ }
```

If *no* route is protected, drop `addBearerAuth()` from `main.ts` so the OpenAPI
doc doesn't advertise a security scheme nothing uses.

## Inbound: Healthcheck

```typescript
// src/inbound/http/health/health.controller.ts
import { Controller, Get } from "@nestjs/common";
import {
  HealthCheck,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from "@nestjs/terminus";
import { ApiTags } from "@nestjs/swagger";

@ApiTags("health")
@Controller("health")
export class HealthController {
  constructor(
    private readonly health: HealthCheckService,
    private readonly db: TypeOrmHealthIndicator,
  ) {}

  /** Liveness — the process is up. Always 200. */
  @Get("live")
  live() {
    return { status: "ok" };
  }

  /** Readiness — can it serve traffic? 503 when DB is unreachable. */
  @Get("ready")
  @HealthCheck()
  ready() {
    return this.health.check([
      () => this.db.pingCheck("database", { timeout: 1000 }),
    ]);
  }
}
```

## Inbound: Job Handler (non-HTTP inbound adapter)

```typescript
// src/inbound/jobs/sync-author.processor.ts
import { Processor, WorkerHost } from "@nestjs/bullmq";
import type { Job } from "bullmq";
import { AuthorName } from "../../domain/authors/models";
import { AuthorService } from "../../domain/authors/ports";

@Processor("author-sync")
export class SyncAuthorProcessor extends WorkerHost {
  constructor(private readonly authorService: AuthorService) {
    super();
  }

  async process(job: Job<{ authorName: string; source: string }>) {
    const domainReq = { name: AuthorName.create(job.data.authorName) };
    await this.authorService.createAuthor(domainReq);
  }
}
```

---

## Outbound: UnitOfWork Adapter (TypeORM + nestjs-cls)

For cross-repository atomicity, the `UnitOfWork` port wraps `DataSource.transaction(...)` and propagates the scoped `EntityManager` to participating repositories via `nestjs-cls`. The service composes the writes; the adapter handles the plumbing.

```typescript
// src/outbound/typeorm/typeorm-unit-of-work.ts
import { Injectable } from "@nestjs/common";
import { DataSource, EntityManager } from "typeorm";
import { ClsService } from "nestjs-cls";
import { UnitOfWork } from "../../domain/shared/unit-of-work";

/**
 * CLS key for the active EntityManager. Every CLS-aware repository reads
 * this — if present, the repo participates in the active tx; if absent,
 * the repo uses its default manager (i.e. a fresh connection per call).
 */
export const TYPEORM_EM_KEY = "typeorm:em";

@Injectable()
export class TypeOrmUnitOfWork extends UnitOfWork {
  constructor(
    private readonly dataSource: DataSource,
    private readonly cls: ClsService,
  ) { super(); }

  run<T>(fn: () => Promise<T>): Promise<T> {
    // REQUIRED propagation: if a UoW is already active (nested uow.run), join
    // it — run the callback in the SAME transaction rather than opening a
    // second, independent one. Without this, a nested run() would commit/roll
    // back on its own boundary and the two writes wouldn't be atomic.
    const existing = this.cls.get<EntityManager>(TYPEORM_EM_KEY);
    if (existing) {
      return fn();
    }

    // No active UoW → open a fresh transaction and publish its scoped EM.
    // DataSource.transaction opens the tx and supplies the scoped EM.
    // cls.run nests a CLS frame inside the tx so this.em() in repos sees it.
    return this.dataSource.transaction(async (em) =>
      this.cls.run(async () => {
        this.cls.set(TYPEORM_EM_KEY, em);
        return fn();
      }),
    );
  }
}
```

> **CLS scope:** the request's outer CLS frame (request_id, userId from `ClsModule.forRoot({ middleware: ... })`) propagates *into* `cls.run(...)` automatically — `nestjs-cls` runs nested frames as children of the active store. The new frame just adds the scoped `EntityManager` on top.

## Outbound: Outbox via UoW

The outbox row must commit atomically with the aggregate write. With UoW, the service composes both — no special repository shape needed.

```typescript
// src/domain/shared/events.ts — plain data, no infra deps
export interface DomainEvent {
  readonly aggregateType: string;
  readonly aggregateId: string;
  readonly eventType: string;
  readonly payload: Record<string, unknown>;
}
```

```typescript
// src/domain/shared/outbox.ts — port
import type { DomainEvent } from "./events";

export abstract class OutboxRepository {
  abstract enqueue(events: readonly DomainEvent[]): Promise<void>;
}
```

```typescript
// src/outbound/typeorm/tracing.ts
//
// Format the active OTel span as a W3C `traceparent` header so the outbox
// row carries the originating request's trace context. Returns null if no
// span is active (test runs, scheduled jobs without auto-instrumentation).
import { trace } from "@opentelemetry/api";

export function currentTraceparent(): string | null {
  const ctx = trace.getActiveSpan()?.spanContext();
  if (!ctx) return null;
  const flags = ctx.traceFlags.toString(16).padStart(2, "0");
  return `00-${ctx.traceId}-${ctx.spanId}-${flags}`;
}
```

```typescript
// src/outbound/typeorm/typeorm-outbox.repository.ts
import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { ClsService } from "nestjs-cls";
import { EntityManager, Repository } from "typeorm";
import { OutboxEntity } from "./entities/outbox.entity";
import { TYPEORM_EM_KEY } from "./typeorm-unit-of-work";
import { currentTraceparent } from "./tracing";
import { OutboxRepository } from "../../domain/shared/outbox";
import type { DomainEvent } from "../../domain/shared/events";

@Injectable()
export class TypeOrmOutboxRepository extends OutboxRepository {
  constructor(
    @InjectRepository(OutboxEntity)
    private readonly repo: Repository<OutboxEntity>,
    private readonly cls: ClsService,
  ) { super(); }

  private em(): EntityManager {
    return this.cls.get<EntityManager>(TYPEORM_EM_KEY) ?? this.repo.manager;
  }

  async enqueue(events: readonly DomainEvent[]): Promise<void> {
    if (events.length === 0) return;
    // Trace context captured at write time, not at relay time, so the
    // published event carries the originating request's trace.
    const traceparent = currentTraceparent();
    await this.em().save(
      OutboxEntity,
      events.map((e) => ({
        aggregateType: e.aggregateType,
        aggregateId: e.aggregateId,
        eventType: e.eventType,
        payload: e.payload,
        traceparent,
        publishedAt: null,
      })),
    );
  }
}
```

```typescript
// Application service — composes aggregate write + outbox enqueue inside one UoW.
async createAuthor(req: CreateAuthorRequest): Promise<Author> {
  try {
    const author = await this.uow.run(async () => {
      const saved = await this.authorRepo.createAuthor(req);
      await this.outbox.enqueue([{
        aggregateType: "author",
        aggregateId: saved.id,
        eventType: "AuthorCreated",
        payload: { name: saved.name.value },
      }]);
      return saved;
    });
    await this.metrics.recordCreationSuccess();
    return author;
  } catch (error) {
    await this.metrics.recordCreationFailure();
    if (error instanceof DomainError) throw error;
    throw new UnknownAuthorError(error);
  }
}
```

**Outbox relay**: the most idiomatic NestJS approach is a `@Processor("outbox")` BullMQ worker scheduled by a `@Cron` task that reads `WHERE published_at IS NULL ORDER BY id LIMIT N`, publishes to the broker, then updates `published_at`. Keep the relay in its own module so it can be deployed as a separate process if traffic grows.

### Cross-aggregate orchestration (general UoW pattern)

The same primitive composes any cross-repo flow:

```typescript
// Transfer post ownership between authors — three writes, one transaction.
async transferPost(from: AuthorId, to: AuthorId, postId: PostId): Promise<void> {
  await this.uow.run(async () => {
    await this.authorRepo.releasePost(from, postId);
    await this.authorRepo.acquirePost(to, postId);
    await this.postRepo.reassign(postId, to);
    // If any of the three throws, all three roll back together.
  });
}
```

### Alternative: `@Transactional` decorator (typeorm-transactional)

If your codebase is already invested in `typeorm-transactional`, its `@Transactional()` decorator gives you the same atomicity guarantee with less per-call-site wiring. It uses AsyncLocalStorage under the hood, just like UoW.

```typescript
// Same effect as uow.run(...) but the boundary is in the decorator,
// not visible at the call site.
@Injectable()
export class AuthorServiceImpl extends AuthorService {
  @Transactional()
  async createAuthor(req: CreateAuthorRequest): Promise<Author> {
    const author = await this.authorRepo.createAuthor(req);
    await this.outbox.enqueue([...]);
    return author;
  }
}
```

**Trade-offs to accept if you pick `@Transactional`:**
- Tx boundary moves into decorator metadata — less visible at the call site
- Third-party library — historically uneven maintenance, currently stable
- Requires `initializeTransactionalContext()` at startup before any DB ops
- Bootstrap test setup must opt into the lib's CLS wrapper

**When it's a good choice:** existing codebase already uses it; team prefers the brevity; you accept the maintenance risk.

**Pick one pattern and stick to it** — mixing `uow.run(...)` and `@Transactional()` in the same codebase is a debugging nightmare. Both produce the same end state; consistency is what matters.

### Common gotchas (cross-repo tx)

- **Don't** open a fresh `manager.transaction(...)` inside a repo method called from `uow.run()`. You'll get a *nested* tx (SAVEPOINT in Postgres), not the outer one. Repos must always go through `this.em()`.
- **Don't** make `OutboxRepository` start its own transaction. The whole point of UoW is shared scope.
- **Don't** rely on TypeORM lifecycle hooks (`@AfterInsert`) to publish events — they fire per row, not per tx, and have no tx context.
- **Don't** inject `Repository<X>` directly into a service. Always go through a domain port — `Repository<X>` skips the CLS-aware `em()` and silently writes outside any active UoW.

---

## Outbound: Idempotency Store

A KV-shaped table keyed by `(scope, key)` with a unique constraint. Wrap the use case via an interceptor or directly in the application service.

```typescript
// src/domain/shared/idempotency.ts
export type Acquire =
  | { tag: "new" }
  | { tag: "replay"; response: Buffer }
  | { tag: "conflict" }   // same key, different request hash
  | { tag: "in_flight" }; // same key, first request still executing — 409 (retry later), never re-run

export abstract class IdempotencyStore {
  abstract acquire(
    scope: string,
    key: string,
    requestHash: string,
  ): Promise<Acquire>;
  abstract store(
    scope: string,
    key: string,
    response: Buffer,
  ): Promise<void>;
}
```

```typescript
// src/outbound/typeorm/postgres-idempotency.ts
//
// Like other repos in this codebase, the store reads the active EntityManager
// from CLS — so if the idempotency check is part of a `uow.run(...)` it
// participates in the same tx. Most apps run it outside any UoW; both work.
@Injectable()
export class PostgresIdempotencyStore extends IdempotencyStore {
  constructor(
    @InjectRepository(IdempotencyEntity)
    private readonly repo: Repository<IdempotencyEntity>,
    private readonly cls: ClsService,
  ) { super(); }

  private em(): EntityManager {
    return this.cls.get<EntityManager>(TYPEORM_EM_KEY) ?? this.repo.manager;
  }

  async acquire(scope: string, key: string, hash: string): Promise<Acquire> {
    // Insert-or-fetch — unique (scope, key) collapses races to one winner.
    const result = await this.em()
      .createQueryBuilder()
      .insert()
      .into(IdempotencyEntity)
      .values({ scope, key, requestHash: hash })
      .orIgnore()
      .returning("scope")
      .execute();

    if (result.identifiers.length === 1) return { tag: "new" };

    const row = await this.em().findOneByOrFail(IdempotencyEntity, { scope, key });
    if (row.requestHash !== hash) return { tag: "conflict" };
    // No stored response yet = the first request is still running. Returning
    // "new" here would double-execute (double charge).
    return row.response
      ? { tag: "replay", response: row.response }
      : { tag: "in_flight" };
  }
  // store(...) updates the row with the response bytes via this.em().update(...)
}
```

Wire as a NestJS interceptor that checks the `Idempotency-Key` header before invoking the controller — keeps the controller body free of replay logic.

### Inbound: Idempotency Interceptor

```typescript
// src/inbound/http/interceptors/idempotency.interceptor.ts
//
// Replay-safe POST/PATCH semantics for clients that retry on transient errors.
// Flow:
//   1. No Idempotency-Key header → skip (lookup-free fast path).
//   2. Acquire (scope, key, request-hash) on the store.
//        "replay"   → respond with the cached body, same status code.
//        "conflict"  → 409 — same key, different request body.
//        "in_flight" → 409 — same key, first request still running; client retries later.
//        "new"       → run the handler, then store the serialised response.
//
// Apply selectively (controller- or route-scoped) — not globally. GET should
// not pay the round-trip; non-mutating endpoints don't need replay protection.
import {
  CallHandler, ExecutionContext, Injectable, NestInterceptor, ConflictException,
} from "@nestjs/common";
import { createHash } from "node:crypto";
import { Observable, concatMap, from, of, switchMap } from "rxjs";
import type { Request, Response } from "express";
import { IdempotencyStore } from "../../../domain/shared/idempotency";

// Headers worth replaying on a cached response. Location (created resource)
// and Content-Type matter; skip hop-by-hop / per-connection headers.
const REPLAYABLE_HEADERS = ["location", "content-type"] as const;

interface StoredResponse {
  status: number;
  body: unknown;
  headers: Record<string, string>;
}

@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(private readonly store: IdempotencyStore) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<Request>();
    const res = context.switchToHttp().getResponse<Response>();
    const key = req.header("idempotency-key");
    if (!key) return next.handle();

    // Scope from controller + handler, NOT req.route?.path — the latter is
    // often undefined under Express 5 inside a Nest interceptor. The class +
    // method name is stable and unique per endpoint.
    const scope = `${context.getClass().name}.${context.getHandler().name}`;
    const hash = createHash("sha256")
      .update(JSON.stringify(req.body ?? null))
      .digest("hex");

    return from(this.store.acquire(scope, key, hash)).pipe(
      switchMap((outcome) => {
        if (outcome.tag === "conflict") {
          throw new ConflictException({
            type: "https://api.example.com/errors/idempotency-conflict",
            title: "Idempotency Conflict",
            status: 409,
            detail: "Idempotency-Key already used with a different request body",
          });
        }
        if (outcome.tag === "in_flight") {
          throw new ConflictException({
            type: "https://api.example.com/errors/idempotency-in-flight",
            title: "Request In Progress",
            status: 409,
            detail: "A request with this Idempotency-Key is still being processed; retry later",
          });
        }
        if (outcome.tag === "replay") {
          // Replay path — short-circuit the handler, return the cached body
          // verbatim. Stored body includes status, headers + serialised JSON.
          const cached = JSON.parse(outcome.response.toString("utf8")) as StoredResponse;
          res.status(cached.status);
          for (const [name, value] of Object.entries(cached.headers)) {
            res.header(name, value);
          }
          return of(cached.body);
        }
        // "new" — run the handler, then persist the response for future replays.
        // concatMap (not tap(async ...)) so the store write is AWAITED before
        // the response flushes and any rejection propagates to the client
        // instead of being swallowed by a floating promise.
        return next.handle().pipe(
          concatMap(async (body) => {
            const headers: Record<string, string> = {};
            for (const name of REPLAYABLE_HEADERS) {
              const value = res.getHeader(name);
              if (typeof value === "string") headers[name] = value;
            }
            const serialised = Buffer.from(
              JSON.stringify({ status: res.statusCode, body, headers } satisfies StoredResponse),
            );
            await this.store.store(scope, key, serialised);
            return body;
          }),
        );
      }),
    );
  }
}
```

Apply at the controller (`@UseInterceptors(IdempotencyInterceptor)`) or per route. Combine with a unique `(scope, key)` constraint in the store — that's what collapses concurrent retries to a single winner.

---

## Inbound: Rate Limiting (`@nestjs/throttler`)

Wire `ThrottlerModule` in `AppModule` and register `ThrottlerGuard` as a global `APP_GUARD`. Per-route overrides via `@Throttle({ default: { limit: 5, ttl: 60_000 } })` or `@SkipThrottle()` for public reads.

```typescript
// In app.module.ts (see examples-bootstrap.md for the full module)
import { ThrottlerModule, ThrottlerGuard } from "@nestjs/throttler";
import { APP_GUARD } from "@nestjs/core";

@Module({
  imports: [
    ThrottlerModule.forRoot([
      // Default: 100 req/min per IP. Tune per route via @Throttle().
      { name: "default", ttl: 60_000, limit: 100 },
    ]),
    // ... other imports
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // ... other providers
  ],
})
export class AppModule {}
```

> **429 must be `application/problem+json` too.** `ThrottlerException`'s default
> body is `{ statusCode, message }`, which breaks the error contract. The
> `DomainExceptionFilter` above already has a `ThrottlerException` branch that
> re-maps it to a problem document — so as long as the global filter is
> registered (it catches everything via `@Catch()`), the 429 is uniform with the
> rest of the API. The throttler still sets `Retry-After` / `X-RateLimit-*`
> headers itself. (Alternative: subclass `ThrottlerGuard` and override
> `throwThrottlingException()` to throw a problem-shaped exception — the filter
> branch is the lower-friction path and keeps all error shaping in one place.)

For Redis-backed limits (multi-instance), swap the storage with `@nest-lab/throttler-storage-redis`.

---

## Outbound: Tracer Port (OTel)

Don't import `@opentelemetry/*` into the domain. Define an abstract class (NestJS DI token); the OTel adapter extends it. Tests bind a no-op or capturing implementation.

```typescript
// src/domain/shared/tracing.ts
export interface Span {
  addEvent(name: string, attrs?: Record<string, string>): void;
  recordError(err: unknown): void;
  end(): void;
}
export abstract class Tracer {
  abstract startSpan(name: string, attrs?: Record<string, string>): Span;
}
```

The OTel adapter (`src/outbound/otel/otel-tracer.ts`) extends `Tracer` and wraps `@opentelemetry/api`. Bind it in the infra module:

```typescript
@Module({
  providers: [{ provide: Tracer, useClass: OtelTracer }],
  exports: [Tracer],
})
export class ObservabilityModule {}
```

This makes vendor swap a one-file change and lets tests run with a no-op `Tracer` provider. NestJS's auto-instrumentation packages still apply at the framework boundary (HTTP, TypeORM); the port is for *application-level* spans the domain wants to emit.

For sampling, cardinality budgets, and span attribute conventions, see `software-architecture/references/observability.md`.
