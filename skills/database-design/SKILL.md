---
name: database-design
description: |
  PostgreSQL data modeling and operations. Design: tables, keys,
  invariants and constraints, indexes from access paths, tenancy and RLS,
  isolation and locking, partition layout, migration plans, schema review;
  writes docs/arch/database.md and migrations. Operations: slow-query and
  load triage, lock-safe migrations and backfills on live tables, pooling,
  VACUUM, wraparound, incidents. Use for "design a database", "review
  this schema", "add an index", "the database is slow", "run this migration
  safely", "upgrade Postgres". Do NOT use for: choosing the store or
  tenancy model (software-architecture); ORM, repository or migration-tool
  wiring (hexagonal-backend); PR diff review (review-checklists).
---

# PostgreSQL Database Design & Operations

The schema is the system's longest-lived contract: code rolls back in seconds, a dropped column does not. Part 1 designs it from invariants and access paths (WHAT); Part 2 changes and runs it under live traffic without stalling it (HOW).

**Ownership.** Writes the database design doc (default `docs/arch/database.md`; caller may redirect) and migrations in the project's tool format. Reads the PRD, feature specs and architecture docs without editing them; a missing input becomes a question in the report. The architecture docs own the store, the tenancy model, any architecture-level partition key and the retention policy: realize them and state any deviation inline. One-way data decisions that change the architecture surface (key strategy, partition key, tenancy model) are reported as `ADR owed: <decision>, <door type>` and recorded via the arch-decision capability, if available; this skill writes no ADRs.

**Engine.** On another engine (SQLite/D1, MySQL) apply the modeling method (Modeling for Change, Stages 1–2) and flag each PostgreSQL-only mechanism (RLS, EXCLUDE, `CONCURRENTLY`, `uuidv7()`) instead of emitting it.

## Stage 0 — Classify & Calibrate

**Classify the request; depth follows the class.**

| Request | Path | Deliverable |
|---|---|---|
| New schema or domain | Stages 1–4 | database.md + migrations |
| Change a live schema or its data | Existing system first, then Stages 1–4 for the touched tables only | migrations + runbook rows + database.md patch |
| Review an existing schema | When Reviewing an Existing Schema | ranked findings; write nothing |
| Slow query, endpoint or database; incident, maintenance, live partitioning, major upgrade | PostgreSQL Operations (Part 2) | that reference's report |

**Budgets size the record, never the analysis.** Run every check the class needs (the problem behind the request, the numbers, the traps, every party the change touches) before deciding what to write; a scope cut is stated with its reason and still leaves the end consumer a working result.

**Small requests: short answers, full checks.** One column, index or constraint: ask only for the version, the runner's transaction scope, the table's size and write rate, and the stall budget, and skip Modeling for Change, sizing and the ERD. Still run what changes the answer: an index passes the Index gate (Stage 3), every variant of its endpoint and the table's existing indexes included; a constraint starts with the violation query on existing rows; a rename, retype or drop inventories its consumers (Stage 4). Deliver the migration, its down step and runbook rows, then each material finding in one line (another variant still slow, a redundant index to drop, a trade-off the owner must decide); patch database.md only if a decision changed.

**Find the problem behind the request.**

| Asked for | Usually means | Ask first |
|---|---|---|
| "Partition this table" | retention, vacuum or index upkeep no longer fits | Which predicate or lifecycle operation would use the key? |
| "Make it SERIALIZABLE", "add locking" | an invariant is breaking | Which "never X"? Can a constraint or one statement hold it? |
| "Optimize this query", "add an index" | an endpoint or the whole database is slow; the named query may be one variant of several, or not what owns the load | One endpoint or everything? Every variant the endpoint issues, with frequency and plan, and the table's existing indexes (Index gate; Part 2) |
| "Denormalize for speed" | a join or aggregate is slow | What does it cost at target volume? |
| "JSONB so we can move fast" | the shape is unknown | Which keys will a query filter, sort or constrain? Those are columns. |
| "Soft delete everything" | fear of losing data | Which rows must stay referenced or restorable? History goes to an audit table. |
| "Raise `max_connections`" | slow or idle-in-transaction sessions hold the connections | Which state holds them? (`scripts/query_diagnostics.sql` §1, §3) |
| "We need a bigger instance" | demand grew on a sound plan, a plan flipped, or the working set outgrew RAM | Which statements own the time in a window, and did their calls or their cost per call grow? (`query_diagnostics.sql` §6 window) |

