# AI data

Tables for what AI features store: retrieval indexes, conversations, memory, agent runs, usage. What to retrieve, which embedder and what to remember are decided with the ai-architecture capability, if available; this file gives those decisions their physical form. The classic rules do the work: these stores are derived data, append-only logs, state machines and counters. SQL was run on PostgreSQL 18.7 with pgvector 0.8.7; versions, limits and alternatives are in `references/landscape.md`.

## 1. Derived data names its source

An embedding, a summary, an extraction or a classification is computed from a source by a producer (a model and its version, a chunking recipe, a prompt release). Each one:
- **points at its source** with a foreign key that cascades, so deleting or erasing the source removes it in the same transaction. Text can be recovered from embeddings: they carry their source's data class and erasure duty;
- **records its producer**, per row, or per table when a table holds one producer's output;
- **is rebuildable, and says so**: a table that can be dropped and recomputed is a cache whose rebuild time is its recovery time. One that cannot (a person corrected it) is primary data with a status.

## 2. Chunks and embeddings

```sql
CREATE TABLE app.chunks (                       -- replaced, never edited
    id           uuid DEFAULT uuidv7() CONSTRAINT pk_chunks PRIMARY KEY,
    tenant_id    uuid NOT NULL,
    document_id  uuid NOT NULL,
    seq          integer NOT NULL,              -- position in the document
    content      text NOT NULL,
    content_hash bytea NOT NULL,                -- sha-256 from the ingest job: skip unchanged text
    tsv          tsvector GENERATED ALWAYS AS (to_tsvector('english', content)) STORED,
    CONSTRAINT uq_chunks_document_seq UNIQUE (document_id, seq),
    CONSTRAINT uq_chunks_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_chunks_document FOREIGN KEY (tenant_id, document_id)
        REFERENCES app.documents (tenant_id, id) ON DELETE CASCADE
);
CREATE INDEX idx_chunks_tsv ON app.chunks USING gin (tsv);

CREATE TABLE app.chunk_embeddings_e1 (          -- one table per embedder
    chunk_id   uuid NOT NULL CONSTRAINT pk_chunk_embeddings_e1 PRIMARY KEY,
    tenant_id  uuid NOT NULL,                   -- the filter lives beside the vector
    embedding  halfvec(1024) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_chunk_embeddings_e1_chunk FOREIGN KEY (tenant_id, chunk_id)
        REFERENCES app.chunks (tenant_id, id) ON DELETE CASCADE
);
COMMENT ON TABLE app.chunk_embeddings_e1 IS
    'Derived from app.chunks.content by embedder acme-embed-3 (1024 dims, cosine). Rebuildable; rows are never updated.';
CREATE INDEX idx_chunk_embeddings_e1_ann ON app.chunk_embeddings_e1 USING hnsw (embedding halfvec_cosine_ops);
CREATE INDEX idx_chunk_embeddings_e1_tenant ON app.chunk_embeddings_e1 (tenant_id);
```

