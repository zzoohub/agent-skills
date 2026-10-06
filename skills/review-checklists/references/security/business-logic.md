# Business Logic Security

> OWASP: A06 (Insecure Design), A01 (Broken Access Control)

---

## Table of Contents

1. [Race Conditions](#race-conditions)
2. [Numeric Manipulation](#numeric-manipulation)
3. [State Machine Violations](#state-machine-violations)
4. [Discount & Coupon Abuse](#discount--coupon-abuse)
5. [Time-Based Attacks](#time-based-attacks)
6. [Account & Limit Abuse](#account--limit-abuse)
7. [Privilege Boundaries](#privilege-boundaries)
8. [Refund & Chargeback Abuse](#refund--chargeback-abuse)
9. [Export & Data Access Abuse](#export--data-access-abuse)


## Race Conditions

| Check | Why | CWE |
|-------|-----|-----|
| Financial operations use transactions + row-level locks | Double-spend, overdraft | CWE-362 |
| Inventory changes are atomic (SELECT FOR UPDATE) | Overselling | CWE-362 |
| Idempotency keys for all sensitive operations | Duplicate submissions | CWE-837 |
| Optimistic locking with version column where appropriate | Lost updates | CWE-362 |
| Distributed locks for multi-instance deployments | Cross-instance races | CWE-362 |
| Critical section identified and protected | TOCTOU vulnerabilities | CWE-367 |

**Patterns to catch:**
- Check-then-act without atomic operation: read balance → check sufficient → update
- Stock decrement computed in the app: read `qty`, check `> 0`, then `UPDATE stock SET qty = :newQty` (races; two buyers both pass the check). A single conditional `UPDATE stock SET qty = qty - 1 WHERE id = ? AND qty > 0` is atomic on its own (the row lock is implicit) — check the affected-row count, 0 = sold out
- Payment endpoint without idempotency key handling
- Concurrent request vulnerability in any state change (test: send 10 identical requests simultaneously)
- Redis `GET` then `SET` without `WATCH` or Lua script (non-atomic)
- File-based operations without file locking

> **Sibling lens:** the *accident*-driven versions of these flaws (client retries, crash mid-operation, replica lag — no attacker required) are owned by the correctness pass (`references/correctness.md`). Same mechanics, different threat model — when money or inventory moves, apply both.

---

## Numeric Manipulation

| Check | Why | CWE |
|-------|-----|-----|
| Negative values rejected where inappropriate | Credit instead of debit | CWE-839 |
| Integer overflow considered (especially in typed languages) | Wrap-around to small/negative | CWE-190 |
| Decimal/integer for money, never floating point | Precision loss ($0.1 + $0.2 ≠ $0.3) | CWE-681 |
| Quantity limits enforced (min and max bounds) | Extreme values | CWE-839 |
| Division by zero handled | Crash or unexpected behavior | CWE-369 |
| Currency conversion uses fixed-point arithmetic | Rounding exploitation | CWE-681 |

**Patterns to catch:**
- Quantity or amount accepted without sign check: `{ quantity: -5 }` → credit
- Price or total calculated with `float` / `double` / JavaScript `number`
- No upper bound on numeric inputs (quantity: 999999999)
- Multiplication without overflow check in Rust/Go/C
- Fractional quantity where only whole numbers make sense
- Percentage values not bounded to 0-100 (discount: 150%)
- Price of $0.00 or $0.01 accepted without validation

---

## State Machine Violations

| Check | Why | CWE |
|-------|-----|-----|
| Valid transitions enforced server-side (state machine pattern) | Skipping required steps | CWE-841 |
| Cannot skip required steps in multi-step flows | Payment bypass | CWE-841 |
| Cannot revisit completed states inappropriately | Double-claiming benefits | CWE-841 |
| State changes logged with before/after values | Audit trail | CWE-778 |
| Parallel state changes handled (e.g., simultaneous approval/rejection) | Inconsistent state | CWE-362 |

**Patterns to catch:**
- Direct status update endpoint without transition validation: `PATCH /order { status: "completed" }`
- Order marked completed without payment confirmation state
- Coupon/benefit re-applied after state regression
- No state transition history (only current state stored)
- Multi-step wizard that allows direct POST to final step
- Subscription downgrade that doesn't adjust current billing cycle
- Cancellation endpoint that doesn't check if already cancelled (double refund)

---

## Discount & Coupon Abuse

| Check | Why | CWE |
|-------|-----|-----|
| Single-use coupons tracked and enforced | Reuse attack | CWE-837 |
| Stacking rules enforced server-side | Over-discount (cart goes negative) | CWE-840 |
| Referral loops prevented (graph check, not just direct) | Self-referral abuse | CWE-840 |
| Discount calculated server-side only | Client-controlled discount | CWE-602 |
| Minimum order value checked after discount applied | Free item via discount | CWE-840 |
| Discount code generation uses cryptographic randomness | Code prediction | CWE-330 |

**Patterns to catch:**
- No check for coupon already used by this user/account
- Multiple discount codes applicable without stacking limit
- Same user as referrer and referee (same email, phone, device)
- Discount percentage from client input: `{ discount: 100 }`
- Coupon applied after price calculation (negative total possible)
- Referral bonus paid before referee completes qualifying action
- Bulk coupon generation with sequential/predictable codes

---

## Time-Based Attacks

| Check | Why | CWE |
|-------|-----|-----|
| Server time for all time-sensitive logic | Client clock manipulation | CWE-367 |
| Timezone handling consistent (UTC internally) | Off-by-hours errors | CWE-187 |
| Expiration checked server-side against server clock | Token/coupon validity bypass | CWE-613 |
| Time-limited offers use server-side countdown | Client-side timer manipulation | CWE-602 |
| Grace periods bounded and audited | Exploiting grace period extension | CWE-840 |

**Patterns to catch:**
- Timestamp from client request body used for business logic validation
- Expiration check comparing against client-provided `Date` header
- Time-limited sale price validated client-side only
- Trial period start date settable by client
- Timezone mismatch between server and database causing off-by-one-day errors
- Cron job race: action happens between midnight check and execution

---

## Account & Limit Abuse

| Check | Why | CWE |
|-------|-----|-----|
| Multi-account detection (device fingerprint, phone, payment method) | Bonus farming | CWE-799 |
| Resource limits per user enforced at creation, not just usage | Free tier abuse | CWE-770 |
| Velocity checks on sensitive operations | Automated abuse | CWE-799 |
| Email verification before account activation | Throwaway account farming | CWE-799 |
| Phone/identity verification for high-value operations | Sybil attacks | CWE-799 |

**Patterns to catch:**
- Signup bonus awarded without identity verification
- No rate limit on account creation endpoint
- Free tier limits checked only at action time, not resource creation
- No detection for same device/IP/payment method creating multiple accounts
- Referral program without minimum account age or activity requirement
- Trial reset by creating new account with alias email (`user+1@example.com`)

---

## Privilege Boundaries

| Check | Why | CWE |
|-------|-----|-----|
| Feature flags verified server-side on every request | Client flag manipulation | CWE-602 |
| Trial/premium boundaries enforced in backend | Feature theft | CWE-285 |
| Admin actions logged with full context and alerted | Abuse detection | CWE-778 |
| Impersonation properly restricted, scoped, and logged | Privilege abuse | CWE-269 |
| API rate limits differ by plan tier (enforced server-side) | Plan limit bypass | CWE-285 |

**Patterns to catch:**
- Feature availability sent in JWT without server-side verification per request
- Premium features with client-only check: `if (user.plan === 'pro')` in frontend only
- Admin impersonation without audit log or scope limits
- Support agent actions without per-action authorization
- Plan upgrade without payment verification (just API call)
- Feature flag value stored in localStorage or cookie

---

## Refund & Chargeback Abuse

| Check | Why | CWE |
|-------|-----|-----|
| Refund requires original order validation | Phantom refund | CWE-840 |
| Partial refund total cannot exceed original payment | Over-refund | CWE-840 |
| Digital goods access revoked upon refund | Consume-then-refund | CWE-840 |
| Refund velocity monitored per account | Serial refund abuse | CWE-799 |
| Refund-then-repurchase-at-discount prevented | Price arbitrage | CWE-840 |

**Patterns to catch:**
- Refund endpoint doesn't verify order belongs to requesting user
- Multiple partial refunds can exceed total order value
- Downloaded digital content remains accessible after refund
- No cooling-off period or limit on refund frequency
- Refund processed but inventory not re-added (or vice versa, creating ghost inventory)

---

## Export & Data Access Abuse

| Check | Why | CWE |
|-------|-----|-----|
| Export endpoints rate-limited and size-bounded | Data exfiltration via legitimate features | CWE-770 |
| Search results limited, no full-table dump via search | Scraping | CWE-770 |
| Bulk operations require additional authorization | Mass data access | CWE-285 |
| Export audit logged with row count and requester | Insider threat detection | CWE-778 |

**Patterns to catch:**
- CSV/PDF export of entire user database without pagination
- Search endpoint with wildcard that returns all records: `GET /api/users?search=*`
- No additional auth step for "export all data" functionality
- API allows `limit=999999` or `per_page=-1`
- GraphQL query returning all records via unbounded list queries
