---
name: software-architecture
description: |
  Produce a full Software Architecture Design Document from a PRD: context, system
  design, decision records, and D2 diagrams.
  Use when: "design doc", "software architecture", "system design", "architect
  this", "tech spec", "how should I build this", "what's the right architecture
  for", "help me plan the backend", "ASR", "utility tree", "domain model", "ATAM",
  "event storming", or a PRD needs technical architecture for a NEW project. Also
  trigger on AI/LLM features (RAG, agents, chat, copilot, semantic search). Also
  use to "review", "audit", or "diagnose" an EXISTING architecture, read-only (see
  Review / Diagnose Mode).
  Do NOT use for: a single architectural decision on an existing system (use
  arch-decision); table schemas, columns, indexes, or migrations (use
  database-design); folder structure, code conventions, or linting (CLAUDE.md);
  concrete UI component trees or page layouts (use ux-design + design-system);
  implementation-level LLM details like prompts, tool schemas, or evals (use
  llm-app-design).
---

# Software Architecture — Full Design Pass

Produces the **full architecture documents** for a new system from a PRD:
context, system design, decision records, and risks. Use this skill at the start of a
new project.

## Premise

Architecture for **system correctness**, not for persuasion.

- **Strengthen**: Logical rigor of decisions, context-restorable structure, fitness functions as automated reviewers
- **Eliminate**: Redundant ceremony — sections, diagrams, and documents that don't inform decisions

**The "6-Month Test"**: If you come back to this project after 6 months away, can you read the docs and understand the system well enough to start making changes within 10 minutes? If yes, it's good enough.

## Philosophy

Great architecture documents are **decision records, not implementation manuals**. Every section must answer *why* a choice was made, not just *what* was chosen. If there are no trade-offs to discuss, the section doesn't belong.

---

## Two Modes

