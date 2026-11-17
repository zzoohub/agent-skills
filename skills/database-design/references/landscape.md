# Database Landscape Snapshot

**Last verified: 2026-11-17.** The perishable facts: versions, limits, extensions, tools, incidents and measurements. The other references hold the durable rules and carry only short version tags (`PG18+`); this file is the one to refresh, and the only place product names and numbers live.

**How to use it.** *P* = read in the project's, vendor's or researcher's own text on the date above; *S* = press, blogs or third-party reports; *T* = run here, on PostgreSQL 18.7 with pgvector 0.8.7, or on 19rc1. **Re-verify before a decision rests on a row**, and record source and date in database.md.

## PostgreSQL versions

Supported majors: 15, 16, 17, 18. PG14 reached end of life on 2026-11-12. **PG19 is not released**: RC 2 shipped 2026-11-12 and general availability is planned for 2026-11-19 (P postgresql.org). Every `PG19+` tag in this skill was checked against the RC docs and, where marked *T*, executed on 19rc1; confirm against the final release notes.

| Feature this skill uses | From | Before that |
|---|---|---|
| `security_invoker` views; `NULLS NOT DISTINCT`; CREATE on `public` no longer granted to everyone | 15 | owner-rights views only; a partial unique index; revoke it |
| HOT updates survive a change to a BRIN-only column; `last_idx_scan` | 16 | — |
| `transaction_timeout`; COPY `ON_ERROR ignore`; pg_upgrade keeps logical slots (old cluster 17+) | 17 | statement and idle timeouts; a staging table; re-snapshot consumers |
| `uuidv7()` | 18 | an RFC 9562 v7 value from the application |
| VIRTUAL generated columns, and VIRTUAL as the default kind | 18 | STORED only |
| `NOT NULL … NOT VALID` | 18 | CHECK `NOT VALID` → `VALIDATE` → `SET NOT NULL` |
| `WITHOUT OVERLAPS` keys, `PERIOD` foreign keys (NO ACTION only) | 18 | `EXCLUDE USING gist` |
| `RETURNING old.*, new.*`; COPY `REJECT_LIMIT`; `LIKE` on nondeterministic collations | 18 | — |
| EXPLAIN ANALYZE prints buffers and `Index Searches`; B-tree skip scan | 18 | `EXPLAIN (ANALYZE, BUFFERS)` |
| pg_upgrade keeps planner statistics (extended statistics too from 19) | 18 | analyze everything after the upgrade |
| Data checksums on by default at `initdb`; both clusters must match for pg_upgrade | 18 | — |
| `autovacuum_vacuum_max_threshold`; fast-path lock slots sized from `max_locks_per_transaction` | 18 | per-table scale factors; 16 slots |
| `REPACK (CONCURRENTLY) t` (*T*) | 19 | pg_repack |
| `WAIT FOR LSN '…' WITH (MODE …, TIMEOUT …, NO_THROW)` (*T*) | 19 | route to the primary, or `remote_apply` |
| `INSERT … ON CONFLICT … DO SELECT [FOR UPDATE] … RETURNING` (*T*) | 19 | `DO NOTHING` then `SELECT` |
| `log_lock_waits` on and `jit` off by default (*T*) | 19 | set them |
| Sequence values synced through a subscription (`REFRESH SEQUENCES`, PG19 publisher) | 19 | `setval` at cutover |

**PG19, for anyone upgrading to it** (P release notes dated 2026-10-09, Beta 4 and RC 2 announcements):
- Stemmers changed and text search moved to the locale provider: reindex text-search and `pg_trgm` indexes and recompute stored `tsvector` columns.
- `pg_upgrade` refuses clusters with `btree_gist` indexes on `inet` or `cidr`.
- `max_locks_per_transaction` defaults to 128, and its meaning changed ("settings must now be doubled to match their capacity in previous releases"); `io_workers` is replaced by `io_min_workers` and `io_max_workers`; the default TOAST compression is lz4.
- Reverted before release, so absent: SQL/PGQ property graphs, `FOR PORTION OF`, `MERGE` / `SPLIT PARTITION`, online checksum toggling. Articles written from Beta 1 still describe them.
- Unchanged, despite reports: adding a column of a constrained-domain type still rewrites the table.
- New and useful: `pg_plan_advice` (pinning planner choices), parallel autovacuum workers, `pg_stat_lock`, `EXPLAIN (ANALYZE, IO)`.