**Existing system first.** Read the migration tool and its latest migrations, the ORM models, and each touched table's size, write rate (`pg_stat_user_tables` deltas), constraints and consumers; run `scripts/schema_review.sql` when a database is reachable. Its conventions (key type, naming, time types, migration format) beat this skill's defaults: never graft UUID keys onto a BIGINT schema.

**Architecture docs** (default `docs/arch/`, read-only): `context.md` §2 Scale Envelope, §3 ASRs, §4 Domain Model; `system.md` §3 Stores, Data Inventory, Tenancy, Partitioning, §4 Scaling Ladder, §5 SLOs and Write-path Integrity (binding).

**Ask once, in one batch, only what the docs and code cannot answer**, each as: question *(default; what it gates)*. A subagent that cannot ask applies the defaults and lists them as assumptions.
- Engine, major version, host *(from the compose image, CI or platform config, else the newest GA major; version-gated syntax, each with its fallback)*
- Pooler *(transaction pooling; tenant context per transaction, migrations over a direct connection)*
- Migration tool and its transaction scope: none, per file, per run, or one per multi-statement string *(detected from the tool; where strong-lock steps, `CONCURRENTLY` and backfills run)*
- Tenancy *(system.md, else single-tenant; keys, uniqueness, RLS)*
- What must never happen *(the PRD; always ask about money, capacity and identity; the invariants)*
- History, deletion and erasure duties *(hard delete plus audit; lifecycle)*
- Hot tables: rows/day, update or append, largest table today; other readers (BI, exports, search, CDC) and their freshness *(Scale Envelope, else none; sizing, migration path, replicas or summary tables, consumers)*
- Deploy model *(rolling, old code live during the deploy; N-1 steps)*
- Stall budget of the hottest query on each touched table *(its p99 latency target; `lock_timeout`)*

**Done** when a reader can trace every "never X" to its mechanism, every index to the paths it serves, and every migration step to its lock, its N-1 safety and its undo, and the Self-Review passes.

## Modeling for Change

The consequential choice is what to model rigidly and what loosely.

| | Core (where the business differentiates) | Supporting (settings, integrations, metadata) |
|---|---|---|
| **Stable shape** | Fully normalized, rich constraints, deliberate transaction design. Invest here. | Plain and lookup tables; don't over-model. |
| **Volatile shape** | Stay relational and constrained; absorb change through migrations, not by softening the model. | The one quadrant where JSONB or config-driven shape is the default, still on a relational spine. |

**Flexible shape vs flexible process.** A generic model (EAV, JSONB for everything) dodges DDL by giving up integrity, statistics and query-shaped indexes, and scatters invariants into application code that drifts. Make migrations routine instead (expand-contract, `NOT VALID` → `VALIDATE`, `CONCURRENTLY`, N-1 steps): a fully constrained schema stays changeable weekly.

- Most "fast-changing requirements" are policy (pricing rules, eligibility, workflow steps): config rows or code, not DDL; three boring nullable columns beat a homegrown rules engine.
- When user-defined structure is the product (custom fields, CMS, CRM), a flexible core on a typed, indexed relational spine is correct; write down the invariants it leaves to the application.
- Decide the spine, the invariants and the one-way doors (key type, tenancy model, distribution key) for the product vision; add columns only for features being built. YAGNI applies to shape, never to invariants.

## Design (Part 1 — WHAT)

### Stage 1 — Model

Each answer becomes a constraint, a column or a table.
1. **Grain.** One row = one what? If it takes more than five words, it is two tables.
2. **Uniqueness scope.** Every business key states its scope (global, tenant, parent, live row, period) and declares exactly that: `UNIQUE (tenant_id, slug)`, a partial unique index `WHERE deleted_at IS NULL`, uniqueness on the normalized form (`lower(email)`), or EXCLUDE / PG18+ `WITHOUT OVERLAPS` for periods. *Break when* the identifier is truly global, such as an external system's id.
3. **Snapshot or reference.** The same fact, or the fact as of an event? An order line copies price, tax rate, currency and address: a snapshot, not denormalization, and it needs no sync.
4. **Source of truth.** Data owned elsewhere (payments provider, identity provider) gets a mirror keyed by the external id, ingested idempotently by event id and guarded against out-of-order events with the source's version.
5. **Duplication.** Normalize until each fact has one home. A deliberate duplicate names its source, sync mechanism, staleness bound and drift query (`references/design-patterns.md` §1); a counter on a parent row serializes every child insert.
6. **Lifecycle.** Take each data set's class, retention and erasure duty from system.md §3 Data Inventory (else ask). History goes in an audit table; event sourcing only when the events are the domain. Retention runs as a partition drop or batched deletes. Personal data has an erasure path that reaches its copies (audit, events, backups). Tag each column's class in `COMMENT ON COLUMN`: it decides redaction, encryption, erasure and grants.
7. **Keys** (a one-way door). UUIDv7 by default (`uuidv7()` on PG18+, else an RFC 9562 v7 generator in the application); BIGINT IDENTITY for internal high-volume tables (8 bytes less per row: ≈8 GB per billion rows in every index and FK carrying it); never UUIDv4 on hot tables, whose random inserts spread writes across the whole index. A v7 identifies but never authorizes and reveals its creation time: share links and reset tokens are random tokens.

