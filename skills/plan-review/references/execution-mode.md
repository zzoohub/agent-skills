# Execution mode: eng-manager lens

**Add the decision record to the evidence** (SKILL.md step 2): the ADRs, `context.md`, `risks.md`, and `database.md` if data changes (defaults under `docs/arch/`; caller may redirect). Spikes owed and unknown assumptions are readiness inputs, not new findings.

**Depth.** Light runs checks 6 and 7. Standard adds what its fired triggers name: data, a contract or a global push → 3; money, an irreversible action or a must-not-lose write → 4; who can do what, personal data or a regulated domain → 5; a new dependency → 1 and 4, plus 5 for an LLM or agent. Deep runs all eight. At any depth: a build past about a month → 1 and 8; parallel streams or a second team → 2; a hard date → 8; a hotfix or incident follow-up → 3, with the incident's failure as a registry row.

## Checks

1. **Slices.** Slice 1 is a walking skeleton: the primary end-to-end path, linking the main components and the riskiest integration, deployed behind a flag where users could see it. The riskiest unknown is retired in slice 1 or 2, by a spike with a pass/fail threshold for any vendor, model or performance fact the plan assumes. *Break:* a single-component change, or an order imposed from outside.

2. **Contracts and dependencies.** Interfaces between parallel streams freeze before they start; each write path has one owner. Each dependency on another team, a vendor, an approval or work in flight on the same paths has an owner and a date, or the slice that needs it moves later.

3. **One-way doors and rollout.** For each change to persisted data, messages or a public contract: what is valid while old and new code run side by side, and after a rollback? Expand → migrate → contract, with batched, resumable backfills. Name the rollout signal, the abort condition, and rollback or forward-fix with how long it takes. No answer → Blocker. Replacing what computes money, access or stored data: run new beside old on real inputs, diffing outputs; the diff rate gates cutover. Config, prompts, model versions and generated data ship like code: validated as untrusted input, staged, with a kill switch; fail-open or fail-closed is chosen per dependency.

4. **Failure registry** (columns in SKILL.md § 5): one row per boundary the plan adds or changes.
   - **Policy**: retry, compensate, surface, alert or accept. Retry only idempotent or idempotency-keyed operations, at one layer, with capped, jittered backoff and a retry budget. Compensate and alert name the tool or runbook the owner acts with (re-drive, refund, unlock).
   - **Probe each boundary for**: duplicate or reordered delivery; concurrent writes; partial failure mid-sequence; a slow (not down) dependency; the backlog after an outage; for an LLM call, refusal, truncation, schema-valid but wrong output, and retirement of the pinned model.
   - **Gates**: a silent row is a Blocker on a critical path (SKILL.md § 4), Major elsewhere; an untested critical-path row is Major.

5. **Trust boundaries.** Which boundary moves: a new input, principal, data access, outbound call or credential? Can user or tenant A reach B's data by changing an id? Money, permission and deletion actions leave an audit record that outlives them. § 4's LLM or agent Blocker: drop one leg or require a person's approval. Cap tokens and cost per request and tenant.

6. **Verification.** Each invariant the plan relies on (one charge per order; tenant A never reads B's rows) gets a failure-path test at the cheapest boundary that catches it, plus a production signal that it broke, routed to an owner; for money and stored state, a reconciliation against the source of truth, not error logs. Each new flow gets a signal that it works, and each legal duty (accessibility, say) a release check. An LLM change needs an eval set with a baseline and pass threshold before rollout; it also qualifies a replacement model.

7. **Implementer's pass.** Walk the build order as the implementer, human or coding agent. At each step: what must they decide that the plan doesn't settle, and what check proves the step done? Undecided items that touch data, a contract or user-visible behavior → unresolved decisions; the rest → defaults you state.

8. **Capacity.** Calibrate the estimate, in S/M/L, against how long the last comparable change here took. Size or split out hidden projects: one-line steps that are plans of their own ("migrate existing users", "support SSO"). A data migration or a technology new to the team gets its own buffer. No slack and no cut line → Major.

**An implementation plan adds, checked against the code** (the first at every depth, the rest at standard and deep):
- each path, symbol, endpoint, flag and table the plan names exists as named (cite `path:line`); a phantom one is Major, a Blocker when later steps build on it;
- each sub-problem mapped to existing code; a rebuild needs a reason;
- duplicated knowledge (one rule in two places), not similar-looking code: a follow-up, except money and security rules, which are unified now;
- each new dependency exists under the intended name and publisher, is pinned, and is worth its transitive surface;
- at the larger of 10× measured load or the 12-month target, which query, loop, payload or bill grows with it?

## Verdict

The first that applies wins.

- **Not ready**: a Blocker needs design rework (software-architecture or arch-decision, if available) or a scope change (scope mode).
- **Ready after fixes**: each Blocker has a known fix, or an owner decision, that keeps scope and design.
- **Ready**: no Blockers.

Then write per SKILL.md § 5 and run its Self-Review.
