# Page CRO

Conversion of existing landing, home, pricing, feature, comparison and content pages. A new page's structure and copy → copywriting; the tiers and prices behind a pricing page → pricing (each via that capability, if available).

## Data-less review: walk order

From the named source and device, log each defect in this order:
1. **Speed and errors**: it renders quickly and fully on that device (§ Performance / Core Web Vitals).
2. **Message match**: the hero repeats the promise that earned the click (the ad, query, email or AI answer). It matters most for paid, email and AI-referred traffic.
3. **Value proposition**: in a 5-second test, cold target users can say what it is, who it's for and why it beats their current way.
4. **CTA**: one primary action, labeled with what happens next and kept by the next step (a second only for another readiness level: "See pricing" beside "Start trial").
5. **Proof and objections**: user-supplied proof near the CTA (gaps go in copy direction); price, setup and risk answered before the ask.
6. **Friction** between the CTA and the outcome.

**Break when** data points elsewhere: start there.

## Leak signatures

- **One source converts far below the others** → its promise and the hero disagree, or the source sends low-intent visitors. Confirm: set the ad, query or referring answer beside the hero. A mismatch is a Fix; a match points to targeting, the caller's media plan.
- **CTA clicks rise, completed next steps don't** → the CTA promises what the next step breaks ("Free", then a card wall). Confirm: click→completion per CTA. Fix the promise or the step.
- **Only mobile under-converts** → speed, layout or input on mobile. Confirm: mobile field vitals and replays. Fix.
- **Returning visitors convert, new ones don't** → the page assumes knowledge cold visitors lack. Confirm: the 5-second test (step 3). Test a clearer hero.
- **Pricing page: plan clicks without checkouts** → plan-choice or next-step anxiety. Confirm: replays and a one-question poll at the plan step. Research, then Test (tiers and prices: pricing).
- **Pricing page: conversions up, revenue per visitor flat** (after a toggle-default, recommended-plan or plan-card change) → plan mix moved down. Confirm: plan mix, by arm or before vs after. Judge on revenue per visitor (guardrails: refunds, month-2 retention).

## Performance / Core Web Vitals

Judge field data at the 75th percentile per device, against web.dev's current "good" thresholds. Failing on the converting device is a Fix, checked before any persuasion work. No field data (CrUX covers only public pages with enough traffic): judge lab LCP and CLS, with Total Blocking Time standing in for INP, which automated lab runs can't measure.
