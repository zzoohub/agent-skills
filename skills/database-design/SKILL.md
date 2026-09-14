---
name: database-design
description: |
  Expert guide for PostgreSQL database design, modeling, and optimization:
  table design, schema modeling, index strategy, normalization/denormalization,
  ACID transaction design, partitioning, multi-tenancy/RLS, isolation levels,
  migration planning, and schema-level performance tuning.
  Use when user asks to "design a database", "create tables", "model data",
  "add indexes", "normalize", "denormalize", "partition", "multi-tenant/RLS",
  "isolation level", "plan migration", "review schema", "design ERD", or
  discusses data modeling or PostgreSQL performance.
  Do NOT use for simple SELECT queries, SQL syntax questions, non-database
  application logic, writing/EXPLAIN-tuning queries, or the lock-safe
  EXECUTION of a migration against live traffic — CONCURRENTLY vs NOT VALID,
  batching a live backfill, expand-contract under load (use postgresql skill).
  This skill decides WHAT schema change to make and how to structure migration
  files; postgresql decides HOW to run it safely in production.
---

# PostgreSQL Database Design Skill

PostgreSQL-specific database design skill. Provides systematic guidance from schema design through performance optimization.

## Core Principles

### 1. Think First, Design Later
Database design must be completed before writing code. Always follow this sequence:

1. **Requirements analysis**: What data, who uses it, how is it accessed?
2. **Conceptual → Logical → Physical**: name entities, relationships, and business rules *before* columns and types. The conceptual/logical pass (on paper, platform-neutral) is where the expensive mistakes — wrong entity boundaries, a missed many-to-many, a mis-identified business key — are still cheap to fix; descend to physical DDL/ERD only once they hold.
3. **Explicit trade-offs**: Every design decision has a reason and a cost — and the cost includes future *change* cost, not just storage and latency (see **Modeling for Change**)

### 2. PostgreSQL First
- All examples and DDL use PostgreSQL syntax
- Actively leverage PostgreSQL-specific features: JSONB, Array, Enum, Partial Index, CTE, Window Functions, Range Types, Row-Level Security
- Consult `references/` files for detailed guidance as needed

### 3. Naming Convention

Pick one and apply consistently — the value is uniformity, not the specific choice.

```
Schemas:      snake_case, abbreviated (fin, hr, mkt)
Tables:       snake_case, plural (`user_accounts`, `orders`). Plural is the industry default and avoids reserved-word collisions (`order` → `orders`). FK columns stay singular: `user_account_id REFERENCES user_accounts(id)`.
Columns:      snake_case, no table prefix (name, NOT user_name in user table)
PK:           id (surrogate) or meaningful natural key
FK:           referenced_table_id (e.g., user_id, order_id)
Indexes:      idx_{table}_{columns} (e.g., idx_orders_created_at)
Constraints:  {type}_{table}_{columns} (e.g., uq_user_email, chk_orders_amount)
Enums:        snake_case (order_status, NOT OrderStatus)
```

## Modeling for Change: Core vs Supporting, Stable vs Volatile

The most consequential schema decision is not a data type — it's deciding **what to model rigidly and what to model loosely**. Two axes settle it:

- **Position** — is this the *core* subdomain where the business differentiates, or a *supporting/generic* one (settings, integrations, metadata)? Spend your scarcest modeling effort on the core (DDD). "Model core differently" does **not** mean "softer at the core" — the opposite: the core is exactly where you most want `NOT NULL` / `FK` / `CHECK` / `UNIQUE`, because the core's invariants *are* the business.
- **Rate of change** — is the shape stable, or does it churn with every requirement?

|              | **Core / differentiating** | **Supporting / generic** |
|---|---|---|
| **Stable**   | Fully normalized, rich constraints, explicit aggregate boundaries, deliberate transaction design. Invest here. | Simple relational + lookup tables. Don't over-model. |
| **Volatile** | Keep the shape relational and constrained; absorb change through the **migration machinery**, not by softening the model. | The one quadrant where JSONB-hybrid / config-driven / app-layer flexibility is the *default* — and even here keep a relational spine. |

