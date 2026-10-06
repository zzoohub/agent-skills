# Error Handling, Logging & Alerting

> OWASP: A09 (Security Logging & Alerting Failures), A10 (Mishandling of Exceptional Conditions)

---

## Table of Contents

1. [Error Handling — Client-Facing](#error-handling--client-facing)
2. [Error Handling — Server-Side](#error-handling--server-side)
3. [Fail-Closed vs Fail-Open Analysis](#fail-closed-vs-fail-open-analysis)
4. [Security Event Logging](#security-event-logging)
5. [Log Integrity & Safety](#log-integrity--safety)
6. [Alerting & Monitoring](#alerting--monitoring)
7. [Audit Trail Requirements](#audit-trail-requirements)


## Error Handling — Client-Facing

| Check | Why | CWE |
|-------|-----|-----|
| Generic error messages to clients (no internals leaked) | Information disclosure | CWE-209 |
| No stack traces in production API responses | Path/library/version exposure | CWE-209 |
| No database error messages forwarded to client | SQL structure disclosure | CWE-209 |
| No internal file paths in error responses | Server layout disclosure | CWE-209 |
| Error responses use consistent format (same structure for all errors) | Error type enumeration | CWE-203 |
| HTTP status codes don't reveal business logic state | State inference | CWE-203 |

A structured error envelope (e.g. RFC 9457 `application/problem+json`) satisfies all of the above — and helps the consistent-format item — as long as `detail` stays generic to clients and the internals (stack, query, paths) live only in server-side logs keyed by a correlation id.

**Patterns to catch:**
- Try/catch that returns `err.message` or `err.stack` to client
- Framework default error handler enabled in production (Django DEBUG, Express default)
- Database query error returned verbatim: `res.status(500).json({ error: err.message })`
- Different error format for different error types (reveals error category)
- `404` vs `403` on resources (reveals resource existence)
- Detailed validation errors that reveal internal schema structure
- Error messages containing SQL queries, file paths, or class names

---

## Error Handling — Server-Side

| Check | Why | CWE |
|-------|-----|-----|
| All exceptions caught and handled (no unhandled rejections/exceptions) | Application crash | CWE-755 |
| Fail-closed: security checks default to deny on error | Fail-open bypass | CWE-636 |
| Error in auth/authz results in access denied, not access granted | Auth bypass via error | CWE-280 |
| Resource cleanup on error (connections, file handles, locks) | Resource leak DoS | CWE-404 |
| Error recovery doesn't skip security-critical steps | Post-error state corruption | CWE-755 |
| Null/undefined handling for all external data | Null pointer crash | CWE-476 |

**Patterns to catch:**
- Empty catch block: `catch (err) { }` (error silently swallowed)
- Auth middleware that calls `next()` on error (fail-open): 
  ```javascript
  try { verify(token) } catch { next() }  // WRONG: should return 401
  ```
- Missing `finally` block for resource cleanup
- Error in rate limiter allows unlimited requests (fail-open)
- Crash on malformed input instead of graceful rejection
- `catch` block that only logs but doesn't set correct response status
- Unhandled promise rejection causing process crash in Node.js
- `panic` in Go without `recover` in HTTP handlers

---

## Fail-Closed vs Fail-Open Analysis

| Scenario | Correct Behavior | Common Mistake |
|----------|-----------------|----------------|
| Auth service unreachable | Block access (fail-closed) | Allow access (fail-open) |
| Token validation throws exception | Return 401/403 | Skip validation, continue |
| Rate limiter service down | Apply default strict limit | Remove rate limiting |
| WAF/filter error | Block request | Pass through unfiltered |
| Payment verification timeout | Don't fulfill order | Fulfill and hope for the best |
| CAPTCHA service error | Show challenge again | Skip CAPTCHA |
| Feature flag service unreachable | Use restrictive defaults | Enable all features |
| Database connection error on permission check | Deny access | Grant based on cached/default role |

**Critical pattern:** Any `catch` block on a security check that allows the operation to proceed is a potential fail-open vulnerability.

---

## Security Event Logging

| Check | Why | CWE |
|-------|-----|-----|
| Authentication attempts logged (success and failure) | Brute force detection | CWE-778 |
| Authorization failures logged | Access control probing | CWE-778 |
| Privilege changes logged (role assignment, permission grant) | Insider threat detection | CWE-778 |
| Sensitive data access logged (export, bulk read, PII access) | Data breach investigation | CWE-778 |
| Account lifecycle events logged (create, delete, disable, MFA changes) | Account manipulation detection | CWE-778 |
| Administrative actions logged with full context | Admin abuse detection | CWE-778 |
| Input validation failures logged (potential attack probing) | Attack pattern detection | CWE-778 |

**Minimum security events to log:**

| Event | What to Record |
|-------|---------------|
| Login success | User ID, IP, user-agent, timestamp, auth method |
| Login failure | Attempted user, IP, user-agent, timestamp, failure reason |
| Logout | User ID, session duration, timestamp |
| Password change/reset | User ID, IP, method (self-service vs admin), timestamp |
| MFA enable/disable | User ID, IP, MFA method, timestamp |
| Permission change | User ID, changed by, old role, new role, timestamp |
| Data export | User ID, data type, row count, IP, timestamp |
| API key created/revoked | User ID, key scope, key ID (not key itself), timestamp |
| Account lockout | User ID, reason, attempt count, IP, timestamp |
| Sensitive resource access | User ID, resource type, resource ID, action, timestamp |

---

## Log Integrity & Safety

| Check | Why | CWE |
|-------|-----|-----|
| No sensitive data in logs (passwords, tokens, PII, credit cards) | Log file exposure | CWE-532 |
| Log injection prevented (newlines, control characters stripped) | Log forging/SIEM confusion | CWE-117 |
| Structured logging format (JSON) not string concatenation | Parsing consistency | CWE-117 |
| Logs stored in append-only or tamper-evident storage | Evidence tampering | CWE-779 |
| Log rotation and retention policy defined | Storage exhaustion, compliance | CWE-779 |
| Centralized logging (not just local files) | Single-point-of-failure, correlation | CWE-778 |

**Patterns to catch:**
- Logging raw request body: `logger.info(req.body)` (may contain passwords)
- Logging tokens: `logger.debug("Token: " + token)`
- Logging full user object: `logger.info("User:", user)` (password hash, PII)
- String interpolation in logs: `logger.info("User " + username + " logged in")` (log injection)
- No structured logging library (just `console.log` in production)
- Logs stored only on application server (lost on restart/crash)
- No log retention policy (unlimited growth or premature deletion)
- Logging credit card numbers, SSNs, or API keys
- Error logging that includes full database connection strings

**Log injection example:**
```
# Attacker submits username: "admin\nINFO: User admin logged in successfully"
# Without sanitization, log shows:
INFO: Login failed for admin
INFO: User admin logged in successfully  # FORGED entry
```

---

## Alerting & Monitoring

| Check | Why | CWE |
|-------|-----|-----|
| Alert on repeated auth failures from single source | Brute force attack | CWE-307 |
| Alert on unusual data access patterns (bulk, off-hours) | Data exfiltration | CWE-778 |
| Alert on privilege escalation events | Unauthorized elevation | CWE-269 |
| Alert on application error rate spikes | Active exploitation | CWE-778 |
| Alert on new admin account creation | Backdoor account | CWE-778 |
| Alert latency reasonable (minutes, not hours/days) | Time to detection | CWE-778 |
| Alert fatigue managed (tuned thresholds, no false positive flood) | Missed real alerts | CWE-778 |

**Detection scenarios to validate:**
- 100 failed logins from single IP in 5 minutes → alert fires?
- Authorized user exports entire customer database → alert fires?
- New admin user created outside business hours → alert fires?
- 500 error rate increases 10x in 1 minute → alert fires?
- Same user authenticates from two countries within 1 hour → alert fires?

---

## Audit Trail Requirements

| Check | Why | CWE |
|-------|-----|-----|
| Who did what, when, from where (user, action, timestamp, IP) | Forensic investigation | CWE-778 |
| Before and after values for state changes | Change attribution | CWE-778 |
| Audit logs immutable (append-only, separate from application) | Evidence preservation | CWE-779 |
| Audit log retention meets compliance requirements | Regulatory obligation | CWE-779 |
| Audit logs cannot be disabled by application admin | Cover-up prevention | CWE-778 |
| Request correlation ID links related log entries | Cross-service tracing | CWE-778 |

**Patterns to catch:**
- State changes without any logging (UPDATE query with no audit record)
- Audit log in same database as application data (can be modified together)
- No correlation ID in distributed systems (can't trace request across services)
- Audit log deletable by admin without additional authorization
- Only current state stored (no history of who changed what and when)
- Audit logs without timestamps or with client-provided timestamps
