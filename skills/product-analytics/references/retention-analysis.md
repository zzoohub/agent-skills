# Retention, Funnels & PMF

The calculations behind the product frame; the verdict rubric lives in SKILL.md § Verdicts.

## Define Retention

- **Retained** = did the core value action in period k, with periods equal to the natural usage interval (SKILL.md § First). A login is not value.
- **One retention type per comparison.** Default: period (bracket) retention — active in period k, so returning users count. Never compare it with rolling or unbounded retention.
- **Cohort** by signup period (first payment, for revenue questions). Read activated users separately from all signups: activated-user retention judges the product; signup retention mixes in activation. No validated Aha yet: activated = a provisional activation event (the first completion of the core job), and any call built on it is labeled provisional.
- **Split** billing intervals (monthly vs annual) and plans when they behave differently.
- **Denominator** = every cohort member, including those who never came back.

Build the cohort from signups, never from activity rows: signups who never acted would vanish and inflate retention. The shape to adapt (tested on PostgreSQL; translate date and series functions for your engine):

```sql
-- Period retention by signup cohort. Rerun: set as_of (any date; only periods complete
-- before it are read) and unit, the natural usage interval: day, week or month.
WITH params AS (
  SELECT *, ('1 ' || unit)::interval AS step
  FROM (SELECT date '2026-10-01' AS as_of, 'month' AS unit) v
),
cohort AS (  -- from signups: members who never return stay in the denominator
  SELECT s.user_id, date_trunc(p.unit, s.signed_up_at)::date AS cohort_start
  FROM signups s, params p
  WHERE s.signed_up_at < p.as_of AND NOT s.is_internal
),
active AS (  -- the core value action, never a login or any event
  SELECT DISTINCT e.user_id, date_trunc(p.unit, e.occurred_at)::date AS period_start, 1 AS hit
  FROM events e, params p
  WHERE e.event = 'core_action' AND e.occurred_at < p.as_of
),
grid AS (    -- complete periods only: immature cells stay blank, never 0
  SELECT c.user_id, c.cohort_start, gs.period_start::date AS period_start,
         gs.n - 1 AS period  -- counts steps, so it holds for any unit
  FROM cohort c, params p,
       generate_series(c.cohort_start, p.as_of - p.step, p.step)
         WITH ORDINALITY AS gs(period_start, n)
)
SELECT g.cohort_start, g.period,
       count(*) AS members,
       coalesce(sum(a.hit), 0) AS retained,  -- sum(hit): some engines fill misses with 0, not NULL
       round(100.0 * coalesce(sum(a.hit), 0) / count(*), 1) AS retention_pct
FROM grid g
LEFT JOIN active a ON a.user_id = g.user_id AND a.period_start = g.period_start
GROUP BY 1, 2
ORDER BY 1, 2;
```

## Read the Cohort Table

A drop at the same age in every cohort is a lifecycle stage (trial end, first renewal). Newer cohorts higher at the same age: a product change or a channel-mix shift; check the mix before crediting the product. A dip along one calendar diagonal is a calendar event: read the changelog first. Active users per calendar period: sum counts, never percentages.

## PMF Evidence

