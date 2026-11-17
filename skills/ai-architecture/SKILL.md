---
name: ai-architecture
description: |
  Design one AI feature or agent system and write its feature doc: whether a
  model belongs at all, model class (decision model, LLM, speech), shape
  (single call, workflow, graph, agent, multi-agent), authority and
  containment, context and memory, the eval gate, cost and latency, placement
  (cloud or on-device), provider exit. Also reviews one.
  Use when: "AI feature", "design this agent", "chatbot", "voice assistant",
  "RAG", "tool use", "MCP", "LLM cost", "on-device AI", "should this be an
  agent", "review this AI design".
  Do NOT use for: the system around it (software-architecture); one recorded
  decision (arch-decision); how users see it (ux-design); building eval sets,
  fine-tuning or SDK code.
---

# AI Architecture

## Premise

**A model is a component that is sometimes wrong, can be talked into things, charges per use and changes under you.** The design follows from those four facts.

1. **Code first, model last.** A model gets only the judgment over open-ended input that code cannot make. Sequencing, arithmetic, policy and limits stay in code.
2. **The model proposes, code disposes.** Authority, money and irreversible effects are enforced outside the model, because anything a model reads can steer it.
3. **Evals are the spec and the guard.** A task you cannot write test cases for is not defined yet, and nothing ships without a gate that can fail.
4. **Budget per successful task**, with caps that stop work instead of alerts that report it.
5. **Everything about the model is replaceable**: behind a port, pinned to a version, with a tested way out.

Write only what changes what the next reader does: a line stays in the feature doc only if an implementer would do something different, and wrong, without it.

## Modes & Routing

