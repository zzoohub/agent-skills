# NestJS examples: the slice

What any command or query needs: the publishing context's domain, its PostgreSQL adapter with the tenant wiring, and the HTTP routes with their problem rendering. Every `file=` block is a complete file of one project that passes its gates on the baseline in `guide.md` § 0. Idempotency, the outbox relay and the webhook are in `reliability.md`, the app factory, modules and entrypoints in `service.md`, the tests in `tests.md`.

## Contents

1. [Errors and shared ports](#errors-and-shared-ports)
2. [Model](#model)
3. [Ports and use cases](#ports-and-use-cases)
4. [Migration and entity](#migration-and-entity)
5. [Connection and error translation](#connection-and-error-translation)
6. [Unit of work and repository](#unit-of-work-and-repository)
7. [Routes](#routes)
8. [Problem documents](#problem-documents)

## Errors and shared ports

The domain imports nothing outside `src/domain`, not even a `node:` built-in. The error kinds are a closed union, so the mapping to problem types in `problem.ts` stops compiling when a kind is added and not mapped.

```ts file=src/domain/shared/errors.ts
export type ErrorKind =
  | "invalid"
  | "malformed" // a token this service issued (a cursor) cannot be read
  | "forbidden"
  | "not_found"
  | "conflict"
  | "precondition_failed"
  | "unavailable"; // a dependency failed transiently: retry later

export class DomainError extends Error {
  readonly code: string;
  readonly field: string | undefined;

  constructor(
    readonly kind: ErrorKind,
    message: string,
    options: { code?: string; field?: string; cause?: unknown } = {},
  ) {
    super(message, { cause: options.cause });
    this.name = "DomainError";
    this.code = options.code ?? kind;
    this.field = options.field;
  }
}

export const invalid = (field: string, code: string, message: string) =>
  new DomainError("invalid", message, { field, code });

export const conflict = (code: "already-exists" | "invalid-transition" | "version-conflict", message: string) =>
  new DomainError("conflict", message, { code });
```

A port that Nest injects is an abstract class, because an interface leaves no token at runtime.

```ts file=src/domain/shared/ports.ts
export interface Actor {
  readonly tenantId: string;
  readonly subject: string;
  readonly roles: readonly string[];
}

export interface Page<T> {
  readonly items: readonly T[];
  readonly nextCursor: string | null;
}

// Abstract classes: a port that Nest injects is its own DI token, and the domain needs no decorator.
export abstract class Clock {
  abstract now(): Date;
}

export abstract class IdGenerator {
  abstract next(): string;
}
```

## Model

Data plus functions that decide. Time and ids arrive as arguments, so the tests in `tests.md` need no doubles.

```ts file=src/domain/publishing/article.ts
import { conflict, invalid } from "../shared/errors.js";
import type { Actor } from "../shared/ports.js";

export type ArticleStatus = "draft" | "published" | "archived";

export interface ArticleState {
  readonly id: string;
  readonly tenantId: string;
  readonly authorId: string;
  readonly slug: string;
  readonly title: string;
  readonly body: string;
  readonly status: ArticleStatus;
  /** Assigned by the store on every write; here it is the version this state was read at. */
  readonly version: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly publishedAt: Date | null;
}

declare const sealed: unique symbol;
/** Only `createArticle` and `rehydrateArticle` mint one, so an Article that broke a rule cannot be built. */
export type Article = ArticleState & { readonly [sealed]: true };

// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- the one place an Article is minted
const seal = (state: ArticleState) => Object.freeze({ ...state }) as Article;

export interface NewArticle {
  readonly slug: string;
  readonly title: string;
  readonly body: string;
}

export function parseSlug(raw: string): string {
  if (raw.length > 100 || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(raw)) {
    throw invalid("slug", "invalid_format", "slug must be lowercase kebab-case, at most 100 characters");
  }
  return raw;
}

export const parseTitle = (raw: string) => text("title", raw.trim(), 1, 200);
export const parseBody = (raw: string) => text("body", raw, 0, 20_000);

/** Lengths in code points, as the CHECK constraints count them. */
function text(field: string, value: string, min: number, max: number): string {
  const length = Array.from(value).length;
  if (length < min || length > max) throw invalid(field, "invalid_length", `${field} must be ${min}-${max} characters`);
  if (value.includes("\u0000")) throw invalid(field, "invalid_characters", `${field} must not contain U+0000`);
  return value;
}

export function createArticle(input: NewArticle & { id: string; tenantId: string; authorId: string }, now: Date): Article {
  return seal({
    id: input.id,
    tenantId: input.tenantId,
    authorId: input.authorId,
    slug: parseSlug(input.slug),
    title: parseTitle(input.title),
    body: parseBody(input.body),
    status: "draft",
    version: 1,
    createdAt: now,
    updatedAt: now,
    publishedAt: null,
  });
}

/** The trusted path for stored rows: a rule tightened later must not break reading older data. */
export const rehydrateArticle = (state: ArticleState): Article => seal(state);

export function editArticle(article: Article, changes: { title?: string; body?: string }, now: Date): Article {
  return seal({
    ...article,
    title: changes.title === undefined ? article.title : parseTitle(changes.title),
    body: changes.body === undefined ? article.body : parseBody(changes.body),
    updatedAt: now,
  });
}

export function publishArticle(article: Article, now: Date): Article {
  requireStatus(article, "draft", "publish");
  return seal({ ...article, status: "published", publishedAt: now, updatedAt: now });
}

export function archiveArticle(article: Article, now: Date): Article {
  requireStatus(article, "published", "archive");
  return seal({ ...article, status: "archived", updatedAt: now });
}

export const canEdit = (actor: Actor, article: Article) =>
  actor.subject === article.authorId || actor.roles.includes("editor");

export const canArchive = (actor: Actor) => actor.roles.includes("moderator");

function requireStatus(article: Article, from: ArticleStatus, action: string): void {
  if (article.status !== from) {
    throw conflict("invalid-transition", `cannot ${action} an article in status '${article.status}'`);
  }
}
```

## Ports and use cases

The ports the unit of work hands over are interfaces, and the repository has no tenant parameter because it arrives bound to the actor's tenant. `IdempotencyCompletion` is declared in `reliability.md`.

```ts file=src/domain/publishing/ports.ts
import type { IdempotencyCompletion } from "../shared/idempotency.js";
import type { Actor, Page } from "../shared/ports.js";
import type { Article, ArticleStatus } from "./article.js";

/** Bound to one transaction and one tenant: another tenant's article looks exactly like a missing one. */
export interface ArticleRepository {
  /** A taken slug fails as the conflict "already-exists". */
  insert(article: Article): Promise<void>;
  get(id: string): Promise<Article | null>;
  /** Newest first. A cursor this list did not issue fails as "malformed". */
  list(cursor: string | null, limit: number): Promise<Page<Article>>;
  /** Conditional writes: null when the stored version (update) or status (transition) no longer matches. */
  update(next: Article, expectedVersion: number): Promise<Article | null>;
  transition(next: Article, from: ArticleStatus): Promise<Article | null>;
}

export interface DomainEvent {
  readonly tenantId: string;
  readonly aggregateType: string;
  readonly aggregateId: string;
  readonly aggregateSeq: number; // the aggregate's new version: consumers apply events in this order
  readonly type: string;
  readonly version: number;
  readonly payload: Readonly<Record<string, unknown>>;
}

export interface Outbox {
  append(event: DomainEvent): Promise<void>;
}

export interface Inbox {
  /** false when the message was already processed. */
  claim(consumer: string, messageId: string): Promise<boolean>;
}

/** What a use case may touch inside its transaction. */
export interface Tx {
  readonly articles: ArticleRepository;
  readonly outbox: Outbox;
  readonly inbox: Inbox;
  readonly idempotency: IdempotencyCompletion;
}

/** One transaction per command, scoped to the actor's tenant. A nested run joins the open one. */
export abstract class UnitOfWork {
  abstract run<T>(actor: Actor, work: (tx: Tx) => Promise<T>): Promise<T>;
}

/** A published contract: change it additively, or ship version 2 beside it. */
export const articlePublished = (article: Article): DomainEvent => ({
  tenantId: article.tenantId,
  aggregateType: "article",
  aggregateId: article.id,
  aggregateSeq: article.version,
  type: "article.published",
  version: 1,
  payload: {
    article_id: article.id,
    tenant_id: article.tenantId,
    slug: article.slug,
    title: article.title,
    published_at: article.publishedAt?.toISOString() ?? null,
  },
});
```

Each use case takes the `Actor` first and owns its transaction. Reads run in a unit of work too, because row-level security shows a query nothing until the transaction names its tenant.

```ts file=src/domain/publishing/use-cases.ts
import { conflict, DomainError } from "../shared/errors.js";
import type { Actor, Clock, IdGenerator, Page } from "../shared/ports.js";
import {
  archiveArticle, canArchive, canEdit, createArticle, editArticle, publishArticle, type Article, type NewArticle,
} from "./article.js";
import { articlePublished, type Tx, type UnitOfWork } from "./ports.js";

export const MAX_PAGE_SIZE = 100;

export class Publishing {
  constructor(
    private readonly uow: UnitOfWork,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
  ) {}

  async create(actor: Actor, input: NewArticle): Promise<Article> {
    const article = createArticle(
      { ...input, id: this.ids.next(), tenantId: actor.tenantId, authorId: actor.subject },
      this.clock.now(),
    );
    await this.uow.run(actor, (tx) => tx.articles.insert(article));
    return article;
  }

  get(actor: Actor, id: string): Promise<Article> {
    return this.uow.run(actor, (tx) => found(tx, id));
  }

  list(actor: Actor, cursor: string | null, limit: number): Promise<Page<Article>> {
    return this.uow.run(actor, (tx) => tx.articles.list(cursor, Math.min(Math.max(1, limit), MAX_PAGE_SIZE)));
  }

  /** A merge patch (`body: null` clears). `expected`: the versions If-Match names, checked after the 404 and the 403. */
  update(actor: Actor, id: string, patch: { title?: string; body?: string | null }, expected?: readonly number[]) {
    return this.uow.run(actor, async (tx) => {
      const current = await editable(tx, actor, id);
      if (expected && !expected.includes(current.version)) throw stale();
      const changes = { title: patch.title, body: patch.body === null ? "" : patch.body };
      const saved = await tx.articles.update(editArticle(current, changes, this.clock.now()), current.version);
      if (saved) return saved;
      throw expected ? stale() : conflict("version-conflict", "the article changed meanwhile; retry");
    });
  }

  publish(actor: Actor, id: string): Promise<Article> {
    return this.uow.run(actor, async (tx) => {
      const current = await editable(tx, actor, id);
      const saved = await tx.articles.transition(publishArticle(current, this.clock.now()), "draft");
      if (!saved) throw conflict("invalid-transition", "the article is no longer a draft"); // the database decided the race
      await tx.outbox.append(articlePublished(saved)); // commits with the state change, or not at all
      return saved;
    });
  }

  archive(actor: Actor, id: string): Promise<Article> {
    return this.uow.run(actor, async (tx) => {
      const current = await found(tx, id);
      if (!canArchive(actor)) throw new DomainError("forbidden", "only moderation archives articles");
      const saved = await tx.articles.transition(archiveArticle(current, this.clock.now()), "published");
      if (!saved) throw conflict("invalid-transition", "the article is no longer published");
      return saved;
    });
  }
}

async function found(tx: Tx, id: string): Promise<Article> {
  const article = await tx.articles.get(id);
  if (!article) throw new DomainError("not_found", `article '${id}' not found`);
  return article;
}

async function editable(tx: Tx, actor: Actor, id: string): Promise<Article> {
  const article = await found(tx, id);
  if (!canEdit(actor, article)) throw new DomainError("forbidden", "only the author or an editor may change it");
  return article;
}

const stale = () => new DomainError("precondition_failed", "the article changed since the version you read; re-read it");

export type ModerationOutcome = "archived" | "approved" | "duplicate" | "ignored";

export class Moderation {
  constructor(
    private readonly publishing: Publishing,
    private readonly uow: UnitOfWork,
  ) {}

  handle(message: { id: string; tenantId: string; articleId: string; verdict: "approved" | "rejected" }) {
    const moderator: Actor = { tenantId: message.tenantId, subject: "system:moderation", roles: ["moderator"] };
    return this.uow.run(moderator, async (tx): Promise<ModerationOutcome> => {
      if (!(await tx.inbox.claim("moderation", message.id))) return "duplicate";
      if (message.verdict === "approved") return "approved";
      try {
        await this.publishing.archive(moderator, message.articleId); // joins this transaction
        return "archived";
      } catch (error) {
        // Permanent: a redelivery cannot succeed, so keep the inbox row and acknowledge.
        if (error instanceof DomainError && ["not_found", "conflict"].includes(error.kind)) return "ignored";
        throw error;
      }
    });
  }
}
```

## Migration and entity

Hand-written SQL is the source of truth. The release step applies it as the owning role, and the application connects as `app_rw`. The outbox, inbox and idempotency tables are a second migration, in `reliability.md`.

```ts file=src/migrations/1791417600000-publishing.ts
import type { MigrationInterface, QueryRunner } from "typeorm";

// Runs as the owning role. The application's role, app_rw, exists before this runs (cluster bootstrap).
export class Publishing1791417600000 implements MigrationInterface {
  async up(db: QueryRunner): Promise<void> {
    await db.query(`
      CREATE SCHEMA app;
      GRANT USAGE ON SCHEMA app TO app_rw;

      CREATE TABLE app.articles (
        id           uuid CONSTRAINT pk_articles PRIMARY KEY,
        tenant_id    uuid NOT NULL,
        author_id    text NOT NULL,
        slug         text NOT NULL,
        title        text NOT NULL,
        body         text NOT NULL,
        status       text NOT NULL,
        version      integer NOT NULL,
        created_at   timestamptz NOT NULL,
        updated_at   timestamptz NOT NULL,
        published_at timestamptz,
        CONSTRAINT uq_articles_tenant_slug UNIQUE (tenant_id, slug),
        CONSTRAINT chk_articles_status CHECK (status IN ('draft', 'published', 'archived')),
        CONSTRAINT chk_articles_lengths CHECK (
          char_length(slug) <= 100 AND char_length(title) BETWEEN 1 AND 200 AND char_length(body) <= 20000)
      );
      CREATE INDEX idx_articles_tenant_id ON app.articles (tenant_id, id);

      -- The second enforcement point. FORCE filters the owner too; TO app_rw keeps the policy off other roles.
      ALTER TABLE app.articles ENABLE ROW LEVEL SECURITY, FORCE ROW LEVEL SECURITY;
      CREATE POLICY tenant_isolation ON app.articles TO app_rw
        USING (tenant_id = (SELECT NULLIF(current_setting('app.current_tenant', true), '')::uuid));

      GRANT SELECT, INSERT, UPDATE ON app.articles TO app_rw;
      -- TypeORM keeps its bookkeeping in the default schema; readiness reads it to refuse pending migrations.
      GRANT SELECT ON migrations TO app_rw;
    `);
  }

  async down(db: QueryRunner): Promise<void> {
    await db.query(`DROP SCHEMA app CASCADE`);
  }
}
```

The entity mirrors the table for typed queries. The drift check compares the two (`guide.md` § 5).

```ts file=src/outbound/postgres/article.entity.ts
import { Check, Column, Entity, Index, PrimaryColumn, Unique } from "typeorm";
import type { ArticleStatus } from "../../domain/publishing/article.js";

// Mirrors the SQL migration, constraint names included: the drift check compares them.
@Entity({ schema: "app", name: "articles" })
@Unique("uq_articles_tenant_slug", ["tenantId", "slug"])
@Index("idx_articles_tenant_id", ["tenantId", "id"])
@Check("chk_articles_status", `status IN ('draft', 'published', 'archived')`)
@Check("chk_articles_lengths", `char_length(slug) <= 100 AND char_length(title) BETWEEN 1 AND 200 AND char_length(body) <= 20000`)
export class ArticleEntity {
  @PrimaryColumn("uuid", { primaryKeyConstraintName: "pk_articles" }) id!: string;
  @Column("uuid", { name: "tenant_id" }) tenantId!: string;
  @Column("text", { name: "author_id" }) authorId!: string;
  @Column("text") slug!: string;
  @Column("text") title!: string;
  @Column("text") body!: string;
  @Column("text") status!: ArticleStatus;
  @Column("integer") version!: number;
  @Column("timestamptz", { name: "created_at" }) createdAt!: Date;
  @Column("timestamptz", { name: "updated_at" }) updatedAt!: Date;
  @Column("timestamptz", { name: "published_at", nullable: true }) publishedAt!: Date | null;
}
```

## Connection and error translation

One function builds the options of every DataSource: the API, the worker, the release step and the tests.

```ts file=src/outbound/postgres/options.ts
import type { DataSourceOptions } from "typeorm";
import { Publishing1791417600000 } from "../../migrations/1791417600000-publishing.js";
import { Reliability1791417600001 } from "../../migrations/1791417600001-reliability.js";
import { ArticleEntity } from "./article.entity.js";

/** For the API and the worker (as app_rw), the release step (as the owner) and the tests. */
export function postgresOptions(settings: {
  url: string;
  applicationName: string;
  poolSize?: number;
  statementTimeoutMs?: number; // 0 = none, for migrations
}): DataSourceOptions {
  const statementTimeoutMs = settings.statementTimeoutMs ?? 0;
  return {
    type: "postgres",
    url: settings.url,
    applicationName: settings.applicationName,
    entities: [ArticleEntity],
    migrations: [Publishing1791417600000, Reliability1791417600001],
    migrationsTransactionMode: "each",
    poolSize: settings.poolSize ?? 10,
    connectTimeoutMS: 3_000, // also bounds the wait for a free pooled connection
    extra: {
      // The database, not the HTTP timeout, ends the work. A statement is cancelled at the request deadline and
      // its connection survives; a transaction still running half a deadline later is terminated with its
      // session, well inside the 60 s idempotency lease.
      statement_timeout: statementTimeoutMs,
      idle_in_transaction_session_timeout: 15_000,
      options: `-c TimeZone=UTC -c transaction_timeout=${Math.round(1.5 * statementTimeoutMs)}`,
    },
  };
}
```

```ts file=src/outbound/postgres/pg-errors.ts
import { QueryFailedError } from "typeorm";
import { DomainError } from "../../domain/shared/errors.js";

export function sqlState(error: unknown): string | undefined {
  if (error instanceof DomainError) return sqlState(error.cause);
  const source: unknown = error instanceof QueryFailedError ? error.driverError : error;
  return typeof source === "object" && source !== null && "code" in source && typeof source.code === "string"
    ? source.code
    : undefined;
}

/** By constraint name: the primary key and the idempotency table raise 23505 too. */
export function isUniqueViolation(error: unknown, constraint: string): boolean {
  const driver: unknown = error instanceof QueryFailedError ? error.driverError : undefined;
  return sqlState(error) === "23505" && typeof driver === "object" && driver !== null &&
    "constraint" in driver && driver.constraint === constraint;
}

export const isRetryable = (error: unknown) => ["40001", "40P01"].includes(sqlState(error) ?? "");

const TRANSIENT = /^(08|53|57P0|57014|55P03|25P0[34]|40001|40P01|ECONNREFUSED|ECONNRESET|ETIMEDOUT)/;

/** A transient failure becomes `unavailable` (503 + Retry-After); anything else stays a bug (500). */
export function translateDbError(error: unknown): unknown {
  if (error instanceof DomainError) return error;
  const transient = TRANSIENT.test(sqlState(error) ?? "") ||
    (error instanceof Error && /timeout exceeded when trying to connect|Connection terminated/.test(error.message));
  return transient ? new DomainError("unavailable", "the database is unavailable", { cause: error }) : error;
}
```

## Unit of work and repository

`run(actor, work)` opens the transaction, sets the tenant as its first statement and hands `work` the ports bound to it. A nested `run` joins the open transaction through `AsyncLocalStorage`. The outbox, inbox and idempotency completion it builds are in `reliability.md`.

```ts file=src/outbound/postgres/unit-of-work.ts
import { Injectable } from "@nestjs/common";
import { AsyncLocalStorage } from "node:async_hooks";
import { setTimeout as sleep } from "node:timers/promises";
import { DataSource, type EntityManager } from "typeorm";
import { UnitOfWork, type Tx } from "../../domain/publishing/ports.js";
import type { Actor } from "../../domain/shared/ports.js";
import { TypeOrmArticles } from "./article.repository.js";
import { SqlIdempotencyCompletion } from "./idempotency.store.js";
import { SqlInbox, SqlOutbox } from "./outbox-inbox.js";
import { isRetryable, translateDbError } from "./pg-errors.js";

/**
 * One transaction for one tenant. The setting is transaction-local, so a pooled connection carries
 * nothing into its next transaction, and the policy on app.articles reads it.
 */
export function inTenantTransaction<T>(db: DataSource, tenantId: string, work: (em: EntityManager) => Promise<T>): Promise<T> {
  return db.transaction(async (em) => {
    await em.query(`SELECT set_config('app.current_tenant', $1, true)`, [tenantId]);
    return work(em);
  });
}

@Injectable()
export class TypeOrmUnitOfWork extends UnitOfWork {
  private readonly open = new AsyncLocalStorage<{ tx: Tx; tenantId: string }>();

  constructor(private readonly db: DataSource) {
    super();
  }

  async run<T>(actor: Actor, work: (tx: Tx) => Promise<T>): Promise<T> {
    const outer = this.open.getStore();
    if (outer) {
      // Joining: the owner commits, retries and translates. The open transaction carries one tenant's policy.
      if (outer.tenantId !== actor.tenantId) throw new Error("a unit of work is already open for another tenant");
      return work(outer.tx);
    }
    for (let attempt = 1; ; attempt++) {
      try {
        return await inTenantTransaction(this.db, actor.tenantId, (em) => {
          const tx: Tx = {
            articles: new TypeOrmArticles(em, actor.tenantId),
            outbox: new SqlOutbox(em),
            inbox: new SqlInbox(em),
            idempotency: new SqlIdempotencyCompletion(em),
          };
          return this.open.run({ tx, tenantId: actor.tenantId }, () => work(tx));
        });
      } catch (error) {
        if (attempt < 3 && isRetryable(error)) {
          await sleep(Math.random() * 50 * 2 ** attempt); // exponential backoff, full jitter
          continue;
        }
        throw translateDbError(error);
      }
    }
  }
}
```

```ts file=src/outbound/postgres/article.repository.ts
import type { EntityManager, FindOptionsWhere } from "typeorm";
import { rehydrateArticle, type Article, type ArticleStatus } from "../../domain/publishing/article.js";
import type { ArticleRepository } from "../../domain/publishing/ports.js";
import { conflict, DomainError } from "../../domain/shared/errors.js";
import type { Page } from "../../domain/shared/ports.js";
import { ArticleEntity } from "./article.entity.js";
import { isUniqueViolation } from "./pg-errors.js";

/** Built per transaction by the unit of work: the manager is the transaction, and every query carries the tenant. */
export class TypeOrmArticles implements ArticleRepository {
  constructor(
    private readonly em: EntityManager,
    private readonly tenantId: string,
  ) {}

  async insert(article: Article): Promise<void> {
    try {
      await this.em.insert(ArticleEntity, { ...article });
    } catch (error) {
      if (!isUniqueViolation(error, "uq_articles_tenant_slug")) throw error;
      throw conflict("already-exists", `an article with slug '${article.slug}' already exists`);
    }
  }

  async get(id: string): Promise<Article | null> {
    const row = await this.em.findOneBy(ArticleEntity, { tenantId: this.tenantId, id });
    return row && rehydrateArticle(row);
  }

  async list(cursor: string | null, limit: number): Promise<Page<Article>> {
    const query = this.em.createQueryBuilder(ArticleEntity, "a").where("a.tenant_id = :tenantId", { tenantId: this.tenantId });
    if (cursor !== null) query.andWhere("a.id < :after", { after: decodeCursor(cursor) });
    const rows = await query.orderBy("a.id", "DESC").limit(limit + 1).getMany();
    const items = rows.slice(0, limit).map(rehydrateArticle);
    const last = items.at(-1);
    return { items, nextCursor: rows.length > limit && last ? encodeCursor(last.id) : null };
  }

  update(next: Article, expectedVersion: number): Promise<Article | null> {
    return this.write(next, { version: expectedVersion }, { title: next.title, body: next.body });
  }

  transition(next: Article, from: ArticleStatus): Promise<Article | null> {
    return this.write(next, { status: from }, { status: next.status, publishedAt: next.publishedAt });
  }

  /** The guard sits in the WHERE and the database assigns the version: zero rows means the guard no longer holds. */
  private async write(next: Article, guard: FindOptionsWhere<ArticleEntity>, set: Partial<ArticleEntity>): Promise<Article | null> {
    const { affected } = await this.em.update(
      ArticleEntity,
      { tenantId: this.tenantId, id: next.id, ...guard },
      { ...set, updatedAt: next.updatedAt, version: () => "version + 1" },
    );
    return affected === 1 ? this.get(next.id) : null; // the stored truth, in the same transaction
  }
}

const encodeCursor = (id: string) => Buffer.from(`v1:${id}`).toString("base64url");

function decodeCursor(cursor: string): string {
  const raw = Buffer.from(cursor, "base64url").toString("utf8");
  const id = /^v1:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/.exec(raw)?.[1];
  if (!id) throw new DomainError("malformed", "the cursor is not one this list issued", { field: "cursor" });
  return id;
}
```

## Routes

Handlers parse, call one use case and map the result. The schemas are strict and carry upper bounds only. The domain owns every other rule.

```ts file=src/inbound/http/articles.schemas.ts
import type { Response } from "express";
import { z } from "zod";
import type { Article } from "../../domain/publishing/article.js";

export const ArticleId = z.uuid();

export const CreateArticleBody = z
  .strictObject({ slug: z.string().max(100), title: z.string().max(200), body: z.string().max(20_000) })
  .meta({ id: "CreateArticle" });
export type CreateArticleBody = z.infer<typeof CreateArticleBody>;

/** JSON Merge Patch: absent = unchanged, `body: null` clears, `title: null` is invalid. */
export const UpdateArticleBody = z
  .strictObject({ title: z.string().max(200).optional(), body: z.string().max(20_000).nullable().optional() })
  .meta({ id: "UpdateArticle" });
export type UpdateArticleBody = z.infer<typeof UpdateArticleBody>;

export const ListArticlesQuery = z.strictObject({
  limit: z.coerce.number().int().min(1).default(20).transform((limit) => Math.min(limit, 100))
    .meta({ description: "Page size; a value above 100 is clamped to 100" }),
  cursor: z.string().optional(), // the adapter decodes it: anything it did not issue is a 400
});
export type ListArticlesQuery = z.infer<typeof ListArticlesQuery>;

const ArticleView = z
  .object({
    id: z.uuid(),
    author_id: z.string(),
    slug: z.string(),
    title: z.string(),
    body: z.string(),
    status: z.enum(["draft", "published", "archived"]),
    version: z.int(),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
    published_at: z.iso.datetime().nullable(),
  })
  .meta({ id: "Article" });

export const ArticleEnvelope = z.object({ data: ArticleView }).meta({ id: "ArticleEnvelope" });
export const ArticlePage = z
  .object({ data: z.array(ArticleView), meta: z.object({ limit: z.int(), next_cursor: z.string().nullable(), has_more: z.boolean() }) })
  .meta({ id: "ArticlePage" });

export const toView = (a: Article): z.output<typeof ArticleView> => ({
  id: a.id,
  author_id: a.authorId,
  slug: a.slug,
  title: a.title,
  body: a.body,
  status: a.status,
  version: a.version,
  created_at: a.createdAt.toISOString(),
  updated_at: a.updatedAt.toISOString(),
  published_at: a.publishedAt?.toISOString() ?? null,
});

export function envelope(res: Response, article: Article) {
  res.setHeader("ETag", `"${article.version}"`);
  return { data: toView(article) };
}

/** If-Match by strong comparison with `"<version>"` (RFC 9110): absent or `*` sets no condition; else the versions listed. */
export function ifMatchVersions(header: string | undefined): number[] | undefined {
  if (header === undefined || header.trim() === "*") return undefined;
  return header.split(",").flatMap((tag) => /^\s*"([1-9]\d{0,8})"\s*$/.exec(tag)?.[1] ?? []).map(Number);
}
```

```ts file=src/inbound/http/articles.controller.ts
import { Body, Controller, Get, Headers, HttpCode, Param, Patch, Post, Query, Res, UseInterceptors } from "@nestjs/common";
import { ApiBearerAuth, ApiHeader, ApiTags } from "@nestjs/swagger";
import type { Response } from "express";
import { Publishing } from "../../domain/publishing/use-cases.js";
import type { Actor } from "../../domain/shared/ports.js";
import {
  ArticleEnvelope, ArticleId, ArticlePage, CreateArticleBody, envelope, ifMatchVersions, ListArticlesQuery, toView,
  UpdateArticleBody,
} from "./articles.schemas.js";
import { CurrentActor } from "./auth.js";
import { IdempotencyInterceptor } from "./idempotency.interceptor.js";
import { ApiProblems, ApiResult } from "./openapi.js";

@ApiTags("articles")
@ApiBearerAuth()
@ApiProblems(401, 404, 500, 503)
@Controller("v1/articles")
export class ArticlesController {
  constructor(private readonly publishing: Publishing) {}

  @Post()
  @UseInterceptors(IdempotencyInterceptor)
  @ApiHeader({ name: "Idempotency-Key", required: false })
  @ApiResult(201, ArticleEnvelope, "Location", "ETag", "Idempotent-Replayed")
  @ApiProblems(400, 409, 413, 415, 422)
  async create(@CurrentActor() actor: Actor, @Body({ schema: CreateArticleBody }) body: CreateArticleBody, @Res({ passthrough: true }) res: Response) {
    const article = await this.publishing.create(actor, body);
    res.location(`/v1/articles/${article.id}`);
    return envelope(res, article);
  }

  @Get()
  @ApiResult(200, ArticlePage)
  @ApiProblems(400, 422)
  async list(@CurrentActor() actor: Actor, @Query({ schema: ListArticlesQuery }) query: ListArticlesQuery) {
    const page = await this.publishing.list(actor, query.cursor ?? null, query.limit);
    const meta = { limit: query.limit, next_cursor: page.nextCursor, has_more: page.nextCursor !== null };
    return { data: page.items.map(toView), meta };
  }

  @Get(":id")
  @ApiResult(200, ArticleEnvelope, "ETag")
  @ApiResult(304, undefined, "ETag")
  @ApiProblems(400)
  async get(@CurrentActor() actor: Actor, @Param("id", { schema: ArticleId }) id: string, @Res({ passthrough: true }) res: Response) {
    return envelope(res, await this.publishing.get(actor, id));
  }

  @Patch(":id")
  @ApiHeader({ name: "If-Match", required: false })
  @ApiResult(200, ArticleEnvelope, "ETag")
  @ApiProblems(400, 403, 409, 412, 413, 415, 422)
  async update(
    @CurrentActor() actor: Actor,
    @Param("id", { schema: ArticleId }) id: string,
    @Body({ schema: UpdateArticleBody }) patch: UpdateArticleBody,
    @Headers("if-match") ifMatch: string | undefined,
    @Res({ passthrough: true }) res: Response,
  ) {
    return envelope(res, await this.publishing.update(actor, id, patch, ifMatchVersions(ifMatch)));
  }

  @Post(":id/publish")
  @HttpCode(200)
  @UseInterceptors(IdempotencyInterceptor)
  @ApiHeader({ name: "Idempotency-Key", required: false })
  @ApiResult(200, ArticleEnvelope, "ETag", "Idempotent-Replayed")
  @ApiProblems(400, 403, 409, 422)
  async publish(@CurrentActor() actor: Actor, @Param("id", { schema: ArticleId }) id: string, @Res({ passthrough: true }) res: Response) {
    return envelope(res, await this.publishing.publish(actor, id));
  }
}
```

The global pipe records where a value came from, so a bad path parameter is a 400 and a bad body or query value a 422.

```ts file=src/inbound/http/validation.pipe.ts
import { StandardSchemaValidationPipe, type ArgumentMetadata } from "@nestjs/common";
import { RequestValidationError } from "./problem.js";

/** The exception factory never learns the source, so transform() adds it: param → 400, else 422. */
export class SchemaValidationPipe extends StandardSchemaValidationPipe {
  constructor() {
    super({ exceptionFactory: (issues) => new RequestValidationError(issues) });
  }

  override async transform<T>(value: T, metadata: ArgumentMetadata): Promise<T> {
    try {
      return await super.transform(value, metadata);
    } catch (error) {
      if (!(error instanceof RequestValidationError)) throw error;
      throw new RequestValidationError(error.issues, metadata.type, metadata.data);
    }
  }
}
```

```ts file=src/inbound/http/openapi.ts
import { applyDecorators, type INestApplication } from "@nestjs/common";
import { ApiResponse, DocumentBuilder, SwaggerModule, type OpenAPIObject, type StandardSchemaObject } from "@nestjs/swagger";
import { STATUS_CODES } from "node:http";
import { z } from "zod";

const Problem = z.object({
  type: z.url(),
  title: z.string(),
  status: z.int(),
  detail: z.string(),
  instance: z.string(),
  errors: z.array(z.object({ pointer: z.string().optional(), parameter: z.string().optional(), detail: z.string(), code: z.string() })).optional(),
});

/** Response headers by name; every response carries X-Request-Id. */
const headers = (...names: string[]) =>
  Object.fromEntries(["X-Request-Id", ...names].map((name) => [name, { schema: { type: "string" as const } }]));

export const ApiResult = (status: number, standardSchema?: StandardSchemaObject, ...headerNames: string[]) =>
  ApiResponse({ status, description: STATUS_CODES[status], standardSchema, headers: headers(...headerNames) });

export const ApiProblems = (...statuses: number[]) =>
  applyDecorators(
    ...statuses.map((status) =>
      ApiResponse({
        status,
        description: STATUS_CODES[status],
        headers: headers(...(status === 409 || status === 503 ? ["Retry-After"] : [])),
        content: { "application/problem+json": { schema: { $ref: "#/components/schemas/Problem" } } },
      }),
    ),
  );

export function buildOpenApi(app: INestApplication): OpenAPIObject {
  const document = SwaggerModule.createDocument(app, new DocumentBuilder().setTitle("Publishing API").setVersion("1").addBearerAuth().build());
  const problem: object = z.toJSONSchema(Problem, { target: "openapi-3.0" });
  document.components = { ...document.components, schemas: { ...document.components?.schemas, Problem: problem } };
  return document;
}
```

## Problem documents

One renderer serves domain errors, validation failures, Nest's and body-parser's exceptions and unknown errors. The global filter and the idempotency interceptor both call it.

```ts file=src/inbound/http/problem.ts
import { HttpException, type Paramtype } from "@nestjs/common";
import type { Request } from "express";
import { METHODS, STATUS_CODES } from "node:http";
import { DomainError, type ErrorKind } from "../../domain/shared/errors.js";

/** http-api.md § Problem types: each slug's status and fixed title. */
const TYPES = {
  "malformed-request": [400, "Malformed request"],
  unauthenticated: [401, "Unauthenticated"],
  forbidden: [403, "Forbidden"],
  "not-found": [404, "Not found"],
  "method-not-allowed": [405, "Method not allowed"],
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
} as const;
export type ProblemSlug = keyof typeof TYPES;

const BY_KIND = {
  invalid: "validation-failed",
  malformed: "malformed-request",
  forbidden: "forbidden",
  not_found: "not-found",
  conflict: "already-exists", // refined by the error's code
  precondition_failed: "precondition-failed",
  unavailable: "unavailable",
} as const satisfies Record<ErrorKind, ProblemSlug>;

/** Statuses with exactly one slug; an exception with any other status renders as about:blank. */
const BY_STATUS: Partial<Record<number, ProblemSlug>> = {
  400: "malformed-request", 401: "unauthenticated", 403: "forbidden", 404: "not-found", 405: "method-not-allowed",
  412: "precondition-failed", 413: "payload-too-large", 415: "unsupported-media-type", 428: "precondition-required",
  429: "rate-limited", 500: "internal", 503: "unavailable",
};

const GENERIC = "An unexpected error occurred";

type FieldIssue = { pointer?: string; parameter?: string; detail: string; code: string };
type Problem = { slug: ProblemSlug | number; detail: string; headers?: Record<string, string>; errors?: FieldIssue[] };

export class ProblemException extends Error {
  constructor(
    readonly slug: ProblemSlug,
    readonly detail: string,
    readonly headers: Readonly<Record<string, string>> = {},
  ) {
    super(detail);
  }
}

export class RequestValidationError extends Error {
  constructor(
    readonly issues: readonly { message: string; path?: readonly (PropertyKey | { key: PropertyKey })[] | undefined }[],
    readonly source: Paramtype = "body",
    readonly parameter = "",
  ) {
    super("request validation failed");
  }
}

/** Every error becomes one problem document; anything unrecognized is a generic 500. */
export function renderProblem(error: unknown, req: Request, baseUri: string) {
  const { slug, detail, headers = {}, errors } = classify(error, req);
  const [status, title] = typeof slug === "number" ? [slug, STATUS_CODES[slug] ?? "Error"] : TYPES[slug];
  if (status === 401) headers["WWW-Authenticate"] ??= "Bearer";
  if (status === 405) headers.Allow ??= allowedMethods(req).filter((method) => method !== req.method).join(", ");
  if (status === 503 || slug === "idempotency-in-flight") headers["Retry-After"] ??= status === 503 ? "2" : "1";
  const type = typeof slug === "number" ? "about:blank" : baseUri + slug;
  const body = { type, title, status, detail, instance: req.originalUrl.split("?")[0], ...(errors && { errors }) };
  return { status, headers: { "Content-Type": "application/problem+json", ...headers }, body };
}

function classify(error: unknown, req: Request): Problem {
  if (error instanceof ProblemException) return { slug: error.slug, detail: error.detail, headers: { ...error.headers } };
  if (error instanceof DomainError) return fromDomain(error);
  if (error instanceof RequestValidationError) return fromValidation(error);
  const status = error instanceof HttpException ? error.getStatus() : exposedStatus(error);
  if (status === undefined || !(error instanceof Error)) return { slug: "internal", detail: GENERIC };
  const allowed = status === 404 ? allowedMethods(req) : [];
  // The router's 404: no route serves this method (a handler's own 404 stays one). Express has no 405.
  if (status === 404 && !allowed.includes(req.method === "HEAD" ? "GET" : req.method)) {
    return allowed.length > 0
      ? { slug: "method-not-allowed", detail: `${req.method} is not supported here` }
      : { slug: "not-found", detail: `no route for ${req.method} ${req.path}` };
  }
  const detail = status < 500 ? error.message : status === 503 ? "Temporarily unable to complete the request" : GENERIC;
  return { slug: BY_STATUS[status] ?? status, detail };
}

const isSlug = (code: string): code is ProblemSlug => Object.hasOwn(TYPES, code);

function fromDomain({ kind, code, field, message: detail }: DomainError): Problem {
  if (kind === "invalid") return { slug: BY_KIND.invalid, detail, errors: [{ pointer: pointer(field ? [field] : []), detail, code }] };
  return { slug: kind === "conflict" && isSlug(code) ? code : BY_KIND[kind], detail };
}

function fromValidation({ issues, source, parameter }: RequestValidationError): Problem {
  if (source === "param") return { slug: "malformed-request", detail: `path parameter '${parameter}' is not a valid identifier` };
  const errors = issues.flatMap((issue) => {
    const path = (issue.path ?? []).map((segment) => String(typeof segment === "object" ? segment.key : segment));
    const code = "code" in issue && typeof issue.code === "string" ? issue.code : "invalid";
    // Zod reports unknown members on their parent; point at each member instead.
    const keys = "keys" in issue && Array.isArray(issue.keys) ? issue.keys.map(String) : [undefined];
    return keys.map((key): FieldIssue => {
      const at = key === undefined ? path : [...path, key];
      return source === "query"
        ? { parameter: at[0] ?? parameter, detail: issue.message, code }
        : { pointer: pointer(at), detail: issue.message, code };
    });
  });
  return { slug: "validation-failed", detail: `${errors.length} invalid value(s)`, errors };
}

/** A JSON Pointer as a URI fragment (RFC 6901 § 6): `#` is the whole body. */
const pointer = (path: readonly string[]) =>
  path.length === 0 ? "#" : `#/${path.map((s) => s.replaceAll("~", "~0").replaceAll("/", "~1")).join("/")}`;

/** body-parser's errors (`http-errors`) expose client faults: 400, 413, 415. */
const exposedStatus = (error: unknown) =>
  typeof error === "object" && error !== null && "expose" in error && error.expose === true &&
  "status" in error && typeof error.status === "number" ? error.status : undefined;

/** The methods the path's endpoints serve, skipping the catch-alls of module middleware. */
function allowedMethods(req: Request): string[] {
  const allowed = req.app.router.stack.flatMap((layer) => {
    const methods = layer.route?.stack.map((handler) => handler.method.toUpperCase()) ?? [];
    return methods.length > 0 && methods.length < METHODS.length && matches(layer, req.path) ? methods : [];
  });
  return [...new Set(allowed)].toSorted();
}

// Express 5's Layer#match(path) is missing from @types/express.
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- a typed view of a runtime method
const matches = (layer: object, path: string) => (layer as { match(path: string): boolean }).match(path);
```

```ts file=src/inbound/http/problem.filter.ts
import { Catch, Logger, type ArgumentsHost, type ExceptionFilter } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { HttpAdapterHost } from "@nestjs/core";
import type { Request, Response } from "express";
import type { Env } from "../../config.js";
import { renderProblem } from "./problem.js";

@Catch()
export class ProblemFilter implements ExceptionFilter {
  private readonly logger = new Logger(ProblemFilter.name);
  private readonly baseUri: string;

  constructor(
    private readonly adapterHost: HttpAdapterHost,
    config: ConfigService<Env, true>,
  ) {
    this.baseUri = config.get("PROBLEM_BASE_URI", { infer: true });
  }

  catch(error: unknown, host: ArgumentsHost): void {
    if (host.getType() !== "http") throw error;
    const req = host.switchToHttp().getRequest<Request>();
    const res = host.switchToHttp().getResponse<Response>();
    if (res.headersSent) return; // the deadline answered first
    const problem = renderProblem(error, req, this.baseUri);
    // Once, here. A probe's 503 is expected while starting or draining.
    if (problem.status >= 500 && !req.path.startsWith("/health")) this.logger.error({ err: error }, "request failed");
    for (const [name, value] of Object.entries(problem.headers)) res.setHeader(name, value);
    this.adapterHost.httpAdapter.reply(res, problem.body, problem.status);
  }
}
```