This is the single rule that unifies the otherwise-scattered `ENUM`-vs-lookup, STI-vs-CTI, and JSONB-hybrid heuristics elsewhere in this skill.

### Two kinds of agility — keep them straight

"Agile schema" silently conflates two opposite things:

- **Flexible *shape*** — a generic, parameterized model (EAV, JSONB-for-everything) that absorbs change without DDL. Almost always the wrong trade: it buys malleability by surrendering the integrity guarantees and query performance that are the database's reason to exist, and relocates every invariant into N application call sites that drift. Its named failure modes — **EAV / inner-platform effect**, the **JSONB swamp** (no planner statistics, no query-shaped indexes), and **speculative generality / YAGNI** (an abstraction tax paid every day for requirements that never arrive) — are the anti-patterns this section exists to prevent. None is a substitute for modeling.
- **Flexible *process*** — evolutionary database design: version-controlled migrations, expand-contract, `NOT VALID`/`VALIDATE`, dual-write, strangler-fig, `CONCURRENTLY`, mandatory *tested* rollbacks. This is the right agility. `references/migration-patterns.md` is **not merely outage-avoidance — it is the engine that lets you keep a hard, fully-constrained schema and still change it weekly.** A team that runs those patterns routinely does not need a soft schema to move fast.

The schema is your **slowest-changing, highest-blast-radius, longest-lived layer** — code rolls back in seconds; a bad `DROP` on a 500M-row table does not. So **don't soften the model to dodge migration; make migration so routine that a rigid schema costs nothing in speed.** Rigid shape + fluid process are complements, not a trade-off.

### Where volatility actually belongs

Most "fast-changing requirements" are **behavior/policy** volatility — pricing rules, eligibility, workflow steps, feature gating — not data-model volatility. Model those as config rows or application logic so they change without DDL. (Double-edged: pushing *too much* policy into generic config rows re-creates the inner-platform effect one level up; three boring nullable columns are sometimes more testable and auditable than a homegrown rules engine. Judge per case — the question is "is this *shape* volatility or *value* volatility?")

### The one legitimate exception — flexible shape *as the product*

When user-defined structure **is** the differentiator — metadata platforms (Stripe `metadata`), custom fields (Shopify metafields, Salesforce), CMS / CRM / low-code, EHR / FHIR — a **controlled flexible core** is the correct core model, not an edge concession. Keep a relational spine, type what you can, index for the real queries (GIN / expression indexes), and write down which invariants you've chosen to enforce in the application instead of the DB. "Flexibility belongs at the edges" is a strong default *with this real, commercially important exception* — don't apply it as a law.

### Design the spine up front, defer the speculation

"Design for the full product vision" means the **relational spine + integrity invariants + key relationships** — the parts that are cheap to get right now and expensive to retrofit: the **one-way doors** (PK type, tenancy model, partition/distribution key, normalization boundaries). It does **not** mean every speculative column for features not yet being built. **YAGNI applies to *shape*; it does not apply to *invariants*.**

## Workflow: When a Database Design Is Requested

### Step 1: Gather Requirements

**If architecture docs exist** (`docs/arch/`), read them first and extract:
- Domain entities and data flows (from `context.md` §1, §4 and `system.md` §2)
- Storage strategy and database choice (from `system.md` §3)
- Performance/scalability expectations (from `context.md` §3 and `system.md` §5)
- Consistency model (from `system.md` §3)
- Ingestion patterns and data volume (from `context.md` §3)

For most decisions, follow the design doc as-is — it represents system-level decisions already made. However, **independently evaluate** decisions where database domain expertise is more appropriate:

| DB-domain decisions (evaluate independently) | System-level decisions (follow design doc) |
|---|---|
| Normalization level per table | Database platform choice (e.g., Neon PostgreSQL) |
| Partitioning strategy and partition key | System architecture pattern (e.g., event-driven) |
| Index types and index design | Which data goes in which store |
| Transaction isolation level per operation | Consistency model (strong vs eventual) |
| Column ordering and physical layout | Data retention policies |
| Materialized view refresh strategy | Read/write separation boundaries |
| Locking strategy (optimistic vs pessimistic) | Multi-tenancy approach |

