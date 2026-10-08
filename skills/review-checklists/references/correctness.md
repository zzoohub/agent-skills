# Correctness Checklists (Pass 1 — blocking)

The *accident* view: bugs that pass tests, lint and types, then corrupt data, double-charge or lose writes in production with no attacker (the attacker view: `references/security/business-logic.md`). Method, gates, severity and the output shape: `SKILL.md`.

---

## Concurrency & Races

Pick the guard by the race's shape; *Reject* lists fixes that don't hold.

| Race shape | Guard | Reject |
|---|---|---|
| absence check → insert (`findOrCreate`, an upsert with no unique index, "one active per user") | unique constraint (partial, for "one active"); `ON CONFLICT`, or catch the violation | `SELECT … FOR UPDATE` (Postgres locks no row that doesn't exist yet; InnoDB's gap locks, at its default isolation, turn the race into deadlocks); an in-process mutex |
| value check → update (balance, stock, status, counter) | one conditional `UPDATE … WHERE <predicate>` (`AND status = 'pending'`, `AND qty > 0`, `SET n = n + 1`); branch on the affected-row count | SELECT, then UPDATE |
| whole-object read-modify-write (incl. a full-object `PUT`) | version column + conditional update (`If-Match` at the API); retry on 0 rows | last write wins |
| invariant across rows (Σ ≤ budget, at most N seats) | lock the parent row, or SERIALIZABLE + retry on serialization failure | per-row constraints alone |
| effect outside the DB (charge, email, file) | idempotency key enforced at the effect; lease + fencing token | a TTL lock alone |

An in-process mutex never spans replicas. *Break when* single-instance is enforced; name what enforces it.

**A fix can unmask a race.** What keeps two writers apart today may be incidental: a row lock held across a slow call, a single worker, a step slow enough that callers never overlap, a status check kept for another purpose, a stale absolute write that collapses concurrent duplicates into one. Moving the call out of the transaction, raising concurrency, adding a cache, relaxing that check (a grace period, a new retry state) or turning that write into an increment removes it; the guard for the race it exposes (this table; for duplicates, Idempotency & Retries) must land with or before that fix.

- **Scheduled job with no singleton or overlap guard** — it fires on every replica, a slow run overlaps the next, and Kubernetes documents that a CronJob may create two Jobs for one scheduled time.
- **Inconsistent lock ordering** — two transactions lock the same rows in different orders and deadlock; acquire in one global order.
- **Request-scoped data in shared scope** — a module-level variable, class attribute or field on a shared singleton (HTTP client, ORM session) written during a request: concurrent requests read each other's data while one-at-a-time tests stay green.
- **Unguarded lazy init** — `if (!instance) instance = create()`: concurrent first callers both initialize, splitting state or doubling connections. Initialize at startup or guard with a once primitive; for async init, cache the promise and evict it on rejection.

## Idempotency & Retries

**Pick the mechanism by the effect, then check it.** Naturally idempotent (set-to-value, delete-by-id, versioned replace) → no key. A natural business key (provider event ID, order + action) → a unique constraint on it, claimed atomically before the effect. Neither → a client key: scoped to the principal, claimed atomically (a lease) before the effect, response stored for replay, a different payload under the same key rejected, kept longer than clients retry. Derive the provider's key from your durable record ID, never a per-attempt UUID: `charge({ idempotencyKey: uuid() })` inside a retry loop is a new charge per attempt. *Break when* duplicates are harmless and cheap.

- **At-least-once treated as exactly-once** — a webhook, queue or event handler unsafe to run twice on the same message. Redelivery is certain: a worker killed mid-job (deploy, crash, OOM) reruns the message.
- **Timeout-then-retry duplicates** — the caller timed out, but the original kept running and succeeded; the retry makes a second effect. A timeout means "I stopped waiting", not "it failed".
- **Retries at several layers** — they multiply (3 layers × 3 attempts = 27 calls) and turn a blip into an outage. Keep one layer: capped, jittered, transient errors only, honoring `Retry-After`.
- **Dedup that isn't atomic under concurrent redelivery** — a visibility or lock timeout expiring mid-job hands the message to a second worker while the first still runs; a read-flag-then-mark guard passes both. Claim atomically (a unique insert on the message ID, or a conditional update); a lapsing lease needs a fencing token checked by the protected write; keep the window longer than the slowest job.
- **Ack before the work** — acking or committing the offset before processing finishes turns a crash into silent loss. Ack on success; dedup the redelivery that implies.
- **Poison message with no exit** — with no max attempts or dead-letter queue it retries forever and blocks the queue, or a swallow-all `catch` acks and loses it. Cap attempts, park it in a DLQ, alert.
- **Ordering assumed on async delivery** — webhooks and events arrive out of order, and a state machine keyed on arrival order corrupts. Order by a version or sequence number from the source of truth, else re-fetch current state; provider timestamps are coarse and producers' clocks don't compare.

