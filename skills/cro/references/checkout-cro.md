# Checkout CRO

Optimize checkout flows, cart experiences, and purchase completion for e-commerce and SaaS.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Checkout Flow Types](#checkout-flow-types)
3. [Cart Page Optimization](#cart-page-optimization)
4. [Checkout Form Optimization](#checkout-form-optimization)
5. [Payment Optimization](#payment-optimization)
6. [Before/After Example: E-commerce Checkout](#beforeafter-example-e-commerce-checkout)
7. [Mobile Checkout](#mobile-checkout)
8. [Abandonment Recovery](#abandonment-recovery)
9. [Benchmarks](#benchmarks)
10. [Key Metrics](#key-metrics)
11. [Experiment Ideas](#experiment-ideas)

---

## Core Principles

1. **Momentum Over Perfection** — The user decided to buy. Every screen, field, and decision slows that momentum. Remove anything that isn't legally or technically required.
2. **Transparency Builds Trust** — No surprise fees, no hidden costs. Show the total early and often.
3. **Recovery Over Prevention** — Some abandonment is inevitable. Build recovery paths (email, retargeting) alongside friction reduction.

---

## Checkout Flow Types

| Type | Best For | Key Consideration |
|------|----------|-------------------|
| Single-page checkout | Simple products, 1-2 items | Speed, but can feel dense |
| Multi-step checkout | Complex orders, B2B | Progress indicator essential |
| Guest checkout | First-time buyers | Account creation post-purchase |
| Express checkout | Returning customers, mobile | Apple Pay, Google Pay, Shop Pay |
| Embedded checkout | SaaS upgrades | Stay in-app, don't redirect |

---

## Cart Page Optimization

### Must-Haves
- Clear product summary (name, image, quantity, price)
- Easy quantity adjustment and removal
- Visible subtotal, updated in real-time
- Prominent "Proceed to Checkout" CTA
- Continue shopping link (secondary)

### Trust Signals at Cart
- Money-back guarantee
- Shipping/return policy summary
- Security badges near checkout CTA
- Payment method icons

### Cart Abandonment Reducers
- Persistent cart (survives session/device)
- Show savings ("You're saving $20")
- Urgency when genuine ("Only 3 left", "Sale ends in 2h")
- Free shipping threshold ("Add $15 more for free shipping")

---

## Checkout Form Optimization

### Field Priority
Essential: Email, Payment, Shipping address (physical goods)
Often needed: Billing address (if different), Phone (for delivery)
Deferrable: Account creation, Marketing opt-in, Survey questions

### Field-by-Field

| Field | Best Practice |
|-------|--------------|
| **Email** | First field. Enables abandonment recovery even if they leave. |
| **Shipping address** | Auto-complete (Google Places), auto-detect country, single address field with parsing |
| **Payment** | Stripe Elements or equivalent embedded form, show accepted methods, card icon updates as they type |
| **Phone** | Explain why ("For delivery updates only"), make optional if possible |
| **Billing address** | Default "Same as shipping", only show if unchecked |

**Accessibility (a real conversion segment):** keyboard-operable payment fields, sufficient CTA contrast (WCAG ~4.5:1 text, ~3:1 large/UI), a visible focus ring, and inline errors announced to screen readers (aria-live / role=alert). Inaccessible checkout silently loses conversions — and for consumer (B2C) e-commerce in the EU it's legally required since June 28, 2025 (European Accessibility Act; microenterprises providing services are exempt).

### Guest vs. Account
- Default to guest checkout. Always.
- Offer account creation post-purchase: "Save your info for faster checkout next time?"
- Never require account creation before payment
- If account required (SaaS), delay password to post-purchase

---

## Payment Optimization

### Payment Methods
- Credit/debit card (baseline)
- Digital wallets: Apple Pay, Google Pay, Shop Pay (directionally ~30-50% faster completion — validate against your own data)
- Buy Now Pay Later: Klarna, Affirm, Afterpay (directionally lifts AOV ~20-30% for $50+ purchases — validate against your own data)
- PayPal (preferred in some markets)

### Express Checkout
Place Apple Pay / Google Pay buttons above the traditional form. Users who can pay in one tap shouldn't need to scroll past 10 fields first.

### Pricing Display
- Show line items, tax, shipping before payment step
- No surprise fees at the last step (the #1 abandonment cause)
- If tax is calculated late, say "Tax calculated at next step"
- Show total prominently at every step

---

## Before/After Example: E-commerce Checkout

**Before (high friction):**
```
Step 1: Login or Create Account
  [Email] [Password] [Confirm Password]
  [First Name] [Last Name] [Phone]
  [Create Account]

Step 2: Shipping
  [Address Line 1] [Address Line 2]
  [City] [State] [Zip] [Country]

Step 3: Shipping Method
  ○ Standard (5-7 days) — $7.99
  ○ Express (2-3 days) — $14.99

Step 4: Payment
  [Card Number] [Exp] [CVV]
  [Billing Address — all fields again]

Step 5: Review & Place Order
```
Problems: Forced account creation. 5 steps. Billing address duplicated. No express payment. No order summary visible during checkout. Shipping costs hidden until step 3.

**After (optimized):**
```
[Apple Pay] [Google Pay] [Shop Pay]
─── or checkout with email ───

[Email]
Shipping
  [Address autocomplete _______________]
  [Apt/Suite (optional)]
  ○ Free standard (5-7 days)  ○ Express $9.99 (2-3 days)

Payment
  [Card ____] [MM/YY] [CVV]
  ☑ Billing same as shipping

┌─────────────────────────┐
│ Order Summary            │
│ Widget × 2      $49.98  │
│ Shipping         FREE   │
│ Tax              $4.12  │
│ Total           $54.10  │
└─────────────────────────┘
[Complete Purchase — $54.10]

🔒 Secure checkout · 30-day returns · Free shipping over $50
```
Why it works: Express payment at top for one-tap buyers. Single page with all information visible. Address autocomplete eliminates 4-5 fields. Order summary always visible. Total shown on button. Trust signals at point of commitment.

---

## Mobile Checkout

Mobile has 2-3x higher abandonment than desktop. Optimize aggressively:

- Express payment (Apple Pay, Google Pay) as primary option
- Large touch targets (48px+ buttons)
- Appropriate keyboard types per field
- Sticky order summary or collapsible at top
- Sticky CTA button at bottom
- Minimize typing (autocomplete, autofill, saved cards)
- Single column, generous spacing
- Page speed is part of this — slow LCP/INP on mobile directly drives abandonment (see page-cro.md "Performance / Core Web Vitals")

---

## Abandonment Recovery

### Email Recovery Sequence
| Timing | Message | Typical Recovery |
|--------|---------|-----------------|
| 1 hour | "You left something behind" + cart contents | 5-10% |
| 24 hours | Social proof + urgency if genuine | 3-5% |
| 72 hours | Incentive (discount, free shipping) | 2-4% |

### On-Site Recovery
- Exit-intent popup with incentive
- Persistent cart with notification badge
- "Complete your order" banner on return visit

### Recovery Best Practices
- Include product images in recovery emails
- Deep link back to pre-filled checkout
- Show the exact cart they left (don't make them rebuild)

---

## Benchmarks

| Metric | Typical | Good | Excellent |
|--------|---------|------|-----------|
| Cart → Checkout start | 40-60% | 60-75% | 75%+ |
| Checkout completion | 30-50% | 50-65% | 65%+ |
| Overall cart-to-purchase | 15-30% | 30-45% | 45%+ |
| Mobile checkout completion | 20-35% | 35-50% | 50%+ |
| Cart abandonment recovery (email) | 5-10% | 10-15% | 15%+ |

These figures are directional and vary by industry, market, and period — validate against your own data. Adding express payment (Apple Pay/Google Pay) typically lifts mobile checkout completion by 15-25% relative.

---

## Key Metrics

| Metric | Description |
|--------|-------------|
| Cart abandonment rate | % who add to cart but don't purchase |
| Checkout abandonment rate | % who start checkout but don't complete |
| Step drop-off | Which checkout step loses the most people |
| Payment failure rate | Failed transactions / attempts |
| Average order value | Revenue / completed orders |
| Time to complete | Seconds from checkout start to purchase |

---

## Experiment Ideas

### Flow & Layout
- Single-page vs. multi-step checkout
- Guest-first vs. login-first
- Express payment above vs. below traditional form
- Order summary sidebar vs. collapsible

### Fields & Friction
- Reduce to minimum fields
- Address autocomplete vs. manual entry
- "Same as shipping" default for billing
- Phone required vs. optional

### Payment & Pricing
- Add/test BNPL options (Klarna, Affirm)
- Free shipping threshold messaging
- Show savings prominently
- Test discount code field visibility (hidden by default reduces abandonment from "coupon hunting")

### Trust & Recovery
- Trust badges near payment vs. near CTA
- Exit-intent offer for abandoners
- Recovery email timing and incentive levels
