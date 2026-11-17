# Access: readers, roles and agents

Who may do what, enforced where it cannot be argued with. Two things changed with AI: most of a schema's readers now arrive knowing only the catalog, and some principals write their own SQL. The SQL here was run on PostgreSQL 18; the behavior it relies on is listed in §4.

## 1. A catalog a stranger can query

A model writing SQL, a new session or an analyst sees names, types, constraints and comments, and nothing else. Measurements agree on what helps (`references/landscape.md`): the business rules a query must apply matter most, descriptions help mainly where names are poor, and a wrong or stale description lowers accuracy. So:

- **Names say what a value is, with its unit**: `total_minor`, `duration_ms`, `starts_at`, `is_trial`. Nothing to decode, and one name per concept across tables: `customer_id` everywhere, never `cust_id` here and `client` there. Two different things never share a name.
- **One meaning per column.** No column whose meaning depends on another column, and no magic values (`-1`, `'N/A'`, year 9999).
- **The catalog lists the legal values**: a CHECK or a lookup table for every closed set, so a reader learns the values of `status` from the schema instead of guessing `'canceled'` against `'cancelled'`.
- **Every reference is a declared foreign key.** Joins are discovered from constraints.
- **A rule every correct query needs is built into a view** (live rows only, test accounts excluded, one currency), and readers get the view. A filter left to memory is the one a stranger omits, and the query still runs and returns a plausible number.
- **Comments carry what a name and type cannot**: a table's grain, a unit or zone, the source system, a rule ("refunds are separate negative rows"), `DEPRECATED: use <x>`. Ship each in the migration that makes it true. Never restate the name, and delete a comment rather than leave it wrong.
- **Fewer, less similar things.** `orders`, `orders_v2` and `orders_backup` side by side is a coin toss: drop dead tables, or keep them out of every schema readers can see.

```sql
COMMENT ON VIEW   reporting.order_lines IS 'One row per line of a paid order. Refunds are separate negative rows.';
COMMENT ON COLUMN reporting.order_lines.net_minor IS 'Line total after discounts, before tax, in minor units of currency.';
COMMENT ON COLUMN app.orders.legacy_state IS 'DEPRECATED: use status.';
```

## 2. Roles

One role per kind of principal, one login per principal, and nothing connects as the owner.

| Role | Who | Holds | Never |
|---|---|---|---|
| `app_owner`, NOLOGIN | owns schemas and tables; migrations' DDL runs as it | DDL | a login |
| `app_rw` | the application | DML on `app`, through RLS | DDL, ownership, BYPASSRLS |
| `app_maint`, NOLOGIN, BYPASSRLS | backfills, purges, cross-tenant jobs | DML across tenants | request traffic |
| `app_reader`, NOLOGIN | the privilege bundle for readers | SELECT on the reading surface (§4) | base tables, any write |
| one login per reader | a BI tool, an analyst, an agent | membership in `app_reader` | a shared credential |

```sql
CREATE ROLE app_owner NOLOGIN;
CREATE ROLE app_rw LOGIN PASSWORD '…';         -- not owner, not superuser, no BYPASSRLS
CREATE ROLE app_maint NOLOGIN BYPASSRLS;
CREATE SCHEMA app AUTHORIZATION app_owner;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;    -- the default since PG15; upgraded clusters keep the old grant
REVOKE TEMPORARY ON DATABASE appdb FROM PUBLIC;   -- grant it back to the roles that need temp tables
GRANT USAGE ON SCHEMA app TO app_rw, app_maint;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw, app_maint;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;   -- then grant per function
```
- `ALTER DEFAULT PRIVILEGES` without `FOR ROLE` covers only objects created by the role running it, so name the migration role. The `REVOKE … FROM PUBLIC` form works only without `IN SCHEMA`.
- New functions are executable by everyone unless that default is revoked, `SECURITY DEFINER` ones included; each of those sets `search_path = pg_catalog, pg_temp`.
- Roles belong to the cluster and migrations to one database: create roles in a bootstrap step that tolerates their existence, and never drop them in a down file. Creating them needs CREATEROLE, and a managed host may refuse BYPASSRLS: there, give `app_maint` and `reporting_owner` a `USING (true)` policy on each table they must read across tenants.

## 3. Tenancy and RLS wiring

