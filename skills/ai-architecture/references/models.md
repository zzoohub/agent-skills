# Model Selection

Decides which class of model answers each call site, which tier within it, how the system reaches models, and how it survives their retirement. Current instances of each class, with dates and prices, are in `landscape.md`; verify them before a decision rests on one.

## Pick the class by what the code needs back

| The caller needs | Class | Notes |
|---|---|---|
| One of a closed set, a score, a yes/no probability | **Decision tier**: rules → trained classifier → decision model | Below |
| A policy screen on text or images | **Guard model** that takes your policy at inference | A decision with safety vocabulary; open-weight ones can run where the data must stay |
| Open text, code, extraction to a schema | **Generative model**, small and fast up to frontier, with a reasoning setting | Prove down, below |
| Many steps chosen at runtime, with tools | **Frontier generative model inside a harness** | `orchestration.md` |
| Nearest items, relevance order | **Embedder, reranker** | The embedder is an index-time commitment (`context.md`) |
| A prediction over rows and tables (churn, fraud, demand) | **Classical model**, or a model pretrained on structured data | Not a language task; assess before defaulting to an LLM |
| Speech in or out | **Speech-to-text, text-to-speech, speech-to-speech** | `voice.md` |
| Understanding of images, documents or video | **Multimodal generative model** | Resize inputs to what the task needs; slow modalities run as jobs |
| Generated images, audio or video | **Media generation model** | Async jobs through object storage; machine-readable provenance added at generation; moderation before publication |
| An answer with no network, or data that may not leave the device | **Local model** | `on-device.md` |

One feature usually mixes classes: code first, a decision tier for what code cannot judge, a generative model for the cases that need language, a person for the rest. Defaulting every call to the strongest model is the most common waste.

## Decision models

A decision model takes a **state** and a list of **typed questions** and returns a probability for each answer you defined, never prose: a choice among labels, a level on a scale, a yes/no probability. It cannot write, call tools or explain itself. Several vendors and at least one open-weight model now share this request shape (`landscape.md`), so it is a tier, not a product.

**Use it when** code consumes the answer and the allowed answers can be listed before the call: route, classify, triage, allow/deny/ask, score, stop/continue, "which stored answer fits this question, if any". Calls take tenths of a second and cost far less than a generative call, which changes designs: gate every proposed tool call, screen every turn, triage every message, answer known questions from stored text, grade every trace, instead of sampling or generating.

**Design rules**

- **Atomic, independent, literal questions.** One property per question, stated as the exact condition: the model answers what was written, not what was meant, and handles double negatives and indirection badly. Questions in one request run in parallel and do not see each other's answers, so ask many at once and never chain them inside a request.
- **Judgment as features, policy in code.** Combine answers with rules or weights you own. Arithmetic, counting, date comparison and anything else computable stay in code: pass the computed number or a named bucket ("overdue by more than 30 days") in as state, and count by asking one question per item.
- **Small, relevant state.** Accuracy falls as unrelated material grows: retrieve and filter in code first, then send the record, the policy text and the criteria. Do not rely on the model's weights for facts you hold.
- **Options are prompt.** Their names, descriptions and order change the answer, and the first option is favored. Describe every option the same way (what it covers, what it is not for, an example), keep the list short by narrowing candidates in code first, include an explicit none/other option tested on real out-of-scope inputs, and check in the eval that answers survive reordering and renaming.
- **A threshold per action, in code**, on the probability of the option you will act on, higher for irreversible actions, with a middle band that abstains or escalates. Vendors define "confidence" differently (the concentration of the distribution for one, an estimate of correctness for another); read the definition, then calibrate on your own labels per slice anyway (`evals.md` § Calibration gate). A pooled calibration figure hides overconfidence on the slices where accuracy is low. Scores are for thresholds, not magnitudes.
- **Bounded extraction is a choice.** When the value must come from a known list, ask which one; when it is open, that is a generative call.
- **The contract** per question: a stable id, the type, the closed options with criteria, the threshold, and what happens below it. Put it behind a `decide(state, questions)` port.

**Stored answers.** The cheapest reply is one already written: code matches exact and rule-based cases, the decision tier asks which approved answer fits a free-form question (or none), code fills any blanks from data, and only "none" or low probability reaches a generative model or a person. Each stored answer must be safe to send to anyone; anything personal is filled after an authorization check in code.

**Break when**: the answer space is open; a readable reason is owed per decision; the step is planning or multi-hop reasoning (a decision model is a classifier, not a planner); no labels exist to calibrate; or volume is too low to justify a second component.

**What it costs architecturally**

- **No customization of weights**, as a rule: behavior changes only through the state, options and criteria you send. Those are part of the release unit and pass the eval gate like a prompt.
- **A young tier.** Versions are supported for weeks, not years, and vendors themselves warn that images and long inputs are less reliable than short text. Pin a version id, never a moving alias, and rehearse a migration measured in weeks. Keep a second adapter that passes the same eval: another vendor's decision endpoint, an open-weight decision model you host (also the answer when data cannot leave), or a trained classifier.
- **Typed output does not stop injection.** The state is not treated as hostile, and a closed set limits what the model can say, not which allowed value an attacker steers it to. Every option must be safe for an attacker to choose, or the decision is gated like an action (`security.md`).
- **The typed readout buys speed, price and a contract, not accuracy.** Show on your own eval that it matches a small generative model on the task before relying on it.
- **The escalation rate decides the economics.** The cheap tier acts on the slice that clears its threshold and escalates the rest to a generative model or a person. Model that rate explicitly and price misroutes. *Break when* most traffic escalates: you pay both tiers plus the hop, so route up front.

## Generative models: prove down

