# PostgreSQL Production Operations

Patterns for running PostgreSQL reliably in production.

For runnable diagnostic queries against a live database (slowest queries, lock waits, bloat, vacuum lag, stale planner stats), see `scripts/query_diagnostics.sql` — psql-ready queries you can execute directly.

## Table of Contents

1. [Zero-Downtime Migrations](#1-zero-downtime-migrations)
2. [Backfilling Large Tables](#2-backfilling-large-tables)
3. [VACUUM & ANALYZE Strategy](#3-vacuum--analyze-strategy)
4. [Connection Pooling](#4-connection-pooling)
5. [Index Maintenance](#5-index-maintenance)
6. [PostgreSQL Configuration Tuning](#6-postgresql-configuration-tuning)
7. [Enabling pg_stat_statements](#7-enabling-pg_stat_statements)
8. [Monitoring Checklist](#8-monitoring-checklist)

## 1. Zero-Downtime Migrations

Lock-safe execution of schema changes against live traffic lives in `references/migration-patterns.md` (the single source): the **Migration Session Preamble** (`lock_timeout` + `statement_timeout`, one DDL step per short transaction, retry on SQLSTATE `55P03`, finding the blocker, the execution runbook), `CREATE INDEX CONCURRENTLY` plus the invalid-index check and drop-then-retry, `NOT VALID` → `VALIDATE CONSTRAINT` for CHECK / FK / NOT NULL (including the PG18+ `NOT NULL ... NOT VALID` path), and expand-contract renames.

## 2. Backfilling Large Tables

See `references/migration-patterns.md` § Large Table Migrations: commit per batch (a `PROCEDURE` + `CALL`, a top-level `DO` with `COMMIT`, or an app-side loop — never inside the migration tool's wrapping transaction), walk a primary-key keyset with an idempotent `IS NULL` recheck, no `FOR UPDATE` / `SKIP LOCKED`, throttle with `pg_sleep` and against `pg_stat_replication.replay_lag`, and finish with `ANALYZE`.

## 3. VACUUM & ANALYZE Strategy

### Why It Matters
- VACUUM reclaims dead tuples (from UPDATE/DELETE)
- ANALYZE refreshes planner statistics (row counts, value distribution)
- Without VACUUM: table/index bloat grows indefinitely
- Without ANALYZE: planner makes wrong decisions (Seq Scan instead of Index Scan)

### Monitor Dead Tuples
```sql
SELECT
    schemaname, relname,
    n_live_tup, n_dead_tup,
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
    last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

### Per-Table Autovacuum Tuning (for hot tables)
```sql
-- More aggressive vacuum for frequently updated tables
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.05,   -- trigger at 5% dead tuples (default 20%)
    autovacuum_analyze_scale_factor = 0.02,  -- re-analyze at 2% changes
    autovacuum_vacuum_cost_delay = 2         -- less throttling
);
```

### When to Run Manual ANALYZE
- After bulk INSERT, UPDATE, or DELETE
- After creating new indexes
- When EXPLAIN shows row estimate ≠ actual (stale stats)

```sql
ANALYZE orders;           -- specific table
ANALYZE;                   -- entire database (use sparingly)
```

## 4. Connection Pooling

PgBouncer configuration, pool modes, what transaction pooling breaks (session `SET`, session-level advisory locks, `LISTEN`/`NOTIFY`, protocol-level prepared statements on PgBouncer < 1.21 or with `max_prepared_statements = 0`), and pool sizing against `max_connections`: see `references/performance-patterns.md` §3.

## 5. Index Maintenance

Finding unused indexes (excluding PK / UNIQUE / replica-identity indexes), rebuilding bloated indexes with `REINDEX INDEX CONCURRENTLY`, and index sizes: see `references/indexing-strategy.md` § Index Maintenance and `scripts/query_diagnostics.sql` (#4 unused indexes, #6 invalid indexes, #7 sizes).

## 6. PostgreSQL Configuration Tuning

Memory parameters (`shared_buffers`, `work_mem`, `maintenance_work_mem`, `effective_cache_size`), the cache-hit-ratio check, and WAL settings for high-write loads: see `references/performance-patterns.md` §2.

## 7. Enabling pg_stat_statements

Several diagnostic queries in this skill rely on `pg_stat_statements`. It's not enabled by default.

```sql
-- 1. Add to postgresql.conf (requires restart)
-- shared_preload_libraries = 'pg_stat_statements'

-- 2. Create the extension (no restart needed after library is loaded)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 3. Verify it's working
SELECT count(*) FROM pg_stat_statements;
```

Key settings (postgresql.conf):
```ini
pg_stat_statements.max = 5000          # max tracked statements (default 5000)
pg_stat_statements.track = top         # track top-level statements only (default)
pg_stat_statements.track_utility = on  # track utility commands (CREATE, ALTER, etc.)
```

On managed PostgreSQL services (RDS, Cloud SQL, Neon, Supabase), this extension is usually pre-installed — you just need `CREATE EXTENSION`.

```sql
-- Reset statistics (useful after deploying query changes)
SELECT pg_stat_statements_reset();
```

### auto_explain — capture the plan, not just the aggregate

`pg_stat_statements` tells you *which* query regressed; `auto_explain` logs the *actual plan* of the slow execution — the difference between knowing and guessing during an incident:

```ini
shared_preload_libraries = 'pg_stat_statements,auto_explain'
auto_explain.log_min_duration = '500ms'   # log plans for anything slower
auto_explain.log_analyze = on             # include actual rows/timing
auto_explain.log_buffers = on
auto_explain.sample_rate = 1.0            # lower (e.g. 0.1) on very hot systems — log_analyze adds overhead
```

At minimum, set `log_min_duration_statement = '1s'` so slow statements land in the log even without the module.

## 8. Monitoring Checklist

| What to Monitor | Query / Tool | Threshold |
|-----------------|-------------|-----------|
| Cache hit ratio | `pg_stat_database` | > 99% |
| Dead tuple ratio | `pg_stat_user_tables` | < 10% per table |
| Unused indexes | `pg_stat_user_indexes` | Drop if idx_scan = 0 |
| Long-running transactions | `pg_stat_activity` | Alert > 5 min |
| Lock contention | `pg_locks` + `pg_stat_activity` | Alert on blocking > 30s |
| Slow queries | `pg_stat_statements` | Investigate top 10 by avg_ms |
| Connection count | `pg_stat_activity` | Alert at 80% of max_connections |
| WAL generation rate | `pg_stat_wal` (PG14+) | Baseline + alert on spikes |
| Replication lag | `pg_stat_replication` (`replay_lag`) | Alert past what read-after-write flows tolerate; throttle backfills against it |
| Idle-in-transaction sessions | `pg_stat_activity` (`state = 'idle in transaction'`) | Alert > 5 min — they block VACUUM, `VALIDATE`, and DDL; set `idle_in_transaction_session_timeout` as the backstop |

Run `scripts/query_diagnostics.sql` weekly and during every incident — point-in-time reads of these same signals, plus FK/index/bloat checks.