## Transactions & Outbox

- **External call inside an open transaction** — an HTTP call, email or publish between `BEGIN` and `COMMIT` holds row locks for the call's latency, survives a rollback (the email announces an order that never existed), and re-fires if the transaction retries. Move side effects after commit, or through an outbox; if the transaction's lock was what serialized concurrent callers, add its replacement in the same fix (Concurrency & Races).
- **Enqueue or publish racing the commit** — enqueued inside the transaction, the worker can run before commit and see nothing; enqueued after it, a crash in between loses the event. Use a transactional outbox (an after-commit hook only where losing the event is acceptable).
- **A write that escapes the transaction** — a helper called mid-transaction takes its own pooled connection (or the ORM autocommits), so it commits independently and rollback misses it. Thread one transaction handle through every write in the unit.

## Partial Failure & Side-Effect Ordering

- **Half-done state on the error path** — a DB write and an external call (or two resources) where one fails and the other stands. Order the steps so every crash point recovers: durable intent row → external call keyed by it → mark done; a reconciler finishes or compensates intents left stuck. `finally` releases resources; it can't refund a charge.
- **Error turned into empty, then acted on** — `catch { return [] }` feeding a sync, reconcile or delete turns an upstream 500 into "zero items" and deletes everything. Keep errors distinct from empty; cap destructive reconciles (abort past N%). *Break when* the value is only displayed.
- **Asymmetric side effects** — one path performs a side effect its sibling forgets (publish regenerates the URL, edit doesn't).
- **Log or metric claims an effect a guard skipped** — `logger.info('email sent')` outside the `if` that sends; emit inside the branch, after the effect.
- **Resource leak on the error path** — an early return or throw skips releasing a connection, file or lock.
- **Fire-and-forget async work** — an un-awaited promise or detached task fails invisibly, and dies silently if the runtime freezes or kills the instance after the response. Await it; a post-response hook (`waitUntil`-style) is only for losable work; must-not-lose work goes through a durable queue or outbox.
- **Outbound call with no timeout** — when the dependency hangs, every pooled connection or worker slot pins behind it and the outage cascades: High when a bounded pool sits upstream, Medium otherwise. Python `requests` and Go's zero-value `http.Client` have no default timeout; a timeout longer than the caller's own is useless.

## Caching

- **Stale or stampeding cache** — the write path doesn't invalidate (derived and aggregate keys included), or invalidates by set instead of delete (concurrent writers' sets land out of order); no TTL backstop; keys not versioned when the cached format changes; a hot key with no single-flight, so one miss floods the origin.
- **Cache key missing a dimension** — the key omits tenant, user, locale or version, so users see each other's data; a cross-tenant leak is rated as one.
- **Read-after-write routed to a replica** — the just-written row isn't visible yet (replication lag); "show what I just created" reads the primary or carries the written data forward.

## Data Volume & Pagination

- **Mutating the set being paginated** — a batch pages with `OFFSET` while its own writes remove rows from the filter (`WHERE migrated = false … OFFSET 200` after migrating 200) and silently skips half the set. Re-run page one until empty, or keyset-paginate on a stable key.
- **`ORDER BY` without a unique tiebreaker** — a non-unique sort (`created_at`, `name`) repeats rows on one page and drops them from the next. Append a unique column.
- **Unbounded read or growth** — no `LIMIT`, or a whole-table load, on a production-unbounded set; an in-process map or cache keyed by user or request data with no size bound. Green on fixtures, OOM in production. Paginate or stream; bound and evict.
- **N+1 on a hot path** — a per-item query in a loop whose count is data-driven; five-row fixtures hide it. Batch with a `JOIN`, an `IN` list or a dataloader.
- **Unbounded fan-out** — `Promise.all` or `gather` over a data-sized list exhausts the pool and fails part-way with no record of what succeeded. Bound concurrency; record per-item results.
- **New access path with no index** — a new filter, sort or join key on a production-large table with no matching index in the migrations: a sequential scan per request in production. Name the query and the table's size (index design: the database-design capability, if available).