If a DB-domain decision differs from what the design doc implies, **state the deviation and the reason explicitly**. Example: "Design doc specifies strong consistency for order processing. For the order listing query, we use a materialized view with eventual consistency (refreshed every 30s) because the read volume makes synchronous joins impractical at the expected scale."

**If no design doc exists**, confirm the following with the user (ask if unknown):
- Domain and core entities
- Read/write ratio (read-heavy vs write-heavy)
- Expected data volume (thousands? millions? billions?)
- Ingestion pattern (append-only, backfill, frequent updates)
- Transaction requirements (ACID strictness)
- Scaling plans (single server vs distributed)

**Size the schema (back-of-envelope)** — turn the scale numbers (from `context.md` §2's scale envelope if present, else the answers above) into per-table arithmetic before any DDL. The numbers gate decisions that are otherwise vibes:

- **Per hot table**: rows/day × bytes/row (padded column widths + ~24B tuple header — see `references/performance-patterns.md` §1) → size at 1yr / 3yr; ×1.3-1.5 for indexes and bloat. Sum the hot tables against RAM — that's the working set.
- **Partitioning gate**: compute months-to-~100M-rows from rows/day. Partition when the table crosses hundreds of millions *within the design horizon* or retention must be a partition drop — not because "logs feel big".
- **PK economics, quantified**: UUID→BIGINT saves 8 bytes × rows × (PK index + every referencing FK column + every index carrying it). At 1B rows that's ~8GB in the PK index alone — that's when "measurably matters" starts. At 10M rows it's ~80MB — irrelevant; take UUID v7's external-safety instead.
- **MV-vs-live-join**: estimate the join fan-out at target volume before reaching for a materialized view (denormalization needs measured cost — `references/normalization-guide.md`).

A ×3 error changes nothing here; a ×100 error changes the design. State the inputs so the arithmetic is checkable; record it in `docs/arch/database.md` under Requirements.

**Feature-aware schema** (read before writing any DDL):

Design the **full relational spine + integrity invariants + key relationships** for the product vision — the one-way doors (PK type, tenancy model, partition/distribution key, normalization boundaries) that are cheap to get right now and expensive to retrofit — **not** every speculative column for features not yet being built (see **Modeling for Change** → "Design the spine up front, defer the speculation"). Then split migrations by domain so features can ship independently.

If the project tracks features in planning docs (e.g. `docs/prd/features/*.md` or any similar `features/` directory), read the relevant spec and **tag tables/indexes with the feature** in comments — e.g., `[auth]`, `[billing]`, `[workspace]`. The tags drive which migration file each table lives in, and the dev order in the PRD determines file numbering (`001_create_user_accounts.sql` → `002_create_workspaces.sql` → ...).

If no such planning docs exist, ask the user which features ship in which order — that order determines numbering.

Don't collapse all of MVP into one mega-migration. Don't over-split into per-table files either — one migration per **domain/bounded context**, holding related tables together.

### Step 2: Schema Design
1. Identify core entities and relationships
2. Normalize to at least 3NF
3. Evaluate denormalization needs → consult `references/normalization-guide.md`
4. Choose appropriate data types → consult `references/data-types-guide.md`
5. Define constraints (PK, FK, UNIQUE, CHECK, NOT NULL)
6. **Classify sensitive columns** at design time (public / internal / PII / regulated) — record the tag in `COMMENT ON COLUMN`. One pass that then drives four decisions the skill otherwise makes ad hoc per column: audit/event-payload exclusion (Critical Rules + `design-patterns.md` §3), column-encryption choice (and its loss of B-tree indexability), erasure obligations (`design-patterns.md` "Erasure vs immutable history"), and GRANT scoping (Roles & Least Privilege)

### Step 3: Transaction & Concurrency Design
→ consult `references/acid-transactions.md`

Identify operations that require explicit transaction design:
- Financial or monetary operations (transfers, payments)
- Inventory or capacity management (stock, seats, quotas)
- Multi-step workflows that must be atomic
- High-contention resources (counters, queues)

For each, decide:
- Isolation level (Read Committed, Repeatable Read, Serializable)
- Locking strategy (optimistic vs pessimistic, advisory locks)
- Retry and deadlock prevention approach

### Step 4: Write DDL
```sql
-- Default skeleton — UUID v7 PK, TIMESTAMPTZ everywhere
-- New tables only; to add a PK/column to an existing table see references/migration-patterns.md
--   (a VOLATILE default like uuidv7() on a new NOT NULL column rewrites the whole table).
CREATE TABLE schema_name.table_name (
    id UUID NOT NULL PRIMARY KEY DEFAULT uuidv7(),  -- PG18+; ≤17: generate at app layer
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- then INTEGER columns, then SMALLINT, BOOLEAN, etc.
);

-- Indexes go in separate statements
CREATE INDEX idx_table_column ON schema_name.table_name (column);

-- Document with comments
COMMENT ON TABLE schema_name.table_name IS 'Table description';
COMMENT ON COLUMN schema_name.table_name.column IS 'Column description';
```

⚠️ The `updated_at DEFAULT now()` only fires on INSERT. To keep it accurate on UPDATE, attach a `BEFORE UPDATE` trigger or manage it at the application/ORM layer — pick one and apply consistently. See `references/design-patterns.md` §9 "Auto-Updated Timestamps".

### Step 5: Index Strategy
→ consult `references/indexing-strategy.md`
- **Every index cites an access path.** List the top access paths first (query shape | expected frequency | latency need), then derive each index from one; record the table in `docs/arch/database.md`. An index serving no listed path is a delete candidate; a hot path served by no index is a seq scan waiting for data volume.
- Verify auto-indexes on PK; manually create indexes on FK columns (PostgreSQL does NOT auto-index FK)
- Identify columns frequently used in WHERE, JOIN, ORDER BY
- Calculate selectivity: distinct values / total rows
- Consider Partial Index, Expression Index, Covering Index (INCLUDE), GIN/GiST/BRIN

### Step 6: Performance Review
→ consult `references/performance-patterns.md`
- Verify execution plans with EXPLAIN ANALYZE
- Consider connection pooling (PgBouncer)
- Evaluate partitioning needs (hundreds of millions of rows+)
- Suggest PostgreSQL configuration tuning
- Design around query patterns: ensure indexes support WHERE/JOIN, limit resultsets, cache computed data

### Step 7: Migration Plan
→ consult `references/migration-patterns.md` — the **engine that lets a rigid schema stay agile** (see **Modeling for Change**), not just outage-avoidance.
- Version-controlled migration scripts
- Rollback scripts are mandatory — and **tested** (run forward → rollback → forward on a production-scale snapshot in CI), not merely written. An untested rollback fails at 3am, which is the only time you need it
- Zero-downtime migration strategies
- **Schema is a contract**: before any rename/retype/drop, inventory who else reads the table beyond the deploying app (read-replica→warehouse, CDC/ETL, sibling services, materialized views, API serializers) and expand-contract across that whole set

### Step 8: Pre-Output Quality Gate

Before writing `docs/arch/database.md` or any migration file, **every Critical Rule (below) must hold** — money is `NUMERIC`, timestamps `TIMESTAMPTZ`, FKs indexed, `ON DELETE` explicit, `CONCURRENTLY` on live tables, destructive ops via expand-contract — plus every item here (these add what the Critical Rules don't cover). A failing item either blocks output or gets explicitly called out in the document with rationale.

**Structural integrity**
- [ ] Every table has a PRIMARY KEY
- [ ] Every FK column used in JOIN or filter has an index (PG does not auto-create); FKs intentionally left unindexed are documented in a comment or ADR
- [ ] Every entity table has `created_at` (and `updated_at` unless append-only). Pure association/pivot tables may omit both when no audit trail is needed
- [ ] ENUMs used only where value set is stable; otherwise lookup table
- [ ] Sensitive columns classified (PII/regulated tagged in `COMMENT ON COLUMN`); PII kept out of audit/event payloads

**Constraints and safety**
- [ ] NOT NULL on every column that logically cannot be null
- [ ] CHECK constraints on domain values (email format, positive amounts, status whitelist)
- [ ] UNIQUE constraints on every business-identity column (email, slug, external_id)

> **NULL semantics:** a `CHECK` passes when its expression is NULL/UNKNOWN — `CHECK (amount > 0)` does *not* reject a NULL `amount`, so pair domain CHECKs with `NOT NULL` when null is invalid. Standard `UNIQUE` treats each NULL as distinct (multiple NULLs allowed); add `NOT NULL`, or use `UNIQUE NULLS NOT DISTINCT` (PG15+), when at most one null-or-distinct row is intended.

**Multi-tenancy (if applicable)**
- [ ] Every tenant-scoped table has `tenant_id` column AND RLS policy — or schema/database-per-tenant is chosen with ADR
- [ ] Composite indexes lead with `tenant_id` where tenant-scoped queries dominate

**Sizing**
- [ ] Size envelope computed for hot tables (rows/day × bytes/row → 1yr/3yr); partitioning and PK-type choices cite its numbers, not vibes

**Indexes**
- [ ] Every index traces to a listed access path (Step 5); no index without a path, no hot path without an index
- [ ] Partial indexes used for low-selectivity boolean/status columns (don't index `WHERE is_deleted = false` globally)
- [ ] Composite index column order follows equality → range → sort rule
- [ ] No obvious unused redundancy (e.g., `(a)` + `(a, b)` — drop `(a)`)

**Migrations**
- [ ] Every migration file has a matching `*.rollback.sql`, and the rollback is **tested** (forward→rollback→forward on a prod-scale snapshot), not just written
- [ ] Files are split per-domain (no single `001_initial_schema.sql`)
- [ ] Destructive/renaming migrations checked against **all** downstream consumers, not just the deploying app (CDC/ETL, replicas→warehouse, MVs, sibling services)

**Deviations**
- [ ] Any decision that deviates from the design doc (`docs/arch/system.md`) is noted inline with reason

If any item fails and isn't justified in-document, revise before saving. Do not save substandard work.

## When Reviewing an Existing Schema

Use this checklist:

1. **Naming**: Convention consistency
2. **Data types**: Appropriate type and size for each column
3. **Constraints**: PK, FK, NOT NULL, CHECK, UNIQUE
4. **Indexes**: Missing indexes (especially on FK columns), unused indexes
5. **Normalization**: Unnecessary data duplication
6. **Transactions**: Appropriate isolation levels and locking for critical operations
7. **Security**: Sensitive data encryption, access control
8. **Scalability**: Partitioning, read replicas
9. **Ingestion pattern**: Append-only vs backfill vs update-heavy implications
10. **Storage**: Column ordering for alignment (large tables only) → `references/performance-patterns.md`
11. **Lifecycle**: retention per large table is *executable* (partition drop, not mass DELETE); erasure obligations reconciled (crypto-shred / PII-free immutable payloads — `references/design-patterns.md` §2)

For runnable diagnostic queries (unindexed FKs, unused indexes, oversized rows, missing constraints), see `scripts/schema_review.sql` — psql-ready queries you can execute directly against the target database.

When invoked from an architecture review, rank findings with the caller's severity rubric (e.g. the software-architecture skill's 🔴/🟠/🟡/🟢) so the two audits merge cleanly.

## Standing Guards (CI / cron)

A schema review is a point-in-time audit; these keep it true continuously — the database-grain analogue of architecture fitness functions:

1. **Migration round-trip in CI** — forward → rollback → forward against a production-scale snapshot on every migration PR (the Step 7 / Pre-Output Gate rule, automated). A chain that has only ever run forward has an untested rollback.
2. **Drift check** — build a scratch database from the full migration chain, `pg_dump --schema-only` both it and each long-lived environment, and diff (or use a schema-diff tool such as `migra`). Any difference means schema was mutated outside migrations — this is the standing enforcement of "auto-DDL is forbidden".
3. **Scheduled `scripts/schema_review.sql`** — monthly, and after every launch, against production: unindexed FKs, unused indexes, dead-tuple ratios, lock pile-ups. Keep `pg_stat_statements` enabled (Recommended Extensions) so query regressions between runs are attributable.

Wire 1-2 into CI; 3 is a cron job plus a human reading the output.

## Key Design Patterns Summary

| Pattern | When to Use | Reference |
|---------|------------|-----------|
| Table Inheritance | Common attributes + type-specific attributes | `references/design-patterns.md` |
| CQRS | Read/write model separation needed | `references/design-patterns.md` |
| Event Sourcing | Complete change history required | `references/design-patterns.md` |
| Soft Delete | Logical deletion required | `references/design-patterns.md` |
| Audit Trail | Change tracking required | `references/design-patterns.md` |
| Partitioning | Large table management | `references/performance-patterns.md` |
| JSONB Hybrid | Flexible schema + relational mix | `references/data-types-guide.md` |
| Domain Types | Reusable constrained types (email, URL, amounts) | `references/data-types-guide.md` |
| Generated Columns | Stored computed values (FTS vectors, derived amounts) | `references/data-types-guide.md` |
| Temporal Data | Time-validity ranges, price history | `references/design-patterns.md` |
| Pessimistic Locking | High contention, short transactions | `references/acid-transactions.md` |
| Optimistic Locking | Low contention, user-facing workflows | `references/acid-transactions.md` |
| Queue (SKIP LOCKED) | Task/job queue processing | `references/acid-transactions.md` |
| Outbox / Idempotency tables | Reliable side effects, retry-safe writes | Table shapes live in a reliability capability (e.g. the software-architecture skill's `reliability-patterns.md`), if available — this skill turns them into migrations |

## Output

Produce these files (default destinations — the caller/agent may redirect the `docs/arch/` and `db/migrations/` roots):

| File | Content |
|---|---|
| `docs/arch/database.md` | **Table of Contents** (linked) → Requirements summary (incl. the size envelope) → ERD (Mermaid, consult `references/mermaid-erd.md` for syntax) → Schema decisions & trade-offs → Transaction design → Access paths & index strategy → Performance notes → Migration plan. Design doc deviations noted inline. Start with a TOC right after the title — the document gets long and a TOC makes it navigable. |
| `db/migrations/NNN_<verb>_<domain>.sql` | Executable DDL split **per domain** (never a single "initial schema" file). Each file pairs with `NNN_<verb>_<domain>.rollback.sql`. See naming convention below. |

### Migration File Naming

Split the initial schema into **per-domain migration files** — one file per bounded context or aggregate. Never produce a single `001_initial_schema.sql` containing everything.

```
db/migrations/
├── 001_create_user_accounts.sql
├── 001_create_user_accounts.rollback.sql
├── 002_create_workspaces.sql
├── 002_create_workspaces.rollback.sql
├── 003_create_billing.sql
├── 003_create_billing.rollback.sql
└── ...
```

**Why per-domain**:
- Rollback is atomic — revert one domain without touching others
- `git blame` attributes each domain's schema history to the right PR
- PR review unit matches the feature unit
- Never modify a migration that has been applied — add a new one. Editing applied migrations creates drift between environments and breaks rollback chains

**Numbering**: Zero-padded sequential (`001`, `002`, ...). Follow the dev order from `docs/prd/prd.md` when deciding which domains migrate first.

**Verbs**: `create_` for new tables, `add_` for columns/indexes, `alter_` for type changes, `backfill_` for data migrations, `drop_` for removals (use expand-contract — see `references/migration-patterns.md`).

## Recommended Extensions

Enable these when the design requires their capabilities:

| Extension | Purpose | Enable When |
|-----------|---------|-------------|
| `btree_gist` | GiST operator support for B-tree types | Exclusion constraints (temporal data, reservations) |
| `pg_trgm` | Trigram-based similarity | Fuzzy text search, `LIKE '%keyword%'` optimization |
| `citext` | Case-insensitive text type | Case-insensitive UNIQUE columns (email, username) without `lower()` expression indexes |
| `pgcrypto` | Cryptographic functions | Hashing passwords, generating UUIDs (pre-PG13) |
| `pg_stat_statements` | Query performance tracking | Production monitoring (enable always) |
| `pg_partman` | Automated partition management | Time-series partitioning in production |
| `uuid-ossp` | UUID generation functions (v1/v1mc/v3/v4/v5 — no v7) | When you need v1/v3/v5 specifically. For v4, `gen_random_uuid()` is built-in (PG13+). For v7 (this skill's PK default), use PG18 `uuidv7()` or generate at the application layer |
| `vector` (pgvector) | Vector similarity search (HNSW, IVFFlat) | Embeddings, semantic search, RAG — up to ~100M vectors co-located with relational data |

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;   -- needed for EXCLUDE constraints
CREATE EXTENSION IF NOT EXISTS pg_trgm;       -- needed for fuzzy search indexes
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- query performance tracking
```

## Critical Rules — Data / Performance Disasters

These prevent data corruption, loss, or major regressions. Not negotiable.

- **Never use FLOAT for monetary values** → `NUMERIC(precision, scale)`. FLOAT cannot represent decimals exactly; you will lose money.
- **Always use TIMESTAMPTZ** for timestamps. `TIMESTAMP` (without tz) silently strips timezone info — a footgun across regions/clients.
- **Index every FK you JOIN or filter on.** PostgreSQL does not auto-create FK indexes. Missing FK indexes turn parent-row updates/deletes into full table scans. Intentionally unindexed FKs must be documented.
- **`ON DELETE` behavior must be explicit on every FK** (`CASCADE` / `RESTRICT` / `SET NULL` / `SET DEFAULT` / `NO ACTION`). The default differs by tool/intent and propagates surprises silently. (`NO ACTION`, the SQL default, can be deferred to end-of-transaction; `RESTRICT` cannot.) `ON UPDATE` is moot for immutable surrogate PKs (the default), but matters (`ON UPDATE CASCADE` vs `RESTRICT`) whenever a FK references a **mutable natural or composite key**.
- **`CREATE INDEX CONCURRENTLY`** for any index added to a table that already serves production traffic. Plain `CREATE INDEX` takes a write lock for the duration.
- **Destructive ops (`DROP COLUMN`, `RENAME`) follow expand-contract**, never direct. Direct DDL mid-deploy breaks rolling deployments.
- **Auto-DDL (`synchronize: true` and friends) is forbidden in any deployed environment.** Migrations are the only sanctioned schema-mutation path.
- **Never store secrets or PII carelessly.** Hash passwords with `pgcrypto` (`crypt()`/`gen_salt()`) — don't encrypt them. For reversible PII, prefer app-layer/envelope encryption (encrypted columns lose B-tree indexability and range/equality search). The audit-trail and event-sourcing patterns dump whole-row `to_jsonb(OLD/NEW)` — mask or exclude sensitive columns there or they leak into `audit_logs`. See `references/design-patterns.md` §3.

## Roles & Least Privilege

DDL produced by this skill is owned by a **migration/owner role**; the application connects as a separate **least-privilege role**. This separation is also what RLS depends on — policies don't apply to the table owner unless `FORCE ROW LEVEL SECURITY` is set, and never to superusers/`BYPASSRLS` roles (see Multi-tenancy below and `references/design-patterns.md` §6).

```sql
-- Owner role owns the schema/tables and runs migrations; app role only does DML.
CREATE ROLE app_owner NOLOGIN;
CREATE ROLE app_rw LOGIN PASSWORD '...';        -- the role the application connects as

REVOKE ALL ON SCHEMA public FROM PUBLIC;        -- no implicit access to the schema
GRANT USAGE ON SCHEMA app TO app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO app_rw;
-- Cover tables created by future migrations too:
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;
```

The app role must be **non-owner and non-superuser** (no `BYPASSRLS`) for tenant isolation to hold. Record the owner/app split and grants alongside the schema (this is the artifact behind review checklist item 7, "Security: access control").

## Conventions — Defensible Defaults

These are choices, not mandates. The skill's defaults are defensible; teams may swap them so long as consistency holds.

- **PK default: UUID v7.** External-API-safe, distributed/offline-friendly, time-ordered (preserves index locality, unlike v4). BIGINT IDENTITY remains the right pick for internal-only IDs and megatables where 8-byte savings measurably matter — see "Primary Key Type Decision" below.
- **Strings: TEXT by default.** No performance cost in PostgreSQL. Use `VARCHAR(n)` only when the length cap carries semantic weight you want enforced at the type level. Otherwise enforce length with `CHECK`.
- **ENUM only when values are stable.** `ALTER TYPE ... ADD VALUE` can run inside a transaction (PG12+), but the new value can't be *used* until that transaction commits — so you can't add a value and insert rows using it in the same migration step, and values can't be cleanly removed or reordered. For anything user-extensible, use a lookup table.
- **Default isolation: Read Committed.** Most OLTP fits. Escalate to Repeatable Read / Serializable per-operation only where correctness demands it (with retry logic).
- **`created_at` / `updated_at` on entity tables**, except pure association/pivot tables (`user_role`) and append-only event tables (which need only `created_at`).
- **Multi-tenancy default depends on tenant shape**:
  - **Many small tenants (B2B SaaS)** → `tenant_id` column + RLS. Single DB, simple ops, isolation enforced in DB — *but only if RLS is wired correctly*: the table owner bypasses RLS unless `FORCE ROW LEVEL SECURITY` is set, and superuser/`BYPASSRLS` roles always bypass, so the app must connect as a dedicated non-owner role. Wrap `current_setting()` in a scalar subquery (`(SELECT current_setting('app.current_tenant', true))`) so it evaluates once per query, not per row, and still filter by `tenant_id` in the query (RLS predicates can suppress partition pruning and some pushdown). Benchmark before committing RLS for high-QPS tenants. See `references/design-patterns.md` §6.
  - **Few large tenants (enterprise)** → schema-per-tenant or DB-per-tenant. Better blast-radius isolation, easier per-tenant tuning/backup, regulatory-friendlier.
  - Either way, record as an ADR. Tenant-scoped composite indexes lead with `tenant_id` *only when* tenant-scoped queries dominate; cross-tenant analytics paths may want the opposite ordering.
- **Foreign-key edge cases:** use `DEFERRABLE INITIALLY DEFERRED` for circular references or intra-transaction row reordering; **composite FKs** require a matching composite `UNIQUE`/PK on the parent — in multi-tenant schemas carry the tenant: `FOREIGN KEY (tenant_id, parent_id) REFERENCES parent (tenant_id, id)`.
- **Design around your query patterns** — indexes serve real WHERE/JOIN, resultsets bounded, computed values cached when worthwhile.

## Primary Key Type Decision

PK type is a **one-way door** — changing it later requires rewriting every FK reference and external consumer. Record the choice as an ADR.

| Situation | Choose | Why |
|---|---|---|
| **Default** — modern app with any external surface (API, mobile, third-party integration, possible future multi-region/offline) | **UUID v7** | Time-ordered (preserves B-tree locality, unlike v4). Safe to expose externally. Distributed/offline-safe. Avoids painful BIGINT→UUID migration if requirements grow. |
| Pure internal IDs, never exposed externally, single-region only, and 8-byte savings are measurable (event logs, metrics, billion-row append-only tables) | **BIGINT IDENTITY** | 8 bytes vs 16, denser B-tree, human-readable in logs. Savings cascade through FK columns. |
| Distributed ID generation across regions/clients (no central DB assignment) | **UUID v7** | No coordination needed; clients can mint IDs |
| Offline-first clients that generate IDs before sync | **UUID v7** | Collision-safe without server round-trip |
| Merging data from multiple systems later | **UUID v7** | No renumbering at merge time |

**Never use UUID v4 for PKs on hot tables** — random ordering fragments B-tree indexes and hurts write performance. v4 is only acceptable for low-volume / low-write tables.

### UUID v7 generation

- **PostgreSQL 18+**: native `uuidv7()` — `id UUID NOT NULL PRIMARY KEY DEFAULT uuidv7()`.
- **PostgreSQL ≤17**: generate at the application layer (Node: `uuidv7` package; Python: `uuid_utils.uuid7()`; Rust: `Uuid::now_v7()`; Go: `github.com/gofrs/uuid` v5+; Java: `com.github.f4b6a3:uuid-creator`). Pass the generated UUID into `INSERT` explicitly.
- The `uuid-ossp` extension provides v1/v1mc/v3/v4/v5 — not v7. For v4, prefer the built-in `gen_random_uuid()` (PG13+); note it produces v4, the version we avoid for hot-table PKs.

**Mixed strategy is fine**: UUID v7 for most tables, BIGINT for the handful of high-volume internal tables where bytes measurably matter (events, audit logs). Just don't flip a whole schema's convention later.
