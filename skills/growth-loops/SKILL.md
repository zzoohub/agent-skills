---
name: growth-loops
description: |
  Growth loop design — referral programs, viral loops, content loops, paid loops.
  Use when: designing a referral program, modeling viral coefficients (K factor),
  identifying acquisition loops, choosing loop type for a product, debugging a stalled loop,
  designing an invite flow or ambassador/affiliate program,
  or when user mentions "viral loop", "referral program", "refer a friend", "invite flow",
  "ambassador program", "affiliate program", "K factor", "growth loop", "viral coefficient",
  "amplification", "two-sided incentive", "compounding growth", "product-led growth", "PLG".
  Do NOT use for: page-level conversion optimization (use cro), the dollar amount of a
  referral reward (use pricing — this skill owns the incentive structure), or instrumented
  measurement of live loop performance (use product-analytics — this skill owns the K model).
---

# Growth Loops

A growth loop is a self-reinforcing system: input → action → output → re-entry, where each cycle's output feeds the next cycle of the same action. Loops *compound* (network effects, viral spread, content moats); funnels *deplete* (one-time visitors). Most durable growth comes from loops, not funnels.

For loop types, K factor math, the 5-stage design framework, amplification techniques, cycle time, anti-patterns, and output format, read `references/loops.md`.

## When to invoke

| Situation | Action |
|---|---|
| "Design a referral program" | Read `references/loops.md` → Loop type selection → 5-stage design |
| "Why isn't our viral loop working?" | Read `references/loops.md` → anti-patterns + cycle time diagnosis |
| "Calculate our K factor" | `references/loops.md` § K Factor |
| "Identify acquisition loops in our product" | `references/loops.md` § Loop Types |

## Boundary

- **Not CRO**: signup form conversion goes to `cro`. Loop design is about what triggers acquisition, not how an individual page converts.
- **Pricing handoff**: this skill owns the *structure* of a referral incentive (one-sided, two-sided, milestone, tiered) and its abuse guardrails. For the *dollar value* of a reward tied to subscription/usage pricing, consult `pricing`.
- **Analytics handoff**: this skill owns the K-factor *model* — the formula, the amplification math, and target-setting. `product-analytics` owns *instrumented measurement* of live K from event data. Design the loop and its targets here; measure the running loop there.

## Output

When this skill produces a referral or loop design, write it to the referral doc (default `biz/growth/referral-program.md`; caller may redirect the `biz/<area>/` root). If no file-write capability is present, return the design inline. Update an existing file in place rather than creating a duplicate.
