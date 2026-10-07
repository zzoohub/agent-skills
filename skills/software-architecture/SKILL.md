---
name: software-architecture
description: |
  Architecture docs (context, system design, ADRs, risks) in three modes.
  Build Mode: a new system from a PRD, or an existing one evolved (as-is
  recovery, re-architecture, modernization, system migration).
  Review / Diagnose Mode: audit an existing architecture from docs or code,
  read-only by default. AI Feature Mode: one AI/LLM feature on a new or
  existing system.
  Use when: "design doc", "system design", "software architecture",
  "architect this", "how should I build this", "ATAM", "quality attributes",
  "threat model", "domain model", "modernize", "re-architect", "strangler",
  "transition plan", "audit our architecture"; AI: RAG, agents, tool use,
  evals, LLM cost/latency, on-device AI.
  Do NOT use for: one decision on an existing system (arch-decision); table
  schemas, indexes or schema-migration scripts (database-design); execution
  review of a locked design doc (plan-review); folder/code conventions; UI
  component trees (ux-design, design-system); provider SDK mechanics; model
  training or fine-tuning.
---

# Software Architecture

## Premise

Architecture for **system correctness**, not for persuasion.

- **Strengthen**: Logical rigor of decisions, context-restorable structure, fitness functions as automated reviewers
- **Eliminate**: Redundant ceremony — sections, diagrams, and documents that don't inform decisions

Great architecture documents are **decision records, not implementation manuals**. Every section must answer *why* a choice was made, not just *what* was chosen. If there are no trade-offs to discuss, the section doesn't belong.

**The 6-Month Test**: after six months away, can you read the docs and start a change within 10 minutes? Then they are good enough.

## Modes & Routing

