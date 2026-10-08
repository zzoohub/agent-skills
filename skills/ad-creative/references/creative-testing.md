# Creative Testing

Scope: the mechanics behind SKILL.md Stage 4, whose default rules live there: test tools, the odds behind each rule, the reads, small accounts, program sizing and the log. This file sizes a test before launch; a finished test's significance readout belongs to product-analytics' A/B analysis, if available, with the Test plan as its design record (α, power, lines, read dates).

## Test structures

As of 2026-10; confirm each tool on its live help page.

| Need | Structure |
|---|---|
| Read 2–5 new ads on Meta without starving them | Meta's creative test: one ad per cell (2–5 cells), each cell's share of a dedicated test budget set by you: keep the shares equal (developers.facebook.com/documentation/ads-commerce/marketing-api/guides/split-testing); moving the winner is your call |
| Two versions on TikTok | Split Test: the audience split in two so each person sees one version, creative as the variable (ads.tiktok.com/help/article/split-testing) |
| Isolate one variable | Meta: an A/B test in Experiments; Search: a custom experiment splitting the campaign's traffic |
| Change assets in a PMax asset group | asset experiments (beta; control vs treatment assets, 4–6 weeks recommended: support.google.com/google-ads/answer/16807329) |
| Any platform without a test tool | one ad set per concept on equal fixed budgets, the control in its own; winners move unchanged to the scaling campaign (reuse the post where allowed, so engagement carries over) |

A split test randomizes who is eligible, but delivery still chooses who sees each ad inside its cell, so a winner is this creative plus the people the system found for it: the right pick for that platform and setup, not proof the message works elsewhere.

## The odds behind each rule

Conversions per ad are small counts, so every kill or promote line is a bet with odds. With λ = spend ÷ the ad's true CPA (its expected conversions), the chance of zero conversions is e^(−λ); for any other count, `POISSON.DIST(c, λ, TRUE)` in a spreadsheet gives the chance of c or fewer.

| Kill rule | Kills an ad truly at target | Catches a dud at 2× target CPA |
|---|---|---|
| 0 conversions by 1.5× target CPA | 22% | 47% |
| 0 by 2× | 14% | 37% |
| 0 by 2.5× (default) | 8% | 29% |
| 0 by 3× | 5% | 22% |
| ≤1 by 2× ("CPA ≥1.5× target at 2×") | 41% | 74% |

Outcome kills catch few duds early; that is triage's job.

Promoting against a fixed target is as noisy: "at or under target CPA after 3× target spend" promotes 58% of at-target ads, 43% of ads 25% worse and 32% of ads 50% worse. The lines in SKILL.md Stage 4 are a one-sided test (α 0.10) on the log ratio of conversions per dollar, whose variance ≈ 1/c_variant + 1/c_control, about 2 ÷ n at n conversions per cell: line = 1 − e^(−1.28 × √(2 ÷ n)). They promote an ad equal to the control ~10% of the time and catch the table's gaps 75–80% of the time (exact Poisson calculation).

- **Cold start** (no control): against a fixed target only the variant is noisy (variance ≈ 1 ÷ n), so each line needs half the conversions: ≥37%, 28%, 21% and 13% at ~8, 15, 30 and 80 conversions expected at target, with the same or better odds. A non-creative shift breaks the comparison: re-base the target first (Reads).
- **Several cells**: the odds are per cell. A round of 3 cells promotes some ad no better than the control (or target) ~20% of the time, 5 cells ~30%. For ~10% per round, use the line for half the conversions (at ~30 per cell, ≥37% instead of ≥28%), which cuts the chance of catching a true winner to ~55%; otherwise keep the line and rerun a winner before a costly bet (a shoot, most of the budget).

**Leading indicators** reach precision in days: ~1,000 impressions per cell separate hook rates about 4 points apart; ~100 clicks per cell separate CTRs about 30% apart. They show who stopped and clicked, not who bought.

## Reads

| Read | When | Decides |
|---|---|---|
| Triage | once each ad passes the triage threshold (SKILL.md Stage 4) | kills duds on hook rate or CTR; never promotes |
| Outcome | the pre-set date, in whole weeks | promote, provisional (a second round), or retire as inconclusive |
| Matured cohort | the outcome date plus the outcome's lag (trial length, sales cycle, refund window) | confirms promotions on the judged outcome; reverses those that drew cheap, low-value converters |

