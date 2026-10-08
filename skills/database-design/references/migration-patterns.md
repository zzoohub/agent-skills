# PostgreSQL Migration Patterns

The single source for running schema and data changes against live traffic. Before writing any step, answer three questions: what lock it takes and for how long, whether both the deployed and the incoming code work after it, and how it is undone.

## Rules for every step

**N-1 compatibility replaces rollback scripts.** Every step works with both the deployed code and the code about to deploy, so an app rollback never needs a schema rollback. Schema and code ship separately: expand → code that handles both shapes → migrate data → code that uses only the new shape → contract.
- *Expand* steps (add a table, column, index, constraint) are reversible: ship the down (rollback) SQL with each, tested on masked or synthetic data, never a copy of production.
- *Contract* steps (drop, narrow, rewrite in place) are irreversible: run them after a verification window, with a recorded PITR target (timestamp or LSN) and an archive of exactly what they destroy (`\copy (SELECT id, legacy_col FROM t) TO 'legacy_col.csv' CSV`).
- *Break when* a maintenance window is acceptable (internal tool, pre-launch): one coordinated deploy is cheaper than four.

A full `pg_dump` is no safety net: it holds ACCESS SHARE on every table for its whole run, so your ACCESS EXCLUSIVE step queues behind it, and restoring it discards every later write.

**Contract steps wait for every consumer** (SKILL.md Stage 4): CDC/ETL sees a rename as drop + add, so the warehouse column vanishes.

**The lock queue is the outage.** Even metadata-only DDL needs a brief ACCESS EXCLUSIVE lock. While a long transaction holds any lock on the table, the DDL waits, and every later query on the table, reads included, queues behind it. Guard each step by type:
- **Strong-lock DDL** (ACCESS EXCLUSIVE, SHARE ROW EXCLUSIVE): `lock_timeout` = the stall the table's hottest query can absorb, usually 100 ms–1 s on OLTP; retry 10–30 times with jittered backoff on SQLSTATE `55P03`; if retries keep failing, find the blocker (`scripts/query_diagnostics.sql` §2–3). A `statement_timeout` of a few seconds catches a "metadata-only" step that is really a rewrite.
- **`CONCURRENTLY`** (index builds, `REINDEX`, `DROP INDEX`, `DETACH PARTITION`) and **`VALIDATE`** block no DML: `statement_timeout = 0`, watch progress (§7). `CONCURRENTLY` also needs `lock_timeout = 0`: its waits for every older transaction are lock waits, and a cancel leaves an INVALID index or a partition pending detach (finish it with `DETACH PARTITION … FINALIZE`).
- **Backfills**: bound each batch, not the session: a `statement_timeout` covers a whole `CALL`, COMMITs inside included.

**One DDL step per transaction.** A multi-step `BEGIN…COMMIT` holds every lock until the final COMMIT, so a later step's wait keeps the earlier ACCESS EXCLUSIVE locks, and the traffic queued behind them, in place. The exception is an atomic swap of metadata-only statements (worked example).

**Connection and tool.** Run migrations over a direct or session-pooled connection: under transaction pooling, `SET lock_timeout` and the runner's session advisory lock land on another server connection than the DDL (fallback: `SET LOCAL` per step, or `ALTER ROLE migrator SET lock_timeout = '1s'`, which a session running `CONCURRENTLY` resets to 0). Then find the runner's transaction scope. Most tools wrap each file in a transaction: put `CONCURRENTLY` and COMMIT-per-batch backfills in a file marked with the tool's no-transaction switch, or run them outside the tool, and say which. A runner holding one transaction across all pending files keeps every lock until the run ends, so each strong-lock step ships as its own run; a multi-statement file sent as one query string runs as one implicit transaction, so it carries one strong-lock step. Neither accepts `CONCURRENTLY`. A generated migration is a draft: read the SQL the ORM emits and label each statement, since generators write plain `CREATE INDEX`, validating FKs and rewriting type changes.

