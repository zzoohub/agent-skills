# Experiment Design

**Layer:** experiment **design**, fixed before launch; the readout lives in `product-analytics/references/ab-test-analysis.md`, via that capability if available.

## Test card

The card is the experiment-log entry (default `biz/growth/experiments.md`; caller may redirect), one per test, updated in place. Other skills' tests (referral programs, save offers, email holdouts) use it with their own unit and holdout. Budget: ≤320 words filled; omit lines that don't apply, except Eligible, Multiplicity, Calendar and Checks, which say "n/a" and why.

```
### EXP-nn: [name] — designed | running | concluded
Hypothesis: Because [evidence, tagged observed | analog | best-practice], we believe [change] will move [primary] for [audience], because [mechanism].
Change: [the one difference between arms; a bundle names what it can't attribute]; defects found while designing ship to every arm before launch
Primary: [outcome per exposed unit] within [window from first exposure]; baseline [x]; [MDE r% | non-inferiority margin −M%]; decided on [the primary | a validated proxy, the primary a delayed guardrail | a proxy, shipping only if the primary leads]
Guardrails: [metric — margin — readout horizon | unpowered], …
Eligible: [who], fixed at first exposure from attributes known then; excluded [bots, staff, existing customers, …]
Unit: [user | account | inviter | cluster] on [anonymous ID carried through signup | user ID | account ID]; exposure: [event where the arms first differ], logged in every arm
Segments (≤3, pre-specified; others exploratory): [..]
Multiplicity: [ways to win: arms, primaries, segments, looks] → [none | Holm or Dunnett | alpha spending]; guardrails cost power, not α
Split: [50/50 | arms + holdout share]; ramp [x% for y days, excluded]
Sample: [N per arm] at [one- | two-]sided α [x], power [y], [fixed | sequential: looks, boundaries | Bayesian: rule]; enroll [whole weeks]; decide on [date]
Ships: [x%] with no effect, [y%] at the MDE, [z%] when only the proxy moves
Calendar: [dates]; events inside the window (§ Design rules) → [how handled]
Checks: outcome count vs [system of record], gap [x%]; [A/A | dry run] of assignment and logging; SRM watched daily (p < 0.001)
Decision (defaults; change only with a reason): Ship if the primary (or its guarded proxy) wins at α (estimate under the MDE: only if ~free to maintain) and every powered guardrail holds its margin; Iterate, as a new test, if the CI spans 0 and the MDE but a diagnostic shows the mechanism moved, or a guardrail failed fixably; else Kill; never extend. Stop early only for SRM, broken tracking, errors, a guardrail past its margin at p < 0.01 on a weekly look, or a pre-registered boundary.
Readout: [default biz/analytics/reports/{experiment}-results.md]; Outcome: [at conclusion]
```

## Sizing

Choose the MDE from the business case: the smallest lift that pays for building and maintaining the change, never one back-solved from your traffic.

**Rules of thumb** (80% power, two-sided α 0.05; p = baseline, r = relative MDE):
- **Conversion**: users per arm ≈ 16 × (1 − p) ÷ (p × r²), about 16 ÷ r² conversions per arm below a ~10% baseline; size the final N with your analysis's method (this runs up to ~7% low).
- **Revenue or margin per exposed user**: users per arm ≈ 16 × CV² ÷ r², CV = SD ÷ mean of per-user value (zeros included) in recent eligible traffic; at low baselines about (1 + CV² of order value) × the conversion N. Pre-register a winsorizing cap; if that N doesn't fit, conversion becomes primary and revenue a guardrail.

**Expect small effects.** Check the MDE against all your log's concluded tests, not only winners, whose estimates run high; without a log, across 1,001 tests the median observed lift was under 0.1%, the mean about 2% (Analytics-Toolkit, 2022). 20%+ usually takes a defect fix or a new offer. If realistic effects sit below the MDE, the change can't pay: don't test it. If ~1 tested idea in 10 works (published success rates 8–33%; Kohavi, Deng and Vermeer, KDD 2022), ~1 significant win in 5 is false at α 0.05 and 80% power, ~1 in 3 at 50%: replicate surprising wins.

