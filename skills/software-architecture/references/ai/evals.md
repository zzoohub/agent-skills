# AI Evals

Decides how you know an AI feature works and what blocks its release. Read when the AI perspective is deep (`ai/protocol.md` step 7) and before any branch acts on a probability. Paths are relative to `references/`.

## Start from failures, not metrics

- **Day 0.** Write success criteria and hand-written seed tasks with reference answers — the first eval set and the spec (`ai/protocol.md` step 1). Turn hard, objective constraints into code checks at once: schema validity, forbidden content, personal data, spend caps.
- **Cold start.** Seed coverage with synthetic *inputs* built from dimension tuples (feature × scenario × persona) and run them through the whole system; never generate the expected outputs. Replace synthetic cases with real traces as soon as traffic exists.
- **Error analysis, first and recurring.** Read diverse traces (practitioner starting point: about 100, the first few dozen read by the quality owner personally); note the first upstream failure in each; group the notes into named failure categories with counts; stop when new traces no longer change the taxonomy. Repeat after every significant change.
- **Fix the spec first.** For each category ask: did we ever ask for this behavior? If not, fix the prompt, tool description or product design. Build an evaluator only for a failure that persists after the fix, or as a cheap regression guard on a critical requirement — and only once the failure is shown to occur. *Break when* a constraint is known and objective: check it in code from day one.
- **Dial rigor to risk.** Raise the bar for external, free-form, regulated or high-stakes outputs; a lighter process fits tasks the providers' own training already covers well, or that experts use daily. Set targets against the human baseline and the risk, not against perfection.

## Evaluators: the cheapest that detects the failure

- **Order:** code assertions (parse and schema checks, enums, execution tests, queries of the resulting state) → a model judge only when detection needs interpretation → people for calibration and ambiguous cases.
- **Judge design.** One failure mode per judge, binary pass/fail against definitions taken from the taxonomy; express gradation as more binary checks. Give it criteria, not freedom; it writes its critique before its verdict, has an explicit "insufficient information" verdict reported as its own rate, sees only the trace slice its failure mode needs, and takes few-shot examples only from the training split. Judge subjective comparisons pairwise and blind, in both orders, counting order flips as ties.
- **Judge family.** Use a different model family when the eval chooses among models; the same family is acceptable when the application's model is fixed and the judge is validated.
- **Validate every judge as a classifier.** Hold out expert labels per failure mode with both classes well represented (practitioner starting point: 100–200 labels); iterate on a dev split and run the test split once. Report true-positive and true-negative rates (TPR, TNR) or a chance-corrected statistic — never raw agreement. Raw agreement flatters a lenient judge: on a set where 85% of outputs pass, an always-pass judge scores 85%. Pin the judge's snapshot and version its prompt — the judge is part of the release unit — and re-validate on any change. If human-rated quality falls while judge scores rise, investigate the judge.
- **Correct aggregate rates for judge error.** With pass as the positive class, true pass rate θ = (p_obs + TNR − 1) / (TPR + TNR − 1); its interval covers both the labeled set and the traffic sample. Invalid when TPR + TNR − 1 ≈ 0 or when labeled failures were deliberately enriched.
- **Labels come from people or outcomes.** Agreement with a stronger model is imitation, not ground truth: base at least the decision-critical and adversarial slices on human or outcome labels. *Break when* the goal is explicitly distillation, or human labels are shown noisier than the model on this task.

## Suites and what they grade

- **Regression vs capability.** The regression suite holds every fixed failure as a permanent case, is expected near 100% and runs on every change. The capability suite is deliberately hard, starts low and reports progress without gating; saturated tasks graduate into the regression suite. When quality saturates, optimize cost and latency at equal quality, or make the capability suite harder.
- **Slices.** Report and gate per failure category and per material slice — language, segment, channel, tenant, input source. An aggregate hides a failing slice.
- **Hill-climbing discipline.** Hold out a test split sized to resolve the smallest gain you would act on; change one root cause per round; revert a change that lifts train while test stays flat; never paste eval items into prompts or tools; reject harness additions that only help eval edge cases.
- **Agents — what passes.** Grade the environment's end state plus the information the user needed, never the agent's own claim; a do-nothing agent must fail; give partial credit by counting passed sub-checks; assert only mandated steps (approval before a write, identity check before a refund). Use trajectories to diagnose and to measure efficiency: a success that took three times its step and cost budget is a failure shaped like a pass.
- **Agents — task hygiene.** Build tasks from real failures (practitioner starting point: 20–50), each with a reference solution and a verdict two experts would agree on; run each trial in a clean, isolated environment; assert each tool call separately (name, arguments, result, resulting state, authorization). A task at 0% across many trials usually means a broken task or grader — read transcripts before trusting any score.
- **pass@k vs pass^k.** Run each scenario k times: pass@k (any of k trials succeeds) measures the capability ceiling; pass^k (all k succeed) measures the reliability floor. Production cares about pass^k: an agent that succeeds 90% per run is a 59% agent at pass^5. Estimate it as C(c, k) / C(n, k) from n ≥ k trials with c successes; use pass@k only when a verifier picks the successful run.
- **Retrieval.** Evaluate retrieval as search first: recall@k at the k actually passed to the model, and precision@k — irrelevant chunks are noise even at perfect recall. Then grade generation by relationship: faithfulness to the retrieved context claim by claim (right by general knowledge but contradicting the source counts as unfaithful), answer relevance, correctness; include unanswerable questions (passing means abstaining) and evidence at the start, middle and end of long inputs; record each stage's latency. A final-answer eval can't tell you whether retrieval, ranking, or generation failed.
- **Pipelines and long sessions.** Pick validators by node type (routers by precision and recall, writers by a purpose-built judge, code or query generators by static checks plus execution) and reproduce each failure with the simplest failing test: single-turn if possible, else a replayed real conversation prefix that tests the next turn; audit simulated users before blaming the agent. For long sessions, add an instruction-retention case: state a constraint early, force compaction, then grade violations deterministically, including adversarial content aimed at the summarizer (`ai/context.md` § Governance decay).
- **Environment and integrity.** An eval's identity includes its environment: resource limits, timeouts, tool and network access. Keep answer keys out of reach of tool- or web-enabled agents, and read transcripts for answer-hunting.