Behind your own API, RLS backs up the `tenant_id` predicate every query still carries: the planner needs that predicate to choose indexes and prune partitions at plan time.
```sql
ALTER TABLE app.orders ENABLE ROW LEVEL SECURITY, FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON app.orders TO app_rw
    USING (tenant_id = (SELECT NULLIF(current_setting('app.current_tenant', true), '')::uuid));
```
- **FORCE**, or the table owner bypasses the policy; superusers and BYPASSRLS roles (`app_maint`) always do. Under FORCE the owner is filtered too: with no policy of its own it reads and writes nothing, which is why data steps run as `app_maint`.
- **`TO app_rw`.** A policy without `TO` applies to every role, and permissive policies are OR-ed. A reader given its own policy would also pass this one, and this one trusts a setting any session can write (§5).
- **The policy** reads the setting in a scalar subquery, evaluated once per query rather than per row; `NULLIF(…, '')` turns an unset or empty setting into zero rows instead of an error. With no `WITH CHECK`, the USING expression also checks inserted and updated rows.
- **Set the context per transaction**, as its first statement: `SELECT set_config('app.current_tenant', $1, true), set_config('app.actor_id', $2, true);`. It takes bind parameters, which `SET LOCAL` cannot. A session `SET` survives into the next client's transaction under transaction pooling, and NULLIF catches an unset value, not a stale one.
- **Views** over RLS tables that should apply the caller's policies: `CREATE VIEW … WITH (security_invoker = true)` (PG15+). Otherwise a view applies its owner's privileges and policies, and bypasses RLS whenever the owner does. An invoker view needs the caller to hold SELECT on every column it touches, predicate columns included.
- **Generated APIs** (PostgREST, the Supabase Data API): an exposed table without RLS is open to every role granted on it. Keep what the API must not serve in an unexposed schema; give every exposed table RLS, per-role policies with `WITH CHECK` on writes, the caller's identity in a scalar subquery (`(SELECT auth.uid())` on Supabase), and column grants for columns users must not change. A service key bypasses all of it and belongs to no client, no agent and no browser.

## 4. A reading surface

Readers get a schema of views built for reading (shape: `references/modeling.md` §10), owned by a role that holds only the base-table grants the views need. This one reads across tenants: it is for the company's own analysts and agents, never for a tenant's users (§5).
```sql
CREATE ROLE reporting_owner NOLOGIN BYPASSRLS;        -- or a per-table policy: §2
CREATE ROLE app_reader NOLOGIN;
CREATE SCHEMA reporting AUTHORIZATION reporting_owner;
GRANT USAGE ON SCHEMA app TO reporting_owner;
GRANT SELECT ON app.orders TO reporting_owner;        -- table by table: what the surface is built from
GRANT USAGE ON SCHEMA reporting TO app_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE reporting_owner IN SCHEMA reporting GRANT SELECT ON TABLES TO app_reader;

SET ROLE reporting_owner;
CREATE VIEW reporting.orders AS                       -- owner's rights: readers hold no grant on app.orders
SELECT id, tenant_id, status, total_minor, currency, created_at     -- no email, no free text
FROM app.orders WHERE deleted_at IS NULL;
RESET ROLE;

CREATE ROLE analyst_agent LOGIN PASSWORD '…' IN ROLE app_reader CONNECTION LIMIT 4;
ALTER ROLE analyst_agent SET default_transaction_read_only = on;
ALTER ROLE analyst_agent SET statement_timeout = '15s';
ALTER ROLE analyst_agent SET idle_in_transaction_session_timeout = '30s';
```
A view owned by the table owner returns nothing here: under FORCE the owner is filtered, and no tenant is set.

**What holds, and what is only a default** (each line was tried as the role):
- **Grants hold.** With no INSERT, UPDATE or DELETE on any table and no CREATE on any schema, the role writes nothing, whatever it sets. Read-only is a grant, not a setting.
- **Role settings are defaults the session can change.** The reader ran `SET statement_timeout = 0` and `SET default_transaction_read_only = off` and both took effect. They also apply at login only, never on `SET ROLE`. A timeout binds when the tool that owns the connection sets it per transaction (§5).
- **PUBLIC grants more than expected**: temp tables in the database and EXECUTE on every new function (both revoked in §2).
- **The catalog is readable by every role**: table, column and role names and view definitions are visible without any grant. No secret in a name, a comment, a default or a view body.
- **Nothing in core caps the rows returned or a plan's cost.** `temp_file_limit` (set by a superuser) caps disk spill, `CONNECTION LIMIT` caps sessions, and a replica keeps a reader's load off the primary. Row caps belong to the tool.
- `pg_read_all_data` is too wide for any of this: it reads every schema, audit and secrets included.