**RLS-forced tables filter their owner too**: with no tenant set, a backfill updates nothing and a verify query finds no mismatches. Run data steps (backfill, verify, archive, purge) as the `BYPASSRLS` maintenance role (`references/design-patterns.md` §6) after `SET row_security = off`, so a policy that still applies raises an error instead of matching zero rows; or set the tenant per batch.

## Lock and work per statement

Label every statement before it ships. AE = ACCESS EXCLUSIVE (blocks everything), SRE = SHARE ROW EXCLUSIVE (blocks writes), SUE = SHARE UPDATE EXCLUSIVE (reads and writes continue).

| Statement | Lock | Work | Online path |
|---|---|---|---|
| ADD COLUMN, nullable or non-volatile default (`now()` included) | AE, brief | metadata; existing rows read the default as evaluated at ALTER time | as is |
| ADD COLUMN with volatile default (`uuidv7()`, `clock_timestamp()`), identity, STORED generated, or (before PG19) constrained domain | AE | rewrite | nullable plain column → backfill → constraint |
| ALTER COLUMN TYPE | AE | rewrite + index rebuild, unless binary-coercible: `varchar(n)` → `text`/longer, `numeric` precision up at same scale, `timestamp` → `timestamptz` with session `TimeZone` UTC | new column + sync |
| SET NOT NULL | AE | scan, skipped when a valid `CHECK (col IS NOT NULL)` exists | CHECK `NOT VALID` → `VALIDATE` → SET NOT NULL; PG18+ `NOT NULL … NOT VALID` |
| ADD CHECK | AE | scan | `NOT VALID` → `VALIDATE` |
| ADD FOREIGN KEY | SRE on both tables | scan of child | `NOT VALID` → `VALIDATE` |
| VALIDATE CONSTRAINT | SUE (FK: + ROW SHARE on parent) | scan | — |
| CREATE INDEX | SHARE (blocks writes) | build | `CONCURRENTLY` |
| ADD PRIMARY KEY / UNIQUE | AE | build (+ NOT NULL scan for a PK) | unique index `CONCURRENTLY` → `ADD CONSTRAINT … USING INDEX` |
| DROP INDEX | AE | — | `CONCURRENTLY` |
| DROP CONSTRAINT (FK) | AE on both tables | — | brief, under `lock_timeout` |
| CREATE TRIGGER | SRE | — | brief, under `lock_timeout` |
| RENAME, DROP COLUMN, SET DEFAULT | AE, brief | metadata | expand-contract for renames, drops |
| ATTACH PARTITION | SUE on parent, AE on attached table | scan, skipped by a matching valid CHECK | add that CHECK first |
| VACUUM FULL, CLUSTER | AE | rewrite | pg_repack, or PG19+ `REPACK CONCURRENTLY` where available |

AE locks replay on physical standbys, cancelling conflicting queries or stalling replay.

**Runbook.** Deliver a migration as one row per step: statement | lock | work (metadata, scan, rewrite, build) | duration | guard (`lock_timeout`, `statement_timeout`, batch size) | verify | abort trigger. Time each scan, rewrite, build and backfill on a masked production-sized copy, or on a seed of at least 10% of the rows scaled up (an estimate: index builds scale worse than linearly); a step with neither a measured nor an estimated duration is not ready. Add at most 150 words of notes: the deploy order, the PITR target, what is irreversible.

## Pre-flight

Before a strong-lock step or a `CONCURRENTLY` build on a busy table (`scripts/query_diagnostics.sql`):
- no long or idle-in-transaction session holds a lock on the table: `SELECT l.pid, a.state, a.xact_start FROM pg_locks l JOIN pg_stat_activity a USING (pid) WHERE l.relation = 'orders'::regclass;` (and §3);
- for `CONCURRENTLY`, no old snapshot anywhere (§4): the build waits for every transaction whose snapshot predates its second scan, on any table, so one forgotten analytics session stalls it for hours;
- no anti-wraparound autovacuum on the table (§7): it does not yield its lock;
- free disk for a rewrite or build (the table and its indexes again, plus WAL);
- replica lag within budget (§8).

## Recipes

Each numbered step is its own migration or deploy, run under the guards above.