- **Build Mode (default)** — produce or extend the full architecture from a PRD via the Design Flow below. This is everything in this file except the Review / Diagnose Mode section.
- **Review / Diagnose Mode** — a **read-only** audit of an *existing* architecture. Triggered when the architecture context doc already exists (default `docs/arch/context.md`; caller may redirect) and the user asks to review / audit / diagnose rather than build. It critiques the docs and never regenerates the context or system doc. Jump to the [Review / Diagnose Mode](#review--diagnose-mode) section and follow it instead of the Design Flow.

---

## Scope Boundaries

This skill produces architecture-level decisions. It deliberately **excludes** the following — they are separate implementation concerns:

| Excluded Topic | Reason |
|---|---|
| Table schemas, column types, indexes, migrations | Implementation detail — derived from data models in the Design Doc |
| API endpoint lists, request/response shapes | Implementation detail — derived from component interfaces in the Design Doc |
| Folder structure, code conventions, linting rules | Codebase concern — belongs in CLAUDE.md or project config |
| Concrete UI component trees, page layouts | Implementation detail — derived from system context in the Design Doc |

**Note**: API *design philosophy* and observability *strategy* are architectural decisions and ARE covered. What's excluded is the concrete endpoint catalog and boilerplate implementation code.

---

## Design Flow Overview

| Stage | Name | What It Answers | Output File |
|---|---|---|---|
| 0 | Auto-Classification | What type of software? What dimensions matter? | — |
| 1 | Problem Definition | What problem, for whom, why now, at what scale? | `docs/arch/context.md` §1-2, §5-6 |
| 2 | ASR Extraction & Utility Tree | Which quality attributes drive the architecture? | `docs/arch/context.md` §3 |
| 3 | Domain Model | What are the core concepts and boundaries? | `docs/arch/context.md` §4 |
| 4 | Pattern Selection & ATAM Gate | What patterns satisfy the architecture drivers? | `docs/arch/system.md` §1 |
| 5 | Component Design | What are the concrete components? | `docs/arch/system.md` §2 |
| 6 | Data Architecture | Where does data live, how does it flow? | `docs/arch/system.md` §3 |
| 7 | Deployment | How does code get to production? | `docs/arch/system.md` §4 |
| 8 | Cross-cutting Concerns | What properties hold across all components? | `docs/arch/system.md` §5 |
| 9 | ADR & Risk Review | Are all decisions recorded? What could go wrong? | `docs/arch/adr/`, `docs/arch/risks.md` |

**Stages 2 <-> 3 <-> 4 co-evolve**: Domain modeling reveals new ASRs, pattern selection changes domain boundaries. One iteration is usually sufficient.

**ADRs are written immediately** when decisions occur — not batched at the end.

See `references/design-flow.md` for detailed methodology for each stage.

---

## Stage 0 — Auto-Classification

**First, read the PRD by path** (defaults below; the caller may redirect to other locations):
- the PRD (default `docs/prd/prd.md`) — vision, dev order, success metrics
- per-feature requirements (default `docs/prd/features/*.md`)
- the upstream product brief (default `docs/prd/product-brief.md`), if present

If the PRD is absent at the expected path, ask the caller where it lives rather than halting.

Then analyze the PRD content and classify the software automatically. No user questions — derive everything from the PRD.

### Software Type Classification

| Type | PRD Signals | Architecture Implications |
|---|---|---|
| Web application | users, pages, dashboard, sign up | Client-server, sessions, rendering strategy |
| API service | endpoints, consumers, rate limits | Interface design, versioning, SLA |
| CLI tool | command, flags, terminal, output | Argument parsing, stdio, exit codes |
| Library/SDK | import, package, API surface | Public API, compatibility, dependency policy |
| Data pipeline | ingest, transform, ETL, batch | Throughput, fault tolerance, idempotency |
| Mobile app | iOS, Android, push, offline | Offline-first, sync strategy |
| Desktop app | native, installer, file system | Distribution, auto-update, OS integration |
| Game | real-time, state sync, tick rate | Determinism, netcode, asset pipeline |
| Embedded/IoT | device, firmware, constrained | Resource constraints, OTA, communication protocol |

> **Scope honesty**: the deep method (Stages 1-9) and reference library are shaped for **web / API / service-backed systems** (including AI features). For CLI, library/SDK, game, embedded, mobile, and desktop, Stage 0 gives you the right framing and the house-stack rows, but the downstream stages stay service-shaped — carry that type's "Architecture Implications" yourself as a checklist; they are not separately-resourced tracks.

### Architecture Dimensions (Auto-Extract)

From the PRD, extract:
- **System boundary** — what this system does vs. what's handled externally
- **Expected scale** — users, requests/sec, data volume, or "single-user tool"
- **Latency requirements** — real-time needs, p99 targets
- **Consistency model** — strong vs eventual, where
- **Deployment constraints** — target environment, distribution method
- **Regulatory/compliance** — data residency, audit requirements
- **AI/LLM features** — whether the system includes AI capabilities

If the PRD has critical gaps that block architecture decisions, note them as assumptions in the output.

---

## Output Structure

The design flow produces these output files (default paths; the caller may redirect the `docs/arch/` root):

| File | Stages | Purpose | Template |
|---|---|---|---|
| `docs/arch/context.md` | 0-3 | What and why — problem, ASRs, domain model, constraints, assumptions | `templates/context.md` |
| `docs/arch/system.md` | 4-8 | How — patterns, components, data, deployment, cross-cutting | `templates/system.md` |
| `docs/arch/adr/ADR-NNN-{slug}.md` | All | One decision per file — context, options, decision, tradeoffs | `templates/adr.md` |
| `docs/arch/risks.md` | 9 | Risk register, tech debt, open questions | `templates/risks.md` |

Read the template files before writing output. Follow their structure.

### Line limits

Before updating, check the file's line count. If it exceeds the limit,
**consolidate** — merge redundant sections, tighten wording, remove items
already resolved. Trust git history.

Exception for ADRs: each decision is its own file at `docs/arch/adr/ADR-NNN-{slug}.md`,
created fresh and never rewritten — so there is no aggregate line cap. When a decision is
superseded, set the older ADR's status to `Superseded by ADR-NNN` in its file rather than
deleting it. A standalone-ADR capability (e.g. the `arch-decision` skill, if available) records
into the same `docs/arch/adr/` directory.

| File | Limit |
|---|---|
| `docs/arch/context.md` | 400 lines |
| `docs/arch/system.md` | 600 lines |
| `docs/arch/risks.md` | 400 lines |

---

## Claude Session Guide

For future Claude sessions working on this project:

- **New session** -> always load `docs/arch/context.md` first
- **Implementation work** -> also load `docs/arch/system.md`
- **Decision point** -> write a new ADR file at `docs/arch/adr/ADR-NNN-{slug}.md` immediately

---

## Writing Style

- **Direct and opinionated**. State what you chose and why. Don't hedge excessively.
- **Trade-offs over descriptions**. Every choice should discuss what was gained and what was sacrificed.
- **Concrete over abstract**. "Redis with 15-minute TTL" beats "a caching layer."
- **Diagrams with D2**. Write D2 source directly in the doc — D2 classes give consistent styling (`person` for actors, `cylinder` for databases, `queue` for message brokers, dashed borders for system boundaries). Minimum: System Context (C4 L1) + Container (C4 L2) diagrams. If a D2 rendering tool/skill is installed, use it; otherwise leave the D2 source as-is, or fall back to Mermaid or ASCII.
- **No filler**. If you catch yourself writing "it is important to note that" — delete it.
- **Reference real-world precedent** when helpful: "Netflix uses a similar circuit-breaker pattern for their API gateway" adds credibility and context.

---

## Self-Review

Before finalizing, verify:

- [ ] Every [H,H] ASR from the utility tree has a corresponding pattern in the design
- [ ] ATAM gate passed — all [H,H] items verified against chosen patterns
- [ ] Every [H,H] ASR also has a *standing guard* — a CI fitness function or a runtime SLO alert, not just the one-time ATAM check
- [ ] Scale envelope computed from the PRD (peak RPS, data growth, working set) — and every pattern escalation cites one of its numbers or a non-scale driver
- [ ] Every generic subdomain has a sourcing decision (build / self-host / buy); each external service adopted carries an ADR naming the non-code asset it sells
- [ ] Ubiquitous language terms match code terms 1:1 *within each bounded context* (the same term may legitimately differ across contexts)
- [ ] Fitness functions defined for key architectural properties (3-5 CI checks)
- [ ] Quality targets have numbers (not "fast" or "reliable" — actual thresholds)
- [ ] Cost estimate exists for two traffic levels (baseline + growth)
- [ ] Every external dependency has a timeout, retry policy, and degradation strategy
- [ ] Data flow is traceable for the main user journey
- [ ] No section exists just because "a design doc should have it" — every section earns its place
- [ ] AI (if applicable): cost ceiling defined, guardrail layers specified, model versions pinned

**The "6-Month Test"**: Do these docs still pass the [6-Month Test](#premise) — readable enough to resume changes within 10 minutes after 6 months away?

---

## Review / Diagnose Mode

Use this mode when the user asks to **review, audit, or diagnose an existing
architecture** — not to build a new one. Trigger: the architecture context doc
(default `docs/arch/context.md`) already exists and the intent is to critique, not create.

**Hard rule — never regenerate.** Do NOT run the Design Flow and do NOT rewrite
the context or system doc wholesale. A review that silently overwrites the
design it was asked to critique is a failure. The only writes allowed are:

- **Targeted patch** of a specific, named defect, in place — and only after you
  have stated the finding it fixes. One surgical edit per finding, never a
  section-wide rewrite or a "consolidate" pass.
- **Additive append** to the Risk Register or Open Questions in `risks.md`.
- **A new ADR** via a standalone-ADR capability (e.g. the `arch-decision` skill, if available).

If the user wants a full redesign rather than an audit, stop and run Build Mode
instead — but say so explicitly first.

### Procedure

1. Read all of `docs/arch/` — `context.md`, `system.md`, `risks.md`, the ADRs
   in `adr/`, and `database.md` if it exists.
2. Audit against the **Self-Review checklist** above, the utility tree's
   `[H,H]` ASRs, and the ATAM gate. Those checklist items *are* the review
   criteria — you are checking whether the existing design still passes them.
3. **Drift check** — if an implementation exists alongside the docs (an
   `apps/` or `src/` tree), sample-verify the load-bearing claims: declared
   containers exist, the declared service pattern is visible in the code
   layout, declared fitness functions actually run in CI. Docs↔code drift on
   a load-bearing claim is a finding (🟠 by default), whichever side is wrong.
4. Rank every finding with the severity rubric below.
5. Disposition each finding:
   - 🔴 / 🟠 fixable now and unambiguous → targeted patch to the affected doc.
   - Accepted risk / won't-fix → append to the Risk Register in `risks.md`.
   - Needs user input → append to Open Questions in `risks.md`.
   - Implies a new decision → new ADR via a standalone-ADR capability (e.g. the `arch-decision` skill, if available).
6. **Never** create a separate `review.md` — findings live in the docs they
   concern. Return a severity-ranked summary of what you found and did.

### Severity rubric

- 🔴 **Critical** — correctness / security / data-loss; ATAM gate failure; an
  `[H,H]` ASR from the utility tree has no covering pattern.
- 🟠 **High** — deviates from a recorded ADR without justification; docs↔code
  drift on a load-bearing claim; an external dependency missing a timeout /
  retry / degradation strategy; an N+1 or thundering-herd baked into the data
  flow.
- 🟡 **Medium** — structural improvement; a doc gap that fails the 6-Month Test.
- 🟢 **Low** — wording, nits, optional consistency fixes.

For data-model and schema findings, also apply the schema-review checklist from a
database-design capability (e.g. the `database-design` skill's "When Reviewing an
Existing Schema" checklist, if available) rather than re-deriving criteria here.

---

## Reference Files

### Reading Order

**Always read**: `design-flow.md` + all four templates.

**Read based on Stage 0 findings**:
- Pattern selection -> `system-architecture.md`, `service-architecture.md`
- Technology selection (Stage 5, Component Design) -> `house-stack.md` (opinionated house stack; deviations need an ADR)
- AI features in PRD -> `ai-architecture.md` (+ `ai-agents.md` if agents needed)
- Cross-cutting -> `operational-patterns.md`
- Writes that must not be lost / duplicated / interleaved -> `reliability-patterns.md`
- Stage 8 (Cross-cutting Concerns) -> `observability.md`

**Skip if PRD has no AI/LLM features**: `ai-architecture.md`, `ai-agents.md`

Every reference is linked directly from here, so read only what a stage needs.
Cross-links between reference files are optional pointers for going deeper — not
a required reading chain.

### Index

| File | Content |
|---|---|
| `references/design-flow.md` | Design-flow methodology, stages 1-9 (Stage 0 lives in this SKILL.md). **Read first.** |
| `templates/*.md` | Output templates for `docs/arch/context.md`, `docs/arch/system.md`, `docs/arch/adr/`, and `docs/arch/risks.md` |
| `references/system-architecture.md` | System patterns, composition flowchart, real-world examples |
| `references/service-architecture.md` | Internal service structure: hexagonal (default), clean, vertical slice, FC/IS |
| `references/ai-architecture.md` | LLM integration, RAG, streaming, vector storage, guardrails |
| `references/ai-agents.md` | Agent patterns, protocols (MCP/A2A/AG-UI), durable execution, safety |
| `references/house-stack.md` | Opinionated, non-portable house stack (deviations need an ADR) — language/runtime, framework, infra, data, AI, services |
| `references/operational-patterns.md` | Resilience, background jobs, caching, rate limiting |
| `references/reliability-patterns.md` | Transaction boundaries, idempotency, outbox, concurrency control |
| `references/observability.md` | OpenTelemetry strategy, traces/metrics/logs, sampling, health checks |