Patterns for subtypes, hierarchies, soft delete, audit, temporal data and derived data: `references/design-patterns.md`.

### Stage 2 — Invariants → enforcement

Write each invariant as "never X" (never two active subscriptions per org, never a double-booked seat, never refunded → paid) and enforce it with the first rung that can express it:
1. **A constraint**: NOT NULL, CHECK, scoped UNIQUE, FK, EXCLUDE. A CHECK passes when its expression is NULL, so pair it with NOT NULL; UNIQUE treats NULLs as distinct unless `NULLS NOT DISTINCT` (PG15+).
2. **One guarded statement**: `UPDATE stock SET qty = qty - $2 WHERE id = $1 AND qty >= $2`; for a state transition, `… SET status = 'shipped' WHERE id = $1 AND status = 'paid'`. Zero rows means rejected: a domain outcome, not a retry.
3. **A lock on a guard row** that every writer touches (the parent, the slot), taken in a fixed order. At Repeatable Read a bare lock protects nothing: the guard must be an `UPDATE`.
4. **SERIALIZABLE**, retrying the whole transaction on 40001 and 40P01.

An invariant left to the application names its owner and the reason. *Break when* a rung's measured cost on a write-hot table is unacceptable; record the step down. Read Committed stays the default (Repeatable Read stops lost updates on one row, not write skew). Map every system.md §5 Write-path Integrity row to a rung, taking its outbox, idempotency and inbox tables from `references/design-patterns.md` §7. Mechanics: `references/acid-transactions.md`.

### Stage 3 — Physical design

**DDL defaults** (break conditions in `references/data-types-guide.md`):
- Instants `timestamptz`; calendar dates `date`; future wall-clock events (appointments, opening hours, local deadlines) `timestamp` plus an IANA zone column, resolved at use time.
- Money: `bigint` minor units or `numeric` at the currency's scale, beside a currency column; never float or `money`, and no default currency, unit or rate.
- `text`, capped by a named CHECK where length matters; email unique on its normalized form, never validated by regex.
- Closed sets: text plus CHECK; a lookup table keyed by its code when values carry attributes; ENUM only for frozen, ordered sets.
- JSONB only for attributes no hot query constrains or filters; a key becomes a column at its first constraint, FK or hot predicate.
- Every FK states ON DELETE (CASCADE only inside one aggregate, never into financial or audit records) and indexes its child columns unless parent rows are never deleted or re-keyed (say so in a comment).
- snake_case, plural tables, `<singular>_id` FK columns; constraints named `{pk,fk,uq,chk,ex}_{table}[_{columns or role}]` (applications map errors by name); `updated_at` set by a trigger or the ORM, never both.

```sql
CREATE TABLE app.orders (
    id          uuid DEFAULT uuidv7() CONSTRAINT pk_orders PRIMARY KEY,  -- PG18+; earlier: v7 from the app
    tenant_id   uuid NOT NULL,
    customer_id uuid NOT NULL,
    total_minor bigint NOT NULL CONSTRAINT chk_orders_total_minor CHECK (total_minor >= 0),
    currency    text NOT NULL CONSTRAINT chk_orders_currency CHECK (currency ~ '^[A-Z]{3}$'),  -- no default
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_orders_tenant_id_id UNIQUE (tenant_id, id),  -- target of child tables' composite FKs
    CONSTRAINT fk_orders_customer FOREIGN KEY (tenant_id, customer_id)
        REFERENCES app.customers (tenant_id, id) ON DELETE RESTRICT
);
-- path: a customer's orders, newest first; also covers the FK
CREATE INDEX idx_orders_customer ON app.orders (tenant_id, customer_id, created_at DESC);
```

