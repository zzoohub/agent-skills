# PostgreSQL Performance Patterns

## Table of Contents

1. [Column Ordering for Storage Optimization](#1-column-ordering-for-storage-optimization)
2. [postgresql.conf Tuning](#2-postgresqlconf-tuning)
3. [Connection Pooling](#3-connection-pooling)
4. [Partitioning](#4-partitioning)
5. [Query Performance Patterns](#5-query-performance-patterns)
6. [Materialized Views](#6-materialized-views)
7. [VACUUM Monitoring](#7-vacuum-monitoring)
8. [Backfill / Bulk Load Optimization](#8-backfill--bulk-load-optimization)
9. [Ingestion Patterns](#9-ingestion-patterns)
10. [Read Replicas (read scaling)](#10-read-replicas-read-scaling)

## 1. Column Ordering for Storage Optimization

PostgreSQL enforces alignment padding based on data type size. An 8-byte BIGINT must start
at an 8-byte boundary. If a 2-byte SMALLINT precedes it, 6 bytes are wasted as padding.

**Rule: Order columns from largest to smallest data type in CREATE TABLE.**

```sql
-- BAD: wastes ~8 bytes per row from alignment padding
CREATE TABLE bad_column_order (
    id BIGINT NOT NULL,          -- 8 bytes, offset 0-7
    val_a SMALLINT NOT NULL,     -- 2 bytes, offset 8-9
    val_b INTEGER NOT NULL,      -- 4 bytes, 2-byte pad at 10-11, data at 12-15
    val_c SMALLINT NOT NULL,     -- 2 bytes, offset 16-17
    created_at TIMESTAMPTZ NOT NULL  -- 8 bytes, 6-byte pad at 18-23, data at 24-31
);
-- Per-row size: 56 bytes

-- GOOD: minimal padding waste
CREATE TABLE good_column_order (
    id BIGINT NOT NULL,              -- 8 bytes
    created_at TIMESTAMPTZ NOT NULL, -- 8 bytes
    val_b INTEGER NOT NULL,          -- 4 bytes
    val_a SMALLINT NOT NULL,         -- 2 bytes
    val_c SMALLINT NOT NULL          -- 2 bytes
);
-- Per-row size: 48 bytes (~14% savings)
```

At millions of rows, this difference adds up to gigabytes of storage and proportionally
faster sequential scans (less data to read from disk).

**Alignment size by type:**
| Alignment | Storage | Types |
|------|------|-------|
| 8 bytes | 8 bytes | BIGINT, TIMESTAMPTZ, TIMESTAMP, DOUBLE PRECISION, BIGSERIAL |
| 1 byte | 16 bytes | UUID |
| 4 bytes | 4 bytes | INTEGER, REAL, DATE, SERIAL |
| 2 bytes | 2 bytes | SMALLINT |
| 1 byte | 1 byte | BOOLEAN, CHAR(1) |
| Variable | variable | TEXT, VARCHAR, NUMERIC, JSONB, BYTEA (start on 4-byte boundary) |

**Recommended column order in CREATE TABLE:**
1. Fixed 8-byte-aligned columns (BIGINT, TIMESTAMPTZ)
2. UUID columns (16 bytes, 1-byte/char aligned — introduce no padding; placed here only by convention since the PK leads the table)
3. Fixed 4-byte columns (INTEGER, DATE)
4. Fixed 2-byte columns (SMALLINT)
5. Fixed 1-byte columns (BOOLEAN)
6. Variable-length columns (TEXT, JSONB, NUMERIC)

Note: with the skill's UUID v7 PK default, the conventional `id` column has 1-byte (char) alignment, so it introduces no padding wherever it sits. Following it directly with `created_at`/`updated_at` (both 8-byte aligned) wastes no padding because the UUID's 16-byte footprint is already a multiple of 8 — not because UUID requires any wide alignment. Place INTEGER/SMALLINT/BOOLEAN columns *after* the timestamps.

**TOAST**: when a row exceeds roughly 2KB, large variable-length values (TEXT/JSONB/arrays/BYTEA) are compressed and stored out-of-line automatically; on wide tables this dominates the alignment-padding optimization above. SELECT only the columns you need to avoid de-TOAST I/O, beware TOAST churn on frequently-updated large JSONB, and tune with `SET STORAGE` (PLAIN/EXTENDED/EXTERNAL/MAIN) when needed.

## 2. postgresql.conf Tuning

### Memory Configuration

| Parameter | OLTP (transaction-heavy) | OLAP (analytics-heavy) | Description |
|-----------|--------------------------|------------------------|-------------|
| shared_buffers | 25-40% of RAM | 25-40% of RAM | Shared memory cache |
| work_mem | 4-64MB | 64MB-1GB | Per-operation sort/hash memory |
| maintenance_work_mem | 512MB-2GB | 1-4GB | VACUUM, CREATE INDEX memory |
| effective_cache_size | 75% of RAM | 75% of RAM | Planner's estimate of OS cache |

shared_buffers above ~25-40% of RAM tends to hurt (PostgreSQL also relies on the OS page cache, so large shared_buffers causes double-buffering). `work_mem` is allocated **per sort/hash node, per connection, and per parallel worker** — budget roughly max_connections × concurrent sorts × work_mem against RAM; keep the global default modest (4-64MB) and raise to hundreds of MB only per-session via `SET` for a few dedicated OLAP sessions. `effective_cache_size` models shared_buffers + OS cache, so it should normally exceed shared_buffers.

```sql
-- Check current settings
SHOW shared_buffers;
SHOW work_mem;

-- Verify buffer cache hit rate (should be > 99%)
SELECT
    sum(blks_hit) * 100.0 / nullif(sum(blks_hit) + sum(blks_read), 0) AS cache_hit_ratio
FROM pg_stat_database;
```

### WAL Configuration for High-Write Workloads

```sql
-- Defaults are often too conservative for high-throughput writes
-- Consider adjusting during heavy ingestion or backfill:
wal_buffers = '64MB'          -- buffer WAL data in memory (default -1 = auto: 1/32 of shared_buffers, capped at one 16MB WAL segment)
checkpoint_completion_target = 0.9  -- spread checkpoint writes
max_wal_size = '4GB'          -- allow larger WAL before forced checkpoint
commit_delay = 100            -- microseconds; general default is 0. Only takes effect when ≥ commit_siblings (default 5) other transactions are active at commit; mainly helps on slow-fsync storage during heavy concurrent ingestion, and is often a no-op or counterproductive on fast SSD/NVMe
```

⚠️ These WAL settings can be temporarily increased during bulk data loads
and reverted to defaults afterward.

## 3. Connection Pooling

PostgreSQL forks a new process per connection (roughly a few MB to tens of MB each — it grows
with the work_mem an operation touches and with cached catalog/prepared statements).
Without pooling, 500 idle connections is already gigabytes of RAM just for backend processes.

```
# PgBouncer configuration (recommended)
[pgbouncer]
pool_mode = transaction        # release connection after each transaction
default_pool_size = 20         # connections per user/database pair
max_client_conn = 1000         # max client connections to PgBouncer
reserve_pool_size = 5          # emergency extra connections
```

| Pool Mode | Description | When to Use |
|-----------|-------------|-------------|
| session | Connection held for entire session | Legacy apps; session state (see below) |
| transaction | Released after each transaction | **Recommended default** |
| statement | Released after each statement | Forbids multi-statement transactions; niche (sharding/PL-proxy), rarely needed |

⚠️ **Transaction mode releases the backend between transactions, so anything session-scoped breaks:**
- **Server-side/protocol-level prepared statements** fail (`prepared statement "S_1" already exists` / `does not exist`) unless PgBouncer ≥1.21 with `max_prepared_statements > 0` (on by default — 200 — since PgBouncer 1.24; 0/off by default on 1.21–1.23), or the driver disables them.
- Use **`pg_advisory_xact_lock()`**, not session-level `pg_advisory_lock()` — the session variant can be acquired and released on different backends and leak. (The advisory-lock examples in `references/acid-transactions.md` use the session form; switch to `_xact` under transaction pooling.)
- Use **`SET LOCAL`** (transaction-scoped), not `SET` — a session GUC leaks across reused backends (including the `work_mem` `SET` shown above).
- Avoid session-lifetime **`LISTEN`/`NOTIFY`**, **`WITH HOLD`** cursors, and **temp tables**. Fall back to **session** pool mode if the app needs any of these.

**Sizing:** total server connections used = sum over pools of (`default_pool_size` + `reserve_pool_size`); keep that under PostgreSQL `max_connections` (a common misconfiguration is many pools each sized 20 overshooting the server limit).

## 4. Partitioning

### When to Partition
- Table exceeds hundreds of millions of rows
- Queries typically filter by time range or category
- Need to drop old data efficiently (DROP partition vs DELETE rows)
- Write throughput needs to scale across partitions

### Partition Types

```sql
-- Range Partitioning (most common: time-series, logs)
-- BIGINT IDENTITY here per SKILL.md mixed strategy: high-volume append-only log
-- where 8-byte savings cascade through every row.
CREATE TABLE access_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    url TEXT NOT NULL,
    status_code SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (created_at);

CREATE TABLE access_logs_2025_01 PARTITION OF access_logs
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE access_logs_2025_02 PARTITION OF access_logs
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Automate with pg_partman for production use

-- List Partitioning (region, category)
CREATE TABLE orders (
    id UUID NOT NULL DEFAULT uuidv7(),
    region TEXT NOT NULL,
    total NUMERIC(15, 2),
    PRIMARY KEY (id, region)  -- partition key must be in PK
) PARTITION BY LIST (region);

CREATE TABLE orders_us PARTITION OF orders FOR VALUES IN ('US');
CREATE TABLE orders_eu PARTITION OF orders FOR VALUES IN ('EU');
CREATE TABLE orders_apac PARTITION OF orders FOR VALUES IN ('APAC');

-- Hash Partitioning (even distribution when no natural key)
-- Note: uuidv7() (PG18+); pre-PG18 generate at app layer. gen_random_uuid() is v4
-- and forbidden for hot-table PKs (see SKILL.md Critical Rules).
CREATE TABLE sessions (
    id UUID NOT NULL DEFAULT uuidv7(),
    user_id UUID NOT NULL,
    data JSONB,
    PRIMARY KEY (id, user_id)  -- partition key must be in PK
) PARTITION BY HASH (user_id);

CREATE TABLE sessions_p0 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sessions_p1 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE sessions_p2 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE sessions_p3 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

### Partition Sizing
- Partitions that fit in memory = optimal write performance
- For time-series: partition interval should keep recent partitions "hot" in shared_buffers
- Rule of thumb: each partition between 100MB-1GB

### Data Lifecycle: Retention via Partition Drop

Range partitioning by `created_at` is PostgreSQL's canonical **retention primitive**: dropping or detaching an old partition is an O(1) catalog operation, versus a `DELETE` that scans, locks, bloats, and must be VACUUMed afterward.

```sql
-- Enforce "keep 90 days": detach the old partition, then archive or drop it
ALTER TABLE access_logs DETACH PARTITION access_logs_2025_01 CONCURRENTLY;  -- PG14+: no ACCESS EXCLUSIVE on the parent
-- archive out-of-database before dropping (tiering to object storage):
--   COPY access_logs_2025_01 TO PROGRAM 'gzip > /archive/access_logs_2025_01.csv.gz' (FORMAT csv);
DROP TABLE access_logs_2025_01;
```

- **Hot/cold tiering**: move older partitions to a cheaper tablespace (`ALTER TABLE … SET TABLESPACE`) instead of dropping, when the data must stay queryable but rarely is.
- **Automate** the retention window and partition creation with `pg_partman` (`retention` / `retention_keep_table` settings) rather than hand-rolling a schedule.
- Retention *policy* (how long to keep) is a system-level decision (SKILL.md → DB-domain vs system-level); the *mechanism* here is DB-domain — design the partition key so the policy is executable as a partition drop.

### When single-node Postgres runs out

Partitioning scales table *management* and read replicas scale *reads*, but neither scales **write throughput beyond a single primary**. Signals you've hit that ceiling: sustained write-IOPS saturation on the primary, a working set larger than one machine's RAM/disk, or per-tenant blast-radius isolation needs. Options:

- **Distributed Postgres (Citus)** — shard across nodes by a **distribution key**. That key must sit in the PK and most indexes and is *design-time, hard to change* (the same one-way door as PK type) — ideally align it with the `tenant_id` you already carry for multi-tenancy.
- **App-level sharding** — route by tenant/hash in the application: more control, more operational burden.
- **Accept the limit** — most products never reach it; don't shard speculatively (YAGNI).

Whether to make the platform jump is a *system-level* call (`docs/arch/system.md`); the DB-design job is to **not foreclose it** — keep the prospective distribution key in the PK so you aren't forced into a full rewrite later.

## 5. Query Performance Patterns

### Keyset Pagination (avoid OFFSET)
```sql
-- BAD: OFFSET scans and discards rows (O(n) cost)
SELECT * FROM products ORDER BY created_at DESC, id DESC LIMIT 20 OFFSET 10000;

-- GOOD: Keyset pagination (constant performance regardless of page depth)
-- This example assumes a BIGINT id (e.g. a high-volume internal table). For a UUID v7 PK, use a uuid literal as the cursor value; keep the (created_at, id) compound cursor either way — do NOT keyset on the UUID alone (v7 is not strictly monotonic across generators, and the sort is by the separate created_at column).
SELECT * FROM products
WHERE (created_at, id) < ('2025-01-15 10:30:00+00', 99500)
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- Requires index
CREATE INDEX idx_products_pagination ON products (created_at DESC, id DESC);
```

### Design Queries Around These Guidelines

1. **Return reasonable resultsets** — aim for under 10,000 rows per query.
   Use LIMIT, pagination, or encourage filtering from the application layer.

2. **Help the planner filter early** — PostgreSQL's query planner is good at
   pushing predicates into joins, but it needs the right indexes to act on them.
   Ensure every column in WHERE and JOIN ON has appropriate indexes.
   ```sql
   -- The planner will push these filters down automatically if indexed:
   SELECT o.id, o.total
   FROM orders o
   JOIN order_items oi ON oi.order_id = o.id
   JOIN products p ON p.id = oi.product_id
   WHERE p.category = 'electronics'
   AND o.created_at > '2025-01-01';

   -- Required indexes for the planner to filter efficiently:
   CREATE INDEX idx_orders_created_at ON orders (created_at);
   CREATE INDEX idx_order_items_order_id ON order_items (order_id);
   CREATE INDEX idx_order_items_product_id ON order_items (product_id);
   CREATE INDEX idx_products_category ON products (category);
   ```

   Use EXISTS instead of JOIN when you only need to check existence (not retrieve columns):
   ```sql
   -- BETTER than JOIN when you don't need product columns:
   SELECT o.id, o.total
   FROM orders o
   WHERE o.created_at > '2025-01-01'
   AND EXISTS (
       SELECT 1 FROM order_items oi
       JOIN products p ON p.id = oi.product_id
       WHERE oi.order_id = o.id AND p.category = 'electronics'
   );
   ```

   Note: since PostgreSQL 12, a non-recursive, side-effect-free CTE (a plain
   `SELECT` with no volatile functions) referenced once is inlined by default
   and optimized like a subquery; others stay materialized. Wrapping filters
   in CTEs does not help the planner — proper indexes do.

3. **Cache computed data** — avoid recomputing expensive aggregations repeatedly.
   Use Materialized Views or dedicated summary tables refreshed on a schedule.

### Batch Processing
```sql
-- Process large datasets in chunks (e.g., 1000 rows at a time)
-- Prevents long-running transactions and excessive lock holding

-- Queue pattern with SKIP LOCKED
SELECT id, payload
FROM task_queues
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1000
FOR UPDATE SKIP LOCKED;
```

## 6. Materialized Views

Definition, the UNIQUE index that `REFRESH MATERIALIZED VIEW CONCURRENTLY` requires, and the non-blocking refresh: see `references/postgresql/query-patterns.md` §9.

## 7. VACUUM Monitoring

The dead-tuple query, per-table autovacuum tuning for hot tables, and when to run a manual `ANALYZE`: see `references/postgresql/production-ops.md` §3.

## 8. Backfill / Bulk Load Optimization

When loading large volumes of historical data:

```sql
-- 1. Drop non-essential indexes before bulk load
DROP INDEX idx_orders_created_at;

-- 2. Bulk insert in batches (1000-5000 rows per INSERT)
INSERT INTO orders (user_id, status, total, created_at)
VALUES
    (...), (...), (...),  -- batch of rows
    ...;

-- 3. Recreate indexes after load (CONCURRENTLY for zero downtime)
CREATE INDEX CONCURRENTLY idx_orders_created_at ON orders (created_at);

-- 4. Analyze after bulk load for fresh statistics
ANALYZE orders;
```

**Additional tips for large backfills:**
- Schedule during lowest database load periods
- Temporarily increase `shared_buffers` and `work_mem` (revert after)
- Increase `wal_buffers` and adjust `commit_delay` to reduce WAL flush overhead
- Use parallel insert processes targeting different partitions
- If using COPY command, it's faster than INSERT for bulk loads:
  ```sql
  COPY orders (user_id, status, total, created_at)
  FROM '/path/to/data.csv' WITH (FORMAT csv, HEADER true);
  ```
- After backfill: VACUUM ANALYZE to update statistics and reclaim space

## 9. Ingestion Patterns

### Append-Only (best performance)
- New records added chronologically to the most recent partition
- No UPDATE or DELETE on existing rows
- Minimal index maintenance overhead
- Ideal for: logs, events, metrics, time-series

### Upsert (INSERT ... ON CONFLICT)
```sql
-- Requires a uniqueness constraint
INSERT INTO products (sku, name, price, updated_at)
VALUES ('ABC-123', 'Widget', 29.99, now())
ON CONFLICT (sku) DO UPDATE SET
    name = EXCLUDED.name,
    price = EXCLUDED.price,
    updated_at = EXCLUDED.updated_at;
```
- The uniqueness check on every insert adds overhead
- Performance depends on whether conflicting rows are in the same partition / cache
- Order inserts to keep recently accessed data "hot" in memory

### Update-Heavy
- Generates dead tuples → requires aggressive VACUUM strategy
- Consider per-table autovacuum tuning (see section 7)
- Monitor dead tuple ratios closely

## 10. Read Replicas (read scaling)

Routing reads to physical replicas scales read throughput, but introduces **replication lag**: a read
issued right after a write may not yet see that write (read-after-write inconsistency). Design for it:

- Route **read-after-write** flows ("show the thing I just created") to the **primary**; send only
  lag-tolerant reads (dashboards, search, analytics, reports) to replicas.
- `synchronous_commit` / synchronous-replica quorum is the knob trading write latency for read freshness.
- A materialized view on the primary can beat a replica when you need a consistent, pre-aggregated read.

Whether to add replicas at all is usually a **system-level** decision (see `docs/arch/system.md` read/write
separation); the lag and read-after-write consequences are the DB-domain concern to flag and design around.
