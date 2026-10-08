# Cryptography

> OWASP: A04 Cryptographic Failures. Method, severity and the output contract live in SKILL.md.

A weak primitive is a finding only when it is used **for security**. An MD5 ETag, a CRC checksum, or `Math.random()` for a cosmetic value is not. Password *policy* and reset live in `auth.md`; HSTS and TLS headers in `misconfiguration.md`.

## Password & Token Hashing

**Finding when:**
- A fast or plain hash stores passwords: `md5`/`sha1`/`sha256(password)`, a single-round digest, a custom hash, or reversible encryption (AES) instead of a password hash (CWE-916).
- A global or shared salt, or no salt (adaptive hashes salt per password automatically).
- A raw password over 72 bytes reaches bcrypt with no handling: bcrypt truncates at 72 bytes and at the first NUL. Fix: cap input at 72, or pre-hash as `bcrypt(base64(hmac-sha384(password, pepper)))` with the pepper stored outside the DB, never a plain `sha*` pre-hash (null-byte and password-shucking risks). pyca/bcrypt ≥5.0 raises `ValueError` past 72 bytes; below that it truncates silently.
- bcrypt over a **composite** input (a cache key of `id + username + password`): the 72-byte truncation drops the password portion (the Okta 2024 class). High or worse.
- `==`/`===` instead of a constant-time compare for a secret or MAC (CWE-208).

**Not a finding:** a high-entropy random API token (≥128-bit) stored as an unsalted SHA-256 (fast hashing suits secrets that can't be brute-forced, unlike passwords); bcrypt at cost ≥10; `secrets.compare_digest` or `crypto.timingSafeEqual`; a fresh per-call nonce.

Parameter floors (OWASP Password Storage, verified 2026-10-08; re-check the current cheat sheet before citing a number): Argon2id `m=19456,t=2,p=1`; scrypt `N=2^17,r=8,p=1`; bcrypt cost ≥10; PBKDF2-HMAC-SHA256 ≥600,000. Prefer Argon2id for new systems.

## Symmetric Encryption

**Finding when:**
- ECB, unauthenticated CBC, or a homegrown, deprecated or undersized primitive guarding data (XOR, Base64 as encryption, DES, RC4, RSA under 2048 bits; CWE-327): use a vetted library, an AEAD for data. A hardcoded key (CWE-321), a password used as a key with no KDF, or one key for both encryption and authentication.
- A static or zeroed IV or nonce, a nonce reused under one key, or a counter nonce that restarts with the process or is shared across instances. For GCM and Poly1305, reuse is catastrophic: it leaks the XOR of plaintexts *and* recovers the auth key, enabling forgery (CWE-323). A random 96-bit GCM nonce used beyond ~2³² messages per key risks a birthday collision: use XChaCha20-Poly1305 or AES-GCM-SIV when uniqueness can't be guaranteed.
- Node's `crypto.createCipher()`, removed in Node 22 (weak key derivation): if present, the service also runs an old Node, so flag the runtime too.

**Not a finding:** any sound AEAD (AES-GCM, ChaCha20-Poly1305) with unique nonces, AES-128 and AES-256 alike.

## Randomness, Tokens & Keys

**Finding when:**
- `Math.random()`, `random.random()`, `rand.Intn` or a predictable seed (`time.Now()`, PID) used for a token, session ID, nonce or reset secret (CWE-338), or a security token short enough to guess (CWE-334). Use the platform CSPRNG (`crypto.getRandomValues`, `secrets`, `crypto/rand`, `SecureRandom`) with ≥128 bits.
- A UUID used as a secret (RFC 9562 §8: UUIDs MUST NOT be used as security capabilities): v1 leaks time and MAC, v7 creation order, and a v4 from a non-CSPRNG library is guessable (CWE-340).

**Not a finding:** a CSPRNG-backed UUIDv4 token (`crypto.randomUUID()`, Python `uuid4()`; 122 random bits): at most `Hardening:`. An unguessable ID offered *alongside* a real ownership check: the check is the control, never the ID (`auth.md`).

## Signatures & TLS

**Finding when:**
- Signed data trusted before the signature is verified, or a signature covering only part of the payload (CWE-347); JWT verification with no algorithm allowlist (`auth.md`); an HMAC compared non-constant-time.
- TLS verification disabled on a production path (any client's verify-off flag or env var) or a self-signed cert accepted there; plain HTTP to an external service; TLS 1.0 or 1.1 allowed (CWE-295, CWE-319, CWE-757).
- A private key file left world-readable (`chmod 644 *.key`, CWE-732); a committed key is a secret (`supply-chain.md`).

**Not a finding:** certificate lifetimes and renewal (operations); mobile certificate pinning (MASVS, out of scope).
