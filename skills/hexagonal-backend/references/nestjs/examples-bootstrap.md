# NestJS examples: bootstrap, tests and CI

Configuration, module wiring, entrypoints, the project manifest and toolchain, the test harness with the PostgreSQL and HTTP suites, and the CI gates. Complete files of the same project as `examples-domain.md`.

## Contents

1. [Manifest and toolchain](#manifest-and-toolchain)
2. [Configuration](#configuration)
3. [Modules](#modules)
4. [HTTP edge](#http-edge)
5. [Entrypoints, shutdown and telemetry](#entrypoints-shutdown-and-telemetry)
6. [Worker](#worker)
7. [Test harness](#test-harness)
8. [PostgreSQL adapter tests](#postgresql-adapter-tests)
9. [HTTP tests](#http-tests)
10. [CI](#ci)

## Manifest and toolchain

```json file=package.json
{
  "name": "publishing-api",
  "private": true,
  "type": "module",
  "engines": {
    "node": "^22.13.0 || >=24.11.0"
  },
  "scripts": {
    "build": "tsc -p tsconfig.build.json",
    "start": "node --import ./dist/telemetry.js dist/main.js",
    "start:worker": "node --import ./dist/telemetry.js dist/worker.js",
    "migrate": "typeorm migration:run -d dist/data-source.js",
    "migrate:check": "typeorm migration:generate -d dist/data-source.js --check src/migrations/drift",
    "typecheck": "tsc --noEmit",
    "lint": "oxlint --type-aware --deny-warnings src test",
    "boundaries": "depcruise src --config .dependency-cruiser.cjs",
    "test": "vitest run"
  },
  "dependencies": {
    "@nestjs-cls/transactional": "^4.0.1",
    "@nestjs-cls/transactional-adapter-typeorm": "^2.0.1",
    "@nestjs/common": "^12.1.2",
    "@nestjs/config": "^12.0.1",
    "@nestjs/core": "^12.1.2",
    "@nestjs/platform-express": "^12.1.2",
    "@nestjs/swagger": "^12.0.2",
    "@nestjs/terminus": "^12.1.0",
    "@nestjs/typeorm": "^12.0.2",
    "@opentelemetry/api": "^1.9.1",
    "@opentelemetry/instrumentation": "^0.223.0",
    "@opentelemetry/instrumentation-express": "^0.71.0",
    "@opentelemetry/instrumentation-http": "^0.223.0",
    "@opentelemetry/instrumentation-nestjs-core": "^0.69.0",
    "@opentelemetry/instrumentation-pg": "^0.75.0",
    "@opentelemetry/instrumentation-pino": "^0.69.0",
    "@opentelemetry/sdk-node": "^0.223.0",
    "jose": "^6.2.12",
    "nestjs-cls": "^7.0.1",
    "nestjs-pino": "^5.3.1",
    "pg": "^8.23.1",
    "pino": "^10.4.0",
    "pino-http": "^11.0.0",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.2",
    "typeorm": "^1.1.1",
    "uuid": "^14.0.2",
    "zod": "^4.6.5"
  },
  "devDependencies": {
    "@nestjs/testing": "^12.1.2",
    "@types/express": "^5.0.6",
    "@types/node": "^24.19.1",
    "@types/supertest": "^7.2.1",
    "dependency-cruiser": "^18.5.0",
    "oxlint": "^1.87.0",
    "oxlint-tsgolint": "^7.0.2003",
    "supertest": "^7.3.1",
    "typescript": "~6.0.3",
    "vite": "^8.3.3",
    "vitest": "^5.0.3"
  }
}
```

```json file=tsconfig.json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "types": ["node"],
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "isolatedModules": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "outDir": "dist"
  },
  "include": ["src", "test", "vitest.config.ts"]
}
```

```json file=tsconfig.build.json
{
  "extends": "./tsconfig.json",
  "compilerOptions": { "rootDir": "src" },
  "include": ["src"]
}
```

```ts file=vitest.config.ts
import { defineConfig } from "vitest/config";

// Assigned here rather than in test.env so that globalSetup, which runs in this process, sees it too.
Object.assign(process.env, {
  APP_ENV: "test",
  LOG_LEVEL: "silent",
  DATABASE_URL: process.env.TEST_DATABASE_URL ?? "postgres://postgres:postgres@127.0.0.1:5432/publishing_test",
  JWT_MODE: "hs256",
  JWT_HS256_SECRET: "test-only-secret-of-at-least-32-chars",
  JWT_ISSUER: "https://auth.example.test",
  JWT_AUDIENCE: "publishing-api",
  PROBLEM_BASE_URI: "https://api.example.com/problems/",
  WEBHOOK_SECRETS: `whsec_${Buffer.from("moderation-webhook-test-secret").toString("base64")}`,
  SHUTDOWN_DELAY_MS: "300",
  CORS_ORIGINS: "https://app.example.test",
});

export default defineConfig({
  test: {
    include: ["test/**/*.spec.ts"],
    globalSetup: ["test/support/global-setup.ts"],
    fileParallelism: false, // the suites share one database
    testTimeout: 15_000,
  },
});
```

```jsonc file=.oxlintrc.json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  // Run with --type-aware --deny-warnings. Everything in these categories is an error.
  "plugins": ["typescript", "unicorn", "oxc", "import", "vitest", "node"],
  "categories": { "correctness": "error", "suspicious": "error", "perf": "error" },
  "env": { "node": true },
  "rules": {
    "typescript/no-floating-promises": "error",
    "typescript/no-misused-promises": "error",
    "typescript/no-explicit-any": "error",
    "typescript/no-non-null-assertion": "error",
    "import/no-cycle": "error",
    "no-console": "error",
    "eqeqeq": "error",
    // Nest modules are decorated classes with no members.
    "typescript/no-extraneous-class": ["error", { "allowWithDecorator": true }],
    // Statements on one connection and ordered relay work are sequential on purpose.
    "no-await-in-loop": "off"
  }
}
```

## Configuration

```ts file=src/config.ts
import { z } from "zod";

const list = z.string().transform((value) => value.split(",").map((s) => s.trim()).filter(Boolean));

// Decoded once, here, for the signature guard.
const webhookSecret = z
  .string()
  .regex(/^whsec_[A-Za-z0-9+/]{32,}={0,2}$/, "must be whsec_ followed by the base64 of at least 24 bytes")
  .transform((secret) => Buffer.from(secret.slice("whsec_".length), "base64"));

const jwtMode = z.discriminatedUnion("JWT_MODE", [
  z.object({ JWT_MODE: z.literal("jwks"), JWT_JWKS_URL: z.url({ protocol: /^https$/ }) }),
  z.object({ JWT_MODE: z.literal("hs256"), JWT_HS256_SECRET: z.string().min(32) }),
]);

export const envSchema = z
  .object({
    APP_ENV: z.enum(["development", "test", "production"]).default("development"),
    PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
    LOG_LEVEL: z.enum(["debug", "info", "warn", "error", "silent"]).default("info"),
    DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/ }),
    DB_POOL_SIZE: z.coerce.number().int().min(1).max(100).default(10),
    JWT_ISSUER: z.string().min(1),
    JWT_AUDIENCE: z.string().min(1),
    PROBLEM_BASE_URI: z.url().endsWith("/"),
    CORS_ORIGINS: list.pipe(z.array(z.url())).default([]),
    REQUEST_TIMEOUT_MS: z.coerce.number().int().min(100).max(30_000).default(5_000), // below the 60 s idempotency lease
    SHUTDOWN_DELAY_MS: z.coerce.number().int().min(0).max(20_000).default(0),
    WEBHOOK_SECRETS: list.pipe(z.array(webhookSecret).min(1)),
  })
  .and(jwtMode)
  .refine((env) => env.APP_ENV !== "production" || env.JWT_MODE === "jwks", {
    path: ["JWT_MODE"],
    message: "hs256 is for development and tests; production verifies tokens against a JWKS",
  })
  .transform((env) => ({
    ...env,
    jwt:
      env.JWT_MODE === "jwks"
        ? { mode: "jwks" as const, jwksUrl: env.JWT_JWKS_URL, issuer: env.JWT_ISSUER, audience: env.JWT_AUDIENCE }
        : { mode: "hs256" as const, secret: env.JWT_HS256_SECRET, issuer: env.JWT_ISSUER, audience: env.JWT_AUDIENCE },
  }));

export type Env = z.output<typeof envSchema>;
```

## Modules

```ts file=src/core.module.ts
import { Module, type DynamicModule } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { getDataSourceToken, TypeOrmModule } from "@nestjs/typeorm";
import { ClsPluginTransactional } from "@nestjs-cls/transactional";
import { TransactionalAdapterTypeOrm } from "@nestjs-cls/transactional-adapter-typeorm";
import type { Request } from "express";
import { ClsModule } from "nestjs-cls";
import { LoggerModule } from "nestjs-pino";
import { randomUUID } from "node:crypto";
import { v7 as uuidv7 } from "uuid";
import { envSchema, type Env } from "./config.js";
import { Clock, IdGenerator, UnitOfWork } from "./domain/shared/ports.js";
import { Db } from "./outbound/postgres/db.js";
import { postgresOptions } from "./outbound/postgres/options.js";
import { TypeOrmUnitOfWork } from "./outbound/postgres/unit-of-work.js";

@Module({})
export class CoreModule {
  static forProcess(name: string): DynamicModule {
    return {
      module: CoreModule,
      global: true,
      imports: [
        ConfigModule.forRoot({ isGlobal: true, validationSchema: envSchema }),
        LoggerModule.forRootAsync({
          inject: [ConfigService],
          useFactory: (config: ConfigService<Env, true>) => ({
            pinoHttp: {
              level: config.get("LOG_LEVEL", { infer: true }),
              genReqId: (req) => req.id, // set by assignRequestId
              customAttributeKeys: { reqId: "request_id" },
              quietReqLogger: true,
              redact: ["req.headers.authorization", "req.headers.cookie", 'req.headers["webhook-signature"]'],
              autoLogging: { ignore: (req) => req.url?.startsWith("/health") ?? false },
            },
          }),
        }),
        TypeOrmModule.forRootAsync({
          inject: [ConfigService],
          useFactory: (config: ConfigService<Env, true>) => ({
            ...postgresOptions({
              url: config.get("DATABASE_URL", { infer: true }),
              applicationName: name,
              poolSize: config.get("DB_POOL_SIZE", { infer: true }),
              statementTimeoutMs: config.get("REQUEST_TIMEOUT_MS", { infer: true }),
            }),
            retryAttempts: 3, // not 10 × 3 s of a misconfigured instance booting
          }),
        }),
        ClsModule.forRoot({
          global: true,
          middleware: {
            mount: true,
            generateId: true,
            idGenerator: (req: Request) => (typeof req.id === "string" ? req.id : randomUUID()),
          },
          plugins: [
            new ClsPluginTransactional({
              imports: [TypeOrmModule],
              adapter: new TransactionalAdapterTypeOrm({ dataSourceToken: getDataSourceToken() }),
            }),
          ],
        }),
      ],
      providers: [
        Db,
        { provide: UnitOfWork, useClass: TypeOrmUnitOfWork },
        { provide: Clock, useValue: { now: () => new Date() } satisfies Clock },
        { provide: IdGenerator, useValue: { next: () => uuidv7() } satisfies IdGenerator }, // monotonic in a process
      ],
      exports: [Db, UnitOfWork, Clock, IdGenerator],
    };
  }
}
```

```ts file=src/app.module.ts
import { Module } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR, APP_PIPE } from "@nestjs/core";
import { TerminusModule } from "@nestjs/terminus";
import type { Env } from "./config.js";
import { CoreModule } from "./core.module.js";
import { ArticleService, ModerationService } from "./domain/publishing/article-service.js";
import { ArticleRepository, Inbox, Outbox } from "./domain/publishing/ports.js";
import { IdempotencyStore } from "./domain/shared/idempotency.js";
import { Clock, IdGenerator, UnitOfWork } from "./domain/shared/ports.js";
import { ArticlesController } from "./inbound/http/articles.controller.js";
import { BearerAuthGuard } from "./inbound/http/auth.js";
import { DeadlineInterceptor } from "./inbound/http/edge.js";
import { HealthController, ReadinessLatch } from "./inbound/http/health.js";
import { IdempotencyInterceptor } from "./inbound/http/idempotency.interceptor.js";
import { ProblemFilter } from "./inbound/http/problem.filter.js";
import { SchemaValidationPipe } from "./inbound/http/validation.pipe.js";
import { ModerationWebhookController, WebhookSignatureGuard } from "./inbound/webhooks/moderation.webhook.js";
import { TypeOrmArticleRepository } from "./outbound/postgres/article.repository.js";
import { SqlIdempotencyStore } from "./outbound/postgres/idempotency.store.js";
import { SqlInbox, SqlOutbox } from "./outbound/postgres/outbox-inbox.js";

@Module({
  controllers: [ArticlesController, ModerationWebhookController],
  providers: [
    { provide: ArticleRepository, useClass: TypeOrmArticleRepository },
    { provide: Outbox, useClass: SqlOutbox },
    { provide: Inbox, useClass: SqlInbox },
    { provide: IdempotencyStore, useClass: SqlIdempotencyStore },
    {
      provide: ArticleService,
      inject: [ArticleRepository, Outbox, UnitOfWork, Clock, IdGenerator],
      useFactory: (...deps: ConstructorParameters<typeof ArticleService>) => new ArticleService(...deps),
    },
    {
      provide: ModerationService,
      inject: [ArticleService, Inbox, UnitOfWork],
      useFactory: (...deps: ConstructorParameters<typeof ModerationService>) => new ModerationService(...deps),
    },
    IdempotencyInterceptor,
    WebhookSignatureGuard,
  ],
})
export class PublishingModule {}

@Module({
  imports: [
    CoreModule.forProcess("publishing-api"),
    TerminusModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<Env, true>) => ({ gracefulShutdownTimeoutMs: config.get("SHUTDOWN_DELAY_MS", { infer: true }) }),
    }),
    PublishingModule,
  ],
  controllers: [HealthController],
  providers: [
    ReadinessLatch,
    { provide: APP_INTERCEPTOR, useClass: DeadlineInterceptor },
    { provide: APP_GUARD, useClass: BearerAuthGuard },
    { provide: APP_PIPE, useClass: SchemaValidationPipe },
    { provide: APP_FILTER, useClass: ProblemFilter },
  ],
})
export class AppModule {}
```

## HTTP edge

```ts file=src/configure-app.ts
import type { NestApplicationOptions } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { Logger } from "nestjs-pino";
import type { Env } from "./config.js";
import { assignRequestId, requireJsonBody } from "./inbound/http/edge.js";

export const httpAppOptions: NestApplicationOptions = { bodyParser: false, rawBody: true, bufferLogs: true };

/** For main.ts and the test builder. */
export function configureApp(app: NestExpressApplication): NestExpressApplication {
  const config = app.get<ConfigService<Env, true>>(ConfigService);
  app.useLogger(app.get(Logger));
  app.use(assignRequestId);
  app.useSecurityHeaders();
  app.enableCors({
    origin: config.get("CORS_ORIGINS", { infer: true }),
    allowedHeaders: ["Authorization", "Content-Type", "Idempotency-Key", "If-Match", "X-Request-Id"],
    exposedHeaders: ["Location", "ETag", "Retry-After", "X-Request-Id", "Idempotent-Replayed"],
    maxAge: 600,
  });
  app.use(requireJsonBody); // 415
  app.useBodyParser("json", { limit: "64kb", type: ["application/json", "application/*+json"] }); // 413, 400
  return app;
}
```

## Entrypoints, shutdown and telemetry

```ts file=src/main.ts
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import type { NestExpressApplication } from "@nestjs/platform-express";
import type { Server } from "node:http";
import { AppModule } from "./app.module.js";
import type { Env } from "./config.js";
import { configureApp, httpAppOptions } from "./configure-app.js";
import { shutDownOnSignal } from "./shutdown.js";

const app = configureApp(await NestFactory.create<NestExpressApplication>(AppModule, httpAppOptions));
const config = app.get<ConfigService<Env, true>>(ConfigService);
const server: Server = await app.listen(config.get("PORT", { infer: true }), "0.0.0.0");
server.keepAliveTimeout = 65_000; // longer than the load balancer's idle timeout
server.headersTimeout = 66_000;
shutDownOnSignal(app, config.get("SHUTDOWN_DELAY_MS", { infer: true }) + config.get("REQUEST_TIMEOUT_MS", { infer: true }) + 3_000);
```

```ts file=src/shutdown.ts
import { Logger } from "@nestjs/common";
import { shutdownTelemetry } from "./telemetry.js";

// close() takes the signal at runtime; the interfaces omit the parameter.
type Closable = { close(signal?: string): Promise<void> };

/** Replaces enableShutdownHooks(): telemetry flushes last, under a failsafe timer. */
export function shutDownOnSignal(app: Closable, deadlineMs: number): void {
  const logger = new Logger("shutdown");
  const shutdown = async (signal: NodeJS.Signals) => {
    setTimeout(() => {
      logger.error(`still draining after ${deadlineMs} ms; exiting`);
      process.exit(1);
    }, deadlineMs).unref();
    await app.close(signal);
    await shutdownTelemetry();
    process.exit(0);
  };
  for (const signal of ["SIGTERM", "SIGINT"] as const) {
    process.once(signal, () => {
      shutdown(signal).catch((error: unknown) => {
        logger.error(error);
        process.exit(1);
      });
    });
  }
}
```

```ts file=src/telemetry.ts
import { register } from "node:module";
import { ExpressInstrumentation } from "@opentelemetry/instrumentation-express";
import { HttpInstrumentation } from "@opentelemetry/instrumentation-http";
import { NestInstrumentation } from "@opentelemetry/instrumentation-nestjs-core";
import { PgInstrumentation } from "@opentelemetry/instrumentation-pg";
import { PinoInstrumentation } from "@opentelemetry/instrumentation-pino";
import { NodeSDK } from "@opentelemetry/sdk-node";

register("@opentelemetry/instrumentation/hook.mjs", import.meta.url);

const sdk = new NodeSDK({
  instrumentations: [
    new HttpInstrumentation({ ignoreIncomingRequestHook: (req) => req.url?.startsWith("/health") ?? false }),
    new ExpressInstrumentation(),
    new NestInstrumentation(),
    new PgInstrumentation({ requireParentSpan: true }),
    new PinoInstrumentation({ disableLogSending: true }), // trace ids on stdout lines, no second log pipeline
  ],
});
sdk.start();

export const shutdownTelemetry = (): Promise<void> => sdk.shutdown();
```

```ts file=src/data-source.ts
import { DataSource } from "typeorm";
import { postgresOptions } from "./outbound/postgres/options.js";

// For the TypeORM CLI, against the build: npm run migrate.
export default new DataSource(postgresOptions({ url: process.env.DATABASE_URL ?? "", applicationName: "publishing-migrations" }));
```

## Worker

```ts file=src/worker.module.ts
import { Injectable, Logger, Module, type OnApplicationBootstrap, type OnModuleDestroy } from "@nestjs/common";
import { setTimeout as sleep } from "node:timers/promises";
import { CoreModule } from "./core.module.js";
import { IdempotencyStore } from "./domain/shared/idempotency.js";
import { SqlIdempotencyStore } from "./outbound/postgres/idempotency.store.js";
import { EventPublisher, OutboxRelay, RelayOptions, type OutboxMessage } from "./outbound/postgres/outbox-relay.js";

/** A placeholder: bind your broker adapter (Kafka, SNS, Pub/Sub, an HTTP sink). */
@Injectable()
export class LogEventPublisher extends EventPublisher {
  private readonly logger = new Logger("events");

  publish(message: OutboxMessage): Promise<void> {
    this.logger.log({ id: message.id, type: message.type, aggregateSeq: message.aggregateSeq }, "event published");
    return Promise.resolve();
  }
}

@Injectable()
export class BackgroundJobs implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(BackgroundJobs.name);
  private readonly stop = new AbortController();
  private loops: Promise<void>[] = [];

  constructor(
    private readonly relay: OutboxRelay,
    private readonly idempotency: IdempotencyStore,
  ) {}

  onApplicationBootstrap(): void {
    this.loops = [
      this.every(1_000, async () => (await this.relay.runOnce()) > 0), // busy: go again at once
      this.every(600_000, () => this.idempotency.purgeExpired().then(() => false)), // idempotent: replicas may overlap
    ];
  }

  async onModuleDestroy(): Promise<void> {
    this.stop.abort();
    await Promise.all(this.loops);
  }

  private async every(idleMs: number, task: () => Promise<boolean>): Promise<void> {
    while (!this.stop.signal.aborted) {
      const busy = await task().catch((error: unknown) => {
        this.logger.error({ err: error }, "background job failed");
        return false;
      });
      if (!busy) await sleep(idleMs, undefined, { signal: this.stop.signal }).catch(() => undefined);
    }
  }
}

@Module({
  imports: [CoreModule.forProcess("publishing-worker")],
  providers: [
    RelayOptions,
    OutboxRelay,
    BackgroundJobs,
    { provide: EventPublisher, useClass: LogEventPublisher },
    { provide: IdempotencyStore, useClass: SqlIdempotencyStore },
  ],
})
export class WorkerModule {}
```

```ts file=src/worker.ts
import { NestFactory } from "@nestjs/core";
import { Logger } from "nestjs-pino";
import { shutDownOnSignal } from "./shutdown.js";
import { WorkerModule } from "./worker.module.js";

// Any number of replicas: SKIP LOCKED keeps them apart.
const worker = await NestFactory.createApplicationContext(WorkerModule, { bufferLogs: true });
worker.useLogger(worker.get(Logger));
shutDownOnSignal(worker, 15_000);
```

## Test harness

`globalSetup` builds a fresh database and migrates it forward from empty; every suite then runs the production modules against it.

```ts file=test/support/global-setup.ts
import { DataSource } from "typeorm";
import { postgresOptions } from "../../src/outbound/postgres/options.js";

export default async function setup(): Promise<void> {
  const url = new URL(process.env.DATABASE_URL ?? "");
  const admin = new URL(url);
  admin.pathname = "/postgres";
  const server = await new DataSource({ type: "postgres", url: admin.toString() }).initialize();
  const name = url.pathname.slice(1);
  await server.query(`DROP DATABASE IF EXISTS "${name}" WITH (FORCE)`);
  await server.query(`CREATE DATABASE "${name}"`);
  await server.destroy();

  const db = await new DataSource(postgresOptions({ url: url.toString(), applicationName: "test-setup" })).initialize();
  await db.runMigrations();
  await db.destroy();
}
```

```ts file=test/support/harness.ts
import type { Type } from "@nestjs/common";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { Test, type TestingModuleBuilder } from "@nestjs/testing";
import { SignJWT } from "jose";
import { createHmac, randomUUID } from "node:crypto";
import { AppModule } from "../../src/app.module.js";
import { configureApp, httpAppOptions } from "../../src/configure-app.js";

/** The test builder: the production modules and edge, served by supertest without a port. */
export async function createApp(
  customize: (builder: TestingModuleBuilder) => TestingModuleBuilder = (builder) => builder,
  controllers: Type[] = [],
): Promise<NestExpressApplication> {
  const moduleRef = await customize(Test.createTestingModule({ imports: [AppModule], controllers })).compile();
  return configureApp(moduleRef.createNestApplication<NestExpressApplication>(httpAppOptions)).init();
}

export const draft = () => ({ slug: `post-${randomUUID().slice(0, 8)}`, title: "Hello", body: "" });

/** An Authorization header value from the hs256 test issuer. */
export async function bearer(claims: { sub: string; tid: string; roles?: string[] }): Promise<string> {
  const token = await new SignJWT({ tid: claims.tid, roles: claims.roles ?? [] })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(claims.sub)
    .setIssuer(process.env.JWT_ISSUER ?? "")
    .setAudience(process.env.JWT_AUDIENCE ?? "")
    .setExpirationTime("5m")
    .sign(new TextEncoder().encode(process.env.JWT_HS256_SECRET));
  return `Bearer ${token}`;
}

/** Standard Webhooks headers for `body`, signed with the configured secret. */
export function signWebhook(body: string, id: string, at: number) {
  const secret = Buffer.from((process.env.WEBHOOK_SECRETS ?? "").slice("whsec_".length), "base64");
  const signature = createHmac("sha256", secret).update(`${id}.${at}.${body}`).digest("base64");
  return { "Content-Type": "application/json", "webhook-id": id, "webhook-timestamp": String(at), "webhook-signature": `v1,${signature}` };
}
```

## PostgreSQL adapter tests

```ts file=test/adapters/postgres.spec.ts
import type { INestApplicationContext } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { setTimeout as sleep } from "node:timers/promises";
import { DataSource } from "typeorm";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createArticle } from "../../src/domain/publishing/article.js";
import { ArticleService } from "../../src/domain/publishing/article-service.js";
import { ArticleRepository, Outbox } from "../../src/domain/publishing/ports.js";
import { IdGenerator, UnitOfWork, type Actor } from "../../src/domain/shared/ports.js";
import { EventPublisher, OutboxRelay, RelayOptions, type OutboxMessage } from "../../src/outbound/postgres/outbox-relay.js";
import { createApp, draft } from "../support/harness.js";

let app: INestApplicationContext;
const actor = (): Actor => ({ tenantId: randomUUID(), subject: "ada", roles: [] });
const newArticle = (tenantId: string, now = new Date()) =>
  createArticle({ id: app.get(IdGenerator).next(), tenantId, authorId: "ada", ...draft() }, now);

beforeAll(async () => {
  app = await createApp();
});
afterAll(() => app.close());

describe("PostgreSQL adapters", () => {
  it("walks newest-first pages without duplicates or gaps when every row shares one now()", async () => {
    const [repo, { tenantId }, now] = [app.get(ArticleRepository), actor(), new Date()];
    const written = Array.from({ length: 7 }, () => newArticle(tenantId, now));
    await app.get(UnitOfWork).run(async () => {
      for (const article of written) await repo.insert(article);
    });
    for (const limit of [1, 2]) {
      const seen: string[] = [];
      let cursor: string | null = null;
      do {
        const page = await repo.list(tenantId, cursor, limit);
        seen.push(...page.items.map((a) => a.id));
        cursor = page.nextCursor;
      } while (cursor !== null);
      expect(seen).toEqual(written.map((a) => a.id).toSorted().toReversed());
    }
  });

  it("lets exactly one of two concurrent creates of a slug succeed", async () => {
    const [ada, input, service] = [actor(), draft(), app.get(ArticleService)];
    const results = await Promise.allSettled([service.create(ada, input), service.create(ada, input)]);
    expect(results.map((r) => r.status).toSorted()).toEqual(["fulfilled", "rejected"]);
    expect(results.find((r) => r.status === "rejected")?.reason).toMatchObject({ code: "already-exists" });
  });

  it("refuses a write conditioned on a version that moved", async () => {
    const [ada, service] = [actor(), app.get(ArticleService)];
    const article = await service.create(ada, draft());
    await service.update(ada, article.id, { title: "Second" });
    await expect(app.get(UnitOfWork).run(() => app.get(ArticleRepository).update(article, 1))).resolves.toBe(false);
  });

  it("publishes with exactly one outbox row, and not at all when that row fails", async () => {
    const [ada, service] = [actor(), app.get(ArticleService)];
    const { id } = await service.publish(ada, (await service.create(ada, draft())).id);
    const rows: unknown[] = await app.get(DataSource).query(`SELECT event_type, aggregate_seq FROM outbox WHERE aggregate_id = $1`, [id]);
    expect(rows).toEqual([{ event_type: "article.published", aggregate_seq: 2 }]);

    const sabotaged = await createApp((b) => b.overrideProvider(Outbox).useValue({ append: () => Promise.reject(new Error("outbox down")) }));
    const created = await sabotaged.get(ArticleService).create(ada, draft());
    await expect(sabotaged.get(ArticleService).publish(ada, created.id)).rejects.toThrow("outbox down");
    await sabotaged.close();
    await expect(service.get(ada, created.id)).resolves.toMatchObject({ status: "draft", version: 1 });
  });

  it("keeps another tenant's article invisible to get, list and publish", async () => {
    const service = app.get(ArticleService);
    const { id } = await service.create(actor(), draft());
    const intruder: Actor = { ...actor(), roles: ["editor"] };
    await expect(service.get(intruder, id)).rejects.toMatchObject({ kind: "not_found" });
    await expect(service.list(intruder, null, 100)).resolves.toMatchObject({ items: [] });
    await expect(service.publish(intruder, id)).rejects.toMatchObject({ kind: "not_found" });
  });

  it("fails a write that outlives its unit of work instead of autocommitting it", async () => {
    let late: Promise<void> | undefined;
    await app.get(UnitOfWork).run(async () => {
      late = sleep(20).then(() => app.get(ArticleRepository).insert(newArticle(randomUUID()))); // the bug: not awaited
    });
    await expect(late).rejects.toThrow("outside a unit of work");
  });

  it("retries the whole unit of work after a deadlock", async () => {
    let attempts = 0;
    const deadlock = Object.assign(new Error("deadlock detected"), { code: "40P01" });
    await expect(app.get(UnitOfWork).run(async () => (++attempts === 1 ? Promise.reject(deadlock) : attempts))).resolves.toBe(2);
  });
});

const enqueue = (aggregateId: string, seqs: number[]) =>
  app.get(DataSource).query(
    `INSERT INTO outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload)
     SELECT $1, 'article', $2, s, 'article.published', 1, '{}' FROM unnest($3::int[]) AS s`,
    [randomUUID(), aggregateId, seqs],
  );

describe("OutboxRelay", () => {
  const published: OutboxMessage[] = [];
  const failing = new Set<string>(); // aggregates whose first event the broker rejects
  const broker: EventPublisher = {
    publish: async (m) => {
      if (failing.has(m.aggregateId) && m.aggregateSeq === 1) throw new Error("broker down");
      published.push(m);
    },
  };
  const runOnce = () => new OutboxRelay(app.get(DataSource), broker, Object.assign(new RelayOptions(), { baseDelayMs: 0, maxAttempts: 3 })).runOnce();
  const seqsOf = (aggregateId: string) => published.filter((m) => m.aggregateId === aggregateId).map((m) => m.aggregateSeq);

  it("publishes one head per aggregate per pass, in aggregate_seq order", async () => {
    const [a, b] = [randomUUID(), randomUUID()];
    await enqueue(a, [3, 1, 2]);
    await enqueue(b, [1]);
    await runOnce();
    expect([seqsOf(a), seqsOf(b)]).toEqual([[1], [1]]);
    await runOnce();
    await runOnce();
    expect(seqsOf(a)).toEqual([1, 2, 3]);
  });

  it("dead-letters a head after maxAttempts, and only then releases the next event", async () => {
    const a = randomUUID();
    failing.add(a);
    await enqueue(a, [1, 2]);
    for (let pass = 0; pass < 3; pass++) await runOnce();
    expect(seqsOf(a)).toEqual([]);
    const [head]: unknown[] = await app.get(DataSource).query(
      `SELECT attempts, dead_lettered_at IS NOT NULL AS dead, last_error FROM outbox WHERE aggregate_id = $1 AND aggregate_seq = 1`,
      [a],
    );
    expect(head).toEqual({ attempts: 3, dead: true, last_error: "Error: broker down" });
    await runOnce();
    expect(seqsOf(a)).toEqual([2]);
  });
});
```

## HTTP tests

```ts file=test/http/api.http.spec.ts
import { Controller, Get, HttpException, Logger, NotFoundException, Param } from "@nestjs/common";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { ApiExcludeController } from "@nestjs/swagger";
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import request from "supertest";
import { DataSource } from "typeorm";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { envSchema } from "../../src/config.js";
import { Inbox } from "../../src/domain/publishing/ports.js";
import { Public } from "../../src/inbound/http/auth.js";
import { ReadinessLatch } from "../../src/inbound/http/health.js";
import { buildOpenApi } from "../../src/inbound/http/openapi.js";
import { bearer, createApp, draft, signWebhook } from "../support/harness.js";

/** Throws what handlers throw: a built-in exception keeps its status. */
@ApiExcludeController()
@Public()
@Controller("throws")
class ThrowingController {
  @Get(":status")
  throw(@Param("status") status: string): never {
    throw status === "404" ? new NotFoundException("no draft by that name") : new HttpException("thrown", Number(status));
  }
}

const type = (slug: string) => `${process.env.PROBLEM_BASE_URI}${slug}`;
const tenant = randomUUID();
let app: NestExpressApplication;
let [ada, bob, mallory] = ["", "", ""]; // the author; a member who is not; an editor in another tenant
let [draftId, liveId] = ["", ""];

const http = () => request(app.getHttpServer());
const as = (auth: string) => request.agent(app.getHttpServer()).set("Authorization", auth);
const create = (body: object = draft(), headers = {}) => as(ada).post("/v1/articles").set(headers).send(body);
const statusOf = async (id: string) => (await as(ada).get(`/v1/articles/${id}`)).body.data.status;
async function published(): Promise<string> {
  const { id } = (await create()).body.data;
  await as(ada).post(`/v1/articles/${id}/publish`);
  return id;
}

beforeAll(async () => {
  app = await createApp(undefined, [ThrowingController]);
  [ada, bob, mallory] = await Promise.all([
    bearer({ sub: "ada", tid: tenant }),
    bearer({ sub: "bob", tid: tenant }),
    bearer({ sub: "mallory", tid: randomUUID(), roles: ["editor"] }),
  ]);
  [draftId, liveId] = [(await create()).body.data.id, await published()];
});
afterAll(() => app.close());

describe("problem documents", () => {
  const cases: [number, string, () => request.Test, Record<string, string>?][] = [
    [401, "unauthenticated", () => http().get("/v1/articles"), { "www-authenticate": "Bearer" }],
    [401, "unauthenticated", () => as(`${ada}x`).get("/v1/articles"), { "www-authenticate": 'Bearer error="invalid_token"' }],
    [403, "forbidden", () => as(bob).patch(`/v1/articles/${draftId}`).send({ title: "Mine" })],
    [404, "not-found", () => as(mallory).get(`/v1/articles/${draftId}`)], // another tenant's
    [404, "not-found", () => as(ada).get("/v1/nope")],
    [405, "method-not-allowed", () => as(ada).delete(`/v1/articles/${draftId}`), { allow: "GET, PATCH" }],
    [400, "malformed-request", () => as(ada).post("/v1/articles").type("json").send('{"slug":')],
    [400, "malformed-request", () => as(ada).get("/v1/articles/42")],
    [400, "malformed-request", () => as(ada).get("/v1/articles?cursor=bm9wZQ")], // a cursor it never issued
    [409, "invalid-transition", () => as(ada).post(`/v1/articles/${liveId}/publish`)],
    [412, "precondition-failed", () => as(ada).patch(`/v1/articles/${draftId}`).set("If-Match", '"9"').send({})],
    [413, "payload-too-large", () => create({ ...draft(), body: "x".repeat(70_000) })],
    [415, "unsupported-media-type", () => as(ada).post("/v1/articles").type("text").send("hi")],
    [422, "validation-failed", () => create({ ...draft(), title: "a\u0000b" })], // a text column cannot hold U+0000
  ];

  it.each(cases)("%i %s (case %#)", async (status, slug, send, headers = {}) => {
    const res = await send();
    expect([res.status, res.headers["content-type"]]).toEqual([status, expect.stringMatching(/^application\/problem\+json/)]);
    expect(res.headers).toMatchObject({ ...headers, "x-request-id": expect.any(String) });
    expect(res.body).toMatchObject({ type: type(slug), status, title: expect.any(String), detail: expect.any(String) });
    expect(res.body.instance).toMatch(/^\/v1\/[\w/-]*$/); // the path, never the query string
  });

  it("points errors[] at the offending member or parameter", async () => {
    expect((await create({ ...draft(), tenant_id: tenant })).body.errors).toMatchObject([{ pointer: "#/tenant_id", code: "unrecognized_keys" }]);
    expect((await create({ ...draft(), slug: "Not A Slug" })).body.errors).toMatchObject([{ pointer: "#/slug", code: "invalid_format" }]);
    expect((await create([])).body.errors).toMatchObject([{ pointer: "#" }]); // the whole body
    expect((await as(ada).get("/v1/articles?limit=0")).body.errors).toEqual([{ parameter: "limit", detail: expect.any(String), code: "too_small" }]);
  });

  it("keeps the status of Nest's built-in exceptions and logs only server errors", async () => {
    const logged = vi.spyOn(Logger.prototype, "error");
    expect((await http().get("/throws/404")).body).toMatchObject({ status: 404, detail: "no draft by that name" }); // not a 405
    expect((await http().get("/throws/410")).body).toMatchObject({ status: 410, type: "about:blank", title: "Gone" });
    expect((await http().get("/throws/401")).headers["www-authenticate"]).toBe("Bearer");
    expect(logged).not.toHaveBeenCalled();
    expect((await http().get("/throws/502")).status).toBe(502);
    expect(logged).toHaveBeenCalledOnce();
    logged.mockRestore();
  });
});

describe("edge and articles", () => {
  it("sends CORS and X-Request-Id on every response, problems included", async () => {
    const res = await http().get("/v1/articles").set("Origin", "https://app.example.test");
    expect([res.status, res.headers["access-control-allow-origin"]]).toEqual([401, "https://app.example.test"]);
    expect((await as(ada).get("/v1/articles").set("X-Request-Id", "req-1.a")).headers["x-request-id"]).toBe("req-1.a");
    expect((await as(ada).get("/v1/articles").set("X-Request-Id", "<script>")).headers["x-request-id"]).toMatch(/^[\da-f-]{36}$/);
  });

  it("creates with 201 and Location, merge-patches under If-Match, clamps the page size", async () => {
    const created = await create();
    const path = `/v1/articles/${created.body.data.id}`;
    expect([created.status, created.headers]).toMatchObject([201, { location: path, etag: '"1"', "cache-control": "no-store" }]);
    const patched = await as(ada).patch(path).set("If-Match", '"1"').send({ body: null, title: "Renamed" });
    expect([patched.headers.etag, patched.body.data.body]).toEqual(['"2"', ""]); // null clears
    expect((await as(ada).patch(path).set("If-Match", '"7", "2"').send({ title: "Listed" })).status).toBe(200);
    expect((await as(ada).patch(path).send({ title: null })).status).toBe(422);
    expect((await as(ada).get("/v1/articles?limit=500")).body.meta).toMatchObject({ limit: 100 });
  });
});

const key = () => ({ "Idempotency-Key": randomUUID() });

describe("Idempotency-Key", () => {
  it("replays the stored response whatever the member order, and refuses a reused or malformed key", async () => {
    const [headers, { slug }] = [key(), draft()];
    const first = await create({ slug, title: "Once", body: "" }, headers);
    const replay = await create({ body: "", title: "Once", slug }, headers);
    expect([replay.status, replay.headers.location, replay.headers["idempotent-replayed"]]).toEqual([201, first.headers.location, "true"]);
    expect(replay.body).toEqual(first.body);
    expect((await create(draft(), headers)).body.type).toBe(type("idempotency-key-mismatch"));
    expect((await create(draft(), { "Idempotency-Key": "x".repeat(256) })).body.type).toBe(type("malformed-request"));
  });

  it("answers 409 + Retry-After while the first request holds the key", async () => {
    const [db, headers, body] = [app.get(DataSource), key(), draft()];
    const blocker = db.createQueryRunner(); // blocks inserts, so the first request waits inside its transaction
    await blocker.startTransaction();
    await blocker.query("LOCK TABLE articles IN SHARE MODE");
    const first = create(body, headers).then((res) => res); // then() sends it now
    const held = () => db.query(`SELECT 1 FROM idempotency_keys WHERE key = $1`, [headers["Idempotency-Key"]]);
    await vi.waitFor(async () => expect(await held()).toHaveLength(1));
    const second = await create(body, headers);
    expect([second.status, second.headers["retry-after"], second.body.type]).toEqual([409, "1", type("idempotency-in-flight")]);
    await blocker.rollbackTransaction();
    await blocker.release();
    expect((await first).status).toBe(201);
  });
});

const rejected = (id: string) => ({ tenant_id: tenant, article_id: id, verdict: "rejected" });
function deliver(payload: object, { messageId = randomUUID(), age = 0, to = app } = {}) {
  const body = JSON.stringify(payload);
  const signed = signWebhook(body, messageId, Math.floor(Date.now() / 1000) - age);
  return request(to.getHttpServer()).post("/internal/webhooks/moderation").set(signed).send(body);
}

describe("moderation webhook", () => {
  it("rejects a bad signature or a stale timestamp, and applies each webhook-id once", async () => {
    const [first, second, messageId] = [await published(), await published(), randomUUID()];
    const forged = await deliver(rejected(first)).set("webhook-signature", "v1,AAAA");
    expect([forged.status, forged.headers["content-type"]]).toEqual([401, expect.stringMatching(/problem\+json/)]);
    expect((await deliver(rejected(first), { age: 301 })).status).toBe(401);
    expect((await deliver(rejected(first), { messageId })).status).toBe(204);
    expect(await statusOf(first)).toBe("archived");
    // Same id, other payload: processing it again would archive the second article.
    expect((await deliver(rejected(second), { messageId })).status).toBe(204);
    expect(await statusOf(second)).toBe("published");
  });

  it("acknowledges what a redelivery cannot fix, and ignores added members", async () => {
    expect((await deliver(rejected(randomUUID()))).status).toBe(204); // unknown article
    expect((await deliver({ ...rejected(draftId), verdict: "escalated" })).status).toBe(204); // unusable payload
    const article = await published();
    expect((await deliver({ ...rejected(article), reason: "spam" })).status).toBe(204);
    expect(await statusOf(article)).toBe("archived");
  });

  it("answers 503 + Retry-After on a transient database failure, so the sender retries", async () => {
    const down = Object.assign(new Error("terminating connection due to administrator command"), { code: "57P01" });
    const failing = await createApp((b) => b.overrideProvider(Inbox).useValue({ claim: () => Promise.reject(down) }));
    const res = await deliver(rejected(liveId), { to: failing });
    await failing.close();
    expect([res.status, res.headers["retry-after"], res.body.type]).toEqual([503, "2", type("unavailable")]);
  });

  it("refuses at startup a secret that is not base64, which would decode to an empty key", () => {
    expect(envSchema.safeParse({ ...process.env, WEBHOOK_SECRETS: `whsec_${"!".repeat(32)}` }).success).toBe(false);
  });
});

describe("probes", () => {
  it("keeps liveness at 200 and readiness at 503 until the latch opens", async () => {
    class NeverReady extends ReadinessLatch {
      override async onApplicationBootstrap() {} // the startup check never completes
    }
    const starting = await createApp((b) => b.overrideProvider(ReadinessLatch).useClass(NeverReady));
    const [live, ready] = [await request(starting.getHttpServer()).get("/health/live"), await request(starting.getHttpServer()).get("/health/ready")];
    await starting.close();
    expect([live.status, ready.status, ready.headers["retry-after"], ready.body.type]).toEqual([200, 503, "2", type("unavailable")]);
  });

  it("answers readiness 503 while draining, and still serves traffic", async () => {
    const draining = await createApp();
    const url = await draining.listen(0).then(() => draining.getUrl());
    expect((await request(url).get("/health/ready")).status).toBe(200);
    const closing = (draining as { close(signal?: string): Promise<void> }).close("SIGTERM");
    await vi.waitFor(async () => expect((await request(url).get("/health/ready")).status).toBe(503));
    expect((await request(url).get("/health/live")).status).toBe(200);
    await closing;
  });
});

it("documents the API in OpenAPI: problems as application/problem+json, internal routes left out", async () => {
  const document = buildOpenApi(app);
  await writeFile("openapi.json", `${JSON.stringify(document, null, 2)}\n`); // committed; CI fails on a diff
  expect(document.paths["/v1/articles"]?.post?.responses).toMatchObject({
    201: { content: { "application/json": {} }, headers: { Location: {}, ETag: {}, "X-Request-Id": {} } },
    409: { content: { "application/problem+json": {} } },
  });
  expect(Object.keys(document.paths)).toEqual(["/v1/articles", "/v1/articles/{id}", "/v1/articles/{id}/publish"]);
});
```

## CI

```yaml file=.github/workflows/ci.yml
name: ci
on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:18
        env: { POSTGRES_PASSWORD: postgres }
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 2s --health-retries 15
    env:
      TEST_DATABASE_URL: postgres://postgres:postgres@localhost:5432/publishing_test
    steps:
      - uses: actions/checkout@v7
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v7
        with: { node-version: 24, cache: npm }
      - run: npm ci
      - run: npm run typecheck
      - run: npm run lint
      - name: Boundaries (fail on a violation, and on zero cruised modules)
        run: |
          set -o pipefail
          npm run --silent boundaries | tee boundaries.txt
          ! grep -q '(0 modules' boundaries.txt
      - run: npm test
      - name: OpenAPI committed, no breaking change against main
        run: |
          git diff --exit-code openapi.json
          git show origin/main:openapi.json > base.json
          docker run --rm -v "$PWD:/w" -w /w tufin/oasdiff breaking base.json openapi.json --fail-on ERR
      - name: Migrations forward from empty; the entities match them
        env: { DATABASE_URL: postgres://postgres:postgres@localhost:5432/publishing_ci }
        run: |
          psql postgres://postgres:postgres@localhost:5432/postgres -c "CREATE DATABASE publishing_ci"
          npm run build && npm run migrate && npm run migrate:check
```
