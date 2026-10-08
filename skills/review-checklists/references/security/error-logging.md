# Error Handling & Logging

> OWASP: A09 Logging & Alerting Failures, A10 Mishandling of Exceptional Conditions. Method, severity and the output contract live in SKILL.md.

Two things matter in a diff: a security control that **fails open**, and sensitive data that **leaks** through an error or a log. Generic logging hygiene (structured format, centralization, alerting thresholds, retention) is operational, not a review finding.

## Fail-Open on a Security Control

The highest-value check here: when a security decision throws, times out or errors, does the system **deny** or **allow**?

**Finding when** a control's error path proceeds instead of blocking (CWE-636):

| Control | Fails open when… |
|---|---|
| Auth / token validation | `catch { next() }`, or an exception path that skips the check and continues |
| Authorization / permission load | the DB or policy lookup errors and a cached or default role is granted |
| Rate limiter / WAF / CAPTCHA | the limiter service is down and the request passes unthrottled |
| Payment / entitlement verification | the verify call times out and the order is fulfilled anyway |
| Feature flag / config service | unreachable, and *all* features default on |

Fix: default to deny; the outcome of a security check must be explicit on every path, the error path included. **Any `catch` around a security check that lets the operation proceed is a candidate fail-open.**

**Not a finding:** an error path that already denies; a non-security control failing open (a display cache).

## Unhandled Errors & Crashes

**Finding when:** an empty catch swallows an error a caller acts on (`catch (e) {}`; an error turned into an empty result that feeds a destructive step is `correctness.md`); a `catch` logs but returns success; an unhandled rejection crashes the process; a goroutine **spawned** from a Go handler panics with no `recover` of its own, which crashes the whole process (CWE-248).

**Not a finding:** a panic inside a Go `net/http` handler itself: the server recovers it, logs the trace and resets the connection.

## Information Leaks

**Finding when:**
- A client-facing error returns internals: `err.message`/`err.stack`, a raw DB error, a SQL fragment, an internal path, or a framework default error page in production (CWE-209). A structured envelope (RFC 9457 `problem+json`) is fine as long as `detail` stays generic and internals live only in server logs keyed by a correlation ID.
- A `404` vs `403` (or a timing difference) reveals whether a resource or account exists (CWE-203): enumeration (`auth.md`).
- Secrets or PII written to logs: `logger.info(req.body)`, a logged token, a full user object, a connection string (CWE-532).
- Untrusted text with newlines or control characters written to a log unescaped (log forging, CWE-117).

**Not a finding:** a generic client-facing detail with the sensitive data kept server-side; a verbose error that leaks nothing sensitive (`Hardening:`).

## Audit Events

Missing audit logging is **not** reported by default. The one exception: a **privileged action the diff adds** (a role grant, impersonation, a payout, a bulk export) with no record, in a system that already has an audit facility, is Medium (CWE-778). Don't demand audit logging where none exists, and don't attach a CWE to tamper-evidence, immutability or retention claims.
