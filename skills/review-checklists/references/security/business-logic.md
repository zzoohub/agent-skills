# Business Logic (Attacker View)

> OWASP: A06 Insecure Design, A01 Broken Access Control. Method, severity, the output contract and the both-views rule live in SKILL.md.

The **attacker view**: the mechanics of `references/correctness.md` (the accident view), driven on purpose.

## Race Conditions

A race is a finding only where an invariant breaks to the attacker's benefit: balance, stock, a single-use grant, a limit. Name the two requests that collide.

**Finding when:**
- Check-then-act on a shared value with no atomic guard: read balance → check sufficient → decrement, in separate statements (CWE-367). An attacker fires concurrent requests to pass the check twice (probe: *send 10 identical requests simultaneously*).
- Stock or quota decremented in app code: read `qty`, check `> 0`, then `UPDATE … SET qty = :new`. Two buyers both pass.
- A non-atomic cross-key sequence: Redis `GET` then `SET` without `WATCH` or a Lua script; a file operation with no lock.

**Not a finding:** a conditional `UPDATE … WHERE <predicate>` that branches on the affected-row count, or a unique constraint carrying the invariant. Fix a real race with the guard its shape needs (`correctness.md`, Concurrency & Races), never an in-process lock.

## Numeric Manipulation

**Finding when:**
- A signed amount or quantity accepted where only positive makes sense: `{ quantity: -5 }` credits instead of debits (CWE-839).
- No upper bound on a quantity or amount that drives cost or payout (CWE-1284); a percentage not clamped to 0–100 (`discount: 150`).
- Integer overflow in a typed language on a value an attacker sets (CWE-190).
- A price, total or discount computed from client-supplied values rather than recomputed server-side (CWE-602).

**Not a finding:** client-side bounds the server enforces again. Money as float is an accident-view precision defect: `correctness.md` (CWE-1339).

## State Machine Violations

**Finding when:** a status or step can be set out of order because transitions aren't enforced server-side (CWE-841): `PATCH /order { status: "completed" }` with no payment-confirmed precondition; a multi-step flow that accepts a direct POST to the final step; a completed benefit re-claimed after a state regression; a cancel or refund endpoint that doesn't check "already cancelled" (double refund); an approval (a manager sign-off, an accepted quote, a confirmed payout) not bound to the exact amount, recipient and content it approved, so they change between approval and execution.

**Not a finding:** a transition already gated server-side (an allowed-transitions check, or a conditional `UPDATE … WHERE status = <expected>`).

## Discount & Coupon Abuse

**Finding when:** a single-use coupon or one-time benefit isn't claimed atomically before the effect, so it reuses under concurrency (CWE-837); stacking has no server-side limit (the cart goes negative); a discount percentage or code comes from client input; the minimum-order check runs before the discount, letting a free item through; codes are sequential or predictable (CWE-340).

**Not a finding:** a benefit claimed by a unique constraint or conditional update before it is granted.

## Refund & Chargeback Abuse

**Finding when:** a refund doesn't verify the order belongs to the requester (CWE-639); partial refunds sum past the original payment because each is validated alone, with no running total (CWE-1284); digital access isn't revoked on refund; a refund adjusts money but not inventory, or the reverse, creating a ghost.

**Not a finding:** refunds bounded against the net already refunded, with ownership checked.

## Account & Limit Abuse

**Finding when:** a per-user or per-tenant resource limit is enforced only at *use* time, not at *creation*, so it is bypassable; a one-time grant (signup bonus, referral payout) is claimable more than once by the same account (CWE-837).

**Not a finding:** fraud economics. Multi-accounting, referral rings and refund-velocity thresholds are product decisions: raise **one** Unconfirmed item only when the diff adds a cash-value incentive one person can farm with new accounts, and name the fact that would settle it. Don't demand device fingerprinting or identity verification.

## Server-authoritative time & privilege

**Finding when:** time-sensitive logic trusts a client-supplied timestamp or expiry (trial start, offer window, token validity) instead of the server clock; a feature flag or plan tier is trusted from a client-held value (JWT claim, localStorage, request body) with no per-request server check; impersonation or support actions are unscoped, or unlogged where an audit facility exists (`error-logging.md`). Time-zone and calendar *correctness* (DST, month arithmetic) is an accident-view concern: `correctness.md`.