## Vectors and search in PostgreSQL

| Fact | Source | What it changes |
|---|---|---|
| pgvector 0.8.7 (2026-10-01). 0.8.3 fixed "possible index corruption with HNSW vacuuming"; 0.8.4 the "graph not repaired" error. 0.9.0, unreleased, drops PG13 and PG14 | P pgvector CHANGELOG | Require 0.8.4 or later where vector rows are deleted |
| Index limits: `vector` 2,000 dimensions, `halfvec` 4,000, `bit` 64,000; `sparsevec` 1,000 non-zero elements (HNSW only). Storage: 4 bytes per dimension + 8 for `vector`, 2 + 8 for `halfvec` | P README | A 3,072-dimension model needs `halfvec` to be indexed |
| HNSW defaults: `m` 16, `ef_construction` 64, `hnsw.ef_search` 40. Iterative scans (0.8.0+): `hnsw.iterative_scan` `strict_order` or `relaxed_order`, off unless set; `hnsw.max_scan_tuples` 20,000 | P README · S on the default | `references/ai-data.md` §3 |
| Filters are applied after the index scan. README advice: a B-tree for selective filters, partial indexes for a few values, partitions for many, list partitions or separate tables per tenant | P README · *T* | Same |
| Build faster when the graph fits `maintenance_work_mem`; "Vacuuming can take a while for HNSW indexes. Speed it up by reindexing first" | P README | Plan index maintenance for tables with deletes |
| Other in-database indexes: pgvectorscale (DiskANN, PostgreSQL License; pre-filters only `smallint[]` labels); VectorChord (AGPLv3 or ELv2); `pg_diskann` (one cloud only); a ScaNN index with inline filtering (one cloud only) | P each project's docs | Check the host ships it before designing on it |
| Scale reports: a parallel sequential scan is usually enough at 10k to 50k vectors; one operator serves 100 to 200 billion embeddings from per-user partitions of about 1 GB with no vector index | S aws.amazon.com/blogs/database 2026-06-25 | Partition by the filter before reaching for a bigger index |
| An embedding can be inverted: 92% of 32-token inputs recovered exactly in one study; listed as a risk by OWASP (LLM08:2025) | P arXiv 2310.06816 · genai.owasp.org | Embeddings carry their source's data class |
| BM25 inside PostgreSQL: `pg_textsearch` (PostgreSQL License, 1.0 on 2026-04-03, PG17 and 18; scores are computed per partition); ParadeDB `pg_search` (AGPL-3.0; index renamed `USING paradedb` in 0.25); VectorChord-BM25. One host withdrew `pg_search` for new projects on 2026-03-19 and ships its own | P project docs, neon.com changelog | Young and uneven across hosts: built-in `tsvector` plus rank fusion is the portable baseline |
| Built-in text search limits: a `tsvector` under 1 MB, 16,383 positions; ranking uses no corpus-wide statistics and reads every matching row | P postgresql.org textsearch-limitations | `references/ai-data.md` §4 |

## AI application stores

