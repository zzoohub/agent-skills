---
name: review-checklists
description: |
  Pre-landing code review, two passes. Pass 1 (blocking): security (OWASP Top 10:2025
  and LLM Top 10 — auth, API, business logic, supply chain, crypto, SSRF, logging,
  AI/LLM/MCP) and correctness bugs that survive green CI. Pass 2 (non-blocking):
  maintainability/design smells.
  Use when: reviewing a diff before commit/PR, security audit, or pentest prep.
  Trigger on "code review", "security checklist", "vulnerability checklist", "OWASP
  check", "auth review", "crypto review", "API audit", "race condition",
  "idempotency", "TOCTOU", "cache invalidation", "double charge", "lost update",
  "concurrent", "retry safety", "exactly once", "deadlock", "outbox", "N+1",
  "pagination", "DST", "fire-and-forget", "maintainability", "refactor smell", "tech
  debt", "design review", "god object", "fat controller", "coupling", "anemic model",
  "test quality", "will this bite us later".
  Do NOT use for: mobile-client internals (MASVS) or privacy law (GDPR/CCPA); logic
  bugs tests own; style (linters); micro-cleanups; or writing fixes.
---

# Review Checklists

One pre-landing review, two passes. Tests prove behavior on a single-threaded happy path; linters and type-checkers catch mechanics. This skill covers what they all miss: **exploits** and **bugs that survive green CI** (Pass 1, blocking), and **cost-to-change** (Pass 2, informational). Pick sections by what the diff touches — most reviews read 3-5 reference files; when in doubt, read more rather than fewer.

| Pass | Section | Blocks the commit? | Catalog |
|---|---|---|---|
| 1 | **Security** — OWASP Top 10:2025 + OWASP LLM Top 10 | A confirmed critical/high finding | `references/security/*.md` |
| 1 | **Correctness** — the bugs that survive green CI | A confirmed finding | `references/correctness.md` |
| 2 | **Maintainability** — will this stay cheap to change | No, unless project policy escalates | `references/maintainability.md` (+ `references/maintainability/<language>.md`) |

**Pass 1 (blocking).** A confirmed finding stops the commit until it is fixed or explicitly accepted with written justification — never an FYI. Medium security findings and correctness hardening notes are reported without blocking (see the finding contract for when they escalate).

**Pass 2 (informational).** Reported in the same review, kept separate from Pass 1, and blocking only when project policy escalates it. Still raise high coupling and missing abstractions early: they get exponentially more expensive to fix the longer they live.

A caller that executes exploits rather than judging design (a runtime red-team) uses the two Pass 1 sections only.

## Routing — what to read

| Reviewing... | Read |
|---|---|
| Login, signup, session, JWT, OAuth, SAML/SSO, MFA, passkeys, CSRF, cookies | `references/security/auth.md` |
| REST/GraphQL endpoints, input validation, XSS, path traversal, file upload, CORS, WebSocket, deserialization, reverse proxy / load balancer (request smuggling) | `references/security/api.md` |
| Payment, inventory, pricing, state machines, discounts, limits — the *attacker* view | `references/security/business-logic.md` |
| package.json, requirements.txt, Dockerfile, CI/CD, IaC / Kubernetes, git, secrets management | `references/security/supply-chain.md` |
| Encryption, hashing, key management, TLS, certificates | `references/security/crypto.md` |
| Headers, debug mode, default creds, cloud config, CORS, subdomain takeover, cache poisoning | `references/security/misconfiguration.md` |
| URL fetching, webhooks, callbacks, image/file proxy | `references/security/ssrf.md` |
| Error messages, logging, audit trails, alerting, exceptions | `references/security/error-logging.md` |
| LLM/AI integration, prompt handling, model output rendering, RAG, agent tools / MCP servers | `references/security/llm-security.md` |
| Concurrency, locks, transactions, retries, webhook/queue handlers, caching, background jobs, pagination or batch reads, datetime/timezone, money/inventory state machines, data crossing serialization/network/DB boundaries, schema changes — the *accident* view | `references/correctness.md` — sections: Concurrency & Races · Idempotency & Retries · Transactions & Outbox · Partial Failure & Side-Effect Ordering · Caching · Data Volume & Pagination · Time & Calendars · Trust & Serialization Boundaries · Schema & Migration Safety |
| Any diff, for design smells | `references/maintainability.md`; TS/JS diffs also `references/maintainability/typescript.md`, Rust diffs `references/maintainability/rust.md` |

