# PostgreSQL Operations — Query Writing, Tuning & Production Problems

The HOW half of the database-design skill (SKILL.md is the WHAT: schema, index, and migration design). Covers writing correct, performant queries (pagination, full-text search, bulk operations, window functions, UPSERT, `DISTINCT ON`, conditional aggregation, time-series gap-filling), `EXPLAIN` tuning, concurrency control, connection pooling, VACUUM strategy, and `pg_stat_statements` diagnostics against an established schema. Lock-safe execution of migrations against live traffic (lock_timeout, `CONCURRENTLY`, `NOT VALID` → `VALIDATE`, batched backfills, expand-contract under load) lives in `references/migration-patterns.md`.

## Core Principles

### 1. Design First, Query Second
This part operates on an existing schema. It assumes:
- Naming follows snake_case convention (tables plural, FKs singular as `referenced_table_id`)
- PKs are `UUID` v7 (`DEFAULT uuidv7()`, PG18+; generated at the app layer pre-18) by default — `BIGINT GENERATED ALWAYS AS IDENTITY` only for high-volume internal tables (events, audit logs, metrics) where the 8-byte savings measurably matter. Inherited from SKILL.md → Primary Key Type Decision
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
Indexes are only useful when the query's WHERE/ORDER BY fits the index structure (column order, sort direction, indexed expression, partial-index predicate).
Consult `references/postgresql/indexing-pitfalls.md` for common mismatches.

### 4. Keep Resultsets Reasonable
As a rule of thumb, aim for under ~10,000 rows returned (the practical limit depends on row width and the client) — use LIMIT, keyset pagination, or encourage filtering from the application layer. Consult `references/postgresql/query-patterns.md` for patterns.

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
- Use CTEs for readability. Since PG12, a non-recursive, side-effect-free CTE (a plain `SELECT` with no volatile functions) referenced once is automatically inlined (optimized like a subquery); recursive and data-modifying CTEs are never inlined. Use `MATERIALIZED` to force materialization (useful as an optimization fence), or `NOT MATERIALIZED` to force inlining even when referenced multiple times
- Use appropriate JOIN type and ensure join columns are indexed
- Consult `references/postgresql/query-patterns.md` for pattern-specific guidance

