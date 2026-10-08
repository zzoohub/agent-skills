# Carrying Capacity & Kill/Keep/Scale

The verdict rubric lives in SKILL.md § Verdicts; retention inputs come from the retention reference.

## Compute CC

CC is the active base the product sustains on organic inflow alone: the equilibrium where users leaving equal users arriving.

**CC = organic new users per period × area under the organic cohort's retention curve (in periods).**
- Area = the sum of the curve's values from period 0 (its measured core-action rate; 100% only if signup is the core action) through the last mature period, plus the tail beyond it: last value × (1 − d) ÷ d, with d the late per-period decay (retention reference).
- No measurable decay (d within noise of zero): write "no equilibrium within the horizon; inflow is the limit", and report CC truncated at 36 months.
- Organic inflow = new users not bought: search, direct, word of mouth, referral signups, content. Exclude paid, sponsored, launch and PR spikes. Audit tagging first (GA4/GTM reference): untagged paid traffic inflates CC silently.
- Resurrected users are inside the curve (period retention counts their return), not inflow.
- Compute monthly, after the launch spike has passed, once ≥3 monthly organic cohorts are mature.
- Compute per segment when the decision differs by segment: the segment with the largest area per user (expected active periods) is where the product works best, whatever its size.
- Sales-led or enterprise (tens of accounts): no CC; use logo retention and GRR/NRR.

**Why not inflow ÷ blended churn.** Blended churn falls as the base ages, so that formula rises with no product change. Example: 1,000 organic signups a month, all active in their first month, 50% lost after it, then 2% a month. With three monthly cohorts in the base (1,990 users), the next month loses 520 (≈26%), so naive CC ≈ 3,800; the true equilibrium is 1,000 × (1 + 0.5 ÷ 0.02) = 26,000. And churn defined as "inactive for N days" only shows N days later, so short trailing windows (7-day CC) are noise.

## Read CC

- Compare CC with the active base counted on the same core-action definition; any-event MAU sits above CC even with no paid spend. An active base above CC is paid-supported, or draining since organic inflow or retention fell (check which driver moved); either way it falls toward CC. Below CC, it is still filling.
- Report CC with its two drivers beside it, organic inflow and same-age retention. Credit the product only when one of them moved; a CC move with neither moving is channel mix or data.
- CC rising while revenue stays flat means users stay but don't pay: a packaging or pricing question (via the pricing capability, if available).

## Live K

A growth-loops capability owns the K model (definition, amplification, targets); this skill measures the live value.
- **Gross K** = `referral_completed` attributed to a cohort ÷ cohort size, within the cohort's referral window. Label it gross.
- **Qualified K_W** = referred users (joined on `referrer_id`) who reach the qualifying event within W days of the inviting cohort's signup ÷ cohort size, as growth-loops defines it; W is the loop design's (K30, K90).
- Referral signups are already organic inflow: count them once. Never multiply CC by 1/(1−K); use 1/(1−K) only to project what a change in non-referral inflow would bring.
- Read K on post-launch cohorts at equal age: launching to the installed base drains a backlog of latent invites, so week-one K overstates.

Events: `invite_sent`, `invite_clicked`, `referral_completed`, `reward_granted` (event-tracking reference).

## Kill-Criteria Record

`kill-criteria.md` (default `biz/analytics/kill-criteria.md`; caller may redirect). If the PRD has a decision rule, seed the criteria from it: stop = Kill; change = Keep and iterate; continue = Keep or Scale.

**Fix next** follows activated-user retention: no flattening → the product; it flattens but few users activate → activation; both healthy → volume. Cohorts under ~100 activated users: buy enough volume to read the curve first, under the spend plan's cap and stop-loss.

This record is the source of truth for its criteria: reports and dashboards quote its thresholds, definitions and as-of dates verbatim, never a variant.

```markdown
# Kill Criteria — [Product]
<!-- ≤500 words + tables and queries; sections are a menu: omit what doesn't apply, heading included. A slot you can't derive reads "not computable: [reason]", never an estimate -->
## Criteria (written YYYY-MM-DD, before the data)
| Call | Metric (definition, unit, interval) | Threshold | Cohorts / n needed | Review date |
## Current read — YYYY-MM-DD
| Metric | Value | n | 95% CI | vs threshold |
Carried by: [aggregate] — top [k] [units] = [x]%; without them [value]
What changed (overturning a figure leadership saw): | Figure | Was | Now | Why |, then likely objections answered, one line each
Supporting, never decisive (monthly, as of YYYY-MM): CC [value | not computable: reason] · organic inflow [n/period; share of all inflow] · same-age retention [x]
Call: Kill / Keep / Scale / no call: [reason] — confidence [high | med | low: SKILL.md scale]
Fix next: product / activation / volume — [why; owner; the metric that shows it worked]
## Spend plan (when the call moves spend)
| Channel | Monthly cap (next raise ≤2×) | Gate: max incremental cost per activated [unit] | Stop-loss: after [spend] | Review date, lagging check | Channel fix |
## Change log
- YYYY-MM-DD: [what changed] — [reason]
## Queries
[one per number above, inline or linked, as-of date as its parameter]
```

## Dashboard Design for CC Monitoring

`dashboards.md` (default `biz/analytics/dashboards.md`; caller may redirect): § Definitions, then one row per tile; ≤250 words beyond the tables; sections are a menu: omit what doesn't apply, heading included.

**Definitions first.** One outcome metric tied to the decision the dashboard serves, and 3–5 input metrics teams can move that sum or multiply to it. Each metric carries a spec: unit, numerator, denominator, window, source of truth, owner, the decision it serves, a counter-metric that catches gaming, and the saved query that computes it.
- Active = did the core value action in the period; never a login or any event.
- Reject a north star that can rise while activated-cohort retention falls (signups, time spent, raw MAU).
- A definition change is logged and runs beside the old one for a full period; never splice two definitions into one trend line.

The tiles below are the default until PMF; past it, tiles come from the metric tree, ≤7 per audience.

| Tile | Shows | Cadence |
|---|---|---|
| Carrying Capacity | monthly CC with organic inflow and same-age retention beside it | monthly |
| Inflow | new organic, referral and paid (kept separate), by source | weekly |
| Retention | cohort table at the natural interval; immature cells blank | per interval |
| Activation | signup → Aha rate and time to Aha, by cohort | weekly |
| Live K (when a loop exists) | gross and qualified K_W per cohort at equal age; cycle time | per cohort |
| Revenue | MRR, GRR/NRR (trailing 12 months), payback | monthly |
| Data health | each key event's volume against its band; client vs server gap | daily |

Annotate releases, campaigns, pricing and tracking changes on every tile.

## Weekly Report Template

Output: `reports/week-YYYY-WW.md` in the analytics dir (default `biz/analytics/`; caller may redirect).

```markdown
# Week YYYY-WW — [Product]
<!-- ≤250 words + a table of ≤8 rows; sections are a menu. CC and GRR/NRR appear in the first report of each month only. Under ~500 users: counts beside rates, rolling 4-week window, no week-over-week verdicts. -->
**Headline:** [what matters this week, with confidence (SKILL.md scale)]
## Moved beyond its noise band
| Metric | This period | Band (mean ± 3 SD, last 8–12) | n | Likely cause | Confidence |
## Decision or ask
[who should do what; or "none this week"]
## Data issues
[gate failures and tracking changes, each with its fix or replacement definition (untested) and, for a figure already reported, was · now · why; or "none"]
## Within normal range
[metric names only]
```
