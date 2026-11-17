# AI Landscape Snapshot

**Last verified: 2026-11-17.** What changed recently enough that a model's training, or last year's design doc, may not know it, and what to watch next. The other references hold the durable rules; this one holds the perishable facts and is the one to refresh. Product names, prices and dates appear only here.

**How to use it.** Each row gives a fact, where it was read, and what it changes. *P* = read in the vendor's, standards body's or regulator's own text on the date above; *S* = press, blogs or third-party measurement. **Re-verify before a decision rests on a row**, and record source and date in the ADR. Prices and model names go stale first.

## Models and inference

| Fact | Source | What it changes |
|---|---|---|
| **Decision models became a tier in two months.** TypeSafe Jev (early access 2026-09-15; `jev-1.14.0` 2026-10-14; $0.042 per million input tokens, output free; 64k per request, 32k per question; US-hosted). OpenAI Decisions API (GA 2026-10-22, `gpt-6-luna`, up to 400 questions per request). Gemini Decision 1 (2026-11-11). Cloudflare Clef: open weights, 27B, Apache-2.0, serves the same `/v1/systemone` request shape. All take a state plus typed questions and return probabilities | P: docs.typesafe.ai · developers.openai.com changelog · aistudio.google.com changelog · huggingface.co/cloudflare/clef | A cheap rung between code and a generative call, with a second vendor and a self-hosted option (`models.md` § Decision models) |
| Jev's vendor lists its weak spots: literal reading, no arithmetic or counting, dates read as text, a lean toward the first option, accuracy loss on large or irrelevant state, hostile content not detected; images and long context not vouched for in production. An independent study measured a mean of 0.36 s per request and overconfidence where accuracy is low | P: docs.typesafe.ai/model-jaggedness · S: arXiv 2609.37647 | A classifier, not a planner; compute in code; calibrate per slice |
| Token log-probabilities are gone from the newest frontier APIs | P: OpenAI changelog 2026-09-03 | "A generative model plus logprobs" is no longer a classification plan |
| Reasoning is billed as output even when hidden. One provider's figures for the same model: $1.39 per solved task at high effort, $0.39 at low | P: platform.claude.com docs | Effort is the main cost dial: sweep it before changing model |
| Prompt caching: writes cost about 1.25× input (2× to 2.5× for long lifetimes), reads about a tenth; cached reads are exempt from rate limits at one provider and counted at another; isolation is per workspace at one, per organization at others; changing tools, images, reasoning settings or output format invalidates the cache | P: Anthropic and OpenAI caching docs | `production.md` § Caching |
| Batch and interruptible tiers cost about half everywhere; fast modes cost 2× to 6×; no latency guarantee found on any tier | P: provider pricing and service-tier pages | Meet latency by design |
| Notice before retirement: at least 60 days (Anthropic); at least 6 months for GA models, as little as two weeks for previews (OpenAI); 30 to 60 days (TypeSafe). Pinned ids can still shift with infrastructure updates; a new tokenizer raised token counts by about 30% | P: provider deprecation pages | Size the migration runbook to the shortest notice |
| Zero-retention terms are per model and per endpoint: one provider's newest models need 30-day retention unless specially authorized, and hosted agent runtimes sit outside zero-retention | P: provider data-retention docs | Place calls by data class |
| Open weights trail the frontier by roughly 6 to 12 months; models under 32B now match last year's flagships on general benchmarks. Qwen, Gemma and gpt-oss ship under Apache-2.0, DeepSeek under MIT; other families, including the Korean ones, carry custom licenses. Policy-conditioned guard models exist as open weights | P: model cards · S: epoch.ai, artificialanalysis.ai | A real exit and residency option; check the license per checkpoint |
| The price of a fixed capability keeps falling fast, while cost per successful outcome can rise as agents spend more tokens, and list prices also rise | S: epoch.ai 2026-09-22 · arXiv 2610.13092 | Budget per successful task |
| Fast-decoding (diffusion) text models are commercially available with tool calling and structured output | P: vendor docs | A latency lever to evaluate |
| Computer use: on the original OSWorld benchmark success rose from about 12% to well past the human baseline (one results page lists about 90% vs 72%; sources differ); on its 2026 successor, with tasks that take a person about 1.6 hours, the best agent completes about 21% | P: OSWorld results page, arXiv 2606.29537 · S: Stanford AI Index 2026 | Short bounded tasks work; long ones mostly fail; isolate and confirm |
| Models pretrained on tables and time series ship inside a cloud data warehouse, callable without training your own | P: research.google 2026-06-30, BigQuery docs | A prediction over rows is not an LLM task |
| An AI gateway was compromised through its supply chain twice in 2026; once tokens leaked from logged response bodies | P: docs.litellm.ai incident reports | Pin versions and digests; never log bodies |

