# NestJS examples: the service

What a new service needs: the app factory with its layer order, authentication, probes, configuration, the modules that compose it, logging and telemetry, the entrypoints with their shutdown, the manifest and the boundary check. Every `file=` block is a complete file of the project in `slice.md`.

## Contents

1. [App factory and layer order](#app-factory-and-layer-order)
2. [Authentication](#authentication)
3. [Probes](#probes)
4. [Configuration](#configuration)
5. [Composition](#composition)
6. [Telemetry](#telemetry)
7. [Entrypoints and shutdown](#entrypoints-and-shutdown)
8. [Manifest and tool configuration](#manifest-and-tool-configuration)
9. [Boundary check](#boundary-check)

## App factory and layer order

Express middleware registered here wraps everything Nest runs after it (`guide.md` § 3). The test builder calls the same function, so HTTP tests run the production edge.

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

```ts file=src/inbound/http/edge.ts
import { Injectable, type CallHandler, type ExecutionContext, type NestInterceptor } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import type { NextFunction, Request, Response } from "express";
import { randomUUID } from "node:crypto";
import { throwError, timeout, type Observable } from "rxjs";
import type { Env } from "../../config.js";
import { ProblemException } from "./problem.js";

export function assignRequestId(req: Request, res: Response, next: NextFunction): void {
  const inbound = req.header("x-request-id");
  req.id = inbound !== undefined && /^[A-Za-z0-9._:-]{1,128}$/.test(inbound) ? inbound : randomUUID();
  res.setHeader("X-Request-Id", req.id);
  next();
}

export function requireJsonBody(req: Request, _res: Response, next: NextFunction): void {
  const hasBody = req.headers["transfer-encoding"] !== undefined || Number(req.headers["content-length"] ?? 0) > 0;
  const json = /^application\/(?:[\w.-]+\+)?json\s*(?:;|$)/i.test(req.headers["content-type"] ?? "");
  next(hasBody && !json ? new ProblemException("unsupported-media-type", "send the body as application/json") : undefined);
}

@Injectable()
export class DeadlineInterceptor implements NestInterceptor {
  private readonly ms: number;

  constructor(config: ConfigService<Env, true>) {
    this.ms = config.get("REQUEST_TIMEOUT_MS", { infer: true });
  }

  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(timeout({ first: this.ms, with: () => throwError(expired) }));
  }
}

const expired = () => new ProblemException("unavailable", "the request deadline passed");
```

## Authentication

A global guard builds the `Actor`, and `@Public()` exempts probes and webhooks. A key source that cannot be reached answers 503, never 401.

```ts file=src/inbound/http/auth.ts
import { createParamDecorator, Injectable, type CanActivate, type ExecutionContext } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Reflector } from "@nestjs/core";
import type { Request, Response } from "express";
import { createRemoteJWKSet, errors, jwtVerify, type JWTVerifyGetKey, type JWTVerifyOptions } from "jose";
import { z } from "zod";
import type { Env } from "../../config.js";
import type { Actor } from "../../domain/shared/ports.js";
import { ProblemException } from "./problem.js";

declare module "express" {
  interface Request {
    actor?: Actor;
  }
}

export const Public = Reflector.createDecorator<boolean>({ transform: () => true });

const Claims = z.object({
  sub: z.string().min(1).max(255).refine((sub) => !sub.includes("\u0000")), // stored as author_id
  tid: z.uuid(),
  roles: z.array(z.string()).default([]),
});

@Injectable()
export class BearerAuthGuard implements CanActivate {
  private readonly keys: JWTVerifyGetKey;
  private readonly options: JWTVerifyOptions;

  constructor(
    private readonly reflector: Reflector,
    config: ConfigService<Env, true>,
  ) {
    const jwt = config.get("jwt", { infer: true });
    this.options = { issuer: jwt.issuer, audience: jwt.audience, requiredClaims: ["exp", "sub"], clockTolerance: 5 };
    if (jwt.mode === "jwks") {
      this.keys = remoteKeys(new URL(jwt.jwksUrl));
      this.options.algorithms = ["ES256", "EdDSA"];
    } else {
      const secret = new TextEncoder().encode(jwt.secret);
      this.keys = () => Promise.resolve(secret);
      this.options.algorithms = ["HS256"];
    }
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (this.reflector.getAllAndOverride(Public, [context.getHandler(), context.getClass()])) return true;
    const req = context.switchToHttp().getRequest<Request>();
    const token = /^Bearer +(\S+)$/i.exec(req.header("authorization") ?? "")?.[1];
    if (token === undefined) throw new ProblemException("unauthenticated", "a bearer token is required");
    req.actor = await this.verify(token);
    context.switchToHttp().getResponse<Response>().setHeader("Cache-Control", "no-store");
    return true;
  }

  private async verify(token: string): Promise<Actor> {
    try {
      const { payload } = await jwtVerify(token, this.keys, this.options);
      const claims = Claims.parse(payload);
      return { tenantId: claims.tid, subject: claims.sub, roles: claims.roles };
    } catch (error) {
      if (error instanceof KeySetUnavailable) throw new ProblemException("unavailable", "token keys are unavailable");
      throw new ProblemException("unauthenticated", "the access token is invalid or expired", {
        "WWW-Authenticate": 'Bearer error="invalid_token"',
      });
    }
  }
}

class KeySetUnavailable extends Error {}

function remoteKeys(url: URL): JWTVerifyGetKey {
  const keys = createRemoteJWKSet(url, { timeoutDuration: 2_000, cooldownDuration: 30_000 });
  return async (header, token) => {
    try {
      return await keys(header, token);
    } catch (error) {
      const tokenFault = [errors.JWKSNoMatchingKey, errors.JWKSMultipleMatchingKeys, errors.JOSENotSupported];
      if (tokenFault.some((type) => error instanceof type)) throw error;
      throw new KeySetUnavailable("the key set could not be fetched", { cause: error });
    }
  };
}

export const CurrentActor = createParamDecorator((_data: unknown, context: ExecutionContext): Actor => {
  const actor = context.switchToHttp().getRequest<Request>().actor;
  if (!actor) throw new Error("@CurrentActor() on a route without bearer auth");
  return actor;
});
```

## Probes

Readiness is a latch: one round-trip at startup, then local state. The same round-trip refuses a role that bypasses row-level security.

```ts file=src/inbound/http/health.ts
import { Controller, Get, Injectable, type BeforeApplicationShutdown, type OnApplicationBootstrap } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { ApiExcludeController } from "@nestjs/swagger";
import { setTimeout as sleep } from "node:timers/promises";
import { DataSource } from "typeorm";
import type { Env } from "../../config.js";
import { Public } from "./auth.js";
import { ProblemException } from "./problem.js";

/** A latch: one database round-trip at startup, then local state only. */
@Injectable()
export class Readiness implements OnApplicationBootstrap, BeforeApplicationShutdown {
  private state: "starting" | "ready" | "draining" = "starting";
  private readonly delayMs: number;

  constructor(
    private readonly db: DataSource,
    config: ConfigService<Env, true>,
  ) {
    this.delayMs = config.get("SHUTDOWN_DELAY_MS", { infer: true });
  }

  async onApplicationBootstrap(): Promise<void> {
    const pending = await this.db.showMigrations().catch((error: unknown) => {
      // On a database the release step never reached, TypeORM tries to create its bookkeeping table and app_rw may not.
      throw new Error("cannot read the migration history: run the release step first", { cause: error });
    });
    if (pending) throw new Error("pending migrations: run the release step first");
    // A superuser or BYPASSRLS role switches row-level security off without an error.
    const [role]: { bypass: boolean }[] = await this.db.query(
      `SELECT rolsuper OR rolbypassrls AS bypass FROM pg_roles WHERE rolname = current_user`,
    );
    if (role?.bypass !== false) throw new Error("the database role bypasses row-level security: connect as app_rw");
    this.state = "ready";
  }

  /** Runs before Nest closes the HTTP server: readiness answers 503 while the load balancer deregisters. */
  async beforeApplicationShutdown(signal?: string): Promise<void> {
    this.state = "draining";
    if (signal !== undefined) await sleep(this.delayMs);
  }

  check(): void {
    if (this.state !== "ready") throw new ProblemException("unavailable", `the instance is ${this.state}`);
  }
}

@ApiExcludeController()
@Public()
@Controller("health")
export class HealthController {
  constructor(private readonly readiness: Readiness) {}

  @Get("live")
  live() {
    return { status: "ok" };
  }

  @Get("ready")
  ready() {
    this.readiness.check();
    return { status: "ready" };
  }
}
```

## Configuration

Validated once at startup. The budget check keeps drain delay, deadline, pool close and telemetry flush inside the platform's grace period.

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

/** After the last request's deadline: the pool closes, then telemetry flushes. */
const CLOSE_MS = 2_000;
const FLUSH_MS = 1_000;

export const envSchema = z
  .object({
    APP_ENV: z.enum(["development", "test", "production"]).default("development"),
    PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
    LOG_LEVEL: z.enum(["debug", "info", "warn", "error", "silent"]).default("info"),
    DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/ }), // the application's role, app_rw: never the owner
    DB_POOL_SIZE: z.coerce.number().int().min(1).max(100).default(10),
    JWT_ISSUER: z.string().min(1),
    JWT_AUDIENCE: z.string().min(1),
    PROBLEM_BASE_URI: z.url().endsWith("/"),
    CORS_ORIGINS: list.pipe(z.array(z.url())).default([]),
    REQUEST_TIMEOUT_MS: z.coerce.number().int().min(100).max(30_000).default(5_000), // below the 60 s idempotency lease
    SHUTDOWN_DELAY_MS: z.coerce.number().int().min(0).max(20_000).default(0),
    SHUTDOWN_GRACE_MS: z.coerce.number().int().min(1_000).default(10_000), // what the platform grants after SIGTERM
    WEBHOOK_SECRETS: list.pipe(z.array(webhookSecret).min(1)),
  })
  .and(jwtMode)
  .refine((env) => env.APP_ENV !== "production" || env.JWT_MODE === "jwks", {
    path: ["JWT_MODE"],
    message: "hs256 is for development and tests; production verifies tokens against a JWKS",
  })
  .refine((env) => env.SHUTDOWN_DELAY_MS + env.REQUEST_TIMEOUT_MS + CLOSE_MS + FLUSH_MS <= env.SHUTDOWN_GRACE_MS, {
    path: ["SHUTDOWN_GRACE_MS"],
    message: "must cover SHUTDOWN_DELAY_MS + REQUEST_TIMEOUT_MS + 3 s (pool close, telemetry flush)",
  })
  .transform((env) => ({
    ...env,
    jwt:
      env.JWT_MODE === "jwks"
        ? { mode: "jwks" as const, jwksUrl: env.JWT_JWKS_URL, issuer: env.JWT_ISSUER, audience: env.JWT_AUDIENCE }
        : { mode: "hs256" as const, secret: env.JWT_HS256_SECRET, issuer: env.JWT_ISSUER, audience: env.JWT_AUDIENCE },
    shutdown: { drainMs: env.SHUTDOWN_DELAY_MS + env.REQUEST_TIMEOUT_MS + CLOSE_MS, flushMs: FLUSH_MS },
  }));

export type Env = z.output<typeof envSchema>;
```

## Composition

`CoreModule` holds what both processes need and is global. A feature module binds ports to adapters and builds the use cases with factories, so the domain carries no decorator.

```ts file=src/core.module.ts
import { Module, type DynamicModule } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { LoggerModule } from "nestjs-pino";
import { v7 as uuidv7 } from "uuid";
import { envSchema, type Env } from "./config.js";
import { UnitOfWork } from "./domain/publishing/ports.js";
import { Clock, IdGenerator } from "./domain/shared/ports.js";
import { postgresOptions } from "./outbound/postgres/options.js";
import { TypeOrmUnitOfWork } from "./outbound/postgres/unit-of-work.js";

/** Config, logging, the DataSource and the ports every process needs: global, for the API and the worker. */
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
      ],
      providers: [
        { provide: UnitOfWork, useClass: TypeOrmUnitOfWork },
        { provide: Clock, useValue: { now: () => new Date() } satisfies Clock },
        { provide: IdGenerator, useValue: { next: () => uuidv7() } satisfies IdGenerator }, // monotonic within a process
      ],
      exports: [UnitOfWork, Clock, IdGenerator],
    };
  }
}
```

```ts file=src/app.module.ts
import { Module } from "@nestjs/common";
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR, APP_PIPE } from "@nestjs/core";
import { CoreModule } from "./core.module.js";
import { UnitOfWork } from "./domain/publishing/ports.js";
import { Moderation, Publishing } from "./domain/publishing/use-cases.js";
import { IdempotencyStore } from "./domain/shared/idempotency.js";
import { Clock, IdGenerator } from "./domain/shared/ports.js";
import { ArticlesController } from "./inbound/http/articles.controller.js";
import { BearerAuthGuard } from "./inbound/http/auth.js";
import { DeadlineInterceptor } from "./inbound/http/edge.js";
import { HealthController, Readiness } from "./inbound/http/health.js";
import { IdempotencyInterceptor } from "./inbound/http/idempotency.interceptor.js";
import { ProblemFilter } from "./inbound/http/problem.filter.js";
import { SchemaValidationPipe } from "./inbound/http/validation.pipe.js";
import { ModerationWebhookController, WebhookSignatureGuard } from "./inbound/webhooks/moderation.webhook.js";
import { SqlIdempotencyStore } from "./outbound/postgres/idempotency.store.js";

/** Ports to adapters, and the use cases built by factories: the domain carries no decorator. */
@Module({
  controllers: [ArticlesController, ModerationWebhookController],
  providers: [
    { provide: IdempotencyStore, useClass: SqlIdempotencyStore },
    {
      provide: Publishing,
      inject: [UnitOfWork, Clock, IdGenerator],
      useFactory: (...deps: ConstructorParameters<typeof Publishing>) => new Publishing(...deps),
    },
    {
      provide: Moderation,
      inject: [Publishing, UnitOfWork],
      useFactory: (...deps: ConstructorParameters<typeof Moderation>) => new Moderation(...deps),
    },
    IdempotencyInterceptor,
    WebhookSignatureGuard,
  ],
})
export class PublishingModule {}

@Module({
  imports: [CoreModule.forProcess("publishing-api"), PublishingModule],
  controllers: [HealthController],
  providers: [
    Readiness,
    { provide: APP_INTERCEPTOR, useClass: DeadlineInterceptor },
    { provide: APP_GUARD, useClass: BearerAuthGuard },
    { provide: APP_PIPE, useClass: SchemaValidationPipe },
    { provide: APP_FILTER, useClass: ProblemFilter },
  ],
})
export class AppModule {}
```

## Telemetry

Preloaded with `node --import`, so the instrumentations patch `http`, `express` and `pg` before the application loads them. Exporters come from the `OTEL_*` variables.

```ts file=src/telemetry.ts
import { setTimeout as sleep } from "node:timers/promises";
import { ExpressInstrumentation } from "@opentelemetry/instrumentation-express";
import { HttpInstrumentation } from "@opentelemetry/instrumentation-http";
import { PgInstrumentation } from "@opentelemetry/instrumentation-pg";
import { PinoInstrumentation } from "@opentelemetry/instrumentation-pino";
import { NodeSDK } from "@opentelemetry/sdk-node";
import { register } from "import-in-the-middle/register-hooks.mjs";

// Preloaded with `node --import`, so this runs before the application's modules load. The loader hook lets
// the Express instrumentation patch `express` as the ESM-only Nest packages import it: without it the
// server span has no route. In-thread hooks: module.register() is deprecated.
register();

const sdk = new NodeSDK({
  instrumentations: [
    new HttpInstrumentation({ ignoreIncomingRequestHook: (req) => req.url?.startsWith("/health") ?? false }),
    new ExpressInstrumentation(),
    new PgInstrumentation({ requireParentSpan: true }),
    new PinoInstrumentation({ disableLogSending: true }), // trace ids on stdout lines, no second log pipeline
  ],
});
sdk.start();

/** Bounded, and never the reason for a failed exit: a collector that does not answer holds the flush for seconds. */
export const shutdownTelemetry = (ms: number): Promise<unknown> => Promise.race([sdk.shutdown().catch(() => undefined), sleep(ms)]);
```

## Entrypoints and shutdown

The API process and the worker. Both shut down through one function that runs Nest's hooks in order and bounds every step.

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
shutDownOnSignal(app, config.get("shutdown", { infer: true }));
```

```ts file=src/worker.ts
import { NestFactory } from "@nestjs/core";
import { Logger } from "nestjs-pino";
import { shutDownOnSignal } from "./shutdown.js";
import { WorkerModule } from "./worker.module.js";

// Any number of replicas: SKIP LOCKED keeps them apart.
const worker = await NestFactory.createApplicationContext(WorkerModule, { bufferLogs: true });
worker.useLogger(worker.get(Logger));
shutDownOnSignal(worker, { drainMs: 14_000, flushMs: 1_000 });
```

```ts file=src/shutdown.ts
import { Logger } from "@nestjs/common";
import { shutdownTelemetry } from "./telemetry.js";

// close() takes the signal at runtime; the interfaces omit the parameter.
type Closable = { close(signal?: string): Promise<void> };

/**
 * Replaces enableShutdownHooks(): close(signal) runs Nest's hooks in order, telemetry flushes last, and a
 * failsafe timer ends a drain that outlives its budget.
 */
export function shutDownOnSignal(app: Closable, budget: { drainMs: number; flushMs: number }): void {
  const logger = new Logger("shutdown");
  const shutdown = async (signal: NodeJS.Signals) => {
    const failsafe = setTimeout(() => {
      logger.error(`still draining after ${budget.drainMs} ms; exiting`);
      process.exit(1);
    }, budget.drainMs);
    await app.close(signal);
    clearTimeout(failsafe);
    await shutdownTelemetry(budget.flushMs);
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

The release step's DataSource. It connects as the owning role through its own URL, which the application never reads.

```ts file=src/data-source.ts
import { DataSource } from "typeorm";
import { postgresOptions } from "./outbound/postgres/options.js";

// The release step, through its own URL as the owning role: npm run migrate. The application never holds this URL.
export default new DataSource(postgresOptions({ url: process.env.MIGRATION_DATABASE_URL ?? "", applicationName: "publishing-migrations" }));
```

## Manifest and tool configuration

```json file=package.json
{
  "name": "publishing-api",
  "private": true,
  "type": "module",
  "engines": {
    "node": "^22.22.3 || ^24.11.1 || >=26.0.0"
  },
  "scripts": {
    "build": "tsc -p tsconfig.build.json",
    "start": "node --import ./dist/telemetry.js dist/main.js",
    "start:worker": "node --import ./dist/telemetry.js dist/worker.js",
    "migrate": "typeorm migration:run -d dist/data-source.js",
    "migrate:check": "typeorm migration:generate -d dist/data-source.js --check src/migrations/drift",
    "typecheck": "tsc --noEmit",
    "lint": "oxlint --type-aware --deny-warnings src test",
    "boundaries": "node scripts/boundaries.mjs",
    "test": "vitest run"
  },
  "dependencies": {
    "@nestjs/common": "^12.5.1",
    "@nestjs/config": "^12.1.1",
    "@nestjs/core": "^12.5.1",
    "@nestjs/platform-express": "^12.5.1",
    "@nestjs/swagger": "^12.1.2",
    "@nestjs/typeorm": "^12.0.3",
    "@opentelemetry/api": "^1.10.0",
    "@opentelemetry/instrumentation-express": "^0.73.0",
    "@opentelemetry/instrumentation-http": "^0.301.2",
    "@opentelemetry/instrumentation-pg": "^0.78.0",
    "@opentelemetry/instrumentation-pino": "^0.71.0",
    "@opentelemetry/sdk-node": "^0.301.2",
    "import-in-the-middle": "^3.6.0",
    "jose": "^6.2.17",
    "nestjs-pino": "^5.3.2",
    "pg": "^8.23.1",
    "pino": "^10.4.0",
    "pino-http": "^11.0.0",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.2",
    "typeorm": "^1.1.3",
    "uuid": "^14.0.3",
    "zod": "^4.6.7"
  },
  "devDependencies": {
    "@nestjs/testing": "^12.5.1",
    "@types/express": "^5.0.6",
    "@types/node": "^26.6.6",
    "@types/supertest": "^7.2.1",
    "dependency-cruiser": "^18.8.0",
    "oxlint": "^1.94.0",
    "oxlint-tsgolint": "^7.0.2007",
    "supertest": "^7.3.2",
    "typescript": "~6.0.3",
    "vite": "^8.3.8",
    "vitest": "^5.1.0"
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

```json file=.oxlintrc.json
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

## Boundary check

Run as `npm run boundaries`. It prints what to do about each violation and fails when it examined no modules.

```js file=scripts/boundaries.mjs
// The boundary check: dependencies point inward. Nest resolves wiring at runtime, so only this catches a leaked import.
import { cruise } from "dependency-cruiser";

const forbidden = [
  {
    name: "domain-imports-only-domain",
    comment:
      "The domain imports nothing outside src/domain: no framework, ORM, driver, SDK or Node built-in. " +
      "Declare a port in the domain and implement it under src/outbound, or pass the value in as an argument.",
    severity: "error",
    from: { path: "^src/domain/" },
    to: { pathNot: "^src/domain/" },
  },
  {
    name: "adapters-meet-only-through-ports",
    comment:
      "Inbound and outbound adapters never import each other. Depend on the port in src/domain, " +
      "and let a module (src/*.module.ts) bind the adapter to it.",
    severity: "error",
    from: { path: "^src/(inbound|outbound)/" },
    to: { path: "^src/(inbound|outbound)/", pathNot: "^src/$1/" },
  },
  {
    name: "no-circular",
    comment: "Break the cycle by moving what both sides need into the module that changes least.",
    severity: "error",
    from: {},
    to: { circular: true },
  },
];

const { output } = await cruise(["src"], {
  validate: true,
  ruleSet: { forbidden },
  tsPreCompilationDeps: true, // `import type` counts: a type-only import of an ORM type is still a leak
  tsConfig: { fileName: "tsconfig.json" },
  doNotFollow: { path: "node_modules" },
});
const { totalCruised, violations } = output.summary;
for (const { rule, from, to } of violations) {
  const fix = forbidden.find((candidate) => candidate.name === rule.name)?.comment ?? "";
  console.error(`${rule.name}: ${from} imports ${to}\n  ${fix}`);
}
console.log(`${totalCruised} modules checked, ${violations.length} violation(s)`);
// Zero modules means the check ran on nothing (a wrong path, or a TypeScript without the compiler API): fail.
if (totalCruised === 0 || violations.length > 0) process.exit(1);
```