## Time & Calendars

Behavior rules live here; column types (instant, date, local time + zone) belong to database-design, if available.

- **Instant vs future local time** — instants (created, expires) are UTC. A future wall-clock event (an appointment, "9:00 every day", a local deadline) is a local datetime + IANA zone, resolved when it fires: a UTC value computed ahead freezes today's zone rules, and a 9:00 job stored in UTC fires at 8:00 or 10:00 for half the year. State the policy for skipped and repeated hours; make jobs idempotent per (job, local date).
- **Naive or server-local time** — naive timestamps compared against UTC; "per day" bucketed in the server's zone, so daily reports and limits shift with it. Bucket in the zone the product defines.
- **Date-only parsed as an instant** — `new Date('2026-03-01')` is UTC midnight, which displays as the previous day west of UTC. Keep date-only values as dates.
- **Duration math for calendar concepts** — `+30 days` for "monthly" or `+24h` for "same time tomorrow" breaks on month lengths and 23- or 25-hour DST days. Period *n* = anchor + *n* months, clamped; never previous + 1 (Jan 31 → Feb 28 → Mar 28).
- **Closed ranges on timestamps** — `BETWEEN '…-01' AND '…-31'` drops everything after midnight on the 31st; use half-open `[start, next_start)`.
- **Async text in the trigger's locale** — an email, push or job renders in the triggering user's or the server's locale and zone instead of the recipient's.

## Trust & Serialization Boundaries

- **LLM output used without validation** — model output used as a flag or written to a store without a shape or enum check (its injection sinks: `references/security/llm-security.md`).
- **Undefined filter widens a destructive query** — `deleteMany({ where: { tenantId } })` with `tenantId` undefined: Prisma treats an undefined field as absent (unless its strict undefined checks are enabled), so the delete matches every row. Assert presence, or assert the affected-row count.
- **Cross-boundary type coercion** — JSON number vs string IDs compared with `===`; non-normalized input to a hash or digest gives nondeterministic results.
- **64-bit integers through a float** — an int64 ID or amount through JS `Number` or `JSON.parse` silently rounds above 2^53, and the wrong row is read or written. Carry big integers as strings or BigInt end to end.
- **Money as float** — rounding, truncation and `==` errors (CWE-1339). Use integer minor units or a decimal type.
- **Splitting a total by rounding each part** — a fee split, per-line tax or installments rounded independently stop summing to the total, and reconciliation breaks. Largest-remainder, or make the last part the balance.
- **Byte length vs character length** — a byte-limited sink (column or index byte limits, buffers, byte-counting APIs) fed a string measured in characters overflows or truncates mid-character; JS `.length` counts UTF-16 units. Measure in the sink's unit; truncate on grapheme boundaries.
- **Uniqueness normalized differently than lookup** — the unique index is case- or Unicode-form-sensitive while the lookup normalizes (or the reverse): `Kim@x.com` and `kim@x.com` become two accounts. Normalize once at the boundary (case + Unicode form) and index the normalized value.
- **Config strings treated as typed** — env vars are strings: `"false"` and `"0"` are truthy, and a variable missing in prod silently takes the code default. Parse and validate config at startup; fail loud on absence.

## Schema & Migration Safety

For any schema change, apply the database-design skill's zero-downtime rules, if available: `database-design/references/migration-patterns.md`, its single source for lock-safe, N-1-compatible steps (expand → migrate → contract, `CREATE INDEX CONCURRENTLY`, `NOT VALID` then `VALIDATE`, batched backfills, rollback SQL for reversible steps, contract steps behind a restore point). A single-deploy rename or drop, or an unbatched full-table `UPDATE`, is an outage.

Beyond the schema, old and new code run side by side during rolling deploys and rollbacks: new enum values, renamed event or cache fields, clients that never update. Ship readers before writers; never reuse a field name with a new meaning.
