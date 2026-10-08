# Units and models: seats, usage, credits, AI and outcomes

Depth for SKILL.md steps 2 and 4.

## Seats

- **Utilization test.** Under ~60% of paid seats active, or buyers asking "do all these people need access?", means the seat misses value: move value to a usage or account-level unit, or to role seats.
- **Role seats.** *Break* SKILL.md step 2's free exposure roles when viewing is the value (dashboards bought for executives): a cheap viewer tier, not a full seat.
- **Seat compression** (SKILL.md step 2): move value to the work unit (tasks, resolutions) or an account platform fee before renewals show it.

## Usage

- **Forms.** Commits (SKILL.md step 2): overage at a pre-agreed rate, trued up at renewal. Tier overage follows SKILL.md step 3; a punitive multiple of the included unit rate, or a forced tier jump at the limit, reads as a penalty: re-space the tiers instead. *Break when* selling commits: on-demand runs at a stated premium over the committed rate, and that premium is the reason to commit. Volume bands: graduated (each unit at its band's rate), not all-units, which makes some bills fall as usage rises.
- **Bill shock.** Alert at thresholds of a budget the buyer sets. Self-serve: a hard stop plus opt-in auto top-up up to a user-set cap. Metering lags, so caps take effect late: set them below the true maximum.
- **Sales comp.** Decide before launch whether reps are paid on commit or on consumption; what they are paid on is what gets sold.

## Credits

- Use credits only when several actions with different costs share one budget; with one or two meters, price them directly.
- Denominate credits in money or a standard task, never an abstract point the buyer cannot price, and publish the burn table (credits per action); changing it is a price change (`references/price-changes.md`).
- Included credits reset each period; purchased top-ups last longer; annual commits pool over the term; any rollover is capped at one period's allotment.
- Model breakage (unused credits) and the deferred-revenue liability with finance before promising rollover or refunds.
- An action costing orders of magnitude more than the rest gets its own meter: in a shared pool it invites arbitrage.

## AI features and agents

- **Packaging.** Bundle into the base when most users benefit and cost per account is bounded; tier it when it marks a segment; add-on when a minority wants it and its cost varies. Table stakes (rivals include it free): bundle under a fair-use cap, funded from margin or the next scheduled increase; an add-on would tax the feature that keeps customers.
- **Meters.** Tokens fail unless buyers budget in them (model APIs, developer infrastructure). Selling the same agent per action, per conversation or per user lets each segment buy in its own budget unit; each meter must pass SKILL.md step 4 on its own.
- **Bill only successful work,** and offer cost ceilings (monthly caps, commits) to buyers who need budget certainty. When a user starts a run whose cost can vary over 10x, show a pre-run estimate or set a per-run cap.
- **Claims match the bill.** Once any cap, throttle or model downgrade can restrict a paying account's legitimate use, drop "unlimited" from plan names and headlines; abuse controls under published terms (resale, scripts, shared logins) are not use limits. Until the word is gone, disclose every restriction beside it, as prominently as the claim: the FTC's 2019 settlement with AT&T Mobility (US$60M), over throttling "unlimited" customers past a usage threshold, bars such claims without prominent disclosure of material restrictions (ftc.gov/news-events/news/press-releases/2019/11/att-pay-60-million-resolve-ftc-allegations-it-misled-consumers-unlimited-data-promises; verified 2026-10-08). Publish every plan's at-limit behavior: a cheaper model, a top-up, or a limit-reached state with its reset time.
- **Clawbacks.** Narrowing what a plan includes is a price increase for every account it binds, and can play out in public: Cursor's June 2025 Pro change, unclear about what "unlimited" still covered, ended in an apology and refunds of unexpected charges from June 16 to July 4, 2025 (cursor.com/en/blog/june-2025-pricing; verified 2026-10-08). Announce with each account's numbers, ship the meter before the limit, and refund surprise bills during the switch.
- **Cost per task.** Measure it on your own workload at current provider rates; re-measure at each model or provider change. Provider price lists are inputs, never anchors for your price.
- **Cost-to-serve levers** (SKILL.md step 4, before any limit). Size each on your own traces: tasks a cheaper model handles at the same eval pass rate × the price gap; cacheable input × the cache discount; work nobody waits on × the batch discount; tokens cut by shorter context, output caps and loop or retry limits; a second provider or committed-use pricing. Take rates from each provider's current price list, dated. A quality drop users notice is a price change too.
- **Unit costs.** Price on today's costs: tokens per task can rise as per-token prices fall. When cost does fall, widen allowances or move to a better model at the same price before cutting list, which reprices the whole base.

## Outcomes

Charge per outcome only when all four hold: the customer can verify it in their own system; it lands within one billing period; your product controls most of its variance; and the contract defines what counts (is a customer who leaves without replying "resolved"?), how disputes and reversals work, and any cap. Cost per billed outcome = cost per attempt ÷ success rate, and it must clear the floor. Otherwise charge per task, with a quality gate.

## Billing systems

Buy billing; don't build it. Require idempotent ingestion with late-event backfill, a credit ledger with expiry, real-time entitlements and invoice preview. Vendors change owners and licenses often; check both at decision time.
