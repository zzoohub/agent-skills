# Measurement Reference: SEO + AEO + GEO Metrics

How to measure success across traditional search, answer engine features, and AI-generated answer platforms.

---

## Table of Contents

1. [The Measurement Challenge](#the-measurement-challenge)
2. [Traditional SEO Metrics](#traditional-seo-metrics)
3. [AEO Metrics](#aeo-metrics)
4. [GEO Metrics](#geo-metrics)
5. [Integrated Measurement Framework](#integrated-measurement-framework)
6. [Tools Landscape](#tools-landscape)
7. [Measurement Pitfalls to Avoid](#measurement-pitfalls-to-avoid)


## The Measurement Challenge

Traditional SEO has a clear attribution path: user searches, clicks result, lands on site, converts. Analytics tools (GA4, GSC) track this end to end.

AEO complicates this: when your content appears as a featured snippet or voice answer, users may get the information without clicking. High impressions with low clicks is often a sign of AEO success, not a problem.

GEO breaks the path further. When an AI tool mentions your brand, the user may search your brand name later, visit your site directly days later, sign up without ever clicking from the AI answer, or never visit your site but form a positive brand impression.

You need traditional SEO metrics, AEO metrics, and GEO metrics to see the full picture.

---

## Traditional SEO Metrics

### Organic Traffic
- **What**: Visits from organic (non-paid) search results
- **Tools**: Google Analytics 4, Google Search Console
- **Track**: Total organic sessions, organic users, landing page performance
- **Segment by**: Brand vs. non-brand queries, landing page, device, geography

### Keyword Rankings
- **What**: Your position in search results for target keywords
- **Tools**: Semrush, Ahrefs, Moz, SE Ranking, Google Search Console
- **Track**: Rank position, ranking URL, SERP features owned, position changes
- **Focus on**: Keywords with business relevance, not just volume

### Click-Through Rate (CTR)
- **What**: Percentage of impressions that result in clicks
- **Tools**: Google Search Console
- **Track**: CTR by query, CTR by page, CTR by position
- **Benchmark**: CTR-by-position is now effectively bimodal. On AI-Overview-*absent* queries it roughly follows the legacy curve (position 1 ~25-30%, position 5 ~5-8%). On AI-Overview-*present* queries it is sharply depressed — position-1 CTR drops ~30-58% when an AI Overview sits above the result (Ahrefs, 2025), and clicks are near-zero for sites not cited inside the AIO. Being cited *inside* the AI Overview is the new CTR lever; do not treat any single position curve as universal
- **Improve by**: Optimizing title tags, meta descriptions, and structured data for rich results

### Impressions
- **What**: How many times your pages appeared in search results
- **Tools**: Google Search Console
- **Track**: Total impressions, impressions by query, impressions by page
- **Use for**: Identifying visibility trends and content opportunities

### Backlink Metrics
- **What**: External links pointing to your site
- **Tools**: Semrush, Ahrefs, Moz, Majestic
- **Track**: Total referring domains, new/lost links, domain authority of linking sites, anchor text distribution
- **Focus on**: Quality (authority and relevance of linking domains) over quantity

### Core Web Vitals
- **What**: Page experience metrics (LCP, INP, CLS)
- **Tools**: Google Search Console, PageSpeed Insights, Chrome UX Report
- **Track**: Pass/fail status for each metric, field data trends, pages needing improvement
- **Target**: LCP 2.5s or less, INP 200ms or less, CLS 0.1 or less

### Indexation
- **What**: How many of your pages are in the search index
- **Tools**: Google Search Console (Pages report)
- **Track**: Indexed pages count, indexation issues, crawl errors
- **Watch for**: Significant drops in indexed pages, increasing "excluded" pages

### Conversions from Organic
- **What**: Goal completions or revenue from organic search traffic
- **Tools**: Google Analytics 4 (with conversion tracking configured)
- **Track**: Conversion rate by landing page, revenue from organic, assisted conversions
- **This is the bottom line**: All SEO metrics ultimately serve conversion goals

---

## AEO Metrics

### Featured Snippet Ownership
- **What**: Which of your pages currently hold featured snippet positions for target queries
- **Why it matters**: Featured snippets are position zero, the most visible placement in search results. Owning a snippet means your brand is the answer.
- **Tools**: Semrush (Position Tracking with SERP Features filter), Ahrefs (SERP Features report), Moz, manual checking
- **Track**: Total snippets owned, snippets gained/lost per period, snippet type (paragraph, list, table), competitor snippet ownership for same queries
- **Segment by**: Topic area, content type, snippet format

### People Also Ask Presence
- **What**: How often your content appears in PAA boxes for target queries
- **Why it matters**: PAA boxes appear on a large share of searches (estimates range ~40-67% depending on dataset/region and are higher on mobile). Each PAA click generates additional questions, creating cascade visibility.
- **Tools**: Semrush, Ahrefs, AlsoAsked, manual tracking
- **Track**: Number of PAA appearances for target topics, which specific questions reference your content, competitor PAA presence comparison

### Voice Search Visibility
- **What**: Whether your content is selected as the voice assistant answer for target queries
- **Why it matters**: Voice assistants read one answer. You are either the answer or invisible.
- **Tools**: Manual testing with Google Assistant, Siri, Alexa; some third-party tracking tools emerging
- **Track**: Voice answer attribution for priority queries, voice-driven branded searches (correlating indicator)
- **Reality check**: Voice search measurement is still immature. Manual testing of priority queries is the most reliable method currently available.

### Zero-Click Visibility Indicators
- **What**: Signals that your content is being seen but not clicked because the answer is delivered on the SERP
- **Why it matters**: Zero-click does not mean zero value. Brand impressions and authority still accrue.
- **Tools**: Google Search Console
- **Track**: Queries with high impressions but unusually low CTR (especially question queries), impression trends for snippet-held queries
- **Interpret carefully**: Low CTR on a query where you hold the snippet is normal AEO behavior, not a problem to fix

### Rich Result Performance
- **What**: Performance of pages with *currently supported* structured-data rich results (review stars, product, breadcrumbs, video, etc.). Note: FAQ and HowTo rich results are deprecated, and their Search Console reports / Rich Results Test support are being retired in 2026 — do not track them as live rich results (timeline in `technical-seo.md` §6)
- **Tools**: Google Search Console (Enhancements reports), Rich Results Test
- **Track**: Valid vs. invalid structured data items, CTR comparison for pages with vs. without rich results, rich result types active

---

## GEO Metrics

### AI Citation Frequency
- **What**: How often AI platforms mention your brand when answering questions related to your domain
- **Why it matters**: Direct measure of AI visibility. Higher frequency means more brand exposure through AI channels.
- **How to track (free)**: Maintain a spreadsheet of 20-50 target queries relevant to your domain. Test monthly across ChatGPT, Perplexity, Google AI Mode, and Claude. Record: cited (yes/no), position in response, exact wording used, competitors also mentioned.
- **Track**: Citation count by AI platform, citation count by topic area, citation count by query type
- **Segment by**: AI platform, topic area, query type

### Share of Voice in AI Answers
- **What**: Your mention frequency compared to competitors for the same queries
- **Why it matters**: Shows competitive positioning in AI discovery
- **How to track (free)**: Use the same query spreadsheet. For each query, note which brands are mentioned. Calculate your share: your mentions / total brand mentions across all queries.
- **Example**: For 50 queries about "best CRM software," Brand A appears 25 times, Brand B appears 18 times, your brand appears 8 times. Your share of voice = 8/51 = 16%.

### Sentiment in AI Mentions
- **What**: Whether AI answers frame your brand positively, neutrally, or negatively
- **Why it matters**: Being mentioned is not enough. Negative framing is worse than not being mentioned.
- **How to track (free)**: When recording citations, add a sentiment column (positive/neutral/negative). Note the exact framing. Track trends over time.
- **Improve by**: Addressing root causes of negative sentiment (product issues, support gaps), building positive content and reviews on third-party platforms.

### Context / Prompt Tracking
- **What**: Which specific questions, topics, or prompts trigger mentions of your brand in AI answers
- **Why it matters**: Reveals which topics you "own" in AI perception vs. where you are invisible
- **How to track (free)**: Organize your query spreadsheet by topic cluster. After 2-3 months, patterns emerge showing which topics consistently cite you and which don't.
- **Use for**: Identifying content gaps (topics where you should appear but don't) and strengths (topics where you consistently appear).

### AI Referral Traffic
- **What**: Visits to your site that originated from AI platforms
- **How to track (free)**: GA4's built-in **"AI Assistant" default channel group** launched ~**May 13 2026** (Google's docs): it auto-tags recognized AI traffic with medium `ai-assistant`, channel `AI Assistant`, and campaign `(ai-assistant)`, with no configuration — check Reports → Acquisition → Traffic acquisition. It is **non-retroactive** and rolling out gradually, so it may not appear in every property yet. Google officially names **only ChatGPT, Gemini, and Claude** (it has not published a fuller list — do not assume Perplexity or "20+ assistants" are covered natively). As a supplement, add a custom channel group covering `chatgpt.com`, `perplexity.ai`, `gemini.google.com`, `claude.ai`, `copilot.microsoft.com`, `bing.com`. To detect AI *visits* in server logs, look for the search/user-initiated agents (OAI-SearchBot, ChatGPT-User, PerplexityBot, Perplexity-User, Claude-SearchBot, Claude-User) — not Google-Extended (an opt-out token for Gemini training/grounding, not a fetcher). See the canonical crawler table in `technical-seo.md`.
- **Reality check (material undercount)**: **35-70% of AI sessions still land in Direct** because mobile-app/in-app clicks strip the referrer (Statcounter, Mar 2026), so GA4 materially undercounts AI traffic. Supplement with "how did you hear about us?" surveys that include an AI option.
- **Track what you can**: Referral traffic from perplexity.ai, chatgpt.com, and other AI platforms that include referral information.

---

## Integrated Measurement Framework

### The Three-Dashboard Approach

**Dashboard 1: Traditional SEO Performance**
- Organic traffic trends
- Keyword ranking positions
- CTR trends
- Backlink growth
- Core Web Vitals status
- Indexation health
- Conversions from organic

**Dashboard 2: Answer Engine Performance (AEO)**
- Featured snippet ownership and changes
- People Also Ask presence
- Rich result performance (currently-supported types — note FAQ/HowTo rich results are deprecated; see `technical-seo.md` §6)
- Voice search visibility (manual audit results)
- Zero-click indicators (high impression / low CTR question queries)

**Dashboard 3: AI Visibility Performance (GEO)**
- AI citation frequency (overall and by platform)
- Share of voice vs. competitors
- Sentiment distribution
- Topic/prompt coverage map
- AI referral traffic (where measurable)

### Connecting the Three

While direct attribution across all three layers is limited, look for correlating signals:

- **Featured snippet ownership to AI citations**: Content that wins snippets is often the same content AI systems cite. Track whether snippet wins correlate with increased AI mentions.
- **Branded search volume increase**: If answer features and AI platforms mention your brand more, branded searches often increase. Track branded query volume in GSC.
- **Direct traffic increase**: Both AEO and GEO brand visibility can increase direct visits.
- **Conversion path analysis**: In GA4, look at assisted conversions and multi-touch attribution.
- **Survey data**: Ask new customers "how did you hear about us?", include both "saw answer in search results" and "AI tool recommended" as options.

### Reporting Cadence

| Metric Category | Recommended Cadence |
|----------------|-------------------|
| Organic traffic, rankings, conversions | Weekly review, monthly report |
| Core Web Vitals, indexation | Monthly check |
| Backlink growth | Monthly review |
| Featured snippet ownership, PAA presence | Monthly tracking |
| Rich result performance | Monthly check |
| Voice search audit (manual) | Quarterly |
| AI citation frequency, share of voice | Monthly tracking |
| AI sentiment | Quarterly assessment |
| Competitive benchmarking (SEO + AEO + GEO) | Quarterly deep dive |
| Full audit (technical SEO + AEO + GEO readiness) | Semi-annual or annual |

---

## Tools Landscape

### Traditional SEO
- **Google Search Console**: Free. Rankings, impressions, CTR, indexation, Core Web Vitals. Essential.
- **Google Analytics 4**: Free. Traffic, user behavior, conversions. Essential.
- **Semrush / Ahrefs / Moz**: Paid. Keyword research, competitor analysis, backlink monitoring, site audits. Choose one as your primary platform.
- **Screaming Frog / Sitebulb**: Paid. Technical SEO crawling and auditing.
- **PageSpeed Insights / Lighthouse**: Free. Core Web Vitals and performance analysis.

### AEO
- **Semrush / Ahrefs**: SERP feature tracking including featured snippets and PAA presence.
- **AlsoAsked**: People Also Ask data mining and visualization.
- **Google Search Console**: Impression/CTR data for identifying zero-click patterns.
- **Rich Results Test**: Validates structured data eligibility.
- **Manual voice assistant testing**: Direct testing on Google Assistant, Siri, Alexa for priority queries.

### GEO / AI Visibility (Zero-Cost)
- **Manual prompt testing**: Spreadsheet of 20-50 queries, test monthly across ChatGPT/Perplexity/Google AI Mode/Claude. See GEO Metrics section above for tracking details.
- **GA4 AI Assistant channel**: Built-in default channel group (added ~May 2026, automatic; medium `ai-assistant`) covering ChatGPT/Gemini/Claude and others. Supplement with a custom channel group for any platforms GA4 hasn't recognized (`chatgpt.com`, `perplexity.ai`, `gemini.google.com`, `claude.ai`, `copilot.microsoft.com`, `bing.com`).
- **GSC brand query trends**: Rising branded searches = indirect GEO attribution.
- **Server logs**: Check AI search/user-initiated agents (OAI-SearchBot, ChatGPT-User, PerplexityBot, Perplexity-User, Claude-SearchBot, Claude-User) — see the canonical table in `technical-seo.md`.
- **Signup survey**: Add "AI tool recommended it" option.

### Dedicated AI-visibility tools (paid)
Purpose-built platforms for tracking AI citations / share of voice at scale (the scalable alternative to the manual prompt spreadsheet above): **Profound** (enterprise category leader), **Peec AI**, **Otterly**, **ZipTie**, **LLMrefs**. See `ai-platform-optimization.md` for coverage details — this market moves fast, so verify current coverage and pricing before committing.

### Integrated
- **Semrush**: Offers traditional SEO tools, SERP feature tracking (AEO), and AI visibility tracking in Enterprise tier.

---

## Measurement Pitfalls to Avoid

- **Do not treat low CTR as always bad**: For question queries where you hold a snippet, low CTR with high impressions is AEO success, not failure.
- **Do not ignore AEO/GEO because they are hard to measure**: The attribution gap does not mean visibility is not valuable.
- **Do not over-index on volatile AI metrics**: AI citation sources are highly volatile — a single platform or algorithm change has shifted a domain's citation share by ~50% within weeks (e.g., Reddit's ChatGPT share collapsing from ~60% to ~10% in 2025). Look at trends over quarters, not days.
- **Do not abandon traditional SEO metrics**: Rankings and organic traffic still drive the majority of measurable conversions.
- **Do not conflate correlation with causation**: Branded search increases could come from many sources, not just answer features or AI visibility.
- **Do not measure everything, measure what matters**: Focus on metrics that connect to business outcomes.
- **Do not judge GEO on engagement KPIs — judge it on conversions, segmented by engine and industry**: AI-referred visitors *bounce more* (67.8% vs 63.7%) and view fewer pages (4.0 vs 5.2) than search visitors; time on site is the only engagement metric AI "won" (86s vs 78s) (Ahrefs cross-site study, ~82K sites, May-Jun 2025). Yet AI traffic converts disproportionately well in some datasets (Ahrefs' own site: 0.5% of traffic but 12.1% of signups). By classic engagement dashboards AI traffic looks *worse*, so they mislead. **Conversion direction is contested** — a 94-brand ecommerce study found ChatGPT converted ~31% higher than *non-branded* organic but at ~1.4% of the volume (Visibility Labs / Search Engine Land, Feb 2026), while a larger academic study (973 sites) found ChatGPT trailing organic overall — so present a modest, segmented lift, not the inflated 4-23x multiples in vendor blogs. Volume benchmark: AI referral is ~**1.08% of total traffic** (Conductor 2026; IT sector highest ~2.8%), and conversion varies by engine (~3.2% ChatGPT/Claude, ~2.3% Gemini/Perplexity; 0.7-7.0% by industry — First Page Sage, Apr 2026). Treat all as directional, re-verify quarterly.
- **Read citation-frequency metrics with wide error bars**: AI search tools gave *incorrect* source attributions in **>60% of 200 tests** across 8 tools (Tow Center, Columbia, Mar 2025; per-tool range 37% Perplexity to 94% Grok 3). Even well-structured content can be cited inaccurately or mis-attributed. **Decision:** put brand-name and entity clarity *inside* the liftable block itself (not just correct facts), and don't over-read small month-to-month citation-share swings.
