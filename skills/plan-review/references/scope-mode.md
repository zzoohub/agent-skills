# Scope mode: CEO/founder lens

Light: checks 1, 2 (judge the plan's own risk work; no pre-mortem) and 4, plus 3 for a posture the caller names or a build past about a month. Standard: all six. Deep: all six, grading every assumption under a one-way door.

## Checks

1. **Premise.** What behavior shows the problem? What does doing nothing, or waiting a quarter, cost, and what else would these people-weeks buy? Is this the direct path to the outcome, or a proxy? Is there a cheaper path (reuse, configure, buy, integrate, or by hand first)? Does it move toward the 12-month direction, or build something to unwind? Mid-build, weigh remaining cost against remaining value: what's built is sunk, except the cost of undoing it.

2. **Riskiest assumptions.** Judge the plan's own risk work (a brief's riskiest assumptions, a PRD's v0.1 bet and risks); don't write a parallel set. Are they the likeliest killers, graded honestly? Where they are missing or miss a likelier killer, run a pre-mortem at the plan's horizon (the v0.1 checkpoint; a year on, for a brief): the three likeliest causes of failure, value and viability included, each traced to a plan line or its absence, negated into assumptions. Keep the 3–5 that success rests on, each graded with its source.

3. **Posture, by evidence.**

   | Evidence | Posture | Break when |
   |---|---|---|
   | Demand [Said] or [Assumed], or the estimate exceeds capacity with no cut line | **REDUCTION**: the smallest slice that tests the riskiest assumption | Untestable without the whole (network effects, compliance) → sequence the bets |
   | Premise evidenced; the plan is the direct path | **HOLD**: harden it; raise a cheaper path or a high-value addition once, with its cost and risk | — |
   | Evidenced demand the plan underserves (users work around the gap); capacity has slack | **EXPANSION**: the 10x pass, then the buildable slice; the rest becomes follow-ups | It adds a one-way door or delays first user contact → phase 2 |

   A posture the caller asks for ("go big", "find the 10x version") wins; if the evidence argues against it, say so once.

   **10x pass.** Start from the user's job, not the plan's features: remove it (do it for them), collapse the wait, change the unit (the team or the outcome, not one action), or use data or distribution only you have. Keep an addition only if it moves the outcome more than the same effort inside the plan would, and its first slice lies on the plan's path.

4. **Cut line.** Judge the plan's own cut line (a PRD's v0.1 Musts; a spec's [Must] requirements); don't draw another. The first release is the smallest set that reaches the success measure for one segment, reaches real users early, and tests the riskiest assumption first, with a threshold that would stop it. No cut line → Major; a first release that leaves that assumption untested → Re-scope. A brief has none by design: judge whether its Decision fits its evidence and its Next test, with a kill threshold, runs before any build.

5. **One-way doors the scope implies** (SKILL.md § 4): published promises, retention and consent, migrating users' data, legal duties, and what an AI feature may do without a person approving. Each needs an owner decision now, or a reversible first version.

6. **Feasibility flags**: at most three, only where the answer could change scope, each with its settling spike and pass/fail threshold.

## Verdict

The first that applies wins.

- **Stop**: the outcome isn't worth the cost, or a cheaper path or a better use of the same people-weeks beats it; name which.
- **Test first**: a one-way door, or most of the cost, is committed before anything in the plan tests the [Said] or [Assumed] assumption it rests on. Name the cheapest test and its pass/fail threshold, then re-review. A v0.1 or slice that tests it first, with a stop threshold, is that test; name its checkpoint. *Break:* the reversible version, built and watched, costs less than the test → Re-scope to it.
- **Re-scope**: cut, add or re-sequence; say which, and what moves.
- **Commit after fixes**: each Blocker has a fix within scope; name them.
- **Commit**: no Blockers.

Then write per SKILL.md § 5 and run its Self-Review.