**Capacity**: tests per quarter on a surface ≈ 13 × weekly eligible users ÷ (arms × N per arm). Spend it on the largest sized leaks.

**Program impact** (roadmaps): expected gain ≈ Σ (weekly outcomes through each tested step × its MDE) × your log's win rate (none: ~1 in 10), capped per leak at its sized ceiling; never a sum of hoped-for lifts. Where traffic allows, a standing holdout kept from every shipped change for a quarter proves it.

## When the default N doesn't fit: design the decision

A test is a decision rule with error costs, not a ritual at α 0.05. When the default N won't fit ~4 weeks, price each rung, alone or combined, in weeks to a decision; never run an underpowered fixed test and peek. Where to start, by weeks the default N needs: up to ~12, error rates set by cost (×0.36–0.57) or a longer window usually close the gap, and pre-registered looks shorten the expected run, never the maximum; beyond that, a guarded proxy or a bolder variant; failing those, a rollout with its blind spot stated.

1. **A bolder variant**: N scales with 1 ÷ MDE², so doubling a realistic MDE quarters it.
2. **Error rates set by cost.** α is the rate of shipping a change that does nothing; shipping a real loss is far rarer. Loosen α when a neutral change is free to keep and a loss would be caught and reverted; keep 0.05 or stricter for one-way doors, pricing and changes costly to maintain. A loose-α ship shows the change is unlikely to hurt, not that it lifts (at 1-in-10 success, ~2 in 3 one-sided-0.20 wins are null): log it as shipped, lift unproven, and leave it out of the win rate (§ Sizing). N scales with (z_α + z_power)²; against the default (two-sided 0.05, 80% power):

| One-sided α, power | × default N | Ships a no-effect change | Ships a loss of the MDE | Ships a loss of half the MDE |
|---|---|---|---|---|
| 0.05, 80% | 0.79 | 5% | <0.1% | 0.2% |
| 0.10, 80% | 0.57 | 10% | <0.1% | 1% |
| 0.20, 80% | 0.36 | 20% | 0.6% | 5% |
| 0.20, 60% | 0.15 | 20% | 3% | 8% |

