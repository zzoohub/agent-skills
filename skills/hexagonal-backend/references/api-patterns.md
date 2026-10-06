# API Patterns

HTTP request/response examples for common and advanced patterns.

## Table of Contents

1. [CRUD](#crud)
2. [Error Responses (RFC 9457)](#error-responses-rfc-9457)
3. [Pagination](#pagination)
4. [Conditional Request (ETag)](#conditional-request-etag)
5. [File Upload](#file-upload)
6. [State Transitions](#state-transitions)
7. [Search](#search)
8. [Relationship Expansion](#relationship-expansion)
9. [Async Operations](#async-operations)
10. [Bulk Operations](#bulk-operations)
11. [Server-Sent Events (SSE)](#server-sent-events-sse)
12. [Webhooks](#webhooks)

---

## CRUD

### Create (POST → 201)

```http
POST /v1/users
{ "name": "Ada Lovelace", "email": "ada@example.com" }

→ 201 Created, Location: /v1/users/usr_123
{ "data": { "id": "usr_123", "name": "Ada Lovelace", "email": "ada@example.com", "created_at": "..." } }
```

### Create with Idempotency Key

```http
POST /v1/payments
Idempotency-Key: txn_8a3b2c1d
{ "amount": 5000, "currency": "USD" }
```

Retry with same key → returns original response without duplicate.

### Read Single (GET → 200)

```http
GET /v1/users/usr_123
→ 200 OK, ETag: "9f62089e"
{ "data": { "id": "usr_123", "name": "Ada Lovelace", ... } }
```

### Read Collection (GET → 200)

```http
GET /v1/users?role=admin&limit=20
→ 200 OK
{ "data": [...], "meta": { "limit": 20, "next_cursor": "eyJ...", "has_more": true } }
```

### Update (PATCH → 200)

```http
PATCH /v1/users/usr_123
{ "name": "Ada Byron Lovelace" }
→ 200 OK
{ "data": { ..., "updated_at": "..." } }
```

### Delete (DELETE → 204)

```http
DELETE /v1/users/usr_123
→ 204 No Content
```

---

## Error Responses (RFC 9457)

All use `Content-Type: application/problem+json`.

**422 Validation**:
```json
{ "type": ".../validation-failed", "title": "Validation Failed", "status": 422,
  "errors": [{ "field": "email", "code": "required", "message": "Email is required" }] }
```

**404 Not Found**: `{ "type": ".../not-found", "status": 404, "detail": "User 'usr_999' not found" }`

**409 Conflict**: `{ "type": ".../duplicate", "status": 409, "detail": "Email already exists" }`

**429 Rate Limited**: `application/problem+json` body **plus** headers `Retry-After: 30`, `RateLimit: "default";r=0;t=30` (IETF ratelimit-headers draft structured field, alongside `RateLimit-Policy`; older `RateLimit-Remaining` / legacy `X-RateLimit-*` names still common; every error — including the limiter's 429 — is a problem document, not a bare `{statusCode, message}`):
```json
{ "type": ".../rate-limited", "title": "Too Many Requests", "status": 429,
  "detail": "Rate limit exceeded; retry after 30s" }
```

---

## Pagination

### Cursor (default)

```http
GET /v1/posts?limit=10&cursor=eyJpZCI6MTAwfQ==
→ { "data": [...], "meta": { "limit": 10, "next_cursor": "eyJ...", "has_more": true } }
```

### Offset

```http
GET /v1/posts?page=3&limit=10
→ { "data": [...], "meta": { "page": 3, "limit": 10, "total": 156, "total_pages": 16 } }
```

---

## Conditional Request (ETag)

**Read — cache validation:**

```http
GET /v1/users/usr_123
If-None-Match: "9f62089e"
→ 304 Not Modified
```

**Write — lost-update protection (optimistic concurrency):**

```http
PATCH /v1/users/usr_123
If-Match: "9f62089e"
{ "name": "Ada Byron Lovelace" }
→ 200 OK, ETag: "a1c30b7d"

# Someone else updated the resource first:
→ 412 Precondition Failed (application/problem+json)
{ "type": ".../version-conflict", "title": "Precondition Failed", "status": 412,
  "detail": "Resource changed since ETag \"9f62089e\" — re-fetch and retry" }
```

Server-side this is the `version` column doing the conditional write. The same conflict surfaced through an application-level version field (no ETag header) returns **409**; via `If-Match` it returns **412** (RFC 9110).

---

## File Upload

### Direct (small files)

```http
POST /v1/documents
Content-Type: multipart/form-data
file: <binary>, title: "Q4 Report"
→ 201 Created
{ "data": { "id": "doc_456", "url": "https://cdn.example.com/...", ... } }
```

### Presigned URL (large files)

```http
POST /v1/uploads
{ "filename": "video.mp4", "content_type": "video/mp4", "size": 52428800 }
→ 200 { "data": { "upload_id": "upl_789", "upload_url": "https://storage.../presigned?..." } }

# Client uploads directly to upload_url, then:
POST /v1/uploads/upl_789/complete
```

---

## State Transitions

Use `POST /resources/{id}/{action}`, not PATCH with magic values.

```http
POST /v1/orders/ord_123/cancel
{ "reason": "Customer changed mind" }
→ 200 { "data": { "status": "cancelled", "cancelled_at": "..." } }
```

Invalid transition → **409**:
```json
{ "type": ".../invalid-transition", "status": 409,
  "detail": "Cannot ship order in 'cancelled' state" }
```

---

## Search

**GET** for simple queries:
```http
GET /v1/products/search?q=keyboard&category=electronics&min_price=50
```

**POST** for complex queries (not creating a resource):
```http
POST /v1/products/search
{ "query": "keyboard", "filters": { "category": ["electronics"], "price": { "min": 50 } },
  "sort": [{ "field": "relevance", "order": "desc" }], "limit": 20 }
→ { "data": [...], "meta": { "total": 42, "facets": { "category": [...] } } }
```

---

## Relationship Expansion

```http
GET /v1/posts/post_123?include=author,comments
→ { "data": { ..., "author": { "id": "usr_456", "name": "Ada" }, "comments": [...] } }
```

One level deep. Keep includable relations explicit.

---

## Async Operations

```http
POST /v1/reports/generate
{ "type": "monthly-sales", "month": "2024-10" }
→ 202 Accepted, Location: /v1/jobs/job_456
{ "data": { "job_id": "job_456", "status": "pending" } }

GET /v1/jobs/job_456
→ { "data": { "status": "completed", "result": { "download_url": "..." } } }
```

---

## Bulk Operations

```http
POST /v1/users/batch
{ "items": [{ "name": "User 1", "email": "u1@example.com" }, ...] }
→ 200 { "data": { "results": [{ "status": 201, "data": {...} }, { "status": 409, "error": {...} }],
         "summary": { "total": 2, "succeeded": 1, "failed": 1 } } }
```

Use 200 (not 201/204) — each item may have a different outcome. Each failed item's `error` is an embedded RFC 9457 problem object (`type`/`title`/`status`/`detail`, minus the `application/problem+json` content-type since the envelope itself is `application/json`) so per-item failures reuse the same error taxonomy as top-level errors.

---

## Server-Sent Events (SSE)

```http
GET /v1/events/stream
Accept: text/event-stream

→ Content-Type: text/event-stream
event: order.updated
data: {"order_id": "ord_123", "status": "shipped"}
id: evt_001
```

---

## Webhooks

### Sending

```http
POST https://customer.example.com/webhooks
X-Webhook-Signature: sha256=a1b2c3...
X-Webhook-Timestamp: 1699900000
{ "event": "order.completed", "data": { "order_id": "ord_789" } }
```

### Verification

```
expected = HMAC-SHA256(secret, timestamp + "." + raw_body)
if not constant_time_equal(expected, signature): reject   # never plain ==/!= (timing leak)
if now() - timestamp > 300: reject (replay)
```

### Registration

```http
POST /v1/webhooks
{ "url": "https://...", "events": ["order.completed", "user.created"] }
→ 201 { "data": { "id": "wh_123", "secret": "whsec_..." } }
```
