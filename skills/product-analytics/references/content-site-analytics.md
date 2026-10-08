# Content & Marketing-Site Analytics

The frame for a **login-less content or marketing site** (blog, docs, lead-gen): most visitors browse
anonymously and never sign in, so the product spine doesn't apply (SKILL.md § First). Leads are a
**rare lagging outcome**: steer day to day on the leading indicators (acquisition, engagement,
content performance) and judge leads on a monthly window.

## The Four Metric Tiers

### 1. Acquisition — where visitors come from
- **AI-assistant referrals:** GA4's AI Assistant channel, with unlisted assistants mapped in a custom
  channel group (GA4/GTM reference § UTM and Channel Rules).
- Split organic search by engine: for Korean-market sites, **Naver vs Google vs Daum** matters; one
  number hides the gap.
- **Search-query detail is NOT in the analytics tool.** Keywords live only in Google Search Console,
  Naver Search Advisor and Bing Webmaster Tools; unregistered consoles are the biggest acquisition
  blind spot. Flat impressions with falling clicks mean search features or AI answers are taking the
  click, not that the content decayed: check per query before rewriting a page.
- Deeper SEO/AEO/GEO work and AI-visibility measurement belong to a search-visibility capability,
  if available.

### 2. Engagement — did they actually read
Use **engaged (active-tab) time**, not wall-clock time-on-page. GA4's built-in scroll event fires
only at 90% depth: add custom 25/50/75% events. Add read-completion rate and pages per session.

### 3. Content performance — which posts earn their keep
**Conversion-assisting content**: which posts were read in the session(s) before a lead.
"High-traffic" and "lead-producing" are different sets; report both.

### 4. Conversion — the one lagging outcome that matters
- The lead / inquiry submit is the North Star event.
- **Intent split must be a client event property.** If the form distinguishes demo vs download
  (inquiry vs asset), the server often only receives name/email — the intent is lost unless captured
  client-side at submit.
- Monthly, count qualified leads by source tag in the CRM, which knows which submissions qualified.

## The Attribution Seam (thin, on purpose)

The only thing the site must hand downstream: tag each lead with its **UTM / source / referring
content** so a CRM can later backtrace "this customer came from post X." One line on the lead
payload.

**Explicitly out of scope:** the downstream B2B funnel (MQL → SQL → closed-won), the real product
activation, and any server-side event stitching beyond the seam. Those belong to the CRM / product
project, not the content site. Pulling them in is the most common over-scoping error.

## Decision: Double Down / Hold / Drop

Per content cluster and acquisition channel, monthly:
- **Lead rate** = qualified leads per 1,000 engaged sessions. Credit each lead to its session's
  landing-page cluster; report assisted reads (tier 3) separately.
- **Double down:** lead rate above the site median on ≥10 qualified leads, traffic not falling, and
  headroom left (for search: Search Console impressions on queries where the cluster ranks off page
  one, or adjacent topics). No headroom → Hold.
- **Hold:** mixed signals.
- **Drop:** below the median with falling traffic for two consecutive reviews. Stop investing; keep
  pages that still rank live.
- **Break when** a cluster has fewer than ~10 leads in the window: roll up to a broader cluster or a
  longer window, and label the call directional. Foundation pages (pricing, docs, about, legal) are
  exempt.
- A double down that adds paid spend carries the spend plan (SKILL.md § Verdicts): a cap, a gate on
  cost per qualified lead (from the lead value the caller sets), a stop-loss and a review date.

Pre-commit the rule and its review dates in `kill-criteria.md` (default `biz/analytics/`; caller may
redirect). Report the call in ≤300 words plus one table (cluster or channel · engaged sessions ·
qualified leads · lead rate · traffic trend · call); sections are a menu: omit what doesn't apply.
Answer the one lagging health read: **is qualified-lead volume and quality trending up?**
