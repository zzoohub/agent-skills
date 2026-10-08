# GA4 & GTM Setup Decisions

Verified 2026-10-08 against Google, PostHog and WebKit documentation. Platform behavior moves: re-check a claim in the vendor's current docs before a decision rests on it.

## Do You Need GA4?

- The product analytics tool (e.g. PostHog) stays primary for funnels, retention and experiments.
- Add GA4 when Google Ads bids on your conversions: GA4 key events import as Ads conversions, still the deepest Google Ads link. Before a product tool's ad-spend import or conversion export replaces it, check that those integrations are generally available, not beta.
- Search Console needs no GA4: its own reports and exports hold the query data.
- Running both: GA4 for acquisition, the product tool for everything after signup. Their session counts differ by design; alert on drift in the gap, not on its size.
- Use Google Tag Manager only when there are many tags (ad pixels) or non-engineers must change tracking; otherwise install tags in code.

## GA4 Essentials

- Key events (called "conversions" until 2024): mark `sign_up`, `purchase` and `generate_lead`, mapped from the tracking plan's GA4 column.
- Single-page apps: check that page views on browser-history changes are enabled in enhanced measurement; send `page_view` manually (with `page_location`) only if your routing escapes it.

## UTM and Channel Rules

- Use a controlled medium vocabulary that GA4's default channel rules recognize: `cpc` for paid search; `paid_social` for paid social (Paid Social needs a social source plus a medium matching `^(.*cp.*|ppc|retargeting|paid.*)$`); `social` for organic posts; `email`; `referral`. Never put `organic` on non-search links: GA4 files that medium as Organic Search.
- **AI Assistant** (a default channel since May 2026): medium `ai-assistant`, or a referrer on Google's list (its examples: ChatGPT, Gemini, DeepSeek, Copilot, Grok). AI Overviews, AI Mode and bing.com stay in Organic Search. Unlisted assistants land in Referral: map them in a custom channel group.
- Add `utm_id` (the campaign ID) so ad cost and creative data join; ad naming maps onto `utm_campaign` and `utm_content`.
- Never tag internal links: it overwrites the visit's real source. After launch, check in Traffic acquisition that tagged links land in their intended channels.
- Audit "(direct)" and organic traffic for untagged paid campaigns: they inflate organic inflow, and with it Carrying Capacity.
- Capture UTMs and click IDs first-party at landing and store them server-side with the signup: Safari caps script-set cookies at 24 hours after a decorated link from a tracker-classified site, and deletes script-writable storage after 7 days without interaction.

## Consent

- Google's EU user consent policy covers the EEA, the UK and Switzerland. There, Consent Mode v2's four signals default to denied until the user opts in.
- Basic mode loads no Google tags before consent. Advanced mode loads them with consent denied and sends cookieless pings: whether that is lawful is a decision for counsel. GA4's behavioral modeling requires advanced mode plus ≥1,000 events a day with analytics storage denied for at least 7 days, and ≥1,000 daily users granting it on at least 7 of the previous 28 days. Below that, GA4 applies no behavioral modeling. Google Ads conversion modeling is separate: it has its own click threshold and may run without the cookieless pings, at lower accuracy (check Google Ads Help).
- Measure your own consent rate instead of assuming a drop. A cookieless mode doesn't by itself remove the need for a consent banner; consent design is counsel's call.

## Server-Side Tagging

- It does not bypass Safari's ITP: cookies set from a server on a different IP address than the site are capped at 7 days. ATT governs apps, not web tags.
- Order of moves: Google tag gateway first (it serves the Google tag first-party through your CDN, load balancer or web server); add a server-side container when paid spend makes the recovered conversion signal worth its hosting and operations cost. The container also gives one control point for redaction and conversions-API forwarding.
