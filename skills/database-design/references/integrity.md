# Integrity under concurrency and failure

Mechanics for the enforcement ladder in SKILL.md (constraint → guarded statement → guard-row lock → SERIALIZABLE), then the tables that keep writes correct across retries and crashes. Climb only as far as the invariant needs.

## What each isolation level lets through

| Level | Stops | Still lets through | You handle |
|---|---|---|---|
| Read Committed (default) | dirty reads | lost updates from read-in-app-then-write; write skew; a new snapshot per statement | nothing is raised: guard the write itself |
| Repeatable Read | lost updates on the same row (the later writer fails) | write skew across rows | 40001: retry |
| Serializable | every anomaly among serializable transactions | — | 40001, false positives included: retry |

Write skew is the one teams miss: two transactions check the same condition, then write different rows, so no row conflict fires below Serializable.

## Rung 2: one guarded statement

```sql
UPDATE stock SET qty = qty - $2 WHERE id = $1 AND qty >= $2 RETURNING qty;
```
Zero rows means rejected (insufficient stock): a domain outcome, not a retry. Under Read Committed a blocked UPDATE re-checks its WHERE against the row as committed, so the guard holds without a stronger level. Optimistic concurrency is the same shape, `… WHERE id = $1 AND version = $2`, with the version on the aggregate root. Reading in the application and then writing is never a guard: a check-then-insert written that way put 17 bookings into a 12-seat class in a 16-client test (`references/proof.md`).

## Rung 3: lock a guard row

