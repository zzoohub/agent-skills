# Review Sections — full prompts

Loaded by `plan-review` in scope mode. Step 0 is run before mode is locked; Sections 1-10 after.

**After every step and section, apply the section gate defined in `SKILL.md`** (surface the top 5-8 issues, ask via the question protocol, pause for the user, honor the non-interactive fallback). Mode-specific behavior: see `references/mode-reference.md`. Do not paste a STOP block per section — the gate is global.

## Table of Contents
1. [Step 0: Nuclear Scope Challenge](#step-0-nuclear-scope-challenge)
2. [Section 1: Architecture Review](#section-1-architecture-review)
3. [Section 2: Error & Rescue Map](#section-2-error--rescue-map)
4. [Section 3: Security & Threat Model](#section-3-security--threat-model)
5. [Section 4: Data Flow & Interaction Edge Cases](#section-4-data-flow--interaction-edge-cases)
6. [Section 5: Code Quality Review](#section-5-code-quality-review)
7. [Section 6: Test Review](#section-6-test-review)
8. [Section 7: Performance Review](#section-7-performance-review)
9. [Section 8: Observability & Debuggability Review](#section-8-observability--debuggability-review)
10. [Section 9: Deployment & Rollout Review](#section-9-deployment--rollout-review)
11. [Section 10: Long-Term Trajectory Review](#section-10-long-term-trajectory-review)

---

## Step 0: Nuclear Scope Challenge

### 0A. Premise Challenge
1. Is this the right problem to solve? Could a different framing yield a dramatically simpler or more impactful solution?
2. What is the actual user/business outcome? Is the plan the most direct path, or is it solving a proxy problem?
3. What would happen if we did nothing? Real pain point or hypothetical one?

### 0B. Existing Code Leverage
1. What existing code already partially or fully solves each sub-problem? Map every sub-problem to existing code. Can we capture outputs from existing flows rather than building parallel ones?
2. Is this plan rebuilding anything that already exists? If yes, explain why rebuilding beats refactoring.

### 0C. Dream State Mapping
Describe the ideal end state 12 months out. Does this plan move toward or away from it?
```
  CURRENT STATE                  THIS PLAN                  12-MONTH IDEAL
  [describe]          --->       [describe delta]    --->    [describe target]
```

### 0D. Mode-Specific Analysis
**SCOPE EXPANSION** — run all three:
1. **10x check:** What's the version 10x more ambitious that delivers 10x more value for 2x the effort? Describe it concretely.
2. **Platonic ideal:** If the best engineer in the world had unlimited time and perfect taste, what would this look like? What would the user feel? Start from experience, not architecture.
3. **Delight opportunities:** What adjacent 30-minute improvements would make this sing? List at least 3 now — the Delight Opportunities required output grows the list to 5+ by review's end.

**HOLD SCOPE** — run this:
1. **Complexity check:** >8 files or >2 new classes/services is a smell — challenge whether the goal needs fewer moving parts.
2. What is the minimum set of changes that achieves the stated goal? Flag deferrable work.
3. **10x check (optional here):** run it only if the plan smells under-ambitious. Surfacing a better version is allowed even while holding scope; act on it only if the user re-picks the mode.

**SCOPE REDUCTION** — run this:
1. **Ruthless cut:** What is the absolute minimum that ships value? Everything else is deferred. No exceptions.
2. What can be a follow-up PR? Separate "must ship together" from "nice to ship together."

### 0E. Temporal Interrogation (EXPANSION and HOLD modes)
What decisions will surface during implementation that should be resolved NOW?
```
  HOUR 1 (foundations):    What does the implementer need to know?
  HOUR 2-3 (core logic):   What ambiguities will they hit?
  HOUR 4-5 (integration):  What will surprise them?
  HOUR 6+ (polish/tests):  What will they wish they'd planned for?
```
Surface these as questions NOW, not "figure it out later."

(Mode selection itself is in `references/scope-mode.md` → Step 0.)

---

## Section 1: Architecture Review
Evaluate and diagram:
* Overall system design and component boundaries. Draw the dependency graph.
* Data flow — all four paths. For every new data flow, ASCII diagram the: happy path; nil path (input nil/missing); empty path (present but empty/zero-length); error path (upstream call fails).
* State machines. ASCII diagram for every new stateful object, including impossible/invalid transitions and what prevents them.
* Coupling concerns. Which components are now coupled that weren't? Justified? Draw before/after dependency graphs.
* Scaling characteristics. What breaks first under 10x load? Under 100x?
* Single points of failure. Map them.
* Security architecture. Auth boundaries, data access patterns, API surfaces. For each new endpoint or mutation: who can call it, what do they get, what can they change?
* Production failure scenarios. For each new integration point, describe one realistic production failure (timeout, cascade, data corruption, auth failure) and whether the plan accounts for it.
* Rollback posture. If this ships and immediately breaks, what's the rollback? Git revert? Feature flag? Migration rollback? How long?

**EXPANSION additions:** What would make this architecture beautiful (elegant, not just correct)? What infrastructure would make this a platform other features build on?

Required ASCII diagram: full system architecture showing new components and their relationships to existing ones.

## Section 2: Error & Rescue Map
This is the section that catches silent failures. Not optional. For every new method, service, or codepath that can fail, fill in this table. (Example is **illustrative** — substitute your project's domain; do not assume network/DB/HTTP failure modes apply if the plan has none.)
```
  METHOD/CODEPATH          | WHAT CAN GO WRONG           | EXCEPTION CLASS
  -------------------------|-----------------------------|-----------------
  ExternalCall.invoke()    | upstream timeout            | TimeoutError
                           | upstream rejects (rate cap) | RateLimitError
                           | malformed response          | ParseError
                           | resource exhausted          | ResourceExhaustedError
                           | record not found            | NotFoundError
  -------------------------|-----------------------------|-----------------

  EXCEPTION CLASS          | RESCUED?  | RESCUE ACTION          | USER SEES
  -------------------------|-----------|------------------------|------------------
  TimeoutError             | Y         | Retry 2x, then raise   | "Temporarily unavailable"
  RateLimitError           | Y         | Backoff + retry        | Nothing (transparent)
  ParseError               | N ← GAP   | —                      | 500 error ← BAD
  ResourceExhaustedError   | N ← GAP   | —                      | 500 error ← BAD
  NotFoundError            | Y         | Return nil, log warn   | "Not found" message
```
Rules:
* Catch-all exception handling is ALWAYS a smell. Name the specific exceptions.
* Logging only the message is insufficient. Log full context: what was attempted, with what arguments, for what user/request.
* Every rescued error must either retry with backoff, degrade gracefully with a user-visible message, or re-raise with added context. "Swallow and continue" is almost never acceptable.
* For each GAP (unrescued error that should be rescued): specify the rescue action and what the user should see.
* For LLM/AI service calls: what happens when the response is malformed? empty? hallucinated invalid JSON? a refusal? Each is a distinct failure mode.

## Section 3: Security & Threat Model
Security gets its own section. Evaluate:
* Attack surface expansion. New endpoints, params, file paths, background jobs?
* Input validation. For every new user input: validated, sanitized, rejected loudly on failure? Behavior with nil, empty string, wrong type, over-length, unicode edge cases, injection attempts?
* Authorization. For every new data access: scoped to the right user/role? Direct object reference vulnerability? Can user A reach user B's data by manipulating IDs?
* Secrets and credentials. New secrets in env vars (not hardcoded)? Rotatable?
* Dependency risk. New third-party dependencies (npm/cargo/pip packages)? Security track record?
* Data classification. PII, payment data, credentials? Handling consistent with existing patterns?
* Injection vectors. SQL, command, template, LLM prompt injection — check all.
* Audit logging. For sensitive operations: is there an audit trail?

For each finding: threat, likelihood (H/M/L), impact (H/M/L), whether the plan mitigates it.

## Section 4: Data Flow & Interaction Edge Cases
**Data Flow Tracing:** For every new data flow, ASCII diagram:
```
  INPUT ──▶ VALIDATION ──▶ TRANSFORM ──▶ PERSIST ──▶ OUTPUT
    │            │              │            │           │
    ▼            ▼              ▼            ▼           ▼
  [nil?]    [invalid?]    [exception?]  [conflict?]  [stale?]
  [empty?]  [too long?]   [timeout?]    [dup key?]   [partial?]
  [wrong    [wrong type?] [OOM?]        [locked?]    [encoding?]
   type?]
```
For each node: what happens on each shadow path? Is it tested?

**Interaction Edge Cases:** For every new user-visible interaction:
```
  INTERACTION          | EDGE CASE              | HANDLED? | HOW?
  ---------------------|------------------------|----------|--------
  Form submission      | Double-click submit    | ?        |
                       | Submit with stale CSRF | ?        |
                       | Submit during deploy   | ?        |
  Async operation      | User navigates away    | ?        |
                       | Operation times out    | ?        |
                       | Retry while in-flight  | ?        |
  List/table view      | Zero results           | ?        |
                       | 10,000 results         | ?        |
                       | Results change mid-page| ?        |
  Background job       | Fails after 3 of 10    | ?        |
                       | Runs twice (dup)       | ?        |
                       | Queue backs up 2 hours | ?        |
```
Flag any unhandled edge case as a gap; specify the fix.

## Section 5: Code Quality Review
* Code organization and module structure. Does new code fit existing patterns? If it deviates, is there a reason?
* DRY violations. Be aggressive — reference file and line.
* Naming quality. Named for what they do, not how?
* Error handling patterns. (Cross-reference Section 2 — this reviews patterns; Section 2 maps specifics.)
* Missing edge cases. List explicitly ("What happens when X is nil?").
* Over-engineering check. Any new abstraction solving a problem that doesn't exist yet?
* Under-engineering check. Anything fragile, happy-path-only, missing obvious defensive checks?
* Cyclomatic complexity. Flag any new method branching more than 5 times; propose a refactor.

## Section 6: Test Review
Diagram every new thing this plan introduces:
```
  NEW UX FLOWS:              [each new user-visible interaction]
  NEW DATA FLOWS:            [each new path data takes]
  NEW CODEPATHS:             [each new branch/condition/execution path]
  NEW BACKGROUND/ASYNC WORK: [each]
  NEW INTEGRATIONS/CALLS:    [each]
  NEW ERROR/RESCUE PATHS:    [each — cross-reference Section 2]
```
For each item: test type (Unit/Integration/System/E2E); does a test exist in the plan (if not, write the spec header); happy-path test; failure-path test (which failure); edge-case test (nil, empty, boundary, concurrent).

Test ambition check (all modes): the test that lets you ship at 2am Friday; the test a hostile QA engineer writes to break this; the chaos test.

Test pyramid check: many unit, fewer integration, few E2E — or inverted? Flakiness risk: flag tests depending on time, randomness, external services, ordering. Load/stress test requirements for frequently-called or data-heavy codepaths.

For LLM/prompt changes: check the project-conventions file (e.g. `CLAUDE.md`) for prompt/LLM-change file patterns. If this plan touches any, state which eval suites must run, which cases to add, what baselines to compare against.

## Section 7: Performance Review
* N+1 queries. For every new relation traversal: eager loading (Drizzle `with`; SQLAlchemy `selectinload` for collections, `joinedload` for many-to-one; etc.)?
* Memory usage. Maximum size in production for every new data structure?
* Database indexes. Index for every new query?
* Caching opportunities. Should expensive computations / external calls be cached?
* Background job sizing. Worst-case payload, runtime, retry behavior?
* Slow paths. Top 3 slowest new codepaths and estimated p99 latency.
* Connection pool pressure. New DB/Redis/HTTP connections?

## Section 8: Observability & Debuggability Review
New systems break — this section ensures you can see why.
* Logging. Structured log lines at entry, exit, each significant branch?
* Metrics. What metric tells you it's working? What tells you it's broken?
* Tracing. Trace IDs propagated across cross-service/cross-job flows?
* Alerting. What new alerts should exist?
* Dashboards. What panels do you want on day 1?
* Debuggability. If a bug is reported 3 weeks post-ship, can you reconstruct what happened from logs alone?
* Admin tooling. New operational tasks needing admin UI, CLI/management commands, or scripts?
* Runbooks. For each new failure mode: the operational response?

**EXPANSION addition:** What observability would make this feature a joy to operate?

## Section 9: Deployment & Rollout Review
* Migration safety. Backward-compatible? Zero-downtime? Table locks?
* Feature flags. Should any part be behind a flag?
* Rollout order. Migrate first, deploy second?
* Rollback plan. Explicit step-by-step.
* Deploy-time risk window. Old and new code running simultaneously — what breaks?
* Environment parity. Tested in staging?
* Post-deploy verification checklist. First 5 minutes? First hour?
* Smoke tests. What automated checks run immediately post-deploy?

**EXPANSION addition:** What deploy infrastructure would make shipping this routine?

## Section 10: Long-Term Trajectory Review
* Technical debt introduced. Code, operational, testing, documentation debt.
* Path dependency. Does this make future changes harder?
* Knowledge concentration. Documentation sufficient for a new engineer?
* Reversibility. Rate 1-5 (1 = one-way door, 5 = easily reversible).
* Ecosystem fit. Aligns with the chosen tech stack's direction?
* The 1-year question. Read as a new engineer in 12 months — obvious?

**EXPANSION additions:** What comes after this ships (Phase 2/3)? Does the architecture support that trajectory? Platform potential — does this create capabilities other features can leverage?
