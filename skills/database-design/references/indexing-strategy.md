# Indexing Strategy

Indexes come from access paths, not from columns; this file is the depth behind the Index gate (SKILL.md Stage 3). A query that ignores its index: `references/postgresql/query-tuning.md`. Building or dropping one on a live table: `references/migration-patterns.md`.

## From paths to indexes

1. **List the paths and every variant** (gate step 1). Sources: the feature specs, the API and the code that builds the queries; on a running system, `pg_stat_statements` ranked by total time.
2. **Constraint indexes first.** PRIMARY KEY, UNIQUE and EXCLUDE indexes enforce invariants, and child-FK indexes (SKILL.md Stage 3) serve parent deletes; none needs a path, and none is ever "unused".
3. **Tabulate candidates × variants, then merge.** Example: a tenant's orders, filtered by status (one value, several, or none), newest first, with a total count:

   | Candidate | `status = $2` | `status = ANY($2)` | no filter | count |
   |---|---|---|---|---|
   | `(tenant_id, created_at DESC, id DESC) WHERE status = 'pending'` | `pending` only, never under a generic plan | — | — | `pending` only |
   | `(tenant_id, created_at DESC, id DESC)` | walk and filter: fast while the value is common | same | seek and stop | reads the tenant's rows |
   | `(tenant_id, status, created_at DESC, id DESC)` | seek and stop | per-value merge | per-value merge over the closed set | index-only, per value |

   An index whose columns are a leading prefix of another's (`(a)` beside `(a, b)`) is redundant unless it is unique or the narrow one is hot and much smaller.
4. **Verify on seeded data** (SKILL.md Stage 3): a plan on an empty table proves nothing.

## Column order

- Equality columns first. `tenant_id` leads when tenant-scoped queries dominate; cross-tenant analytics may want the opposite.
- Then, under `ORDER BY … LIMIT`, the sort columns: the scan returns rows in order and stops at LIMIT, and a range column placed after them is still checked inside the index.
- Otherwise the range column next.
- *Break when* the range alone leaves a handful of rows: then equality → range, and sort those few.

Example (range vs sort): `WHERE tenant_id = $1 AND due_at < now() ORDER BY priority DESC LIMIT 50`. The textbook "equality → range → sort" index `(tenant_id, due_at, priority)` fetches and sorts every overdue row (≈2,500 buffers on a 400k-row test table); `(tenant_id, priority DESC, due_at)` reads 50 rows in order (≈50 buffers).

Example (filter, then sort): `WHERE tenant_id = $1 AND status = $2 ORDER BY created_at DESC LIMIT 20`. `(tenant_id, status, created_at DESC)` seeks each status and reads 20 rows in order, for every value the endpoint sends. A partial `(tenant_id, created_at DESC) WHERE status = 'pending'` serves only `pending`, and only when the planner sees the value (a generic plan's `$2` cannot use it), and leaves every other status to scan.

**Several values, one sort.** The composite index returns rows value by value, so `status = ANY($2) ORDER BY created_at DESC LIMIT 20` reads every matching row and sorts them (a Sort node above the index scan). Merge per value instead; each branch stops after one page:
```sql
SELECT o.*
FROM unnest($2::text[]) AS v(status)
CROSS JOIN LATERAL (
    SELECT id, status, created_at, total_minor FROM orders
    WHERE tenant_id = $1 AND status = v.status
      AND (created_at, id) < ($3, $4)        -- keyset cursor; omit on the first page
    ORDER BY created_at DESC, id DESC
    LIMIT 21                                 -- page size + 1, for has-next
) o
ORDER BY o.created_at DESC, o.id DESC
LIMIT 21;
```
It reads at most 21 index entries per value. For the "no filter" variant, pass the closed set (the CHECK list) while it is small; when the requested values are common among recent rows, or the set is large, an index led by the sort, `(tenant_id, created_at DESC, id DESC)`, walks and filters for less. Compare both plans on seeded data.

## Selectivity

Judge a predicate by the fraction of rows its value matches, not by distinct values / total rows:
```sql
-- as a role that bypasses RLS: pg_stats shows nothing for tables whose policies apply to you
SELECT most_common_vals, most_common_freqs FROM pg_stats
WHERE schemaname = 'app' AND tablename = 'orders' AND attname = 'status';
```
A path that only ever reads one rare value (a queue's `pending` rows) wants a partial index; a value matching 30% of rows is served better by a scan, or by walking a sort-led index. A status column alone rarely deserves an index; as the equality column ahead of a sort, it serves every value's page (Column order).

## Partial, expression and covering indexes

- **Partial**: index only the rows a hot path reads, `CREATE INDEX idx_orders_pending ON orders (created_at) WHERE status = 'pending';`. Queries must repeat the predicate literally; a generic plan's `status = $1` cannot use it. Name the variants it leaves unserved. A partial UNIQUE scopes uniqueness (`… WHERE deleted_at IS NULL`).
- **Expression**: `lower(email)`, `(attributes->>'brand')`; queries must repeat the exact expression. `created_at::date` on a `timestamptz` cannot be indexed (it depends on `TimeZone`): query a half-open range on the bare column instead.
- **Covering**: `INCLUDE (cols)` turns a hot read into an index-only scan, which needs a current visibility map (vacuum; watch `Heap Fetches`). Only for columns that rarely change.

## Beyond B-tree

GIN for containment (jsonb, arrays, `tsvector`) and `pg_trgm` (`ILIKE '%term%'`); GiST for ranges and EXCLUDE (`btree_gist` for scalar columns); BRIN only where physical order follows the column (append-only events by time).

## Reconcile the index set

Every index is paid on every insert, on every update that is not HOT, and again in vacuum, WAL volume, replica apply and cache. An update that changes any indexed column, INCLUDE columns too, cannot be HOT (PG16+ exempts columns indexed only by BRIN). On write-hot tables count the indexes and prefer one composite index serving two paths over two narrow ones.

Before and after an index change, list the table's set:
```sql
SELECT s.indexrelid::regclass AS index_name, s.idx_scan,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
       pg_get_indexdef(s.indexrelid) AS definition
FROM pg_stat_user_indexes s
WHERE s.relid = 'app.orders'::regclass
ORDER BY s.idx_scan;
```
- **Redundant prefixes**: `scripts/schema_review.sql` §3 lists B-tree indexes whose key columns lead another valid index with the same operator classes, collations, directions and predicate. Drop them unless unique, or hot and much smaller.
- **Zero scans** are a question for the owner, not a verdict: counts are per node, so run §3 on the primary and every replica, and they restart on a statistics reset, a crash or `pg_upgrade`; sum them over a business cycle, since monthly jobs scan rarely.
- **Drop** one at a time with `DROP INDEX CONCURRENTLY`, as a runbook row, keeping the definition to restore it. An expression index also gives the planner statistics on its expression: replace them with `CREATE STATISTICS … ON (<expression>)` before dropping it.
