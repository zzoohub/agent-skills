# Review Lens

Review / Diagnose Mode only, at the audit step. Each group points to its rule's home: judge against that rule and cite the question or flag in the finding. Glyphs are default severities on the `SKILL.md` rubric; raise or lower them with blast radius and reversibility.

## Review Questions

Ask all of them in a full audit; in a scoped review, those whose perspective the change touches. A missing answer is a finding.

1. **Problem & drivers** (design-flow Stages 1–2) — What problem, for whom, with which non-goals, and which goal or stakeholder concern does each [H,H] driver serve?
2. Are the top risks failure scenarios with numbers, and do they (with lifespan and product phase) set each perspective's depth?
3. **Decisions** (`design-flow.md` § Stage 9 — ADR & Risk Review) — Which decisions are one-way doors, counting anything consumers can observe, data formats and cache sharing, and does each have an ADR with a `Confirmation` guard?
4. For each choice: what was rejected, what does it cost, and which variable and threshold would flip it?
5. Which seams and abstractions are options being paid for, and which named exit justifies each premium?
6. **Numbers & cost** (`design-flow.md` § Quantitative Envelope; § Cost & Unit Economics) — What are the numbers now and at the next order of magnitude (load in its binding unit, data, quota headroom, cost per unit of value), and could one well-built process do the job?
7. What does a successful unit of value cost for the tail user where usage is priced, and what costs money while idle?
8. **Failure & recovery** (`design-flow.md` § Resilience & Overload; `operational-patterns.md`) — When each dependency is slow, not just down, what happens, and does the system recover by itself once the trigger is gone?
9. Where exactly do retries happen, on what budget, and which errors are permanent?
10. Does any recovery step need the impaired component or a control plane, and can the system cold-start without circular dependencies?
11. What queues up during an outage, how long does it take to drain, and is that work still worth doing then?
12. Which paths run only on bad days (fallback, failover, cold cache, open breaker, restore), and when was each last exercised?
13. **Operations & change** (`design-flow.md` § Release Model; § Observability & SLOs; § Fitness Functions) — Who is paged for what, how do they know, and what can they do at 3 a.m. through a designed, audited path? Has rollback been exercised, and restore (not just backup) been tested?
14. Which config changes alter behavior (flags, defaults, prompts, model settings), and do they pass the same gates as code?
15. Which guard fails when the property behind each [H,·] scenario breaks, and has it been shown to fail?
16. **Boundaries & ownership** (design-flow Stages 3 and 5) — Can each owner change, test and deploy its part without coordinating with others? Each "no" is a coupling to fix, monolith or not.
17. Can what already runs do this? If not, who operates the new thing, and what does it replace by when?
18. Which volatile decision does each port or layer hide, and does each shared component have two real consumers?
19. **Data & trust** (`design-flow.md` § Stage 6 — Data Architecture; § Security; `security-privacy.md`) — Who is the single writer of each data set, and which invariants span rows, services or offline writers?
20. Which data crosses which boundary (caches, logs, traces, analytics, derived copies, processors, non-production environments), and does each copy inherit its source's permissions, residency and deletion?
21. Who shares each cache, index and queue, and could one tenant observe, starve or poison another?

## Red Flags

One row per perspective (`design-flow.md` § Perspectives); a perspective skipped in Perspective Coverage skips its row.

| Perspective | 🔴 by default | 🟠 by default | 🟡 by default |
|---|---|---|---|
| Performance & scale | — | An incident pattern (below) on a key flow; capacity sized to the cache hit rate or average load (no cold-cache or past-saturation test, averages instead of percentiles, queues alarmed on depth instead of age) | An escalation (distribution, CQRS, event sourcing, sharding) that cites no envelope number or named non-scale driver |
| Availability & resilience | — | An external dependency with no deadline, single budgeted retry layer, isolation or degradation path; an unexercised fallback, failover or restore on a critical path; recovery that needs the impaired component; a stateful component in one failure domain under a driver that needs more | — |
| Security | Authorization only at the edge, a route guard or the client; a trust boundary crossed with no authenticated principal | Secrets or keys with no owner, rotation or revocation; the build and release path outside the threat model; untrusted input parsed without limits | — |
| Privacy & compliance | Personal or regulated data in an append-only, derived or third-party store (event log, backup, analytics, search or vector index, provider log) with no erasure or expiry path; such data (backups, logs, replicas included) outside the region its residency allows, or at a processor not eligible for its class | — | A compliance control with no evidence the pipeline produces |
| Data integrity & lifecycle | Effectively-once effects (money, stock, state transitions) relying on broker or transport guarantees with no deduplication where the effect commits; a dual write with no outbox or change-data-capture | Two writers for one data set; a read-modify-write or multi-row invariant under concurrency with no constraint, serializable isolation or lock; offline writers with no merge policy; the only copy of anything with no RPO/RTO or restore test | — |
| Tenancy & isolation *(cond.)* | Isolation enforced at one point only, or no cross-tenant test; a cache, index, queue or log shared across tenants whose key omits the tenant | One tenant's peak can starve others, with no noisy-neighbor policy | — |
| Interoperability & contracts | — | A published contract with no compatibility policy or consumer inventory; a breaking change with no versioning or deprecation window | — |
| Operability & observability | — | An error budget that tolerates correctness, security or data-loss violations; repairs that depend on ad-hoc production writes | An SLO with no owner or runbook; alerts on causes instead of symptoms users feel |
| Delivery & change safety | — | Behavior-changing config (flags, defaults, prompts, model settings) outside the release gates; rollback never exercised; a schema change that is not expand-contract across a deploy; shipped or fleet software with no signed update or kill switch | — |
| Evolvability | — | — | A likely change touching many modules; a shared component accreting flags, modes and caller-specific branches; one rule or format encoded in several modules |
| Cost & unit economics | — | An account-level spend cap as the only cost control | Usage-priced cost estimated only for the average user; idle cost unpriced |
| Socio-technical fit | — | — | One context with several owners; an owner holding more contexts than it can keep in its head; the most frequent change spanning owners |
| User reach | — | — | A core flow that fails offline or on a slow link where reach requires it; an accessibility duty with no design answer |
| Safety *(cond.)* | A safety function that an update, security control or credential expiry can disable, or that depends on a network, cloud, general-purpose runtime or model; a hazard deadline stated as a percentile instead of a worst-case bound | — | — |
| Decisions & evidence | An [H,H] driver with no covering decision, or one repeatedly breached in operation | An [H,·] scenario with no standing guard; ATAM evidence that is missing, unverified with no spike, or precedent without matching conditions; a fired `Revisit when` or Scaling-Ladder trigger with no follow-up ADR; a one-way door on a low-confidence assumption with no scheduled spike, or an invalidated assumption whose dependent ADRs stand unrevised | An ADR with no rejected option, numbers or failure behavior; `Revisit when` without a variable and threshold; consistency stated only as "eventual" or a CAP label; an [H,H] driver serving no goal; new technology with no written reason why what already runs can't do the job |

