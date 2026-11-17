# Proof

A design claim is an execution or it is a hope. Starting a database, seeding a million rows and running a plan takes minutes; reading four hundred lines of DDL for the constraint that is missing takes longer and finds less. Every snippet here was run on PostgreSQL 18.

## 1. A database to run on

- **Scratch**: a container or local server of the target major version, with the project's extensions, built from the migration chain. Starting one is part of the work, not a favor to ask for.
- **A copy shaped like production**, for timings and plans: a provider branch or thin clone, or a restore, with personal data masked. A branch that carries no data (some platforms' do not) proves syntax and order only.
- **Never production** for anything that writes, locks or loads. Evidence queries there are read-only, under a `statement_timeout` (SKILL.md, Your own access).
- An embedded or WebAssembly Postgres runs DDL and constraints; it has one connection, so it cannot show a race, a lock queue or a pooler's behavior, and its version and extensions may differ from the target.

## 2. Seed to shape

Plans on empty tables prove nothing, and uniform data hides the tenant that hurts. Seed the hot tables at volume with production's skew, then `ANALYZE`:
```sql
-- 1M orders over 2,000 tenants. power() skews them: here the largest tenant owns 15% of the rows
-- and the top 20 own a third.
INSERT INTO orders (tenant_id, status, total_minor, created_at)
SELECT ('00000000-0000-0000-0000-' || lpad((1 + floor(2000 * power(random(), 4)))::int::text, 12, '0'))::uuid,
       (ARRAY['pending', 'paid', 'paid', 'paid', 'paid', 'paid', 'paid', 'shipped', 'shipped', 'refunded'])[1 + floor(random() * 10)::int],
       (random() * 100000)::bigint,
       now() - random() * interval '365 days'
FROM generate_series(1, 1000000);
ANALYZE orders;
```
Match what the plan depends on: the share of the largest tenant, the mix of each filtered status, the time spread, the row width (long text and JSON at their real sizes). Then measure bytes per row (`scripts/schema_review.sql` §10) for the sizing arithmetic. Vectors are the costly part of a seed: scale their count down, keep each filter value's share, and report the share that was not reproduced as not run.

## 3. An invariant is proven by the write it rejects

For each "never X", run the write that does X and require the rejection:
```sql
DO $$
BEGIN
    INSERT INTO bookings (class_id, member_id) SELECT class_id, member_id FROM bookings LIMIT 1;
    RAISE EXCEPTION 'NOT ENFORCED: one booking per member and class';
EXCEPTION WHEN unique_violation THEN NULL;   -- the expected rejection; anything else propagates
END $$;
```
If the insert succeeds, the block raises and the script fails; if it is rejected for another reason, that error propagates too. Run the file with `psql -v ON_ERROR_STOP=1`, keep it beside the migrations, and run it in CI: it is the guard that fails when someone drops the constraint. One block per invariant, named in the invariant's words.

## 4. A race is proven under concurrency

A rung-2 or rung-3 invariant holds only against concurrent writers, which one session cannot show. Fire the write from many clients, then check the invariant:
```sql
-- race.sql: every client tries to book the same class
\set member random(1, 1000000)
BEGIN;
SELECT 1 FROM classes WHERE id = 2 FOR NO KEY UPDATE;      -- the guard under test
INSERT INTO bookings (class_id, member_id)
SELECT 2, :member
WHERE (SELECT count(*) FROM bookings WHERE class_id = 2) < (SELECT capacity FROM classes WHERE id = 2)
ON CONFLICT DO NOTHING;
COMMIT;
```
```bash
pgbench -n -c 16 -j 4 -t 50 -f race.sql "$SCRATCH_URL"
psql "$SCRATCH_URL" -c "SELECT c.id FROM classes c JOIN bookings b ON b.class_id = c.id GROUP BY c.id, c.capacity HAVING count(*) > c.capacity"   -- must return no rows
```
With the guard line, a 12-seat class ended at 12 bookings. Without it, the same check-then-insert ended at 17 in under a second. Run the unguarded form once to see the test can fail. A guard that raises (a CHECK, a trigger) aborts a pgbench client at its first rejection: call the write through a function that catches the expected SQLSTATE and returns false.

## 5. Access is proven as the role

Log in as each role and try what it must not do: `references/access.md` §6.

## 6. A plan is proven on the seed

`EXPLAIN (ANALYZE, BUFFERS)` each hot path's every variant, the way the application runs it (prepared, six or more executions, as the application role: `references/query-tuning.md`, Triage). Read for: the intended index; rows read against rows returned (`Rows Removed by Filter`); a sort that should have been an ordered scan; buffers per call; for a search with a LIMIT, the rows actually returned.

## 7. A migration is proven by a rehearsal

- **The chain applies** to a scratch database from empty, and to a copy at the previous release's schema.
- **Each scan, rewrite, build and backfill is timed** on the production-shaped copy; that number is the runbook's duration.
- **Strong-lock steps give up instead of queueing.** Hold a transaction open on the table in a second session, then run the step with its `lock_timeout`:
  ```sql
  -- session A:  BEGIN; SELECT 1 FROM orders LIMIT 1;          (left open)
  -- session B:
  SET lock_timeout = '500ms';
  ALTER TABLE orders ADD COLUMN note text;                     -- must fail in ~500 ms with SQLSTATE 55P03
  ```
  A step that waits here would have queued every later query on the table behind it in production.
- **N-1**: the previous release's tests, or at least its statements, pass against the new schema; the down step of each expand step runs.
- **A backfill** is interrupted once and resumed; counts match an independent count taken as a role that bypasses RLS.

## 8. Say what ran

In database.md and in the report, every proof is **ran** (where, on how many rows, the number that came out) or **not run** (the exact command, and what it would settle). Never write a result that was not observed: "the index is used" without a plan is a guess with a confident face. When no database could be started, say so once and list the commands in order.

## 9. Standing guards

What keeps the proof true after the session ends: the invariant file (§3) and the race scripts for money and capacity (§4) in CI; a scratch database built from the migration chain and its `pg_dump --schema-only` diffed against each long-lived environment (drift); the previous release's tests against the new schema (N-1); `scripts/schema_review.sql` against production monthly and after launches; `pg_stat_statements` kept on, so `scripts/query_diagnostics.sql` §6 has history.