When money or inventory moves, apply both views: the attacker's (`references/security/business-logic.md` — deliberate concurrent double-spend, cumulative refund/limit abuse, state-machine skips) and the accident's (`references/correctness.md` — client retries, crash mid-operation, replica lag). Same mechanics, different threat model.

## Scope

- **Security scope** is web / server / API and cloud / supply-chain, plus the AI/LLM features they host. Mobile-client-internal security (MASVS, jailbreak/root detection) and legal privacy-compliance (GDPR/CCPA) are out of scope.
- **Correctness scope** is the concurrency / retry / partial-failure / boundary class. Deterministic logic bugs belong to tests; style and formatting to linters.
- **Maintainability scope** is staff-level design judgment — see its scope guard below.
- **Not in scope for any pass:** implementing the fixes.
- **One root cause, one finding.** An exploit an attacker drives is security; breakage that needs no attacker is correctness; a cost to future change is maintainability. When a root cause fits two passes, report it once, in the pass where it blocks.

---

## Pass 1 — Security

The checklists are organized by domain (routing table above); each lists specific patterns to detect, CWE references, and its OWASP mapping.

### OWASP Top 10:2025 coverage map

| OWASP Category | Checklist File(s) |
|---------------|-------------------|
| A01: Broken Access Control | `references/security/auth.md`, `references/security/api.md`, `references/security/ssrf.md` |
| A02: Security Misconfiguration | `references/security/misconfiguration.md` |
| A03: Software Supply Chain Failures | `references/security/supply-chain.md` |
| A04: Cryptographic Failures | `references/security/crypto.md` |
| A05: Injection | `references/security/api.md` |
| A06: Insecure Design | `references/security/business-logic.md` |
| A07: Authentication Failures | `references/security/auth.md` |
| A08: Software or Data Integrity Failures | `references/security/supply-chain.md`, `references/security/api.md` (deserialization) |
| A09: Security Logging & Alerting Failures | `references/security/error-logging.md` |
| A10: Mishandling of Exceptional Conditions | `references/security/error-logging.md` |

Label findings with these 2025 IDs, not the 2021 numbering (SSRF now folds into A01; A03 is supply chain; A10 is exceptional conditions).

_AI/LLM security is governed by the separate OWASP Top 10 for LLM Applications, not the web Top 10 above. Label with the current 2026 IDs (published 2026-08: Excessive Agency rose to LLM03, System Prompt Leakage became Hidden Context Exposure at LLM08, Improper Output Handling moved to LLM10); the 2025↔2026 crosswalk heads `references/security/llm-security.md`._

### Universal red flags

These auto-fail patterns apply everywhere regardless of domain:

```
□ Secrets in code, logs, or git history (CWE-798)
□ User input reaching shell, eval, or raw queries (CWE-78, CWE-89, CWE-94)
□ Missing ownership check before data access (CWE-639)
□ State-changing request without authenticity/origin verification — CSRF, missing signature/webhook check (CWE-345)
□ TLS/certificate verification disabled (CWE-295)
□ User-controlled URL in server-side request (CWE-918)
□ Sensitive data in error responses or logs (CWE-209, CWE-532)
□ Weak or deprecated cryptographic algorithm (CWE-327)
```

## Pass 1 — Correctness

The bugs that pass tests + lint + types and still break in production. Tests run single-threaded on a happy path, so the entire class of **concurrency / retry / partial-failure / boundary** defects slips through a green pipeline — and these corrupt data, double-charge, or lose writes. Flag them when the diff touches the trigger areas in the routing table; the catalog is `references/correctness.md`. A few catalog items carry their own blocking threshold (an outbound call with no timeout blocks only when a bounded pool sits upstream; an after-commit hook instead of an outbox is acceptable only where losing the event is acceptable) — honor it.

