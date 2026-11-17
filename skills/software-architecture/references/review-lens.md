# Review Lens

Review / Diagnose Mode. The design rules in `SKILL.md` and the topical references are the criteria; a broken rule is a finding. This file holds the procedure, the severity scale, the questions that expose a broken rule, and the ways a design run itself goes wrong.

## Procedure

1. **Read** the docs root: `context.md`, `system.md`, `risks.md`, `adr/`, `ai-features/`, `as-is.md`, and `database.md` if present. With no docs, recover the as-is (`evolution.md`).
2. **Audit** against the Self-Review in `SKILL.md`, its Concerns table at the depth each trigger demands, and the questions below; review each AI feature doc against the ai-architecture capability's gate, if available.
3. **Drift check.** Where code exists, sample the load-bearing claims: declared containers exist, declared boundaries show in the layout, declared guards run in CI, declared fallbacks are exercised. During a transition, compare with the live step, not the target. Drift on such a claim is a finding (🟠 by default), whichever side is wrong.
4. **Fired triggers.** Test every `Revisit when`, Scaling Ladder trigger and assumption against operational evidence: SLO history, incidents, cost trend, load against the envelope. With no evidence, an Open Question names what is needed.
5. **Rank and dispose.** 🔴/🟠 that is fixable and unambiguous → a targeted patch; an accepted risk → Risk Register; needs input → Open Questions; implies a decision → a new ADR via `arch-decision`. Findings live in the docs they concern, never in a separate review file. Schema findings also take the database-design review checklist, if available.

## Severity

- 🔴 **Critical**: correctness, security or data loss; a driver with no covering decision, or one repeatedly breached in operation; regulated data with no erasure path; cross-tenant exposure; a safety function that can be disabled.
- 🟠 **High**: an unjustified departure from an ADR; docs↔code drift on a load-bearing claim; a dependency with no deadline or degraded mode; an unexercised fallback on a critical path; a published contract with no compatibility policy; a fired trigger with no follow-up decision; a one-way door on a low-confidence assumption with no spike.
- 🟡 **Medium**: a structural improvement; a gap that fails the cold-read test; a document so long that its decisions are hard to find.
- 🟢 **Low**: wording and optional consistency.

Raise or lower a severity with blast radius and reversibility. Defaults per finding type are listed after the questions.

## Questions

Ask all of them in a full audit; in a scoped review, those the change touches. A missing answer is a finding.

**Problem and drivers**
1. What problem, for whom, with which non-goals, and which goal does each driver serve?
2. Are the top risks failure scenarios with numbers?

**Decisions**
3. Which decisions are one-way doors, counting everything consumers can observe, stored formats and cache sharing, and does each have an ADR with a guard?
4. For each choice: what was rejected, what does it cost, and which variable and threshold would flip it?
5. Which seams and abstractions are options being paid for, and which named exit justifies each?

**Numbers and cost**
6. What are the numbers now and at the next order of magnitude, and could one well-built process do the job?
7. What does a successful unit of value cost for the tail user, and what costs money while idle?

**Failure and recovery**
8. When each dependency is slow, not just down, what happens, and does the system recover by itself once the trigger is gone?
9. Where exactly do retries happen, on what budget, and which errors are permanent?
10. Does any recovery step need the impaired component, and can the system cold-start without circular dependencies?
11. What queues up during an outage, how long does it take to drain, and is that work still worth doing then?
12. Which paths run only on bad days (fallback, failover, cold cache, restore), and when was each last exercised?

**Operations and change**
13. Who is paged for what, and what can they do at 3 a.m. through a designed, audited path? Has rollback been exercised and a restore tested?
14. Which config changes alter behavior (flags, defaults, prompts, model settings), and do they pass the same gates as code?
15. Which guard fails when each driver's property breaks, and has it been shown to fail?

**Boundaries and ownership**
16. Can each owner change, test and deploy its part without coordinating? Each "no" is a coupling, monolith or not.
17. Can what already runs do this? If not, who operates the new thing, and what does it replace by when?
18. Which volatile decision does each port or layer hide, and does each shared component have two real consumers?

**Data and trust**
19. Who is the single writer of each data set, and which invariants span rows, services or offline writers?
20. Which data crosses which boundary (caches, logs, traces, analytics, derived copies, processors, non-production), and does each copy inherit its source's permissions, residency and deletion?
21. Who shares each cache, index and queue, and could one tenant observe, starve or poison another?

## Default severities

🔴 unless shown otherwise:
- Authorization only at the edge, a route guard or the client; a trust boundary crossed with no authenticated principal.
- Personal or regulated data in an append-only, derived or third-party store with no erasure path, or outside the region its residency allows.
- Effectively-once effects (money, stock, state transitions) that rely on broker or transport guarantees, with no deduplication where the effect commits; a dual write with no outbox.
- Tenant isolation enforced at one point only, or a shared cache, index, queue or log whose key omits the tenant.
- A safety function that depends on a network, cloud or model, or that an update or expired credential can disable.

🟠 unless shown otherwise:
- Two writers for one data set; a multi-row invariant under concurrency with no constraint, lock or serializable isolation; offline writers with no merge policy.
- Capacity sized to the cache hit rate or the average load; queues alarmed on depth instead of age.
- Recovery that needs the impaired component; a stateful component in one failure domain under a driver that needs more.
- An error budget that tolerates correctness, security or data-loss violations; repairs that depend on ad-hoc production writes.
- Behavior-changing config outside the release gates; a schema change that is not expand-contract across a deploy.
- An account-level spend cap as the only cost control.
- Evidence that is missing, unverified with no spike, or precedent without matching conditions.

AI features: the red flags of the ai-architecture capability, if available.

## How a design run fails

Judgment fails both ways. Check the design, and your own findings, for these.

| Failure | Tell | Antidote |
|---|---|---|
| Speculative generality | Load assumed orders of magnitude past the envelope; plug-in points with one implementation; a platform before its second consumer | Size to the envelope; put the rewrite on the Scaling Ladder |
| Under-designed one-way doors | Tenancy, identity, audit history, the public contract or consent left "for later" | Build the minimal hard-to-retrofit version now |
| Premature distribution | Services split before ownership, deployment and monitoring exist, or for throughput one process could carry | The one-box check; split only on a named force |
| Résumé-driven choice | "A big company uses it"; precedent without its conditions | Boring by default; a deviation names its gap, operator and exit |
| Sunny-day resilience | Fallbacks configured but never run | Exercise every fallback; size for the bad mode |
| Adjective architecture | "Fast", "scalable", "eventually consistent", CAP labels | Scenarios with numbers; consistency per operation; a price on every choice |
| Portability maximalism | Neutral layers over every dependency, hiding the features being paid for | Buy a seam only for a named exit |
| Big-bang rewrite, unfinished migration | One cutover; two systems with no end date | Releasable intermediate states; exit and decommission criteria per step |

## Smells

Each is 🟠 on a driver's path and 🟡 elsewhere: a distributed monolith (parts that must release together or share a writable store), a chatty interface across a process boundary, a pass-through layer, a god service on most change paths, cyclic dependencies, N+1 queries baked into a flow, a thundering herd on cache expiry, retries at several layers, a cold-start cascade after scale-to-zero, a reconnect storm after a deploy, a hot partition, and any loop (retries, cold caches, backlogs) that keeps the system overloaded after its trigger is gone.