**Tenancy** (model from system.md §3; default single-tenant):
- **Pooled tables**: `tenant_id NOT NULL` on every tenant-owned table, in every UNIQUE, and in composite FKs `(tenant_id, parent_id) → parent (tenant_id, id)`, so no row can point into another tenant; tenant-scoped indexes lead with it. Make the PK `(tenant_id, id)` when tenant sharding is on the Scaling Ladder.
- **RLS** on every pooled table by default, backing up the `tenant_id` predicate every query carries: forced, the app on a non-owner role, the tenant set per transaction, never by a session `SET`. *Break when* its measured hot-path cost is unacceptable: record it in Decisions and aim the cross-tenant test at the query filter. Behind a generated API that queries as the caller's role (PostgREST, Supabase), RLS is the only gate: never off. Wiring: `references/design-patterns.md` §6.
- **Schema-per-tenant** multiplies every migration and the catalog by N. **Database-per-tenant** only for contractual isolation, residency or per-tenant restore.
- **Skew.** Check the largest tenant's share of each hot table (`most_common_freqs` on `tenant_id`, as a role that bypasses RLS). A dominant tenant gets plans fitted to the average one (give its sessions custom plans, `SET LOCAL plan_cache_mode = force_custom_plan`, or add statistics on `(tenant_id, <filter column>)`), and it draws on the CPU, I/O, connections and cache every tenant shares: when its demand drives a slowdown (Part 2 load attribution plus the app's per-tenant request rates), give it a budget (rate limit, its own pool or replica), cache its hot aggregates, or isolate it in its own partition or database. Record which in Decisions.

**Index gate.** Every index added, changed or dropped, in design or in tuning, passes these steps (method and examples: `references/indexing-strategy.md`):
1. **Enumerate the paths.** Each hot path as query shape · frequency · latency need · rows returned, and for an endpoint every variant it issues: each filter and value (one, several, none), each sort, deep pages, and the queries that run beside it (the total count, facet counts). Sources: the query-building code, the table's `pg_stat_statements` entries, the feature spec. The caller names one variant; the index serves the endpoint.
2. **Choose against the whole list.** Tabulate candidates × variants (seek and stop, seek then sort, walk and filter) and keep the set that serves the most traffic with the fewest indexes. Equality columns first, then the `ORDER BY … LIMIT` columns, else the range column. A status-like filter goes in front of the sort, `(tenant_id, status, created_at DESC)`, which serves every value; a partial index names the variants it leaves unserved; several values in one request need the per-value merge.
3. **Reconcile the table's index set.** Show the table's indexes with scan counts and sizes, each marked keep, add or drop: drop what the new index makes a redundant prefix, flag zero-scan indexes for an owner check (counts are per node and restart on a reset), and ship each drop as a runbook row with its definition kept for restore (`scripts/schema_review.sql` §3). On write-hot tables every index taxes each insert and non-HOT update: count them.
4. **Hot-path aggregates** (a count, sum or badge computed per request) are paths too: choose bounded, estimated, cached or index-only (`references/postgresql/query-tuning.md`, Demand on a sound plan) and tell the owner what the choice gives up.

**Size it.** Per hot table, rows/day × bytes/row → size at 1 and 3 years with indexes; sum the hot tables against RAM for the working set. A ×3 error changes nothing; a ×100 error changes the design, so state the inputs. When a database is reachable, seed the hot tables with `generate_series` at realistic skew (≥1M rows), ANALYZE, then measure bytes per row (`scripts/schema_review.sql` §10) and run EXPLAIN on the seed: plans on empty tables prove nothing.

**Partitions.** Weigh partitioning from the month a hot table outgrows memory ("logs feel big" is not a reason); it pays only when a predicate or lifecycle operation uses the key, and every PK and UNIQUE must then include it. An architecture-level key comes from system.md §3 Partitioning; the method, interval and layout are yours: `references/performance-patterns.md`.

### Stage 4 — Migration plan

