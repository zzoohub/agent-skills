# Price changes, discounts, offers and rewards

Depth for SKILL.md step 7, the required rows and point decisions.

## Changing prices for paying customers

**Model every account, not the average.** For a restructure, sort accounts by old-to-new bill change; check the largest, fastest-growing and reference accounts by name. Winners move at once. Losers move at renewal, phased over several renewals when one step would push expected loss past step 7's gross-profit break-even. Revenue-neutral, p/(1 + p) (+20% → 17% of revenue-weighted volume), is the stricter line for when the top line must not fall; state which one governs.

**Hard constraints and conflicts** (SKILL.md Output, required rows). List them before modeling: contracted renewal caps and uplift clauses, price-protection or most-favored-customer terms, committed rates and volumes, notice windows (contract and statute), marketplace or reseller terms, and what the pricing page and terms promise. Run every scenario, upside included, through each: growth on a committed rate bills at that rate, not list, and a contractual spend or uplift cap holds however good the upside looks. Contracts and law never yield, and a contract changes only by signed amendment: offer the largest loss-making accounts one (a new term, a commit, or a paid add-on for the costly use), led by an executive, rather than carry the loss to term end; a margin-floor shortfall may stand as a dated exception finance approves; a launch date yields to notice. Each unconfirmed dependency gets an owner, a confirm-by date and a fallback you would still ship (no billing meter by launch → a published fair-use limit enforced from usage logs, at the same break-even).

**Legacy plans** get a sunset date announced with the change; kept forever, they block the next repackaging. Exceptions are written down, owned, and expire.

**Contracted uplifts.** B2B: take the contracted renewal uplift at every renewal; put a capped annual uplift clause in new contracts now.

**Notice.** Contracts and statutes set the window, and statutes can cap it as well as set a minimum (current windows: the churn-prevention capability's compliance reference, if available; verify each jurisdiction served). Defaults: a negotiated contract gets notice before its non-renewal deadline; self-serve plans, monthly or annual, 30 days ahead, inside the strictest consumer window served; any earlier heads-up or preview needs a second notice inside that window. Each notice states the account's new bill, the effective date, what they gain, every option that survives, including any cheaper plan, and how to cancel. Omitting the cheaper plan drew a regulator lawsuit over a Copilot price rise (ACCC v Microsoft, filed 2025-10-27; verified 2026-10-08, accc.gov.au/media-release/microsoft-in-court-for-allegedly-misleading-millions-of-australians-over-microsoft-365-subscriptions). copywriting writes the notice; sales and support get a talk track and the exception policy; log the change in a dated pricing changelog.

**Meters and credits.** A change to a meter, an allowance or a credit burn rate is a price change. Show each account a preview bill on the new terms at least one monthly cycle before it applies, or with the contract's notice for annual terms.

**Watch and roll back.** Before launch, set a kill threshold and read date for renewal rate, downgrade rate, price-tagged tickets and new-deal win rate; name who can roll back and what a rollback restores for accounts already moved.

## Discounts, offers and rewards

**Read the discount distribution before touching list** (the symptom table in `references/research-methods.md`). When most deals close far below list, list is fiction; debate the realized price instead. *Break when* a high list is a deliberate procurement anchor.

**One deal's discount.** Give-get only: each step of discount buys term, prepayment, volume or a reference, within the floor and the approval matrix. Write it as a dated line item off list, so the renewal starts from list.

**Save, upgrade and switch-to-annual offers.** A real lower tier at list beats discounting the current one. A save discount stays above the next tier down and above the margin floor at the account's own cost, and ends on a stated date (default within 3 billing months, or the current annual term); open-ended, it becomes a hidden price list for whoever threatens to leave. An upgrade incentive is time-boxed and never prices the higher tier at or below the current one. Switch-to-annual uses the SKILL.md step 6 ceiling at the account's own churn, usually below average.

**Lifetime deals** need near-zero marginal cost and a price above what buyers would pay by subscription; with variable cost (AI, storage), sell one only as a capped, dated, usage-capped cash raise, never a standing plan: it draws the heaviest users, whom you serve forever.

**Referral rewards and affiliate commissions.** growth-loops, if available, hands over the ceiling (r_max), value unit and side; else compute it here. The binding number is cost per incremental customer: reward per qualified referral (both sides, expected fraud leakage, payout ops) ÷ incremental share (from a holdout, else a stated assumption). It stays under the displaced channel's marginal CAC × LTV_referred ÷ LTV_next (ratio 1 until measured; this test is r_max) and under SKILL.md's CAC budget; the stricter governs. A $50 reward at 40% incremental costs $125 and fails a $100 CAC. Cost the reward by its form: capacity the recipient would not otherwise buy costs your marginal cost; cash, or a discount on a bill they would pay anyway, costs face value. Time-box the invitee's discount. Commission is a rate on collected revenue, net of refunds, over a fixed window, with rate × expected window revenue inside the ceiling; pay it for life only if the ceiling holds at expected lifetime revenue. *Break when* a referred account brings value beyond its own revenue (marketplace liquidity): add that value to the ceiling, with its evidence.
