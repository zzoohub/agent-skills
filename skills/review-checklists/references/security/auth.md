# Authentication & Authorization

> OWASP: A01 Broken Access Control, A07 Authentication Failures. Method, severity and the output contract live in SKILL.md; this file is a decision aid: the exploitable shape, and what separates it from the decoy.

Password *storage* (hashing, pepper, bcrypt limits) lives in `crypto.md`. This file owns password *policy*, reset, sessions, cookies, CSRF, JWT, federation, redirects and access control.

## Authorization (Access Control)

The costliest, highest-recall section. Work it first on any handler that takes an object ID.

**Scoped load, then siblings.** The load must be scoped by the authenticated principal: owner or tenant from the session, never from the body, a header or the path. Then check every sibling the diff touches: list vs get, read vs write, single vs bulk, export or search, other transports to the same method (REST, GraphQL, RPC, WebSocket), nested routes (does `:id` belong to `:org`?). Authz checked on the path ID while the operation acts on a body ID is the same bug.

**Finding when:**
- An object loads by user-supplied ID with no principal scope: `db.find(req.params.id)` returned without an owner or tenant check (CWE-862 missing / CWE-863 wrong / CWE-639 user-controlled key).
- A sibling of a scoped handler is unscoped: the GET checks ownership but the bulk export, the GraphQL resolver or the PATCH does not.
- A role or tenant read from the request (`req.body.role`, `X-Tenant-Id`, a JWT claim the client can set) rather than the server's session.
- `isAdmin`, `role` or `orgId` settable through a mass-assignment sink (`api.md`).
- Default-allow routing: a new endpoint inherits no authz because protection is opt-in.

**Not a finding:**
- Sequential or guessable IDs on a scoped query. Enumeration raises severity; the bug is the missing scope check.
- Scope enforced in the data layer (session-bound RLS, a repository that requires the principal): cite it and move on.
- A frontend-only role gate the server also enforces.

## Password Policy & Reset

Anchor to NIST SP 800-63B-4 (verified 2026-10-08): single-factor minimum **15** characters; 8 allowed only when the password is always paired with a second factor; accept at least 64; **SHALL NOT** impose composition rules or periodic rotation; **SHALL** check a breach and commonality blocklist. Force a change only on evidence of compromise.

**Finding when:**
- Composition rules (required character classes) or scheduled forced rotation: these now *reduce* security and contradict the standard.
- A reset token that is predictable (a UUIDv1, a base64 user ID or email, anything not from a CSPRNG), never expires, or is reusable.
- A reset or magic-link URL built from `Host`/`X-Forwarded-Host`: the attacker sets the host and the victim's token lands on the attacker's domain (CWE-640).
- A password or email change without the current password or a fresh factor, or an email change with no notice to the old address: change the email, reset the password, and the account is taken over (CWE-620).
- A password echoed in logs, errors, responses or a URL (CWE-532).
- Plaintext or reversible password storage (hashing details: `crypto.md`).

**Not a finding:** a short single-factor minimum (8) with a blocklist in place: at most a `Hardening:` line.

## Multi-Factor Authentication (MFA)

**Finding when:** a full-privilege session issued after the first factor, with the second enforced only by a client redirect (protected routes must check MFA completion server-side, CWE-304); MFA can be disabled or its settings changed without re-authentication; a recovery or reset path silently drops MFA (an email-only reset disables it); MFA state is trusted from a client-held value (JWT claim, localStorage) with no server check; the TOTP secret is returned to the client after enrollment; the verify endpoint has no attempt cap; a TOTP or recovery code is accepted more than once (no record of the last used time step or of the consumed code, CWE-294).

**Not a finding:** SMS OTP offered as one option (NIST marks PSTN a **restricted** authenticator), unless it is the only or default second factor with no stronger option and no risk notice.

## Passkeys / WebAuthn

**Finding when:** an assertion is accepted without verifying origin and RP ID; no COSE algorithm allowlist (list at least ES256 and RS256; Windows platform authenticators need RS256); user verification not required for a sensitive action; recovery downgrades to SMS or email only (defeats phishing resistance).

**Not a finding:** a syncable passkey, unless the system claims AAL3, which needs a non-exportable key: NIST SP 800-63B-4 says syncable authenticators SHALL NOT be used there.

## Sessions & Cookies

**Finding when:**
- Logout or a password reset leaves the server-side session or token valid: a stolen session survives the reset.
- The session ID isn't regenerated at login or privilege change (fixation, CWE-384); a session token rides in a URL; a session cookie lacks `Secure`.
- A `__Host-` cookie set with a `Domain` attribute or a non-root `Path`: the browser silently drops it, so the protection you think you have is absent (`__Host-` requires `Secure`, no `Domain`, `Path=/`).

**Not a finding:**
- A missing `HttpOnly`, or a token in `localStorage`/`sessionStorage`, unless an XSS sink can read it (chain them) or it defeats a revocation requirement. HttpOnly cookies and header-bearer tokens are both valid designs.
- A session lifetime, unless it exceeds the reauthentication limit of the AAL the system claims (AAL1 ≤30 d; AAL2 ≤24 h, ≤1 h idle; AAL3 ≤12 h, ≤15 min idle).
- No UA or IP binding: a weak signal an attacker replays with the stolen cookie, never a substitute for server-side invalidation.

