# NestJS examples: tests

The proof: a harness on real PostgreSQL with the application's role, model tests without doubles, use cases and adapters tested together, and the HTTP risk set through the production modules. Every `file=` block is a complete file of the project in `slice.md`. `guide.md` § 8 says how each risk is forced.

## Contents

1. [Harness](#harness)
2. [Model tests](#model-tests)
3. [Use cases and adapters on PostgreSQL](#use-cases-and-adapters-on-postgresql)
4. [HTTP tests](#http-tests)

## Harness

One URL for the owner, from which the config derives the application's URL as `app_rw`. Every suite connects as `app_rw`, so every test runs under row-level security.

```ts file=vitest.config.ts
import { defineConfig } from "vitest/config";

// The release step connects as the owner, the application as app_rw: neither owner nor BYPASSRLS.
const owner = new URL(process.env.TEST_DATABASE_URL ?? "postgres://postgres:postgres@127.0.0.1:5432/publishing_test");
const application = new URL(owner);
[application.username, application.password] = ["app_rw", "app_rw"];

// Assigned here rather than in test.env so that globalSetup, which runs in this process, sees it too.
Object.assign(process.env, {
  APP_ENV: "test",
  LOG_LEVEL: "silent",
  MIGRATION_DATABASE_URL: owner.href,
  DATABASE_URL: application.href,
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
    fileParallelism: false, // the suites share one database and isolate by random tenant ids
    testTimeout: 15_000,
  },
});
```

The global setup creates the role if it is missing and runs the release step on an empty database.

```ts file=test/support/global-setup.ts
import { DataSource } from "typeorm";
import { postgresOptions } from "../../src/outbound/postgres/options.js";

export default async function setup(): Promise<void> {
  const owner = new URL(process.env.MIGRATION_DATABASE_URL ?? "");
  const server = new URL(owner);
  server.pathname = "/postgres";
  const admin = await new DataSource({ type: "postgres", url: server.href }).initialize();
  // Cluster bootstrap, outside the migrations: the application's role, tolerated if it exists.
  await admin.query(`DO $$ BEGIN CREATE ROLE app_rw LOGIN PASSWORD 'app_rw'; EXCEPTION WHEN duplicate_object THEN NULL; END $$`);
  const name = owner.pathname.slice(1);
  await admin.query(`DROP DATABASE IF EXISTS "${name}" WITH (FORCE)`);
  await admin.query(`CREATE DATABASE "${name}"`);
  await admin.destroy();

  // The release step: forward from empty, as the owner.
  const db = await new DataSource(postgresOptions({ url: owner.href, applicationName: "test-setup" })).initialize();
  await db.runMigrations();
  await db.destroy();
}
```

The test builder and the saboteur, which wraps the real unit of work and replaces one part of its transaction. The event publisher and the key source are faked inline where a test needs them.

```ts file=test/support/harness.ts
import type { Type } from "@nestjs/common";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { Test, type TestingModuleBuilder } from "@nestjs/testing";
import { SignJWT } from "jose";
import { createHmac, randomUUID } from "node:crypto";
import { DataSource } from "typeorm";
import { AppModule } from "../../src/app.module.js";
import { configureApp, httpAppOptions } from "../../src/configure-app.js";
import { UnitOfWork, type Tx } from "../../src/domain/publishing/ports.js";
import { TypeOrmUnitOfWork } from "../../src/outbound/postgres/unit-of-work.js";

/** The test builder: the production modules and edge on the real database, served by supertest without a port. */
export async function createApp(
  customize: (builder: TestingModuleBuilder) => TestingModuleBuilder = (builder) => builder,
  controllers: Type[] = [],
): Promise<NestExpressApplication> {
  const moduleRef = await customize(Test.createTestingModule({ imports: [AppModule], controllers })).compile();
  return configureApp(moduleRef.createNestApplication<NestExpressApplication>(httpAppOptions)).init();
}

/** A saboteur: the real unit of work with one part of its transaction replaced, to fail one step. */
export const sabotage = (part: Partial<Tx>) => (builder: TestingModuleBuilder) =>
  builder.overrideProvider(UnitOfWork).useFactory({
    inject: [DataSource],
    factory: (db: DataSource): UnitOfWork => {
      const real = new TypeOrmUnitOfWork(db);
      return { run: (actor, work) => real.run(actor, (tx) => work({ ...tx, ...part })) };
    },
  });

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

## Model tests

```ts file=test/domain/article.spec.ts
import { describe, expect, it } from "vitest";
import {
  archiveArticle, canArchive, canEdit, createArticle, editArticle, publishArticle, rehydrateArticle,
} from "../../src/domain/publishing/article.js";

// The model is pure: time and ids are arguments, so these tests need no doubles.
const created = new Date("2026-11-18T09:00:00Z");
const later = new Date("2026-11-18T10:00:00Z");
const input = { id: "0199c4e0-0000-7000-8000-000000000001", tenantId: "t1", authorId: "ada", slug: "hello", title: "Hi", body: "" };
const draft = () => createArticle(input, created);
const invalidAt = (field: string) => expect.objectContaining({ kind: "invalid", field });

describe("Article", () => {
  it("normalizes on creation and starts as a version-1 draft", () => {
    expect(createArticle({ ...input, title: "  Hello  " }, created)).toMatchObject({
      title: "Hello", status: "draft", version: 1, publishedAt: null,
    });
  });

  it.each(["", "Hello", "a--b", "-a", "a-", "a_b", "x".repeat(101)])("rejects the slug %j", (slug) => {
    expect(() => createArticle({ ...input, slug }, created)).toThrow(invalidAt("slug"));
  });

  it.each(["", "   ", "x".repeat(201), "😀".repeat(201), "a\u0000b"])("rejects the title %j", (title) => {
    expect(() => createArticle({ ...input, title }, created)).toThrow(invalidAt("title"));
  });

  it("counts characters as code points, as PostgreSQL does, not UTF-16 units", () => {
    expect(createArticle({ ...input, title: "😀".repeat(200) }, created).title).toHaveLength(400);
  });

  it("publishes a draft once and archives only a published article", () => {
    const published = publishArticle(draft(), later);
    expect(published).toMatchObject({ status: "published", publishedAt: later, updatedAt: later });
    const refused = expect.objectContaining({ kind: "conflict", code: "invalid-transition" });
    expect(() => publishArticle(published, later)).toThrow(refused);
    expect(() => archiveArticle(draft(), later)).toThrow(refused);
    expect(archiveArticle(published, later)).toMatchObject({ status: "archived", publishedAt: later });
  });

  it("leaves the version to the store: a decision never numbers its own write", () => {
    expect(editArticle(draft(), { title: "Edited" }, later)).toMatchObject({ title: "Edited", version: 1, updatedAt: later });
  });

  it("rehydrates stored rows without re-running creation rules", () => {
    const legacy = rehydrateArticle({ ...draft(), title: "x".repeat(300) }); // stored before the rule tightened
    expect(editArticle(legacy, { body: "edited" }, later)).toMatchObject({ title: "x".repeat(300), body: "edited" });
  });

  it.each([
    ["the author", true, false, { subject: "ada", roles: [] }],
    ["an editor", true, false, { subject: "eve", roles: ["editor"] }],
    ["another member", false, false, { subject: "bob", roles: [] }],
    ["moderation", false, true, { subject: "system:moderation", roles: ["moderator"] }],
  ])("%s may edit: %j, archive: %j", (_who, edits, archives, who) => {
    const actor = { tenantId: "t1", ...who };
    expect([canEdit(actor, draft()), canArchive(actor)]).toEqual([edits, archives]);
  });
});
```

## Use cases and adapters on PostgreSQL

```ts file=test/adapters/postgres.spec.ts
import type { INestApplicationContext } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { randomUUID } from "node:crypto";
import { setTimeout as sleep } from "node:timers/promises";
import { DataSource, type EntityManager } from "typeorm";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createArticle } from "../../src/domain/publishing/article.js";
import { UnitOfWork, type Tx } from "../../src/domain/publishing/ports.js";
import { Publishing } from "../../src/domain/publishing/use-cases.js";
import { IdGenerator, type Actor } from "../../src/domain/shared/ports.js";
import { Readiness } from "../../src/inbound/http/health.js";
import { TypeOrmArticles } from "../../src/outbound/postgres/article.repository.js";
import { postgresOptions } from "../../src/outbound/postgres/options.js";
import { EventPublisher, OutboxRelay, RelayOptions, type OutboxMessage } from "../../src/outbound/postgres/outbox-relay.js";
import { inTenantTransaction } from "../../src/outbound/postgres/unit-of-work.js";
import { createApp, draft, sabotage } from "../support/harness.js";

// Use cases and adapters together, on real PostgreSQL, connected as app_rw.
let app: INestApplicationContext;
let db: DataSource;
let uow: UnitOfWork;
let publishing: Publishing;
const actor = (): Actor => ({ tenantId: randomUUID(), subject: "ada", roles: [] });
const newArticle = (tenantId: string, now = new Date()) =>
  createArticle({ id: app.get(IdGenerator).next(), tenantId, authorId: "ada", ...draft() }, now);
const count = (on: DataSource | EntityManager): Promise<number> =>
  on.query(`SELECT count(*)::int AS n FROM app.articles`).then(([row]: { n: number }[]) => row?.n ?? -1); // no tenant predicate
const pid = (on: DataSource | EntityManager): Promise<number> =>
  on.query(`SELECT pg_backend_pid() AS pid`).then(([row]: { pid: number }[]) => row?.pid ?? -1);
const connect = (as: "owner" | "app_rw", poolSize?: number) =>
  new DataSource(postgresOptions({
    url: (as === "owner" ? process.env.MIGRATION_DATABASE_URL : process.env.DATABASE_URL) ?? "", applicationName: `test-${as}`, poolSize,
  })).initialize();

beforeAll(async () => {
  app = await createApp();
  [db, uow, publishing] = [app.get(DataSource), app.get(UnitOfWork), app.get(Publishing)];
});
afterAll(() => app.close());

describe("write path", () => {
  it("lets exactly one of two concurrent creates of a slug succeed", async () => {
    const [ada, input] = [actor(), draft()];
    const results = await Promise.allSettled([publishing.create(ada, input), publishing.create(ada, input)]);
    expect(results.map((r) => r.status).toSorted()).toEqual(["fulfilled", "rejected"]);
    expect(results.find((r) => r.status === "rejected")?.reason).toMatchObject({ code: "already-exists" });
  });

  it("refuses a write conditioned on a version that moved, and numbers each write in the database", async () => {
    const ada = actor();
    const article = await publishing.create(ada, draft());
    await expect(publishing.update(ada, article.id, { title: "Second" })).resolves.toMatchObject({ version: 2 });
    await expect(uow.run(ada, (tx) => tx.articles.update(article, 1))).resolves.toBeNull();
    await expect(publishing.publish(ada, article.id)).resolves.toMatchObject({ version: 3, status: "published" });
  });

  it("publishes with exactly one outbox row, and not at all when that row fails", async () => {
    const ada = actor();
    const { id } = await publishing.publish(ada, (await publishing.create(ada, draft())).id);
    const rows: unknown[] = await db.query(`SELECT event_type, aggregate_seq FROM app.outbox WHERE aggregate_id = $1`, [id]);
    expect(rows).toEqual([{ event_type: "article.published", aggregate_seq: 2 }]);

    const sabotaged = await createApp(sabotage({ outbox: { append: () => Promise.reject(new Error("outbox down")) } }));
    const created = await sabotaged.get(Publishing).create(ada, draft());
    await expect(sabotaged.get(Publishing).publish(ada, created.id)).rejects.toThrow("outbox down");
    await sabotaged.close();
    await expect(publishing.get(ada, created.id)).resolves.toMatchObject({ status: "draft", version: 1 });
  });

  it("walks newest-first pages without duplicates or gaps when every row shares one now()", async () => {
    const [ada, now] = [actor(), new Date()];
    const written = Array.from({ length: 7 }, () => newArticle(ada.tenantId, now));
    await uow.run(ada, async (tx) => {
      for (const article of written) await tx.articles.insert(article);
    });
    for (const limit of [1, 2]) {
      const seen: string[] = [];
      let cursor: string | null = null;
      do {
        const page = await publishing.list(ada, cursor, limit);
        seen.push(...page.items.map((a) => a.id));
        cursor = page.nextCursor;
      } while (cursor !== null);
      expect(seen).toEqual(written.map((a) => a.id).toSorted().toReversed());
    }
  });

  it("fails a write that outlives its unit of work instead of committing it alone", async () => {
    const ada = actor();
    let late: Promise<void> | undefined;
    await uow.run(ada, async (tx) => {
      late = sleep(20).then(() => tx.articles.insert(newArticle(ada.tenantId))); // the bug: not awaited
    });
    await expect(late).rejects.toThrow(/already released/);
    await expect(publishing.list(ada, null, 10)).resolves.toMatchObject({ items: [] });
  });

  it("retries the whole unit of work after a deadlock", async () => {
    let attempts = 0;
    const deadlock = Object.assign(new Error("deadlock detected"), { code: "40P01" });
    await expect(uow.run(actor(), async () => (++attempts === 1 ? Promise.reject(deadlock) : attempts))).resolves.toBe(2);
  });
});

describe("tenant isolation, enforced twice", () => {
  it("keeps another tenant's article invisible to get, list and publish", async () => {
    const { id } = await publishing.create(actor(), draft());
    const intruder: Actor = { ...actor(), roles: ["editor"] };
    await expect(publishing.get(intruder, id)).rejects.toMatchObject({ kind: "not_found" });
    await expect(publishing.list(intruder, null, 100)).resolves.toMatchObject({ items: [] });
    await expect(publishing.publish(intruder, id)).rejects.toMatchObject({ kind: "not_found" });
  });

  it("filters by policy when a query carries no tenant predicate, and shows the bare pool nothing", async () => {
    const [a, b] = [actor(), actor()];
    for (const owner of [a, a, b]) await publishing.create(owner, draft());
    await expect(inTenantTransaction(db, a.tenantId, count)).resolves.toBe(2);
    await expect(inTenantTransaction(db, b.tenantId, count)).resolves.toBe(1);
    await expect(count(db)).resolves.toBe(0); // no tenant set: no rows, not an error
  });

  it("filters in the repository too: for the owner, whom the policy does not bind, a foreign id is still missing", async () => {
    const a = actor();
    const { id } = await publishing.create(a, draft());
    const owner = await connect("owner");
    const [own, foreign] = [new TypeOrmArticles(owner.manager, a.tenantId), new TypeOrmArticles(owner.manager, randomUUID())];
    await expect(Promise.all([own.get(id), foreign.get(id), foreign.list(null, 10)])).resolves.toMatchObject([{ id }, null, { items: [] }]);
    await owner.destroy();
  });

  it("leaves no tenant behind on a pooled connection", async () => {
    const a = actor();
    await publishing.create(a, draft());
    const single = await connect("app_rw", 1);
    const inside = await inTenantTransaction(single, a.tenantId, async (em) => ({ rows: await count(em), pid: await pid(em) }));
    expect([inside.rows, await pid(single)]).toEqual([1, inside.pid]); // the same connection, afterwards
    await expect(count(single)).resolves.toBe(0);
    await single.destroy();
  });

  it("refuses to join an open unit of work under another tenant", async () => {
    const [a, b] = [actor(), actor()];
    await expect(uow.run(a, () => uow.run(b, (tx: Tx) => tx.articles.list(null, 1)))).rejects.toThrow("another tenant");
  });

  it("refuses to start as a role that bypasses row-level security", async () => {
    const owner = await connect("owner"); // a superuser here
    await expect(new Readiness(owner, app.get(ConfigService)).onApplicationBootstrap()).rejects.toThrow("bypasses row-level security");
    await owner.destroy();
  });
});

const enqueue = (aggregateId: string, seqs: number[]) =>
  db.query(
    `INSERT INTO app.outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload)
     SELECT $1, 'article', $2, s, 'article.published', 1, '{}' FROM unnest($3::int[]) AS s`,
    [randomUUID(), aggregateId, seqs],
  );

const head = (aggregateId: string) =>
  db.query(
    `SELECT attempts, published_at IS NOT NULL AS published, dead_lettered_at IS NOT NULL AS dead, last_error
     FROM app.outbox WHERE aggregate_id = $1 AND aggregate_seq = 1`,
    [aggregateId],
  ).then(([row]: unknown[]) => row);

describe("OutboxRelay", () => {
  const published: OutboxMessage[] = [];
  const failing = new Set<string>(); // aggregates whose first event the broker rejects
  const broker: EventPublisher = {
    publish: async (m) => {
      if (failing.has(m.aggregateId) && m.aggregateSeq === 1) throw new Error("broker down");
      published.push(m);
    },
  };
  const relay = (publisher = broker, options: Partial<RelayOptions> = {}) =>
    new OutboxRelay(db, publisher, Object.assign(new RelayOptions(), { baseDelayMs: 0, maxAttempts: 3 }, options));
  const seqsOf = (aggregateId: string) => published.filter((m) => m.aggregateId === aggregateId).map((m) => m.aggregateSeq);

  it("publishes one head per aggregate per pass, in aggregate_seq order", async () => {
    const [a, b] = [randomUUID(), randomUUID()];
    await enqueue(a, [3, 1, 2]);
    await enqueue(b, [1]);
    await relay().runOnce();
    expect([seqsOf(a), seqsOf(b)]).toEqual([[1], [1]]);
    await relay().runOnce();
    await relay().runOnce();
    expect(seqsOf(a)).toEqual([1, 2, 3]);
  });

  it("dead-letters a head after maxAttempts, and only then releases the next event", async () => {
    const a = randomUUID();
    failing.add(a);
    await enqueue(a, [1, 2]);
    for (let pass = 0; pass < 3; pass++) await relay().runOnce();
    expect(seqsOf(a)).toEqual([]);
    await expect(head(a)).resolves.toEqual({ attempts: 3, published: false, dead: true, last_error: "Error: broker down" });
    await relay().runOnce();
    expect(seqsOf(a)).toEqual([2]);
  });

  it("fences a claim whose lease ran out: its late failure cannot overwrite the newer claim's success", async () => {
    const a = randomUUID();
    await enqueue(a, [1]);
    let overtake: Promise<number> | undefined;
    const slow: EventPublisher = {
      publish: async () => {
        overtake ??= relay(broker, { claimMs: 0 }).runOnce(); // the lease is already over: a second relay claims and publishes
        await overtake;
        throw new Error("timed out after the lease");
      },
    };
    await relay(slow, { claimMs: 0 }).runOnce();
    await expect(head(a)).resolves.toEqual({ attempts: 2, published: true, dead: false, last_error: null });
  });

  it("hands its claims back when it is told to stop", async () => {
    const a = randomUUID();
    await enqueue(a, [1]);
    await relay().runOnce(AbortSignal.abort());
    expect(seqsOf(a)).toEqual([]);
    await expect(head(a)).resolves.toMatchObject({ attempts: 0, published: false });
  });

  it("claims no more than its batch when the planner re-runs the claim for every row", async () => {
    await db.query(
      `INSERT INTO app.outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload)
       SELECT $1, 'article', gen_random_uuid(), 1, 'article.published', 1, '{}' FROM generate_series(1, 200)`,
      [randomUUID()],
    );
    // The plan under which `id IN (SELECT … LIMIT n FOR UPDATE SKIP LOCKED)` runs its subquery once per row and claims them all.
    const single = await connect("app_rw", 1);
    for (const node of ["hashjoin", "mergejoin", "material", "hashagg", "sort", "indexscan", "bitmapscan", "indexonlyscan"]) {
      await single.query(`SET enable_${node} = off`);
    }
    await expect(new OutboxRelay(single, broker, Object.assign(new RelayOptions(), { batchSize: 5 })).runOnce()).resolves.toBe(5);
    await single.destroy();
  });
});
```

## HTTP tests

```ts file=test/http/api.http.spec.ts
import { Controller, Get, HttpException, Logger, NotFoundException, Param } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Reflector } from "@nestjs/core";
import { ExecutionContextHost } from "@nestjs/core/helpers/execution-context-host.js";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { ApiExcludeController } from "@nestjs/swagger";
import { exportJWK, generateKeyPair } from "jose";
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { createServer, type ServerResponse } from "node:http";
import request from "supertest";
import { DataSource } from "typeorm";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { envSchema, type Env } from "../../src/config.js";
import { ArticlesController } from "../../src/inbound/http/articles.controller.js";
import { BearerAuthGuard, Public } from "../../src/inbound/http/auth.js";
import { Readiness } from "../../src/inbound/http/health.js";
import { buildOpenApi } from "../../src/inbound/http/openapi.js";
import { bearer, createApp, draft, sabotage, signWebhook } from "../support/harness.js";

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

const segment = (value: object) => Buffer.from(JSON.stringify(value)).toString("base64url");

describe("bearer tokens against a key set", () => {
  const token = `${segment({ alg: "ES256", kid: "rotated-away" })}.${segment({ sub: "ada" })}.c2lnbmF0dXJl`;

  /** The guard in JWKS mode against a local key source that answers with `reply`, or refuses connections without one. */
  async function verify(reply?: (res: ServerResponse) => void): Promise<unknown> {
    const server = createServer((_req, res) => reply?.(res));
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const address = server.address();
    const jwksUrl = `http://127.0.0.1:${typeof address === "object" && address ? address.port : 0}/jwks`;
    if (!reply) await new Promise((resolve) => server.close(resolve));
    const config = new ConfigService<Env, true>({ jwt: { mode: "jwks", jwksUrl, issuer: "https://auth.example.test", audience: "publishing-api" } });
    const req = { header: (name: string) => (name === "authorization" ? `Bearer ${token}` : undefined) };
    const context = new ExecutionContextHost([req, {}], ArticlesController, () => undefined);
    try {
      return await new BearerAuthGuard(new Reflector(), config).canActivate(context).catch((error: unknown) => error);
    } finally {
      server.close();
    }
  }

  it("answers 503 when the key set cannot be fetched, and 401 when it lacks the token's key", async () => {
    const keys = JSON.stringify({ keys: [{ ...(await exportJWK((await generateKeyPair("ES256")).publicKey)), kid: "current" }] });
    expect(await verify((res) => res.writeHead(503).end())).toMatchObject({ slug: "unavailable" });
    expect(await verify((res) => res.writeHead(200, { "Content-Type": "text/html" }).end("<html></html>"))).toMatchObject({ slug: "unavailable" });
    expect(await verify()).toMatchObject({ slug: "unavailable" }); // connection refused
    expect(await verify((res) => res.writeHead(200, { "Content-Type": "application/json" }).end(keys))).toMatchObject({ slug: "unauthenticated" });
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

  it("replays a 4xx that the state decided, stored after the handler's writes rolled back", async () => {
    const headers = key();
    const first = await as(ada).post(`/v1/articles/${liveId}/publish`).set(headers);
    const replay = await as(ada).post(`/v1/articles/${liveId}/publish`).set(headers);
    expect([first.status, replay.status, replay.headers["idempotent-replayed"]]).toEqual([409, 409, "true"]);
    expect(replay.body).toEqual(first.body);
  });

  it("answers 409 + Retry-After while the first request holds the key", async () => {
    const [db, headers, body] = [app.get(DataSource), key(), draft()];
    const blocker = db.createQueryRunner(); // blocks inserts, so the first request waits inside its transaction
    await blocker.startTransaction();
    await blocker.query("LOCK TABLE app.articles IN SHARE MODE");
    const first = create(body, headers).then((res) => res); // then() sends it now
    const held = () => db.query(`SELECT 1 FROM app.idempotency_keys WHERE key = $1`, [headers["Idempotency-Key"]]);
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
    const failing = await createApp(sabotage({ inbox: { claim: () => Promise.reject(down) } }));
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
    class NeverReady extends Readiness {
      override async onApplicationBootstrap() {} // the startup check never completes
    }
    const starting = await createApp((b) => b.overrideProvider(Readiness).useClass(NeverReady));
    const [live, ready] = [await request(starting.getHttpServer()).get("/health/live"), await request(starting.getHttpServer()).get("/health/ready")];
    await starting.close();
    expect([live.status, ready.status, ready.headers["retry-after"], ready.body.type]).toEqual([200, 503, "2", type("unavailable")]);
  });

  it("refuses at startup a shutdown budget that the platform's grace cannot hold", () => {
    expect(envSchema.safeParse({ ...process.env, SHUTDOWN_DELAY_MS: "8000" }).success).toBe(false); // 8 s + 5 s + 3 s > 10 s
    expect(envSchema.safeParse({ ...process.env, SHUTDOWN_DELAY_MS: "8000", SHUTDOWN_GRACE_MS: "30000" }).success).toBe(true);
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
