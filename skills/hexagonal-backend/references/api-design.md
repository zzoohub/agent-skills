# API Design Conventions

Reference for REST API endpoint design. Consult when defining routes, request/response types, and error handling.

## Table of Contents

1. [Resource Identification](#resource-identification)
2. [Naming](#naming)
3. [Response Format](#response-format)
4. [Pagination](#pagination)
5. [Filtering, Sorting, Field Selection](#filtering-sorting-field-selection)
6. [Soft Delete](#soft-delete)
7. [Security](#security)
8. [Caching](#caching)
9. [Versioning](#versioning)
10. [Checklist](#checklist)

---

## Resource Identification

1. List nouns from PRD, database schema, or requirements
2. Decide: first-class resource (own lifecycle) or property (part of another)?
3. List operations needed — think beyond CRUD to real workflows
4. Map relationships

**From DB schema**: `snake_case` → `kebab-case` (`user_accounts` → `/v1/user-accounts`)

**Sub-resource vs flat route:**

| Signal | Sub-resource `/parents/{id}/children` | Flat `/children?parentId=X` |
|--------|--------------------------------------|-----------------------------|
| Child cannot exist without parent | Yes | — |
| Child belongs to exactly one parent | Either works | Either works |
| Child can belong to multiple parents | — | Yes |
| Need to list children across parents | — | Yes |
| Nesting would exceed 2 levels | — | Yes (flatten) |

Default to flat routes. Use sub-resources only when parent-child ownership is fundamental.

**PATCH vs custom action:**

| Signal | PATCH | Custom action `POST /resources/{id}/{action}` |
|--------|-------|-----------------------------------------------|
| Changing a data field | Yes | — |
| Triggering a side effect | — | Yes |
| State machine transition | — | Yes |

---

## Naming

- **Paths**: Plural nouns, lowercase, kebab-case (`/v1/line-items`)
- **No verbs in paths** — HTTP methods express actions
- **`/v1/` prefix** on all paths
- **Max 2 levels** of nesting

| Pattern | Example |
|---------|---------|
| Collection | `/v1/users` |
| Single | `/v1/users/{userId}` |
| Nested | `/v1/users/{userId}/orders` |
| Filtered | `/v1/orders?userId=123` |
| Custom action | `POST /v1/orders/{orderId}/cancel` |

**Schema naming:**

| Purpose | Pattern | Example |
|---------|---------|---------|
| Create request | `Create{Resource}` | `CreateUser` |
| Update request | `Update{Resource}` | `UpdateUser` |
| Full resource | `{Resource}` | `User` |
| Error | `ProblemDetail` | RFC 9457 |

---

## Response Format

**Single**: `{ "data": {...} }` — the resource is always wrapped in `data` so clients handle single and collection responses uniformly (`resp.data`).

**Collection**: `{ "data": [...], "meta": { "limit": 20, "next_cursor": "...", "has_more": true } }`

**Correlation ID**: returned in the `X-Request-Id` response header (and propagated via `traceparent`), **not** in the body — so it is present on bodiless responses (204/304) and on every error. Echo an inbound `X-Request-Id` if present, otherwise generate one.

**Errors** (RFC 9457, `application/problem+json`):

```json
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "Email is required",
  "instance": "/v1/users",
  "errors": [{ "field": "email", "code": "required", "message": "Email is required" }]
}
```

`errors` is an RFC 9457 **extension** member (the RFC defines only `type`/`title`/`status`/`detail`/`instance`); use it for field-level validation detail. `type` may be a relative URI or `about:blank`.

**Status codes:**

| Operation | Success | Common errors |
|-----------|---------|---------------|
| POST create | 201 + Location | 409, 422 |
| GET | 200 | 404 |
| PATCH | 200 | 404, 422 |
| DELETE | 204 | 404 |
| Custom action | 200 | 409 |
| Async | 202 + Location | |

---

## Pagination

**Cursor** (default): `?cursor=X&limit=20` → meta: `{ limit, next_cursor, has_more }`

**Offset** (admin panels, small datasets): `?page=2&limit=20` → meta: `{ page, limit, total, total_pages }`

---

## Filtering, Sorting, Field Selection

```
GET /v1/users?role=admin&status=active
GET /v1/users?sort=-created_at,name          # - = descending
GET /v1/users?fields=id,name,email
```

---

## Soft Delete

DELETE → 204, mark `deleted_at` internally. Filter deleted by default. `?include_deleted=true` for admin.

---

## Security

| Context | Pattern |
|---------|---------|
| User-facing | JWT Bearer (ES256/EdDSA) |
| Public API | API keys, OAuth 2.0 |
| Service-to-service | mTLS |
| Webhooks | HMAC-SHA256 |

Headers: `RateLimit-Policy` + `RateLimit` (structured fields from the IETF `draft-ietf-httpapi-ratelimit-headers` — e.g. `RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=42;t=30`; still an Internet-Draft as of 2026-10, and the separate `RateLimit-Limit`/`RateLimit-Remaining` fields of earlier drafts plus legacy `X-RateLimit-*` names remain common in the wild), `Retry-After`, `X-Request-Id` (correlation)

`Idempotency-Key` for safe POST retries.

> **JWT signing**: HS256 (symmetric) is fine for a single service that both issues and verifies tokens. Prefer asymmetric **ES256/EdDSA** once *multiple* services verify (only the issuer holds the private key; verifiers hold the public key/JWKS). Register the bearer scheme in the OpenAPI doc and apply it to protected operations either way.

> **Authorization ≠ authentication**: proving identity (a valid JWT) is not enough. Add a resource-ownership / policy check (a policy port) before returning or mutating a resource, or `GET /v1/{resource}/{id}` is an IDOR.

---

## Caching

`ETag` + `If-None-Match` → 304. `Cache-Control: public/private/no-store`. `Vary` for cache key variation.

---

## Versioning

`/v1/` prefix. Bump only for breaking changes. `Sunset` header for deprecation.

> **Trade-off**: a URI prefix (`/v1/`) is the simplest and most common option, but it versions the *representation*, not the resource. Header / media-type versioning (`Accept: application/vnd.api+json;version=1`) or a date-pinned version header (à la Stripe's `Stripe-Version`) keep URLs stable at the cost of tooling friction. Pick one per product; this skill standardizes on `/v1/` for simplicity. Apply it consistently — mount routes under exactly `/v1/...` (no extra `/api`, no missing prefix).

---

## Checklist

- [ ] Plural nouns, no verbs in paths
- [ ] POST → 201, DELETE → 204, async → 202
- [ ] Collections have cursor pagination
- [ ] Errors use RFC 9457 with `application/problem+json`
- [ ] Mutable resources honor `If-Match`/ETag — stale writes return 412 (or 409 via a version field)
- [ ] Create/Update types exclude readOnly fields (id, created_at, updated_at)
- [ ] Custom actions use `POST /resources/{id}/{verb}`
- [ ] No nesting beyond 2 levels
- [ ] If phase-tagged schema exists, implement Phase 1 endpoints only
