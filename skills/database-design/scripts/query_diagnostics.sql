-- PostgreSQL runtime diagnostics, for incidents and the weekly check (structure: schema_review.sql).
-- psql -X -f query_diagnostics.sql <conn>   Read-only; PostgreSQL 14+; also runs on a replica.
-- [pg_stat_statements] queries need the extension. Newer columns are read via to_jsonb(row), NULL
-- on older versions. Reading the results: references/postgresql/production-ops.md.

-- 1. Sessions by state and wait event. Lock waits -> 2. Many 'idle in transaction' -> 3.
--    'active' with no wait_event = CPU -> 6 (window it: which statements own the time, and did
--    their calls or their cost per call grow?). IO DataFileRead everywhere = the working set
--    outgrew memory, a plan flipped to a scan, or a call rate grew (6, by shared_blks_read).
SELECT state, wait_event_type, wait_event, count(*) AS sessions,
       max(now() - xact_start) AS oldest_xact,
       sum(count(*)) OVER () AS total_clients,
       current_setting('max_connections') AS max_connections
FROM pg_stat_activity
WHERE backend_type = 'client backend' AND pid <> pg_backend_pid()
GROUP BY 1, 2, 3
ORDER BY sessions DESC;

-- 2. Blocker tree. Terminate the ROOT blocker, never the queue behind it, and never an
--    anti-wraparound autovacuum: SELECT pg_terminate_backend(<pid>);
WITH w AS (SELECT pid, pg_blocking_pids(pid) AS blocked_by FROM pg_stat_activity)
SELECT a.pid, w.blocked_by,
       cardinality(w.blocked_by) = 0 AS root_blocker,
       (SELECT count(*) FROM w w2 WHERE a.pid = ANY (w2.blocked_by)) AS blocks_directly,
       a.backend_type, a.state, a.wait_event_type,
       now() - a.xact_start AS xact_age, left(a.query, 120) AS query
FROM w JOIN pg_stat_activity a USING (pid)
WHERE cardinality(w.blocked_by) > 0
   OR w.pid IN (SELECT unnest(blocked_by) FROM w)
ORDER BY root_blocker DESC, blocks_directly DESC, xact_age DESC NULLS LAST;

-- 3. Idle open transactions: they hold locks and pin the xmin horizon.
SELECT pid, usename, application_name,
       now() - xact_start AS xact_age, now() - state_change AS idle_for,
       left(query, 120) AS last_query
FROM pg_stat_activity
WHERE state IN ('idle in transaction', 'idle in transaction (aborted)')
ORDER BY xact_age DESC;

-- 4. xmin horizon holders: dead tuples newer than the oldest one survive every vacuum.
SELECT 'session' AS holder, pid::text AS id, age(backend_xmin) AS xmin_age,
       state || ': ' || left(query, 80) AS detail
FROM pg_stat_activity WHERE backend_xmin IS NOT NULL AND pid <> pg_backend_pid()
UNION ALL
SELECT 'replication slot', slot_name::text, greatest(age(xmin), age(catalog_xmin)),
       format('active=%s wal_status=%s retained_wal=%s', active, wal_status,
              CASE WHEN NOT pg_is_in_recovery()
                   THEN pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) END)
FROM pg_replication_slots
UNION ALL
SELECT 'prepared transaction', gid, age(transaction), 'prepared at ' || prepared
FROM pg_prepared_xacts
UNION ALL
SELECT 'standby feedback', application_name, age(backend_xmin), 'hot_standby_feedback from a replica'
FROM pg_stat_replication WHERE backend_xmin IS NOT NULL
ORDER BY xmin_age DESC NULLS LAST
LIMIT 20;

-- 5. Wraparound: alert at x_freeze_max >= 2 or pct_to_wraparound >= 47 (1 billion); page at 70.
--    Never cancel an anti-wraparound vacuum.
SELECT datname, age(datfrozenxid) AS xid_age, mxid_age(datminmxid) AS mxid_age,
       round(age(datfrozenxid)::numeric / current_setting('autovacuum_freeze_max_age')::numeric, 1)
           AS xid_x_freeze_max,
       round(mxid_age(datminmxid)::numeric
             / current_setting('autovacuum_multixact_freeze_max_age')::numeric, 1) AS mxid_x_freeze_max,
       round(100.0 * greatest(age(datfrozenxid), mxid_age(datminmxid)) / 2147483648, 1)
           AS pct_to_wraparound
FROM pg_database
ORDER BY greatest(age(datfrozenxid), mxid_age(datminmxid)) DESC;

SELECT c.oid::regclass AS table_name, age(c.relfrozenxid) AS xid_age,
       mxid_age(c.relminmxid) AS mxid_age, pg_size_pretty(pg_total_relation_size(c.oid)) AS size
