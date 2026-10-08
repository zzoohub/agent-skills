# LLM, AI & MCP Security

> OWASP Top 10 for LLM Applications **2026** (GenAI Security Project). Method, severity and the output contract live in SKILL.md. Label with the 2026 IDs; the crosswalk to 2025 IDs (for tools and reports still on the old numbering):

| 2026 | Risk | 2025 |
|---|---|---|
| LLM01 | Prompt Injection | LLM01 |
| LLM02 | Sensitive Information Disclosure | LLM02 |
| LLM03 | Excessive Agency | LLM06 |
| LLM04 | Supply Chain | LLM03 |
| LLM05 | Data and Model Poisoning | LLM04 |
| LLM06 | Unbounded Consumption | LLM10 |
| LLM07 | Misinformation | LLM09 |
| LLM08 | Hidden Context Exposure (was System Prompt Leakage) | LLM07 |
| LLM09 | Vector and Embedding Weaknesses | LLM08 |
| LLM10 | Improper Output Handling | LLM05 |

For agent-level risks the LLM list doesn't cover (memory poisoning, inter-agent channels, multi-step compromise), label with the current **OWASP Agentic Top 10** ID (ASI01–ASI10) — never invent one.

## Prompt Injection (LLM01)

**Assume the model obeys injected text; review what it can do once it does.** Delimiters, "ignore untrusted input" instructions, and input sanitizing are **not** fixes — do not accept them as the control (CWE-1427).

**Direct** (the user is the attacker): a finding only when the model holds authority the user doesn't — it can call tools or read data the user couldn't reach directly. User text in a system prompt, where the model can do nothing the user can't, is not a finding.

**Indirect** is a finding when one context holds all three legs:
1. **Attacker-influenceable content** — retrieved docs, web pages, email, tickets, other users' messages, tool results, third-party tool descriptions. Hidden Unicode and markdown carry instructions (the EchoLeak class, CVE-2025-32711, was zero-click via a crafted email reaching RAG).
2. **Data or tools beyond that party's authority** — other users' or tenants' records, retrieved documents, memory, secrets, internal notes and URLs: anything in the context its author couldn't read or do.
3. **An exit** — a side-effecting tool, an outbound fetch, links/images auto-rendered in the response, and every free-text argument the model writes (an email body, a ticket comment, a URL query, a file).

**Close each path, not a slice of a leg.** For every exit ask *who receives it* and *what it can carry*: the model can copy anything in its context into a free-text argument, so binding the recipient (the requester's own address, an allowlisted domain) leaves the body open, and a reply to the right customer can carry another customer's record. A fix holds only if, on that path, nothing the context holds or can call exceeds the content author's authority, or no exit can act beyond that authority or carry context data to anyone not entitled to read it. So caller-scoped credentials and tool authorization close a path only when the content's author has the caller's authority (never an operator's agent over tickets, CRM records or an inbox), and an egress allowlist only when every allowed destination may read the whole context (first-party hosts, never a customer or user list). Fixes that hold: sensitive data kept out of any context that has an exit, or the exit moved to a step that never sees it; exits with no free text (server-filled templates, enumerated values); no auto-rendered external URLs. A confirmation removes the exit leg only when the person approves the exact call (every parameter and the full model-written content, not a model-written summary or rationale, ASI09) and the call that runs is bound to what was approved. Report the leg still standing, not the presence of untrusted text.

## Supply Chain & Poisoning (LLM04, LLM05)

**Finding when:** an untrusted model file loads through a pickle-based path (`torch.load` with `weights_only=False`, whose default is `True` from PyTorch 2.6; `joblib.load`), or `trust_remote_code=True` runs on a model an attacker can choose: remote code execution, not just integrity (CWE-502). A RAG index or fine-tune corpus anyone can write to without review.

**Not a finding:** a floating model alias (`*-latest`): a reliability note, not a security finding.

## MCP Server Security