- **Build Mode** (default): the Design Flow, for a new system from its requirements or an existing system's evolution.
- **[Review / Diagnose Mode](#review--diagnose-mode)**: audit an existing architecture (its docs, else its code); critique by default, edits only on request.
- **[AI Feature Mode](#ai-feature-mode)**: one AI/LLM feature on a new or existing system; writes that feature's doc.

**Route by intent and state.** Signals: the context doc, and implementation presence (build or deploy files, a schema, a source tree, or the caller says so). The greenfield sentinel is the context doc (default `docs/arch/context.md`) — not the `docs/arch/` directory, which a database-design pass may have created on its own.

| State | Design, extend | Re-architect, modernize, system migration | Review, audit | One decision or option comparison | One AI feature |
|---|---|---|---|---|---|
| No doc, no code | Build, greenfield | — | Ask what to review | Answer inline in ADR shape; a Proposed ADR only if a docs root exists or the caller asks; never a full pass | AI Feature Mode; missing system context is a gap |
| Code, no doc | Recover as-is → Build on existing system | Recover as-is → Build on existing system + Transition Plan | Recover as-is → Review, returning the as-is with the findings | Recover what it touches → ADR via `arch-decision` | Recover what it touches → AI Feature Mode |
| Doc exists | Build on existing system (patch) | Build on existing system + Transition Plan | Review | ADR via `arch-decision` | AI Feature Mode |

**Scope.** Architecture-level decisions only, including API philosophy, observability strategy and the strategy for moving or splitting a system's data (Transition Plan); endpoint catalogs, folder layout and code conventions are out. Table schemas, indexes and schema-migration scripts → `database-design`; execution review of a just-locked design → `plan-review` (fitness and docs↔code drift stay with Review). Sibling skills named in this file are used if available. Spanning requests run Build → `database-design` → AI Feature Mode with one report; when AI is the core subdomain or takes consequential actions, `references/ai/protocol.md` steps 1–5 run inside Stages 2–4.

**Build Mode on an existing system** patches, never regenerates. If docs exist, drift-check their load-bearing claims first (Review step 3) and recover what drifted. Re-enter at the earliest stage whose inputs the change alters: a re-architecture, system migration or new business, regulatory or placement driver re-runs Stage 0 (re-calibrate; ask what the request cannot hold) and Stage 1 (the problem behind the requested solution; measured envelope; placement), patching context §1–§2 and §5–§6 before appending ASR deltas; an extension with no new driver re-enters at Stage 2. Later stages run only for the contexts the change touches; patch named sections in place; number ADRs from the directory's current max; supersede, never edit, reversed ADRs. Recovering the as-is, and where it lives: `references/evolution.md`.

**Ownership.** This skill writes only under the architecture docs root (default `docs/arch/`). Read the PRD and brief; never edit them or any other owner's docs — a missing or wrong input becomes a gap in your summary.

**After a Build pass**, audit the ADR directory against design-flow § Minimum ADRs and gap-fill only the foundational decisions the design settled but did not record (at Lite rigor, one-way doors only), via `arch-decision`: most foundational first, never duplicating ADRs the pass already wrote.

**Report back** a short summary, not the document contents: files created/updated; rigor; key decisions (technology baseline, architecture pattern, database); spikes owed; open questions and assumptions for the caller to relay; on a first Build pass, a proposed 3-line pointer for the project conventions file (load `context.md` first; `system.md` for implementation; decisions as ADRs); a 2-3 sentence summary. For a review, replace key decisions with the severity-ranked findings (Critical/High/Medium/Low, 🔴/🟠/🟡/🟢). Push back both ways: simple CRUD doesn't need event sourcing; concurrent financial transactions need explicit concurrency design.

## Stage 0 — Classification & Calibration

**Read first**, by path (defaults; caller may redirect): the requirements, meaning the PRD (`docs/prd/prd.md`), feature specs (`docs/prd/features/*.md`) and product brief (`docs/prd/product-brief.md`) if present, or the strategy memo, issue or change request the caller names; then the project conventions file, existing code and config. With no requirements source, ask the caller where it lives rather than halting.

**Ask once, in one batch, only what the requirements cannot hold and a one-way door depends on**: mandated platforms, regions and jurisdictions, team and operating model, compliance regime, budget, safety standards. Give each question the default you will otherwise assume and the sections it gates. A subagent that cannot prompt applies the defaults provisionally, marks the dependent `A-nn` assumptions and lists the questions in its report.

**Classify each deployable unit** (a system may span several types) and mark it **operated** (you run it), **shipped** (others run it) or **fleet** (devices you update remotely); design-flow § Release Model says what each implies.

| Type | Forcing question |
|---|---|
| Web application | What renders where, and what are the session and cache models? |
| API service | Who consumes it, and how does a breaking change ship? |
| Library / SDK / CLI | What is the public contract, and how does it evolve without breaking users? |
| Data pipeline | What happens to a record that fails mid-pipeline, and is every stage idempotent on replay? |
| Mobile app | What works offline, for how long, and how do conflicting edits merge? |
| Desktop app | How do updates reach users, and which old versions must the backend still serve? |
| Game | Is the client or the server authoritative, and what tick and latency budget follows? |
| Embedded / IoT | What must keep working with zero connectivity, for how long, and what happens if an update fails mid-install? |

**Calibrate**, one line each in `context.md` §2 ("none" is an answer):
- **Load & latency**: load sources and units, data volume, latency targets.
- **Placement**: residency, on-prem or air-gapped sites, edge or offline clients, user geography.
- **Exposure**: internal, authenticated or public; untrusted input; money movement.
- **Criticality**: cost of an hour down and of lost data; contractual availability; invariants at stake.
- **Data sensitivity**: none, personal, sensitive or regulated (name the regime).
- **Tenancy**: single or multi; the isolation promised.
- **Run model**: per unit, who operates it, who is on call, release cadence.
- **Teams**: how many, and expected growth.
- **External consumers**: public API or SDK, partners, file formats.
- **Reach**: locales, devices, networks, offline use, accessibility duties.
- **Hazard**: can an action or omission harm people or property?
- **Usage-priced dependencies**: metered inputs and margin pressure.
- **AI**: decisions it owns (any about people?), tools and autonomy, untrusted or personal data in context, user-facing volume, client-side inference.
- **Lifespan & phase**: prototype, product or platform.
- **Top-3 risks**: failure scenarios with numbers ("checkout p99 > 5 s at peak").

These set **rigor** and each perspective's **depth** (rules: design-flow § Perspectives).

## Design Flow Overview

| Stage | Name | Output |
|---|---|---|
| — | As-is Recovery (existing systems) | `as-is.md`, or `context.md` + `system.md` |
| 0 | Classification & Calibration | `context.md` header, §2, §5–§6 |
| 1 | Problem Definition | `context.md` §1–§2, §5–§6 |
| 2 | ASR Extraction & Utility Tree | `context.md` §3 |
| 3 | Domain Model | `context.md` §4 |
| 4 | Pattern Selection & ATAM Gate | `system.md` §1, ADRs |
| 5 | Component Design | `system.md` §2 (+ §1 service pattern), `context.md` §5 baseline |
| 6 | Data Architecture | `system.md` §3 |
| 7 | Deployment | `system.md` §4 |
| 8 | Cross-cutting Concerns | `system.md` §5 |
| 9 | ADR & Risk Review | `adr/`, `risks.md` |

Stages 1–9: `references/design-flow.md`, header first.

## Output Structure

Default paths; the caller may redirect the `docs/arch/` root.

| File | Holds | Template |
|---|---|---|
| `docs/arch/context.md` | What and why | `templates/context.md` |
| `docs/arch/system.md` | How | `templates/system.md` |
| `docs/arch/adr/ADR-NNN-{slug}.md` | One decision per file | `templates/adr.md` |
| `docs/arch/risks.md` | Risk Register, Tech Debt, Open Questions | `templates/risks.md` |
| `docs/arch/ai-features/{feature}.md` | One AI feature, ≤ 200 lines | `references/ai/protocol.md` |
| `docs/arch/as-is.md` | Recovered as-is during a re-architecture, modernization or system migration | `references/evolution.md` |

**Line caps** (`context.md` 400, `system.md` 600, `risks.md` 400 lines): check before updating and, over the cap, **consolidate** (merge redundant sections, tighten wording, remove resolved items), trusting version-control history. ADRs are exempt: one file per decision, superseded rather than rewritten, numbered in a namespace shared with `arch-decision`.

## Writing Style

- **Direct and opinionated.** State what you chose and why; put confidence in fields (assumption confidence, door type), not hedged prose.
- **Trade-offs over descriptions.** Name what each choice gains and gives up.
- **Concrete over abstract.** "A per-tenant read-through cache, 15-minute TTL, stale-while-revalidate" beats "a caching layer". Name a version only where the decision rests on one — the current supported line.
- **Diagrams as code, in C4 notation.** System Context always, Container at Full rigor, deployment and dynamic views when a perspective needs them; trust boundaries marked; the notation the project (or an adopted house profile) names, else any text-based one.
- **Evidence over reputation.** Justify choices with this system's numbers. Cite precedent only together with the condition that made it work; never for credibility.
- **No filler.** If you catch yourself writing "it is important to note that", delete it. IDs only where another line cites them.
- **Write for the reader, not the method.** Never narrate this skill's machinery in docs or reports — gate names, rule quotes, calibration lists, self-review tallies. Reviews lead with findings; patch text only for 🔴/🟠 unless asked.

## Self-Review

Before finalizing, verify. Skip any item whose perspective is skipped in Perspective Coverage.

- Every `[H,H]` driver is a six-part scenario with an ATAM row (evidence; risk or non-risk); every `[H,·]` scenario has a standing guard, found by its QA id.
- Every `[H,H]` QA id is in at least one ADR's `Drivers` and one guard; every one-way-door ADR has a `Confirmation`; no one-way door rests on a low-confidence assumption without a scheduled spike.
- Envelope computed (measured, if the system runs); scale class and placement constraints recorded; every escalation cites an envelope number or a non-scale driver.
- Perspective Coverage complete; every skip has a reason.
- Technology baseline stated with its source; deviations, and one-way-door sourcing choices either way, have ADRs.
- Every external dependency has a deadline, one budgeted retry layer, isolation and an exercised degradation path.
- Every write that must not be lost or duplicated has a write-path decision (`system.md` §5).
- Every personal or regulated data set has an owner, class, retention, an erasure path reaching every copy, and residency.
- Every `Revisit when` names a variable and a threshold.
- Existing system: each transition step states the driver levels it holds, its exit fitness function and its rollback trigger.
- Operated or usage-priced: cost per unit of value at two load levels, plus idle cost.
- AI present: the self-review gate in `references/ai/protocol.md` passes.
- **Footprint**: every section earns its place; a light perspective is one line; at Lite, both docs fit about 2,000 words — cut subsections first, keep the specifics.
- The docs pass the [6-Month Test](#premise).

## Review / Diagnose Mode

Trigger: the context doc or an implementation exists, and the intent is to review, audit or diagnose rather than build.

**Hard rule — never regenerate.** Do NOT run the Design Flow and do NOT rewrite the context or system doc wholesale. A review that silently overwrites the design it was asked to critique is a failure. **By default write nothing**: return each finding with its proposed disposition and patch text. When the caller asks you to apply them, the only writes allowed are:

- **Targeted patch** of a specific, named defect, in place — and only after you have stated the finding it fixes. One surgical edit per finding, never a section-wide rewrite or a "consolidate" pass.
- **Additive append** to the Risk Register or Open Questions in `risks.md`.
- **A new ADR** via a standalone-ADR capability (e.g. the `arch-decision` skill, if available).

If the user wants a redesign rather than an audit, say so, then switch to Build Mode on an existing system, never a regeneration from the PRD.

### Procedure

1. **Read** the architecture docs root (default `docs/arch/`; caller may redirect): `context.md`, `system.md`, `risks.md`, `adr/`, `ai-features/`, `as-is.md`, and `database.md` (read-only) if present. With no docs, recover the as-is (`references/evolution.md`) and set rigor from it.
2. **Audit** against Self-Review, Perspective Coverage at the depth each trigger demands, ATAM evidence quality and `references/review-lens.md`; apply the AI gate to each feature doc.
3. **Drift check**: if an implementation exists alongside the docs (e.g. an `apps/` or `src/` tree), sample-verify the load-bearing claims: declared containers exist, the declared service pattern shows in the code layout, declared fitness functions run in CI. During a transition, compare against the live Transition Plan step. Behavior-changing config (prompts, model settings, flags) passes the same gates as code; declared fallbacks are exercised. Docs↔code drift on a load-bearing claim is a finding (🟠 by default), whichever side is wrong.
4. **Fired triggers**: test every `Revisit when`, Scaling Ladder trigger and `context.md` §6 assumption against operational evidence (SLO history, incidents, cost trend, load vs the envelope). A fired trigger without a follow-up ADR is 🟠; a repeatedly breached `[H,H]` driver is 🔴; an invalidated assumption lists the ADRs resting on it. With no evidence, an Open Question names what is needed.
5. **Rank** every finding with the rubric below.
6. **Disposition** each finding (proposed by default; applied on request): 🔴/🟠 fixable now and unambiguous → targeted patch to the affected doc; accepted risk or won't-fix → Risk Register; needs user input → Open Questions; implies a new decision → new ADR via `arch-decision`.

**Never** create a separate `review.md` — findings live in the docs they concern. Return a severity-ranked summary of what you found and, if asked, applied.

### Severity rubric

- 🔴 **Critical**: correctness, security or data loss; ATAM gate failure; an `[H,H]` ASR from the utility tree has no covering pattern; unlawful or unlisted processing of regulated data, or regulated data with no erasure path; cross-tenant exposure; a safety function that can be disabled.
- 🟠 **High**: deviates from a recorded ADR without justification; docs↔code drift on a load-bearing claim; an external dependency missing a timeout, retry or degradation strategy; an N+1 or thundering herd baked into the data flow; an unexercised fallback on a critical path; a published contract with no compatibility policy; a required item missing without a recorded reason.
- 🟡 **Medium**: structural improvement; a doc gap that fails the 6-Month Test.
- 🟢 **Low**: wording, nits, optional consistency fixes.

For data-model and schema findings, also apply the schema-review checklist from a database-design capability (e.g. the `database-design` skill's "When Reviewing an Existing Schema" checklist, if available) rather than re-deriving criteria here.

## AI Feature Mode

Design **one AI/LLM feature** (chatbot, copilot, agent, retrieval, classification, extraction), including whether to use a model at all, workflow vs agent, and evals: provider-neutral design and operational planning, not SDK code.

**Works on a new or existing system**: one feature per run, written to the AI feature doc (default `docs/arch/ai-features/{feature}.md`; caller may redirect). An existing context doc does **not** route this request to `arch-decision`. Standalone, it writes only that feature file and records any architecture-surface change (new container, store, provider or trust boundary) as an ADR via `arch-decision`. In a combined run it adopts Build's decisions and ADRs, completes the remaining steps, and may patch docs written earlier in that run; Build itself records only the system-level AI slots.

**Method**: follow `references/ai/protocol.md` and the `references/ai/` files its steps name; write the doc from its 8-section template (≤ 200 lines) and pass its self-review gate. A **light** feature (defined in `references/ai/protocol.md` § Depth: light or deep) skips the evals, security and production files and applies its minimum gate. Link the originating feature spec (default `docs/prd/features/{feature}.md`), if any.

**Report back** files created/updated; shape and model tier (or the spike that will choose it); autonomy level; release gate; envelope vs the cost ceiling; ADRs recorded or requested; spikes owed; open questions for the caller to relay.

## Reference Files

| File | Read when | Owns |
|---|---|---|
| `references/design-flow.md` | Build: first. Review: criteria | Stages 1–9: perspectives, ATAM gate, technology baseline, data inventory, guards, Minimum ADRs |
| `templates/*.md` | Writing or patching that file | Output structure; section numbers other skills read |
| `references/evolution.md` | Existing system: recovery, re-architecture, modernization, system migration | As-is recovery and where it lives; Transition Plan method |
| `references/review-lens.md` | Review only | Questions, red flags with default severity, failure modes, smells |
| `references/system-architecture.md` | Pattern selection; topology, tenancy, contract evolution | Patterns, Deployment Topology, Multi-Tenancy, API Versioning Strategy, Feature Flag Architecture |
| `references/service-architecture.md` | Internal structure | Style per context, tactical rules, Strategic Context Mapping |
| `references/security-privacy.md` | Security or Privacy & compliance light or deep | Threat modeling, principals, keys, supply chain, data duties, compliance evidence |
| `references/reliability-patterns.md` | Writes that must not be lost, duplicated or interleaved | Transactions, idempotency, outbox, concurrency, offline writers |
| `references/operational-patterns.md` | Resilience, overload, jobs, caching, webhooks, rate limits | Dependency protection, Durable Execution, Pagination Strategy |
| `references/observability.md` | Stage 8: what you operate; diagnosability for software others run | Instrumentation, sampling, cardinality, burn-rate alerts, health checks |
| `references/house-stack.md` | Only if the project adopts this house profile (the project conventions or the caller say so; caller may redirect or omit) | One swappable house profile |
| `references/ai/protocol.md` | Any AI | AI inputs, Build-mode hooks, steps, feature-doc template, self-review gate |
| `references/ai/evals.md`, `references/ai/security.md`, `references/ai/production.md` | AI perspective deep | Evals; AI threats, authority, governance; envelope, limits, caching, routing, AI SLIs |
| `references/ai/context.md` | Retrieval, memory or long sessions | Retrieval, index lifecycle, context budget, memory |
| `references/ai/agentic.md` | Tools or agents | Tool design, harness, multi-agent, oversight |
| `references/ai/placement.md` | Inference could run on a client | Client tiers, fallback chains, client model lifecycle and trust |