### Add a column
One statement, even with NOT NULL and a constant default (`ADD COLUMN is_verified boolean NOT NULL DEFAULT false`). Never invent a sentinel such as `'unknown'` to satisfy NOT NULL: add the column nullable, backfill real values, then make it NOT NULL. Down: `DROP COLUMN`.

### Make an existing column NOT NULL
1. Deploy code that sets the column on every insert and update: after step 2, any writer that updates an old row without setting it fails.
2. `ALTER TABLE t ADD CONSTRAINT t_col_nn CHECK (col IS NOT NULL) NOT VALID;` (new NULLs rejected)
3. Backfill existing NULLs (Large Table Migrations).
4. `ALTER TABLE t VALIDATE CONSTRAINT t_col_nn;`
5. `ALTER TABLE t ALTER COLUMN col SET NOT NULL;` (no scan), then `DROP CONSTRAINT t_col_nn`.

PG18+: `ADD CONSTRAINT t_col_nn NOT NULL col NOT VALID` → `VALIDATE CONSTRAINT` replaces steps 2, 4 and 5; until it is validated, `information_schema` already reports the column non-nullable, which misleads ORMs and code generators. Down: `DROP NOT NULL`, `DROP CONSTRAINT IF EXISTS t_col_nn`.

### Add an index, unique constraint or primary key
```sql
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);  -- outside any transaction block
SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;    -- must return no rows
```
A failed or cancelled build leaves an INVALID index that queries ignore but every write maintains (a UNIQUE build that fails in its second scan also keeps enforcing uniqueness). `DROP INDEX CONCURRENTLY` it and rebuild; never retry with `IF NOT EXISTS`, which checks only the name and keeps the invalid index. Rebuild bloat with `REINDEX INDEX CONCURRENTLY`. Down: `DROP INDEX CONCURRENTLY`.

A constraint attaches to a prebuilt index: `CREATE UNIQUE INDEX CONCURRENTLY t_x_key ON t (x);` → `ALTER TABLE t ADD CONSTRAINT t_x_key UNIQUE USING INDEX t_x_key;` (AE, brief). For a primary key, make the columns NOT NULL first, or `ADD PRIMARY KEY USING INDEX` scans under AE.

Partitioned tables refuse `CONCURRENTLY` on the parent:
```sql
CREATE INDEX idx_events_k ON ONLY events (k);                          -- invalid for now
CREATE INDEX CONCURRENTLY idx_events_2026_10_k ON events_2026_10 (k);  -- each partition
ALTER INDEX idx_events_k ATTACH PARTITION idx_events_2026_10_k;        -- valid once all are attached
```

### Add a foreign key
```sql
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);  -- child side; never automatic
ALTER TABLE orders ADD CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users (id) NOT VALID;         -- SRE on both, brief
ALTER TABLE orders VALIDATE CONSTRAINT fk_orders_user;             -- SUE; DML continues
```
Down: `DROP CONSTRAINT fk_orders_user` (AE on both tables, brief).

### Change a column's type
Binary-coercible (lock table): one metadata-only statement. Otherwise:
1. **Expand**: `ALTER TABLE products ADD COLUMN price_cents bigint;`
2. **Sync** before any backfill, or rows updated during it drift. A trigger stays right whichever code version writes:
   ```sql
   CREATE FUNCTION products_sync_price() RETURNS trigger LANGUAGE plpgsql AS $$
   BEGIN NEW.price_cents := round(NEW.price * 100); RETURN NEW; END $$;
   CREATE TRIGGER products_sync_price BEFORE INSERT OR UPDATE ON products
       FOR EACH ROW EXECUTE FUNCTION products_sync_price();
   ```
3. **Backfill** in batches, rechecking `price_cents IS DISTINCT FROM round(price * 100)`.
4. **Verify**: `SELECT count(*) FROM products WHERE price_cents IS DISTINCT FROM round(price * 100);` = 0.
5. **Switch reads**: deploy code that reads the new column and writes both.
6. **Stop old writes**: drop the trigger, drop NOT NULL on the old column, then deploy code that writes only the new one.
7. **Contract** after the verification window: drop the old column.

