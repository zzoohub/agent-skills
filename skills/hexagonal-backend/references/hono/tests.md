# Hono examples: tests

The proof: a harness on real PostgreSQL with the application's role, model tests without doubles, use cases and adapters tested together, and the HTTP risk set through the app factory. Every `file=` block is a complete file of the project in `slice.md`. `guide.md` § 8 says how each risk is forced.

## Contents

1. [Harness](#harness)
2. [Model tests](#model-tests)
3. [Use cases and adapters on PostgreSQL](#use-cases-and-adapters-on-postgresql)
4. [HTTP tests](#http-tests)
5. [Configuration tests](#configuration-tests)

## Harness

Each test file gets its own database, migrated from empty by the release step. `db` and `pool` connect as `app_rw`, so every test runs under row-level security. `owner` bypasses it and is used only to seed rows and to inspect them.

```ts file=test/support/postgres.ts
import { randomUUID } from "node:crypto";
import { Client, Pool } from "pg";
import { afterAll } from "vitest";
import { migrateDatabase } from "../../src/app/migrate.ts";
import { connectPostgres, type Db } from "../../src/outbound/postgres/db.ts";

const ADMIN_URL = process.env.TEST_DATABASE_URL ?? "postgres://postgres@localhost:5432/postgres";
/** Cluster bootstrap, outside the migrations: the application's login role. Test files race to create it. */
const APP_ROLE = "DO $$ BEGIN CREATE ROLE app_rw LOGIN PASSWORD 'app_rw'; EXCEPTION WHEN duplicate_object OR unique_violation THEN NULL; END $$";

async function admin(statement: string): Promise<void> {
  const client = new Client(ADMIN_URL);
  await client.connect();
  try {
    await client.query(statement);
  } finally {
    await client.end();
  }
}

/**
 * A database per test file, migrated from empty by the release step, dropped afterwards.
 * `db` and `pool` are the application's connection: app_rw, under row-level security.
 * `owner` is the migrating role, which bypasses it here: for seeding rows and inspecting them.
 */
export async function freshDatabase(migrated = true): Promise<{ db: Db; pool: Pool; owner: Pool; url: string }> {
  const name = `t_${randomUUID().replaceAll("-", "")}`;
  const ownerUrl = new URL(ADMIN_URL);
  ownerUrl.pathname = `/${name}`;
  const appUrl = new URL(ownerUrl);
  [appUrl.username, appUrl.password] = ["app_rw", "app_rw"];
  await admin(APP_ROLE);
  await admin(`CREATE DATABASE ${name}`);
  if (migrated) await migrateDatabase(ownerUrl.href);
  const settings = { url: appUrl.href, poolMax: 10, statementTimeoutMs: 5_000, transactionTimeoutMs: 10_000, applicationName: "tests" };
  const { pool, db } = connectPostgres(settings, () => {});
  const owner = new Pool({ connectionString: ownerUrl.href, max: 2 });
  afterAll(async () => {
    await Promise.all([pool.end(), owner.end()]);
    await admin(`DROP DATABASE ${name} WITH (FORCE)`);
  });
  return { db, pool, owner, url: appUrl.href };
}
```

The only doubles: a saboteur and an input factory. The event publisher and the key source are faked inline where a test needs them.

```ts file=test/support/doubles.ts
import type { Outbox } from "../../src/domain/shared/events.ts";

/** Always fails: wraps a real unit of work to prove the state change rolls back with the outbox row. */
export const SaboteurOutbox: Outbox = { append: () => Promise.reject(new Error("outbox unavailable")) };

/** Fresh input per test: suites share a database and isolate by tenant and slug. */
export const draft = () => ({ slug: `post-${crypto.randomUUID().slice(0, 8)}`, title: "Hello", body: "" });
```

## Model tests

```ts file=test/domain.test.ts
import { describe, expect, it } from "vitest";
import { archive, editArticle, newArticle, publish, rehydrate } from "../src/domain/publishing/article.ts";
import { DomainError } from "../src/domain/shared/errors.ts";

const now = new Date("2026-10-08T09:00:00.000Z");
const input = { id: "a1", tenantId: "t1", authorId: "alice", slug: "hello-world", title: "  Hello  ", body: "" };

function invalidFields(fn: () => unknown): string[] {
  try {
    fn();
  } catch (error) {
    if (error instanceof DomainError) return error.issues.map((i) => i.field);
  }
  return [];
}

describe("article", () => {
  it("trims the title and starts as a version-1 draft", () => {
    expect(newArticle(input, now)).toMatchObject({ title: "Hello", status: "draft", version: 1, publishedAt: null });
  });

  it.each(["Hello", "a--b", "-a", "a_b", "x".repeat(101), ""])("rejects slug %j", (slug) => {
    expect(invalidFields(() => newArticle({ ...input, slug }, now))).toEqual(["slug"]);
  });

  it("reports every invalid field, counts code points and refuses NUL", () => {
    expect(invalidFields(() => newArticle({ ...input, slug: "Bad", title: "   " }, now))).toEqual(["slug", "title"]);
    expect(invalidFields(() => newArticle({ ...input, title: "😀".repeat(200) }, now))).toEqual([]);
    expect(invalidFields(() => editArticle(newArticle(input, now), { title: "😀".repeat(201), body: "a\0" }, now))).toEqual(["title", "body"]);
  });

  it("publishes only drafts and archives only published articles", () => {
    const draft = newArticle(input, now);
    expect(archive(publish(draft, now), now)).toMatchObject({ status: "archived", publishedAt: now });
    expect(() => publish(publish(draft, now), now)).toThrow(expect.objectContaining({ code: "invalid_transition" }));
    expect(() => archive(draft, now)).toThrow(expect.objectContaining({ code: "invalid_transition" }));
  });

  it("rehydrates stored rows without re-validating them", () => {
    expect(rehydrate({ ...newArticle(input, now), title: "x".repeat(500) }).title).toHaveLength(500);
  });
});
```

## Use cases and adapters on PostgreSQL

```ts file=test/postgres.test.ts
import { randomUUID } from "node:crypto";
import { eq, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import { generateDrizzleJson, generateMigration } from "drizzle-kit/api";
import { Pool } from "pg";
import { describe, expect, it } from "vitest";
import { buildServices, publishingTx } from "../src/app/services.ts";
import type { Article } from "../src/domain/publishing/article.ts";
import type { UnitOfWork } from "../src/domain/publishing/ports.ts";
import type { EventPublisher } from "../src/domain/shared/events.ts";
import type { Actor } from "../src/domain/shared/ports.ts";
import { assertRuntimeRole, connectPostgres } from "../src/outbound/postgres/db.ts";
import { PgIdempotencyStore } from "../src/outbound/postgres/idempotency.ts";
import { OutboxRelay, RELAY_DEFAULTS } from "../src/outbound/postgres/outbox.ts";
import * as schema from "../src/outbound/postgres/schema.ts";
import { PgUnitOfWork } from "../src/outbound/postgres/unit-of-work.ts";
import { draft, SaboteurOutbox } from "./support/doubles.ts";
import { freshDatabase } from "./support/postgres.ts";

const { db, owner, url } = await freshDatabase();
const unmigrated = await freshDatabase(false); // for the schema mirror test
const uow = new PgUnitOfWork(db, publishingTx);
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

describe("article repository", () => {
  it("walks the keyset over rows sharing one now() with no duplicates or gaps", async () => {
    const tenant = randomUUID();
    await owner.query(
      `INSERT INTO app.articles (id, tenant_id, author_id, slug, title, body, status, version, created_at, updated_at)
       SELECT uuidv7(), $1, 'alice', 'post-' || g, 'Post ' || g, '', 'draft', 1, now(), now() FROM generate_series(1, 9) AS g`,
      [tenant],
    );
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
    const actor = as(randomUUID());
    const article = await publishing.create(actor, draft());
    expect(await uow.run(actor, (tx) => tx.articles.update({ ...article, title: "A" }, 1))).toMatchObject({ version: 2 });
    expect(await uow.run(actor, (tx) => tx.articles.update({ ...article, title: "B" }, 1))).toBeNull();
    expect(await uow.run(actor, (tx) => tx.articles.transition({ ...article, status: "archived" }, "published"))).toBeNull();
    const escaped = await uow.run(actor, (tx) => Promise.resolve(tx));
    await expect(escaped.articles.get(article.id)).rejects.toThrow("late work refused");
  });

  it("answers a deadlock with unavailable instead of retrying the unit, on UTC sessions", async () => {
    expect((await db.execute(sql`SHOW TimeZone`)).rows).toEqual([{ TimeZone: "UTC" }]);
    const actor = as(randomUUID());
    const [a, b] = [await publishing.create(actor, draft()), await publishing.create(actor, draft())];
    const locked = [Promise.withResolvers<void>(), Promise.withResolvers<void>()] as const;
    const cross = (first: Article, second: Article, mine: PromiseWithResolvers<void>) =>
      uow.run(actor, async (tx) => {
        await tx.articles.update({ ...first, title: "1" }, 1);
        mine.resolve();
        await Promise.all(locked.map((l) => l.promise)); // each holds its first row lock, then reaches for the other's
        await tx.articles.update({ ...second, title: "2" }, 1);
      });
    const results = await Promise.allSettled([cross(a, b, locked[0]), cross(b, a, locked[1])]);
    expect(results.map((r) => r.status).toSorted()).toEqual(["fulfilled", "rejected"]);
    expect(results.find((r) => r.status === "rejected")).toMatchObject({ reason: { code: "unavailable" } });
  });
});

describe("use cases on PostgreSQL", () => {
  it("publishes a draft once under concurrency with one outbox row, and not at all when the outbox fails", async () => {
    const actor = as(randomUUID());
    const { id } = await publishing.create(actor, draft());
    const results = await Promise.allSettled([1, 2, 3, 4, 5, 6].map(() => publishing.publish(actor, id)));
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    expect(await db.select().from(schema.outbox).where(eq(schema.outbox.aggregateId, id))).toMatchObject([
      { eventType: "article.published", eventVersion: 1, aggregateSeq: 2 },
    ]);
    const sabotaged: UnitOfWork = { run: (who, work) => uow.run(who, (tx) => work({ ...tx, outbox: SaboteurOutbox })) };
    const second = await publishing.create(actor, draft());
    const broken = buildServices(db, { idempotencyLeaseMs: 1, uow: sabotaged }).publishing;
    await expect(broken.publish(actor, second.id)).rejects.toThrow("outbox unavailable");
    expect(await publishing.get(actor, second.id)).toMatchObject({ status: "draft", version: 1 });
  });

  it("decides authorization before the precondition, and lets only an editor or a moderator archive", async () => {
    const tenant = randomUUID();
    const { id } = await publishing.create(as(tenant), draft());
    await expect(publishing.update(as(tenant, "bob"), id, { title: "Mine" }, () => false)).rejects.toMatchObject({ code: "forbidden" });
    await expect(publishing.update(as(tenant, "bob", ["editor"]), id, { title: "Ok" })).resolves.toMatchObject({ version: 2 });
    await publishing.publish(as(tenant), id);
    await expect(publishing.archive(as(tenant), id)).rejects.toMatchObject({ code: "forbidden" });
    await expect(publishing.archive(as(tenant, "mod", ["moderator"]), id)).resolves.toMatchObject({ status: "archived", version: 4 });
  });
});

describe("tenant isolation", () => {
  it("keeps another tenant's article invisible to get, list and publish", async () => {
    const article = await publishing.create(as(randomUUID()), draft());
    const stranger = as(randomUUID(), "mallory", ["editor"]);
    await expect(publishing.get(stranger, article.id)).rejects.toMatchObject({ code: "not_found" });
    await expect(publishing.publish(stranger, article.id)).rejects.toMatchObject({ code: "not_found" });
    expect(await publishing.list(stranger, { limit: 100 })).toMatchObject({ items: [] });
  });

  it("scopes a query that forgot its tenant predicate, and leaves no tenant on the connection", async () => {
    const [a, b] = [as(randomUUID()), as(randomUUID())];
    for (const actor of [a, a, b]) await publishing.create(actor, draft());
    const everything = sql`SELECT count(*)::int AS n FROM app.articles`;
    // One connection, so each statement below provably reuses the one the transactions ran on.
    const single = connectPostgres({ url, poolMax: 1, statementTimeoutMs: 5_000, transactionTimeoutMs: 10_000, applicationName: "tests" }, () => {});
    const probe = new PgUnitOfWork(single.db, (q) => q);
    expect((await probe.run(a, (q) => q().execute(everything))).rows).toEqual([{ n: 2 }]);
    expect((await probe.run(b, (q) => q().execute(everything))).rows).toEqual([{ n: 1 }]);
    const after = sql`SELECT current_setting('app.current_tenant', true) AS tenant, (SELECT count(*)::int FROM app.articles) AS n`;
    expect((await single.db.execute(after)).rows).toEqual([{ tenant: "", n: 0 }]);
    await single.pool.end();
  });

  it("refuses a row for another tenant, and a nested run that would switch tenants", async () => {
    const [a, b] = [as(randomUUID()), as(randomUUID())];
    const article = await publishing.create(a, draft());
    const smuggled = { ...article, id: randomUUID(), slug: "smuggled", tenantId: b.tenantId };
    await expect(uow.run(a, (tx) => tx.articles.insert(smuggled))).rejects.toThrow("database error 42501");
    await expect(uow.run(a, () => uow.run(b, (tx) => tx.articles.get(article.id)))).rejects.toThrow("another tenant");
  });

  it("refuses to start on a role that bypasses row-level security", async () => {
    await expect(assertRuntimeRole(db)).resolves.toBeUndefined();
    await expect(assertRuntimeRole(drizzle(owner))).rejects.toThrow("bypasses row-level security");
  });
});

describe("idempotency store", () => {
  it("grants an expired lease to one taker, fences the old holder out and keeps the key from the purge", async () => {
    const [store, scope, key] = [new PgIdempotencyStore(db, { leaseMs: 30_000 }), randomUUID(), randomUUID()];
    await store.acquire(scope, key, "hash");
    // The holder died: its lease ran out, and the key is a second away from the purge.
    const died = "UPDATE app.idempotency_keys SET locked_until = now() - interval '1 second', expires_at = now() + interval '1 second' WHERE key = $1 RETURNING lease_token";
    const held = String((await owner.query<{ lease_token: string }>(died, [key])).rows[0]?.lease_token);
    const takers = await Promise.all([1, 2, 3].map(() => store.acquire(scope, key, "hash")));
    expect(takers.map((t) => t.kind).toSorted()).toEqual(["execute", "in_flight", "in_flight"]);
    const stored = { status: 201, headers: {}, body: new Uint8Array() };
    await expect(uow.run(as(randomUUID()), (tx) => tx.idempotency.complete(scope, key, held, stored))).rejects.toThrow("taken over");
    const spared = "SELECT expires_at > now() + interval '23 hours' AS fresh FROM app.idempotency_keys WHERE key = $1";
    expect((await owner.query(spared, [key])).rows).toEqual([{ fresh: true }]);
  });
});

describe("outbox relay", () => {
  const [failing, published] = [new Set<string>(), [] as string[]];
  const broker: EventPublisher = {
    publish: (m) => {
      if (failing.has(m.aggregateId)) return Promise.reject(new Error("rejected by broker"));
      published.push(`${m.aggregateId}:${String(m.aggregateSeq)}`);
      return Promise.resolve();
    },
  };

  it("relays each aggregate in sequence, hands claims back on stop and dead-letters after the last attempt", async () => {
    await owner.query("DELETE FROM app.outbox");
    const [a, b] = [randomUUID(), randomUUID()];
    for (const [aggregateId, aggregateSeq] of [[a, 1], [a, 2], [b, 1], [a, 3]] as const) {
      await uow.run(as(a), (tx) => tx.outbox.append({ type: "t", version: 1, tenantId: a, aggregateType: "article", aggregateId, aggregateSeq, payload: {} }));
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

  it("claims one batch per pass whatever the plan, and each row once when relays race", async () => {
    await owner.query("DELETE FROM app.outbox");
    await owner.query(
      `INSERT INTO app.outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload, created_at)
       SELECT $1, 'article', uuidv7(), 1, 't', 1, '{}', now() - make_interval(secs => 1000 - g) FROM generate_series(1, 200) AS g`,
      [randomUUID()], // oldest first on disk, the way an outbox fills
    );
    const sent: string[] = [];
    const counting: EventPublisher = { publish: (m) => Promise.resolve(void sent.push(m.id)) };
    // The plan that re-runs an `id IN (SELECT … LIMIT n FOR UPDATE SKIP LOCKED)` subquery per row, which then claims all 200.
    const rescan = ["hashjoin", "mergejoin", "material", "hashagg", "sort", "indexscan", "bitmapscan", "indexonlyscan"];
    const forced = new Pool({ connectionString: url, options: rescan.map((node) => `-c enable_${node}=off`).join(" ") });
    expect(await new OutboxRelay(drizzle(forced), counting, { ...RELAY_DEFAULTS, batchSize: 5 }).runOnce()).toBe(5);
    await forced.end();
    const relay = new OutboxRelay(db, counting, { ...RELAY_DEFAULTS, batchSize: 5 });
    const claimed = await Promise.all(Array.from({ length: 16 }, () => relay.runOnce()));
    expect(Math.max(...claimed)).toBe(5);
    expect(new Set(sent).size).toBe(sent.length);
  });
});

/** Columns, keys and indexes as PostgreSQL normalizes them; CHECK constraints, policies and grants live only in SQL. */
const catalog = async (pool: Pool) =>
  (
    await pool.query<{ entry: string }>(`
      SELECT format('%s.%s %s null=%s default=%s', table_name, column_name, data_type, is_nullable, column_default) AS entry
        FROM information_schema.columns WHERE table_schema = 'app'
      UNION ALL SELECT format('%s %s %s', conrelid::regclass, conname, pg_get_constraintdef(oid))
        FROM pg_constraint WHERE connamespace = 'app'::regnamespace AND contype <> 'c'
      UNION ALL SELECT indexdef FROM pg_indexes WHERE schemaname = 'app' ORDER BY 1`)
  ).rows.map((r) => r.entry);

describe("schema mirror", () => {
  it("keeps the Drizzle schema identical to the SQL migrations", async () => {
    const empty = unmigrated.owner;
    for (const statement of await generateMigration(generateDrizzleJson({}), generateDrizzleJson(schema))) await empty.query(statement);
    const migrated = await catalog(owner);
    expect(migrated).toContain("app.articles uq_articles_tenant_slug UNIQUE (tenant_id, slug)"); // not two empty catalogs
    expect(await catalog(empty)).toEqual(migrated);
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
const { db, owner } = await freshDatabase();

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
    const blocker = await owner.connect(); // the owner sees the row whatever the tenant
    await blocker.query("BEGIN");
    await blocker.query("SELECT 1 FROM app.articles WHERE id = $1 FOR UPDATE", [path.split("/").at(-1)]);
    const key = randomUUID();
    const first = publish(path, { "idempotency-key": key });
    await vi.waitFor(async () => {
      expect((await db.execute(sql`SELECT 1 FROM app.idempotency_keys WHERE key = ${key}`)).rows).toHaveLength(1);
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

  it("acks a signed payload that fails its schema, so the sender stops retrying it", async () => {
    const body = JSON.stringify({ tenant_id: T1, article_id: "42", verdict: "rejected" });
    expect((await deliver(body, signWebhook(randomUUID(), body))).status).toBe(204);
  });

  it("archives once, tolerating unknown fields, and acks a redelivery without a second effect", async () => {
    const path = await create();
    const id = path.split("/").at(-1);
    await publish(path);
    const body = JSON.stringify({ tenant_id: T1, article_id: id, verdict: "rejected", reviewer: "bot-7" });
    const headers = signWebhook(randomUUID(), body);
    expect((await deliver(body, headers)).status).toBe(204);
    expect(await json(call("GET", path, alice))).toMatchObject({ data: { status: "archived" } });
    await owner.query("UPDATE app.articles SET status = 'published' WHERE id = $1", [id]);
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

Each case is a startup refusal that would otherwise fail in production.

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
