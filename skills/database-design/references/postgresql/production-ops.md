# PostgreSQL Production Operations

Incidents, vacuum and wraparound, connection pooling, major upgrades, and the settings that make problems visible. The queries cited as § numbers are in `scripts/query_diagnostics.sql`.

## Incident triage

Stabilize first, explain later. Mid-incident, change only settings that apply without a restart (`pg_settings.context` other than `postmaster`): a restart is a second outage.

1. **What changed, and when?** Deploy, migration, bulk load or backfill, traffic shift, upgrade, failover, config change. A step change at a known time points to that change; a slow climb points to growth, bloat or a pinned xmin horizon.
2. **Shape** (§1): group sessions by state and wait event.
   - `Lock` waits → the blocker tree (§2). Terminate the root blocker, never the queue behind it. The usual root is an idle-in-transaction session, or DDL waiting behind one and blocking everyone after it (the lock queue: `references/migration-patterns.md`).
   - Many `idle in transaction` (§3) → the application holds transactions open across network calls. The fix is in the application; `idle_in_transaction_session_timeout` on the app role is the backstop.
   - `active` with no wait event → CPU. Attribute the load before blaming a plan (`references/postgresql/query-tuning.md`, Attribute the load first): statements by share of the §6 window, each split into calls/s and mean ms, before vs during. A flipped plan shows as mean up at steady calls; demand as calls up on a steady mean (a deploy's new caller, retries after timeouts, a poller, one tenant). Name every statement that owns a material share: an incident can have several causes.
   - `IO` waits (`DataFileRead`) everywhere → the working set no longer fits in memory, a plan flipped to a scan, or a statement's call rate grew: rank the §6 window by `shared_blks_read`.
   - `LWLock` waits, by `wait_event`. `LockManager`: queries lock more relations (partitions and their indexes) than a backend's fast-path slots (16 before PG18, sized from `max_locks_per_transaction` since, so raising it adds slots after a restart); prune partitions at plan time, drop unused indexes. `SubtransSLRU`/`SubtransBuffer`: some transaction holds more than 64 subtransactions (savepoints, ORM nested transactions, `EXCEPTION` blocks in loops), worst on replicas; remove them. `MultiXact*`: many transactions locking the same rows at once, typically FK checks against a hot parent or lookup row. `WALWrite`: many tiny commits; batch them. Any other: look it up in the monitoring docs before tuning.
3. **"Too many connections"**: raising `max_connections` trades errors for contention collapse. Pool instead (below), and check that app instances × pool size fits the pooler and the server.
4. **Leave anti-wraparound vacuum alone** (`… (to prevent wraparound)` in §2 or §7): cancelled, it restarts and blocks your DDL again. Cancel the DDL instead.

**Report** in about 300 words for one cause, plus about 100 per further cause; never drop a material finding to fit, compress it to one line:
1. **Evidence**: what changed and when, the session shape, the root blocker, and the load table (statement · share of the window · calls/s and mean ms before → during).
2. **Stabilized by**: what was done during the incident.
3. **Causes**, ranked by the share they explain, each with its lasting fix.
4. **Other contributors and follow-ups**, one line each, and the alert that would have caught it sooner.

Maintenance (vacuum, freeze, repack) ships as runbook rows (`references/migration-patterns.md`).

## Vacuum and wraparound

Vacuum is healthy when it **reaches** every table in time and **removes** what it finds.

- **Dead tuples survive a vacuum** (§10, high `n_dead_tup` just after `last_autovacuum`): the xmin horizon is pinned, and no tuning helps until its holder is gone. Check §4 in this order: the oldest `backend_xmin` (a long or idle-in-transaction session), replication slots (`xmin`, `catalog_xmin`; an inactive slot also retains WAL until the disk fills), prepared transactions, standbys sending `hot_standby_feedback`. Then end the session, drop the dead slot, or finish the prepared transaction.
- **Vacuum reaches big tables too late**: by default it starts when dead rows reach about 20% of the table. Set per-table `autovacuum_vacuum_scale_factor` to 0.01–0.05 on large tables (PG18 also caps the trigger with `autovacuum_vacuum_max_threshold`). On append-only tables lower `autovacuum_vacuum_insert_scale_factor`, so pages get frozen and marked all-visible. These are online changes (SHARE UPDATE EXCLUSIVE).
- **Vacuum runs too slowly**: `autovacuum_vacuum_cost_limit` is shared by all running workers, so more workers split the same budget. Raise the limit, globally or per table, before adding workers.
- **Wraparound** (§5): alert when `age(datfrozenxid)` passes 2× `autovacuum_freeze_max_age` or `mxid_age(datminmxid)` 2× `autovacuum_multixact_freeze_max_age` (autovacuum is losing), and in any case at 1 billion; page at 1.5 billion. Wraparound sits near 2.1 billion: the server first warns, then refuses new transaction IDs. Clear whatever pins the horizon (§4), then run a plain `VACUUM` on the tables with the oldest `relfrozenxid` (§5), or database-wide: not `VACUUM FREEZE` (more work than needed), not `VACUUM FULL` (it needs a transaction ID), and no single-user mode, whatever an older server's hint says.
- **Bloat**: measure it with `pgstattuple` (`pgstattuple_approx` on large tables), not from table size. Rebuild online with pg_repack (needs a primary key or a NOT NULL unique index, free disk of about twice the table and its indexes, brief ACCESS EXCLUSIVE locks at start and end, no DDL on the table meanwhile) or, where the server has it (PG19+), `REPACK … CONCURRENTLY`. Never `VACUUM FULL` a live table.
- `ANALYZE` a table after a bulk load or backfill; autoanalyze lags.

## Pooling

Pool application traffic in transaction mode (PgBouncer or the platform's pooler). Size pools for **active** work: start near 2–4× the server's CPU cores across all pools and measure (I/O-latency-bound storage tolerates more). An idle backend costs a few MiB (`ps` overstates it): pool to cap active connections and setup cost, not idle memory. Keep pool sizes plus reserves below `max_connections`, leaving admin and replication headroom.

Transaction pooling breaks anything scoped to a session:
- session `SET` → `SET LOCAL`, or `set_config(name, value, true)` per transaction (tenant context for RLS: `references/design-patterns.md`);
- session advisory locks → `pg_advisory_xact_lock`;
- `LISTEN`, temporary tables, `WITH HOLD` cursors and SQL-level `PREPARE`/`EXECUTE` → a session-mode pool or a direct connection;
- protocol-level prepared statements work through PgBouncer when `max_prepared_statements` > 0 (the default is 200 in current releases and 0 in older ones: check yours). After a migration that changes a statement's result type, clients fail with "cached plan must not change result type" until the pooler runs `RECONNECT`.

## Upgrades

A major-version upgrade or host move: list the extensions (each must exist on the target), size, replicas and CDC consumers, then choose by downtime budget.
- **`pg_upgrade --link`**, minutes down. Rehearse on a restored copy; once the new cluster starts, the way back is the pre-upgrade backup. PG18+ `initdb` enables data checksums and both clusters must match (`--no-data-checksums`). pg_upgrade keeps logical slots only from a PG17+ source; from older ones, CDC consumers re-snapshot.
- **Logical replication** into the new major, seconds down: every updated table needs a primary key or replica identity, DDL freezes, sequence values are copied at cutover (unless the old server is PG19+), and large objects are not carried. A host's blue/green upgrade is often this underneath.
- **Before traffic**, run the `vacuumdb` steps pg_upgrade prints: PG18+ keeps planner statistics but not extended ones (`--analyze-in-stages --missing-stats-only`).
- **A new OS image that moves glibc** reorders text and silently corrupts text indexes: heed the collation-version warning, `REINDEX` text indexes, verify with amcheck.

Ship it as runbook rows (`references/migration-patterns.md`).

## Settings

Set only what differs from the default:
- `track_io_timing = on` (check its clock cost with `pg_test_timing`); `log_lock_waits = on` (the default from PG19); `log_autovacuum_min_duration`, `log_min_duration_statement` and `log_temp_files` low enough that slow vacuums, slow statements and spills reach the log.
- `statement_timeout` and `idle_in_transaction_session_timeout` per app role (`ALTER ROLE app_rw SET …`), never global: migrations and maintenance need other values.
- `shared_preload_libraries = 'pg_stat_statements,auto_explain'` (restart; managed services expose both as parameters). `auto_explain`: `log_min_duration` near the latency SLO, `log_analyze = on` with `sample_rate` below 1 on busy systems, `log_timing = off`.

## Alerts

Starting thresholds: oldest xmin age and freeze age (above); slot retained WAL; blocked sessions > 30 s; idle in transaction > 5 min; connections > 80% of the limit; `replay_lag` past the read-after-write budget; any invalid index (§9).
