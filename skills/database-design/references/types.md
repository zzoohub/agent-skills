# Column Types and DDL Defaults

Each default carries the condition that breaks it. An existing schema keeps its conventions unless they cause a defect named here. Adding a column of an identity, STORED generated or constrained-domain type to a live table rewrites it (`references/migration-patterns.md`).

## Keys

- **UUIDv7** (SKILL.md, Model): before PG18, no default; the application passes an RFC 9562 v7 value. UUIDv4 (`gen_random_uuid()`) only on low-volume tables.
- **`bigint GENERATED ALWAYS AS IDENTITY`** for internal, high-volume, never-exposed tables (events, audit, metrics): 8 bytes less per row than a UUID, about 8 GB per billion rows in every index and foreign key that carries it; `BY DEFAULT` only where ids are loaded from elsewhere. Identity needs no sequence grant, `serial` does: no new `serial` columns. No new `integer` keys; an existing one past half its range is a migration to schedule now (`references/migration-patterns.md`, worked example).
- **Possession tokens** (share links, invites, reset tokens, API keys): ≥128 random bits, never a UUID (RFC 9562 forbids UUIDs as security capabilities), stored as a SHA-256 hash and looked up by hash.
- **Natural keys** for stable external codes (ISO 4217 currency, ISO 3166 country) and lookup tables; never emails, names or anything a person can change.

## Time

| Value | Type | Why |
|---|---|---|
| An instant: created, paid, expires | `timestamptz` | Stores the instant and renders it in the session `TimeZone`; it keeps no zone. |
| A calendar date: birthday, business date, due date | `date` | As an instant it shows the previous day west of UTC. |
| A future wall-clock event: appointment, opening hours, "9:00 daily", local deadline | `timestamp` (or `date` + `time`) plus an IANA zone column (`'Asia/Seoul'`) | An instant computed today freezes today's zone rules, so a rule or DST change moves the event. Resolve it when it fires. |
| A period | `tstzrange` / `daterange` + EXCLUDE | `references/modeling.md` §8 |

Never `timestamp` for an instant: its meaning depends on each writer's session zone.

A zone column holds a region name and says so: `time_zone text NOT NULL CONSTRAINT chk_reminders_time_zone CHECK (time_zone ~ '^[A-Za-z_]+(/[A-Za-z0-9_+-]+)+$' AND (timestamp '2000-01-01' AT TIME ZONE time_zone) IS NOT NULL)`. The pattern rejects abbreviations and offsets (`EST`, `+09:00`), which do not follow rule changes; an unknown name raises `time zone … not recognized`. The second test yields NULL for a NULL zone, so a nullable column needs `time_zone IS NULL OR (…)`.

## Money

- Multi-currency: `bigint` minor units plus a currency column, the exponent taken from the currency (ISO 4217: 0 for JPY and KRW, 2 for most, 3 for BHD and KWD), so a fixed `numeric(_, 2)` is wrong. `numeric(p, s)` fits a single-currency table or sub-minor precision (unit prices, FX rates).
- Never `real`/`double precision`, nor the `money` type: its precision and format follow `lc_monetary`, and it records no currency.
- No default currency, unit, tax rate or FX rate: a missing value must fail the insert, not become dollars.
- Store the rate and amount actually applied on the line (a snapshot) and round once, at a named step.

## Text and identity strings

- `varchar(n)` only where an external contract fixes the length; never `char(n)`, which displays blank-padded while comparisons drop the padding. Fixed codes are `text` + `CHECK (currency ~ '^[A-Z]{3}$')`.
- **Email**: `text` with `CHECK (strpos(email COLLATE "C", '@') > 1 AND char_length(email) <= 254)`. No regex: common ones reject `o'connor@`, `josé@` and internationalized domains. Prove ownership by sending a link.
- **Sorting for people** follows their language, not the database default: `ORDER BY name COLLATE "ko-x-icu"` in the query; index that collation only when the sorted path is hot, one index per locale served.
- **Case-insensitive uniqueness**, in its scope: `CREATE UNIQUE INDEX uq_users_email ON users (tenant_id, lower(email)) WHERE deleted_at IS NULL;` with queries on `lower(email)`; or a nondeterministic collation, which the citext documentation recommends over citext: `CREATE COLLATION ci (provider = icu, locale = 'und-u-ks-level2', deterministic = false);`, then `email text COLLATE ci`. On such a column, `LIKE` and substring functions (`position`, `strpos`) fail before PG18, CHECKs included, and regular expressions fail on PG18 too: apply them to `email COLLATE "C"`.

