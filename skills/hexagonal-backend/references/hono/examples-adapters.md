# Hono examples — adapters

Inbound HTTP and the webhook receiver; outbound PostgreSQL. Each `file=` block is a complete file of the verified project; `createApp` is in `examples-bootstrap.md`.

## Contents

1. [Request context and problem documents](#request-context-and-problem-documents)
2. [Authentication to Actor](#authentication-to-actor)
3. [Idempotency middleware](#idempotency-middleware)
4. [Article routes](#article-routes)
5. [Probes and the moderation webhook](#probes-and-the-moderation-webhook)
6. [Schema and migration](#schema-and-migration)
7. [Connection and error translation](#connection-and-error-translation)
8. [Unit of work and article repository](#unit-of-work-and-article-repository)
9. [Outbox, inbox and relay](#outbox-inbox-and-relay)
10. [Idempotency store and system adapters](#idempotency-store-and-system-adapters)

## Request context and problem documents

```ts file=src/inbound/http/env.ts
import type { UnitOfWork } from "../../domain/publishing/ports.ts";
import type { Publishing } from "../../domain/publishing/use-cases.ts";
import type { IdempotencyStore } from "../../domain/shared/idempotency.ts";
import type { Actor } from "../../domain/shared/ports.ts";

export interface Logger {
  info(fields: object, message: string): void;
  warn(fields: object, message: string): void;
  error(fields: object, message: string): void;
  child(bindings: Record<string, unknown>): Logger;
}

export type Services = Readonly<{ publishing: Publishing; uow: UnitOfWork; idempotency: IdempotencyStore }>;

export interface AppEnv {
  Variables: { log: Logger; actor: Actor; services: Services };
}
```

```ts file=src/inbound/http/problem.ts
import { STATUS_CODES } from "node:http";
import type { z } from "@hono/zod-openapi";
import type { Context } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import { DomainError, type ErrorCode } from "../../domain/shared/errors.ts";

/** api-design.md § Problem Types: each type's status and fixed title. */
const TYPES = {
  "malformed-request": [400, "Malformed request"],
  unauthenticated: [401, "Unauthenticated"],
  forbidden: [403, "Forbidden"],
  "not-found": [404, "Not found"],
  "method-not-allowed": [405, "Method not allowed"],
  "not-acceptable": [406, "Not acceptable"],
  "already-exists": [409, "Already exists"],
  "invalid-transition": [409, "Invalid transition"],
  "version-conflict": [409, "Version conflict"],
  "idempotency-in-flight": [409, "Request in progress"],
  "precondition-failed": [412, "Precondition failed"],
  "payload-too-large": [413, "Payload too large"],
  "unsupported-media-type": [415, "Unsupported media type"],
  "validation-failed": [422, "Validation failed"],
  "idempotency-key-mismatch": [422, "Idempotency key mismatch"],
  "precondition-required": [428, "Precondition required"],
  "rate-limited": [429, "Too many requests"],
  internal: [500, "Internal error"],
  unavailable: [503, "Service unavailable"],
} as const satisfies Record<string, readonly [ContentfulStatusCode, string]>;

export type ProblemType = keyof typeof TYPES;
export type ProblemIssue = Readonly<{ pointer?: string; parameter?: string; detail: string; code: string }>;

/** A registry type, or a bare status outside the registry (rendered as about:blank). */
export class ProblemError extends Error {
  override readonly name = "ProblemError";
  readonly type: ProblemType | ContentfulStatusCode;
  readonly headers: Record<string, string>;
  readonly errors: readonly ProblemIssue[];

  constructor(type: ProblemType | ContentfulStatusCode, detail: string, init: { headers?: Record<string, string>; errors?: ProblemIssue[]; cause?: unknown } = {}) {
    super(detail, { cause: init.cause });
    this.type = type;
    this.headers = init.headers ?? {};
    this.errors = init.errors ?? [];
  }
}

const BY_CODE = {
  invalid: "validation-failed",
  malformed: "malformed-request",
  not_found: "not-found",
  forbidden: "forbidden",
  already_exists: "already-exists",
  invalid_transition: "invalid-transition",
  version_conflict: "version-conflict",
  precondition_failed: "precondition-failed",
  unavailable: "unavailable",
} as const satisfies Record<ErrorCode, ProblemType>;

const isType = (t: string): t is ProblemType => Object.hasOwn(TYPES, t);
const retry = (type: ProblemType | number) => (type === "unavailable" || type === "rate-limited" ? { "Retry-After": "2" } : {});

export function toProblem(err: Error): ProblemError {
  if (err instanceof ProblemError) return err;
  if (err instanceof DomainError) {
    const type = BY_CODE[err.code];
    const errors = err.issues.map((i) => ({ pointer: `#/${i.field}`, detail: i.detail, code: i.code }));
    return new ProblemError(type, err.message, { errors, headers: retry(type) });
  }
  if (err instanceof HTTPException && err.status !== 500) {
    // Keep the status (its type when exactly one has it, else about:blank) and the headers.
    const [only, ...more] = Object.keys(TYPES).filter((t) => isType(t)).filter((t) => TYPES[t][0] === err.status);
    const type = only !== undefined && more.length === 0 ? only : err.status;
    const headers = new Headers(retry(type));
    for (const [name, value] of err.getResponse().headers) if (!name.startsWith("content-")) headers.set(name, value);
    return new ProblemError(type, err.message, { headers: Object.fromEntries(headers) });
  }
  return new ProblemError("internal", "An unexpected error occurred", { cause: err });
}

export function renderProblem(c: Context, base: string, p: ProblemError): Response {
  const [status, title] = typeof p.type === "number" ? ([p.type, STATUS_CODES[p.type] ?? "Error"] as const) : TYPES[p.type];
  const type = typeof p.type === "number" ? "about:blank" : `${base}${p.type}`;
  const body = { type, title, status, detail: p.message === "" ? title : p.message, instance: c.req.path };
  const headers = { ...p.headers, "Content-Type": "application/problem+json" };
  return c.json(p.errors.length > 0 ? { ...body, errors: p.errors } : body, status, headers);
}

/** RFC 6901 in URI-fragment form; "#" is the whole body. */
const pointer = (path: readonly PropertyKey[]) => ["#", ...path.map((p) => String(p).replaceAll("~", "~0").replaceAll("/", "~1"))].join("/");

/** For the defaultHook: an unparseable path parameter is 400; any other failed validation is 422. */
export function validationProblem(error: z.ZodError, target: string): ProblemError {
  if (target === "param") return new ProblemError("malformed-request", "A path parameter is not a valid identifier");
  const errors = error.issues.flatMap((issue) => {
    const unknown = issue.code === "unrecognized_keys";
    const code = unknown ? "unknown_field" : issue.code;
    return (unknown ? issue.keys.map((k) => [...issue.path, k]) : [issue.path]).map((path) =>
      target === "json" ? { pointer: pointer(path), detail: issue.message, code } : { parameter: String(path[0] ?? target), detail: issue.message, code },
    );
  });
  return new ProblemError("validation-failed", `${String(errors.length)} invalid value(s)`, { errors });
}
```

## Authentication to Actor

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

## Idempotency middleware

Applied per route, after auth; never in a handler.

```ts file=src/inbound/http/idempotency.ts
import { createMiddleware } from "hono/factory";
import { DomainError } from "../../domain/shared/errors.ts";
import { LeaseLostError, type StoredResponse } from "../../domain/shared/idempotency.ts";
import type { AppEnv } from "./env.ts";
import { ProblemError } from "./problem.ts";

const KEY = /^[!-~]{1,255}$/u; // visible ASCII
/** Decided by headers outside the hash (Accept, Content-Type, If-Match): never stored, the key is released. */
const HEADER_DECIDED = new Set([406, 412, 415, 428]);
const storable = (status: number) => status < 500 && !HEADER_DECIDED.has(status);
class Rollback extends Error {}

const sortKeys = (_key: string, v: unknown): unknown =>
  v !== null && typeof v === "object" && !Array.isArray(v) ? Object.fromEntries(Object.entries(v).toSorted(([a], [b]) => (a < b ? -1 : 1))) : v;

/** Method, path with query, and the body with keys sorted at every depth; a body that is not JSON hashes as sent. */
async function requestHash(method: string, target: string, body: string): Promise<string> {
  let canonical = body;
  try {
    canonical = JSON.stringify(JSON.parse(body), sortKeys);
  } catch {
    // not JSON: validation answers 400 after the key is taken, and that 400 is replayed
  }
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${method} ${target}\n${canonical}`));
  return Buffer.from(digest).toString("hex");
}

async function snapshot(res: Response): Promise<StoredResponse> {
  const headers = Object.fromEntries([...res.headers].filter(([name]) => ["content-type", "location", "etag"].includes(name)));
  return { status: res.status, headers, body: new Uint8Array(await res.clone().arrayBuffer()) };
}

export const idempotent = createMiddleware<AppEnv>(async (c, next) => {
  const key = c.req.header("idempotency-key");
  if (key === undefined) return next();
  if (!KEY.test(key)) throw new ProblemError("malformed-request", "Idempotency-Key must be 1-255 visible ASCII characters");
  const { actor, services } = c.var;
  const scope = `${actor.tenantId}:${actor.subject}`;
  const { pathname, search } = new URL(c.req.url);
  const acquired = await services.idempotency.acquire(scope, key, await requestHash(c.req.method, pathname + search, await c.req.text()));
  if (acquired.kind === "replay") {
    const { body, status, headers } = acquired.response;
    return new Response(body, { status, headers: { ...headers, "Idempotent-Replayed": "true" } });
  }
  if (acquired.kind === "mismatch") throw new ProblemError("idempotency-key-mismatch", "This key was used for another request");
  if (acquired.kind === "in_flight") {
    throw new ProblemError("idempotency-in-flight", "A request with this key is still running", { headers: { "Retry-After": "1" } });
  }
  const { lease } = acquired;
  const release = () => services.idempotency.release(scope, key, lease).catch(() => {});
  try {
    await services.uow.run(async (tx) => {
      await next();
      if (c.error !== undefined || !storable(c.res.status)) throw new Rollback();
      await tx.idempotency.complete(scope, key, lease, await snapshot(c.res));
    });
  } catch (err) {
    if (!(err instanceof Rollback)) {
      await release();
      throw err instanceof LeaseLostError ? new DomainError("unavailable", "The idempotency lease expired", { cause: err }) : err;
    }
    // The handler's writes rolled back: store the 4xx in a fresh unit, or free the key.
    if (storable(c.res.status)) await services.uow.run(async (tx) => tx.idempotency.complete(scope, key, lease, await snapshot(c.res))).catch(release);
    else await release();
  }
});
```

## Article routes

```ts file=src/inbound/http/articles.ts
import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { type Article, LIMITS, SLUG_PATTERN } from "../../domain/publishing/article.ts";
import { MAX_PAGE } from "../../domain/publishing/use-cases.ts";
import type { AppEnv } from "./env.ts";
import { idempotent } from "./idempotency.ts";

const ArticleData = z
  .object({
    id: z.uuid(),
    slug: z.string(),
    title: z.string(),
    body: z.string(),
    status: z.enum(["draft", "published", "archived"]),
    version: z.int(),
    author_id: z.string(),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
    published_at: z.iso.datetime().nullable(),
  })
  .openapi("Article");
const Single = z.object({ data: ArticleData }).openapi("ArticleResponse");
const Meta = z.object({ limit: z.int(), next_cursor: z.string().nullable(), has_more: z.boolean() });
const PageOf = z.object({ data: z.array(ArticleData), meta: Meta }).openapi("ArticlePage");
const Issue = z.looseObject({ detail: z.string(), code: z.string() });
const Problem = z
  .object({ type: z.url(), title: z.string(), status: z.int(), detail: z.string(), instance: z.string(), errors: z.array(Issue).optional() })
  .openapi("Problem");

const Create = z
  .strictObject({
    slug: z.string().openapi({ pattern: SLUG_PATTERN, maxLength: LIMITS.slug }),
    title: z.string().openapi({ minLength: 1, maxLength: LIMITS.title }),
    body: z.string().openapi({ maxLength: LIMITS.body }),
  })
  .openapi("CreateArticle");
const Patch = z.strictObject({ title: z.string().optional(), body: z.string().nullable().optional() }).openapi("UpdateArticle");
const params = z.object({ id: z.uuid().openapi({ param: { name: "id", in: "path" } }) });
/** Decimal digits: 0, 1.5 and 1e3 are 422; above 100 clamps to 100, 2^64 too. */
const limit = z.string().regex(/^\d+$/u, "must be an integer").transform((s) => Math.min(Number(s), MAX_PAGE)).pipe(z.number().min(1)).default(20);
const query = z.strictObject({ limit: limit.openapi({ type: "integer", minimum: 1, default: 20 }), cursor: z.string().optional() });
const none = z.strictObject({});
const keyHeader = z.object({ "idempotency-key": z.string().optional() });
const json = <S extends z.ZodType>(schema: S) => ({ "application/json": { schema } });

const security = [{ bearerAuth: [] }];
const ok = (schema: z.ZodType) => ({ description: "Success", content: json(schema) });
const problem = { description: "Problem", content: { "application/problem+json": { schema: Problem } } };

const routes = {
  create: createRoute({
    method: "post",
    path: "/",
    security,
    middleware: [idempotent] as const,
    request: { query: none, headers: keyHeader, body: { required: true, content: json(Create) } },
    responses: { 201: ok(Single), default: problem },
  }),
  list: createRoute({ method: "get", path: "/", security, request: { query }, responses: { 200: ok(PageOf), default: problem } }),
  get: createRoute({ method: "get", path: "/{id}", security, request: { query: none, params }, responses: { 200: ok(Single), default: problem } }),
  update: createRoute({
    method: "patch",
    path: "/{id}",
    security,
    request: {
      query: none,
      params,
      headers: z.object({ "if-match": z.string().optional() }),
      body: { required: true, content: { ...json(Patch), "application/merge-patch+json": { schema: Patch } } },
    },
    responses: { 200: ok(Single), default: problem },
  }),
  publish: createRoute({
    method: "post",
    path: "/{id}/publish",
    security,
    middleware: [idempotent] as const,
    request: { query: none, params, headers: keyHeader },
    responses: { 200: ok(Single), default: problem },
  }),
};

const etag = (version: number) => `"${String(version)}"`;
const TAG = /(W\/)?"[!#-~\u0080-\u00FF]*"/gu;

/** RFC 9110 § 13.1.1: absent or `*` is unconditional; otherwise only an exactly equal strong tag matches. */
function ifMatch(header: string | undefined): ((version: number) => boolean) | undefined {
  if (header === undefined || header.trim() === "*") return undefined;
  const wellFormed = header.replaceAll(TAG, "").replaceAll(/[\s,]/gu, "") === "";
  const strong = new Set([...header.matchAll(TAG)].filter((m) => m[1] === undefined).map((m) => m[0]));
  return (version) => wellFormed && strong.has(etag(version));
}

const wire = (a: Article) => ({
  id: a.id,
  slug: a.slug,
  title: a.title,
  body: a.body,
  status: a.status,
  version: a.version,
  author_id: a.authorId,
  created_at: a.createdAt.toISOString(),
  updated_at: a.updatedAt.toISOString(),
  published_at: a.publishedAt?.toISOString() ?? null,
});

export function articleRoutes() {
  const app = new OpenAPIHono<AppEnv>();
  app.openapi(routes.create, async (c) => {
    const a = await c.var.services.publishing.create(c.var.actor, c.req.valid("json"));
    return c.json({ data: wire(a) }, 201, { Location: `/v1/articles/${a.id}`, ETag: etag(a.version) });
  });
  app.openapi(routes.list, async (c) => {
    const { limit: used, cursor } = c.req.valid("query");
    const page = await c.var.services.publishing.list(c.var.actor, { cursor, limit: used });
    return c.json({ data: page.items.map(wire), meta: { limit: used, next_cursor: page.nextCursor, has_more: page.hasMore } }, 200);
  });
  app.openapi(routes.get, async (c) => {
    const a = await c.var.services.publishing.get(c.var.actor, c.req.valid("param").id);
    return c.json({ data: wire(a) }, 200, { ETag: etag(a.version) });
  });
  app.openapi(routes.update, async (c) => {
    const { title, body } = c.req.valid("json"); // merge patch: absent stays, a null body clears it
    const precondition = ifMatch(c.req.header("if-match"));
    const a = await c.var.services.publishing.update(c.var.actor, c.req.valid("param").id, { title, body: body === null ? "" : body }, precondition);
    return c.json({ data: wire(a) }, 200, { ETag: etag(a.version) });
  });
  app.openapi(routes.publish, async (c) => {
    const a = await c.var.services.publishing.publish(c.var.actor, c.req.valid("param").id);
    return c.json({ data: wire(a) }, 200, { ETag: etag(a.version) });
  });
  return app;
}
```

## Probes and the moderation webhook

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

```ts file=src/inbound/webhooks/moderation.ts
import { createHmac, timingSafeEqual } from "node:crypto";
import { Hono } from "hono";
import { z } from "zod";
import { DomainError } from "../../domain/shared/errors.ts";
import { systemActor } from "../../domain/shared/ports.ts";
import type { AppEnv } from "../http/env.ts";
import { ProblemError } from "../http/problem.ts";

const PERMANENT = new Set<string>(["not_found", "invalid_transition"]);
const Verdict = z.object({ tenant_id: z.uuid(), article_id: z.uuid(), verdict: z.enum(["approved", "rejected"]) });

/** Standard Webhooks: any configured secret may match any `v1,` entry; ±300 s. */
export function verifySignature(secrets: readonly string[], h: Record<"id" | "ts" | "sig", string>, body: Uint8Array): boolean {
  if (!/^\d+$/u.test(h.ts) || Math.abs(Date.now() / 1000 - Number(h.ts)) > 300) return false;
  const sent = h.sig.split(" ").flatMap((e) => (e.startsWith("v1,") ? [Buffer.from(e.slice(3), "base64")] : []));
  return secrets.some((secret) => {
    const expected = createHmac("sha256", Buffer.from(secret.replace(/^whsec_/u, ""), "base64")).update(`${h.id}.${h.ts}.`).update(body).digest();
    return sent.some((s) => s.length === expected.length && timingSafeEqual(s, expected));
  });
}

export function moderationWebhook(secrets: readonly string[]) {
  const app = new Hono<AppEnv>();
  app.post("/internal/webhooks/moderation", async (c) => {
    const h = { id: c.req.header("webhook-id") ?? "", ts: c.req.header("webhook-timestamp") ?? "", sig: c.req.header("webhook-signature") ?? "" };
    if (h.id === "" || !verifySignature(secrets, h, await c.req.bytes())) {
      throw new ProblemError("unauthenticated", "Invalid or stale signature", { headers: { "WWW-Authenticate": 'Webhook realm="moderation"' } });
    }
    const message = Verdict.safeParse(await c.req.json().catch(() => null)); // parsed only after the raw bytes verified
    const { uow, publishing } = c.var.services;
    const outcome = await uow.run(async (tx) => {
      if (!(await tx.inbox.claim("moderation", h.id))) return "duplicate";
      if (!message.success) return "invalid_payload";
      if (message.data.verdict === "approved") return "approved";
      try {
        await publishing.archive(systemActor(message.data.tenant_id, "moderation"), message.data.article_id);
        return "archived";
      } catch (err) {
        if (err instanceof DomainError && PERMANENT.has(err.code)) return err.code; // recorded and acked, never retried
        throw err;
      }
    });
    c.var.log.info({ webhook_id: h.id, outcome }, "moderation webhook");
    return c.body(null, 204);
  });
  return app;
}
```

## Schema and migration

```sql file=migrations/0000_init.sql
CREATE TABLE articles (
  id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL,
  author_id text NOT NULL,
  slug text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  status text NOT NULL,
  version integer NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  published_at timestamptz,
  CONSTRAINT articles_tenant_slug_key UNIQUE (tenant_id, slug),
  CONSTRAINT articles_status_check CHECK (status IN ('draft', 'published', 'archived')),
  CONSTRAINT articles_slug_check CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug) <= 100),
  CONSTRAINT articles_title_check CHECK (char_length(title) BETWEEN 1 AND 200),
  CONSTRAINT articles_body_check CHECK (char_length(body) <= 20000),
  CONSTRAINT articles_version_check CHECK (version >= 1)
);
CREATE INDEX articles_tenant_id_idx ON articles (tenant_id, id);

CREATE TABLE outbox (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  tenant_id uuid NOT NULL,
  aggregate_type text NOT NULL,
  aggregate_id uuid NOT NULL,
  aggregate_seq integer NOT NULL,
  event_type text NOT NULL,
  event_version integer NOT NULL,
  payload jsonb NOT NULL,
  headers jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  attempts integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_error text,
  dead_lettered_at timestamptz,
  CONSTRAINT outbox_aggregate_seq_key UNIQUE (aggregate_id, aggregate_seq)
);
CREATE INDEX outbox_pending_idx ON outbox (created_at) WHERE published_at IS NULL AND dead_lettered_at IS NULL;
CREATE INDEX outbox_dead_letter_idx ON outbox (dead_lettered_at) WHERE dead_lettered_at IS NOT NULL;

CREATE TABLE idempotency_keys (
  scope text NOT NULL,
  key text NOT NULL,
  request_hash text NOT NULL,
  lease_token uuid NOT NULL,
  locked_until timestamptz NOT NULL,
  status integer,
  headers jsonb,
  body bytea,
  completed_at timestamptz,
  expires_at timestamptz NOT NULL,
  PRIMARY KEY (scope, key)
);
CREATE INDEX idempotency_keys_expires_at_idx ON idempotency_keys (expires_at);

CREATE TABLE inbox (
  consumer text NOT NULL,
  message_id text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (consumer, message_id)
);
```

```json file=migrations/meta/_journal.json
{
  "version": "7",
  "dialect": "postgresql",
  "entries": [{ "idx": 0, "version": "7", "when": 1791446400000, "tag": "0000_init", "breakpoints": true }]
}
```

```ts file=src/outbound/postgres/schema.ts
import { sql } from "drizzle-orm";
import { customType, index, integer, jsonb, pgTable, primaryKey, text, timestamp, unique, uuid } from "drizzle-orm/pg-core";
import type { ArticleStatus } from "../../domain/publishing/article.ts";

const tz = (name: string) => timestamp(name, { withTimezone: true });
const bytea = customType<{ data: Uint8Array; driverData: Uint8Array }>({ dataType: () => "bytea" });

export const articles = pgTable(
  "articles",
  {
    id: uuid("id").primaryKey(),
    tenantId: uuid("tenant_id").notNull(),
    authorId: text("author_id").notNull(),
    slug: text("slug").notNull(),
    title: text("title").notNull(),
    body: text("body").notNull(),
    status: text("status").$type<ArticleStatus>().notNull(),
    version: integer("version").notNull(),
    createdAt: tz("created_at").notNull(),
    updatedAt: tz("updated_at").notNull(),
    publishedAt: tz("published_at"),
  },
  (t) => [unique("articles_tenant_slug_key").on(t.tenantId, t.slug), index("articles_tenant_id_idx").on(t.tenantId, t.id)],
);

export const outbox = pgTable(
  "outbox",
  {
    id: uuid("id").primaryKey().default(sql`uuidv7()`),
    tenantId: uuid("tenant_id").notNull(),
    aggregateType: text("aggregate_type").notNull(),
    aggregateId: uuid("aggregate_id").notNull(),
    aggregateSeq: integer("aggregate_seq").notNull(),
    eventType: text("event_type").notNull(),
    eventVersion: integer("event_version").notNull(),
    payload: jsonb("payload").$type<Record<string, unknown>>().notNull(),
    headers: jsonb("headers").$type<Record<string, string>>().notNull().default({}),
    createdAt: tz("created_at").notNull().defaultNow(),
    publishedAt: tz("published_at"),
    attempts: integer("attempts").notNull().default(0),
    nextAttemptAt: tz("next_attempt_at").notNull().defaultNow(),
    lastError: text("last_error"),
    deadLetteredAt: tz("dead_lettered_at"),
  },
  (t) => [
    unique("outbox_aggregate_seq_key").on(t.aggregateId, t.aggregateSeq),
    index("outbox_pending_idx").on(t.createdAt).where(sql`published_at IS NULL AND dead_lettered_at IS NULL`),
    index("outbox_dead_letter_idx").on(t.deadLetteredAt).where(sql`dead_lettered_at IS NOT NULL`),
  ],
);

export const idempotencyKeys = pgTable(
  "idempotency_keys",
  {
    scope: text("scope").notNull(),
    key: text("key").notNull(),
    requestHash: text("request_hash").notNull(),
    leaseToken: uuid("lease_token").notNull(),
    lockedUntil: tz("locked_until").notNull(),
    status: integer("status"),
    headers: jsonb("headers").$type<Record<string, string>>(),
    body: bytea("body"),
    completedAt: tz("completed_at"),
    expiresAt: tz("expires_at").notNull(),
  },
  (t) => [
    primaryKey({ name: "idempotency_keys_pkey", columns: [t.scope, t.key] }),
    index("idempotency_keys_expires_at_idx").on(t.expiresAt),
  ],
);

export const inbox = pgTable(
  "inbox",
  {
    consumer: text("consumer").notNull(),
    messageId: text("message_id").notNull(),
    receivedAt: tz("received_at").notNull().defaultNow(),
  },
  (t) => [primaryKey({ name: "inbox_pkey", columns: [t.consumer, t.messageId] })],
);
```

## Connection and error translation

```ts file=src/outbound/postgres/db.ts
import { drizzle, type NodePgDatabase, type NodePgQueryResultHKT } from "drizzle-orm/node-postgres";
import type { PgDatabase } from "drizzle-orm/pg-core";
import { Pool } from "pg";
import { DomainError } from "../../domain/shared/errors.ts";

export type Db = NodePgDatabase;
/** The pool-backed database or a transaction: the same query builder. */
export type Executor = PgDatabase<NodePgQueryResultHKT>;
export type PostgresConfig = Readonly<{ url: string; poolMax: number; statementTimeoutMs: number; transactionTimeoutMs: number; applicationName: string }>;

export function connectPostgres(cfg: PostgresConfig, onIdleError: (err: Error) => void): { pool: Pool; db: Db } {
  const pool = new Pool({
    connectionString: cfg.url,
    max: cfg.poolMax,
    connectionTimeoutMillis: 2_000, // bounds acquire and connect
    application_name: cfg.applicationName,
    statement_timeout: cfg.statementTimeoutMs,
    idle_in_transaction_session_timeout: cfg.statementTimeoutMs,
    options: `-c transaction_timeout=${String(cfg.transactionTimeoutMs)} -c TimeZone=UTC`,
  });
  pool.on("error", onIdleError);
  return { pool, db: drizzle(pool) };
}

export class DatabaseError extends Error {
  override readonly name = "DatabaseError";
}

const CONFLICTS: Record<string, string | undefined> = { articles_tenant_slug_key: "An article with this slug already exists" };
const UNAVAILABLE = /^(08|53|57P0|57014|25P0[34]|40001|40P01)/u;
const CONNECTION = /^E[A-Z]+$|timeout exceeded when trying to connect|Connection terminated|not queryable/u;

/** Drizzle wraps pg's error: walk the cause chain to the SQLSTATE or socket code. */
function driverError(err: unknown): { code: string; constraint: string; message: string } | undefined {
  let e = err;
  for (let depth = 0; depth < 5 && e instanceof Error; depth++) {
    const code = "code" in e && typeof e.code === "string" ? e.code : "";
    const constraint = "constraint" in e && typeof e.constraint === "string" ? e.constraint : "";
    if (code !== "" || CONNECTION.test(e.message)) return { code, constraint, message: e.message };
    e = e.cause;
  }
  return undefined;
}

/** Domain or sanitized errors, never Drizzle's message (it holds the SQL and its parameters). */
export function translate(err: unknown): Error {
  if (!(err instanceof Error)) return new Error(String(err));
  const driver = err instanceof DomainError ? undefined : driverError(err);
  if (!driver) return err;
  const conflict = driver.code === "23505" ? CONFLICTS[driver.constraint] : undefined;
  if (conflict !== undefined) return new DomainError("already_exists", conflict);
  const summary = new DatabaseError(`database error ${driver.code || "(connection)"} ${driver.constraint}`.trim());
  const down = UNAVAILABLE.test(driver.code) || CONNECTION.test(driver.code) || CONNECTION.test(driver.message);
  return down ? new DomainError("unavailable", "The database is temporarily unavailable", { cause: summary }) : summary;
}

/** For `.catch(rethrow)` outside a unit of work. */
export const rethrow = (err: unknown): never => {
  throw translate(err);
};
```

## Unit of work and article repository

```ts file=src/outbound/postgres/unit-of-work.ts
import { AsyncLocalStorage } from "node:async_hooks";
import type { Tx, UnitOfWork } from "../../domain/publishing/ports.ts";
import { PgArticles } from "./articles.ts";
import { type Db, type Executor, rethrow } from "./db.ts";
import { pgCompletion } from "./idempotency.ts";
import { pgInbox, pgOutbox } from "./outbox.ts";

/** READ COMMITTED, no retry loop: a deadlock surfaces as unavailable (503). */
export class PgUnitOfWork implements UnitOfWork {
  readonly #db: Db;
  readonly #open = new AsyncLocalStorage<{ tx: Tx; finished: () => boolean }>();

  constructor(db: Db) {
    this.#db = db;
  }

  run<T>(work: (tx: Tx) => Promise<T>): Promise<T> {
    const outer = this.#open.getStore();
    if (outer?.finished() === true) return Promise.reject(new Error("The unit of work already finished; this work would escape it"));
    if (outer) return work(outer.tx).catch(rethrow);
    return this.#db
      .transaction(async (dtx) => {
        let finished = false;
        const q = (): Executor => {
          if (finished) throw new Error("Transaction finished; late work refused");
          return dtx;
        };
        const tx: Tx = { articles: new PgArticles(q), outbox: pgOutbox(q), inbox: pgInbox(q), idempotency: pgCompletion(q) };
        try {
          return await this.#open.run({ tx, finished: () => finished }, () => work(tx));
        } finally {
          finished = true;
        }
      })
      .catch(rethrow);
  }
}
```

One class serves the reader (pool accessor) and the transaction-bound repository.

```ts file=src/outbound/postgres/articles.ts
import { and, desc, eq, lt, type SQL, sql } from "drizzle-orm";
import { type Article, type ArticleStatus, rehydrate } from "../../domain/publishing/article.ts";
import type { ArticleReader, ArticleRepository } from "../../domain/publishing/ports.ts";
import { MAX_PAGE } from "../../domain/publishing/use-cases.ts";
import { DomainError } from "../../domain/shared/errors.ts";
import type { Page, PageRequest } from "../../domain/shared/ports.ts";
import { type Executor, rethrow } from "./db.ts";
import { articles } from "./schema.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/u;
const encodeCursor = (id: string) => Buffer.from(`v1:${id}`).toString("base64url");

function decodeCursor(cursor: string): string {
  const raw = /^[\w-]{1,64}$/u.test(cursor) ? Buffer.from(cursor, "base64url").toString("utf8") : "";
  const id = raw.startsWith("v1:") ? raw.slice(3) : "";
  if (!UUID.test(id)) throw new DomainError("malformed", "The cursor is not valid for this list");
  return id;
}

export class PgArticles implements ArticleReader, ArticleRepository {
  readonly #q: () => Executor;

  constructor(q: () => Executor) {
    this.#q = q;
  }

  async get(tenantId: string, id: string): Promise<Article | null> {
    const where = and(eq(articles.tenantId, tenantId), eq(articles.id, id));
    const [row] = await this.#q().select().from(articles).where(where).catch(rethrow);
    return row ? rehydrate(row) : null;
  }

  async list(tenantId: string, page: PageRequest): Promise<Page<Article>> {
    const limit = Math.min(page.limit, MAX_PAGE);
    const after = page.cursor === undefined ? undefined : lt(articles.id, decodeCursor(page.cursor));
    const rows = await this.#q()
      .select()
      .from(articles)
      .where(and(eq(articles.tenantId, tenantId), after))
      .orderBy(desc(articles.id))
      .limit(limit + 1)
      .catch(rethrow);
    const items = rows.slice(0, limit).map((row) => rehydrate(row));
    const last = items.at(-1);
    const hasMore = rows.length > limit;
    return { items, hasMore, nextCursor: hasMore && last ? encodeCursor(last.id) : null };
  }

  async insert(article: Article): Promise<void> {
    await this.#q().insert(articles).values(article);
  }

  update(next: Article, expectedVersion: number): Promise<Article | null> {
    return this.#write({ title: next.title, body: next.body }, next, eq(articles.version, expectedVersion));
  }

  transition(next: Article, from: ArticleStatus): Promise<Article | null> {
    return this.#write({ status: next.status, publishedAt: next.publishedAt }, next, eq(articles.status, from));
  }

  async #write(set: Partial<Article>, next: Article, guard: SQL): Promise<Article | null> {
    const [row] = await this.#q()
      .update(articles)
      .set({ ...set, updatedAt: next.updatedAt, version: sql`${articles.version} + 1` })
      .where(and(eq(articles.tenantId, next.tenantId), eq(articles.id, next.id), guard))
      .returning();
    return row ? rehydrate(row) : null;
  }
}
```

## Outbox, inbox and relay

```ts file=src/outbound/postgres/outbox.ts
import { context, propagation } from "@opentelemetry/api";
import { and, eq, sql } from "drizzle-orm";
import type { Inbox, Outbox } from "../../domain/publishing/ports.ts";
import type { EventPublisher, OutboxMessage } from "../../domain/shared/ports.ts";
import type { Db, Executor } from "./db.ts";
import { inbox, outbox } from "./schema.ts";

export const pgOutbox = (q: () => Executor): Outbox => ({
  async append(e) {
    const headers: Record<string, string> = { "tenant-id": e.tenantId };
    propagation.inject(context.active(), headers); // traceparent, continued by the relay
    await q().insert(outbox).values({
      tenantId: e.tenantId,
      aggregateType: e.aggregateType,
      aggregateId: e.aggregateId,
      aggregateSeq: e.aggregateSeq,
      eventType: e.type,
      eventVersion: e.version,
      payload: e.payload,
      headers,
    });
  },
});

export const pgInbox = (q: () => Executor): Inbox => ({
  async claim(consumer, messageId) {
    const rows = await q().insert(inbox).values({ consumer, messageId }).onConflictDoNothing().returning();
    return rows.length === 1;
  },
});

export const RELAY_DEFAULTS = { batchSize: 50, maxAttempts: 10, leaseSeconds: 30, backoffBaseMs: 1_000, backoffCapMs: 300_000 };

export class OutboxRelay {
  readonly #db: Db;
  readonly #publisher: EventPublisher;
  readonly #opts: typeof RELAY_DEFAULTS;

  constructor(db: Db, publisher: EventPublisher, opts = RELAY_DEFAULTS) {
    this.#db = db;
    this.#publisher = publisher;
    this.#opts = opts;
  }

  /** One pass. Outcomes are fenced on the claim's `attempts`, so an expired claim cannot overwrite a newer one. */
  async runOnce(stop?: AbortSignal): Promise<number> {
    const { batchSize, leaseSeconds, maxAttempts, backoffBaseMs, backoffCapMs } = this.#opts;
    const { rows } = await this.#db.execute<OutboxMessage & { attempts: number }>(sql`
      UPDATE outbox SET attempts = attempts + 1, next_attempt_at = now() + make_interval(secs => ${leaseSeconds})
      WHERE id IN (
        SELECT o.id FROM outbox o
        WHERE o.published_at IS NULL AND o.dead_lettered_at IS NULL AND o.next_attempt_at <= now()
          AND NOT EXISTS (
            SELECT 1 FROM outbox e
            WHERE e.aggregate_id = o.aggregate_id AND e.aggregate_seq < o.aggregate_seq
              AND e.published_at IS NULL AND e.dead_lettered_at IS NULL)
        ORDER BY o.created_at LIMIT ${batchSize}
        FOR UPDATE SKIP LOCKED)
      RETURNING id, event_type AS type, event_version AS version, tenant_id AS "tenantId", aggregate_type AS "aggregateType",
        aggregate_id AS "aggregateId", aggregate_seq AS "aggregateSeq", payload, headers, attempts`);
    for (const row of rows) {
      const claim = and(eq(outbox.id, row.id), eq(outbox.attempts, row.attempts));
      if (stop?.aborted === true) {
        // Stopping: hand the claim back instead of letting its lease run out.
        await this.#db.update(outbox).set({ attempts: row.attempts - 1, nextAttemptAt: sql`now()` }).where(claim);
        continue;
      }
      try {
        await this.#publisher.publish(row);
        await this.#db.update(outbox).set({ publishedAt: sql`now()` }).where(claim);
      } catch (err) {
        const delay = (Math.random() * Math.min(backoffCapMs, backoffBaseMs * 2 ** row.attempts)) / 1000;
        await this.#db
          .update(outbox)
          .set({
            lastError: err instanceof Error ? err.message.slice(0, 500) : "publish failed",
            nextAttemptAt: sql`now() + make_interval(secs => ${delay})`,
            deadLetteredAt: row.attempts >= maxAttempts ? sql`now()` : null,
          })
          .where(claim);
      }
    }
    return rows.length;
  }

  async stats(): Promise<{ oldestPendingSeconds: number; deadLettered: number }> {
    const { rows } = await this.#db.execute<{ age: number | null; dead: number }>(sql`
      SELECT extract(epoch FROM now() - (SELECT min(created_at) FROM outbox
          WHERE published_at IS NULL AND dead_lettered_at IS NULL))::float8 AS age,
        (SELECT count(*) FROM outbox WHERE dead_lettered_at IS NOT NULL)::int AS dead`);
    return { oldestPendingSeconds: rows[0]?.age ?? 0, deadLettered: rows[0]?.dead ?? 0 };
  }
}
```

## Idempotency store and system adapters

```ts file=src/outbound/postgres/idempotency.ts
import { and, eq, isNull, lt, type SQL, sql } from "drizzle-orm";
import { type Acquired, type IdempotencyCompletion, type IdempotencyStore, LeaseLostError } from "../../domain/shared/idempotency.ts";
import { type Db, type Executor, rethrow } from "./db.ts";
import { idempotencyKeys as keys } from "./schema.ts";

const at = (scope: string, key: string) => and(eq(keys.scope, scope), eq(keys.key, key));
const owned = (scope: string, key: string, lease: string) => and(at(scope, key), eq(keys.leaseToken, lease), isNull(keys.completedAt));

export class PgIdempotencyStore implements IdempotencyStore {
  readonly #db: Db;
  readonly #lease: SQL;
  readonly #ttl: SQL;

  /** Lease > request deadline and transaction bound; TTL > every client's retry horizon. */
  constructor(db: Db, opts: { leaseMs: number; ttlHours?: number }) {
    this.#db = db;
    this.#lease = sql`now() + make_interval(secs => ${opts.leaseMs / 1000})`;
    this.#ttl = sql`now() + make_interval(hours => ${opts.ttlHours ?? 24})`;
  }

  async acquire(scope: string, key: string, requestHash: string): Promise<Acquired> {
    for (let attempt = 0; attempt < 3; attempt++) {
      const [won] = await this.#db
        .insert(keys)
        .values({ scope, key, requestHash, leaseToken: crypto.randomUUID(), lockedUntil: this.#lease, expiresAt: this.#ttl })
        .onConflictDoNothing()
        .returning()
        .catch(rethrow);
      if (won) return { kind: "execute", lease: won.leaseToken };
      const [row] = await this.#db.select().from(keys).where(at(scope, key)).catch(rethrow);
      if (!row) continue; // released or purged since our INSERT: race again
      if (row.requestHash !== requestHash) return { kind: "mismatch" };
      if (row.completedAt !== null && row.status !== null && row.body !== null) {
        return { kind: "replay", response: { status: row.status, headers: row.headers ?? {}, body: row.body } };
      }
      const [took] = await this.#db
        .update(keys)
        .set({ leaseToken: crypto.randomUUID(), lockedUntil: this.#lease })
        .where(and(at(scope, key), isNull(keys.completedAt), lt(keys.lockedUntil, sql`now()`)))
        .returning()
        .catch(rethrow);
      return took ? { kind: "execute", lease: took.leaseToken } : { kind: "in_flight" };
    }
    return { kind: "in_flight" };
  }

  async release(scope: string, key: string, lease: string): Promise<void> {
    await this.#db.delete(keys).where(owned(scope, key, lease)).catch(rethrow);
  }

  async purgeExpired(): Promise<number> {
    const result = await this.#db.delete(keys).where(lt(keys.expiresAt, sql`now()`)).catch(rethrow);
    return result.rowCount ?? 0;
  }
}

/** Inside the use case's transaction: completes only under this request's live lease. */
export const pgCompletion = (q: () => Executor): IdempotencyCompletion => ({
  async complete(scope, key, lease, r) {
    const done = await q()
      .update(keys)
      .set({ status: r.status, headers: r.headers, body: r.body, completedAt: sql`now()` })
      .where(owned(scope, key, lease))
      .returning({ key: keys.key });
    if (done.length === 0) throw new LeaseLostError("The idempotency lease was taken over");
  },
});
```

```ts file=src/outbound/system.ts
import { context, propagation, ROOT_CONTEXT } from "@opentelemetry/api";
import type { Clock, EventPublisher, IdGenerator, OutboxMessage } from "../domain/shared/ports.ts";

export const systemClock: Clock = { now: () => new Date() };

/** RFC 9562 UUIDv7 on Web Crypto: node:crypto's randomUUIDv7 does not exist on workerd. */
export const uuidv7Ids: IdGenerator = {
  next: () => {
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    const view = new DataView(bytes.buffer);
    const now = Date.now();
    view.setUint32(0, Math.floor(now / 2 ** 16));
    view.setUint16(4, now % 2 ** 16);
    view.setUint8(6, 0x70 | (view.getUint8(6) & 0x0f));
    view.setUint8(8, 0x80 | (view.getUint8(8) & 0x3f));
    const hex = Buffer.from(bytes).toString("hex");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  },
};

export class HttpEventPublisher implements EventPublisher {
  readonly #url: string;

  constructor(url: string) {
    this.#url = url;
  }

  async publish(m: OutboxMessage): Promise<void> {
    // Continue the trace captured at insert; the fetch instrumentation injects traceparent.
    const res = await context.with(propagation.extract(ROOT_CONTEXT, m.headers), () =>
      fetch(this.#url, {
        method: "POST",
        headers: { "content-type": "application/json", "idempotency-key": m.id, "tenant-id": m.tenantId },
        body: JSON.stringify({ id: m.id, type: m.type, version: m.version, subject: m.aggregateId, sequence: m.aggregateSeq, data: m.payload }),
        signal: AbortSignal.timeout(5_000),
      }),
    );
    await res.body?.cancel();
    if (!res.ok) throw new Error(`event endpoint answered ${String(res.status)}`);
  }
}
```
