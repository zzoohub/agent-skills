# On-device & Hybrid Inference

Decides which tier runs each inference task when any could run on a client: a mobile, desktop or browser app, an offline need, data that must stay on the device, in-interface latency, or very high call volume. Server-side placement → `models.md`. Platform capabilities change with every OS and browser release: verify per platform and version, and see `landscape.md`.

## Tiers

| Tier | Buys | Pays |
|---|---|---|
| **Platform-provided local** (a model the OS or browser manages) | No download per app; vendor-updated; zero marginal cost | Not pinnable: it changes with OS updates, and one OS release ships different variants to different devices, an order of magnitude apart in size and context window; gated by device, OS, region, language and storage; often foreground-only and quota-limited |
| **App-shipped local** (weights you bundle or download onto your runtime) | A pinned version; the same behavior across platforms; offline; your license choice | A large download; memory and energy; porting per accelerator; you own safety and updates; the weights become public |
| **Private remote** (attested, stateless compute) | More capability while keeping a privacy claim | Eligibility-gated, with per-user daily limits; the operating system, not your app, verifies the attestation; without verified attestation and no retention it is ordinary cloud |
| **Cloud** | Capability, pinning, central safety and observability | Cost per call; a round trip; data leaves the device |
| **Hybrid** (an ordered chain of the above) | The best tier per task and device | Two code paths, an eval matrix, governance of what leaves the device |

**Where inference runs is a fact about each request: choose it explicitly and record it.** One platform API can now reach a local model, the vendor's private cloud or a third-party server model. Some platforms fix the location by the model you select; others offer modes that fall back to the cloud by design, and a default speech recognizer may send audio to a server unless you ask for the on-device one. The privacy guarantee is a property of your routing, verified per platform and version, never of an API's name.

## Decide per task, not per app

Give each task a default tier and an ordered fallback chain. Ask in order; an answer can end the analysis.

1. **Must this data stay on the device?** Then use only paths whose execution location you control or the platform documents as local for that capability and version, and never fall back to remote silently. *Break when* the user opts in, per request, to a disclosed processor.
2. **Which property must survive when the local model is missing**: privacy, offline use, zero marginal cost, a latency bound or reach? That property picks the fallback: remote, a smaller local model, a non-AI path, or hiding the feature.
3. **What share of your active users can run each local route**, counted from your own analytics per capability: device, OS, region, language, storage, user setting?
4. **Does the task fit a small model inside the context the runtime actually exposes on the lowest supported device?** Starting hypotheses, confirmed by an eval on that device: a phone transforms context it is given (rewrite, summarize a few thousand tokens, extract to a schema, classify, route, translate, transcribe, pick among a handful of tools); a recent laptop also runs assistants and short agent loops; a server or attested cloud takes unaided knowledge, long documents, multi-step agents and fresh information. Small models answer from memory badly and call tools unreliably, so give them the facts and few choices.
5. **Must outputs come from a pinned, known version** (audit, regulated decisions, experiment metrics)? Then an app-shipped pinned model or the server.
6. **Is the prompt or tuning itself the asset, or does safety depend on the model refusing?** Then the task stays remote.
7. **Who controls version, capacity and terms on each tier, and what is the exit** if the vendor replaces the model or ends your eligibility?

Defaults, each with its counter-condition:

- **Broad consumer reach**: a remote or non-AI baseline, with local inference as progressive enhancement. *Break when* governance makes the feature local-only and "not available on this device" is accepted.
- **Among local options, take the first that passes the eval**: a platform task-specific capability, then a platform general model, then an app-shipped open-weight model. Move down the list for pinning, identical behavior across platforms, or a missing language or modality.
- **Never build on tuning a platform model.** An adapter binds to one model version, and vendors replace models and withdraw the tooling. Tune an artifact you ship, or do not tune.
- **Justify local placement by durable drivers** (data locality, offline, latency, user-owned compute for always-on features), never by today's price: the cloud price of a fixed capability falls quickly, so recompute the comparison yearly.
- **Depend without a fallback** only on a capability that ships on every target platform. Everything else sits behind one inference port over local and remote adapters.
- **Shipping weights is redistribution**: license terms and store policies are placement inputs.

Record per task in the feature doc §2: default tier · fallback chain · egress mode · measured eligible share · eval evidence on the lowest tier · exit.

## When to move a task onto the device

Devices do not improve evenly: phone memory has been flat while small models and accelerators keep improving, so the trigger is a measurement, not a calendar. Keep the cloud branch first-class and move a task when its own signals cross (thresholds are starting points):

| Signal, from your own analytics and evals | Starting threshold | Unlocks |
|---|---|---|
| Share of the task's active users on an eligible device, OS, language and region | ≥ 60–70% | The device as the default tier |
| Eval gap to the cloud path, per platform model generation, with schema-valid output | within a few points; valid ≥ 99% | Classification, extraction, rewriting |
| On the 25th-percentile device: time to first token, tokens per second, and the tenth run against the first | ≤ 1 s; ≥ 20/s; ≥ 70% | Interactive use; heat is the hidden limit |
| Fallback rate (busy, quota, unavailable, input too long) | < 10% | Proof the placement is real |
| Tool-use score of a model the tier can hold | ≥ 70% | Tool-calling agents on that tier |
| Context window the runtime reports against your p95 input | ≥ 2× | Document tasks |
| Counter-signal: cloud cost per task falling faster than the cost of testing each device tier | — | Stay in the cloud |