## Pass 2 — Maintainability

The review lens nothing else covers. Tests prove *behavior*; linters and type-checkers catch *mechanics*; the security section catches *exploits*; the correctness section catches the *survive-CI bugs*. None of them tell you whether the code will be **cheap to change in six months**. That is this pass. The catalog is `references/maintainability.md`.

### Scope guard — do NOT flag what tooling already owns

| Owned by | Don't review here |
|---|---|
| Formatter (prettier/black/`ruff format`/rustfmt) | formatting, import order |
| Linter (eslint/ruff/clippy/`go vet`) | unused vars/imports, unreachable code, simple dead code |
| Type-checker (tsc strict/mypy/pyright/rustc) | within-language type errors, simple nullability |
| Tests | behavioral correctness of deterministic logic |
| The correctness section (Pass 1) | races, idempotency, cache invalidation, partial-failure, boundary defects — and missing *runtime* validation (unchecked responses/`res.ok`, unvalidated input): that a check is absent is a correctness finding, not an error-handling-design one. A type-system escape hatch at a boundary (`any`/`as`/`unsafe`/`transmute`) that makes unchecked data *look* typed is the design finding here |
| The security section (Pass 1) | exploits |
| A dedicated cleanup pass (e.g. `/simplify` in Claude Code), if available | reuse / efficiency / micro-simplification cleanups |

This pass is for **staff-level design judgment** — the cost-to-change problems none of those own.

---

## Before You Report — the gates

A checklist that cries wolf gets ignored; the fastest way to get it ignored is a false positive (or an opinion war) on every PR. Every candidate passes its gates before it becomes a finding.

### Every pass

1. **Prove it before you report it** — security: reachability and exploitability; correctness: the real trigger; maintainability: the concrete future cost. The per-pass gates below say how.
2. **Don't re-flag what the diff already fixes** — read the full diff before commenting; a vulnerability the diff removes, a guard it adds, or a smell it pays down is not a finding against this PR.
3. **Leave decoys alone** — code that matches a checklist pattern but is safe in context is not a finding: a parameterized `WHERE id = $1`, a fetch whose host is hardcoded or chosen from a server-side allowlist, an allowlisted identifier, a high-entropy random API token stored as an unsalted SHA-256 hash, bcrypt at cost 12, a numeric IPv4 form that a WHATWG URL parser normalizes before the check. At most leave a one-line "considered and cleared" note; never pad the findings with it.

### Security — exploitability discipline

1. **Trace the source** — is the input actually attacker-controlled, or does it originate from config or a trusted service? Name the entry point.
2. **Check one layer up** — middleware authz, framework auto-escaping, schema validation, or a gateway control may already guard what looks unguarded locally. A guard that lives upstream is still a guard; cite it instead of flagging its local absence.
3. **Check context applicability** — webhook/cloud/storage items assume those features exist; don't apply bucket-policy findings to a CLI tool.
4. **State the precondition with the finding** — "exploitable when X" beats "vulnerable"; it gives the reader both the risk and the test.

### Correctness — confirm it's real

1. **Look for the guard one layer away** — a unique index in the schema/migrations, a transaction or lock in the caller, framework-level dedup, a single-consumer queue. A guard that lives elsewhere is still a guard; cite it instead of flagging its local absence.
2. **Confirm the concurrency is real** — request-scoped state can't race with itself; a single-writer cron can't lose updates to itself. Name the two actors that actually collide.
3. **Confirm the retry is real** — who retries this path (client, queue, gateway)? If nothing retries it, a missing idempotency key is a hardening note, not a blocker.
4. **Confirm the scale is real** — for N+1 / unbounded-read / data-volume findings, name what makes the cardinality production-unbounded (rows per user, items per order, events per day). A loop over a fixed enum or a 30-row lookup table is not a finding.

If you can't name the trigger ("two concurrent webhook deliveries for the same order"), the finding isn't confirmed yet.

