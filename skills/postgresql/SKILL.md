---
name: postgresql
description: |
  PostgreSQL query writing, optimization, and production problem-solving patterns.
  Implements schemas designed by database-design skill with correct query patterns.
  Use when: writing SELECT/INSERT/UPDATE/DELETE queries, optimizing slow queries,
  debugging EXPLAIN plans, implementing pagination, full-text search, bulk operations,
  window functions, UPSERT, DISTINCT ON, conditional aggregation, time-series gap-filling,
  concurrency control, zero-downtime migrations, connection pooling, VACUUM strategy,
  batched backfills, pg_stat_statements setup, or any PostgreSQL query-level work.
  Do NOT use for: schema design or data modeling (use database-design skill first),
  basic SQL syntax lookup (use a docs lookup).
---

# PostgreSQL Query & Optimization Skill

Focuses on writing correct, performant queries and solving production PostgreSQL problems against an established schema.

## Core Principles

### 1. Design First, Query Second
This skill operates on an existing schema. It assumes:
- Naming follows snake_case convention (tables plural, FKs singular as `referenced_table_id`)
- PKs are `UUID` v7 (`DEFAULT uuidv7()`, PG18+; generated at the app layer pre-18) by default — `BIGINT GENERATED ALWAYS AS IDENTITY` only for high-volume internal tables (events, audit logs, metrics) where the 8-byte savings measurably matter. Inherited from the database-design skill's PK decision
- All tables have `created_at` and `updated_at` (TIMESTAMPTZ)
- Columns ordered largest-to-smallest for alignment optimization
- FK columns are indexed (PostgreSQL does NOT auto-index FKs)

### 2. Measure Before Optimizing
Never optimize without evidence. Always:
1. Run `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` on the actual query
2. Identify the bottleneck (Seq Scan, Filter vs Index Cond, Sort, high buffer reads)
3. Apply the targeted fix
4. Verify with EXPLAIN again

### 3. Match Index to Query Pattern
Indexes are only useful when query WHERE/ORDER BY matches index structure exactly.
Consult `references/indexing-pitfalls.md` for common mismatches.

### 4. Keep Resultsets Reasonable
As a rule of thumb, aim for under ~10,000 rows returned (the practical limit depends on row width and the client) — use LIMIT, keyset pagination, or encourage filtering from the application layer. Consult `references/query-patterns.md` for patterns.

## Workflow: When Writing Queries

### Step 1: Understand the Access Pattern
- Which columns are filtered (WHERE)?
- Which columns are sorted (ORDER BY)?
- How many rows expected in result?
- Read frequency vs write frequency?
- Concurrent access patterns?

### Step 2: Write the Query
- SELECT only needed columns (never `SELECT *` in production)
- Filter early to reduce intermediate data volume
- Use CTEs for readability. Since PG12, CTEs referenced once are automatically inlined (optimized like subqueries). Use `MATERIALIZED` to force materialization (useful as an optimization fence), or `NOT MATERIALIZED` to force inlining even when referenced multiple times
- Use appropriate JOIN type and ensure join columns are indexed
- Consult `references/query-patterns.md` for pattern-specific guidance

