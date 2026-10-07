# AI Context

Decides what each model call sees and where knowledge and state live: the retrieval choice, index authorization and lifecycle, the context budget, compaction, the session log and memory. Read when a feature retrieves, remembers, or runs long sessions (`ai/protocol.md` step 4). Paths are relative to `references/`; prefix-cache rules live in `ai/production.md`; tenant partitioning of shared AI state and memory-poisoning controls live in `ai/security.md`.

## Choose retrieval by corpus and caller

Decide per source. Knowledge goes in context, never in weights (`ai/protocol.md` § Improving a feature).

| Source | Default | Break when |
|---|---|---|
| Small, stable corpus | In context and cached — only if it fits the working budget, a full-length eval shows no loss of recall or position sensitivity, and cost holds at volume | it changes often, or measured quality drops at that length |
| Navigable source of truth with structure (code, document trees, databases, APIs), read by an agent | Agentic search with deterministic tools; add a semantic index when the corpus is large or its vocabulary fuzzy | the answer is latency-critical and single-shot — precomputed retrieval wins |
| Input larger than the window | Programmatic access: load it as data, slice, recurse (code as the action layer, `ai/agentic.md`) | the model must read every part to judge |
| Large private knowledge base, fuzzy queries, citations, a latency budget | Hybrid keyword + embedding retrieval, chunk-level context, a reranker, and k tuned on the retrieval eval rather than fixed | the eval shows one method alone, or no rerank, holds quality |

Forcing question: could the caller navigate the source of truth directly instead of a copy in an index? Direct navigation inherits the source's freshness and permissions. Multi-hop questions over an index call for agentic retrieval — query decomposition, iterative retrieval until the evidence suffices, or model-written structured queries — climbed to only when one-shot retrieval fails the eval, since it costs turns and latency. Semantic search, clustering and deduplication stop at retrieval when no language must be generated. Choose on your own queries, not on leaderboards.

## Index: authorization, freshness, deletion

- **Authorize inside the query.** Choose the index topology by the authorization model first and scale second. Permission and tenant filters are not relevance filters: they are mandatory, derived from the caller's authenticated context, and applied inside the retrieval query — a pre-filter on access metadata, or a per-tenant partition or index — before ranking. Never rely on post-filtering the top k: it starves recall, and skipping it leaks other users' data. *Break when* the corpus is public or uniform-access.
- **Every chunk carries** its source id, section, version, tenant or access scope, and trust label. Retrieved text is untrusted input and never carries authority (`ai/security.md`).
- **Freshness** is the maximum delay before edits and permission revocations reach the index: a stated target with a guard. Index incrementally — re-chunking everything for every change does not survive churn.
- **Deletion.** Deletions tombstone at once and reach every derived copy — chunks, embeddings, caches, summaries — through the `design-flow.md` § Data Inventory & Lifecycle rows. The index is a derived store: its rebuild time and re-embedding cost are its recovery objective (Stage 6 RPO/RTO).
- **Placement** follows Stage 6 (storage by data characteristics): co-locate the index in a store you already run while it meets the access-filter, latency and scale needs; move to a dedicated index when a measured ceiling binds. Size it from chunk count (overlap included) × dimensions × bytes per value; a memory-resident graph index needs that much memory, or quantization, or a disk-based index.

## Chunking and the embedder

- **Chunk by structure** per document type, prepend context (a breadcrumb or short summary) to each chunk, and tune size and overlap on the retrieval eval.
- **The embedder is an index-time commitment.** Queries and index use the same model and version; a change is a scheduled re-embed migration, not a config flip. Select it on your own golden queries — leaderboard rank ≠ rank on your corpus and query style — and check language coverage with goldens in every language you serve. Its max input must be at least the chunk size, or chunks are truncated (silently, on some embedders) or rejected; dimensions are a storage lever. The reranker follows the same rules.

## Injecting context