FROM pg_class c
WHERE c.relkind IN ('r', 'm', 't')
ORDER BY age(c.relfrozenxid) DESC
LIMIT 10;

-- 6. [pg_stat_statements] Top statements by TOTAL time since the last reset; never reset to
--    "start clean". For what changed, use the window below.
SELECT queryid, calls,
       round(total_exec_time::numeric / 1000, 1) AS total_s,
       round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 1) AS pct_of_total,
       round(mean_exec_time::numeric, 2) AS mean_ms,
       rows / nullif(calls, 0) AS rows_per_call,
       shared_blks_read, temp_blks_written,
       left(query, 120) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
-- Window (it writes a snapshot table, so not on a replica; there, use the host's per-query
-- history): snapshot, wait through the incident or a normal period, then rank by share of the
-- window. Calls/s is demand, mean ms is cost per call; compare each with its before value
-- (calls_per_s_before needs PG17+, else run the same window over a normal period). Statements
-- new in the window show NULL before values.
--   CREATE TABLE pgss_t0 AS SELECT now() AS taken_at, * FROM pg_stat_statements;
--   WITH t0 AS (SELECT max(taken_at) AS at FROM pgss_t0),
--   d AS (
--       SELECT s.queryid, left(s.query, 100) AS query,
--              s.calls - coalesce(t.calls, 0) AS calls,
--              s.total_exec_time - coalesce(t.total_exec_time, 0) AS ms,
--              s.shared_blks_read - coalesce(t.shared_blks_read, 0) AS blks_read,
--              t.total_exec_time / nullif(t.calls, 0) AS mean_ms_before,
--              t.calls / nullif(extract(epoch FROM t.taken_at
--                  - (to_jsonb(t) ->> 'stats_since')::timestamptz), 0) AS calls_per_s_before
--       FROM pg_stat_statements s
--       LEFT JOIN pgss_t0 t USING (userid, dbid, toplevel, queryid))
--   SELECT queryid, round((100 * ms / nullif(sum(ms) OVER (), 0))::numeric, 1) AS pct_of_window,
--          round(calls_per_s_before::numeric, 2) AS calls_per_s_before,
--          round((calls / extract(epoch FROM now() - (SELECT at FROM t0)))::numeric, 2) AS calls_per_s,
--          round(mean_ms_before::numeric, 2) AS mean_ms_before,
--          round((ms / nullif(calls, 0))::numeric, 2) AS mean_ms, blks_read, query
--   FROM d WHERE calls > 0
--   ORDER BY ms DESC LIMIT 20;

-- 7. In flight: index builds (one 'waiting for ...' waits on current_locker_pid) and vacuums.
SELECT p.pid, p.relid::regclass AS table_name, p.index_relid::regclass AS index_name,
       p.command, p.phase, p.lockers_done || '/' || p.lockers_total AS lockers,
       p.current_locker_pid,
       round(100.0 * p.blocks_done / nullif(p.blocks_total, 0), 1) AS pct_blocks
FROM pg_stat_progress_create_index p;

SELECT v.pid, v.relid::regclass AS table_name, v.phase,
       round(100.0 * v.heap_blks_scanned / nullif(v.heap_blks_total, 0), 1) AS pct_scanned,
       v.index_vacuum_count, now() - a.xact_start AS running_for,
       a.query LIKE '%to prevent wraparound%' AS anti_wraparound
FROM pg_stat_progress_vacuum v
JOIN pg_stat_activity a USING (pid);

-- 8. Replica lag, on the primary.
SELECT application_name, client_addr, state, sync_state, write_lag, flush_lag, replay_lag,
       CASE WHEN NOT pg_is_in_recovery()
            THEN pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) END AS replay_gap
FROM pg_stat_replication;

-- 9. INVALID indexes, left by failed CONCURRENTLY builds (references/migration-patterns.md).
SELECT indexrelid::regclass AS index_name, indrelid::regclass AS table_name
FROM pg_index
WHERE NOT indisvalid;

-- 10. Vacuum and HOT per table; a high newpage_upd (PG16+) means full pages: lower fillfactor.
SELECT s.relid::regclass AS table_name, s.n_live_tup, s.n_dead_tup,
       s.last_autovacuum, s.autovacuum_count, s.n_mod_since_analyze, s.last_autoanalyze,
       s.n_tup_upd, round(100.0 * s.n_tup_hot_upd / nullif(s.n_tup_upd, 0), 1) AS hot_pct,
       (to_jsonb(s) ->> 'n_tup_newpage_upd')::bigint AS newpage_upd
FROM pg_stat_user_tables s
ORDER BY s.n_dead_tup DESC
LIMIT 20;
