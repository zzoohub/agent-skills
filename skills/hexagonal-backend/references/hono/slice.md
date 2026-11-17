# Hono examples: the slice

What any command or query needs: the publishing context's domain, its PostgreSQL adapter with the tenant wiring, and the HTTP routes with their problem rendering. Every `file=` block is a complete file of one project that passes its gates on the baseline in `guide.md` § 0. Idempotency, the outbox relay and the webhook are in `reliability.md`, the app factory and entrypoints in `service.md`, the tests in `tests.md`.

## Contents

1. [Errors and shared ports](#errors-and-shared-ports)
2. [Model](#model)
3. [Ports and use cases](#ports-and-use-cases)
4. [Migration and schema mirror](#migration-and-schema-mirror)
5. [Connection and error translation](#connection-and-error-translation)
6. [Unit of work and repository](#unit-of-work-and-repository)
7. [Routes](#routes)
8. [Problem documents](#problem-documents)

## Errors and shared ports

The domain imports nothing outside `src/domain`, not even a `node:` built-in. The error kinds are a closed union, so the mapping to problem types in `problem.ts` stops compiling when a kind is added and not mapped.

```ts file=src/domain/shared/errors.ts
export type ErrorCode =
  | "invalid"
  | "malformed"
  | "not_found"
  | "forbidden"
  | "already_exists"
  | "invalid_transition"
  | "version_conflict"
  | "precondition_failed"
  | "unavailable";

export type Issue = Readonly<{ field: string; code: string; detail: string }>;

export class DomainError extends Error {
  override readonly name = "DomainError";
  readonly code: ErrorCode;
  readonly issues: readonly Issue[];

  constructor(code: ErrorCode, message: string, options: { cause?: unknown; issues?: readonly Issue[] } = {}) {
    super(message, { cause: options.cause });
    this.code = code;
    this.issues = options.issues ?? [];
  }
}
```

```ts file=src/domain/shared/ports.ts
export type Actor = Readonly<{ tenantId: string; subject: string; roles: readonly string[] }>;

/** A non-HTTP trigger acting inside one tenant, such as a verified webhook. */
export const systemActor = (tenantId: string, name: string): Actor => ({
  tenantId,
  subject: `system:${name}`,
  roles: ["moderator"],
});

export interface Clock {
  now(): Date;
}

/** UUIDv7 (time-ordered). */
export interface IdGenerator {
  next(): string;
}

export type PageRequest = Readonly<{ cursor?: string | undefined; limit: number }>;
export type Page<T> = Readonly<{ items: readonly T[]; nextCursor: string | null; hasMore: boolean }>;
```

## Model

Data plus functions that decide. Time and ids arrive as arguments, so the tests in `tests.md` need no doubles.

```ts file=src/domain/publishing/article.ts
import { DomainError, type Issue } from "../shared/errors.ts";
import type { Actor } from "../shared/ports.ts";

export type ArticleStatus = "draft" | "published" | "archived";

export type Article = Readonly<{
  id: string;
  tenantId: string;
  authorId: string;
  slug: string;
  title: string;
  body: string;
  status: ArticleStatus;
  version: number;
  createdAt: Date;
  updatedAt: Date;
  publishedAt: Date | null;
}>;

export const LIMITS = { slug: 100, title: 200, body: 20_000 } as const;
export const SLUG_PATTERN = "^[a-z0-9]+(?:-[a-z0-9]+)*$";
const SLUG = new RegExp(SLUG_PATTERN, "u");
/** Lengths in code points (PostgreSQL's char_length); no NUL, which text cannot store. */
const text = (min: number, max: number) => (v: string) => {
  const length = Array.from(v).length;
  return length >= min && length <= max && !v.includes("\0");
};

const RULES = {
  slug: [(v: string) => SLUG.test(v) && v.length <= LIMITS.slug, "lowercase kebab-case, at most 100 characters"],
  title: [text(1, LIMITS.title), "1-200 characters after trimming, no NUL"],
  body: [text(0, LIMITS.body), "at most 20000 characters, no NUL"],
} as const;

function validate(fields: Partial<Record<keyof typeof RULES, string | undefined>>): void {
  const issues: Issue[] = [];
  for (const field of ["slug", "title", "body"] as const) {
    const value = fields[field];
    const [ok, detail] = RULES[field];
    if (value !== undefined && !ok(value)) issues.push({ field, code: "invalid_value", detail });
  }
  if (issues.length > 0) throw new DomainError("invalid", `${String(issues.length)} field(s) invalid`, { issues });
}

/** The id and the time are arguments: the model never generates one or reads the clock. */
export function newArticle(input: Pick<Article, "id" | "tenantId" | "authorId" | "slug" | "title" | "body">, now: Date): Article {
  const article: Article = {
    ...input,
    title: input.title.trim(),
    status: "draft",
    version: 1,
    createdAt: now,
    updatedAt: now,
    publishedAt: null,
  };
  validate(article);
  return article;
}

export type ArticlePatch = Readonly<{ title?: string | undefined; body?: string | undefined }>;

export function editArticle(article: Article, patch: ArticlePatch, now: Date): Article {
  const title = patch.title?.trim();
  validate({ title, body: patch.body });
  return { ...article, title: title ?? article.title, body: patch.body ?? article.body, updatedAt: now };
}

export function publish(article: Article, now: Date): Article {
  if (article.status !== "draft") throw new DomainError("invalid_transition", `Only a draft can be published; this article is ${article.status}`);
  return { ...article, status: "published", publishedAt: now, updatedAt: now };
}

export function archive(article: Article, now: Date): Article {
  if (article.status !== "published") throw new DomainError("invalid_transition", `Only a published article can be archived; this one is ${article.status}`);
  return { ...article, status: "archived", updatedAt: now };
}

/** Trusted path for stored rows: never re-validated, so a tightened rule cannot break reads. */
export const rehydrate = (state: Article): Article => state;

export const canEdit = (actor: Actor, article: Article): boolean =>
  actor.subject === article.authorId || actor.roles.includes("editor");

export const canModerate = (actor: Actor): boolean =>
  actor.roles.includes("editor") || actor.roles.includes("moderator");
```

## Ports and use cases

The repository port has no tenant parameter: the unit of work hands out one that is already bound to the actor's tenant. `Outbox`, `Inbox` and `IdempotencyCompletion` are declared in `reliability.md`.

```ts file=src/domain/publishing/ports.ts
import type { Inbox, Outbox } from "../shared/events.ts";
import type { IdempotencyCompletion } from "../shared/idempotency.ts";
import type { Actor, Page, PageRequest } from "../shared/ports.ts";
import type { Article, ArticleStatus } from "./article.ts";

/** Bound to one transaction and one tenant: no method takes a tenant, and none can reach another's rows. */
export interface ArticleRepository {
  get(id: string): Promise<Article | null>;
  /** Newest first; an undecodable cursor fails with DomainError("malformed"). */
  list(page: PageRequest): Promise<Page<Article>>;
  /** A taken slug fails with DomainError("already_exists"). */
  insert(article: Article): Promise<void>;
  /** Conditional writes: null when the stored version (update) or status (transition) no longer matches. */
  update(next: Article, expectedVersion: number): Promise<Article | null>;
  transition(next: Article, from: ArticleStatus): Promise<Article | null>;
}

export type Tx = Readonly<{ articles: ArticleRepository; outbox: Outbox; inbox: Inbox; idempotency: IdempotencyCompletion }>;

export interface UnitOfWork {
  /** One transaction scoped to the actor's tenant; a nested run for the same tenant joins the open one. */
  run<T>(actor: Actor, work: (tx: Tx) => Promise<T>): Promise<T>;
}
```

Each use case takes the `Actor` first and owns its transaction. Reads run in a unit of work too, because row-level security shows a query nothing until the transaction names its tenant.

```ts file=src/domain/publishing/use-cases.ts
import { DomainError } from "../shared/errors.ts";
import type { DomainEvent } from "../shared/events.ts";
import type { Actor, Clock, IdGenerator, Page, PageRequest } from "../shared/ports.ts";
import {
  archive,
  type Article,
  type ArticlePatch,
  canEdit,
  canModerate,
  editArticle,
  newArticle,
  publish,
} from "./article.ts";
import type { UnitOfWork } from "./ports.ts";

export const MAX_PAGE = 100;

export type PublishingDeps = Readonly<{ uow: UnitOfWork; clock: Clock; ids: IdGenerator }>;

const notFound = (id: string): never => {
  throw new DomainError("not_found", `Article ${id} not found`);
};
const stale = (): DomainError =>
  new DomainError("precondition_failed", "The article changed since the ETag you sent; re-fetch and retry");

const articlePublished = (a: Article): DomainEvent => ({
  type: "article.published",
  version: 1,
  tenantId: a.tenantId,
  aggregateType: "article",
  aggregateId: a.id,
  aggregateSeq: a.version,
  payload: { article_id: a.id, slug: a.slug, title: a.title, published_at: a.publishedAt?.toISOString() ?? null },
});

export class Publishing {
  readonly #uow: UnitOfWork;
  readonly #clock: Clock;
  readonly #ids: IdGenerator;

  constructor(deps: PublishingDeps) {
    this.#uow = deps.uow;
    this.#clock = deps.clock;
    this.#ids = deps.ids;
  }

  async create(actor: Actor, input: Pick<Article, "slug" | "title" | "body">): Promise<Article> {
    const article = newArticle({ ...input, id: this.#ids.next(), tenantId: actor.tenantId, authorId: actor.subject }, this.#clock.now());
    await this.#uow.run(actor, (tx) => tx.articles.insert(article));
    return article;
  }

  get(actor: Actor, id: string): Promise<Article> {
    return this.#uow.run(actor, async (tx) => (await tx.articles.get(id)) ?? notFound(id));
  }

  list(actor: Actor, page: PageRequest): Promise<Page<Article>> {
    return this.#uow.run(actor, (tx) => tx.articles.list({ ...page, limit: Math.min(Math.max(page.limit, 1), MAX_PAGE) }));
  }

  /** `precondition` (If-Match) is checked after the 404 and 403 decisions. */
  update(actor: Actor, id: string, patch: ArticlePatch, precondition?: (version: number) => boolean): Promise<Article> {
    return this.#uow.run(actor, async (tx) => {
      const current = (await tx.articles.get(id)) ?? notFound(id);
      if (!canEdit(actor, current)) throw new DomainError("forbidden", "Only the author or an editor may change it");
      if (precondition && !precondition(current.version)) throw stale();
      const saved = await tx.articles.update(editArticle(current, patch, this.#clock.now()), current.version);
      if (saved) return saved;
      throw precondition ? stale() : new DomainError("version_conflict", "The article changed concurrently");
    });
  }

  publish(actor: Actor, id: string): Promise<Article> {
    return this.#uow.run(actor, async (tx) => {
      const current = (await tx.articles.get(id)) ?? notFound(id); // another tenant's row is invisible: 404
      if (!canEdit(actor, current)) throw new DomainError("forbidden", "Only the author or an editor may publish");
      const saved = await tx.articles.transition(publish(current, this.#clock.now()), "draft");
      if (!saved) throw new DomainError("invalid_transition", "The article is no longer a draft"); // the database decided the race
      await tx.outbox.append(articlePublished(saved)); // commits with the state change, or not at all
      return saved;
    });
  }

  archive(actor: Actor, id: string): Promise<Article> {
    return this.#uow.run(actor, async (tx) => {
      const current = (await tx.articles.get(id)) ?? notFound(id);
      if (!canModerate(actor)) throw new DomainError("forbidden", "Only an editor or a moderator may archive");
      const saved = await tx.articles.transition(archive(current, this.#clock.now()), "published");
      if (!saved) throw new DomainError("invalid_transition", "The article is no longer published");
      return saved;
    });
  }
}
```

## Migration and schema mirror

Hand-written SQL is the source of truth. The release step applies it as the owning role; the application connects as `app_rw`.

```sql file=migrations/0000_publishing.sql
-- Applied by the release step as the owning role. The application connects as app_rw, a login role
-- created outside the migrations, which neither owns these tables nor has BYPASSRLS.
CREATE SCHEMA app;
GRANT USAGE ON SCHEMA app TO app_rw;

CREATE TABLE app.articles (
  id uuid NOT NULL,
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
  CONSTRAINT pk_articles PRIMARY KEY (id),
  CONSTRAINT uq_articles_tenant_slug UNIQUE (tenant_id, slug),
  CONSTRAINT chk_articles_status CHECK (status IN ('draft', 'published', 'archived')),
  CONSTRAINT chk_articles_slug CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug) <= 100),
  CONSTRAINT chk_articles_title CHECK (char_length(title) BETWEEN 1 AND 200),
  CONSTRAINT chk_articles_body CHECK (char_length(body) <= 20000),
  CONSTRAINT chk_articles_version CHECK (version >= 1)
);
-- Keyset pages: WHERE tenant_id = $1 AND id < $2 ORDER BY id DESC.
CREATE INDEX idx_articles_tenant_id ON app.articles (tenant_id, id);

-- The second enforcement point: a query that forgot its tenant predicate still sees one tenant.
-- The unit of work sets app.current_tenant as the first statement of every transaction.
ALTER TABLE app.articles ENABLE ROW LEVEL SECURITY, FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON app.articles TO app_rw
  USING (tenant_id = (SELECT NULLIF(current_setting('app.current_tenant', true), '')::uuid));
GRANT SELECT, INSERT, UPDATE ON app.articles TO app_rw;
```

The journal lists the files the migrator applies, in order. An entry's `when` must be later than every entry before it (`guide.md` § 9).

```json file=migrations/meta/_journal.json
{
  "version": "7",
  "dialect": "postgresql",
  "entries": [
    { "idx": 0, "version": "7", "when": 1794700800000, "tag": "0000_publishing", "breakpoints": true },
    { "idx": 1, "version": "7", "when": 1794700860000, "tag": "0001_reliability", "breakpoints": true }
  ]
}
```

```ts file=src/outbound/postgres/schema.ts
import { sql } from "drizzle-orm";
import { customType, index, integer, jsonb, pgSchema, primaryKey, text, timestamp, unique, uuid } from "drizzle-orm/pg-core";
import type { ArticleStatus } from "../../domain/publishing/article.ts";

/**
 * Mirrors migrations/*.sql for typed queries; a test compares the two catalogs.
 * CHECK constraints, policies and grants live only in the SQL. The schema object is exported
 * because drizzle-kit generates CREATE SCHEMA only for a schema it finds among the exports.
 */
export const app = pgSchema("app");
const tz = (name: string) => timestamp(name, { withTimezone: true });
const bytea = customType<{ data: Uint8Array; driverData: Uint8Array }>({ dataType: () => "bytea" });

export const articles = app.table(
  "articles",
  {
    id: uuid("id").notNull(),
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
  (t) => [
    primaryKey({ name: "pk_articles", columns: [t.id] }),
    unique("uq_articles_tenant_slug").on(t.tenantId, t.slug),
    index("idx_articles_tenant_id").on(t.tenantId, t.id),
  ],
);

export const outbox = app.table(
  "outbox",
  {
    id: uuid("id").notNull().default(sql`uuidv7()`),
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
    primaryKey({ name: "pk_outbox", columns: [t.id] }),
    unique("uq_outbox_aggregate_seq").on(t.aggregateId, t.aggregateSeq),
    index("idx_outbox_pending").on(t.createdAt).where(sql`published_at IS NULL AND dead_lettered_at IS NULL`),
    index("idx_outbox_dead_letter").on(t.deadLetteredAt).where(sql`dead_lettered_at IS NOT NULL`),
  ],
);

export const idempotencyKeys = app.table(
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
    primaryKey({ name: "pk_idempotency_keys", columns: [t.scope, t.key] }),
    index("idx_idempotency_keys_expires_at").on(t.expiresAt),
  ],
);

export const inbox = app.table(
  "inbox",
  {
    consumer: text("consumer").notNull(),
    messageId: text("message_id").notNull(),
    receivedAt: tz("received_at").notNull().defaultNow(),
  },
  (t) => [primaryKey({ name: "pk_inbox", columns: [t.consumer, t.messageId] })],
);
```

## Connection and error translation

```ts file=src/outbound/postgres/db.ts
import { sql } from "drizzle-orm";
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

/** The startup round-trip. A superuser or BYPASSRLS role switches row-level security off without an error. */
export async function assertRuntimeRole(db: Db): Promise<void> {
  const { rows } = await db.execute<{ bypass: boolean }>(sql`SELECT rolsuper OR rolbypassrls AS bypass FROM pg_roles WHERE rolname = current_user`);
  if (rows[0]?.bypass !== false) throw new Error("DATABASE_URL names a role that bypasses row-level security; connect as the application role");
}

export class DatabaseError extends Error {
  override readonly name = "DatabaseError";
}

const CONFLICTS: Record<string, string | undefined> = { uq_articles_tenant_slug: "An article with this slug already exists" };
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

/** For `.catch(rethrow)` on queries that run outside a unit of work. */
export const rethrow = (err: unknown): never => {
  throw translate(err);
};
```

## Unit of work and repository

`run(actor, work)` opens the transaction, sets the tenant as its first statement and builds the ports through a `Bind` function. The publishing binding, `publishingTx`, is in `src/app/services.ts` (`service.md`). A nested `run` joins the open transaction through `AsyncLocalStorage`.

```ts file=src/outbound/postgres/unit-of-work.ts
import { AsyncLocalStorage } from "node:async_hooks";
import { sql } from "drizzle-orm";
import type { Actor } from "../../domain/shared/ports.ts";
import { type Db, type Executor, rethrow } from "./db.ts";

/** Builds a context's transaction-bound ports; `q` throws once the transaction has ended. */
export type Bind<Tx> = (q: () => Executor, tenantId: string) => Tx;

/** READ COMMITTED, no retry loop: a deadlock surfaces as unavailable (503). */
export class PgUnitOfWork<Tx> {
  readonly #db: Db;
  readonly #bind: Bind<Tx>;
  readonly #open = new AsyncLocalStorage<Readonly<{ tx: Tx; tenantId: string; finished: () => boolean }>>();

  constructor(db: Db, bind: Bind<Tx>) {
    this.#db = db;
    this.#bind = bind;
  }

  run<T>(actor: Actor, work: (tx: Tx) => Promise<T>): Promise<T> {
    const outer = this.#open.getStore();
    if (outer) {
      if (outer.finished()) return Promise.reject(new Error("The unit of work already finished; this work would escape it"));
      if (outer.tenantId !== actor.tenantId) return Promise.reject(new Error("A unit of work is open for another tenant; a nested run cannot switch tenants"));
      return work(outer.tx).catch(rethrow);
    }
    return this.#db
      .transaction(async (dtx) => {
        // The first statement. Transaction-local, so a pooled connection carries nothing to its next user.
        await dtx.execute(sql`SELECT set_config('app.current_tenant', ${actor.tenantId}, true)`);
        let finished = false;
        const tx = this.#bind(() => {
          if (finished) throw new Error("Transaction finished; late work refused");
          return dtx;
        }, actor.tenantId);
        try {
          return await this.#open.run({ tx, tenantId: actor.tenantId, finished: () => finished }, () => work(tx));
        } finally {
          finished = true;
        }
      })
      .catch(rethrow);
  }
}
```

```ts file=src/outbound/postgres/articles.ts
import { and, desc, eq, lt, type SQL, sql } from "drizzle-orm";
import { type Article, type ArticleStatus, rehydrate } from "../../domain/publishing/article.ts";
import type { ArticleRepository } from "../../domain/publishing/ports.ts";
import { MAX_PAGE } from "../../domain/publishing/use-cases.ts";
import { DomainError } from "../../domain/shared/errors.ts";
import type { Page, PageRequest } from "../../domain/shared/ports.ts";
import type { Executor } from "./db.ts";
import { articles } from "./schema.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/u;
const encodeCursor = (id: string) => Buffer.from(`v1:${id}`).toString("base64url");

function decodeCursor(cursor: string): string {
  const raw = /^[\w-]{1,64}$/u.test(cursor) ? Buffer.from(cursor, "base64url").toString("utf8") : "";
  const id = raw.startsWith("v1:") ? raw.slice(3) : "";
  if (!UUID.test(id)) throw new DomainError("malformed", "The cursor is not valid for this list");
  return id;
}

/** Built by the unit of work for one transaction and one tenant. Every query names the tenant; row-level security backs it up. */
export class PgArticles implements ArticleRepository {
  readonly #q: () => Executor;
  readonly #mine: SQL;

  constructor(q: () => Executor, tenantId: string) {
    this.#q = q;
    this.#mine = eq(articles.tenantId, tenantId);
  }

  async get(id: string): Promise<Article | null> {
    const [row] = await this.#q().select().from(articles).where(and(this.#mine, eq(articles.id, id)));
    return row ? rehydrate(row) : null;
  }

  async list(page: PageRequest): Promise<Page<Article>> {
    const limit = Math.min(page.limit, MAX_PAGE);
    const after = page.cursor === undefined ? undefined : lt(articles.id, decodeCursor(page.cursor));
    const rows = await this.#q()
      .select()
      .from(articles)
      .where(and(this.#mine, after))
      .orderBy(desc(articles.id))
      .limit(limit + 1);
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

  /** The database increments the version: one computed in memory would let two writers produce the same ETag. */
  async #write(set: Partial<Article>, next: Article, guard: SQL): Promise<Article | null> {
    const [row] = await this.#q()
      .update(articles)
      .set({ ...set, updatedAt: next.updatedAt, version: sql`${articles.version} + 1` })
      .where(and(this.#mine, eq(articles.id, next.id), guard))
      .returning();
    return row ? rehydrate(row) : null;
  }
}
```

```ts file=src/outbound/system.ts
import type { Clock, IdGenerator } from "../domain/shared/ports.ts";

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
```

## Routes

Handlers parse, call one use case and map the result. The schemas are strict and document the domain's limits; the domain enforces them.

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

## Problem documents

One renderer serves domain errors, validation failures, `HTTPException`s and unknown errors. `app.ts` (`service.md`) routes every failure to it.

```ts file=src/inbound/http/problem.ts
import { STATUS_CODES } from "node:http";
import type { z } from "@hono/zod-openapi";
import type { Context } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import { DomainError, type ErrorCode } from "../../domain/shared/errors.ts";

/** The registry in http-api.md § Problem types: each type's status and fixed title. */
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
