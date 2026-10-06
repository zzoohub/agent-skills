# LLM Application Design — AI Feature Mode Guide

Provider-neutral LLM application design: prompt engineering, tool use, RAG, agent patterns, evaluation, and production concerns. This is the method behind the skill's **AI Feature Mode** (see `SKILL.md` § AI Feature Mode for when it runs, what it writes, and the output-doc template).

A design and operational-planning guide, not a coding guide. It helps you decide **what to build, how to structure it, how to know if it works, and how to operate it** — everything before and around the SDK, but not the SDK calls themselves.

## The first question: do you need an LLM?

LLMs are the right tool when the problem has:

- **Open-ended language** — input or output is free-form prose, where hand-coded rules would miss cases.
- **Fuzzy matching or synthesis** — combining or summarizing information that isn't cleanly structured.
- **Novel inputs** — the full input space can't be enumerated, so pattern recognition beats exhaustive rules.

They are the wrong tool when:

- A regex, SQL query, or deterministic function would produce the same answer faster and cheaper.
- Correctness is safety-critical and the model's confidence can't be verified (payments, medical dosing, legal filings without review).
- The output is a simple classification with sufficient training data — a small classifier is usually faster, cheaper, and more reliable.

If you can solve 80% of the task deterministically and only use the LLM for the residual 20%, that's almost always the right architecture. Pre-filter with code, let the model handle the ambiguous cases, post-validate the output.

## The four layers of any LLM app

Every LLM feature decomposes into the same four layers. Design them explicitly — skipping any of them is how systems ship and then degrade silently.

1. **Context layer** — what the model sees: system prompt, user input, retrieved documents, tool results, conversation history. The job here is relevance and cost: get the right tokens in, keep irrelevant tokens out.
2. **Reasoning layer** — how the model thinks: single-shot vs multi-step, chain-of-thought, tool-calling loops, agent planning. The job is matching the task's shape to the model's strengths.
3. **Output layer** — what comes back: free text, structured JSON, tool calls, streaming. The job is making the output usable by downstream code without a second guessing step.
4. **Evaluation layer** — how you know it works: golden examples, LLM-as-judge, A/B tests, production monitoring. The job is catching regressions before users do.

These layers map onto the references: the **Context** and **Output** layers are designed in `references/llm-app/prompting.md` (fed by `references/llm-app/rag.md` and `references/llm-app/tool-use.md` when retrieval or tools supply the context); the **Reasoning** layer is the shape table below plus `references/llm-app/agents.md`; the **Evaluation** layer is `references/llm-app/evaluation.md`; and `references/llm-app/production.md` wraps all four with the operational concerns that decide whether the design survives real traffic.

Most "my LLM app is flaky" problems trace back to a missing or vague layer. If you can't answer "what's in the context, how does it reason, what's the output contract, and how do I measure quality?" in one sentence each, the design isn't ready to implement.

## Picking the shape

Pick the simplest shape that solves the task. Upgrading to a more complex shape is cheap; downgrading from one is a rewrite.

| Task shape | Right architecture | When to upgrade |
|---|---|---|
| Classify, extract, rewrite, summarize | Single prompt, structured output | Never — if this works, stop |
| Answer from a knowledge base | RAG: retrieve → augment → generate | Multi-hop questions need agent retrieval |
| Call external systems (search, DB, API) | Tool use / function calling | Multi-tool planning needs an agent loop |
| Several LLM steps in a *known, fixed* order | Workflow / pipeline: chain, route, parallelize, evaluator-optimize | When steps can't be predetermined → agent |
| Multi-step reasoning where the *model* picks the steps | Agent: plan → act → observe → repeat | Most tasks don't actually need this |
| Multiple specialized roles collaborating | Multi-agent / orchestrator-worker | Only when one agent demonstrably can't do it |

Read `references/llm-app/prompting.md` before designing any shape — prompt structure underlies all of them. Then jump to the shape-specific reference:

- `references/llm-app/tool-use.md` — tool/function-calling design
- `references/llm-app/rag.md` — retrieval architecture, chunking, hybrid search, re-ranking
- `references/llm-app/agents.md` — the workflow-vs-agent decision, agent loops, planning, safety rails
- `references/llm-app/evaluation.md` — eval strategies for all shapes
- `references/llm-app/production.md` — latency, cost, caching, rate limits, observability

**Workflow vs agent — the line that matters most.** A *workflow* (a.k.a. agentic pipeline) runs LLM calls through steps *you* fixed in advance: prompt chaining, routing, parallelization, evaluator-optimizer loops. An *agent* lets the *model* choose the next step at runtime. If you can draw the flowchart before running, build the workflow — it's cheaper, faster, and far easier to debug. Reach for an agent only when the steps genuinely can't be predetermined. See `references/llm-app/agents.md` for both pattern sets and the decision rule.

**Prompt vs RAG vs fine-tune.** Reach for prompting first; add RAG when the model lacks the facts (table above); fine-tune only when prompting and RAG both fall short on a stable, high-volume task — it trades flexibility and iteration speed for lower per-call cost and tighter style control. For the full cost/maintenance decision matrix, see `references/ai-architecture.md` §8.

