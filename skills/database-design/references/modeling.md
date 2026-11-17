# Modeling

How the answers in SKILL.md's Model section become tables, each shape with the trap that breaks it. Examples use the PG18 `uuidv7()` default; before 18 the application supplies v7 ids.

## 1. From facts to tables

Write what the business must remember as sentences in its own words, then give each one a home. A studio's booking rules:

| Fact, as the business says it | Becomes |
|---|---|
| A studio runs classes | `classes`, owned by a studio (the tenant) |
| A class holds at most 12 people | `classes.capacity` with `CHECK (capacity > 0)`; "never more bookings than capacity" is an invariant (a guard row: `references/integrity.md`) |
| A member books a class once | `bookings` with `UNIQUE (class_id, member_id)` |
| A booking can be cancelled until two hours before the class | policy: code that reads `classes.starts_at`; the cancellation itself is a state of the booking |
| A freed spot is offered to the waitlist for 20 minutes | `waitlist_offers` with `expires_at`; "never two live offers for one spot" is an invariant |
| The price is what it was when the member paid | a snapshot on the booking: `price_minor`, `currency` |

A noun that needs an identity is a table. A verb between two of them is a relationship. "At most", "once", "never" and "until" are keys, constraints or invariants. A value that may change later but must be remembered as it was is a snapshot. A sentence that produces none of these was not a fact, and a table no sentence asks for is speculation. Use the business's words for names, so the schema reads like the sentences.

## 2. Relationships

- **Many-to-many is a table with its own name**, and usually its own facts: `memberships`, `enrollments`, never `user_group`. Key it by the pair when the pair occurs once; when the same pair recurs (a member re-books after cancelling), give it a surrogate id and scope uniqueness to the live row.
- **A child that cannot exist without its parent** takes the parent's key into its own: `order_lines (order_id, line_no)`. Its identity is its place in the parent, and reading a parent's children is one index range.
- **One-to-one splits a table for a reason**: columns only some rows have (a subtype, §4), columns with a different data class or grant (payout details), or a hot narrow part beside a cold wide one. The split table shares the parent's primary key.

## 3. Duplicated and derived data