- **The vector row is written once.** A changed document inserts new chunks and deletes old ones, so an embedding never describes text that has since changed, and no update re-inserts a vector into the graph. Mutable facts (title, tags, read counts) stay on the document.
- **One table per embedder.** Vectors from two models are not comparable, and an index needs one dimension. The embedder is in the table comment; a new one is a new table (§5).
- **Filters that must apply inside the search live on the vector row** (`tenant_id`, an access scope): a deliberate duplicate of a fact that does not change. A filter reached through a join is applied after the candidates are chosen. One that changes rarely (an article's visibility) is kept in step by a composite foreign key with `ON UPDATE CASCADE` to a matching UNIQUE on the source (`(tenant_id, id, visibility)`); each change re-inserts that row's vector, which rare changes can afford. One that changes often (per-user permissions) stays in its own table and is applied through a join, with iterative scans on.
- **The operator must match the operator class**: `halfvec_cosine_ops` serves `<=>` only. With `<->` the same query ran as a parallel sequential scan and sort, without an error.
- **`halfvec`** stores a dimension in 2 bytes instead of 4 and is the indexable type from 2,001 to 4,000 dimensions; confirm recall on your own queries before and after.
- **Build after loading**: `CREATE INDEX CONCURRENTLY` once the rows are in, with `maintenance_work_mem` large enough to hold the graph. Inserting row by row into an existing HNSW index is many times slower.
- **Size it like any hot table**: rows × (dimensions × bytes + overhead) for the heap, and the index is larger than the heap (60 MB and 79 MB for 100k 256-dimension rows here). The graph must stay in memory to be fast.

## 3. Searching with a filter

An approximate index returns its nearest candidates first, and the filter (a WHERE clause, a join, an RLS policy) is applied afterwards. With defaults, a filtered search returns fewer rows than its LIMIT and raises nothing. Measured on 100k vectors, `LIMIT 20`:

| The filter keeps | Defaults | `hnsw.iterative_scan = strict_order` | Exact, through the tenant B-tree |
|---|---|---|---|
| 26.6% of rows | 15 rows | 20 | 20 |
| 3.4% | 2 rows | 20 | 20 |
| 0.12% (120 rows) | (planner chose exact) | 17 when forced through the index | 20, the plan the planner chose |

- **Turn iterative scans on** for every role that searches with a filter: `ALTER ROLE app_rw SET hnsw.iterative_scan = 'strict_order'`, or `SET LOCAL` in the transaction. `hnsw.max_scan_tuples` bounds how far the scan walks.
- **Keep a B-tree on the filter column.** For a small tenant the planner then reads its rows and sorts them: exact and cheap. Approximate search earns its place only where a filter value keeps many thousands of rows.
- **Run the search under custom plans** (`SET LOCAL plan_cache_mode = force_custom_plan`). A prepared statement's generic plan is chosen without the filter's value, so it suits the average tenant: forced generic, the largest tenant here was searched exactly in 96 ms, against 5 ms through the index.
- **A tenant or category with its own large corpus** gets its own graph: a partial index for a few values, list or hash partitions for many.
- **Guard it.** Alert when a search returns fewer rows than its LIMIT while more exist. Measure recall on real queries by running each again exactly (`SET LOCAL enable_indexscan = off`) and comparing ids; random or toy vectors say nothing about recall.

```sql
SELECT e.chunk_id, e.embedding <=> $2 AS distance
FROM app.chunk_embeddings_e1 e
WHERE e.tenant_id = $1
ORDER BY e.embedding <=> $2
LIMIT 20;
```

## 4. Hybrid search

Keyword and vector results are fused by rank, each branch filtered and limited before the join:
```sql
WITH kw AS (
    SELECT id, row_number() OVER (ORDER BY score DESC, id) AS r
    FROM (SELECT c.id, ts_rank_cd(c.tsv, q) AS score
          FROM app.chunks c, websearch_to_tsquery('english', $2) q
          WHERE c.tenant_id = $1 AND c.tsv @@ q
          ORDER BY score DESC, c.id
          LIMIT 40) s
), vec AS (
    SELECT id, row_number() OVER (ORDER BY distance, id) AS r
    FROM (SELECT e.chunk_id AS id, e.embedding <=> $3 AS distance
          FROM app.chunk_embeddings_e1 e
          WHERE e.tenant_id = $1
          ORDER BY e.embedding <=> $3
          LIMIT 40) s
)
SELECT id, coalesce(1.0 / (60 + kw.r), 0) + coalesce(1.0 / (60 + vec.r), 0) AS score
FROM kw FULL JOIN vec USING (id)
ORDER BY score DESC, id
LIMIT 10;
```
The inner `ORDER BY … LIMIT` keeps the vector branch on its index; numbering the rows in the outer query keeps the ranks deterministic. `ts_rank_cd` reads every matching row and knows nothing about how rare a word is across the corpus: when a keyword query matches tens of thousands of rows, or keyword ranking quality matters, a BM25 index extension is the step up (`references/landscape.md`).

## 5. Changing the embedder

A migration, never a configuration change: the query vector and the stored vectors must come from the same model.
1. **Expand**: create `chunk_embeddings_e2` with its dimension, and have ingest write both tables.
2. **Backfill** by key, in batches, resumable (`references/migration-patterns.md`, Large Table Migrations):
   ```sql
   SELECT c.id, c.tenant_id, c.content FROM app.chunks c
   WHERE c.id > $1 AND NOT EXISTS (SELECT 1 FROM app.chunk_embeddings_e2 e WHERE e.chunk_id = c.id)
   ORDER BY c.id LIMIT $2;
   ```
3. **Index** `CONCURRENTLY` once the counts match, then measure recall and the retrieval eval on the new table.
4. **Switch reads** in one deploy: the query embedder and the table change together.
5. **Contract**: stop the old writes, then drop the old table after the verification window.

A new chunking recipe is the same move one level up: new chunks beside the old, then their embeddings.

## 6. The session log

One row per message, appended, never one JSON document per conversation: a document is rewritten in full on every turn, cannot be paged or indexed by position, and has no place to hang a constraint.
```sql
CREATE TABLE app.threads (
    id          uuid DEFAULT uuidv7() CONSTRAINT pk_threads PRIMARY KEY,
    tenant_id   uuid NOT NULL,
    user_id     uuid NOT NULL,                       -- a foreign key to the project's users table
    next_seq    integer NOT NULL DEFAULT 1,          -- guard row: every append takes it
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_threads_tenant_id_id UNIQUE (tenant_id, id)
);
CREATE TABLE app.messages (
    thread_id     uuid NOT NULL,
    seq           integer NOT NULL,                  -- position in the thread
    tenant_id     uuid NOT NULL,
    role          text NOT NULL CONSTRAINT chk_messages_role CHECK (role IN ('user', 'assistant', 'tool', 'system')),
    parts         jsonb NOT NULL CONSTRAINT chk_messages_parts CHECK (jsonb_typeof(parts) = 'array'),
    parts_format  smallint NOT NULL,                 -- version of the app's own part shape
    model         text,                              -- assistant rows: the model id that answered
    created_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_messages PRIMARY KEY (thread_id, seq),
    CONSTRAINT fk_messages_thread FOREIGN KEY (tenant_id, thread_id)
        REFERENCES app.threads (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT chk_messages_model CHECK ((role = 'assistant') = (model IS NOT NULL))
);

-- Append: one statement takes the next position under the thread's row lock.
WITH t AS (
    UPDATE app.threads SET next_seq = next_seq + 1
    WHERE id = $1 AND tenant_id = $2 AND next_seq = $3      -- $3: the position the writer believes is next
    RETURNING next_seq - 1 AS seq
)
INSERT INTO app.messages (thread_id, seq, tenant_id, role, parts, parts_format, model)
SELECT $1, t.seq, $2, $4, $5, 1, $6 FROM t
RETURNING seq;
```
- **Order is a key, not a timestamp.** `(thread_id, seq)` gives the transcript one gap-free order for replay, resume and audit. Zero rows from the append means another writer got there first: re-read the thread, never retry blind. Drop the `next_seq = $3` test where late arrivals may simply append.
- **Typed spine, loose content.** What is filtered, ordered, counted, billed or constrained is a column. Content blocks are JSONB in the application's own shape, with its version in `parts_format`: provider and SDK message formats change, and rows written last year must still parse. Translate at the provider adapter, and migrate a format like any other data change (expand, backfill, switch).
- **Raw provider payloads and traces are not the log.** Keep them in a separate store or schema with a short retention and no foreign keys from product tables.
- **It grows without bound**: retention per data class, time partitions once volume says so (`references/scale.md`), and erasure by cascade from the user or thread.

## 7. Tool calls and approvals

A tool call is a row with a lifecycle: the ledger of what an agent did, and the durable wait for a person.
```sql
CREATE TABLE app.tool_calls (
    id            uuid DEFAULT uuidv7() CONSTRAINT pk_tool_calls PRIMARY KEY,
    tenant_id     uuid NOT NULL,
    thread_id     uuid NOT NULL,
    message_seq   integer NOT NULL,                  -- the assistant message that asked for it
    tool          text NOT NULL,
    arguments     jsonb NOT NULL,
    status        text NOT NULL DEFAULT 'proposed'
                  CONSTRAINT chk_tool_calls_status CHECK (status IN ('proposed', 'approved', 'rejected', 'running', 'succeeded', 'failed')),
    decided_by    uuid,                              -- the person who approved or rejected
    decided_at    timestamptz,
    result        jsonb,
    finished_at   timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_tool_calls_message FOREIGN KEY (thread_id, message_seq)
        REFERENCES app.messages (thread_id, seq) ON DELETE CASCADE,
    CONSTRAINT chk_tool_calls_decision CHECK ((status IN ('approved', 'rejected')) <= (decided_by IS NOT NULL))
);
CREATE INDEX idx_tool_calls_message ON app.tool_calls (thread_id, message_seq);
CREATE INDEX idx_tool_calls_waiting ON app.tool_calls (tenant_id, created_at) WHERE status = 'proposed';
```
Every transition is a guarded statement, so two approvers or two executors cannot both win: `UPDATE … SET status = 'approved', decided_by = $2, decided_at = now() WHERE id = $1 AND status = 'proposed'`, then the executor's `… SET status = 'running' WHERE id = $1 AND status = 'approved'`. Zero rows means someone else did it. The call's id is the idempotency key for its external effect (`references/integrity.md`). When the domain already has a row for the action with its own states (a refund awaiting approval), that row is the ledger entry and the wait: record who or what proposed it there, and add no second, generic row.

## 8. Memory

Governed state, not a transcript: immutable versions with provenance, a scope and a validity period.
```sql
CREATE TABLE app.memories (
    id             uuid DEFAULT uuidv7() CONSTRAINT pk_memories PRIMARY KEY,
    tenant_id      uuid NOT NULL,
    user_id        uuid NOT NULL,                    -- scope: never read across users
    topic          text NOT NULL,                    -- what the fact is about
    content        text NOT NULL,
    written_by     text NOT NULL CONSTRAINT chk_memories_written_by CHECK (written_by IN ('user', 'model', 'operator')),
    trust          text NOT NULL CONSTRAINT chk_memories_trust CHECK (trust IN ('verified', 'unverified', 'tainted')),
    source_thread_id uuid,                           -- provenance: the message it was learned from
    source_seq     integer,
    valid          tstzrange NOT NULL DEFAULT tstzrange(now(), NULL),
    expires_at     timestamptz,                      -- unverified entries expire
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_memories_source FOREIGN KEY (source_thread_id, source_seq)
        REFERENCES app.messages (thread_id, seq) ON DELETE CASCADE,
    CONSTRAINT ex_memories_one_current EXCLUDE USING gist (user_id WITH =, topic WITH =, valid WITH &&),
    CONSTRAINT chk_memories_expiry CHECK (trust = 'verified' OR expires_at IS NOT NULL)
);
```
- **A change closes the old version and inserts the new one in one transaction**: `UPDATE … SET valid = tstzrange(lower(valid), now()) WHERE user_id = $1 AND topic = $2 AND upper_inf(valid)`, then the insert. The exclusion constraint (it needs `btree_gist`) rejects two current values for one topic, and its index serves recall: `WHERE user_id = $1 AND valid @> now() AND trust <> 'tainted' AND (expires_at IS NULL OR expires_at > now())`.
- **Provenance is what makes a poisoned memory removable**: which message taught it, who wrote it, how far it is trusted. A session that read untrusted content writes `tainted` until reviewed. Rollback is by version.
- Free-text memories without a topic drop the exclusion constraint and keep everything else. Their embeddings follow §2.

## 9. Runs and steps

A durable run persists each non-deterministic step's result, so a resume reads it and never calls the model or tool again.
```sql
CREATE TABLE app.runs (
    id             uuid DEFAULT uuidv7() CONSTRAINT pk_runs PRIMARY KEY,
    tenant_id      uuid NOT NULL,
    thread_id      uuid,
    status         text NOT NULL DEFAULT 'queued'
                   CONSTRAINT chk_runs_status CHECK (status IN ('queued', 'running', 'waiting', 'succeeded', 'failed', 'cancelled')),
    release        text NOT NULL,                    -- code, prompt and model set the run started on
    lease_token    uuid,
    lease_expires  timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    finished_at    timestamptz,
    CONSTRAINT fk_runs_thread FOREIGN KEY (tenant_id, thread_id)
        REFERENCES app.threads (tenant_id, id) ON DELETE CASCADE
);
CREATE TABLE app.run_steps (
    run_id       uuid NOT NULL CONSTRAINT fk_run_steps_run REFERENCES app.runs (id) ON DELETE CASCADE,
    seq          integer NOT NULL,                   -- the step's position in the run: the replay key
    kind         text NOT NULL CONSTRAINT chk_run_steps_kind CHECK (kind IN ('model_call', 'tool_call', 'wait')),
    input_hash   bytea NOT NULL,                     -- a replay with a different input is a bug, not a cache miss
    output       jsonb NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_run_steps PRIMARY KEY (run_id, seq)
);
```
Record a step with `INSERT … ON CONFLICT (run_id, seq) DO NOTHING RETURNING seq`: no row back means the step already ran, so read its stored output. Claim and lease a run as a job (`references/integrity.md`), and finish a run on the release it started with.

**A framework's own tables** (a checkpointer, a workflow engine, a memory library) belong to the framework: give them their own schema, no foreign keys into them, and their retention on your schedule. Checkpoint stores keep a copy of the state per step, so a long thread grows faster than its message count; nothing prunes them unless you do.

## 10. Usage and budgets

```sql
CREATE TABLE app.model_calls (                       -- one row per model call, append-only
    id                  bigint GENERATED ALWAYS AS IDENTITY,
    created_at          timestamptz NOT NULL DEFAULT now(),
    tenant_id           uuid NOT NULL,
    feature             text NOT NULL,
    run_id              uuid,                        -- no foreign key: the ledger outlives the run
    provider            text NOT NULL,
    model               text NOT NULL,
    input_tokens        integer NOT NULL,            -- uncached input only
    cache_read_tokens   integer NOT NULL DEFAULT 0,
    cache_write_tokens  integer NOT NULL DEFAULT 0,
    output_tokens       integer NOT NULL,            -- visible output plus reasoning
    cost_micro          bigint NOT NULL,             -- millionths of the currency unit, at the price in force when called
    currency            text NOT NULL CONSTRAINT chk_model_calls_currency CHECK (currency ~ '^[A-Z]{3}$'),
    latency_ms          integer,
    outcome             text NOT NULL CONSTRAINT chk_model_calls_outcome CHECK (outcome IN ('completed', 'truncated', 'refused', 'error')),
    CONSTRAINT pk_model_calls PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE app.model_budgets (                     -- a cap that stops work
    tenant_id     uuid NOT NULL,
    period        date NOT NULL,                     -- first day of the month
    limit_micro   bigint NOT NULL CONSTRAINT chk_model_budgets_limit CHECK (limit_micro >= 0),
    spent_micro   bigint NOT NULL DEFAULT 0 CONSTRAINT chk_model_budgets_spent CHECK (spent_micro >= 0),
    CONSTRAINT pk_model_budgets PRIMARY KEY (tenant_id, period),
    CONSTRAINT chk_model_budgets_cap CHECK (spent_micro <= limit_micro)
);
```
- **Normalize token counts at the provider adapter.** Providers disagree on whether the input count includes cached tokens and on how many cache classes exist; the ledger's columns mean one thing each, whatever the provider.
- **Cost is a snapshot**: computed when the call is made, at the price then in force. Prices change, and last month's bill must not.
- **Reserve, then settle.** Before the call, reserve the worst case with a guarded statement: `UPDATE app.model_budgets SET spent_micro = spent_micro + $3 WHERE tenant_id = $1 AND period = $2 AND spent_micro + $3 <= limit_micro`. Zero rows means over budget: stop. After the call, in the transaction that writes the ledger row, give back what was not used. The counter is a deliberate duplicate of the ledger: its drift query is the ledger's sum for the period.
- A response cache keys on the tenant first, then the feature, the model and a hash of the prompt: a cache is a confidentiality decision before it is a saving.

## 11. Rows a model wrote

- **Model output passes the same constraints as any other write.** A CHECK on a closed set, a foreign key and a NOT NULL are the last validators between a plausible wrong value and the table.
- **A proposal is not a fact.** An extraction, a suggested category or a drafted reply lands in its own table or under a `proposed` status, with its producer and source, and becomes the record through a guarded transition a person or a rule makes. It never overwrites what a person entered.
- **No model call inside a transaction** (`references/integrity.md`): commit the intent, call, then commit the result.
