# API & Injection

> OWASP: A01 Broken Access Control, A05 Injection, A08 Integrity (deserialization). Method, severity and the output contract live in SKILL.md; this file gives the exploitable shape and what separates it from the decoy.

CORS and response security headers live in `misconfiguration.md`; authorization, IDOR and redirects in `auth.md`.

**Entry points include more than routes.** A Next.js Server Action (`'use server'`) is reachable by a direct POST; a TanStack Start `createServerFn` is an HTTP RPC route; RSC props serialize to the client. Treat each as a public endpoint and apply this file plus `auth.md` (framework detail: the react-best-practices Server boundary, if available).

## Injection

**Finding when** user input is concatenated or interpolated into SQL (ORM raw modes too: `queryRawUnsafe`, `knex.raw(input)`; CWE-89), a shell command (use an argument array; CWE-78), a template rendered as code (SSTI, CWE-1336), `eval` or `Function` (CWE-94), an LDAP filter, or a NoSQL query that accepts user-supplied operators such as `$where` or `$regex` (CWE-943).

XXE is a finding when an XML parser loads external entities or DTDs: `noent: true` (libxml2), external DTD fetching, or a Java `DocumentBuilderFactory` or SAX parser left at its defaults (CWE-611). `noent: false` is libxml2's safe default, and the Python stdlib doesn't fetch external entities: don't flag those.

**Not a finding:** a parameterized query (`$1` placeholders, bound params, a query builder); `execFile` with an argument array; an identifier checked against a fixed set. An allowlist *regex* counts only when anchored to the whole string: an unanchored pattern (`/[a-z]+/`), Python `re.match` or `re.search` instead of `re.fullmatch`, and Ruby's line anchors `^…$` instead of `\A…\z` each pass input that merely contains a match (CWE-777).

## Mass Assignment

**Finding when:** the whole request body is spread into a create or update (`Model.update({...req.body})`), letting the client set fields it shouldn't (`role`, `isAdmin`, `balance`, `verified`, `userId`), or prototype-pollution keys (`__proto__`, `constructor`) reach an object merge (CWE-915, CWE-1321). Severity follows what the writable field controls (authz or money fields: `auth.md`).

**Not a finding:** a body filtered through an explicit per-operation allowlist or DTO.

## Cross-Site Scripting (XSS)

**Finding when** attacker-influenced content (a reflected value; user or LLM content shown to others) reaches unescaped server HTML (CWE-79), a DOM sink (`innerHTML` and its kin, a `location` assignment), a framework escape hatch (`dangerouslySetInnerHTML`, `v-html`, Angular `bypassSecurityTrust*`), or a URL attribute with no scheme allowlist (`javascript:`; React 19+ and Angular neutralize it). Server-side auto-escaping doesn't stop DOM XSS: the sink is client-side. Escaping for the wrong context is the same bug (CWE-838): an HTML-escaped value inside `<script>`, an inline event handler, an unquoted attribute or CSS, or server data serialized into a `<script>` tag without escaping `<`. Encode for the sink's context; serialize with a script-safe encoder.

**Not a finding:** content passed through a vetted sanitizer (DOMPurify) before render, or output encoded for the context it lands in. A strict CSP or Trusted Types is a hardening layer, not a precondition.

## Path Traversal & Arbitrary File Access

**Finding when:**
- A file path built from user input without canonicalize-and-contain: `fs.readFile(base + name)`, `open(base + name)`, accepting `..`, absolute paths, or encoded or double-encoded traversal (CWE-22).
- A containment prefix check without a trailing separator: `resolved.startsWith('/srv/uploads')` also admits `/srv/uploads-archive/...`. Compare against `base + path.sep`, or use `path.relative` and reject `..`.
- Archive extraction that writes an entry whose resolved destination is outside the target directory (Zip Slip).
- A template or include path built from user input (LFI).

**Not a finding:** input mapped to an ID or allowlist; a path from a trusted store reduced with `path.basename`.

