# Measurement

Read for Search Console, Bing or GA4 data, a traffic change, a baseline, proof that a fix worked, or AI visibility. Platform facts checked 2026-10-08 in Google's and Bing's docs: cite them with that date.

## 1. Data hygiene

- **Register every console the market uses:** Search Console (a Domain property), Bing Webmaster Tools, Naver Search Advisor for Korea. Query data lives only there. Search Console's platform properties (2026) add your official Instagram, TikTok, X and YouTube accounts' performance in Search and Discover.
- **Search Console rows are incomplete, not sampled.** Anonymized queries count in chart totals but never as rows, and leave the totals once a query filter is on, so rows never sum to the total. The UI export stops at 1,000 rows, the API at 50,000 a day per search type; the BigQuery bulk export has no cap.
- **History is 16 months,** and the BigQuery export starts the day you enable it, with no backfill: enable it, or archive through the API, before you need a year-over-year comparison.
- **Split brand from non-brand** with Search Console's branded-queries filter (it can misclassify, and low-impression sites don't get it) or a regex, and report non-brand on its own: brand demand follows PR and product news.
- **Average position misleads:** it averages your topmost position per query, so new rankings at position 40 drag it down while clicks grow; read it per query or cluster. A link inside an AI Overview takes the Overview's position.
- **Search Console clicks never match GA4 sessions** (consent, blockers, redirects): compare trends, not totals.
- **Annotate** releases, migrations, tracking and consent changes, and Google's updates (Search Status Dashboard). The newest days are preliminary.

## 2. Traffic changes

Answer in order: is the change real (tracking, reporting); which stage broke (`technical-seo.md` triage order and symptoms); which segment moved, when (template, device, country, brand or non-brand, cluster). A site-wide average hides a one-template loss. Report three numbers, in the reader's metric (clicks, key events, revenue) over a stated window: the change as reported, the part that is artifact, and the corrected change as a range. A memo that only implies the corrected size hasn't answered the question.

| Pattern | Likely cause | Check |
|---|---|---|
| GA4 down, Search Console flat | Tracking or consent change | Tag and consent-banner deploys |
| Impressions down and average position improving, from mid-September 2025 | Google stopped serving 100 results per page (`&num=100`), removing deep-position impressions | Reporting artifact: compare clicks across the date |
| Impressions flat, CTR down | The results page absorbed the click: an AI Overview, ads, a new feature | Live results for top queries; the Generative AI report for those pages |
| Impressions down, position flat | Demand or seasonality | Year over year; Google Trends |
| Positions fall across templates on a core update's dates | Core update | The rule below |
| Sudden site-wide drop, or impressions on queries you never targeted (pharma, casino, foreign script) | Manual action, or hacked pages | Search Console › Manual actions and Security issues; URLs you didn't create. Clean up, then request a review |
| Slow decline on one cluster | Competitors added what you lack, or lost links | Information-gain grid (`seo-fundamentals.md` §3); lost referring domains |

**After a core update, don't thrash.** With no technical regression, wait until a week after the update completes, compare that week with one before it started, and find where losing pages cluster (template, query type, intent). Improve those on substance: Google warns against quick fixes, and recovery can take months. *Break:* a release shipped near the drop; revert or fix it first.

## 3. Your CTR curve

Published CTR curves describe other sites and results pages; build your own. Take three months of non-brand Search Console queries per device and compute CTR per position (1, 2, 3, 4–5, 6–10). Split the queries by whether an AI Overview shows (from a SERP tool or a hand check) and, where one shows, whether it cites you. Use the curve to find winners to leave alone, titles to test (well below the curve at a stable position; one change at a time) and the value of a ranking gain.

Cited pages tend to out-click uncited ones on AI Overview queries, but stronger brands are both cited and clicked more: the gap is correlation, so promise no clicks from a citation.

## 4. The AI-visibility ladder

Measure from the bottom rung up; no rung stands in for another.

