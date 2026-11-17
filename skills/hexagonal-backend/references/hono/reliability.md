# Hono examples: reliability

What a trigger calls for (`SKILL.md` § Size the change): the idempotency wrapper and its store, the outbox with its relay and publisher, and the inbox behind the webhook receiver. Every `file=` block is a complete file of the project in `slice.md`.

## Contents

1. [Tables](#tables)
2. [Idempotency](#idempotency)
3. [Outbox and relay](#outbox-and-relay)
4. [Webhook receiver and inbox](#webhook-receiver-and-inbox)

## Tables

Infrastructure tables carry no row-level security: the relay and the purge work across tenants.

```sql file=migrations/0001_reliability.sql
-- Infrastructure tables. No row-level security: the relay and the purge work across tenants,
-- and no request path reads them by tenant.
CREATE TABLE app.outbox (
  id uuid NOT NULL DEFAULT uuidv7(),
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
  CONSTRAINT pk_outbox PRIMARY KEY (id),
  CONSTRAINT uq_outbox_aggregate_seq UNIQUE (aggregate_id, aggregate_seq)
);
CREATE INDEX idx_outbox_pending ON app.outbox (created_at) WHERE published_at IS NULL AND dead_lettered_at IS NULL;
CREATE INDEX idx_outbox_dead_letter ON app.outbox (dead_lettered_at) WHERE dead_lettered_at IS NOT NULL;

CREATE TABLE app.idempotency_keys (
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
  CONSTRAINT pk_idempotency_keys PRIMARY KEY (scope, key)
);
CREATE INDEX idx_idempotency_keys_expires_at ON app.idempotency_keys (expires_at);

CREATE TABLE app.inbox (
  consumer text NOT NULL,
  message_id text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_inbox PRIMARY KEY (consumer, message_id)
);

GRANT SELECT, INSERT, UPDATE ON app.outbox TO app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.idempotency_keys TO app_rw;
GRANT SELECT, INSERT ON app.inbox TO app_rw;
```

## Idempotency

The port separates acquiring a key, which happens before any transaction, from completing it, which happens inside the use case's transaction.

```ts file=src/domain/shared/idempotency.ts
export type StoredResponse = Readonly<{ status: number; headers: Record<string, string>; body: Uint8Array }>;

export type Acquired =
  | Readonly<{ kind: "execute"; lease: string }>
  | Readonly<{ kind: "replay"; response: StoredResponse }>
  | Readonly<{ kind: "mismatch" }>
  | Readonly<{ kind: "in_flight" }>;

export interface IdempotencyStore {
  /** "execute" only when this request's INSERT, or its takeover of an expired lease, won. */
  acquire(scope: string, key: string, requestHash: string): Promise<Acquired>;
  release(scope: string, key: string, lease: string): Promise<void>;
  purgeExpired(): Promise<number>;
}

/** Runs in the use case's transaction; throws LeaseLostError when another request took the lease over. */
export interface IdempotencyCompletion {
  complete(scope: string, key: string, lease: string, response: StoredResponse): Promise<void>;
}

export class LeaseLostError extends Error {
  override readonly name = "LeaseLostError";
}
```

One middleware per route applies it, after authentication. It opens the unit of work around `next()`, so the use case joins it and the stored response commits with the writes.

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
    await services.uow.run(actor, async (tx) => {
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
    if (storable(c.res.status)) await services.uow.run(actor, async (tx) => tx.idempotency.complete(scope, key, lease, await snapshot(c.res))).catch(release);
    else await release();
  }
});
```

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
      // Reading the row grants nothing: only this conditional takeover of an expired lease does.
      // It extends expires_at, so the purge cannot delete a key that is running again.
      const [took] = await this.#db
        .update(keys)
        .set({ leaseToken: crypto.randomUUID(), lockedUntil: this.#lease, expiresAt: sql`greatest(${keys.expiresAt}, ${this.#ttl})` })
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

## Outbox and relay

```ts file=src/domain/shared/events.ts
export type DomainEvent = Readonly<{
  type: string;
  version: number;
  tenantId: string;
  aggregateType: string;
  aggregateId: string;
  /** The aggregate's new version: the order of its events. */
  aggregateSeq: number;
  payload: Record<string, unknown>;
}>;

/** Written in the transaction that changes the aggregate. */
export interface Outbox {
  append(event: DomainEvent): Promise<void>;
}

export interface Inbox {
  /** false: the message was already processed. */
  claim(consumer: string, messageId: string): Promise<boolean>;
}

export type OutboxMessage = DomainEvent & Readonly<{ id: string; headers: Record<string, string> }>;

/** The relay's way out; called outside any transaction. */
export interface EventPublisher {
  publish(message: OutboxMessage): Promise<void>;
}
```

`pgOutbox` and `pgInbox` run inside the unit of work. The relay runs on the bare pool, in its own process (`src/app/relay.ts` in `service.md`).

```ts file=src/outbound/postgres/outbox.ts
import { context, propagation } from "@opentelemetry/api";
import { and, eq, sql } from "drizzle-orm";
import type { EventPublisher, Inbox, Outbox, OutboxMessage } from "../../domain/shared/events.ts";
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

  /**
   * One pass. The claim is a materialized CTE, which runs once; `id IN (SELECT … LIMIT n FOR UPDATE SKIP LOCKED)`
   * may be evaluated again per row and claim more than n. Only the head of each aggregate is claimable, and
   * `next_attempt_at` moved forward is the lease, so publishing runs outside any transaction.
   */
  async runOnce(stop?: AbortSignal): Promise<number> {
    const { batchSize, leaseSeconds, maxAttempts, backoffBaseMs, backoffCapMs } = this.#opts;
    const { rows } = await this.#db.execute<OutboxMessage & { attempts: number }>(sql`
      WITH head AS MATERIALIZED (
        SELECT o.id FROM app.outbox o
        WHERE o.published_at IS NULL AND o.dead_lettered_at IS NULL AND o.next_attempt_at <= now()
          AND NOT EXISTS (
            SELECT 1 FROM app.outbox e
            WHERE e.aggregate_id = o.aggregate_id AND e.aggregate_seq < o.aggregate_seq
              AND e.published_at IS NULL AND e.dead_lettered_at IS NULL)
        ORDER BY o.created_at LIMIT ${batchSize}
        FOR UPDATE SKIP LOCKED)
      UPDATE app.outbox o SET attempts = o.attempts + 1, next_attempt_at = now() + make_interval(secs => ${leaseSeconds})
      FROM head WHERE o.id = head.id
      RETURNING o.id, o.event_type AS type, o.event_version AS version, o.tenant_id AS "tenantId", o.aggregate_type AS "aggregateType",
        o.aggregate_id AS "aggregateId", o.aggregate_seq AS "aggregateSeq", o.payload, o.headers, o.attempts`);
    for (const row of rows) {
      // Outcomes are fenced on the claim's `attempts`: a relay whose lease ran out cannot overwrite a newer claim.
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
        const delay = (Math.random() * Math.min(backoffCapMs, backoffBaseMs * 2 ** row.attempts)) / 1000; // full jitter
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
      SELECT extract(epoch FROM now() - (SELECT min(created_at) FROM app.outbox
          WHERE published_at IS NULL AND dead_lettered_at IS NULL))::float8 AS age,
        (SELECT count(*) FROM app.outbox WHERE dead_lettered_at IS NOT NULL)::int AS dead`);
    return { oldestPendingSeconds: rows[0]?.age ?? 0, deadLettered: rows[0]?.dead ?? 0 };
  }
}
```

```ts file=src/outbound/publisher.ts
import { context, propagation, ROOT_CONTEXT } from "@opentelemetry/api";
import type { EventPublisher, OutboxMessage } from "../domain/shared/events.ts";

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

## Webhook receiver and inbox

The signature is verified over the raw bytes before anything is parsed. The inbox claim and the effect share one unit of work, scoped to the tenant the signed payload names.

```ts file=src/inbound/webhooks/moderation.ts
import { createHmac, timingSafeEqual } from "node:crypto";
import { Hono } from "hono";
import { z } from "zod";
import { DomainError } from "../../domain/shared/errors.ts";
import { systemActor } from "../../domain/shared/ports.ts";
import type { AppEnv, Services } from "../http/env.ts";
import { ProblemError } from "../http/problem.ts";

const PERMANENT = new Set<string>(["not_found", "invalid_transition"]);
/** z.object, not strictObject: the sender may add fields. */
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

/** The inbox claim and the effect commit together; the signed payload names the tenant the unit of work is scoped to. */
function apply({ uow, publishing }: Services, messageId: string, message: z.infer<typeof Verdict>): Promise<string> {
  const actor = systemActor(message.tenant_id, "moderation");
  return uow.run(actor, async (tx) => {
    if (!(await tx.inbox.claim("moderation", messageId))) return "duplicate";
    if (message.verdict === "approved") return "approved";
    try {
      await publishing.archive(actor, message.article_id);
      return "archived";
    } catch (err) {
      if (err instanceof DomainError && PERMANENT.has(err.code)) return err.code; // a permanent outcome: recorded and acked, never retried
      throw err;
    }
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
    if (message.success) {
      c.var.log.info({ webhook_id: h.id, outcome: await apply(c.var.services, h.id, message.data) }, "moderation webhook");
    } else {
      // Signed but unreadable is permanent: a 4xx would be retried until the sender disables the endpoint.
      c.var.log.warn({ webhook_id: h.id, outcome: "invalid_payload" }, "moderation webhook");
    }
    return c.body(null, 204);
  });
  return app;
}
```
