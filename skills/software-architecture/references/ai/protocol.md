# AI Protocol

Decides whether a model belongs in the path, what it owns, its shape and authority, and what proves it works. Read for any AI: in Build Mode through the hooks below, in AI Feature Mode as steps 1–10. File paths are relative to `references/`; `context.md` and `system.md` mean the architecture docs (default `docs/arch/`; caller may redirect).

## Drivers and constraints first

Read the AI driver scenarios and constraints in `context.md` §3 and §5. With no architecture docs, ask the caller for the two numbers that gate everything: the cost ceiling and the tolerated error rate. Any other missing driver becomes a question to the caller, with the default you will otherwise assume — never a silent guess (Stage 0 asking protocol in `SKILL.md`).

| Driver or constraint | Feeds |
|---|---|
| Cost ceiling per successful task, and per user per period | envelope and caps (step 8) |
| Tolerated error per failure class, as a one-sided bound ("unsafe advice below 0.5% at 95% confidence") | failure-path depth, release gate (steps 6–7) |
| Latency class per call site: interactive (time-to-first-output and total budgets), near-real-time, deferred | shape, routing, streaming (steps 2, 8) |
| Consequences: actions that change state or send data outside, their reversibility, who oversees them and whether that person can judge them | autonomy level (step 3) |
| Untrusted inputs: web pages, email, files, tickets, retrieved text, tool output, other agents | three-leg check (step 3) |
| Data constraints: residency, provider retention and training terms, tenancy, erasure duties | context, placement, provider choice |
| Technology baseline (`context.md` §5): mandates, else an adopted house profile's AI rows | default provider, gateway, retrieval and eval tooling; a deviation rests on a verified gap and gets an ADR (`design-flow.md` § Technology Baseline & Selection) |
| Regulatory class from the intended purpose — ask which jurisdictions apply | governance design-ins (`ai/security.md`) |
| Provider-exit window: how fast you must be able to switch | model port, fallback, exit ADR (`ai/production.md`) |

Mechanisms — streaming, retrieval, tools, agents — are never drivers; steps 2–5 choose them to meet these.

## Depth: light or deep

**Light** = one advisory call (a person reads the output; nothing automated acts on it), no tools, no egress, no sensitive data, and no other AI trigger in `design-flow.md` § Perspectives. Light skips `ai/evals.md`, `ai/security.md` and `ai/production.md` and must pass the minimum gate below. Everything else is **deep** and reads those three. Either depth adds `ai/context.md` (retrieval, memory, long sessions), `ai/agentic.md` (tools, agents) and `ai/placement.md` (inference could run on a client) when their own triggers fire.

**Light minimum gate** — every item recorded in the feature doc (in a combined run, AI Feature Mode writes it after Build):
1. The task sentence and how a user verifies the output.
2. An output contract validated in code, branching on refusal and truncation.
3. A wrong / unsure / down path: what catches errors, where uncertain cases go, the degraded state.
4. Objective failure modes checked in code: schema, forbidden content, length.
5. Seed tasks with reference answers — run, or "not run" plus a spike — and a named quality owner.
6. Envelope arithmetic against the ceiling, with per-request caps.
7. The three-leg check (untrusted input × sensitive access × state change or egress) recorded as not applicable; if any leg appears, the feature is deep.

## Build-mode hooks

With AI present in Build Mode, apply each stage's row. Build records only system-level content — the rows below plus `system.md` §1 AI platform, §2 AI containers and §5 cross-feature AI authority; feature depth stays in AI Feature Mode (`SKILL.md`).

