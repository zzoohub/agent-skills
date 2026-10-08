# PostgreSQL Performance Patterns

Physical layout at scale: row size, partitioning, scale-out and read replicas. Query tuning: `references/postgresql/query-tuning.md`; vacuum, pooling and settings: `references/postgresql/production-ops.md`.

## 1. Row size and column order

Measure bytes per row on representative rows (`scripts/schema_review.sql` §10, after ANALYZE) rather than computing it: tuple headers, alignment padding and TOAST (past about 2 kB per row) defeat the arithmetic. Column order matters only for narrow tables past roughly 100M rows: fixed-width 8-byte types first, then 4, 2 and 1 byte, then variable-length types.

## 2. Partitioning

**Who decides.** A key that shapes the system (throughput, ordering, retention, a tenant or residency boundary) comes from the architecture doc (default `docs/arch/system.md` §3 Partitioning); method, interval and layout are this file's.

**When.** Partition when a query predicate or a lifecycle operation uses the key: retention as a partition drop instead of a mass DELETE, pruning hot queries down to a few partitions, or vacuum and index maintenance that no longer fit in one table (the documentation's rule of thumb: the table outgrows the server's memory). Not on row count alone, and not to scale writes: every partition lives on the same primary, and each one adds planning and locking overhead.

**Costs to accept up front.**
- Every PRIMARY KEY and UNIQUE constraint must include the partition key, so a global `UNIQUE (email)` cannot be enforced across partitions; enforce it in another table or do not partition this one.
- Foreign keys that reference the partitioned table must carry the key too.
- Queries without a predicate on the key scan every partition; runtime pruning helps only with parameters and join keys.
- `ON CONFLICT` targets must include the key, and index builds go partition by partition (`references/migration-patterns.md`).

**Interval = the retention drop unit.** 90-day retention → daily or weekly partitions; 13 months → monthly. Aim for hot queries that touch 1–3 partitions and a total in the hundreds: the planner handles up to a few thousand partitions when pruning leaves few, but more is not better by default.

**Method.** RANGE on time is the default for events, logs and ledgers. LIST fits a few known values with different lifecycles (region, tenant tier). HASH only spreads a hot key or vacuum load: it cannot prune ranges or drop old data.

```sql
CREATE TABLE access_logs (
    id bigint GENERATED ALWAYS AS IDENTITY,
    created_at timestamptz NOT NULL,
    url text NOT NULL,
    status_code smallint NOT NULL,
    PRIMARY KEY (id, created_at)          -- the partition key must be part of it
) PARTITION BY RANGE (created_at);
CREATE TABLE access_logs_2026_10 PARTITION OF access_logs
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
```

Create partitions ahead of time (pg_partman's premake, or a scheduled job) and alert when the next one is missing. A DEFAULT partition catches stray rows but makes every later ATTACH scan it and forbids `DETACH … CONCURRENTLY`; pg_partman creates one unless told not to (`p_default_table := false`).

**Retention is a partition drop:**
```sql
ALTER TABLE access_logs DETACH PARTITION access_logs_2026_07 CONCURRENTLY;  -- no transaction block; lock_timeout 0
-- interrupted? ALTER TABLE access_logs DETACH PARTITION access_logs_2026_07 FINALIZE;
\copy access_logs_2026_07 TO 'access_logs_2026_07.csv' CSV                  -- archive, if retention requires it
DROP TABLE access_logs_2026_07;
```
pg_partman automates creation and retention (`retention`, `retention_keep_table`).

## 3. When one primary runs out

Partitioning scales table management and replicas scale reads; neither scales writes past one primary. Signals: write saturation after query and vacuum tuning, a working set larger than one machine, per-tenant blast-radius requirements. The way out (a sharding layer such as Citus, application-level sharding, or a PostgreSQL-compatible distributed database whose isolation, transaction limits and PL/pgSQL support differ) is a system-level decision (`system.md`), and most products never need one. The schema's job is to **not foreclose it**: every unique constraint carries the prospective distribution key (usually `tenant_id`) now, and primary keys do too once sharding is on the Scaling Ladder (`system.md` §4).

## 4. Read replicas

Replicas scale reads and add lag.
- Route read-after-write flows ("show what I just saved") to the primary; send only lag-tolerant reads (dashboards, search, reports) to replicas. `synchronous_commit = remote_apply` makes a commit wait until a synchronous standby has applied it: read-your-writes on that standby, paid in write latency. On PG19+ the reader pays instead: the client keeps the LSN the primary reports after its commit (`pg_current_wal_insert_lsn()`), and the replica runs `WAIT FOR LSN '<lsn>' WITH (TIMEOUT '…')` before reading.
- A long query on a replica is either cancelled by replay conflicts or, with `hot_standby_feedback = on`, pins the primary's xmin horizon and bloats it (`references/postgresql/production-ops.md`). Choose per replica.
