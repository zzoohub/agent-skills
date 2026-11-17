# AI Evals

Decides how you know an AI feature works and what blocks its release. Read when the feature is deep, and before any branch acts on a probability. Sample sizes below are practitioner starting points, not laws.

## Start from failures, not metrics

- **Day 0.** Success criteria and hand-written seed tasks with reference answers are the first eval set and the spec. Hard, objective constraints become code checks at once: schema validity, forbidden content, personal data, spend caps.
- **Cold start.** Build synthetic *inputs* from dimension tuples (feature × scenario × persona) and run them through the whole system; never generate the expected outputs. Replace them with real traces as soon as traffic exists.
- **Error analysis, first and recurring.** Read diverse traces (about 100 to start, the first few dozen by the quality owner in person), note the first upstream failure in each, group the notes into named categories with counts, and stop when new traces no longer change the taxonomy. Repeat after every significant change.
- **Fix the spec first.** For each category: did we ever ask for this behavior? If not, fix the prompt, tool description or product. Build an evaluator only for a failure that persists, or as a cheap regression guard on a critical requirement.
- **Dial rigor to risk.** Targets are set against the human baseline and the stakes, not against perfection.

## Evaluators: the cheapest that detects the failure

- **Order**: code assertions (schema, enums, execution tests, queries of the resulting state) → a decision model or model judge when detection needs interpretation → people for calibration and ambiguous cases.
- **Judge design.** One failure mode per judge, binary pass/fail against a definition from the taxonomy; gradation is more binary checks. A binary judgment over a closed answer is a decision-tier question (`models.md`), which is cheap enough to run on every trace instead of a sample. A generative judge writes its critique before its verdict and has an explicit "insufficient information" verdict.
- **Validate every judge as a classifier.** Hold out expert labels per failure mode with both classes well represented (100–200 to start). Report true-positive and true-negative rates, never raw agreement: where 85% of outputs pass, an always-pass judge scores 85%. Pin the judge's model version; it is part of the release unit. If human-rated quality falls while judge scores rise, investigate the judge.
- **Correct aggregate rates for judge error**: true pass rate = (observed + TNR − 1) / (TPR + TNR − 1). Invalid when the denominator is near zero.
- **Labels come from people or outcomes.** Agreement with a stronger model is imitation, not ground truth.

## The sets

| Set | Holds | Gate |
|---|---|---|
| **Golden** | Curated inputs with reference answers or pass conditions, labeled by people; small, stable, the working spec | Quality bound per category and slice |
| **Regression** | Every production failure that was fixed | Expected near 100%; runs on every change |
| **Red** | Adversarial cases: injection, abuse, authority and privacy violations, policy edges | Absolute: any failure in any run blocks |
| **Capability** | Deliberately hard tasks the feature cannot do yet | Reported, never gating |

A held-out split of each stays out of prompts and tuning data. Building and maintaining the sets and judges is ongoing practice (an AI-evals capability, if available); the design fixes which sets exist, what each gates, who owns them, and the terms under which production data may enter them.

## Suites

- **Slices.** Report and gate per failure category and per material slice (language, segment, channel, tenant, input source). An aggregate hides a failing slice.
- **Hill-climbing discipline.** Hold out a test split; change one root cause per round; never paste eval items into prompts.
- **Agents.** Grade the environment's end state plus the information the user needed, never the agent's own claim or the path it took. A do-nothing agent must fail, and some tasks must be ones where doing nothing or refusing is the right answer. Assert only mandated steps (approval before a write), not exact tool sequences; give partial credit as the share of binary criteria met. A success that took three times its budget is a failure shaped like a pass. Run each trial in a clean, isolated environment.
- **pass@k vs pass^k.** Any-of-k measures the capability ceiling; all-of-k measures the reliability floor, and production lives on the floor: 90% per run is 59% at five runs.
- **Workflows and graphs.** Evaluate each node by its type (a router by precision and recall, a writer by a purpose-built judge, a code generator by execution) and reproduce each failure with the smallest failing input, before grading the whole.
- **Retrieval.** Grade retrieval as search first (recall and precision at the k actually passed to the model), then generation by faithfulness to the retrieved context claim by claim. Include unanswerable questions, where passing means abstaining. A final-answer eval cannot tell which stage failed.
- **Long sessions.** State a constraint early, force compaction, then grade violations deterministically.
- **Simulated users** for multi-turn and voice: audit the simulator before blaming the agent.
- **Integrity.** An eval's identity includes its environment: CPU, memory and time limits, tool and network access. Pin them, because resource settings alone move scores by several points. Keep answer keys out of reach of tool-enabled agents.