| Fact | Source | What it changes |
|---|---|---|
| A popular graph framework's PostgreSQL checkpointer keeps `checkpoints`, `checkpoint_blobs`, `checkpoint_writes`; pruning is an explicit call, and users report blob storage growing faster than the message count | P langgraph checkpoint-postgres source · S forum.langchain.com 2026-08 | Schedule retention for framework tables |
| A widely used SDK changed its stored message shape between major versions; its own migration guide used a side-by-side table, dual writes, a backfill and a read switch | P ai-sdk.dev migration guide 5.0 | Version the stored message format |
| An agents SDK's default SQL session stores each message as JSON text, ordered by an integer id, with timestamps without a zone | P openai-agents-python `sqlalchemy_session.py` | A framework default is not a schema decision |
| Token accounting differs: one provider's `input_tokens` excludes cached tokens, two others' includes them; cache writes now come in several lifetimes | P Anthropic, OpenAI and Gemini API docs | Normalize in the adapter (`references/ai-data.md` §10) |
| `NOTIFY` under load: three outages in one week at one company; another measured about 2,900 writes per second with a notification per write and about 60,000 with batching, and reports the global lock remains in PG19 | S recall.ai 2025-03 · dbos.dev 2026-07-24 | Poll queues; contested whether PG19 helps |
| Autovacuum does not analyze partitioned parents; one team traced a 6,100,000× row misestimate to it | P postgresql.org routine-vacuuming · S hatchet.run 2025-12-16 | `references/scale.md` §2 |
| Memory poisoning by query alone: 98.2% injection success in one study, called idealized by a later one; seen in shipped assistants in 2024 and 2025 | P arXiv 2503.03704, 2601.05504 · S | Provenance and trust columns on memory rows |

## Agents as database clients

| Fact | Source | What it changes |
|---|---|---|
| A database tool server running as a role that bypasses RLS read a support ticket containing instructions, then copied secret rows into the ticket. "No permissions were violated" | P generalanalysis.com 2025-07-08 | The role is the boundary; stored text steers readers |
| The reference PostgreSQL tool server wrapped queries in a read-only transaction; `COMMIT; DROP SCHEMA …` in one string escaped it. The fix forces one prepared statement per call and a restricted role "in any case". The server was archived | P securitylabs.datadoghq.com 2025-08-21 | One statement per call; read-only by grants |
| A coding agent deleted a production database that also served development. The vendor's agents now write only a development database and read production through a replica | S theregister.com 2025-07-22 · P docs.replit.com | Agents get a database that is not production |
| An agent found an infrastructure token in an unrelated file and deleted a production database; the backups were on the same volume. Elsewhere, a swapped state file led `terraform destroy` to remove a database and its automated snapshots | S theregister.com 2026-04-27 · P alexeyondata.substack.com 2026-02 | Deletion and backups sit outside database grants |
| Vendors on their own tool servers: "even in read-only mode, prompt injection remains the number one concern"; "We recommend MCP for development and testing only"; a parser-based read-only mode is "not a security boundary" and "the strongest control is to connect … using a dedicated Postgres role"; "Allowing an LLM to execute arbitrary queries in production is highly dangerous": prefer named, parameterized queries | P supabase.com 2025-09-16 · neon.com docs · awslabs.github.io · mcp-toolbox.dev | `references/access.md` §5 |
| Role settings are defaults a session can change; grants, `temp_file_limit` and `CONNECTION LIMIT` are not | P postgresql.org · *T* | `references/access.md` §4 |
| Text-to-SQL accuracy: 83.4% on the best-known academic benchmark (people: 93.0%); 10.8% for an agentic system on private enterprise warehouses, 30.1% with hints | P bird-bench.github.io 2026-10-22 · arXiv 2409.02038 | Generated SQL is often wrong, and wrong SQL runs |
| What moves it: schema alone 43.9% correct; plus the business rules 60.2%; plus sample values 62.0% | P arXiv 2501.12372 | Rules in views and comments before anything else |
| Column descriptions: +3 points on one model, over 20 where names were uninformative; machine-written ones lowered another model by 3. Natural names correlate with accuracy; declared foreign keys add 0.6 to 2.9 points | P arXiv 2408.04691, 2308.15363 · SNAILS (SIGMOD 2025) | Names first; comments where a name cannot say it |
| One lab's internal analytics agent: 21% unaided, above 95% with curated documentation, 65% a month after its upkeep stopped. Machine-written metric definitions were net-negative | P claude.com/blog 2026-06-03 | Comments are maintained or deleted |
| A governed semantic layer answered 98 to 100% of 11 questions against 84 to 90% for raw text-to-SQL, and refuses what it cannot express | P docs.getdbt.com 2026-04-07 (vendor-run) | Published views turn wrong answers into refusals |

