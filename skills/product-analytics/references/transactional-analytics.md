# Transactional Product Analytics

The frame for a product sold **per purchase** (paid reports, digital goods, e-commerce), where most visitors stay anonymous until they pay and many buy once (SKILL.md § First). Revenue is earned at checkout, not over a subscription, so the spine follows the money per product: acquisition → product funnel → revenue per visitor → repeat and cross-sell → channel payback → scale / fix / retire.

## Grain and Identity

- **Grain:** product × market. Each has its own funnel and price, so it is the decision unit, not an exploratory cut; the catalog total is their sum, split into mix and rate (SKILL.md § Explaining a Move, step 3).
- **Unit:** the visitor (a device until identified) up to checkout; the buyer, keyed by the payment record (account, else billing email), for revenue, repeat and payback. A buyer who switches devices or logs in mid-funnel splits into several visitors, so funnel rates that span checkout read low and directional: settle buyers, revenue and repeat purchases from the payments table.
- **Money:** per currency, never summed across currencies; the price actually paid, net of discounts, coupons and refunds. A 100% coupon is a zero-revenue order, not a sale. Refunds come from a server refund event keyed by the order or from the payments table; without either, revenue is gross: label it.

## Metric Tree

Revenue = Σ over product × market × channel of visitors × purchase rate × revenue per order.
- **Revenue per visitor (RPV)** = revenue ÷ unique visitors who reached the product's first screen, same window: the outcome that weighs traffic, conversion and price together. Report it per product × channel with the funnel beside it.
- **Funnel** (retention reference § Funnels): first screen → input done → free result or teaser → checkout opened → paid → delivered, in unique visitors, with a window matched to the purchase decision (same day to 7 days).
- **Revenue per order:** price mix, packages and upsells, discounts.
- **Delivered rate:** paid orders whose result was produced and opened. A paid order never delivered is a loss and a support ticket, not a conversion.
- **Refund and complaint rate** per product: the counter-metric to every price and conversion push.

## Repeat and Cross-Sell: the Retention Read

- Cohort buyers by first-purchase month; report the share that buys again within 30, 90 and 180 days (each cohort only once it is that old) and the time to a second purchase (median, p90).
- Repeat buyers' share of payments or revenue describes the revenue mix, not retention: it rises whenever new-buyer acquisition falls. Judge repeat only on buyer cohorts at equal age.
- The return event is a purchase. Revisits and page views are engagement, never retention.
- Build the first product × next product matrix from the payments table, buyer-keyed: it shows which products feed others. A low-RPV product that feeds the catalog is not a retire candidate.
- A cross-sell or placement click counts only when the clicked product is bought within the window (default 7 days), per placement. Read the impression definition first: "placed on the page" counts unseen slots, so lower positions mix appeal with scroll loss.
- **Aha analog:** the post-purchase action that predicts a second purchase (reading the result through, reopening it in later weeks, saving or sharing it, a cross-sell click), found with the Aha method on first-time buyers (Aha reference). An engagement metric becomes a north star only once it predicts repeat purchase this way.

## Channels and Payback

- Credit a purchase last-touch and a buyer's acquisition first-touch (tool guide); report both where they disagree.
- **Contribution margin per order** = price paid − payment fees − delivery cost (e.g. model inference per report) − refunds.
- **Payback** per channel = cumulative margin per acquired buyer (first order plus observed repeat) against the channel's cost per acquired buyer, at 30 and 90 days; the spend gate and stop-loss follow the retention reference § LTV and Payback with the buyer as the unit.
- An ad platform's ROAS (its own conversion count × a list price) is an in-flight alarm only: platforms credit overlapping sales, a list price ignores discounts and packages, and it measures revenue, not margin.
- Spend comes from the ad platforms (an export or a spend import into the analytics tool), joined on the campaign key. Without it, report buyers, revenue and margin per channel and list the spend source under Open Questions.

## PMF Evidence

Carrying Capacity applies only where repeat purchase is the business. The evidence: a repeat rate holding or rising in newer buyer cohorts at the same age; organic, direct and share-driven buyers growing as a share; RPV holding as spend steps up (the incremental step, SKILL.md § Verdicts, Spend). A Sean Ellis survey reads only on buyers who received their result.

## Decision: Scale / Fix / Retire

Per product × market and per channel, monthly, against criteria written in `kill-criteria.md` before the data (SKILL.md § Verdicts):
- **Scale:** payback inside the bar on file (default: cumulative contribution margin covers cost per buyer within 90 days), RPV stable as spend steps up, refund rate inside its band.
- **Fix:** traffic holds but one funnel step, the price or the delivered rate sits far from the product's own history or the catalog median → that step's owner (cro or pricing capability, if available).
- **Retire:** RPV below the catalog floor for two consecutive reviews, no fix in flight, and no feeder role in the cross-sell matrix. Keep pages that still earn organic traffic live.
- **Break when** a product has fewer than ~30 orders in the window: pool a longer window or label the call directional.
- Price, discount and packaging tests decide on revenue per exposed unit (A/B reference § 1).

## Dashboard and Weekly Report

Default tiles, until the metric tree in `dashboards.md` § Definitions replaces them: revenue and RPV per product × market; funnel step rates per product; buyers and cost per buyer per channel (first-party); repeat rate by buyer cohort (monthly); delivered and refund rates; data health (key event volumes against their bands, analytics vs payments gap). The weekly report keeps the CC reference's template, with product × market rows in place of CC.
