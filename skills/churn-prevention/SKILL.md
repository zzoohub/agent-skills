---
name: churn-prevention
description: |
  Reduces subscription churn: finds where lost revenue goes (failed payments,
  early vs late cancels, contraction), then designs the fix: cancel flows and
  save offers (which offer, to whom, when; price terms via pricing),
  failed-payment recovery, churn health scores, and auto-renewal
  compliance. Owns billing-event notices (dunning, card expiry, renewal,
  cancellation confirmation), not copywriting.
  Use when: "churn", "cancel flow", "save offer", "failed payments",
  "at-risk accounts", "renewal at risk".
  Do NOT use for: win-back or re-engagement email (copywriting); retention
  cohorts, curves or PMF (product-analytics); tier design or discount price
  terms (pricing); onboarding (cro).
---

# Churn Prevention

## Premise

Churn work wins only on durable, incremental retained revenue: a save counts only if the account would otherwise have left and still pays after the offer ends. The cancel flow harvests a decision made weeks earlier, so the cheapest saves come before intent. Find where lost revenue goes before choosing a lever; then cost and reversibility, not clean evidence, decide what ships now (§ Ship or gate).

Good output: lever 1 from the largest addressable bucket; do-now steps in order, with preconditions; every offer capped and costed; every change with a comparison that could show it failed.

## Modes & outputs

Default paths; the caller may redirect the `biz/` root. Update files in place; with no file-write tool, return content inline. Sections, listed here or in each reference's header, are a menu: omit what does not apply, heading included.

| Request | Read | Output · budget |
|---|---|---|
| Reduce churn (default) | Stages 0-1 | `biz/growth/churn-prevention.md` ≤1,200 words: Situation (motion, who bills, decomposition, assumptions; logo churn, GRR and NRR separately; annual terms: renewal rate by cohort) · Findings · Do now (ordered; owner, date, precondition, risk, rollback) · Levers 1-3 ranked, each with owner, ship week, sizing, assumption and a 2-4-week leading indicator · Asks (verdict, evidence, cost, counterproposal each) · Forecast against target · Measurement · Not doing. Lever 1's design follows its mode's row |
| Cancel flow, save offers | `references/cancel-flow-patterns.md`, `references/compliance.md` | § Cancel flow in `churn-prevention.md`, ≤800 |
| Failed payments, billing notices | `references/dunning-playbook.md`, `references/compliance.md` | `biz/growth/dunning.md` ≤700 |
| Sales-led renewals, one account at risk | `references/renewal-playbook.md` | § Renewals ≤600 or a save plan ≤400 |
| Health score | § Customer Health Score Framework, `references/health-signals.md` | § Health-score model, ≤500 |
| Review a setup, or change a live one | The matching reference | Findings first, ≤700: 🔴 legal exposure, broken cancel or retry path · 🟠 sized revenue leak · 🟡 measurement gap · 🟢 polish; then do-now steps |

- **Budgets limit the record, never the analysis.** They cap decision prose; paste-ready drafts and a calculations appendix (inputs, formula, result) sit outside. Every request runs the checks (who bills, the user's numbers, the reference's traps, every party and automation touched); a material finding that does not fit becomes one line or moves to the appendix, never dropped. **Small requests** skip the question batch (state the defaults) and the written decomposition: the artifact plus one line per material finding, in scope or not. A scope cut names its reason and an owner, with enough to act on.
- **Build on what exists:** redline the owner's score, flow, notices or spec in your doc, with reasons; replace only what fails a check; owners' files stay unchanged unless the caller asks. In any mode, each stakeholder ask gets an Asks entry.
- **Drafts only:** no live retry, coupon, offer or send changes without approval. **Report back:** do-now steps in order with preconditions and risks; lever 1 and why; every material finding, one line each; assumptions, questions, approvals needed; files written (cite only what exists).

## Stage 0 — Read and frame

**Read first** (defaults; caller may redirect): `biz/analytics/health-score.md`, `biz/analytics/funnels.md`, `biz/marketing/pricing.md`, `biz/growth/experiments.md`, `biz/growth/churn-prevention.md`, `biz/growth/dunning.md`, the exit-survey export; then what is live: retry, dunning and end-of-retry settings, and each automation that messages customers or changes access on billing or usage events, with its trigger.

**Ask once, in one batch**, with defaults; a subagent that cannot prompt applies them and lists the questions:
1. Who bills; what else messages customers? (your processor; others unknown, so confirming them is a precondition of every settings change)
2. Term and motion? (monthly self-serve)
3. Lost MRR by bucket and month, last 3-6 months: rising, or steadily high? (unknown: measure it in week 1 while reversible fixes ship)
4. Who acts on risk flags: accounts each, review cadence? (automation only)
5. Consumers or businesses, where? (consumers, strictest regime served)
6. Concession ceiling or gross margin? (the launch default, `references/cancel-flow-patterns.md` § Offer mechanics)
7. Target and date? (none: forecast the base case)