Prototype on the strongest model to learn whether the task is possible at all. If it cannot pass the seed tasks, redesign the task instead of shopping for models. Once it passes, walk down and ship the cheapest configuration that still passes the eval set. If you cannot run models in this pass, write the spike (configurations to try, pass criterion). *Break when* residency, latency or self-hosting fix the candidate set: prove down inside it.

- **Sweep the reasoning setting before adding a second model.** Reasoning is billed as output even when it is hidden, so it is the main cost dial, and a stronger model at a low setting can beat a cheaper one at a high setting. Walk the tier × setting grid, per call site.
- **One (model, reasoning setting) pair per task class**, versioned beside the model id and set explicitly, with output caps that include reasoning tokens. *Break when* a task is low-volume and high-stakes: use the strongest setting.
- **Compare on cost per successful task**, never on list price per token: cost per task ÷ measured success rate, at the settings you will ship. The price of a given capability keeps falling while tokens per task (reasoning, tool loops, sub-agents) keep rising, and list prices also go up.
- **Route at task or session boundaries**, never per turn inside a cached conversation: a model switch loses the prompt cache and the model's own reasoning state. Evaluate any router like a model, against an unrouted control.
- **Fast generation is a lever**, not a class: where a slower model fails only the latency budget, a faster serving tier or a fast-decoding model may pass it. It goes through the same eval.
- **A schema-valid answer is not a correct one.** Constrained output fixes shape within each provider's schema limits; validate meaning in code and handle refusal and truncation explicitly.

## Tuning and distillation

Changing weights is the last lever, after the spec, the context, tools, the model tier and the reasoning setting (`SKILL.md` § Improving a feature). It earns its place when **all** hold: the task is narrow, stable and high-volume; the eval has plateaued on the other levers; a hard latency, unit-cost, residency or on-device target cannot be met otherwise; the training data may lawfully be used; and someone owns retraining.

- **Forms.** An adapter trained on open weights (an artifact you own and can host or ship to devices) · distillation of a stronger model's behavior into a small one (check the provider's terms on training from its outputs) · a provider's hosted tuning (the weights may never leave) · a trained classifier for the decision tier.
- **What it adds to the system**: versioned training data with consent and de-identification; a reproducible training job; an artifact registry (base model id, adapter hash, data version); the same release gate, run on the exact artifact; serving capacity someone operates; a retraining trigger (a new base model, measured drift); rollback to the previous artifact; a hosted fallback behind the same port.
- **One-way doors**: training on user data, because weights cannot unlearn and an erasure request still arrives; the base model's license, which differs per checkpoint even within one family; the host of the weights.

The mechanics of training, distillation and serving are out of scope here; the design hands over a contract: per-failure-mode targets on this feature's eval suite, latency and cost per successful task at volume, a drop-in behind the model port, an owner and a refresh cadence.

## Access

- **Model access is a port.** The domain calls task-level operations (`classify_ticket`, `draft_reply`), never provider request types, and a deterministic fake keeps it testable. Provider quirks (reasoning settings, caching hints, structured-output mode, tool dialect) stay in the adapter, with a prompt variant per provider. Never a lowest-common-denominator interface: provider features pass through explicitly and are recorded as portability debt.
- **A gateway arrives with the second team or provider**, or with a central audit requirement; until then, an in-process adapter. A gateway holds every provider credential, meters per tenant and feature, enforces caps and owns the single retry layer. It is tier-0 and has been a supply-chain target: pin its version and image digest, never follow `latest`, never log request or response bodies, and ask what falls if it is compromised.
- **Where the model runs** (hosted API, dedicated capacity, self-hosted open weights, attested confidential compute) follows residency, data sensitivity, latency, sustained volume and who operates it, never a spend threshold. Self-hosting makes serving someone's job. Open weights are also an exit: no forced retirement, at the price of owning serving.
- **Retention is a property of the model, not of the provider.** Zero-retention terms, eligible regions and hosted-agent features differ per model and per endpoint: place each call by data class, and record the terms with source and date.

## Lifecycle & exit

- **Pin immutable version ids** and stamp version, prompt version and parameters on every trace. Aliases move, and a pinned model can still shift with the provider's infrastructure: scheduled evals on the unchanged production unit catch silent drift.
- **Notice periods run from two weeks for previews to six months.** Size the migration runbook to the shortest one you depend on: inventory model use per call site → run the successor in shadow → regression suite with repeated trials → retune prompts → re-sweep the reasoning setting and re-measure tokens per task (a new tokenizer alone can move the count by a third), latency and refusal rate → check every request parameter is still accepted → remove scaffolds the new model no longer needs → canary with instant rollback.
- **Long-lived sessions** finish on the model, prompt and tool schemas they started with, within a maximum pin lifetime.
- **Exit cost lives in evals and adapters, not SDK calls.** Keep a provider-neutral eval suite and an alternate model that passes it at an agreed fraction of baseline, re-checked on a schedule.
- **Provider-exclusive features on the critical path** (structured-output modes, hosted retrieval, hosted agents, managed memory, tuned weights, the embedder) sit behind the port with a tested fallback, or get an ADR with an exit estimate. *Break when* the capability is the product's moat.
- **Own your state**: session logs, transcripts, memory, eval sets. Provider-side state is a rebuildable cache.

## Red flags

- A generative model asked for a label that code then parses out of prose, or the strongest model used for every call.
- A threshold on a vendor's "calibrated" confidence with no check on your own labels.
- A choice question with dozens of options, or one whose answer changes when the options are reordered.
- Models compared on price per token, or a moving alias in production.
- A fallback that has never run through the regression suite.
- A gateway or AI SDK followed at `latest`, or logging full request and response bodies.