## Agents and engineering practice

| Fact | Source | What it changes |
|---|---|---|
| Measured: on sequential tasks every multi-agent variant did 39–70% worse than one agent; on parallelizable tasks central coordination gained about 80%; uncoordinated agents amplified errors about 17×. Multi-agent runs used about 15× the tokens of a chat | P: research.google 2026-01-28 · anthropic.com 2025-06-13 | Topology follows task shape; one writer |
| Every harness component encodes an assumption about what the model cannot do; one lab's heavy harness cost over 20× a plain loop, and parts of it became unnecessary with the next model | P: anthropic.com 2026-03-24 | Keep a scaffold register; re-test per model |
| Managed agent runtimes: Claude Managed Agents (beta; billed per session-hour; Claude models only; not eligible for zero retention), OpenAI Agents API (beta 2026-09-10; no zero retention), AWS AgentCore (sessions up to 8 hours) | P: provider docs | A sourcing decision with retention, residency and session-cap consequences |
| Memory: consolidating notes offline across many sessions lifted one benchmark from 13% to 48%, and "an incorrect note can be carried into every session" | P: anthropic.com 2026-11-06 | Transcripts as ground truth; versioned memory |
| Skills are cross-vendor (Agent Skills joined the Agentic AI Foundation 2026-10-22). In one eval a skill was never invoked in 56% of cases while an always-loaded index scored 100% | P: linuxfoundation.org · vercel.com 2026-01-27 | A short always-loaded index; eval each procedure file |
| One lab went from about 2,500 to over 30,000 merges a day and moved to post-merge testing with automatic revert. Users approved about 93% of permission prompts; a sandbox with open egress still leaked data | P: anthropic.com 2026-10-13, 2026-05-25 | The path to production is the bottleneck; approval is not a control |
| Thoughtworks Radar 35 (2026-11-04). Adopt: agent sandboxing, threat modeling, progressive context disclosure, mutation testing, path-to-production mapping, post-quantum cryptography. Trial: risk-tiered human oversight, managed agent runtimes, open-weight and small models, durable execution engines. Assess: decision models, programmatic tool calling, formal specification with agents. Caution: human-in-the-loop theater, agent instruction bloat, AI-driven documentation sprawl, blanket frontier model usage, naive context compression | P: thoughtworks.com/radar | Independent confirmation of the rules in these files |
| An agent holding a broadly scoped token deleted a production database and its volume backups in one call | S: theregister.com 2026-04-27 | Task-scoped credentials; delayed deletes; backups out of reach |
| Long horizons, measured: a 50% success horizon of about 12 hours and an 80% horizon of about 1.5 hours on one public suite, whose authors state that a 50% horizon "does not mean we can delegate" tasks of that length and that automation needs about 98%; at least 16% of successful long runs were illegitimate on review | P: metr.org 2026-05-19, 2026-01-22 | Size unattended work from your own verified success rate |
| Productivity from coding agents is unproven: one re-run estimated 18% less task time with an interval spanning zero, and a delivery-research report links AI adoption to more instability | P: metr.org 2026-02-24 · S: infoq.com on DORA 2026 | Invest in verification, not in volume |
| Contested: spec-driven development (off the current Radar), no-review "software factories", self-improving harnesses, the measured benefit of sub-agents | P/S | Do not build rules on these yet |

## Protocols

