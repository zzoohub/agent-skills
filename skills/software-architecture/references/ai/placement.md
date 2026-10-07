# Client & Hybrid Inference Placement

Decides which tier runs each inference task when any could run on a client (mobile, desktop or browser app; an offline need; data that must stay on the device; in-UI latency; very high call volume). Client-tier deltas only: server-side placement, routing and caps → `ai/production.md`; the AI threat model → `ai/security.md`; gate statistics → `ai/evals.md`; rings, signing and kill switches → `design-flow.md` § Release Model.

## Tiers

| Tier | Buys | Pays |
|---|---|---|
| Platform-provided local (OS- or browser-managed model) | no per-app download; vendor-updated and safety-filtered; zero marginal cost | not pinnable, hot-swapped, version sometimes hidden; gated by device, OS, region, user setting, language and storage; often foreground-first, quota-limited and small-context — verify per platform and version |
| App-shipped local (bundled or downloaded weights on your runtime) | a pinned version; identical behavior across platforms; offline; your license choice | large delivery; memory and energy budget; porting per accelerator; you own safety and updates; the weights become public |
| Edge (inference near the user) | lower network latency; residency | server cost and server trust — no on-device privacy claim |
| Private remote (attested, stateless) | more capability while keeping a privacy claim | usually first-party or eligibility-gated, with quotas; qualifies only if the client verifies attestation before sending, nothing is retained, operators have no privileged access and requests cannot be targeted at a user — otherwise it is ordinary cloud |
| Cloud | reach, capability, pinning, central safety and observability | cost per call; a round trip; data leaves the device |
| Hybrid (an ordered chain of the above) | the best tier per task and device | two code paths, an eval matrix, governance of what leaves the device |

## Decide per task, not per app

Give each task a default tier and an ordered fallback chain, and re-place it when models change. Profile it on latency budget and call frequency, data sensitivity, context size and modality, capability needed, offline need, volume × cost per call, eligible share, who controls updates, IP and abuse exposure, and energy. Then ask, in order — an answer can end the analysis:
1. **Must this data stay on the device?** Then use only paths whose execution location you control, that the platform documents as local for that capability and version, or a qualifying private remote tier, and never fall back to remote silently. *Break when* the user opts in, per request, to a disclosed processor.
2. **Which property must survive when the local model is missing** — privacy, offline, zero marginal cost, a latency bound or reach? That property, not the model, picks the fallback: remote, a smaller local tier, a non-AI path, or hiding the feature. *Break when* the task is inherently remote (world knowledge, long context, shared server state): ask instead what the feature does offline or degraded.
3. **What share of *our* active users can run each local route**, now and over the planning horizon? Count it from your own analytics, per capability: device and OS eligibility, region, user setting, language, storage and memory. *Break when* the fleet is managed and homogeneous.
4. **Does the task fit a small model inside the context the runtime actually exposes on the lowest supported tier**, counted per language? Starting hypotheses, confirmed by a task eval on that tier: local for narrow, short-context transforms of data the user already has (rewrite, extract to a schema, classify, route, caption); remote for world knowledge, multi-step reasoning, math and code, long documents, fresh information, and behavior that must be identical across platforms. *Break when* regulation forbids remote processing: split the task into device-sized steps.
5. **Must outputs come from a pinned, known version** (audit, reproducibility, regulated decisions, experiment metrics)? Then an app-shipped pinned model or the server.
6. **Is the prompt or tuning itself the asset, or does safety depend on the model refusing?** Then keep the task remote. *Break when* the prompt and model are commodity or open and the capability is low-risk.
7. **Who controls version, customization, capacity and terms on each tier, and what is the exit** if the vendor replaces the model, withdraws customization or ends your eligibility?

Defaults, each with its counter-condition:
- **Broad consumer reach:** a remote or non-AI baseline, with local inference as progressive enhancement. *Break when* data governance makes the feature local-only and "not available on this device" is an accepted outcome.
- **Among local options, take the first that passes the eval:** a platform task-specific capability, then a platform general-prompt capability, then an app-shipped open-weight model, then an app-shipped tuned model. Move down for pinning, identical behavior across platforms, a missing language, modality or context size, or operating limits that conflict with the task. Customizing a platform model binds you to one base version — tune an artifact you control (gate → `ai/protocol.md`).
- **Justify local placement by durable drivers** — data locality, offline operation, latency, user-owned compute for always-on features — never by today's price, and re-review on a schedule. *Break when* usage grows faster than prices fall, or the remote path carries egress or compliance cost that does not decline.
- **Depend without a fallback** only on capabilities that ship on every target platform on a standards track, or on a platform you control; everything else sits behind the inference port — one app-level interface over local and remote adapters — with at least two adapters. *Break when* the product's whole premise is that one platform capability.
- **Shipping weights is redistribution:** license terms, use restrictions you must pass on, and store and OS policies are placement inputs.

