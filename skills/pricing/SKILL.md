---
name: pricing
description: |
  Sets prices and packaging for SaaS, AI and subscription products: value metric and model (seat, usage, credits, outcome), tiers and fences, free vs trial, discounts, price increases and cuts, grandfathering, AI margin and caps, PPP and price-display rules, referral reward and commission amounts, and save-offer price terms (discount depth, duration, margin floor).
  Use when: "how much should we charge", "raise prices", "pricing tiers", "usage-based pricing", "price our AI feature".
  Do NOT use for: pricing-page or paywall UI and tests (cro), pricing copy (copywriting), measuring NRR or LTV (product-analytics), referral program design (growth-loops), or choosing save offers (churn-prevention).
---

# Pricing

Value sets the level, cost the floor and the structure, the next-best alternative the anchor; benchmarks are sanity ranges, never reasons. Every price is a hypothesis with evidence and a kill criterion. Named siblings are used if available.

## Frame

**Name the real problem first**, in one sentence: which accounts, how much money, why now. A request to raise prices, cap usage or match a cut may hide a margin, packaging, segment or activation problem: solve that, or hand it off with owner, numbers and a done test. **Give any proposal a verdict** (a number, limit, cut, tier or date) on its **number** (from break-even and contribution, or arbitrary?), **scope** (which accounts by count, ARR and contribution; any profitable?) and **timing** (contracts, notice, renewals, promises): keep, amend or replace each, saying why. Your alternative must pass your own objections. One mechanism per cause, never a stack.

**Read first** (defaults; caller may redirect): price book `biz/marketing/pricing.md`, paywall doc `biz/growth/paywall-pricing.md`, buyer and segments (`docs/prd/product-brief.md`, `docs/prd/prd.md`), `biz/marketing/competitors.md`, `biz/analytics/funnels.md`; from billing, if reachable: realized vs list price, discount spread, plan mix, usage and cost per account; for any change reaching paying customers, contract terms (renewal caps, notice, price protection) and the plan's public promises.

| Situation | Forcing question | Inspect first |
|---|---|---|
| First price | What does the buyer use today, at what cost? | alternatives, segments, cost per account |
| Level change, paying base | How much revenue can leave before this loses money? | price-cited churn, renewals, notice terms |
| Cut or competitor move | Which winnable deals do we lose, and to whom? | losses buyers (not reps) blame on price, by segment |
| Restructure | Who pays more, who less, and is that fair? | each account's old vs new bill; metering; rep comp; renewal caps |
| AI cost, or a limit on a live plan | What does each account cost vs pay, and what was it promised? | contribution per account: its own usage × its segment's cost per successful task (`docs/arch/ai-features/{feature}.md` §7, `docs/arch/system.md` §4), never a usage percentile × a cost percentile, which overstates the tail; the plan's claims |
| Symptom | Is this a price problem at all? | the symptom table in `references/research-methods.md`; a cause for every affected tier |
| Point decision | What does the price book already imply? | the asking doc (`biz/growth/referral-program.md`, `biz/growth/churn-prevention.md`); `references/price-changes.md` |

**Ask once**, only what inputs lack; unanswered, apply these defaults, listed as assumptions. Objective and what yields when new logos, expansion and margin conflict (gross profit, never below the margin floor); buyer and budget line (team lead, software budget); motion (self-serve; sales above the top tier); market (B2B, USD, tax-exclusive); paying customers and terms (none); customers and data (under 50, no test traffic); cost per account (else a labeled estimate; never flat for AI); gross-margin floor (75%; 50–60% for AI-heavy tiers); CAC budget (12 months of gross profit per account).

## Decide

Run every step the situation touches, in order (4 and 7 whenever a bill changes), before deciding what to write.