Keep the new name: a closing `RENAME` breaks every reader switched in step 5 (map the name in the ORM if it matters). Down until step 6: drop the trigger, function and new column.

### Rename a column or table
First ask whether a rename is worth four deploys; an ORM mapping costs nothing. A column rename is the type-change recipe without the cast. A table renames in one transaction with a view under the old name: `ALTER TABLE old RENAME TO new; CREATE VIEW old WITH (security_invoker = true) AS SELECT * FROM new;` (PG15+). The simple view is updatable, so old code keeps working; `security_invoker` keeps RLS applying to the caller.

### Drop a column or table
- **Column**: deploy code that neither reads nor writes it (ORMs select every mapped column: unmap it), archive it, record the PITR target, then `DROP COLUMN`. Prepared `SELECT *` statements then fail until the pools reconnect (`references/postgresql/production-ops.md`, Pooling).
- **Table**: evidence first: no scans on the primary or any replica over a business cycle (`seq_scan`/`idx_scan` deltas), no dependents (`pg_depend`), no publication (`pg_publication_tables`). Archive, then `DROP TABLE` without `CASCADE`, which silently drops dependent views and FKs.

### Replace a table (strangler)
New table → sync writes (trigger or dual-write) → keyset backfill → verify counts and checksums → switch reads → stop old writes → re-point every referencing FK (`ADD … NOT VALID` → `VALIDATE`, then drop the old FK) → after the verification window, drop the old table without `CASCADE`. Keep the new name or put a view under the old one.

## Large Table Migrations

Batch every data change on a table with millions of rows. A single full-table `UPDATE` is one long transaction: it locks every row it touches, pins the xmin horizon so VACUUM cleans nothing, and bloats the table and the WAL.

**Commit per batch, outside any wrapping transaction.** A `PROCEDURE` run with `CALL`, or a top-level `DO` block, may `COMMIT` between batches only outside a transaction block: under `BEGIN…COMMIT`, `psql -1` or a tool that wraps each file, the `COMMIT` raises `invalid transaction termination`, as it does inside a PL/pgSQL block with an `EXCEPTION` clause. A job running each batch in its own transaction is the alternative, and the better one when you need a per-batch timeout. Either way the backfill is its own script, not part of the transactional migration file.

**Every backfill is:**
- **keyset-walked** by primary key: never `OFFSET`, and never re-scanning `WHERE new_col IS NULL`, which re-reads the processed, now dead, pages every batch (quadratic on a big table);
- **idempotent**: the `UPDATE` rechecks its own condition, so a re-run or overlap is a no-op;
- **resumable**: it commits the last key with each batch and restarts from it;
- **bounded**: each batch commits in well under a second (start at 1–5k rows; adjust to measured time);
- **throttled**: it pauses between batches, longer when `pg_stat_replication.replay_lag` grows; a backfill is a WAL storm, and lagging replicas break read-after-write traffic.

**No `FOR UPDATE`, no `SKIP LOCKED`** in the batch select: the `UPDATE` takes its own row locks, and the recheck makes a concurrently modified row safe. `SKIP LOCKED` is for competing queue workers: in a backfill it silently skips locked rows, and an "exit when 0 rows" loop can finish with rows unprocessed.

```sql
-- Keyset backfill as a PROCEDURE, because it COMMITs per batch; the cursor commits with each batch.
CREATE TABLE backfill_progress (job text PRIMARY KEY, last_key uuid NOT NULL);
INSERT INTO backfill_progress VALUES ('full_name', '00000000-0000-0000-0000-000000000000');

CREATE PROCEDURE backfill_full_name()
LANGUAGE plpgsql AS $$
DECLARE
    batch_size int := 5000;
    cur uuid := (SELECT last_key FROM backfill_progress WHERE job = 'full_name');
BEGIN
    LOOP
        WITH batch AS (
            SELECT id FROM user_accounts
            WHERE id > cur
            ORDER BY id
            LIMIT batch_size
        ), updated AS (
            UPDATE user_accounts u
            SET full_name = u.name
            FROM batch
            WHERE u.id = batch.id AND u.full_name IS NULL   -- idempotent recheck
        )
        -- No max(uuid) aggregate exists: take the cursor from the ordered batch.
        SELECT (SELECT id FROM batch ORDER BY id DESC LIMIT 1) INTO cur;
        EXIT WHEN cur IS NULL;
        UPDATE backfill_progress SET last_key = cur WHERE job = 'full_name';
        COMMIT;   -- legal only because the CALL runs outside any transaction block
        PERFORM pg_sleep(0.1);
    END LOOP;
END $$;

SET statement_timeout = 0;    -- it would cover the whole CALL
SET lock_timeout = '1s';      -- a batch blocked by an app transaction fails fast
CALL backfill_full_name();    -- psql without -1; after any failure, CALL again to resume
DROP PROCEDURE backfill_full_name(); DROP TABLE backfill_progress;
```

