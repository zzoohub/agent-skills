# NestJS examples: adapters

Outbound PostgreSQL adapters (TypeORM 1.1 under `@nestjs-cls/transactional`) and inbound HTTP and webhook adapters. Complete files of the same project as `examples-domain.md`.

## Contents

1. [Schema migration](#schema-migration)
2. [Entity and connection options](#entity-and-connection-options)
3. [Transaction rules and the unit of work](#transaction-rules-and-the-unit-of-work)
4. [Article repository](#article-repository)
5. [Outbox and inbox](#outbox-and-inbox)
6. [Idempotency store](#idempotency-store)
7. [Outbox relay](#outbox-relay)
8. [Problem documents](#problem-documents)
9. [Filter, validation pipe and edge middleware](#filter-validation-pipe-and-edge-middleware)
10. [Bearer auth and the Actor](#bearer-auth-and-the-actor)
11. [Idempotency interceptor](#idempotency-interceptor)
12. [Schemas, controller and OpenAPI](#schemas-controller-and-openapi)
13. [Moderation webhook](#moderation-webhook)
14. [Health probes](#health-probes)

## Schema migration

Hand-written SQL that TypeORM runs; the release step applies it before the code that needs it.

```ts file=src/migrations/1791417600000-publishing.ts
import type { MigrationInterface, QueryRunner } from "typeorm";

// uuidv7() needs PostgreSQL 18.
export class Publishing1791417600000 implements MigrationInterface {
  async up(db: QueryRunner): Promise<void> {
    await db.query(`
      CREATE TABLE articles (
        id           uuid PRIMARY KEY,
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
        CONSTRAINT articles_tenant_slug_key UNIQUE (tenant_id, slug),
        CONSTRAINT articles_status_check CHECK (status IN ('draft', 'published', 'archived')),
        CONSTRAINT articles_length_check CHECK (
          char_length(slug) <= 100 AND char_length(title) BETWEEN 1 AND 200 AND char_length(body) <= 20000)
      );
      CREATE INDEX articles_tenant_id_id_idx ON articles (tenant_id, id);

      CREATE TABLE outbox (
        id               uuid PRIMARY KEY DEFAULT uuidv7(),
        tenant_id        uuid NOT NULL,
        aggregate_type   text NOT NULL,
        aggregate_id     uuid NOT NULL,
        aggregate_seq    integer NOT NULL,
        event_type       text NOT NULL,
        event_version    integer NOT NULL,
        payload          jsonb NOT NULL,
        headers          jsonb NOT NULL DEFAULT '{}',
        created_at       timestamptz NOT NULL DEFAULT now(),
        published_at     timestamptz,
        attempts         integer NOT NULL DEFAULT 0,
        next_attempt_at  timestamptz NOT NULL DEFAULT now(),
        last_error       text,
        dead_lettered_at timestamptz,
        CONSTRAINT outbox_aggregate_seq_key UNIQUE (aggregate_id, aggregate_seq)
      );
      CREATE INDEX outbox_pending_idx ON outbox (next_attempt_at, id)
        WHERE published_at IS NULL AND dead_lettered_at IS NULL;

      CREATE TABLE idempotency_keys (
        scope        text NOT NULL,
        key          text NOT NULL,
        request_hash text NOT NULL,
        lease_token  uuid NOT NULL,
        locked_until timestamptz NOT NULL,
        status       integer,
        response     bytea,
        completed_at timestamptz,
        expires_at   timestamptz NOT NULL,
        PRIMARY KEY (scope, key)
      );
      CREATE INDEX idempotency_keys_expires_at_idx ON idempotency_keys (expires_at);

      CREATE TABLE inbox (
        consumer    text NOT NULL,
        message_id  text NOT NULL,
        received_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (consumer, message_id)
      );
    `);
  }

  async down(db: QueryRunner): Promise<void> {
    await db.query(`DROP TABLE inbox, idempotency_keys, outbox, articles`);
  }
}
```

## Entity and connection options

Only `articles` has an entity; the infrastructure tables are reached through SQL.

```ts file=src/outbound/postgres/article.entity.ts
import { Check, Column, Entity, Index, PrimaryColumn, Unique } from "typeorm";
import type { ArticleStatus } from "../../domain/publishing/article.js";

// Mirrors the SQL migration, constraint names included.
@Entity({ name: "articles" })
@Unique("articles_tenant_slug_key", ["tenantId", "slug"])
@Index("articles_tenant_id_id_idx", ["tenantId", "id"])
@Check("articles_status_check", `status IN ('draft', 'published', 'archived')`)
@Check("articles_length_check", `char_length(slug) <= 100 AND char_length(title) BETWEEN 1 AND 200 AND char_length(body) <= 20000`)
export class ArticleEntity {
  @PrimaryColumn("uuid") id!: string;
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

```ts file=src/outbound/postgres/options.ts
import type { DataSourceOptions } from "typeorm";
import { Publishing1791417600000 } from "../../migrations/1791417600000-publishing.js";
import { ArticleEntity } from "./article.entity.js";

/** For the API, the worker, the CLI and the tests. */
export function postgresOptions(settings: {
  url: string;
  applicationName: string;
  poolSize?: number;
  statementTimeoutMs?: number; // 0 = none, for migrations
}): DataSourceOptions {
  return {
    type: "postgres",
    url: settings.url,
    applicationName: settings.applicationName,
    entities: [ArticleEntity],
    migrations: [Publishing1791417600000],
    migrationsTransactionMode: "each",
    poolSize: settings.poolSize ?? 10,
    connectTimeoutMS: 3_000,
    extra: { statement_timeout: settings.statementTimeoutMs ?? 0, idle_in_transaction_session_timeout: 15_000 },
  };
}
```

## Transaction rules and the unit of work

```ts file=src/outbound/postgres/db.ts
import { Injectable } from "@nestjs/common";
import { TransactionHost } from "@nestjs-cls/transactional";
import type { TransactionalAdapterTypeOrm } from "@nestjs-cls/transactional-adapter-typeorm";
import { QueryFailedError, type EntityManager } from "typeorm";
import { DomainError } from "../../domain/shared/errors.js";

@Injectable()
export class Db {
  constructor(private readonly txHost: TransactionHost<TransactionalAdapterTypeOrm>) {}

  async read<T>(query: (em: EntityManager) => Promise<T>): Promise<T> {
    try {
      return await query(this.txHost.tx);
    } catch (error) {
      throw translateDbError(error);
    }
  }

  write<T>(command: (em: EntityManager) => Promise<T>): Promise<T> {
    if (!this.txHost.isTransactionActive()) return Promise.reject(new Error("database write outside a unit of work"));
    return command(this.txHost.tx);
  }

  /** Commits on its own, even inside a unit of work. */
  outside<T>(query: (em: EntityManager) => Promise<T>): Promise<T> {
    return this.txHost.withoutTransaction(() => this.read(query));
  }
}

export function sqlState(error: unknown): string | undefined {
  if (error instanceof DomainError) return sqlState(error.cause);
  const source: unknown = error instanceof QueryFailedError ? error.driverError : error;
  return typeof source === "object" && source !== null && "code" in source && typeof source.code === "string"
    ? source.code
    : undefined;
}

export function isUniqueViolation(error: unknown, constraint: string): boolean {
  const driver: unknown = error instanceof QueryFailedError ? error.driverError : undefined;
  return sqlState(error) === "23505" && typeof driver === "object" && driver !== null &&
    "constraint" in driver && driver.constraint === constraint;
}

export const isRetryable = (error: unknown) => ["40001", "40P01"].includes(sqlState(error) ?? "");

const TRANSIENT = /^(08|53|57P0|57014|55P03|40001|40P01|ECONNREFUSED|ECONNRESET|ETIMEDOUT)/;

export function translateDbError(error: unknown): unknown {
  if (error instanceof DomainError) return error;
  const transient = TRANSIENT.test(sqlState(error) ?? "") ||
    (error instanceof Error && /timeout exceeded when trying to connect|Connection terminated/.test(error.message));
  return transient ? new DomainError("unavailable", "the database is unavailable", { cause: error }) : error;
}
```

```ts file=src/outbound/postgres/unit-of-work.ts
import { Injectable } from "@nestjs/common";
import { TransactionHost } from "@nestjs-cls/transactional";
import type { TransactionalAdapterTypeOrm } from "@nestjs-cls/transactional-adapter-typeorm";
import { setTimeout as sleep } from "node:timers/promises";
import { UnitOfWork } from "../../domain/shared/ports.js";
import { isRetryable, translateDbError } from "./db.js";

@Injectable()
export class TypeOrmUnitOfWork extends UnitOfWork {
  constructor(private readonly txHost: TransactionHost<TransactionalAdapterTypeOrm>) {
    super();
  }

  async run<T>(work: () => Promise<T>): Promise<T> {
    // Joining: the outer owner commits, retries and translates.
    if (this.txHost.isTransactionActive()) return work();
    for (let attempt = 1; ; attempt++) {
      try {
        return await this.txHost.withTransaction(work);
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

## Article repository

Tenant-scoped in every query.

```ts file=src/outbound/postgres/article.repository.ts
import { Injectable } from "@nestjs/common";
import { rehydrateArticle, type Article, type ArticleStatus } from "../../domain/publishing/article.js";
import { ArticleRepository } from "../../domain/publishing/ports.js";
import { conflict, DomainError } from "../../domain/shared/errors.js";
import type { Page } from "../../domain/shared/ports.js";
import { ArticleEntity } from "./article.entity.js";
import { Db, isUniqueViolation } from "./db.js";

@Injectable()
export class TypeOrmArticleRepository extends ArticleRepository {
  constructor(private readonly db: Db) {
    super();
  }

  async insert(article: Article): Promise<void> {
    try {
      await this.db.write((em) => em.insert(ArticleEntity, { ...article }));
    } catch (error) {
      if (!isUniqueViolation(error, "articles_tenant_slug_key")) throw error;
      throw conflict("already-exists", `an article with slug '${article.slug}' already exists`);
    }
  }

  async findById(tenantId: string, id: string): Promise<Article | null> {
    const row = await this.db.read((em) => em.findOneBy(ArticleEntity, { tenantId, id }));
    return row && rehydrateArticle(row);
  }

  async list(tenantId: string, cursor: string | null, limit: number): Promise<Page<Article>> {
    const after = cursor === null ? null : decodeCursor(cursor);
    const rows = await this.db.read((em) => {
      const query = em.createQueryBuilder(ArticleEntity, "a").where("a.tenant_id = :tenantId", { tenantId });
      if (after) query.andWhere("a.id < :after", { after });
      return query.orderBy("a.id", "DESC").limit(limit + 1).getMany();
    });
    const items = rows.slice(0, limit).map(rehydrateArticle);
    const last = items.at(-1);
    return { items, nextCursor: rows.length > limit && last ? encodeCursor(last.id) : null };
  }

  async update(article: Article, expectedVersion: number): Promise<boolean> {
    const { tenantId, id, title, body, version, updatedAt } = article;
    const { affected } = await this.db.write((em) =>
      em.update(ArticleEntity, { tenantId, id, version: expectedVersion }, { title, body, version, updatedAt }),
    );
    return affected === 1;
  }

  async transition(next: Article, from: ArticleStatus): Promise<Article | null> {
    const { tenantId, id, status, publishedAt, updatedAt } = next;
    const { affected } = await this.db.write((em) =>
      em.update(ArticleEntity, { tenantId, id, status: from }, { status, publishedAt, updatedAt, version: () => "version + 1" }),
    );
    return affected === 1 ? this.findById(tenantId, id) : null;
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

## Outbox and inbox

```ts file=src/outbound/postgres/outbox-inbox.ts
import { Injectable } from "@nestjs/common";
import { context, propagation } from "@opentelemetry/api";
import { Inbox, Outbox, type DomainEvent } from "../../domain/publishing/ports.js";
import { Db } from "./db.js";

@Injectable()
export class SqlOutbox extends Outbox {
  constructor(private readonly db: Db) {
    super();
  }

  async append(events: readonly DomainEvent[]): Promise<void> {
    const headers: Record<string, string> = {};
    propagation.inject(context.active(), headers); // traceparent, captured at insert
    for (const e of events) {
      await this.db.write((em) =>
        em.query(
          `INSERT INTO outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload, headers)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [e.tenantId, e.aggregateType, e.aggregateId, e.aggregateSeq, e.type, e.version, e.payload, { ...headers, tenant_id: e.tenantId }],
        ),
      );
    }
  }
}

@Injectable()
export class SqlInbox extends Inbox {
  constructor(private readonly db: Db) {
    super();
  }

  async claim(consumer: string, messageId: string): Promise<boolean> {
    const rows: unknown[] = await this.db.write((em) =>
      em.query(`INSERT INTO inbox (consumer, message_id) VALUES ($1, $2) ON CONFLICT DO NOTHING RETURNING 1`, [consumer, messageId]),
    );
    return rows.length === 1;
  }
}
```

## Idempotency store

```ts file=src/outbound/postgres/idempotency.store.ts
import { Injectable } from "@nestjs/common";
import { DomainError } from "../../domain/shared/errors.js";
import { IdempotencyStore, type Acquired, type StoredResponse } from "../../domain/shared/idempotency.js";
import { Db } from "./db.js";

// Longer than REQUEST_TIMEOUT_MS (<= 30 s) plus the tail of a handler Node cannot cancel.
const LEASE = "interval '60 seconds'";

interface KeyRow { request_hash: string; completed_at: Date | null; status: number; response: Buffer }

@Injectable()
export class SqlIdempotencyStore extends IdempotencyStore {
  constructor(private readonly db: Db) {
    super();
  }

  acquire(scope: string, key: string, requestHash: string): Promise<Acquired> {
    return this.db.outside(async (em) => {
      // Only this insert, or a takeover of an expired lease on the same request, grants execution.
      const [won]: { lease: string }[] = await em.query(
        `INSERT INTO idempotency_keys AS k (scope, key, request_hash, lease_token, locked_until, expires_at)
         VALUES ($1, $2, $3, gen_random_uuid(), now() + ${LEASE}, now() + interval '24 hours')
         ON CONFLICT (scope, key) DO UPDATE SET lease_token = excluded.lease_token, locked_until = excluded.locked_until
           WHERE k.completed_at IS NULL AND k.locked_until < now() AND k.request_hash = excluded.request_hash
         RETURNING lease_token AS lease`,
        [scope, key, requestHash],
      );
      if (won) return { kind: "new", lease: won.lease };
      const [row]: KeyRow[] = await em.query(
        `SELECT request_hash, completed_at, status, response FROM idempotency_keys WHERE scope = $1 AND key = $2`,
        [scope, key],
      );
      if (!row) return { kind: "in_flight" }; // released meanwhile: the retry wins
      if (row.request_hash !== requestHash) return { kind: "mismatch" };
      if (!row.completed_at) return { kind: "in_flight" };
      const stored: Omit<StoredResponse, "status"> = JSON.parse(row.response.toString("utf8"));
      return { kind: "replay", response: { status: row.status, ...stored } };
    });
  }

  async complete(scope: string, key: string, lease: string, response: StoredResponse): Promise<void> {
    const stored = Buffer.from(JSON.stringify({ headers: response.headers, body: response.body }));
    const [, completed]: [unknown[], number] = await this.db.write((em) =>
      em.query(
        `UPDATE idempotency_keys SET status = $4, response = $5, completed_at = now()
         WHERE scope = $1 AND key = $2 AND lease_token = $3 AND completed_at IS NULL`,
        [scope, key, lease, response.status, stored],
      ),
    );
    if (completed !== 1) {
      throw new DomainError("conflict", "the idempotency lease expired and was taken over", { code: "idempotency-in-flight" });
    }
  }

  async release(scope: string, key: string, lease: string): Promise<void> {
    await this.db.outside((em) =>
      em.query(`DELETE FROM idempotency_keys WHERE scope = $1 AND key = $2 AND lease_token = $3 AND completed_at IS NULL`, [scope, key, lease]),
    );
  }

  async purgeExpired(): Promise<number> {
    const [, deleted]: [unknown[], number] = await this.db.outside((em) => em.query(`DELETE FROM idempotency_keys WHERE expires_at < now()`));
    return deleted;
  }
}
```

## Outbox relay

```ts file=src/outbound/postgres/outbox-relay.ts
import { Injectable, Logger } from "@nestjs/common";
import { metrics } from "@opentelemetry/api";
import { DataSource } from "typeorm";

export interface OutboxMessage {
  readonly id: string;
  readonly tenantId: string;
  readonly aggregateId: string;
  readonly aggregateSeq: number;
  readonly type: string;
  readonly version: number;
  readonly payload: unknown;
  readonly headers: Readonly<Record<string, string>>;
  readonly attempts: number;
}

/** Delivery is at-least-once: consumers dedup by `id`. */
export abstract class EventPublisher {
  abstract publish(message: OutboxMessage): Promise<void>;
}

export class RelayOptions {
  batchSize = 50;
  maxAttempts = 10;
  baseDelayMs = 1_000;
  maxDelayMs = 300_000;
  claimMs = 30_000;
}

const CLAIM = `
  WITH heads AS (
    SELECT o.id FROM outbox o
    WHERE o.published_at IS NULL AND o.dead_lettered_at IS NULL AND o.next_attempt_at <= now()
      AND NOT EXISTS (SELECT 1 FROM outbox p WHERE p.aggregate_id = o.aggregate_id AND p.aggregate_seq < o.aggregate_seq
                        AND p.published_at IS NULL AND p.dead_lettered_at IS NULL)
    ORDER BY o.next_attempt_at, o.id LIMIT $1
    FOR UPDATE SKIP LOCKED)
  UPDATE outbox SET next_attempt_at = now() + $2 * interval '1 millisecond' FROM heads WHERE outbox.id = heads.id
  RETURNING outbox.id, outbox.tenant_id AS "tenantId", outbox.aggregate_id AS "aggregateId",
    outbox.aggregate_seq AS "aggregateSeq", outbox.event_type AS "type", outbox.event_version AS "version",
    outbox.payload, outbox.headers, outbox.attempts`;

@Injectable()
export class OutboxRelay {
  private readonly logger = new Logger(OutboxRelay.name);
  private oldestPendingSeconds = 0;

  constructor(
    private readonly db: DataSource,
    private readonly publisher: EventPublisher,
    private readonly options: RelayOptions,
  ) {
    metrics
      .getMeter("outbox")
      .createObservableGauge("outbox.oldest_pending.age", { unit: "s" })
      .addCallback((gauge) => gauge.observe(this.oldestPendingSeconds));
  }

  async runOnce(): Promise<number> {
    const [claimed]: [OutboxMessage[], number] = await this.db.query(CLAIM, [this.options.batchSize, this.options.claimMs]);
    for (const message of claimed) {
      try {
        await this.publisher.publish(message);
        await this.db.query(`UPDATE outbox SET published_at = now(), attempts = attempts + 1 WHERE id = $1`, [message.id]);
      } catch (error) {
        await this.recordFailure(message, error);
      }
    }
    const [oldest]: { age: number }[] = await this.db.query(
      `SELECT coalesce(extract(epoch FROM now() - min(created_at)), 0)::float8 AS age
       FROM outbox WHERE published_at IS NULL AND dead_lettered_at IS NULL`,
    );
    this.oldestPendingSeconds = oldest?.age ?? 0;
    return claimed.length;
  }

  private async recordFailure(message: OutboxMessage, error: unknown): Promise<void> {
    const attempts = message.attempts + 1;
    const dead = attempts >= this.options.maxAttempts;
    const delayMs = Math.random() * Math.min(this.options.maxDelayMs, this.options.baseDelayMs * 2 ** attempts);
    await this.db.query(
      `UPDATE outbox SET attempts = $2, last_error = $3, next_attempt_at = now() + $4 * interval '1 millisecond',
         dead_lettered_at = CASE WHEN $5::boolean THEN now() END
       WHERE id = $1`,
      [message.id, attempts, String(error).slice(0, 2_000), Math.round(delayMs), dead],
    );
    if (dead) this.logger.error({ outboxId: message.id, err: error }, "outbox event dead-lettered");
  }
}
```

## Problem documents

The registry and the one renderer every error passes through, used by the filter and by the idempotency interceptor (a stored 4xx is exactly what the filter sends).

```ts file=src/inbound/http/problem.ts
import { HttpException, type Paramtype } from "@nestjs/common";
import type { Request } from "express";
import { METHODS, STATUS_CODES } from "node:http";
import { DomainError, type ErrorKind } from "../../domain/shared/errors.js";

/** api-design.md § Problem Types: each slug's status and fixed title. */
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

## Filter, validation pipe and edge middleware

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

## Bearer auth and the Actor

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

## Idempotency interceptor

```ts file=src/inbound/http/idempotency.interceptor.ts
import { Injectable, type CallHandler, type ExecutionContext, type NestInterceptor } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import type { Request, Response } from "express";
import { createHash } from "node:crypto";
import { from, lastValueFrom, type Observable } from "rxjs";
import type { Env } from "../../config.js";
import { IdempotencyStore } from "../../domain/shared/idempotency.js";
import { UnitOfWork } from "../../domain/shared/ports.js";
import { ProblemException, renderProblem } from "./problem.js";

@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  private readonly baseUri: string;

  constructor(
    private readonly store: IdempotencyStore,
    private readonly uow: UnitOfWork,
    config: ConfigService<Env, true>,
  ) {
    this.baseUri = config.get("PROBLEM_BASE_URI", { infer: true });
  }

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<Request>();
    const res = context.switchToHttp().getResponse<Response>();
    const key = req.header("idempotency-key");
    if (key === undefined) return next.handle();
    if (!req.actor) throw new Error("IdempotencyInterceptor needs an authenticated route");
    if (!/^[\x21-\x7E]{1,255}$/.test(key)) {
      throw new ProblemException("malformed-request", "Idempotency-Key must be 1-255 visible ASCII characters");
    }
    const scope = `${req.actor.tenantId}:${req.actor.subject}`;
    const hash = createHash("sha256").update(`${req.method} ${req.path}\n${canonicalJson(req.body ?? null)}`).digest("hex");
    return from(this.execute(scope, key, hash, req, res, next));
  }

  private async execute(scope: string, key: string, hash: string, req: Request, res: Response, next: CallHandler) {
    const acquired = await this.store.acquire(scope, key, hash);
    switch (acquired.kind) {
      case "mismatch":
        throw new ProblemException("idempotency-key-mismatch", "this key was used for a different request");
      case "in_flight":
        throw new ProblemException("idempotency-in-flight", "a request with this key is still running");
      case "replay":
        res.status(acquired.response.status).setHeader("Idempotent-Replayed", "true");
        for (const [name, value] of Object.entries(acquired.response.headers)) res.setHeader(name, value);
        return acquired.response.body;
    }
    const { lease } = acquired; // "new": this request won the key
    try {
      return await this.uow.run(async () => {
        const body: unknown = await lastValueFrom(next.handle(), { defaultValue: undefined });
        if (res.headersSent) throw new Error("the deadline answered first; not storing");
        const headers: Record<string, string> = { "content-type": "application/json; charset=utf-8" };
        for (const name of ["location", "etag"]) {
          const value = res.getHeader(name);
          if (typeof value === "string") headers[name] = value;
        }
        await this.store.complete(scope, key, lease, { status: res.statusCode, headers, body });
        return body;
      });
    } catch (error) {
      const problem = renderProblem(error, req, this.baseUri);
      const stored = problem.status < 500 &&
        (await this.uow.run(() => this.store.complete(scope, key, lease, problem)).then(() => true, () => false));
      if (!stored) await this.store.release(scope, key, lease).catch(() => undefined);
      throw error;
    }
  }
}

const canonicalJson = (value: unknown): string =>
  JSON.stringify(value, (_key, v: unknown) =>
    v !== null && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(Object.entries(v).toSorted(([a], [b]) => (a < b ? -1 : 1)))
      : v,
  );
```

## Schemas, controller and OpenAPI

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
import { ArticleService } from "../../domain/publishing/article-service.js";
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
  constructor(private readonly articles: ArticleService) {}

  @Post()
  @UseInterceptors(IdempotencyInterceptor)
  @ApiHeader({ name: "Idempotency-Key", required: false })
  @ApiResult(201, ArticleEnvelope, "Location", "ETag", "Idempotent-Replayed")
  @ApiProblems(400, 409, 413, 415, 422)
  async create(@CurrentActor() actor: Actor, @Body({ schema: CreateArticleBody }) body: CreateArticleBody, @Res({ passthrough: true }) res: Response) {
    const article = await this.articles.create(actor, body);
    res.location(`/v1/articles/${article.id}`);
    return envelope(res, article);
  }

  @Get()
  @ApiResult(200, ArticlePage)
  @ApiProblems(400, 422)
  async list(@CurrentActor() actor: Actor, @Query({ schema: ListArticlesQuery }) query: ListArticlesQuery) {
    const page = await this.articles.list(actor, query.cursor ?? null, query.limit);
    const meta = { limit: query.limit, next_cursor: page.nextCursor, has_more: page.nextCursor !== null };
    return { data: page.items.map(toView), meta };
  }

  @Get(":id")
  @ApiResult(200, ArticleEnvelope, "ETag")
  @ApiResult(304, undefined, "ETag")
  @ApiProblems(400)
  async get(@CurrentActor() actor: Actor, @Param("id", { schema: ArticleId }) id: string, @Res({ passthrough: true }) res: Response) {
    return envelope(res, await this.articles.get(actor, id));
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
    return envelope(res, await this.articles.update(actor, id, patch, ifMatchVersions(ifMatch)));
  }

  @Post(":id/publish")
  @HttpCode(200)
  @UseInterceptors(IdempotencyInterceptor)
  @ApiHeader({ name: "Idempotency-Key", required: false })
  @ApiResult(200, ArticleEnvelope, "ETag", "Idempotent-Replayed")
  @ApiProblems(400, 403, 409, 422)
  async publish(@CurrentActor() actor: Actor, @Param("id", { schema: ArticleId }) id: string, @Res({ passthrough: true }) res: Response) {
    return envelope(res, await this.articles.publish(actor, id));
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

## Moderation webhook

```ts file=src/inbound/webhooks/moderation.webhook.ts
import {
  Body, Controller, Headers, HttpCode, Injectable, Logger, Post, UseGuards, type CanActivate, type ExecutionContext,
  type RawBodyRequest,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { ApiExcludeController } from "@nestjs/swagger";
import type { Request } from "express";
import { createHmac, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import type { Env } from "../../config.js";
import { ModerationService } from "../../domain/publishing/article-service.js";
import { Clock } from "../../domain/shared/ports.js";
import { Public } from "../http/auth.js";
import { ProblemException } from "../http/problem.js";

/** Standard Webhooks; any configured secret may match, for rotation. */
@Injectable()
export class WebhookSignatureGuard implements CanActivate {
  private readonly secrets: Buffer[];

  constructor(
    config: ConfigService<Env, true>,
    private readonly clock: Clock,
  ) {
    this.secrets = config.get("WEBHOOK_SECRETS", { infer: true }); // decoded and checked by config.ts
  }

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<RawBodyRequest<Request>>();
    const id = req.header("webhook-id") ?? "";
    const timestamp = req.header("webhook-timestamp") ?? "";
    if (!/^[\x21-\x7E]{1,255}$/.test(id) || !/^\d{1,12}$/.test(timestamp) || !req.rawBody) throw reject("missing headers");
    if (Math.abs(this.clock.now().getTime() / 1000 - Number(timestamp)) > 300) throw reject("timestamp out of range");
    const signed = Buffer.concat([Buffer.from(`${id}.${timestamp}.`), req.rawBody]);
    const expected = this.secrets.map((secret) => createHmac("sha256", secret).update(signed).digest());
    const offered = (req.header("webhook-signature") ?? "")
      .split(" ")
      .filter((entry) => entry.startsWith("v1,"))
      .map((entry) => Buffer.from(entry.slice(3), "base64"));
    if (!offered.some((sig) => expected.some((mac) => mac.length === sig.length && timingSafeEqual(mac, sig)))) {
      throw reject("signature mismatch");
    }
    return true;
  }
}

const reject = (detail: string) =>
  new ProblemException("unauthenticated", `webhook rejected: ${detail}`, { "WWW-Authenticate": 'Signature realm="webhooks"' });

// Not strict: senders add fields.
const Verdict = z.object({ tenant_id: z.uuid(), article_id: z.uuid(), verdict: z.enum(["approved", "rejected"]) });

@ApiExcludeController()
@Public()
@Controller("internal/webhooks")
export class ModerationWebhookController {
  private readonly logger = new Logger(ModerationWebhookController.name);

  constructor(private readonly moderation: ModerationService) {}

  @Post("moderation")
  @HttpCode(204)
  @UseGuards(WebhookSignatureGuard)
  async receive(@Headers("webhook-id") id: string, @Body() body: unknown): Promise<void> {
    const message = Verdict.safeParse(body);
    if (!message.success) {
      // Permanent: record and acknowledge.
      this.logger.warn({ webhookId: id, issues: message.error.issues }, "moderation payload refused");
      return;
    }
    const { tenant_id: tenantId, article_id: articleId, verdict } = message.data;
    const outcome = await this.moderation.handle({ id, tenantId, articleId, verdict });
    this.logger.log({ webhookId: id, outcome }, "moderation verdict");
  }
}
```

## Health probes

```ts file=src/inbound/http/health.ts
import { Controller, Get, Injectable, type OnApplicationBootstrap } from "@nestjs/common";
import { ApiExcludeController } from "@nestjs/swagger";
import { HealthCheck, HealthCheckService, HealthIndicatorService } from "@nestjs/terminus";
import { DataSource } from "typeorm";
import { Public } from "./auth.js";

@Injectable()
export class ReadinessLatch implements OnApplicationBootstrap {
  private ready = false;

  constructor(
    private readonly db: DataSource,
    private readonly indicators: HealthIndicatorService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    if (await this.db.showMigrations()) throw new Error("pending migrations: run the release step first");
    this.ready = true;
  }

  check() {
    const indicator = this.indicators.check("instance");
    return this.ready ? indicator.up() : indicator.down({ reason: "starting" });
  }
}

@ApiExcludeController()
@Public()
@Controller("health")
export class HealthController {
  constructor(
    private readonly health: HealthCheckService,
    private readonly latch: ReadinessLatch,
  ) {}

  @Get("live")
  live() {
    return { status: "ok" };
  }

  @Get("ready")
  @HealthCheck()
  ready() {
    return this.health.check([() => this.latch.check()]);
  }
}
```
