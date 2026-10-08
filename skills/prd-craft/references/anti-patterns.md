# PRD Anti-Patterns

Failures that sink a PRD in any format. Each entry: looks like · test · fix. feature-spec cites entries by name; keep the names.

1. **The Solution Masquerading as a Problem.** "We need a notification system." · Does the problem name a feature or product? · State the pain and its cost.

2. **The Design Document in Disguise.** Layouts, pixel values, component specs, final copy. · Would the first usability test make the line obsolete? · State what the user can do; at most, link a rough flow of the bet's one interaction.

3. **The Technical Spec in Disguise.** "Built with React", features named after modules (`file-parser`). · Is it architecture's choice, or a part no user would name? · Describe the capability; imposed technology is a §8 constraint with its reason.

4. **The Everything Bagel.** Every wish in scope, everything a Must, estimates shaved until it fits, non-goals nobody wanted. · Is there a cut line in the first release users get, do its Musts fit about 60% of the appetite on whole-job estimates, and would someone argue for each non-goal? · Move Musts below the line, or call the plan tight while the high end still fits the appetite; non-goals are the tempting features.

5. **The One-Sided Coin.** No risks, or only technical ones. · Is one about value (will they buy or choose it) or viability (cost, sales, legal, support)? · A pre-mortem at the v0.1 checkpoint: each risk's earliest signal and what retires it.

6. **The Fabricated PRD.** Precise baselines, statistics, quotes or personas nobody measured or met. · Name each one's source. · Tag each number by where it came from; delete invented quotes and personas.

7. **The Output-Metric Trap.** "Launch X", "10 endpoints built", "95% of deploys auto-verified". · Does it say what changed for users or the business, and what must not get worse? · Measure the behavior change, not the activity, and pair it with a counter-metric.

8. **The Lab Pilot.** A v0.1 its real audience can't run: no way in, nobody to fix a wrong record, no way out, data duties left for "later". · Walk one pilot user from invite to deletion and the operator through a week: does each step have a feature, a named manual owner or a reason it won't come up? · Add the step to §5, the build bar or §7.

9. **Law as a Footnote.** "Must comply with [law]" in §8 or §9, and no requirement anywhere; outputs never classified. · Point to the requirement and acceptance criterion that meets each duty, in the release that incurs it. · Turn each duty into requirements; check whether the product's output, not only its data, is regulated.

10. **The Paper Cutover.** "Migrate from the old tool", undated: dirty records, in-flight work and the old tool's end unplanned, so users run both and drift back. · Does the first release users get name the go/no-go check and a cutover date per segment, with no integration below the cut line whose absence the evidence says sends users back? · Add the Transition line; move those integrations above the line.

11. **The Silent Departure.** The PRD drops or overturns what the approved brief asked, and only the report, or nothing, says so. · Compare the PRD with the brief's problem, segment, metric and asks. · Decide each departure in §3 with its evidence and approver; recommend revising the brief.

## Severity

| Severity | Typical findings |
|---|---|
| 🔴 Critical (blocks) | no problem or no segment; success unmeasurable; v0.1 can't test the core bet, or its real audience can't run it (no way in, a duty it incurs with no requirement); an item both in scope and a non-goal; an unsourced number driving scope |
| 🟠 High | a metric missing a §4 column, or gameable with no counter-metric; a stated outcome dropped silently; a departure from the brief left undecided; a replaced tool with no dated transition, or an integration below the cut line whose absence the evidence says sends users back; Musts over ~60% of the appetite and neither justified nor called tight, or over the whole appetite at the high end; estimates trimmed to fit; a decision rule v0.1's sample can't settle; no cut line; a costly `[later]` unflagged; a v0.1-blocking question with no default; module-named features; a broken §5/§6/spec join; technology without a mandate |
| 🟡 Medium | stale Last Updated, or §6 out of step with what shipped; a generic segment; no build bar; only technical risks; shorthand a cold reader can't follow; over the word ceiling |
| 🟢 Low | wording |

## Trouble map

Trouble reported while a PRD is in use points to a section: architects asking about scale or tenancy → §8; arguing whether v0.1 worked → the decision rule; v0.1 over- or under-built → the build bar; pilot users stuck getting in, fixing a record or leaving → the lifecycle features and build bar; users back on the old tool → the Transition line and integrations below the cut line; launch blocked by legal → §8 Duties with no requirements; settled asks reopened → §3 departures; scope creep → the cut line or non-goals; a target with no data → §4's source; screens for cut features → specs too deep, too early.