AI features: apply the red flags of the `ai/` files the feature's depth loads, `ai/protocol.md` first.

## Failure Modes of a Design Run

Judgment fails both ways, building too much and deciding too little. Check the design, and your own findings, for these.

| Failure mode | Tell | Antidote |
|---|---|---|
| Speculative generality | Load assumed orders of magnitude past the envelope; plug-in points with one implementation; a platform before its second consumer; complexity for marginal gains | Size to the envelope and plan the rewrite on `design-flow.md` § Scaling Ladder; generalize only from real consumers (`design-flow.md` § Stage 5 — Component Design) |
| Under-designed one-way doors | Tenancy, identity, audit history, public contract, security model or consent for data use left "for later" | Build the minimal hard-to-retrofit version now; type every door (`design-flow.md` § Stage 9 — ADR & Risk Review) |
| Premature distribution | Services split before boundaries, deployment, monitoring and ownership exist, or for throughput one process could carry | The one-box check (`design-flow.md` § Quantitative Envelope); distribute only on a named driver (design-flow Stage 4) |
| Résumé-driven choice | "A big company uses it"; precedent cited without the conditions that made it work; new technology with no written gate | Boring by default; a deviation names its gap, operator and exit (`design-flow.md` § Technology Baseline & Selection) |
| Sunny-day resilience | Fallbacks and failover configured but never run; capacity sized at the steady-state cache hit rate | Static stability; exercise every fallback; size for the bad mode (`design-flow.md` § Resilience & Overload) |
| Adjective architecture | "Fast", "scalable", "highly available", "it depends", CAP labels; cost rules priced on stale constants | Six-part scenarios with measures (`design-flow.md` § Utility Tree); consistency per operation; a price and flip condition on every choice |
| Big-bang rewrite | The target replaces the as-is in one cutover; a v2 carrying every deferred idea while v1 keeps changing | Releasable intermediate states with behavior capture (`evolution.md` § Transition Plan) |
| Unfinished migration | Two systems and two mental models with no end date; the old path still takes new use | Exit and decommission criteria per step; finish what you start (`evolution.md` § Transition Plan) |
| Portability maximalism | Neutral layers over every dependency; a lowest-common-denominator abstraction hiding the features being paid for | Lock-in is a priced option: buy a seam only for a named exit (`design-flow.md` § Technology Baseline & Selection) |

## Smells & Incident Patterns

Defined only here; other files name them. Default 🟠 on a key flow or an [H,H] path, 🟡 elsewhere — except an N+1 or thundering herd baked into the data flow, 🟠 anywhere (`SKILL.md` rubric).

- **Distributed monolith** — separately deployed parts that must release together, share a writable store, or call each other in synchronous chains while claiming independence: distribution's costs without its independence.
- **Shared writable database across contexts** — two contexts write the same tables, so neither can change its schema or invariants alone; one writer per data set, others read through a published contract or a replica.
- **Chatty interface** — many fine-grained calls per user action across a process or network boundary, so latency and failure compound per hop; make operations coarse and task-shaped, or move the boundary.
- **Pass-through layer** — a layer or port that forwards calls and hides no volatile decision: indirection cost with no information hiding.
- **God service** — one service or module that owns most entities or sits on most change scenarios, so every change and every team routes through it.
- **Cyclic dependencies** — modules or services that depend on each other, directly or transitively: none can be built, tested, deployed or cold-started alone; guard with an import-graph cycle check.
- **N+1 queries** — a list read followed by one query per item; batch or eager-load, or serve a read model.
- **Thundering herd** — a hot cache entry expires and every request recomputes it at once; coalesce requests, serve stale while revalidating, jitter expiries.
- **Retry storm** — retries at several layers multiply load on a struggling dependency; one budgeted retry layer (`operational-patterns.md`).
- **Cold-start cascade** — capacity scaled to zero meets a burst, and simultaneous cold starts breach latency and trigger retries; keep warm capacity sized to the burst ramp, or admit and queue.
- **Reconnect storm** — a node loss or deploy drops many long-lived connections that return at once; drain gradually, jitter reconnects, resume from a cursor.
- **Hot partition** — one key, tenant or shard takes a disproportionate share of load or storage; choose the key per scaling dimension and plan hot-key handling (`design-flow.md` § Stage 6 — Data Architecture).
- **Metastable failure** — retries, reconnects, cold caches or backlogs keep the system overloaded after the trigger is gone; shed load, cap retries, size for the bad mode.