Pin the eval suites, since the platform models cannot be pinned, and re-run them on every model generation. Review placement about twice a year.

## Routing and egress

- **Egress is a policy.** Each feature gets one routing mode from its data class (local-only, prefer-local, prefer-remote, remote-only), and the interface says when data leaves the device and who processes it.
- **Every escalation is egress**, including personal context an on-device orchestrator adds to a remote prompt: minimize locally first.
- **Patterns, by the invariant each keeps**: device-first with escalation on a measured gap (privacy and cost by default) · user-initiated escalation (privacy unless asked) · degrade to a smaller local model, never the cloud (privacy as an invariant) · device as sensor, remote as reasoner, with perception and redaction local (minimization) · a decision tier next to the data that gates every event and stays safe when the remote tier is late or offline (latency and resilience).
- **One output contract across tiers.** The schema binds every eligible tier, with one encoding for abstain and refusal; a tier that lacks a capability the task needs is ineligible, and the contract is never loosened to fit the weakest. Prompts are per-route artifacts. Every response carries provenance (route, model id and version where observable); branch on the route, never on the model's self-reported identity.

## Availability is a runtime state

- **Never block the core flow on a model.** Ship the baseline first; enable the local path only after detection succeeds for the exact options the feature needs. First use (download, warm-up) is its own state, entered on clear intent, with consent for large downloads.
- **States, each with a designed screen and a route**: unsupported · disabled by the user · downloadable, downloading, preparing · ready · busy or rate-limited · quota exhausted · blocked in the background · evicted mid-session · input too long · unsupported language · refused · remote offline. Re-check at launch and on return to the foreground: states regress after updates and under storage pressure.
- **Detect by capability**, never by device name or user agent, and query only the options you will use; probing others can trigger downloads.
- **Budget from the runtime on the lowest supported device, not the model card.** Read the model variant and its context window at run time, since they differ per device, and count tokens per language. Where a platform model is foreground-only or quota-limited, background and bulk work goes to an app-shipped model or a server job.
- **Keep a path that works without GPU acceleration.** Browser GPU support is still missing on some widely sold phone chipsets.

## Client model lifecycle

- **A platform model is an unversioned dependency.** It changes with OS releases and differs per device. Record the observed model id, variant and version on every inference; keep prompt variants per version where behavior differs; run golden and safety suites on pre-release OS and browser channels; where the version is hidden, re-run on a schedule.
- **App-delivered weights**: a channel that versions models apart from the app binary (not every store offers one) lets them ship and roll back alone, and makes you own the compatibility of app code × runtime × prompt template × model artifact. Encode it in a manifest per artifact and refuse to load a mismatch. Verify integrity before loading, roll out in stages with a remote kill switch, and keep the last-known-good artifact until the new one passes an on-device smoke eval.
- **Config under server control** (model ids, thresholds, prompt templates, deny-lists) with safe defaults compiled in. Config for a local path still lands on the device: it buys update speed, not secrecy.

## The client is untrusted

- **Shipped weights, prompts and outputs can be extracted, read and forged.** A system prompt is neither a secret nor a control.
- **Client inference is advisory; the server is authoritative.** Anything that affects other users, money, safety, ranking, entitlements or permissions is decided, or re-run, on the server. *Break when* the output is private to the requesting user and has no downstream effect.
- **Nothing secret on the client**, and never a provider key. Every client-reachable model endpoint, the hybrid fallback included, goes through your authenticated backend or requires device attestation plus per-user quotas.
- **Moderation follows publication**: locally generated content shown to others is moderated server-side.

## Cost & energy

- **Local inference moves cost; it does not remove it**: eligible share × local cost (battery, storage, an eval matrix, two code paths) + ineligible share × remote cost + abuse exposure of the fallback endpoint.
- **Where a platform subsidizes a remote tier**, verify its quotas at design time and design the quota-exhausted state before launch.
- **Run local inference on explicit intent**, never speculatively in the background. Near-zero marginal cost invites always-on loops: cap total consumption alongside battery budgets, and defer batch work to when the device is charging.
- **Measure energy per task and thermal throttling** over sustained sessions on low- and mid-tier devices: throughput can halve within a few runs, and a phone uses more energy per token than a batched server.

## Evals & telemetry

- **The eval matrix is the release gate**: task × tier × model version (pre-release included) × device class, the lowest supported mandatory × language. Measure quality, time to first token, cold start, peak memory, energy and failure rate per availability state, on the exact artifact (quantized file plus runtime version), never the model card.
- **Local-path telemetry is content-free**: route, observed model version, availability state at first use, fallback reason, latency, error class, and the eligibility funnel (eligible → enabled → ready → served locally). Content only from explicit feedback or opt-in.

## Red flags

- 🔴 A feature sold as on-device or private while a fallback silently goes remote, or an "on-device" API assumed to run locally.
- 🔴 The server trusts a client verdict, or a rule enforced in a client prompt.
- 🔴 A provider key or proprietary prompt on the client, or a client-reachable model endpoint with no quota.
- 🟠 A platform model treated as a pinned dependency: no observed-version telemetry, no per-version evals.
- 🟠 Validated on flagships only, or on the model card instead of the artifact.
- 🟠 The core flow waits on a model's download, availability or warm-up.