## Stage 1 — Decompose and route

**Who bills sets the scope:** merchant of record or app store → configure their retry, grace and retention settings; net-terms invoices → collections with finance, not dunning; app and web mixed → route each subscriber by who bills them.

Split lost MRR over the last 3-6 months (annual terms: 12 months of renewals) into involuntary · voluntary before the first renewal or day 90 · voluntary later · contraction, leaving out unaddressable exits (business closed). Cut each bucket by billing term and acquisition promo: churn at promo expiry is a pricing-fit leak. Counting: churn at its effective date; past due after the retry window is involuntary; paused MRR is at risk, not retained; unconverted trials are acquisition loss; reactivations are a separate inflow, never netted.

**If churn rose, find the break first:** each bucket by month and by signup cohort. A step in one bucket at one date is an event (price change, billing migration, outage, release, a promo or annual cohort coming due): explain or reverse it before ranking. Cohorts flat while the blend rises: mix shift toward monthly, promo or new-channel customers, an acquisition-fit lever. **Bound every attribution:** parts sum to no more than the user's counts; a cause owns only the excess churn among accounts it touched over comparable untouched ones (grandfathered plans for a price change, non-users for a release).

**Rank** levers by low-case retained MRR (bucket MRR × share reached × lift) ÷ effort-weeks. Unmeasured lift: use the break-even lift (repays build and concession cost within two quarters), rank by its plausibility, and make it the test hypothesis and kill line. Don't assume dunning first: involuntary's share falls as price rises (Recurly, July 2026: ~30% of churn at $10-25 a month, ~6% at $250+).

