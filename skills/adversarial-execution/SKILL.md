---
name: adversarial-execution
description: |
  Runtime adversarial verification (DAST) — EXECUTE, against a running app in an isolated
  environment, the exploits a static diff review can only name. Use when a high-risk change
  (auth/session, payments, credential issuance, irreversible data, DB migrations, LLM/agent
  features) needs live proof that a named risk can or cannot be reproduced: races, token/nonce
  replay, cross-tenant IDOR, illegal state transitions, limit abuse, migration dry-runs, SSRF,
  and prompt-injection / excessive-agency abuse of a running agent. Trigger on "adversarial
  test", "exploit the running app", "DAST", "abuse testing", "red-team this change", "prove the
  race", "reproduce the exploit", "jailbreak the running agent", "prove the SSRF".
  Do NOT use for: the threat taxonomy itself (use security-checklists and correctness-checklists —
  this skill EXECUTES their findings); static review with no running app; happy-path browser/E2E
  checks (use the qa capability); or implementing the fixes.
compatibility: Host-coupled — requires a running app in a disposable, isolated environment (never prod) plus a way to drive concurrent, replayed, and multi-session traffic against it (a Bash/curl runtime, or a browser driver such as the Playwright MCP). With no live target it produces the attack plan and reports the missing environment as the blocker, rather than attacking a real one.
---

# Adversarial Execution

The **runtime arm of the static review.** The `security-checklists` and `correctness-checklists`
capabilities *name* the ways a change breaks — and their own discipline stops at naming ("if you
can't name the trigger, it isn't confirmed yet"). The attacker-view file `business-logic.md` even
ends checks with a runtime instruction — *"send 10 identical requests simultaneously"* — that a
static, read-only reviewer cannot run, and a black-box functional verifier is forbidden to form
(it may not read the diff to build the hypothesis). This skill is where those stranded instructions
get **executed**: you take a named risk and reproduce it against a running app, or prove you couldn't.

**A reproduction is the only currency.** You never argue "exploitable when X" — you demonstrate the
request sequence that broke the invariant.

## 1. Reuse the catalog — never reinvent the taxonomy

You carry no list of your own. The catalog already exists; read the section that matches the change
(via these capabilities, if available) and supply the verb it can't — **fire it**:

- **Business-logic abuse** — race/double-spend, numeric manipulation, state-machine violations,
  discount/refund/limit abuse, privilege boundaries → `security-checklists/references/business-logic.md`
  (the *attacker* view, written to be executed).
- **Auth / session / identity** — IDOR, session fixation, JWT alg/`none` confusion, OAuth
  state+nonce+PKCE, SAML XSW/replay, WebAuthn → `security-checklists/references/auth.md`.
- **Correctness under load** — idempotency, retries, partial failure, caching, boundaries →
  `correctness-checklists`.
- **AI/LLM agent abuse** — prompt injection (direct + indirect via RAG-poisoned or fetched content),
  jailbreaks, excessive agency / unauthorized tool-calls, cross-user RAG retrieval, system-prompt /
  secret extraction → `security-checklists/references/llm-security.md` (the OWASP LLM Top 10 — it even
  names the runtime red-team tooling: Garak, PyRIT, Promptfoo).
- **Server-side request forgery** — outbound fetch pushed to cloud-metadata / internal hosts, DNS
  rebinding, IP-encoding bypass, webhook/callback abuse → `security-checklists/references/ssrf.md`.
- **Runtime injection & untrusted input** — stored XSS, path traversal, malicious file upload, unsafe
  deserialization, request smuggling → `security-checklists/references/api.md`.

## 2. Safe target environment — NON-NEGOTIABLE

You send mutating, abusive, sometimes destructive traffic. Before any attack, confirm the target is
safe to break:

- **Never production. Never a shared dev/staging others rely on.** Only a disposable, isolated
  instance you may corrupt and reset.
- **Seed from prod-*shape*, anonymized** — realistic volume/distribution/edge cases; never real PII
  or real credentials.
- **Stub every irreversible side effect** — outbound email/SMS, payment capture, webhooks, any
  **LLM/agent tool-call that performs a real action** (refund, delete, send, publish), and especially
  **credential/VC issuance to a ledger, registry, or chain** (testnet/stub only — an issuance-abuse
  test fired at mainnet is itself the incident).
- **Allow-list the target host — and fail closed on the app's own egress.** A misconfigured base URL
  must not hit prod or a third party; likewise an SSRF or webhook repro must be contained so it can't
  actually reach a real cloud-metadata endpoint, internal service, or third party. Prove the
  *reachability* (the request left, the guard was absent); don't complete the exfiltration — landing
  on a real internal target is itself the incident.
- **Reset between runs** so a destructive attack doesn't poison the next.
- **Read-only on the codebase.** You attack the running system; you never edit code. Report — the
  developer fixes.

If no such environment exists, **that is the blocker to report** — building it precedes any attack.

## 3. The techniques static review can't run

This is the whole value — setups a single-request, single-actor, code-blind verifier structurally
cannot create:

- **Concurrency / race.** Fire N simultaneous identical requests at one state change and check the
  invariant held exactly once — `seq 20 | xargs -P 20 -I _ curl -s -X POST …`, or parallel browser
  contexts. Targets: double-spend, oversell, double-issue, single-use coupon/credential redeemed
  twice, limit bypass.
- **Replay.** Capture a token / nonce / one-time link / idempotency key and resend it — after use,
  after expiry, after revoke. Targets: nonce/OTP replay, idempotency duplication, revoked-credential
  acceptance.
- **Multi-session / cross-tenant IDOR.** Hold two real sessions (attacker + victim, or tenant A + B).
  With A's session, read or mutate B's object by ID swap, parameter tamper, forced browsing. The
  highest-yield runtime check — and impossible single-actor.
- **Illegal state-machine transitions.** Craft requests that skip or revisit steps — POST straight to
  the final step, present-after-revoke, re-claim a consumed benefit, transition without the guard.
- **Numeric / limit abuse.** Negative / zero / overflow quantities, client-tampered
  price/discount/currency, `limit=999999`, unbounded export.
- **Prompt injection & excessive agency** (LLM/agent changes). The setups a single-request, code-blind
  verifier can't build: plant an *indirect* injection in content the agent will retrieve (a poisoned
  RAG document, a ticket body, a fetched page) and check whether it steers a real tool-call; drive a
  *multi-turn* jailbreak (gradual escalation, many-shot) that single-turn filters miss; hold two users
  and see whether one's retrieval surfaces the other's documents. Target the invariant the tools are
  supposed to enforce — "the agent never refunds / deletes / sends outside the caller's own
  authorization." Fire what `llm-security.md` names; don't restate it.
