# Dunning Playbook

Read when designing or reviewing failed-payment recovery or billing-event notices (card expiry, renewal). Notice windows: `compliance.md`; the copywriting capability, if available, writes trial-end and price-change notices inside them. Write the result to `biz/growth/dunning.md` (default; caller may redirect), ≤700 words plus the paste-ready notices, sections a menu: what each tool already does · do-now steps (precondition, risk, rollback) · decline routing · the clock · state × recipients × channel × content · metrics.

## Inventory and trace

List what each tool already does before designing anything:
- **Billing provider:** adaptive retries, card updater, network tokens, a hosted payment-update or invoice page, its own dunning emails, the end-of-retry action (cancel, mark unpaid, pause, suspend), exposed decline and advice codes, portal retention offers.
- **Messaging tool:** which billing events start journeys; native waits, branches, exit conditions (exit when the invoice is paid), suppression.
- **CRM, support, in-app:** tasks, banners and access rules keyed to billing status.

No-build first: switch on missing provider features, point every notice at the hosted page, let native waits and exits run the sequence. Build only gaps, by recovered MRR per effort-week; a scheduled job or custom update link needs a requirement the native version cannot meet.

**Trace every change first:** list what fires on the events it changes and fix those; report it as a do-now step with precondition, risk and rollback. Common multipliers:
- More retries mean more `payment failed` events, and a journey keyed to that event sends once per attempt: key notices to deduplicated state transitions (first failure, final attempt scheduled, suspended, recovered).
- Provider emails switched on beside a messaging journey send twice: one sender per notice.
- A new end-of-retry status changes what deprovisioning, win-back, the CRM and revenue reports see.

When a merchant of record or an app store bills, configure theirs (§ App store and merchant of record).

## Pre-dunning

- **Tokens and updater:** run both; neither saves a closed account with no replacement card.
- **Expiry alerts:** lead time is what the payer needs to act: days for a consumer, weeks for a company card behind finance or an approval. Default: email ~30 and ~7 days before the first charge the card cannot cover, plus an in-app banner for admins; skip cards the updater has refreshed. Never suppress alerts to keep forgetful subscribers billing: that revenue returns as refunds, disputes and complaints.
- **Before large charges:** annual renewals get the notice inside the `compliance.md` window plus a heads-up ~3-7 days before the charge (amount, date, card brand and last four, how to update or cancel); where the processor supports it, a zero-amount card check 2-4 weeks before, a failure opening the update flow.
- **Strong customer authentication** (EU, UK): authenticate the mandate at signup so renewals run as merchant-initiated payments.
- **Backup method:** offer one in billing settings and at the first failure, not at signup.

## Decline routing

Route on the decline code and the network's advice code:

| Response | Route |
|---|---|
| Revocation or stop-payment, checked first: Mastercard advice code 21, Visa R0, R1 or R3, ACH R07 or R08 | Self-serve: the customer cancelled through their bank; process a voluntary cancellation and never send "update your card". Contracted terms: the payment method ended, not the contract; hand to the account owner or collections |
| Soft: insufficient funds, issuer unavailable, generic decline | Adaptive retries within the network cap |
| Hard or do-not-retry: closed account, lost or stolen card, Visa's other never-approve codes, Mastercard advice code 03 | Never retry that credential; request a new payment method (the updater or a token may refresh a reissued card) |
| Authentication required | The customer, on-session, in an authenticated update flow; never another retry |

Without adaptive retries: about three soft-decline retries in week one, then weekly to the window's end, with insufficient-funds retries just after common paydays in the customer's time zone. Card networks cap reattempts per card per 30 days and charge for the excess; take the current cap from your processor. Each payment rail gets its own schedule: ACH may re-present an R01 or R09 return (insufficient or uncollected funds) at most twice within 180 days of the original settlement.

## The clock

- The retry window is the provider's; never end a subscription while retries are pending.
- One deadline, set at the first failure: the window's end, or the access cutoff if earlier. Every notice states it; moving it is a logged decision, never drift.
- Each notice names the next attempt, if any; the final notice lands days before the final attempt or the deadline.
- Keep access during the window, but cap costly metered usage (AI inference, for example).
- At the end: B2B → suspend, keep the data, offer one-click reactivation; low-value consumer plans → cancel with a reactivation link. Data is kept for the reactivation window (`cancel-flow-patterns.md` § Offer mechanics), the same number everywhere. To customers, say "suspend", never "pause": pause is a save offer.

## Notifications

Every failure notice carries: what failed (plan, amount, card brand and last four); the fix this decline needs (a new card, the bank's approval, authentication); the next attempt, if any; the deadline and what is lost then; one call to action, the hosted update page unless it cannot meet a requirement; a support contact; and trust cues (your usual sender and domain, no request for card details by email or reply, the same fix reachable by signing in).

| State transition | Recipients · channel | Adds |
|---|---|---|
| Renewal ahead, inside the `compliance.md` window | Billing contact and every admin · email | Renewal date, amount, term, how to cancel (direct link); annual: a value recap |
| First failure | Billing contact · email; every admin · in-app | — |
| Unpaid after the first retry (B2B: ~3 days) | Every admin · email and in-app | Any admin can update the method |
| Final attempt or deadline days away | Billing contact and admins · email, in-app, SMS where consented | What is lost on the deadline |
| Suspended or cancelled | Billing contact and admins · email | Data kept until [date]; one-click reactivation |
| Recovered | Everyone notified | "Payment received; nothing changes"; banners cleared; the sequence exits |

In B2B the card owner has often left, so admins hear early, not last.

## Disputes

Retrying unfamiliar or disputed charges, or hard declines, raises chargebacks; hard declines recover through card updates, not retries. Track dispute and fraud ratios against the thresholds your acquirer states in writing and alarm at half the lowest: dispute rate is the guardrail on retry aggressiveness.

## Metrics

- Prevention first: the first-attempt authorization rate on renewals, by rail and card type.
- Recovery rate = failed-invoice value recovered within the window ÷ failed-invoice value, split by decline category, payment rail and cure (customer update or retry), so retries get credit only for retry cures.
- Outcome: involuntary churn as a share of MRR, against the prior period or a split of the change (retry policy, notice content or timing; never notice presence).
- Recovery up, involuntary churn flat → more failures: check the failed-invoice rate, repeat failures per account and the debit or prepaid mix. Total churn flat → recovered accounts cancelling within 60 days (passive voluntary churn): stop escalating dunning and fix value.
- Notices sent, recovery flat → they miss the payer or land too late: check cures by recipient role and the days from each notice to the deadline.

## App store and merchant of record

- App stores retry and send their own payment notices: Apple for up to 60 days; Google Play puts the subscription on account hold, by default for 60 days minus any grace period. Turn on grace periods (Apple's is opt-in in App Store Connect; Google Play's is on by default) and show an in-app message linking to the store's payment settings.
- A merchant of record (Paddle, for example) runs retries and dunning: configure its settings and copy; don't rebuild them.
