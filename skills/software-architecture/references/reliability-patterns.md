# Reliability Patterns

Patterns that keep state correct under failure, retry and concurrency.

These are not "advanced" — they are the floor for any system that takes money, sends notifications, or coordinates with external services. Decisions land as one row per command and consumer in the Write-path Integrity table of `system.md` §5 (default `docs/arch/system.md`; caller may redirect), which implementation treats as binding; the Self-Check at the end is the gate. Shapes here are logical — physical types, indexes and migrations come from the database-design capability, if available.

---

## 1. Transaction Boundaries

**Rule**: One command = one transaction. The application service (use case) owns the transaction; the domain layer never sees it.

### Where to put `begin/commit`

| Location | When |
|---|---|
| **Application service / use case** | Default. The service knows the unit of work. |
| **Inbound adapter (controller/handler)** | Only for trivial pass-through endpoints — discouraged because it leaks tx into transport layer. |
| **Outbound adapter (repository)** | Never. Repositories don't know what other writes need to be atomic with theirs. |
| **Domain entity** | Never. Domain must remain ignorant of persistence. |

### What belongs inside a single transaction

**Inside**: writes to the *same* logical aggregate, outbox row insertion, idempotency record insertion.

**Outside**: external HTTP/RPC calls, message broker publishes, email sends, anything that can't be rolled back. If you need these to feel atomic with the DB write, use the **Outbox pattern** (§3) instead of `try/commit/then publish`.

### The dual-write problem

Commit, then publish: a crash between them leaves committed state that no consumer ever learns of. **Symmetric failure** (publish first, then commit) creates phantom events. Never write code that needs both. Use the outbox. (Dual writes between an old and a new system during a migration need an ADR — `evolution.md`.)

### Long-running transactions

Don't: external calls, uploads and human approvals happen *outside* the transaction (above); a long-running workflow is a **saga** (`system-architecture.md`) or **durable execution** (`operational-patterns.md` § Durable Execution).

### Read-your-writes inside the same request

After `COMMIT`, a subsequent read on a replica may not see the write. If the same request needs to read what it just wrote, route the read to the primary, or pass the data through in-memory rather than re-querying.

---

## 2. Idempotency

Every non-`GET` endpoint that a client may retry — directly or via a queue — needs an idempotency strategy, checked where the effect commits: transport retries and broker delivery guarantees are performance aids, not the correctness mechanism.

### Three implementation strategies

| Strategy | How | Best For |
|---|---|---|
| **Natural idempotency** | Operation is `PUT`-shaped — same input always produces same state (e.g., "set user email to X") | Configuration writes, upserts |
| **Idempotency key** | Client sends `Idempotency-Key` header; server stores `(key -> response)` and replays on repeat | Payments, money movement, externally-triggered writes |
| **Dedup by event id** | Consumer tracks processed `event.id`s and skips duplicates | Async consumers, webhook handlers |

### Idempotency-Key contract

```
POST /payments
Idempotency-Key: <client-chosen, one per intent, stable across its retries>
Body: { "amount": 1000, "currency": "...", "customer_id": "c-123" }
```

Server behavior:

| Case | Response |
|---|---|
| Required key missing | `400` |
| First time seeing key | Acquire it (below), process, store `(key, request_hash, response)` |
| Same key, same `request_hash`, completed | Return stored response (replay) |
| Same key, **different** `request_hash` | Non-retryable client error, distinct from in-flight (e.g. `422`) — client bug, refuse |
| Same key, still in flight (lease unexpired) | Retryable: `409` + `Retry-After`, or block until the original finishes |
| Same key, lease expired before completion | The retry takes over and resumes from the last recovery point |

### Storage decisions

| Decision | Recommended Default |
|---|---|
| **Scope** | `(tenant_id, user_id, key)` — keys are per-account, not global |
| **TTL** | Longer than the longest retry horizon of any sender (client policy, queue redelivery, provider webhook retries) — hours for sync APIs, days for async/webhook receivers |
| **What to hash** | Method + path + canonicalized body, excluding volatile headers |
| **Storage** | Same store as the resource being written; local-only effects commit in the *same transaction* |
| **Index** | Unique constraint on `(scope, key)` — concurrent retry races collapse to one winner |

