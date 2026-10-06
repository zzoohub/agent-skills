# PostgreSQL Query Patterns

Problem-solution patterns for common PostgreSQL query challenges.

## Table of Contents

1. [Keyset Pagination (Cursor Pagination)](#1-keyset-pagination-cursor-pagination)
2. [Full-Text Search](#2-full-text-search)
3. [N+1 Query Prevention](#3-n1-query-prevention)
4. [High-Concurrency Patterns](#4-high-concurrency-patterns)
5. [Optimistic Locking](#5-optimistic-locking)
6. [Hierarchical Data (Recursive CTE)](#6-hierarchical-data-recursive-cte)
7. [JSONB Query Patterns](#7-jsonb-query-patterns)
8. [Bulk Import](#8-bulk-import)
9. [Materialized View Caching](#9-materialized-view-caching)
10. [Row-Level Security (Multi-Tenant)](#10-row-level-security-multi-tenant)
11. [Time-Series with Partitioning](#11-time-series-with-partitioning)
12. [UPSERT (INSERT ON CONFLICT)](#12-upsert-insert-on-conflict)
13. [Window Functions](#13-window-functions)
14. [DISTINCT ON (PostgreSQL-Specific)](#14-distinct-on-postgresql-specific)
15. [Conditional Aggregation](#15-conditional-aggregation)
16. [Date Gap-Filling with generate_series](#16-date-gap-filling-with-generate_series)
17. [Efficient Filtering Patterns](#17-efficient-filtering-patterns)

## 1. Keyset Pagination (Cursor Pagination)

**Problem**: OFFSET scans and discards rows — O(n) cost that worsens with page depth.

```sql
-- ❌ Slow at deep offsets
SELECT * FROM posts ORDER BY created_at DESC LIMIT 20 OFFSET 100000;

-- ✅ Keyset pagination (constant performance regardless of page)
SELECT id, title, created_at FROM posts
WHERE (created_at, id) < (:last_created_at, :last_id)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

Required index:
```sql
CREATE INDEX idx_posts_pagination ON posts (created_at DESC, id DESC);
```

**Trade-off**: Cannot jump to arbitrary page numbers. Use for infinite scroll, feeds, API cursors.

## 2. Full-Text Search

**Problem**: `LIKE '%term%'` forces a sequential scan — no B-tree index can serve a mid-string match (a `pg_trgm` GIN index can; see below) — and it has no stemming or ranking.

```sql
-- Generated tsvector column with weighted fields
ALTER TABLE posts ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(content, '')), 'B')
    ) STORED;

CREATE INDEX idx_posts_search ON posts USING GIN (search_vector);

-- Query with ranking
SELECT id, title, ts_rank(search_vector, q) AS rank
FROM posts, to_tsquery('english', 'postgres & performance') q
WHERE search_vector @@ q
ORDER BY rank DESC
LIMIT 20;
```

**For fuzzy / typo-tolerant search**: Use `pg_trgm` extension instead:
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_posts_title_trgm ON posts USING GIN (title gin_trgm_ops);

SELECT * FROM posts WHERE title % 'postgre';  -- similarity search
```

## 3. N+1 Query Prevention

**Solution A**: JSON aggregation (single query)
```sql
SELECT u.id, u.name,
    COALESCE(
        jsonb_agg(jsonb_build_object('id', o.id, 'total', o.total))
        FILTER (WHERE o.id IS NOT NULL),
        '[]'
    ) AS orders
FROM user_accounts u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.id = ANY(:user_ids)
GROUP BY u.id;
```

**Solution B**: LATERAL join (when you need a per-parent row limit, e.g. latest 5)
```sql
SELECT u.id, u.name, recent.orders
FROM user_accounts u
LEFT JOIN LATERAL (
    -- Cap rows in an INNER subquery BEFORE aggregating. A LIMIT next to jsonb_agg
    -- has no effect: jsonb_agg collapses every matched row into one, so the LIMIT
    -- would apply to that single aggregate row, not to the input rows.
    SELECT jsonb_agg(
        jsonb_build_object('id', t.id, 'total', t.total)
        ORDER BY t.created_at DESC
    ) AS orders
    FROM (
        SELECT o.id, o.total, o.created_at
        FROM orders o
        WHERE o.user_id = u.id
        ORDER BY o.created_at DESC
        LIMIT 5
    ) t
) recent ON true
WHERE u.id = ANY(:user_ids);
```

## 4. High-Concurrency Patterns

### Queue Processing with SKIP LOCKED
```sql
-- Worker grabs next pending job without blocking others
UPDATE jobs SET status = 'processing', worker_id = :worker
WHERE id = (
    SELECT id FROM jobs
    WHERE status = 'pending'
    ORDER BY created_at
    FOR UPDATE SKIP LOCKED
    LIMIT 1
) RETURNING *;
```

### Batched Counter Updates (avoid row-level contention)
```sql
-- Buffer increments into a staging table
INSERT INTO view_count_buffers (post_id, delta) VALUES (:id, 1);

-- Periodic flush (cron or background worker)
WITH flushed AS (
    DELETE FROM view_count_buffers RETURNING post_id, delta
)
UPDATE posts p
SET view_count = view_count + f.total
FROM (SELECT post_id, SUM(delta) AS total FROM flushed GROUP BY post_id) f
WHERE p.id = f.post_id;
```

### Advisory Locks (application-level coordination)
```sql
-- Try to acquire (non-blocking, returns boolean)
SELECT pg_try_advisory_lock(hashtext('import:' || :resource_id));

-- Do exclusive work...

-- Release
SELECT pg_advisory_unlock(hashtext('import:' || :resource_id));
```

**Under PgBouncer transaction pooling** (the recommended pool mode — see `references/performance-patterns.md` §3), session-level advisory locks break: acquire and release can land on different backends and the lock leaks. Use the transaction-scoped variant inside one transaction instead — `pg_advisory_xact_lock()` / `pg_try_advisory_xact_lock()` (auto-released at COMMIT/ROLLBACK).

## 5. Optimistic Locking

Version column + `UPDATE ... WHERE id = :id AND version = :expected_version` (0 rows affected = concurrent modification → retry or error), and when to choose optimistic vs pessimistic locking: see `references/acid-transactions.md` § Optimistic Locking.

## 6. Hierarchical Data (Recursive CTE)

```sql
WITH RECURSIVE tree AS (
    -- Base case: root node
    SELECT id, name, parent_id, 1 AS depth, ARRAY[id] AS path
    FROM categories WHERE id = :root_id

    UNION ALL

    -- Recursive case: children
    SELECT c.id, c.name, c.parent_id, t.depth + 1, t.path || c.id
    FROM categories c
    JOIN tree t ON c.parent_id = t.id
    WHERE t.depth < 10  -- always add depth limit
)
SELECT * FROM tree ORDER BY path;
```

**Required index**: `CREATE INDEX idx_categories_parent ON categories (parent_id);`

## 7. JSONB Query Patterns

```sql
-- Containment check (uses GIN index)
CREATE INDEX idx_products_attrs ON products USING GIN (attributes);
SELECT * FROM products WHERE attributes @> '{"color": "red"}';

-- Specific key lookup (uses expression index, smaller)
CREATE INDEX idx_products_color ON products ((attributes->>'color'));
SELECT * FROM products WHERE attributes->>'color' = 'red';

-- Check key existence
SELECT * FROM products WHERE attributes ? 'color';

-- Nested path
SELECT * FROM products WHERE attributes #>> '{specs,weight}' = '1.5kg';
```

**Pitfall**: `->>'key'` returns TEXT, `->'key'` returns JSONB. Use `->>` for comparison with string values.

## 8. Bulk Import

```sql
-- 1. Create staging table (copies columns, defaults and NOT NULL — no CHECK, UNIQUE or indexes)
CREATE TEMP TABLE staging (LIKE products INCLUDING DEFAULTS);

-- 2. COPY is fastest for bulk loading
COPY staging FROM '/path/to/data.csv' WITH (FORMAT csv, HEADER true);

-- 3. Upsert from staging to production table
INSERT INTO products (sku, name, price, updated_at)
SELECT sku, name, price, now() FROM staging
ON CONFLICT (sku) DO UPDATE SET
    name = EXCLUDED.name,
    price = EXCLUDED.price,
    updated_at = EXCLUDED.updated_at;

-- 4. Clean up
DROP TABLE staging;

-- 5. Refresh statistics
ANALYZE products;
```

**For very large loads** (millions of rows):
1. Drop non-essential indexes before load
2. Load data (COPY or batched INSERT)
3. Recreate indexes with `CREATE INDEX CONCURRENTLY`
4. Run `ANALYZE`

## 9. Materialized View Caching

```sql
CREATE MATERIALIZED VIEW mv_daily_revenue AS
SELECT
    date_trunc('day', o.created_at) AS day,
    SUM(oi.quantity * oi.unit_price) AS revenue,
    COUNT(DISTINCT o.id) AS order_count
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY 1;

-- Required for CONCURRENTLY refresh
CREATE UNIQUE INDEX idx_mv_daily_revenue_day ON mv_daily_revenue (day);

-- Non-blocking refresh
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_revenue;
```

**Pitfall**: `REFRESH CONCURRENTLY` requires a UNIQUE index on the materialized view.

## 10. Row-Level Security (Multi-Tenant)

Table setup (`ENABLE` + `FORCE ROW LEVEL SECURITY`) and the fail-closed policy — a scalar subquery so `current_setting()` evaluates once per query, `NULLIF(..., '')` so an unset GUC yields zero rows instead of an error — live in `references/design-patterns.md` §6. At query time:

```sql
-- Set per transaction (SET LOCAL — survives pooled connections; plain SET leaks across reuse)
BEGIN;
SET LOCAL app.current_tenant = '<tenant-uuid>';
SELECT * FROM orders;  -- automatically filtered to that tenant
COMMIT;
```

**Pitfalls**: superusers and `BYPASSRLS` roles always bypass; the table owner bypasses unless `FORCE` is set — the app must connect as a **non-owner** role. Test with that role, not as yourself. (Tenancy-model choice and the full RLS wiring live in SKILL.md → Conventions (multi-tenancy) and Roles & Least Privilege.)

## 11. Time-Series with Partitioning

```sql
CREATE TABLE events (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    event_type TEXT NOT NULL,
    data JSONB,
    created_at TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (created_at);

-- Monthly partitions
CREATE TABLE events_2025_01 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE events_2025_02 PARTITION OF events
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- BRIN index for time-ordered data (tiny, effective for append-only)
CREATE INDEX idx_events_brin ON events USING BRIN (created_at);

-- Drop old data instantly (vs DELETE which generates dead tuples)
DROP TABLE events_2025_01;
```

**Rule**: Queries SHOULD include a predicate on the partition key (`created_at`) so the planner can prune partitions at plan time. Without it, PostgreSQL scans all partitions — runtime (execution-time) pruning only helps for parameterized values and join keys.

## 12. UPSERT (INSERT ON CONFLICT)

```sql
-- Insert or update a single row
INSERT INTO user_settings (user_id, key, value, updated_at)
VALUES (:user_id, :key, :value, now())
ON CONFLICT (user_id, key) DO UPDATE SET
    value = EXCLUDED.value,
    updated_at = EXCLUDED.updated_at;
```

**Pitfall**: `ON CONFLICT` requires a unique constraint or unique index on the conflict target columns. Without it, PostgreSQL raises an error.

```sql
-- Insert-only if not exists (no update on conflict)
INSERT INTO user_accounts (email, name)
VALUES ('user@example.com', 'New User')
ON CONFLICT (email) DO NOTHING;

-- Return the row whether inserted or existing.
-- DO NOTHING returns NO row on conflict, so DO UPDATE is required for RETURNING to
-- fire. But this is NOT a free no-op: it writes a new row version on every conflict
-- (WAL, dead tuple, row lock, fires UPDATE triggers) even when the value is identical.
-- For hot, high-conflict rows, prefer DO NOTHING + a follow-up SELECT.
INSERT INTO tags (name) VALUES ('postgresql')
ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name  -- writes a row version
RETURNING id, name;
```

## 13. Window Functions

Window functions compute values across a set of rows related to the current row without collapsing them into a single output row (unlike GROUP BY).

### Top-N Per Group
```sql
-- Latest 3 orders per user
SELECT * FROM (
    SELECT o.*,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
    FROM orders o
) sub
WHERE rn <= 3;
```

### Running Total
```sql
SELECT id, amount,
    SUM(amount) OVER (ORDER BY created_at) AS running_total
FROM payments
WHERE user_id = :user_id;
```

### Compare to Previous Row
```sql
-- Revenue change from previous day
SELECT
    day,
    revenue,
    revenue - LAG(revenue) OVER (ORDER BY day) AS daily_change,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY day))
        / NULLIF(LAG(revenue) OVER (ORDER BY day), 0), 2) AS pct_change
FROM mv_daily_revenue;
```

### Ranking with Ties
```sql
-- RANK: same rank for ties, gaps after (1, 1, 3)
-- DENSE_RANK: same rank for ties, no gaps (1, 1, 2)
SELECT name, score,
    RANK() OVER (ORDER BY score DESC) AS rank,
    DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rank
FROM leaderboard_entries;
```

## 14. DISTINCT ON (PostgreSQL-Specific)

Returns one row per group — simpler than window function + subquery when you only need the first match.

```sql
-- Latest order per user (single query, no subquery)
SELECT DISTINCT ON (user_id) *
FROM orders
ORDER BY user_id, created_at DESC;
```

`ORDER BY` must start with the `DISTINCT ON` columns. PostgreSQL picks the first row per group according to that ordering.

```sql
-- Most recent login per user, only active users
SELECT DISTINCT ON (u.id) u.id, u.name, l.logged_in_at
FROM user_accounts u
JOIN logins l ON l.user_id = u.id
WHERE u.status = 'active'
ORDER BY u.id, l.logged_in_at DESC;
```

## 15. Conditional Aggregation

### FILTER Clause (PG 9.4+)
```sql
-- Count orders by status in a single pass
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE status = 'pending') AS pending,
    COUNT(*) FILTER (WHERE status = 'completed') AS completed,
    SUM(total) FILTER (WHERE status = 'completed') AS completed_revenue
FROM orders
WHERE created_at > now() - interval '30 days';
```

### CASE-Based Aggregation (portable alternative)
```sql
SELECT
    date_trunc('month', created_at) AS month,
    SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END) AS credits,
    SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END) AS debits
FROM transactions
GROUP BY 1
ORDER BY 1;
```

## 16. Date Gap-Filling with generate_series

Time-series queries often have missing intervals. `generate_series` fills them.

```sql
-- Daily revenue including days with zero orders
SELECT
    d.day,
    COALESCE(SUM(o.total), 0) AS revenue,
    COUNT(o.id) AS order_count   -- COUNT returns 0 (not NULL) for empty groups
FROM generate_series(
    date_trunc('day', now() - interval '30 days'),
    date_trunc('day', now()),
    interval '1 day'
) AS d(day)
LEFT JOIN orders o ON date_trunc('day', o.created_at) = d.day
    AND o.status = 'completed'
GROUP BY d.day
ORDER BY d.day;
```

Also works for hourly, weekly, monthly:
```sql
-- Hourly signups (last 24 hours)
SELECT h.hour, COUNT(u.id) AS signups
FROM generate_series(
    date_trunc('hour', now() - interval '24 hours'),
    date_trunc('hour', now()),
    interval '1 hour'
) AS h(hour)
LEFT JOIN user_accounts u ON date_trunc('hour', u.created_at) = h.hour
GROUP BY h.hour
ORDER BY h.hour;
```

## 17. Efficient Filtering Patterns

### Filter Early with CTEs
```sql
-- Reduce intermediate data before joining
WITH recent_orders AS (
    SELECT id, user_id, total FROM orders
    WHERE created_at > now() - interval '30 days'
),
target_products AS (
    SELECT id FROM products WHERE category = 'electronics'
)
SELECT ro.id, ro.total
FROM recent_orders ro
JOIN order_items oi ON oi.order_id = ro.id
JOIN target_products tp ON tp.id = oi.product_id;
```

### EXISTS vs IN vs JOIN
```sql
-- EXISTS: stops at first match (good when you only need boolean check)
SELECT * FROM user_accounts u
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id AND o.status = 'pending');

-- IN: good for small subquery results
SELECT * FROM products WHERE category_id IN (SELECT id FROM categories WHERE name = 'Electronics');

-- JOIN: when you need columns from both tables
SELECT u.name, o.total
FROM user_accounts u
JOIN orders o ON o.user_id = u.id;
```
