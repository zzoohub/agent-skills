# AI Security

Decides how an AI feature stays safe when its model is wrong, hijacked or misused. Read when the feature is deep. The general threat pass (principals, secrets, data duties, supply chain) belongs to the software-architecture capability, if available; this file adds only what a model changes.

## The premise: assume injection succeeds

No detector stops prompt injection reliably: published defenses fall to attackers who adapt to them, and success climbs with every retry. The weakest route decides, so a fallback model, a second agent or a less defended endpoint is where the attack lands. Design the system to stay safe when the model is fully hijacked, add model-layer defenses afterwards, cap the attempts one principal gets, and give every route the same safeguards. For each feature: *assuming injection succeeds, what is the worst available action, and which deterministic control stops it?*

## Trust-flow pass

Per model context (one session or context window), inside the threat pass:

- **Inventory three columns.** *Inputs*: every channel into context (user turns, retrieved chunks, tool results, tool descriptions, file names and metadata, memory, messages from other agents, images, audio), tagged untrusted, semi-trusted, or internal but attacker-writable (tickets, wikis, anything a public path can write). *Authority*: data scopes, credentials, state-changing tools, spend. *Egress*: outbound tools, URL fetches (path, query and DNS all leak), auto-rendered images and links, search queries, drafts others read, network from a code runtime, telemetry.
- **Every modality is an injection channel.** Strip invisible characters, hidden text and metadata payloads at ingest; transcribe or OCR audio and images before text filters run.
- **Taint is sticky and travels.** Once untrusted text enters a context, every later plan, tool choice and argument is attacker-influenced, and so is everything derived from it: summaries, compaction output, memories, sub-agent results. Provenance has to follow the data across tools, memory and agents, or a downstream agent will read untrusted content as trusted.
- **Hidden context is discoverable.** If the whole assembled context were published, what would break? Only "nothing important" passes: no credentials, internal endpoints or authorization logic in prompts, tool descriptions or parameters.

## The three-leg check

Per context: **[A]** reads untrusted input · **[B]** reaches sensitive data or systems · **[C]** changes state or communicates externally.