### Maintainability — is it a finding?

1. **Name the cost, or drop it** — the Cost line must name a concrete future change that gets more expensive or riskier because of this code. "Not clean" / "I'd have written it differently" is noise, not a finding.
2. **Check the codebase's own convention first** — if the diff follows the established local pattern, it is not a finding against *this PR*; consistency is itself a maintainability asset. Raise pattern-level objections once, as a separate codebase-wide proposal, not per-diff. A convention excuses *style*, not *defects*: an established smell elsewhere in the codebase does not grandfather a new instance of the same smell.
3. **Framework idiom is not a smell — and neither is the declared paradigm** — judge code against its framework's grain: an ActiveRecord model isn't an anemic-model finding; a server route colocated with its data fetch isn't a layering violation; a CLI script printing to stdout isn't a logging smell. Likewise check the project's declared architecture style (docs/arch/system.md, the README, AGENTS.md) before applying items that assume one: a vertical-slice codebase colocating handler + logic + data access per feature is not a fat-handler finding, and a functional-core module of pure functions over plain data is not an anemic model. Flag *fighting* the declared style, not *using* it.
4. **Scale the bar to blast radius** — a one-off script or internal tool doesn't need the architecture of the module every feature imports; the same shortcut that's fine in `scripts/` is a finding in `core/`. Say why this code's position justifies the standard you're applying.
5. **Rule of three cuts both ways** — don't demand an abstraction at the second occurrence, and don't bless the fifth copy either. A single-implementation interface that exists as a test seam is a seam, not premature abstraction.
6. **Findings live in the diff** — pre-existing smells the diff didn't introduce or worsen are context notes for the author, not findings against the PR.

The gates kill findings you *can't ground* — they never excuse the ones you can. If the Cost line is fillable with a concrete future change, the finding survives every gate: report it and state the tension ("follows the house pattern, but each new instance re-pays the same cost"). Naming a smell and then waiving it through a gate is the failure mode this section exists to prevent, not an application of it.

---

## Review Output Contract

Every finding carries a name, its labels, `file:line`, a severity, whether it blocks, and three body lines that end in a specific fix. The pass decides the labels and the body:

| Pass | Labels | Severity → blocking | Body lines |
|---|---|---|---|
| Security | CWE-XXX + OWASP A0X:2025 (AI/LLM issues: LLM0X:2026) | critical / high → blocking; medium → non-blocking unless it chains | Problem · Exploit path · Fix |
| Correctness | "blocking", plus a CWE where one fits (e.g. CWE-362 race, CWE-367 TOCTOU) | confirmed → blocking; downgraded by a gate → hardening note | Failure mode · Trigger · Fix |
| Maintainability | — | informational → non-blocking unless project policy escalates | Smell · Cost · Fix |

**Security (Pass 1):**

```markdown
- **[Issue Name]** (CWE-XXX, OWASP A0X:2025) — `file:line` — severity: critical | high | medium
  - Problem: [one line]
  - Exploit path: [who controls the input, what they reach — the precondition]
  - Fix: [specific remediation]
```

Severity = impact × exploitability: **critical** — remote compromise, auth bypass, secrets exposure, injection with attacker-controlled input; **high** — exploitable with preconditions, sensitive-data exposure; **medium** — hardening gaps (headers, rate limits, verbose errors). Medium escalates when findings chain (verbose error + IDOR = targeted exfiltration) — report chains explicitly.

**Correctness (Pass 1):**

```markdown
- **[Issue Name]** (blocking) — `file:line`
  - Failure mode: [how it breaks under concurrency / retry / partial failure — one line]
  - Trigger: [the real-world condition that exposes it — load, retry, crash mid-op]
  - Fix: [specific mechanism — unique index, idempotency key, FOR UPDATE, try/finally]
```

**Maintainability (Pass 2):**

```markdown
- **[Smell / Issue Name]** — `file:line`
  - Smell: [name the design smell, one line]
  - Cost: [what future change gets expensive, or which change becomes risky]
  - Fix: [specific — "extract X behind interface Y", not "improve the design"]
```
