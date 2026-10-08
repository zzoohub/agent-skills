# PostgreSQL Query Patterns

The traps in everyday query shapes. Diagnosing a slow query: `references/postgresql/query-tuning.md`.

## Keyset pagination

Seek past the previous page's last row, never `OFFSET`:
```sql
SELECT id, title, created_at FROM posts
WHERE (created_at, id) < ($1, $2)
ORDER BY created_at DESC, id DESC
LIMIT 21;   -- page of 20, plus one row for has-next; index (created_at DESC, id DESC),
            -- led by tenant_id for a tenant's list
```
- When creation order is the contract, a unique time-ordered id (UUIDv7) alone is the cursor: `WHERE id < $1 ORDER BY id DESC`.
- Any other order needs the sort key plus a unique tiebreaker, with the comparison and the index in the same direction. Mixed directions (`ORDER BY score DESC, id ASC`) cannot use one row comparison: write `score <= $1 AND (score < $1 OR id > $2)` with an index on `(score DESC, id ASC)`. The first conjunct is the index seek; the bare OR form filters from the top of the index on every page.
- A page can miss a row that commits late with an earlier key: fine for lists, wrong for a change feed or sync that must see every row, which needs a commit-ordered cursor (`references/design-patterns.md`, reliability tables).
- **The calling code** fetches `LIMIT page_size + 1` and returns a next cursor, built from the last row it returns, only when the extra row came back; an exactly full last page then ends the list instead of leading to an empty one. The cursor carries every sort key at full precision: `timestamptz` keeps microseconds and a JavaScript `Date` keeps milliseconds, so a truncated cursor skips or repeats rows.
- A filter over several values with one sort (`status = ANY($2)`) needs the per-value merge: `references/indexing-strategy.md`, Column order.

## Child caps and fan-out

- To cap children per parent, put the LIMIT inside a LATERAL subquery before aggregating; a LIMIT beside `jsonb_agg` applies to the one aggregated row:
```sql
SELECT u.id, recent.orders
FROM user_accounts u
LEFT JOIN LATERAL (
    SELECT jsonb_agg(t ORDER BY t.created_at DESC) AS orders
    FROM (SELECT o.id, o.total, o.created_at FROM orders o
          WHERE o.user_id = u.id ORDER BY o.created_at DESC LIMIT 5) t
) recent ON true
WHERE u.id = ANY($1);
```
- Fan-out: joining a parent to two independent child tables multiplies rows, so `sum` and `count` come out wrong (each order line counted once per payment). Aggregate each child separately, then join the aggregates.

## UPSERT

- `ON CONFLICT` needs a unique index that matches the target exactly, including a partial index's predicate: `ON CONFLICT (email) WHERE deleted_at IS NULL`.
- `DO NOTHING` returns no row on conflict. `DO UPDATE` writes a new row version on every conflict (WAL, a dead tuple, a row lock, UPDATE triggers) even when nothing changed; skip no-op writes with `… DO UPDATE SET v = EXCLUDED.v WHERE t.v IS DISTINCT FROM EXCLUDED.v` (no row returned then). To read the existing row, follow `DO NOTHING` with a `SELECT`; PG19+ `ON CONFLICT DO SELECT … RETURNING` returns it, optionally locked `FOR UPDATE`.
- PG18+: `RETURNING old.*, new.*` tells an insert (old is NULL) from an update.

## Full-text search

- A GIN expression index on `to_tsvector('english', …)` serves only queries that repeat the expression exactly; a generated `tsvector` column avoids that, but it must be STORED to be indexed, and adding one rewrites a live table.
- Parse user input with `websearch_to_tsquery('english', $1)`; `to_tsquery` raises on stray syntax.
- `ts_rank` scores every match: when matches can run to tens of thousands, narrow the candidates first.

## Bulk import

- Load with client-side `\copy` (server-side `COPY … FROM 'file'` needs `pg_read_server_files`) into a staging table, then upsert into the target in batches. `COPY … (FREEZE)` writes rows pre-frozen into a table created or truncated in the same transaction. PG17+ `ON_ERROR ignore` skips malformed rows (PG18+ `REJECT_LIMIT` caps them).
- Drop and recreate indexes around a load only on a table no traffic uses. `ANALYZE` afterwards.

## Time buckets in the business time zone

Days end at the business's midnight, not the session's: `date_trunc('day', created_at, 'Asia/Seoul')` or `SET LOCAL TimeZone`. To fill empty days, join local midnights, as instants, on a half-open range (index-friendly and DST-safe):
```sql
SELECT d::date AS day, count(o.id) AS orders, coalesce(sum(o.total), 0) AS revenue
FROM generate_series(timestamp '2026-09-01', timestamp '2026-09-30', interval '1 day') AS d
LEFT JOIN orders o
  ON  o.created_at >= d AT TIME ZONE 'Asia/Seoul'
  AND o.created_at <  (d + interval '1 day') AT TIME ZONE 'Asia/Seoul'
  AND o.status = 'completed'
GROUP BY d
ORDER BY d;
```

## Hot rows, queues and materialized views

- A counter updated by every request serializes those writers on one row lock. Append increments to a side table and fold them in periodically (`WITH d AS (DELETE … RETURNING …) UPDATE …`), or split the counter into N rows summed on read.
- Job queues claim rows with `FOR UPDATE SKIP LOCKED` and a lease, commit the claim, and work outside the transaction. An outbox relay that keeps per-aggregate order claims only each aggregate's head row, so the row lease is the aggregate lease. Table shapes: `references/design-patterns.md` (reliability tables).
- `REFRESH MATERIALIZED VIEW CONCURRENTLY` needs a unique index on the view and still recomputes the whole query before diffing. At scale, maintain a summary table incrementally.
