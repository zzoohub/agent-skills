# API Patterns

Worked HTTP exchanges for common and advanced patterns. Rules live in SKILL.md and `api-design.md`; problem `type` URIs are abbreviated here as `.../<slug>`.

## Table of Contents

1. [CRUD](#crud)
2. [Idempotent Create](#idempotent-create)
3. [Error Responses (RFC 9457)](#error-responses-rfc-9457)
4. [Pagination](#pagination)
5. [Conditional Requests (ETag)](#conditional-requests-etag)
6. [State Transitions](#state-transitions)
7. [File Upload](#file-upload)
8. [Search](#search)
9. [Relationship Expansion](#relationship-expansion)
10. [Async Jobs](#async-jobs)
11. [Bulk Operations](#bulk-operations)
12. [Server-Sent Events (SSE)](#server-sent-events-sse)
13. [Webhooks](#webhooks)

---

## CRUD

### Create (POST → 201)

```http
POST /v1/users
Content-Type: application/json
{ "name": "Ada Lovelace", "email": "ada@example.com" }

→ 201 Created
Location: /v1/users/0192c8f7-4d62-7c98-b5fd-3e1a2c9d8b40
X-Request-Id: 7f3c2a9e
{ "data": { "id": "0192c8f7-4d62-7c98-b5fd-3e1a2c9d8b40", "name": "Ada Lovelace", "email": "ada@example.com", "created_at": "..." } }
```

### Read (GET → 200)

```http
GET /v1/users/0192c8f7-4d62-7c98-b5fd-3e1a2c9d8b40
→ 200 OK
ETag: "3"
{ "data": { "id": "0192c8f7-4d62-7c98-b5fd-3e1a2c9d8b40", "name": "Ada Lovelace", ... } }
```

A user from another tenant gets the same 404 as a missing id — existence is not disclosed.

### Update (PATCH → 200, JSON Merge Patch)

```http
PATCH /v1/users/0192c8f7-4d62-7c98-b5fd-3e1a2c9d8b40
If-Match: "3"
{ "name": "Ada Byron Lovelace", "nickname": null }    # nickname cleared; absent fields unchanged
→ 200 OK
ETag: "4"
{ "data": { ..., "updated_at": "..." } }
```

### Delete (DELETE → 204)

```http
DELETE /v1/users/0192c8f7-4d62-7c98-b5fd-3e1a2c9d8b40
→ 204 No Content
X-Request-Id: 1b7d40c2
```

---

## Idempotent Create

```http
POST /v1/payments
Idempotency-Key: 8e1c6a0f-3b2d-4f7e-9a51-2c4d6e8f0a1b
{ "amount": 5000, "currency": "USD" }
→ 201 Created
Location: /v1/payments/0192c8f9-...
```

| Retry of the same intent | Response |
|---|---|
| Same key, same request (method, path with query, body), completed | The stored status, body, `Location` / `Content-Type` / `ETag` replayed (optionally `Idempotent-Replayed: true`) |
| Same key, first request still running | **409** `.../idempotency-in-flight` + `Retry-After: 1` |
| Same key, different body, path or method | **422** `.../idempotency-key-mismatch` — a client bug; do not retry |
| Key over 255 chars or not visible ASCII; route requires a key and none sent | **400** `.../malformed-request` |

A key is scoped to tenant + principal. A completed 4xx decided by the body or state (e.g. 422 validation, 409 already-exists) is replayed too; one decided by headers outside the hash (415, 406, 412, 428) is never stored, and a 5xx or a crash releases the key so the retry runs again.

---

## Error Responses (RFC 9457)

All use `Content-Type: application/problem+json`; the `X-Request-Id` header is present on each.

**422 Validation**:
```json
{ "type": ".../validation-failed", "title": "Validation failed", "status": 422,
  "detail": "1 field is invalid", "instance": "/v1/users",
  "errors": [{ "pointer": "#/email", "detail": "is required", "code": "required" }] }
```

**400 Malformed** (unparseable JSON, a bad path id, an undecodable cursor):
```json
{ "type": ".../malformed-request", "title": "Malformed request", "status": 400,
  "detail": "Path parameter 'id' is not a valid identifier", "instance": "/v1/users/abc" }
```

**401 Unauthenticated** — header `WWW-Authenticate: Bearer error="invalid_token"` (a key source that cannot be fetched is a 503, not a 401):
```json
{ "type": ".../unauthenticated", "title": "Unauthenticated", "status": 401,
  "detail": "The access token is expired", "instance": "/v1/users" }
```

**404 Not Found**: `{ "type": ".../not-found", "title": "Not found", "status": 404, "detail": "User '0192c8f7-...' not found", "instance": "/v1/users/0192c8f7-..." }` — the same body for an unknown route, with its own `detail`.

**409 Conflict**: `{ "type": ".../already-exists", "title": "Already exists", "status": 409, "detail": "Email already registered", "instance": "/v1/users" }`

**429 Rate Limited** — headers `Retry-After: 30`, `RateLimit: "default";r=0;t=30`:
```json
{ "type": ".../rate-limited", "title": "Too many requests", "status": 429,
  "detail": "Rate limit exceeded; retry after 30s", "instance": "/v1/users" }
```

**503 Unavailable** — a dependency is down, the deadline passed, or the instance is draining; header `Retry-After: 2`:
```json
{ "type": ".../unavailable", "title": "Service unavailable", "status": 503,
  "detail": "Temporarily unable to complete the request", "instance": "/v1/payments" }
```

**500 Internal** (title "Internal error"): `detail` is always the generic "An unexpected error occurred"; the cause goes to the log with the request id.

**A status outside the registry** (e.g. a library's 410): `{ "type": "about:blank", "title": "Gone", "status": 410, "instance": "..." }`.

---

## Pagination

### Cursor (default)

```http
GET /v1/posts?limit=10&cursor=djE6MDE5MmM4ZjctNGQ2Mi03Yzk4LWI1ZmQtM2UxYTJjOWQ4YjQw
→ 200 { "data": [...], "meta": { "limit": 10, "next_cursor": "djE6MDE5MmM4ZjctN...", "has_more": true } }

GET /v1/posts?limit=500
→ 200 { "data": [...], "meta": { "limit": 100, ... } }      # clamped, reported in meta

# last page
→ 200 { "data": [...], "meta": { "limit": 10, "next_cursor": null, "has_more": false } }
```

The cursor is opaque to clients. One that fails to decode → 400 `.../malformed-request`; one that decodes is only a position — the tenant filter still decides what is visible. `limit=0` or `limit=abc` → 422 with `errors[].parameter`; an unknown query parameter (`?sort=title` where no sort is offered) → 422 too.

### Offset

```http
GET /v1/audit-entries?page=3&limit=10
→ { "data": [...], "meta": { "page": 3, "limit": 10, "total": 156, "total_pages": 16 } }
```

---

## Conditional Requests (ETag)

**Read — cache validation:**

```http
GET /v1/users/0192c8f7-...
If-None-Match: "3"
→ 304 Not Modified
```

**Write — lost-update protection:**

```http
PATCH /v1/users/0192c8f7-...
If-Match: "3"
{ "name": "Ada Byron Lovelace" }
→ 200 OK, ETag: "4"

# Someone else updated it first:
→ 412 Precondition Failed
{ "type": ".../precondition-failed", "title": "Precondition failed", "status": 412,
  "detail": "The resource changed since ETag \"3\"; re-fetch and retry", "instance": "/v1/users/0192c8f7-..." }
```

Server-side the `version` column does the conditional write. The same conflict detected through a version field in the body (no `If-Match`) returns 409 `.../version-conflict`; through `If-Match` it returns 412 (RFC 9110). Where the arch doc makes `If-Match` mandatory, a missing header → 428 `.../precondition-required`.

---

## State Transitions

Use `POST /resources/{id}/{action}`, not PATCH with magic values.

```http
POST /v1/orders/0192c8fa-.../cancel
{ "reason": "Customer changed mind" }
→ 200 { "data": { "id": "0192c8fa-...", "status": "cancelled", "cancelled_at": "..." } }
```

Invalid transition → **409**:
```json
{ "type": ".../invalid-transition", "title": "Invalid transition", "status": 409,
  "detail": "Cannot cancel an order in status 'shipped'", "instance": "/v1/orders/0192c8fa-.../cancel" }
```

The adapter guards the write (`… WHERE id = $1 AND status IN ('pending','paid')`): 0 rows affected means another request moved it first — the same 409.

---

## File Upload

### Direct (small files)

```http
POST /v1/documents
Content-Type: multipart/form-data
file: <binary>, title: "Q4 Report"
→ 201 Created, Location: /v1/documents/0192c8fb-...
```

### Presigned URL (large files)

```http
POST /v1/uploads
{ "filename": "video.mp4", "content_type": "video/mp4", "size": 52428800 }
→ 201 Created, Location: /v1/uploads/0192c8fc-...
{ "data": { "id": "0192c8fc-...", "upload_url": "https://storage.../presigned?...", "expires_at": "..." } }

# Client uploads directly to upload_url, then:
POST /v1/uploads/0192c8fc-.../complete
→ 200 { "data": { "id": "0192c8fc-...", "status": "scanning" } }
```

The server picks the object key, signs a size condition, and on completion verifies size and magic bytes and quarantines until scanned (software-architecture `operational-patterns.md` § File Uploads, if available).

---

## Search

**GET** for simple queries:
```http
GET /v1/products?q=keyboard&category=electronics&min_price=50
```

**POST to a search resource** for complex queries — safe and retryable, documented as such (or HTTP `QUERY` where the whole toolchain supports it, see `api-design.md`):
```http
POST /v1/products/search
{ "query": "keyboard", "filters": { "category": ["electronics"], "price": { "min": 50 } },
  "sort": [{ "field": "relevance", "order": "desc" }], "limit": 20 }
→ 200 { "data": [...], "meta": { "limit": 20, "next_cursor": "...", "has_more": true, "facets": { "category": [...] } } }
```

---

## Relationship Expansion

```http
GET /v1/posts/0192c8fd-...?include=author,comments
→ { "data": { ..., "author": { "id": "...", "name": "Ada" }, "comments": [...] } }
```

One level deep; includable relations are an allowlist. Each include is loaded in one batched query, authorized per item, and capped (e.g. the first 20 comments plus a `comments_next_cursor`).

---

## Async Jobs

```http
POST /v1/report-jobs
Idempotency-Key: 3f9a...
{ "type": "monthly-sales", "month": "2026-09" }
→ 202 Accepted, Location: /v1/report-jobs/0192c8fe-...
{ "data": { "id": "0192c8fe-...", "status": "pending" } }

GET /v1/report-jobs/0192c8fe-...
→ 200 { "data": { "id": "0192c8fe-...", "status": "completed", "result": { "download_url": "..." } } }
```

The job row commits with the request; a worker claims it. A failed job reports `status: "failed"` with an embedded problem object.

---

## Bulk Operations

```http
POST /v1/users/batch
{ "items": [{ "name": "User 1", "email": "u1@example.com" }, ...] }      # max 100 items, else 413/422
→ 200 { "data": { "results": [{ "status": 201, "data": {...} }, { "status": 409, "error": {...} }],
         "summary": { "total": 2, "succeeded": 1, "failed": 1 } } }
```

Declare the semantics: **per-item** (above — 200, each item's outcome; a failed item's `error` is an embedded problem object) or **atomic** (one transaction; any failure → the whole request fails with one problem document listing items in `errors[]`).

---

## Server-Sent Events (SSE)

```http
GET /v1/events/stream
Accept: text/event-stream
Last-Event-ID: evt_000041                 # resume after a reconnect

→ 200 Content-Type: text/event-stream
id: evt_000042
event: order.updated
data: {"order_id": "0192c8fa-...", "status": "shipped"}

: heartbeat                               # comment line every ~15 s keeps proxies from closing the stream
```

Authenticate on connect (and end the stream when the token expires); ids are monotonic per stream so `Last-Event-ID` can replay the gap from a retained log.

---

## Webhooks

### Sending (Standard Webhooks shape)

```http
POST https://customer.example.com/webhooks
webhook-id: msg_0192c8ff-...
webhook-timestamp: 1791370000
webhook-signature: v1,K5oZfzN95Z9UVu1EsfQmfVNQhnkZ2pj9o9NDN/H/pI4= v1,Q2xhc3NpY...      # two during secret rotation
{ "type": "order.completed", "data": { "order_id": "0192c8fa-..." } }
```

- Signature: HMAC-SHA256 over `webhook-id + "." + webhook-timestamp + "." + raw_body`, base64; space-separated list so a rotated secret overlaps the old one.
- Deliver from the outbox with backoff and a dead-letter state; the same event keeps the same `webhook-id` on every retry.
- `webhook-id` is the receiver's idempotency key; payloads are versioned published contracts.

### Receiving

```
signed = webhook_id + "." + timestamp + "." + raw_body          # the raw bytes, before any JSON parsing
if not any(constant_time_equal(hmac(secret, signed), sig) for sig in signatures): reject 401   # with WWW-Authenticate naming the scheme
if abs(now() - timestamp) > 300: reject 401                     # both directions — future-dated too
insert inbox(webhook_id) in the same transaction as the effect, or record and process async if the effect is slow
duplicate webhook_id → 2xx, no re-processing
signed but schema-invalid payload → record (log) and 2xx: a permanent outcome; parse tolerantly (providers add fields)
```

### Registration

```http
POST /v1/webhooks
{ "url": "https://customer.example.com/webhooks", "events": ["order.completed", "user.created"] }
→ 201 Created, Location: /v1/webhooks/0192c900-...
{ "data": { "id": "0192c900-...", "secret": "whsec_..." } }        # shown once
```

Validate the URL as untrusted (SSRF): `https` only; resolve at send time and refuse private, loopback, link-local and metadata ranges; follow no redirects; cap response size and time.
