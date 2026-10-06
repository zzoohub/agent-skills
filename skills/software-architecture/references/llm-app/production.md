# Production Concerns

**Layer:** design-level (planning the operational posture — latency/cost budgets, caching strategy, rollout plan, incident readiness — *before* you ship). Concrete wiring lives in SDK and observability capabilities (e.g. the `claude-api` skill for Anthropic, if available; otherwise the provider's SDK docs and your LLM-observability platform); system-level deployment topology lives in `references/ai-architecture.md`.

Shipping an LLM feature is easy. Operating it is the hard part. This covers the layer between "the prompt works" and "it survives real traffic" — the concerns you decide at design time so the feature is operable, not the runtime mechanics of operating it.

## Table of Contents

1. [Latency](#latency)
2. [Cost](#cost)
3. [Caching](#caching)
4. [Reliability](#reliability)
5. [Observability](#observability)
6. [Security and privacy](#security-and-privacy)
7. [Rollout](#rollout)
8. [Model updates](#model-updates)
9. [When things go wrong](#when-things-go-wrong)

## Latency

LLM latency is dominated by two factors: time-to-first-token (TTFT) and time-per-output-token. You trade these against quality.

**Budget by feature shape:**

- User-facing chat: stream responses; TTFT matters more than total time. Target TTFT < 1s.
- Background batch: total time matters; TTFT is irrelevant. Batch endpoints (Anthropic Batch API, OpenAI Batch) are cheaper and higher throughput.
- In-product autocomplete / inline suggestions: needs sub-500ms. Usually means small model, short prompt, caching.

**Reducing latency:**

- **Shorter prompts.** Every cut token saves time and money.
- **Smaller model** where quality allows. Run evals on both; ship the smaller one if pass rate is acceptable.
- **Prompt caching.** Cache the stable system prompt; only send the dynamic per-request part. Anthropic, OpenAI, and others support this with different APIs.
- **Streaming.** Don't wait for full output to show the user something.
- **Parallel tool calls** when the model supports them (see `references/llm-app/tool-use.md`).
- **Provider proximity.** If you're in Europe and calling US-only endpoints, round-trip dominates.

## Cost

Cost = (input tokens × input rate) + (output tokens × output rate). Output is typically ~5-8x more expensive than input per token (5x on current Claude models, 5-8x across OpenAI's lineup, as of 2026-10 — check current pricing).

**Cost traps:**

- **Long system prompts × every call.** 4000-token system prompt × 1M calls/month × $3/MTok input = $12k/month. Same prompt with aggressive caching at a 0.1x cache-read rate (~90% off — the common rate on current Anthropic and OpenAI models as of 2026-10): ~$1.2k; the win grows or shrinks with each provider's and model's cache-read rate.
- **Verbose output.** Asking the model to "explain your reasoning" multiplies output tokens. Use it when it helps quality; skip when it doesn't.
- **Retries without caching.** A retry re-sends the full context. With caching, it's cheap. Without, the cost doubles.
- **Agent loops.** Each turn sends the full history. A 10-turn agent easily 10xs single-prompt cost.
- **Logging full traces at full prompts.** Infrastructure cost, not API cost — but adds up fast. Sample or truncate.

**Cost estimation before shipping:**

- Estimate expected traffic (requests/day).
- Estimate input + output tokens per request (with a worst-case multiplier).
- Calculate before, not after. "We'll optimize later" sometimes means "we'll get surprise invoices first."

## Caching

Different layers cache different things:

**Prompt caching (provider-level).** Cache stable parts of the prompt (system, few-shot examples, long context documents) so subsequent requests reuse them at a steep discount and lower latency. The exact savings are provider- and model-specific — as of 2026-10, cache reads typically bill at ~0.1x input (90% off) on current Anthropic and OpenAI models and as low as 0.025-0.05x on some newer ones; Anthropic caches via `cache_control` (one top-level field for automatic caching, or explicit per-block breakpoints, with a write premium), OpenAI caches eligible prompts automatically, others vary — so check current pricing rather than hard-coding a number. All require the prefix to match exactly: design prompts with a stable prefix and a variable suffix.

**Response caching (your infrastructure).** For deterministic or slow-changing queries, cache the final response by hash of input. Works for tasks like "summarize this URL" but useless for personalized or time-sensitive responses.

**Embedding caching.** Embeddings are deterministic per model+version. Cache aggressively; re-embedding is wasted money.

**Retrieval result caching.** For popular queries, cache the retrieved chunks. Beware cache staleness after index updates.

## Reliability

LLM APIs fail. Rates are low but non-zero. Design for it.

**Handle:**

- **Rate limits.** Provider-specific; implement exponential backoff with jitter. Consider queueing non-urgent requests.
- **Timeouts.** Set them. Default SDK timeouts are often too high (minutes). User-facing features should time out in 10-30s max — stream, or move longer generations to an async job; the per-call infrastructure ceilings (60-120s non-streaming, ~300s streaming) are in `references/ai-architecture.md` §2 and `references/operational-patterns.md`.
- **Invalid outputs.** Schema validation on structured output; retry with a feedback message if it fails ("Your previous response was not valid JSON. Please respond with valid JSON matching this schema: ...").
- **Model deprecations.** Providers deprecate models. Your prompt tuned for model X may behave differently on model Y. Pin model versions in code; upgrade deliberately.
- **Provider outages.** If the feature is critical, plan fallback — simpler model, cached response, or graceful degradation.

## Observability

LLM apps fail in ways that regular apps don't: hallucinations, quality drift, slow degradation after a prompt tweak. Logs alone won't catch these.

**Capture per request:**

- Inputs (prompt, retrieved context, tool calls).
- Outputs (response text, tool calls, token counts).
- Latency breakdown (embedding time, retrieval time, LLM time).
- Model ID + version.
- Cost.
- User/session identifier for correlation.
- Any user feedback (thumbs up/down, correction).

**Watch:**

- **Quality drift.** Sudden drop in user thumbs-up rate, or LLM-as-judge eval scores on sampled traces. Often caused by a prompt change or silent model update.
- **Cost spikes.** Runaway agents, unusually long inputs (user pasted a novel), or retries gone wild.
- **Latency regressions.** TTFT going up can signal provider load, new system prompt bloat, or a change in caching effectiveness.
- **Safety signals.** Jailbreak attempts, PII in outputs, scope violations.

For concrete wiring, use an LLM-observability capability or platform, if available (e.g. PostHog LLM analytics, Sentry AI monitoring, Langfuse — see the eval/observability row in `references/house-stack.md`). Most LLM observability platforms let you sample traces, replay them, and tag for eval.

## Security and privacy

LLM apps are vulnerable to attacks that don't exist elsewhere:

**Prompt injection.** Untrusted input (user message, scraped webpage, retrieved document) contains instructions that hijack the model. Hard to fully prevent. Mitigations:

- Separate untrusted data from instructions using clear delimiters.
- Tell the model which content is user-provided and shouldn't be followed as instructions.
- Never give the LLM enough authority to do serious damage on its own (see agent safety rails in `references/llm-app/agents.md`).

**Data leakage.** The model outputs training data, earlier conversations, or data from other users. Mitigations:

- Don't put secrets in prompts unless essential.
- Validate outputs for known-sensitive patterns (PII, credentials) before showing to users.
- Use dedicated/no-train endpoints from providers for anything regulated.

**Harmful output.** Model generates offensive, biased, or dangerous content. Mitigations:

- Content safety filters on inputs and outputs (provider-native or third-party).
- Clear refusal instructions in system prompt for scope violations.
- Human-in-the-loop for high-stakes outputs.

**Cost attacks.** Adversarial users send expensive-to-process requests. Mitigations:

- Rate limit per user.
- Input length caps.
- Cost budgets per user per day.

## Rollout

Ship LLM features like any risky change:

- **Feature flag + % rollout.** Start at 1-5%, monitor, increase.
- **A/B test if you can measure outcome.** Compare user engagement, task completion, or satisfaction between variants.
- **Shadow traffic before promotion.** Run the new prompt/model on production traffic without showing results to users; compare against the current version's outputs.
- **Keep the old version deployable.** Prompts are code. Version control them. Be able to roll back in minutes.

## Model updates

Providers update underlying models regularly. Even "same model name" may behave differently after an update. Defenses:

- Pin specific model versions in production, not "latest."
- Re-run evals on model changes. Treat model upgrades like dependency upgrades.
- Have a plan for forced upgrades (deprecations). Budget time to re-tune prompts.

## When things go wrong

Post-incident analysis for LLM incidents needs trace data. If you don't have traces, you have no post-mortem — just guessing. Re-read "Observability" above and make sure the logs exist before you need them.

Common incidents:

- Quality regression after prompt change → roll back prompt, add eval case, retune.
- Cost spike → find the request shape, add input caps or rate limits.
- Hallucination making it to users → validate outputs, add safety eval case, consider human-in-the-loop for the affected feature.
- Prompt injection exploit → sanitize input, improve prompt separation, consider tighter tool authorization.

None of these are unfixable. They are all much easier to fix with traces, evals, and rollback capability already in place.
