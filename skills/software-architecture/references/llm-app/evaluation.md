# Evaluation

**Layer:** design-level (eval strategy, golden sets, LLM-as-judge design, what to measure). For AI **testing/eval architecture** (CI integration, evaluation-driven-development pipelines, A/B infrastructure), see `references/ai-architecture.md` §7.

You cannot ship an LLM feature responsibly without evals. Prompts look fine on three test cases and fail on the fourth. Model updates silently change behavior. A "small" prompt tweak breaks 20% of cases you didn't think to check. Evals catch all of this.

## Table of Contents

1. [What an eval is](#what-an-eval-is)
2. [Types of evals](#types-of-evals)
3. [LLM-as-judge: getting it right](#llm-as-judge-getting-it-right)
4. [Agent evals: score the path, not just the destination](#agent-evals-score-the-path-not-just-the-destination)
5. [Anti-patterns](#anti-patterns)
6. [The eval workflow](#the-eval-workflow)
7. [Structuring the eval set](#structuring-the-eval-set)
8. [Eval infrastructure](#eval-infrastructure)
9. [When to stop iterating](#when-to-stop-iterating)

## What an eval is

An eval is a triple: `(input, expected_behavior, metric)`. You run the system on the input, observe behavior, compare to expected, produce a score.

The minimum viable eval:

- **Golden examples:** ~10-50 hand-labeled (input, ideal output) pairs covering the common cases and known edges.
- **A metric:** how you compare the actual output to the expected one. Exact match, substring match, JSON schema match, LLM-as-judge, etc.
- **A runner:** a script that runs all examples and reports per-example + aggregate results.

That's it. Build this before optimizing prompts, before shipping, before anything else. It's almost always less work than the first debugging session you avoid. The prompt-iteration loop that consumes this eval set lives in `references/llm-app/prompting.md` § Iteration loop.

## Types of evals

**Exact/structural match.** For classification, extraction, or structured output where there's one correct answer. Easy to implement, high signal.

**Reference-based metrics.** BLEU, ROUGE, semantic similarity. Decent for summarization and translation; often noisy for open-ended generation.

**LLM-as-judge.** Use a (usually stronger, separate) model to score outputs. Works for free-form outputs where there's no single correct answer. Surprisingly reliable when the judge prompt is well-designed — surprisingly unreliable when it isn't.

**Behavioral / invariant tests.** "For any input matching pattern X, the output must satisfy property Y." Good for safety properties (no PII leaks, no offensive content, always valid JSON).

**Production traces as evals.** Sample real production traces, have humans label them, add to the eval set. The single best way to make evals representative.

**Online measurement.** Offline pass rates don't guarantee business outcomes — A/B tests and drift monitoring close that gap. The design-side rollout discipline (shadow traffic, % rollout, judge-sampled production traces) lives in `references/llm-app/production.md` § Rollout / § Observability.

## LLM-as-judge: getting it right

Judge prompts are themselves prompts, subject to all the same failure modes. Rules:

- **Binary or small ordinal scale, not 1-10.** Judges are unreliable at fine-grained scoring. Pass/fail or 1-3 is more consistent.
- **Give the judge the criteria, not freedom.** "Score this output" is worse than "Score this output on (a) factual accuracy, (b) citation of sources, (c) format compliance. Each criterion is pass/fail."
- **Include reasoning.** Have the judge explain its score before giving it. This catches both model errors and criteria errors.
- **Calibrate.** Score a hand-labeled subset yourself; compare to the judge. If agreement is <80%, the judge prompt isn't good enough to trust.
- **Use a stronger or different model** as judge than the one being evaluated. Same model judging itself has self-bias.

## Agent evals: score the path, not just the destination

Single-shot metrics under-measure agents. The design-level metric set (system-level trace capture is `references/ai-agents.md` §7):

- **Task success rate** — did the agent achieve the goal, judged against each scenario's explicit success criteria.
- **pass@k vs pass^k** — run each scenario k times (k = 3-5; agents are nondeterministic). pass@k (*any* of k trials succeeds) measures the capability **ceiling**; **pass^k** (*all* k trials succeed) measures the reliability **floor**. Production cares about pass^k: an agent that succeeds 90% per run is a 59% agent at pass^5.
- **Step efficiency** — steps, tokens, and cost versus a reference path. A success that took 15 steps and $2 is a failure shaped like a pass.
- **Trajectory eval** — judge the path itself: right tool choices, valid arguments, error recovery, no scope violations. Catches accidental successes that final-output eval scores as clean passes.

## Anti-patterns

**Shipping without evals.** "The prompt works fine on my test case." One test case is not an eval. The test case you ran a week ago that "seemed fine" is not an eval.

**Eval drift.** The eval set grew organically from whatever the latest bug was. It no longer represents production. Refresh periodically; sample from real traffic.

**Optimizing to the eval.** Your prompt passes the eval set but fails in production. The eval has become the goal instead of a proxy. Add held-out examples; keep part of the eval set unused during prompt iteration.

**Judge without calibration.** Using LLM-as-judge without ever checking whether the judge agrees with you. Judges have quirks (over-praising, style preferences, length bias). Spot-check.

**Only final-output eval for agents.** An agent succeeded, but took 15 steps and $2 in tokens. Final-output eval says "pass." Trajectory eval would have caught the problem. For agents, score the path, not just the destination.

**No regression set.** Fixed bugs that don't become permanent eval cases. The same bug ships again six months later.

## The eval workflow

**1. Start small (10 examples).** Write them by hand, representing the common cases and 2-3 known edges. Run them before every prompt change. **Cold start, nothing to hand-write yet?** Bootstrap the set: have an LLM generate synthetic inputs to seed coverage, paraphrase-augment the few real examples you do have, then swap synthetic cases out for real production traces as soon as traffic exists (step 3). Synthetic data seeds the set; real traffic makes it representative.

**2. Diagnose before scaling.** The first time an example fails, understand why. Prompt issue? Example mislabeled? Task genuinely too hard? Fixing the wrong thing wastes the rest of the session.

**3. Grow the set continuously.** Every production bug → new eval example. Every customer complaint → new eval example. Every edge case you discussed in a design review → new eval example.

**4. Automate — as a gate, not a script.** Run in CI on every change to a prompt, model version, retrieval config, or tool schema — and **block merge on regression**: a previously-passing example failing, or a per-category pass rate dropping below the recorded baseline. Stamp each run with the prompt hash + model version + retrieval config that produced it, so every score is traceable to what generated it. Manual eval processes decay quickly; ungated automated ones decay almost as fast. (CI wiring and the EDD pipeline are the system half — `references/ai-architecture.md` §7.)

**5. Track per-example history.** Which examples pass across model or prompt changes? Which are flaky? A dashboard showing "pass rate by example over time" tells you more than a single aggregate score.

## Structuring the eval set

Organize by category, not by chronology:

- **Happy path** (60-70%): the common, straightforward cases.
- **Edge cases** (20-30%): known tricky inputs, ambiguous phrasings, boundary conditions.
- **Adversarial** (5-10%): prompt injection attempts, jailbreaks, scope violations. Ship with these if your model faces untrusted input.
- **Regression** (grows over time): one example per past bug fix.

Aggregate pass rate over all categories hides important signal. Report pass rate per category.

## Eval infrastructure

Keep it simple. A directory of YAML or JSON files, a script that runs them, a markdown report. Complexity you don't need:

- Full eval frameworks with DSLs.
- Complex statistical significance testing on 30-example evals.
- Custom web UIs before you have more than a few hundred examples.

Complexity you do need (as you grow):

- Version control for the eval set.
- Reproducibility (same input → same result, modulo model variance).
- Per-example history across runs.
- Export/import between local and CI.

For LLM-as-judge evals in production, consider tools that automate the judging loop at scale — an LLM-analytics platform for trace capture and scoring (e.g. PostHog LLM analytics), or a dedicated eval platform (e.g. Langfuse, Braintrust).

## When to stop iterating

You stop when:

- Pass rate on held-out examples plateaus.
- Remaining failures are ambiguous cases where humans would disagree too.
- The cost of the next improvement exceeds the benefit of fixing the remaining failures.

"100% pass rate" is usually a signal you've overfit to the eval set, not that the model is perfect.