- Fetch predictable needs up front; fetch the rest just in time through references (ids, paths, queries) and navigation tools.
- Prefer precision over recall in what you inject: irrelevant chunks are distractors that degrade answers as length grows. Put the most relevant evidence first or last, label each chunk with an id and require citations — citation coverage then doubles as a grounding check — and when nothing relevant is found, say so and let the abstain path fire.
- Always-on context (system prompt, project instructions) holds only what most calls need, each line traced to an observed failure; procedures and references load on demand behind a short index. *Break when* a rule most calls hit cannot be discovered on demand — it stays always-on and, if consequential, is also enforced in code.

## Context budget and compaction

- **Context is a budget with diminishing returns.** Set a working ceiling well below the advertised window, measured per model as quality against context length on your eval, and treat it as an SLO: the p95 call fits with headroom. *Break when* measured quality stays flat at long lengths — then spend the tokens.
- **Relieve pressure in order:** (1) keep junk out — cap and paginate tool output, use concise formats; (2) clear stale tool results by rule; (3) push exploration into sub-agents that return condensed results (`ai/agentic.md`); (4) externalize state to artifacts; (5) compact only when a named constraint binds — the window, the price, or measured quality loss.
- **Every compression must be restorable.** First replace stale content with references the agent can re-fetch; drop content only when such a pointer remains, and keep failed actions as evidence. Only then summarize, against a fixed schema: the user's intent verbatim, constraints and open commitments, decisions, current state, next steps — with the trail of created and modified artifacts kept outside the summary. Compact at task or idle boundaries, keeping recent turns verbatim. *Break when* the source is mutable or ephemeral — snapshot it first; very long autonomous runs may do better with a clean reset and a structured handoff (`ai/agentic.md`).
- Compaction and history never rewrite the cached prefix: history is append-only, and one cache miss per deliberate compaction is the price (`ai/production.md`).

## Governance decay

No constraint lives only in compactable context. Pin governance constraints in a region the compactor never rewrites and re-inject them after compaction; summaries carry constraints and open commitments; anything consequential is also enforced outside the model (`ai/security.md`). Gate: an instruction-retention eval across forced compaction, including adversarial content aimed at the summarizer (`ai/evals.md`). *Break when* the rule is a soft stylistic preference — some decay is tolerable; rules enforced in code are immune.

## Session log and memory

- **The session log is the source of truth.** A durable, append-only event log of turns, tool calls and results outlives the context window; each call's context is a view compiled from it, and resume, audit and eval replay read it (loop, executor and log separation → `ai/agentic.md`). *Break when* the feature is a local single-user tool or a short request/response call — the extra infrastructure isn't justified.
- **Memory is governed state, not a transcript.** Persist durable facts — preferences, entities, commitments, decisions — as versioned, attributable, exportable records with explicit scopes: organization read-only, user read-write, never across users, and no personal memory in multi-user contexts. Each entry carries provenance (source, session, trust level, time) and a validity interval; unverified entries expire, and rollback is versioned. Write at task boundaries or on explicit signals, consolidate offline, and update by incremental deltas, never by rewriting the whole store; recall relevant entries at run start rather than loading everything. Memory written by a session that read untrusted content stays tainted until reviewed (`ai/security.md`). Every memory store is a Data Inventory row with retention and an erasure path. Forcing question: can we tell which session wrote this memory, and roll it back? *Break when* the memory is simple preferences for a single-user assistant — no consolidation needed; regulated data may rule out long-term memory entirely.

## Red flags

- A permission filter applied after similarity search, or retrieval through a broad service account.
- Compaction on a timer ("summarize every N turns"), or context rewritten mid-session.
- A policy that exists only in compactable context — "the prompt says never do X" as the only control for X.
- "The window is big enough," with no measured curve of quality against context length for this model.
- Memory written from untrusted sessions without provenance, or readable across users.
- An embedder swapped as a configuration change, or deletions that never reach the index.
