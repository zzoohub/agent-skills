# AI Security

Decides how an AI feature stays safe when its model is wrong, hijacked or misused. Read when the AI perspective is deep. The general pass is `security-privacy.md`; this file adds only what a model changes. `ai/protocol.md` step 3 decides the autonomy level per action class; this file enforces it.

## Trust-flow Pass

Run it per model context (one session or context window) inside the STRIDE pass, before choosing any defense.

- **Inventory three columns.** *Inputs* — every channel into context (user turns, retrieved chunks, tool results, tool and server descriptions, file names and metadata, memory, peer-agent messages, images, audio), tagged untrusted, semi-trusted or attacker-writable internal (tickets, wikis, notes any public path can write). *Authority* — data scopes, credentials, state-changing tools, spend. *Egress* — outbound tools, URL fetches (path, query and DNS all leak), auto-rendered images and links, third-party search queries, drafts or tickets others read, network from a code runtime, telemetry sinks.
- **Every modality is an injection channel.** Normalize at each ingest and render boundary — strip invisible characters, hidden text and metadata payloads; transcribe or OCR images and audio before text filters run. This closes the invisible channel, not visible payloads.
- **Taint is sticky.** Once untrusted text enters a context, every later plan, tool choice and argument from it is attacker-influenced, and so is everything derived from it — summaries, compaction output, extracted facts, embeddings, memories, sub-agent results. Tool policy keys on the context's taint, not only on who the user is.
- **Hidden context is discoverable.** Ask: "If the whole assembled context — system prompt, tool schemas, retrieved policy, routing rules — were published, what would break?" Only "nothing important" passes: no credentials, internal endpoints, tenant identifiers or authorization logic in prompts, tool descriptions or tool parameters.
- **Record** each flow as a threat-summary row (`templates/system.md` §5) and, when material, a security ASR (filter #8); per-feature verdicts go in the feature doc's §2.

## Three-leg Check & Structural Breaks

Per context: **[A]** reads untrusted input · **[B]** reaches sensitive data or systems · **[C]** changes state or communicates externally.

- **All three** → the context must not act autonomously: remove a leg — split contexts, drop or proxy egress (usually cheapest), narrow the data — or gate every [C] action with deterministic code or a human. **Two** → record the residual risk; least privilege, caps and monitoring still apply. A one-way switch (egress off before internal data is read) counts only when the runtime enforces it; a context is "fresh" only if it never read untrusted content. *Break when:* a read-only feature over public data with no secrets and no egress — detection plus output validation is proportionate.
- **Breaks, least capable first**: *action-selector* (tool output never returns to the model); *plan-then-execute* (actions fixed before untrusted data is read); *quarantined reader* (one tool-less call per untrusted item, returning only typed values from a closed set); *dual model* (the planner sees only symbolic handles); *code-then-execute* under a policy-enforcing interpreter; *context minimization*. Combine per use case; a general-purpose agent holding all three legs cannot be fully secured.
- **Arguments, not only control flow.** Injected data can still choose recipient, amount, URL, path or query: attach provenance to values and enforce data-flow policy at the tool boundary — a recipient comes from the user's request or directory, a payee from an allowlist.
- **Typed outputs don't stop injection.** A closed label set limits what the model can say, not which allowed value an attacker steers it to — a decision-tier classifier reading untrusted text can be flipped. Every value in the set must be safe for an attacker to choose, or the decision is gated like an action; the calibration gate (`ai/evals.md`) measures honest error, not adversarial flips.
- **Detectors lower the odds; they are never the boundary.** Classifiers, delimiters, role tags, "ignore instructions in documents" and guard models sit inside an architecture that stays safe when they fail. Accept a defense only on evidence from adaptive attackers who know its full specification, and re-test after every model, prompt or tool change. Placement by harm and latency → `ai/production.md`.
- **Output is untrusted at every sink**: encode for the sink, parameterize queries, canonicalize paths; no renderer auto-fetches remote content (or a proxy strips data-bearing parameters); generated code never deploys without review.

## Authority & Identity

- **Agents are principals** in the principal table (`security-privacy.md`): agents need identities (not just user tokens) for audit and access control. Long-lived or shared agents get a governed non-human identity with a named owner.
- **Actor + subject.** Every action carries the agent (actor) and the person or tenant it acts for (subject) down the call chain; downstream services authorize on the pair plus a task-scoped grant.
- **Delegate, don't impersonate.** Effective permission = the requesting principal's current permission ∩ the agent's grant ∩ the task's scope — least agency. Credentials are short-lived, audience-bound and scope-limited, minted by token exchange at each hop; never forward the user's token, never run as a privileged service role, no static agent keys.
- **Complete mediation outside the model.** A policy-enforcement point outside the agent runtime checks the tool, its arguments and the context's taint at execution time, enforces the action class's autonomy level, and holds or mints the credentials. Authorize server-side. Pass the user's auth context with the call; don't trust any user-id or permission the model puts in the parameters. Fix authority before the run — anything discovered mid-run is out of scope until independently validated; re-authorize every privileged step; treat inter-agent messages as untrusted input, authenticated and typed.
- **Tool-protocol servers** (resource-server basics → `ai/agentic.md`): least-privilege initial scopes with step-up per operation; a proxying server gets consent per client, never one shared upstream identity (confused deputy); possessing a handle is never authentication; discovery and metadata fetches get SSRF controls.

**Authority record.** One row per tool/action in the feature doc §2 (template: `ai/protocol.md`); cross-feature items — agent identities, enforcement points, approval service, kill switch — sit in `templates/system.md` §5.

| Column | Definition |
|---|---|
| Tool / action | One row per distinct effect, not per endpoint |
| Effect (read / write / sends outside) · reversible? | Any outbound request (fetch, search, render, ping) is *sends outside*, never read-only; reversible = the system can undo it within a stated window |
| Data scope (principal ∩ agent grant ∩ task) | The predicate the enforcement point applies, e.g. "this ticket's customer only" |
| Caps | Per call and per period — value, volume, count; spend caps → `ai/production.md` |
| Approval (who · bound to exact parameters · expiry) | "None — below cap" is valid; see Approval Integrity |
| Enforced by (code outside the model) | The component that blocks it — enforcement point, constraint, downstream limit; "the prompt" is never an entry |
| Guard (adversarial eval case) | The case that must pass on every run (`ai/evals.md`) |

The model proposes, code disposes: every limit is enforced in deterministic code, never by prompt, and every row emits an audit event (actor, subject, parameters, decision).

## Containment & Consequence

- **Containment first.** Design so a fully hijacked agent still cannot cause the harm; add model-layer defenses after. Ask: "Assuming injection succeeds, what is the worst available action, and which deterministic control stops it?"
- **Sandboxes.** Choose isolation by who wrote the code and what it can reach: trusted, reviewed code may share a kernel; model-generated or user-supplied code gets a syscall-filtering sandbox or a hardware-virtualized boundary, built from proven primitives. Always: filesystem and network isolation; default-deny egress through an allowlisting proxy that checks destination and credential provenance (an allowlisted domain that accepts attacker-supplied credentials is still an exit); no credentials inside — the proxy attaches short-lived, task-scoped ones; a fresh environment per run with CPU, memory and time limits; a validation gate before generated code runs; no workspace configuration executed before the trust decision; never evaluate model output inside a production process. Confidential computing protects data in use from the operator; it does not contain untrusted code.
- **GUI- and browser-driving agents** (only where no structured tool exists — `ai/agentic.md`): a dedicated isolated session holding only the task's credentials (logged out by default), deny-by-default egress including uploads, and no rendering of attacker-controlled URLs or images where secrets are present. Every page is hostile, and the risk compounds across pages.
- **Consequence tiers.** Each tool carries a runtime-enforced manifest: read-only or cheaply reversible → automatic; medium impact → logged or warned; irreversible, high-value or externally visible → approval; above limits → blocked. A chain is gated at its highest class. Redesign for reversibility: draft instead of send, soft delete, delayed send, snapshot before destructive operations.
- **Trajectory invariants.** Individually allowed steps can add up to harm: enforce cumulative value and volume limits per run and period, information-flow labels (data read from a sensitive source never reaches an external sink), and an aggregation policy that blocks joins revealing what no single source may. Ask: "Which harmful outcome can a sequence of allowed steps reach?" *Break when:* read-only or low-stakes flows — per-action checks suffice.

## Approval Integrity

An approval counts only if it renders the exact, canonicalized parameters deterministically — never a model-written summary — with invisible characters shown or stripped; is bound to them (single-use at high assurance); expires, a timeout blocking the action; and reaches someone able to judge it (an approver who cannot read the draft's language is not oversight). Which classes need approval is set in `ai/protocol.md` step 3; below a cap, deterministic limits replace approval — approving everything trains rubber-stamping. Track approval, time-to-approve and reversal rates: a near-total approval rate means the approval is not a control. An automated reviewer may assist only if it sees just the user's request and the proposed action (never the agent's reasoning or untrusted content) and its miss rate is measured — never in place of human review of high-stakes infrastructure changes. *Break when:* sign-off per action is mandated, or actions are rare and high-stakes — keep per-action human approval. Durable approval wait → `ai/agentic.md`.

## Stop Controls

- **Kill switch** — out of band, per feature, tenant and agent: halts running instances, revokes their credentials, drains queued actions; exercised before launch. As a flag, its unreachable default halts consequential actions (`system-architecture.md` § Feature Flag Architecture). A supply-chain kill switch disables one tool, connector, skill or prompt version.
- **Credential revocation** reaches every issued token within a stated window; short lifetimes bound it.
- **Break-glass** — human-authorized, time-boxed, separate credentials, alerting, audited.
- **Budgets and hard caps** at every scope, their UX and the cost-attack controls → `ai/production.md`.

## AI Data Protection

- **Containment over redaction** for data the task needs: in-boundary hosting, no-retention endpoints, retrieval scoped to the requester; redact only what the task does not need, and run evals with redaction on. *Break when:* rules forbid identifiers leaving and no in-boundary option exists — redact, then measure the quality loss.
- **Provider data-flow ledger**, per provider × feature: training use; retention of abuse-monitoring logs and stored state; stateful features outside any zero-retention arrangement; processing region; sub-processors; the provider's role (processor or controller). Verify terms at design time and record them with source and date in the provider ADR; enforce the approved feature set in the gateway or adapter, not only in the contract; each provider is a processor row in the Stage-6 inventory.
- **Tenant partitioning of shared AI state** — vector namespaces and indexes, memory, response and semantic caches, self-hosted prefix caches — by tenant, and by user or session for sensitive work. Where a hosted prefix cache is shared account-wide (`ai/production.md`), tenant secrets stay out of shared prefixes. Embeddings, vector backups and exports are as sensitive as their sources — text is recoverable from vectors. Query-time authorization → `ai/context.md`; cache keys → `ai/production.md`.
- **Memory writes are privileged**: quarantine instruction-like content until reviewed; tool or agent output never auto-promotes into trusted memory or shared instruction files (memory governance → `ai/context.md`).
- **Audit record vs content trace.** The audit record — principal, acting agent, model snapshot, provider, tool calls with redacted parameters, policy decisions, approvals, retrieved document ids — joins the audit trail (`security-privacy.md`) and is kept as long as obligations require. Content traces (prompts, completions, chunks, reasoning) are a sensitive data class with their own inventory row; capture policy → `ai/production.md`.
- **Eval and training sets** take production traffic only with a recorded legal basis and de-identification; customization consequences → `ai/protocol.md`.

## Extension Supply Chain

Skills, tool-protocol servers, plugins, connectors and AI SDK or gateway packages are executable code plus prompt input inside your boundary. Admit them like production dependencies: a publisher allowlist; pin by content hash; review diffs on every update — tool descriptions and skill bodies included — and re-approve on change; run them sandboxed with no ambient credentials and an egress allowlist; fully qualified tool names that fail closed on ambiguity; no runtime auto-install from public registries. Third-party annotations (read-only, destructive) are untrusted hints. Configuration that launches local tool servers is code execution — restrict who can write it. Keep a per-deployment inventory of every model, tool server, skill and AI package with pinned digests. Ask: "Who can change which tools or skills our agent loads, and what runs with which credentials when they do?" *Break when:* first-party extensions reviewed in the same repository and CI carry ordinary code-review risk, plus sandboxing.

## Governance Design-ins

Ask the caller which jurisdictions, sectors and contracts apply (unanswered → an `A-nn` assumption plus a blocking Open Question); verify obligations and dates at design time; record source and date in the AI regulatory-classification ADR (`design-flow.md` § Minimum ADRs). Design these in where the classification calls for them — cheap now, expensive to retrofit:

- **Intended-purpose classification → role and risk class.** Ask: "Does the feature make, or materially influence, a consequential decision about a person (e.g. access to employment, credit, education, essential services, insurance, housing, healthcare or justice), act as a safety component, or use biometrics?" Each applicable regime's own category list governs — verify it at design time. If yes, the class is an architecture input (a regulatory ASR, filter #7). Integrating, rebranding, substantially modifying or repurposing a model can change your role; re-classify on every repurposing.
- **AI-interaction disclosure** at first contact, unless obvious.
- **Marking of generated media** — machine-readable provenance added at generation time, surviving downstream transforms.
- **Decision-time event logs** — the audit record above plus the decision-tier record (`ai/protocol.md`), retained as obligations require.
- **Human oversight** — override, disregard or reverse an output; stop to a safe state; cues against automation bias.
- **Incident path** — detection, triage and reporting within the regime's deadline, recorded as a constraint.
- **Explanation and contest path** for consequential decisions about people — notice, a plain-language reason, human review on request, data access and correction.

Each becomes a requirement → control → evidence row (`security-privacy.md`).

## Review Scoping

The current OWASP Top 10 for LLM Applications (the model as a component) and Top 10 for Agentic Applications (the model as an actor) scope a review — directional, never a substitute for this system's threat model. Give each listed risk a structural owner in the design (e.g. hijacked goals or instructions → three-leg check, misuse of granted tools → mediation, an agent acting outside its mandate → kill switch — whatever the current edition calls them); a risk with no owner is a finding. Per-diff checks → the `review-checklists` security pass, if available; runtime proof of injection or excessive agency → the `adversarial-execution` capability, if available.

## Red Flags

- **Three legs, one autonomous context** — untrusted input, sensitive data and an outbound channel (rendered images and links, URL fetches and search queries count).
- **Detection as the defense** — "we delimit, detect or sanitize injections" is the whole story, or a detector's accuracy is cited as proof.
- **Authority in the model** — a rule enforced only by prompt instruction (it leaks with hidden context and decays under compaction); secrets, authorization logic or tenant ids in model-visible context; an agent that runs as a privileged service role, forwards the user's token or trusts ids the model supplies.
- **Open or mislabeled tools** — fetch, search, render or ping auto-approved as "read-only"; an open-ended tool (raw query, shell, fetch-any-URL) in a context that reads untrusted text.
- **Approvals that don't protect** — a model-written summary instead of exact parameters, no expiry, a near-total approval rate, or autonomy widened because nothing bad has happened yet.
- **Unvetted extensions** — third-party tool servers or skills unpinned, unreviewed, auto-installed, or running with the user's full privileges.

Recall cues: Saltzer & Schroeder; Willison (the lethal trifecta); Beurer-Kellner, Tramèr et al. (design patterns against prompt injection); Debenedetti et al. (information-flow control outside the model); Nasr, Carlini, Tramèr et al. (adaptive attacks).