## Closed sets

| Situation | Use |
|---|---|
| Values fixed by code, may grow | `text` + `CHECK (status IN (…))`; to add a value, drop and re-add the CHECK `NOT VALID` in one statement, then `VALIDATE` |
| Values carry attributes (label, order, flags) or users manage them | A lookup table whose primary key is the natural code |
| A frozen set whose order SQL compares | ENUM: values can be added, never removed or reordered, and a new value is unusable until the adding transaction commits |

- A boolean that will grow a third state, or two booleans that must never both be true, is a status column.
- Lookup rows are schema: ship them as idempotent migrations (`INSERT … ON CONFLICT (code) DO NOTHING`; `DO UPDATE` to rename a label) and key FKs by the code, because identity values can differ between environments.

## JSONB, arrays and files

- JSONB holds attributes no hot query constrains, joins or filters, and user-defined fields when they are the product. A key becomes a column at its first constraint, FK or hot `WHERE`/`ORDER BY`.
- Index one key with an expression B-tree (`((attributes->>'brand'))`); GIN (`jsonb_path_ops` when only `@>` is needed) serves ad-hoc containment over the whole document.
- No FK reaches into JSONB: an id inside a document is a snapshot, never a live reference.
- Updating one key rewrites the whole value: large documents updated often belong in rows.
- Arrays: short value lists with no FK and no per-element attributes. GIN serves `@>` and `&&`, not `= ANY`. Anything more is a child table.
- Files live in object storage; the row keeps the key, size, media type, checksum and lifecycle state. `bytea` only for small values read with their row; never large objects, which a row `DELETE` orphans and logical replication skips.

## Foreign keys

- State `ON DELETE` on every FK: CASCADE only inside one aggregate whose root may be deleted (cart → items, draft order → lines), never from a referenced entity (customer, product, account) into financial or audit records; RESTRICT or NO ACTION for references; SET NULL for optional links. A NO ACTION check can be deferred to commit (`DEFERRABLE INITIALLY DEFERRED`, for circular references or reordering inside a transaction); RESTRICT cannot.
- A composite FK needs a matching UNIQUE on the parent, so pooled tenancy gives every parent `UNIQUE (tenant_id, id)` for `FOREIGN KEY (tenant_id, customer_id) REFERENCES customers (tenant_id, id)`. Child-column indexes: SKILL.md, Physical design.
- Declare the reference even where the application "already checks": the constraint is also how a reader who has only the catalog finds the join.

## Domains and generated columns

- A domain pays off when one rule covers three or more columns; its CHECK applies to array elements too. Outer joins can still produce NULLs of a NOT NULL domain, so repeat `NOT NULL` on the column.
- Write `STORED` or `VIRTUAL` explicitly: PG18 defaults to VIRTUAL, earlier versions accept only STORED. Both take immutable expressions over the current row. STORED is indexable; VIRTUAL (PG18+) is free to add, but cannot be indexed, cannot be part of a key or foreign key, is not sent by logical replication, and may use only built-in functions and types. A `tsvector` column meant for a GIN index therefore says STORED.
- Full-text vectors use the two-argument form, with a constant or a `regconfig`-typed column, and coalesce each nullable part, since one NULL empties the vector: `to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))`.

## Secrets and personal data

- Passwords: hashed in the application or by the identity provider, stored as `text`; never hashed in SQL, where the plaintext lands in statement logs and `pg_stat_activity`.
- Reversible personal data: application-level envelope encryption; encrypted columns lose indexing, so add a keyed-hash column for lookup by value.

## Vectors

`vector(n)` or `halfvec(n)` from pgvector, on a row that is written once, in a table per embedder: `references/ai-data.md`.