| Stage | Hook |
|---|---|
| 0 | Set light or deep per AI feature; batch-ask what the PRD cannot hold (cost ceiling, tolerated error, jurisdictions, exit window), each with the default you will assume |
| 1 | Model calls per unit of value (turns, retries, judge and embedding calls) are a load source next to Stage 1's tail-user price and quota headroom |
| 2 | These drivers become six-part scenarios (tolerated error, cost per successful task, latency class, autonomy, untrusted-input exposure) or `C-nn` constraints (data terms, regulatory class, exit window) |
| 3 | A context that owns AI hides its volatile decisions — model choice, prompt templates, tool schemas, index and embedder version — one module each |
| 4 | AI is the core subdomain or takes consequential actions → run steps 1–5 inside the 2↔3↔4 loop; ATAM evidence for an AI driver is an eval run or a spike with a numeric pass criterion |
| 5 | Model access is a driven port with a deterministic fake for tests (when a gateway pays → `ai/production.md`); AI containers per `templates/system.md` §2 |
| 6 | Each AI store — traces, memory, caches, index and chunks, eval and tuning sets — is a `design-flow.md` § Data Inventory & Lifecycle row: class, tenant/user key, retention, residency incl. the provider's processing region, erasure path |
| 7 | Prompts, model snapshot, reasoning settings and tool descriptions ship as releases (release unit, `ai/evals.md`); one envelope roll-up row per feature in the `system.md` §4 cost table (`design-flow.md` § Cost & Unit Economics); hosted vs self-hosted → `ai/production.md`; client tiers → `ai/placement.md` |
| 8 | Eval gates are fitness functions; the AI SLI set (`ai/production.md`) joins the SLO table; the AI trust-flow pass runs inside STRIDE (`ai/security.md`); the provider is a row in the Resilience table |
| 9 | AI one-way doors go to `design-flow.md` § Minimum ADRs (autonomy & authority, provider dependency & exit, regulatory classification); AI rows join § Risk Register |

## Steps

| Step | Decides | Depth lives in |
|---|---|---|
| 1 Task, verification & the decisions the model owns | whether a model belongs; what it decides | below |
| 2 Shape | rung, decision tier, model tier and reasoning setting | below; multi-agent → `ai/agentic.md` |
| 3 Autonomy & authority | the human's role per action class | below; enforcement → `ai/security.md` |
| 4 Context | sources, retrieval, budget, compaction, memory | `ai/context.md`; prompt guidance below |
| 5 Tools & actions | tool surface, code as the action layer, tool vs peer agent | `ai/agentic.md` |
| 6 Output contract & failure path | wrong, unsure, down, attacked, runaway, stopped halfway | below |
| 7 Eval gate | failure taxonomy, evaluators, release gate | `ai/evals.md` |
| 8 Envelope | cost, latency and quota per successful task | `ai/production.md` |
| 9 Rollout & lifecycle | release unit, pinning, migration, exit | `ai/evals.md`, `ai/production.md` |
| 10 Record | one-way doors and surface changes as ADRs (each links the feature-doc section, never restates it), AI risks, spikes owed | `design-flow.md` § Minimum ADRs, § Risk Register |

## Step 1 — Task, verification & the decisions the model owns

- **Do you need a model?** Yes when input or output is open-ended language, needs fuzzy matching or synthesis, or cannot be enumerated. No when a regex, a query or a deterministic function gives the same answer faster and cheaper, or when correctness is safety-critical and the model's confidence can't be verified (payments, medical dosing, legal filings without review). If you can solve 80% of the task deterministically and only use the LLM for the residual 20%, that's almost always the right architecture. Pre-filter with code, let the model handle the ambiguous cases, post-validate the output.
- **Name the task:** "Given X, produce Y, so that Z". Name how a user verifies Y; if verifying means redoing the work, redesign the output into checkable units (citations, intermediate artifacts, diffs against a vetted anchor) — hard to evaluate is a product smell. At each decision point ask whether it needs judgment over unstructured or ambiguous input, or whether code could decide; the model gets only the first kind (`ai/agentic.md`). Intern test: could a competent junior succeed with exactly this input? No for lack of knowledge → enrich the context; no even then → re-scope; yes but slowly → decompose or template.
- **Seed tasks.** Hand-written tasks with reference answers are the first eval set and the spec. If you can't write them, the task is underspecified; if you would label a case differently on different days, spec the edge cases first. Error analysis on real traces takes over once traffic exists (`ai/evals.md`).
- **Readiness bar.** Every feature has a context, reasoning, output and evaluation layer — plus an execution layer (tools, sandbox, permissions, state, verification) when it has tools or agents. If you can't answer "what's in the context, how does it reason, what's the output contract, how do I measure quality — and what may it execute?" in one sentence each, the design isn't ready to implement.

## Step 2 — Shape

