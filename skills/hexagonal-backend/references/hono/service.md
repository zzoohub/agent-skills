# Hono examples: the service

What a new service needs: the app factory with its layer order, authentication, probes, configuration, logging and telemetry, the composition root, the entrypoints for Node and Workers, the manifest and the boundary check. Every `file=` block is a complete file of the project in `slice.md`.

## Contents

1. [App factory and layer order](#app-factory-and-layer-order)
2. [Authentication](#authentication)
3. [Probes](#probes)
4. [Configuration](#configuration)
5. [Logging and telemetry](#logging-and-telemetry)
6. [Composition](#composition)
7. [Entrypoints](#entrypoints)
8. [Workers entry](#workers-entry)
9. [Manifest and tool configuration](#manifest-and-tool-configuration)
10. [Boundary check](#boundary-check)

## App factory and layer order

Registration order is execution order (`guide.md` § 3). Tests build the same app and call `app.request()` without a port.

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

## Authentication

```ts file=src/inbound/http/auth.ts
import { createMiddleware } from "hono/factory";
import { createRemoteJWKSet, errors, jwtVerify, type JWTPayload } from "jose";
import { z } from "zod";
import type { AppEnv } from "./env.ts";
import { ProblemError } from "./problem.ts";

export type AuthConfig = Readonly<
  { issuer: string; audience: string } & ({ mode: "jwks"; jwksUrl: URL } | { mode: "hs256"; secret: string })
>;

const Claims = z.object({ sub: z.string().regex(/^[^\0]+$/u), tid: z.uuid(), roles: z.array(z.string()).default([]) }); // sub is stored: no NUL
const BEARER = /^Bearer +([\w.~+/-]+=*)$/iu;
/** Key-source outages; jose throws a plain JOSEError for a non-200 or non-JSON reply. */
const KEY_SOURCE_DOWN = new Set(["ERR_JOSE_GENERIC", "ERR_JWKS_TIMEOUT", "ERR_JWKS_INVALID"]);

const unauthenticated = (detail: string, tokenSent: boolean) =>
  new ProblemError("unauthenticated", detail, {
    headers: { "WWW-Authenticate": `Bearer realm="api"${tokenSent ? ', error="invalid_token"' : ""}` },
  });

function verifier(cfg: AuthConfig): (token: string) => Promise<JWTPayload> {
  const options = { issuer: cfg.issuer, audience: cfg.audience, requiredClaims: ["exp", "sub"] };
  if (cfg.mode === "jwks") {
    const keys = createRemoteJWKSet(cfg.jwksUrl, { timeoutDuration: 2_000 }); // cached 10 min; refetch cooldown 30 s
    return async (token) => (await jwtVerify(token, keys, { ...options, algorithms: ["ES256", "EdDSA"] })).payload;
  }
  const secret = new TextEncoder().encode(cfg.secret);
  return async (token) => (await jwtVerify(token, secret, { ...options, algorithms: ["HS256"] })).payload;
}

export function authenticate(cfg: AuthConfig) {
  const verify = verifier(cfg);
  return createMiddleware<AppEnv>(async (c, next) => {
    const token = BEARER.exec(c.req.header("authorization") ?? "")?.[1];
    if (token === undefined) throw unauthenticated("A bearer token is required", false);
    const payload = await verify(token).catch((err: unknown) => {
      if (err instanceof errors.JOSEError && !KEY_SOURCE_DOWN.has(err.code)) throw unauthenticated("The access token is invalid or expired", true);
      throw new ProblemError("unavailable", "The token issuer's keys are unreachable", { headers: { "Retry-After": "5" }, cause: err });
    });
    const claims = Claims.safeParse(payload);
    if (!claims.success) throw unauthenticated("The access token lacks a valid tenant or subject", true);
    c.set("actor", { tenantId: claims.data.tid, subject: claims.data.sub, roles: claims.data.roles });
    await next();
    c.header("Cache-Control", "no-store");
  });
}
```

## Probes

```ts file=src/inbound/http/health.ts
import { Hono } from "hono";
import type { AppEnv } from "./env.ts";
import { ProblemError } from "./problem.ts";

export class Readiness {
  state: "starting" | "ready" | "draining" = "starting";

  ready(): void {
    if (this.state === "starting") this.state = "ready";
  }

  drain(): void {
    this.state = "draining";
  }
}

export function probes(readiness: Readiness | undefined) {
  const app = new Hono<AppEnv>();
  app.get("/health", (c) => c.json({ status: "ok" }));
  if (readiness) {
    app.get("/ready", (c) => {
      if (readiness.state === "ready") return c.json({ status: "ready" });
      throw new ProblemError("unavailable", `Instance is ${readiness.state}`, { headers: { "Retry-After": "5" } });
    });
  }
  return app;
}
```

## Configuration

Validated once at startup. The budget check keeps drain delay, deadline, pool close and telemetry flush inside the platform's grace period.

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
      // transaction_timeout ends the session, not the statement, so the statement bound stays below it.
      statementTimeoutMs: Math.min(5_000, Math.floor(env.REQUEST_TIMEOUT_MS * 0.75)),
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

## Logging and telemetry

```ts file=src/app/logger.ts
import { isSpanContextValid, trace } from "@opentelemetry/api";
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
      return span && isSpanContextValid(span) ? { trace_id: span.traceId, span_id: span.spanId } : {};
    },
  });
}
```

Preloaded with `node --import`, so the instrumentations patch `pg` and `fetch` before the application loads them. Exporters come from the `OTEL_*` variables.

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

## Composition

```ts file=src/app/services.ts
import type { Tx, UnitOfWork } from "../domain/publishing/ports.ts";
import { Publishing } from "../domain/publishing/use-cases.ts";
import type { Services } from "../inbound/http/env.ts";
import { PgArticles } from "../outbound/postgres/articles.ts";
import type { Db } from "../outbound/postgres/db.ts";
import { pgCompletion, PgIdempotencyStore } from "../outbound/postgres/idempotency.ts";
import { pgInbox, pgOutbox } from "../outbound/postgres/outbox.ts";
import { type Bind, PgUnitOfWork } from "../outbound/postgres/unit-of-work.ts";
import { systemClock, uuidv7Ids } from "../outbound/system.ts";

/** What a publishing use case sees inside its transaction: every port bound to it, the repository to its tenant too. */
export const publishingTx: Bind<Tx> = (q, tenantId) => ({
  articles: new PgArticles(q, tenantId),
  outbox: pgOutbox(q),
  inbox: pgInbox(q),
  idempotency: pgCompletion(q),
});

/** The composition root: the only place that names concrete adapters. */
export function buildServices(db: Db, opts: { idempotencyLeaseMs: number; uow?: UnitOfWork }): Services {
  const uow = opts.uow ?? new PgUnitOfWork(db, publishingTx);
  const publishing = new Publishing({ uow, clock: systemClock, ids: uuidv7Ids });
  return { publishing, uow, idempotency: new PgIdempotencyStore(db, { leaseMs: opts.idempotencyLeaseMs }) };
}
```

## Entrypoints

The API process. Its one startup round-trip also refuses a database role that would bypass row-level security.

```ts file=src/app/main.ts
import { once } from "node:events";
import { setTimeout as sleep } from "node:timers/promises";
import { serve } from "@hono/node-server";
import { httpInstrumentationMiddleware } from "@hono/otel";
import { createApp } from "../inbound/http/app.ts";
import { Readiness } from "../inbound/http/health.ts";
import { assertRuntimeRole, connectPostgres } from "../outbound/postgres/db.ts";
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

await assertRuntimeRole(db); // the one startup round-trip; failing it fails the boot
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

The relay and the key purge, as a separate process.

```ts file=src/app/relay.ts
import { setTimeout as sleep } from "node:timers/promises";
import { metrics } from "@opentelemetry/api";
import { connectPostgres } from "../outbound/postgres/db.ts";
import { PgIdempotencyStore } from "../outbound/postgres/idempotency.ts";
import { OutboxRelay } from "../outbound/postgres/outbox.ts";
import { HttpEventPublisher } from "../outbound/publisher.ts";
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

The release step. It connects as the owning role through its own URL.

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
  const url = process.env.MIGRATION_DATABASE_URL; // the owning role, never the application's; unset would fall back to libpq's PG* defaults
  if (url === undefined || url === "") throw new Error("MIGRATION_DATABASE_URL is required");
  await migrateDatabase(url);
}
```

## Workers entry

The same app over Hyperdrive, typechecked as its own program and run with `wrangler dev` (`guide.md` § 2).

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
import { HttpEventPublisher } from "../src/outbound/publisher.ts";

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
    log.warn({ err }, "idle database client failed");
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

```jsonc file=wrangler.jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "publishing-api",
  "main": "worker/index.ts",
  // Node.js compatibility: pg opens its sockets through it, and vars and secrets arrive in process.env.
  "compatibility_date": "2026-11-01",
  "compatibility_flags": ["nodejs_compat"],
  // A Hyperdrive configuration with caching disabled, whose origin user is app_rw.
  // `wrangler dev` connects to localConnectionString, or to CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_DB when set.
  "hyperdrive": [
    { "binding": "DB", "id": "<hyperdrive-configuration-id>", "localConnectionString": "postgres://app_rw:app_rw@localhost:5432/publishing" }
  ],
  // The relay pass and the key purge run from scheduled().
  "triggers": { "crons": ["* * * * *"] }
}
```

## Manifest and tool configuration

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
    "worker": "wrangler dev",
    "typecheck": "tsc && tsc -p worker",
    "lint": "oxlint --type-aware --deny-warnings",
    "boundaries": "node scripts/boundaries.ts",
    "test": "vitest run"
  },
  "dependencies": {
    "@hono/node-server": "^2.1.9",
    "@hono/otel": "^1.3.0",
    "@hono/zod-openapi": "^1.6.3",
    "@opentelemetry/api": "^1.10.0",
    "@opentelemetry/instrumentation-pg": "^0.78.0",
    "@opentelemetry/instrumentation-undici": "^0.35.1",
    "@opentelemetry/sdk-node": "^0.301.2",
    "drizzle-orm": "~0.45.4",
    "hono": "^4.13.19",
    "jose": "^6.2.17",
    "pg": "^8.23.1",
    "pino": "^10.4.0",
    "zod": "~4.6.7"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^5.20261117.1",
    "@types/node": "^26.6.6",
    "@types/pg": "^8.23.1",
    "@typescript/native": "npm:typescript@^7.0.2",
    "dependency-cruiser": "^18.8.0",
    "drizzle-kit": "~0.31.11",
    "oxlint": "^1.94.0",
    "oxlint-tsgolint": "^7.0.2007",
    "typescript": "npm:@typescript/typescript6@^6.0.2",
    "vitest": "^5.1.0",
    "wrangler": "^4.164.0"
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
  "ignorePatterns": ["node_modules", ".wrangler", "openapi.json"]
}
```

```ts file=vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({ test: { testTimeout: 20_000 } });
```

```ts file=drizzle.config.ts
import { defineConfig } from "drizzle-kit";

export default defineConfig({ dialect: "postgresql", schema: "./src/outbound/postgres/schema.ts", out: "./migrations" });
```

## Boundary check

Run as `npm run boundaries`. It prints what to do about each violation and fails when it examined no modules.

```ts file=scripts/boundaries.ts
import { cruise, type IForbiddenRuleType } from "dependency-cruiser";
import ts from "typescript";

/** Each `comment` is the instruction printed with a violation: what to do instead. */
const forbidden: IForbiddenRuleType[] = [
  {
    name: "domain-is-pure",
    comment: "The domain imports only the domain: no package, no node: built-in, no adapter. Declare a port in src/domain and implement it under src/outbound, or pass the value in as an argument.",
    severity: "error",
    from: { path: "^src/domain/" },
    to: { pathNot: "^src/domain/" },
  },
  {
    name: "inbound-not-outbound",
    comment: "An inbound adapter reaches a store or a provider only through a domain port. Take it from c.var.services; src/app wires the concrete adapter.",
    severity: "error",
    from: { path: "^src/inbound/" },
    to: { path: "^src/(outbound|app)/" },
  },
  {
    name: "outbound-not-inbound",
    comment: "An outbound adapter knows no transport. Move the shared type into src/domain, or translate it at the inbound edge.",
    severity: "error",
    from: { path: "^src/outbound/" },
    to: { path: "^src/(inbound|app)/" },
  },
  {
    name: "no-circular",
    comment: "Break the cycle: move what both modules need into a third that imports neither.",
    severity: "error",
    from: { path: "^src/" },
    to: { circular: true },
  },
];

const { output } = await cruise(["src"], {
  validate: true,
  ruleSet: { forbidden },
  tsPreCompilationDeps: true, // `import type` counts: a type-only import of a driver type is still a leak
  doNotFollow: { path: "node_modules" },
  tsConfig: { fileName: "tsconfig.json" },
});
if (typeof output === "string") throw new TypeError(output);
const { totalCruised, violations } = output.summary;
for (const v of violations) {
  console.error(`${v.rule.name}: ${v.from} imports ${v.to}\n  fix: ${forbidden.find((rule) => rule.name === v.rule.name)?.comment ?? ""}`);
}
console.log(`typescript ${ts.version}: ${String(totalCruised)} modules checked, ${String(violations.length)} violations`);
if (totalCruised === 0) {
  // dependency-cruiser reads TypeScript through the compiler API, which TypeScript 7.0 does not ship: it then finds no modules and passes.
  console.error('The check examined 0 modules, so it proved nothing. Keep "typescript" aliased to @typescript/typescript6 until the tool supports the installed compiler.');
}
if (totalCruised === 0 || violations.length > 0) process.exit(1);
```