- **Flattens** = the per-interval loss rate (the share of last interval's retained users lost) drops well below its early level and holds low and steady over the last 3 mature intervals, or the curve turns up (expansion, network effects). A loss rate that stays near its early level is decay toward zero, even where a linear chart looks flat near the bottom. Report the plateau with n and CI.
- **Late decay (d)** = the mean per-interval loss rate over those intervals. Carrying Capacity uses it; LTV takes the same measure on revenue.
- **Newer vs older:** compare activated cohorts at the same age.
- **Height:** compare with your own earlier cohorts. An external bar needs source, date, denominator and horizon: Lenny Rachitsky's benchmarks (June 2020) put "good" 6-month retention near 25% for consumer social, measured on registered users, and near 60% for SMB SaaS, measured on paying companies. Different denominators: never hold a consumer product's signups to a B2B bar.
- **Sean Ellis survey** (supporting only): ask users who recently experienced the core (Superhuman asked those who had used it at least twice in the last two weeks); results turn directional around 40 responses (First Round Review). Read only the 40% "very disappointed" line, then profile those respondents by segment (persona, use case, plan, channel) and check they reached the Aha action: where they concentrate is who the product fits. To learn why, ask what main benefit they get and read the answers against the product's core bet; the somewhat-disappointed who name that benefit are the next segment to win: fix what holds them back. Re-run it in waves on the same qualifying rule and compare waves, never mixed rules. Before launch, or without qualified users, it is not PMF evidence.

Record the current read in `funnels.md` § Retention (default `biz/analytics/funnels.md`; caller may redirect; ≤150 words plus a table; a menu: omit what doesn't apply): plateau, d and n per pre-specified segment, activated vs all, with its as-of date.

## Revenue Retention (GRR/NRR)

Source: per-account MRR snapshots from billing or its warehouse model, reconciled with finance. If only events exist, use event-derived MRR, labeled "unreconciled".
- **NRR(T)** = current MRR of the accounts that had MRR at T−12 ÷ their MRR at T−12.
- **GRR(T)** = the same, with each account capped at its T−12 MRR, so expansion can't hide churn.
- Annual plans count ÷12 per month while active, never as churned between renewals. Exclude one-time charges. Complete months only.
- GRR is revenue, not customers: GRR 70% means 30% of starting revenue lost, not 30% of customers.
- Monthly figures are not annual ones: report trailing-12 and compare annual with annual.
- AI products: inference cost belongs in gross margin.
- **Concentration:** report the top expanders' share of expansion and NRR without them, and the largest losses' share of churn and contraction. NRR above 100% that falls below it without a handful of accounts is carried by them: name them, and rest any call on the rest.

```sql
-- Trailing-12 NRR and GRR with the influence check (PostgreSQL). mrr_snapshots: one row
-- per paying account per month start; annual plans / 12; one-time charges excluded.
WITH params AS (  -- any as-of date: T is its month start
  SELECT date_trunc('month', date '2026-10-01')::date AS as_of
),
acct AS (    -- every account paying at T-12; churned ones stay in, at zero
  SELECT b.account_id, b.mrr AS mrr_then, coalesce(c.mrr, 0) AS mrr_now
  FROM params p
  JOIN mrr_snapshots b ON b.month = p.as_of - interval '12 months' AND b.mrr > 0
  LEFT JOIN mrr_snapshots c ON c.account_id = b.account_id AND c.month = p.as_of
),
flagged AS ( -- the 5 largest expanders and the 5 largest losses (churn or contraction)
  SELECT *,
    mrr_now > mrr_then AND row_number() OVER (ORDER BY mrr_now - mrr_then DESC) <= 5 AS top_gain,
    mrr_now < mrr_then AND row_number() OVER (ORDER BY mrr_now - mrr_then) <= 5 AS top_loss
  FROM acct
)
SELECT count(*) AS base_accounts,
       round(sum(mrr_now) / sum(mrr_then), 3) AS nrr,
       round(sum(least(mrr_now, mrr_then)) / sum(mrr_then), 3) AS grr,
       round(sum(mrr_now) FILTER (WHERE NOT top_gain)
             / sum(mrr_then) FILTER (WHERE NOT top_gain), 3) AS nrr_without_top5,
       round(sum(mrr_now - mrr_then) FILTER (WHERE top_gain)
             / nullif(sum(greatest(mrr_now - mrr_then, 0)), 0), 3) AS top5_share_of_expansion,
       round(sum(mrr_then - mrr_now) FILTER (WHERE top_loss)
             / nullif(sum(greatest(mrr_then - mrr_now, 0)), 0), 3) AS top5_share_of_losses
FROM flagged;
```

Reading, annual (diagnostic cut lines, not targets):
- NRR above 100% with GRR below 90%: expansion masks churn; fix churn first, in the segment where it happens.
- GRR 90% or more with NRR below 100%: accounts stay but shrink or never grow; check seat and plan contraction, and whether an expansion path exists.
- Both low: find the churning segment (plan, contract size, cohort) before blaming price.

Benchmark against your own trailing four quarters, or one dated survey banded by contract size (SaaS Capital's private-SaaS retention survey bands by ACV because retention rises with contract value).

## LTV and Payback

- LTV = Σ over months ≤36 of the cohort's gross-margin revenue per acquired customer (expansion and contraction included), observed, with the tail extended at its late decay. Logo retention × ARPA fits only flat-priced plans: it misses expansion and contraction. Never 1 ÷ churn on a flat plateau: it implies an infinite lifetime.
- No plateau yet: report cumulative gross margin per acquired customer against CAC, month by month, instead of an LTV.
- Payback = months until cumulative gross margin per customer covers CAC. David Skok's bars (LTV:CAC above 3, payback within 12 months) assume an uncapped LTV: the 36-month cap makes 3× stricter.
- Compute both per channel, CAC = that channel's spend ÷ the customers it acquired: a blended CAC hides the channel that loses money.
- **Spend gate**, the leading check on any spend call: max cost per activated unit = cumulative gross margin per activated unit through the payback bar (P months), read off the activated cohort's observed curve, expansion included. Per channel, max cost per signup = the gate × that channel's activation rate. Example: activated accounts earn $420 gross margin over their first 12 months, so with a 12-month bar the gate is $420; a channel activating 25% of signups can pay up to $105 a signup. Use the channel's own activated curve once mature; until then the organic one, which flatters paid cohorts, so payback stays the lagging check at the review date. Activated cohorts observed for fewer than P months: the gate is their cumulative margin through the last observed month, labeled a floor (it rises as they age), with the late-decay extension to P beside it, labeled a projection.
- **Stop-loss:** size the fixed spend to buy ~30 activated units at the gate price (at 30, cost per activated unit still has a 95% range of about −30% to +50%); past it, a cost above the gate stops the channel until its fix (§ Channel Quality) is in.

## Funnels

`funnels.md` holds, per funnel, ≤150 words plus a step table (a menu: omit what doesn't apply): the definition (unit, ordered steps, conversion window, order rule — strict or any order), baseline, noise band, owner and last diagnosis. UX top tasks (step completion, drop-off) are funnels too.
- Report step conversion, cumulative conversion and time to convert (median and p90) per step.
- Fix the largest absolute loss × downstream value, not the lowest step rate.
- Locate the leak with ≤5 cuts (source, device, new vs returning first).
- A sudden step drop is tracking until the data-trust gate clears it.
- Fixing the page or flow goes to the cro capability, if available.

## Channel Quality

Judge channels and campaigns by the cohorts they bring, not by platform-reported conversions: each ad platform credits itself within its own attribution window, so platform totals overlap. Per channel: signups, activation rate, same-age retention, revenue per acquired user, and payback against that channel's CAC. Join ad and creative names through `utm_campaign` and `utm_content` so creative tests read through to cohort quality. Without a holdout or geo test, write "attributed", not "caused".

Weak cohorts from a channel (activation or same-age retention below organic's): before cutting it, check what it optimizes for and seeds from. A platform bidding on signups or installs finds the cheapest of those, who often never activate; lookalikes seeded from all signups copy them. Fix: optimize toward the activation event, or a value-weighted one, once it fires often enough for the platform to learn (check its current minimum); seed from activated or paying users; exclude existing customers. Then judge the channel on cost per activated unit, not cost per signup.

## Health Score: Backtest and Scoring

The model — outcome and horizon, signals, red flags, weights, bands and the pass bar — comes from churn-prevention (if available; otherwise state the model you assumed). This skill runs it:
1. Take the outcome and horizon H from the model (default: churn or major contraction within 90 days).
2. Pick a scoring date S at least H before the latest complete data. Score the accounts active at S on data dated ≤ S only, and read the outcome over (S, S + H]. Any signal dated after S leaks the outcome and inflates precision and recall. Few churn events: pool several scoring dates.
3. Compare each band's churn with the base rate in the same plan or contract-size segment. For the at-risk band report precision (share that churned), recall (share of churners caught) and lift (precision ÷ base rate), with n, at the model's capacity cutoff (the accounts the team can work per cycle). Report the same for the simple comparator (the red-flag count, or the best single signal such as the 30-day active-seat trend): a composite that doesn't beat it adds nothing.
4. A band drives action only after the backtest clears the model's pass bar.
5. Score live on the same code and windows; recalibrate when lift decays and after pricing or packaging changes.

`health-score.md` (default `biz/analytics/health-score.md`; caller may redirect; ≤300 words plus tables; a menu: omit what doesn't apply) records the model version and source, thresholds, the backtest (date, n, base rate, churn by band, precision, recall, lift) and the next refresh date.
