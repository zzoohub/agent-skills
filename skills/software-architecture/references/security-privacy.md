# Security & Privacy

The method behind design-flow Stage 8 § Security. Read when Security or Privacy & compliance is light or deep. **Light**: a line per slot — threat summary, principals, secrets and keys in `templates/system.md` §5; class, retention and residency in its §3 Data Inventory. **Deep**: the full method below for the flows its trigger names, with drivers, guards and ADRs. Model-mediated flows add `ai/security.md`.

## Threat Modeling

**When.** A first pass at Stage 2 over the context diagram's boundary crossings (actors and external systems), so threat drivers reach the ATAM gate. A second pass at Stage 8 (`design-flow.md` § Security) over the container view, the Key Scenarios, operator and support paths, the build and release path (source → build → artifact → registry or store → runtime) and every model-mediated flow. Existing system: run it over the as-is, then over each interim topology a transition step creates — coexistence seams and sync channels are new crossings.

**Per flow — a lightweight STRIDE pass** (Shostack: data-flow diagrams with trust boundaries). Ask which of Spoofing / Tampering / Repudiation / Information disclosure / Denial of service / Elevation of privilege applies. Every crossing ends in exactly one of: a control with its guard, a security ASR, or an accepted risk in the Risk Register. Promote material findings to Stage 2 as security ASRs (filter #8; design-flow Stage 8); one promoted after Stage 4 gets its gate row and ADR updates before Stage 9 closes. **Material** = it defeats an H-importance scenario, crosses a tenant boundary, touches money or regulated data, or its harm cannot be undone.

**Privacy — LINDDUN-lite.** For flows carrying personal data, run the privacy analogue over the same diagram — linking, identifying, non-repudiation, detecting, data disclosure, unawareness, non-compliance — and promote material findings the same way; unawareness and non-compliance findings usually become data duties (below), not controls.

**Record** each crossing in the threat summary (`templates/system.md` §5). A guard is the test or monitor that fails when its control is removed: authorization tests per principal type, a cross-tenant denial test, a deprovisioning test, an egress or residency policy check, a fuzzer on a parser.

## Principals & Access

Ask before listing controls: which principals exist, where does each authenticate, how is it provisioned and removed, where is it authorized, and how is privileged access granted and audited? Federation, provisioning and support access are decisions, not defaults. Deep: this table in `templates/system.md` §5.

| Principal | Authentication source | Provisioning & deprovisioning | Authorization model & enforcement point | Credential lifetime & revocation | Privileged/emergency path & audit |
|---|---|---|---|---|---|
| one row per type: end user · tenant admin · operator/support · workload · device · agent | own / federated per tenant / workload identity | e.g. directory-driven; removal revokes sessions and grants | e.g. role-based within tenant, at each owning service | e.g. short-lived session, revoked on removal | e.g. just-in-time elevation, audited |

- **Authentication** sourcing follows `design-flow.md` § Subdomain Classification & Build-vs-Buy; the identity and authorization model is a one-way door (ADR).
- **Deprovisioning** revokes sessions, tokens and delegated grants, not only the account — directory-driven where tenants bring a directory.
- **Authorization** is enforced at the service that owns the resource, never only at the edge, gateway or UI; tenant and subject come from the authenticated context, never from a request body or model-written parameters. Choose role-, attribute- or relationship-based by how permissions are shared; tenant isolation → `system-architecture.md` § Multi-Tenancy.
- **Credentials** are short-lived, scoped and sender-constrained, not shared static secrets; each has an owner and a rotation and revocation path exercised before it is needed. Internal services authenticate to each other — zero trust within the network.
- **Devices**: per-unit identity at manufacture or enrollment, revocation of a stolen unit, and a stated behavior when a credential expires offline — never one that disables a safety function (design-flow Stage 4 safety rule). **Agents** are principals too (`ai/security.md`).
- **Privileged and emergency access** to customer data runs through a designed path — just-in-time, time-boxed, approved (with tenant consent where contracts require it), audited — never ad-hoc production queries. Break-glass uses separate credentials, alerts on use and is reviewed afterwards.

## Secrets & Keys

- **Secrets** never live in code, images, config repositories, prompts or logs; workloads fetch them at runtime by identity, scoped per service and environment. Rotation overlaps two valid versions, so it needs no downtime; a leak runbook revokes, rotates and reviews use.
- **Keys** you manage get, per key: who controls it (provider-managed / customer-managed / customer-held); its place in the hierarchy (root → key-encryption keys → data keys); the copies it covers (replicas, backups, caches, indexes, exports, telemetry); what rotation and revocation break, and for whom; its availability during recovery — keys, identity and secrets are recovery prerequisites, and a restore that cannot decrypt or authenticate is not a restore. Per-tenant or customer-controlled keys are a one-way door (ADR: key ownership & hierarchy).
- **Crypto-shredding** erases by deleting the key: encrypt per tenant or data subject, and every covered copy — backups and append-only logs included — becomes unreadable, provided no plaintext copy escaped the key (caches, search and vector indexes, analytics, exports).
- **Encryption** at rest by default; field-level when access must be narrower than the store's.

## Supply Chain & Release Integrity

Build and release are a trust boundary: the threat pass covers them as a flow; `design-flow.md` § Release Model records the rollout.

- **Dependency admission**: versions and digests pinned in lockfiles; vulnerability and licence policy enforced in CI; few dependencies; a bill of materials per release; no install-time scripts from unreviewed sources.
- **Provenance and signing**: SLSA-style build provenance; artifacts signed at build and verified at deploy, install or boot; reproducible builds where feasible.
- **Publishing credentials** are short-lived and job-scoped; scanners and other build tools are pinned and cannot read them — a tool that can read the publish token can publish.
- **Revocation path**: yank or deprecate a release, rotate signing keys, notify consumers.
- AI extensions — skills, tool-protocol servers, plugins — follow `ai/security.md`.

## Data Duties

The Stage-6 inventory (`design-flow.md` § Data Inventory & Lifecycle) lists each data set's writer, class and copies; every personal or regulated row must meet these duties.

- **Class** — public / internal / personal / sensitive or sector-regulated / secret (credentials, keys) — decides eligible processors and regions, retention, encryption, and what may enter logs, traces, analytics and model context.
- **Purpose and minimization** — each personal field has a stated purpose; collect and copy only what it needs; derived data keeps its source's purpose and deletion.
- **Erasure** reaches every listed copy within a stated window, by a mechanism per copy: delete in the system of record; tombstone and rebuild derived stores and indexes; expire or crypto-shred backups; obtain confirmed deletion from each processor. Append-only stores (event logs, the audit trail) hold pseudonymous ids or per-subject encrypted payloads, so erasure never rewrites them. Guard: an erasure test that seeds a subject and proves absence everywhere — or key deletion.
- **Export** — access, portability, tenant offboarding — in a defined machine-readable format, scoped to the authenticated requester and audited.
- **Retention** per class: as short as the purpose allows, as long as obligations require. Reconcile conflicting obligations (a retention mandate vs an erasure right) per class in an ADR (retention & erasure); legal hold suspends deletion for named records only.
- **Residency** — bound classes are written only to in-region stores; replicas, backups, processors, telemetry, support access and failover targets inherit the binding; each cross-border flow records who, why and its legal basis. Guard: a policy check that a bound class cannot be written out of region.
- **Consent**, where processing rests on it, is data with history — checked at use; withdrawal propagates like erasure.
- **Non-production** environments get masked or synthetic data; a production copy anywhere else is an inventory row with production controls.

## Compliance Evidence

Ask the caller which regimes and contracts apply (SKILL.md Stage 0); never infer obligations from geography alone. Unanswered → an `A-nn` assumption plus an Open Question blocking the one-way doors it gates. Verify current obligations at design time and record source and date in the ADR.

- Each regulatory ASR (filter #7) names its control, enforcement point and evidence source; the evidence source is its standing guard. When deep, record `Requirement → control → enforcement point → evidence → guard` in `templates/system.md` §5.
- Evidence comes from the pipeline and the runtime, not from assembly before an audit: policy-as-code checks over code and infrastructure in CI, access reviews generated from the directory, recorded restore and erasure drills, change approvals captured by the delivery pipeline. An evidence monitor alerts when evidence stops arriving; a control with no evidence source is a risk, not a control.

## Audit Trail

An append-only audit trail for sensitive operations is its own data set, not a log stream.

- **Content**: actor, on-behalf-of subject, action, resource, tenant, purpose, outcome, time — pseudonymous ids rather than personal data, so erasure never rewrites it. Log reads of sensitive data too when a regime requires access logging.
- **Write path**: with the change, so no committed effect lacks its record — never through the diagnostic log pipeline (`observability.md`; outbox → `reliability-patterns.md`).
- **Integrity and access**: tamper-evident (hash-chained or write-once storage); the people it audits cannot edit or delete it; its own retention and access rules; tenant export or streaming where contracts require it.

## Defense in Depth

Never rely on a single control: edge (request-size and rate limits, abuse controls) → transport (current TLS on every hop, no plaintext internal hops) → authentication → authorization at the owning service → data (encryption at rest; field-level for the most sensitive) → audit. Saltzer–Schroeder is the generative lens this layering only echoes: **fail-safe defaults** (deny unless granted; a failed or timed-out check denies), **least privilege** (per component, credential and principal), **complete mediation** (every access checked at the resource, every time; a cached decision expires with its grant).

## Untrusted Input

- **Parsers** of external input — files, archives, images, documents, config, network messages — are attack surface: bound size, depth, decompression ratio and time; never execute code or resolve external references on load (arbitrary-type deserialization, external entities, remote includes); canonicalize paths; isolate risky parsers in a sandboxed process. Guard: fuzzing.
- **Server-side fetches of caller-supplied URLs** (SSRF): allowlist destinations, block internal and link-local addresses after resolution, re-check every redirect.
- Upload mechanics: `operational-patterns.md`.

## Hand-offs

Per-diff checklist → the `review-checklists` security pass, if available — don't inline it here. Runtime proof of a named risk (cross-tenant access, token replay, SSRF) → the `adversarial-execution` capability, if available. Row-level policies and constraints → a database-design capability, if available.

## Red Flags

Perspective-level flags with default severities live in `review-lens.md`; these are the method's own:

- A control list with no threat pass, or a boundary crossing that ends in neither a control, an ASR nor an accepted risk.
- A tenant or user id read from the request body or a model-written parameter.
- Shared static credentials across services, environments or devices; deprovisioning that leaves sessions or grants alive.
- Support access to customer data through ad-hoc production queries; break-glass with no alert or audit.
- Audit records carrying personal data, or an audit trail its subjects can edit.
- Long-lived publishing tokens in CI, unsigned artifacts, or build tools that can read publishing credentials.
