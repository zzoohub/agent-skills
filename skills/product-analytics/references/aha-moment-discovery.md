# Aha Moment Discovery

## Definition

The Aha Moment is the early action that predicts long-term retention, and, once validated, drives it:

> **"[Action X] within [Y days] of signup, [Z times]"**

Canonical examples (Facebook's "7 friends in 10 days") are folklore: other products' discoveries, not targets.

## Discovery Process

1. **Cohorts.** Take every signup from cohorts whose outcome window has fully elapsed. Never start from preselected power users: that selects on the outcome.
2. **Candidates.** List 5–10 actions that deliver core value early (created a first project, invited a teammate, connected an integration), not vanity or forced steps (viewed settings, finished a mandatory tutorial). Compute them from raw events, so the hypothesis can change without re-instrumenting.
3. **Windows.** Count the action only in [0, Y]; measure retention strictly after Y (for a weekly product: active in weeks 5–8). An outcome window that overlaps Y leaks the outcome into the action.
4. **Score each candidate** on the 2×2 (A = did and retained, B = didn't and retained, C = did and churned, D = didn't and churned):
   - **retention predictive value (RPV)** = P(retained | did) = A/(A+C);
   - **coverage** = A/(A+B), the share of retained users who did it;
   - **lift** = RPV ÷ P(retained | didn't) = [A/(A+C)] ÷ [B/(B+D)].

   Compare users with the same number of early active days: an action that doesn't beat plain "active days" only measures engagement. Example: "invited a teammate in week 1" shows 3× lift overall but 1.2× among users active 4+ days that week; the invite mostly marks engaged users and ranks below an action that keeps its lift inside each activity band. Prefer high lift with useful coverage; a rare action with huge lift reaches too few users to steer onboarding.
5. **Sweep (Y, Z)** for the strongest candidates: frequencies such as 1, 2, 3, 5, 10; windows matched to the natural usage interval.
6. **Multiple-comparisons guard (FDR).** Candidates × frequencies × windows make dozens to hundreds of hypotheses, so the peak you pick is partly noise. Treat the sweep as exploratory: control the false-discovery rate (Benjamini–Hochberg across candidates), or re-check the winning (X, Y, Z) on a holdout cohort the sweep never saw. Only step 7 confirms it.
7. **Validate with an encouragement test.** Nudge a random half of new users toward the action. Retention gain ÷ uptake gain estimates the action's effect: if the nudge lifts uptake from 20% to 35% (+15 pp) and retention from 30% to 33% (+3 pp), each extra adopter gains about 3 ÷ 15 = 20 pp of retention. Uptake up with retention flat means the action marks engaged users; it doesn't cause retention. The ratio holds only if the nudge moves retention solely through the action: nudge in-product at the moment of eligibility, never by email or push, which bring users back on their own (otherwise read the ratio as an upper bound). It measures the effect on users the nudge moves, not on everyone.

After adoption, the action becomes a target and can be gamed: check that nudged users retain like those who did it unprompted. Run the analysis per persona when personas use the product differently, and again after major launches.

## Activation Rate

Activation rate = signups who reach the Aha Moment ÷ signups, per cohort; time to Aha = median time from signup. Judge both against your own earlier cohorts: external activation benchmarks don't transfer across Aha definitions.

## Tooling

Funnel correlation features (PostHog's correlation analysis) only shortlist candidates; compute RPV, coverage and lift yourself. Emit `aha_moment_reached` only after validation (event-tracking reference).

**Output:** `reports/aha-analysis.md` in the analytics dir (default `biz/analytics/`; caller may redirect; ≤400 words plus the table; sections are a menu): the candidate table (action · window · frequency · RPV · coverage · lift overall and at equal active days · n), the FDR or holdout check, and the encouragement-test design. Only the definition and its status go to the tracking plan.
