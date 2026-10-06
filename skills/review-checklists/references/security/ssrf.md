# Server-Side Request Forgery (SSRF)

> OWASP: A01 (Broken Access Control — SSRF consolidated here)
> 
> SSRF attacks surged ~452% from 2023 to 2024 (2025 SonicWall Cyber Threat Report). This checklist addresses one of the fastest-growing attack vectors.

---

## Table of Contents

1. [URL Input Handling](#url-input-handling)
2. [Internal Network Protection](#internal-network-protection)
3. [Cloud Metadata Exploitation](#cloud-metadata-exploitation)
4. [Webhook & Callback URLs](#webhook--callback-urls)
5. [Image/File Proxy & Processing](#imagefile-proxy--processing)
6. [DNS Rebinding Defense](#dns-rebinding-defense)


## URL Input Handling

| Check | Why | CWE |
|-------|-----|-----|
| User-provided URLs validated against strict allowlist | Arbitrary destination | CWE-918 |
| URL scheme restricted to `https` (and `http` only if required) | `file://`, `gopher://`, `dict://` abuse | CWE-918 |
| Resolved IP checked against internal ranges AFTER DNS resolution | DNS rebinding | CWE-918 |
| Redirects disabled or followed with same restrictions | Redirect to internal network | CWE-918 |
| Response from fetched URL not returned raw to user | Information disclosure chain | CWE-200 |
| DNS resolution performed by application, not delegated to library blindly | Pre-resolution validation bypass | CWE-918 |

**Patterns to catch:**
- User input directly in `fetch()`, `requests.get()`, `http.Get()`, `HttpClient`
- No URL scheme validation: `fetch(userUrl)` accepts `file:///etc/passwd`
- URL validation before DNS resolution only (DNS rebinding: first resolves to allowed IP, then to internal)
- Following redirects without re-validating each hop destination
- `curl` or HTTP library with redirect following enabled by default
- URL parsed and validated, but different parser used for actual request (parser differential)
- SSRF via PDF generation (HTML-to-PDF tools fetching URLs in `<img>`, `<link>`, `<iframe>`)

---

## Internal Network Protection

| Check | Why | CWE |
|-------|-----|-----|
| Block requests to private IP ranges (10.x, 172.16-31.x, 192.168.x, 127.x) | Internal service access | CWE-918 |
| Block cloud metadata endpoints (169.254.169.254, fd00:ec2::254, 100.100.100.200) | Credential theft | CWE-918 |
| Block localhost variants (127.0.0.1, [::1], 0.0.0.0, 0x7f000001) | Loopback access | CWE-918 |
| Block link-local addresses (169.254.x.x) | Link-local service access | CWE-918 |
| Check the parsed/resolved IP, not the raw host string (decimal/hex/octal IPv4 forms only bypass raw-string checks — see the parser note below) | Encoding-based bypass | CWE-918 |

**IP ranges to block:**
```
# Private networks (RFC 1918)
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16

# Loopback
127.0.0.0/8
::1/128

# Link-local
169.254.0.0/16
fe80::/10

# Cloud metadata
169.254.169.254/32     # AWS, GCP, Azure
fd00:ec2::254/128      # AWS IPv6 metadata
100.100.100.200/32     # Alibaba Cloud

# Other
0.0.0.0/8              # "This" network
fc00::/7               # IPv6 unique local
::ffff:0:0/96          # IPv4-mapped IPv6 — check the embedded IPv4 against the ranges above
```

**Bypass techniques to defend against:**
- Decimal IP: `http://2130706433` = `http://127.0.0.1`
- Hex IP: `http://0x7f000001` = `http://127.0.0.1`
- Octal IP: `http://0177.0.0.01` = `http://127.0.0.1`
- IPv6 compressed: `http://[::1]` = `http://127.0.0.1`
- IPv6-mapped IPv4: `http://[::ffff:127.0.0.1]`
- Domain pointing to internal IP: attacker controls `evil.com` → `127.0.0.1`
- URL with credentials: `http://user:pass@internal-host/`
- URL with port: `http://127.0.0.1:8080` (non-standard port bypass)
- Enclosed brackets: `http://[127.0.0.1]` (some parsers accept)
- Short URL / redirect: `http://bit.ly/abc` → `http://127.0.0.1`
- Unicode confusables in hostname

> **Parser note — the numeric IPv4 forms are stack-dependent.** Decimal, hex, octal and shortened forms (`2130706433`, `0x7f000001`, `0177.0.0.01`, `127.1`) are a real bypass only when the guard compares the raw host string while the request is resolved through an `inet_aton`-style path (e.g. Python `urllib.parse` + `requests`/`socket`, curl, other non-WHATWG clients). WHATWG URL parsers (Node's `URL`, browsers, Deno, Bun) normalize all of them to dotted-quad before any check — `new URL('http://0x7f000001').hostname === '127.0.0.1'` — so on those stacks a hostname check run on the parsed URL is *not* bypassed by them; don't report it. IPv6 forms (`[::1]`, `[::ffff:127.0.0.1]`, which Node normalizes to `[::ffff:7f00:1]`), other 127/8 addresses, `0.0.0.0`, and DNS names resolving internal still bypass a string blocklist on every stack. The robust guard is the same everywhere: resolve, check the resolved IP against the ranges above, then connect to that pinned IP (see DNS Rebinding Defense).

---

## Cloud Metadata Exploitation

| Check | Why | CWE |
|-------|-----|-----|
| IMDSv2 required on AWS (token-based, not open GET) | SSRF → full credential theft | CWE-918 |
| Metadata endpoint blocked at network/firewall level | Defense in depth | CWE-918 |
| Application doesn't need metadata access (restrict if possible) | Principle of least privilege | CWE-918 |
| GCP requires `Metadata-Flavor: Google` header | Header-based protection | CWE-918 |
| Azure requires `Metadata: true` header | Header-based protection | CWE-918 |

**Attack chain example (AWS IMDSv1):**
1. SSRF found: `GET /api/proxy?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/`
2. Response reveals IAM role name
3. Second request: `GET /api/proxy?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/ROLE_NAME`
4. Response contains AccessKeyId, SecretAccessKey, Token
5. Attacker now has full AWS credentials for that role

**Mitigations:**
- Enforce IMDSv2 (requires PUT request with token, not just GET)
- Network-level block of 169.254.169.254 from application containers
- Minimal IAM role permissions on compute instances
- Monitor for unexpected metadata endpoint access in logs

---

## Webhook & Callback URLs

| Check | Why | CWE |
|-------|-----|-----|
| Webhook destination URLs validated against allowlist or blocklist | SSRF via feature | CWE-918 |
| Webhook delivery uses dedicated outbound proxy | Network isolation | CWE-918 |
| Webhook timeout short (5-10 seconds) | Slow-loris / port scanning | CWE-400 |
| Webhook response body not stored or returned | Data exfiltration channel | CWE-200 |
| Webhook URL changes require re-verification | URL swap after initial validation | CWE-918 |

**Patterns to catch:**
- User-configurable webhook URL without any validation
- Webhook delivery from application server (same network as internal services)
- Webhook response body stored and viewable by user (SSRF data exfiltration)
- No timeout on webhook delivery (used for port scanning: timing-based)
- Webhook URL validated at registration but not at delivery time

---

## Image/File Proxy & Processing

| Check | Why | CWE |
|-------|-----|-----|
| Image proxy validates URL before fetching | SSRF via image URL | CWE-918 |
| Image processing library updated (ImageMagick, PIL, Sharp) | Known SSRF/RCE CVEs | CWE-918 |
| SVG files not processed server-side (or sanitized first) | SVG can trigger SSRF via `<image>`, `<use>` | CWE-918 |
| OpenGraph/unfurl preview validates target URL | SSRF via link preview | CWE-918 |
| PDF generation tools restricted from network access | HTML-to-PDF SSRF | CWE-918 |

**Patterns to catch:**
- Avatar URL fetched server-side: `fetch(user.avatarUrl)` without validation
- Link unfurling/preview that fetches arbitrary URLs
- HTML-to-PDF (wkhtmltopdf, Puppeteer) with user-controlled HTML containing `<img src="http://internal/">`
- ImageMagick processing user-uploaded SVG (CVE history of SSRF/RCE)
- OEmbed/embed endpoint fetching user-provided URLs
- QR code processing that auto-follows encoded URLs

---

## DNS Rebinding Defense

| Check | Why | CWE |
|-------|-----|-----|
| DNS resolution pinned for duration of request | Time-of-check vs time-of-use | CWE-367 |
| IP re-validated if connection is reused from pool | Cached connection to rebound IP | CWE-918 |
| Short DNS TTL from external domains treated with suspicion | Rebinding indicator | CWE-918 |
| DNS resolution and HTTP request use same resolved IP | Split resolution attack | CWE-918 |

**How DNS rebinding works:**
1. Attacker registers `evil.com` with very short TTL (0-1 second)
2. First DNS query: `evil.com` → `1.2.3.4` (attacker's public IP, passes validation)
3. Application validates URL: "not internal, allowed"
4. DNS TTL expires, attacker changes record: `evil.com` → `169.254.169.254`
5. Actual HTTP request resolves again: `evil.com` → `169.254.169.254` (internal!)
6. Request hits cloud metadata endpoint

**Defense:**
- Resolve DNS once, use that IP for the actual request
- Validate IP AFTER resolution, immediately before connection
- Don't rely on DNS caching for security (TTL controlled by attacker)
