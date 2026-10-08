---
name: product-analytics
description: |
  Measures a product to drive a decision: tracking plans and GA4/UTM setup,
  metric definitions, dashboards and weekly reports, funnels, retention cohorts,
  PMF, Carrying Capacity, GRR/NRR, LTV, live K, health-score backtests, A/B,
  holdout and ad-creative test readouts, and kill/keep/scale calls (double
  down/hold/drop for a login-less content site). Use for "why did X drop",
  "read this test", "is this PMF", "set up tracking".
  Do NOT use for: experiment design or conversion fixes (cro), the K model
  (growth-loops), health-score design or churn interventions (churn-prevention).
---

# Product Analytics Methodology

Analytics exists to change a decision: name it first, distrust every number until the data-trust gate clears it, and judge a move against its noise band, a causal claim against its design, a verdict against criteria written before the data.

## First: Pick the Analytics Frame

| If the product is… | …use this frame | Spine |
|---|---|---|
| **A logged-in product** — persistent identity, repeat use (SaaS, app) | **Product frame** | Aha Moment → Retention → Carrying Capacity → Kill/Keep/Scale |
| **A login-less content / marketing site** — mostly anonymous browsing, conversion = a lead/inquiry (blog, docs, lead-gen) | **Content-site frame** (`references/content-site-analytics.md`) | Acquisition → Engagement → Conversion (lead) → double down / hold / drop |

A content site has no persistent identity or repeat-use curve: Aha, cohorts, Carrying Capacity (CC), PMF and health scores don't apply.

**Hybrid** (a product plus its marketing site): content-site frame pre-signup, product frame post-signup. State the split; never average metrics across the seam.

**Product frame: fix the unit and the clock before computing.** Unit of analysis:
- self-serve SaaS → the account (workspace); user actions still define activation;
- sales-led B2B → logo + revenue (GRR/NRR); too few units for CC or per-user curves;
- consumer app → the user;
- commerce → the buyer; retention = a repeat purchase within the interval;
- marketplace → each side; scarce-side liquidity before any other read.

Natural usage interval ≈ the 80th percentile of users' median gaps between core actions (users with ≥3 of them), rounded up to a day, week or month. Measure retention in periods of that length: a yearly product judged monthly looks dead.

## Then: Name the Request

| Request | Done means | Writes (default) | Budget (words) |
|---|---|---|---|
| Instrument | every in-scope metric is computable; identity and money rules set | `tracking-plan.md` | event table + ≤300 |
| Define, monitor | metrics defined (an outcome tied to the decision, 3–5 inputs, a counter-metric each), banded and owned | `dashboards.md`, `reports/week-YYYY-WW.md` | ≤250 + table |
| Assess (retention, PMF evidence, CC, GRR/NRR, LTV, channel quality) | curves at the natural interval: n, plateau and late decay per pre-specified segment, activated vs all | `funnels.md` § Retention; CC in `kill-criteria.md`; `reports/{topic}-analysis.md` | ≤400 + tables |
| Explain (a move, a funnel) | real, localized and timed, with a cause, what would disprove it and who carries it — or "no signal" / "data issue" | `reports/{topic}-analysis.md`, `funnels.md` | ≤400 |
| Discover (Aha) | candidates ranked by lift; a validation test designed | `reports/aha-analysis.md`; definition and status in `tracking-plan.md` | ≤400 |
| Evaluate (A/B, holdout, launch) | a decision read from the CI against pre-registered thresholds, after the validity checks (no test: principle 3) | `reports/{experiment}-results.md` | ≤300 + table |
| Score (health) | backtest cleared before any band drives action | `health-score.md` | ≤300 + tables |
| Verdict | the call against criteria written in advance, what to fix next and, when it moves spend, the spend plan | `kill-criteria.md` | ≤500 + tables |

**Budgets size the write-up, never the analysis.** Run every check (gate, numbers, traps) in full, then write to budget: a one-number question gets the number, its definition, n, its noise-band read and each material finding, one line each, no template. Never cut a material finding to fit: compress it, move detail to an appendix, or exceed the budget and say why. Queries, code and tables don't count.

**Answer the decision, not just the request.** Evidence that puts the real problem elsewhere (a broken definition, a primary the treatment itself prompts, a channel buying users who never activate, a contradicted premise) leads the write-up, fixed or handed off with an action, owner and closing check. State any scope cut and why.

**No verdict unless asked or a pre-committed threshold is crossed**; otherwise write "no call" and why.

**Output:** the analytics dir (default `biz/analytics/`; caller may redirect), under the names above, updated in place. Every number comes from a saved query or script, linked or in the deliverable's appendix, parameterized by an as-of date so it reruns. Without file-write, return results inline, queries included.