Idempotency record (logical shape):

```
idempotency_record (
  scope           tenant + principal; unique together with key
  key             client-chosen
  request_hash    proves a retry matches its key
  state           in_flight | completed
  lease_expires   in-flight lease; once expired, the next retry may take over
  recovery_point  last committed phase (external side effects only)
  response        stored status + body, replayed on repeat
  expires_at      TTL
)
```

### Across external side effects

A provider call cannot join your transaction. If the key row commits only with the result, a retry arriving during the call executes again (double charge); if an in-flight marker commits first with no lease, a crash after the call leaves it stuck and every retry fails forever. For external side effects:

1. **Record intent**: commit the key row *before* the external call, `in_flight`, with a lease.
2. **Call with a derived key**: pass a key derived from it to every downstream call that accepts one (payment APIs commonly do), so re-execution cannot double-apply.
3. **Record progress** on the key row at each recovery point (an atomic phase), so a retry resumes instead of restarting.
4. **Take over on expiry**: an expired lease lets the next retry resume from the recovery point.
5. **Complete**: store the response when the last phase commits.

If a downstream accepts no key, **reconcile** — query its state for this intent before any re-execution.

### Idempotency as a port

In hexagonal: model an `IdempotencyStore` port. The application service wraps the use case:

```
IdempotencyStore.acquire(key, request_hash) ->
  | NewExecution(lease)        -> run use case, record recovery points, store result
  | Resume(recovery_point)     -> continue from the last committed phase
  | Replay(stored_response)    -> return stored_response
  | InFlight(retry_after)      -> retryable conflict
  | Mismatch                   -> non-retryable client error
```

This keeps idempotency out of every controller and out of the domain.

### What NOT to use as the key

- **Request body hash alone** — two distinct intents can have identical bodies (two separate purchases of the same item); a body-hash key silently swallows the second. The hash verifies that a retry matches its key; it is not the identity.
- **Trace or request id** (changes on each retry) or **user id** (too coarse).

The key must be **client-chosen** (a random or time-ordered UUID), included in the request, and stable across retries of the *same intent*.

---

## 3. Transactional Outbox

Commit the state change **and** an outbox row in the same transaction; a relay claims pending rows, publishes them to the broker and marks them published.

### Outbox table shape (logical)

```
outbox (
  id              unique, time-sortable — for debugging, not trusted for order
  aggregate_type  "order", "user"
  aggregate_id    partition / ownership key
  aggregate_seq   per-aggregate monotonic sequence — THE ordering key; unique with aggregate_id
  event_type      "OrderCreated"
  payload         structured document
  headers         trace context captured at insert, tenant
  created_at      assigned by the store, time-zoned
  published_at    null = pending
  attempts        relay attempts so far
  last_error      last relay failure; dead-letter after N attempts
)
index:     pending rows (published_at is null) — filtered/partial where the engine supports it
retention: published rows kept for a debug/replay window, then purged
```

