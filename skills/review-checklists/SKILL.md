---
name: review-checklists
description: |
  Pre-landing code review in two passes. Pass 1 (blocking): security (OWASP Top
  10, LLM Top 10: access control, auth, injection, SSRF, crypto, supply chain,
  AI/LLM/MCP) and bugs that survive green CI (races, retries, partial failure,
  caching, time, untested logic). Pass 2 (informational): maintainability and
  design smells. Use to review a diff, PR or file before it lands, audit code,
  or pre-mortem code being written: "code review", "review this PR",
  "security review", "OWASP check", "is this race-safe", "can this
  double-charge". Do NOT use for: plans or design docs (plan-review);
  exploiting a running app (adversarial-execution); building these mechanisms
  (hexagonal-backend, database-design).
---

# Review Checklists

Tests prove the single-threaded happy path and linters catch mechanics; this review covers the rest. Two questions sit behind "review this": what can the change now make happen (to whom, twice, concurrently, after a crash) that it couldn't before, and what does the requester need to decide, by when?

| Pass | Section | Blocks the commit? |
|---|---|---|
| 1 | **Security**: OWASP Top 10:2025 + OWASP LLM Top 10 | A confirmed critical or high finding |
| 1 | **Correctness**: the bugs that survive green CI | A confirmed critical or high finding |
| 2 | **Maintainability**: will this stay cheap to change | No, unless project policy escalates |

A blocking finding stops the commit (or, once an interim keeps it unreachable, the enabling) until fixed or explicitly accepted in writing, never an FYI. So does an unmet **mandate**, in any section, with no exploit needed: a sign-off a governing doc requires, an accepted decision record the change contradicts, a risk control assigned to it, a compliance control the system is in scope for, a checklist item marked mandatory (conventions and style guides are not mandates). A sign-off the diff can't show is *not shown* and blocks only the step its source gates.

## Calibrate first

**Frame the decision** before reading hunks. Don't stop to ask: take the default and list it in Scope.
- *Decision and deadline*: merge, release, demo or go/no-go, and when. Default: merge to production today.
- *First exposure*: who meets the change first, behind what (a flag defaulting off, an allowlist, a beta cohort). Default: every user and tenant on deploy.
- *Fixed decisions*: product calls stakeholders won't reopen ("the agent emails customers"). Fixes work within them; if only reopening one closes a blocking path, say so and name who decides. Default: what the PR and governing docs state.
- *Governing docs*: decision records, risk register, architecture doc (defaults `docs/arch/adr/`, `docs/arch/risks.md`, `docs/arch/system.md`; caller may redirect), sign-off rules for this kind of change (security review of agent tools), a project `checklist.md`, any checklist the requester supplies. Each mandatory item is a mandate, each stated invariant one to check; routine CODEOWNERS review is a Scope line ("requires: @owner"), not a mandate. None found: say so in Scope.

**Mode** (name it in Scope):
- *Diff* (default): the diff and the code it calls or is called by. A pre-existing defect is a finding, marked *pre-existing*, when the diff makes it reachable or worse or composes with it (Method step 4); else one Scope line.
- *Re-review* (fixes pushed): mark each prior blocking finding, mandate and Unconfirmed item closed, partial or open; then Diff mode on the fix commits only, with no new Pass 2 items on code the fix didn't touch.
- *Audit* (asked for, or no diff): the whole target, caps per module. Inventory the route registry, auth middleware and data-scoping layer, then hunt the entry points that bypass them, then money and tenant paths.
- *One pass* ("security only"): that pass alone; mandates still apply.
- *Pre-mortem* (code being written): Method steps 1–3 with the triggered sections as a checklist; return ≤10 items of invariant → guard → test (≤150 words), no verdict.

**Depth follows the riskiest thing touched:**
- **Deep**: auth, permissions, money, tenant scope, personal data, migrations, LLM tools, irreversible effects, code on every request path (middleware, client wrappers, config and flag defaults). Both views, chains, Unconfirmed items.
- **Light**: docs, tests, renames, pure refactors, once verified (`git diff -w -M`; nothing renamed is persisted or external): confirm no guard, check or effect moved or vanished; a one-line verdict. Never Light: prompts, tool descriptions, agent-instruction or policy files, or a test whose expected value or assertion changed: each changes behavior. A hunk that isn't pure gets the depth of what it touches.
- **Standard**: everything else. Too big to read closely: Deep hunks line by line, the rest skimmed; Scope says so and asks to split mixed mechanical and behavior changes.

