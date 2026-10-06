# Authentication & Authorization Security

> OWASP: A01 (Broken Access Control), A07 (Authentication Failures)

## Table of Contents

1. [Password Security](#password-security)
2. [Multi-Factor Authentication (MFA)](#multi-factor-authentication-mfa)
3. [Passkeys / WebAuthn](#passkeys--webauthn)
4. [Session Management](#session-management)
5. [Cookie Security](#cookie-security)
6. [Cross-Site Request Forgery (CSRF)](#cross-site-request-forgery-csrf)
7. [JWT Security](#jwt-security)
8. [OAuth / SSO](#oauth--sso)
9. [SAML 2.0 SSO](#saml-20-sso)
10. [Authorization (Access Control)](#authorization-access-control)
11. [Rate Limiting & Brute Force](#rate-limiting--brute-force)

---

## Password Security

| Check | Why | CWE |
|-------|-----|-----|
| Strong adaptive hashing (bcrypt/argon2id) with proper cost factor | Rainbow tables, GPU cracking | CWE-916 |
| No password in logs, errors, responses, or URLs | Credential leakage | CWE-532 |
| Secure reset flow (expiring, single-use, random token) | Account takeover via reset | CWE-640 |
| Password change requires current password verification | Session hijack escalation | CWE-620 |
| Minimum password length enforced (>=8, ideally >=12) | Brute force feasibility | CWE-521 |
| Breached password check (Have I Been Pwned API or similar) | Credential stuffing with known passwords | CWE-521 |

**Patterns to catch:**
- Weak hash algorithms (MD5, SHA1, SHA256 without key stretching for passwords)
- Password field included in API responses or serialized user objects
- Reset tokens that don't expire or are reusable
- Reset token is user ID or email encoded in base64 (predictable)
- Password stored in plaintext or reversible encryption
- No minimum password complexity or length requirement
- Same error message not used for "user not found" vs "wrong password" (see Rate Limiting section)

---

## Multi-Factor Authentication (MFA)

| Check | Why | CWE |
|-------|-----|-----|
| TOTP implementation uses proper time window (30s, ±1 step) | Replay and timing attacks | CWE-294 |
| Recovery codes are single-use and securely stored | Recovery code reuse | CWE-294 |
| MFA cannot be silently disabled without re-authentication | MFA bypass via settings | CWE-306 |
| MFA challenge cannot be skipped by modifying client flow | Step-skipping attack | CWE-304 |
| Backup authentication method doesn't weaken MFA | Weakest link bypass | CWE-1390 |
| SMS-based MFA = **restricted authenticator** (NIST SP 800-63B-4, finalized mid-2025) | SIM swap; phishing | CWE-1390 |
| Passkeys (FIDO2/WebAuthn) preferred over TOTP where supported | Phishing-resistant by design | CWE-1390 |

> **NIST SP 800-63B-4 status (finalized mid-2025):** SMS/PSTN OTP is now formally a "restricted authenticator" — use requires offering alternatives, informing users of risks, and maintaining a migration plan. Passkeys (syncable) are explicitly approved at AAL2; device-bound passkeys at AAL3.

**Patterns to catch:**
- TOTP secret transmitted to client after setup (should only display once during enrollment)
- MFA verification endpoint without rate limiting
- MFA status stored only in JWT/client without server-side verification
- Recovery flow that bypasses MFA entirely (e.g., email-only reset disables MFA)
- No re-authentication required before changing MFA settings

---

## Passkeys / WebAuthn

Default to passkeys for new auth systems where supported (Chrome, Safari, Edge, Firefox all support since 2023). Two flavors:

| Flavor | AAL (NIST 800-63B-4) | Notes |
|---|---|---|
| **Syncable passkeys** (iCloud Keychain, Google Password Manager, 1Password) | AAL2 | Recovery via the platform's sync ecosystem. Survives device loss. |
| **Device-bound passkeys** (security keys, platform attestations) | AAL3 | Cannot be exfiltrated. Required for high-assurance. Plan recovery carefully. |

| Check | Why | CWE |
|-------|-----|-----|
| Use COSE algorithm allowlist (ES256, EdDSA); reject weak algs | Algorithm confusion | CWE-327 |
| Verify origin and RP ID on attestation/assertion | Phishing | CWE-290 |
| User verification (UV) required for sensitive operations | Stolen-device replay | CWE-294 |
| Recovery flow does NOT downgrade to SMS / email-only | Recovery downgrade defeats phishing resistance | CWE-1390 |
| For syncable passkeys: surface "this credential is synced across your devices" to users | Informed consent | — |
| Attestation verified for AAL3 / device-bound deployments | Counterfeit authenticator | CWE-290 |

**Patterns to catch:**
- Accepting `none` attestation when policy requires AAL3
- RP ID matching relaxed across subdomains
- Password fallback enabled by default alongside passkeys (defeats phishing resistance)
- No mechanism to enumerate / revoke passkeys per user

---

## Session Management

| Check | Why | CWE |
|-------|-----|-----|
| Server-side invalidation on logout | Token theft persistence | CWE-613 |
| Session ID regeneration after auth state change | Session fixation | CWE-384 |
| Concurrent session limits or notification | Account sharing, stolen sessions | CWE-613 |
| Idle timeout (15-30 min) + absolute timeout (8-24 hours) | Abandoned session hijack | CWE-613 |
| Separate long-lived token for remember-me | Reduced exposure window | CWE-613 |
| Session bound to user-agent (and IP only for high-security contexts) | Session theft detection | CWE-384 |

> **IP binding caveat:** Pinning sessions to IP breaks mobile users on cellular networks and any user behind CGNAT. Recommend only for high-security contexts (banking, admin panels, gov) where false-positive logouts are acceptable. Consumer apps should rely on UA + behavioral signals instead — but note UA is itself client-controlled and is usually captured alongside the stolen cookie, so UA binding is low-cost anomaly detection an attacker can replay, not a real control; it complements (never replaces) server-side invalidation and refresh-token rotation.

**Patterns to catch:**
- Logout only clears client state, server still accepts token
- Same session ID before and after login
- No mechanism to invalidate all sessions ("log out everywhere")
- Session tokens in URL parameters (exposed in referrer headers, logs)
- Missing `Set-Cookie` security attributes (see Cookie Security below)

---

## Cookie Security

| Check | Why | CWE |
|-------|-----|-----|
| `HttpOnly` flag on session cookies | XSS cannot steal session | CWE-1004 |
| `Secure` flag on all sensitive cookies | Prevents transmission over HTTP | CWE-614 |
| `SameSite=Lax` or `Strict` on session cookies | CSRF mitigation | CWE-1275 |
| Cookie `Path` restricted to application scope | Reduces exposure surface | CWE-1004 |
| `__Host-` prefix for sensitive cookies | Prevents subdomain attacks — requires `Secure`, NO `Domain` attribute, and `Path=/`; browser silently rejects the cookie otherwise | CWE-1004 |
| No sensitive data stored in cookies beyond session ID | Cookie theft exposure | CWE-315 |

**Patterns to catch:**
- Session cookie without `HttpOnly` (XSS can read it via `document.cookie`)
- Cookie set without `Secure` flag (sent over plain HTTP)
- `SameSite=None` without `Secure` (browser rejects, or enables cross-site)
- Token/user data stored in cookie instead of just session reference
- Cookie expiration set excessively long (months/years)
- `__Host-` cookie set with a `Domain` attribute or a non-root `Path` (silently dropped by the browser)

---

## Cross-Site Request Forgery (CSRF)

> OWASP: A01 (Broken Access Control)

| Check | Why | CWE |
|-------|-----|-----|
| Synchronizer (anti-CSRF) token on all state-changing requests — per-session/per-request, generated and validated server-side, never reflected to the attacker | Forged cross-site state change | CWE-352 |
| Double-submit cookie only when stateless — token signed/HMAC-bound to the session (raw double-submit is weak to subdomain/cookie injection) | Double-submit bypass | CWE-352 |
| Origin/Referer validated on state-changing requests (complementary to tokens) | Cross-origin forgery | CWE-352 |
| `SameSite=Lax`/`Strict` treated as defense-in-depth, NOT a substitute for tokens | Over-reliance on SameSite | CWE-352 |
| Bearer/`Authorization`-header APIs not also accepting the credential from a cookie | Cookie-auth reintroduces CSRF | CWE-352 |

**SameSite is not sufficient alone:** `Lax` still permits top-level GET-initiated state changes; Chrome's "Lax+POST" ~2-minute window sends cookies that carry *no* `SameSite` attribute (Lax-by-default) on cross-site top-level POSTs for two minutes after they are set — it does not apply to cookies set with an explicit `SameSite=Lax`, so never build a CSRF finding on it against an explicit-Lax cookie; SameSite does not isolate same-site subdomains and JS-initiated same-site requests bypass it. Require an anti-CSRF token on every sensitive POST/PUT/PATCH/DELETE.

**Patterns to catch:**
- State-changing endpoint (POST/PUT/PATCH/DELETE) with no anti-CSRF token, relying only on the session cookie
- `SameSite=Lax` treated as full CSRF protection for cookie-authenticated POSTs
- Anti-CSRF token reflected back to the client/attacker, or not bound to the session
- Raw double-submit cookie (token not signed/HMAC-bound) — forgeable via subdomain cookie injection
- API that authenticates via both `Authorization` header AND cookie (cookie path is CSRF-able)
- XSS present alongside CSRF defenses (XSS defeats both token and header checks — fix XSS too)

---

## JWT Security

| Check | Why | CWE |
|-------|-----|-----|
| Algorithm explicitly verified (whitelist, not blacklist) | Algorithm confusion attack ("none", HS256/RS256 swap) | CWE-327 |
| Algorithm fits the topology — asymmetric (ES256/EdDSA via JWKS) when verifiers are not the issuer; HS256 only when one service both issues and verifies | Shared-secret sprawl: every HS256 verifier can also mint valid tokens | CWE-321 |
| Short-lived access tokens (5-15 minutes) | Token theft window | CWE-613 |
| Refresh token rotation (new refresh token on each use) | Refresh token theft detection | CWE-613 |
| Stateless JWTs have a revocation strategy — jti deny-list, server-side token-version/sessions table checked per request, or short access TTL + revocable refresh token; logout, password change, and role change must invalidate already-issued access tokens | Stolen/stale token usable until `exp` | CWE-613 |
| Sensitive claims verified server-side on every request | JWT tampering | CWE-345 |
| Token in httpOnly cookie (NOT localStorage); pair with `SameSite=Lax`/`Strict` + CSRF defense, OR keep it out of cookies and send via the `Authorization` header | XSS token theft vs CSRF re-exposure (cookies auto-send cross-site) — see Cookie Security & CSRF | CWE-922, CWE-352 |
| `iss`, `aud`, `exp` claims validated | Token misuse across services | CWE-345 |
| JWK/JWKS endpoint properly secured | Key confusion attacks | CWE-327 |

**Patterns to catch:**
- JWT verification without algorithm whitelist (`algorithms: ["RS256"]`)
- Long-lived access tokens (hours/days instead of minutes)
- Same refresh token valid after use (no rotation)
- Role/permissions stored only in JWT, not verified against DB
- Token stored in `localStorage` or `sessionStorage` (XSS accessible)
- JWT secret is a simple string (not cryptographically random, >=256 bits)
- Token in URL parameters or query strings
- Missing `exp` claim or very distant expiration
- Logout / password reset / role change does not invalidate already-issued access tokens (stateless JWT stays valid until `exp`)

---

## OAuth / SSO

| Check | Why | CWE |
|-------|-----|-----|
| State parameter validated (tied to user session) | CSRF on OAuth flow | CWE-352 |
| PKCE for all public clients (and recommended for confidential) | Auth code interception | CWE-345 |
| Redirect URI strictly validated against allowlist | Open redirect to steal tokens | CWE-601 |
| Token exchange happens server-side | Token exposure to client | CWE-522 |
| ID token `nonce` validated | Replay attacks | CWE-345 |
| Scopes are minimal (principle of least privilege) | Over-privileged tokens | CWE-269 |

**Patterns to catch:**
- Missing state parameter check on callback
- Redirect URI from user input without strict allowlist matching
- Redirect URI validation using string prefix (allows `evil.com?redirect=good.com`)
- Access token handled in frontend JavaScript (implicit flow)
- Missing PKCE on mobile/SPA clients
- OAuth tokens stored without encryption at rest
- Generic post-login/logout redirect (`returnUrl`/`next`/`redirect`/`continue`) not validated against a relative-path-only rule or host allowlist (open redirect → phishing, chainable into token theft)

---

## SAML 2.0 SSO

> OWASP: A07 (Authentication Failures), A01 (Broken Access Control)

| Check | Why | CWE |
|-------|-----|-----|
| Consumed assertion is the SAME element the signature covers (verify signature reference binding) | XML Signature Wrapping (XSW) | CWE-347 |
| Reject responses with missing/unsigned assertions (no signature-exclusion bypass) | Unsigned assertion accepted | CWE-347 |
| Canonicalization / XML-comment-truncation handled in the parser | 2018 comment-truncation auth bypass (CVE-2017-11427 class) | CWE-347 |
| `Audience` (SP entityID), `Recipient`, `Destination`, `InResponseTo` validated | Assertion replay / misdirection | CWE-290 |
| Assertion validity window enforced (`NotBefore` / `NotOnOrAfter`) | Replay of expired assertion | CWE-294 |
| External entity resolution disabled in the SAML response parser | XXE via SAML response | CWE-611 |
| Vetted SAML library used, not hand-rolled XML/DSig | Implementation flaws | CWE-290 |

**Patterns to catch:**
- Signature verified but the assertion is located by tag-name/XPath rather than bound to the signed element (XSW)
- Assertion accepted without checking it is actually signed/enveloped (signature exclusion)
- No `Audience`/`Recipient`/`InResponseTo` validation (assertion reuse across SPs)
- `NotOnOrAfter` not enforced (expired-assertion replay)
- External entities enabled in the SAML XML parser (XXE — see api.md "Injection Prevention")
- Hand-rolled XML signature verification instead of a maintained SAML library

---

## Authorization (Access Control)

| Check | Why | CWE |
|-------|-----|-----|
| Ownership verified before every data access | IDOR | CWE-639 |
| Role check on every protected endpoint (server-side) | Broken access control | CWE-285 |
| Default deny — explicit allow per endpoint | Forgotten endpoints exposed | CWE-276 |
| Indirect references where possible (UUIDs, not sequential IDs) | ID enumeration | CWE-639 |
| Horizontal privilege checked (user A can't access user B's data) | Horizontal escalation | CWE-639 |
| Vertical privilege checked (regular user can't access admin) | Vertical escalation | CWE-269 |
| Resource-level permissions, not just endpoint-level | Granular access bypass | CWE-285 |

**Patterns to catch:**
- Data fetched by ID without ownership check: `db.find(req.params.id)`
- Role check only on frontend (hidden UI elements, not enforced server-side)
- New endpoints inherit no protection by default
- Sequential integer IDs exposed in URLs (`/api/users/123`)
- Admin endpoints rely only on separate URL path, no role verification
- Missing permission check on sub-resources (user owns order, but can they see its invoice?)
- `isAdmin` or `role` field settable via API request body

---

## Rate Limiting & Brute Force

| Check | Why | CWE |
|-------|-----|-----|
| Strict limit on login endpoint (5-10 attempts / 15 min) | Credential stuffing | CWE-307 |
| Very strict limit on password reset (3-5 / hour) | Account enumeration | CWE-307 |
| Lockout or CAPTCHA after threshold | Automated attacks | CWE-307 |
| Timing-safe comparison for all credential checks | Timing-based enumeration | CWE-208 |
| Consistent error messages (same for "not found" and "wrong password") | User enumeration | CWE-203 |
| Rate limit by multiple dimensions (IP + account + fingerprint) | Distributed brute force | CWE-307 |

**Patterns to catch:**
- No rate limit on login/register/reset endpoints
- Different error messages: "user not found" vs "wrong password"
- Early return on user lookup failure (timing difference reveals existence)
- Rate limit only by IP (bypassed with IP rotation)
- Registration endpoint allows unlimited account creation
- OTP/MFA code verification without attempt limit
- Password reset email sent regardless of account existence (timing difference)