- **N-1 safe.** Every step works with both the deployed and the incoming code, so an app rollback never needs a schema rollback: expand steps ship tested down SQL; irreversible contract steps wait for a verification window, a PITR target and an archive (`references/migration-patterns.md`). *Break when* a maintenance window is acceptable.
- **Schema is a contract.** Before any rename, retype or drop, inventory every consumer beyond the deploying app (logical-replication subscribers, which get no DDL: add columns there first, drop them there last; CDC/ETL; sibling services; materialized views; API serializers) and expand-contract across all of them.
- **Label every statement** with its lock and work class from `references/migration-patterns.md`; an ACCESS EXCLUSIVE scan or rewrite on a live table takes that file's online path.
- **Format.** SQL in the project tool's format and directory, split into files or runs that fit the runner's transaction scope (`references/migration-patterns.md`, Connection and tool); say where each step runs. With no tool: `<UTC timestamp>_<verb>_<domain>.sql` plus `.down.sql` for reversible steps, in the migrations directory (default `db/migrations/`; caller may redirect), one file per domain in the PRD's dev order, tables tagged with their feature (`-- [billing]`). Never edit an applied migration; no auto-DDL (`synchronize: true`) in deployed environments.
- **Standing guards.** In CI, build a scratch database from the migration chain and diff its `pg_dump --schema-only` against each long-lived environment (drift), and run the previous release's tests against the new schema (N-1). Monthly and after launches, run `scripts/schema_review.sql` against production; keep `pg_stat_statements` enabled so `query_diagnostics.sql` §6 has history.

## When Reviewing an Existing Schema