## 5. Principals that write their own SQL

An agent, a text-to-SQL feature or a database tool server sends SQL that a model composed, and anything that model read (a ticket, a web page, a row) may have steered it. Its limits are the role's grants. A prompt, a parser in the tool or a "read-only mode" is a courtesy on top.

- **Read path.** A login in `app_reader`, on a replica when one exists. The tool that owns the connection sends one statement per call through the extended protocol, because a multi-statement string walks out of a read-only wrapper (`COMMIT; DROP …`). It runs each statement as `BEGIN READ ONLY; SET LOCAL statement_timeout = '15s'; <statement>; ROLLBACK`, which also discards anything the statement set, caps the rows it hands back, and logs the statement with the principal.
- **A setting-based tenant policy does not confine a SQL writer.** Any session can call `set_config`, inside a single SELECT and inside a read-only transaction: with the tool's tenant set to A, `WITH s AS MATERIALIZED (SELECT set_config('app.current_tenant', '<B>', true)) SELECT … FROM s, app.orders` returned B's rows. For a tenant-scoped principal that writes SQL, bind the tenant to something SQL cannot change: a login role per tenant (below), a database or branch per tenant, or no free SQL at all, only named, parameterized queries.
  ```sql
  CREATE TABLE app.tenant_readers (rolname name PRIMARY KEY, tenant_id uuid NOT NULL);
  CREATE FUNCTION app.reader_tenant() RETURNS uuid
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
  AS $$ SELECT tenant_id FROM app.tenant_readers WHERE rolname = session_user $$;

  CREATE ROLE tenant_reader NOLOGIN;
  GRANT USAGE ON SCHEMA app TO tenant_reader;
  GRANT EXECUTE ON FUNCTION app.reader_tenant() TO tenant_reader;
  GRANT SELECT (id, tenant_id, status, total_minor, currency, created_at) ON app.orders TO tenant_reader;
  CREATE POLICY tenant_reader_isolation ON app.orders FOR SELECT TO tenant_reader
      USING (tenant_id = (SELECT app.reader_tenant()));

  CREATE ROLE reader_tenant_a LOGIN PASSWORD '…' IN ROLE tenant_reader;   -- one per tenant
  INSERT INTO app.tenant_readers VALUES ('reader_tenant_a', '…');
  ```
  Logged in as `reader_tenant_a`, forging `app.current_tenant` changes nothing, because `tenant_isolation` is scoped `TO app_rw`.
- **Write path.** An agent changes data through the application's commands (its API, a queue, or `SECURITY DEFINER` functions that take parameters), which carry the invariants, the authorization, the idempotency key and the audit actor. It never holds `app_rw`, the owner, a service key or a BYPASSRLS role.
- **Schema path.** An agent writes migrations as files and runs them on a scratch database or a branch (`references/proof.md`); production applies them through the release pipeline. No credential it can read may drop the database, its volumes or its backups: those are provider tokens, outside every grant here, and the recorded incidents went through them (`references/landscape.md`).
- **Stored text is untrusted input to whoever reads it.** A column holding text that users wrote or that was fetched from outside (tickets, messages, display names, documents) can carry instructions aimed at a model. Tag it in its comment (`untrusted text`), leave it out of the reading surface unless the task needs it, and give a context that reads it no power to write or send (the ai-architecture capability's three-leg check, if available).
- **Experiments** run on a branch or a scratch copy with personal data masked, never against production data with a writing role.

## 6. Test as the role

Log in as each role (role settings apply at login) and run what it must not be able to do:
- **Application role, tenant A set**: every tenant-scoped table returns zero rows of tenant B, and an insert carrying B's id fails. Behind a generated API, the same through the API with A's claims.
- **Reader**: a write, a base-table read, a temp table, and a write after `SET default_transaction_read_only = off` all fail.
- **Tenant-scoped reader**: after forging the application's setting, it still sees one tenant, and no ungranted column.