From application code, run the same batch statement in a loop, one transaction per batch with its own `statement_timeout`, committing the last key with the batch; stop when a batch returns no rows. Finish every backfill with `ANALYZE`.

## Verify and finish

After each step, before the next: no invalid index (query above); no unvalidated constraint (`SELECT conrelid::regclass, conname FROM pg_constraint WHERE NOT convalidated`); `ANALYZE` the touched tables and `EXPLAIN` their hot queries; error rates, lock waits and replica lag steady; the previous code still deployable until the contract step; `COMMENT ON` updated.

## Worked example: int4 key to bigint

An `integer` key fed by a sequence stops at 2,147,483,647 (`scripts/schema_review.sql` §4 shows the headroom). `ALTER COLUMN id TYPE bigint` rewrites the table and every index under AE; this path never rewrites.
1. Expand and sync: `ALTER TABLE orders ADD COLUMN id_new bigint;` plus a `BEFORE INSERT OR UPDATE` trigger `orders_sync_id` setting `NEW.id_new := NEW.id`.
2. Keyset backfill `id_new = id`; verify no `id_new IS NULL` remains.
3. `CREATE UNIQUE INDEX CONCURRENTLY orders_id_new_key ON orders (id_new);`
4. `ADD CONSTRAINT orders_id_new_nn CHECK (id_new IS NOT NULL) NOT VALID`, then `VALIDATE` it.
5. Swap in one short metadata-only transaction under `lock_timeout` (AE on `orders` and each child whose FK it drops):
```sql
BEGIN;
ALTER TABLE order_items DROP CONSTRAINT order_items_order_id_fkey;  -- every referencing FK
ALTER TABLE orders DROP CONSTRAINT orders_pkey;
ALTER TABLE orders ALTER COLUMN id_new SET NOT NULL;                -- no scan: the CHECK proves it
ALTER TABLE orders ADD CONSTRAINT orders_pkey PRIMARY KEY USING INDEX orders_id_new_key;
ALTER TABLE orders DROP CONSTRAINT orders_id_new_nn;
ALTER TABLE orders ALTER COLUMN id DROP DEFAULT, ALTER COLUMN id DROP NOT NULL;
ALTER SEQUENCE orders_id_seq AS bigint OWNED BY orders.id_new;      -- an int4 sequence stops at 2^31-1
ALTER TABLE orders ALTER COLUMN id_new SET DEFAULT nextval('orders_id_seq');
DROP TRIGGER orders_sync_id ON orders;
ALTER TABLE orders RENAME COLUMN id TO id_old;
ALTER TABLE orders RENAME COLUMN id_new TO id;
ALTER TABLE order_items ADD CONSTRAINT order_items_order_id_fkey
    FOREIGN KEY (order_id) REFERENCES orders (id) NOT VALID;
COMMIT;
```
6. `VALIDATE` each re-added FK, reconnect the pools, and drop `id_old` after the verification window.

For an identity key, replace the sequence lines with `DROP IDENTITY` on the old column, `ADD GENERATED BY DEFAULT AS IDENTITY` on the new one, and `setval()` to the current maximum. Done means two more things: every child FK column is widened the same way before the sequence passes 2^31-1, or child inserts fail (`schema_review.sql` §4 lists them); and every client driver reads int8 correctly (some return strings; JavaScript numbers lose precision above 2^53).
