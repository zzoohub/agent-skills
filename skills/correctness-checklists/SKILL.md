---
name: correctness-checklists
description: |
  Correctness checklists for the bugs that survive green CI — defects that pass
  tests, lint, and type-checks but corrupt data, double-charge, lose writes, or
  page you at 3am. This is the Pass 1 (blocking) review layer for runtime
  correctness, alongside security-checklists.
  Use when: reviewing a diff that touches concurrency, locks, transactions,
  retries, webhooks, event/queue handlers, caching, background jobs, pagination
  or batch reads, datetime/timezone logic, money/inventory state machines, or
  data crossing serialization/network/DB boundaries. Trigger on "race
  condition", "idempotency", "TOCTOU", "cache invalidation", "double charge",
  "lost update", "concurrent", "retry safety", "exactly once", "deadlock",
  "outbox", "N+1", "pagination", "DST", "fire-and-forget".
  Do NOT use for: security vulnerabilities (use security-checklists);
  design/maintainability smells (use maintainability-checklists); deterministic
  logic bugs (tests own those); style/formatting (linters own those); or
  implementing the fixes.
---

# Correctness Checklists

The bugs that pass tests + lint + types and still break in production. Tests run single-threaded on a happy path, so the entire class of **concurrency / retry / partial-failure / boundary** defects slips through a green pipeline. This is **Pass 1 (blocking)** — these corrupt data, double-charge, or lose writes. Treat a confirmed finding as a commit blocker, not an FYI.

Flag these when the diff touches the trigger areas. Pick sections by what changed.

The *attacker*-driven view of the same flaws (deliberate concurrent requests for double-spend, abuse economics) is `security-checklists/references/business-logic.md`, if available; this file owns the *accident*-driven view (client retries, crash mid-operation, replica lag). Same mechanics, different threat model — when money or inventory moves, apply both.

---

## Concurrency & Races

- **Read-check-write without a uniqueness constraint or atomic guard** — two callers both pass the check, both write. Fix: DB unique index + `ON CONFLICT`, `SELECT ... FOR UPDATE`, or an advisory lock.
- **Lost update** — load row → mutate in app → save, with no version column / optimistic lock; concurrent edits silently clobber each other. Same bug at the HTTP layer: a full-object `PUT` replace overwrites a concurrent editor's fields — wants a version / `If-Match` precondition where two live writers are real.
- **Status transition without a guard** — `UPDATE ... SET status='paid' WHERE id=?` missing `AND status='pending'`; two workers both transition the same row.
- **Upsert relying on an app-level existence check** — `findOrCreate` / `upsert` without a unique index creates duplicates under load.
- **TOCTOU** — any check-then-act that must be atomic (balance ≥ amount → debit; slot free → reserve; quota left → consume).
- **Non-atomic counter / aggregate** — read-modify-write of a count/total instead of an atomic increment or a DB-side aggregate.
- **Inconsistent lock ordering** — two transactions lock the same resources in different orders and deadlock. Fix: acquire locks in a consistent, well-defined order everywhere.
- **Request-scoped data in shared scope** — a module-level variable, class attribute, or field on a shared singleton (HTTP client, ORM session) written during a request; concurrent requests interleave and read each other's data. Tests run one request at a time, so this is always green. Shared scope is for immutable config and pools; per-request state belongs in request scope.
- **Unguarded lazy init** — `if (!instance) instance = create()` on first use; two concurrent first-callers both initialize, splitting state or doubling connections. Initialize at startup, or guard with a once/lock primitive.

## Idempotency & Retries

