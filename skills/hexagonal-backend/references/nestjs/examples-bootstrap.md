# Examples: Bootstrap & Testing

Config, main.ts, module wiring, TypeORM setup, and hex-specific test mocks.

## Table of Contents

1. [Config](#config)
2. [Bootstrap (main.ts)](#bootstrap-maints)
3. [Root Module (AppModule)](#root-module-appmodule)
4. [Feature Module (AuthorsModule)](#feature-module-authorsmodule)
5. [NoOp Adapters](#noop-adapters)
6. [TypeORM DataSource + Migrations](#typeorm-datasource--migrations)
7. [package.json](#packagejson)
8. [tsconfig.json](#tsconfigjson)
9. [Vitest config](#vitest-config)
10. [Testing: Hex-Specific Mocks](#testing-hex-specific-mocks)
11. [.env.example](#envexample)

---

## Config

```typescript
// src/config.ts
import { z } from "zod";

/**
 * Typed config — validates env once at startup.
 */
const configSchema = z.object({
  DATABASE_URL: z.string().min(1),
  PORT: z.coerce.number().default(3000),
  CORS_ORIGIN: z.string().default("http://localhost:3000"),
  // Asymmetric JWT (canonical) — verifiers fetch public keys from the issuer's
  // JWKS endpoint and pin audience/issuer. See guards/jwt-auth.guard.ts.
  JWT_JWKS_URL: z.string().url(),
  JWT_AUDIENCE: z.string().min(1),
  JWT_ISSUER: z.string().min(1),
  // Symmetric secret — only for the single-service / dev HS256 fallback.
  JWT_SECRET: z.string().min(16),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
});

export type AppConfig = z.infer<typeof configSchema>;

export function validateConfig(config: Record<string, unknown>): AppConfig {
  // .parse throws a ZodError listing every failing key — surfaced at startup.
  return configSchema.parse(config);
}
```

## Bootstrap (main.ts)

```typescript
// src/main.ts
import { NestFactory } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { cleanupOpenApiDoc } from "nestjs-zod";
import { Logger } from "nestjs-pino";
import helmet from "helmet";
import { AppModule } from "./app.module";

async function bootstrap() {
  // `bufferLogs: true` queues startup logs until nestjs-pino is wired,
  // so the Nest banner uses the same JSON formatter as the rest of the app.
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  // Replace the built-in logger with nestjs-pino (structured JSON, low overhead).
  app.useLogger(app.get(Logger));

  // Security
  app.use(helmet());
  const configService = app.get(ConfigService);
  app.enableCors({ origin: [configService.get("CORS_ORIGIN")] });

  // NOTE: the global exception filter (DomainExceptionFilter) is registered via
  // APP_FILTER in AppModule, NOT `new DomainExceptionFilter()` here — it injects
  // ClsService (for the X-Request-Id correlation id) and so must be DI-resolved.
  // Request validation runs through the global ZodValidationPipe (APP_PIPE in AppModule).

  // Swagger — cleanupOpenApiDoc post-processes createZodDto schemas into valid OpenAPI.
  // addBearerAuth() registers the scheme; apply it per-operation with
  // @ApiBearerAuth() + @UseGuards(JwtAuthGuard) on protected routes (see below).
  const config = new DocumentBuilder()
    .setTitle("Author API")
    .setVersion("1")
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup("docs", app, cleanupOpenApiDoc(document));

  // Graceful shutdown — triggers onModuleDestroy
  app.enableShutdownHooks();

  const port = configService.get("PORT");
  await app.listen(port);
}
bootstrap();
```

## Root Module (AppModule)

```typescript
// src/app.module.ts
import { Module } from "@nestjs/common";
import { APP_FILTER, APP_GUARD, APP_PIPE } from "@nestjs/core";
import { ConfigModule } from "@nestjs/config";
import { TerminusModule } from "@nestjs/terminus";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { ClsModule } from "nestjs-cls";
import { LoggerModule } from "nestjs-pino";
import { randomUUID } from "node:crypto";
import { validateConfig } from "./config";

import { TypeOrmPersistenceModule } from "./outbound/typeorm/typeorm.module";

import { AuthorsModule } from "./authors.module";
import { HealthController } from "./inbound/http/health/health.controller";
import { ZodValidationPipe } from "./inbound/http/pipes/zod-validation.pipe";
import { DomainExceptionFilter } from "./inbound/http/filters/domain-exception.filter";

@Module({
  imports: [
    ConfigModule.forRoot({ validate: validateConfig, isGlobal: true }),

    // Request-scoped context (request_id, tenant_id, userId).
    // The CLS store is populated automatically per request; adapters read it
    // without threading values through every constructor.
    ClsModule.forRoot({
      global: true,
      middleware: {
        mount: true,
        generateId: true,
        idGenerator: () => randomUUID(),
        setup: (cls, req) => {
          cls.set("requestId", cls.getId());
          // Populate tenantId / userId from guard or header here once auth runs.
        },
      },
    }),

    // Structured logging — stamps every line with the CLS request_id.
    LoggerModule.forRoot({
      pinoHttp: {
        level: process.env.NODE_ENV === "production" ? "info" : "debug",
        // Avoid noisy req/res serialisation in production; rely on Pino's defaults.
        autoLogging: { ignore: (req) => req.url === "/health/live" },
        customProps: () => ({}),
      },
    }),

    // Global rate limit. Per-route tightening with @Throttle(); opt-out with @SkipThrottle().
    ThrottlerModule.forRoot([{ name: "default", ttl: 60_000, limit: 100 }]),

    TypeOrmPersistenceModule,
    TerminusModule,
    AuthorsModule,
  ],
  controllers: [HealthController],
  providers: [
    // Global ZodValidationPipe — validates every createZodDto-typed parameter.
    { provide: APP_PIPE, useClass: ZodValidationPipe },
    // Global rate-limit guard (ThrottlerGuard reads ThrottlerModule's config).
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // Global exception filter — DI-resolved so it can inject ClsService for the
    // X-Request-Id correlation header. Catches everything (incl. ThrottlerException
    // 429s) and emits RFC 9457 application/problem+json.
    { provide: APP_FILTER, useClass: DomainExceptionFilter },
  ],
})
export class AppModule {}
```

## Feature Module (AuthorsModule)

```typescript
// src/authors.module.ts
import { Module } from "@nestjs/common";
import { AuthorsController } from "./inbound/http/authors/authors.controller";
import { AuthorService, AuthorRepository, AuthorMetrics, AuthorNotifier } from "./domain/authors/ports";
import { AuthorServiceImpl } from "./domain/authors/service";
import { NoOpMetrics, NoOpNotifier } from "./outbound/noop";

/**
 * Feature module — wires controller, service, and supporting ports.
 *
 * Default pattern: `useClass`. `AuthorServiceImpl` carries `@Injectable()`,
 * so NestJS reads its constructor metadata and injects the abstract-class
 * tokens (AuthorRepository / AuthorMetrics / AuthorNotifier) directly.
 *
 * AuthorRepository comes from the persistence module (@Global).
 *
 * Alternative — `useFactory` (no @Injectable() in domain). Keeps
 * domain/ free of NestJS imports at the cost of more wiring per service:
 *
 *   {
 *     provide: AuthorService,
 *     useFactory: (repo, metrics, notifier) =>
 *       new AuthorServiceImpl(repo, metrics, notifier),
 *     inject: [AuthorRepository, AuthorMetrics, AuthorNotifier],
 *   }
 */
@Module({
  controllers: [AuthorsController],
  providers: [
    // ⚠️ NoOp metrics/notifier are DEV/TEST DEFAULTS — they drop every signal
    // on the floor. Override per-environment with real adapters (e.g. an OTel
    // meter, a queue-backed notifier) in production wiring, or move this NoOp
    // binding into a dedicated dev module so prod can't accidentally ship it.
    { provide: AuthorMetrics, useClass: NoOpMetrics },
    { provide: AuthorNotifier, useClass: NoOpNotifier },
    { provide: AuthorService, useClass: AuthorServiceImpl },
  ],
  exports: [AuthorService],
})
export class AuthorsModule {}
```

## NoOp Adapters

```typescript
// src/outbound/noop.ts
import { Injectable } from "@nestjs/common";
import { AuthorMetrics, AuthorNotifier } from "../domain/authors/ports";
import type { Author } from "../domain/authors/models";

@Injectable()
export class NoOpMetrics extends AuthorMetrics {
  async recordCreationSuccess(): Promise<void> {}
  async recordCreationFailure(): Promise<void> {}
}

@Injectable()
export class NoOpNotifier extends AuthorNotifier {
  async authorCreated(_author: Author): Promise<void> {}
}
```

---

## TypeORM DataSource + Migrations

The TypeORM CLI needs a standalone `DataSource` (it can't read Nest's DI graph). Keep this file at the project root and reuse the same `entities` and `migrations` paths the runtime module uses.

```typescript
// data-source.ts
import "reflect-metadata";
import { DataSource } from "typeorm";
import { AuthorEntity } from "./src/outbound/typeorm/entities/author.entity";

export default new DataSource({
  type: "postgres",
  url: process.env.DATABASE_URL,
  entities: [AuthorEntity],
  migrations: ["./migrations/*.ts"],
  // synchronize stays absent — migrations are the only path that mutates schema.
});
```

```bash
# Generate a migration from the entity diff
bunx typeorm-ts-node-commonjs migration:generate -d ./data-source.ts ./migrations/CreateAuthors

# Apply pending migrations
bunx typeorm-ts-node-commonjs migration:run -d ./data-source.ts

# Revert the most recent migration
bunx typeorm-ts-node-commonjs migration:revert -d ./data-source.ts
```

---

## package.json

```json
{
  "name": "myapp",
  "private": true,
  "engines": {
    "node": ">=20.19.0"
  },
  "scripts": {
    "build": "nest build",
    "dev": "nest start --watch",
    "start": "node dist/main.js",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "vitest run --config vitest.e2e.config.ts",
    "migration:generate": "typeorm-ts-node-commonjs migration:generate -d ./data-source.ts",
    "migration:run": "typeorm-ts-node-commonjs migration:run -d ./data-source.ts",
    "migration:revert": "typeorm-ts-node-commonjs migration:revert -d ./data-source.ts"
  },
  "dependencies": {
    "@nestjs/common": "^11.0",
    "@nestjs/core": "^11.0",
    "@nestjs/platform-express": "^11.0",
    "@nestjs/config": "^11.0",
    "@nestjs/swagger": "^11.0",
    "@nestjs/terminus": "^11.0",
    "@nestjs/typeorm": "^11.0.1",
    "@nestjs/throttler": "^6.0",
    "@node-rs/argon2": "^2.0",
    "@opentelemetry/api": "^1.9",
    "jose": "^6.2",
    "typeorm": "^1.0",
    "pg": "^8.13",
    "nestjs-zod": "^5.4",
    "nestjs-pino": "^4.4",
    "pino-http": "^10.4",
    "nestjs-cls": "^5.0",
    "zod": "^4.0",
    "helmet": "^8.0",
    "reflect-metadata": "^0.2",
    "rxjs": "^7.0"
  },
  "devDependencies": {
    "@nestjs/cli": "^11.0",
    "@nestjs/testing": "^11.0",
    "typescript": "^5.7",
    "vitest": "^3.0",
    "@vitest/coverage-v8": "^3.0",
    "unplugin-swc": "^1.5",
    "supertest": "^7.0",
    "ts-node": "^10.9",
    "@types/express": "^5",
    "@types/pg": "^8.0",
    "@types/supertest": "^6.0"
  }
}
```

```bash
bun install                    # install all deps
bun run dev                    # watch mode development
bun run test                   # run unit tests (vitest)
```

> **Version baseline (as of 2026-10).** This set is the coherent **NestJS 11** line, kept deliberately: `nestjs-zod` 5.5 (latest) still declares peer `@nestjs/common` ^10 || ^11 and `@nestjs/swagger` ^7.4.2 || ^8 || ^11. Current majors have moved on — `@nestjs/*` 12 (Aug 2026), `@nestjs/typeorm` 12, `nestjs-cls` 7, `nestjs-pino` 5 (needs `pino` 10 + `pino-http` 11), Vitest 5, `unplugin-swc` 2, TypeScript 7 — but `@nestjs/swagger` 12 declares peer `typescript` ^5.5 || ^6. Upgrade as a deliberate pass: check each package's peer ranges and changelog (nestjs-zod support for Nest 12 first), then bump together. `typeorm` 1.x needs Node `^20.19 || ^22.13 || >=24.11`.

> **Why no `jsonwebtoken` / `passport-jwt`?** The JWT guard uses `jose` directly — modern, ESM-friendly, clean security history. Add `@nestjs/passport` + a strategy package only when you need OAuth providers alongside JWT.

---

## tsconfig.json

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2023",
    "sourceMap": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strict": true,
    "strictNullChecks": true,
    "noImplicitAny": true,
    "forceConsistentCasingInFileNames": true,
    "paths": { "~/*": ["./src/*"] }
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
```

Key: `emitDecoratorMetadata` and `experimentalDecorators` are required for NestJS DI **and** for TypeORM `@Entity`/`@Column` reflection.

---

## Vitest config

Vitest replaces Jest as the test runner — faster startup, native ESM, better with Bun. The catch: Vitest doesn't transform decorators by default. Use `unplugin-swc` so `@Injectable`, `@Entity`, etc. emit reflect metadata correctly.

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";
import swc from "unplugin-swc";

export default defineConfig({
  test: {
    globals: false,          // import { describe, it, expect } explicitly
    environment: "node",
    include: ["tests/**/*.spec.ts"],
    setupFiles: ["reflect-metadata"],
  },
  plugins: [
    swc.vite({
      jsc: {
        parser: { syntax: "typescript", decorators: true },
        transform: { legacyDecorator: true, decoratorMetadata: true },
        target: "es2023",
      },
    }),
  ],
});
```

```typescript
// vitest.e2e.config.ts — same plugin, separate include + longer timeouts
import { defineConfig, mergeConfig } from "vitest/config";
import base from "./vitest.config";

export default mergeConfig(base, defineConfig({
  test: {
    include: ["tests/e2e/**/*.spec.ts"],
    testTimeout: 30_000,
    hookTimeout: 30_000,
  },
}));
```

---

## Testing: Hex-Specific Mocks

### Strategy

| Layer | Mock | What to test |
|-------|------|--------------|
| Controller | Mock service | HTTP parsing, status codes, error format |
| Service | Mock repo/metrics/notifier | Orchestration, side-effect ordering |
| Repository | Real DB | SQL/queries, error mapping, transactions |
| E2E | Nothing mocked | Critical happy paths |

### Mocks (extend abstract port classes)

```typescript
// tests/mocks.ts
import type {
  Author,
  CreateAuthorRequest,
  CursorPage,
} from "../src/domain/authors/models";
import {
  AuthorRepository, AuthorMetrics, AuthorNotifier, AuthorService,
} from "../src/domain/authors/ports";
import { UnknownAuthorError } from "../src/domain/authors/errors";

/** Stub — returns configured results. */
export class MockAuthorRepository extends AuthorRepository {
  createCalls: CreateAuthorRequest[] = [];
  constructor(private createResult?: Author | Error) { super(); }

  async createAuthor(req: CreateAuthorRequest): Promise<Author> {
    this.createCalls.push(req);
    if (this.createResult instanceof Error) throw this.createResult;
    return this.createResult!;
  }
  async findAuthor(_id: string): Promise<Author | null> { return null; }
  async listAuthors(_cursor: string | null, _limit: number): Promise<CursorPage<Author>> {
    return { items: [], nextCursor: null, hasMore: false };
  }
}

/** Saboteur — always throws to test error paths. */
export class SaboteurRepository extends AuthorRepository {
  constructor(private error?: Error) { super(); }
  async createAuthor(_req: CreateAuthorRequest): Promise<Author> {
    throw this.error ?? new UnknownAuthorError(new Error("db on fire"));
  }
  async findAuthor(_id: string): Promise<Author | null> {
    throw this.error ?? new UnknownAuthorError(new Error("db on fire"));
  }
  async listAuthors(_cursor: string | null, _limit: number): Promise<CursorPage<Author>> {
    throw this.error ?? new UnknownAuthorError(new Error("db on fire"));
  }
}

/** Spy — counts side effects. */
export class SpyMetrics extends AuthorMetrics {
  successes = 0; failures = 0;
  async recordCreationSuccess(): Promise<void> { this.successes++; }
  async recordCreationFailure(): Promise<void> { this.failures++; }
}

export class SpyNotifier extends AuthorNotifier {
  notifications: Author[] = [];
  async authorCreated(author: Author): Promise<void> { this.notifications.push(author); }
}

/** NoOp — for E2E tests where side effects don't matter. */
export class NoOpMockMetrics extends AuthorMetrics {
  async recordCreationSuccess(): Promise<void> {}
  async recordCreationFailure(): Promise<void> {}
}
export class NoOpMockNotifier extends AuthorNotifier {
  async authorCreated(_author: Author): Promise<void> {}
}
```

### Test Module Helper

Controller tests follow the documented strategy: **mock service/repo, NO DB.**
The slim helper imports only `AuthorsModule` plus the global pipe + filter — it
never touches `TypeOrmPersistenceModule`, so `app.init()` opens no Postgres
connection. (Booting the full `AppModule` is the E2E path — it triggers
`TypeOrmModule.forRootAsync`, which connects to a real database on `init()`; do
that in `tests/e2e/**` against a throw-away DB, not in fast controller tests.)

```typescript
// tests/helpers.ts
import { Test, type TestingModule } from "@nestjs/testing";
import { type INestApplication } from "@nestjs/common";
import { APP_FILTER, APP_PIPE } from "@nestjs/core";
import { ClsModule } from "nestjs-cls";
import { AuthorsModule } from "../src/authors.module";
import { AuthorRepository } from "../src/domain/authors/ports";
import { ZodValidationPipe } from "../src/inbound/http/pipes/zod-validation.pipe";
import { DomainExceptionFilter } from "../src/inbound/http/filters/domain-exception.filter";
import { MockAuthorRepository } from "./mocks";

/**
 * Fast controller test app — NO database.
 *
 * Imports only AuthorsModule and re-declares the two globals the controller
 * relies on (the ZodValidationPipe and the DomainExceptionFilter). The repo
 * port is bound to a mock, so the service runs for real but persistence is
 * stubbed and `app.init()` opens no DB connection.
 *
 * ClsModule is registered (without middleware) so DomainExceptionFilter can
 * inject ClsService for the X-Request-Id header. For E2E, import AppModule
 * instead — see tests/e2e/**.
 */
export async function createTestApp(overrides?: {
  repo?: MockAuthorRepository;
}): Promise<{ app: INestApplication; module: TestingModule }> {
  const module = await Test.createTestingModule({
    imports: [ClsModule.forRoot({ global: true }), AuthorsModule],
    providers: [
      { provide: APP_PIPE, useClass: ZodValidationPipe },
      { provide: APP_FILTER, useClass: DomainExceptionFilter },
    ],
  })
    // Mock the persistence port — AuthorsModule's service resolves it normally,
    // but it never reaches TypeORM. AuthorRepository is provided by the @Global
    // persistence module in prod; here we supply it directly.
    .overrideProvider(AuthorRepository)
    .useValue(overrides?.repo ?? new MockAuthorRepository())
    .compile();

  const app = module.createNestApplication();
  await app.init();
  return { app, module };
}
```

> AuthorsModule injects `AuthorRepository` (normally exported by the `@Global`
> `TypeOrmPersistenceModule`). In the slim test module that global provider is
> absent, so `.overrideProvider(AuthorRepository).useValue(...)` supplies it.
> NestJS's `overrideProvider` registers the token even when the original
> provider isn't present in the compiled graph.

### Controller Tests (Vitest + supertest)

```typescript
// tests/controllers/authors.controller.spec.ts
import { afterEach, describe, expect, it } from "vitest";
import request from "supertest";
import type { INestApplication } from "@nestjs/common";
import { AuthorName } from "../../src/domain/authors/models";
import { DuplicateAuthorError } from "../../src/domain/authors/errors";
import { createTestApp } from "../helpers";
import { MockAuthorRepository } from "../mocks";

describe("AuthorsController", () => {
  let app: INestApplication;
  afterEach(async () => { await app?.close(); });

  describe("POST /v1/authors", () => {
    it("creates an author and returns 201", async () => {
      const author = { id: "123", name: AuthorName.create("Alice") };
      const repo = new MockAuthorRepository(author);
      ({ app } = await createTestApp({ repo }));

      const res = await request(app.getHttpServer())
        .post("/v1/authors").send({ name: "Alice" }).expect(201);

      expect(res.body.data.name).toBe("Alice");
      expect(repo.createCalls).toHaveLength(1);
    });

    it("returns 409 for duplicate author", async () => {
      const repo = new MockAuthorRepository(new DuplicateAuthorError("Alice"));
      ({ app } = await createTestApp({ repo }));

      const res = await request(app.getHttpServer())
        .post("/v1/authors").send({ name: "Alice" }).expect(409);
      expect(res.body.type).toContain("duplicate-author");
    });

    it("returns 422 for empty name (Zod)", async () => {
      const repo = new MockAuthorRepository();
      ({ app } = await createTestApp({ repo }));
      // Status is 422 (Unprocessable Entity) — body validated but semantically
      // invalid. 400 would imply malformed transport (unparseable JSON, etc.).
      await request(app.getHttpServer())
        .post("/v1/authors").send({ name: "" }).expect(422);
    });
  });

  describe("GET /v1/authors", () => {
    it("returns empty list with cursor pagination meta", async () => {
      const repo = new MockAuthorRepository();
      ({ app } = await createTestApp({ repo }));

      const res = await request(app.getHttpServer())
        .get("/v1/authors?limit=10").expect(200);
      expect(res.body.data).toEqual([]);
      // Cursor metadata lives in `meta`, per api-design.md.
      expect(res.body.meta.has_more).toBe(false);
      expect(res.body.meta.next_cursor).toBeNull();
    });
  });
});
```

### Service Tests (unit tests with mocks)

```typescript
// tests/services/author.service.spec.ts
import { describe, expect, it } from "vitest";
import { AuthorServiceImpl } from "../../src/domain/authors/service";
import { AuthorName } from "../../src/domain/authors/models";
import { DuplicateAuthorError, UnknownAuthorError } from "../../src/domain/authors/errors";
import { MockAuthorRepository, SpyMetrics, SpyNotifier, SaboteurRepository } from "../mocks";

describe("AuthorServiceImpl", () => {
  it("creates author, records success, notifies", async () => {
    const author = { id: "1", name: AuthorName.create("Alice") };
    const repo = new MockAuthorRepository(author);
    const metrics = new SpyMetrics();
    const notifier = new SpyNotifier();
    const service = new AuthorServiceImpl(repo, metrics, notifier);

    const result = await service.createAuthor({ name: AuthorName.create("Alice") });
    expect(result.name.value).toBe("Alice");
    expect(metrics.successes).toBe(1);
    expect(notifier.notifications).toHaveLength(1);
  });

  it("records failure on duplicate", async () => {
    const repo = new MockAuthorRepository(new DuplicateAuthorError("Alice"));
    const metrics = new SpyMetrics();
    const notifier = new SpyNotifier();
    const service = new AuthorServiceImpl(repo, metrics, notifier);

    await expect(
      service.createAuthor({ name: AuthorName.create("Alice") }),
    ).rejects.toBeInstanceOf(DuplicateAuthorError);
    expect(metrics.failures).toBe(1);
  });

  it("wraps unknown errors", async () => {
    const repo = new SaboteurRepository();
    const metrics = new SpyMetrics();
    const notifier = new SpyNotifier();
    const service = new AuthorServiceImpl(repo, metrics, notifier);

    await expect(
      service.createAuthor({ name: AuthorName.create("Bob") }),
    ).rejects.toBeInstanceOf(UnknownAuthorError);
  });
});
```

> **Spy mock note:** hand-rolled `SpyMetrics` / `SpyNotifier` are clear at small port surfaces. Once a port has 5+ methods, hybrid with `vi.fn()` — extend the abstract class but back each method with a `vi.fn()` so you get the same Stub/Saboteur/Spy ergonomics plus `toHaveBeenCalledWith` assertions without growing a class per behaviour.

### Integration Tests (real DB)

```typescript
// tests/integration/typeorm-author.repository.spec.ts
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { Test } from "@nestjs/testing";
import { TypeOrmModule } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import { AuthorEntity } from "../../src/outbound/typeorm/entities/author.entity";
import { TypeOrmAuthorRepository } from "../../src/outbound/typeorm/author.repository";
import { AuthorRepository } from "../../src/domain/authors/ports";
import { AuthorName } from "../../src/domain/authors/models";
import { DuplicateAuthorError } from "../../src/domain/authors/errors";

describe("TypeOrmAuthorRepository (integration)", () => {
  let dataSource: DataSource;
  let repo: AuthorRepository;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: "postgres",
          url: process.env.TEST_DATABASE_URL,
          entities: [AuthorEntity],
          // synchronize is acceptable in a throw-away test DB only — never in deployed envs.
          synchronize: true,
          dropSchema: true,
        }),
        TypeOrmModule.forFeature([AuthorEntity]),
      ],
      providers: [
        { provide: AuthorRepository, useClass: TypeOrmAuthorRepository },
      ],
    }).compile();
    dataSource = module.get(DataSource);
    repo = module.get(AuthorRepository);
  });

  afterAll(async () => {
    await dataSource.destroy();
  });

  beforeEach(async () => {
    await dataSource.getRepository(AuthorEntity).clear();
  });

  it("creates and finds an author", async () => {
    const author = await repo.createAuthor({ name: AuthorName.create("Alice") });
    expect(author.name.value).toBe("Alice");
    const found = await repo.findAuthor(author.id);
    expect(found).not.toBeNull();
    expect(found!.name.value).toBe("Alice");
  });

  it("throws DuplicateAuthorError on unique constraint", async () => {
    await repo.createAuthor({ name: AuthorName.create("Alice") });
    await expect(
      repo.createAuthor({ name: AuthorName.create("Alice") }),
    ).rejects.toBeInstanceOf(DuplicateAuthorError);
  });
});
```

---

## .env.example

```bash
DATABASE_URL="postgres://postgres:postgres@localhost:5432/myapp"
PORT=3000
CORS_ORIGIN="http://localhost:3000"
# Asymmetric JWT (canonical guard)
JWT_JWKS_URL="https://issuer.example.com/.well-known/jwks.json"
JWT_AUDIENCE="https://api.example.com"
JWT_ISSUER="https://issuer.example.com"
# Symmetric secret — single-service / dev HS256 fallback only
JWT_SECRET="your-secret-key-at-least-16-chars"
NODE_ENV="development"
```
