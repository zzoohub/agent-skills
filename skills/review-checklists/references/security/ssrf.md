# Server-Side Request Forgery (SSRF)

> OWASP: A01 Broken Access Control (SSRF folds in here). Method, severity and the output contract live in SKILL.md.

**Control of the host or scheme is SSRF; control of only the path is not**, except a path that traverses into a privileged internal API. Rate by what the attacker gets back: a **full-response** SSRF that reaches credentials (an open cloud metadata endpoint, an internal admin API) is Critical; a **blind** SSRF (no response body returned) is High, unless it reaches a state-changing internal endpoint or a raw-protocol service (an internal Redis via `gopher://`): then rate it by that effect.

## Finding when

- User input reaches a server-side fetch with no scheme or host allowlist: `fetch(userUrl)`, `requests.get(userUrl)`, `http.Get`, `HttpClient`, accepting `file://`, `gopher://`, `dict://` or any internal host (CWE-918).
- Redirects followed without re-validating each hop: an allowed URL 3xx-redirects to an internal address (`redirect: 'follow'` with no per-hop check).
- Check-then-fetch on a hostname: the guard resolves and classifies the IP, then the client resolves the name again to connect (DNS rebinding: a short-TTL record flips to an internal address in between). Connect to the IP you checked.
- The guard parses the URL with a different parser than the client that fetches it: userinfo (`http://allowed@evil/`), backslashes and encoded characters split differently between parsers. Parse once and hand the client the checked result.
- The fetched body is returned to or stored for the user, turning SSRF into an internal-response disclosure and exfiltration channel.
- A server-side fetcher the user can steer: an avatar, OpenGraph or unfurl URL; HTML-to-PDF or headless-browser input containing `<img src="http://internal/">`; an image library processing a user-supplied SVG (`<image>`/`<use>` fetch); a webhook or callback URL validated at registration but not at delivery.

## Not a finding

- A host that is a fixed server-side constant or chosen from a server-side allowlist, with only a validated non-URL component (an integer ID, an encoded key) under user control.
- A numeric IPv4 form (decimal `2130706433`, hex `0x7f000001`, octal `0177.0.0.01`, short `127.1`) against a check on a WHATWG-parsed hostname (Node `URL`, browsers, Deno, Bun), which normalizes it to dotted-quad first. It bypasses only a guard that compares the raw host string while the client resolves it `inet_aton`-style (Python `requests`, curl). IPv6 forms (`[::1]`, `[::ffff:127.0.0.1]`), other 127/8 addresses, `0.0.0.0` and names that resolve internal beat a raw-string blocklist on every stack.

## The robust guard

The only guard that holds across stacks: **resolve the hostname, classify the resolved IP, then connect to that pinned IP** (re-running the check on every redirect hop), or route the fetch through an egress proxy that enforces the policy.

Classify with a **maintained special-purpose-address predicate**, not a hand-written list, decoding IPv4-embedded IPv6 first. Hand-rolled lists miss ranges: beyond RFC 1918 (`10/8`, `172.16/12`, `192.168/16`), loopback (`127/8`, `::1`) and link-local (`169.254/16`, `fe80::/10`), they routinely omit `100.64.0.0/10` (carrier-grade NAT, which holds Alibaba's `100.100.100.200` metadata address) and the NAT64 prefix `64:ff9b::/96`.

## Cloud metadata

The highest-value SSRF target. Rate an SSRF that reaches `169.254.169.254` (AWS, GCP, Azure), `fd00:ec2::254` (AWS IPv6), `fd20:ce::254` (GCP IPv6) or `100.100.100.200` (Alibaba) by what the fetch can do there. AWS IMDSv1 answers a plain GET: credential theft, Critical when the response comes back. IMDSv2 needs a token from a `PUT`, and GCP and Azure require a request header (`Metadata-Flavor: Google`, `Metadata: true`), so a fetch that can't set the method or headers can't read credentials there. An IMDSv2-only host proves the host is hardened, not that the fetch is guarded. A network block of the metadata IP and a minimal instance role lower the severity.