- **All three** (a session should hold at most two) → the context must not act autonomously. Remove a leg (split contexts, drop or proxy egress, which is usually cheapest, or narrow the data), or gate every [C] action with deterministic code or a person. **Two** → record the residual risk; least privilege, caps and monitoring still apply. *Break when* a read-only feature over public data has no secrets and no egress.
- **Structural breaks, least capable first**: tool output never returns to the model · actions fixed before untrusted data is read · a quarantined reader (a tool-less call per untrusted item that returns only typed values from a closed set) · a planner that sees only symbolic handles · generated code run under a policy-enforcing interpreter. A general-purpose agent holding all three legs cannot be fully secured.
- **Arguments, not only control flow.** Injected data can still choose the recipient, amount, URL or path: attach provenance to values and enforce data-flow policy at the tool boundary (a recipient comes from the user's request or a directory, a payee from an allowlist).
- **Typed outputs do not stop steering.** A decision model reading untrusted text can be flipped to any allowed value; each value must be safe for an attacker to choose, or the decision is gated like an action.
- **Detectors lower the odds; they are never the boundary.** Accept a defense only on evidence from adaptive attackers who know its specification, and re-test after every model, prompt or tool change.
- **Output is untrusted at every sink**: encode for the sink, parameterize queries, canonicalize paths; no renderer auto-fetches remote content; generated code never deploys without review.

## Authority & identity

- **Agents are principals** with identities of their own, a named owner and an audit trail, not borrowed user tokens.
- **Actor and subject.** Every action carries the agent (actor) and the person or tenant it acts for (subject) down the call chain; downstream services authorize on the pair plus a task-scoped grant.
- **Delegate, never impersonate.** Effective permission = the requesting principal's current permission ∩ the agent's grant ∩ the task's scope. Credentials are short-lived, audience-bound and minted by token exchange at each hop, narrowing at each one; never forward the user's token, never run as a privileged service role. Standards can record a delegation chain through sub-agents but not enforce it: keep the chain short, log it yourself, and keep the scheme behind an adapter.
- **Complete mediation outside the model.** A policy-enforcement point outside the agent runtime checks the tool, its arguments and the context's taint at execution time, enforces the autonomy level and holds the credentials. Never trust a user id or permission the model puts in a parameter. Fix authority before the run; treat messages between agents as untrusted input.
- **Tool servers**: least-privilege scopes with step-up per operation; a proxying server takes consent per client, never one shared upstream identity; possessing a handle is never authentication.
- **Proving your agent to others.** Outbound, an agent that browses third-party sites may need to sign its requests so the site can tell whose bot it is; that identifies the operator, not the user. Inbound, decide which agents your product admits and with what authority. Both are published-contract decisions.

**Authority record.** One row per tool or action in the feature doc §2: effect and reversibility (any outbound request is "sends outside", never read-only) · data scope as the predicate the enforcement point applies · caps per call and per period · approval · the component that enforces it ("the prompt" is never an entry) · the adversarial eval case that guards it. Every row emits an audit event, to a log the agent cannot write to or alter: agents have been seen tampering with their own monitoring.

## Containment

- **Sandboxes.** Model-generated or user-supplied code gets a syscall-filtering sandbox or a hardware-virtualized boundary: filesystem and network isolation; default-deny egress through an allowlisting proxy; no credentials inside (the proxy attaches short-lived ones); a fresh environment per run with resource and time limits. A sandbox that contains execution but not egress still leaks: the boundary is where data can go and which credentials are reachable. Never evaluate model output inside a production process.
- **Browser and computer-use agents**: a dedicated isolated session holding only the task's credentials, deny-by-default egress, and no secrets where attacker-controlled pages render. Every page is hostile.
- **Consequence tiers.** Read-only or cheaply reversible → automatic; medium impact → logged; irreversible, high-value or externally visible → approval; above limits → blocked. A chain is gated at its highest class. Redesign for reversibility: draft instead of send, soft delete, delayed send, snapshot before destruction.
- **Trajectory invariants.** Individually allowed steps can add up to harm: enforce cumulative value and volume limits per run and period, and information-flow labels (data read from a sensitive source never reaches an external sink). Guardrails that judge one message at a time miss gradual evasion: evaluate the conversation, and keep count across turns.

## Approvals and stops

- **An approval counts only if** it shows the exact, canonicalized parameters (never a model-written summary), is bound to them, expires, and reaches someone able to judge it. Below a cap, deterministic limits replace approval. People approve almost every prompt they are shown, so a near-total approval rate means the approval is not a control, and the containment has to hold without it. A delegated purchase is the same thing under another name: a mandate bound to amounts, merchants and expiry.
- **Kill switch**, out of band, per feature, tenant and agent: halts running instances, revokes their credentials, drains queued actions; exercised before launch. As a flag, its unreachable default halts consequential actions.
- **Credential revocation** reaches every issued token within a stated window.

## Data

- **Containment over redaction** for data the task needs: in-boundary hosting, no-retention endpoints, retrieval scoped to the requester. Redact only what the task does not need, and run evals with redaction on.
- **Provider data terms**, per provider × feature: training use, log retention, stateful features outside a zero-retention arrangement, processing region, sub-processors. Verified at design time, recorded with source and date, and enforced in the adapter or gateway, not only in the contract.
- **Partition shared AI state by tenant**: vector indexes, memory, response caches. Embeddings are as sensitive as their sources; text is recoverable from vectors.
- **Memory writes are privileged**: instruction-like content is quarantined until reviewed; tool output never auto-promotes into trusted memory or instruction files.
- **Audit record vs content trace.** The audit record (principal, agent, model snapshot, tool calls with redacted parameters, policy decisions, approvals) is kept as obligations require. Prompts, completions and retrieved chunks are a sensitive data class with their own retention and erasure.

## Extension supply chain

Instruction files, tool servers, plugins and AI packages are executable code plus prompt input inside your boundary, and public registries of them have carried malicious entries. Admit them like production dependencies: an allowlist of publishers, pinned by content hash, diffs reviewed on every update (descriptions and instruction bodies included), run sandboxed with no ambient credentials, no auto-install from public registries. Configuration that launches a local tool server is code execution. Who can change which tools or instructions the agent loads, and what runs with which credentials when they do?

**Agents in the build pipeline.** An agent that reads public input (issues, pull requests, web pages) holds no secrets and shares no cache with a release job. Release jobs run isolated, with actions pinned by commit and writes staged for review. A signed provenance record proves where an artifact was built, not that the build was clean.

## Governance design-ins

Ask which jurisdictions, sectors and contracts apply; verify obligations and dates at design time (`landscape.md` lists recent changes) and record source and date in an ADR. Duties differ by country and keep moving, so build disclosure and labeling as configuration per jurisdiction. Where the classification calls for them, design these in now; they are expensive to retrofit:

- **Intended-purpose classification.** Does the feature make or materially influence a consequential decision about a person (employment, credit, education, essential services, healthcare, justice), act as a safety component, or use biometrics? Re-classify on every repurposing.
- **Disclosure** that the user is dealing with AI, at first contact.
- **Marking of generated media**: machine-readable provenance added at generation.
- **Decision-time logs**, human override and a stop to a safe state, an incident path with the regime's deadline, and an explanation and contest path for decisions about people.

## Review scoping

The OWASP lists for LLM applications and for agentic applications, and MITRE's catalog of attacks on AI systems, scope a review; they never replace this system's threat model. Give each listed risk a structural owner in the design. Per-diff checks → `review-checklists`; runtime proof → `adversarial-execution`; each if available.

## Red flags

- **Three legs in one autonomous context**; rendered links, URL fetches and search queries count as egress.
- **Detection as the defense**, or a detector's accuracy cited as proof.
- **Authority in the model**: a rule enforced only by prompt text; secrets or authorization logic in context; an agent that runs as a privileged role, forwards the user's token or trusts ids the model supplies.
- **Mislabeled tools**: fetch, search or render auto-approved as "read-only"; a raw query, shell or fetch-any-URL tool in a context that reads untrusted text.
- **Approvals that do not protect**: a model-written summary, no expiry, a near-total approval rate, or autonomy widened because nothing has gone wrong yet.
- **Unvetted extensions**: unpinned, unreviewed or auto-installed, or running with the user's full privileges.