Record per task, in the feature doc's shape section (§2): default tier · fallback chain · egress mode · measured eligible share · eval evidence on the lowest tier · exit plan.

## Hybrid routing & egress

- **Egress is a policy, not an accident.** Each feature gets one routing mode from its data class — local-only, prefer-local, prefer-remote or remote-only — and each scenario an egress mode: automatic and disclosed, user-initiated per request, or disabled (the default for sensitive data). The UI says when data leaves the device and who processes it.
- **Fallback sequence:** does a local capability fit, and is it ready on this device? If it needs a download, ask first, and serve remote meanwhile only if policy allows. If it is not ready and the data may not leave, explain the requirement and disable or hide the feature.
- **Every escalation, enrichment and subtask output is egress**, including personal context an on-device orchestrator adds to a remote prompt: minimize locally first and measure leakage on representative private inputs. Deterministic triggers (unavailable, context overflow, explicit request, task class) need no calibration; confidence-based escalation follows the cascade rules in `ai/production.md`.
- **Each route carries its own policy** inside the inference port — data handling, consent state, logging rules — so swapping a provider never crosses a boundary users were promised.

Pick the hybrid pattern by the invariant it must keep:

| Pattern | Keeps |
|---|---|
| Device-first: escalate on a measured gap, context overflow or explicit retry | privacy and marginal cost by default |
| User-initiated escalation for more depth | privacy unless the user asks |
| Degrade locally: older devices get a smaller local model, never the cloud | privacy as an invariant |
| Remote warm-start while a local model downloads, where egress is allowed | a usable first run |
| Device as sensor, remote as reasoner: perception, redaction and minimization stay local; only minimal derived text goes up | data minimization |
| Decision tier next to the data: gates, routes and triages every event, safe when the remote tier is late, wrong, offline or out of quota | latency and resilience |

## One output contract across tiers

- The schema binds every eligible tier — enums, fields, citations, and one encoding for abstain and refusal; constrained decoding where a tier supports it, validation in code on every tier.
- The inference port declares each tier's capabilities (context window, tools, multi-turn, modalities, reasoning, structured output); a tier lacking one the task needs is ineligible for that task — never loosen the contract to fit the weakest tier. *Break when* tiers differ so much that the experience must differ: show the tier in the product.
- Prompts are per-route artifacts, versioned per model family and version; sampling settings do not transfer, and context is shaped per tier.
- Every response carries provenance (route, adapter, model id and version where observable); branch on the route, never on the model's self-reported identity.

## Availability is a runtime state

- **Never block the core flow on a model.** Ship a baseline first (remote, smaller local, or non-AI), and enable the local path only after detection succeeds for the exact options the feature needs (languages, modalities, output constraints, context size). First use — download and warm-up — is its own state, entered on clear user intent, with consent for large downloads.
- **States**, each with a designed UI and a route: unsupported (device, OS, region, admin policy) · disabled by the user · downloadable, downloading, preparing · ready · busy or rate-limited · quota exhausted (not the same as unavailable) · blocked in the background · evicted or swapped mid-session · context overflow · unsupported language or modality · guardrail refusal · remote offline. Re-check at launch and on return to the foreground: states regress after updates, under storage pressure and after resets. Presentation via the ux-design capability, if available.
- **Detect by capability**, never by user agent, engine or device name; query availability only for the options you will use — probing others is a fingerprinting vector and can trigger downloads — and treat thrown errors as unavailable.
- **Budget from the runtime on the lowest supported tier, not the model card:** context window (counted per language), memory and operating limits. Where a platform model is foreground-first or quota-limited (check per version), bulk or background work goes to an app-shipped model under the platform's sanctioned background mechanism, or to a server job.
- **Capability tiers by measurement** — platform-model availability and version, memory, accelerator, storage, a warm-up benchmark — never by marketing class; map each tier to a route and degrade before failing (smaller input, shorter output, a skipped refinement step).

## Client model lifecycle

- **What you own per tier.** Platform-provided (unpinnable — see Tiers): per-version prompts, evals, feature gates and the exit plan. App-delivered weights: distribution, integrity, compatibility, safety and quality updates, and cleanup. Remote: `ai/production.md`.
- **Silent drift is the platform-model default.** Record the observed model id and version on every inference; keep per-version prompt variants where behavior differs; run golden and safety suites on pre-release OS and browser channels; gate features per version; where the version is hidden, re-run on a schedule and canary output validity and edit/undo rates (pinning rule: question 5).
- **The distribution channel decides independence from app releases.** A channel that versions model assets apart from the app binary lets models ship and roll back on their own schedule — and makes you own the compatibility of app code × runtime version × prompt-template version × model artifact. Encode it in a per-artifact manifest (model id, version, content hash, quantization, minimum runtime, prompt-template version, target capability tier) and refuse to load a mismatch.
- **App-delivered artifacts:** verify integrity before loading; roll out in stages with a remote kill switch that reroutes to the fallback chain; keep the last-known-good artifact until the new one passes an on-device smoke eval; re-verify presence on every launch; remove old versions within a storage budget. For platform models the OS owns integrity and storage, but you still own staged exposure and the kill switch for your prompts and features.
- **Config under server control** — model ids, routing thresholds, prompt templates, safety settings, deny-lists — with safe defaults compiled in. Config for a local path still lands on the device: it buys update speed, not secrecy. *Break when* deployments are offline-only or certified: version-lock config and re-certify each change.

