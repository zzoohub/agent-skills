# Cancel Flow Patterns

Read when designing or reviewing a cancel flow, exit survey or save offer. Rules per jurisdiction: `compliance.md`; measuring saves: SKILL.md § Measure. Write the result as § Cancel flow in `churn-prevention.md` (default `biz/growth/churn-prevention.md`), ≤800 words plus the screens' final copy, sections a menu: screens · reason → offer → eligibility → cap → cost · jurisdiction check · events to log · what the readout decides.

## Survey

- One optional, single-choice question: 5-8 reasons, "Business closed" among them, "Other" (free text) last; randomize the rest, since order biases answers. Freeze the list per measurement window so trends compare.
- Split "too expensive" into "not worth the price" and "budget cut": they need different offers.
- Revealed beats stated: near-zero usage in the last 30 days turns "too expensive" into "not using it".
- Capture the reason once and pass it on; win-back (copywriting, if available) and product reuse it instead of asking again.

## Reason → offer

Launch the compliant path, the survey and a capped offer for every mapped reason together, under one holdout (SKILL.md § Measure); waiting for survey data first forfeits saves the holdout would already be measuring. Read the blend first, then each reason as samples allow, to decide what deepens, lengthens, stops or gets added. Redline an existing flow reason by reason.

Check first, then show one offer, optionally with one alternative. Price terms come from pricing, if available; else § Offer mechanics sets the launch ceiling. High-value accounts may also be offered a call with their CSM or a founder, never required.

| Reason | Check first | Offer | Eligibility, cap |
|---|---|---|---|
| Not worth the price | Usage, seat utilization | Low usage: right-size to a lower tier, or re-onboard. Healthy usage: annual prepay on monthly billing (pricing's terms, else the public annual discount), or the time-boxed discount | Lower tier: fits their usage. Annual: past ~3 paid months, refund terms shown before acceptance. Discount: the last 3 months at full price (a cancel at promo expiry is a pricing-fit leak: to pricing). Discount or annual: one per 12 months; repeat cancellers: lower tier only |
| Budget cut | Tenure, plan | Pause or a lower tier first; a time-boxed discount as the fallback | Discount: the last 3 months at full price and no save in the last 12 months |
| Not using it, never activated | Did they reach the value event? | Guided setup, or let them go: a pause only defers churn | No discount |
| Not using it, previously active | What changed | Fix that cause; pause only if it is temporary | One pause per 12 months |
| Missing feature | Is there a workaround? | The workaround; else log the gap with the account's MRR (for feature-spec, if available) and offer a ship notification | Never promise dates |
| Switching tools | Which tool (optional field, logged) | A clean export | No discount unless price is the stated reason and usage is healthy: a discount does not close a capability gap and trains cancel-and-return |
| Technical issues | Open tickets, incidents | Priority support; an outage credit, not a discount: it repays the failure without lowering the price anchor | — |
| Temporary or seasonal | — | Pause (mechanics below) | One pause per 12 months |
| Business closed | — | None: confirm and offer the data export | — |

**Break:** with no lower tier and near-zero marginal cost (most consumer apps), a time-boxed discount may lead for a budget cut; test it against pause under a holdout.

## Offer mechanics

- **Discount**, price reasons with healthy usage only: inside the ceiling, duration and margin floor from pricing or the caller. Without them, launch at the public annual-prepay discount or 20%, whichever is lower, for at most 3 billing months, priced above the next tier down and the margin floor, and flag the ceiling for pricing; deeper or longer waits for the readout, since depth trains cancel-to-negotiate and is hard to take back. Cost per acceptance = depth × months × MRR, logged per offer. Show the saving, the post-offer price and its start date; claim an expiry only if real.
- **Pause:** one per 12 months, at most 3 months by default; data and settings kept; resume date shown up front; a reminder before billing resumes. Judge pause, and any longer pause, by treatment minus holdout in paid months from the cancel attempt to 90 days past the pause's end, not by resume rates against reactivation rates: pausers self-select.
- **Data after cancellation:** keep it through the window that holds most reactivations (measure days from cancel to reactivation; default 90 days unless law, contract or a deletion request says otherwise). The same number appears on the confirmation, in its email, in dunning's end-state notices and in pause terms.
- **Lower tier:** show what they keep and lose and how the paid period is prorated or credited; one click back up.

## Abuse guardrails

Any repeatable concession gets farmed, as referral rewards do (the growth-loops capability's fraud guardrails, if available):
- One save discount per account per 12 months; repeat cancellers see non-discount options.
- No stacking: a save discount never combines with a dunning credit or another concession.
- Track the repeat-save rate: an account saved twice in a year is churn with extra steps; offer the lower tier or let it go.

## Refunds, proration and credits

- Refund posture, one of: full, prorated, or none with access to the period end.
- Some jurisdictions set refund duties (New York's price-rise rule, the EU 14-day withdrawal right): `compliance.md`.

## Compliant UI

The invariants in SKILL.md § Compliance & Click-to-Cancel apply to every screen: "Cancel now" on each, with at least the weight of any accept button, nothing preselected. Default flow (Minnesota-style rules or an unknown jurisdiction):
1. Reason: the optional survey question.
2. Save step, mapped to the reason: pause or the lower tier described in words, then one permission ask ("See your options?" [Show me] [Cancel now]). A reason with no mapped offer goes straight to step 4.
3. After [Show me]: the options, each with its post-offer price and start date, beside [Cancel now].
4. Confirmation: "Cancelled. Access until [date]. Refund: [posture]." [Export data] [Reactivate].

Steps 2 and 3 are the one save step; where routing allows offers without an opt-in, they merge.
- The confirmation email repeats the effective date and refund posture, says how long data is kept, and links to reactivation.
- **Germany (§ 312k BGB):** the cancel path holds no save step (invariant 4), so put pause and lower tiers on the plan page.
- **EU consumers inside the 14-day withdrawal period:** a "withdraw from contract here" function, prominent for the whole period and distinct from cancel; no survey or offer in it.
- **App-store billing:** the store owns the cancel sheet. Apple's Retention Messaging, set up in App Store Connect, can put a message, image or offer on it; a plan switch needs the real-time API (by request while pre-release). Google Play subscribers can pause by default. An in-app pre-cancel screen is optional and links straight to the store's subscription settings.

## Events to log

`cancel_intent` (account, plan, tenure, MRR, billing term, acquisition channel, arm) · `reason` and free text · `options_opt_in` · `offer_shown` · `offer_accepted` · `cancelled` (effective date) · `reactivated`; then each account's status and MRR at 90 days and 60 days after any discount ends. Acceptance = `offer_accepted` ÷ `offer_shown`; vendor "save rates" may count abandoned sessions.