- **Mutating endpoint without an idempotency key** — a client retry or double-submit charges/creates twice.
- **At-least-once treated as exactly-once** — a webhook / queue / event handler that isn't safe to run twice on the same message. Redelivery is a certainty, not an edge case: a worker killed mid-job (deploy, crash, OOM) means the message runs again.
- **Retry around a non-idempotent side effect** — a retry wrapper over send-email / charge-card / external POST that isn't safe to repeat.
- **Timeout-then-retry duplicates** — the caller timed out, but the original request kept running server-side and succeeded; the retry creates a second effect. A timeout means "I stopped waiting", not "it failed" — retry-on-timeout needs an idempotency key honored end-to-end.
- **No dedup on event consumers** — the same event id can be processed more than once with no guard.
- **Dedup that isn't atomic under concurrent redelivery** — a visibility/lock timeout expiring mid-job hands the same message to a second worker *while the first is still running*; a read-processed-flag-then-mark guard passes both. Claim atomically (unique insert on the message id, or a conditional update), and keep the lock window longer than the slowest job.
- **Ack before the work** — acking the message / committing the offset before processing completes turns a crash into silent loss — at-most-once by accident. Ack on success, and pair with a dedup guard for the duplicate that implies.
- **Poison message with no exit** — a permanently failing message with no max-attempts/DLQ either retries forever and blocks the queue, or — under a swallow-all `catch` — is acked and silently lost. Cap attempts, park to a dead-letter queue, alert.
- **Ordering assumed on async delivery** — webhooks/queue events can arrive out of order; a state machine keyed on arrival order corrupts. Decide by the event's own timestamp/version and ignore stale transitions.

## Transactions & Outbox

- **External call inside an open transaction** — an HTTP call / email / publish between `BEGIN` and `COMMIT` holds row locks for the call's full latency, survives rollback (the email announces an order that never existed), and re-fires if the transaction retries. Move side effects after commit — or through an outbox.
- **Enqueue/publish racing the commit** — enqueued inside the transaction, the worker can pick the job up before commit and see nothing (or stale state); enqueued after commit, a crash in between loses the event. There is no safe naive ordering — that's the problem the transactional outbox exists to solve (or an after-commit hook, where losing the event is acceptable).
- **A write that escapes the transaction** — a helper called mid-transaction grabs its own connection from the pool (or the ORM autocommits it), so it commits independently and rollback doesn't cover it. Thread one transaction handle through every write in the unit.
- **Multi-resource write without a transaction or compensation** — two writes that must both land or both not.

## Partial Failure & Side-Effect Ordering