| Largest bucket | Lever 1 | Break when |
|---|---|---|
| Involuntary | Payment recovery (`references/dunning-playbook.md`) | Recovered accounts cancelling within 60 days: passive voluntary churn; fix value |
| Voluntary before first renewal or day 90 | Activation (cro, if available); acquisition fit by channel | Cancels cluster at trial-to-paid: fix trial disclosure and reminders first |
| Voluntary later, self-serve | Reason-mapped cancel flow with capped offers (`references/cancel-flow-patterns.md`), then health-triggered automation; annual-plan offers to monthly payers past ~3 paid months (pricing's terms) | Under ~50 cancels a month: the same flow, read as directional, plus churner interviews |
| Voluntary later, sales-led | Renewal process and account saves (`references/renewal-playbook.md`); health score for owners, not save offers | Book under ~50 accounts: review each renewal by hand |
| Contraction | Seat and usage utilization; packaging to pricing, if available | Seasonal or usage-priced: compare year over year |

## Ship or gate

| Action | Ships | Waits for |
|---|---|---|
| Loss-preventing notices (payment failure, card expiry, renewal, confirmations) | Now; never held out (test content or timing) | — |
| Capped, reason-matched save offers within the given or default ceiling | Now, under the holdout | Readout, to deepen, lengthen or add |
| Human outreach on red flags, triggers and intent signals, sized to capacity | Now, with a holdout or owner-by-owner rollout | — |
| Retry, updater, token, end-of-retry and journey settings | Once traced and approved | — |
| Automated plays keyed to health bands | — | Backtest clears the pass bar |
| Over-ceiling concessions, contract or price changes, data deletion, billing migration | — | Evidence, owner approval |

**Trace first:** before changing a setting, fix what fires on the events it touches (`references/dunning-playbook.md` § Inventory and trace). **No-build first,** whatever the rank: native features of the tools already paid for, and hosted pages; then builds by value per effort.

## Measure

- **Holdout**, random and sticky per account: 10-20% of cancel-intent accounts get the survey-only path; proactive plays are withheld from 10-20% of flagged accounts, or rolled out owner by owner. Size via cro, if available.
- **Primary metric**, treatment minus holdout: saves, net revenue retained per cancel-intent after concession cost, at 90 days and 60 days after any discount ends; plays, GRR of flagged accounts at 90 days (annual: at renewal).
- **Guardrails:** re-cancels within 30 days of an offer ending, refunds and chargebacks, complaints.
- **Small samples** (under ~150 holdout cancel-intents per decision window; plays, ~200 flagged accounts a quarter): compare with a pre-launch cohort of matching reason and tenure (plays: the prior quarter's flagged cohort); directional only.
- **Forecast against the target:** low and base case per lever, deduplicated, dated from when each starts counting; name any shortfall and what would close it, never a raised lift.
- Log each test in `biz/growth/experiments.md` (default; caller may redirect) as cro's test card, if available.

**If the numbers don't move** (symptom → cause → check):
- Save rate up, revenue churn flat → saves not incremental or durable → holdout delta, re-cancels after offers end.
- Recovery or notices up, churn flat → `references/dunning-playbook.md` § Metrics.

## Compliance & Click-to-Cancel

Not legal advice; dated, sourced rules per jurisdiction: `references/compliance.md`; verify before launch.

**Invariants**, everywhere unless you route by jurisdiction:
1. Online signup → online cancel, at least as easy.
2. A cancel control on every screen, at least as prominent as any offer; skipping survey and offer cancels within two actions.
3. Survey optional; at most one save step per attempt.
4. Describe pause and lower tiers freely; anything accepted in one click (pause, plan change, discount, credit) waits for one opt-in per attempt (Minnesota; default if jurisdiction unknown). Germany: no survey, offer or pause between the cancel button and its confirmation page.
5. Declining cancels immediately; post-offer price and end date shown before acceptance.
6. Confirmation screen and email: effective date, refund posture.
7. Renewal, trial-end and price-change notices inside every window served (`references/compliance.md`).
8. No re-enrollment without fresh consent; consent and cancellation records kept 3 years, or 1 year after termination if longer.

## Customer Health Score Framework

This section owns the model; read `references/health-signals.md` before designing or computing a score. Record each project's calibration as § Health-score model in `churn-prevention.md`, ≤500 words, a menu: outcome and lead time · signals · red flags · weights · pass bar · bands. Backtest any existing score against the new one. Backtests and live scoring (`biz/analytics/health-score.md`): product-analytics, if available.

1. **Outcome and lead time:** churn or ≥20% contraction within 90 days (annual: at the next renewal), predicted only from data available a lead time earlier. Lead time = owners' review cadence + the play's time to effect (annual: + the notice period); unknown: 30 days self-serve; sales-led or annual, T-120 before the notice deadline.
2. **Formula:** each signal scores its change against the account's own baseline, sub-score = min(100, 100 × current ÷ baseline), never percentile ranks; category = mean of the segment's valid sub-scores (void signals dropped, never scored 0); `Health = Usage × 0.40 + Engagement × 0.25 + Business × 0.35`, B2B or sales-led `0.25 / 0.25 / 0.50`; Business includes payment risk. These weights are a prior: used at ≥100 churn events until fitted, kept only if they beat the red-flag count (fewer events: `references/health-signals.md` § Small data).
3. **Red flags override the composite:** failed payment or dispute; champion or admin departure; seat removal; downgrade request; below the activation bar (no value event by day 30, sales-led by the onboarding plan's date; under a quarter of paid seats active; under a third of the segment's median value events at that tenure). Renewal proximity sets urgency, not health. Intent signals (exports, billing- or cancel-page visits) stay out of the score and get a same-day response, never an offer.
4. **Pass bar** before the composite's bands drive any action (red flags act at once): an out-of-time backtest at the lead time (via product-analytics, if available) shows churn rising band by band and At risk, at the capacity cutoff, churning ≥3× the base rate within its plan or contract-size segment; re-run quarterly and after pricing or packaging changes. Until it clears, red flags and triggers, not bands, feed a capacity-sized human worklist under a holdout (`references/health-signals.md` § Interim worklist); the backtest runs now, on history, never on treated accounts.

| Band | Action | Owner |
|---|---|---|
| Healthy ≥70 | Expansion signals to pricing or cro, if available | Automation |
| Watch 40-69 | Nudge tied to the dropped signal | Lifecycle automation |
| At risk <40, or any red flag | Named owner within 5 business days; value recovery (re-onboarding, admin training, fix the blocker); no discount by default. Payment flags instead: dunning (`references/dunning-playbook.md`) and the worklist's billing row | CSM or founder; automation only: a value-recovery sequence |

Move the At-risk cutoff so the band holds what its owners can work in one review cycle; each flagged account shows its top two reasons.

## Self-Review

Before finalizing (a review checks the existing setup):
- Counting rules applied; rises traced to their break; attributions within the user's counts, causes checked on untouched accounts.
- Levers sized (unmeasured lift: break-even); lever 1 from the largest addressable bucket, or the doc says why; the forecast meets the target or names the gap.
- Reversible plays ship now under a holdout, no-build first, settings traced downstream; no loss-preventing notice or billing call held out.
- Each offer and concession has eligibility, a cap and a cost; no discount reaches a never-activated account.
- Failure notices reach every admin early with the next attempt, the one deadline, the loss and trust cues; recovery is confirmed.
- Existing artifacts redlined; pause length and data retention one number each.
- Numbers are the user's or marked assumptions, calculated in the appendix; no vendor benchmark is a target.
- Each change has a holdout or stated comparison, primary metric, guardrails and decision date.
- Each jurisdiction served passes the invariants and its variants (Germany, EU withdrawal, app stores).
- Health score: lead time from cadence and time to effect; signals valid per segment; payment risk in; backtest on history, without treated accounts, before bands drive action.
- Asks have verdicts; the reply has the ordered do-now steps with preconditions and risks and every material finding, citing only what exists; nothing live changed without approval.
- **Footprint:** decision prose within the mode's budget, no material finding dropped to fit; each section carries a decision; the doc never narrates this method.
