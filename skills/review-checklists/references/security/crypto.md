# Cryptographic Failures

> OWASP: A04 (Cryptographic Failures)

---

## Table of Contents

1. [Password & Credential Hashing](#password--credential-hashing)
2. [Encryption (At Rest)](#encryption-at-rest)
3. [Encryption (In Transit)](#encryption-in-transit)
4. [Key Derivation](#key-derivation)
5. [Random Number Generation](#random-number-generation)
6. [Digital Signatures & Verification](#digital-signatures--verification)
7. [Certificate Management](#certificate-management)
8. [Homegrown Crypto Detection](#homegrown-crypto-detection)


## Password & Credential Hashing

| Check | Why | CWE |
|-------|-----|-----|
| Argon2id (preferred) or bcrypt (OWASP minimum cost 10; prefer ≥12 where login latency allows — 10–11 is a hardening note, not a finding) for passwords | GPU/ASIC resistance | CWE-916 |
| bcrypt input length handled — pre-hash (e.g. base64(SHA-256)) passwords >72 bytes; bcrypt silently truncates at 72 bytes / first NULL byte (Argon2id/scrypt have no such limit) | Silent password weakening, hash collisions | CWE-916 |
| NEVER MD5, SHA1, SHA256 alone for passwords | No key stretching, rainbow tables | CWE-916 |
| Unique salt per password (auto-handled by bcrypt/argon2) | Pre-computation attacks | CWE-916 |
| API tokens (high-entropy random ≥128-bit) hashed with SHA-256 before storage — fast unsalted hash is fine since tokens aren't brute-forceable, unlike low-entropy passwords | Token theft from DB | CWE-312 |
| Timing-safe comparison for all credential checks | Timing side-channel | CWE-208 |

**Patterns to catch:**
- `md5(password)`, `sha1(password)`, `sha256(password)` for password storage
- `hashlib.md5`, `crypto.createHash('md5')` used for security purposes
- Custom hash function or "encryption" for passwords
- Same salt for all users (global salt)
- String comparison (`===`, `==`) instead of `crypto.timingSafeEqual` for tokens
- Password stored with reversible encryption (AES) instead of hashing
- Raw password >72 bytes passed to bcrypt without pre-hashing (excess silently ignored); binary digest with embedded NULL bytes fed to bcrypt

---

## Encryption (At Rest)

| Check | Why | CWE |
|-------|-----|-----|
| AES-256-GCM or ChaCha20-Poly1305 for symmetric encryption | Authenticated encryption required | CWE-327 |
| NEVER ECB mode (patterns visible in ciphertext) | Pattern preservation | CWE-327 |
| Unique IV/nonce per encryption operation | For GCM/Poly1305, nonce reuse is catastrophic: leaks plaintext XOR AND recovers the auth key → ciphertext forgery (2016 "forbidden attack"), not just confidentiality loss | CWE-323 |
| Encryption keys stored in KMS/HSM, not in code or config files | Key exposure | CWE-321 |
| Key rotation mechanism exists and is exercised | Compromised key longevity | CWE-324 |
| Sensitive database columns encrypted at application level | DB breach protection | CWE-311 |

**Patterns to catch:**
- `AES-ECB` mode anywhere: `cipher = AES.new(key, AES.MODE_ECB)`
- `DES`, `3DES`, `RC4`, `Blowfish` (deprecated algorithms)
- Hardcoded encryption key in source code: `key = "my-secret-key-123"`
- IV/nonce set to static value or zeros: `iv = b'\x00' * 16`
- Counter-based nonce that resets on process restart, or a random 96-bit GCM nonce used beyond ~2³² messages per key (birthday collision) — use XChaCha20-Poly1305 or a SIV mode (AES-GCM-SIV) if uniqueness can't be guaranteed
- Same key used for encryption and authentication
- Encryption without authentication (AES-CBC without HMAC)
- Key derived from password without proper KDF (see Key Derivation below)
- `crypto.createCipher()` in Node.js (deprecated, weak key derivation)

---

## Encryption (In Transit)

| Check | Why | CWE |
|-------|-----|-----|
| TLS 1.2+ enforced (TLS 1.0, 1.1 disabled) | Known protocol attacks | CWE-326 |
| Strong cipher suites only (no RC4, DES, NULL, EXPORT) | Weak cipher downgrade | CWE-326 |
| Certificate validation enabled (never disabled) | MITM attacks | CWE-295 |
| HSTS header with long max-age (≥31536000) | Protocol downgrade | CWE-319 |
| Internal service communication also encrypted | Lateral movement after breach | CWE-319 |
| Certificate pinning for mobile apps (when appropriate) | CA compromise | CWE-295 |

**Patterns to catch:**
- `verify=False` (Python requests), `rejectUnauthorized: false` (Node.js)
- `InsecureSkipVerify: true` (Go), `@insecure` annotation
- `NODE_TLS_REJECT_UNAUTHORIZED=0` environment variable
- HTTP URLs for API calls to external services (no TLS)
- Self-signed certificates accepted in production
- TLS configuration allowing SSLv3 or TLS 1.0
- Missing HSTS header or very short max-age

---

## Key Derivation

**Preference order (2026):** Argon2id > scrypt > PBKDF2. Use Argon2id when available; PBKDF2 only when FIPS-140 compliance forces it.

| Check | Why | CWE |
|-------|-----|-----|
| Argon2id (preferred): OWASP floor `m=19456 (19 MiB), t=2, p=1` (equal-defense alts: m=12288/t=3/p=1, m=9216/t=4/p=1, m=7168/t=5/p=1); harden toward `m≥64 MiB, t≥3` where capacity allows | Memory-hard, GPU-resistant | CWE-916 |
| scrypt with `N=2^17, r=8, p=1` (acceptable alternative) | Memory-hard | CWE-916 |
| PBKDF2-HMAC-SHA256 ≥600,000 iterations (legacy / FIPS only) | Brute force resistance | CWE-916 |
| HKDF for deriving multiple keys from shared secret | Proper key separation | CWE-327 |
| High entropy salt (≥128 bits, cryptographically random) | Pre-computation resistance | CWE-916 |
| Parameters reviewed annually against OWASP cheatsheet | Hardware advances | CWE-916 |

> **Last reviewed against OWASP Password Storage Cheatsheet:** 2026-05. Current OWASP-recommended PBKDF2-SHA256 minimum is 600,000 iterations.

**Patterns to catch:**
- PBKDF2 with <600,000 iterations (SHA-256)
- Direct use of password as encryption key: `AES(password, data)`
- Single-round hash as key derivation: `key = sha256(password)`
- Salt shorter than 128 bits or non-random salt
- Same derived key used for multiple purposes without HKDF expand step

---

## Random Number Generation

| Check | Why | CWE |
|-------|-----|-----|
| Cryptographic RNG for all security values | Predictable outputs | CWE-338 |
| `Math.random()` NEVER used for security | Not cryptographic, predictable | CWE-330 |
| Sufficient entropy for tokens (≥128 bits, ideally 256) | Brute force feasibility | CWE-334 |
| UUIDs use v4 (random) for security purposes, not v1 (time-based) | Predictable UUIDs | CWE-330 |

**Patterns to catch:**
- `Math.random()` for tokens, IDs, secrets, session IDs, nonces
- `random.random()` (Python) for security (use `secrets` module)
- `rand.Intn()` (Go) without `crypto/rand` for security values
- Short tokens: `Math.random().toString(36)` (only ~48 bits entropy)
- UUID v1 used for session tokens (contains timestamp and MAC address)
- Seed from predictable source (`time.Now()`, process ID)
- Custom random function ("roll your own")

**Correct alternatives:**
- JavaScript: `crypto.randomUUID()`, `crypto.getRandomValues()`
- Python: `secrets.token_hex()`, `secrets.token_urlsafe()`
- Go: `crypto/rand.Read()`
- Java: `SecureRandom`
- Ruby: `SecureRandom.hex`

---

## Digital Signatures & Verification

| Check | Why | CWE |
|-------|-----|-----|
| RSA keys ≥2048 bits (ideally 4096) | Key factoring | CWE-326 |
| ECDSA with P-256 or Ed25519 (preferred over RSA for new systems) | Modern standards | CWE-327 |
| Signature verified before trusting signed data | Unsigned data accepted | CWE-347 |
| No signature algorithm confusion (JWT "none" alg) | Algorithm downgrade | CWE-327 |
| Webhook/callback signatures verified with constant-time comparison | Forged payloads | CWE-345 |

**Patterns to catch:**
- RSA key <2048 bits
- DSA keys (deprecated, use ECDSA or Ed25519)
- Signature verification optional or skipped on error
- JWT without algorithm whitelist: `jwt.verify(token, key)` without `algorithms` param
- HMAC comparison with `==` instead of constant-time function
- Signature covers only part of the payload (unsigned fields can be modified)

---

## Certificate Management

| Check | Why | CWE |
|-------|-----|-----|
| Certificates auto-renewed (Let's Encrypt, cert-manager) | Expiration outage | CWE-298 |
| Revocation strategy appropriate to issuer: short-lived certs and/or CRLs, plus OCSP stapling where the CA still issues OCSP URLs (note: Let's Encrypt ended OCSP 2025-08-06, now CRL-only) | Compromised cert usage | CWE-299 |
| Wildcard certificates scoped appropriately | Over-broad trust | CWE-295 |
| Private keys have restricted file permissions (0600) | Key theft | CWE-732 |
| No self-signed certificates in production | Trust chain validation bypass | CWE-295 |

**Patterns to catch:**
- Certificate files with world-readable permissions (`chmod 644 server.key`)
- Private keys stored in git repository (even `.gitignore`d, check history)
- Self-signed certificates in production deployment configurations
- Certificate lifetime exceeding the CA/Browser Forum maximum — 200 days (since 2026-03-15), dropping to 100 days (2027-03-15) and 47 days (2029-03-15); any config assuming the old 398-day ceiling is a renewal-automation gap
- No automated certificate renewal process

---

## Homegrown Crypto Detection

| Check | Why | CWE |
|-------|-----|-----|
| No custom encryption algorithms | Unaudited, likely broken | CWE-327 |
| No custom hash functions for security | Not cryptographically proven | CWE-328 |
| No XOR-based "encryption" | Trivially reversible | CWE-327 |
| No Base64 treated as encryption | Encoding is not encryption | CWE-311 |
| Standard well-maintained libraries used (libsodium, OpenSSL, crypto) | Audited implementations | CWE-327 |

**Patterns to catch:**
- Custom `encrypt()` function that XORs input with a key
- Base64 encoding called "encryption" or used to "protect" sensitive data
- ROT13, Caesar cipher, or substitution cipher for any security purpose
- Custom padding implementation (use PKCS7 from library)
- Re-implementation of standard algorithms (custom AES, custom SHA)
- "Obfuscation" passed off as encryption (string reversal, character shifting)
- `btoa()` / `atob()` used to "secure" data