- **Conditional side-effect leak** — one branch performs a side effect another path forgets (publish generates a URL, edit doesn't → stale URL).
- **Log claims an action a guard skipped** — `logger.info("email sent")` sits outside the `if` that actually sends.
- **Error path leaves state half-done** — DB write + external call; one fails, the other isn't compensated or rolled back. Use `try/finally`, `defer`, or an outbox/saga.
- **Resource leak on the error path** — connection/file/lock acquired, then an early return or throw skips the release.
- **Fire-and-forget async work** — an un-awaited promise / detached task with no error handler: its failure is invisible, so the "sent" email or analytics write silently never happens. On serverless (Lambda, Vercel, Cloudflare Workers) it's worse — the runtime can freeze at response time, so detached work routinely dies mid-flight; use the platform's `waitUntil` or hand it to a queue.
- **Outbound call with no timeout** — a request-path call to a dependency with no deadline; when the dependency hangs, every pooled connection / worker slot pins behind it and the outage cascades upstream. Blocking when a bounded pool sits upstream of it; a hardening note otherwise.

## Caching

- **Stale read after write** — the write path doesn't invalidate or update the cache.
- **Missing invalidation on related keys** — updating one entity leaves derived/aggregate cache entries stale.
- **Cache key collision / missing dimension** — key omits tenant/locale/version, so users see each other's data.
- **Stampede** — no single-flight / negative caching; a hot-key miss floods the origin.
- **Read-after-write routed to a replica** — the just-written row isn't visible yet (replication lag); "show the thing I just created" flows must read the primary or carry the written data forward in memory.

## Data Volume & Pagination

- **Mutating the set being paginated** — a batch loop pages with `OFFSET` while its own writes remove rows from the filter (`WHERE migrated = false ... OFFSET 200` after migrating 200): it silently skips half the set. Re-run page one until empty, or keyset-paginate on a stable key.
- **`ORDER BY` without a unique tiebreaker** — sorting on a non-unique column (`created_at`, `name`) leaves row order nondeterministic across pages: items repeat on one page and vanish from the next. Append a unique column to the sort.
- **Unbounded read** — no `LIMIT` (or a whole-table load into memory) on a production-unbounded set. Green on fixture data; OOM or minutes-long at real volume. Paginate or stream.
- **N+1 on a hot path** — a per-item query inside a loop whose iteration count is data-driven (rows per user, items per order). Five-row fixtures hide it; production cardinality turns one request into thousands of queries. Batch it — `JOIN`, `IN` list, or a dataloader.

## Time & Calendars

- **Naive datetime across a boundary** — parsing/storing timestamps without a timezone, then comparing or ordering against UTC; or bucketing "per day" in server-local time, so daily reports and limits shift with the server's timezone. Store UTC; bucket in the timezone the product defines.
- **Duration math for calendar concepts** — `+30 days` for "monthly" or `+24h` for "same time tomorrow" breaks on 28–31-day months and 23/25-hour DST days; billing anniversaries drift. Use calendar-aware date arithmetic.
- **Local-time schedule on a DST day** — a job pinned to a wall-clock time runs twice or never when DST repeats or skips that hour; a "daily" charge double-fires or a report never runs. Schedule in UTC, or use a scheduler that resolves DST explicitly.

## Trust & Serialization Boundaries

- **LLM output used without validation** — model output used as a flag or written to a store without a shape/enum check. (See `security-checklists/references/llm-security.md`.)
- **Cross-boundary type coercion** — JSON number↔string IDs compared with `===`; non-normalized hash/digest inputs producing nondeterministic results.
- **64-bit integers through a float boundary** — an int64 ID or amount crossing JS `Number` / `JSON.parse` silently rounds above 2^53: the value *changes*, and the wrong row is read or written. Carry big integers as strings (or BigInt) end-to-end.
- **Money as float** — currency in floating point; rounding, truncation, or `==` comparison errors. Use integer minor units or a decimal type.
- **Splitting a total by rounding each part** — allocating a sum (fee split, per-line tax, installments) by rounding each share independently; the parts stop summing to the total and reconciliation breaks. Largest-remainder, or make the last part the balance.
- **Byte length vs character length** — a byte-limited sink (column/index byte limits, fixed-size buffers, APIs that count bytes) fed a string measured in characters: multi-byte text (CJK, emoji) overflows the limit or truncates mid-character into mojibake — and JS `.length` counts UTF-16 units, so even "character" counts lie. Measure in the sink's unit; truncate on grapheme boundaries.
- **Uniqueness normalized differently than lookup** — the unique index is case/Unicode-form sensitive while the lookup normalizes (or vice versa): `Kim@x.com` and `kim@x.com` become two accounts; NFC/NFD twins collide or miss. Normalize once at the boundary (case + Unicode form) and index the normalized value.
- **Config strings treated as typed** — env vars are strings: `"false"` and `"0"` are truthy, and a var missing in prod silently takes the code default. Parse and validate config at startup; fail loud on absence.

## Schema & Migration Safety

For any schema change, apply the zero-downtime rules in `database-design/references/migration-patterns.md` and `postgresql/references/production-ops.md` (expand→migrate→contract, `CREATE INDEX CONCURRENTLY`, FK `NOT VALID` + `VALIDATE CONSTRAINT`, batched backfills, rollback SQL). A single-deploy rename/drop, or an unbatched full-table `UPDATE`, is an outage. That's their single source of truth — don't restate the patterns here.

---

## Before You Report — Confirm It's Real

The fastest way to get this checklist ignored is a false positive on every PR. Before reporting:

1. **Look for the guard one layer away** — a unique index in the schema/migrations, a transaction or lock in the caller, framework-level dedup, a single-consumer queue. A guard that lives elsewhere is still a guard; cite it instead of flagging its local absence.
2. **Confirm the concurrency is real** — request-scoped state can't race with itself; a single-writer cron can't lose updates to itself. Name the two actors that actually collide.
3. **Confirm the retry is real** — who retries this path (client, queue, gateway)? If nothing retries it, a missing idempotency key is a hardening note, not a blocker.
4. **Confirm the scale is real** — for N+1 / unbounded-read / data-volume findings, name what makes the cardinality production-unbounded (rows per user, items per order, events per day). A loop over a fixed enum or a 30-row lookup table is not a finding.

If you can't name the trigger ("two concurrent webhook deliveries for the same order"), the finding isn't confirmed yet.

---

## Review Output Contract

```markdown
- **[Issue Name]** (blocking) — `file:line`
  - Failure mode: [how it breaks under concurrency / retry / partial failure — one line]
  - Trigger: [the real-world condition that exposes it — load, retry, crash mid-op]
  - Fix: [specific mechanism — unique index, idempotency key, FOR UPDATE, try/finally]
```

These are Pass 1 (blocking). A confirmed finding should stop the commit until it's fixed or explicitly accepted with written justification.
