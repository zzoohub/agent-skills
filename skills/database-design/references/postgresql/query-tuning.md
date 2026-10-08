# Query Tuning

Diagnose slowness from evidence: attribute the load, reproduce each statement that owns it the way the application runs it, find its misestimate or its excess work, then fix it in the cheapest layer that works: the call pattern, statistics, the query, an index, a role setting, the schema.

## Attribute the load first

The request names one query; the problem is whatever owns the time.
- **Scope.** One endpoint slow, or everything? Everything, or CPU, I/O or connections saturated, means a shared resource ran out (check the session shape first: `references/postgresql/production-ops.md`, Incident triage), so find the statements consuming it. One endpoint: list every statement it issues per request (the list, its count, facets, any N+1) and every variant (filters, sorts, page depth), and fix the set, not the sample.
- **Rank by share of total time over a window** that brackets the change (`scripts/query_diagnostics.sql` §6 window, or the host's per-query history). Never by mean, never on totals since the last reset, and never reset the statistics to "start clean": that destroys the baseline. A 3 ms statement called 20M times a day spends about 17 hours of database time daily, and a ranking by mean never shows it.
- **Split each top statement's growth** into calls/s (demand) and mean ms (cost per call), before vs during:

  | Mean | Calls/s | Family | Look for |
  |---|---|---|---|
  | up | steady | cost per call | a flipped or generic plan, stale statistics, more rows under the same plan, cache misses, lock waits (Triage) |
  | steady | up | demand on a sound plan | a new caller, traffic, retries after timeouts, a poller, an expired-cache stampede, an N+1, one tenant (Demand on a sound plan) |
  | up | up | both | each, by its share |

- **Blast radius.** The statements that together own most of the window explain a system-wide symptom; a statement that regressed but owns a few percent is a finding, not the cause. Name every cause that owns a material share.
- **Always slow, or only sometimes?** Always: the plan, a missing index, or the work itself. Sometimes: a generic plan, parameter skew, lock waits (`log_lock_waits`) or a cold cache; compare the slow execution's own plan, logged by `auto_explain` (`references/postgresql/production-ops.md`), with a fast one, since a plan reproduced later may differ.
- Huge `calls` with `rows / calls` near 1 is an N+1 in the application. Fix it there with one query (`= ANY($1)`, a join), not with an index. `shared_blks_read` ranks I/O (with `track_io_timing` on, its time too); `temp_blks_written` ranks sorts and hashes that spill to disk.
- No workload data, only a pasted query: say so, give the §6 queries to run, and analyze the statement given.

## Triage, per statement

1. **Reproduce as the application runs it**: same parameter types, as a prepared statement executed six or more times (the first five get custom plans, then the server may switch to a generic plan), in a session logged in as the application role (role settings such as `work_mem`, `plan_cache_mode` and `jit` apply at login, not on `SET ROLE`).
   ```sql
   PREPARE q(bigint) AS SELECT id, total FROM orders WHERE account_id = $1 ORDER BY created_at DESC LIMIT 20;
   EXPLAIN (ANALYZE, BUFFERS) EXECUTE q(42);   -- repeat 6+ times; $1 in the plan = a generic plan
   ```
   "Fast in psql, slow in the app" is usually a generic plan or a type mismatch: a `numeric` parameter against a `bigint` column becomes `col::numeric = $1` and cannot use the index. Cast the parameter, never the column. `EXPLAIN ANALYZE` executes the statement, so wrap DML in `BEGIN … ROLLBACK`.
2. **Find the misestimate.** Actual rows and time are per loop: multiply by `loops`. The lowest node where estimated and actual rows differ by 10× or more is this plan's cause; everything above it is consequence. Ignore misestimates off the expensive path, and check each statement that owns load: several can each have one. Estimates within 10× and still too slow: the plan fits the work asked, so cut the work (Demand on a sound plan) or the rows read (steps 3–5). Stop at the first rung that fixes the estimate:

   | Cause | Fix |
   |---|---|
   | Stale statistics after a bulk change or on a new partition | `ANALYZE t` |
   | Skew beyond the most-common-values list | `ALTER TABLE t ALTER COLUMN c SET STATISTICS 1000;` then `ANALYZE t` |
   | Correlated predicates (`city` and `country`) | `CREATE STATISTICS t_city_country (dependencies, mcv) ON city, country FROM t;` then `ANALYZE t` |
   | A function or expression on the column | `CREATE STATISTICS t_email_lower ON (lower(email)) FROM t;` (statistics without an index), an expression index, or a rewrite to the bare column |
   | A generic plan that is wrong for some values | `ALTER ROLE app_rw SET plan_cache_mode = force_custom_plan`, or `SET LOCAL` in the transaction |

   `ANALYZE`, `SET STATISTICS` and `CREATE STATISTICS` run online (SHARE UPDATE EXCLUSIVE); build any index `CONCURRENTLY`.
3. **Rank nodes** by their own time × loops, then by shared blocks read (from outside shared_buffers, often still the OS cache) vs hit, then temp blocks.
4. **`ORDER BY x LIMIT n` walking an index on `x`** while discarding rare matches (large `Rows Removed by Filter`): index `(filter_col, x)`, or fix the filter's estimate so the planner stops betting on finding matches early.
5. **Widen an index only when** `Rows Removed by Filter` × loops is at least 10× the rows returned and the query is hot. A Filter line is not a defect by itself: every extra index column costs every write and can end HOT updates. Exception: completing an index-only scan. Any index added or changed here passes the Index gate (SKILL.md Stage 3): every variant of the endpoint, and the table's existing indexes.
6. **JIT** taking a large share of a short query (the `JIT:` block at the end of the plan; `jit` is on by default before PG19): `jit = off` for that role.
7. **Index Only Scan with high `Heap Fetches`**: the visibility map is stale, so VACUUM the table; on append-only tables, lower `autovacuum_vacuum_insert_scale_factor`.

## Demand on a sound plan

Estimates within 10× and every row read is needed, yet the statement owns the load: cut the calls or the work per call; the plan is not the problem.
- **Fewer calls.** Batch an N+1 (`= ANY($1)`, a join); compute a list's total once and carry it across its pages; bound retries with jittered backoff so timeouts do not multiply the load; coalesce identical concurrent requests and stagger cache expiry; lengthen or replace polling.
- **Less work per call.** Bound every result set (LIMIT, keyset, a time window). A statement that reads a growing history on each call gets slower every month on the same plan.
- **Hot-path aggregates** (a count, sum or badge per request). Exactness and freshness are the owner's decision:

  | Option | Gives | Gives up |
  |---|---|---|
  | **Bounded**: `SELECT count(*) FROM (SELECT 1 FROM … LIMIT 1001) s`, shown as "1,000+"; or a recent window | work capped per call | the exact number past the cap |
  | **Estimated**: the planner's row estimate (`reltuples` for a whole table) | almost free | accuracy: filtered estimates can be off by multiples |
  | **Cached**: a summary row updated with each write (contention: `references/postgresql/query-patterns.md`, hot rows) or a table refreshed on a schedule | exact within a staleness bound | write cost or staleness, and a drift query to run |
  | **Index-only**: a covering index on the filter columns | exact and fresh | still reads every matching entry; vacuum must keep pages all-visible (`Heap Fetches` near 0), so it is weak on update-heavy tables |

## Why the index is not used

| Symptom | Cause | Fix |
|---|---|---|
| Partial index ignored | The query's WHERE does not provably imply the index predicate (repeat it literally), or a generic plan's `$1` cannot be proven to match it; custom plans substitute the value and can | A literal predicate on hot paths, or `force_custom_plan` for that role |
| Index on `col` ignored for `lower(col)` or `created_at::date` | A function or cast on the column | An expression index on the same expression; for a day bucket on `timestamptz` (not indexable: it depends on `TimeZone`), a half-open range on the bare column |
| `LIKE 'prefix%'` scans the table | Non-C collation | A `text_pattern_ops` index (ranges and ORDER BY still need a default-opclass index; equality works with either) or `COLLATE "C"` |
| Parent `DELETE` slow, plan shows `Trigger for constraint …` time | Unindexed child FK column: every delete scans the child | Index the child FK column (`scripts/schema_review.sql` §1) |
| Writes slow, low `hot_pct` (`query_diagnostics.sql` §10) | An updated column is indexed, so updates are never HOT | Drop the index on the churning column, or lower `fillfactor` when pages are full |
| `status = ANY($2) ORDER BY created_at LIMIT n` reads every match, then sorts | The index returns rows value by value | The per-value merge (`references/indexing-strategy.md`, Column order) |

PG18 B-tree skip scan can use a composite index whose leading column is unconstrained, but it pays off only when that column has few distinct values. Do not design for it.

## Reading the plan

- `EXPLAIN (ANALYZE, BUFFERS)`. PG18 includes BUFFERS automatically, prints fractional row counts and reports `Index Searches` per index scan.
- `Sort Method: external merge`, or a hash with `Batches` above 1: a memory spill. Raise `work_mem` for that role or transaction (hashes may use `work_mem × hash_mem_multiplier`), or sort fewer rows.
- `Rows Removed by Index Recheck` on a bitmap heap scan: with `Heap Blocks: lossy=` above 0 the bitmap outgrew `work_mem`, so raise it; otherwise the index type rechecks by design (BRIN, trigram).

## Report

Write the reply from these slots. Budget: about 150 words per cause, plus the tables. Slots are a menu: omit one that does not apply, heading included. Never drop a material finding to fit: compress it to one line.
1. **Load**: statement · share of the window · calls/s before → during · mean ms before → during · family. Without workload data, say so and list the §6 queries to run.
2. **Causes**, ranked by the share they explain: the evidence (the misestimated node with estimated vs actual rows and buffers, or the call-rate growth and its source), the fix and why that layer, and before and after from the same reproduction.
3. **Index set**, when an index changes: each index on the table with scans and size → keep, add or drop, and the variants each serves; drops ship as runbook rows (`references/migration-patterns.md`).
4. **Decisions for the owner**: what each fix gives up (an estimated count, cache staleness, the vacuum an index-only scan depends on).
5. **Other contributors and follow-ups**, one line each. Anything the reader must act on goes in the reply, never only in a script comment.