**Finding when:**
- A third-party tool **description or result** trusted as instruction rather than data ("tool poisoning"): treat both as attacker-influenceable content (LLM01). Its **arguments** are an exit: whatever the model writes into them reaches that server's operator.
- **Remote (HTTP) server:** it accepts OAuth tokens without checking they were issued for it (the **audience**), or passes them through upstream; it exposes non-public tools or data with no authentication; a token rides in a query string; a server-assigned session ID is used as authentication, or a state or handle isn't bound server-side to the authenticated user.
- **Proxy server** (static upstream client ID): no per-client consent before the upstream flow, or a `redirect_uri` matched by pattern rather than exact string (the confused-deputy path).
- **Server-side client** fetching OAuth metadata or discovery URLs with no SSRF guard (`ssrf.md`).
- **Local server:** not pinned or sandboxed, or a one-click config that executes a command with no consent shown; credentials passed as arguments rather than through scoped environment variables.

**Not a finding:** a stdio server without network auth: it is code you execute locally, so the controls are pinning, sandboxing and scoped env credentials. A remote server that serves only public data without OAuth.

## Excessive Agency & Tool Use (LLM03)

**Finding when:** a tool runs with service/admin credentials instead of the current user's authorization (a request can act outside the caller's own rights); a tool is broader than its task (write where read suffices; shell, raw SQL or arbitrary HTTP where one narrow operation would do); the agent can widen its own authority (add tools or MCP servers, edit its permissions, instructions or memory); a destructive or irreversible call, or an outbound one that no fix above closes, has no confirmation or one that doesn't bind the exact call; tool outputs are fed back and acted on with no validation; there is no cap on tool-call count, depth or run time for an agent loop. The invariants: **the agent never acts outside the caller's own authorization, and no exit carries data to anyone not entitled to read it.**

## Hidden Context Exposure (LLM08)

**Finding when:** the system prompt, developer instructions, retrieved policy text, or tool/function schemas can be read back by the user **and** they contain secrets, credentials, or business rules you can't afford to publish. Fix: keep secrets out of the context window; filter responses for prompt fragments as defense in depth (a "don't reveal your instructions" meta-instruction is not sufficient alone).

**Not a finding:** exposed context that holds nothing sensitive.

Neighboring labels: memory that serves one user's data to another is LLM02, plus LLM08 when it rides in hidden context; memory poisoning (attacker text stored and acted on later) is ASI06; spoofed, replayed or tampered inter-agent messages are ASI07.

## Output Handling (LLM10)

Model output is untrusted input to whatever consumes it. **Finding when** output reaches a sink unchecked: rendered as raw HTML (XSS, CWE-79), run as SQL (CWE-89), passed to `eval`/`exec`/shell (CWE-94), used as a redirect/fetch URL (SSRF/open redirect, CWE-918), or used as a filename. Validate shape/enum before acting; bound output length.

## Sensitive Data & Consumption (LLM02, LLM06)

**Finding when:** secrets, credentials, connection strings or internal hosts embedded in a prompt template or tool schema; a provider API key shipped to the client (a public-prefixed env var, an SDK's browser opt-in such as `dangerouslyAllowBrowser`; CWE-798): call the model from the server, under the per-principal cap below; records placed in context with more fields or rows than the task needs; memory, history or a cache carried across users, tenants or sessions; RAG retrieval that ignores the user's document-level permissions, so one user's query surfaces another's data (CWE-862); prompts or completions logged with PII or secrets (CWE-532); no per-principal token/cost cap on model or tool spend (budget-exhaustion, CWE-770). Each of these also feeds leg 2 of any injection path above. Provider data-handling agreements and user consent are legal/compliance, out of scope here.

## Red-team tooling

Runtime probing belongs to the adversarial-execution capability, if available: **Garak** and **PyRIT** probe, **Promptfoo** regression-tests your own injection and jailbreak set. In a review, name the control (an injection classifier on inputs and retrieved content, an output classifier, both regression-tested), not a vendor product.