- **Migration dry-run** (schema changes). Run the migration against a prod-*census* clone and verify
  the named zero-downtime patterns actually hold — lock duration, the app working in the
  **intermediate state** (old code + new schema, *and* new code + old schema), backfill
  idempotency/resumability, rollback. Don't invent the method — execute the patterns
  `correctness-checklists` points to (the `database-design` / `postgresql` migration references),
  against a disposable DB.

## 4. Confirm, but never acquit

- A finding is real **only with a reproduction** — the exact request sequence that violated the
  invariant. No repro → not a finding (and no false positives: a reproduction is proof).
- **Failure to reproduce ≠ safe.** You could not build the right conditions; that is not proof the
  flaw is absent. A risk the static review named and you couldn't trigger stays **OPEN** (documented),
  never closed. You confirm; you do not clear. But **open ≠ a work order** — what it obligates is
  decided by disposition (next section).
- Keep an attempt log — invariant → attack → result — so a clean pass is *evidenced coverage*, not a
  shrug.

## 5. Disposition — the verdict is not the fix list

Two outputs, two obligations; conflating them is where this turns into gold-plating.

- **Reproduced exploit → fix once, at the invariant's choke point** (unique constraint, `FOR UPDATE`, `WHERE status='pending'`, authz at the query). Checks sprinkled around it hide the real guard — true defense-in-depth is independent layers failing closed on the *same* invariant, not two on one layer.
- **Un-reproduced risk → obligates no code.** It's coverage evidence, logged as residual risk. "Open, not cleared" = *not certified impossible*, not *go build a defense*; the gate passes with these present by design.
- **Guard one anyway only when blast-radius × plausibility beats the guard's cost** — a high-value invariant (money, auth, tenant, irreversible) plus a cheap canonical guard earns the hedge; a speculative trigger, or a guard heavier than its risk, is deferred.
- **The stopping line is invariants, not attacks** — a slice's invariants are a short list; attacks aren't. Defend it to the depth a *named, plausible* attack reaches, then stop. Can't name the trigger? Don't write the defense — log it.

