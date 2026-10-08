# API Design Conventions

REST conventions for new surfaces. An existing API's published conventions win (SKILL.md Step 1). Consult when defining routes, request/response types and errors.

## Table of Contents

1. [Resource Identification](#resource-identification)
2. [Naming](#naming)
3. [Response Format](#response-format)
4. [Problem Types](#problem-types)
5. [Status Codes](#status-codes)
6. [Pagination](#pagination)
7. [Filtering, Sorting, Field Selection](#filtering-sorting-field-selection)
8. [Updates and Deletes](#updates-and-deletes)
9. [Security](#security)
10. [Caching](#caching)
11. [Versioning and Deprecation](#versioning-and-deprecation)
12. [Checklist](#checklist)

---

## Resource Identification

1. List the nouns in the use cases and the domain model, not the tables. A schema is a naming hint only (`user_accounts` → `/v1/user-accounts`); responses shaped straight from columns break on every schema change.
2. Decide: first-class resource (own lifecycle) or property of another?
3. List the operations the workflows need — beyond CRUD.
4. Map relationships.

**Sub-resource vs flat route:**

| Signal | Sub-resource `/parents/{id}/children` | Flat `/children?parentId=X` |
|--------|--------------------------------------|-----------------------------|
| Child cannot exist without parent | Yes | — |
| Child belongs to exactly one parent | Either works | Either works |
| Child can belong to multiple parents | — | Yes |
| Need to list children across parents | — | Yes |
| Nesting would exceed 2 levels | — | Yes (flatten) |

Default to flat routes; use sub-resources only when parent-child ownership is fundamental.

**PATCH vs custom action:**

| Signal | PATCH | Custom action `POST /resources/{id}/{action}` |
|--------|-------|-----------------------------------------------|
| Changing a data field | Yes | — |
| Triggering a side effect | — | Yes |
| State machine transition | — | Yes |

---

## Naming

- **Paths**: plural nouns, lowercase, kebab-case (`/v1/line-items`); no verbs — methods express actions, custom actions excepted
- **`/v1/` prefix** on all new paths; at most 2 levels of nesting
- **JSON members**: `snake_case`, applied consistently

| Pattern | Example |
|---------|---------|
| Collection | `/v1/users` |
| Single | `/v1/users/{userId}` |
| Nested | `/v1/users/{userId}/orders` |
| Filtered | `/v1/orders?user_id=123` |
| Custom action | `POST /v1/orders/{orderId}/cancel` |
| Async job | `POST /v1/report-jobs` → 202 + `Location` |

**Schema naming:** `Create{Resource}`, `Update{Resource}` (write types exclude read-only `id`, `created_at`, `updated_at` and never accept owner, tenant or role), `{Resource}`, `Problem`.

---

## Response Format

**Single**: `{ "data": {...} }` — wrapped so clients handle single and collection responses alike.

**Collection**: `{ "data": [...], "meta": { "limit": 20, "next_cursor": "...", "has_more": true } }` — `next_cursor` is always present, `null` on the last page.

**Correlation**: `X-Request-Id` response header on every response (bodiless 204 / 304 included), never in success bodies; log it beside the W3C trace id (`traceparent`), as a separate field.

**Errors** (RFC 9457, `application/problem+json`):

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

`type` is an absolute URI from the API's problem registry (below), resolvable to human docs; `title` is fixed per type; `detail` explains this occurrence; `instance` is the request path without the query string. `errors` is an extension member: each item names its location with `pointer` (a JSON Pointer into the body, in URI-fragment form: `#/items/0/name`; `#` for the whole body) or `parameter` (a query or path parameter), plus a human `detail` and a stable machine `code`.

---

## Problem Types

One registry per API, base URI configured once (e.g. `https://api.example.com/problems/`). Clients branch on `type`, never on `detail`.

| Status | `type` slug | `title` | Raised for |
|---|---|---|---|
| 400 | `malformed-request` | Malformed request | unparseable JSON; a path id that cannot be an id; a cursor that fails to decode; a malformed, or required but missing, `Idempotency-Key` |
| 401 | `unauthenticated` | Unauthenticated | missing or invalid credentials — with `WWW-Authenticate` |
| 403 | `forbidden` | Forbidden | resource visible, action not permitted |
| 404 | `not-found` | Not found | missing, foreign, or unknown route |
| 405 | `method-not-allowed` | Method not allowed | with `Allow` |
| 406 | `not-acceptable` | Not acceptable | no acceptable representation — answered before the handler runs, never after a write |
| 409 | `already-exists` | Already exists | unique constraint |
| 409 | `invalid-transition` | Invalid transition | state machine refuses the action |
| 409 | `version-conflict` | Version conflict | the version changed between read and write without `If-Match` (a body version, or a lost race) |
| 409 | `idempotency-in-flight` | Request in progress | same key still running — with `Retry-After` |
| 412 | `precondition-failed` | Precondition failed | `If-Match` does not match the current version |
| 413 | `payload-too-large` | Payload too large | body over the route's limit |
| 415 | `unsupported-media-type` | Unsupported media type | body not `application/json` (or the route's declared type) |
| 422 | `validation-failed` | Validation failed | well-formed input failing validation, unknown members or query parameters included — with `errors[]` |
| 422 | `idempotency-key-mismatch` | Idempotency key mismatch | key reused with a different request |
| 428 | `precondition-required` | Precondition required | `If-Match` missing where the arch doc requires it |
| 429 | `rate-limited` | Too many requests | with `Retry-After` |
| 500 | `internal` | Internal error | anything unmapped — `detail` "An unexpected error occurred", cause logged with the request id |
| 503 | `unavailable` | Service unavailable | dependency down (a database, a key source), deadline exceeded, or draining — with `Retry-After` |

A status raised by the framework or a library takes its registry type when exactly one type has that status (e.g. 404 → `not-found`); otherwise — a 410, a 504, or a 409 / 422 that several types share — it keeps its code with `type: "about:blank"` and the HTTP status phrase as `title` (RFC 9457 § 4.2.1). Only protocol-level rejections before the application sees the request — malformed HTTP, a refused CORS preflight — are exempt from problem documents.

Add domain-specific slugs (e.g. `insufficient-funds`) under the same base; never reuse a slug for a different meaning.

---

## Status Codes

| Operation | Success | Typical errors |
|-----------|---------|----------------|
| POST create | 201 + `Location` | 400, 409, 413, 415, 422 |
| GET | 200 (+ `ETag`) | 304, 400, 404 |
| PATCH | 200 (+ `ETag`) | 404, 409, 412, 422 |
| DELETE | 204 | 404, 409 |
| Custom action | 200 | 404, 409 |
| Async | 202 + `Location` | 400, 422 |

Every route can also return 401, 403, 429, 500 and 503. 400 vs 422: 400 when the request cannot be read at all, 422 when it was read and its values are wrong.

---

## Pagination

**Cursor** (default): `?cursor=<opaque>&limit=20` → `meta: { limit, next_cursor, has_more }`. The cursor is an unpadded base64url token the client never parses; one that fails to decode (malformed, oversized, wrong version) → 400. `limit`: absent → 20; any integer above 100 → 100; below 1 or not an integer → 422.

**Offset** (admin views, small data): `?page=2&limit=20` → `meta: { page, limit, total, total_pages }`.

Mechanics and the precision rule: SKILL.md § Pagination.

---

## Filtering, Sorting, Field Selection

```
GET /v1/users?role=admin&status=active
GET /v1/users?sort=-created_at,name          # - = descending
GET /v1/users?fields=id,name,email
```

Allowlist every filter, sort and field name and map each to a known column: identifiers can't be bound parameters, so an unmapped name is an injection or a disclosure. Offer only sorts an index serves, and bind the cursor to the sort and filters it was issued for. Unknown names — and unknown query parameters — → 422 with `errors[].parameter`, so a client never mistakes an ignored filter for an applied one.

---

## Updates and Deletes

**PATCH** uses JSON Merge Patch (RFC 7396, `application/merge-patch+json` or plain JSON): an absent member stays unchanged, `null` clears it. The request type must distinguish absent from `null` — each stack guide shows how.

**`If-Match`** (RFC 9110 § 13.1.1): a list of strong entity tags or `*`; compare tags as exact strings; a weak or malformed tag never matches. Evaluate it after the resource is found and the actor may act on it (§ 13.2.1): a missing or foreign resource is 404 and a forbidden one 403, never 412.

**Soft delete** only where `docs/arch/database.md` chose it: `DELETE` → 204 and set `deleted_at`; reads filter deleted rows; uniqueness becomes a partial unique index (`WHERE deleted_at IS NULL`); erasure obligations still need a hard delete or anonymization path. `?include_deleted=true` is admin-only.

---

## Security

| Context | Pattern |
|---------|---------|
| User-facing | JWT bearer (ES256 / EdDSA; HS256 only when one service issues and verifies) or session cookie + CSRF defense |
| Public API | API keys or OAuth 2.0 |
| Service-to-service | mTLS or workload identity (OIDC tokens) |
| Webhooks and push queues | signatures with a timestamp window, or OIDC with an audience check |

Headers: `RateLimit-Policy` + `RateLimit` (structured fields from the IETF `draft-ietf-httpapi-ratelimit-headers` — e.g. `RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=42;t=30`; still an Internet-Draft as of 2026-10, and the separate `RateLimit-Limit` / `RateLimit-Remaining` fields of earlier drafts plus legacy `X-RateLimit-*` names remain common), `Retry-After`, `X-Request-Id`. `Idempotency-Key` for safe POST retries (SKILL.md § Write path).

Register the security scheme in the OpenAPI document and apply it per operation. Authentication proves identity; authorization is the use case's decision plus the repository's tenant filter (SKILL.md § Inbound adapters).

---

## Caching

`ETag` + `If-None-Match` → 304. Authenticated responses default to `Cache-Control: no-store` (or `private` with a short `max-age` when the arch doc allows); public responses set `Cache-Control: public` with `Vary` on every header that changes the representation. Shared caches never store a response keyed without the tenant.

---

## Versioning and Deprecation

`/v1/` prefix; bump only for breaking changes, which ship beside the old version until consumers move. Announce retirement with `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) plus a `Link` to the migration guide.

> **Trade-off**: a URI prefix is the simplest and most common option, but it versions the representation, not the resource. Header or media-type versioning, or a date-pinned version header (à la Stripe), keep URLs stable at the cost of tooling friction. Pick one per product.

**HTTP `QUERY`** (RFC 10008, June 2026) standardizes safe, idempotent queries with a body. Use it only where the router, the OpenAPI 3.2 generator and every intermediary support it; otherwise `POST /v1/<resource>/search`, documented as safe and retryable.

---

## Checklist

- [ ] Resources from use cases, not tables; plural nouns, no verbs except custom actions
- [ ] POST → 201 + `Location`, DELETE → 204, async → 202 + `Location`
- [ ] Collections use cursor pagination with `next_cursor` always present
- [ ] Every error is a problem document whose `type` comes from the registry
- [ ] Contended resources honor `If-Match` — stale writes return 412
- [ ] Write types exclude read-only fields and never accept owner, tenant or role
- [ ] Filters, sorts and fields allowlisted and index-backed
- [ ] Authenticated responses `no-store` by default
- [ ] No nesting beyond 2 levels
