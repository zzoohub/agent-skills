# Evidence, symptoms and price tests

Depth for SKILL.md step 5 and its Symptom situation.

**Evidence by customer count.** Under ~50 customers: buying conversations. 50–1,000: behavioral data plus Van Westendorp or Gabor-Granger ranges per segment. Larger: conjoint or MaxDiff for packaging, randomized or geo tests for level.

| Method | Misleads when |
|---|---|
| Buying conversations | you talk to users instead of budget holders |
| Van Westendorp | the category is new and has no reference price: show the alternative's cost first |
| Gabor-Granger | it shows the product without competitive context |
| Conjoint, MaxDiff | read as absolute willingness to pay, not relative value |
| Behavioral data | prices changed alongside launches or campaigns |
| Win/loss | reps report it (they over-report price): ask buyers, and track price's share of losses over time |

Stated willingness to pay overstates real willingness to pay by about 21% on average, more for indirect methods such as conjoint than for direct questions (consumer goods, 77 studies; Schmidt & Bijmolt, J. Acad. Mark. Sci., 2020). Use surveys for ranges and relative value, never a price point; calibrate levels with your own purchase data.

**Questions for buying conversations**, best first:
- "If this didn't exist, what would you do instead, and what would that cost?"
- "How would you justify this expense internally, and from which budget?"
- "What would make this worth twice the price?"

## Symptoms: is it a price problem?

| Symptom | Usual cause | Check first | Lever |
|---|---|---|---|
| Low free/trial→paid | activation | activated users' conversion | onboarding (cro), unless activated users stall at the paywall |
| "Too expensive" | wrong segment, invisible value | who says it, against what alternative | segment and packaging before level |
| Heavy discounting | package misfit, no governance | discount spread by segment vs rep or quarter-end | segment package; floors, give-gets |
| Easy wins, thin discounts, price rarely cited in losses | under-priced | win rate, discount depth by segment | raise for new customers first |
| Margin erosion | flat price, variable cost | contribution per account by plan and feature | SKILL.md step 4, in order |
| Usage grows, revenue flat; seat pushback | metric misses value; seat compression | usage vs bill; active vs paid seats | value metric, role seats, add-on |
| Entry-tier pile-up | leaky fence | entry accounts' usage against the limits | move the fence |
| Churn at first renewal | rarely price | cancel reasons, pre-churn usage | churn-prevention, product-analytics |

Name a cause for every affected tier or segment. When one cause leaves a tier unexplained (rising AI cost cannot explain a margin drop on a tier without AI), look for the second before prescribing.

## Competitor audit

For each real alternative, record its unit, fences, entry price, the target buyer's typical bill (worked), discounting behavior, and a dated source. A competitor is the alternative only if this buyer would switch to it. Never copy a competitor's price: it encodes another company's costs, segments and mistakes.

## Price tests

- New visitors only, with sticky assignment across sessions and devices; honor the shown price at checkout.
- Read paid conversion, ARPA and month-2 retention, not signups.
- Randomize in-product on logged-in surfaces. On a public B2B page, use geo or sequential cohorts against a holdout; back-to-back weeks alone confound seasonality and traffic mix.
- At low volume, fix the quote price per period and read the win rate.
- Consumer apps: test price points on new installs at the paywall and judge revenue per install after the first renewal, net of refunds, not trial starts.
- Never vary paying customers' prices.
- Size the test with the cro capability's experiments method and read it with product-analytics' threshold for high-stakes changes, if available. If the sample cannot be reached within a quarter, stage the rollout with kill criteria instead.
- Prices set from a person's data carry disclosure duties, e.g. EU Consumer Rights Directive art. 6(1)(ea) and New York General Business Law §349-a (in force since 2025-11-10; verified 2026-10-08, jonesday.com/en/insights/2025/11/new-yorks-novel-algorithmic-pricing-disclosure-law-takes-effect). Check whether a test design counts before launch.