## Client trust boundary

- **The client is untrusted.** Shipped weights, prompts, adapters and outputs can be extracted, read and forged; quantization and obfuscation are not protection, and a system prompt is neither a secret nor a control.
- **Client inference is advisory; the server is authoritative.** Anything that affects other users, money, trust and safety, ranking, entitlements or permissions is decided — or re-run — on the server. *Break when* the output is private to the requesting user and has no downstream effect.
- **Nothing secret on the client.** Credentials, proprietary prompts, business rules and differentiating tunes stay remote; refusal-dependent or dual-use weights stay remote (question 6).
- **Gate every client-reachable model endpoint**, the hybrid fallback included: route through your authenticated backend, or require app or device attestation plus per-user quotas, spend alerts and server-side moderation. Never ship a provider key.
- **Moderation follows publication.** Locally generated content shown to others or stored server-side is moderated server-side. Local guardrails protect only the local user and cover only the languages their vendor supports: add bounded inputs and outputs, a remotely updatable deny-list, and adversarial tests in every supported language, mixed-language input included.
- **On-device is not automatically private.** A platform contract may allow cloud- or OS-backed execution, and "prefer local" modes fall back by design, so the guarantee is a property of your routing: a local-only mode with no silent fallback, verified per engine and version, logged and disclosed. Your app still sees every prompt and output.

## Cost & energy

- **Local inference moves cost; it does not remove it:** eligible share × local cost (users' battery, storage and bandwidth; a larger eval matrix; two code paths; per-version retuning) + ineligible share × remote cost + abuse exposure of the fallback endpoint. Re-run the model as platform coverage grows.
- **Subsidy cliff.** Where a platform subsidizes a remote tier, verify its eligibility thresholds and per-user quotas at design time (source and date); design the quota-exhausted state and budget the after-threshold path before launch.
- **Who pays, and did the user ask?** Run local inference on explicit intent, never speculatively in background or hidden contexts; bound input size and repetitions, and cache results for identical inputs. Near-zero marginal cost invites always-on loops: cap total consumption (`ai/production.md`) alongside battery and background budgets.
- **Energy and thermal gate.** Measure energy per task and throttling over sustained sessions on low- and mid-tier target devices; favor short, bursty generations; degrade under throttling. "On-device is greener" is a hypothesis to measure end to end, per task, at equal quality.

## Evals & telemetry across tiers

- **The eval matrix is the release gate:** task × tier (each local variant, private remote, cloud) × model version, pre-release included × device class, with the lowest supported tier mandatory × backend, where you own the runtime × language, mixed-language input included. Measure task quality on a labeled set, time to first token and decode rate, cold start, peak memory, energy per task, sustained performance under thermal load, and failure rate per availability state. Gate on the exact artifact (quantized file plus runtime version), never the model card.
- **Prove down across tiers:** set the ceiling on the strongest remote model and walk down — local tiers included — to the smallest that passes on the lowest supported device. Re-run on every platform model, OS or browser release, runtime version, prompt-template, remote-model or routing-threshold change, and on a schedule where the version is hidden; the safety suite re-runs on every model update.
- **Local-path telemetry is content-free:** route and adapter, observed model version, availability state at first use, fallback or escalation reason, latency, token counts, error class, consent and download outcome, output-validity and edit/undo/retry rates, and the eligibility funnel (eligible → enabled → ready → served locally). Instrument the local path yourself — provider consoles may not see on-device inference. Content-level signal comes only from explicit user feedback or opt-in, privacy-preserving aggregation, and eval sets are built from synthetic and consented data. *Break when* the user, or an approved enterprise deployment, consents to content logging.

## Red flags

- 🔴 A feature sold as on-device or private while a fallback silently goes remote, or an "on-device" capability assumed to run locally.
- 🔴 The server trusts a client verdict or a rule enforced in a client prompt (moderation, fraud, pricing, entitlements, permissions).
- 🔴 Secrets, a proprietary prompt or a provider key on the client, or a client-reachable model endpoint without attestation, quotas or metering.
- 🟠 A platform-provided model treated as a pinned dependency: no observed-version telemetry, no per-version evals.
- 🟠 Validated on flagships only, or on the model card instead of the exact artifact on the lowest supported tier.
- 🟠 The core flow waits on a model — its download, availability or warm-up.
