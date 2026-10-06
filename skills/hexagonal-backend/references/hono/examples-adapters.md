# Examples: Adapters

Inbound (createApp, handlers, task handlers, auth, errors) and outbound (Drizzle, SQLite, mapper).

## Table of Contents

1. [Outbound: Drizzle Schema + Mapper](#outbound-drizzle-schema--mapper)
2. [Outbound: Cursor Helpers (composite + base64)](#outbound-cursor-helpers-composite--base64)
3. [Outbound: Drizzle Adapter (ORM + mapper)](#outbound-drizzle-adapter-orm--mapper)
4. [Outbound: Drizzle Postgres Adapter with Transactions](#outbound-drizzle-postgres-adapter-with-transactions)
5. [Outbound: Raw SQL Adapter (no ORM)](#outbound-raw-sql-adapter-no-orm)
6. [Inbound: createApp (wraps Hono)](#inbound-createapp-wraps-hono)
7. [Inbound: DI Middleware](#inbound-di-middleware)
8. [Inbound: Auth Middleware](#inbound-auth-middleware)
9. [Inbound: Request / Response Schemas](#inbound-request--response-schemas)
10. [Inbound: Handlers (Routes with OpenAPI)](#inbound-handlers-routes-with-openapi)
11. [Inbound: API Error Handler (RFC 9457)](#inbound-api-error-handler-rfc-9457)
12. [Inbound: Response Helpers](#inbound-response-helpers)
13. [Inbound: Healthcheck](#inbound-healthcheck)
14. [Inbound: Task Handler (non-HTTP inbound adapter)](#inbound-task-handler-non-http-inbound-adapter)
15. [Outbound: Outbox Adapter (transactional, Drizzle)](#outbound-outbox-adapter-transactional-drizzle)
16. [Outbound: Idempotency Store](#outbound-idempotency-store)
17. [Outbound: Tracer Port (OTel)](#outbound-tracer-port-otel)

---

## Outbound: Drizzle Schema + Mapper

```typescript
// src/outbound/drizzle/schema.ts
import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";

/**
 * Drizzle table definition — outbound only. Never import in domain.
 * createdAt is required by composite cursor pagination — index on (created_at, id).
 */
export const authors = sqliteTable("authors", {
  id: text("id").primaryKey(),
  name: text("name").notNull().unique(),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .default(sql`(unixepoch())`),
});

// For Postgres, use pgTable from drizzle-orm/pg-core:
// import { pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
// export const authors = pgTable("authors", {
//   id: uuid("id").primaryKey().defaultRandom(),
//   name: text("name").notNull().unique(),
//   createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
// });
```

```typescript
// src/outbound/drizzle/mapper.ts
import { AuthorName } from "../../domain/authors/models";
import type { Author } from "../../domain/authors/models";

type AuthorRow = { id: string; name: string; createdAt: Date };

/**
 * DB row <-> domain translation. Keeps domain free from Drizzle.
 * Note: domain Author intentionally omits createdAt — adapters carry it for pagination.
 */
export class AuthorMapper {
  static toDomain(row: AuthorRow): Author {
    return {
      id: row.id,
      name: AuthorName.create(row.name),
    };
  }

  static toRow(author: Author): { id: string; name: string } {
    return {
      id: author.id,
      name: author.name.value,
    };
  }
}
```

## Outbound: Cursor Helpers (composite + base64)

```typescript
// src/outbound/cursor.ts
// Composite cursor (createdAt, id) encoded as opaque base64.
// Single-column `id > X` cursors skip/duplicate rows under concurrent inserts;
// composite (createdAt, id) is stable.

// Runtime-agnostic base64url — works in Node, Bun, Deno, and Cloudflare Workers.
function base64UrlEncode(raw: string): string {
  if (typeof Buffer !== "undefined") return Buffer.from(raw).toString("base64url");
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlDecode(raw: string): string {
  if (typeof Buffer !== "undefined") return Buffer.from(raw, "base64url").toString("utf8");
  const padded = raw.replace(/-/g, "+").replace(/_/g, "/");
  return atob(padded + "===".slice(0, (4 - (padded.length % 4)) % 4));
}

export function encodeCursor(createdAt: Date, id: string): string {
  return base64UrlEncode(`${createdAt.toISOString()}|${id}`);
}

export function decodeCursor(raw: string): { createdAt: Date; id: string } {
  const [ts, id] = base64UrlDecode(raw).split("|", 2);
  return { createdAt: new Date(ts), id };
}
```

## Outbound: Drizzle Adapter (ORM + mapper)

```typescript
// src/outbound/drizzle/repository.ts
import { and, asc, eq, gt, or } from "drizzle-orm";
import type { BaseSQLiteDatabase } from "drizzle-orm/sqlite-core";
import { authors } from "./schema";
import { AuthorMapper } from "./mapper";
import { decodeCursor, encodeCursor } from "../cursor";
import {
  DuplicateAuthorError,
  UnknownAuthorError,
} from "../../domain/authors/errors";
import type {
  Author,
  CreateAuthorRequest,
  CursorPage,
} from "../../domain/authors/models";
import type { AuthorRepository } from "../../domain/authors/ports";

/**
 * Type against the SQLite base, not a concrete driver — `BunSQLiteDatabase`
 * (sync, Bun) and `DrizzleD1Database` (async, Cloudflare D1) are both
 * `BaseSQLiteDatabase`, so one adapter spans both runtimes. The query builder
 * is identical; only the driver differs. `'async'` covers D1's promise-based
 * results (Bun-SQLite's sync results satisfy it too).
 *
 * Postgres uses a SEPARATE adapter (`PostgresAuthorRepository`) — its query
 * builder and base type (`PgDatabase`) differ, so one class does NOT span every
 * runtime. If you only ever target Postgres, type this against `PgDatabase`.
 */
type SQLiteClient = BaseSQLiteDatabase<"async" | "sync", unknown>;

/**
 * Transactions encapsulated here — invisible to callers.
 */
export class DrizzleAuthorRepository implements AuthorRepository {
  constructor(private readonly db: SQLiteClient) {}

  static fromClient(db: SQLiteClient): DrizzleAuthorRepository {
    return new DrizzleAuthorRepository(db);
  }

  async createAuthor(req: CreateAuthorRequest): Promise<Author> {
    const id = crypto.randomUUID();
    try {
      await this.db.insert(authors).values({
        id,
        name: req.name.value,
      });
    } catch (error) {
      if (this.isUniqueConstraintError(error)) {
        throw new DuplicateAuthorError(req.name.value);
      }
      throw new UnknownAuthorError(error);
    }
    return { id, name: req.name };
  }

  async findAuthor(authorId: string): Promise<Author | null> {
    const rows = await this.db
      .select()
      .from(authors)
      .where(eq(authors.id, authorId));
    if (rows.length === 0) return null;
    return AuthorMapper.toDomain(rows[0]);
  }

  async listAuthors(
    cursor: string | null,
    limit: number,
  ): Promise<CursorPage<Author>> {
    // Fetch limit+1 to detect whether more rows exist beyond the boundary.
    const fetchLimit = limit + 1;

    // Drizzle has no native tuple-comparison operator — emulate
    // (createdAt, id) > (cursorAt, cursorId) via OR + AND.
    const rows = cursor
      ? await (() => {
          const { createdAt, id } = decodeCursor(cursor);
          return this.db
            .select()
            .from(authors)
            .where(
              or(
                gt(authors.createdAt, createdAt),
                and(eq(authors.createdAt, createdAt), gt(authors.id, id)),
              ),
            )
            .orderBy(asc(authors.createdAt), asc(authors.id))
            .limit(fetchLimit);
        })()
      : await this.db
          .select()
          .from(authors)
          .orderBy(asc(authors.createdAt), asc(authors.id))
          .limit(fetchLimit);

    // Drop overflow row; cursor points at the LAST RETURNED row so the
    // next page resumes AFTER it (no duplicates, no skips).
    const hasMore = rows.length > limit;
    const pageRows = rows.slice(0, limit);
    const items = pageRows.map(AuthorMapper.toDomain);
    const last = pageRows[pageRows.length - 1];
    const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

    return { items, nextCursor, hasMore };
  }

  private isUniqueConstraintError(error: unknown): boolean {
    // drizzle-orm >= 0.44 wraps driver errors in DrizzleQueryError
    // ("Failed query: ..."); the driver's own error is on `.cause`.
    const e = error instanceof Error && error.cause instanceof Error ? error.cause : error;
    if (e instanceof Error) {
      // SQLite: UNIQUE constraint failed
      // Postgres: SQLSTATE 23505 on the driver error's `code` (not in the message)
      return (
        e.message.includes("UNIQUE constraint failed") ||
        (e as { code?: string }).code === "23505"
      );
    }
    return false;
  }
}
```

## Outbound: Drizzle Postgres Adapter with Transactions

```typescript
// src/outbound/drizzle/postgres-repository.ts
import { and, asc, eq, gt, or } from "drizzle-orm";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import { authors } from "./schema";
import { AuthorMapper } from "./mapper";
import { decodeCursor, encodeCursor } from "../cursor";
import {
  DuplicateAuthorError,
  UnknownAuthorError,
} from "../../domain/authors/errors";
import type {
  Author,
  CreateAuthorRequest,
  CursorPage,
} from "../../domain/authors/models";
import type { AuthorRepository } from "../../domain/authors/ports";

export class PostgresAuthorRepository implements AuthorRepository {
  constructor(private readonly db: NodePgDatabase) {}

  static fromClient(db: NodePgDatabase): PostgresAuthorRepository {
    return new PostgresAuthorRepository(db);
  }

  async createAuthor(req: CreateAuthorRequest): Promise<Author> {
    const id = crypto.randomUUID();
    try {
      // Transaction scoped to adapter — domain doesn't know
      await this.db.transaction(async (tx) => {
        await tx.insert(authors).values({
          id,
          name: req.name.value,
        });
      });
    } catch (error) {
      if (this.isUniqueConstraintError(error)) {
        throw new DuplicateAuthorError(req.name.value);
      }
      throw new UnknownAuthorError(error);
    }
    return { id, name: req.name };
  }

  async findAuthor(authorId: string): Promise<Author | null> {
    const rows = await this.db
      .select()
      .from(authors)
      .where(eq(authors.id, authorId));
    if (rows.length === 0) return null;
    return AuthorMapper.toDomain(rows[0]);
  }

  async listAuthors(
    cursor: string | null,
    limit: number,
  ): Promise<CursorPage<Author>> {
    const fetchLimit = limit + 1;

    const rows = cursor
      ? await (() => {
          const { createdAt, id } = decodeCursor(cursor);
          return this.db
            .select()
            .from(authors)
            .where(
              or(
                gt(authors.createdAt, createdAt),
                and(eq(authors.createdAt, createdAt), gt(authors.id, id)),
              ),
            )
            .orderBy(asc(authors.createdAt), asc(authors.id))
            .limit(fetchLimit);
        })()
      : await this.db
          .select()
          .from(authors)
          .orderBy(asc(authors.createdAt), asc(authors.id))
          .limit(fetchLimit);

    const hasMore = rows.length > limit;
    const pageRows = rows.slice(0, limit);
    const items = pageRows.map(AuthorMapper.toDomain);
    const last = pageRows[pageRows.length - 1];
    const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

    return { items, nextCursor, hasMore };
  }

  private isUniqueConstraintError(error: unknown): boolean {
    // drizzle-orm >= 0.44 wraps driver errors in DrizzleQueryError; node-postgres
    // puts SQLSTATE 23505 on the driver error's `code` (on `.cause`), not in the message.
    const e = error instanceof Error && error.cause instanceof Error ? error.cause : error;
    return (e as { code?: string } | null)?.code === "23505";
  }
}
```

## Outbound: Raw SQL Adapter (no ORM)

```typescript
// src/outbound/sqlite/repository.ts
import { Database } from "bun:sqlite";
import { AuthorName } from "../../domain/authors/models";
import type {
  Author,
  CreateAuthorRequest,
  CursorPage,
} from "../../domain/authors/models";
import type { AuthorRepository } from "../../domain/authors/ports";
import {
  DuplicateAuthorError,
  UnknownAuthorError,
} from "../../domain/authors/errors";
import { decodeCursor, encodeCursor } from "../cursor";

type AuthorRow = { id: string; name: string; created_at: number };

/**
 * Raw SQL — demonstrates that adapters choose their own data access strategy.
 * SQLite stores timestamps as unix epoch integers (seconds).
 */
export class SqliteAuthorRepository implements AuthorRepository {
  constructor(private readonly db: Database) {}

  static fromClient(db: Database): SqliteAuthorRepository {
    return new SqliteAuthorRepository(db);
  }

  async createAuthor(req: CreateAuthorRequest): Promise<Author> {
    const id = crypto.randomUUID();
    try {
      // created_at uses DEFAULT (unixepoch()) declared in schema.
      this.db
        .prepare("INSERT INTO authors (id, name) VALUES (?, ?)")
        .run(id, req.name.value);
    } catch (error) {
      if (
        error instanceof Error &&
        error.message.includes("UNIQUE constraint failed")
      ) {
        throw new DuplicateAuthorError(req.name.value);
      }
      throw new UnknownAuthorError(error);
    }
    return { id, name: req.name };
  }

  async findAuthor(authorId: string): Promise<Author | null> {
    const row = this.db
      .prepare("SELECT id, name, created_at FROM authors WHERE id = ?")
      .get(authorId) as AuthorRow | null;
    if (!row) return null;
    return { id: row.id, name: AuthorName.create(row.name) };
  }

  async listAuthors(
    cursor: string | null,
    limit: number,
  ): Promise<CursorPage<Author>> {
    const fetchLimit = limit + 1;
    const rows = (cursor
      ? (() => {
          const { createdAt, id } = decodeCursor(cursor);
          // Composite (created_at, id) tuple comparison via SQLite row-value syntax.
          return this.db
            .prepare(
              "SELECT id, name, created_at FROM authors " +
                "WHERE (created_at, id) > (?, ?) " +
                "ORDER BY created_at ASC, id ASC LIMIT ?",
            )
            .all(Math.floor(createdAt.getTime() / 1000), id, fetchLimit);
        })()
      : this.db
          .prepare(
            "SELECT id, name, created_at FROM authors ORDER BY created_at ASC, id ASC LIMIT ?",
          )
          .all(fetchLimit)) as AuthorRow[];

    const hasMore = rows.length > limit;
    const pageRows = rows.slice(0, limit);
    const items = pageRows.map((r) => ({
      id: r.id,
      name: AuthorName.create(r.name),
    }));
    const last = pageRows[pageRows.length - 1];
    const nextCursor = hasMore && last
      ? encodeCursor(new Date(last.created_at * 1000), last.id)
      : null;

    return { items, nextCursor, hasMore };
  }
}
```

---

## Inbound: createApp (wraps Hono)

```typescript
// src/inbound/http/app.ts
import { OpenAPIHono } from "@hono/zod-openapi";
import { swaggerUI } from "@hono/swagger-ui";
import { cors } from "hono/cors";
import { secureHeaders } from "hono/secure-headers";
import { logger } from "hono/logger";
import { requestId } from "hono/request-id";

import type { AuthorService } from "../../domain/authors/ports";
import { authorRoutes } from "./authors/routes";
import { problem, problemHeaders, registerErrorHandler } from "./errors";
import { withFieldErrorsFrom } from "./problem";
import { healthRoutes, type HealthPing } from "./health";
import { injectServices } from "./middleware";

/**
 * App-wide type for context variables.
 * Handlers access services via c.var.authorService — fully typed.
 * requestId() populates c.var.requestId (typed via hono/request-id's RequestIdVariables).
 */
export type AppEnv = {
  Variables: {
    authorService: AuthorService;
    requestId: string;
  };
};

export type AppContext = OpenAPIHono<AppEnv>;

/** Subset of config the inbound layer needs. Keeps server.ts free of Hono types. */
export type AppHttpConfig = {
  corsOrigins: string[];
};

export type AppDeps = {
  authorService: AuthorService;
  /** HTTP-relevant config (CORS origins, etc.) — driven from loadConfig(). */
  config: AppHttpConfig;
  /** Readiness ping — typically `() => db.execute(sql`SELECT 1`)`. */
  healthPing: HealthPing;
};

/**
 * Creates the Hono app. Bootstrap (server.ts) never imports Hono/OpenAPIHono.
 *
 * NOTE: for OpenAPIHono the shared validation hook is the constructor
 * `defaultHook` (set it on every OpenAPIHono instance — sub-apps mounted with
 * app.route() don't inherit it). `app.openapi(route, handler, hook)` also takes
 * an optional per-route hook that overrides `defaultHook`. The hook converts
 * every failed Zod validation into an RFC 9457 problem document so validation
 * errors share the same content type/shape as domain errors.
 */
export function createApp(deps: AppDeps): OpenAPIHono<AppEnv> {
  const app = new OpenAPIHono<AppEnv>({
    defaultHook: (result, c) => {
      if (!result.success) {
        return c.json(
          problem(
            "validation-error",
            "Unprocessable Entity",
            422,
            "Request validation failed",
            { instance: c.req.path, ...withFieldErrorsFrom(result.error) },
          ),
          422,
          problemHeaders(),
        );
      }
    },
  });

  // Request id first — every downstream log line + the response echo the same id.
  app.use("*", requestId());

  // Health endpoints BEFORE auth/DI middleware: a global requireAuth must not
  // 401 the liveness/readiness probes, and they need no services.
  app.route("/", healthRoutes(deps.healthPing));

  // Global middleware — order matters: CORS must come first.
  // Origins are config-driven (no hardcoded localhost).
  app.use("*", cors({ origin: deps.config.corsOrigins }));
  app.use("*", secureHeaders());
  app.use("*", logger());

  // DI middleware — sets services on context for all downstream handlers
  app.use("*", injectServices(deps.authorService));

  // Bearer security scheme — registered once, attached to protected routes.
  app.openAPIRegistry.registerComponent("securitySchemes", "bearerAuth", {
    type: "http",
    scheme: "bearer",
    bearerFormat: "JWT",
  });

  // Domain routes — generates OpenAPI from createRoute() definitions
  app.route("/v1/authors", authorRoutes());

  // OpenAPI document + Swagger UI. doc31 emits OAS 3.1 — nullable schemas are
  // lossless (`type: ["string","null"]`) instead of the 3.0 `nullable: true` hack.
  app.doc31("/openapi.json", {
    openapi: "3.1.0",
    info: { title: "Authors API", version: "1.0.0" },
  });
  app.get("/docs", swaggerUI({ url: "/openapi.json" }));

  // Error handler — runs after routes
  registerErrorHandler(app);

  return app;
}

/**
 * For tests: same app, no server binding. Pass a stub ping that always resolves.
 */
export function createTestApp(deps: AppDeps): OpenAPIHono<AppEnv> {
  return createApp(deps);
}
```

The `withFieldErrorsFrom` helper turns a `ZodError` into the RFC 9457
`errors[]` extension member. Keep it next to `problem()`:

```typescript
// src/inbound/http/problem.ts
import type { ZodError } from "@hono/zod-openapi";

/** RFC 9457 `errors[]` extension member, populated from a Zod failure. */
export function withFieldErrorsFrom(error: ZodError): {
  errors: { field: string; code: string; message: string }[];
} {
  return {
    errors: error.issues.map((issue) => ({
      field: issue.path.join(".") || "(root)",
      code: issue.code,
      message: issue.message,
    })),
  };
}
```

## Inbound: DI Middleware

```typescript
// src/inbound/http/middleware.ts
import { createMiddleware } from "hono/factory";
import type { AuthorService } from "../../domain/authors/ports";
import type { AppEnv } from "./app";

/**
 * Sets services on context variables for downstream handlers.
 * Type-safe: c.var.authorService is typed via AppEnv.
 */
export function injectServices(authorService: AuthorService) {
  return createMiddleware<AppEnv>(async (c, next) => {
    c.set("authorService", authorService);
    await next();
  });
}
```

## Inbound: Auth Middleware

```typescript
// src/inbound/http/auth.ts
/**
 * Auth lives entirely in the inbound layer. Domain never handles tokens.
 */
import { createMiddleware } from "hono/factory";
import { HTTPException } from "hono/http-exception";
import { verify } from "hono/jwt";

import type { AppEnv } from "./app";

type AuthEnv = AppEnv & {
  Variables: AppEnv["Variables"] & {
    userId: string;
  };
};

export function requireAuth(secret: string) {
  return createMiddleware<AuthEnv>(async (c, next) => {
    const authHeader = c.req.header("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      throw new HTTPException(401, { message: "Missing token" });
    }

    const token = authHeader.slice(7);
    let payload: Awaited<ReturnType<typeof verify>>;
    try {
      // The algorithm argument is required by hono/jwt `verify` (hono 4.13+) —
      // pin it explicitly; never let the token header pick the algorithm.
      // HS256 = single-service fallback; use ES256/EdDSA when several services verify.
      payload = await verify(token, secret, "HS256");
    } catch {
      throw new HTTPException(401, { message: "Invalid token" });
    }

    // `sub` is `string | undefined` on the JWT payload — guard, don't cast.
    if (typeof payload.sub !== "string") {
      throw new HTTPException(401, { message: "Invalid token" });
    }
    c.set("userId", payload.sub);

    await next();
  });
}
```

## Inbound: Request / Response Schemas

```typescript
// src/inbound/http/authors/request.ts
// `z` from @hono/zod-openapi is the same Zod with .openapi() metadata extension.
import { z } from "@hono/zod-openapi";
import { AuthorName, type CreateAuthorRequest } from "../../../domain/authors/models";

/**
 * Zod schema for HTTP request body — decoupled from domain.
 * Validates shape at transport boundary. Domain validates business rules.
 */
export const createAuthorBodySchema = z.object({
  name: z.string().min(1, "name is required"),
});

export type CreateAuthorBody = z.infer<typeof createAuthorBodySchema>;

/**
 * Convert validated HTTP body into domain type.
 * AuthorName.create() enforces domain invariants (trimming, non-empty).
 */
export function toDomain(body: CreateAuthorBody): CreateAuthorRequest {
  return { name: AuthorName.create(body.name) };
}

/**
 * Pagination query params schema — maps to domain pagination.
 */
export const paginationSchema = z.object({
  cursor: z.string().nullish().transform(v => v ?? null),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});
```

```typescript
// src/inbound/http/authors/response.ts
import type { Author } from "../../../domain/authors/models";

/**
 * Public API representation — never expose domain models directly.
 */
export interface AuthorResponse {
  id: string;
  name: string;
}

export function fromDomain(author: Author): AuthorResponse {
  return {
    id: author.id,
    name: author.name.value,
  };
}
```

## Inbound: Handlers (Routes with OpenAPI)

Routes use `@hono/zod-openapi` (`OpenAPIHono` + `createRoute`) so the OpenAPI
spec is generated from the same schemas that validate requests — no
separate API spec to drift from the implementation.

```typescript
// src/inbound/http/authors/routes.ts
import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnv } from "../app";
import { problem, problemHeaders } from "../errors";
import { withFieldErrorsFrom } from "../problem";
import { AuthorNotFoundError } from "../../../domain/authors/errors";
import {
  createAuthorBodySchema,
  paginationSchema,
  toDomain,
} from "./request";
import { fromDomain } from "./response";

const AuthorSchema = z.object({
  id: z.string().openapi({ example: "f47ac10b-58cc-4372-a567-0e02b2c3d479" }),
  name: z.string().openapi({ example: "Ada Lovelace" }),
}).openapi("Author");

const AuthorResultSchema = z.object({ data: AuthorSchema }).openapi("AuthorResult");

// Collection: pagination nested under `meta`, with `limit` echoed back.
const AuthorPageSchema = z.object({
  data: z.array(AuthorSchema),
  meta: z.object({
    limit: z.number().int(),
    next_cursor: z.string().nullable(),
    has_more: z.boolean(),
  }),
}).openapi("AuthorPage");

// RFC 9457 problem document. `instance` stays in the body; the correlation id
// lives in the X-Request-Id response header (not the body). `errors[]` is the
// field-level validation extension member.
const ProblemSchema = z.object({
  type: z.string(),
  title: z.string(),
  status: z.number(),
  detail: z.string(),
  instance: z.string().optional(),
  errors: z.array(z.object({
    field: z.string(),
    code: z.string(),
    message: z.string(),
  })).optional(),
}).openapi("ProblemDetails");

// Ids are opaque server-generated UUIDs — constrain so a malformed id 400s at
// the boundary instead of reaching the service and returning a misleading 404.
const authorParams = z.object({
  id: z.uuid().openapi({ param: { name: "id", in: "path" } }),
});

const createAuthorRoute = createRoute({
  method: "post",
  path: "/",
  tags: ["authors"],
  security: [{ bearerAuth: [] }],
  request: {
    body: { content: { "application/json": { schema: createAuthorBodySchema } } },
  },
  responses: {
    201: {
      content: { "application/json": { schema: AuthorResultSchema } },
      description: "Created",
      headers: z.object({
        Location: z.string().openapi({ example: "/v1/authors/<id>" }),
      }),
    },
    400: { content: { "application/problem+json": { schema: ProblemSchema } }, description: "Malformed request" },
    409: { content: { "application/problem+json": { schema: ProblemSchema } }, description: "Duplicate" },
    422: { content: { "application/problem+json": { schema: ProblemSchema } }, description: "Validation failed" },
    500: { content: { "application/problem+json": { schema: ProblemSchema } }, description: "Internal error" },
  },
});

const listAuthorsRoute = createRoute({
  method: "get",
  path: "/",
  tags: ["authors"],
  security: [{ bearerAuth: [] }],
  request: { query: paginationSchema },
  responses: {
    200: { content: { "application/json": { schema: AuthorPageSchema } }, description: "Page of authors" },
  },
});

const getAuthorRoute = createRoute({
  method: "get",
  path: "/{id}",
  tags: ["authors"],
  security: [{ bearerAuth: [] }],
  request: { params: authorParams },
  responses: {
    200: { content: { "application/json": { schema: AuthorResultSchema } }, description: "Author" },
    404: { content: { "application/problem+json": { schema: ProblemSchema } }, description: "Not found" },
  },
});

export function authorRoutes() {
  // Per-feature instance also needs the defaultHook so its zValidator
  // failures become problem documents (the hook is per-instance, not inherited
  // from the parent app it is mounted on).
  const app = new OpenAPIHono<AppEnv>({
    defaultHook: (result, c) => {
      if (!result.success) {
        return c.json(
          problem(
            "validation-error",
            "Unprocessable Entity",
            422,
            "Request validation failed",
            { instance: c.req.path, ...withFieldErrorsFrom(result.error) },
          ),
          422,
          problemHeaders(),
        );
      }
    },
  });

  app.openapi(createAuthorRoute, async (c) => {
    const body = c.req.valid("json");
    const author = await c.var.authorService.createAuthor(toDomain(body));
    c.header("Location", `/v1/authors/${author.id}`);
    return c.json({ data: fromDomain(author) }, 201);
  });

  app.openapi(listAuthorsRoute, async (c) => {
    const { cursor, limit } = c.req.valid("query");
    const page = await c.var.authorService.listAuthors(cursor, limit);
    return c.json(
      {
        data: page.items.map(fromDomain),
        meta: {
          limit,
          next_cursor: page.nextCursor,
          has_more: page.hasMore,
        },
      },
      200,
    );
  });

  app.openapi(getAuthorRoute, async (c) => {
    const { id } = c.req.valid("param");
    const author = await c.var.authorService.findAuthor(id);
    if (!author) {
      // Throw a domain error; the central handler maps it to a 404 problem
      // document via the same problem() builder (no hand-built inline body).
      throw new AuthorNotFoundError(id);
    }
    return c.json({ data: fromDomain(author) }, 200);
  });

  return app;
}
```

## Inbound: API Error Handler (RFC 9457)

```typescript
// src/inbound/http/errors.ts
import type { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import {
  AuthorNameEmptyError,
  AuthorNotFoundError,
  DuplicateAuthorError,
  UnknownAuthorError,
} from "../../domain/authors/errors";
import type { AppEnv } from "./app";

export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail: string;
  /** Request-specific URI (RFC 9457). The correlation id is the X-Request-Id header, not here. */
  instance?: string;
  /** RFC 9457 extension member: field-level validation detail. */
  errors?: { field: string; code: string; message: string }[];
}

export function problem(
  typeSlug: string,
  title: string,
  status: number,
  detail: string,
  extra?: Partial<Pick<ProblemDetails, "instance" | "errors">>,
): ProblemDetails {
  return {
    type: `https://api.example.com/errors/${typeSlug}`,
    title,
    status,
    detail,
    ...extra,
  };
}

/** Every error body is application/problem+json (RFC 9457). */
export function problemHeaders(): { "content-type": string } {
  return { "content-type": "application/problem+json" };
}

export function registerErrorHandler(app: Hono<AppEnv>): void {
  app.onError((err, c) => {
    // Genuinely-thrown transport exceptions (e.g. auth middleware). Validation
    // failures never reach here — the OpenAPIHono defaultHook converts them to
    // problem documents before onError runs.
    if (err instanceof HTTPException) {
      // err.status is already ContentfulStatusCode; the import keeps the
      // annotation honest under strict mode.
      const status: ContentfulStatusCode = err.status;
      return c.json(
        problem("request-error", err.message || "Request Error", status, err.message, {
          instance: c.req.path,
        }),
        status,
        problemHeaders(),
      );
    }

    // Domain errors — match on tag for exhaustive handling
    if (err instanceof AuthorNotFoundError) {
      return c.json(
        problem("not-found", "Not Found", 404, err.message, { instance: c.req.path }),
        404,
        problemHeaders(),
      );
    }

    if (err instanceof DuplicateAuthorError) {
      return c.json(
        problem("duplicate-author", "Conflict", 409, err.message, { instance: c.req.path }),
        409,
        problemHeaders(),
      );
    }

    if (err instanceof AuthorNameEmptyError) {
      return c.json(
        problem("validation-error", "Unprocessable Entity", 422, err.message, {
          instance: c.req.path,
        }),
        422,
        problemHeaders(),
      );
    }

    if (err instanceof UnknownAuthorError) {
      console.error(`[${c.var.requestId}] Unexpected error:`, err.cause);
    } else {
      console.error(`[${c.var.requestId}] Unhandled error:`, err);
    }

    return c.json(
      problem("internal-error", "Internal Server Error", 500, "An unexpected error occurred", {
        instance: c.req.path,
      }),
      500,
      problemHeaders(),
    );
  });
}
```

## Inbound: Response Helpers

```typescript
// src/inbound/http/response.ts

/**
 * Standard response wrappers.
 * Use these types for documenting the API contract — not required at runtime
 * since Hono's c.json() handles serialization directly.
 */
export interface ApiSuccess<T> {
  data: T;
}

export interface CursorPageResponse<T> {
  data: T[];
  meta: {
    limit: number;
    next_cursor: string | null;
    has_more: boolean;
  };
}
```

## Inbound: Healthcheck

```typescript
// src/inbound/http/health.ts
/**
 * Healthcheck is infrastructure — not a domain concern.
 * Wire directly in createApp. The readiness probe takes a small
 * "ping" callback so the inbound layer doesn't import drizzle/postgres directly.
 */
import { Hono } from "hono";

export type HealthPing = () => Promise<void>;

/** Reject after `ms` so a hung DB connection can't stall the readiness probe. */
function withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    p,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`timed out after ${ms}ms`)), ms),
    ),
  ]);
}

export function healthRoutes(ping: HealthPing) {
  const app = new Hono();

  // Liveness — is the process alive?
  app.get("/healthz", (c) => c.json({ status: "ok" }));

  // Readiness — can it serve traffic? Returns 503 if the DB is unreachable
  // so k8s/load balancers can drain a node before it accepts more traffic.
  // Wrap the ping in a timeout for a fast 503 instead of hanging the probe.
  app.get("/readyz", async (c) => {
    try {
      await withTimeout(ping(), 1000);
      return c.json({ status: "ready" });
    } catch (err) {
      console.error("readiness check failed:", err);
      return c.json({ status: "not ready" }, 503);
    }
  });

  return app;
}

// In createApp(): pass a ping function constructed at bootstrap.
// e.g. `() => db.execute(sql`SELECT 1`).then(() => undefined)`
```

## Inbound: Task Handler (non-HTTP inbound adapter)

```typescript
// src/inbound/tasks/handler.ts
/**
 * Task queue handler — inbound adapter.
 * Same pattern as HTTP: typed payload -> toDomain() -> service -> ack.
 */
import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
// Import `z` from @hono/zod-openapi everywhere — importing from "zod" directly
// risks two Zod instances (a "split-Zod" type mismatch) when zod-openapi
// re-exports its own v4-compatible `z`.
import { z } from "@hono/zod-openapi";
import { AuthorName } from "../../domain/authors/models";
import type { AppEnv } from "../http/app";
import { problem, problemHeaders } from "../http/errors";
import { withFieldErrorsFrom } from "../http/problem";

const syncAuthorPayloadSchema = z.object({
  author_name: z.string().min(1),
  source: z.string(),
});

export function taskRoutes() {
  const app = new Hono<AppEnv>();

  app.post(
    "/tasks/sync-author",
    // Plain Hono + zValidator takes the hook as its 3rd arg (OpenAPIHono uses
    // the constructor defaultHook, or a per-route 3rd arg to app.openapi()).
    zValidator("json", syncAuthorPayloadSchema, (result, c) => {
      if (!result.success) {
        return c.json(
          problem("validation-error", "Unprocessable Entity", 422, "Request validation failed", {
            instance: c.req.path,
            ...withFieldErrorsFrom(result.error),
          }),
          422,
          problemHeaders(),
        );
      }
    }),
    async (c) => {
      const payload = c.req.valid("json");
      const domainReq = { name: AuthorName.create(payload.author_name) };
      await c.var.authorService.createAuthor(domainReq);
      return c.json({ status: "ok" });
    },
  );

  return app;
}

// In createApp():
// app.route("/", taskRoutes());    // task queue endpoints
// app.route("/", webhookRoutes()); // webhook endpoints
```

---

## Outbound: Outbox Adapter (transactional, Drizzle)

The outbox row must be inserted inside the same `db.transaction` callback as the aggregate write. Drizzle's tx callback is the natural unit-of-work scope.

```typescript
// src/domain/shared/events.ts — plain data, no infra deps
export interface DomainEvent {
  readonly aggregateType: string;
  readonly aggregateId: string;
  readonly eventType: string;
  readonly payload: Record<string, unknown>;
}
```

This is an **alternate** outbound adapter implementing an **alternate
(events-carrying) port shape** — NOT the canonical `AuthorRepository` above.
Keep exactly one canonical contract per port; if you adopt the events-carrying
variant, swap the whole stack (port + service + adapter) to it, don't run two
conflicting `AuthorRepository` definitions side by side.

```typescript
// src/domain/authors/ports.ts — ALTERNATE port that carries events to persist atomically.
// Distinct name so it never collides with the canonical AuthorRepository.
export interface OutboxAuthorRepository {
  createAuthor(
    author: Author,
    events: readonly DomainEvent[],
  ): Promise<Author>;
  // ...
}
```

```typescript
// src/outbound/outbox-postgres-author-repository.ts
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import { authors, outbox } from "./schema";
import { AuthorMapper } from "./drizzle/mapper";
import { currentTraceparent } from "./tracing";
import type { Author, CreateAuthorRequest } from "../domain/authors/models";
import type { DomainEvent } from "../domain/shared/events";
import type { OutboxAuthorRepository } from "../domain/authors/ports";

/**
 * ALTERNATE implementation of the events-carrying OutboxAuthorRepository port.
 * Named distinctly so it never collides with the canonical
 * DrizzleAuthorRepository / PostgresAuthorRepository above.
 */
export class OutboxPostgresAuthorRepository implements OutboxAuthorRepository {
  constructor(private readonly db: NodePgDatabase) {}

  async createAuthor(
    author: Author,
    events: readonly DomainEvent[],
  ): Promise<Author> {
    return this.db.transaction(async (tx) => {
      const [row] = await tx
        .insert(authors)
        .values({ id: author.id, name: author.name.value })
        .returning();

      if (events.length > 0) {
        // Trace context captured at write time, not at relay time.
        const traceparent = currentTraceparent();
        await tx.insert(outbox).values(
          events.map((e) => ({
            id: crypto.randomUUID(),
            aggregateType: e.aggregateType,
            aggregateId: e.aggregateId,
            eventType: e.eventType,
            payload: e.payload,
            traceparent,
          })),
        );
      }

      // Author is an interface — use the mapper, not a (non-existent) static.
      // `returning()` yields { id, name, createdAt }, the shape AuthorMapper expects.
      return AuthorMapper.toDomain(row);
    });
  }
}
```

```typescript
// Application service composes the events. It generates the id so the outbox
// aggregateId is the real entity id (not the name) and the persisted row id matches.
async createAuthor(req: CreateAuthorRequest): Promise<Author> {
  const author: Author = { id: crypto.randomUUID(), name: req.name };
  const events: DomainEvent[] = [{
    aggregateType: "author",
    aggregateId: author.id,
    eventType: "AuthorCreated",
    payload: { name: author.name.value },
  }];
  try {
    const created = await this.repo.createAuthor(author, events);
    await this.metrics.recordCreationSuccess();
    return created;
  } catch (error) {
    await this.metrics.recordCreationFailure();
    throw error;
  }
}
```

**Outbox relay** is a separate worker (a Node process, a Cloudflare Cron Worker, or a queue consumer). It polls `WHERE published_at IS NULL` in insertion order (`ORDER BY` a `created_at`/sequence column — `crypto.randomUUID()` ids don't sort by insertion) `LIMIT N`, publishes to the broker, and updates `published_at` on success. Failures move to a `outbox_dead` table after N attempts.

### Edge runtime gotcha (Cloudflare D1)

D1's transaction model is per-request and not transferable across `waitUntil` boundaries. If you defer the broker publish into `waitUntil`, the publish runs *outside* any tx — which is exactly what the outbox is for. Don't try to skip the outbox by using `waitUntil` directly; it loses durability if the worker is evicted before the publish completes.

### Common gotchas

- Don't make `Outbox` a separate port that takes a `tx` parameter — leaks Drizzle types into the domain. Keep both writes in the same adapter method.
- Don't publish to the broker inside the tx. Outbox relay is the only thing that talks to the broker.

---

## Outbound: Idempotency Store

A KV-shaped table keyed by `(scope, key)` with a unique constraint.

```typescript
// src/domain/shared/idempotency.ts
export type Acquire =
  | { tag: "new" }
  | { tag: "replay"; response: Uint8Array }
  | { tag: "conflict" }   // same key, different request hash
  | { tag: "in_flight" }; // same key, first request still executing — 409 (retry later), never re-run

export interface IdempotencyStore {
  acquire(scope: string, key: string, requestHash: string): Promise<Acquire>;
  store(scope: string, key: string, response: Uint8Array): Promise<void>;
}
```

```typescript
// src/outbound/drizzle/schema.ts — idempotency table (Postgres dialect shown)
import { pgTable, text, timestamp, primaryKey, customType } from "drizzle-orm/pg-core";

// Raw response bytes; `bytea` in Postgres.
const bytea = customType<{ data: Uint8Array }>({ dataType: () => "bytea" });

export const idempotency = pgTable(
  "idempotency",
  {
    scope: text("scope").notNull(),
    key: text("key").notNull(),
    requestHash: text("request_hash").notNull(),
    response: bytea("response"), // null until the response is stored
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  // Composite PK gives the unique (scope, key) constraint races collapse on.
  (t) => [primaryKey({ columns: [t.scope, t.key] })],
);
```

```typescript
// src/outbound/drizzle/idempotency.ts
import { and, eq } from "drizzle-orm";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import { idempotency } from "./schema";
import type { Acquire, IdempotencyStore } from "../../domain/shared/idempotency";

export class PostgresIdempotencyStore implements IdempotencyStore {
  constructor(private readonly db: NodePgDatabase) {}

  async acquire(scope: string, key: string, hash: string): Promise<Acquire> {
    // Insert-or-fetch — unique (scope, key) collapses races to one winner.
    const inserted = await this.db
      .insert(idempotency)
      .values({ scope, key, requestHash: hash })
      .onConflictDoNothing()
      .returning({ ok: idempotency.scope });

    if (inserted.length === 1) return { tag: "new" };

    const [row] = await this.db
      .select()
      .from(idempotency)
      .where(and(eq(idempotency.scope, scope), eq(idempotency.key, key)));

    // The losing racer may read before the winner's row is visible — treat a
    // missing row as a fresh insert rather than dereferencing undefined.
    if (!row) return { tag: "new" };

    if (row.requestHash !== hash) return { tag: "conflict" };
    if (row.response) return { tag: "replay", response: row.response };
    // No stored response yet = the first request is still running. Returning
    // "new" here would double-execute (double charge).
    return { tag: "in_flight" };
  }
  // store(...) updates the row with the response bytes.
}
```

---

## Outbound: Tracer Port (OTel)

Don't import `@opentelemetry/*` into the domain. Define a minimal interface; the OTel adapter implements it. Tests use a no-op or capturing adapter.

```typescript
// src/domain/shared/tracing.ts
export interface Span {
  addEvent(name: string, attrs?: Record<string, string>): void;
  recordError(err: unknown): void;
  end(): void;
}
export interface Tracer {
  startSpan(name: string, attrs?: Record<string, string>): Span;
}
```

The Node adapter (`src/outbound/otel.ts`) wraps `@opentelemetry/api`'s tracer.

**Edge variant** (Cloudflare Workers): wrap `otel-cf-workers` instead, or implement a minimal `Tracer` that emits spans via `fetch` to the OTel Collector. Same port, different adapter — no domain code changes. This is exactly the kind of swap the port abstraction earns its keep on.

For sampling, cardinality budgets, and span attribute conventions, see `software-architecture/references/observability.md`.