- **No peeking**: promoting on the first day a cell looks ahead multiplies false wins. Stop early only for triage duds, broken tracking or a policy problem.
- **Same dates, whole weeks**: compare cells over identical days so weekday mix and auction conditions match; wait until the ad set's learning status settles (read the status, don't count events).
- **After a shift** (CPM, price, site, tracking, season, a delivery change): besides reading cells against the control (SKILL.md Stage 4), re-base the target with the media buyer before the next round.
- **Log who it reached** when promoting (promotion never waits on it): breakdowns (age, gender, placement, region; new vs returning) against the persona it was written for, or, for a situational persona no breakdown shows, survey answers and the ad's comments. A win with another audience still counts, logged against that audience.
- **Offer ads and harvesting**: offer ads (discounts, most-aware audiences) and wins mostly on returning customers take platform CPA partly from people who would have bought anyway: judge them on margin and new-customer share.
- **Graduates** move unchanged into the scaling ad set (the same post where allowed, so engagement carries over) and regress there: a winner was the best of several noisy reads. If most miss target in the scaling ad set, check its optimization event against the judged outcome before anything else (SKILL.md Stage 4).
- **Reach or awareness**: after a week, kill at ≥1.5× target cost per completed view (else the account median), promote at or under it.

## Small accounts

By optimized conversions per week (defaults):

| Per week | Method |
|---|---|
| ~50 or more | SKILL.md Stage 4 as written |
| ~10–50 | one campaign with 2–3 distinct concepts and the control live; every two weeks, replace the weakest on the judged outcome per dollar. At these counts only gaps near 2× show: call results directional and favor big-swing concepts over iterations |
| Under ~10, or slow conversions (B2B, high-ticket) | judge an earlier event shown to predict the real one (add-to-cart, qualified lead, trial start), with its own target cost; or test beliefs as organic posts and put spend behind the ones that earn it |

Costly or slow conversions lean hardest on triage (SKILL.md Stage 4): most duds should die on leading indicators before an outcome kill could fire.

## Program sizing

New ads a month ≈ live winners needed ÷ winner lifespan in months ÷ hit rate. Until the log holds the account's own figures, assume (and label) 3–6 live winners, each carrying a real share of spend at target on the judged outcome, a 2-month lifespan, and 1 new concept in 10 winning (iterations of a winner win more often). When budget or production can't supply that, raise the hit rate before the volume: stronger customer evidence, more iterations of winners. Flag one ad holding most of the spend as a risk.

- **New vs iterated**: all new until something wins, then about a third new.
- **Production mix**: mostly the cheapest credible executions (SKILL.md Stage 2), shoots only for proven concepts or beliefs only motion can carry; budget by cost per usable ad: cost per attempt × attempts per keeper, measured on the first batch (AI-made: `references/generative-tools.md`).
- **Peak windows** (sales events, launches): bank winners before; during, run offer executions of proven concepts and pause net-new tests.
- **Waves**: order the queue by the learning question each wave answers; a wave waits for the result it depends on, never for a calendar date alone.

## The iteration ladder

From a winning ad, change one rung at a time, cheapest first:

1. **Hook**: a new first frame, then first line, then VO opening, over the same body.
2. **Creator or format**: the same script from another creator; the same belief as a static, a carousel or a demo.
3. **Proof or offer**: testimonial ↔ demo ↔ statistic; guarantee or trial framing.
4. **Platform-native cut**: the TikTok, Reels or Shorts version, transformed rather than resized.

Iterations usually move results less than the smallest gap a modest budget detects (SKILL.md Stage 4): read them on leading indicators, or pool several rounds. When two rungs in a row fail to beat the control, check for fatigue (SKILL.md § Diagnose) before climbing further: the concept, not the execution, may be wearing out.

## Learning log

Write each cell's hypothesis before launch, in the Test plan's cell table (SKILL.md Output): `If [persona] buys [belief] (evidence: [source]), [variant] beats [control] on [judged outcome per dollar]; a loss teaches [X].` Budget, expected conversions and detectable gap fill the other columns; rules, odds and read dates are set once per round.

Then log one row per ad per round, appended to the campaign's file (default `biz/marketing/assets/{campaign-slug}.md`; caller may redirect):

| Ad name (tags) | Spend (× target CPA) | Conversions; outcome per dollar vs control | Result vs rule | Who it reached | Why, in one line | Replicated? |
|---|---|---|---|---|---|---|

Ad names carry the tags (SKILL.md Stage 2), so rows roll up by concept, persona, belief and format. A row without a why is not a learning. Each round, roll the rows up by tag (which beliefs and personas won, which personas are fatiguing, which concepts were retired and why). Only replicated learnings enter the playbook; one-off wins go back in as hypotheses.
