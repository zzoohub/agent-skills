-- ============================================
-- PostgreSQL Query Performance Diagnostic Script
-- Run against your database to identify query-level issues
-- ============================================

-- 1. Slowest queries by average execution time (pg_stat_statements)
-- pg_stat_statements has NO per-node "rows removed by filter" metric. To find
-- non-selective-index queries, run EXPLAIN (ANALYZE) on the statements below and
-- look for "Rows Removed by Filter".
-- Requires pg_stat_statements extension
SELECT
    queryid,
    calls,
    ROUND(mean_exec_time::NUMERIC, 2) AS avg_ms,
    rows AS avg_rows_returned,
    LEFT(query, 150) AS query_preview
FROM pg_stat_statements
WHERE calls > 50
AND mean_exec_time > 100  -- over 100ms average
ORDER BY mean_exec_time DESC
LIMIT 20;

-- 2. Tables with poor HOT update ratio (updates hit indexed columns, OR pages lack
--    free space — consider dropping indexes on hot columns OR lowering fillfactor)
SELECT
    schemaname, relname,
    n_tup_upd AS total_updates,
    n_tup_hot_upd AS hot_updates,
    ROUND(100.0 * n_tup_hot_upd / NULLIF(n_tup_upd, 0), 2) AS hot_pct
FROM pg_stat_user_tables
WHERE n_tup_upd > 1000
ORDER BY hot_pct ASC
LIMIT 20;

-- 3. FK constraints without a usable supporting index (slow CASCADE and JOIN)
-- An index helps FK maintenance only when the FK column(s) form a LEADING prefix of
-- the index key. A non-leading position (e.g. FK (b) under an index on (a, b)) does
-- NOT count. This compares the full ordered conkey against each index's leading cols.
SELECT
    c.conrelid::regclass AS table_name,
    c.conname AS constraint_name,
    (SELECT string_agg(a.attname, ', ' ORDER BY x.ord)
       FROM unnest(c.conkey) WITH ORDINALITY AS x(attnum, ord)
       JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = x.attnum) AS fk_columns
FROM pg_constraint c
WHERE c.contype = 'f'
AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid
    -- leading index columns (1-based after normalizing the int2vector) must equal conkey
    AND (string_to_array(i.indkey::text, ' ')::int2[])[1:array_length(c.conkey, 1)] = c.conkey
)
ORDER BY table_name, constraint_name;

-- 4. Unused indexes (wasting storage and slowing writes)
-- idx_scan is cumulative since the last stats reset — trust 0 only over a representative
-- window (check stats_reset in pg_stat_database; PG16+ has last_idx_scan for recency).
SELECT
    s.schemaname, s.relname AS tablename, s.indexrelname AS indexname,
    s.idx_scan AS times_used,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size
FROM pg_stat_user_indexes s
JOIN pg_index ix ON ix.indexrelid = s.indexrelid
WHERE s.idx_scan = 0
-- never drop what enforces uniqueness or feeds logical replication
AND NOT ix.indisunique
AND NOT ix.indisprimary
AND NOT ix.indisreplident
AND s.indexrelid NOT IN (
    SELECT conindid FROM pg_constraint WHERE contype IN ('p', 'u')
)
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 20;

-- 5. Tables needing VACUUM (high dead tuple ratio)
SELECT
    schemaname, relname,
    n_live_tup, n_dead_tup,
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
    last_vacuum, last_autovacuum,
    last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;

-- 6. Invalid indexes (from failed CONCURRENTLY operations)
SELECT
    n.nspname AS schema_name,
    c.relname AS index_name,
    i.indisvalid AS is_valid
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT i.indisvalid;

-- 7. Table and index sizes (find bloat candidates)
SELECT
    t.schemaname, t.tablename,
    pg_size_pretty(pg_total_relation_size(format('%I.%I', t.schemaname, t.tablename))) AS total_size,
    pg_size_pretty(pg_relation_size(format('%I.%I', t.schemaname, t.tablename))) AS table_size,
    pg_size_pretty(
        pg_total_relation_size(format('%I.%I', t.schemaname, t.tablename)) -
        pg_relation_size(format('%I.%I', t.schemaname, t.tablename))
    ) AS index_size
FROM pg_tables t
WHERE t.schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(format('%I.%I', t.schemaname, t.tablename)) DESC
LIMIT 20;

-- 8. Cache hit ratio per table (identify cold tables)
SELECT
    schemaname, relname,
    heap_blks_hit, heap_blks_read,
    ROUND(
        100.0 * heap_blks_hit / NULLIF(heap_blks_hit + heap_blks_read, 0), 2
    ) AS cache_hit_pct
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 100
ORDER BY cache_hit_pct ASC
LIMIT 20;

-- 9. Per-column distinct fraction (rough index-candidate selectivity, from pg_stats)
-- Both branches yield distinct_values / row_count: when n_distinct > 0 it is an
-- absolute count (divide by reltuples); when < 0 it is already that fraction (abs).
-- Higher = more distinct values = better B-tree candidate. These are planner ESTIMATES.
SELECT
    s.schemaname, s.tablename, s.attname AS column_name,
    s.n_distinct,
    CASE
        WHEN s.n_distinct > 0 THEN ROUND((s.n_distinct / c.reltuples)::NUMERIC, 6)
        WHEN s.n_distinct < 0 THEN ROUND(abs(s.n_distinct)::NUMERIC, 6)
        ELSE 0
    END AS distinct_fraction
FROM pg_stats s
JOIN pg_namespace nsp ON nsp.nspname = s.schemaname
JOIN pg_class c ON c.relname = s.tablename AND c.relnamespace = nsp.oid
WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema')
AND c.reltuples > 0
ORDER BY s.tablename, distinct_fraction DESC;

-- 10. Long-running active queries
SELECT
    pid,
    now() - query_start AS duration,
    state,
    wait_event_type,
    wait_event,
    LEFT(query, 120) AS query
FROM pg_stat_activity
WHERE state = 'active'
AND query_start < now() - interval '30 seconds'
ORDER BY duration DESC;
