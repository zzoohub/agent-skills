# Retention & Cohort Analysis

## Table of Contents

1. [Why Retention Is the Only Metric That Matters](#why-retention-is-the-only-metric-that-matters)
2. [Cohort Types](#cohort-types)
3. [Retention Intervals](#retention-intervals)
4. [PMF Assessment via Retention Curves](#pmf-assessment-via-retention-curves)
5. [Building Cohort Tables](#building-cohort-tables)
6. [Common Retention Patterns & Diagnoses](#common-retention-patterns--diagnoses)
7. [Segmented Analysis](#segmented-analysis)
8. [Implementation in PostHog](#implementation-in-posthog)
9. [Revenue Retention (GRR/NRR) via HogQL](#revenue-retention-grrnrr-via-hogql)
10. [LTV Estimation from Cohorts](#ltv-estimation-from-cohorts)

## Why Retention Is the Only Metric That Matters

Acquisition can be bought. Revenue can be inflated. But retention is the unmanipulable signal of whether your product delivers value. A product with 80% D30 retention and 100 users beats one with 10% D30 retention and 10,000 users on every horizon that matters: the first can buy growth and keep it; the second leaks whatever it buys.

---

## Cohort Types

### Time-Based Cohorts (Acquisition Cohorts)
Group users by signup date (week or month). The standard for tracking retention over time.

```
             Month 0  Month 1  Month 2  Month 3  Month 4
Jan 2025     100%     45%      32%      28%      27%
Feb 2025     100%     48%      35%      30%      29%
Mar 2025     100%     52%      40%      35%      —
```

**How to read:**
- Each row = one cohort (all users who signed up in that month)
- Each column = months since signup
- **Read diagonally** (top-left to bottom-right) = same calendar month across cohorts
- **Read columns** = same lifecycle stage across cohorts (are newer cohorts retaining better?)
- **Read rows** = one cohort's lifecycle

### Behavioral Cohorts
Group users by actions taken (or not taken). Critical for Aha Moment validation.

Examples:
- Users who completed onboarding vs. skipped
- Users who invited a teammate vs. solo users
- Users who used feature X in first week vs. didn't

### Segment-Based Cohorts
Group by user properties. Reveals which segments have fundamentally different retention.

Examples:
- By acquisition channel (organic vs. paid vs. referral)
- By company size (1-10 vs. 11-50 vs. 50+ employees)
- By plan tier (free vs. paid)
- By geography or persona

---

## Retention Intervals

| Interval | Measures | When to Use |
|----------|----------|-------------|
| **D1** | First return after signup | Onboarding quality |
| **D7** | Weekly return | Early habit formation |
| **D14** | Second week | Habit stability |
| **D30** | Monthly return | Core retention |
| **D60** | Two-month | PMF signal |
| **D90** | Quarterly | Long-term viability |

**For SaaS specifically:**
- **Weekly products** (project management, communication): D7 is the key early signal
- **Monthly products** (analytics, invoicing): D30 is the first meaningful signal
- **Usage frequency < 1x/month**: Retention plateau is nearly impossible — reconsider the product

---

## PMF Assessment via Retention Curves

### The Plateau Test

Plot cohort retention curves. The shape tells you everything:

**Shape 1: Continuous decline (no plateau)**
```
100% ─╲
      ╲
       ╲
        ╲
         ╲─── → 0%
```
**Diagnosis**: No PMF. Stop all acquisition spending. Fix the product.

**Shape 2: Decline then flatten (plateau exists)**
```
100% ─╲
      ╲
       ╲___________  → plateau at X%
```
**Diagnosis**: PMF exists. Plateau height determines business ceiling.

**Shape 3: Smile curve (decline, flatten, then rise)**
```
100% ─╲
      ╲
       ╲_____╱─── → expanding
```
**Diagnosis**: Strong PMF with network effects or expanding use cases. Rare and very valuable.

### Plateau Height Benchmarks (B2B SaaS, directional — re-verify before citing)

| Plateau Height | Assessment | Action |
|---------------|------------|--------|
| < 5% | No PMF | Kill or pivot |
| 5-10% | Weak signal | Focus entirely on retention |
| 10-20% | Early PMF | Optimize activation, cautious acquisition |
| 20-40% | Solid PMF | Scale activation and acquisition |
| > 40% | Strong PMF | Scale aggressively |

**Consumer products** typically need higher plateaus (>20%) due to lower monetization per user.

### Revenue Retention Benchmarks (directional — re-verify before citing)

| Metric | Median | Top Quartile | Elite |
|--------|--------|--------------|-------|
| GRR (Gross Revenue Retention) | ~84% (2025 actuals; down from ~88% earlier) | 95%+ | 97%+ |
| NRR (Net Revenue Retention) | ~102% (2025 actuals; survey-dependent — medians have compressed since 2022). By pricing model: usage-based ~108%, seat-based ~98% | 115%+ | 120%+ |

**Warning**: High NRR can mask poor GRR. NRR of 130% with GRR of 70% = losing 30% of customers but making it up with upsells. That's fragile.

By company scale (earlier survey cut, before the 2025 compression — directional; the pattern of NRR/GRR rising with scale matters more than the exact figures):
- **$1M-$10M ARR**: Median NRR ~98%, GRR ~85%
- **$10M-$100M ARR**: Median NRR ~106%, GRR ~90%
- **$100M+ ARR**: Median NRR ~115%, GRR ~94%

---

## Building Cohort Tables

### Step 1: Define the cohort
- What groups users together? (signup date, plan start, first action)
- What's the time interval? (daily, weekly, monthly)
- **Don't mix annual and monthly subscriptions** — analyze separately

### Step 2: Define retention
- What counts as "retained"? (logged in, performed core action, paid)
- Be precise: "logged in" ≠ "got value"
- Best practice: define retention as performing the **core value action**, not just any activity

### Step 3: Build the table
```sql
-- Basic cohort retention query
WITH cohorts AS (
  SELECT
    user_id,
    DATE_TRUNC('month', signup_date) AS cohort_month,
    DATE_TRUNC('month', activity_date) AS activity_month
  FROM user_activity
),
cohort_sizes AS (
  SELECT cohort_month, COUNT(DISTINCT user_id) AS cohort_size
  FROM cohorts
  GROUP BY 1
),
retention AS (
  SELECT
    cohort_month,
    DATE_DIFF('month', cohort_month, activity_month) AS months_since,
    COUNT(DISTINCT user_id) AS active_users
  FROM cohorts
  GROUP BY 1, 2
)
SELECT
  r.cohort_month,
  r.months_since,
  r.active_users,
  ROUND(r.active_users * 100.0 / cs.cohort_size, 1) AS retention_pct
FROM retention r
JOIN cohort_sizes cs ON r.cohort_month = cs.cohort_month
ORDER BY 1, 2;
```

### Step 4: Read the table

**Diagonal reading** (left-aligned table): Sum values moving from Month 0 up and to the right = total active users in a given calendar month.

**Column comparison**: Are newer cohorts retaining better at the same lifecycle stage? If yes, product improvements are working.

**Row analysis**: Where does each cohort's biggest drop happen? That's your highest-leverage fix.

---

## Common Retention Patterns & Diagnoses

### Massive D1 Drop (>70% lost on Day 1)
**Problem**: Onboarding failure. Users don't understand what to do or can't get first value.
**Fix**: Simplify onboarding, reduce time-to-first-value.

### Steady Decline Through D30 (Never Flattens)
**Problem**: Product doesn't create a habit. No retention plateau = no PMF.
**Fix**: Find or strengthen the Aha Moment. Consult `aha-moment-discovery.md`.

### D7 Plateau Then D30 Drop
**Problem**: Initial novelty wears off. Product solves a one-time problem, not an ongoing need.
**Fix**: Create recurring value (regular reports, ongoing workflows, fresh content).

### Newer Cohorts Retaining Worse
**Problem**: Quality of acquisition is declining (bad channels, broad targeting) or recent product changes hurt.
**Fix**: Segment by acquisition channel. Check if product changes correlate.

### Newer Cohorts Retaining Better
**Signal**: Product improvements are working. Keep going.

---

## Segmented Analysis

**Always segment.** The average hides the insight.

Priority segments:
1. **By acquisition channel** — Organic users almost always retain better than paid. Quantify the gap.
2. **By Aha Moment completion** — Compare users who reached vs. didn't reach the Aha Moment. The gap should be dramatic (2-5x).
3. **By plan/tier** — Free vs. paid retention tells you about activation and value perception.
4. **By company size/persona** — Different segments may have fundamentally different retention profiles.
5. **By feature usage** — Which features correlate with retention? This is Aha Moment discovery.

---

## Implementation in PostHog

Execute retention analysis via a PostHog capability (MCP tools or the UI), if available:

| Analysis | PostHog Feature | How |
|----------|----------------|-----|
| Cohort retention curves | **Retention** insight | Set start event (signup), return event (core action). Period: day/week/month |
| Lifecycle breakdown | **Lifecycle** view | New/returning/resurrecting/dormant per period. Rising "resurrecting" = win-back working |
| Stickiness | **Stickiness** insight | Distribution of active days/weeks. Bimodal = healthy (casual + power users) |
| User journey analysis | **Paths** | Compare paths of retained vs churned users |
| Behavioral segments | **Cohorts** | Create cohorts by behavior, plan, channel for segmented retention |
| Revenue retention (GRR/NRR) | **HogQL** | Custom SQL on revenue events. PostHog's built-in Revenue analytics (Stripe-synced MRR, in flux) has no cohort-level GRR/NRR — build those via HogQL |
| Custom cohort tables | **HogQL** | Full SQL control for any analysis the UI doesn't support |

---

## Revenue Retention (GRR/NRR) via HogQL

PostHog's built-in Revenue analytics (Stripe-synced MRR dashboards — still in flux) does not produce cohort-level GRR/NRR. Use HogQL to build revenue retention cohorts from subscription/payment events.

### Gross Revenue Retention (GRR)

GRR measures revenue kept from existing customers, excluding expansion. It answers: "How much of last period's revenue did we lose?"

**Event-schema assumption:** `subscription_renewed` carries the renewal amount in `properties.amount`. `subscription_cancelled` should carry `amount = 0` (or be filtered out). Adjust the WHERE clause to your schema.

```sql
-- GRR: Monthly revenue retention excluding expansion
-- Uses LEFT JOIN so churned users (no row in curr month) still contribute to
-- beginning_revenue, and contribute 0 to retained_revenue via COALESCE.
WITH monthly_revenue AS (
  SELECT
    person_id,
    DATE_TRUNC('month', timestamp) AS month,
    SUM(toFloat64(properties.amount)) AS revenue
  FROM events
  WHERE event = 'subscription_renewed'
    AND timestamp >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
  GROUP BY person_id, month
),
cohort_revenue AS (
  SELECT
    prev.month + INTERVAL 1 MONTH AS month,
    SUM(prev.revenue) AS beginning_revenue,
    -- LEAST() caps retention at prev.revenue, excluding expansion.
    -- COALESCE() treats churned users (no curr row) as 0 retained.
    SUM(COALESCE(LEAST(curr.revenue, prev.revenue), 0)) AS retained_revenue
  FROM monthly_revenue prev
  LEFT JOIN monthly_revenue curr
    ON curr.person_id = prev.person_id
    AND curr.month = DATE_ADD(prev.month, INTERVAL 1 MONTH)
  GROUP BY prev.month
)
SELECT
  month,
  ROUND(retained_revenue * 100.0 / beginning_revenue, 1) AS grr_pct
FROM cohort_revenue
ORDER BY month
```

> **Why LEFT JOIN matters:** with an INNER JOIN, users who churn (no `subscription_renewed` event in the next month) get dropped from BOTH `beginning_revenue` AND `retained_revenue` — making churn invisible and inflating GRR. LEFT JOIN keeps the churned user in the denominator with 0 retention.

### Net Revenue Retention (NRR)

NRR includes expansion (upgrades) and contraction (downgrades). It answers: "Is each cohort paying us more or less over time?"

**Event-schema assumption:** each user's recurring charge lands as **one** amount-bearing event per
month (`purchase_completed` or `subscription_renewed`). If `subscription_upgraded` /
`subscription_downgraded` fire *in addition to* a same-month renewal carrying the full new amount,
drop them from the `IN` list below — the next renewal already reflects the change, and summing both
double-counts. (Their `revenue_delta` property is for plan-change reporting, not this sum.)

```sql
-- NRR: Monthly revenue retention including expansion/contraction
WITH monthly_revenue AS (
  SELECT
    person_id,
    DATE_TRUNC('month', timestamp) AS month,
    SUM(toFloat64(properties.amount)) AS revenue
  FROM events
  WHERE event IN ('purchase_completed', 'subscription_renewed',
                   'subscription_upgraded', 'subscription_downgraded')
    AND timestamp >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
  GROUP BY person_id, month
),
nrr AS (
  -- LEFT JOIN keyed on prev (the base period) so customers who fully churned
  -- (revenue last month, no events this month) stay in beginning_revenue and
  -- contribute 0 to ending_revenue via COALESCE. An INNER JOIN would drop them
  -- from both sides, hiding contraction-to-zero and inflating NRR.
  SELECT
    prev.month + INTERVAL 1 MONTH AS month,
    SUM(prev.revenue) AS beginning_revenue,
    SUM(COALESCE(curr.revenue, 0)) AS ending_revenue
  FROM monthly_revenue prev
  LEFT JOIN monthly_revenue curr
    ON curr.person_id = prev.person_id
    AND curr.month = DATE_ADD(prev.month, INTERVAL 1 MONTH)
  GROUP BY prev.month
)
SELECT
  month,
  ROUND(ending_revenue * 100.0 / beginning_revenue, 1) AS nrr_pct
FROM nrr
ORDER BY month
```

### Reading GRR vs NRR Together

| GRR | NRR | Diagnosis |
|-----|-----|-----------|
| ≥95% | >110% | Healthy — low churn, good expansion |
| 90-95% | 100-110% | The median zone — solid retention, modest expansion; pricing/packaging upside |
| ≥90% | <100% | Keeping customers but shrinking accounts — contraction problem, check packaging/seat counts |
| <90% | >110% | Masking churn with upsells — fragile, fix retention |
| <90% | <100% | Revenue shrinking — urgent, fix product or pricing |

Adapt these queries to your event schema. The load-bearing events are `purchase_completed` and
`subscription_renewed`, each carrying the recurring `amount`; plan changes flow through the next
renewal's amount (or ride `subscription_upgraded`/`downgraded` events — see the NRR schema note
above); cancellation is the *absence* of the next renewal, which the LEFT JOIN already handles.

---

## LTV Estimation from Cohorts

If cohort retention stabilizes, estimate LTV:

```
Estimated Lifetime (months) = 1 / Monthly Churn Rate at Plateau

LTV = ARPU × Gross Margin % × Estimated Lifetime

LTV:CAC Ratio Target: ≥ 3:1
CAC Payback Period Target: ≤ 12 months
```

The canonical 3:1 target (David Skok's SaaS metrics) assumes **margin-adjusted** LTV. Skipping the
gross-margin term overstates LTV by ~25% at typical 80% SaaS margins — and by 2x+ for low-margin
AI products — passing products that fail the real test.

If the plateau hasn't formed yet, use the most recent cohort's decay rate as a conservative estimate. Do not extrapolate from early, unstable cohorts.
