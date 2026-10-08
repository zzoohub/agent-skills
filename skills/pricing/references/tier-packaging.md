# Tiers, fences, free plans, page defaults and localization

Depth for SKILL.md steps 3, 4 and 6.

## Fences and gating

| Fence | Fails when |
|---|---|
| Team scale (seats, workspaces) | one login is shared |
| Admin, security, compliance (SSO, roles, audit log, residency) | large buyers have no mandate yet, or small regulated teams are forced up |
| Volume (projects, records, usage) | limits sit above what heavy users need |
| Service (SLA, support, onboarding) | the top segment runs nothing critical on you |

Place each feature by who must have it: every segment → every tier, never a fence; only the higher segment → the fence; a minority across segments → add-on; nobody → cut. A core job that needs three add-ons means repackage.

Adjacent tiers' price gap should match the value gap the fence opens; about 2–3x is a sanity range, not a rule. An anchor or decoy tier is a packaging choice: it must be buyable and servable at margin (its psychology: copywriting).

**Plan mix is a diagnostic, not a target.** Judge tiers by revenue per account and 90-day upgrade rate, not by share. Entry-tier accounts near their limits, with few upgrades: the next tier's jump or fence is wrong. An empty top tier names no real need; that is fine only for a deliberate anchor.

**Enterprise.** Add it when custom-pricing requests recur, deals exceed the top tier, or security and compliance needs appear, and someone can sell it. "From $X" qualifies leads only when that floor is real.

## Free plan, trial or reverse trial

| Option | Fits when | Watch |
|---|---|---|
| Free plan | value in minutes, low marginal cost, network or exposure effects, self-serve | free-tier cost per paying customer (below) |
| Trial | value needs setup or data, or marginal cost is high | trial length about twice the time to value, since users start late and use it in bursts: over 3 days rules out a 7-day trial |
| Reverse trial (full access, then the free plan) | a free plan exists but premium value stays invisible until used | the downgrade keeps the user's data and work |

Free-tier cost per paying customer = monthly cost per free user × months on free ÷ free→paid ($0.40 × 6 ÷ 3% = $80). Above the CAC budget, tighten the free quota or offer a trial instead.

Card-required trials convert more trials but start fewer, and add auto-renewal consent and reminder duties (via the churn-prevention capability's compliance reference, if available). Compare options on visitor→paid and month-3 paid retention, never on stage rates.

## Page content defaults

cro presents and tests these; the price book's §4 sets them.

- Plans run cheapest to dearest, one tier recommended; premium-first is a test variant, judged on paid conversion and ARPA together.
- The billing toggle defaults to the term you want most buyers on; show annual as the monthly equivalent plus the billed total.
- Usage pricing shows a typical and a heavy bill, or a calculator.
- Consumer prices carry every mandatory fee (no drip pricing) in the EU, UK, Australia and a growing list of US states (California since 2024-07-01: Civil Code §1770(a)(29)), and include tax in the EU (Consumer Rights Directive art. 6(1)(e)), UK (DMCC Act 2024 s.230) and Australia (Australian Consumer Law s.48). B2B and US prices are normally tax-exclusive; say which.

## Localization

- B2C: regional prices from price-level (PPP) data, each still passing SKILL.md step 4's line test (an AI-heavy plan can fall below cost). Expect some arbitrage (VPNs, foreign cards): accept leakage while regional prices earn more than they leak; tighten fences only when data shows otherwise.
- B2B: local currency, rarely lower prices; budgets do not scale with local price levels.
- Volatile currencies: price in USD and display local, or reprice local points on a dated cadence.
- Billing-country fences hold outside the EEA and Switzerland. In the EEA, per-country prices are lawful, but any end customer, businesses included, may buy an e-service at any storefront's price, whatever their card's issuing country (Regulation 2018/302 arts 4–5; services whose main feature is copyrighted content are exempt from the price part). Switzerland bars price or payment-term discrimination by residence or card origin without objective justification (Unfair Competition Act art. 3a).
- EU consumers: decide whether the tax-inclusive or the net price stays constant across VAT rates.

Display and geo rules last verified 2026-10-08; not legal advice, so confirm each market before launch. Sources: legislation.gov.uk/eudr/2011/83/article/6, legislation.gov.uk/ukpga/2024/13/section/230, accc.gov.au/business/selling-products-and-services/small-business-toolkit/pricing-and-unfair-selling-practices/component-pricing, oag.ca.gov/system/files/attachments/press-docs/SB%20478%20FAQ%20%28B%29.pdf, troutman.com/insights/state-attorneys-general-and-continued-enforcement-against-junk-fees-in-2026, eur-lex.europa.eu/eli/reg/2018/302/oj, efta.int/eea-lex/32018r0302, swlegal.com/en/insights/newsletter-detail/switzerlands-ban-on-geoblocking-enters-into-force-.

## Consumer apps and app stores

One plan, monthly and annual, until usage diverges enough for tiers. Store commission is a cost line that varies by program, storefront and year: verify it at decision time. High consumer churn makes deep annual discounts rational (SKILL.md step 6); lifetime deals: `references/price-changes.md`. Where web checkout is allowed, price web and in-app differently only with a stated reason.