## CSRF

A finding only when **all three** hold (OWASP CSRF cheat sheet, verified 2026-10-08):
1. the credential is **ambient**: a cookie, HTTP auth or client cert sent automatically; and
2. a cross-site page can **trigger** the change: a mutating GET, a form-encodable POST (`application/x-www-form-urlencoded`, `multipart/form-data`, `text/plain`), or credentialed CORS; and
3. **nothing checks origin**: no anti-CSRF token, no `Sec-Fetch-Site`/`Origin` check (with an `Origin` fallback for browsers lacking Fetch Metadata), no required custom header, no non-form content type enforced.

A synchronizer token, Fetch Metadata with the Origin fallback, and a required custom header on an AJAX/JSON API are each **primary** defenses. `SameSite` is defense in depth, not a substitute.

**Finding when:** a state-changing cookie-authenticated endpoint has none of the origin checks; a synchronizer token checked only for presence or format, or against any issued token rather than the session's own; a raw double-submit cookie (token not signed or bound to the session), forgeable through subdomain cookie injection; an API that accepts the credential from *both* an `Authorization` header and a cookie (the cookie path is CSRF-able); `SameSite` as the only defense: Medium when explicitly `Lax` or `Strict`, High when left to the browser default or paired with a mutating GET or an attacker-controllable same-site origin.

**Not a finding:** a pure bearer-header API that never reads a cookie; Chrome's temporary "Lax+POST" window against an *explicit*-Lax cookie.

## JWT Security

Token lifetimes are arch-doc policy; flag verification, topology and revocation defects here.

**Finding when:**
- Verification with no algorithm allowlist: accepts `none`, or an HS256/RS256 swap where the public key is used as an HMAC secret (CWE-347).
- `decode` without `verify`; a signature checked over only part of the payload.
- `kid`, `jku` or `x5u` from the token reaches a file path, URL or fetch (key injection: forge any token).
- HS256 where verifiers are not the issuer: every holder of the shared secret can also mint tokens. Asymmetric (ES256/EdDSA via JWKS) when verifier ≠ issuer.
- No revocation path, *and* logout, password reset or role change must invalidate already-issued tokens but doesn't (a stateless token stays valid until `exp`).
- `iss`, `aud` or `exp` not validated; a low-entropy secret.

**Not a finding:** roles carried as JWT claims, unless staleness is harmful (a removed admin keeps access until `exp` with no revocation).

## OAuth / SSO

Federation is the highest-impact takeover surface: trace the **identity-binding** path.

**Finding when (OAuth / OIDC, RFC 9700):**
- `redirect_uri` validated by prefix or substring, not exact string match (`evil.com?x=good.com`, `good.com.evil.com`).
- No PKCE on a public client; `state` not generated or compared; `nonce` not validated on the ID token.
- The password grant (ROPC), which RFC 9700 says MUST NOT be used. The implicit grant is SHOULD NOT: rate it by whether token injection and leakage are mitigated.
- A public client's refresh token neither rotated with reuse detection nor sender-constrained (an RFC 9700 MUST).
- Any redirect target taken from input (`returnUrl`, `next`, `/go?url=`) not restricted to a relative path or host allowlist: open redirect (CWE-601), chainable into token theft. Protocol-relative (`//evil`), backslash and `user@host` forms bypass naive checks.
- Account identity keyed on **email** instead of `(issuer, subject)`; accounts auto-linked on an unverified or IdP-asserted email; an invite bound to the wrong email.

**Not a finding:** a vetted library at its defaults; flag only the check the diff removes or misconfigures.

## SAML 2.0 SSO

**Finding when:**
- Signature verified but the consumed assertion located by tag name or XPath rather than bound to the signed element (XML Signature Wrapping, CWE-347).
- The signature checked by one XML parser and the assertion read by another: a parser differential forges any user (ruby-saml CVE-2025-25291/25292). Flag two different parsers in one verify path.
- NameID or an attribute read from the first text node (`firstChild`, lxml or REXML `.text`) rather than the element's full text: a comment inside the value truncates it to another user's identity while the signature still verifies (CVE-2017-11427 class). Read identity through the SAML library's API.
- An assertion accepted without confirming it is actually signed; `Audience`, `Recipient`, `InResponseTo` or `NotOnOrAfter` not validated; external entities enabled in the SAML parser (XXE, `api.md`); hand-rolled DSig instead of a vetted library.

## Credential-guessing surfaces

**Finding when:** login, OTP, password-reset, invite or coupon endpoints have no attempt limit (NIST floor: at most 100 consecutive failures per authenticator per account); a per-request limiter on a guessing mutation that GraphQL aliases or batched operations multiply inside one request (count attempts per operation and per account, CWE-307); a non-constant-time credential comparison; a login or reset path that skips the hash for unknown users (timing reveals which accounts exist); distinguishable "user not found" and "wrong password" responses (enumeration, CWE-203).

**Not a finding:** a missing generic rate limit on an endpoint that isn't a guessing surface (`Hardening:`; amplification-based DoS: `api.md`).
