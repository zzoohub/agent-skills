# Health-Score Signals

Read before designing, reviewing or computing a health score; the model itself is in SKILL.md § Customer Health Score Framework.

## Signals

Score change above a level floor (the activation-bar red flag): rate each signal's last 4 weeks against the account's own prior 8 (seasonal segments: the same weeks last year). Percentile ranks would put most accounts below 60 by construction. New accounts and baselines under ~5 events: compare with the segment median at the same tenure.
- **Usage:** value actions, core-feature breadth (time in product only where more time means more value); inactive = no value event for 2× the segment's median gap between active days (event-driven products: value-delivered events).
- **Engagement:** email clicks, never opens (privacy proxies fake them); admin and champion activity; a support spike then silence scores 0.
- **Business:** seat utilization, plan-value trend, payment risk from billing data (failures, past-due invoices or disputes in the last 90 days; a card expiring before the next charge that the updater has not refreshed). B2B and sales-led weights favor it: the economic buyer rarely logs in, and churn shows at renewal and in seat contraction.

## Validity per segment

Before a signal enters the score in a plan or contract-size segment, check that it is defined and varies for most accounts there (coverage) and that churned and retained accounts differ on it (separation). A void signal is dropped in that segment and the category averages the rest; never impute 0. Common voids: seat utilization on single-seat or unlimited-seat plans; logins where use runs through an API or integration; email clicks where most contacts opted out; plan-value trend under usage pricing, where it tracks price, not value. A score that flags most of a segment usually carries a void signal or an averaging artifact: check churn by band per segment.

## Small data

Under ~100 churn events, no fitted weights: 3-5 yes/no red flags, each kept only if churn with it is ≥2× churn without. No flag is Healthy, any flag At risk; there is no Watch band. Under ~50 accounts, no score: review each account monthly.

## Interim worklist

Until the backtest clears, these triggers feed a human worklist; the thresholds are starting points, tuned to capacity:

| Trigger | First action | Owner, first action by |
|---|---|---|
| Failed payment unpaid after the first retry (B2B) | A personal call or message to the account owner; confirm who pays | Billing or CSM, 2 business days |
| Champion or admin gone (bounced email, deactivated user) | Name a new champion; rerun admin onboarding | CSM, this cycle |
| Value events down ≥50% against the account's baseline for 2 weeks | Ask what changed; fix the blocker | CSM or lifecycle, this cycle |
| Seat removal or downgrade request | Utilization review; right-size before they cut further | CSM, 5 business days |
| Support spike then silence, or a ticket past its SLA | Escalate and close the loop | Support lead, 2 business days |
| NPS ≤6 or a negative CSAT | Follow up on the stated issue | CSM, 2 business days |
| Below the activation bar | Guided setup (cro, if available) | Onboarding owner, this cycle |

Intent signals (exports, billing- or cancel-page visits) get a same-day response, not a queue slot: the owner's outreach, highest MRR first within capacity, else an in-product help prompt, neither citing the signal; never an offer, which belongs only in the cancel flow's one save step. Rank the list by MRR × the number of triggers fired, cut it at what the owners can work per cycle, and hold out a random 10-20% of eligible accounts or roll out owner by owner; the failed-payment row is never held out (test its timing or channel instead). Log trigger, action, date and 90-day status: holdout rows validate each trigger, and treated minus holdout measures the play.