Denormalize only for a cost you measured; a snapshot (SKILL.md, Model) is not a duplicate.
- **A true duplicate** names its source, staleness bound and sync mechanism, cheapest first: a STORED generated column (same row) → a write in the same transaction → a trigger (writers you don't control; hidden cost) → an async projection from the outbox or CDC (cross-service; seconds stale). Pair it with a drift query: `SELECT count(*) FROM t WHERE dup IS DISTINCT FROM <recomputed>`.
- **Stored aggregates** (counters, materialized views) pay on every write or refresh: fixes in `references/query-patterns.md` (hot rows). **Read models** (CQRS) only when read and write shapes truly diverge.
- **Computed by a model** (embeddings, summaries, extractions): the same rule, plus the producer. `references/ai-data.md`.

## 4. Subtypes, polymorphic references and hierarchies

- **Subtypes.** Few type-specific columns: one table with per-type CHECKs (`CHECK (type <> 'card' OR card_last4 IS NOT NULL)`). Many: a shared table plus a table per type keyed by the parent's id. Never native `INHERITS`: UNIQUE and FKs do not span child tables.
- **Polymorphic references** (a comment on an article or a product): never a `(parent_type, parent_id)` pair, which no FK enforces. For a few parent types, an exclusive arc: one nullable FK column per parent, `CONSTRAINT chk_comments_one_parent CHECK (num_nonnulls(article_id, product_id) = 1)`, and a partial index per FK (`WHERE article_id IS NOT NULL`). For many, a supertype: `commentables (id)`, each parent holding `commentable_id uuid NOT NULL UNIQUE REFERENCES commentables (id)`, comments referencing `commentables`. Or one comment table per parent.
- **Hierarchies.** An adjacency list (`parent_id`) walked by a recursive CTE by default; a closure table or `ltree` path only when subtree reads dominate and moves are rare. No CHECK prevents a cycle: the statement that moves a node, or a trigger, must.

## 5. States and absence

- **A lifecycle is one `status` column** with its legal values in a CHECK, and each transition is a guarded statement (`… SET status = 'shipped' WHERE id = $1 AND status = 'paid'`). Timestamps record when (`paid_at`); they never replace the status, or "which state is this row in" becomes a CASE over five columns that every reader writes differently.
- A state that carries its own facts says so: `CHECK (status <> 'cancelled' OR cancelled_at IS NOT NULL)`.
- A history of transitions the product shows (an order timeline) is an `<entity>_events` table appended in the same transaction; otherwise the audit trail (§7) holds it.
- **NULL means one thing: not known, or not yet.** When "none", "unknown" and "not applicable" lead to different behavior, they are states. A query written without that knowledge falls into these: `x NOT IN (subquery)` returns nothing once the subquery yields a NULL (write `NOT EXISTS`); `x <> 'a'` drops the NULL rows; `count(col)` and `avg(col)` skip them; a CHECK passes on NULL; UNIQUE admits many NULLs.

## 6. Soft delete and erasure

Default to a hard delete plus an audit or archive copy. Use `deleted_at` only when deleted rows must stay referenceable or restore is a product feature, and then:
- every UNIQUE becomes partial `WHERE deleted_at IS NULL`, and hot indexes do too;
- children of a deleted parent get a decided fate: hidden, cascaded or kept;
- reads filter in the query or a view, never through an RLS SELECT policy `USING (deleted_at IS NULL)`: an UPDATE's new row must pass the SELECT policy, so the soft delete itself fails;
- readers who write their own SQL get a view of the live rows (`references/access.md`): a filter every correct query needs is the one a stranger forgets;
- erasure keeps a hard-delete or anonymizing path.

*Break when* "deleted" is really a domain state (cancelled, archived): model it as a status.

**Erasure vs immutable history.** Soft-deleted rows, audit payloads and event stores keep personal data by design, which collides with erasure duties (GDPR Art. 17). Decide before adopting them:
- **Crypto-shredding**: encrypt the subject's personal data under a per-subject key stored elsewhere; destroying the key erases it everywhere at once.
- **No personal data in immutable payloads**: audit rows and events carry a pseudonymous subject id only.
- **Tombstone**: overwrite the personal columns, keep the row and its FKs.
- **Derived copies** (search documents, embeddings, summaries, caches) are deleted with their source, by a cascading FK where they share the database.
- **Backups** expire on their retention schedule; keep an erasure log and re-apply it after any restore.

## 7. Audit trail

The actor is the person or agent, not the database role (`current_user` is the shared app role), and the app role can neither read nor rewrite the trail.
```sql
CREATE SCHEMA audit AUTHORIZATION app_owner;            -- no grants to the app role
CREATE TABLE audit.changes (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name   text        NOT NULL,
    row_id       text        NOT NULL,
    action       text        NOT NULL,
    actor_kind   text,                                   -- 'user', 'agent', 'system': from app.actor_kind
    actor_id     text,                                   -- from app.actor_id, set per transaction
    on_behalf_of text,                                   -- the person an agent acted for
    old_row      jsonb,
    new_row      jsonb,
    changed_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_changes_row ON audit.changes (table_name, row_id);
CREATE INDEX idx_changes_changed_at ON audit.changes USING brin (changed_at);

CREATE FUNCTION audit.capture() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
    INSERT INTO audit.changes (table_name, row_id, action, actor_kind, actor_id, on_behalf_of, old_row, new_row)
    VALUES (TG_TABLE_NAME, CASE TG_OP WHEN 'DELETE' THEN OLD.id ELSE NEW.id END::text, TG_OP,
            current_setting('app.actor_kind', true), current_setting('app.actor_id', true),
            NULLIF(current_setting('app.on_behalf_of', true), ''),
            CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) - 'password_hash' END,   -- strip classified columns
            CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) - 'password_hash' END);
    RETURN NULL;
END $$;
CREATE TRIGGER trg_orders_audit AFTER INSERT OR UPDATE OR DELETE ON app.orders
    FOR EACH ROW EXECUTE FUNCTION audit.capture();
```
- `to_jsonb(row)` copies every column: strip each column whose class forbids it, or keep a per-table allowlist. The trail inherits the access rules and retention of the most sensitive column it records.
- **Agents are actors.** A change made by an agent records the agent (its name and release) and the person it acted for; "the app did it" is not an audit answer. The application sets all three settings per transaction, beside the tenant (`references/access.md`). The settings are only as trustworthy as the code that sets them: a principal that writes its own SQL can set them too, so it gets its own login role and the server log attributes its statements.
- A row trigger doubles its table's write volume: on write-hot tables, capture changes from logical decoding (CDC) instead. CDC cannot see the settings: write the actor into an `updated_by` column, or, to cover deletes too, emit it with `pg_logical_emit_message(true, 'actor', $1)` in the same transaction.

## 8. Event sourcing, ledgers and temporal data

- **Event sourcing** only when the events are the domain and projections are rebuilt from them; "we need history" is an audit trail (§7). An event store keeps `UNIQUE (aggregate_id, version)` for optimistic concurrency, and its readers follow a commit-ordered cursor (`references/integrity.md`, change feeds).
- **Money movement** is a double-entry ledger: immutable entries `(txn_id, account_id, amount_minor, currency)` that sum to zero per transaction and currency, written together by one function or checked at commit by a deferred constraint trigger. Corrections are reversing entries, never UPDATEs; balances are derived, or maintained by a guarded statement (`references/integrity.md`).
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
  PG18+ can declare `PRIMARY KEY (product_id, valid WITHOUT OVERLAPS)` instead (empty ranges rejected; still needs btree_gist), and a referencing table can demand coverage for its whole period: `FOREIGN KEY (product_id, PERIOD valid) REFERENCES product_prices (product_id, PERIOD valid)`. A temporal foreign key supports `NO ACTION` only: no CASCADE, SET NULL or RESTRICT.

## 9. Translations

Translatable text is a child table keyed by the locale, and a translation is derived from one version of its source:
```sql
CREATE TABLE product_translations (
    product_id     uuid    NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    locale         text    NOT NULL,                 -- BCP 47: 'ko', 'pt-BR'
    name           text    NOT NULL,
    source_version integer NOT NULL,                 -- products.content_version it was translated from
    PRIMARY KEY (product_id, locale)
);
-- the requested locale, else the product's default; stale when the source moved on
SELECT p.id, coalesce(t.name, d.name) AS name, t.source_version < p.content_version AS stale
FROM products p
LEFT JOIN product_translations t ON t.product_id = p.id AND t.locale = $1
LEFT JOIN product_translations d ON d.product_id = p.id AND d.locale = p.default_locale;
```
Per-locale columns (`name_en`, `name_ko`) only for two or three locales that will never grow. User-written content keeps the language it was written in as a column; it is not translated in place.

## 10. Reporting shape

Readers that analyze (BI, exports, a model writing SQL) get a surface built for reading, in its own schema (`references/access.md`):
- **One row is one business thing, at a grain stated in the comment** ("one row per paid order line"). Mixed grain is how totals double (`references/query-patterns.md`, fan-out).
- **Facts and dimensions.** A fact row carries an event's measures and the keys of what it happened to; a dimension carries the attributes people filter and group by. Publish them joined, as one wide view, where readers want one table.
- **Measures add, or say that they do not.** A sum adds across any dimension. A balance adds across accounts but not across days. A ratio never adds: publish its numerator and denominator and let the query divide.
- **A dimension's history** (which plan was the customer on when they paid?): the fact snapshots the attribute it needs, or the dimension keeps validity periods (§8) and the join is `valid @> fact.occurred_at`.
- **Mandatory predicates live in the view**: live rows only, test accounts excluded, one currency.
- A view first. A materialized or incrementally maintained table only when the measured read cost says so, with its staleness in the comment.

## 11. `updated_at`

Either a `BEFORE UPDATE` trigger (`NEW.updated_at := now()`) or the ORM sets it, never both: mixed writers leave some updates unstamped. A no-op UPDATE still writes a row version: skip it in the statement (`WHERE col IS DISTINCT FROM $1`), or add `suppress_redundant_updates_trigger()` under a name that sorts before the `updated_at` trigger (triggers fire in name order; after the stamp, every row differs).
