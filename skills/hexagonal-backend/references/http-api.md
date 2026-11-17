# HTTP API conventions

Wire conventions for new HTTP surfaces, each with one worked exchange. These are the choices where two competent engineers would differ, so one has to be picked and then held. An existing API's published conventions win (`SKILL.md` § Read first), and the architecture doc's Published Contracts table says what is binding. The rules behind the conventions are in `SKILL.md`. Problem `type` URIs are abbreviated below as `…/<slug>`.

Standards status was checked on 2026-11-18: RFC 9457 (problem details), RFC 9110 (HTTP semantics), RFC 7396 (merge patch), RFC 9745 (`Deprecation`), RFC 8594 (`Sunset`) and RFC 10008 (the `QUERY` method, June 2026) are published. `Idempotency-Key` (draft 08) and the `RateLimit` fields (draft 11) are still Internet-Drafts.

## Contents

1. [Resources and names](#resources-and-names)
2. [Envelope and correlation](#envelope-and-correlation)
3. [Problem documents](#problem-documents)
4. [Problem types](#problem-types)
5. [Status mapping](#status-mapping)
6. [Pagination](#pagination)
7. [Filtering and sorting](#filtering-and-sorting)
8. [Updates and deletes](#updates-and-deletes)
9. [Idempotency-Key](#idempotency-key)
10. [State transitions](#state-transitions)
11. [Async jobs](#async-jobs)
12. [Bulk](#bulk)
13. [Uploads](#uploads)
14. [Search and expansion](#search-and-expansion)
15. [Server-sent events](#server-sent-events)
16. [Webhooks](#webhooks)
17. [Security, rate limits and caching](#security-rate-limits-and-caching)
18. [Versioning and deprecation](#versioning-and-deprecation)
19. [Checklist](#checklist)

## Resources and names

- **Resources come from the use cases and the model, not from the tables.** A response shaped straight from columns breaks on every schema change.
- **Paths**: plural nouns in kebab-case under a `/v1` prefix, at most two levels of nesting (`/v1/users/{user_id}/orders`). Nest only when the child cannot exist without the parent and is never listed across parents; otherwise a flat route with a filter (`/v1/orders?user_id=…`).
- **JSON members** are `snake_case`, everywhere.
- **A state change or a side effect is an action**, `POST /v1/orders/{id}/cancel`, never a `PATCH` that writes a magic value into `status`. `PATCH` changes data fields only.
- **Schemas**: `Create{Resource}`, `Update{Resource}`, `{Resource}`, `Problem`. Write types leave out read-only members (`id`, `created_at`, `updated_at`) and never accept owner, tenant or role.

## Envelope and correlation

A single resource is `{ "data": {…} }` and a collection is `{ "data": […], "meta": { "limit", "next_cursor", "has_more" } }`, so a client handles both alike and metadata has a place to grow. `next_cursor` is always present and `null` on the last page.

```http
POST /v1/users
Content-Type: application/json
{ "name": "Ada Lovelace", "email": "ada@example.com" }

→ 201 Created
Location: /v1/users/0192c8f7-4d62-7c98-b5fd-3e1a2c9d8b40
ETag: "1"
X-Request-Id: 7f3c2a9e
{ "data": { "id": "0192c8f7-4d62-7c98-b5fd-3e1a2c9d8b40", "name": "Ada Lovelace", "email": "ada@example.com", "created_at": "…" } }
```

- A create answers 201 with `Location`, a delete 204, accepted asynchronous work 202 with `Location`.
- **`X-Request-Id` is on every response**, the bodiless 204 and 304 and every error included. Echo an inbound value only when it is a bounded token (1 to 128 characters of `[A-Za-z0-9._:-]`), otherwise generate one. Log it beside the W3C trace id as a separate field, and never put it in a success body.
- A resource from another tenant answers the same 404 as a missing id. Existence is not disclosed.

## Problem documents

Every error is `application/problem+json` (RFC 9457):

```json
{
  "type": "https://api.example.com/problems/validation-failed",
  "title": "Validation failed",
  "status": 422,
  "detail": "2 fields are invalid",
  "instance": "/v1/users",
  "errors": [
    { "pointer": "#/email", "detail": "must be a valid email address", "code": "invalid_format" },
    { "parameter": "limit", "detail": "must be at least 1", "code": "too_small" }
  ]
}
```

- `type` is an absolute URI from the registry below, and clients branch on it, never on `detail`.
- `title` is fixed per type. `detail` explains this occurrence. `instance` is the request path without its query string.
- `errors` is an extension member for validation. Each item names its location with `pointer` (a JSON Pointer into the body in URI-fragment form: `#/items/0/name`, and `#` for the whole body) or `parameter` (a query or path parameter), plus a human `detail` and a stable machine `code`.
- A 500 always carries the generic `detail` "An unexpected error occurred". The cause goes to the log with the request id.

## Problem types

One registry per API, under a base URI configured once (for example `https://api.example.com/problems/`).

| Status | `type` slug | `title` | Raised for |
|---|---|---|---|
| 400 | `malformed-request` | Malformed request | unparseable JSON; a path id that cannot be an id; a cursor that fails to decode; a malformed, or required and missing, `Idempotency-Key` |
| 401 | `unauthenticated` | Unauthenticated | missing or invalid credentials, with `WWW-Authenticate` |
| 403 | `forbidden` | Forbidden | the resource is visible, the action is not permitted |
| 404 | `not-found` | Not found | missing, foreign, or an unknown route |
| 405 | `method-not-allowed` | Method not allowed | with `Allow` |
| 406 | `not-acceptable` | Not acceptable | no acceptable representation, answered before the handler runs and never after a write |
| 409 | `already-exists` | Already exists | a unique constraint |
| 409 | `invalid-transition` | Invalid transition | the state machine refuses the action |
| 409 | `version-conflict` | Version conflict | the version changed between read and write, without `If-Match` |
| 409 | `idempotency-in-flight` | Request in progress | the same key is still running, with `Retry-After` |
| 412 | `precondition-failed` | Precondition failed | `If-Match` does not match the current version |
| 413 | `payload-too-large` | Payload too large | a body over the route's limit |
| 415 | `unsupported-media-type` | Unsupported media type | a body that is not `application/json` or the route's declared type |
| 422 | `validation-failed` | Validation failed | well-formed input that fails validation, unknown members and query parameters included, with `errors[]` |
| 422 | `idempotency-key-mismatch` | Idempotency key mismatch | a key reused with a different request |
| 428 | `precondition-required` | Precondition required | `If-Match` missing where the architecture doc requires it |
| 429 | `rate-limited` | Too many requests | with `Retry-After` |
| 500 | `internal` | Internal error | anything unmapped |
| 503 | `unavailable` | Service unavailable | a dependency is down (a database, a key source), the deadline passed, or the instance is draining, with `Retry-After` |

Domain-specific slugs (`insufficient-funds`) go under the same base. A slug is never reused for a different meaning.

## Status mapping

| Operation | Success | Typical errors |
|---|---|---|
| POST create | 201 + `Location` | 400, 409, 413, 415, 422 |
| GET | 200 (+ `ETag`) | 304, 400, 404 |
| PATCH | 200 (+ `ETag`) | 404, 409, 412, 422 |
| DELETE | 204 | 404, 409 |
| Action | 200 | 404, 409 |
| Async | 202 + `Location` | 400, 422 |

Every route can also answer 401, 403, 429, 500 and 503.

- **400 or 422.** 400 when the request cannot be read at all: bad JSON syntax, a path id that is not an id, an undecodable cursor. 422 when it was read and its values are wrong: types, ranges, unknown members, missing members, domain validation.
- **403 or 404.** 404 when the actor may not know the resource exists (another tenant's, or hidden by policy). 403 when the actor can see it and may not perform this action.
- **A status raised by the framework or a library** takes its registry type when exactly one type has that status (a 404 becomes `not-found`). Otherwise (a 410, a 504, or a 409 or 422 that several types share) it keeps its code with `type: "about:blank"` and the HTTP status phrase as `title` (RFC 9457 § 4.2.1).
- **Exempt**: only protocol-level rejections that happen before the application sees the request, such as malformed HTTP or a refused CORS preflight.

## Pagination

```http
GET /v1/posts?limit=10&cursor=djE6MDE5MmM4ZjctNGQ2Mi03Yzk4LWI1ZmQtM2UxYTJjOWQ4YjQw
→ 200 { "data": […], "meta": { "limit": 10, "next_cursor": "djE6MDE5MmM4ZjctN…", "has_more": true } }

GET /v1/posts?limit=500
→ 200 { "data": […], "meta": { "limit": 100, … } }          # clamped, and reported

# last page
→ 200 { "data": […], "meta": { "limit": 10, "next_cursor": null, "has_more": false } }
```

- **`limit`**: absent means 20, any integer above 100 means 100 (`meta.limit` reports the value used), and below 1 or not an integer is a 422 naming `limit`.
- **The cursor** is an unpadded base64url token that the client never parses. One that fails to decode (malformed, oversized, a wrong version) is a 400. One that decodes is only a position: the tenant filter still decides what is visible.
- **Offset** (`?page=2&limit=20` with `meta: { page, limit, total, total_pages }`) only for admin views over small data, because offsets skip and repeat rows under concurrent writes and an exact total costs a full count.

The mechanics and the precision rule are in `SKILL.md` § Edge.

## Filtering and sorting

```
GET /v1/users?role=admin&status=active
GET /v1/users?sort=-created_at,name          # a leading minus is descending
GET /v1/users?fields=id,name,email
```

Every filter, sort and field name comes from an allow-list that maps it to a known column. An identifier cannot be a bound parameter, so an unmapped name is an injection or a disclosure. Offer only the sorts an index serves, and bind the cursor to the sort and filters it was issued for. An unknown name, or an unknown query parameter, is a 422 with `errors[].parameter`, so a client never mistakes an ignored filter for an applied one.

## Updates and deletes

**`PATCH` is JSON Merge Patch** (RFC 7396, as `application/merge-patch+json` or plain JSON): an absent member stays unchanged and `null` clears it. The request type must tell absent from `null`, and each stack guide shows how.

**`If-Match` protects a read-modify-write** (RFC 9110 § 13.1.1). It is a list of strong entity tags or `*`. Compare tags as exact strings; a weak or malformed tag never matches. Evaluate it after the resource was found and the actor may act on it (§ 13.2.1), so a missing or foreign resource is still 404 and a forbidden one 403, never 412.

```http
GET /v1/users/0192c8f7-…
→ 200 OK
ETag: "3"

PATCH /v1/users/0192c8f7-…
If-Match: "3"
{ "name": "Ada Byron Lovelace", "nickname": null }       # nickname cleared, absent members unchanged
→ 200 OK
ETag: "4"

# someone else updated it first:
→ 412 Precondition Failed
{ "type": "…/precondition-failed", "title": "Precondition failed", "status": 412,
  "detail": "The resource changed since ETag \"3\"; re-fetch and retry", "instance": "/v1/users/0192c8f7-…" }
```

The `version` column does the conditional write on the server. The same conflict detected through a version member in the body, with no `If-Match`, is a 409 `…/version-conflict`. Where the architecture doc makes `If-Match` mandatory, a missing header is a 428. For reads, `If-None-Match` with the current tag answers 304.

**Soft delete** only where `docs/arch/database.md` chose it: `DELETE` answers 204 and sets `deleted_at`, reads filter deleted rows, uniqueness becomes a partial unique index, and an erasure duty still needs a hard-delete or anonymization path.

## Idempotency-Key

```http
POST /v1/payments
Idempotency-Key: 8e1c6a0f-3b2d-4f7e-9a51-2c4d6e8f0a1b
{ "amount": 5000, "currency": "USD" }
→ 201 Created
Location: /v1/payments/0192c8f9-…
```

| A later request with the same key | Response |
|---|---|
| the same request (method, path with query, body), completed | the stored status, body and `Location`, `Content-Type`, `ETag`, optionally with `Idempotent-Replayed: true` |
| the first request is still running | **409** `…/idempotency-in-flight` + `Retry-After: 1` |
| a different body, path or method | **422** `…/idempotency-key-mismatch`: a client bug, not to be retried |
| a key over 255 characters or not visible ASCII, or required and missing | **400** `…/malformed-request` |

- A key is scoped to tenant and principal, one per intent, stable across that intent's retries.
- A completed 4xx that the body or the state decided (a 422 validation, a 409 already-exists) is replayed too.
- A status decided by headers outside the hash (415, 406, 412, 428) is never stored, or the corrected retry would replay the error.
- A 5xx or a crash releases the key, so the retry runs again.
- `Retry-After` on the 409 is the expected completion time, a second or two, not the remaining lease.

## State transitions

```http
POST /v1/orders/0192c8fa-…/cancel
{ "reason": "Customer changed mind" }
→ 200 { "data": { "id": "0192c8fa-…", "status": "cancelled", "cancelled_at": "…" } }

# from a state that does not allow it:
→ 409 Conflict
{ "type": "…/invalid-transition", "title": "Invalid transition", "status": 409,
  "detail": "Cannot cancel an order in status 'shipped'", "instance": "/v1/orders/0192c8fa-…/cancel" }
```

The adapter guards the write (`… WHERE id = $1 AND status IN ('pending', 'paid')`). Zero rows affected means another request moved it first, and that is the same 409.

## Async jobs

```http
POST /v1/report-jobs
Idempotency-Key: 3f9a…
{ "type": "monthly-sales", "month": "2026-09" }
→ 202 Accepted
Location: /v1/report-jobs/0192c8fe-…
{ "data": { "id": "0192c8fe-…", "status": "pending" } }

GET /v1/report-jobs/0192c8fe-…
→ 200 { "data": { "id": "0192c8fe-…", "status": "completed", "result": { "download_url": "…" } } }
```

The job row commits with the request, and a worker claims it. A failed job reports `status: "failed"` with an embedded problem object. Work a model or an agent performs for a caller takes this shape too: a job the caller polls, never a request held open.

## Bulk

```http
POST /v1/users/batch
{ "items": [{ "name": "User 1", "email": "u1@example.com" }, …] }       # at most 100 items
→ 200 { "data": { "results": [{ "status": 201, "data": {…} }, { "status": 409, "error": {…} }],
         "summary": { "total": 2, "succeeded": 1, "failed": 1 } } }
```

Declare the maximum and the semantics. **Per item** (above): 200 with each item's outcome, a failed item's `error` being an embedded problem object. **Atomic**: one transaction, and any failure fails the whole request with one problem document that lists the items in `errors[]`.

## Uploads

A small file may go straight through the API as `multipart/form-data` within the route's body limit. Anything larger goes directly to object storage:

```http
POST /v1/uploads
{ "filename": "video.mp4", "content_type": "video/mp4", "size": 52428800 }
→ 201 Created
Location: /v1/uploads/0192c8fc-…
{ "data": { "id": "0192c8fc-…", "upload_url": "https://storage.…/presigned?…", "expires_at": "…" } }

# the client uploads to upload_url, then:
POST /v1/uploads/0192c8fc-…/complete
→ 200 { "data": { "id": "0192c8fc-…", "status": "scanning" } }
```

The server chooses the object key and signs a size condition. On completion it verifies size and magic bytes and keeps the object quarantined until it is scanned (software-architecture `operational-patterns.md` § File Uploads, if available).

## Search and expansion

A simple search is a `GET` with query parameters. A complex one is a `POST` to a search resource, documented as safe and retryable:

```http
POST /v1/products/search
{ "query": "keyboard", "filters": { "category": ["electronics"], "price": { "min": 50 } },
  "sort": [{ "field": "relevance", "order": "desc" }], "limit": 20 }
→ 200 { "data": […], "meta": { "limit": 20, "next_cursor": "…", "has_more": true } }
```

The `QUERY` method (RFC 10008) standardizes exactly this, a safe and idempotent request with a body. Use it only where the router, the OpenAPI 3.2 generator and every intermediary on the path support it.

**Expansion** (`GET /v1/posts/{id}?include=author,comments`) is one level deep and comes from an allow-list. Each include loads in one batched query, is authorized per item and is capped, for example the first 20 comments plus a `comments_next_cursor`.

## Server-sent events

```http
GET /v1/events/stream
Accept: text/event-stream
Last-Event-ID: evt_000041                 # resume after a reconnect

→ 200 Content-Type: text/event-stream
id: evt_000042
event: order.updated
data: {"order_id": "0192c8fa-…", "status": "shipped"}

: heartbeat                               # a comment line every 15 s keeps proxies from closing the stream
```

Authenticate on connect, and end the stream when the token expires. Ids are monotonic per stream, so `Last-Event-ID` can replay the gap from a retained log. Nothing may depend on the stream surviving: the state it reports is durable elsewhere, and long work behind it is a job.

## Webhooks

**Sending**, in the Standard Webhooks shape:

```http
POST https://customer.example.com/webhooks
webhook-id: msg_0192c8ff-…
webhook-timestamp: 1791370000
webhook-signature: v1,K5oZfzN95Z9UVu1EsfQmfVNQhnkZ2pj9o9NDN/H/pI4= v1,Q2xhc3NpY…      # two entries during a secret rotation
{ "type": "order.completed", "data": { "order_id": "0192c8fa-…" } }
```

- The signature is HMAC-SHA256 over `webhook-id + "." + webhook-timestamp + "." + raw_body`, base64-encoded, as a space-separated list so a rotated secret overlaps the old one.
- Deliver from the outbox with backoff and a dead-letter state. The same event keeps the same `webhook-id` on every retry, and that id is the receiver's idempotency key.
- Payloads are versioned published contracts.

**Receiving**:

```
signed = webhook_id + "." + timestamp + "." + raw_body          # the raw bytes, before any JSON parsing
no signature matches under any configured secret (constant-time compare)  → 401, WWW-Authenticate naming the scheme
abs(now - timestamp) > 300 s, future-dated included                       → 401
insert inbox(webhook_id) in the same transaction as the effect            (or record and process later when the effect is slow)
duplicate webhook_id                                                      → 2xx, no second effect
signed, but the payload fails its schema                                  → record and 2xx: a permanent outcome
```

Parse a sender's payload tolerantly, because providers add fields. Answer 429 or 503 only for a transient failure, so the sender backs off and retries.

**Registration**:

```http
POST /v1/webhooks
{ "url": "https://customer.example.com/webhooks", "events": ["order.completed", "user.created"] }
→ 201 Created
Location: /v1/webhooks/0192c900-…
{ "data": { "id": "0192c900-…", "secret": "whsec_…" } }        # shown once
```

The URL is untrusted input (SSRF): `https` only, resolved at send time, private, loopback, link-local and metadata ranges refused, no redirects followed, response size and time capped.

## Security, rate limits and caching

| Caller | Scheme |
|---|---|
| A user | a JWT bearer (ES256 or EdDSA; HS256 only when one service both issues and verifies) or a session cookie with CSRF defense |
| A public API client | API keys or OAuth 2.0 |
| Another service, or an agent acting for a user | mTLS or workload identity (OIDC tokens), audience-checked; a token minted for another service is never accepted or passed on |
| Webhooks and push queues | a signature with a timestamp window, or OIDC with an audience check |

- Register the security scheme in the OpenAPI document and apply it per operation.
- **Rate limits** answer 429 with `Retry-After`. To expose quota, use the `RateLimit-Policy` and `RateLimit` structured fields (`RateLimit-Policy: "default";q=100;w=60`, `RateLimit: "default";r=42;t=30`). They are still an Internet-Draft, and the older `RateLimit-Limit` / `RateLimit-Remaining` fields and `X-RateLimit-*` names remain common in the wild.
- **CORS** comes from configured origins, never a wildcard with credentials, and exposes `Location`, `ETag`, `Retry-After` and `X-Request-Id`.
- **Caching.** An authenticated response defaults to `Cache-Control: no-store` (or `private` with a short `max-age` when the architecture doc allows). A public response sets `Cache-Control: public` and `Vary` on every header that changes the representation. A shared cache never stores a response keyed without the tenant.

## Versioning and deprecation

The `/v1` prefix changes only for a breaking change, which ships beside the old version until its consumers have moved. Announce a retirement with `Deprecation` (RFC 9745) and `Sunset` (RFC 8594), plus a `Link` to the migration guide. A URI prefix is the simplest option and versions the representation rather than the resource; a header or a date-pinned version keeps URLs stable at the cost of tooling friction. Pick one per product and record it with the published contract.

## Checklist

- [ ] Resources come from use cases; plural nouns; no verbs except actions; at most two levels of nesting
- [ ] Create answers 201 + `Location`, delete 204, async 202 + `Location`
- [ ] Collections page by cursor, with `next_cursor` always present
- [ ] Every error is a problem document whose `type` comes from the registry
- [ ] Contended resources honor `If-Match`, and a stale write answers 412
- [ ] Write types leave out read-only members and never accept owner, tenant or role
- [ ] Filters, sorts and fields are allow-listed and index-backed; unknown parameters are refused
- [ ] Authenticated responses are `no-store` by default; `X-Request-Id` is on every response