1. **Anchor on the alternative.** Value = the next-best alternative's cost (nothing, a competitor, a hire, building it) + what you add − switching cost, AI-error risk included. Price below it: a wide gap when you are unproven or replace a trusted person, narrow against a competitor you beat; by default capture at most ~20% of the quantified gain, counting displaced spend in full and time saved only toward the ceiling. *Break when* the buyer's KPI is time (billable hours, SLA teams): count it in full.
2. **Value metric and structure.** Pick a value metric the buyer budgets in, that grows with their value, is auditable by both sides and doesn't tax adoption; name two rejected. Exposure roles (viewer, guest, commenter) free; no seats where success shrinks headcount. Add usage only when a fair-use limit at break-even (step 4) would bind ordinary accounts, or value varies over 10x within a tier, keeping at least 80% of a typical bill committed (platform fee, commit, allowance). *Break when* procurement needs a fixed annual number (commit, drawdown, true-up) or developers expect pay-as-you-go.
3. **Tiers and fences.** One tier per willingness-to-pay segment; each boundary's fence is a need the higher segment has and the lower lacks. Leak test: could each tier's buyer live one tier down? Never fence the aha moment; prefer limits that rise with success to locks. Set limits from economics, not usage percentiles (those say whom a limit touches, never where it goes): a limit added to a live plan sits at or above break-even usage (step 4; lower restricts profitable accounts); a new plan's allowance passes step 4's line test; a fence opens a paid path, priced so the next tier is cheaper at its median usage. One paid plan until segments are known. *Break when* a feature carries heavy variable cost: quota it across tiers.
4. **Margin, cost to serve, limits.** Three separate tests:
   - *Tier:* (net price − mean cost per account) ÷ net price clears the floor at today's costs and expected mix (heavy users drift to generous plans).
   - *Line:* every price line (seat, add-on, top-up, overage, credit pack, each meter) clears it at its lowest reachable price (the deepest allowed discount, save offer, regional price or term) and highest reachable unit cost (the costliest segment that can buy at that price; per outcome, cost per attempt ÷ that segment's success rate). A new plan's included allowance, fully used at that price and cost, at least breaks even.
   - *Account:* a paying account's contribution = net revenue (after discounts, payment and store fees) − variable cost. Only negative contribution or abuse justifies restricting an account for cost; one under the floor but above zero still earns money.

   Fix failures in order, re-testing after each: (1) **cost to serve**: size each lever in money per account and landing date (cheaper-model routing that passes the same evals, caching, batching, provider or contract rates); one landing first may make (2) unnecessary; (2) **one limit** on loss-making use, at or above break-even usage per paid seat or account = (net price − other variable cost) ÷ cost per unit (the highest result where net price varies by term, discount, region or store), with a paid path past it (top-up, overage, next tier) that passes the line test; abuse (resale, shared logins, scripts) is a second cause with its own behavioral control, never a lower limit for all; (3) **price or package**, new customers first. Free-tier cost per paying customer fits the CAC budget. *Break when* a land-grab has a capped subsidy with a dated repricing announced at launch, or free users are the distribution channel.

   Every usage limit ships with a meter, warnings before it binds, a soft step before any stop (a slower model or a top-up offer), a reset date and notice; metered overage stops only at a budget the buyer sets. Clawing back a promise (unlimited use, an allowance, a grandfathered price) costs trust beyond the revenue: restrict only losing accounts, from the next term after notice, never retroactively, and retire claims the bill no longer honors. The core recommendation clears the floor on measured inputs; a part that needs an estimate ships behind measurement (meter first, dated trigger) or a kill criterion.
5. **Level and evidence.** Evidence by customer count: `references/research-methods.md`; under ~50 customers, no qualified pushback in buying conversations means too low. B2B entry prices sit below the buyer's approval threshold (card or no-PO limit, procurement or security review) or well above it with sales; never just above. Between two defensible prices, launch the higher; an introductory price ends on a stated date. *Break when* network or marketplace density matters more than revenue per account.
6. **Billing terms.** Keep the annual discount below its churn ceiling 1 − L/12, where L = (1 − (1 − c)^12)/c is year-one paid months at monthly churn c (2% → ~10%, 5% → ~23%, 10% → ~40%); would-be annual buyers get it too. *Break when* cash is the constraint, or procurement buys annual regardless (discount little).
7. **Paying customers.** A +p increase stays gross-profit-neutral while at most p/(m + p) of revenue-weighted volume leaves (m = contribution margin; +20% at 80% tolerates 20%). A −p cut needs volume up p/(m − p) (−20% at 80%: +33%) and reprices the whole base: answer a price-sensitive segment with a fenced entry package. Estimate loss from past changes and price-cited churn, not surveys. New customers first; existing ones at renewal with lawful notice, their new bill in advance, time-boxed grandfathering (default 6–12 months; notice isn't grandfathering) and value they can see; every scenario within the hard constraints (Output, required rows). *Break when* most bills fall: move everyone at once.

## References

On demand: `references/pricing-models.md` (steps 2 and 4: seats, usage, credits, AI cost levers and claims, outcomes); `references/tier-packaging.md` (steps 3, 4 and 6: free vs trial, page defaults, price display, localization, consumer apps); `references/research-methods.md` (step 5, symptoms); `references/price-changes.md` (step 7, required rows, point decisions).

## Output

**Budgets size the record, never the analysis.** A material finding (it changes the decision, the money, a bill, a promise or legal exposure) is never dropped to fit: compress it, link a sheet, or exceed the budget and say why. A scope cut is stated with its reason. Write for the decider: full sentences; every number with its unit, period and basis.

**Price book** (default `biz/marketing/pricing.md`; caller may redirect the `biz/<area>/` root; update in place; without file-write, return it inline), *≤900 words, tables included; ≤1,800 for a restructure or when paying customers' bills or entitlements change. Sections are a menu: omit any that does not apply, heading included; required rows are never cut.* Live terms stay intact until a change is approved: keep them under "Live (as of YYYY-MM-DD)", outside the budget; add the change as "Proposed, pending [approver] by [date]; not in force, do not publish or quote"; on approval, move the old terms to a dated changelog.

1. Decision, situation, objective; the verdict on any proposal
2. Buyer, budget line, alternative and its cost, switching cost
3. Value metric; two rejected and why
4. Price table: tier, for whom, fence, monthly, annual, included usage, overage or cap, evidence (data, alternative or cost; else assumption + cheapest test); page defaults for cro: recommended tier, plan order, toggle, tax display
5. Margin: tiers at mean cost; price lines at their lowest reachable price and highest reachable unit cost; each allowance at full use; loss-making accounts (count, ARR, cause); cost-to-serve levers, sized; each limit's break-even usage and protections; free-tier cost per paying customer
6. Typical and heavy bill per usage-priced tier
7. Paying customers and rollout: accounts and ARR by bill-change band, named top movers, expected loss vs break-even, phasing; per-account table in a separate sheet
8. Discounts, offers, rewards, each with its margin at its lowest price and highest unit cost: annual discount, deal floor and approval matrix, save, upgrade and switch-to-annual ceilings with end dates, referral reward and commission
9. Watch and kill: metric, threshold, date, rollback
10. Assumptions, each measured or estimated, with what it gates; open questions

**Required rows** when paying customers' bills or entitlements change: in §1, *rejected options* (each with a specified replacement, owner and date); in §7, *scenarios* (downside, base and upside, each against every hard constraint: contracted renewal caps, price protection, committed rates, notice windows, the margin floor; breaches with fixes) and *conflicts* (which constraint yields, at what cost, who approves); in §10, *dependencies* (each unconfirmed input, such as a meter, a provider rate, a cheaper model's quality or legal sign-off: its confirm-by date and a fallback with numbers).

**Paywall doc** (default `biz/growth/paywall-pricing.md`; same rules), ≤300 words: gate (cro owns timing) → offered tier (link its price-book row) → any in-app-only offer with fence and expiry; store price points per channel.

**Reply** delivering a doc the caller asked for, ≤250 words: verdict first, then the recommendation with its key numbers and their qualifiers (measured or estimated, period, which accounts, at which price); top risks (what customers lose and how they are protected, the legal exposure of any claim or notice, the assumption the decision leans on most); decisions needed, from whom, by when; the doc's path.

**Inline answers** when no doc was asked for, same order: verdict on a proposal ≤600 words (number, scope and timing; the replacement with its thresholds, prices and line margins; accounts and money affected; protections, claim changes, notice and rollout; what to measure; record it in the price book, as Proposed, only once adopted); point decision ≤200 words (decision, numbers, risk, what to measure; standing terms also update the price book's §8); cut or competitor move ≤400; symptom ≤400, ranked (cause per affected tier, evidence, lever, owner). Add a line per further material finding.

## Self-Review

- Problem stated in accounts and money; any proposal judged on number, scope and timing; your alternative passes your own objections; one mechanism per cause.
- Tiers at mean cost, and price lines at their lowest reachable price and highest reachable unit cost (floors and offers included), clear the floor; each new allowance breaks even at full use; restrictions hit only contribution-negative or abusive accounts (count, ARR), after sized cost-to-serve levers.
- The core recommendation clears the floor on measured inputs; each price cites this case's data, alternative or cost, or is a labeled assumption with its cheapest test; external numbers are sourced, dated and never set a price.
- Each usage limit has a meter, warnings, a soft step before any stop, a reset date and notice; each headline claim ("unlimited", "no price increase", "save 20%") is true of every affected bill; consumer prices include tax and mandatory fees where rules require.
- Fences pass the leak test; the aha moment is ungated; §6's heavy bill is signable or bounded by a cap or commit; the annual discount is below its churn ceiling.
- Paying customers: live terms intact, the change pending; step 7's break-even passed; required rows complete. Every affected tier has its cause; a kill criterion has a number and date.
- **Footprint**: within its § Output budget, or over it with the reason stated; every material finding in the reply; no section that decides nothing; no unexplained shorthand.