Assign `aggregate_seq` in the same transaction as the state change (e.g. from the aggregate's version, §4).

### Relay strategies

| Strategy | How | Trade-off |
|---|---|---|
| **Polling** | Workers claim pending rows oldest-first (in `aggregate_seq` order within an aggregate), one owner per aggregate, every N seconds | Simple, works on any store. Adds query load and a latency floor. |
| **Log-based change data capture** | A connector tails the store's change/replication log and emits the outbox inserts | Lower latency, no polling load. Needs CDC infrastructure to operate. |
| **Store-native change notification** | The store signals new rows, where the engine offers it | Low latency on one store; a hint only — keep a polling fallback for missed signals and relay restarts. |

**Default**: Start with polling at a seconds-level interval. Move to CDC only when latency requires it.

### Delivery semantics

The outbox guarantees **at-least-once**. The consumer must be idempotent (§2) — process by `event.id` with dedup. Exactly-once across systems is a fiction; design for at-least-once + idempotent consumers.

### Ordering

Per-aggregate order holds only if all four hold:

1. the relay publishes each aggregate's rows in `aggregate_seq` order;
2. one relay worker owns an aggregate (or partition) at a time — a lease or lock per key;
3. a failed row holds back later rows of its aggregate until it is published or dead-lettered (head-of-line blocking — accept it, or declare that this aggregate's consumers tolerate reordering);
4. the broker is partitioned by `aggregate_id`.

Consumers that need order check `aggregate_seq` and tolerate duplicates and gaps. Global ordering is almost never needed.

**A change-feed cursor follows commit order.** A reader that pulls "everything after cursor X" (device sync, stream replay, a polling consumer) by an id or timestamp assigned before commit skips any row whose transaction commits after a later one was read — a gap that never heals. Cursor on the store's commit-log position, a per-scope counter taken as the transaction's last statement (it serializes that scope's writers), or a read horizon held below the oldest in-flight transaction; else re-read an overlap window longer than the longest transaction and dedupe by id.

### Inbox pattern (the consumer side)

Mirror image: the consumer records `(message_id, processed_at)` in an inbox table inside the same transaction as its state change. Duplicates are dropped on insert by the unique constraint. Required when the consumer cannot be made naturally idempotent. When several handlers share one inbox, the unique key is `(consumer, message_id)`; a webhook receiver keys by the provider's event id.

### Common mistakes

- **Outbox in a separate database** from the source of truth. Then you're back to dual-writes.
- **Deleting outbox rows immediately after publish.** Keep them for a retention window — useful for debugging and replay.
- **Publishing inside the transaction** ("just emit to the broker before COMMIT"). Broker hiccup blocks your DB transaction; broker timeout poisons your write path.
- **No DLQ on relay failures.** A poison message will jam the relay forever. Move to a dead-letter table after N attempts.
- **No alert on relay lag.** A stuck relay raises no errors; alert on the age of the oldest pending row (`observability.md`).

### When NOT to use outbox

If the only "side effect" is an internal background job in the same database, use a **job table** (the simplest outbox). Don't bring in a streaming broker just to send an email — a `pending_emails` table polled by a worker is the same pattern at a tenth of the complexity.

---

## 4. Concurrency Control

Every system with mutable shared state needs a strategy against the **lost update** (concurrent read-modify-writes silently overwriting each other), and invariants that span rows need more than per-row protection.

### Strategy selection

First match wins; one write path can need several:

1. **Can a writer act while partitioned** (offline client, edge site, long-offline device)? Conflicts are then certain and locks impossible → *Offline and partitioned writers* (below).
2. **Does an invariant span rows** (uniqueness, capacity, non-overlap, sum limit, "at most N active")? That is **write skew** (Kleppmann); per-row versions don't catch it. Enforce with a store constraint (preferred) → an explicit lock on the invariant's rows (when the conflict is an insert, a parent or slot row every writer must touch) → serializable isolation with retry on serialization failure. Isolation mechanics via the database-design capability, if available.
3. **Is the new value a function of the old** (counter, balance, stock)? → Conditional atomic update.
4. **Conflicts rare, and the command can be re-validated against fresh state?** → Optimistic concurrency (version column / ETag).
5. **Conflicts common, short critical section over a few rows?** → Pessimistic row lock. For one hot key, a single writer per key (one owner or partition).

Collaboratively edited content (several users typing at once) → CRDT or operational transform — required, not out of scope.

### Optimistic concurrency (default)

Each row carries a `version` (monotonic integer). Writes are conditional:

```sql
UPDATE orders
SET status = 'paid', version = version + 1
WHERE id = :id AND version = :expected_version
```

If `rows_affected = 0`, somebody else wrote first. The application returns `409 Conflict` (or retries internally by re-reading the row and re-validating the command against the fresh state — never by re-applying the stale write).

**HTTP equivalent**: `ETag` + `If-Match`; a failed `If-Match` returns `412 Precondition Failed` (per RFC 9110), as opposed to the `409 Conflict` returned by the application-level version-column check above.

| Decision | Recommended |
|---|---|
| **Where the version lives** | Column on the aggregate root, never on child rows |
| **Type** | Monotonic integer. Don't use `updated_at` — clock skew, identical timestamps under load |

### Pessimistic locking

Use only for short critical sections whose read-decide-write logic spans a few rows and can't be pushed into one conditional UPDATE — e.g. moving a booking between two slots: lock both slot rows (`SELECT … FOR UPDATE` or the engine's equivalent), check capacity, update both, commit. A single hot counter (flash-sale stock) is not this case — use the conditional atomic update below, or a single writer per key.

**Watch for**:
- **Deadlocks** — always lock rows in a consistent order across the codebase.
- **Lock duration** — never hold a row lock across a network call.
- **Connection pool starvation** — a long-held lock can block every other writer.

### Atomic operations

When the new value is a function of the old value (`balance += amount`, `views += 1`), don't read-modify-write. Push the math into the DB:

```sql
UPDATE accounts SET balance = balance + :amount WHERE id = :id AND balance + :amount >= 0
```

This is conflict-free by construction. Use it for counters, balances, and aggregates whenever possible. Zero rows affected means the guard failed (insufficient balance or stock) — a domain outcome, not a retry.

### Offline and partitioned writers

A writer that acts while disconnected (mobile, desktop, edge site, field device) cannot take a lock, and a `409` after days offline discards the user's work. Per aggregate, choose a merge policy and record it in the offline/sync ADR:

| Policy | Use when |
|---|---|
| Server-authoritative; rejected changes surfaced to the user | Conflicts are rare and the user can redo the change |
| Field-level merge | Concurrent edits usually touch different fields |
| Append-only operations (add, increment, log entry) | The domain can be expressed as commutative operations instead of state |
| Convergent data type (CRDT) | Collaborative or long-offline multi-writer data |
| Last-writer-wins | Only where silently losing a concurrent edit is acceptable |

Track causality with a version vector or hybrid logical clock — never wall-clock time (the same reason `updated_at` is not a version). Tombstone deletes, and purge a tombstone only after every replica has synced past it. The server re-validates invariants after each merge: a violation (stock oversold while offline) is a domain conflict surfaced to a person, not a merge outcome. Pulls resume from a commit-ordered cursor (§3 Ordering). State the longest supported offline window and the re-sync path beyond it.

### Idempotency vs concurrency

These solve different problems and you usually need both:

| Problem | Tool |
|---|---|
| Same client retries the same intent | Idempotency key |
| Different clients race on the same resource | Optimistic version / pessimistic lock |
| Different clients break an invariant across rows | Constraint / lock on the invariant's rows / serializable + retry |

A payment endpoint typically has both: idempotency key on the request, version on the wallet row.

---

## Self-Check

When designing any write path, answer — one row per command and consumer in `system.md` §5 Write-path Integrity:

- [ ] Where does the transaction begin and end? Is it in the application service?
- [ ] Are there external side effects (broker, HTTP, email)? If yes, is there an outbox — with an alert on the age of its oldest unpublished row? Does an external call inside a retried command have an intent record with a lease and recovery points?
- [ ] Can the client safely retry? If yes, is there an idempotency key or natural idempotency?
- [ ] Can two writers race? Same row → version column or conditional atomic update. Invariant spanning rows → named enforcement (constraint / lock on the invariant's rows / serializable + retry). Partitioned writers → a merge policy per aggregate.
- [ ] On the consumer side: is the handler idempotent by `event.id`, with a DLQ whose depth is alerted?

If any answer is "no" or "we'll handle it later," document it as a known risk in the Risk Register (default `docs/arch/risks.md`; caller may redirect).