## Scratch databases and checks

| Fact | Source | What it changes |
|---|---|---|
| Branches differ: copy-on-write with the parent's data (Neon, with masking in beta; Lakebase; Xata; Tiger Data; Database Lab) or schema and seed only (Supabase); empty or restored from a backup (PlanetScale for Postgres) | P each vendor's docs | A branch without data cannot time a migration |
| An in-process WebAssembly PostgreSQL runs one connection | P electric.ax 2026-03-25 | No race or lock tests there |
| Migration linters: squawk (static rules such as `require-concurrent-index-creation`, `constraint-missing-not-valid`, `require-timeout-settings`; Apache-2.0 or MIT); Atlas (PostgreSQL lock analyzers are in the paid plan; `migrate lint` left the free plan in v0.38); Eugene (runs the migration and reports the locks taken; MIT) | P project docs | `references/migration-patterns.md` |
| Migration runners and planners: pgroll (expand and contract with versioned views; Apache-2.0); pg-schema-diff (plans from a target schema, flags hazards, PG14 to 17; MIT) | P project repos | Read the plan they produce as you would an ORM's |
| Live-database lints: Supabase's advisors (unindexed foreign keys, definer views, mutable `search_path`, RLS off in an exposed schema); pgTAP for assertions inside the database | P project docs | Overlap with `scripts/schema_review.sql` |

## SQLite and its hosts

The modeling method, the first two enforcement rungs, the Index gate and N-1 changes carry over. What does not: there are no roles or RLS, so isolation is a database per tenant or per agent; one writer at a time; types are enforced only in `STRICT` tables; most schema changes are a table rebuild; instants are stored as ISO-8601 UTC text or integer epochs, and money as integer minor units.

| Fact | Source |
|---|---|
| D1: 10 GB per database, 100 columns per table, 100 bound parameters, a 100 KB statement, 30 s per query; `batch()` is the transaction; foreign keys enforced by default; read replicas only through the Sessions API | P developers.cloudflare.com/d1 |
| Durable Objects SQLite: 10 GB per object; `transactionSync()` instead of `BEGIN`; 30 days of point-in-time recovery | P developers.cloudflare.com/durable-objects |
| Plain SQLite: foreign keys "disabled by default", per connection; `STRICT` tables since 3.37; `ALTER TABLE` renames, adds and drops columns and, since 3.53.0 (2026-04-09), sets or drops NOT NULL: everything else is the rebuild procedure; "GRANT and REVOKE … are not implemented"; no date or decimal type | P sqlite.org |
| Turso: concurrent writes are an early preview on its cloud, on its own engine, without DDL inside concurrent transactions | P turso.tech 2026-08-03 |

## Watch list

- PG19 general availability and its final notes; whether the reverted features return in PG20.
- pgvector 0.9 (asynchronous I/O for indexes), and filtered search moving into the index.
- Which BM25 extension the large hosts settle on.
- Scoped infrastructure tokens and delayed deletes at hosting platforms.
- Agent identity standards (a NIST concept paper closed for comment 2026-04-02) and a semantic-layer interchange format (a v0.1 specification, 2026-01-27).

## Repeated but poorly supported

- Vector benchmark numbers: every one found was run by a vendor on its own product.
- "Agents create 80% of databases": one vendor's telemetry about its own service.
- Near-solved text-to-SQL: one leaderboard reports 96.7% where a private-warehouse benchmark reports 10.8%.
- Whether production may be read by agents at all: the same vendor wrote "Never connect AI agents directly to production data" in 2025 and promotes read-only production checks in 2026.