## 6. Output + promote to CI

```markdown
## Adversarial Execution Report

**Target**: [isolated env URL] · **Change**: [high-risk flag(s) fired] · **Catalog**: [sections executed]

### Confirmed Exploits (BLOCKING)
- **[Name]** — invariant violated: [what must never happen]
  - Repro: [exact request sequence / concurrency setup / replayed token]
  - Impact: [what an attacker achieves]
  - Fix locus: [the one choke point the invariant funnels through — developer implements one guard, not scaffolding around it]
  - Promote: [the CI security-regression test this becomes — red now, green after fix]

### Attempted, Not Reproduced — residual risk (non-blocking; NOT a fix backlog)
- **[Name from reviewer/catalog]** — attack tried: […] — result: not reproduced under [conditions].
  - Disposition: [accept & log | guard now — only if blast-radius × plausibility warrants the cheap guard]. Recommend; do not mandate.

### Coverage
- Invariants targeted: […] · Techniques run: [concurrency / replay / IDOR / state / numeric / migration]

### Verdict
- [ ] No exploit reproduced → adversary gate PASSES
- Any confirmed exploit → BLOCKS merge; route to developer; re-run after fix
- Residual (not-reproduced) risks do **not** block — they ship as logged, accepted risk unless a Disposition above says to guard now
```

Every confirmed exploit becomes a **CI security-regression test** (red now, green after the fix) —
the same way a permanent external contract is promoted to a CI-resident wire-guard spec. Pin whatever
made the repro non-deterministic — the concurrency timing, the injection seed, the fixture it needs —
so the guard fails reliably on a regression instead of flapping: a flaky security gate gets muted, and
a muted gate protects nothing.

## Trigger → battery

Run only the rows whose high-risk flag fired.

| High-risk flag | Catalog section | Runtime techniques to fire |
|---|---|---|
| auth / session | `auth.md` | cross-tenant IDOR, session fixation, JWT alg/`none`, token+nonce replay, OAuth state/PKCE, rate-limit & enumeration |
| payments | `business-logic.md` (Race, Numeric, Refund) + `correctness` (idempotency) | concurrent double-charge, idempotency-key replay, negative/overflow amount, client price tamper, over-refund |
| credential / VC issuance | `auth.md` (nonce/replay/alg, WebAuthn/SAML) + `business-logic.md` (State Machine, single-use) | present-after-revoke, re-issue-then-use-old, signature/alg downgrade, nonce replay, holder ≠ subject |
| irreversible data | `correctness` (idempotency, partial failure) + `business-logic.md` (limit/refund) | retry/replay for duplicate effect, race to bypass once-only, partial-failure double-write |
| DB schema / migration | `correctness` (Schema & Migration Safety) → `database-design` / `postgresql` refs | migration dry-run on prod-census: lock time, intermediate-state app, backfill idempotency, rollback |
| AI/LLM agent (tool-enabled) | `llm-security.md` (+ `correctness` for tool-output handling) | indirect injection via retrieved/RAG content → unauthorized tool-call, multi-turn jailbreak, cross-user RAG retrieval, system-prompt / secret extraction, model output consumed unsanitized |
| server-side URL fetch / webhooks | `ssrf.md` | push outbound fetch to cloud-metadata (IMDSv1 chain) / internal host, DNS rebinding, decimal/hex/octal IP bypass, blind-vs-returned response |
| file upload / deserialization | `api.md` | malicious upload (SVG→ImageMagick SSRF/RCE, polyglot, path traversal on filename), unsafe deserialization gadget, content-type confusion |