## File Upload

Three questions decide it:
1. **Can the user choose the stored key or path?** Overwrite or traversal (above).
2. **Is it served from the app's own origin with a sniffable or client-supplied type (HTML, SVG)?** Stored XSS. Fix: a separate domain, or `Content-Disposition: attachment` + a server-set type + `nosniff` (CWE-434).
3. **What parses it server-side?** That is where SSRF, RCE and decompression bombs come from (image and PDF fetchers: `ssrf.md`).

**Finding when:** any of the three is unguarded; the type is validated by extension or client `Content-Type` only and question 2 or 3 applies; no server-side size limit.

**Not a finding:** extension-only checks on a store that never executes or renders files by type (object storage served as `attachment`).

## Webhook Security (inbound)

**Finding when:** the signature isn't verified over the **raw** body bytes before parsing; the comparison isn't constant-time; the handler doesn't fail closed when the signature header is missing; no timestamp window (replay); not idempotent on the event ID (duplicate delivery: `correctness.md`). A user-configurable callback URL with no SSRF guard: `ssrf.md`.

## Deserialization

**Finding when (untrusted input, CWE-502):**
- Python: `pickle.loads`; `yaml.load` with `Loader=yaml.Loader` or `UnsafeLoader`, or `yaml.unsafe_load` (PyYAML ≥6 requires a `Loader`, so a bare `yaml.load` no longer parses; `FullLoader` below 5.4 is also unsafe).
- Ruby: `Marshal.load`; `YAML.unsafe_load`, or Psych pinned below 4 (Psych ≥4 makes `YAML.load` safe).
- PHP: `unserialize()` on input; use `json_decode`.
- Java `ObjectInputStream.readObject`; .NET `BinaryFormatter`, or a serializer that takes a type name from input (Json.NET `TypeNameHandling` other than `None`); `node-serialize`.
- A signed blob deserialized before its signature is checked.

**Not a finding:** JSON parsing, a safe loader (`yaml.safe_load`), or an allowlist of permitted classes.

## HTTP Request Smuggling

**Finding when:** a front proxy and the backend parse request boundaries differently: both `Transfer-Encoding` and `Content-Length` accepted, an obfuscated `Transfer-Encoding`, a duplicate `Content-Length`, or an ambiguous request interpreted rather than rejected (CWE-444). HTTP/2-to-HTTP/1.1 downgrade at the edge reintroduces these; prefer HTTP/2 end to end to the origin.

## WebSocket Security

**Finding when:** the upgrade doesn't validate `Origin` (cross-site WebSocket hijacking, CWE-1385); auth is checked only at the handshake, never per session, so a stolen socket stays usable; user input is broadcast to other clients unsanitized; no message-size or per-connection message cap.

## Rate Limiting & Resource Exhaustion

Report exhaustion **only with amplification**: one request causing unbounded work or spend.

**Finding when:** unbounded batch, alias, depth or array sizes (GraphQL included: set limits from the deepest operation real clients send, or allowlist persisted operations); decompression or pixel bombs (CWE-409); a ReDoS shape on attacker input, on a backtracking engine only: nested quantifiers `(a+)+`, overlapping alternation `(a|a)*`, `(\w+\s?)*$` (CWE-1333; RE2-family engines such as Go `regexp` and Rust `regex` don't backtrack, and disjoint alternation like `(a|b)*c` is not ReDoS); LLM, SMS, email or export spend with no per-principal cap (CWE-770).

**Not a finding:** a missing generic rate limit with no amplification (`Hardening:`; a guessing surface with no attempt limit is High: `auth.md`); GraphQL introspection in production. Missing field-level authz on resolvers is an access finding (`auth.md`).

## Data Exposure

**Finding when:** a response serializes sensitive fields the client doesn't need (a password hash, a token, another user's PII); select fields explicitly (CWE-201). Error-detail leaks: `error-logging.md`; missing pagination: `correctness.md`.