## Release unit and release gate

**Automate — as a release gate, not a script.** The release unit is everything that changes behavior: model snapshot, reasoning and decoding settings, prompts and templates, the tool set with its schemas and descriptions, loaded harness extensions, retrieval index and embedder version, guardrail and policy configuration, context and caching policy, and the judge (model and prompt). A change to any member — including a prompt-registry promotion or an adopted provider default — runs the gate, and every run is stamped with the full unit.

The gate has three classes, each stated as a one-sided confidence bound:
1. **Absolute invariants** — safety, authority, privacy, schema: any failure in any of k runs blocks.
2. **Quality** — per category and per material slice, against the recorded baseline, with k runs and a tolerance wider than the measured noise; gate on the worst material slice, and investigate single-run flips rather than auto-blocking on them.
3. **Budgets** — cost per successful task and p95 latency per scenario, against the envelope (`ai/production.md`).

**Statistics.** Measure the noise floor before optimizing: rerun the suite, grade identical outputs twice, and scan for timeouts, truncation, provider errors and leftover state; a difference inside that band is noise. Gate on one-sided 95% bounds (Wilson or Clopper–Pearson): for a "fewer than 5% defects" gate, 6 defects in 200 items fails and 12 in 400 passes. Compare variants as paired differences on the same items; use clustered errors when items share a source or conversation; size the set for the smallest effect you would act on, declared in advance.

**Promotion.** Shadow, then canary: the same three classes — measured on judge-sampled production traces, escalation and override rates and cost per unit — are the promote and abort criteria (`design-flow.md` § Release Model); the quality class becomes an AI SLI on the SLO table.

**Before an external launch**, all hold: one completed error-analysis cycle with its spec fixes; code assertions for every objective failure mode, run on every change; every gating judge validated, pinned and versioned; the regression suite green; release bounds met, above the noise floor; for agents, end-state grading, a failing null agent and pass^k at the product's k; for retrieval, a recall@k baseline recorded apart from answer quality; a named owner for the production loop. A light feature ships on the minimum gate in `ai/protocol.md` instead.

## Calibration gate

Before any branch acts, abstains or escalates on a probability or confidence (`ai/protocol.md` steps 2 and 6), measure it on labeled examples from your own traffic: reliability by bucket (calibration error or Brier score) and selective accuracy — how much traffic the threshold you will use covers at your target precision — per slice, since a pooled curve hides miscalibrated slices. Fit or recalibrate the threshold on one split, confirm it on a held-out split, re-check it on a later time slice, and refit on every model, version or criteria-wording change. A vendor's "calibrated" describes a training objective, not your data. *Break when* labels truly cannot be obtained: then nothing acts automatically on confidence — keep a person in the loop and collect labels from the reviews; advisory outputs may ship with a provisional, logged threshold.

## Production loop

- **Guardrails vs evaluators.** Synchronous guardrails sit in the request path: fast, deterministic, block or allow. Asynchronous evaluators score sampled traces with validated judges, at trajectory (whole-session) level for agents; alert when the lower bound of the quality interval crosses the threshold.
- **Scheduled evals.** Pinned is not stable. Run the gate against the unchanged production unit on a fixed schedule, on any provider notice (deprecation, changelog, incident), and when a drift alarm fires (`ai/production.md`); probe continuously through the real production path, and check your own change log before blaming the provider.
- **Owner and cadence.** A named quality owner on the on-call rotation reviews outlier and random traces on a fixed cadence, and runs a full error-analysis cycle after model switches, prompt rewrites, incidents or complaint spikes. Every triaged production failure becomes a permanent regression case — clustered and reproduced automatically if you like, confirmed by a person. Forcing question: which production failure from last week is now a regression test?
- **Design for evaluability.** Stamp every trace with the release unit and carry it through to the business outcome; capture what reviewers need and transcripts lack (channel, locale, tenant policy); design feedback UX to yield labels on the dimension you measure, and mix random traces into feedback-driven samples. Where privacy rules forbid storing traces, rely on synthetic replays and aggregate metrics.
- **Automation assists, people decide.** Agent-run error analysis supports a human-led loop and never replaces it; never let the same agent write a rubric and score with it.

## Red flags

- A rubric written before anyone read traces, or generic scores (helpfulness, similarity to a reference) reported as quality.
- A judge validated by raw agreement, scoring several criteria at once, on a numeric scale, or running on a floating model alias.
- Agents graded on their own claims or on exact tool sequences, with no do-nothing-agent check.
- Release gates on point estimates, one trial per stochastic item, or "wins" inside the noise.
- Hill-climbing on the cases you report, or failing eval items pasted into prompts.
- A threshold acted on with no calibration check on your own labeled data, or labels taken from a stronger model's consensus.