When the decision reads several rows or inserts new ones (a slot's capacity, one active subscription per org), every writer first locks the same row:
```sql
BEGIN;
SELECT 1 FROM rooms WHERE id = $1 FOR NO KEY UPDATE;   -- every booking writer takes this first
SELECT count(*) FROM bookings WHERE room_id = $1 AND day = $2;
INSERT INTO bookings (room_id, day, guest_id) VALUES ($1, $2, $3);
COMMIT;
```
- **A bare lock guards only at Read Committed**, where the count takes a new snapshot after the lock wait and sees the previous writer's row. At Repeatable Read the snapshot predates the wait, so both writers insert. Make the guard a write, `UPDATE rooms SET version = version + 1 WHERE id = $1`, which holds at both levels (at Repeatable Read the later writer fails with 40001: record the level in database.md so the transaction runner retries it), or run the transaction at Read Committed.
- `FOR NO KEY UPDATE` unless you change the row's key: `FOR UPDATE` also blocks the FK check of every child insert that references the row.
- Several guard rows: lock them in one fixed order (`ORDER BY id`), or two writers deadlock (40P01).
- `NOWAIT` fails fast for interactive requests. `SKIP LOCKED` belongs to competing queue consumers, never to an invariant: skipping the row skips the check.
- No row to lock (the invariant concerns a key not yet inserted)? A scoped UNIQUE or EXCLUDE is rung 1. Otherwise take `pg_advisory_xact_lock(hashtextextended('booking:' || $1, 0))`, released at commit and, like any bare lock, a guard only at Read Committed; session-level advisory locks break under transaction pooling.

## Rung 4: SERIALIZABLE

`BEGIN ISOLATION LEVEL SERIALIZABLE;` for invariants no constraint or guard row can express.
- Every transaction that touches the invariant's rows must run SERIALIZABLE; a writer at a lower level reopens the hole.
- Index the predicates: a sequential scan takes a relation-level predicate lock and multiplies false-positive failures.
- Long read-only reports: `SERIALIZABLE READ ONLY DEFERRABLE` waits for a safe snapshot and is never cancelled for serialization.

## A sum or count held as a constraint

Rungs 2 to 4 are protocols: a writer that skips the guard breaks the invariant. When the invariant is a sum or a count against a limit (refunds never exceed what was paid, seats never exceed capacity), a trigger keeps the total on the parent row and a CHECK there makes it rung 1, for every writer:
```sql
CREATE TABLE orders (
    id             uuid DEFAULT uuidv7() PRIMARY KEY,
    paid_minor     bigint NOT NULL,
    refunded_minor bigint NOT NULL DEFAULT 0,
    CONSTRAINT chk_orders_refunds_within_paid CHECK (refunded_minor BETWEEN 0 AND paid_minor)
);
CREATE TABLE refunds (                              -- append-only: no UPDATE or DELETE grant
    id           uuid DEFAULT uuidv7() PRIMARY KEY,
    order_id     uuid NOT NULL REFERENCES orders (id),
    amount_minor bigint NOT NULL CONSTRAINT chk_refunds_amount CHECK (amount_minor > 0)
);
CREATE FUNCTION refunds_apply() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE orders SET refunded_minor = refunded_minor + NEW.amount_minor WHERE id = NEW.order_id;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_refunds_apply AFTER INSERT ON refunds
    FOR EACH ROW EXECUTE FUNCTION refunds_apply();
```
The trigger's UPDATE takes the order's row lock, so concurrent refunds of one order queue, and the CHECK rejects the one that would overshoot (SQLSTATE 23514) together with its insert. In a 16-client race against a limit of 100,000 the total stopped at 99,400. The total is a deliberate duplicate: its drift query is the sum of the child rows. It serializes writers per parent, which suits an order's refunds and not a counter every request touches (`references/query-patterns.md`, hot rows). Where a trigger is unwelcome, a function that is the only granted way to write gives the protocol its one door.

## Retry the whole transaction

On 40001 (serialization failure) and 40P01 (deadlock), re-run the transaction from `BEGIN`, re-reading state; never re-send only the failed statement. Bound the attempts and back off with jitter. Deadlocks occur at any level; frequent ones are a lock-ordering bug, not a tuning problem. A retry is safe only because the transaction made no external call.

## Keep transactions short and local

- **No network call inside a transaction**, a model call included: it holds row locks and pins the xmin horizon for the call's duration, and idle-in-transaction sessions stall vacuum and queue DDL. External effects commit an intent row with a lease first and publish through the outbox (below).
- **Savepoints** (and PL/pgSQL `EXCEPTION` blocks) are subtransactions: keep them out of loops, because a transaction holding more than 64 slows visibility checks for every session, replicas included.

## Reliability tables

Physical forms of software-architecture's reliability patterns, if that capability is in use: its logical fields are the contract; column names may follow the backend adapter (`locked_until` for `lease_expires`, `completed_at` set for `state = 'completed'`, one `scope` column for tenant + principal).

**Idempotency keys**
```sql
CREATE TABLE idempotency_keys (
    tenant_id      uuid        NOT NULL,
    principal_id   uuid        NOT NULL,
    key            text        NOT NULL,          -- client-chosen, one per intent
    request_hash   text        NOT NULL,
    state          text        NOT NULL DEFAULT 'in_flight'
                   CONSTRAINT chk_idempotency_keys_state CHECK (state IN ('in_flight', 'completed')),
    lease_token    uuid        NOT NULL DEFAULT gen_random_uuid(),   -- fencing: new on every acquire and takeover
    lease_expires  timestamptz NOT NULL,
    recovery_point text,                          -- last committed phase of an external side effect
    response       jsonb,                         -- status and body, replayed on repeat
    expires_at     timestamptz NOT NULL,          -- past the longest sender's retry horizon
    PRIMARY KEY (tenant_id, principal_id, key)
);
CREATE INDEX idx_idempotency_keys_expires_at ON idempotency_keys (expires_at);   -- batched purge
```
Acquire with `INSERT … ON CONFLICT DO NOTHING RETURNING lease_token`: only a returned row grants execution, under that token. Otherwise read the row: another `request_hash` → reject; `completed` → replay; a live lease → retryable conflict. Commit the in-flight row before any external call. Every later write (each recovery point as it commits, then the completion) adds `AND lease_token = $token AND state = 'in_flight'`; zero rows means the lease was taken over, so stop. Take over an expired lease conditionally under a new token, extending `expires_at` so the purge cannot delete a live row:
```sql
UPDATE idempotency_keys
SET lease_token = gen_random_uuid(), lease_expires = now() + $5,
    expires_at = greatest(expires_at, now() + $6)                -- $5 lease, $6 TTL
WHERE (tenant_id, principal_id, key) = ($1, $2, $3) AND request_hash = $4
  AND state = 'in_flight' AND lease_expires < now()
RETURNING lease_token, recovery_point;
```

**Outbox**
```sql
CREATE TABLE outbox (
    id               uuid        PRIMARY KEY DEFAULT uuidv7(),   -- debugging only, never order
    aggregate_type   text        NOT NULL,
    aggregate_id     uuid        NOT NULL,
    aggregate_seq    integer     NOT NULL,          -- per-aggregate order: the aggregate's new version
    event_type       text        NOT NULL,
    payload          jsonb       NOT NULL,
    headers          jsonb       NOT NULL DEFAULT '{}',
    created_at       timestamptz NOT NULL DEFAULT now(),
    published_at     timestamptz,                   -- NULL = pending
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),   -- backoff, and the relay's claim lease
    attempts         integer     NOT NULL DEFAULT 0,
    last_error       text,
    dead_lettered_at timestamptz,
    CONSTRAINT uq_outbox_aggregate_seq UNIQUE (aggregate_id, aggregate_seq)
);
CREATE INDEX idx_outbox_pending ON outbox (created_at)
    WHERE published_at IS NULL AND dead_lettered_at IS NULL;
CREATE INDEX idx_outbox_published_at ON outbox (published_at)   -- batched purge
    WHERE published_at IS NOT NULL;
```
Insert in the state change's transaction. The relay claims only each aggregate's oldest pending row (`NOT EXISTS` an earlier pending `aggregate_seq`) with `FOR UPDATE SKIP LOCKED`, pushes `next_attempt_at` forward as its lease, publishes outside the transaction, then marks the row published; a failing row holds back its aggregate until dead-lettered after N attempts. Alert on the age of the oldest pending row; purge published rows after the replay window.

**Inbox**: `PRIMARY KEY (consumer, message_id)` plus `received_at`, where `message_id` is the producer's event id (for a webhook, the provider's). In the handler's transaction, `INSERT … ON CONFLICT DO NOTHING RETURNING message_id`: no row means a duplicate, so skip the effect. Purge after the sender's redelivery horizon.

