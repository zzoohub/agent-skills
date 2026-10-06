# API Security

> OWASP: A01 (Broken Access Control), A05 (Injection)

## Table of Contents

1. [Input Validation](#input-validation)
2. [Mass Assignment](#mass-assignment)
3. [Injection Prevention](#injection-prevention)
4. [Cross-Site Scripting (XSS)](#cross-site-scripting-xss)
5. [Path Traversal & Arbitrary File Access](#path-traversal--arbitrary-file-access)
6. [Data Exposure](#data-exposure)
7. [GraphQL Specific](#graphql-specific)
8. [File Upload](#file-upload)
9. [Webhook Security](#webhook-security)
10. [API Key & Token Management](#api-key--token-management)
11. [CORS & Security Headers](#cors--security-headers)
12. [HTTP Request Smuggling](#http-request-smuggling)
13. [WebSocket Security](#websocket-security)
14. [Deserialization](#deserialization)
15. [Rate Limiting & DoS Prevention](#rate-limiting--dos-prevention)

---

## Input Validation

| Check | Why | CWE |
|-------|-----|-----|
| Schema validation on all inputs (zod, joi, pydantic, etc.) | Unexpected data types, injection | CWE-20 |
| Explicit type coercion (no implicit string-to-number) | Type confusion attacks | CWE-843 |
| Size limits on strings, arrays, files, nested objects | DoS, buffer issues | CWE-770 |
| Reject unexpected fields (strict schema, no extra properties) | Mass assignment via extra fields | CWE-915 |
| Validate content-type matches actual body | Content-type mismatch attacks | CWE-436 |
| Canonicalize input before validation (Unicode, encoding) | Validation bypass via encoding | CWE-180 |
| Redirect/return URLs validated (relative-path-only or host allowlist) | Open redirect → phishing, SSO token theft | CWE-601 |

**Patterns to catch:**
- Request body used directly without validation: `db.create(req.body)`
- No max length on string fields (allows multi-MB strings)
- Dynamic field names from user input: `obj[req.body.field]`
- Array input without max items limit (100,000 item array)
- Nested object depth unbounded (deeply nested JSON for DoS)
- Regex validation without anchors: `/[a-z]+/` instead of `/^[a-z]+$/`
- Missing validation on query parameters and path parameters (not just body)
- Redirect target from `returnUrl`/`next`/`redirect`/`continue` used without allowlist; substring/prefix match (`evil.com?x=good.com`), protocol-relative (`//evil.com`), backslash (`\evil.com`), or `user@`-host bypasses accepted (CWE-601)

---

## Mass Assignment

| Check | Why | CWE |
|-------|-----|-----|
| Explicit allowlist of updatable fields per endpoint | Privilege escalation via hidden fields | CWE-915 |
| Separate DTOs for create vs update operations | Different allowed fields per operation | CWE-915 |
| Role-based field restrictions | Admin fields writable by regular users | CWE-915 |
| Nested object assignment reviewed | Deep property override | CWE-915 |

**Patterns to catch:**
- Full request body spread into model update: `User.update({...req.body})`
- Same input DTO for user and admin endpoints
- Fields like `role`, `isAdmin`, `balance`, `verified`, `emailVerified` not explicitly blocked
- Prototype pollution via `__proto__` or `constructor` in request body (Node.js)
- ORM `update` called with raw request body without field filtering

---

## Injection Prevention

| Check | Why | CWE |
|-------|-----|-----|
| Parameterized queries for all database operations | SQL Injection | CWE-89 |
| ORM used correctly (no raw query with string interpolation) | SQL Injection via ORM | CWE-89 |
| No user input in shell commands | Command Injection | CWE-78 |
| Template engine auto-escaping enabled | XSS | CWE-79 |
| LDAP queries use parameterized API | LDAP Injection | CWE-90 |
| XML parsing disables external entities (XXE) | XXE | CWE-611 |
| NoSQL queries use typed operators, not string concat | NoSQL Injection | CWE-943 |

**Patterns to catch:**
- String concatenation in SQL: `` `SELECT * FROM users WHERE id = ${id}` ``
- ORM raw query mode with interpolation: `sequelize.query("SELECT..."+input)`
- `child_process.exec(userInput)` instead of `execFile` with args array
- `dangerouslySetInnerHTML` with unsanitized input (React)
- MongoDB query with `$where`, `$regex` from user input
- XML parser without `disableEntityExpansion` or `noent: false`
- Path traversal in file operations: `fs.readFile(basePath + userInput)`

---

## Cross-Site Scripting (XSS)

> OWASP: A05 (Injection)

| Check | Why | CWE |
|-------|-----|-----|
| Output encoded for the specific context (HTML body, attribute, JS, URL, CSS) — a single escaper does not cover all contexts | Reflected/stored XSS | CWE-79 |
| Server-side template auto-escaping on — note it does NOT stop DOM-based XSS | Stored/reflected XSS | CWE-79 |
| DOM sinks avoided/sanitized: `innerHTML`/`outerHTML`, `document.write`, `insertAdjacentHTML`, `location`/`href` assignment, `eval`, `setTimeout`/`Function` with string args, jQuery `.html()` | DOM-based XSS | CWE-79 |
| User/LLM-supplied HTML sanitized with a vetted library (DOMPurify) before render | Stored/DOM XSS | CWE-79 |
| Trusted Types enforced where supported | DOM-XSS hardening | CWE-79 |
| CSP as a mitigation layer (no `unsafe-inline`/`unsafe-eval`) | Defense-in-depth | CWE-693 |

**Patterns to catch:**
- Reflected: unescaped request value echoed into the HTML response
- Stored: user content rendered to other users without sanitization
- DOM-based: `el.innerHTML = userInput`, `document.write(location.hash)`, `location = userInput`
- Framework escape hatches: React `dangerouslySetInnerHTML`, Vue `v-html`, Angular `[innerHTML]`, and `href={userUrl}` allowing `javascript:` URIs
- Relying on server-side template escaping to stop DOM-XSS (it cannot — the sink is client-side)
- `eval`/`new Function`/`setTimeout` called with attacker-influenced strings

---

## Path Traversal & Arbitrary File Access

> OWASP: A01 (Broken Access Control), A05 (Injection)

| Check | Why | CWE |
|-------|-----|-----|
| File download/serve paths canonicalized (`realpath`/`path.resolve`) then asserted to stay within the base dir | Path traversal / LFI | CWE-22 |
| Prefer mapping user input to an ID or allowlist over accepting a raw path | Arbitrary file read | CWE-22 |
| Absolute paths, `..`, and encoded/Unicode/double-encoded traversal rejected | Traversal bypass | CWE-23 |
| Archive extraction validates each entry's resolved destination is inside the target dir before writing | Zip Slip | CWE-22 |

**Patterns to catch:**
- Download/serve endpoint takes a user path/filename: `GET /files?path=../../etc/passwd`
- `fs.readFile(basePath + userInput)` / `open(base + name)` without canonicalize-and-contain
- Archive (zip/tar/jar) extracted with entry names like `../../` written outside the target (Zip Slip)
- Absolute path or null-byte/encoded traversal accepted by a "filename" parameter
- Template/include path built from user input (PHP/templating LFI, CWE-98)

---

## Data Exposure

| Check | Why | CWE |
|-------|-----|-----|
| Response contains only needed fields (explicit serialization) | Sensitive data leakage | CWE-200 |
| No internal IDs, metadata, or debug info leaked | Information disclosure | CWE-200 |
| Error messages sanitized for production | Stack traces reveal internals | CWE-209 |
| Pagination enforced on all list endpoints | DoS via large responses | CWE-770 |
| Sensitive data not cached (Cache-Control headers) | Cached sensitive responses | CWE-524 |
| Response headers don't leak server info (X-Powered-By, Server) | Fingerprinting | CWE-200 |

**Patterns to catch:**
- Full database object returned: `res.json(user)` instead of `res.json(pick(user, ['id','name']))`
- Stack traces in production error responses
- List endpoint returns all records without limit/offset
- API version header reveals internal framework version
- Sensitive fields (password hash, SSN, tokens) in response body
- Debug endpoints left enabled in production (`/debug`, `/phpinfo`, `/__debug__`)
- Internal service URLs or IP addresses in response data

---

## GraphQL Specific

| Check | Why | CWE |
|-------|-----|-----|
| Introspection disabled in production | Schema disclosure | CWE-200 |
| Query depth limiting (max 7-10 levels) | Nested query DoS | CWE-770 |
| Query complexity/cost analysis | Resource exhaustion | CWE-770 |
| Field-level authorization on resolvers | Data access bypass | CWE-285 |
| Batch query limiting | Batch attack amplification | CWE-770 |
| Alias-based attack prevention | Rate limit bypass via aliases | CWE-770 |

**Patterns to catch:**
- `__schema` query enabled in production
- Deeply nested queries without limit: `{user{posts{comments{author{posts{...}}}}}}`
- Same resolver for public and private fields without auth check
- No cost calculation before query execution
- Mutations exposed without proper authorization
- Subscriptions without authentication or rate limiting

---

## File Upload

| Check | Why | CWE |
|-------|-----|-----|
| Validate type by magic bytes/content, not just extension | Extension spoofing | CWE-434 |
| Size limits enforced server-side (not just client) | Storage DoS | CWE-770 |
| Filename sanitized (strip path separators, special chars) | Path traversal | CWE-22 |
| Stored outside webroot with random generated names | Direct execution | CWE-434 |
| Content-Type header set correctly on serve (not from upload) | MIME confusion | CWE-436 |
| Image files re-processed/re-encoded | Embedded malicious content | CWE-434 |
| Antivirus scan for applicable file types | Malware upload | CWE-434 |

**Patterns to catch:**
- Extension-only validation: `if (file.ext === '.jpg')` (rename .php to .jpg)
- User-provided filename used directly in file path
- Uploads stored in publicly accessible directory with original names
- No content-type verification (trust client Content-Type header)
- SVG uploads allowed without sanitization (SVG can contain JavaScript)
- ZIP file upload without bomb detection (zip bomb DoS)
- Double extension bypass: `file.php.jpg` if server processes first extension

---

## Webhook Security

| Check | Why | CWE |
|-------|-----|-----|
| Webhook signatures verified (HMAC) | Forged webhook payloads | CWE-345 |
| Replay protection (timestamp + nonce validation) | Replay attacks | CWE-294 |
| Webhook URLs validated against allowlist | SSRF via webhook | CWE-918 |
| Timeout on webhook delivery | Slow-loris DoS | CWE-400 |
| Webhook payload size limited | Memory exhaustion | CWE-770 |
| Idempotent webhook processing | Duplicate delivery handling | CWE-837 |

**Patterns to catch:**
- Webhook endpoint accepts any POST without signature verification
- No timestamp check (allows replay of old webhooks indefinitely)
- User-configurable webhook URL without SSRF protection
- Webhook processing modifies state without idempotency key
- Webhook secret shared across multiple consumers

---

## API Key & Token Management

| Check | Why | CWE |
|-------|-----|-----|
| API keys have scoped permissions (not full access) | Over-privileged keys | CWE-269 |
| Key rotation mechanism exists | Long-lived compromised keys | CWE-324 |
| Revocation is immediate and complete | Delayed revocation window | CWE-324 |
| Keys are high-entropy, cryptographically random | Predictable keys | CWE-330 |
| Keys transmitted only via headers, never URL params | Log exposure | CWE-598 |
| Different keys for different environments | Prod key in dev | CWE-798 |

**Patterns to catch:**
- Single "god key" with all permissions
- API keys in URL query parameters (logged in server logs, proxy logs)
- No key expiration or rotation policy
- Keys generated with `Math.random()` or sequential patterns
- Same API key used across dev/staging/production
- No audit log of key usage

---

## CORS & Security Headers

| Check | Why | CWE |
|-------|-----|-----|
| Specific origins, no wildcard with credentials | Cross-origin attacks | CWE-942 |
| Content-Security-Policy header present and restrictive | XSS mitigation | CWE-693 |
| Strict-Transport-Security (HSTS) with `max-age≥31536000` | Downgrade attacks | CWE-319 |
| X-Frame-Options or CSP frame-ancestors | Clickjacking | CWE-1021 |
| X-Content-Type-Options: nosniff | MIME sniffing attacks | CWE-693 |
| Referrer-Policy set appropriately | URL leakage via referrer | CWE-200 |
| Permissions-Policy restricting browser features | Feature abuse | CWE-693 |

**Patterns to catch:**
- `Access-Control-Allow-Origin: *` combined with `Access-Control-Allow-Credentials: true`
- Origin reflected from request without validation: `res.setHeader('ACAO', req.headers.origin)`
- Regex-based origin validation with bypasses: `/\.example\.com$/` matches `evil-example.com`
- `Access-Control-Allow-Origin: null` accepted (exploitable via sandboxed iframes)
- Missing Content-Security-Policy entirely
- CSP with `unsafe-inline` or `unsafe-eval` (defeats purpose)
- Missing X-Frame-Options on pages with sensitive actions
- HSTS max-age too short (should be >= 1 year / 31536000)

---

## HTTP Request Smuggling

| Check | Why | CWE |
|-------|-----|-----|
| Consistent parsing between frontend proxy and backend | Request boundary confusion | CWE-444 |
| `Transfer-Encoding` and `Content-Length` not both accepted | CL.TE / TE.CL smuggling | CWE-444 |
| HTTP/2 downgrade to HTTP/1.1 reviewed for smuggling vectors | H2.CL / H2.TE smuggling | CWE-444 |
| Proxy and backend agree on request boundaries | Request splitting | CWE-113 |
| Ambiguous requests rejected (not interpreted) | Parser differential exploitation | CWE-444 |

**Patterns to catch:**
- Reverse proxy (Nginx, HAProxy) and backend (Node, Go) using different HTTP parsers
- Backend accepting both `Transfer-Encoding: chunked` and `Content-Length` on same request
- `Transfer-Encoding` header with obfuscation: `Transfer-Encoding: xchunked`, `Transfer-Encoding : chunked` (space before colon)
- HTTP/2 to HTTP/1.1 translation at load balancer without smuggling protections
- Multiple `Content-Length` headers accepted by backend
- Request body interpreted differently by proxy vs backend (prefix attack)

---

## WebSocket Security

| Check | Why | CWE |
|-------|-----|-----|
| Origin header validated on WebSocket upgrade | Cross-site WebSocket hijacking | CWE-346 |
| Authentication on connection AND per-message if needed | Unauthenticated WS access | CWE-306 |
| Message size limits enforced | Memory exhaustion via large frames | CWE-770 |
| Message rate limiting per connection | WS flood DoS | CWE-770 |
| Input validation on all incoming WS messages | Injection via WebSocket | CWE-20 |
| Connection timeout for idle WebSockets | Resource exhaustion | CWE-400 |

**Patterns to catch:**
- WebSocket upgrade without checking `Origin` header (any site can connect)
- Auth token checked only at handshake, not validated during session (stolen WS reused indefinitely)
- No message schema validation — raw `JSON.parse(data)` without schema check
- Broadcasting user input to other clients without sanitization (XSS via WebSocket)
- No max connections per user/IP
- WebSocket endpoint allowing cross-site WebSocket hijacking (CSWSH)
- Missing `wss://` (TLS) in production

---

## Deserialization

| Check | Why | CWE |
|-------|-----|-----|
| Untrusted data never deserialized with unsafe methods | Remote Code Execution | CWE-502 |
| JSON preferred over binary serialization formats | Reduced attack surface | CWE-502 |
| If binary serialization required, use allowlist of permitted classes | Class instantiation control | CWE-502 |
| Deserialized data validated against schema before use | Data integrity | CWE-20 |
| Serialization libraries kept updated | Known CVEs in deserializers | CWE-502 |

**Patterns to catch:**
- Python: `yaml.load(data)` without `Loader=SafeLoader`, unsafe deserialization of user data
- Java: `ObjectInputStream.readObject()` on untrusted input, Commons Collections gadget chains
- PHP: `unserialize($user_input)` — use `json_decode` instead
- Ruby: `Marshal.load(user_data)`, `YAML.load(user_data)` without safe mode
- Node.js: `node-serialize` with eval-based deserialization on untrusted input
- .NET: `BinaryFormatter.Deserialize()`, `XmlSerializer` with type from user input
- Signed serialized data where signature not validated before deserialization

---

## Rate Limiting & DoS Prevention

| Check | Why | CWE |
|-------|-----|-----|
| Global rate limits per IP/user | Resource exhaustion | CWE-770 |
| Stricter limits on expensive operations (export, report, search) | Targeted DoS | CWE-770 |
| Request body size limits | Memory exhaustion | CWE-770 |
| Timeout on long-running operations | Thread/connection exhaustion | CWE-400 |
| Regex patterns reviewed for catastrophic backtracking | ReDoS | CWE-1333 |
| Batch endpoints limit items per request | Amplification attacks | CWE-770 |
| Rate-limit state returned in headers (`RateLimit-*`; legacy `X-RateLimit-*` still common) + `Retry-After` on 429 | Clients can't self-regulate; synchronized retry storms | CWE-770 |

**Patterns to catch:**
- No rate limiting middleware at all
- Expensive operations (CSV export, PDF generation, report) without limits
- Regex with nested quantifiers: `(a+)+`, `(a|b)*c` (ReDoS vulnerable)
- No request body size limit (default may be very large)
- Long-running database queries without timeout
- Search endpoint without query complexity limits
- Batch API accepts unlimited items: `POST /api/batch` with 100,000 items
