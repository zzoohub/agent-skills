# PostgreSQL Indexing Strategy Guide

## Table of Contents

1. [Core Principle](#core-principle)
2. [Index Types](#index-types)
3. [Advanced Index Patterns](#advanced-index-patterns)
4. [Index Maintenance](#index-maintenance)
5. [Index Anti-Patterns](#index-anti-patterns)
6. [Reading EXPLAIN ANALYZE](#reading-explain-analyze)

## Core Principle

The goal of indexing: **minimize disk I/O**. An index is metadata pointing to where specific values are stored.

### Selectivity
```
Selectivity = Number of distinct values / Total number of rows
```
- Close to 1 = highly selective (good) → index is very effective
- Close to 0 = low selectivity → index is less effective
- Boolean / low-cardinality columns (only 2-3 distinct values → selectivity near 0): a plain index is rarely worthwhile; use a Partial Index targeting the rare value (e.g. `WHERE is_active`) instead. (Note: 'selectivity' here = distinct-value ratio; it differs from the fraction of rows a single predicate matches.)

```sql
-- Check selectivity
SELECT
    attname AS column_name,
    n_distinct,
    CASE
        WHEN reltuples <= 0 THEN NULL  -- reltuples is -1 on never-analyzed tables (PG14+); NULL = "run ANALYZE first" instead of a bogus negative
        WHEN n_distinct > 0 THEN n_distinct / reltuples
        WHEN n_distinct < 0 THEN abs(n_distinct)
        ELSE 0
    END AS selectivity
FROM pg_stats
JOIN pg_class ON pg_class.relname = pg_stats.tablename
WHERE tablename = 'your_table'
ORDER BY selectivity DESC;
-- Figures are meaningful only after ANALYZE; add `schemaname = 'public'` (or the target schema) to avoid cross-schema name collisions in the join.
```

## Index Types

### B-tree (default, most commonly used)
```sql
-- Suitable for equality, range, sorting, LIKE 'prefix%'
CREATE INDEX idx_orders_created_at ON orders (created_at);
CREATE INDEX idx_user_email ON user_accounts (email);

-- Composite index: matches left-to-right (leftmost prefix rule)
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
-- ✅ WHERE user_id = 1
-- ✅ WHERE user_id = 1 AND status = 'pending'
-- ❌ WHERE status = 'pending' (without user_id: not usable as an index search on PG ≤17)
```
PG18+ adds B-tree **skip scan**: the planner can use this index for `WHERE status = 'pending'` by probing each distinct leading `user_id` — worthwhile only when the skipped leading column has few distinct values. Design order for the real queries anyway; don't count on skip scan for a high-cardinality leading column.

### Hash (equality-only)
Hash supports only equality (=). Crash-safe since PG10, but B-tree is still the default even for equality. Hash indexes cannot be UNIQUE, multicolumn, used for sorting/ranges, or used for index-only scans (they store only the hash, not the value). Consider hash only for very large keys where smaller index size matters; otherwise prefer B-tree.

```sql
CREATE INDEX idx_sessions_token ON sessions USING HASH (token);
-- A session token usually wants a UNIQUE B-tree instead.
```

### GIN (Generalized Inverted Index)
```sql
-- Essential for ARRAY, JSONB, full-text search
CREATE INDEX idx_products_tags ON products USING GIN (tags);
CREATE INDEX idx_products_attrs ON products USING GIN (attributes);

-- Full-text search
CREATE INDEX idx_articles_fts ON articles USING GIN (to_tsvector('english', title || ' ' || body));
```

For JSONB, the default GIN opclass (jsonb_ops) supports key-existence (?, ?|, ?&), containment (@>), and the jsonpath operators (@?, @@); `USING GIN (attributes jsonb_path_ops)` is smaller/faster and supports @>, @? and @@ but NOT the key-existence operators — that lack is the only difference between the two opclasses. For substring/fuzzy matching, `CREATE EXTENSION pg_trgm;` then `USING GIN (col gin_trgm_ops)` makes `ILIKE '%term%'` and similarity (%) indexable.

### GiST (Generalized Search Tree)
```sql
-- Geographic data, range types, proximity searches
-- Requires a GiST-indexable type: built-in point/box/polygon, a range type, or (most commonly for geo) PostGIS geometry/geography via CREATE EXTENSION postgis. This example assumes location is a PostGIS geography column.
CREATE INDEX idx_store_location ON store USING GIST (location);

-- Range types (overlap searches)
CREATE INDEX idx_reservation_period ON reservation USING GIST (
    tstzrange(check_in, check_out)
);
```

### BRIN (Block Range Index)
```sql
-- Physically sorted large datasets (time-series, logs)
-- Much smaller than B-tree
CREATE INDEX idx_logs_created_at ON access_logs USING BRIN (created_at);
-- Effective only when physical row order strongly correlates with the indexed column (append-only time-series, logs). Always correct regardless of order, just not selective without correlation. Tune with pages_per_range.
```

### Foreign Key Indexing
PostgreSQL auto-creates indexes for PRIMARY KEY and UNIQUE constraints, but does NOT index foreign-key (referencing) columns. Always add an index on FK columns — without it, a DELETE/UPDATE on the parent row forces a sequential scan of the child table during the referential-integrity check (and takes row-level locks on matching child rows), and FK joins are unindexed.

```sql
CREATE INDEX idx_orders_user_id ON orders (user_id);  -- for FOREIGN KEY (user_id) REFERENCES user_accounts (id)
```

## Advanced Index Patterns

### Partial Index
Index only rows that match a condition. Saves space and improves performance.

```sql
-- Only index active orders (if 5% of total, saves 95% space)
CREATE INDEX idx_orders_active ON orders (created_at)
WHERE status NOT IN ('delivered', 'cancelled');

-- Unread notifications only
CREATE INDEX idx_notification_unread ON notification (user_id, created_at)
WHERE is_read = false;

-- Soft delete pattern
CREATE INDEX idx_user_active ON user_accounts (email)
WHERE deleted_at IS NULL;
```

### Expression Index
```sql
-- Case-insensitive search
CREATE INDEX idx_user_email_lower ON user_accounts (lower(email));
-- Query: WHERE lower(email) = 'user@example.com'

-- Date extraction
CREATE INDEX idx_orders_year_month ON orders (
    date_trunc('month', created_at)
);

-- JSONB specific key
CREATE INDEX idx_products_brand ON products ((attributes->>'brand'));
```

### Covering Index (INCLUDE)
Enables Index-Only Scan by including all needed columns in the index.

```sql
-- Frequent lookup by id returning email and name
CREATE INDEX idx_user_lookup ON user_accounts (id) INCLUDE (email, name);
-- Covering indexes are most useful on a non-PK lookup column; here the PK index on (id) doesn't store email/name, so INCLUDE turns this into an index-only scan (no heap fetch).

-- Order listing optimization
CREATE INDEX idx_orders_user_list ON orders (user_id, created_at DESC)
INCLUDE (status, total_amount);
```

### Composite Index Design Rules

Column order matters:
1. **Equality conditions** first
2. **Range conditions** next
3. **Sort columns** last

```sql
-- Query: WHERE user_id = ? AND status = ? ORDER BY created_at DESC
CREATE INDEX idx_orders_user_status_date ON orders (user_id, status, created_at DESC);

-- Query: WHERE user_id = ? AND created_at > ?
CREATE INDEX idx_orders_user_date ON orders (user_id, created_at);
```

## Index Maintenance

### Check index usage
```sql
-- Find unused indexes
SELECT
    s.schemaname, s.relname AS tablename, s.indexrelname AS indexname,
    s.idx_scan AS times_used,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size
FROM pg_stat_user_indexes s
JOIN pg_index ix ON ix.indexrelid = s.indexrelid
-- idx_scan is cumulative since the last stats reset — trust 0 only over a
-- representative window (PG16+ has last_idx_scan for recency).
WHERE s.idx_scan = 0
    -- never drop what enforces uniqueness or feeds logical replication
    -- (standalone UNIQUE indexes have no pg_constraint row):
    AND NOT ix.indisunique
    AND NOT ix.indisprimary
    AND NOT ix.indisreplident
    AND s.indexrelid NOT IN (
        SELECT conindid FROM pg_constraint WHERE contype IN ('p', 'u')
    )
ORDER BY pg_relation_size(s.indexrelid) DESC;
```

### Rebuild bloated indexes
```sql
-- CONCURRENTLY (zero-downtime, recommended)
REINDEX INDEX CONCURRENTLY idx_orders_created_at;

-- Or create new + swap
CREATE INDEX CONCURRENTLY idx_orders_created_at_new ON orders (created_at);
DROP INDEX CONCURRENTLY idx_orders_created_at;  -- plain DROP takes ACCESS EXCLUSIVE and queues traffic
ALTER INDEX idx_orders_created_at_new RENAME TO idx_orders_created_at;
-- REINDEX INDEX CONCURRENTLY (PG12+) is the preferred one-step path. All CONCURRENTLY index ops cannot run inside a transaction block, and a failed run can leave an INVALID index that must be dropped and recreated.
```

### Check index sizes
```sql
SELECT
    relname AS tablename, indexrelname AS indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```

## Index Anti-Patterns

1. **Indexing every column** → degrades INSERT/UPDATE/DELETE, wastes storage
2. **Regular index on low-selectivity columns** → use Partial Index for Boolean/status
3. **Leaving unused indexes** → check `pg_stat_user_indexes` regularly
4. **Ignoring composite index column order** → leftmost prefix rule violation (PG18 skip scan softens this only for a low-cardinality leading column)
5. **Function in WHERE without Expression Index**
   ```sql
   -- Index is ignored
   WHERE UPPER(email) = 'USER@EXAMPLE.COM'
   -- Needs Expression Index
   CREATE INDEX idx_user_email_upper ON user_accounts (UPPER(email));
   ```

## Reading EXPLAIN ANALYZE

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';
```

Key indicators:
- **Seq Scan**: reads the whole table — expected and optimal when a query returns a large fraction of rows (low-selectivity/analytics); a problem only when a selective predicate should have used an index but didn't (stale stats, non-sargable predicate, or missing index)
- **Index Scan**: Finds rows via index, reads data from table (good)
- **Index Only Scan**: Completes entirely from index (best)
- **Bitmap Index Scan**: Builds a bitmap of matching rows, then reads the heap in physical order — chosen when a single index matches many rows (avoids random I/O), or to combine multiple indexes via BitmapAnd/BitmapOr. Often the optimal plan, not a warning sign
- **actual time**: Real execution time (ms)
- **Buffers: shared hit**: Pages read from cache (more = better)
- **Buffers: shared read**: Pages read from disk (less = better)
