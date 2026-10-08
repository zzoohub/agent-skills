# Security Misconfiguration

> OWASP: A02 Security Misconfiguration. Method, severity and the output contract live in SKILL.md. This file owns CORS and response security headers (do not duplicate them in `api.md`).

Most hardening gaps here are **not reported** unless the diff edits that surface and the gap has a concrete exploit path. Flag what the change introduces, not the absence of a header on an endpoint it never touched.

## CORS

Browsers already refuse `Access-Control-Allow-Origin: *` together with `Access-Control-Allow-Credentials: true`, so that pair is not itself exploitable: it signals intent, not a breach.

**Finding when (CWE-942):**
- The origin is **reflected** from the request with credentials allowed: `setHeader('ACAO', req.headers.origin)` with `credentials: true`, so any site reads authenticated responses.
- A regex or suffix origin check is bypassable: `/example\.com$/` (no leading dot) admits `evilexample.com`, an unescaped `.` matches any character, and `startsWith('https://good.com')` admits `https://good.com.evil.com`.
- `Access-Control-Allow-Origin: null` with credentials (reachable from a sandboxed iframe).
- `*` on an **intranet or IP-allowlisted** API that a browser on the internal network can reach.

**Not a finding:** a static, exact-match allowlist of trusted origins. CORS does not prevent CSRF (`auth.md`).

## Response Security Headers

A missing header with no demonstrated exploit path is at most one `Hardening:` line, and only for a surface the diff touches.

**Finding when:** a page with an XSS sink ships no CSP, or a CSP whose `unsafe-inline`, `unsafe-eval` or `*` sources defeat it (report it inside the XSS finding, `api.md`); a sensitive action page has no `X-Frame-Options` or `frame-ancestors` (clickjacking, CWE-1021); `X-Content-Type-Options: nosniff` is missing where a user-supplied type is served (sniffing becomes stored XSS).

**Not a finding:** missing HSTS, `Referrer-Policy` or `Permissions-Policy`, or an `X-Powered-By`/`Server` header left in, unless a specific downgrade or leak is shown.

## Secrets, Defaults & Debug

**Finding when:** a default or placeholder credential is deployed (`admin/admin`, `password`, a default JWT secret like `"secret"`, an unauthenticated MongoDB, Redis or Elasticsearch; CWE-1393); debug mode is on in production (`DEBUG=True`, a framework's default error handler, source maps served, GraphQL Playground or Swagger open) and leaks internals (CWE-489); a static handler or web root pointed at the project root or any directory holding `.env`, `.git/` or backups, or with directory listing on (CWE-538, CWE-548). Committed secrets: `supply-chain.md`.

**Not a finding:** a documented non-production default.

## Public Cloud Storage

**Finding when:** a bucket or object holding non-public data made world-readable or writable (CWE-732); cloud credentials in app code instead of a workload role (CWE-798).

**Not a finding:** an intentionally public bucket (a static site or CDN origin); a guessable bucket name (the access policy is what counts); a long-lived pre-signed URL, unless it is logged, emailed or cached where others can reach it.

## Cache Poisoning & Deception

**Finding when:**
- **Poisoning:** the response varies by an **unkeyed** input that the cache ignores but the app honors: an `X-Forwarded-Host` or `X-Forwarded-Scheme` reflected into links or redirects, or a fat-GET body parameter the app processes (CWE-349). A `Host` or `X-Forwarded-Host` reflected unvalidated into a redirect is CWE-601; into a reset link, `auth.md`.
- **Deception:** a static-looking path (`/account/settings/x.css`, `/api/./admin`) that the origin serves as the authenticated page while the CDN caches it and serves it to others; authenticated responses stored by a shared cache for lack of `Cache-Control: private` or `no-store` (CWE-524).

**Fix:** key the cache on every input that varies the response; validate `Host` and forwarded headers against an expected set; mark authenticated responses private.

## DNS & Exposed Services

**Finding when** the diff adds a DNS record pointing at a resource it doesn't own yet, or removes or renames a bucket, app or SaaS account that a remaining record still points to: anyone who claims that name serves content on your subdomain (subdomain takeover). Also when it adds infrastructure exposure: an open database port, an unauthenticated dashboard.
