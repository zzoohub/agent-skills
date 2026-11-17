# Reviewing an existing schema

Read-only by default; write only when asked. A review that redesigns the schema it was asked to critique has failed: return findings with patch text, and leave the redesign to a design pass the caller requests.

## Procedure

1. **Evidence**, in this order: `scripts/schema_review.sql` on the live catalog, else the migration chain, then the ORM models. Drift between them is itself a finding.
2. **Violation queries** before ranking an unenforced invariant: duplicates on the normalized key, orphans, NULLs where none belong, int4 key headroom (`schema_review.sql` §4), and for each tenant gap (§11) child rows whose parent belongs to another tenant. Run them as a role that bypasses RLS: under a policy they count zero. Violating rows make it 🔴 and the fix starts with cleanup; none make it 🟠, except cross-tenant reachability, which is 🔴 regardless.
3. **Order**: invariants → tenancy → roles and what each login can do (§13) → keys and types → indexes against access paths and each other (§3) → derived and AI data (§14) → lifecycle → growth headroom (hot tables against memory at 1 and 3 years; the distribution key where sharding is on the Scaling Ladder) → pending migrations → what a reader with only the catalog can learn (§12) → naming.
4. **Rank**, then report.

## Ranks

Compatible with software-architecture's rubric.

- 🔴 **Critical**
  - Cross-tenant reachability: the tenant missing from a UNIQUE or FK, RLS not forced, the application connecting as table owner, a table in an API-exposed schema without RLS, a setting-based policy as the only fence around a principal that writes its own SQL.
  - An agent or tool holding an owner, service or BYPASSRLS role.
  - Money in float; cascades into financial records; an int4 key past half its range.
  - Personal data with no erasure path, immutable payloads and embeddings included.
- 🟠 **High**
  - A pooled table without RLS and no recorded break condition; a policy with no `TO`; a reader role that can write.
  - An unindexed FK on a parent that gets deleted; a hot path with no index.
  - A filtered vector search without iterative scans, or a query operator that does not match its index.
  - Retention that cannot execute; a hot table outgrowing memory with no partition or retention plan.
  - A pending migration that is not N-1 safe or locks a hot table; UUIDv4 keys on hot tables; catalog drift.
- 🟡 **Medium**: redundant data or indexes; derived data with no recorded source or producer; undeclared references and open value sets; one conversation stored as one JSON document; a model that drifted from the domain.
- 🟢 **Low**: naming and consistency.

## Report

At most 1,200 words, findings first, each with its evidence (the query and its count, or the catalog row) and a proposed disposition. Patch text only for 🔴 and 🟠. A finding past the budget shrinks to one line, never drops. Say which checks ran against a live catalog and which were read from files.
