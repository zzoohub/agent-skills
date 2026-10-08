# Transactions, Isolation and Locking

Mechanics for the enforcement ladder in SKILL.md Stage 2 (constraint → guarded statement → guard-row lock → SERIALIZABLE). Climb only as far as the invariant needs.

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
Zero rows means rejected (insufficient stock): a domain outcome, not a retry. Under Read Committed a blocked UPDATE re-checks its WHERE against the row as committed, so the guard holds without a stronger level. Optimistic concurrency is the same shape, `… WHERE id = $1 AND version = $2`, with the version on the aggregate root. Reading in the application and then writing is never a guard.

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

## Retry the whole transaction

On 40001 (serialization failure) and 40P01 (deadlock), re-run the transaction from `BEGIN`, re-reading state; never re-send only the failed statement. Bound the attempts and back off with jitter. Deadlocks occur at any level; frequent ones are a lock-ordering bug, not a tuning problem. A retry is safe only because the transaction made no external call.

## Keep transactions short and local

- **No network call inside a transaction**: it holds row locks and pins the xmin horizon for the call's duration, and idle-in-transaction sessions stall vacuum and queue DDL. External effects commit an intent row with a lease first and publish through the outbox (`references/design-patterns.md`, reliability tables).
- **Savepoints** (and PL/pgSQL `EXCEPTION` blocks) are subtransactions: keep them out of loops, because a transaction holding more than 64 slows visibility checks for every session, replicas included.