- **Design** (default): one feature per run, written to the feature doc (default `docs/arch/ai-features/{feature}.md`; caller may redirect) from `templates/ai-feature.md`.
- **Review**: audit a feature doc, or a running feature, against the [Gate](#gate) and the red flags of each reference its depth loads. Read-only by default: return findings ranked 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low with proposed patch text; apply only targeted patches, and only when asked. Never regenerate the doc.
- **A question is not a request for a document.** "Should this be an agent?" or "which model for this?" gets an inline answer of about 300 words: the lowest rung that could work, what it costs, what to prove first.

**Read first** (defaults; caller may redirect): the feature spec (`docs/prd/features/{feature}.md`) or the PRD; the architecture docs if they exist (`docs/arch/context.md` §3 drivers and §5 constraints, `docs/arch/system.md` §1 AI Platform); existing code. Missing system context is a gap to report, not a reason to stop. On a running system with no docs, recover only what the feature touches.

**Ask once.** With no architecture docs, ask for the two numbers that gate the rest: the cost ceiling and the tolerated error. Any other gap is a question with the default you will otherwise assume, never a silent guess. A subagent that cannot prompt applies the defaults and lists the questions in its report.

**Ownership.** Write only the feature doc. What the system docs need from this design is handed over: in a pass that also runs the software-architecture capability, put these rows straight into its docs; standalone, list them in the report as owed.

- A new container, store, provider or trust boundary → an ADR, via the arch-decision capability if available, that points to the feature doc section instead of restating it.
- A Data Inventory row per AI store: traces, memory, caches, index, eval sets.
- The provider as a dependency with a degraded mode; the AI service-level indicators; one cost row; risks taken from the failure path.
- What features share: the model access port, providers and exit path, the AI cost ceiling, agent identities, enforcement points, the kill switch.

**Technology.** Mandates and the incumbent stack first; then the project's adopted house profile, where it states a preference; otherwise at least two candidates compared on the inputs below. A choice that rests on a vendor fact cites a current primary source and its date, or becomes a spike: versions, prices, limits and model names move faster than training data (`references/landscape.md`).

## Inputs that gate everything

| Input | Feeds |
|---|---|
| Cost ceiling per successful task, and per user per period | envelope, caps |
| Tolerated error per failure class, as a one-sided bound ("unsafe advice below 0.5% at 95% confidence") | failure path, release gate |
| Latency class per call site: interactive, near-real-time, deferred, live voice | shape, model class, streaming |
| Consequences: actions that change state or send data out, their reversibility, and who oversees them | autonomy |
| Untrusted inputs: web pages, email, files, tickets, retrieved text, tool output, audio, other agents | the three-leg check |
| Data constraints: residency, provider retention and training terms, tenancy, erasure | context, placement, provider |
| Jurisdictions and intended purpose | governance design-ins (`references/security.md`) |
| Exit window: how fast you must be able to switch provider | model port, fallback, exit |

Mechanisms (streaming, retrieval, tools, agents, graphs) are never inputs. Steps 2–5 choose them to meet these.

## Depth

**Light**: one advisory call whose output a person reads, with no tools, no egress and no sensitive data. It skips the evals, security and production references and must pass this gate, recorded in the feature doc:

1. The task sentence and how a user verifies the output.
2. An output contract validated in code, branching on refusal and truncation.
3. A wrong / unsure / down path.
4. Objective failure modes checked in code: schema, forbidden content, length.
5. Seed tasks with reference answers, run or marked "not run" with a spike, and a quality owner.
6. Envelope arithmetic against the ceiling, with per-request caps.
7. The three-leg check recorded as not applicable: the context reads no untrusted input, reaches no sensitive data, and neither changes state nor sends anything out. If any leg appears, the feature is deep.

Everything else is **deep**. Either depth reads the context, orchestration, interop, voice and on-device references when their triggers fire.

## Steps

| Step | Decides | Depth in |
|---|---|---|
| 1 Task and what the model owns | whether a model belongs | below |
| 2 Shape | orchestration shape, model class and tier | `references/orchestration.md`, `references/models.md` |
| 3 Autonomy & authority | the human's role per action class | below; enforcement → `references/security.md` |
| 4 Context | sources, retrieval, budget, memory | `references/context.md` |
| 5 Tools & actions | tool surface, what crosses a boundary | `references/orchestration.md` § Tools, `references/interop.md` |
| 6 Output contract & failure path | wrong, unsure, down, attacked, runaway, stopped halfway | below |
| 7 Eval gate | the sets, evaluators, release gate | `references/evals.md` |
| 8 Envelope | cost, latency, quota per successful task | `references/production.md` |
| 9 Rollout & lifecycle | release unit, pinning, migration, exit | `references/evals.md`, `references/models.md` |
| 10 Record | the feature doc, rows handed to the system docs, spikes owed | [Output](#output) |

### Step 1 — Task and what the model owns

- **Do you need a model?** Yes when input or output is open-ended language, needs fuzzy matching or synthesis, or cannot be enumerated. No when a query, a rule or a function gives the same answer. If code solves 80% of the task, let it: pre-filter with code, give the model the ambiguous remainder, validate its output in code.
- **Name the task**: "Given X, produce Y, so that Z", and how a user verifies Y. If verifying means redoing the work, redesign the output into checkable units: citations, diffs, intermediate artifacts. At each decision point, the model gets only what needs judgment over ambiguous input.
- **The junior test.** Could a capable newcomer succeed with exactly this input? No for lack of knowledge → enrich the context. No even then → re-scope. Yes but slowly → decompose.
- **Seed tasks** with reference answers are the first eval set and the spec. If you cannot write them, the task is underspecified.

### Step 2 — Shape

Take the lowest rung of `references/orchestration.md` that passes the seed tasks, and the cheapest model class in `references/models.md` that passes on it. Climbing is cheap; coming back down is a rewrite. Record why each rung below was not enough: the eval failure seen there, or, in a design pass where nothing has run yet, the reason it cannot work in principle and the spike that tries it first.

### Step 3 — Autonomy & authority

Set the human's role per action class, never per agent: **suggest** (a person executes) · **approve** (each action waits durably for a person) · **oversee** (acts; a person is notified and can interrupt) · **audit** (acts; reviewed afterward) · **autonomous**. First answer: what is the worst plausible action in one session, and is it reversible? Is there an objective check for "done" and "safe"? What can it reach if manipulated? Can the overseer actually judge its actions? How is a bad run stopped within minutes?

- **Autonomy is bounded by the verifier.** Long-horizon autonomy only where a check of "done" exists that the agent can run and cannot edit. A benchmark horizon is not a delegation length: size unattended work to the longest task your agents finish with verified success nearly every time. Widen autonomy only on that evidence, as a reviewed change; lower it automatically when failure thresholds trip.
- **Approvals only for irreversible, high-blast-radius or externally visible actions**, shown as exact parameters. Everything else gets boundaries plus cheap interruption; approving everything trains rubber-stamping. *Break when* law requires sign-off per action.
- Enforcement sits outside the model (`references/security.md`).

### Step 6 — Output contract & failure path

Structured output for anything code consumes, free text for what a person reads. Validate meaning, not only shape, and branch on the termination reason (completed, truncated, refused) before parsing. Decide each failure before writing the prompt:

- **Wrong**: what catches it. Depth follows the tolerated error: brainstorming tolerates much, invoice extraction does not.
- **Unsure**: below a threshold, abstain or escalate to a person. Route on a signal calibrated on your own labeled data (a decision model's probability, agreement across samples, a retrieval score, citation coverage), with the threshold set from the cost of a wrong answer against an abstention. Size the queue: abstain rate × volume must fit staffed capacity. A feature with no abstain path converts uncertainty into confident error.
- **Down**: degrade, never break: a qualified fallback model, a cached or stored answer, or feature-off.
- **Attacked**: a context that has read untrusted content cannot trigger consequential actions.
- **Runaway**: budgets that stop iterations, tokens, time and money, plus loop detection.
- **Stopped halfway**: stop semantics per action, compensations, idempotency keys.

The design supplies, and the ux-design capability presents: a server-side cancel with a partial-output policy, limit-reached states, a refusal path, an activity ledger, AI disclosure, and the autonomy level per action class as configuration.

## Improving a feature

- **Start minimal.** Draft a short, high-signal prompt on the strongest model; add an instruction or an example only for a failure the evals show. A rule that is mandatory for safety or compliance is enforced in code, not in prompt text.
- **Add the missing capability, not more instructions.** When a model fails, supply what is missing: information, a rule checked in code, a tool, feedback it can run, or state it can read. A prompt edit alone rarely closes a recurring failure. *Break when* it still fails with the right information, tools and feedback: decompose, add a verifier, use a stronger tier, or keep a person on that step.
- **Re-prove scaffolds on every model change.** Each planner, retry, evaluator loop or forced decomposition encodes a weakness of some model. On a model change, remove them one at a time against the eval suite and delete those that no longer move outcomes. *Break when* the component bounds blast radius: sandboxes, egress control, permissions, budgets and approvals are never removed for capability or speed.
- **Knowledge goes in context, never in weights.** A spec gap → fix the spec. A knowledge gap → retrieval or tools. A behavior gap that persists with good context on a narrow, stable, high-volume task → a tuning or distillation candidate, under the gate in `references/models.md` § Tuning and distillation.

## Inside a system design

When the software-architecture capability is designing the system around the feature, the system docs hold only what features share, and this skill adds to each of its stages:

| Its stage | What AI adds |
|---|---|
| Frame | Light or deep per feature; batch-ask the cost ceiling, tolerated error, jurisdictions and exit window |
| Size & drivers | Model calls per unit of value (turns, retries, judges, embeddings) are a load source; the AI drivers are scenarios (tolerated error, cost per successful task, latency, authority), never mechanisms |
| Shape | A context that owns AI hides model choice, prompts, tool schemas and index version, one module each. Model access is a port with a deterministic fake. Each AI store is a Data Inventory row |
| Decide | One-way doors: autonomy and authority, provider dependency and exit, training on user data, the embedder, a custom voice, regulatory classification. Evidence for an AI driver is an eval run or a spike with a numeric pass |
| Operate | Prompts, model version, reasoning settings and tool descriptions ship as releases; eval gates are the guards; the provider is a dependency with a degraded mode; one cost row per feature |
| Record | AI risks come from this design's failure paths, never pre-rated |

Write the feature doc in the same pass for each feature that is core to the product or acts consequentially; list the rest as owed.

## Measurement policy

Label every number in a feature doc or ADR:

- **measured**, with source and date;
- **derived**, with the inputs shown: envelope arithmetic from list prices and assumed volumes is fine, and says so;
- a **target** the requirements set;
- **not run**, with the time-boxed spike and numeric pass or fail that will produce it.

Pass rates, hit rates, calibration and latency under load are never derived: they are measured or not run.

## Output

One file per feature from `templates/ai-feature.md`: eight numbered sections that other skills read by number, about 1,200 words for a deep feature and 400 for a light one, tables included. State a default once and list only where the feature departs from it; a cell is a phrase. Over budget, cut what the spec or this skill already says, never a decision, a number or a failure behavior.

**Report back** a summary, not the document: the file written; shape, model class and tier, or the spike that will choose them; autonomy level; the release gate; cost per successful task against the ceiling; rows owed to the system docs; ADRs recorded or requested; spikes owed, in order; open questions.

## Gate

Skip what the feature's depth does not require.

- [ ] Every model-owned decision is one code could not make; every rung above the lowest says why the one below was not enough.
- [ ] Every action class has an autonomy level and every context a three-leg verdict; authorization and credentials sit outside the model's reach.
- [ ] The failure path covers wrong, unsure, down, attacked, runaway and stopped halfway; "unsure" routes on a calibrated signal to a sized queue.
- [ ] The release gate is a one-sided bound on a regression suite, with validated judges and a stamped release unit.
- [ ] Cost per successful task meets the ceiling; caps stop work at every scope; a kill switch exists.
- [ ] The model version is pinned, scheduled evals run, and the fallback is qualified or a degrade path is defined.
- [ ] AI stores have retention and erasure; provider data terms and intended-purpose class are recorded.
- [ ] Every number is labeled measured, derived, target or not run; provider facts carry source and date.

## Red flags

- An agent, graph or multi-agent shape with no stated reason the simpler rung fails.
- A decision consumed by code but parsed from free text, or a threshold on a confidence nobody calibrated on your data.
- No abstain path, or an escalation queue nobody sized.
- Pass rates, costs or quotas written as if measured, with no source or spike.
- A recurring failure "fixed" with more prompt instructions.
- Fine-tuning proposed to add knowledge.

## Reference Files

Read the section a decision touches, not the whole file.

| File | Read when |
|---|---|
| `templates/ai-feature.md` | Writing or patching the feature doc |
| `references/models.md` | Step 2: model class and tier, decision models, tuning, access, lifecycle and exit |
| `references/orchestration.md` | More than one call: workflows, graphs, pipelines, agents, tools, multi-agent, durable runs |
| `references/interop.md` | A tool server, another party's agent, an agent-driven interface or a payment crosses a boundary |
| `references/context.md` | Retrieval, memory, long sessions |
| `references/voice.md` | Speech in or out: recognition, synthesis, live conversation |
| `references/on-device.md` | Inference could run on a client |
| `references/evals.md` | Deep: the eval gate; before any branch acts on a probability |
| `references/security.md` | Deep: untrusted input, tools, authority, governance |
| `references/production.md` | Deep: envelope, caps, latency, caching, failures, telemetry |
| `references/landscape.md` | Before naming any AI product, protocol, price or regulation: a dated snapshot and a watch list |
