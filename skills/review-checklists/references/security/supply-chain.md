# Supply Chain & CI/CD

> OWASP: A03 Software Supply Chain Failures, A08 Integrity Failures. Method, severity and the output contract live in SKILL.md.

**Review what the diff changes about the protections, not the whole inventory.** A known CVE in a dependency the diff didn't add or make reachable is for a scanner (SCA), not this review. Flag what the change *weakens or introduces*.

## Dependencies

**Finding when the diff adds:**
- A `git`, URL or tarball dependency source (CWE-829), or `*` or `latest` as a version.
- A package whose name is a near-miss of a popular one, or that was published recently with no history: a typosquat, or a name a model suggested that someone has since registered.
- A package newly allowed to run install or build scripts, or build-script gating or a release-age cooldown disabled or shortened (check the package manager's current setting names in its docs).
- An install that bypasses the frozen lockfile (`npm install` where CI should run `npm ci`; `--no-frozen-lockfile`), or a lockfile hand-edited to diverge from the manifest or missing where one belongs (CWE-494).
- An unscoped internal package name that a public package could shadow (dependency confusion, CWE-427): private packages use scoped names with registry priority.

**Not a finding:** a version *range* (`^4.0.0`) with a committed lockfile and frozen CI installs. Libraries need ranges: flag the missing lockfile or the bypass, not the caret.

## CI/CD Pipelines

**Finding when:**
- Untrusted text interpolated into a `run:` step: `github.event.*` (PR title or body, branch name, comment) in shell is injection (CWE-94). Pass it through an `env:` var instead.
- `pull_request_target` or `workflow_run` executes PR-controlled code, or restores PR-populated artifacts or caches, in a job that holds secrets. (`pull_request_target` takes the workflow file and checkout from the default branch; the risk is checking out and running the PR head, or trusting its build output.)
- A third-party action, scanners included, pinned to a **mutable tag** in a job that can read secrets: tags have been force-pushed to backdoored commits. Pin to a full commit SHA.
- PR workflows of a public repository run on a persistent (non-ephemeral) self-hosted runner, which any fork PR can compromise.
- Publishing with a long-lived token (`NPM_TOKEN`) instead of OIDC trusted publishing; a cloud OIDC trust policy with a missing or wildcard `sub` (any repo can assume the role); `GITHUB_TOKEN` with write scope where read suffices; a secret echoed to logs; a build that runs `curl … | bash`.

**Not a finding:** branch protection, required reviews and signed commits. They are process controls: raise them once as a repo-wide note, not per diff.

## Containers, IaC & Kubernetes

**Finding when the diff adds:**
- A secret in an image layer (`ENV` or `ARG` secrets, `COPY . .` with no `.dockerignore`), in IaC variables or state, or in a K8s `Secret` committed as if base64 were encryption (CWE-798, CWE-312).
- An escalation path: `--privileged` or K8s `privileged`, `hostNetwork`, `hostPID`, `hostPath`, `allowPrivilegeEscalation: true` (CWE-250); wildcard IAM actions or RBAC, or `cluster-admin`, for the app's role or service account; a sensitive port open to `0.0.0.0/0` (public buckets: `misconfiguration.md`).

**Not a finding:** a mutable base-image tag, a container running as root, a missing `securityContext` or default-deny NetworkPolicy: `Hardening:`, unless the diff also adds one of the escalation paths above. A pre-existing gap in a manifest the diff didn't touch: one Scope line.

## Git & Secrets

**Finding when:** a secret is committed, in the working tree or history, unless it is a placeholder, a test-mode key or public by design (publishable or anon keys); treat a real-format key as live. Scrubbing history doesn't fix a committed secret: rotate or revoke it at the source (CWE-798). A `.gitignore` missing `.env`, `*.pem` or `credentials.json` is `Hardening:` until such a file is committed.

## SBOM & Provenance

**Finding when:** the diff removes provenance or attestation from a publish step, or stops verifying signatures at deploy. An SBOM or provenance that never existed is at most `Hardening:`; license compatibility is legal review.
