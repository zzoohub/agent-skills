# Hono examples — bootstrap, operability and tests

App factory, configuration, telemetry, entrypoints, tool configuration, tests and CI. Each `file=` block is a complete file of the verified project.

## Contents

1. [App factory](#app-factory)
2. [Configuration, logging, telemetry, wiring](#configuration-logging-telemetry-wiring)
3. [Entrypoints](#entrypoints)
4. [Project and tool configuration](#project-and-tool-configuration)
5. [Test harness](#test-harness)
6. [Adapter tests on PostgreSQL](#adapter-tests-on-postgresql)
7. [HTTP tests](#http-tests)
8. [Configuration tests](#configuration-tests)
9. [CI](#ci)

## App factory

```ts file=src/inbound/http/app.ts
import { OpenAPIHono } from "@hono/zod-openapi";
import type { MiddlewareHandler } from "hono";
import { bodyLimit } from "hono/body-limit";
import { cors } from "hono/cors";
import { HTTPException } from "hono/http-exception";
import { methodNotAllowed } from "hono/method-not-allowed";
import { routePath } from "hono/route";
import { secureHeaders } from "hono/secure-headers";
import { timeout } from "hono/timeout";
import { moderationWebhook } from "../webhooks/moderation.ts";
import { articleRoutes } from "./articles.ts";
import { type AuthConfig, authenticate } from "./auth.ts";
import type { AppEnv, Logger } from "./env.ts";
import { probes, type Readiness } from "./health.ts";
import { ProblemError, renderProblem, toProblem, validationProblem } from "./problem.ts";

export type AppDeps = Readonly<{
  logger: Logger;
  problemBase: string;
  corsOrigins: readonly string[];
  requestTimeoutMs: number;
  auth: AuthConfig;
  webhookSecrets: readonly string[];
  /** Sets c.var.services: a singleton on Node, per request on Workers. */
  provide: MiddlewareHandler<AppEnv>;
  /** Absent where the platform has no probes. */
  readiness?: Readiness | undefined;
  /** Server spans and HTTP metrics (@hono/otel). */
  telemetry?: MiddlewareHandler | undefined;
}>;

const REQUEST_ID = /^[A-Za-z0-9._:-]{1,128}$/u;

export function createApp(deps: AppDeps): OpenAPIHono<AppEnv> {
  const app = new OpenAPIHono<AppEnv>({
    defaultHook: (result) => {
      if (!result.success) throw validationProblem(result.error, result.target);
    },
  });
  if (deps.telemetry) app.use(deps.telemetry);
  app.use(async (c, next) => {
    const sent = c.req.header("x-request-id");
    const requestId = sent !== undefined && REQUEST_ID.test(sent) ? sent : crypto.randomUUID();
    c.set("log", deps.logger.child({ request_id: requestId }));
    const started = performance.now();
    await next();
    c.header("X-Request-Id", requestId);
    // Draining: no kept-alive socket outlives its response, so server.close() ends in time.
    if (deps.readiness?.state === "draining") c.header("Connection", "close");
    c.var.log.info({ method: c.req.method, route: routePath(c), status: c.res.status, ms: Math.round(performance.now() - started) }, "request");
  });
  app.use(
    cors({
      origin: [...deps.corsOrigins],
      allowMethods: ["GET", "POST", "PATCH"],
      allowHeaders: ["Authorization", "Content-Type", "Idempotency-Key", "If-Match", "X-Request-Id"],
      exposeHeaders: ["Location", "ETag", "Retry-After", "X-Request-Id"],
      maxAge: 600,
    }),
  );
  app.use(secureHeaders({ xFrameOptions: "DENY", contentSecurityPolicy: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] } }));
  app.use(
    methodNotAllowed({
      app,
      onMethodNotAllowed: (c, methods) =>
        renderProblem(c, deps.problemBase, new ProblemError("method-not-allowed", `${c.req.method} is not supported here`, { headers: { Allow: methods.join(", ") } })),
    }),
  );
  app.route("/", probes(deps.readiness));
  app.use(timeout(deps.requestTimeoutMs, () => new HTTPException(503, { message: "The request deadline passed" })));
  app.use(
    bodyLimit({
      maxSize: 64 * 1024,
      onError: () => {
        throw new ProblemError("payload-too-large", "The request body exceeds 64 KiB");
      },
    }),
  );
  app.use(deps.provide);
  app.use("/v1/*", authenticate(deps.auth));
  app.route("/v1/articles", articleRoutes());
  app.route("/", moderationWebhook(deps.webhookSecrets));
  app.openAPIRegistry.registerComponent("securitySchemes", "bearerAuth", { type: "http", scheme: "bearer", bearerFormat: "JWT" });
  app.doc31("/openapi.json", { openapi: "3.1.0", info: { title: "Publishing API", version: "1.0.0" } });
  app.notFound((c) => renderProblem(c, deps.problemBase, new ProblemError("not-found", `No route matches ${c.req.method} ${c.req.path}`)));
  app.onError((err, c) => {
    const problem = toProblem(err);
    if (problem.type === "internal") c.var.log.error({ err }, "unhandled error");
    return renderProblem(c, deps.problemBase, problem);
  });
  return app;
}
```

## Configuration, logging, telemetry, wiring

```ts file=src/app/config.ts
import { z } from "zod";
import type { AuthConfig } from "../inbound/http/auth.ts";

const csv = (item: z.ZodType<string, string>, min = 0) =>
  z.string().default("").transform((v) => v.split(",").map((s) => s.trim()).filter((s) => s !== "")).pipe(z.array(item).min(min));
const ms = (fallback: number) => z.coerce.number().int().min(0).default(fallback);
/** Browsers send a bare origin: "https://app.example/" or an uppercase host would never match. */
const origin = z.string().refine((o) => URL.canParse(o) && new URL(o).origin === o, "must be an origin, e.g. https://app.example");
/** Standard Webhooks: whsec_ + padded base64 of at least 24 bytes. */
const webhookSecret = z
  .string()
  .regex(/^whsec_(?:[A-Za-z0-9+/]{4})+(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/u, "must be whsec_ + base64")
  .refine((s) => Buffer.from(s.slice(6), "base64").length >= 24, "must decode to >= 24 bytes");
/** Pool close and telemetry flush, each. */
const CLOSE_MS = 500;

const Env = z
  .object({
    APP_ENV: z.enum(["development", "test", "production"]), // no default: unset must not mean development
    PORT: z.coerce.number().int().min(1).max(65_535).default(8080),
    LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
    DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/u }),
    DB_POOL_MAX: z.coerce.number().int().min(1).default(10),
    JWT_MODE: z.enum(["jwks", "hs256"]),
    JWT_JWKS_URL: z.url().optional(),
    JWT_ISSUER: z.string().min(1),
    JWT_AUDIENCE: z.string().min(1),
    JWT_HS256_SECRET: z.string().optional(),
    PROBLEM_BASE_URI: z.url().refine((uri) => uri.endsWith("/"), "must end with /"),
    CORS_ORIGINS: csv(origin),
    REQUEST_TIMEOUT_MS: ms(8_000).pipe(z.number().min(1_000)),
    DRAIN_DELAY_MS: ms(0),
    SHUTDOWN_GRACE_MS: ms(10_000),
    WEBHOOK_SECRETS: csv(webhookSecret, 1),
    EVENTS_URL: z.url().optional(),
  })
  .superRefine((env, ctx) => {
    const fail = (path: string, message: string) => {
      ctx.addIssue({ code: "custom", path: [path], message });
    };
    const production = env.APP_ENV === "production";
    if (env.JWT_MODE === "jwks" && env.JWT_JWKS_URL === undefined) fail("JWT_JWKS_URL", "required when JWT_MODE=jwks");
    if (production && env.JWT_JWKS_URL?.startsWith("https://") === false) fail("JWT_JWKS_URL", "must be https");
    if (production && env.JWT_MODE === "hs256") fail("JWT_MODE", "hs256 is for development and tests");
    if (env.JWT_MODE === "hs256" && Buffer.byteLength(env.JWT_HS256_SECRET ?? "") < 32) fail("JWT_HS256_SECRET", "needs >= 32 bytes");
    // Drain delay, then the last request's deadline, then pool close and telemetry flush.
    if (env.DRAIN_DELAY_MS + env.REQUEST_TIMEOUT_MS + 2 * CLOSE_MS >= env.SHUTDOWN_GRACE_MS) {
      fail("SHUTDOWN_GRACE_MS", "must exceed DRAIN_DELAY_MS + REQUEST_TIMEOUT_MS + 1 s (pool close, telemetry flush)");
    }
  });

export function loadConfig(source: Record<string, unknown>) {
  const parsed = Env.safeParse(source);
  if (!parsed.success) throw new Error(`Invalid configuration:\n${z.prettifyError(parsed.error)}`);
  const env = parsed.data;
  const jwt = { issuer: env.JWT_ISSUER, audience: env.JWT_AUDIENCE };
  const auth: AuthConfig =
    env.JWT_MODE === "jwks"
      ? { ...jwt, mode: "jwks", jwksUrl: new URL(env.JWT_JWKS_URL ?? "") }
      : { ...jwt, mode: "hs256", secret: env.JWT_HS256_SECRET ?? "" };
  return {
    port: env.PORT,
    logLevel: env.LOG_LEVEL,
    db: {
      url: env.DATABASE_URL,
      poolMax: env.DB_POOL_MAX,
      statementTimeoutMs: Math.min(5_000, env.REQUEST_TIMEOUT_MS),
      transactionTimeoutMs: env.REQUEST_TIMEOUT_MS,
      applicationName: "publishing-api",
    },
    auth,
    problemBase: env.PROBLEM_BASE_URI,
    corsOrigins: env.CORS_ORIGINS,
    requestTimeoutMs: env.REQUEST_TIMEOUT_MS,
    idempotencyLeaseMs: 3 * env.REQUEST_TIMEOUT_MS,
    drainDelayMs: env.DRAIN_DELAY_MS,
    shutdownGraceMs: env.SHUTDOWN_GRACE_MS,
    closeTimeoutMs: CLOSE_MS,
    webhookSecrets: env.WEBHOOK_SECRETS,
    eventsUrl: env.EVENTS_URL,
  };
}
```

```ts file=src/app/logger.ts
import { trace } from "@opentelemetry/api";
import pino from "pino";

export function createLogger(level: string): pino.Logger {
  return pino({
    level,
    base: { service: "publishing-api" },
    timestamp: pino.stdTimeFunctions.isoTime,
    formatters: { level: (label) => ({ level: label }) },
    redact: { paths: ["authorization", "*.authorization", "*.password", "*.secret", "*.token", "*.cookie"], censor: "[redacted]" },
    mixin: () => {
      const span = trace.getActiveSpan()?.spanContext();
      return span ? { trace_id: span.traceId, span_id: span.spanId } : {};
    },
  });
}
```

Exporters come from the `OTEL_*` variables.

```ts file=src/app/telemetry.ts
import { setTimeout as sleep } from "node:timers/promises";
import { PgInstrumentation } from "@opentelemetry/instrumentation-pg";
import { UndiciInstrumentation } from "@opentelemetry/instrumentation-undici";
import { NodeSDK } from "@opentelemetry/sdk-node";

const sdk = new NodeSDK({
  serviceName: process.env.OTEL_SERVICE_NAME ?? "publishing-api",
  instrumentations: [new PgInstrumentation({ requireParentSpan: true }), new UndiciInstrumentation()],
});
sdk.start();

/** Bounded wait: an unreachable collector would hold the flush for its exporter's 30 s timeout. */
export const within = (ms: number, work: Promise<unknown>): Promise<unknown> => Promise.race([work, sleep(ms)]);
export const shutdownTelemetry = (ms: number): Promise<unknown> => within(ms, sdk.shutdown());
```

```ts file=src/app/services.ts
import type { UnitOfWork } from "../domain/publishing/ports.ts";
import { Publishing } from "../domain/publishing/use-cases.ts";
import type { Services } from "../inbound/http/env.ts";
import { PgArticles } from "../outbound/postgres/articles.ts";
import type { Db } from "../outbound/postgres/db.ts";
import { PgIdempotencyStore } from "../outbound/postgres/idempotency.ts";
import { PgUnitOfWork } from "../outbound/postgres/unit-of-work.ts";
import { systemClock, uuidv7Ids } from "../outbound/system.ts";

export function buildServices(db: Db, opts: { idempotencyLeaseMs: number; uow?: UnitOfWork }): Services {
  const uow = opts.uow ?? new PgUnitOfWork(db);
  const publishing = new Publishing({ uow, reader: new PgArticles(() => db), clock: systemClock, ids: uuidv7Ids });
  return { publishing, uow, idempotency: new PgIdempotencyStore(db, { leaseMs: opts.idempotencyLeaseMs }) };
}
```

## Entrypoints

```ts file=src/app/main.ts
import { once } from "node:events";
import { setTimeout as sleep } from "node:timers/promises";
import { serve } from "@hono/node-server";
import { httpInstrumentationMiddleware } from "@hono/otel";
import { sql } from "drizzle-orm";
import { createApp } from "../inbound/http/app.ts";
import { Readiness } from "../inbound/http/health.ts";
import { connectPostgres } from "../outbound/postgres/db.ts";
import { loadConfig } from "./config.ts";
import { createLogger } from "./logger.ts";
import { buildServices } from "./services.ts";
import { shutdownTelemetry, within } from "./telemetry.ts";

const config = loadConfig(process.env);
const log = createLogger(config.logLevel);
const { pool, db } = connectPostgres(config.db, (err) => {
  log.warn({ err }, "idle database client failed");
});
const services = buildServices(db, config);
const readiness = new Readiness();
const app = createApp({
  ...config,
  logger: log,
  readiness,
  telemetry: httpInstrumentationMiddleware({ serviceName: "publishing-api" }),
  provide: async (c, next) => {
    c.set("services", services);
    await next();
  },
});

await db.execute(sql`select 1`); // the one startup round-trip; failing it fails the boot
readiness.ready();
const server = serve({ fetch: app.fetch, port: config.port });
log.info({ port: config.port }, "listening");

async function shutdown(signal: string): Promise<void> {
  log.info({ signal }, "draining");
  readiness.drain(); // /ready answers 503; responses now carry Connection: close
  setTimeout(() => process.exit(1), config.shutdownGraceMs - 250).unref(); // failsafe
  await sleep(config.drainDelayMs);
  server.close(); // stop accepting; idle sockets close now, busy ones after their response
  await within(config.requestTimeoutMs, once(server, "close"));
  await within(config.closeTimeoutMs, pool.end());
  await shutdownTelemetry(config.closeTimeoutMs);
  process.exit(0);
}

for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.once(signal, () => {
    shutdown(signal).catch((err: unknown) => {
      log.error({ err }, "shutdown failed");
      process.exit(1);
    });
  });
}
```

```ts file=src/app/relay.ts
import { setTimeout as sleep } from "node:timers/promises";
import { metrics } from "@opentelemetry/api";
import { connectPostgres } from "../outbound/postgres/db.ts";
import { PgIdempotencyStore } from "../outbound/postgres/idempotency.ts";
import { OutboxRelay } from "../outbound/postgres/outbox.ts";
import { HttpEventPublisher } from "../outbound/system.ts";
import { loadConfig } from "./config.ts";
import { createLogger } from "./logger.ts";
import { shutdownTelemetry, within } from "./telemetry.ts";

const config = loadConfig(process.env);
const log = createLogger(config.logLevel);
if (config.eventsUrl === undefined) throw new Error("EVENTS_URL is required by the relay");
const { pool, db } = connectPostgres({ ...config.db, applicationName: "publishing-relay" }, (err) => {
  log.warn({ err }, "idle database client failed");
});
const relay = new OutboxRelay(db, new HttpEventPublisher(config.eventsUrl));
const keys = new PgIdempotencyStore(db, { leaseMs: config.idempotencyLeaseMs });
const meter = metrics.getMeter("publishing");
const [lag, dead] = [meter.createGauge("outbox.oldest_pending_age", { unit: "s" }), meter.createGauge("outbox.dead_lettered")];
const stop = new AbortController();
const pause = (ms: number) => sleep(ms, undefined, { signal: stop.signal }).catch(() => {});
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.once(signal, () => {
    stop.abort(); // stop claiming; the pass in progress hands its unpublished claims back
  });
}

let nextPurge = 0;
while (!stop.signal.aborted) {
  try {
    const claimed = await relay.runOnce(stop.signal);
    const stats = await relay.stats();
    lag.record(stats.oldestPendingSeconds);
    dead.record(stats.deadLettered);
    if (Date.now() >= nextPurge) {
      log.info({ purged: await keys.purgeExpired() }, "expired idempotency keys purged");
      nextPurge = Date.now() + 3_600_000;
    }
    if (claimed === 0) await pause(1_000);
  } catch (err) {
    log.error({ err }, "relay pass failed");
    await pause(5_000);
  }
}
await within(config.closeTimeoutMs, pool.end());
await shutdownTelemetry(config.closeTimeoutMs);
process.exit(0);
```

```ts file=src/app/migrate.ts
import { fileURLToPath } from "node:url";
import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import { Client } from "pg";

export async function migrateDatabase(url: string): Promise<void> {
  const client = new Client({ connectionString: url, application_name: "publishing-migrate" });
  await client.connect();
  try {
    await client.query("SET lock_timeout = '5s'");
    await client.query("SELECT pg_advisory_lock(hashtext('publishing.migrations'))");
    await migrate(drizzle(client), { migrationsFolder: fileURLToPath(new URL("../../migrations", import.meta.url)) });
  } finally {
    await client.end();
  }
}

if (process.argv[1] === import.meta.filename) {
  const url = process.env.DATABASE_URL; // unset would fall back to libpq's PG* defaults: refuse instead
  if (url === undefined || url === "") throw new Error("DATABASE_URL is required");
  await migrateDatabase(url);
}
```

The Workers entry over Hyperdrive (guide § 9), typechecked as its own program.

```ts file=worker/index.ts
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { loadConfig } from "../src/app/config.ts";
import { buildServices } from "../src/app/services.ts";
import { createApp } from "../src/inbound/http/app.ts";
import type { Logger } from "../src/inbound/http/env.ts";
import { PgIdempotencyStore } from "../src/outbound/postgres/idempotency.ts";
import { OutboxRelay } from "../src/outbound/postgres/outbox.ts";
import { HttpEventPublisher } from "../src/outbound/system.ts";

declare global {
  namespace Cloudflare {
    interface Env {
      /** Hyperdrive with caching disabled: reads must see the latest write. */
      readonly DB: Hyperdrive;
    }
  }
}

// Vars and secrets arrive in process.env (nodejs_compat); bindings can be read only inside handlers.
const config = loadConfig({ DATABASE_URL: "postgresql://hyperdrive.invalid/unused", ...process.env });
const printable = (_key: string, value: unknown) => (value instanceof Error ? `${value.name}: ${value.message}` : value);
const consoleLogger = (bound: object): Logger => {
  const write = (level: string) => (fields: object, message: string) => {
    console.log(JSON.stringify({ level, message, ...bound, ...fields }, printable));
  };
  return { info: write("info"), warn: write("warn"), error: write("error"), child: (b) => consoleLogger({ ...bound, ...b }) };
};
const log = consoleLogger({ service: "publishing-api" });
/** One client per request or event; Hyperdrive pools the real connections. */
function connect() {
  const pool = new Pool({ connectionString: env.DB.connectionString, max: 1, connectionTimeoutMillis: 2_000 });
  pool.on("error", (err) => {
    // on workerd, pool.end() reports its own socket close as an error
    if (!pool.ending) log.warn({ err }, "idle database client failed");
  });
  return { pool, db: drizzle(pool) };
}

const app = createApp({
  ...config,
  logger: log,
  provide: async (c, next) => {
    const { pool, db } = connect();
    c.set("services", buildServices(db, config));
    try {
      await next();
    } finally {
      c.executionCtx.waitUntil(pool.end());
    }
  },
});

export default {
  fetch: app.fetch,
  async scheduled(_controller, _env, ctx) {
    const { pool, db } = connect();
    try {
      if (config.eventsUrl !== undefined) await new OutboxRelay(db, new HttpEventPublisher(config.eventsUrl)).runOnce();
      await new PgIdempotencyStore(db, { leaseMs: config.idempotencyLeaseMs }).purgeExpired();
    } finally {
      ctx.waitUntil(pool.end());
    }
  },
} satisfies ExportedHandler<Cloudflare.Env>;
```

```json file=worker/tsconfig.json
{
  "extends": "../tsconfig.json",
  "compilerOptions": { "types": ["@cloudflare/workers-types", "node"] },
  "include": ["."]
}
```

## Project and tool configuration

```json file=package.json
{
  "name": "publishing-api",
  "private": true,
  "type": "module",
  "engines": { "node": ">=24" },
  "scripts": {
    "start": "node --import ./src/app/telemetry.ts src/app/main.ts",
    "relay": "node --import ./src/app/telemetry.ts src/app/relay.ts",
    "db:migrate": "node src/app/migrate.ts",
    "typecheck": "tsc && tsc -p worker",
    "lint": "oxlint --type-aware --deny-warnings",
    "boundaries": "node scripts/boundaries.ts",
    "test": "vitest run"
  },
  "dependencies": {
    "@hono/node-server": "^2.1.3",
    "@hono/otel": "^1.2.0",
    "@hono/zod-openapi": "^1.6.3",
    "@opentelemetry/api": "^1.9.1",
    "@opentelemetry/instrumentation-pg": "^0.75.0",
    "@opentelemetry/instrumentation-undici": "^0.33.0",
    "@opentelemetry/sdk-node": "^0.223.0",
    "drizzle-orm": "~0.45.3",
    "hono": "^4.13.13",
    "jose": "^6.2.12",
    "pg": "^8.23.1",
    "pino": "^10.4.0",
    "zod": "~4.6.5"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^5.20261007.1",
    "@types/node": "^24.19.1",
    "@types/pg": "^8.23.1",
    "@typescript/native": "npm:typescript@^7.0.2",
    "dependency-cruiser": "^18.5.0",
    "drizzle-kit": "~0.31.11",
    "oxlint": "^1.87.0",
    "oxlint-tsgolint": "^7.0.2003",
    "typescript": "npm:@typescript/typescript6@^6.0.2",
    "vitest": "^5.0.3"
  }
}
```

```json file=tsconfig.json
{
  "compilerOptions": {
    "target": "es2024",
    "lib": ["es2024"],
    "module": "nodenext",
    "types": ["node"],
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "verbatimModuleSyntax": true,
    "erasableSyntaxOnly": true,
    "allowImportingTsExtensions": true,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["src", "test", "scripts", "*.ts"]
}
```

```json file=.oxlintrc.json
{
  "plugins": ["typescript", "unicorn", "oxc", "import", "promise", "node", "vitest"],
  "categories": { "correctness": "error", "suspicious": "error", "pedantic": "error", "perf": "error" },
  "rules": {
    "typescript/prefer-readonly-parameter-types": "off",
    "no-await-in-loop": "off",
    "no-inline-comments": "off",
    "max-lines-per-function": "off",
    "max-classes-per-file": "off",
    "import/max-dependencies": "off"
  },
  "ignorePatterns": ["node_modules", "openapi.json"]
}
```

```ts file=scripts/boundaries.ts
import { cruise, type IForbiddenRuleType } from "dependency-cruiser";
import ts from "typescript";

const forbidden: IForbiddenRuleType[] = [
  { name: "domain-is-pure", severity: "error", from: { path: "^src/domain/" }, to: { pathNot: "^src/domain/" } },
  { name: "inbound-not-outbound", severity: "error", from: { path: "^src/inbound/" }, to: { path: "^src/(outbound|app)/" } },
  { name: "outbound-not-inbound", severity: "error", from: { path: "^src/outbound/" }, to: { path: "^src/(inbound|app)/" } },
  { name: "no-circular", severity: "error", from: { path: "^src/" }, to: { circular: true } },
];
const { output } = await cruise(["src"], {
  validate: true,
  ruleSet: { forbidden },
  tsPreCompilationDeps: true,
  doNotFollow: { path: "node_modules" },
  tsConfig: { fileName: "tsconfig.json" },
});
if (typeof output === "string") throw new Error(output);
const { totalCruised, violations } = output.summary;
for (const v of violations) console.error(`${v.rule.name}: ${v.from} -> ${v.to}`);
console.log(`typescript ${ts.version}: ${String(totalCruised)} modules, ${String(violations.length)} violations`);
if (!ts.version.startsWith("6.") || totalCruised === 0 || violations.length > 0) process.exit(1);
```

```ts file=vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({ test: { testTimeout: 20_000 } });
```

```ts file=drizzle.config.ts
import { defineConfig } from "drizzle-kit";

export default defineConfig({ dialect: "postgresql", schema: "./src/outbound/postgres/schema.ts", out: "./migrations" });
```

## Test harness

```ts file=test/support/postgres.ts
import { randomUUID } from "node:crypto";
import { Client, type Pool } from "pg";
import { afterAll } from "vitest";
import { migrateDatabase } from "../../src/app/migrate.ts";
import { connectPostgres, type Db } from "../../src/outbound/postgres/db.ts";

const ADMIN_URL = process.env.TEST_DATABASE_URL ?? "postgres://postgres@localhost:5432/postgres";

async function admin(statement: string): Promise<void> {
  const client = new Client(ADMIN_URL);
  await client.connect();
  try {
    await client.query(statement);
  } finally {
    await client.end();
  }
}

/** A database per test file, migrated from empty by the release step (or left empty), dropped afterwards. */
export async function freshDatabase(migrated = true): Promise<{ db: Db; pool: Pool }> {
  const name = `t_${randomUUID().replaceAll("-", "")}`;
  const url = new URL(ADMIN_URL);
  url.pathname = `/${name}`;
  await admin(`CREATE DATABASE ${name}`);
  if (migrated) await migrateDatabase(url.href);
  const settings = { url: url.href, poolMax: 10, statementTimeoutMs: 5_000, transactionTimeoutMs: 10_000, applicationName: "tests" };
  const { pool, db } = connectPostgres(settings, () => {});
  afterAll(async () => {
    await pool.end();
    await admin(`DROP DATABASE ${name} WITH (FORCE)`);
  });
  return { db, pool };
}
```

## Adapter tests on PostgreSQL

```ts file=test/postgres.test.ts
import { randomUUID } from "node:crypto";
import { eq, sql } from "drizzle-orm";
import { generateDrizzleJson, generateMigration } from "drizzle-kit/api";
import { describe, expect, it } from "vitest";
import { buildServices } from "../src/app/services.ts";
import type { Article } from "../src/domain/publishing/article.ts";
import type { UnitOfWork } from "../src/domain/publishing/ports.ts";
import type { Actor, EventPublisher } from "../src/domain/shared/ports.ts";
import type { Db } from "../src/outbound/postgres/db.ts";
import { OutboxRelay, RELAY_DEFAULTS } from "../src/outbound/postgres/outbox.ts";
import * as schema from "../src/outbound/postgres/schema.ts";
import { PgUnitOfWork } from "../src/outbound/postgres/unit-of-work.ts";
import { draft, SaboteurOutbox } from "./support/doubles.ts";
import { freshDatabase } from "./support/postgres.ts";

const { db } = await freshDatabase();
const uow = new PgUnitOfWork(db);
const { publishing } = buildServices(db, { idempotencyLeaseMs: 30_000, uow });
const as = (tenantId: string, subject = "alice", roles: string[] = []): Actor => ({ tenantId, subject, roles });

async function walk(actor: Actor, limit: number): Promise<string[]> {
  const seen: string[] = [];
  let cursor: string | undefined;
  do {
    const page = await publishing.list(actor, { cursor, limit });
    seen.push(...page.items.map((a) => a.id));
    cursor = page.nextCursor ?? undefined;
  } while (cursor !== undefined);
  return seen;
}

/** Columns, keys and indexes as PostgreSQL normalizes them; CHECK constraints live only in SQL. */
const catalog = async (target: Db) =>
  (
    await target.execute<{ entry: string }>(sql`
      SELECT format('%s.%s %s null=%s default=%s', table_name, column_name, data_type, is_nullable, column_default) AS entry
        FROM information_schema.columns WHERE table_schema = 'public'
      UNION ALL SELECT format('%s %s %s', conrelid::regclass, conname, pg_get_constraintdef(oid))
        FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND contype <> 'c'
      UNION ALL SELECT indexdef FROM pg_indexes WHERE schemaname = 'public' ORDER BY 1`)
  ).rows.map((r) => r.entry);

const [failing, published] = [new Set<string>(), [] as string[]];
const broker: EventPublisher = {
  publish: (m) => {
    if (failing.has(m.aggregateId)) return Promise.reject(new Error("rejected by broker"));
    published.push(`${m.aggregateId}:${String(m.aggregateSeq)}`);
    return Promise.resolve();
  },
};

describe("PostgreSQL adapters", () => {
  it("walks the keyset over rows sharing one now() with no duplicates or gaps", async () => {
    const tenant = randomUUID();
    await db.execute(sql`
      INSERT INTO articles (id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at)
      SELECT uuidv7(), ${tenant}, 'alice', 'post-' || g, 'Post ' || g, '', 'draft', 1, now(), now()
      FROM generate_series(1, 9) AS g`);
    const all = await walk(as(tenant), 100);
    expect(all).toHaveLength(9);
    expect(all).toEqual(all.toSorted().toReversed());
    expect(await walk(as(tenant), 1)).toEqual(all);
    expect(await walk(as(tenant), 2)).toEqual(all);
  });

  it("lets exactly one of two concurrent creates take the slug", async () => {
    const [tenant, input] = [randomUUID(), draft()];
    const results = await Promise.allSettled([publishing.create(as(tenant), input), publishing.create(as(tenant, "bob"), input)]);
    expect(results.map((r) => r.status).toSorted()).toEqual(["fulfilled", "rejected"]);
    expect(results.find((r) => r.status === "rejected")).toMatchObject({ reason: { code: "already_exists" } });
  });

  it("guards writes on version and status, and refuses work once the transaction ended", async () => {
    const article = await publishing.create(as(randomUUID()), draft());
    expect(await uow.run((tx) => tx.articles.update({ ...article, title: "A" }, 1))).toMatchObject({ version: 2 });
    expect(await uow.run((tx) => tx.articles.update({ ...article, title: "B" }, 1))).toBeNull();
    expect(await uow.run((tx) => tx.articles.transition({ ...article, status: "archived" }, "published"))).toBeNull();
    const escaped = await uow.run((tx) => Promise.resolve(tx));
    await expect(escaped.articles.get(article.tenantId, article.id)).rejects.toThrow("late work refused");
  });

  it("answers a deadlock with unavailable instead of retrying the unit, on UTC sessions", async () => {
    expect((await db.execute(sql`SHOW TimeZone`)).rows).toEqual([{ TimeZone: "UTC" }]);
    const actor = as(randomUUID());
    const [a, b] = [await publishing.create(actor, draft()), await publishing.create(actor, draft())];
    const locked = [Promise.withResolvers<void>(), Promise.withResolvers<void>()] as const;
    const cross = (first: Article, second: Article, mine: PromiseWithResolvers<void>) =>
      uow.run(async (tx) => {
        await tx.articles.update({ ...first, title: "1" }, 1);
        mine.resolve();
        await Promise.all(locked.map((l) => l.promise)); // each holds its first row lock, then reaches for the other's
        await tx.articles.update({ ...second, title: "2" }, 1);
      });
    const results = await Promise.allSettled([cross(a, b, locked[0]), cross(b, a, locked[1])]);
    expect(results.map((r) => r.status).toSorted()).toEqual(["fulfilled", "rejected"]);
    expect(results.find((r) => r.status === "rejected")).toMatchObject({ reason: { code: "unavailable" } });
  });

  it("publishes a draft once under concurrency with one outbox row, and not at all when the outbox fails", async () => {
    const actor = as(randomUUID());
    const { id } = await publishing.create(actor, draft());
    const results = await Promise.allSettled([1, 2, 3, 4, 5, 6].map(() => publishing.publish(actor, id)));
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    expect(await db.select().from(schema.outbox).where(eq(schema.outbox.aggregateId, id))).toMatchObject([
      { eventType: "article.published", eventVersion: 1, aggregateSeq: 2 },
    ]);
    const sabotaged: UnitOfWork = { run: (work) => uow.run((tx) => work({ ...tx, outbox: SaboteurOutbox })) };
    const second = await publishing.create(actor, draft());
    const broken = buildServices(db, { idempotencyLeaseMs: 1, uow: sabotaged }).publishing;
    await expect(broken.publish(actor, second.id)).rejects.toThrow("outbox unavailable");
    expect(await publishing.get(actor, second.id)).toMatchObject({ status: "draft", version: 1 });
  });

  it("keeps another tenant's article invisible to get, list and publish", async () => {
    const article = await publishing.create(as(randomUUID()), draft());
    const stranger = as(randomUUID(), "mallory", ["editor"]);
    await expect(publishing.get(stranger, article.id)).rejects.toMatchObject({ code: "not_found" });
    await expect(publishing.publish(stranger, article.id)).rejects.toMatchObject({ code: "not_found" });
    expect(await publishing.list(stranger, { limit: 100 })).toMatchObject({ items: [] });
  });

  it("relays each aggregate in sequence, hands claims back on stop and dead-letters after the last attempt", async () => {
    await db.delete(schema.outbox);
    const [a, b] = [randomUUID(), randomUUID()];
    for (const [aggregateId, aggregateSeq] of [[a, 1], [a, 2], [b, 1], [a, 3]] as const) {
      await uow.run((tx) => tx.outbox.append({ type: "t", version: 1, tenantId: a, aggregateType: "article", aggregateId, aggregateSeq, payload: {} }));
    }
    failing.add(b);
    const relay = new OutboxRelay(db, broker, { ...RELAY_DEFAULTS, maxAttempts: 3, backoffBaseMs: 0 });
    expect(await relay.runOnce(AbortSignal.abort())).toBe(2); // both heads handed back at once, attempt uncounted
    for (let pass = 0; pass < 4; pass++) await relay.runOnce();
    expect(published).toEqual([`${a}:1`, `${a}:2`, `${a}:3`]);
    const [dead] = await db.select().from(schema.outbox).where(eq(schema.outbox.aggregateId, b));
    expect(dead).toMatchObject({ attempts: 3, publishedAt: null, lastError: "rejected by broker" });
    expect(dead?.deadLetteredAt).toBeInstanceOf(Date);
    expect(await relay.stats()).toEqual({ oldestPendingSeconds: 0, deadLettered: 1 });
  });

  it("keeps the Drizzle schema identical to the SQL migration", async () => {
    const { db: empty } = await freshDatabase(false);
    for (const statement of await generateMigration(generateDrizzleJson({}), generateDrizzleJson(schema))) {
      await empty.execute(sql.raw(statement));
    }
    expect(await catalog(empty)).toEqual(await catalog(db));
  });
});
```

## HTTP tests

```ts file=test/http.test.ts
import { createHmac, randomUUID } from "node:crypto";
import { once } from "node:events";
import { createServer, type RequestListener } from "node:http";
import { sql } from "drizzle-orm";
import type { MiddlewareHandler } from "hono";
import { HTTPException } from "hono/http-exception";
import { SignJWT } from "jose";
import { describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { buildServices } from "../src/app/services.ts";
import { createApp } from "../src/inbound/http/app.ts";
import type { AppEnv, Logger } from "../src/inbound/http/env.ts";
import { Readiness } from "../src/inbound/http/health.ts";
import { draft } from "./support/doubles.ts";
import { freshDatabase } from "./support/postgres.ts";

const PROBLEMS = "https://api.example.test/problems/";
const SECRET = `whsec_${Buffer.from("moderation-test-secret-32-bytes!").toString("base64")}`;
const JWT = { issuer: "https://id.example.test/", audience: "publishing-api", secret: "s".repeat(32) };
const silent: Logger = { info: () => {}, warn: () => {}, error: () => {}, child: () => silent };
const { db, pool } = await freshDatabase();

/** The test builder: real adapters, no port, HS256 tokens unless a JWKS URL is given. */
function testApp(opts: { ready?: boolean; jwksUrl?: URL; provide?: MiddlewareHandler<AppEnv> } = {}) {
  const services = buildServices(db, { idempotencyLeaseMs: 30_000 });
  const readiness = new Readiness();
  if (opts.ready ?? true) readiness.ready();
  const app = createApp({
    logger: silent,
    problemBase: PROBLEMS,
    corsOrigins: ["https://app.example.test"],
    requestTimeoutMs: 5_000,
    auth: opts.jwksUrl ? { ...JWT, mode: "jwks", jwksUrl: opts.jwksUrl } : { ...JWT, mode: "hs256" },
    webhookSecrets: [SECRET],
    readiness,
    provide:
      opts.provide ??
      (async (c, next) => {
        c.set("services", services);
        await next();
      }),
  });
  return { app, readiness };
}

const token = (sub: string, tid: string, roles: string[] = []) =>
  new SignJWT({ tid, roles })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(sub)
    .setIssuer(JWT.issuer)
    .setAudience(JWT.audience)
    .setExpirationTime("5m")
    .sign(new TextEncoder().encode(JWT.secret));

/** A stand-in identity provider; without a listener the port is closed again (connection refused). */
async function keyEndpoint(behave?: RequestListener): Promise<URL> {
  const idp = createServer(behave).listen(0, "127.0.0.1").unref();
  await once(idp, "listening");
  const { port } = z.object({ port: z.int() }).parse(idp.address());
  if (behave === undefined) idp.close();
  return new URL(`http://127.0.0.1:${String(port)}/jwks`);
}

function signWebhook(id: string, body: string, sentAt = Math.floor(Date.now() / 1000)): Record<string, string> {
  const signature = createHmac("sha256", Buffer.from(SECRET.slice(6), "base64")).update(`${id}.${String(sentAt)}.${body}`).digest("base64");
  return { "content-type": "application/json", "webhook-id": id, "webhook-timestamp": String(sentAt), "webhook-signature": `v1,${signature}` };
}

const { app } = testApp();
const [T1, T2] = [randomUUID(), randomUUID()];
const [alice, bob, mallory] = await Promise.all([token("alice", T1), token("bob", T1), token("mallory", T2, ["editor"])]);
const UUID = /^[0-9a-f-]{36}$/u;

function call(method: string, path: string, bearer?: string, body?: unknown, headers: Record<string, string> = {}) {
  const auth = bearer === undefined ? {} : { authorization: `Bearer ${bearer}` };
  const type = body === undefined ? {} : { "content-type": "application/json" };
  const payload = body === undefined || typeof body === "string" ? (body ?? null) : JSON.stringify(body);
  return Promise.resolve(app.request(path, { method, headers: { ...auth, ...type, ...headers }, body: payload }));
}
const json = async (res: Response | Promise<Response>): Promise<unknown> => (await res).json();
const create = async (body = draft()) => (await call("POST", "/v1/articles", alice, body)).headers.get("location") ?? "";
const publish = (path: string, headers?: Record<string, string>) => call("POST", `${path}/publish`, alice, undefined, headers);
const deliver = (body: string, headers: Record<string, string>) =>
  Promise.resolve(app.request("/internal/webhooks/moderation", { method: "POST", body, headers }));
const [draftPath, publishedPath] = [await create(), await create()];
await publish(publishedPath);

describe("problem documents", () => {
  it.each<[string, () => Promise<Response>, number, string, string[]?]>([
    ["no token", () => call("GET", "/v1/articles"), 401, "unauthenticated", ['www-authenticate: Bearer realm="api"', '"title":"Unauthenticated"']],
    ["not the author, 403 before 412", () => call("PATCH", draftPath, bob, {}, { "if-match": '"9"' }), 403, "forbidden"],
    ["foreign id", () => call("GET", draftPath, mallory), 404, "not-found", ['"title":"Not found"', `"instance":"${draftPath}"`]],
    ["unknown route", () => call("GET", "/v1/unknown", alice), 404, "not-found"],
    ["wrong method", () => call("DELETE", draftPath, alice), 405, "method-not-allowed", ["allow: GET, HEAD, PATCH"]],
    ["malformed JSON", () => call("POST", "/v1/articles", alice, "{"), 400, "malformed-request", ['"title":"Malformed request"']],
    ["malformed id", () => call("GET", "/v1/articles/42", alice), 400, "malformed-request"],
    ["undecodable cursor", () => call("GET", "/v1/articles?cursor=bm9wZQ", alice), 400, "malformed-request", ['"instance":"/v1/articles"']],
    ["600-character cursor", () => call("GET", `/v1/articles?cursor=${"a".repeat(600)}`, alice), 400, "malformed-request"],
    ["malformed key", () => call("POST", "/v1/articles", alice, draft(), { "idempotency-key": "a b" }), 400, "malformed-request"],
    ["publishing twice", () => publish(publishedPath), 409, "invalid-transition", ['"title":"Invalid transition"']],
    ["over 64 KiB", () => call("POST", "/v1/articles", alice, { ...draft(), body: "x".repeat(70_000) }), 413, "payload-too-large"],
    ["text/plain", () => call("POST", "/v1/articles", alice, "a", { "content-type": "text/plain" }), 415, "unsupported-media-type"],
    ["unknown member", () => call("POST", "/v1/articles", alice, { ...draft(), tenant_id: T2 }), 422, "validation-failed", ['"#/tenant_id"', '"unknown_field"']],
    ["domain rules", () => call("POST", "/v1/articles", alice, { slug: "Bad", title: " ", body: "" }), 422, "validation-failed", ['"#/slug"', '"#/title"']],
    ["NUL in the title", () => call("POST", "/v1/articles", alice, { ...draft(), title: "a\u0000b" }), 422, "validation-failed", ['"#/title"']],
    ["null body", () => call("POST", "/v1/articles", alice, "null"), 422, "validation-failed", ['"pointer":"#"']],
    ["limit 0", () => call("GET", "/v1/articles?limit=0", alice), 422, "validation-failed", ['"parameter":"limit"', '"too_small"']],
    ["limit 100.5", () => call("GET", "/v1/articles?limit=100.5", alice), 422, "validation-failed", ['"parameter":"limit"']],
    ["unknown query parameter", () => call("GET", "/v1/articles?sort=title", alice), 422, "validation-failed", ['"parameter":"sort"']],
    ["unknown query parameter by id", () => call("GET", `${draftPath}?x=1`, alice), 422, "validation-failed", [`"instance":"${draftPath}"`]],
  ])("%s", async (_name, send, status, type, evidence = []) => {
    const res = await send();
    const text = `${await res.clone().text()}\n${[...res.headers].map(([k, v]) => `${k}: ${v}`).join("\n")}`;
    expect([res.status, res.headers.get("content-type"), res.headers.get("x-request-id")]).toEqual([status, "application/problem+json", expect.stringMatching(UUID)]);
    expect(await res.json()).toMatchObject({ type: `${PROBLEMS}${type}`, status });
    for (const fragment of evidence) expect(text).toContain(fragment);
  });

  it.each<[string, RequestListener | undefined]>([
    ["answers 503", (_req, res) => void res.writeHead(503).end()],
    ["serves HTML", (_req, res) => void res.writeHead(200, { "content-type": "text/html" }).end("<html>")],
    ["never answers", () => {}],
    ["refuses the connection", undefined],
  ])("answers 503, not 401, while the key endpoint %s", async (_name, behave) => {
    const { app: jwks } = testApp({ jwksUrl: await keyEndpoint(behave) });
    const unverified = `${Buffer.from('{"alg":"ES256"}').toString("base64url")}.e30.c2ln`; // fails at the key fetch first
    const res = await jwks.request("/v1/articles", { headers: { authorization: `Bearer ${unverified}` } });
    expect([res.status, res.headers.get("retry-after")]).toEqual([503, "5"]);
    expect(await res.json()).toMatchObject({ type: `${PROBLEMS}unavailable`, title: "Service unavailable" });
  });

  it.each<[string, Error, number, string, string]>([
    ["a framework 406", new HTTPException(406), 406, `${PROBLEMS}not-acceptable`, "Not acceptable"],
    ["a status outside the registry", new HTTPException(410), 410, "about:blank", "Gone"],
    ["an unknown error, generically", new Error("SELECT secret"), 500, `${PROBLEMS}internal`, "Internal error"],
  ])("renders %s", async (_name, error, status, type, title) => {
    const body = await json(testApp({ provide: () => Promise.reject(error) }).app.request("/v1/articles"));
    expect(body).toMatchObject({ type, title, status, instance: "/v1/articles" });
    expect(JSON.stringify(body)).not.toContain("secret");
  });
});

describe("articles", () => {
  it("creates with 201, Location, ETag, no-store and the request id; clamps the page size", async () => {
    const res = await call("POST", "/v1/articles", alice, { ...draft(), title: " Hi " }, { "x-request-id": "edge.42:a_b" });
    expect([res.status, res.headers.get("etag"), res.headers.get("cache-control"), res.headers.get("x-request-id")]).toEqual([201, '"1"', "no-store", "edge.42:a_b"]);
    expect(res.headers.get("location")).toMatch(/^\/v1\/articles\/[0-9a-f-]{36}$/u);
    expect(await res.json()).toMatchObject({ data: { title: "Hi", status: "draft", version: 1 } });
    expect(await json(call("GET", "/v1/articles?limit=99999999999999999999", alice))).toMatchObject({ meta: { limit: 100 } });
    for (const invalid of ["", "has space", "x".repeat(129)]) {
      expect((await call("GET", "/health", undefined, undefined, { "x-request-id": invalid })).headers.get("x-request-id")).toMatch(UUID);
    }
  });

  it("applies merge patches under If-Match: exact strong tags or *, 404 before 412", async () => {
    const path = await create({ ...draft(), body: "text" });
    const merge = { "if-match": '"1"', "content-type": "application/merge-patch+json" };
    const patched = await call("PATCH", path, alice, { title: "New", body: null }, merge);
    expect([patched.headers.get("etag"), await patched.json()]).toMatchObject(['"2"', { data: { title: "New", body: "" } }]);
    expect(await json(call("PATCH", path, alice, { title: "Late" }, merge))).toMatchObject({ status: 412, type: `${PROBLEMS}precondition-failed` });
    for (const [tag, status] of [['"1", "2"', 200], ["*", 200], ['W/"4"', 412], ['"04"', 412], ['"4", *', 412], ['"4"', 200]] as const) {
      expect((await call("PATCH", path, alice, { title: tag }, { "if-match": tag })).status).toBe(status);
    }
    expect((await call("PATCH", path, mallory, { title: "x" }, { "if-match": "garbage" })).status).toBe(404);
    expect((await call("PATCH", path, alice, { title: null })).status).toBe(422);
  });
});

describe("idempotency", () => {
  it("replays a completed create and refuses the key for another request", async () => {
    const [headers, body] = [{ "idempotency-key": randomUUID() }, draft()];
    const first = await call("POST", "/v1/articles", alice, body, headers);
    const replay = await call("POST", "/v1/articles", alice, { body: "", title: "Hello", slug: body.slug }, headers);
    expect([replay.status, replay.headers.get("idempotent-replayed"), replay.headers.get("location")]).toEqual([201, "true", first.headers.get("location")]);
    expect(await replay.json()).toEqual(await first.json());
    const mismatch = await json(call("POST", "/v1/articles", alice, draft(), headers));
    expect(mismatch).toMatchObject({ type: `${PROBLEMS}idempotency-key-mismatch`, title: "Idempotency key mismatch" });
  });

  it("never stores an outcome decided by a header outside the hash (415)", async () => {
    const [headers, body] = [{ "idempotency-key": randomUUID() }, JSON.stringify(draft())];
    expect((await call("POST", "/v1/articles", alice, body, { ...headers, "content-type": "text/plain" })).status).toBe(415);
    const retried = await call("POST", "/v1/articles", alice, body, headers);
    expect([retried.status, retried.headers.get("idempotent-replayed")]).toEqual([201, null]);
  });

  it("answers 409 + Retry-After while the first request with the key still runs", async () => {
    const path = await create();
    const blocker = await pool.connect();
    await blocker.query("BEGIN");
    await blocker.query("SELECT 1 FROM articles WHERE id = $1 FOR UPDATE", [path.split("/").at(-1)]);
    const key = randomUUID();
    const first = publish(path, { "idempotency-key": key });
    await vi.waitFor(async () => {
      expect((await db.execute(sql`SELECT 1 FROM idempotency_keys WHERE key = ${key}`)).rows).toHaveLength(1);
    });
    const second = await publish(path, { "idempotency-key": key });
    expect([second.status, second.headers.get("retry-after")]).toEqual([409, "1"]);
    expect(await second.json()).toMatchObject({ title: "Request in progress" });
    await blocker.query("ROLLBACK");
    blocker.release();
    expect((await first).status).toBe(200);
    expect((await publish(path, { "idempotency-key": key })).headers.get("idempotent-replayed")).toBe("true");
  });
});

describe("moderation webhook", () => {
  it("answers 401 to a bad signature or a stale timestamp", async () => {
    const body = JSON.stringify({ tenant_id: T1, article_id: randomUUID(), verdict: "rejected" });
    expect((await deliver(body, { ...signWebhook("m1", body), "webhook-signature": "v1,AAAA" })).status).toBe(401);
    expect((await deliver(body, signWebhook("m1", body, Math.floor(Date.now() / 1000) - 301))).status).toBe(401);
  });

  it("records and acks a signed payload that fails its schema", async () => {
    const [id, body] = [randomUUID(), JSON.stringify({ tenant_id: T1, article_id: "42", verdict: "rejected" })];
    expect((await deliver(body, signWebhook(id, body))).status).toBe(204);
    expect((await db.execute(sql`SELECT 1 FROM inbox WHERE message_id = ${id}`)).rows).toHaveLength(1);
  });

  it("archives once, tolerating unknown fields, and acks a redelivery without a second effect", async () => {
    const path = await create();
    const id = path.split("/").at(-1);
    await publish(path);
    const body = JSON.stringify({ tenant_id: T1, article_id: id, verdict: "rejected", reviewer: "bot-7" });
    const headers = signWebhook(randomUUID(), body);
    expect((await deliver(body, headers)).status).toBe(204);
    expect(await json(call("GET", path, alice))).toMatchObject({ data: { status: "archived" } });
    await db.execute(sql`UPDATE articles SET status = 'published' WHERE id = ${id}`);
    expect((await deliver(body, headers)).status).toBe(204);
    expect(await json(call("GET", path, alice))).toMatchObject({ data: { status: "published" } });
  });
});

describe("probes and the published contract", () => {
  it("is unready before the latch and while draining, alive throughout; draining closes connections", async () => {
    const { app: probed, readiness } = testApp({ ready: false });
    expect((await probed.request("/ready")).status).toBe(503);
    readiness.ready();
    expect((await probed.request("/ready")).status).toBe(200);
    readiness.drain();
    const health = await probed.request("/health");
    expect([(await probed.request("/ready")).status, health.status, health.headers.get("connection")]).toEqual([503, 200, "close"]);
  });

  it("matches the committed OpenAPI document, which leaves the internal router out", async () => {
    const doc = await json(call("GET", "/openapi.json"));
    expect(doc).not.toHaveProperty(["paths", "/internal/webhooks/moderation"]);
    await expect(`${JSON.stringify(doc, null, 2)}\n`).toMatchFileSnapshot("../openapi.json");
  });
});
```

## Configuration tests

```ts file=test/config.test.ts
import { describe, expect, it } from "vitest";
import { loadConfig } from "../src/app/config.ts";

const secret = (bytes: number) => `whsec_${Buffer.alloc(bytes, 7).toString("base64")}`;
const production = {
  APP_ENV: "production",
  DATABASE_URL: "postgres://app@db:5432/app",
  JWT_MODE: "jwks",
  JWT_JWKS_URL: "https://id.example/jwks.json",
  JWT_ISSUER: "https://id.example/",
  JWT_AUDIENCE: "publishing-api",
  PROBLEM_BASE_URI: "https://api.example/problems/",
  CORS_ORIGINS: "https://app.example",
  WEBHOOK_SECRETS: `${secret(32)},${secret(24)}`,
};

describe("configuration", () => {
  it("accepts a sound production config with the lease above the deadline", () => {
    expect(loadConfig(production)).toMatchObject({ requestTimeoutMs: 8_000, idempotencyLeaseMs: 24_000, webhookSecrets: [secret(32), secret(24)] });
  });

  it.each<[string, Record<string, string | undefined>, string]>([
    ["APP_ENV unset", { APP_ENV: undefined }, "APP_ENV"],
    ["hs256 in production", { JWT_MODE: "hs256", JWT_HS256_SECRET: "s".repeat(32) }, "JWT_MODE"],
    ["no webhook secret", { WEBHOOK_SECRETS: "" }, "WEBHOOK_SECRETS"],
    ["a webhook secret under 24 bytes", { WEBHOOK_SECRETS: secret(23) }, "WEBHOOK_SECRETS"],
    ["a webhook secret that is not base64", { WEBHOOK_SECRETS: "whsec_c2VjcmV0*" }, "WEBHOOK_SECRETS"],
    ["an origin with a path", { CORS_ORIGINS: "https://app.example/" }, "CORS_ORIGINS"],
    ["a grace period below deadline + pool close + flush", { REQUEST_TIMEOUT_MS: "9000" }, "SHUTDOWN_GRACE_MS"],
  ])("stops on %s", (_name, change, field) => {
    expect(() => loadConfig({ ...production, ...change })).toThrow(field);
  });
});
```

## CI

```yaml file=.github/workflows/ci.yml
name: ci
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:18
        env: { POSTGRES_HOST_AUTH_METHOD: trust }
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 2s --health-retries 30
    env: { CI: "true", TEST_DATABASE_URL: "postgres://postgres@localhost:5432/postgres" }
    steps:
      - uses: actions/checkout@v7
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v7
        with: { node-version: 24, cache: npm }
      - run: npm ci
      - run: npm run typecheck && npm run lint && npm run boundaries && npm test
      - run: git show "origin/${{ github.base_ref }}:openapi.json" > base-openapi.json || cp openapi.json base-openapi.json
      - uses: oasdiff/oasdiff-action/breaking@v0.1.18
        with: { base: base-openapi.json, revision: openapi.json, fail-on: ERR }
```