## Release unit and gate

The **release unit** is everything that changes behavior: model snapshot, reasoning and decoding settings, prompts, the tool set with its schemas and descriptions, loaded instruction files, decision-model questions and criteria, retrieval index and embedder version, guardrail configuration, context policy, and the judges. A change to any member runs the gate, and every trace is stamped with the full unit.

The gate has three classes, each a one-sided confidence bound:

1. **Absolute invariants** (safety, authority, privacy, schema): any failure in any of k runs blocks.
2. **Quality**, per category and material slice against the recorded baseline, with a tolerance wider than the measured noise; gate on the worst material slice.
3. **Budgets**: cost per successful task and p95 latency, against the envelope.

**Statistics.** Measure the noise floor before optimizing: rerun the suite and grade identical outputs twice; a difference inside that band is noise. Gate on one-sided 95% bounds: for "fewer than 5% defects", 6 defects in 200 fails and 12 in 400 passes. Compare variants as paired differences on the same items.

**Promotion.** Shadow, then canary: the same three classes, measured on sampled production traces, are the promote and abort criteria, and the quality class becomes an SLI.

## Calibration gate

Before any branch acts, abstains or escalates on a probability or confidence, measure it on labeled examples from your own traffic: reliability by bucket, and how much traffic the threshold covers at the target precision, per slice. Fit the threshold on one split, confirm on a held-out one, re-check on a later time slice, and refit on every model, version or criteria change. *Break when* labels cannot be obtained: then nothing acts automatically on confidence; keep a person in the loop and collect labels from the reviews.

## Production loop

- **Guardrails vs evaluators.** Guardrails sit in the request path: fast, deterministic, block or allow. Evaluators score traces afterwards with validated judges, at whole-session level for agents.
- **Scheduled evals.** Run the gate against the unchanged production unit on a fixed schedule and on any provider notice. Check your own change log before blaming the provider.
- **The loop**: trace → sample → label → group into failure categories → fix the spec, context, tool or model → add the case → gate → ship → watch. It needs a trace store, a review queue and an owner, and those are components of the design.
- **Owner and cadence.** A named quality owner reviews outlier and random traces on a fixed cadence. Every triaged production failure becomes a permanent regression case. Which production failure from last week is now a test?
- **This is the outer loop** of `orchestration.md`: automation may cluster and propose, people decide, and the same agent never writes a rubric and scores with it.
- **Design for evaluability.** Stamp every trace with the release unit and carry it through to the business outcome; design feedback UX to yield labels on the dimension you measure.

## Before an external launch

One completed error-analysis cycle with its spec fixes; code assertions for every objective failure mode; every gating judge validated and pinned; the regression suite green; release bounds met above the noise floor; for agents, end-state grading, a failing null agent and all-of-k at the product's k; for retrieval, a recall baseline recorded apart from answer quality; a named owner. A light feature ships on the minimum gate in `SKILL.md`.

## Red flags

- A rubric written before anyone read traces, or generic scores (helpfulness, similarity) reported as quality.
- A judge validated by raw agreement, scoring several criteria at once, or running on a moving model alias.
- Agents graded on their own claims or on exact tool sequences.
- Release gates on point estimates, one trial per stochastic item, or "wins" inside the noise.
- A threshold acted on with no calibration check on your own labeled data.