3. **A higher-volume proxy** nearer the change (plan selection for paid conversion, a first key action for activation). Validated in past tests here, it may decide, the outcome a delayed guardrail. Unvalidated, it decides only if the outcome's estimate also favors the variant: when only the proxy moves, that guard roughly halves the false ship rate (to about a third if the outcome must reach one-sided p < 0.30), at some cost in power; simulate to choose. Log each proxy test's outcome, so the proxy earns validation or is dropped.
4. **Variance reduction**: CUPED with a pre-period covariate multiplies N by (1 − ρ²); halving it needs ρ ≈ 0.7, and new visitors have no pre-period.
5. **A longer window**, bounded by identity and the calendar, not a week count. Re-bucketing a share c of units (lost anonymous IDs, cross-device journeys) shrinks the measured lift by about c, so N grows ~1 ÷ (1 − c)²; estimate c from recognizable users (logged in, arriving from email) who saw both arms. Plan the window to end before that loss, or a calendar shift ahead (a season, a price change, a launch), outweighs the added sample, and never lengthen a running test; server-side assignment on a user or account ID removes most of the identity limit.
6. **Pre-registered looks.** A group-sequential design (four looks, an O'Brien–Fleming-type efficacy boundary, a futility stop when the estimate is negative midway) ends on average at ~65–90% of the fixed N, earliest when the effect is large or absent, and runs at most ~2% past it. A Bayesian rule (ship when the expected loss of shipping falls below a threshold of caring) prices the asymmetry directly, but its error rates aren't guaranteed: simulate them. Choose the mode before launch; never switch mid-test.
7. **No test**: Fix, Ship & watch (§ Rollouts without a test), or Research (a painted-door test gauges demand before building).

**Price, then check the rule.** List each viable design with its weeks to a decision. For the chosen rule, get the three ship rates the card records: for a one-sided z rule, P(ship) = Φ(true effect ÷ SE − z_α); simulate when it combines metrics or looks. Tune α, the guard and the window until the rates match what each mistake costs.

Bandits and auto-allocation suit only short-lived choices with an immediate outcome (a promo headline): their shifting split confounds time with arm.

## Rollouts without a test

Before launch, Ship & watch sets its guardrail thresholds and:
- **A comparison**: an untouched market, platform or segment; a staggered rollout (groups switched on in random order, a week or more apart); or a 5–20% holdout.
- **A rollback rule with its blind spot stated.** Backtest it on your last 26–52 weeks: replay it with no change (false alarms), then with the smallest loss worth catching injected (misses). False alarms grow with the watch: with independent weeks, the default rule fires by chance ~5% of the time over 4 weeks and ~16% over 12; trend and seasonality add more. If the rule misses the smallest loss worth catching more often than not, say so ("can't see a loss under ~X%") and narrow it: a holdout, a comparison series that shares your seasonality (their gap is quieter than either series), a longer watch.

## Design rules

- **Test one thing, or you won't know what worked**: one hypothesis per variant; bundle only changes that serve one mechanism, and write on the card what the bundle can't attribute.
- **Non-inferiority** when the change ships for another reason (a redesign, re-platform, compliance change, cost cut or removed field): test that it is no worse than −M, the largest loss that reason pays for; one-sided α 0.05, N ≈ 0.8× the two-sided N at an MDE of M; Ship then means the CI stays above −M. Test a redesign whole, as one arm, then iterate its parts.
- **A/B/n**: every arm needs the full N, at α ÷ k for k variants against control (the readout applies Holm or Dunnett): two variants need ~1.2× N per arm, ~1.8× an A/B's traffic. Default to one variant.
- **Multiplicity**: correct α for every way to win (arms against control, primaries, pre-specified segments, looks). Correct power, not α, for guardrails: when shipping needs every guardrail to hold, each one is another way to miss a real winner, so power each metric at 1 − β ÷ (G + 1) for G guardrails (Schultzberg, Ankargren and Frånberg, Spotify, 2024), or mark a guardrail unpowered.
- **Unit**: randomize where the outcome lives: the account for B2B seats and plans; the inviter or a cluster when users affect each other's outcomes (referrals, invites, collaboration, marketplaces); else the user, never the session when the outcome spans sessions.
- **Eligibility**: fix who counts at first exposure, from attributes known then (new or returning, plan, country, device); a unit stays in its arm and in the analysis whatever it does next. Filtering on later behavior (reached checkout, stayed a week) compares different people.
- **Identity**: assign on the anonymous ID and carry it through signup, or activation and payment can't be credited to an arm; persist assignment server-side or by user ID (Safari deletes script-set storage after 7 days without user interaction, re-bucketing returning visitors).
- **Split**: 50/50 by default; for equal power, 90/10 needs ~2.8× and 80/20 ~1.6× the traffic. Ramp briefly to catch breakage, then hold the split fixed and analyze only that period; record the expected split for the sample-ratio check.
- **Duration**: whole weeks, at least 2 (the readout compares week 1 with later weeks for novelty), covering any cycle the outcome follows (paydays, month-end billing); the upper bound is identity loss and drift (rung 5).
- **Calendar**: check the window against the audience's business calendar (holidays, paydays, month- and quarter-end, sales events, campaigns, launches, price changes, other tests on the same users), and log external factors as they happen. An event that covers only part of the window reads as an effect.
- **Outcome window**: a lagging primary (paid after a trial, SQLs, activation) counts over the same window from each unit's first exposure; stop enrolling at N and read when the last window closes. Past ~2 weeks, decide on a validated proxy (the outcome a delayed guardrail), or on an unvalidated one (rung 3) whose guard reads the outcome in cohorts whose window has closed; if too few have closed, the proxy buys volume, not speed.
- **Guardrails** carry a non-inferiority margin (the largest loss the expected gain pays for) and a readout horizon; lagging ones (refunds, retention) get a delayed readout or a post-launch holdout, as does any guardrail whose margin the planned N can't detect (mark it unpowered on the card).
- **Hygiene**: arms render equally fast (assign server-side or at the edge above the fold: flicker or an anti-flicker delay is itself a treatment); tracking checked in every arm and reconciled with the system of record; an A/A test, or a week's dry run of assignment and logging, before trusting a new platform, exposure event or identity stitching.