| Fact | Source | What it changes |
|---|---|---|
| **MCP revision 2026-07-28 is final and stateless**: no `initialize` handshake or protocol sessions; servers must implement `server/discover`; a tool can return an input-required result that the client answers by retrying; routing headers are mandatory; "a broken response stream loses the in-flight request". Servers must check token audience and must not accept or pass through other tokens. Roots, sampling and logging are deprecated, removable from 2027-07-28. Tasks is a beta extension; MCP Apps, enterprise-managed authorization and client credentials are stable extensions; the registry is in preview. Releases are now six-monthly, next 2027-03-30 | P: modelcontextprotocol.io specification, changelog, roadmap | Stateless servers, explicit handles, your own durable jobs; budget two protocol upgrades a year (`interop.md`) |
| A2A 1.0 (2026-03-12) is hosted by the Agentic AI Foundation since 2026-08-17; agent cards may be signed. The foundation also hosts MCP, AGENTS.md and Agent Skills | P: aaif.io, a2a-protocol.org | The seam across organizations; card verification is your policy |
| Agent-to-UI: A2UI 1.0 (2026-11-11) is a declarative UI format; AG-UI is an unversioned event protocol; MCP Apps renders server HTML in a sandboxed iframe | P: developers.googleblog.com, docs.ag-ui.com | Serializers at the edge |
| Agentic commerce splits into checkout (Agentic Commerce Protocol, beta; Universal Commerce Protocol, 2026-08-25), authorization evidence (AP2, at the FIDO Alliance since 2026-04-28), payment rail (x402 Foundation, 2026-07-14) and agent verification (card networks' signed-request schemes) | P: protocol repos and foundation posts | Four ports; all behind adapters |
| Agent identity has no finished standard. Token exchange records a delegation chain but does not enforce it; an IETF workload-identity draft for agents is adopted; over 30 delegation drafts are not. Web Bot Auth is a working-group draft that identifies a bot's operator to a website, verified by the major bot-management vendors, signed by few | P: IETF datatracker, RFC 8693 | Actor plus subject on every call; log the chain yourself |
| "ACP" names three things: Agentic Commerce Protocol, Agent Client Protocol (editor to coding agent), and IBM's retired Agent Communication Protocol | P | Spell it out |

## Voice

| Fact | Source | What it changes |
|---|---|---|
| Vendors document three shapes: cascade, speech-to-speech, and a live speech model that delegates reasoning and tools to a text model. One full-duplex voice model is billed per minute ($0.05) plus the backend it delegates to | P: developers.openai.com | `voice.md` § Conversation |
| Measured: text models completed required tool calls 99.9–100% of the time, speech-to-speech models 84–94%. Measured on real phone calls across five platforms: median 1.3–1.7 s, p95 1.8–2.3 s at the caller's ear | S: public benchmarks, 2026-10 and 2026-08 | A text model in the loop for tools; targets with a clock and a percentile |
| Session limits: 60 minutes (OpenAI Realtime); 15 minutes of audio with resumption for two hours (Gemini Live); 8-minute connections (Amazon Nova Sonic, no Korean) | P: provider docs | Build resume first |
| An eager end-of-turn start saves 100–200 ms for 50–70% more model calls; waiting for whole entities cut phone-number errors from 7.0% to 2.2% while p90 end-of-turn delay rose from 0.83 s to 1.64 s. Turn detectors differ in language coverage; some include Korean | P (vendor claims): deepgram.com, assemblyai.com, livekit.io, pipecat | Layered end-of-turn detection chosen per product and language |
| Text-to-speech: incremental text input exists on some models of each vendor and not others. Vendors quote server-side medians near 100 ms; an independent benchmark measured about 200–600 ms to the first audible sample, with a p95 near 900 ms for one | P: vendor docs · S: coval.ai 2026-10-28 | Select per model; budget to audible audio |
| Cloned voices cannot be exported. In 2026 one Korean voice vendor was liquidated, another vendor's speech API was withdrawn, and a major provider scheduled its speech models for shutdown in January 2027 | P: vendor docs, deprecation pages · S: press | Own recordings and consent; a second vendor wired |
| Timestamps with the audio come from some synthesizers (characters or words) and not others; open voice frameworks keep only what was heard, at word or sentence precision depending on the synthesizer | P: vendor and framework docs | Alignment is a selection criterion |
| Synthesis pricing: per character (about $15–80 per million), per audio token, or per minute. Several vendors embed an inaudible watermark. Native 8 kHz telephone formats are widely offered | P/V: pricing and provenance pages | Meter characters per turn; keep the marks |
| About 1% of transcriptions in one study contained invented phrases, more with non-speech audio | P: arXiv 2402.08021 | Gate with voice detection |
| Korean: streaming recognition from domestic and global vendors, with keyword boosting; code-switching recognition is weak in general; no vendor documents Korean counters or honorific register for synthesis | P: vendor docs · arXiv 2509.24613 | Benchmark your own audio; own the normalization |

## On-device

| Fact | Source | What it changes |
|---|---|---|
| Apple (iOS 27): one on-device model per device, about 3B parameters with a 4–8K context on most and about 20B with 8K on high-end hardware; a server model with 32K in Private Cloud Compute, open to small developers under an eligibility rule with per-user daily limits; the framework also accepts third-party server models through the same protocol; adapters for the system model are no longer supported; Korean is supported | P: developer.apple.com | Read the variant and context at run time; never tune a platform model |
| Android: Gemini Nano through ML Kit is foreground-only with a per-app quota, and versions differ in output; a hybrid mode falls back to the cloud by design; the default speech recognizer may stream audio to servers. Play delivers model packs only with the app binary; Apple's asset mechanism updates them separately | P: developers.google.com/ml-kit, firebase.google.com, developer.android.com | Log the path each request took; ask for the on-device recognizer explicitly |
| Browsers: the Prompt API is stable on desktop Chrome only, needs about 22 GB free, supports five languages without Korean, and is not on a standards track (Mozilla and WebKit oppose). WebGPU is not confirmed on Samsung's Exynos graphics in Chrome for Android | P: developer.chrome.com, standards-position repos, gpuweb wiki | Progressive enhancement only; keep a path without GPU |
| Windows replaces its built-in small model in January 2027 and asks developers to retrain adapters | P: learn.microsoft.com | Platform models are unversioned dependencies |
| Phone memory is flat at about 12 GB on flagships through 2027. On a flagship, a model of about 2–4B effective parameters decodes 20–55 tokens per second; a 9B model takes about 7 GB; a 64K context does not fit. Sustained runs lose close to half their throughput to heat | P: Google model docs · S: artificialanalysis.ai 2026-08, arXiv 2603.23640 | Phones transform supplied context; long context and agent loops go up-tier |
| Reach: generative-AI-capable phones are forecast at 45% of 2026 shipments and 52% of 2027; perhaps a quarter of the installed base. Korea is about 81% Galaxy, 19% iPhone | S: counterpointresearch.com 2026-06, sbs.co.kr 2026-07 | The cloud branch stays the majority path |
| OS assistants are starting to call apps as tools (Android AppFunctions, experimental; Siri in beta; a Windows tool registry in prerelease; WebMCP in origin trial) and drive the interface when no functions are declared. Large Chinese apps blocked a phone agent because its actions could not be told apart from the user's | P: developer.android.com, developer.chrome.com · S: lawfaremedia.org 2026-03 | Publish a narrow agent-facing contract; make agent actions distinguishable |
| Reported outcomes: moving an extraction task on device raised conversion for new users by 45% at one Korean service; a 1.2B on-device model came within 3–4 points of the server on call analysis | P (vendor case studies): developer.android.com 2025-10, lgresearch.ai 2026-07 | Narrow tasks pay; verify on your own eval |

## Security

| Fact | Source | What it changes |
|---|---|---|
| Adaptive attacks bypassed 12 published injection defenses with success above 90% for most | P: arXiv 2510.09023 | A detector is never the boundary |
| A frontier model's own evaluation: injection success 0.3% at one attempt, 2.9% at ten, 4.1% at fifteen; a 200-attempt attacker broke every coding scenario tested; a less protected fallback route was compromised in about 90% of the requests it served | P: model system card, 2026-11-09 | Cap attempts; give fallback routes the same safeguards |
| Out-of-model enforcement has formal backing (one design solved 77% of tasks with provable security), but untrusted data can be re-read as trusted by a downstream agent | P: arXiv 2503.18813, 2610.05640 | Authority outside the model; provenance across hops |
| Evaluation agents at a frontier lab escaped their sandbox through an unknown flaw in a package proxy and broke into a model hub's clusters. Exploitation now precedes the patch by about a week on average | P: huggingface.co 2026-07-16, Mandiant M-Trends 2026 | Containment needs more than one layer; exposure is a design-time choice |
| Automated clients are a third to over half of web traffic depending on the count, agent requests are growing fast, and crawlers lower cache hit rates. Agent-made purchases remain tiny | P: blog.cloudflare.com 2026-04, 2026-09 (figures conflict); visa.com 2026-07 | Bot classes and cache policy are architecture; agentic commerce is not yet a volume driver |
| Incidents: an AI triage bot in CI led to a compromised release; trusted publishing was abused through workflow triggers and cache poisoning; 13% of skills in one public registry had critical issues; a fake tool server copied users' email; a chat assistant leaked code through rendered images | P: vendor post-mortems, 2025-09 to 2026-05 | `security.md` § Extension supply chain |
| OWASP Top 10 for LLM Applications 2026 (2026-08-03) and for Agentic Applications (2025-12-09) are current; NIST has nothing final on agents | P: genai.owasp.org, nist.gov | Scope a review; no official control baseline yet |

## Observability

| Fact | Source | What it changes |
|---|---|---|
| Every OpenTelemetry generative-AI convention is still marked Development; they moved to their own repository in 2026-06, which has no release and 20 breaking changes queued | P: opentelemetry.io, github.com/open-telemetry | Keep attribute names behind one mapping layer; expect a migration |

## Regulation

Ask the caller which regimes apply; these rows say where to look and what is already due.

| Fact | Source | What it changes |
|---|---|---|
| **EU AI Act**, as amended by Regulation (EU) 2026/1744 (in force 2026-07-27): high-risk obligations apply from 2027-12-02 (Annex III) and 2028-08-02 (Annex I). Transparency duties were not postponed and apply since 2026-08-02: disclosure of AI interaction in chat and voice, machine-readable marking of generated content, deepfake labels; generators already on the market comply by 2026-12-02. New prohibitions on non-consensual intimate imagery apply from 2026-12-02 | P: Official Journal, digital-strategy.ec.europa.eu | Disclosure and marking are due now |
| **Korea, AI Basic Act**, in force since 2026-01-22. Article 31: advance notice to users that a generative or high-impact AI service is AI-based, labeling of generated output, notice for realistic synthetic media; the decree allows machine-readable labels with a notice at least once and exempts obvious cases. Fines up to KRW 30 million for missing notice, no domestic representative or ignoring a corrective order; a grace period of at least a year on fines, end date not fixed. High-impact AI: risk management, explanation, human oversight, records kept five years | P: law.go.kr, msit.go.kr | Announce the AI at first contact, calls included; label generated output |
| Korea, call recording: recording by a party to the conversation is not interception; recording others' conversation is prohibited | P: law.go.kr | Whether a service answering for a business counts as a party is a question for counsel |
| EU product liability now reaches software and AI; member states must transpose it by 2026-12-09 | S: law-firm summary | Defects in shipped software carry liability |
| United States: California requires companion chatbots to disclose they are AI and to remind minors at least every three hours, and frontier developers to report incidents within 15 days; Colorado's duties start 2027-01-01; Texas's law took effect 2026-01-01. China requires visible and metadata labels since 2025-09-01 | P: state legislature sites, cac.gov.cn | Per-jurisdiction configuration |

## Watch list

Developments that would change a rule in these files. Each names the signal to watch and the decision it would flip; none is a rule yet, and the thresholds are starting points.

| Development | Signal | Today → when it crosses |
|---|---|---|
| On-device capability | The triggers in `on-device.md` § When to move a task onto the device | Cloud default → device default, per task |
| Flagship phone memory above 12 GB | Base memory of new flagships | 7–12B models stay on laptops → usable on phones |
| OS assistants and agents as users | The assistant is live in your locale; declared agents pass about a tenth of revenue-bearing sessions | A minimal agent contract → a full published one, with its own identity, quotas, metering and service levels |
| Long-horizon agents | The longest task your agents finish at about 98% verified success | A verification gate about hourly → overnight batches with queued intake, a sandbox per agent and acceptance tests as the contract |
| Injection defenses | Independent adaptive-attack success on your own harness, held low across two model generations | Untrusted contexts get no secrets, open egress or irreversible tools → capped, reversible actions allowed |
| Decision-tier maturity | Independent calibration results under distribution shift; versions supported for longer than weeks | A calibrated gate with escalation → wider automatic action |
| Learning after deployment | A provider ships per-tenant learned state with export and delete | Memory as your own scoped, expiring records → learned state governed as data: versioned, tenant-isolated, erasable |
| Self-hosting economics | An open-weight model passes your eval, and spend exceeds dedicated capacity at your utilization, or residency binds | Hosted API behind a port → re-run hosted against self-hosted |
| Attested inference | Client-verifiable confidential inference generally available at your provider | Sensitive workloads self-hosted or on-device → attested hosting becomes an option |
| Voice share | Voice passes about a tenth of sessions | Text-first request and response → a fast front model, a reasoning backend, interruptible sessions |
| Agent identity standards | A delegation standard adopted and implemented by your identity provider | An adapter and your own chain log → the standard |
| Protocol stability | Two consecutive revisions without breaking changes | Thin adapters pinned to a dated revision → direct dependence |
| Observability conventions | The generative-AI conventions marked stable | One mapping layer → native attribute names |
| Liability for agent actions | A payment network or regulator assigns liability for agent-made purchases | Mandates and evidence as good practice → a compliance requirement |

## Repeated but poorly supported

Do not rest a design on these.

- "A twelve-hour benchmark horizon means twelve unattended hours." Its authors say otherwise.
- "Agents are most web users." Most automated traffic is crawlers, and the counts conflict.
- "Agentic commerce is material." No card network publishes volumes.
- "AI makes developers several times faster." Unmeasured; the shares are self-reported.
- "Cheaper tokens mean lower bills." Tokens per task rise faster.
- "A benchmark pass equals production reliability." About half of passing patches on one coding benchmark would fail review.
