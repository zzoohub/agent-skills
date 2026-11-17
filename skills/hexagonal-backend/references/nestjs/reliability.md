# NestJS examples: reliability

What a trigger calls for (`SKILL.md` § Size the change): the idempotency interceptor and its store, the outbox with its relay and the worker that runs it, and the inbox behind the webhook receiver. Every `file=` block is a complete file of the project in `slice.md`.

## Contents

1. [Tables](#tables)
2. [Idempotency](#idempotency)
3. [Outbox and relay](#outbox-and-relay)
4. [Webhook receiver and inbox](#webhook-receiver-and-inbox)

## Tables

Infrastructure tables carry no row-level security, because the relay and the purge work across tenants.

```ts file=src/migrations/1791417600001-reliability.ts
import type { MigrationInterface, QueryRunner } from "typeorm";

// The infrastructure tables carry no RLS: relays and the purge work across tenants, and no request path exposes them.
// uuidv7() needs PostgreSQL 18.
export class Reliability1791417600001 implements MigrationInterface {
  async up(db: QueryRunner): Promise<void> {
    await db.query(`
      CREATE TABLE app.outbox (
        id               uuid CONSTRAINT pk_outbox PRIMARY KEY DEFAULT uuidv7(),
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
        CONSTRAINT uq_outbox_aggregate_seq UNIQUE (aggregate_id, aggregate_seq)
      );
      CREATE INDEX idx_outbox_pending ON app.outbox (next_attempt_at, id)
        WHERE published_at IS NULL AND dead_lettered_at IS NULL;
      CREATE INDEX idx_outbox_dead_lettered_at ON app.outbox (dead_lettered_at) WHERE dead_lettered_at IS NOT NULL;

      CREATE TABLE app.idempotency_keys (
        scope        text NOT NULL,
        key          text NOT NULL,
        request_hash text NOT NULL,
        lease_token  uuid NOT NULL,
        locked_until timestamptz NOT NULL,
        status       integer,
        response     bytea,
        completed_at timestamptz,
        expires_at   timestamptz NOT NULL,
        CONSTRAINT pk_idempotency_keys PRIMARY KEY (scope, key)
      );
      CREATE INDEX idx_idempotency_keys_expires_at ON app.idempotency_keys (expires_at);

      CREATE TABLE app.inbox (
        consumer    text NOT NULL,
        message_id  text NOT NULL,
        received_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT pk_inbox PRIMARY KEY (consumer, message_id)
      );

      GRANT SELECT, INSERT, UPDATE ON app.outbox TO app_rw;
      GRANT SELECT, INSERT, UPDATE, DELETE ON app.idempotency_keys TO app_rw;
      GRANT SELECT, INSERT ON app.inbox TO app_rw;
    `);
  }

  async down(db: QueryRunner): Promise<void> {
    await db.query(`DROP TABLE app.inbox, app.idempotency_keys, app.outbox`);
  }
}
```

## Idempotency

The port separates acquiring a key, which commits on its own before the command runs, from completing it, which happens inside the command's transaction.

```ts file=src/domain/shared/idempotency.ts
export interface StoredResponse {
  readonly status: number;
  readonly headers: Readonly<Record<string, string>>;
  readonly body: unknown;
}

export type Acquired =
  | { readonly kind: "new"; readonly lease: string }
  | { readonly kind: "replay"; readonly response: StoredResponse }
  | { readonly kind: "mismatch" }
  | { readonly kind: "in_flight" };

/** Commits on its own, outside any unit of work: the key row must exist before the command runs. */
export abstract class IdempotencyStore {
  /** "new" only when this request's insert, or its takeover of an expired lease, won. */
  abstract acquire(scope: string, key: string, requestHash: string): Promise<Acquired>;
  abstract release(scope: string, key: string, lease: string): Promise<void>;
  abstract purgeExpired(): Promise<number>;
}

/** Inside the unit of work that holds the result; throws when the lease was taken over. */
export interface IdempotencyCompletion {
  complete(scope: string, key: string, lease: string, response: StoredResponse): Promise<void>;
}
```

One interceptor per route applies it, after the auth guard. It opens the unit of work around the handler, so the use case joins it and the stored response commits with the writes.

```ts file=src/inbound/http/idempotency.interceptor.ts
import { Injectable, type CallHandler, type ExecutionContext, type NestInterceptor } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import type { Request, Response } from "express";
import { createHash } from "node:crypto";
import { from, lastValueFrom, type Observable } from "rxjs";
import type { Env } from "../../config.js";
import { UnitOfWork } from "../../domain/publishing/ports.js";
import { IdempotencyStore } from "../../domain/shared/idempotency.js";
import type { Actor } from "../../domain/shared/ports.js";
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
    // Method, path with its query string, and the body with members sorted at every depth.
    const hash = createHash("sha256").update(`${req.method} ${req.originalUrl}\n${canonicalJson(req.body ?? null)}`).digest("hex");
    return from(this.execute(req.actor, scope, key, hash, req, res, next));
  }

  private async execute(actor: Actor, scope: string, key: string, hash: string, req: Request, res: Response, next: CallHandler) {
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
      // The use case joins this transaction, so the stored response commits with its writes.
      return await this.uow.run(actor, async (tx) => {
        const body: unknown = await lastValueFrom(next.handle(), { defaultValue: undefined });
        if (res.headersSent) throw new Error("the deadline answered first; not storing");
        const headers: Record<string, string> = { "content-type": "application/json; charset=utf-8" };
        for (const name of ["location", "etag"]) {
          const value = res.getHeader(name);
          if (typeof value === "string") headers[name] = value;
        }
        await tx.idempotency.complete(scope, key, lease, { status: res.statusCode, headers, body });
        return body;
      });
    } catch (error) {
      // The handler's writes rolled back. A 4xx is stored in a fresh transaction, so it replays; anything else frees the key.
      const problem = renderProblem(error, req, this.baseUri);
      const stored = problem.status < 500 &&
        (await this.uow.run(actor, (tx) => tx.idempotency.complete(scope, key, lease, problem)).then(() => true, () => false));
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

```ts file=src/outbound/postgres/idempotency.store.ts
import { Injectable } from "@nestjs/common";
import { DataSource, type EntityManager } from "typeorm";
import { DomainError } from "../../domain/shared/errors.js";
import {
  IdempotencyStore, type Acquired, type IdempotencyCompletion, type StoredResponse,
} from "../../domain/shared/idempotency.js";
import { translateDbError } from "./pg-errors.js";

// Longer than REQUEST_TIMEOUT_MS (<= 30 s) plus the tail of a handler Node cannot cancel.
const LEASE = "interval '60 seconds'";
// Longer than any client's retry horizon.
const TTL = "interval '24 hours'";

interface KeyRow { request_hash: string; completed_at: Date | null; status: number; response: Buffer }

const rethrow = (error: unknown): never => {
  throw translateDbError(error);
};

/** On the pool: each statement commits on its own, whatever unit of work the caller is in. */
@Injectable()
export class SqlIdempotencyStore extends IdempotencyStore {
  constructor(private readonly db: DataSource) {
    super();
  }

  async acquire(scope: string, key: string, requestHash: string): Promise<Acquired> {
    // Only this insert, or a takeover of an expired lease on the same request, grants execution.
    // The takeover extends expires_at, so the purge never deletes a live lease.
    const [won]: { lease: string }[] = await this.db
      .query(
        `INSERT INTO app.idempotency_keys AS k (scope, key, request_hash, lease_token, locked_until, expires_at)
         VALUES ($1, $2, $3, gen_random_uuid(), now() + ${LEASE}, now() + ${TTL})
         ON CONFLICT ON CONSTRAINT pk_idempotency_keys DO UPDATE
           SET lease_token = excluded.lease_token, locked_until = excluded.locked_until,
               expires_at = greatest(k.expires_at, excluded.expires_at)
           WHERE k.completed_at IS NULL AND k.locked_until < now() AND k.request_hash = excluded.request_hash
         RETURNING lease_token AS lease`,
        [scope, key, requestHash],
      )
      .catch(rethrow);
    if (won) return { kind: "new", lease: won.lease };
    const [row]: KeyRow[] = await this.db
      .query(`SELECT request_hash, completed_at, status, response FROM app.idempotency_keys WHERE scope = $1 AND key = $2`, [scope, key])
      .catch(rethrow);
    if (!row) return { kind: "in_flight" }; // released meanwhile: the retry wins
    if (row.request_hash !== requestHash) return { kind: "mismatch" };
    if (!row.completed_at) return { kind: "in_flight" };
    const stored: Omit<StoredResponse, "status"> = JSON.parse(row.response.toString("utf8"));
    return { kind: "replay", response: { status: row.status, ...stored } };
  }

  async release(scope: string, key: string, lease: string): Promise<void> {
    await this.db
      .query(`DELETE FROM app.idempotency_keys WHERE scope = $1 AND key = $2 AND lease_token = $3 AND completed_at IS NULL`, [scope, key, lease])
      .catch(rethrow);
  }

  async purgeExpired(): Promise<number> {
    const [, deleted]: [unknown[], number] = await this.db.query(`DELETE FROM app.idempotency_keys WHERE expires_at < now()`).catch(rethrow);
    return deleted;
  }
}

/** In the command's transaction: the stored response commits with the writes, under this request's live lease. */
export class SqlIdempotencyCompletion implements IdempotencyCompletion {
  constructor(private readonly em: EntityManager) {}

  async complete(scope: string, key: string, lease: string, response: StoredResponse): Promise<void> {
    const stored = Buffer.from(JSON.stringify({ headers: response.headers, body: response.body }));
    const [, completed]: [unknown[], number] = await this.em.query(
      `UPDATE app.idempotency_keys SET status = $4, response = $5, completed_at = now()
       WHERE scope = $1 AND key = $2 AND lease_token = $3 AND completed_at IS NULL`,
      [scope, key, lease, response.status, stored],
    );
    if (completed !== 1) {
      throw new DomainError("conflict", "the idempotency lease expired and was taken over", { code: "idempotency-in-flight" });
    }
  }
}
```

## Outbox and relay

`SqlOutbox` and `SqlInbox` run inside the unit of work. The relay runs on the bare pool, in the worker process.

```ts file=src/outbound/postgres/outbox-inbox.ts
import { context, propagation } from "@opentelemetry/api";
import type { EntityManager } from "typeorm";
import type { DomainEvent, Inbox, Outbox } from "../../domain/publishing/ports.js";

export class SqlOutbox implements Outbox {
  constructor(private readonly em: EntityManager) {}

  async append(e: DomainEvent): Promise<void> {
    const headers: Record<string, string> = { tenant_id: e.tenantId };
    propagation.inject(context.active(), headers); // traceparent, captured at insert and continued by the relay's publisher
    await this.em.query(
      `INSERT INTO app.outbox (tenant_id, aggregate_type, aggregate_id, aggregate_seq, event_type, event_version, payload, headers)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [e.tenantId, e.aggregateType, e.aggregateId, e.aggregateSeq, e.type, e.version, e.payload, headers],
    );
  }
}

export class SqlInbox implements Inbox {
  constructor(private readonly em: EntityManager) {}

  async claim(consumer: string, messageId: string): Promise<boolean> {
    const rows: unknown[] = await this.em.query(
      `INSERT INTO app.inbox (consumer, message_id) VALUES ($1, $2) ON CONFLICT DO NOTHING RETURNING 1`,
      [consumer, messageId],
    );
    return rows.length === 1;
  }
}
```

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

// The CTE is materialized, so the locking SELECT runs once and LIMIT holds. Only each aggregate's oldest
// pending row is claimable, and pushing next_attempt_at forward is the claim's lease.
const CLAIM = `
  WITH claimed AS MATERIALIZED (
    SELECT o.id FROM app.outbox o
    WHERE o.published_at IS NULL AND o.dead_lettered_at IS NULL AND o.next_attempt_at <= now()
      AND NOT EXISTS (SELECT 1 FROM app.outbox p WHERE p.aggregate_id = o.aggregate_id AND p.aggregate_seq < o.aggregate_seq
                        AND p.published_at IS NULL AND p.dead_lettered_at IS NULL)
    ORDER BY o.next_attempt_at, o.id LIMIT $1
    FOR UPDATE SKIP LOCKED)
  UPDATE app.outbox o SET attempts = o.attempts + 1, next_attempt_at = now() + $2 * interval '1 millisecond'
  FROM claimed WHERE o.id = claimed.id
  RETURNING o.id, o.tenant_id AS "tenantId", o.aggregate_id AS "aggregateId", o.aggregate_seq AS "aggregateSeq",
    o.event_type AS "type", o.event_version AS "version", o.payload, o.headers, o.attempts`;

@Injectable()
export class OutboxRelay {
  private readonly logger = new Logger(OutboxRelay.name);
  private readonly backlog = { oldestPendingSeconds: 0, deadLettered: 0 };

  constructor(
    private readonly db: DataSource,
    private readonly publisher: EventPublisher,
    private readonly options: RelayOptions,
  ) {
    const meter = metrics.getMeter("outbox");
    meter.createObservableGauge("outbox.oldest_pending.age", { unit: "s" })
      .addCallback((gauge) => gauge.observe(this.backlog.oldestPendingSeconds));
    meter.createObservableGauge("outbox.dead_lettered")
      .addCallback((gauge) => gauge.observe(this.backlog.deadLettered));
  }

  /** One pass. Every outcome is fenced on the claim's `attempts`, so a relay whose lease ran out cannot overwrite a newer claim. */
  async runOnce(stop?: AbortSignal): Promise<number> {
    const [claimed]: [OutboxMessage[], number] = await this.db.query(CLAIM, [this.options.batchSize, this.options.claimMs]);
    for (const message of claimed) {
      const fence = [message.id, message.attempts];
      if (stop?.aborted) {
        // Stopping: hand the claim back instead of letting its lease run out.
        await this.db.query(`UPDATE app.outbox SET attempts = attempts - 1, next_attempt_at = now() WHERE id = $1 AND attempts = $2`, fence);
        continue;
      }
      try {
        await this.publisher.publish(message); // outside any transaction
        await this.db.query(`UPDATE app.outbox SET published_at = now() WHERE id = $1 AND attempts = $2`, fence);
      } catch (error) {
        await this.recordFailure(message, error);
      }
    }
    const [backlog]: { age: number; dead: number }[] = await this.db.query(
      `SELECT coalesce(extract(epoch FROM now() - (SELECT min(created_at) FROM app.outbox
                WHERE published_at IS NULL AND dead_lettered_at IS NULL)), 0)::float8 AS age,
         (SELECT count(*) FROM app.outbox WHERE dead_lettered_at IS NOT NULL)::int AS dead`,
    );
    this.backlog.oldestPendingSeconds = backlog?.age ?? 0;
    this.backlog.deadLettered = backlog?.dead ?? 0;
    return claimed.length;
  }

  private async recordFailure(message: OutboxMessage, error: unknown): Promise<void> {
    const dead = message.attempts >= this.options.maxAttempts;
    const delayMs = Math.random() * Math.min(this.options.maxDelayMs, this.options.baseDelayMs * 2 ** message.attempts); // full jitter
    await this.db.query(
      `UPDATE app.outbox SET last_error = $3, next_attempt_at = now() + $4 * interval '1 millisecond',
         dead_lettered_at = CASE WHEN $5::boolean THEN now() END
       WHERE id = $1 AND attempts = $2`,
      [message.id, message.attempts, String(error).slice(0, 2_000), Math.round(delayMs), dead],
    );
    if (dead) this.logger.error({ outboxId: message.id, err: error }, "outbox event dead-lettered");
  }
}
```

The worker's module runs the relay and the key purge as loops, and stops claiming before the pool closes. Bind a real broker in place of the placeholder publisher.

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
      this.every(1_000, async () => (await this.relay.runOnce(this.stop.signal)) > 0), // busy: go again at once
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

## Webhook receiver and inbox

A guard verifies the signature over the raw bytes before the payload is validated. The inbox claim and the effect share one unit of work, scoped to the tenant the signed payload names.

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
import { Moderation } from "../../domain/publishing/use-cases.js";
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

  constructor(private readonly moderation: Moderation) {}

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