## Method

1. **Name the intent** (what the change must achieve, and whether it does) **and the invariants** it must keep ("one charge per order", "tenant A never reads B's rows") from the PR text, commits, tests and governing docs. Where they are silent, assume these and list them in Scope:
   - a new entry point is reachable anonymously until you cite its authentication, and by any user of any tenant until you cite its object scope;
   - two or more instances run; every caller retries (users double-submit; clients, SDKs and proxies retry);
   - webhooks, queues and cron deliver at least once and overlap; rolling deploys run old and new code together;
   - money and customer messages are irreversible.
2. **Map the delta** (notes, not output):
   - entry points added or changed (route, resolver, server action or function, consumer, webhook, cron, CLI, LLM tool): who can reach each, the asset, the guard;
   - effects: DB write, external call, enqueue, cache write or delete;
   - sinks: raw query, shell, eval, raw HTML, outbound fetch, file path, deserializer, redirect, disabled TLS or signature check, committed secret, and every message or tool call an agent can send (who receives it, and what from the model's context it can carry);
   - changed contracts: a function, type, endpoint, event, config key or default whose meaning changed (nullable, throwing, a new enum value or unit, a renamed field); every caller or consumer the diff didn't update, jobs and other services included, is a candidate finding;
   - minus lines: a removed `await`, `WHERE` predicate, lock, transaction, check or test is a one-line regression;
   - dependency, CI and infrastructure changes; a version bump is a changed contract (read the breaking changes of each major, or 0.x minor, it crosses; an unread changelog is "not reviewed" in Scope).
3. **Hunt in damage order**: identity and permissions → money, tenant scope, irreversible effects → sinks → concurrency, retries, partial failure → volume, time, boundaries → supply chain, config → design.
   - *Per entry point*: is the object load scoped by the authenticated principal, and do its siblings match (list vs get, bulk or export, other transports to the same method)?
   - *Per effect*: **twice** (who redelivers it?), **concurrently** (every other writer of that row or key, new or pre-existing; how many instances of this one?), **crash after each step** (what state is left?), **slow** (on timeout, is the outcome known?).
   - *Per sink*: trace it to its source (committed secrets: `references/security/supply-chain.md`).
4. **Prove, then widen.** Run the gates. Search every path to the changed behavior, touched or not (other transports, workers, admin tools, scripts), and pre-existing code sharing its state or effects (the same row, counter, queue, cache key or tool): a defect there that changes the new behavior's outcome is a finding. One root cause is one finding with every location; a fix on one path only is a finding on the rest; ask which findings chain. Note paths **safe by accident** (one worker today, a lock or status check kept for another reason, a slow call that serializes, a stale absolute write that absorbs duplicates) and what would end that. A risk the code can't settle (isolation level, a guard in code you can't see, outside reachability) that would be critical or high if true goes to Unconfirmed with its deciding fact: never dropped, never inflated.
5. **Close the loop.** Apply the whole fix set on paper, holding the fixed decisions, and re-run every blocking path: each trigger must now fail at a named guard, and each agent exit is re-checked for who receives it and what context rides along. Fixes open paths: one that ends a step-4 accident (relaxing that status check, turning that stale write into an increment, dropping that lock) unmasks the race it hid, so it lands with or after that race's guard; binding an exit's recipient leaves its model-written content free. Then set the fix order, the residual risk and, if a blocker can't land by the deadline, a safe interim: a finding the interim keeps unreachable then blocks enabling, not merging; a mandate binds where its source says, so a flag never defers a merge-time one.
6. **Rank and write** with the Review Output Contract; run the Self-Review.

## Routing — what to read

Open the file for each area your map touches (in a security file, read its *Not a finding* lines before reporting there), never to hunt for absent controls.

| The diff touches… | Read |
|---|---|
| Object access, roles, tenants; login, sessions, cookies, CSRF, JWT, OAuth/SSO, SAML, MFA, passkeys, redirects | `references/security/auth.md` |
| Endpoints, injection, XSS, path traversal, uploads, inbound webhooks, deserialization, WebSocket, smuggling, resource exhaustion | `references/security/api.md` |
| Payments, inventory, pricing, discounts, refunds, limits, approvals, state machines: the *attacker* view | `references/security/business-logic.md` |
| Dependencies, lockfiles, CI/CD, containers, IaC, committed secrets | `references/security/supply-chain.md` |
| Hashing, encryption, randomness, signatures, TLS | `references/security/crypto.md` |
| CORS, headers, debug and default config, static file serving, cloud storage, caches and CDNs, DNS records, exposed services | `references/security/misconfiguration.md` |
| A server-side fetch of a URL | `references/security/ssrf.md` |
| A security control's error path; leaky errors and logs | `references/security/error-logging.md` |
| LLM calls, prompts, RAG, model output, agent tools, MCP | `references/security/llm-security.md` |
| Effects, races, retries, transactions, partial failure, caching, data volume, time, serialization boundaries, schema migrations: the *accident* view | `references/correctness.md` |
| A module boundary, public or persisted contract, or abstraction the diff adds or changes (otherwise Pass 2 is the gates alone) | `references/maintainability.md`; TS/JS also `references/maintainability/typescript.md`, Rust `references/maintainability/rust.md` |

When money or inventory moves, read both views: abuse (double-spends, cumulative refunds or limits, skipped states) and accident (retries, crashes mid-operation, replica lag).

## Scope

- **One root cause, one finding**, in the pass where it blocks: an exploit an attacker drives is security; breakage needing no attacker is correctness; a cost to future change is maintainability. A boundary escape hatch (`any`, `as`, `unsafe`) and the missing runtime check behind it are two: the check is correctness, the hatch Pass 2.
- **Elsewhere**, if available: plans and specs → plan-review; architecture → software-architecture; superseding a decision record → arch-decision; live exploits → adversarial-execution; building fixes → hexagonal-backend, database-design; React or React Native UI correctness → react-best-practices or react-native-skills, rated on this ladder. Not covered: mobile-client internals (MASVS), privacy law, lint and type errors.

## Before You Report — the gates

### Every pass

1. **Prove it by the pass's gates below; don't re-flag what the diff already fixes** (read the whole diff first).
2. **Find the guard one layer away** — middleware authz, auto-escaping, schema validation, a gateway control; a unique index in the migrations, a transaction or lock in the caller, framework dedup, a single-consumer queue. A guard elsewhere is still a guard: cite its `file:line`.
3. **Leave decoys alone** — safe in context despite the pattern (a parameterized `WHERE id = $1`, a server-allowlisted host, a random API token stored as unsalted SHA-256; each security file's *Not a finding* lines list more): at most a "considered and cleared" line in Scope, never a finding.
4. **Defaults are version facts** — check a library default against the version the lockfile pins; an option that turns a protection on must exist under that exact name there (a misspelled or invented key fails open).

### Security — exploitability discipline

1. **Trace the source** — attacker-controlled, or from config or a trusted service? Name the entry point and the attacker's position, in the Severity ladder's terms.
2. **Check context applicability** — no bucket-policy findings on a CLI tool.
3. **State the precondition** — "exploitable when X", not "vulnerable". Give each distinct path (attacker position, entry point) its own line: the fix must close each.

### Correctness — confirm it's real

1. **Name the two actors that collide.** Request-scoped state can't race itself unless the request fans out (goroutines, threads, `Promise.all` or `gather` over shared state). A single writer exists only if something enforces it (a leader lock, a lock row, one replica deployed stop-before-start): name it. A scheduler or CronJob is not one.
2. **Name the retrier** — client, queue, gateway, SDK or a double-submit, which always counts for money and irreversible effects (charge, payout, customer email or SMS, stock). Downgrade only a cheap, reversible effect whose duplicates you can show can't arrive.
3. **Name the cardinality** that makes it unbounded in production. A fixed enum or a 30-row lookup table is not a finding.
4. **Logic bugs on untested paths count** — an inverted comparison, off-by-one, wrong variable or unhandled null that no test exercises: report it and name the missing test.
5. **Run each trigger past the state guards on its path** — a status check, an early return or a caller-held lock can make it unreachable: clear that one, but list it under Safe by accident if the guard exists for another purpose. Keep each survivor with its precondition, and every end state its orderings produce (A before B, B before A).

If you can't name the trigger ("two concurrent webhook deliveries for the same order"), the finding isn't confirmed yet.

### Maintainability — is it a finding?

1. **Name the cost, or drop it** — the Cost line names a concrete future change this code makes costlier or riskier; "not clean" is noise.
2. **Convention first** — following the local pattern isn't a finding against this PR; object to the pattern once, codebase-wide. A convention excuses *style*, not *defects*: an established smell doesn't grandfather a new instance.
3. **Rank by cost of reversal** — persisted formats and public contracts > module boundaries and dependency direction > abstractions with several callers > one function's insides (a finding only if it hides a defect or blocks the change named in Cost). At most three unless a design review was asked for. Tag a Cost on a persisted format or public or event contract this diff introduces **one-way door** (cheap to change only before merge).

The gates kill findings you *can't ground*, never the ones you can: if the Cost line holds a concrete future change, report it and state the tension ("follows the house pattern, but each new instance re-pays the same cost").

## Review Output Contract

**Severity** (Pass 1, both sections) follows the attacker's position and the damage, never the vulnerability's name:
- **Critical** (blocks): an anonymous or self-registered attacker, with no victim action, reaches code execution, takeover of any account, another tenant's or user's private data (read or write), money movement, or live production credentials. With no attacker: irreversible or unnoticed damage on a normal production path (money moved wrongly, records destroyed or corrupted, data lost with no alert).
- **High** (blocks): those impacts behind one realistic precondition (same-tenant membership, one victim click, a non-default config this project uses); a verification switched off on a production path (TLS, signature, token audience); repairable but visible or cascading damage (duplicate customer messages, stuck jobs, staleness the product can't tolerate, a path to an outage).
- **Medium** (doesn't block): needs a privileged or improbable position (tenant admin on their own tenant, insider, internal network), only aids another attack, or heals itself. Report it only if concrete and fixable in this diff.
- **Not reported**: missing defense in depth with no exploit path here (security headers, generic rate limits, verbose errors leaking nothing sensitive, routine audit events). At most one `Hardening:` line, for an area the diff edits.

A chain that changes the attacker's position goes up a level; a partial guard one layer away takes it down one. *Break when* the diff removes or weakens an existing control (rate it by what it now exposes, Medium at least) or a mandate covers the item (then it blocks). A catalog item's explicit severity wins; a matched *Finding when* line has an exploit path, so it is never Not reported.

**Labels.** Security: the most specific CWE, never a Category, Pillar or entry MITRE marks Discouraged (not CWE-20, 200, 284, 285, 287 or 840), plus `OWASP Axx:2025` (A01 access control incl. SSRF and CSRF, A02 misconfiguration, A03 supply chain, A04 crypto, A05 injection, A06 insecure design, A07 authentication, A08 integrity, A09 logging and alerting, A10 exceptional conditions) or, for AI features, `LLMxx:2026` (crosswalk and agent IDs: `llm-security.md`). Correctness: a CWE only where one fits (CWE-367 TOCTOU, CWE-362 race).

**Write the review in this shape.** The budget limits the record, never the analysis: blocking findings share 150 words × their count, spent where the triggers are; each Mandate item is one line; other finding bodies ≤60 words; the verdict block ≤80; Scope ≤90; a clean review ≤120, a checklist map aside. A material finding that won't fit is compressed to one line or overruns with the reason stated, never dropped. Sections are a menu: omit empty ones, heading included; add one the requester's decision needs. Fixes name the mechanism and its layer in prose, never a patch. Verdict: *needs fixes* if anything blocks, mandates included; *needs answers* if nothing blocks but an Unconfirmed item or a one-way door remains; else *ready*.

```markdown
**Verdict:** needs fixes (N blocking) | needs answers (N) | ready — [the requester's decision, answered against the deadline]
- Land first: [blocking items in order, and why that order]; can follow: [the rest, and on what condition]
- If a blocker misses [deadline]: [interim: flag off, internal-only, tool disabled, scope cut] — [what it keeps closed]
- Residual after the fixes: [what stays open; who accepts it]

### Prior findings (re-review)
- **[Name]** — closed at the guard's layer (`file:line`) | partial: [what remains] | open

### Pass 1 — blocking
- **Mandate: [what is required]** — [source `doc:line` or approver] — unmet | not shown: [what is missing]; blocks: [the step its source gates]; settle by: [the sign-off, a superseding decision, or the code change]
- **[Name]** (CWE-nnn, OWASP Axx:2025) — `file:line`[, …] — critical | high[ — pre-existing]
  - Problem: [one line]
  - Exploit paths: [each distinct one: attacker position → input they control → sink or missing check → impact; its precondition]
  - Fix: [mechanism, at the guard's layer]; test: [the one that fails on revert]
- **[Name]** (CWE-nnn, if one fits) — `file:line`[, …] — critical | high[ — pre-existing]
  - Failure mode: [what breaks]
  - Triggers: [each reachable one: the two actors, the retrier or the crash point, with its precondition]
  - End states: [each outcome the orderings produce: A then B → …; B then A → …]
  - Fix: [mechanism, at the guard's layer]; test: [the one that fails on revert]

### Pass 1 — non-blocking
- [≤3 Mediums in the same shape; past three, one line each: name — `file:line`]
- Safe by accident: [path — what protects it today — what would end that]
- Hardening: [one line]

### Chains
- [A] + [B] → [new position or impact] — [severity]

### Unconfirmed (critical or high if true; ≤3, then one line each)
- [deciding fact] → if true: [finding, severity]; settle by: [file to read, question for the author, or requests to fire]

### Checklist ([whose])
- [item, a few words] — met (`file:line`) | not met → [finding or mandate] | n/a | can't verify here: [what would]

### Pass 2 — informational (≤3)
- **[Smell]** — `file:line`[ — one-way door]
  - Smell: [one line]
  - Cost: [the future change it makes expensive or risky]
  - Fix: [specific: "extract X behind Y", never "improve the design"]

**Scope:** reviewed …; not reviewed …; assumed …; mandates met: …; considered and cleared: [surface — guard `file:line`]; pre-existing: …
```

Write for the author: never narrate this skill's gates or walk its catalogs; a checklist the requester or project supplies gets the item → status map, every item once.

## Self-Review

- Each blocking finding: every trigger or exploit path, each reachable past its path's state guards, with its precondition; every end state; the guard sought one layer away; a Fix (mechanism, layer) and its revert-failing test.
- Loop closed (step 5): every blocking path fails at a named guard, fixed decisions held; each agent exit checked for carried context; each fix ending a safe-by-accident path lands with or after its race's guard; order, residual and interim stated.
- Every mandate and supplied-checklist item has a status; an unmet mandate blocks and shows in the verdict.
- Every mapped entry point, effect and changed contract (callers searched) ends as a finding, an Unconfirmed item or a cleared line citing its guard's `file:line` (routine ones grouped); minus lines read; pre-existing code sharing state or effects checked; whatever rests on a library default names the pinned version.
- No Pass 1 finding in tests, fixtures or dev-only config (a committed real-format secret excepted); nothing Not-reported; no decoy.
- One root cause, one finding, one pass; the verdict matches the counts, mandates and one-way doors, and answers the requester's decision against the deadline.
- **Footprint**: blocking findings within 150 words × their count, each Mandate one line; other bodies ≤60, verdict block ≤80, Scope ≤90, a clean review ≤120 (checklist map aside), a pre-mortem ≤10 items and ≤150 words; ≤3 full Mediums and ≤3 full Unconfirmed (one line each past that), ≤3 Pass 2, per module in an audit; no patch; nothing material dropped to fit.
