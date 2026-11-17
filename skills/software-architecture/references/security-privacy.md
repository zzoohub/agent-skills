# Security & Privacy

Read when Security or Privacy & compliance is light or deep. **Light**: one line per slot in `system.md` §5 (threats, principals, secrets) and class, retention and residency in its §3 Data Inventory. **Deep**: the method below for the flows its trigger names. Model-mediated flows add the ai-architecture capability's security rules, if available.

## Threat pass

Run it twice: early, over the context diagram's boundary crossings, so that threats become drivers; and at Stage 4, over the container view, the Key Scenarios, operator and support paths, the build and release path, and every model-mediated flow. On an existing system, also over each interim topology a transition step creates.

Per crossing, ask what an attacker gains by spoofing an identity, tampering with data, denying an action, reading what they should not, exhausting a resource or escalating privilege (STRIDE is the prompt list). Where personal data flows, also ask who can be linked or identified, and what the subject was never told. **Every crossing ends in exactly one of**: a control with its guard, a driver, or an accepted risk in the Risk Register. A finding is material when it defeats a driver, crosses a tenant boundary, touches money or regulated data, or cannot be undone.

Exploit attempts now tend to arrive before the patch does: keep exposed surface minimal by default, and make patching an automated rollout, not a project. A guard is the test or monitor that fails when its control is removed: an authorization test per principal type, a cross-tenant denial test, a deprovisioning test, a residency policy check, a fuzzer on a parser.

Three questions generate the rest: what happens when a check fails or times out (**deny**), what is the least each component, credential and principal needs (**least privilege**), and is every access checked at the resource, every time (**complete mediation**)?

## Principals & access

Before listing controls: which principals exist, where does each authenticate, how is it provisioned and removed, where is it authorized, and how is privileged access granted and audited? When deep, one row per principal type (end user, tenant admin, operator, workload, device, agent) with those columns.

- **Authorization at the service that owns the resource**, never only at the edge, gateway or UI. Tenant and subject come from the authenticated context, never from a request body or a model-written parameter.
- **Deprovisioning** revokes sessions, tokens and delegated grants, not only the account.
- **Credentials** are short-lived, scoped and bound to their holder; each has an owner and a rotation and revocation path exercised before it is needed. Internal services authenticate to each other.
- **Devices**: an identity per unit, revocation of a stolen unit, and a stated behavior when a credential expires offline, never one that disables a safety function.
- **Privileged access to customer data** runs through a designed path: just-in-time, time-boxed, approved, audited. Never ad-hoc production queries. Break-glass uses separate credentials and alerts on use.
- The identity and authorization model is a one-way door.

## Secrets & keys

- **Secrets** never live in code, images, config repositories, prompts or logs; workloads fetch them at runtime by identity. Rotation overlaps two valid versions.
- **Keys** you manage: who controls each, its place in the hierarchy, which copies it covers, what rotation and revocation break, and its availability during recovery. Per-tenant or customer-held keys are a one-way door.
- **Crypto-shredding** erases by deleting a per-tenant or per-subject key, provided no plaintext copy escaped it (caches, search and vector indexes, analytics, exports).
- **Long-lived confidentiality.** Data that must stay secret for years is exposed to recording now and decryption later: prefer post-quantum key exchange where the platform offers it, and keep algorithms swappable (a versioned envelope, never an algorithm baked into a stored format).

## Supply chain

Build and release are a trust boundary. Pin dependency versions and digests; hold new package versions in quarantine for a few days before they can be installed; enforce vulnerability and license policy in CI; keep a bill of materials per release; sign artifacts at build and verify at deploy, install or boot. Coding agents in the pipeline are principals inside this boundary: sandboxed, least-privileged, with credentials brokered at run time, and with no secrets at all when they read public input. Provenance proves where an artifact was built, not that the build was clean: isolate the release job from caches and triggers that untrusted contributions can reach. Publishing credentials are short-lived and job-scoped, and no build tool that can read them is unpinned. Keep a revocation path: yank a release, rotate signing keys, notify consumers. AI extensions (instruction files, tool servers, plugins) are admitted the same way, under the ai-architecture capability's rules if available.

## Data duties

Every personal or regulated row of the Data Inventory meets these.

- **Class** (public, internal, personal, sensitive or regulated, secret) decides eligible processors and regions, retention, encryption, and what may enter logs, traces, analytics and model context.
- **Purpose and minimization**: each personal field has a stated purpose; derived data keeps its source's purpose and deletion.
- **Erasure reaches every listed copy** within a stated window, by a mechanism per copy: delete in the system of record, tombstone and rebuild derived stores, expire or crypto-shred backups, confirmed deletion from each processor. Append-only stores hold pseudonymous ids or per-subject encrypted payloads so erasure never rewrites them. Guard: seed a subject and prove absence everywhere.
- **Retention** per class: as short as the purpose allows, as long as obligations require. A retention mandate that conflicts with an erasure right is reconciled in an ADR.
- **Residency**: bound classes are written only in region, and replicas, backups, processors, telemetry, support access and failover targets inherit the binding. Guard: a policy check that a bound class cannot be written out of region.
- **Consent**, where processing rests on it, is data with history, checked at use; withdrawal propagates like erasure.
- **Non-production** gets masked or synthetic data.

## Compliance evidence

Ask which regimes and contracts apply; never infer obligations from geography alone. Unanswered → an assumption plus an Open Question blocking the doors it gates. Verify current obligations at design time and record source and date. Each obligation names its control, enforcement point and evidence source, and the evidence comes from the pipeline and the runtime (policy checks in CI, access reviews generated from the directory, recorded restore and erasure drills), not from assembly before an audit. A control with no evidence source is a risk.

## Audit trail

An append-only record of sensitive operations is its own data set, not a log stream: actor, on-behalf-of subject, action, resource, tenant, outcome, time, with pseudonymous ids. It is written with the change, never through the diagnostic log pipeline, which samples and drops. It is tamper-evident, and the people it audits cannot edit it.

## Untrusted input

Parsers of external input (files, archives, images, documents, network messages) are attack surface: bound size, depth, decompression ratio and time; never execute code or resolve external references on load; isolate risky parsers. A server-side fetch of a caller-supplied URL allowlists destinations, blocks internal addresses after resolution and re-checks every redirect.

## Hand-offs

Per-diff checks → the `review-checklists` security pass. Runtime proof of a named risk → the `adversarial-execution` capability. Row-level policies → the database-design capability. Each if available.

## Red flags

- A control list with no threat pass, or a crossing that ends in neither a control, a driver nor an accepted risk.
- A tenant or user id read from the request body or a model-written parameter.
- Shared static credentials across services or environments; deprovisioning that leaves sessions alive.
- Support access through ad-hoc production queries; break-glass with no alert.
- Audit records carrying personal data, or editable by their subjects.
- Long-lived publishing tokens in CI, or unsigned artifacts.
