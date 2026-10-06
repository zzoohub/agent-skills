# Dunning Playbook

Complete payment recovery strategy for involuntary churn prevention.

## Table of Contents

1. [The Dunning Stack](#the-dunning-stack)
2. [Pre-Dunning (Prevent Failures)](#pre-dunning-prevent-failures)
3. [Smart Retry Logic](#smart-retry-logic)
4. [Dunning Email Sequence](#dunning-email-sequence)
5. [Recovery Benchmarks](#recovery-benchmarks)
6. [Chargeback / Dispute Risk](#chargeback--dispute-risk)
7. [Billing Provider Capabilities](#billing-provider-capabilities)
8. [Tool Integrations](#tool-integrations)

---

## The Dunning Stack

```
Pre-dunning → Smart retry → Dunning emails → Grace period → Hard cancel
```

Failed payments cause roughly 20-40% of all churn (industry estimates, Recurly/Zuora) but are the most recoverable.

---

## Pre-Dunning (Prevent Failures)

- **Card expiry alerts**: Email 30, 15, and 7 days before card expires
- **Backup payment method**: Prompt for a second payment method at signup
- **Network tokens** (Visa Token Service, Mastercard MDES, Amex tokenization): the network keeps the token's underlying card-on-file current when the issuer reissues or re-numbers a card (new PAN/expiry) — covering expired, reissued, AND lost/stolen-then-reissued cards, so stored credentials self-heal with no customer action. Network tokens **complement, they do NOT replace,** the older Account Updater batch programs (Visa VAU / Mastercard ABU): issuer/processor participation in token programs is still incomplete, and you need an up-to-date underlying PAN to fall back to — mature billing stacks run **both**. Stripe requests network tokens automatically for Stripe Payments accounts (out of the box); Adyen, Braintree, and Checkout.com also provision tokens for stored cards. Typical impact: ~2-7 percentage-point CNP authorization-rate lift (Visa cites ~4.6%, Mastercard ~2.1%) and a meaningful cut in card-credential-staleness declines. (Does not recover a permanently closed account with no replacement card.)
- **Pre-billing notification**: Email 3-5 days before charge for annual plans

---

## Smart Retry Logic

Not all failures are the same:

| Decline Type | Examples | Retry Strategy |
|-------------|----------|----------------|
| Soft decline (temporary) | Insufficient funds, processor timeout | ML-driven retry (Stripe Smart Retries, Adyen Auto Rescue) or static 3-5 retries over 7-10 days |
| Hard decline (permanent) | Account closed, card reported lost/stolen with no reissue | Don't retry the failed card — request a new card (a *reissued* card is auto-followed by network tokens / Account Updater) |
| Authentication required (SCA) | 3D Secure 2 challenge required | Send customer to update payment via authenticated flow — automatic retries fail without consumer challenge |

### Retry Timing — Prefer ML over Static Schedule

Static schedule (**soft declines only** — hard declines skip retries and go straight to a card-update request):
- Retry 1: 24 hours after failure (day 1)
- Retry 2: day 3
- Retry 3: day 5
- Retry 4: day 7 (with dunning email escalation)
- Grace period through day 10, then hard cancel with reactivation path

The terminal hard-cancel (day 10) lands **after** the final dunning email (day 10), so the retry track and the email track below stay on one clock. **Trigger dunning emails off retry/billing-state events** (e.g., "retry 3 failed", "entering grace", "grace expired → cancel"), not a fixed calendar, so the two never drift.

**ML-driven retry (preferred for >$10k MRR):** Stripe Smart Retries (within Stripe Billing; Stripe's recommended default policy is 8 tries within 2 weeks, configurable from 1 week to 2 months), Stripe Authorization Boost (across Stripe, which includes Adaptive Acceptance), Adyen Auto Rescue (part of RevenueAccelerate), or churn-recovery tools (Churnkey, Baremetrics Recover, Stunning) pick retry timing per card / per issuer / per failure code. Lifts recovery 10-30% over static schedules in industry benchmarks. **The day-10 clock above is for the static schedule.** With ML retry, set the grace period and hard cancel to the end of the configured retry window (e.g. day 14 on Stripe's default) and stretch the email track to match — never hard-cancel while scheduled retries are still pending.

### SCA / 3DS notes (EU enforced end-2020 through 2021, phased by country; UK fully enforced from 14 March 2022)

> Not legal/payments advice — verify current requirements with your billing provider and against current law per region.

- Failed retries on SCA-required transactions don't recover without explicit consumer authentication
- Bring the customer back **on-session** to an authenticated card-update flow — Stripe's Payment Element / Checkout render and complete the 3DS challenge automatically once the customer is present (when integrated via Setup/Payment Intents), but the off-session → on-session hand-off (detecting `requires_payment_method` / authentication-required, then notifying and routing the customer back) is merchant integration work, not automatic
- Excluding low-value or recurring exemptions is provider-specific — verify with your billing provider

---

## Dunning Email Sequence

This email track shares the same day-0 to day-10 clock as the retry/grace schedule in § Smart Retry Logic above — both are triggered off billing-state events (not the calendar), so the two tracks never drift.

| Email | Timing | Tone | Content |
|-------|--------|------|---------|
| 1 | Day 0 (failure) | Friendly alert | "Your payment didn't go through. Update your card." |
| 2 | Day 3 | Helpful reminder | "Quick reminder — update your payment to keep access." |
| 3 | Day 7 | Urgency | "Your account will be paused in 3 days. Update now." |
| 4 | Day 10 | Final warning | "Last chance to keep your account active." |

(Timings track the retry/grace schedule above — Email 4 lands the same day grace expires, just before hard cancel.)

### Email Best Practices
- Direct link to payment update page (no login required if possible)
- Show what they'll lose (their data, their team's access)
- Don't blame ("your payment failed" not "you failed to pay")
- Include support contact for help
- Plain text performs better than designed emails for dunning

---

## Recovery Benchmarks

| Metric | Poor | Average | Good |
|--------|------|---------|------|
| Soft decline recovery | <40% | 50-60% | 70%+ |
| Hard decline recovery\* | <10% | 20-30% | 40%+ |
| Overall payment recovery | <30% | 40-50% | 60%+ |
| Pre-dunning prevention | None | 10-15% | 20-30% |
| Dispute / chargeback rate (guardrail) | above network threshold | — | well under threshold |

\* Hard-decline recovery comes from card-update prompts and network token / Account Updater refreshes (see Pre-Dunning), **not** from retrying the failed card — retrying hard declines wastes retry budget and inflates disputes. Tune recovery against the dispute-rate guardrail, not gross recovery alone.

---

## Chargeback / Dispute Risk

Recovery tactics optimize gross revenue, but retry aggressiveness directly drives cardholder disputes:

- Retrying unfamiliar or disputed charges (and retrying hard declines) raises chargebacks
- Excessive dispute rates trigger card-network monitoring programs (Visa VDMP, Mastercard Excessive Chargeback) that carry fines and merchant-account jeopardy
- Keep dispute rate well under the network threshold (commonly ~0.65-0.9% depending on program — verify current values with your processor)
- Track dispute rate as a **guardrail** alongside recovery rate; tune retry cadence against disputes, not just gross recovery

---

## Billing Provider Capabilities

| Provider | Smart Retries | Dunning Emails | Card Updater |
|----------|:------------:|:--------------:|:------------:|
| **Stripe** | Built-in (Smart Retries) | Built-in | Automatic |
| **Chargebee** | Built-in | Built-in | Via gateway |
| **Paddle** | Built-in (Paddle Retain — algorithmic "Tactical Retries") | Built-in (Paddle Retain — email + SMS + in-app) | Managed (MoR) |
| **Recurly** | Built-in | Built-in | Built-in |
| **Braintree** | Manual config | Manual | Via gateway |

Paddle Retain (formerly ProfitWell Retain, acquired by Paddle in 2022) is Paddle's named, algorithm-driven recovery product. Because Paddle is the merchant of record, it owns the payment relationship and card-on-file on the seller's behalf — which is why card updating is "Managed" rather than gateway-dependent.

---

## Tool Integrations

| Tool | Use For |
|------|---------|
| Stripe | Subscription management, dunning config, payment retries |
| Customer.io | Dunning email sequences, retention campaigns |
| Churnkey | Full cancel flow + dunning, AI-powered adaptive offers |
| Baremetrics Recover | Failed-payment / dunning recovery (add-on to Baremetrics analytics) |
| ProsperStack | Cancel flows with analytics, Stripe/Chargebee integration |
| Raaft | Simple cancel flow builder |
