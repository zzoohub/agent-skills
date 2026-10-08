# A/B Test Results Analysis

**Layer:** experiment **analysis** only; design (sizing, ramp, the test card) belongs to the **cro** skill, if available.

## 1. Read the Design Record

Start from the test card in the experiment log (default `biz/growth/experiments.md`; caller may redirect). Its pre-registered Ship / Iterate / Kill rule governs the call; §4 is the default when the card has none.

α belongs to the card, never to the analysis: stricter (e.g. 0.01) for one-way or high-stakes changes such as pricing, looser only for cheap, reversible calls. No record → assume α 0.05 two-sided, 80% power, the change's target outcome as primary and revenue per user as guardrail; state the MDE and margin you assumed, and label the readout "exploratory: no pre-registered design".

Sanity-check power: n per arm ≈ 16·p(1−p)/δ² at 80% power and α 0.05, with δ the absolute MDE; a holdout beside a far larger treated arm needs ≈ 8·p(1−p)/δ² by itself. An underpowered test can't show "no effect", only "inconclusive".

## 2. Validity Before Results

- **Sample ratio mismatch (SRM):** chi-square on assignment counts against the planned split, at a strict threshold (p < 0.0005–0.001; Microsoft's platform uses 0.0005). The raw ratio can't tell: 48/52 is noise at 1,000 users and a bug at 100,000. SRM invalidates the readout: find the cause (assignment after filtering, bots, a redirect dropping one arm), fix, rerun.
- **Pre-period balance** (returning units): compare the arms on the primary metric over the 2 weeks before exposure. A gap comparable to the measured effect means a bucketing bug or carry-over from an earlier test on the same buckets: re-salt the assignment and rerun.
- **Exposure rule:** when exposure rates match by arm (next bullet), use the platform's readout. A hand-written query must replicate it: assign at first exposure, exclude units that saw several variants, count outcomes only after exposure.
- **Assigned → exposed, per arm:** count eligible, assigned and exposed units in each arm and account for every assigned-but-unexposed unit (never returned, became ineligible, logging gap). Control must log the trigger counterfactually, where it would have seen the change. Exposure rates differing by arm (test them like SRM) mean the treatment changed who reaches the trigger: make all assigned units (intent-to-treat) the primary read and the exposed-only cut secondary.
- **A primary the treatment prompts:** when the variant itself asks for the primary's action (an invite prompt read on invites sent, a banner read on its own clicks), the primary rises by construction. Read the next downstream step (invites accepted, activated invitees, repeat use) per assigned unit in both arms; if it doesn't move, report the primary's lift as mechanical and decide on the downstream step, noting the deviation from the card.
- **Unit and interference:** analyze at the randomization unit (account, inviter or cluster: cluster-robust errors or per-cluster aggregates). Marketplaces, social and referral features leak treatment across arms: flag it; the design should randomize by cluster or switchback.
- **Runtime:** whole weeks at the fixed split; ramp days excluded, since a split that changes mid-test confounds time with arm.

## 3. Looking Early

Before the planned n, stop only for harm or bugs (SRM, a guardrail past its margin, errors); an interim CI spanning 0 and the MDE means keep running, not Iterate. Never stop early for a win unless the design is sequential with a pre-registered boundary: stopping at the first p < 0.05 on daily looks multiplies false wins.

"Keep running" is not the whole interim read. Pre-commit the call for each plausible final CI (template), so a flat ending can't be recast as a win later, and name what an early rollout would disturb: control units still inside their outcome window (switched mid-window, so their outcomes mix both arms), the planned n and α, the novelty read, guardrail power, and other tests on the same users. A rollout that can't wait keeps a holdout.

## 4. Decide From the Primary CI

| Primary-metric CI at the planned n | Default call |
|---|---|
| Lower bound > 0; every guardrail shown non-inferior | **Ship** (point estimate below the MDE: a maintenance-cost call, ship only if ~free to maintain) |
| Inside ±MDE, containing 0 | **Kill**: no meaningful effect. Keeping the change anyway is a product decision on standalone value against maintenance cost, never reported as a win |
| Contains 0 and reaches past ±MDE | **Iterate**: inconclusive; keep control, rerun bolder or larger as a new test, never extend this one |
| Upper bound < 0 | **Kill**; record what was learned |
| Any guardrail's CI reaches past its margin | Don't ship, whatever the primary says: **Iterate** if the harm is fixable, else **Kill** (unpowered guardrail: §5) |

## 5. Metric Family

- The primary metric decides, uncorrected in a two-arm test. Pre-registered arms against control are a confirmatory family: control the family-wise error across them (Holm, or Dunnett) and decide without a rerun.
- Guardrails get one-sided non-inferiority tests against their margins. A guardrail whose CI half-width exceeds its margin at the planned n was never powered: write "guardrail unpowered" and ship only a reversible change, holding out a slice after launch to watch that metric.
- Secondary metrics explain the mechanism; they never rescue a flat primary.
- Unplanned segments and arms are exploratory: correct with Benjamini–Hochberg, then confirm with a rerun. Segments belong in the card; a segment win inside a flat total is a hypothesis.
- A test that can't be powered ramps on guardrails only and is reported as directional.

## 6. Statistics That Change the Call

- **Ratio metrics** (analysis unit ≠ randomization unit, e.g. clicks per session or average order value with users randomized): delta method, or a bootstrap by randomization unit. Revenue per user, randomized by user, is a per-unit mean: a t-test is valid; cap its heavy tail at a pre-registered percentile (p99–p99.9), and CUPED (a pre-period covariate) can then cut the remaining variance.
- **Sequential** designs: read their always-valid intervals, wider at any given n than fixed-horizon ones.
- **Bayesian** readouts: "chance to win" is not an effect size. Read the credible interval against the MDE like a CI; stopping the first day the probability crosses 95% inflates false wins like p-value peeking. Note which engine the platform ran.

## 7. Novelty and Change Aversion

Plot lift by days since first exposure, split new vs existing users. New users, who never saw control, lifting like existing ones → not novelty. Existing users negative, then recovering → change aversion: wait before calling. Under 2 weeks of exposure → write "novelty unassessed".

## 8. Revenue Impact

- Size impact on the triggered population (users who saw the change), with revenue per converting user for conversion lifts and the post-novelty lift (§7), never the whole-run average.
- Commit to the CI's lower bound: a winning test's point estimate is inflated (winner's curse).
- Recompute the lift without the top contributors (the top 1% of units by the metric, or the largest accounts): a lift that vanishes without them is theirs, not the population's; name them.
- A lift above 2× the planned MDE → check instrumentation first (Twyman's law).
- Never sum test wins into a forecast; a standing holdout measures cumulative impact.

## 9. Holdout and Creative Readouts

- **Program holdouts** (lifecycle email, save offers, referral programs): lift = treated − holdout on the program's primary outcome per eligible unit, with a CI, at the planned horizon.
- **Referral programs:** tracked referrals include word of mouth that would have come anyway; the true effect is on total signups, readable only under cluster randomization (market, company domain, team). With an inviter-level holdout, record attribution the same way in both arms (unrewarded share links, "who referred you?") and compare referred signups per eligible user.
- **Ad creative tests:** platform split tests suffer divergent delivery — each creative reaches a different audience mix, so the winner is creative plus audience (Braun & Schwartz, Journal of Marketing, 2025): the right pick for that platform and campaign setup, but no evidence that the message works elsewhere. To test the message itself, randomize who sees it (a landing-page or email test). Read cost per outcome with CIs, then the cohort quality each creative brought (`utm_content`; retention reference § Channel Quality).

## Experiment Report Template

Output: `reports/{experiment}-results.md` in the analytics dir (default `biz/analytics/`; caller may redirect).

```markdown
# Experiment: [name] — [Ship | Iterate | Kill | interim: no call] ([card rule | default: CI vs MDE])
<!-- ≤300 words + the results table and queries; decision first; sections are a menu: omit what doesn't apply, heading included -->
**Decision:** [call] — confidence [high | med | low: SKILL.md scale], because [one line]
**Design:** [card link] · unit · primary · α · MDE · planned vs actual n · dates · [pre-registered | exploratory]
**Validity:** SRM p = [x] · eligible → assigned → exposed per arm · pre-period balance · exposure rule · runtime · interference [none | flagged] · primary prompted by the treatment [no | downstream step per arm]
| Metric | Role | Control | Variant | Δ (95% CI) | MDE / margin | Read |
**Segments:** [pre-specified; anything else labeled exploratory]
**Novelty:** [by days since exposure | unassessed (<2 weeks)]
**Impact:** [triggered population, post-novelty lift; CI lower bound per year; without the top contributors]
**Interim: final CI → call:** [lower bound > 0 → … · inside ±MDE → Kill; keeping it is a maintenance-cost call, not a win · spans 0 and past ±MDE → Iterate as a new test · upper bound < 0 → … · a guardrail past its margin → don't ship] · an early rollout would disturb: [control units mid-window, n, novelty read, guardrails, other tests]
**Learning and next step:** [what we learned] · [ship | rerun bolder or larger | remove; flat or sub-MDE → keep only for standalone value worth its upkeep] — owner, date
```
