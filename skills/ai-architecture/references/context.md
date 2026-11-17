# AI Context

Decides what each model call sees and where knowledge and state live: retrieval, index authorization and lifecycle, the context budget, compaction, the session log and memory. Read when a feature retrieves, remembers or runs long sessions. Prompt-cache rules live in `production.md`; tenant partitioning and memory poisoning in `security.md`.

## Choose retrieval by corpus and caller

Decide per source. Knowledge goes in context, never in weights.

| Source | Default | Break when |
|---|---|---|
| Small, stable corpus | In context and cached, if it fits the working budget and a full-length eval shows no loss | it changes often, or quality drops at that length |
| A navigable source of truth (code, document trees, databases, APIs), read by an agent | Agentic search with deterministic tools; add a semantic index when the corpus is large or its vocabulary fuzzy | the answer is latency-critical and single-shot: precomputed retrieval wins |
| Input larger than the window | Programmatic access: load it as data in a sandbox, slice it with code, call sub-models on the slices, return aggregates | the model must read every part to judge |
| Large private knowledge base, fuzzy queries, citations | Hybrid keyword + embedding retrieval, structure-aware chunks, a reranker, k tuned on the retrieval eval | the eval shows one method alone holds quality |

Could the caller navigate the source of truth directly instead of a copy in an index? Direct navigation inherits the source's freshness and permissions. Climb to multi-step retrieval (decompose the query, retrieve until the evidence suffices) only when one-shot retrieval fails the eval; it costs turns and latency. Choose on your own queries, not on leaderboards.

## The index

- **Authorize inside the query.** Pick the index topology by the authorization model first and scale second. Permission and tenant filters are mandatory, derived from the caller's authenticated context and applied before ranking, as a pre-filter or a per-tenant partition. Post-filtering the top k starves recall when it runs and leaks data when it is skipped. *Break when* the corpus is public.
- **Every chunk carries** its source id, section, version, access scope and a trust label. Retrieved text is untrusted input and never carries authority.
- **Freshness** is the maximum delay before edits and permission revocations reach the index: a stated target with a guard. Index incrementally.
- **Deletion** tombstones at once and reaches every derived copy: chunks, embeddings, caches, summaries. The index is a derived store whose rebuild time is its recovery objective.
- **The embedder is an index-time commitment.** Queries and index use the same model and version; a change is a scheduled re-embedding migration, not a config flip. Select it on your own queries in every language you serve. The reranker follows the same rule.
- **Placement**: co-locate the index in a store you already run until a measured ceiling binds. Size it from chunk count × dimensions × bytes per value. Its physical form (tables, vector index, filtered and hybrid search) comes from the database-design capability, if available.

## Injecting context

- Fetch predictable needs up front; fetch the rest just in time through references and navigation tools.
- **Precision over recall**: irrelevant chunks degrade answers as length grows. Label each chunk with an id and require citations; citation coverage then doubles as a grounding check. When nothing relevant is found, say so and let the abstain path fire.
- Always-on context holds only what most calls need, each line traced to an observed failure; procedures and references load on demand behind a short index.

## Budget and compaction

- **Context is a budget with diminishing returns.** Set a working ceiling well below the advertised window, measured as quality against context length on your eval, and treat it as an SLO. *Break when* measured quality stays flat at length.
- **Relieve pressure in order**: keep junk out (cap and paginate tool output) → clear stale tool results by rule → push exploration into sub-agents that return condensed results → externalize state to artifacts → compact only when a named constraint binds.
- **Every compression is restorable.** Replace stale content with references the agent can re-fetch before dropping anything. Summarize against a fixed schema: the user's intent verbatim, constraints and open commitments, decisions, current state, next steps. Compact at task boundaries, never on a timer, and measure the net effect: aggressive compression loses information and breaks the prompt cache. Compaction or a clean reset with a handoff file: which works better is a property of the model, re-tested at each model change.
- **No constraint lives only in compactable context.** Governance rules sit in a region the compactor never rewrites and are re-injected after compaction; anything consequential is also enforced in code. Guard: an instruction-retention eval across forced compaction.

## Session log and memory

- **The session log is the source of truth**: a durable, append-only record of turns, tool calls and results that outlives the context window. Each call's context is a view compiled from it; resume, audit and eval replay read it. *Break when* the feature is a short request/response call.
- **Memory is governed state, not a transcript.** Decide which kinds the feature needs and store each on purpose:

| Kind | Holds | Typical store |
|---|---|---|
| Working | The current task's plan and scratch state | The run's checkpointed state |
| Episodic | What happened in past sessions | The session log, searched or summarized |
| Semantic | Durable facts: preferences, entities, commitments | Versioned records with provenance |
| Procedural | How to do recurring work | Instruction files under version control |

- **Every entry carries provenance** (source, session, trust level, time), a scope (shared stores read-only to the agent, user stores read-write, never across users) and a validity interval; each change makes a new immutable version, unverified entries expire, and rollback is by version. Can we tell which session wrote this memory, and undo it?
- **Write at task boundaries, consolidate offline.** A background job that merges, deduplicates and promotes entries across many sessions is a pipeline stage with its own eval, not an agent rewriting its own memory mid-task. The transcripts stay the ground truth that notes are rebuilt from, because a wrong note is otherwise carried into every later session. Recall relevant entries at run start; never load everything.
- **Memory written by a session that read untrusted content stays tainted** until reviewed.
- **Your database is the record; a model's memory is a scoped, expiring derivative of it.** Every memory store is a Data Inventory row with retention and an erasure path, and regulated data may rule out long-term memory.

## Red flags

- A permission filter applied after similarity search, or retrieval through a broad service account.
- Compaction on a timer, or a policy that exists only in compactable context.
- "The window is big enough", with no measured curve of quality against length.
- Memory written from untrusted sessions without provenance, or readable across users.
- An embedder swapped as a configuration change, or deletions that never reach the index.