### Step 3: Verify with EXPLAIN
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;
```
Consult `references/explain-guide.md` for reading plans.

Key checks:
- No Seq Scan on large tables (unless intentional full-table operation)
- Index Cond covers all filter columns (no leftover Filter step)
- Rows estimated ≈ actual (if not, run ANALYZE)
- No external Sort (add index or increase work_mem)

### Step 4: Index Strategy
→ Consult `references/indexing-pitfalls.md`
- Composite index column order: equality first → range next → sort last
- Partial index for low-selectivity columns (boolean, status)
- Covering index (INCLUDE) for index-only scans
- Expression index for function-based filters

### Step 5: Production Readiness
→ Consult `references/production-ops.md`
- Connection pooling configured
- VACUUM/ANALYZE strategy in place
- Monitoring for slow queries and lock contention
- **Standing guards**: `pg_stat_statements` always on; `auto_explain` (or `log_min_duration_statement`) capturing the actual plans of slow queries — aggregates tell you *which* query regressed, auto_explain tells you *why*
- `scripts/query_diagnostics.sql` (slow queries, locks, bloat, vacuum lag, stale stats) — run **weekly and during every incident**, not just when something feels slow

## Quick Decision Table

| Problem | Solution | Reference |
|---------|----------|-----------|
| Deep pagination | Keyset/cursor pagination | `references/query-patterns.md` |
| Full-text search | tsvector + GIN index | `references/query-patterns.md` |
| N+1 queries | JSON aggregation or LATERAL join | `references/query-patterns.md` |
| Slow query | EXPLAIN ANALYZE → targeted index | `references/explain-guide.md` |
| Index not used | Check pitfalls (order, collation, stats) | `references/indexing-pitfalls.md` |
| High contention | SKIP LOCKED / advisory locks / batching | `references/query-patterns.md` |
| Schema migration | NOT VALID + VALIDATE / CONCURRENTLY | `references/production-ops.md` |
| Bulk import | COPY + staging table | `references/query-patterns.md` |
| Caching aggregates | Materialized views | `references/query-patterns.md` |
| Multi-tenant | Row-level security | `references/query-patterns.md` |
| Hierarchical data | Recursive CTE with depth limit | `references/query-patterns.md` |
| JSONB queries | GIN or expression index | `references/query-patterns.md` |
| Concurrent edits | Optimistic locking (version column) | `references/query-patterns.md` |
| Upsert / merge | INSERT ON CONFLICT | `references/query-patterns.md` |
| Top-N per group | Window function + DISTINCT ON | `references/query-patterns.md` |
| Running totals | SUM() OVER (ORDER BY) | `references/query-patterns.md` |
| Pivot / crosstab | Conditional aggregation (FILTER) | `references/query-patterns.md` |
| Missing time intervals | generate_series + LEFT JOIN | `references/query-patterns.md` |
| Stale planner stats | ANALYZE after bulk operations | `references/production-ops.md` |
| pg_stat_statements setup | Extension + config | `references/production-ops.md` |
| Too many connections / pool sizing | PgBouncer transaction pooling | `references/production-ops.md` |
| Table bloat / dead tuples | Autovacuum tuning + VACUUM | `references/production-ops.md` |

## Critical Rules

- **Specify columns in SELECT** — `SELECT *` fetches unnecessary data, breaks index-only scans, and couples code to schema changes
- **EXPLAIN before and after optimization** — guessing at performance is unreliable; measure with `EXPLAIN (ANALYZE, BUFFERS)` to confirm the plan changed
- **Composite index order: equality → range → sort** — PostgreSQL uses composite indexes left-to-right. Once a range condition is hit, subsequent columns are less effective (leftmost prefix rule). See `references/indexing-pitfalls.md`
- **Partial index WHERE must match query WHERE exactly** — PostgreSQL won't infer that your application logic guarantees the condition
- **Run ANALYZE after bulk operations** — the planner relies on row-count statistics; stale stats after large INSERT/UPDATE/DELETE cause it to pick wrong plans
- **Index FK columns** — PostgreSQL does not auto-index foreign keys. Missing FK indexes cause slow CASCADE deletes and slow joins
- **TIMESTAMPTZ over TIMESTAMP** — bare TIMESTAMP loses timezone context and breaks across timezones (inherited from database-design)
- **NUMERIC for money, not FLOAT** — floating-point arithmetic introduces rounding errors in financial calculations (inherited from database-design)
- **Keyset pagination over OFFSET** — OFFSET scans and discards skipped rows (cost grows with page depth); keyset seeks directly via the index. See `references/query-patterns.md`
- **CONCURRENTLY for production indexes** — `CREATE INDEX` without CONCURRENTLY takes a write lock on the entire table, blocking inserts/updates until done
- **`SET lock_timeout` before any production DDL** — even "safe" DDL takes a brief ACCESS EXCLUSIVE lock; if it queues behind a long transaction, **every subsequent query on that table queues behind it** — the classic migration outage. Fail fast and retry instead (see `references/production-ops.md` § Migration Session Preamble)
- **Use PROCEDURE for batched backfills** — DO blocks run in a single transaction and cannot COMMIT between batches; use `CREATE PROCEDURE` + `CALL` for incremental commits (see `references/production-ops.md`)

## Recent Postgres Versions (use when available)

| Version | Released | Notable additions |
|---|---|---|
| **PG 18** | 2025-09-25 | Built-in `uuidv7()`; async I/O improvements; `EXPLAIN ANALYZE` includes `BUFFERS` by default; explicit `uuidv4()` alias (UUIDv4 already available via `gen_random_uuid()` since PG 13) |
| **PG 17** | 2024-09 | `MERGE ... RETURNING`; `JSON_TABLE`; incremental sort improvements; faster `vacuum` |
| **PG 16** | 2023-09 | `pg_stat_io` (per-IO-type stats — complements per-query `BUFFERS`); logical decoding on standby; parallel apply of large transactions |
| **PG 15** | 2022-10 | `MERGE` statement |

Practical implications:
- Prefer `uuidv7()` (PG 18) over app-generated UUIDv4 for new primary keys — better B-tree clustering.
- For diagnostics on PG 16+, supplement `EXPLAIN (BUFFERS)` with `pg_stat_io` for per-backend / per-IO-type breakdown.
- `JSON_TABLE` (PG 17) replaces ad-hoc JSONB-to-rows lateral joins for many use cases.
- **PgBouncer 1.21+ supports prepared statements in transaction mode** — earlier prohibitions ("PgBouncer breaks prepared statements") no longer apply post-1.21.

### DDL portability (PG18 vs ≤PG17)

When generating UUID-keyed DDL, default to PG 18 (`DEFAULT uuidv7()`). For PG 17 and below, **generate UUIDv7 at the application layer** and pass it into INSERT (no column DEFAULT) — that preserves the time-ordered B-tree locality the PK decision is built on. `gen_random_uuid()` (UUIDv4, core since PG 13) is acceptable **only for low-volume/low-write tables**: random v4 fragments hot B-trees (the database-design skill's Critical Rule).

```sql
-- PG 18+ (preferred)
id UUID PRIMARY KEY DEFAULT uuidv7()

-- PG 17 and below (preferred): no DEFAULT; app generates UUIDv7
id UUID PRIMARY KEY

-- PG 17 and below, low-write tables only (UUIDv4 — random, fragments hot B-trees)
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
```