**Read first** (defaults; caller may redirect): `tracking-plan.md`, `dashboards.md` § Definitions, `kill-criteria.md`, `funnels.md` and the latest report in the analytics dir (the figures leadership has seen); for a readout, its test card (`biz/growth/experiments.md`); the changelog for the compared periods (releases, campaigns, pricing, tracking-code history) — ask the caller where it lives.

**Ask once, in one batch**, only what changes the output, each with its default; a subagent that can't ask applies them as labeled assumptions and lists the questions.
- Which decision does this serve, and who owns it? (none named → describe, no call)
- Shape, unit, natural usage interval? (inferred from the data, stated)
- Reachable data and cohort sizes? (what the tools expose; principle 1)
- Where does revenue live? (no billing access → event-derived MRR labeled "unreconciled")

## When to Use Which Reference

| Task | Reference |
|---|---|
| Content/marketing site: acquisition, engagement, leads, double down / hold / drop | `references/content-site-analytics.md` |
| Aha Moment discovery and validation; activation rate | `references/aha-moment-discovery.md` |
| Retention cohorts, PMF evidence, GRR/NRR, LTV, payback and spend gates, funnels and drop-off, channel quality, health-score backtest; worked queries | `references/retention-analysis.md` |
| Carrying Capacity, live K, kill-criteria record and spend plan, metric definitions and dashboards, weekly report | `references/carrying-capacity.md` |
| Tracking plan, event naming, identity, server-side events | `references/event-tracking-design.md` |
| GA4, GTM, UTM, AI-assistant channel, consent mode, server-side tagging | `references/ga4-gtm-setup.md` |
| A/B, holdout and ad-creative test readouts, interim reads | `references/ab-test-analysis.md` |

## Before Any Number: Data-Trust Gate

A surprising number is a bug until checked:
- definitions, events and pipeline unchanged across the compared periods (deploys, SDK upgrades, renames, consent changes);
- periods complete (ended, and ingestion caught up: mobile SDKs send offline events days late) and cohorts mature; incomplete cells blank, never 0;
- internal, test and bot traffic excluded; identity merges and timezone consistent;
- totals reconciled with billing or the app database. Client-side counts run below server truth; watch that gap for drift, not its size.

A failed check is the finding: report it instead of the metric, then replace what broke (corrected definition, its query, the value it gives), flagged "untested" until reconciled with a second source. Overturning a figure leadership has seen adds a what-changed table and the likely objections answered, one line each. **Break when** a live incident needs numbers now: report them, labeled unverified.

## Explaining a Move

1. **Real?** Run the gate, then the noise band: mean ± 3 SD of the last 8–12 comparable periods (same weekday or point in the month; holidays and launches excluded; a trending metric bands its period-over-period change). A holiday or launch period compares with last year's, scaled by normal periods' year-over-year change. Two consecutive periods beyond 2 SD on one side also count; a new 8-period high or low doesn't (2 in 9 by chance). Inside the band, write "within normal range" with the band's width (smaller moves need a longer window or a test) and stop; a real move too small to change a decision gets one line.
2. **Decompose** down the metric tree (`dashboards.md` § Definitions) to the term that moved. No tree on file: active = new + retained + resurrected; ΔMRR = new + expansion + reactivation − contraction − churn; a rate splits into numerator and denominator; conversions = Σ traffic × rate, per source. Share of move = the term's Δ ÷ the total Δ. Run the influence check (principle 4) inside the moving term.
3. **Localize** where the tree points, ≤5 pre-specified cuts (never slice until something moves; a one-segment finding is a hypothesis until it replicates): platform/version, country, channel, new vs returning, plan. Distinct users don't add across days, platforms or segments: reconcile segment totals with the total first. Split mix from rate, Δ = Σ Δshare × old rate + Σ new share × Δrate: a total can fall while every segment rises.
4. **Time it.** A step change points to deploys, incidents, tracking, campaigns or pricing — read the changelog first. A slope points to cohort quality or seasonality.
5. **Conclude**, leading the write-up with:

```markdown
<!-- ≤400 words; queries in an appendix; sections are a menu: omit what doesn't apply, heading included -->
**Answer:** real | no signal | data issue — where — when — likely cause; confidence [high | med | low]
| Term | Before | After | Δ | Share of move |
**Carried by:** [top k units] = [x]% of the move; without them Δ = [y]
**What changed** (overturning a figure leadership saw): | Figure | Was | Now | Why |, then likely objections answered, one line each
**Disproved if:** … · **Next check, owner:** …
```