Pick the simplest shape that solves the task. Upgrading to a more complex shape is cheap; downgrading from one is a rewrite.

| Rung | Shape | When to upgrade — record the eval failure observed here, with its quality, cost and latency |
|---|---|---|
| 0 | Deterministic code | the step needs judgment over open-ended input (step 1) |
| 1 | One model call, plus retrieval or examples: classify, extract, rewrite, summarize, answer from a corpus | never — if this works, stop; multi-hop questions → agentic retrieval (`ai/context.md`) |
| 2 | Fixed workflow: chain, route, parallelize, evaluator loop, or model-written orchestration code run by a deterministic runtime | the steps cannot be predetermined |
| 3 | One agent with tools: the model picks the next step at runtime — most tasks don't need this | one agent demonstrably fails and multi-agent admission holds |
| 4 | Multiple agents (admission and rules → `ai/agentic.md`) | — |

- **Workflow vs agent.** If you can draw the flowchart before running, build the workflow — it is cheaper, faster and far easier to debug; reach for an agent only when the steps genuinely can't be predetermined. *Break when* the path is unknown: explore with an agent in a sandbox with evals, then compile the discovered path into a workflow; a hard security or ownership boundary may force a split from day one.
- **Decision-shaped steps.** At any rung, if code consumes the output and the allowed answers can be listed before the call (route, classify, allow/deny/ask, score, stop/continue), use a decision tier — rules, a trained classifier, a small model scored over the labels, or a decision model (Kahneman's System 1; generation is System 2) — behind a `decide(state, questions)` port. *Break when* the answer space is open; the step needs arithmetic, dates or multi-hop reasoning (compute those in code); no labels exist to calibrate; a readable reason is owed per decision; or volume is too low to justify a second component.
- **Typed decision contract**, per question: a stable id; the type (choice, ordinal score, boolean); closed options with contrastive criteria; an explicit none/other option tested on real out-of-scope inputs; a probability per option; a threshold per action, in code — higher for irreversible actions, abstain or escalate below the floor, and valid only after the calibration gate (`ai/evals.md`).
- **Model choice — prove down.** Prototype on a frontier model to establish that the task is possible at all: if the strongest model can't pass your examples, redesign the task instead of shopping models. Once it passes, walk down tiers and ship the cheapest model that still passes the eval set. Sweep model tier and reasoning setting (however the model exposes reasoning depth) together, per call site. If you can't run models in this design pass, write the spike (tiers to try, pass criterion) instead of a result. *Break when* residency, latency or self-hosting constraints fix the candidate set — prove down within it.

## Step 3 — Autonomy & authority

Set the human's role per action class, never per agent: **suggest** (a person executes) · **approve** (each action waits durably for a person) · **oversee** (acts; a person is notified and can interrupt) · **audit** (acts; reviewed afterward) · **autonomous**. Answer first: What is the worst plausible action in one session, and is it reversible? Is there an objective check for "done" and "safe"? What can it reach if manipulated? Can the overseer judge its actions? How is a bad run stopped within minutes?
- Autonomy is bounded by the verifier: long-horizon autonomy only where a near-perfect, agent-readable check of "done" exists (*break when* none exists — a person stays the verifier and autonomy drops). Widen autonomy only on evidence — pass^k at the target horizon and incident-free runtime — as a reviewed change, after replaying recent recorded runs in an isolated copy with blast-radius caps. Lower it automatically when failure thresholds trip.
- Approvals only for irreversible, high-blast-radius or externally visible actions, shown as exact parameters; everything else gets boundaries plus cheap interruption. *Break when* law requires sign-off per action.
- Enforcement sits outside the model (`ai/security.md`); approval wait, interrupt and activity ledger → `ai/agentic.md`.

## Step 6 — Output contract & failure path

Structured output for anything code consumes, free text for what a person reads; validate meaning, not only shape (prompt guidance below). Decide each failure before writing the prompt:
- **Wrong** — what catches it: schema and invariant checks, citation checks, judge-sampled traces, human review. Depth follows the tolerated-error scenario: a brainstorming feature tolerates much; an invoice extractor doesn't.
- **Unsure** — design the confidence boundary: below the threshold, abstain ("I can't determine this from the available information") or escalate to a human queue. Route on a signal calibrated on the eval set — agreement across k samples, a retrieval or rerank score, a validator or judge pass, citation coverage, a decision tier's probability, token log-probabilities where exposed; verbalized confidence qualifies only after the same calibration (`ai/evals.md`). Set the threshold from the cost of a wrong answer versus an abstention. Size the escalation path: abstain rate × volume, per language and segment, must fit staffed capacity at its SLA; abstain, escalation and override rates are SLIs. A feature without an abstain path converts uncertainty into confident error.
- **Down** — degrade, don't break: an eval-qualified fallback model, a cached or deterministic answer, or a feature-off state (qualification → `ai/production.md`; unavailable on this device → `ai/placement.md`).
- **Attacked** — a context that has read untrusted content cannot trigger consequential actions (`ai/security.md`).
- **Runaway** — budgets that stop iterations, tokens, time and money, plus loop detection (caps at every scope → `ai/production.md`).
- **Stopped halfway** — stop semantics per action, compensations, idempotency keys (`operational-patterns.md` § Durable Execution; agent deltas → `ai/agentic.md`).
- **UX hand-off** — the architecture supplies, and the ux-design capability (if available) presents: stop as a server-side cancel with a partial-output policy (`ai/production.md` § Streaming & generation lifetime), limit-reached states with their reset, a refusal path, an activity ledger users can see, AI-interaction disclosure, and the autonomy level per action class as configuration.

## Prompt guidance

- Draft a minimal, high-signal prompt on the strongest model; add an instruction or example only for a failure evals show, and trace every always-on line to one. Examples match the production distribution and include a hard case. *Break when* a rule is mandatory for safety or compliance — enforce it in code, not in prompt text.
- Constrain every machine-consumed output to a schema; validate in code what the schema cannot express (ranges, cross-field rules, enum normalization) and branch on the termination reason (completed, truncated, refused) before parsing. Constrained decoding fixes shape (except on truncation or refusal) but never content. Let the model reason before the constrained answer.

- Untrusted text enters only through user or tool channels, delimited and labeled — hygiene, not a security boundary (`ai/security.md`).
- Iterate on the whole eval set, never on one example: classify each failure as spec, example or model, and keep old versions — the prompt is a versioned member of the release unit (`ai/evals.md`).

## Improving a feature

- **Add the missing capability, not more instructions.** When a model or agent fails, supply what is missing: information (retrieval, search), a rule (a formal check), a tool, feedback (a verifier it can run) or legibility (logs and state it can read). A prompt edit alone does not close a recurring failure; it needs a mechanical guide or sensor, or a written reason why not. *Break when* it still fails with the right information, tools and feedback — a capability limit: decompose, add an evaluator, use a stronger tier or reasoning setting, or keep a person on that step.
- **Re-prove scaffolds on every model change.** Each scaffold — planner, context reset, retry, evaluator loop, forced decomposition — encodes a model weakness; register it with that weakness. On every model or reasoning-setting change, remove scaffolds one at a time against the eval suite and delete those that no longer move outcomes; keep stability in interfaces (session log, tool contracts, execution API), not harness internals. *Break when* the component bounds blast radius: sandbox, egress control, permissions, budgets, approvals and audit are never removed for capability or speed.
- **Customization boundary.** Diagnose the gap from error analysis: spec gap → fix the prompt or spec; knowledge gap (missing, changing or permissioned facts) → context, retrieval or tools, never weights; behavior gap that persists with adequate context (format, style, policy adherence) → tuning candidate; capability gap → decompose, add a verifier, a stronger tier or reasoning setting, or a person. First try automated prompt or harness optimization on held-out evals, accepted only with no regression. Tune only when all four hold: (a) a narrow, stable, high-volume task with data you may lawfully train on; (b) prompting, retrieval, tier and reasoning setting have plateaued on the eval; (c) hosted options cannot meet a hard latency, unit-cost or residency target; (d) you own retraining at every base-model change. Record each consequence as an ADR: the training pipeline and its retraining cadence become a component; the weights host is lock-in and weights may not export; training on user data is a one-way door, because weights cannot unlearn.
- **Contract to model engineering** (training, distillation, RL, weight-level evals, serving internals and MLOps are out of scope here): per-failure-mode targets as one-sided bounds on this feature's eval suite, pass^k where every run must succeed, no regressions; p95 latency and cost per successful task at volume; a drop-in behind the model port with a qualified hosted fallback; an owner, refresh cadence and re-evaluation at every base-model release. A trained classifier in the decision tier is a custom model under the same gate.

## Measurement policy

Every number in a feature doc or ADR is **measured** (source and date), a **target**, or **not run** plus a time-boxed spike with a numeric pass/fail — never an estimated pass rate, hit rate or cost. Provider rates, quotas, snapshot ids and deprecation windows are verified against current provider documentation at design time and recorded with source and date (feature doc §7). Report spikes owed.

## Feature doc

`docs/arch/ai-features/{feature}.md` (default; caller may redirect): one feature per run, eight sections, ≤ 200 lines; reference the originating feature spec when one exists. A light feature writes `n/a — reason` where the gate needs nothing.

1. **Task & decisions the model owns** — the task sentence; how a user verifies Y; what the model decides and what stays in code.
2. **Shape, autonomy & authority** — the rung and the eval failure behind each climb; decision contracts; model tier and reasoning setting, or the spike that will choose them; placement; the three-leg verdict per context; the autonomy level per action class; one authority row per tool or action: `Tool / action | Effect (read / write / sends outside) · reversible? | Data scope (principal ∩ agent grant ∩ task) | Caps | Approval (who · bound to exact parameters · expiry) | Enforced by (code outside the model) | Guard (adversarial eval case)`.
3. **Context** — prompt outline, sources and retrieval choice, context budget, compaction and memory policy, cache plan.
4. **Output contract** — schema or free text, validation, termination-reason handling.
5. **Failure path** — wrong / unsure / down / attacked / runaway / stopped halfway; thresholds and the escalation-queue sizing.
6. **Eval set & release gate** — failure taxonomy with 5–10 worked seed cases (input → pass condition), evaluator per failure mode, judge validation, suites, release bound, pass^k where every run must succeed, owner; baseline = the measured pass rate, or "not run" plus a prove-down spike — never estimated.
7. **Production envelope & lifecycle** — cost per successful task (p50/p95/p99, per segment) vs the ceiling, latency class, quota headroom, caps, caching; release unit and rollout; pinned snapshot, fallback, exit; data and regulatory obligations (personal data minimized or masked before prompts, traces and caches; AI stores with retention and erasure, provider data-flow ledger, intended-purpose class, disclosure duties).
8. **Open questions / risks** — options, the information needed, decide-by; spikes owed.

## Self-review gate

Skip what the feature's depth does not require.
- [ ] Every model-owned decision is one code could not make; every climb cites the eval failure on the rung below; each decision-shaped step uses the decision tier or records why not.
- [ ] Every action class has an autonomy level and every context a three-leg verdict; authorization and credentials sit outside the model's reach.
- [ ] The failure path covers wrong, unsure, down, attacked, runaway and stopped halfway; "unsure" routes on a calibrated signal to a sized escalation queue.
- [ ] The release gate is a one-sided bound on a regression suite, with validated judges and a stamped release unit.
- [ ] Cost per successful task meets the ceiling in the statistic the requirement states (an average target stays an average gate), with the p95/p99 user reported as risk; caps stop at every scope; a kill switch exists.
- [ ] The model snapshot is pinned, scheduled evals run, and the fallback is eval-qualified or a degrade path is defined.
- [ ] AI stores are inventory rows with retention and erasure; the provider data-flow ledger and intended-purpose class are recorded.
- [ ] Every number is measured, a target, or "not run" with a spike; provider facts the design rests on (region, data terms, price, quota) carry source and date; spikes owed are reported.

## Red flags

- An agent or multi-agent shape with no recorded eval failure on the simpler rung.
- A decision-shaped step answered by parsed free text, or a threshold on a confidence nobody calibrated on your data.
- No abstain path, or an escalation queue nobody sized.
- Pass rates, costs or quotas written as if measured, with no source, date or spike.
- A recurring failure "fixed" with more prompt instructions and no guide or sensor.
- Fine-tuning proposed to add knowledge, or before error analysis shows the model is the bottleneck.
