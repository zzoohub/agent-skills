# EXPLAIN ANALYZE Reading Guide

## Table of Contents

1. [Running EXPLAIN](#running-explain)
2. [Scan Types (typical cost order — NOT absolute; depends on selectivity)](#scan-types-typical-cost-order--not-absolute-depends-on-selectivity)
3. [Key Indicators](#key-indicators)
4. [Common EXPLAIN Anti-Patterns](#common-explain-anti-patterns)
5. [Diagnostic Queries](#diagnostic-queries)

## Running EXPLAIN

```sql
-- Plan only (does NOT execute)
EXPLAIN SELECT * FROM orders WHERE user_id = 123;

-- Full execution with timing and buffer stats
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';
```

**WARNING**: EXPLAIN ANALYZE executes the query. For INSERT/UPDATE/DELETE, wrap in a transaction and ROLLBACK:
```sql
BEGIN;
EXPLAIN ANALYZE UPDATE orders SET status = 'shipped' WHERE id = 1;
ROLLBACK;
```

## Scan Types (typical cost order — NOT absolute; depends on selectivity)

| Scan Type | Meaning | Action |
|-----------|---------|--------|
| Index Only Scan | Data from index alone (visibility-map permitting) | Best case — covering index working |
| Index Scan | Find rows via index, fetch from table | Good — index is being used |
| Bitmap Index Scan | Combine multiple indexes, then fetch | Acceptable — multiple conditions |
| Seq Scan | Full table scan | Bad for large tables — add index or check statistics |

> This is a rough guide, not a ranking. A **Bitmap Heap Scan** or **Seq Scan** can be the cheapest plan when a large fraction of rows match, and an **Index Only Scan** still does heap visibility checks (and falls back to heap fetches) when pages aren't marked all-visible.

## Key Indicators

### Index Cond vs Filter
```
Index Scan using idx_orders_user_status on orders
  Index Cond: (user_id = 42)
  Filter: (status = 'pending')
  Rows Removed by Filter: 3847
```
- **Index Cond**: condition resolved by the index (efficient)
- **Filter**: condition checked AFTER fetching rows from index (wasteful)
- **Rows Removed by Filter**: wasted I/O — these rows were read then discarded

**Fix**: Create a composite index covering both conditions:
```sql
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
```
After fix, both conditions appear in Index Cond, Filter disappears.

### Estimated vs Actual Rows
```
Index Scan ... (rows=10) (actual rows=8432)
```
Large mismatch = stale statistics.

**Fix**:
```sql
ANALYZE orders;
```

### Buffer Statistics
```
Buffers: shared hit=128 read=4096
```
- **shared hit**: pages read from PostgreSQL's shared_buffers cache (fast)
- **shared read**: pages read from outside shared_buffers (may still be served by the OS page cache, not necessarily physical disk)
- High `read` relative to `hit` = data not cached, consider if table/index fits in shared_buffers (on PG16+, `pg_stat_io` breaks this down per IO type)

### Sort Methods
```
Sort Method: external merge  Disk: 15240kB
```
External merge = data too large for work_mem, spilled to disk.

**Fix options**:
1. Add index matching ORDER BY (eliminates sort entirely)
2. Increase `work_mem` for the session: `SET work_mem = '64MB';`

## Common EXPLAIN Anti-Patterns

### 1. Seq Scan on large table with WHERE clause
**Cause**: Missing index, or planner thinks too many rows match.
**Fix**: Add appropriate index. If index exists but unused, check selectivity and statistics.

### 2. Nested Loop with high row count
```
Nested Loop (actual rows=500000)
  -> Index Scan on users (actual rows=500)
  -> Index Scan on orders (actual rows=1000 loops=500)
```
500 × 1000 = 500,000 row operations.
**Fix**: Consider Hash Join (may need more work_mem) or restructure query.

### 3. Index scan followed by Sort
**Cause**: The index's sort order can't produce the requested **mixed-direction** ORDER BY, so a Sort is added. A *pure* single-direction DESC does NOT trigger this — an all-ASC index is scanned backward. See `references/postgresql/indexing-pitfalls.md` Pitfall 5.
```sql
-- A Sort appears only for MIXED directions an all-ASC index can't satisfy:
CREATE INDEX idx_items_published ON items (category, published_at);
SELECT * FROM items ORDER BY category, published_at DESC LIMIT 10;
-- (With WHERE category = 'books' there is no Sort: the equality makes category constant,
--  and published_at DESC comes from a backward scan.)

-- Fix: encode the mixed direction in the index
CREATE INDEX idx_items_published_mixed ON items (category ASC, published_at DESC);
```

## Diagnostic Queries

### Find slow queries (requires pg_stat_statements)
```sql
SELECT
    queryid,
    calls,
    ROUND(total_exec_time::NUMERIC, 2) AS total_ms,
    ROUND(mean_exec_time::NUMERIC, 2) AS avg_ms,
    ROUND(max_exec_time::NUMERIC, 2) AS max_ms,
    rows,
    LEFT(query, 120) AS query_preview
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Current locks and blocking

Simplest version (PG 9.6+) — `pg_blocking_pids()` returns the PIDs blocking a given backend:
```sql
SELECT
    blocked.pid AS blocked_pid,
    LEFT(blocked.query, 80) AS blocked_query,
    blocked.wait_event_type,
    pg_blocking_pids(blocked.pid) AS blocking_pids,
    now() - blocked.query_start AS blocked_duration
FROM pg_stat_activity blocked
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0
ORDER BY blocked_duration DESC;
```

Detailed version (explicit `pg_locks` self-join — shows the exact blocking query per lock):
```sql
SELECT
    blocked.pid AS blocked_pid,
    LEFT(blocked.query, 80) AS blocked_query,
    blocking.pid AS blocking_pid,
    LEFT(blocking.query, 80) AS blocking_query,
    now() - blocked.query_start AS blocked_duration
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid
JOIN pg_locks kl ON kl.locktype = bl.locktype
    AND kl.database IS NOT DISTINCT FROM bl.database
    AND kl.relation IS NOT DISTINCT FROM bl.relation
    AND kl.page IS NOT DISTINCT FROM bl.page
    AND kl.tuple IS NOT DISTINCT FROM bl.tuple
    AND kl.virtualxid IS NOT DISTINCT FROM bl.virtualxid
    AND kl.transactionid IS NOT DISTINCT FROM bl.transactionid
    AND kl.pid != bl.pid
JOIN pg_stat_activity blocking ON blocking.pid = kl.pid
WHERE NOT bl.granted
ORDER BY blocked_duration DESC;
```

### Long-running transactions (VACUUM blockers)
```sql
SELECT pid, now() - xact_start AS duration, state, LEFT(query, 100) AS query
FROM pg_stat_activity
WHERE state != 'idle'
AND xact_start IS NOT NULL
ORDER BY duration DESC
LIMIT 10;
```
