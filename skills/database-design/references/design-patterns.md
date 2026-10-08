# Design Patterns

The shapes that SKILL.md Stage 1–2 decisions take, each with the trap that breaks it. Examples use the PG18 `uuidv7()` default; before 18 the application supplies v7 ids.

## 1. Duplicated and derived data

Denormalize only for a cost you measured; a snapshot (SKILL.md Stage 1) is not a duplicate.
- **A true duplicate** names its source, staleness bound and sync mechanism, cheapest first: a STORED generated column (same row) → a write in the same transaction → a trigger (writers you don't control; hidden cost) → an async projection from the outbox or CDC (cross-service; seconds stale). Pair it with a drift query: `SELECT count(*) FROM t WHERE dup IS DISTINCT FROM <recomputed>`.
- **Stored aggregates** (counters, materialized views) pay on every write or refresh: fixes in `references/postgresql/query-patterns.md` (hot rows). **Read models** (CQRS) only when read and write shapes truly diverge.

## 2. Subtypes, polymorphic references and hierarchies

- **Subtypes.** Few type-specific columns: one table with per-type CHECKs (`CHECK (type <> 'card' OR card_last4 IS NOT NULL)`). Many: a shared table plus a table per type keyed by the parent's id. Never native `INHERITS`: UNIQUE and FKs do not span child tables.
- **Polymorphic references** (a comment on an article or a product): never a `(parent_type, parent_id)` pair, which no FK enforces. For a few parent types, an exclusive arc: one nullable FK column per parent, `CONSTRAINT chk_comments_one_parent CHECK (num_nonnulls(article_id, product_id) = 1)`, and a partial index per FK (`WHERE article_id IS NOT NULL`). For many, a supertype: `commentables (id)`, each parent holding `commentable_id uuid NOT NULL UNIQUE REFERENCES commentables (id)`, comments referencing `commentables`. Or one comment table per parent.
- **Hierarchies.** An adjacency list (`parent_id`) walked by a recursive CTE by default; a closure table or `ltree` path only when subtree reads dominate and moves are rare. No CHECK prevents a cycle: the statement that moves a node, or a trigger, must.

## 3. Soft delete and erasure

Default to a hard delete plus an audit or archive copy. Use `deleted_at` only when deleted rows must stay referenceable or restore is a product feature, and then:
- every UNIQUE becomes partial `WHERE deleted_at IS NULL`, and hot indexes do too;
- children of a deleted parent get a decided fate: hidden, cascaded or kept;
- reads filter in the query or a view, never through an RLS SELECT policy `USING (deleted_at IS NULL)`: an UPDATE's new row must pass the SELECT policy, so the soft delete itself fails;
- erasure keeps a hard-delete or anonymizing path.

*Break when* "deleted" is really a domain state (cancelled, archived): model it as a status.

**Erasure vs immutable history.** Soft-deleted rows, audit payloads and event stores keep personal data by design, which collides with erasure duties (GDPR Art. 17). Decide before adopting them:
- **Crypto-shredding**: encrypt the subject's personal data under a per-subject key stored elsewhere; destroying the key erases it everywhere at once.
- **No personal data in immutable payloads**: audit rows and events carry a pseudonymous subject id only.
- **Tombstone**: overwrite the personal columns, keep the row and its FKs.
- **Backups** expire on their retention schedule; keep an erasure log and re-apply it after any restore.

## 4. Audit trail

The actor is the person, not the database role (`current_user` is always the shared app role), and the app role can neither read nor rewrite the trail.
```sql
CREATE SCHEMA audit AUTHORIZATION app_owner;            -- no grants to the app role
CREATE TABLE audit.changes (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name text        NOT NULL,
    row_id     text        NOT NULL,
    action     text        NOT NULL,
    actor_id   text,                                     -- from app.actor_id, set per transaction
    old_row    jsonb,
    new_row    jsonb,
    changed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_changes_row ON audit.changes (table_name, row_id);
CREATE INDEX idx_changes_changed_at ON audit.changes USING brin (changed_at);

CREATE FUNCTION audit.capture() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
    INSERT INTO audit.changes (table_name, row_id, action, actor_id, old_row, new_row)
    VALUES (TG_TABLE_NAME, CASE TG_OP WHEN 'DELETE' THEN OLD.id ELSE NEW.id END::text, TG_OP,
            current_setting('app.actor_id', true),
            CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) - 'password_hash' END,   -- strip classified columns
            CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) - 'password_hash' END);
    RETURN NULL;
END $$;
CREATE TRIGGER trg_orders_audit AFTER INSERT OR UPDATE OR DELETE ON app.orders
    FOR EACH ROW EXECUTE FUNCTION audit.capture();
```
- `to_jsonb(row)` copies every column: strip each column whose class forbids it, or keep a per-table allowlist. The trail inherits the access rules and retention of the most sensitive column it records.
- A row trigger doubles its table's write volume: on write-hot tables, capture changes from logical decoding (CDC) instead. CDC cannot see `app.actor_id`: write the actor into an `updated_by` column, or, to cover deletes too, emit it with `pg_logical_emit_message(true, 'actor', $1)` in the same transaction.

## 5. Event sourcing, ledgers and temporal data

- **Event sourcing** only when the events are the domain and projections are rebuilt from them; "we need history" is an audit trail (§4). An event store keeps `UNIQUE (aggregate_id, version)` for optimistic concurrency, and its readers follow a commit-ordered cursor (§7).
- **Money movement** is a double-entry ledger: immutable entries `(txn_id, account_id, amount_minor, currency)` that sum to zero per transaction and currency, written together by one function or checked at commit by a deferred constraint trigger. Corrections are reversing entries, never UPDATEs; balances are derived, or maintained by a guarded statement (`references/acid-transactions.md`).
- **Validity periods** (prices, policies, assignments) need an overlap guard, or "the price at time T" becomes ambiguous:
  ```sql
  CREATE EXTENSION IF NOT EXISTS btree_gist;     -- GiST equality for the scalar column
  CREATE TABLE product_prices (
      product_id  uuid      NOT NULL REFERENCES products (id),
      valid       tstzrange NOT NULL,
      price_minor bigint    NOT NULL,
      CONSTRAINT ex_product_prices_overlap EXCLUDE USING gist (product_id WITH =, valid WITH &&)
  );
  -- current price: WHERE product_id = $1 AND valid @> now()
  ```
  PG18+ can declare `PRIMARY KEY (product_id, valid WITHOUT OVERLAPS)` instead (empty ranges rejected; still needs btree_gist), and a referencing table can demand coverage for its whole period: `FOREIGN KEY (product_id, PERIOD valid) REFERENCES product_prices (product_id, PERIOD valid)`.

## 6. Tenancy and RLS wiring

Behind your own API, the application connects as a role that owns nothing, and RLS backs up the `tenant_id` predicate every query still carries: the planner needs that predicate to choose indexes and prune partitions at plan time.
```sql
CREATE ROLE app_owner NOLOGIN;                 -- owns schemas and tables; migrations' DDL runs as it
CREATE ROLE app_rw LOGIN PASSWORD '…';         -- the application: not owner, not superuser, no BYPASSRLS
CREATE ROLE app_maint NOLOGIN BYPASSRLS;       -- data migrations and cross-tenant jobs (purges) only
CREATE SCHEMA app AUTHORIZATION app_owner;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;    -- the default since PG15; upgraded clusters keep the old grant
GRANT USAGE ON SCHEMA app TO app_rw, app_maint;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw, app_maint;

ALTER TABLE app.orders ENABLE ROW LEVEL SECURITY, FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON app.orders
    USING (tenant_id = (SELECT NULLIF(current_setting('app.current_tenant', true), '')::uuid));
```
- **FORCE**, or the table owner bypasses the policy; superusers and BYPASSRLS roles (`app_maint`) always do. `ALTER DEFAULT PRIVILEGES` without `FOR ROLE` covers only objects created by the role running it, so name the migration role.
- **The policy** reads the setting in a scalar subquery, evaluated once per query rather than per row; `NULLIF(…, '')` turns an unset or empty setting into zero rows instead of an error. With no `WITH CHECK`, the USING expression also checks inserted and updated rows.
- **Set the context per transaction**, as its first statement: `SELECT set_config('app.current_tenant', $1, true), set_config('app.actor_id', $2, true);`. It takes bind parameters, which `SET LOCAL` cannot. A session `SET` survives into the next client's transaction under transaction pooling, and NULLIF catches an unset value, not a stale one.
- **Views** over RLS tables: `CREATE VIEW … WITH (security_invoker = true)` (PG15+); otherwise they apply the view owner's policies and bypass RLS whenever the owner does.
- **Generated APIs** (PostgREST, the Supabase Data API): an exposed table without RLS is open to every role granted on it. Keep what the API must not serve in an unexposed schema; give every exposed table RLS, per-role policies with `WITH CHECK` on writes, the caller's identity in a scalar subquery (`(SELECT auth.uid())` on Supabase), and column grants for columns users must not change.
- **Test** each tenant-scoped table as the app role with tenant A set (behind a generated API, as its role with A's claims): zero rows of tenant B, and an insert carrying B's id fails.

## 7. Reliability tables

Physical forms of software-architecture's reliability patterns, if that capability is in use: its logical fields are the contract; column names may follow the backend adapter (`locked_until` for `lease_expires`, `completed_at` set for `state = 'completed'`, one `scope` column for tenant + principal).

**Idempotency keys**
```sql
CREATE TABLE idempotency_keys (
    tenant_id      uuid        NOT NULL,
    principal_id   uuid        NOT NULL,
    key            text        NOT NULL,          -- client-chosen, one per intent
    request_hash   text        NOT NULL,
    state          text        NOT NULL DEFAULT 'in_flight'
                   CONSTRAINT chk_idempotency_keys_state CHECK (state IN ('in_flight', 'completed')),
    lease_token    uuid        NOT NULL DEFAULT gen_random_uuid(),   -- fencing: new on every acquire and takeover
    lease_expires  timestamptz NOT NULL,
    recovery_point text,                          -- last committed phase of an external side effect
    response       jsonb,                         -- status and body, replayed on repeat
    expires_at     timestamptz NOT NULL,          -- past the longest sender's retry horizon
    PRIMARY KEY (tenant_id, principal_id, key)
);
CREATE INDEX idx_idempotency_keys_expires_at ON idempotency_keys (expires_at);   -- batched purge
```
Acquire with `INSERT … ON CONFLICT DO NOTHING RETURNING lease_token`: only a returned row grants execution, under that token. Otherwise read the row: another `request_hash` → reject; `completed` → replay; a live lease → retryable conflict. Commit the in-flight row before any external call. Every later write (each recovery point as it commits, then the completion) adds `AND lease_token = $token AND state = 'in_flight'`; zero rows means the lease was taken over, so stop. Take over an expired lease conditionally under a new token, extending `expires_at` so the purge cannot delete a live row:
```sql
UPDATE idempotency_keys
SET lease_token = gen_random_uuid(), lease_expires = now() + $5,
    expires_at = greatest(expires_at, now() + $6)                -- $5 lease, $6 TTL
WHERE (tenant_id, principal_id, key) = ($1, $2, $3) AND request_hash = $4
  AND state = 'in_flight' AND lease_expires < now()
RETURNING lease_token, recovery_point;
```

**Outbox**
```sql
CREATE TABLE outbox (
    id               uuid        PRIMARY KEY DEFAULT uuidv7(),   -- debugging only, never order
    aggregate_type   text        NOT NULL,
    aggregate_id     uuid        NOT NULL,
    aggregate_seq    integer     NOT NULL,          -- per-aggregate order: the aggregate's new version
    event_type       text        NOT NULL,
    payload          jsonb       NOT NULL,
    headers          jsonb       NOT NULL DEFAULT '{}',
    created_at       timestamptz NOT NULL DEFAULT now(),
    published_at     timestamptz,                   -- NULL = pending
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),   -- backoff, and the relay's claim lease
    attempts         integer     NOT NULL DEFAULT 0,
    last_error       text,
    dead_lettered_at timestamptz,
    CONSTRAINT uq_outbox_aggregate_seq UNIQUE (aggregate_id, aggregate_seq)
);
CREATE INDEX idx_outbox_pending ON outbox (created_at)
    WHERE published_at IS NULL AND dead_lettered_at IS NULL;
CREATE INDEX idx_outbox_published_at ON outbox (published_at)   -- batched purge
    WHERE published_at IS NOT NULL;
```
Insert in the state change's transaction. The relay claims only each aggregate's oldest pending row (`NOT EXISTS` an earlier pending `aggregate_seq`) with `FOR UPDATE SKIP LOCKED`, pushes `next_attempt_at` forward as its lease, publishes outside the transaction, then marks the row published; a failing row holds back its aggregate until dead-lettered after N attempts. Alert on the age of the oldest pending row; purge published rows after the replay window.

**Inbox**: `PRIMARY KEY (consumer, message_id)` plus `received_at`, where `message_id` is the producer's event id (for a webhook, the provider's). In the handler's transaction, `INSERT … ON CONFLICT DO NOTHING RETURNING message_id`: no row means a duplicate, so skip the effect. Purge after the sender's redelivery horizon.

**Jobs**: `jobs (id, kind, payload, state, run_at, lease_token, lease_expires, attempts)` with a partial index `(run_at) WHERE state IN ('queued', 'running')`. Claim in a short transaction committed before the work starts:
```sql
WITH c AS MATERIALIZED (   -- runs once; an IN (subquery) may run again and claim more than $1 rows
    SELECT id FROM jobs
    WHERE run_at <= now()
      AND (state = 'queued' OR (state = 'running' AND lease_expires < now()))
    ORDER BY run_at LIMIT $1
    FOR UPDATE SKIP LOCKED)
UPDATE jobs j SET state = 'running', lease_token = gen_random_uuid(),
       lease_expires = now() + $2, attempts = j.attempts + 1
FROM c WHERE j.id = c.id
RETURNING j.id, j.lease_token, j.payload;
```
Complete with `UPDATE jobs SET state = 'done' WHERE id = $1 AND lease_token = $2`: zero rows means the lease expired and another worker owns the job. Jobs must be idempotent, since a lease can expire mid-run; dead-letter after N attempts. A queue lives on vacuum: per-table `autovacuum_vacuum_scale_factor = 0` with a fixed `autovacuum_vacuum_threshold`, finished rows purged, and no long transaction in the database, or dead rows at the head of the index slow every claim.

**Change feeds** (sync, replay, polling consumers). Identity values, UUIDv7 and `now()` are assigned before commit, so a reader paging by `id > cursor` permanently skips a row whose transaction commits after a later row was read. Cursor on commit order instead:
- logical decoding (CDC), which emits changes in commit order;
- a commit horizon: `txid xid8 NOT NULL DEFAULT pg_current_xact_id()`, an index on `(txid, id)`, and reads of `WHERE (txid, id) > ($1, $2) AND txid < pg_snapshot_xmin(pg_current_snapshot()) ORDER BY txid, id`. Nothing commits below the oldest running transaction, so no row can appear behind the cursor; a long transaction delays the feed but loses nothing;
- a per-scope counter taken as the transaction's last statement (`UPDATE feed_heads SET seq = seq + 1 WHERE scope = $1 RETURNING seq`), which serializes that scope's writers.

## 8. `updated_at`

Either a `BEFORE UPDATE` trigger (`NEW.updated_at := now()`) or the ORM sets it, never both: mixed writers leave some updates unstamped. A no-op UPDATE still writes a row version: skip it in the statement (`WHERE col IS DISTINCT FROM $1`), or add `suppress_redundant_updates_trigger()` under a name that sorts before the `updated_at` trigger (triggers fire in name order; after the stamp, every row differs).
