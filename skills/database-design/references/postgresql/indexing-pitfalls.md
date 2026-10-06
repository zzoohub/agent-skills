# PostgreSQL Indexing Pitfalls

Real-world scenarios where indexes are ignored or used inefficiently, and how to fix them.

## Table of Contents

1. [Pitfall 1: Partial Index Not Used — Query Doesn't Match Exactly](#pitfall-1-partial-index-not-used--query-doesnt-match-exactly)
2. [Pitfall 2: Composite Index Column Order Mismatch](#pitfall-2-composite-index-column-order-mismatch)
3. [Pitfall 3: Index Not Selective Enough — Filter Instead of Index Cond](#pitfall-3-index-not-selective-enough--filter-instead-of-index-cond)
4. [Pitfall 4: LIKE Query Ignored Due to Collation](#pitfall-4-like-query-ignored-due-to-collation)
5. [Pitfall 5: Mixed-Direction ORDER BY Forces a Sort](#pitfall-5-mixed-direction-order-by-forces-a-sort)
6. [Pitfall 6: FK DELETE Slow — Missing Index on the Referencing (Child FK) Column](#pitfall-6-fk-delete-slow--missing-index-on-the-referencing-child-fk-column)
7. [Pitfall 7: Overindexing Kills HOT Updates](#pitfall-7-overindexing-kills-hot-updates)
8. [Pitfall 8: Index Ignored After Bulk DELETE — Stale Statistics](#pitfall-8-index-ignored-after-bulk-delete--stale-statistics)
9. [Pitfall 9: Index-Only Scan Slow — Index Bloat](#pitfall-9-index-only-scan-slow--index-bloat)
10. [Pitfall 10: Function in WHERE Without Expression Index](#pitfall-10-function-in-where-without-expression-index)
11. [Index Selection Cheat Sheet](#index-selection-cheat-sheet)

## Pitfall 1: Partial Index Not Used — Query Doesn't Match Exactly

```sql
-- Index
CREATE INDEX idx_files_zero ON files (size) WHERE size = 0 AND file_hash IS NULL;

-- ❌ NOT USED: query doesn't include file_hash IS NULL
SELECT * FROM files WHERE size = 0;

-- ✅ USED: query matches index WHERE clause exactly
SELECT * FROM files WHERE size = 0 AND file_hash IS NULL;
```

**Rule**: The query's WHERE must provably imply the partial index's predicate — in practice, repeat the predicate literally in the query. PostgreSQL proves only simple implications (`x < 1` ⇒ `x < 2`; a strict comparison such as `col = $1` ⇒ `col IS NOT NULL`); it will not infer that `file_hash IS NULL` is always true when `size = 0`, even if your data guarantees it. Matching happens at plan time, so a parameterized clause (`size = $1`) never matches a literal predicate (`WHERE size = 0`).

## Pitfall 2: Composite Index Column Order Mismatch

```sql
-- Index (wrong order for this query)
CREATE INDEX idx_logs_time_user ON logs (created_at, user_id);

-- Query
SELECT * FROM logs WHERE user_id = 42 AND created_at > now() - interval '1 day';
```

PostgreSQL uses composite indexes left-to-right. Once it hits a range condition, subsequent columns are less effective.

**Rule**: Equality conditions first → Range conditions next → Sort columns last.

**PG18+ caveat**: B-tree skip scan lets the planner use an index whose leading column is unrestricted (or only range-restricted) when later columns are restricted — it probes each distinct leading value, so it pays off only when that leading column has few distinct values. Treat it as a safety net, not a reason to keep the wrong order.

```sql
-- ✅ Correct order
CREATE INDEX idx_logs_user_time ON logs (user_id, created_at);
```

## Pitfall 3: Index Not Selective Enough — Filter Instead of Index Cond

```sql
-- Index on only one column
CREATE INDEX idx_downloads_user ON downloads (user_id);

-- Query filters on two columns
SELECT * FROM downloads WHERE user_id = 42 AND download_status = 'complete';
```

EXPLAIN shows:
```
Index Scan using idx_downloads_user
  Index Cond: (user_id = 42)
  Filter: (download_status = 'complete')    -- ← wasteful
  Rows Removed by Filter: 3847             -- ← wasted I/O
```

**Fix**: Composite index covering both filter columns:
```sql
CREATE INDEX idx_downloads_user_status ON downloads (user_id, download_status);
```

**Rule**: If EXPLAIN shows `Filter` + `Rows Removed by Filter`, the index is incomplete. All WHERE conditions should appear in `Index Cond`.

## Pitfall 4: LIKE Query Ignored Due to Collation

```sql
-- B-tree index on text column with en_US.UTF-8 collation
CREATE INDEX idx_files_path ON files (path);

-- ❌ NOT USED with locale-aware collation
SELECT * FROM files WHERE path LIKE '/media/photos/2023/%';
```

PostgreSQL converts `LIKE 'prefix%'` to range comparison (`>= AND <`), but locale-aware collation (en_US.UTF-8) doesn't guarantee binary-consistent ordering.

**Fix options**:
```sql
-- Option 1: Specify C collation on the index
CREATE INDEX idx_files_path_c ON files (path COLLATE "C");
-- Query must also use: WHERE path COLLATE "C" LIKE '/media/photos/2023/%'

-- Option 2: Use text_pattern_ops operator class (varchar_pattern_ops /
-- bpchar_pattern_ops for varchar/char). Caveat: a pattern_ops index serves
-- prefix LIKE but is NOT used for ordinary = / range / ORDER BY under
-- locale-aware collations — keep a separate default-opclass index if those need one.
CREATE INDEX idx_files_path_pattern ON files (path text_pattern_ops);

-- Option 3: Set database default collation to "C" (if appropriate for your use case)
```

**Rule**: For LIKE 'prefix%' with B-tree, ensure collation allows binary-consistent comparison. A plain B-tree index already serves `LIKE 'prefix%'` when the column/database collation is `C` (or the built-in `C.UTF-8` / `pg_c_utf8` provider) — the special opclass is only needed under locale-aware (ICU/libc) collations.

## Pitfall 5: Mixed-Direction ORDER BY Forces a Sort

A single-direction (all-ASC) composite index already serves a **pure-DESC** ORDER BY on its trailing column via a **backward index scan** — no separate Sort node:

```sql
CREATE INDEX idx_items_cat_pub ON items (category, published_at);

-- ✅ Served by an "Index Scan Backward" (no Sort): for a given category the index
--    range is scanned in reverse to produce published_at DESC.
SELECT * FROM items WHERE category = 'books' ORDER BY published_at DESC LIMIT 10;
```

A per-column DESC index is only needed for **mixed-direction** sorts, where one all-ASC index cannot be backward-scanned to produce the requested order:

```sql
-- Needs explicit per-column direction (ASC then DESC can't both come from one scan)
CREATE INDEX idx_items_cat_pub_mixed ON items (category ASC, published_at DESC);
SELECT * FROM items ORDER BY category, published_at DESC LIMIT 10;
-- (Not with WHERE category = 'books': once category is fixed by equality its sort key is
--  constant, and the all-ASC index above serves the rest with a backward scan.)
```

## Pitfall 6: FK DELETE Slow — Missing Index on the Referencing (Child FK) Column

```sql
DELETE FROM regions WHERE id = 1;
```

Looks simple, but EXPLAIN ANALYZE reveals:
```
Trigger for constraint files_region_id_fkey: time=10244.000 calls=1
```

On DELETE, PostgreSQL validates referential integrity:
```sql
-- Internally executes:
SELECT 1 FROM files WHERE region_id = 1;
```

If `files.region_id` has no index → sequential scan for every DELETE.

**Fix**:
```sql
CREATE INDEX idx_files_region_id ON files (region_id);
```

**Rule**: Always index FK columns. PostgreSQL does NOT auto-index foreign keys. This affects both JOIN performance and CASCADE DELETE/UPDATE speed.

## Pitfall 7: Overindexing Kills HOT Updates

HOT (Heap-Only Tuple) updates skip index maintenance when:
- Updated columns are NOT part of any index
- New row version fits on the same page

If a frequently-updated column is indexed, every update must also update the index → slower writes, more bloat.

```sql
-- Check HOT update ratio
SELECT n_tup_upd, n_tup_hot_upd,
    ROUND(100.0 * n_tup_hot_upd / NULLIF(n_tup_upd, 0), 2) AS hot_pct
FROM pg_stat_all_tables
WHERE relname = 'your_table';
```

**Example**: Index on `modified_at` which is updated on every write:
```sql
-- Drop if only used for occasional admin queries
DROP INDEX idx_documents_modified_at;
```

**Rule**: Don't index columns that are updated frequently unless critical queries depend on it. Check HOT ratio for high-write tables.

## Pitfall 8: Index Ignored After Bulk DELETE — Stale Statistics

After large batch DELETE, PostgreSQL statistics become stale. The planner overestimates row count and chooses Seq Scan instead of Index Scan.

```sql
-- Check when last analyzed
SELECT relname, last_autoanalyze, last_analyze
FROM pg_stat_all_tables
WHERE relname = 'your_table';

-- Fix: refresh statistics
ANALYZE your_table;
```

**Rule**: Always run `ANALYZE` after bulk INSERT, UPDATE, or DELETE operations. Don't rely on autovacuum timing for immediate query plan correctness.

## Pitfall 9: Index-Only Scan Slow — Index Bloat

Index-only scan avoids table access but can be slow if the index itself is bloated (dead entries from deleted/updated rows).

```sql
-- Check index size
SELECT pg_size_pretty(pg_relation_size('your_index'));

-- Fix: clean up index
VACUUM (INDEX_CLEANUP ON) your_table;

-- Or rebuild (zero-downtime)
REINDEX INDEX CONCURRENTLY your_index;
```

## Pitfall 10: Function in WHERE Without Expression Index

```sql
-- ❌ Index on email is NOT used
SELECT * FROM user_accounts WHERE lower(email) = 'user@example.com';

-- ✅ Create expression index
CREATE INDEX idx_user_email_lower ON user_accounts (lower(email));
```

**Rule**: If WHERE clause applies a function to a column, you need an expression index on that same function call. The bare column index won't be used.

## Index Selection Cheat Sheet

| Query Pattern | Index Type | Example |
|---------------|-----------|---------|
| `WHERE col = value` | B-tree | `CREATE INDEX ON t (col)` |
| `WHERE col1 = ? AND col2 > ?` | B-tree composite | `CREATE INDEX ON t (col1, col2)` |
| `WHERE col LIKE 'prefix%'` | B-tree + text_pattern_ops ¹ | `CREATE INDEX ON t (col text_pattern_ops)` |
| `WHERE jsonb_col @> '{}'` | GIN | `CREATE INDEX ON t USING GIN (jsonb_col)` |
| `WHERE scalar_col = ANY(array)` (= IN-list) | B-tree | `CREATE INDEX ON t (scalar_col)` |
| `WHERE arr_col @> ARRAY[…]` / `&&` (array column) | GIN | `CREATE INDEX ON t USING GIN (arr_col)` |
| `WHERE func(col) = value` | Expression index | `CREATE INDEX ON t (func(col))` |
| `WHERE status = 'active'` | Partial index | `CREATE INDEX ON t (col) WHERE status = 'active'` |
| `WHERE ts > now() - '1 day'` (time-series) | BRIN ² | `CREATE INDEX ON t USING BRIN (ts)` |
| Covering for index-only scan | INCLUDE | `CREATE INDEX ON t (filter_col) INCLUDE (select_col)` |

¹ A `text_pattern_ops` index serves prefix `LIKE` but is **not** used for ordinary `=` / range / `ORDER BY` under locale-aware collations — keep a separate default-opclass index if those need one.
² BRIN only helps when `ts` is physically correlated with on-disk row order (append-only). Without that correlation use B-tree; B-tree is also better for small, highly selective recent windows.