**Jobs**: `jobs (id, kind, payload, state, run_at, lease_token, lease_expires, attempts)` with a partial index `(run_at) WHERE state IN ('queued', 'running')`. Claim in a short transaction committed before the work starts:
```sql
WITH c AS MATERIALIZED (   -- runs once; an IN (subquery) may run again and claim more than $1 rows
    SELECT id FROM jobs
    WHERE run_at <= now()
      AND (state = 'queued' OR (state = 'running' AND lease_expires < now()))
    ORDER BY run_at LIMIT $1
    FOR UPDATE SKIP LOCKED)
UPDATE jobs j SET state = 'running', lease_token = gen_random_uuid(),
       lease_expires = now() + $2, attempts = j.attempts + 1
FROM c WHERE j.id = c.id
RETURNING j.id, j.lease_token, j.payload;
```
Complete with `UPDATE jobs SET state = 'done' WHERE id = $1 AND lease_token = $2`: zero rows means the lease expired and another worker owns the job. Jobs must be idempotent, since a lease can expire mid-run; dead-letter after N attempts. A queue lives on vacuum: per-table `autovacuum_vacuum_scale_factor = 0` with a fixed `autovacuum_vacuum_threshold`, finished rows purged, and no long transaction in the database, or dead rows at the head of the index slow every claim. Wake workers by polling: a transaction that issues `NOTIFY` commits under a global lock, so a notification per enqueue serializes the enqueuing commits (field reports put the ceiling at a few thousand writes per second).

**Change feeds** (sync, replay, polling consumers). Identity values, UUIDv7 and `now()` are assigned before commit, so a reader paging by `id > cursor` permanently skips a row whose transaction commits after a later row was read. Cursor on commit order instead:
- logical decoding (CDC), which emits changes in commit order;
- a commit horizon: `txid xid8 NOT NULL DEFAULT pg_current_xact_id()`, an index on `(txid, id)`, and reads of `WHERE (txid, id) > ($1, $2) AND txid < pg_snapshot_xmin(pg_current_snapshot()) ORDER BY txid, id`. Nothing commits below the oldest running transaction, so no row can appear behind the cursor; a long transaction delays the feed but loses nothing;
- a per-scope counter taken as the transaction's last statement (`UPDATE feed_heads SET seq = seq + 1 WHERE scope = $1 RETURNING seq`), which serializes that scope's writers.

Agent runs, tool calls, approvals and model budgets are these same shapes: `references/ai-data.md`.