| Rung | Question | Evidence |
|---|---|---|
| 1. Eligibility | Can the engine use you? | Index status in Search Console and Bing Webmaster Tools; search-bot hits per template in logs (agents: `technical-seo.md` §2) |
| 2. Retrieval | Do engines fetch you while answering? | User-fetcher hits per URL (ChatGPT-User, Perplexity-User, Claude-User) |
| 3. First-party citations | Where do engines show or cite you? | Bing Webmaster Tools › AI Performance, a sample: citations, cited pages and grounding queries (Copilot, Bing's AI answers). Search Console's Generative AI report: impressions only, AI Overviews and AI Mode combined, by page, country and device |
| 4. Sampled appearance | How often are you named, recommended or cited against competitors? | The prompt panel (§5) |
| 5. Outcomes | Does it pay? | AI-referral sessions and key events; self-reported attribution; pipeline |

- **A bot hit is not a visit.** Search-bot hits show eligibility, user-fetcher hits an engine answering with your page; neither is traffic.
- **Google's AI clicks don't show up as such:** AI Overview and AI Mode clicks sit inside Search Console's Web totals and GA4's Organic Search.
- **AI referrals** follow the product-analytics capability's channel definition, if available; map missing assistants in a custom channel group, never bing.com. They undercount (apps and some assistants strip the referrer): add an AI option to "how did you hear about us?" and compare its share with the channel's.
- **Bing's grounding queries** (searches an engine ran to answer) feed the keyword map and the panel.
- **Judge AI traffic on key events and pipeline,** not engagement rates.

## 5. The prompt panel

A tracked panel and its waves live in `ai-visibility-log.md` in the search dir.

- **Build** prompts from real demand: Search Console question queries, sales-call and support wording, site search, Bing grounding queries, titles of the threads and roundups engines cite, and the tracked prompts in each competitor-page draft's opening comment, or a handoff the caller passes. At least 5 per cluster, tagged by type (shortlist, comparison, how-to, brand fact) and weighted by revenue proximity; include the brand-fact prompts (`consensus-and-accuracy.md`). Start with 20–30 prompts on the 3–5 clusters nearest revenue and two engines; grow toward 100 only with a tracker that meets the Tools bar below. Freeze the wording: a reworded prompt starts a new series.
- **Pilot** (one cluster or engine in question): that cluster's 5 prompts × 5 runs on one or two engines, logged in the AI-visibility log when one is kept or tracking is wanted; answer with the gap class, evidence and lever, and size the full panel.
- **Run** monthly waves, each prompt at least 5 times per engine (10 when a decision rides on it): logged out, or a clean account with memory off; fixed location and language; in the consumer interface buyers use, since API answers can differ. *Can't run the consumer interfaces* (no logins, bot walls)? Check Access yourself, hand the caller the panel and a run sheet, and mark the other gap classes as hypotheses; API runs with web search may seed the source map, labeled as such, never as appearance rates.
- **Record** per run: named; recommended (offered as a pick); your cited URLs; every cited domain; factual errors; paid or organic placement.
- **Report** per cluster and engine: appearance rate (share of runs naming you) and cited rate beside each competitor's from the same runs, plus the top cited domains. Never a rank: in SparkToro and Gumshoe's January 2026 test, repeated runs of one prompt returned the same brand list under 1% of the time. Judge a change at the next one or two waves.
- **Noise floor.** Take each prompt's change in appearance rate between waves; across n prompts, a shift is real when the mean change ± 2·SD/√n excludes zero and the next wave agrees. On a 50-prompt × 5-run panel, moves under about 10 points are usually noise.
- *Break:* a confident wrong answer to a brand-fact prompt is a bug to trace now (`consensus-and-accuracy.md`), not a rate to watch.
- **Tools.** Hand collection suits a small panel; a tracker earns its cost only if it uses the consumer interface, repeats prompts, exports raw answers with every cited URL, fixes location and language, and separates paid placements.

## 6. KPIs and proof

Report by money template and cluster: non-brand organic clicks and key events; the indexed share of each money template's sitemap; appearance and cited rates against competitors, Bing AI citations and Generative AI impressions on money pages; brand-fact accuracy (share of brand-fact prompts answered correctly); AI-referral key events and the self-reported AI share.

**Never targets:** average position across queries; total impressions or ranking-keyword counts; the "Not indexed" total; DA or DR; AI ranks or single runs; bot hits as traffic.

**Proving a fix.** Record the baseline before shipping (metric, source, date range). Read Google metrics only once the changed URLs are recrawled (URL Inspection shows the last crawl), against equal windows before and after adjusted with last year's same weeks, or against similar untouched pages. A branded-search rise after AI or off-site work may come from PR, ads or seasonality: report it as correlation, not proof.