**Confidence**, in every write-up: high = gate passed, clear of the band or threshold, and the cause survived a check that could disprove it (randomization counts); med = real, cause inferred from timing alone; low = near the edge, data partly unverified, or the cause a guess.

## Verdicts

Product frame only (content sites: per cluster and channel, content-site reference).

**Criteria first.** Write each criterion (metric, threshold, review date) in `kill-criteria.md` before the data; a later change needs a written reason. Thresholds below are defaults: a criterion on file overrides them; label any default applied. Asked for a call with none on file: write them before reading the outcome metrics and label that first call provisional. The record, its fix order and the spend plan: CC reference.

**PMF evidence:** (a) the activated cohort's curve flattens at the natural usage interval; (b) newer cohorts flatten at or above older ones. CC, organic inflow and a Sean Ellis "very disappointed" share ≥40% support a call, never decide it.

| Call | When | Break when |
|---|---|---|
| Kill / pivot | ≥3 consecutive cohorts, each ≥8 intervals old, and none flattens overall | a pre-specified segment flattens in ≥2 consecutive cohorts → narrow the product to it; interval over a month → ≥3 intervals plus repeat-intent and referral signals, provisional |
| Keep | a curve flattens, or a pre-specified segment does in ≥2 consecutive cohorts, but (b), activation, economics or volume fails | — |
| Scale | (a) and (b), plus observed gross-margin payback per paid channel within a fundable horizon (12 months; margin-adjusted LTV:CAC ≥3 on a lifetime capped at 36 months), with the organic share of inflow beside it | — |

One-off jobs (a wedding, a home purchase) have no repeat curve: judge referrals and repeat need.

**Spend.** A call that moves spend sets per channel a monthly cap; a leading gate, the maximum cost per activated unit back-solved from the payback bar (retention reference § LTV and Payback); a stop-loss, the spend after which a missed gate stops the channel; and a review date when those cohorts' retention matures. Before (a) holds, spend is a capped test, never a scale. Raise a cap at most 2× a step, judging each step on its incremental cost per activated unit: an average under the gate can hide a step above it. Paid cohorts retaining below organic at the same age: pause at the stop-loss, fix what the channel optimizes for and seeds from, and re-test under the cap before cutting it (retention reference § Channel Quality).

## Analysis Principles

1. **Small numbers require humility.** Give n and a 95% CI with every rate; a result is directional exactly when its CI straddles the decision threshold (n = 100 at 20% → ±8 pp). Under ~500 users: absolute counts beside rates, monthly or rolling 4-week windows, no week-over-week verdicts, and interviews alongside the numbers.
2. **Speed for reversible calls, rigor for one-way ones.** A dashboard change ships on a directional read; a kill, an Aha definition or a pricing change gets the full method.
3. **Ask for a holdout before the launch**, sized for the smallest effect worth acting on (A/B reference § 1) and kept until the decision metric matures (retention: ≥4 intervals); too small a base → 50/50 for a fixed window. After the fact, one series' before/after isn't evidence: use a staggered rollout or difference-in-differences against an untouched group with ≥4 parallel pre-periods, or write "coincided with". "Feature users retain 2×" is selection until a test says otherwise.
4. **The average hides who carries it.** For each aggregate a call or headline rests on (NRR, revenue growth, a lift), report the top contributors' share and the value without them; when a few units or one segment carry it, name them and say what holds without them. This check always runs; exploratory slicing waits for a move (step 3).

## Self-Review

Before returning, check:
- It meets its request's "done means"; the answer and its confidence (scale above) lead; frame and unit are stated; a problem found beyond the request leads, fixed or handed off.
- Every number has its definition, a complete period, n and a saved query keyed to an as-of date; every comparison a CI or the step-1 noise band; every aggregate a call rests on, its top contributors' share and value without them.
- The gate passed, or its failure leads with a replacement definition flagged untested (plus the what-changed table if leadership saw the old figure).
- Thresholds, definitions and dates are identical in every file one analysis touches; no slot holds an underived estimate ("not computable: [reason]" instead).
- A call that moves spend has its cap, gate, stop-loss and review date; an interim test read maps each final outcome to its call.
- Causal verbs ("caused", "drove") only with randomized, staggered-rollout or difference-in-differences evidence; exploratory segments and applied defaults labeled.
- A verdict cites criteria dated before the data, or reads "no call: [reason]".
- Benchmarks are sourced, dated and denominator-matched, or absent.
- **Footprint:** prose within the request's word budget (code and tables excluded), or over it with the reason stated; no material finding cut to fit; the deliverable reports findings and never narrates this method.
