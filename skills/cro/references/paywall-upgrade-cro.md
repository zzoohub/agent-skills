# Paywall and Upgrade CRO

In-app paywalls, upgrade screens, upsell modals, feature gates and trial-end screens. Tiers, prices, plan order and the recommended tier come from pricing (price book `biz/marketing/pricing.md` §4); the paywall doc (`biz/growth/paywall-pricing.md`) holds the gate, offered tiers and in-app offers; this file owns when the paywall appears and how it presents them. The paywall screen's spec → screen-design; consent, renewal and cancellation law by jurisdiction → churn-prevention (each via that capability, if available); the on-screen check below stays here.

## Placement and trial decisions

**Place the paywall by business model.** Consumer subscription apps: at the end of onboarding, since most trials start on install day (RevenueCat, State of Subscription Apps), then at natural triggers. B2B or product-led: after use; a limit on a feature the user already relies on beats a lock on one they've never seen. **Break when** the value can't be shown credibly before use.

**Card upfront vs no card** is a trial-model call that pricing owns (via that capability, if available); this file designs its test. Judge on paid conversions per signup-page visitor, plus refunds, chargebacks and month-2 retention; never on trial→paid, which a card requirement inflates by construction. Dropping the card also drops a fraud filter: name its replacement (one trial per device, verified email or phone; usage caps during the trial). **Break when** the trial is sales-assisted: judge it on pipeline.

## Leak signatures

- **Many views, few trial starts** → anxiety about the terms. Confirm: replays and a one-question poll. Show the charge date, amount and cancel path at the CTA.
- **Day-0 trial cancellations** → check whether cancellers keep using the trial. If they do, they're guarding against forgetting: promise and send a pre-charge reminder. If they stop, the first session delivered no value (`references/onboarding-cro.md`).
- **Upgrade clicks without completed payments** → the payment step (`references/checkout-cro.md`) or the app-store sheet. Confirm: drop between plan choice and payment.
- **Conversions up, refunds or chargebacks up** → not a win; the guardrail failed.
- **Prompts dismissed again and again** → wrong moment or frequency. Confirm: dismissals per user and later conversion. Cap per session; cool down for days after a dismissal.

## Judgment calls

- **Show what they'd get from their own usage**: the limit they hit, the work they'd keep. A generic feature list converts the curious, not the ready.
- **Present plans honestly**: the current plan marked, a recommended plan labeled as such, annual vs monthly with the real per-period price. Which tiers and prices exist stays with pricing.
- **Never put a critical flow** (saving work, exporting the user's own data) behind the paywall.
- **iOS web checkout**, where store rules allow it: judge net revenue per exposed user after fees, not conversion alone.

## On screen before the user agrees

Check every paywall and trial screen, test arms included: the price and billing period; when the first charge happens and its amount; that it renews until canceled; how to cancel; and a deliberate act to accept that reads as a commitment to pay (EU order buttons must say so). An app store's purchase sheet shows some of this; your screen must not contradict it. Sign-off: whoever owns legal or compliance, before launch and before any test that changes these terms.

## Never

Statutes: the copywriting capability's dark-pattern anti-catalog and churn-prevention's subscription compliance, if available.
- A hidden, tiny or delayed close.
- An undisclosed pre-selected plan or add-on.