### Step 3: Verify with EXPLAIN
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;
```
Consult `references/postgresql/explain-guide.md` for reading plans.

Key checks:
- No Seq Scan on large tables (unless intentional full-table operation)
- Index Cond covers all filter columns (no leftover Filter step)
- Rows estimated ≈ actual (if not, run ANALYZE)
- No external Sort (add index or increase work_mem)

### Step 4: Index Strategy
→ Consult `references/postgresql/indexing-pitfalls.md`
- Composite index column order: equality first → range next → sort last
- Partial index for low-selectivity columns (boolean, status)
- Covering index (INCLUDE) for index-only scans
- Expression index for function-based filters

### Step 5: Production Readiness
→ Consult `references/postgresql/production-ops.md`
- Connection pooling configured
- VACUUM/ANALYZE strategy in place
- Monitoring for slow queries and lock contention
- **Standing guards**: `pg_stat_statements` always on; `auto_explain` (or `log_min_duration_statement`) capturing the actual plans of slow queries — aggregates tell you *which* query regressed, auto_explain tells you *why*
- `scripts/query_diagnostics.sql` (slow queries, locks, bloat, vacuum lag, stale stats) — run **weekly and during every incident**, not just when something feels slow

## Quick Decision Table

| Problem | Solution | Reference |
|---------|----------|-----------|
| Deep pagination | Keyset/cursor pagination | `references/postgresql/query-patterns.md` |
| Full-text search | tsvector + GIN index | `references/postgresql/query-patterns.md` |
| N+1 queries | JSON aggregation or LATERAL join | `references/postgresql/query-patterns.md` |
| Slow query | EXPLAIN ANALYZE → targeted index | `references/postgresql/explain-guide.md` |
| Index not used | Check pitfalls (order, collation, stats) | `references/postgresql/indexing-pitfalls.md` |
| High contention | SKIP LOCKED / advisory locks / batching | `references/postgresql/query-patterns.md` |
| Schema migration | NOT VALID + VALIDATE / CONCURRENTLY | `references/migration-patterns.md` |
| Large backfill | Per-batch commits on a PK keyset | `references/migration-patterns.md` |
| Bulk import | COPY + staging table | `references/postgresql/query-patterns.md` |
| Caching aggregates | Materialized views | `references/postgresql/query-patterns.md` |
| Multi-tenant | Row-level security | `references/postgresql/query-patterns.md` |
| Hierarchical data | Recursive CTE with depth limit | `references/postgresql/query-patterns.md` |
| JSONB queries | GIN or expression index | `references/postgresql/query-patterns.md` |
| Concurrent edits | Optimistic locking (version column) | `references/postgresql/query-patterns.md` |
| Upsert / merge | INSERT ON CONFLICT | `references/postgresql/query-patterns.md` |
| Top-N per group | Window function + DISTINCT ON | `references/postgresql/query-patterns.md` |
| Running totals | SUM() OVER (ORDER BY) | `references/postgresql/query-patterns.md` |
| Pivot / crosstab | Conditional aggregation (FILTER) | `references/postgresql/query-patterns.md` |
| Missing time intervals | generate_series + LEFT JOIN | `references/postgresql/query-patterns.md` |
| Stale planner stats | ANALYZE after bulk operations | `references/postgresql/production-ops.md` |
| pg_stat_statements setup | Extension + config | `references/postgresql/production-ops.md` |
| Too many connections / pool sizing | PgBouncer transaction pooling | `references/performance-patterns.md` §3 |
| Table bloat / dead tuples | Autovacuum tuning + VACUUM | `references/postgresql/production-ops.md` |

## Critical Rules

- **Specify columns in SELECT** — `SELECT *` fetches unnecessary data, breaks index-only scans, and couples code to schema changes
- **EXPLAIN before and after optimization** — guessing at performance is unreliable; measure with `EXPLAIN (ANALYZE, BUFFERS)` to confirm the plan changed
- **Composite index order: equality → range → sort** — PostgreSQL uses composite indexes left-to-right. Once a range condition is hit, subsequent columns are less effective (leftmost prefix rule). PG18+ B-tree skip scan can use a later column when the leading column is unrestricted, but only pays off when that leading column has few distinct values — don't design for it. See `references/postgresql/indexing-pitfalls.md`
- **Partial index: the query's WHERE must provably imply the index predicate** — in practice, repeat the predicate literally. The planner proves only simple implications (`x < 1` ⇒ `x < 2`; a strict comparison on `col` ⇒ `col IS NOT NULL`), never your application logic, and matching happens at plan time — so a bound parameter (`status = $1`) never matches an index `WHERE status = 'active'`
- **Run ANALYZE after bulk operations** — the planner relies on row-count statistics; stale stats after large INSERT/UPDATE/DELETE cause it to pick wrong plans
- **SKILL.md's Critical Rules apply here too** — indexed FK columns, `TIMESTAMPTZ` over `TIMESTAMP`, `NUMERIC` (never FLOAT) for money, `CREATE INDEX CONCURRENTLY` on live tables
- **Keyset pagination over OFFSET** — OFFSET scans and discards skipped rows (cost grows with page depth); keyset seeks directly via the index. See `references/postgresql/query-patterns.md`
- **`SET lock_timeout` before any production DDL** — even "safe" DDL takes a brief ACCESS EXCLUSIVE lock; if it queues behind a long transaction, **every subsequent query on that table queues behind it** — the classic migration outage. Fail fast and retry instead (see `references/migration-patterns.md` § Fail Fast on Locks — the Migration Session Preamble)
- **Commit batched backfills per batch** — a `PROCEDURE` + `CALL` or a top-level `DO` block can `COMMIT` between batches (PG11+), but only when not wrapped in an explicit transaction (`BEGIN…COMMIT`, `psql -1`, a migration tool's per-file transaction); otherwise loop the batches from a script (see `references/migration-patterns.md` § Large Table Migrations)

## Recent Postgres Versions (use when available)

| Version | Released | Notable additions |
|---|---|---|
| **PG 18** | 2025-09-25 | Built-in `uuidv7()`; async I/O improvements; `EXPLAIN ANALYZE` includes `BUFFERS` by default; explicit `uuidv4()` alias (UUIDv4 already available via `gen_random_uuid()` since PG 13); B-tree skip scan; `NOT NULL` constraints can be added `NOT VALID` |
| **PG 17** | 2024-09 | `MERGE ... RETURNING`; `JSON_TABLE`; faster B-tree searches for multiple values (`IN` lists); lower-memory, faster `VACUUM`; `pg_basebackup --incremental` |
| **PG 16** | 2023-09 | `pg_stat_io` (per-IO-type stats — complements per-query `BUFFERS`); logical decoding on standby; parallel apply of large transactions |
| **PG 15** | 2022-10 | `MERGE` statement |

*As of 2026-10-06, PG 19 is still in beta (Beta 4 released 2026-09-24); check its release notes once it is GA before relying on new features.*

Practical implications:
- Prefer `uuidv7()` (PG 18) over app-generated UUIDv4 for new primary keys — better B-tree clustering.
- For diagnostics on PG 16+, supplement `EXPLAIN (BUFFERS)` with `pg_stat_io` for per-backend / per-IO-type breakdown.
- `JSON_TABLE` (PG 17) replaces ad-hoc JSONB-to-rows lateral joins for many use cases.
- **PgBouncer 1.21+ supports prepared statements in transaction mode** — earlier prohibitions ("PgBouncer breaks prepared statements") no longer apply post-1.21. It needs `max_prepared_statements > 0`, which is the default (200) since PgBouncer 1.24; on 1.21–1.23 set it explicitly.
- On PG 18, prefer `ADD CONSTRAINT ... NOT NULL col NOT VALID` → `VALIDATE CONSTRAINT` over the CHECK-helper path for adding NOT NULL to a live table (`references/migration-patterns.md`).

### DDL portability (PG18 vs ≤PG17)

UUID-keyed DDL: `DEFAULT uuidv7()` on PG 18+; on PG 17 and below generate UUIDv7 at the application layer and pass it into INSERT (no column DEFAULT); `gen_random_uuid()` (v4) only for low-volume/low-write tables. The full rule is SKILL.md → Primary Key Type Decision → "UUID v7 generation"; the DDL variants are in `references/data-types-guide.md` § PK Type Selection.