**Not every "AI" task needs generation.** Semantic search, clustering, dedup, and some classification are embedding problems, not generation problems — an embedding model + vector index (or a small classifier) is often cheaper, faster, and more reliable than an LLM call. Use the embedding/hybrid-search primitives in `references/llm-app/rag.md` for the retrieval mechanics; reserve a generation call for when you actually need synthesized language out.

**System-level AI architecture lives in the sibling references.** LLM gateways, streaming and deployment topology, vector-store and infrastructure choice, multi-agent orchestration infrastructure, protocols (MCP/A2A/AG-UI), durable execution, and model lifecycle are covered at system altitude in `references/ai-architecture.md` and `references/ai-agents.md`. This guide is the design-discipline layer that runs alongside and after them.

## The design flow

Follow this sequence when designing a new LLM feature. Skipping steps is a false economy — each one takes minutes and saves hours of rework.

**Inputs first**: if architecture docs exist (default `docs/arch/`; caller may redirect), read the AI ASR answers in `context.md` §3 — cost ceiling, hallucination tolerance, streaming, agent capability. They are design constraints, not suggestions: the failure path (step 5) consumes hallucination tolerance; the production envelope (step 8) consumes the cost ceiling. If no architecture docs exist, ask the caller for the two numbers that gate everything: the cost ceiling and the tolerated error rate.

**1. Name the task in one sentence.**
"Given X, produce Y, so that Z." If you can't, the task isn't defined well enough to prompt. Example: "Given a customer support ticket, produce a category label and confidence, so that we route high-confidence tickets automatically."

**2. Write 5–10 input/output examples by hand.**
This is your first eval set. If you can't write them, the task is underspecified. If writing them is tedious but possible, congratulations — the LLM is probably the right tool. If writing them feels ambiguous (you'd label things differently on different days), that ambiguity will show up in the model's output too — spec the edge cases first.

**3. Decide the output contract.**
Structured (JSON schema, regex-parseable) or free-form? Structured outputs cost more tokens but cut the downstream validation burden. For anything a program will consume, use structured. For anything a human will read, free-form is fine.

**4. Pick the shape (table above).** Start with the simplest. Don't add an agent because it feels modern — add one when a simpler shape demonstrably fails your eval set.

**5. Design the failure path.** The model will be wrong, unsure, or down — decide each before writing the prompt:
- **Wrong** — what catches it: schema validation, citation checks, judge-sampled traces, human review. Calibrate the depth to the hallucination-tolerance ASR (a brainstorming feature tolerates much; an invoice extractor doesn't).
- **Unsure** — design the confidence boundary: below threshold → abstain ("I can't determine this from the available information") or escalate to a human queue. A feature without an abstain path converts uncertainty into confident error.
- **Down** — degrade, don't break: fallback model, cached response, or feature-off state (see `references/llm-app/production.md` § Reliability).

**6. Write the system prompt.** Role, task, constraints, output format, examples. See `references/llm-app/prompting.md`.

**7. Run your hand-written examples — and pick the model by proving down.** Prototype on a frontier model to establish that the task is possible at all: if the strongest model can't pass your examples, redesign the task instead of shopping models. Once it passes, walk down tiers and ship the cheapest model that still passes the eval set. If it fails, read `references/llm-app/evaluation.md` for how to diagnose.

**8. Plan production concerns — with arithmetic.** Compute the envelope, don't estimate it by adjective: (system + examples + retrieved + history + output) tokens/request → check it fits the context window with headroom; × requests/day × provider rate → $/month, compared against the cost ceiling; name the latency target (TTFT < 1s for streamed chat, < 500ms for inline suggestions — `references/llm-app/production.md`). Then caching strategy, rate limiting, error handling, observability. A feature whose envelope was never computed ships as a surprise invoice.

## Anti-patterns to avoid

**Prompt stuffing.** Cramming every edge case into the system prompt as a bullet list. LLMs weight long prompts unevenly — the 47th "always do X" gets ignored. Use structure (sections, examples, clear roles) instead of volume.

**No evals.** Iterating on prompts by vibes. Without a fixed eval set, every "fix" can silently break a previous case. You cannot ship an LLM feature responsibly without one — even 10 hand-written examples beat zero.

**Over-agentifying.** Wrapping a single-prompt task in an agent loop because agents are trendy. Agents are multiplicatively more expensive, slower, and harder to debug. Use them only when the task genuinely requires tool-use planning the model has to figure out at runtime.

**Trusting structured output without validation.** Even with JSON mode or schema-constrained decoding, models occasionally drift. Validate every structured output and define recovery (retry, fallback, escalate) before shipping.

**Logging nothing.** LLM apps generate latent failure modes: hallucinations, drift after a model update, quality regression from a prompt tweak. Without traces, you find out from users. Wire observability from day one — it costs almost nothing and saves everything.

**Mixing design and implementation.** Deciding "we'll figure out the prompt while we code" leads to prompts shaped like the first thing that compiled. Design the prompt, the output contract, and the eval set *before* opening the SDK.

The system-altitude counterparts (RAG everything, agent when a pipeline will do, ignoring LLM costs, premature fine-tuning) are in `references/ai-architecture.md` § Anti-Patterns.

This mode's job ends where the implementation SDK begins.

---

## Output

Write the feature design to the AI feature doc (default `docs/arch/ai-features/{feature}.md`; caller may redirect) using the section template in `SKILL.md` § AI Feature Mode — one file per feature, ≤200 lines.
