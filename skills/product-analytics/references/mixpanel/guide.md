# Mixpanel: Analysis Guide

How this skill's methods run in Mixpanel: what a number means there, the reading rules, report recipes and experiment traps. Tracking design: `references/mixpanel/taxonomy.md`. Vendor behavior below was checked against Mixpanel's docs on 2026-10-30; confirm in the current docs before a decision rests on it.

## Before Any Query

- **Read the project's taxonomy first** (default `docs/mixpanel/`; caller may redirect). For each event you will use: when it fires and how often, its value meanings, exposure semantics, renames with dates (query the old name for earlier periods) and its analysis recipe. For compared periods, also the experiment timeline and the changelog.
- **Production project only.** A dev project receives test traffic and events that never shipped.
- **A Mixpanel user is a device until identified.** Under Simplified ID Merge (the default for organizations created since April 2024), the first event carrying both `$device_id` and `$user_id` links them, the user ID becomes the distinct ID, and `alias()` merges nothing; older projects may still run Original ID Merge, so check which. A logged-out buyer on two devices is two users, so a funnel spanning login or checkout reads low. Mixpanel gives direction and where people drop; settle participants, buyers, coupon use and revenue from the database.
- **Server events carry only what the server sends:** no browser super properties (`AB_*`, `접속환경`, last-touch keys) unless the sender forwards them. Read them through a funnel whose browser step carries the property, or join in the database.
- **Timezone:** reports bucket days in the project timezone (UTC unless set). Projects created before 2023 converted timestamps at ingestion, so a later timezone change splits their history. Align with the database's timezone before reconciling a day.

## Reading Rules

1. **Market and surface first**, on every metric of a ratio, by the taxonomy's one written rule: the display-name suffix (`-tw`) or the `$current_url` path for markets, `접속환경` for app vs web. Unfiltered reports mix markets whose keys collide, and a substring filter such as "`서비스` doesn't contain `tw`" counts every other market as domestic.
2. **Unique users** for conversion and drop-off; totals only for volume. Never subtract totals across steps: a user repeating a step inflates it.
3. Uniques don't add across days, segments or markets: reconcile segment sums with the total before splitting a move.
4. An outcome is its committed event (`payment_complete`, `signup`, a participation), never the button that asked for it. An event that fires once per step (`input_complete` per field) is a funnel step only with its step filter.
5. A ratio's two metrics carry identical filters and windows, each stated as uniques or totals.
6. Money in Mixpanel is behavioral: reconcile revenue with the payments table per currency and watch the gap for drift. An outcome with no event (a rating stored only in the database) is counted there and divided by the event count, labeled a cross-source ratio.
7. Read the impression definition before a click rate: "placed on the page" counts slots nobody scrolled to.
8. A sharer and the people who arrive by the link are different users: report both counts, never one funnel.

## Report Recipes

| Analysis | Report | Settings that change the answer |
|---|---|---|
| A rate (click rate, step rate) | Insights: metrics A and B, formula B ÷ A | identical filters on both; uniques or totals named |
| A funnel | Funnels | the funnel settings below |
| Period retention | Retention | criterion "On" (bracket), not the default "On or After" (unbounded); a "First Time Ever" filter on the birth event for an acquisition cohort, since by default a user is born in every interval they did it; return = the core action, never a page view; read from interval 1, since the first bucket holds returns inside the birth interval |
| Repeat purchase | the payments table by buyer (transactional reference); Retention born on the first payment and returning on any payment as a directional cross-check | device identity undercounts repeat; the `is_repeat` share of payments is a mix read, not retention |
| Revenue | Insights: sum of the amount property on the server payment event, per currency | reconcile with the payments table |
| Channel | a breakdown by `if(defined(ch), ch, utm_source)` (last-touch) or `최초채널` (first-touch) | name the axis; share inflow is `ct = share` or `최초콘텐츠 = share` |
| Paths | Flows | exploratory only |

**Funnel settings that change the answer:**
- Uniques count each user's first entry in the date range unless re-entry is turned on: over a long range, a later converting attempt reads as no conversion.
- A conversion window chosen for the decision (1 or 7 days from a click to a purchase), not the 7-day default by habit; step order and exclusion steps stated.
- A breakdown attributed to the step where the property holds one value: "First Step Defined" takes the first non-null value, so an array on an earlier step puts every user in every segment.
- A property held constant across steps, through a custom property merging two keys when the steps name it differently (`대상상품아이디` on the click, `상품아이디` on the payment).

**Beyond the report types:** a join the reports can't express (a key mapping between two events, per-order matching, a database value such as a variant's price) runs on an event export with a script, or in the database, or through a saved custom property or lookup table, which changes the shared project: only with its owner's approval. Label which route each number took. JQL is in maintenance mode (Mixpanel advises against new use) and the MCP doesn't run it: build no new metric on it.

**One definition per KPI.** Build each KPI once, as a saved metric or saved report named in `dashboards.md` § Definitions, and point every board at it: a KPI rebuilt per board drifts in window, market rule and steps. An unknown or retired event name returns zeros, not an error, so check that a saved metric's events still fire before trusting it.

**Saving:** every number in a deliverable cites a saved report (its link) or the report definition in the appendix, keyed to its date range.

## Experiments

- **Assignment tags are not exposure.** When assignment registers `AB_<key>` on every event, visitors of every product carry some arm: filter to the test's eligible population first (from its timeline entry: entry campaign, market, age band, treated products), then to units that reached the trigger, and count both per arm (A/B reference § 2).
- **App vs web:** when the app sits outside a test (fixed in-app prices, no assignment), filter `접속환경 = 웹`.
- **Time:** start when the treatment turned on, not at the deploy; end at the stop. After a weight change or a removed arm, analyze from the change or per stable period. Tags outlive the test (cookie lifetime): ignore them after it ends.
- **Unit:** the randomization unit (a browser for cookie buckets): unique users per arm, never events.
- **Server outcomes by arm:** a funnel from a browser step carrying `AB_<key>`, its breakdown attributed to that step; or database orders joined to assignments.
- **Price tests:** revenue per exposed unit = the arm's paid amount ÷ its exposed units (A/B reference § 1). Server payments carry no tag, so sum the amount through a cohort per arm, or take conversions × the arm's fixed price from the experiment definition.
- **A test registered in Mixpanel Experiments** reads exposure from `$experiment_started` ("Experiment name", "Variant name"), always runs an SRM check, and defaults to a sequential model: read its intervals as always-valid (A/B reference § 6), then still run the A/B reference's validity checks and decision table.
