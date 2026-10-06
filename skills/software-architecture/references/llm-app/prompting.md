# Prompt Design

Prompts are programs written in natural language. Like code, they have structure, reusable patterns, and failure modes. Treat them that way.

## Table of Contents

1. [Structure over volume](#structure-over-volume)
2. [Role priming](#role-priming)
3. [Specifying output](#specifying-output)
4. [Few-shot examples](#few-shot-examples)
5. [Chain-of-thought (CoT)](#chain-of-thought-cot)
6. [System prompt vs user prompt](#system-prompt-vs-user-prompt)
7. [Extended / "thinking" modes](#extended--thinking-modes)
8. [Anti-patterns](#anti-patterns)
9. [Iteration loop](#iteration-loop)

## Structure over volume

A 100-line unstructured prompt performs worse than a 40-line structured one. The model's attention is a finite resource — waste it on filler and the important parts get ignored.

**Canonical system prompt structure:**

```
# Role
One sentence: who the model is and what it's for.

# Task
One sentence: what to do with each input.

# Constraints
- Hard rules: what must / must not happen
- Ambiguity resolution: what to do when input is unclear
- Scope: what's out of scope (and what to do when asked)

# Output format
Exact schema or template. Show it, don't describe it.

# Examples
2-5 input → output pairs covering the common shape and 1-2 edge cases.
```

Every section earns its place. If you find yourself writing a section without content, delete the header.

## Role priming

The first line shapes everything. "You are a helpful assistant" primes the model toward default behavior — usually too cautious, too verbose, too hedgy. Specificity wins:

- Bad: "You are an AI assistant that helps with code."
- Better: "You are a staff-level code reviewer. Your job is to find bugs that tests miss — race conditions, boundary errors, trust violations. You are blunt and technical."

The role isn't flavor — it sets the conversational register, the level of hedging, the vocabulary, and the default behaviors for ambiguous cases.

## Specifying output

Three failure modes in output design:

**Under-specified.** "Return the result as JSON." The model picks the shape. The shape varies between calls. Downstream code breaks.

**Over-specified in prose.** Three paragraphs describing the JSON schema. The model misreads and invents fields. Downstream code breaks differently.

**Specified by example.** Show the exact JSON structure once, with realistic values. The model matches the pattern.

```
# Output format
Return exactly this JSON structure:

{
  "category": "billing" | "technical" | "general",
  "confidence": 0.0-1.0,
  "reasoning": "one sentence"
}
```

Use schema-constrained decoding or JSON mode when the provider supports it, and always validate the parsed output against a schema (Zod, Pydantic, etc.) before using it — constrained decoding guarantees shape, not correctness. See `references/llm-app/tool-use.md` § Tool use vs structured output for why, and for the provider mechanisms.

## Few-shot examples

Examples are the highest-leverage part of a prompt. They do what no amount of rule-writing can: they show the model the exact shape of "good."

**Rules for examples:**

- **Cover the common case first, then edges.** The first example anchors the model's understanding. Make it the canonical shape.
- **Include at least one hard case.** Show how to handle ambiguity, missing info, or a tempting-but-wrong answer.
- **Match production distribution.** If 80% of inputs are short, don't make all examples long.
- **Show, don't narrate.** Put the reasoning inline in the example output, not in meta-commentary around it.

Examples are expensive in tokens. If your prompt has >5 examples, ask whether a fine-tune or a different model would be cheaper at volume.

## Chain-of-thought (CoT)

For tasks that require reasoning (math, logic, multi-step analysis), asking the model to "think step by step" before answering measurably improves accuracy on most benchmarks. But CoT isn't free:

- It increases output length, latency, and cost.
- It can leak verbose reasoning into structured outputs unless the schema has a dedicated field.
- For simple tasks, it adds noise without gain.

**When to use CoT:**

- Multi-step reasoning, math, logic puzzles.
- Classification where borderline cases exist and the reasoning aids accuracy.
- Any time you'll want to debug why the model answered a certain way.

**When to skip:**

- Classification with clear categories.
- Extraction where the answer is a copy from the input.
- Any case where users wait on output and reasoning adds latency without quality gain.

If using CoT with structured output, give the reasoning its own field:

```json
{
  "reasoning": "step-by-step thought process here",
  "answer": "the final answer"
}
```

This keeps reasoning available for debugging without polluting the machine-readable answer.

## System prompt vs user prompt

A common confusion: what goes where?

**System prompt** — stable across turns: role, task definition, constraints, output format, examples. Cache this aggressively (provider-specific; Anthropic supports prompt caching, others vary).

**User prompt** — per-turn input: the actual data to process, the user's current question, retrieved documents for this query.

The boundary matters for caching. A system prompt that stays identical across 1M calls caches well. Mix user-specific data in and the cache never hits.

## Extended / "thinking" modes

Some providers (Anthropic, OpenAI, Google) offer extended reasoning modes where the model thinks internally before responding. Rules of thumb:

- For hard reasoning tasks, extended thinking beats manual CoT — the model can think longer internally without inflating the final answer.
- For easy tasks, it's wasted tokens.
- Exposure varies by provider and model, and none return the raw chain of thought: Claude returns a *summary* of its reasoning in thinking blocks (on recent models the summary is omitted unless you opt in), and OpenAI reasoning models surface a summary or nothing. Where a summary is exposed, it's a useful debugging artifact; either way, thinking tokens are billed as output — treat hidden reasoning as latency and cost you can't inspect. Whether thinking is cached also varies — check the provider docs rather than assuming it's free or discarded.

## Anti-patterns

**Verbose hedging instructions.** "Please make sure to always be careful about..." These primarily slow the model down and cost tokens without changing behavior. Use structure or constraints, not politeness.

**Contradictory rules.** "Be concise. Include lots of detail. Don't make assumptions. Fill in reasonable defaults." The model will pick one, and which one varies. Resolve contradictions in the prompt, not at runtime.

**Negative-only instructions.** "Don't output markdown. Don't use lists. Don't be verbose." Models are trained to do things, not avoid things. Replace with positive: "Output plain text, one paragraph, under 100 words."

**Instruction at the end, data in the middle.** Models weight recent tokens heavily. If the instruction is at the top and the input is long, the model may drift. For long inputs, restate the task after the data, or keep the data short.

**Leaking context markers.** Sending `<user>`, `<system>`, or `[INST]` in the content (e.g., from a scraped webpage) can confuse the model. Sanitize or escape special tokens from untrusted input.

## Iteration loop

1. Write the prompt.
2. Run against your 5-10 hand-written examples.
3. For each failure, classify: prompt problem (clarify), example problem (the hand-written answer is wrong or ambiguous), or model problem (task is too hard for this model — try a bigger one).
4. Fix the prompt or examples. Keep old versions — prompt regression is real.
5. Expand eval set as the prompt stabilizes.

This loop assumes you have an eval set and a runner to execute it against — `references/llm-app/evaluation.md` covers how to build, grow, and automate one. Never iterate on prompts by running one example, making a change, and shipping. You'll fix the one case and break three others.