Read-only by default; write only when asked.
1. **Evidence**, in this order: `scripts/schema_review.sql` on the live catalog, else the migration chain, then the ORM models. Drift between them is itself a finding.
2. **Violation queries** before ranking an unenforced invariant: duplicates on the normalized key, orphans, NULLs where none belong, int4 key headroom (`schema_review.sql` §4), and for each tenant gap (§11) child rows whose parent belongs to another tenant. Run them as a role that bypasses RLS: under a policy they count zero. Violating rows make it 🔴 and the fix starts with cleanup; none make it 🟠, except cross-tenant reachability, which is 🔴 regardless.
3. **Order**: invariants → tenancy → keys and types → indexes vs access paths and each other (redundant prefixes, zero scans: `schema_review.sql` §3) → lifecycle → growth headroom (hot tables vs RAM at 1 and 3 years; the distribution key where sharding is on the Scaling Ladder) → pending migrations → access control → naming.
4. **Rank** (compatible with software-architecture's rubric):
   - 🔴 cross-tenant reachability (tenant missing from a UNIQUE or FK, RLS not forced, the app connecting as table owner, a table in an API-exposed schema without RLS); money in float; cascades into financial records; an int4 key past half its range; personal data with no erasure path (immutable payloads included).
   - 🟠 a pooled table without RLS and no recorded break condition; an unindexed FK on a parent that gets deleted; a hot path with no index; retention that cannot execute; a hot table outgrowing memory with no partition or retention plan; a pending migration that is not N-1 safe or locks a hot table; UUIDv4 keys on hot tables; catalog drift.
   - 🟡 redundant data or indexes; a model that drifted from the domain.
   - 🟢 naming and consistency.

Report in ≤1,200 words, findings first; patch text only for 🔴 and 🟠; a finding past the budget shrinks to one line, never drops.

## PostgreSQL Operations (Part 2 — HOW)

Route by the first evidence; each reference holds the report format to write from.

| Request | First evidence | Read | Deliver |
|---|---|---|---|
| DDL or backfill on a live table | lock and work class; size and write rate; oldest snapshot; replica lag | `references/migration-patterns.md` | runbook rows + ≤150 words of notes |
| Slow query, endpoint or database | one endpoint or everything; statements by share of total time over a window, each split into calls/s and mean; reproduce as the app runs it; `EXPLAIN (ANALYZE, BUFFERS)` | `references/postgresql/query-tuning.md` | load table, causes ranked with before/after, index-set changes, follow-ups; ≈150 words per cause |
| Query shape: pagination, UPSERT, search, import, time buckets, hot rows | the query, its index and the code that calls it | `references/postgresql/query-patterns.md` | the query, its index and the calling code |
| Incident: stalls, errors, connection exhaustion | what changed, and when; sessions by wait event; the root blocker (`scripts/query_diagnostics.sql` §1–2); the load window (§6) | `references/postgresql/production-ops.md` | stabilize first; load table, causes ranked; ≈300 words plus ≈100 per further cause |
| Maintenance: vacuum, bloat, wraparound | xmin holders, freeze age (`query_diagnostics.sql` §4–5) | `references/postgresql/production-ops.md` | runbook rows |
| Partitioning a live table, replicas, scale-out | system.md §3–§4; the lifecycle operation the key serves | `references/performance-patterns.md` | layout + runbook rows |
| Major-version upgrade or host move | extensions and their target versions; size; downtime budget; replicas and CDC consumers | `references/postgresql/production-ops.md` (Upgrades) | runbook rows |

**Done** when the same reproduction or metric shows each fix, before and after; the named causes together account for the load behind the symptom (slowness across endpoints is a shared resource running out, and a regressed statement that owns a few percent of it is a finding, not the cause); and an incident report names the lasting fix and the alert that would have caught it.

**On every live table:** strong-lock steps under `lock_timeout` at the stall budget, retried with jitter on 55P03; `CONCURRENTLY` with `lock_timeout` and `statement_timeout` at 0 (a cancel leaves an invalid index or a pending detach), outside any transaction block, then an `indisvalid` check; one DDL step per transaction; backfills bounded per batch; data steps on RLS tables as a role that bypasses RLS; migrations over a direct or session-pooled connection.

## Output

**The database design doc** (default `docs/arch/database.md`) records decisions and their reasons, never this skill's steps. Write it from this skeleton:

```markdown
# Database Design: <system>
<!-- Budget, excluding DDL and ERD: ≤400 words for 1–3 tables (no ERD); ≤1,200 for a domain; ≤2,500 for a product.
     Sections are a menu: omit any that would be empty, heading included. A patch edits only the sections it changes. -->
## Decisions         <!-- one-way doors and departures from defaults: choice · rejected alternative · why · revisit when -->
## Model             <!-- Mermaid ERD of entities, keys and cardinality (references/mermaid-erd.md); columns live in the DDL -->
## Invariants        <!-- never X → constraint | guarded statement | lock | isolation level, or the app owner -->
## Access paths      <!-- path and its variants · frequency · latency need → index; indexes dropped as redundant -->
## Tenancy & access  <!-- model · RLS yes/no · roles -->
## Lifecycle         <!-- per table: history, retention mechanism, erasure path, soft delete yes/no -->
## Sizing            <!-- inputs → rows and bytes at 1 and 3 years; working set vs RAM -->
## Migration plan    <!-- step · lock/work class · N-1 safe · duration on the largest table (timing: references/migration-patterns.md, Runbook) · reversible -->
## Open questions    <!-- each with the default assumed meanwhile -->
```

**Migrations** follow Stage 4. **Report back** in about 150 words plus one line per material finding: files written, one-way doors, `ADR owed` items, defaults assumed, open questions, migration risks, and anything the reader must act on.

## Self-Review

Skip items for stages that did not run.
- Every invariant has a rung or a named owner; every system.md Write-path Integrity row maps to one.
- Every business key declares its uniqueness scope. No float or `money` for money, no default currency or rate, `timestamptz` for instants, ON DELETE on every FK.
- Index gate: every non-constraint index names the paths and variants it serves, chosen against every variant of its endpoint (a partial index names what it leaves unserved); every hot path has an index; the table's index set was listed with scan counts, redundant prefixes dropped as runbook rows and zero-scan indexes flagged for an owner check; EXPLAIN ran on seeded data when a database was reachable.
- Tenancy: `tenant_id` in every UNIQUE and FK (`schema_review.sql` §11 empty or explained); RLS forced where on, and on for every table in an API-exposed schema; as the app role with tenant A set, every scoped table returns no rows of tenant B and rejects an insert of B's id.
- One-way doors recorded with their rejected alternatives; `ADR owed` items listed.
- Every growing or personal table has a retention mechanism and an erasure path.
- Every migration statement carries its lock and work class and a timed or estimated duration; no ACCESS EXCLUSIVE scan or rewrite on a live table exceeds the stall budget or shares a runner transaction with a later step; every step is N-1 safe; `CONCURRENTLY` runs with both timeouts at 0; every backfill is keyset-walked, idempotent, resumable, bounded, throttled and, on RLS tables, run as a role that bypasses RLS.
- Part 2: load attributed before any cause was named (statements by share of a window, growth split into calls/s and mean ms); every cause that owns a material share named with its numbers (the lowest node misestimated 10× or more, the call-rate growth and its source, or the root blocker); each fix at the cheapest layer that works; the reproduction prepared, run 6+ times, as the app role.
- Delivered calling code checked at its edges: pagination fetches one extra row and returns no next cursor after an exactly full last page; cursors carry every sort key at full precision; retries are bounded and jittered.
- Every version-tagged feature (PG15+ to PG19+, collation behavior included) matches the target version or names its fallback.
- **Footprint**: database.md within its budget for the request's size; one runbook row per step; each report within its per-cause or per-finding budget; no material finding dropped to fit, and every trade-off and follow-up the reader must act on stated in the reply, not only in a script comment or a file.
