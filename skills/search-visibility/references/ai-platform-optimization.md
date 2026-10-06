# AI Platform Optimization

Specific tactics for maximizing visibility in AI-powered search and answer platforms. Extends the GEO principles in the main skill with platform-specific and monitoring strategies.

See also (not prerequisites; each is linked directly from SKILL.md): `geo-content-extractability.md`, `geo-entity-clarity.md`, `geo-multi-platform.md` for the foundational GEO concepts.

---

## Table of Contents

1. [How AI Search Platforms Select Sources](#how-ai-search-platforms-select-sources)
2. [The Three Pillars of AI Optimization](#the-three-pillars-of-ai-optimization)
3. [AI Visibility Audit](#ai-visibility-audit)
4. [Content Types That Get Cited Most](#content-types-that-get-cited-most)
5. [Schema Markup for AI](#schema-markup-for-ai)
6. [Monitoring AI Visibility](#monitoring-ai-visibility)
7. [Common Mistakes](#common-mistakes)
8. [2025-2026 AI Search Landscape Updates](#2025-2026-ai-search-landscape-updates)
9. [Agentic Commerce — Being Purchasable, Not Just Cited](#agentic-commerce--being-purchasable-not-just-cited)
10. [Non-English Surfaces — Korea / Naver](#non-english-surfaces--korea--naver)


## How AI Search Platforms Select Sources

| Platform | How It Works | Source Selection |
|----------|-------------|----------------|
| **Google AI Overviews** | Summarizes top-ranking pages | Strong correlation with traditional rankings |
| **ChatGPT (with search)** | Searches web, cites sources | Wider range, not just top-ranked |
| **Perplexity** | Always cites sources with links | Favors authoritative, recent, well-structured content |
| **Gemini** | Google's AI assistant | Google index + Knowledge Graph |
| **Copilot** | Bing-powered AI search | Bing index + authoritative sources |
| **Claude** | Brave Search (when enabled) | Training data + Brave search results |

**Key difference from traditional SEO:** Traditional SEO gets you ranked. AI SEO gets you **cited**. A well-structured page can get cited even if it ranks on page 2 or 3.

**Critical stats** (as of early 2026 — these move fast; keep the date and re-verify). Each stat is followed by the decision it should drive:
- AI Overviews appear in roughly **15-25% of Google queries in broad global keyword studies** (Semrush: peaked ~25% mid-2025, ~16% by Nov 2025), but **45-60% in US-focused / curated-keyword trackers** and per Google's own framing (Advanced Web Ranking ~60% of US queries; BrightEdge/Google ~50%). Varies widely by country, intent, device, and measurement method — treat as directional, not a single fact. **Decision:** measure AIO presence on *your own* tracked query set rather than picking a headline number; size the GEO investment to how many of your queries actually trigger an AIO
- AI Overviews initially cut click-through to the **top organic result sharply** when present (Seer Interactive headlines a **~61% CTR decline** Q3→Q4 2025; an earlier iteration of the study put it at ~58%), **but that decline reversed in early 2026.** Per Seer (Apr 24 2026; 53 brands, 5.47M queries, 2.43B impressions, Jan 2025–Feb 2026), organic CTR on AIO queries rebounded from a **1.3% floor (Dec 2025) to 2.4% (Feb 2026)** — an ~85% jump that reversed an 18-month slide. **Being cited now pays:** cited brands earn **~+120% more clicks per impression than uncited** (roughly 2.2x), though cited pages still trail the no-AIO baseline by ~38% (treat as directional, single-study, re-verify quarterly — these are moving fast). **Decision:** for AIO-present queries, target citation *inside* the AIO (it is now worth ~2.2x the clicks of being uncited), and stop modeling AIO as a permanently collapsing CTR ceiling — GEO effort now compounds rather than fighting a falling floor
- Brands are reportedly cited via third-party sources (Reddit, Wikipedia, review sites) far more than via their own domains. **Decision:** fund third-party presence (Reddit, Wikipedia, review sites) alongside on-site content, not after it
- Well-structured, sourced content is cited materially more often than thin/undated content. **Decision:** add visible dates, authors, and sources to priority pages before chasing new content
- Adding statistics and citing sources are among the highest-leverage on-page tactics (see the GEO study below). **Decision:** prioritize adding cited statistics and quotations to existing pages as the first GEO action

**Assistant market share is re-ranking — stop treating Claude and Gemini as secondary** (as of Oct 2026; trackers disagree widely by methodology, treat as directional and re-verify quarterly). ChatGPT's share fell well below its earlier ~85-87% dominance. First Page Sage (Oct 1 2026 update, Sept 2026 data, US methodology): **ChatGPT 52.1%, Gemini 26.9%, Claude 10.6%, Perplexity 1.9%, Copilot 1.3%**. Other trackers diverge hard — StatCounter has shown ChatGPT ~77% with Claude ~3%; SimilarWeb ~68% with Gemini #2 (~18%) and Claude ~2% (mid-2026 readings) — so the *exact* shares and the size of Claude's slice are methodology-dependent; Gemini as the clear #2 is the one point most trackers now share. Scale check: Gemini's app reached ~750M MAU (Google Q4'25 earnings, Feb 2026) and reportedly ~900M by May 2026, vs ChatGPT ~900M weekly active users (Feb 2026). **Decision:** size GEO across at least ChatGPT, Claude, and Gemini — optimizing only for ChatGPT/Google now leaves a large, double-digit slice of assistant usage uncovered. Pick the share figure that matches your own measured referral mix, not a headline.

---

## The Three Pillars of AI Optimization

### Pillar 1: Structure — Make Content Extractable

AI systems extract passages, not pages. Every key claim should work as a standalone statement.

**Content block patterns:**
- **Definition blocks** for "What is X?" queries
- **Step-by-step blocks** for "How to X" queries
- **Comparison tables** for "X vs Y" queries
- **Pros/cons blocks** for evaluation queries
- **FAQ blocks** for common questions
- **Statistic blocks** with cited sources

**Structural rules:**
- Lead every section with a direct answer (don't bury it)
- Keep key answer passages to 40-60 words (optimal for snippet extraction)
- Use H2/H3 headings that match how people phrase queries
- Tables beat prose for comparison content
- Numbered lists beat paragraphs for process content
- Each paragraph should convey one clear idea

### Pillar 2: Authority — Make Content Citable

The **GEO study** (Aggarwal et al., *GEO: Generative Engine Optimization*, KDD 2024 — [arXiv:2311.09735](https://arxiv.org/abs/2311.09735); a Princeton / Georgia Tech / Allen AI / IIT Delhi paper, tested across multiple generative engines, **not** a "Perplexity.ai study") found GEO methods can boost visibility by **up to ~40%**. Its three strongest methods are citing sources, adding quotations, and adding statistics (collectively a 30-40% relative improvement on the paper's Position-Adjusted Word Count metric):

| Method | Effect | How to apply |
|--------|--------|--------------|
| **Cite sources** | Top tier | Add authoritative references with links |
| **Add quotations** | Top tier (strongest single method on one metric) | Expert quotes with name and title |
| **Add statistics** | Top tier | Include specific numbers with sources |
| **Authoritative tone / clarity / fluency** | Positive, smaller | Write with demonstrated expertise; simplify; improve flow |
| ~~Keyword stuffing~~ | **Counterproductive** | Do not do it — does not help and can hurt AI visibility |

**Biggest lever for underdogs:** citing credible external sources gave a **~115% visibility increase specifically for pages ranked ~5th** in the SERP (while top-ranked pages actually *lost* ~30%) — i.e., citations help lower-ranked pages most. The paper's exact per-method percentages depend on which metric you read (Position-Adjusted Word Count vs Subjective Impression), so pull them from its tables if you need precise figures rather than treating any single number as canonical.

**Freshness signals:**
- "Last updated: [date]" prominently displayed
- Regular content refreshes (quarterly minimum)
- Current year references and recent statistics
- Remove or update outdated information

### Pillar 3: Presence — Be Where AI Looks

AI systems don't just cite your website — they cite where you appear.

**Third-party sources matter more than your own site:**
- **Reddit** — still the **#1 most-cited domain by absolute volume** across AI platforms (Peec AI 30M-source study, Mar 31 2026, ranks it #1 overall; ~2.5x YouTube's total citations) and ~12% of ChatGPT citations in Q1 2026. Highly volatile — Reddit's ChatGPT share swung from ~60% to ~10% within two weeks in Sept 2025
- **YouTube** — now the **most-cited *social* source by share-of-answers** (cited in ~16% of LLM answers vs Reddit's ~10% over a trailing 6 months — Bluefish, reported by Adweek ~Jan 2026; YouTube's social-citation share roughly doubled Aug–Dec 2025 per Goodie AI's 6.1M-citation analysis) as LLMs extract from transcripts. **Decision:** treat video *with a full transcript* as a first-class citation asset, not a secondary channel — a video without a transcript is invisible to text retrieval (see `technical-seo.md` §8)
- **Wikipedia** — consistently a top source (~8% of ChatGPT citations in 2024-25 per Profound; higher in some Q1 2026 reads)
- **Per-engine source pools diverge** — the same Peec study confirms platforms pull from largely different pools (ChatGPT favors Wikipedia/Reddit/Forbes; Google AI favors Facebook/Yelp; Perplexity favors Reddit/LinkedIn/G2). Independent analyses (The Digital Bloom; Averi/Profound) put ChatGPT↔Perplexity domain overlap at only ~11%. **Decision:** a single citation strategy for all engines is wrong — split source-targeting by engine (e.g., Yelp/Facebook for Google, G2/LinkedIn for Perplexity B2B) and track citation share per engine, not in aggregate
- Industry publications and guest posts
- Review sites (G2, Capterra, TrustRadius for B2B SaaS)
- Quora answers

(Citation shares vary by platform, study, and month — treat all figures as directional and re-check quarterly.)

**Actions:**
- Ensure your Wikipedia page is accurate and current
- Participate authentically in Reddit communities
- Get featured in industry roundups and comparison articles
- Maintain updated profiles on relevant review platforms
- Create YouTube content for key how-to queries

---

## AI Visibility Audit

### Step 1: Check AI Answers for Key Queries

Test 10-20 important queries across platforms:

| Query | Google AI Overview | ChatGPT | Perplexity | You Cited? | Competitors Cited? |
|-------|:-----------------:|:-------:|:----------:|:----------:|:-----------------:|
| [query 1] | Yes/No | Yes/No | Yes/No | Yes/No | [who] |

**Query types to test:**
- "What is [your product category]?"
- "Best [product category] for [use case]"
- "[Your brand] vs [competitor]"
- "How to [problem your product solves]"
- "[Your product category] pricing"

### Step 2: Analyze Citation Patterns

When competitors get cited and you don't, examine:
- **Content structure** — Is their content more extractable?
- **Authority signals** — More citations, stats, expert quotes?
- **Freshness** — More recently updated?
- **Schema markup** — Structured data you're missing?
- **Third-party presence** — Cited via Wikipedia, Reddit, review sites?

### Step 3: Content Extractability Check

For each priority page, verify:

| Check | Pass/Fail |
|-------|-----------|
| Clear definition in first paragraph? | |
| Self-contained answer blocks? | |
| Statistics with sources cited? | |
| Comparison tables for "X vs Y" queries? | |
| FAQ section with natural-language questions? | |
| Schema markup (FAQ, HowTo, Article, Product)? | |
| Expert attribution (author name, credentials)? | |
| Recently updated (within 6 months)? | |
| Heading structure matches query patterns? | |
| AI bots allowed in robots.txt? | |

### Step 4: AI Bot Access Check

Verify robots.txt allows the AI crawlers you want (see the canonical table in `technical-seo.md`):
- **OAI-SearchBot** (ChatGPT Search citation — this is the one that controls ChatGPT Search visibility), **ChatGPT-User** (live fetch), **GPTBot** (training) — OpenAI
- **PerplexityBot**, **Perplexity-User** — Perplexity
- **Claude-SearchBot** (search), **Claude-User** (live fetch), **ClaudeBot** (training) — Anthropic
- **Googlebot** — powers Google AI Overviews and AI Mode
- **Google-Extended** / **Applebot-Extended** — opt-out *tokens* (not fetchers): Google-Extended controls use for Gemini training and for grounding in Gemini Apps / Vertex AI (not Search or AI Overviews); Applebot-Extended controls Apple Intelligence training
- **Bingbot** — Microsoft Copilot

Blocking the **search/citation** bots (OAI-SearchBot, PerplexityBot, Claude-SearchBot) prevents those platforms from citing you. You can allow search bots while blocking training-only crawlers (GPTBot, ClaudeBot, CCBot). Caveat: robots.txt does not reliably control every vendor — Cloudflare documented (Aug 2025) PerplexityBot using **undeclared stealth crawlers** that rotate IPs and impersonate browsers to evade no-crawl directives, and de-listed it as a verified bot.

---

## Content Types That Get Cited Most

Ranked roughly by how often each format gets cited (published citation-share percentages vary widely by study and shift month to month — e.g., listicle citation rates moved sharply over a single month in late 2025 — so rank the formats rather than trusting fixed percentages):

| Content Type | Why AI cites it |
|-------------|----------------|
| **Best-of / listicles** | Clear structure, entity-rich — often the single most-cited format |
| **Comparison / "X vs Y" articles** | Structured, balanced, high-intent |
| **Definitive guides** | Comprehensive, authoritative |
| **Original research / data** | Unique, citable statistics |
| **Product pages** | Specific details AI can extract |
| **How-to guides** | Step-by-step structure |

**Underperformers:** Generic blog posts, thin product pages, gated content, content without dates/author attribution, PDF-only content.

---

## Schema Markup for AI

| Content Type | Schema | Why It Helps |
|-------------|--------|-------------|
| Articles/Blog posts | `Article`, `BlogPosting` | Author, date, topic identification |
| How-to content | `HowTo` | Step extraction for process queries |
| FAQs | `FAQPage` | Direct Q&A extraction |
| Products | `Product` | Pricing, features, reviews |
| Comparisons | `ItemList` | Structured comparison data |
| Organization | `Organization` | Entity recognition |

Structured data helps Google and Bing/Copilot reliably parse entities, pricing, and Q&A — Microsoft confirms Bing/Copilot uses schema; Google says no special schema is needed for AI Overviews/AI Mode. But it is **not a proven citation lever** on the AI engines that parse plain text. A controlled Ahrefs test (May 11 2026, 1,885 pages adding JSON-LD vs ~4,000 controls) found Google AI Overviews **−4.6%**, AI Mode **+2.4%**, ChatGPT **+2.2%** (the last two indistinguishable from noise); the widely-repeated "~3x more likely to have JSON-LD" correlation is confounded (schema co-occurs with better-maintained, higher-authority sites). Independent retrieval tests (searchVIU, Dec 2025) found ChatGPT/Claude/Perplexity/Gemini/AI Mode extract only visible HTML and ignore JSON-LD during direct retrieval (treat as directional, re-verify). **Decision:** treat schema as extraction infrastructure for Google/Bing parsing accuracy, not a citation multiplier — do not over-invest in markup at the expense of extractable, stat-dense on-page content.

---

## Monitoring AI Visibility

### Metrics to Track

| Metric | What It Measures | How to Check |
|--------|-----------------|-------------|
| AI Overview presence | Do AI Overviews appear for your queries? | Manual check or Semrush/Ahrefs |
| Brand citation rate | How often you're cited in AI answers | AI visibility tools |
| Share of AI voice | Your citations vs. competitors | Peec AI, Otterly, ZipTie |
| Citation sentiment | How AI describes your brand | Manual review |
| Source attribution | Which pages get cited | Track referral traffic from AI sources |

### AI Visibility Monitoring Tools

This market moves fast — verify current coverage and pricing before committing.

| Tool | Coverage | Best For |
|------|----------|----------|
| **Profound** | ChatGPT, Perplexity, Google AI Overviews/AI Mode, Gemini, Copilot | Enterprise-scale AI-visibility tracking (current category leader) |
| **Otterly AI** | ChatGPT, Perplexity, Google AI Overviews | Share of AI voice tracking |
| **Peec AI** | ChatGPT, Gemini, Perplexity, Claude, Copilot+ | Multi-platform monitoring at scale |
| **ZipTie** | Google AI Overviews, ChatGPT, Perplexity | Brand mention + sentiment tracking |
| **LLMrefs** | ChatGPT, Perplexity, AI Overviews, Gemini | SEO keyword to AI visibility mapping |

### DIY Monitoring (No Tools)

Monthly manual check:
1. Pick your top 20 queries
2. Run each through ChatGPT, Perplexity, and Google
3. Record: Are you cited? Who is? What page?
4. Log in a spreadsheet, track month-over-month

---

## Common Mistakes

- **Ignoring AI search** — AI Overviews now appear on a large and growing share of Google searches (see Critical stats above)
- **Treating AI SEO as separate from SEO** — Good traditional SEO is the foundation
- **Writing for AI, not humans** — Content must read naturally
- **No freshness signals** — Undated content loses to dated content
- **Gating all content** — AI can't access gated content
- **Ignoring third-party presence** — Wikipedia mentions may matter more than your blog
- **Keyword stuffing** — Actively reduces AI visibility by 10%
- **Blocking AI bots** — Prevents those platforms from citing you
- **Generic content without data** — "We're the best" won't get cited

---

## 2025-2026 AI Search Landscape Updates

The AI search surface is fragmenting. Optimize per platform — not just for "AI" in general. (Landscape as of early 2026 — these facts move quickly; re-verify and re-date this table.)

| Surface | What changed | What to do |
|---|---|---|
| **Google AI Search — AI Overviews + AI Mode merged** (I/O 2026) | At I/O 2026 (May 2026) Google merged AI Overviews and AI Mode into one seamless AI Search experience — Gemini 3.5 Flash as default model, live worldwide; AI Mode passed 1B monthly users. "Separate tab" framing is obsolete; agentic "query fan-out" is now default-Search behavior | Optimize for the implied sub-questions (see "Optimizing for AI Mode" below); favors structured, source-able content; track the merged surface as one |
| **Google AI Overviews** (within the merged experience) | On a large share of searches (~15-25% in broad global studies, 45-60% in US/curated trackers; pre-merge figures); appearance volatile | Optimize for citation, not click — measure mentions, not just CTR |
| **ChatGPT Search** (search.chatgpt.com) | Launched late 2024; distinct from ChatGPT-with-browsing. Controlled by OAI-SearchBot in robots.txt | Source-citation behavior differs from Perplexity; track separately |
| **Perplexity Spaces / Shopping** | Product-recommendation surfaces with structured product data | Product schema (Offer, Review, AggregateRating) is now key for product visibility |
| **Apple Intelligence / Gemini-powered Siri** (iOS 26.x, rolling out 2026) | Jan 2026: Apple signed a multi-year deal (reported ~$1B/yr) for a custom Google **Gemini** model to power the rebuilt Siri and Apple Foundation Models; first features in iOS 26.4, fuller conversational Siri expected at iOS 27 (Sept 2026). ChatGPT (GPT-5) remains an optional handoff, not the default | Gemini/Google signals increasingly drive Apple-device AI answers — prioritize the same structured, source-able content that helps in Gemini / AI Overviews. ChatGPT still matters as a secondary handoff |
| **Reddit Answers** | Reddit's own AI answer feature launched 2024 | Reddit presence (genuine, not spam) matters even more |
| **llms.txt** | A community convention (roughly 9-12% adoption in most 2026 samples, higher in some — varies by sample, directional); **no major AI vendor documents consuming it** — Google's John Mueller likened it to the deprecated keywords meta tag, and crawlers fetch HTML, not llms.txt | Low cost, speculative benefit — publish if trivial (see "llms.txt" below), but do not prioritize it or expect citation impact |
| **Cloudflare "Content Independence Day"** (July 1 2025) | New domains **block all known AI crawlers by default**, plus a "Pay Per Crawl" marketplace for paid access. Cloudflare fronts ~22% of the web, so this is a structural shift in AI crawl access | Audit your CDN/bot settings so you are not blocking the search/citation crawlers you want (OAI-SearchBot, PerplexityBot, Claude-SearchBot) |

**Practical implication:** measure citation share across at least Google AI Mode, AI Overviews, ChatGPT (Search + browsing), Perplexity, and Gemini. A tool like Profound, Peec AI, or Otterly will cover the spread; rolling your own monthly check works for smaller sites.

### Optimizing for Google AI Mode (query fan-out)

AI Mode does not answer your exact query directly — it decomposes it into multiple related sub-questions ("query fan-out"), retrieves passages for each, and synthesizes one answer. Since the May 2026 I/O merge, this fan-out behavior is part of the default Google AI Search experience, not an opt-in tab. Practical implications:

- Optimize for the **sub-questions implied by a topic**, not just the head query. A page that only answers "best CRM" may be skipped in favor of pages that cleanly answer "best CRM for small teams," "CRM with the easiest setup," "CRM pricing compared," etc.
- Cover a topic comprehensively with **self-contained, individually-extractable passages** (one clear answer per heading) so different fan-out sub-questions can each retrieve a relevant chunk.
- Entity clarity and topical authority (see `geo-entity-clarity.md`) matter more here than exact-match keywords, because retrieval is semantic.
- There is no "rank 1" in AI Mode — success is being one of the sourced passages across several sub-questions for a topic.

### llms.txt (how-to, with caveat)

`llms.txt` is a proposed plain-Markdown file at `/llms.txt` that lists your most important URLs (and optionally `/llms-full.txt` with full content) so LLMs can find canonical content. To publish one: place a Markdown file at the site root with an H1 title, a short summary blockquote, and sectioned lists of links with brief descriptions.

**Caveat (important):** as of early 2026 **no major AI vendor has confirmed reading llms.txt**; crawlers fetch your HTML, and Google's John Mueller compared it to the deprecated keywords meta tag. Adoption is roughly 9-12% in most 2026 samples (varies by sample), and one 2026 log study found ~97% of llms.txt files received no AI requests. It is cheap to publish but should be treated as a speculative, low-priority gesture — do not invest heavily or expect a citation lift.

---

## Agentic Commerce — Being Purchasable, Not Just Cited

Beyond citation, a 2025-2026 agentic-checkout layer now lets assistants *transact*. For product/ecommerce brands, on-page content alone no longer makes you buyable inside AI. (Landscape as of Oct 2026 — moving fast, re-verify and re-date.)

| Surface | Mechanism | Entry ticket / fee | Notes |
|---|---|---|---|
| **OpenAI/Stripe ACP** (Agentic Commerce Protocol, Sept 29 2025) | Powered ChatGPT Instant Checkout via a Shared Payment Token (merchant stays merchant-of-record). **Instant Checkout was discontinued in March 2026** after weak conversion; OpenAI moved shopping to merchant apps inside ChatGPT that use the merchant's own checkout, and is monetizing via ads rather than a checkout cut | The former **4% Instant Checkout fee no longer applies**; entry is now product-data/feed quality for ChatGPT shopping discovery plus a merchant app if you want an in-ChatGPT storefront (re-verify current OpenAI merchant docs) | Instant Checkout converted poorly (~3x worse than Walmart.com per Walmart EVP; <1% buy-button conversion reported) |
| **Google UCP** (Universal Commerce Protocol, Jan 11 2026) | Agentic discovery + checkout over the Shopping Graph (50B+ listings Jan, 60B+ by May 2026); A2A/MCP + AP2 | A complete **Merchant Center feed + checkout-eligible products**. **No added Google fee** | Co-launched with Shopify/Etsy/Wayfair/Target/Walmart. The feed (not just web content) is the entry ticket to AI Mode/Gemini shopping |
| **Amazon "Alexa for Shopping"** (Rufus retired into it, May 13 2026) | "Buy for Me" agent checks out on third-party retailer sites using stored card/address | Strong product attributes, reviews, Q&A discoverability | Grew 65K → 500K+ products; some retailers say they never opted in |
| **Perplexity "Buy with Pro" + Merchant Program** | One-click in-chat checkout on PayPal/Venmo rails; merchant stays merchant-of-record | **Zero merchant fee**; ~5-min enrollment | Low-friction enrollment step distinct from generic Perplexity citation work (program details vendor-sourced — directional) |
| **AP2** (Agent Payments Protocol, donated to FIDO Alliance Apr 28 2026) | Signs Intent/Cart/Payment mandates as tamper-proof authorization | Verified product data + merchant trust signals | Payment auth is converging on signed-mandate standards; MCP Storefront servers are emerging as the "plumbing" (directional/unverified) |

**Decision:** for any transactable brand, treat a clean machine-readable product feed (Google Merchant Center for AI Mode/Gemini; OpenAI's merchant product data for ChatGPT shopping; Perplexity's Merchant Program) plus agentic-checkout endpoints where a surface offers them as a *separate workstream from citation GEO*, and weigh fees vs reach per surface as a real merchant decision. Being cited/recommended in ChatGPT still matters now that its native checkout is gone — ChatGPT sends the buyer to your own checkout.

---

## Non-English Surfaces — Korea / Naver

This skill is English-global; Korea is the one market with hard platform-disclosed data and a structurally different playbook (as of mid-2026 — re-verify; per-language LLM-citation research is thin, so lean on platform-disclosed data and DIY per-language prompt tracking, not inferred LLM behavior).

- **Naver (~64% Korean search share)** launched **AI Briefing**, which draws **~70% of its citations from Naver's own properties** — mainly walled-garden UGC (Blog, Cafe, Knowledge iN, Premium Content) plus SmartPlace/News (reported figure, not independently verified — directional). A global-web playbook (own-domain articles, schema, backlinks) is largely *invisible* to Naver AI. **Decision:** for Korean queries, the highest-leverage tactic is publishing optimized content *inside* Naver's ecosystem, and tracking AI Briefing citation share as the core Korean KPI.
- **"Naver Mate" (launching June 2026)** pays ~3,000 creators/month selected by AI Briefing citation frequency (creator-stipend pool ~20bn won/yr, inside a broader 1 trillion won / 5-yr ecosystem investment) — a literal pay-for-AI-citation economy.
- **Obsolete targets:** Naver's standalone Cue: (discontinued Mar 2025) and Clova X (shut down Apr 9 2026). The live surfaces are **AI Briefing** now and **AI Tab/agents** next. ChatGPT (GPT-5) is also embedded in KakaoTalk.
- **Cross-cutting multilingual rule:** non-English pages that merely duplicate an English page get "semantically collapsed" and dropped — a machine-translated mirror does **not** inherit citations. Each locale needs net-new local facts, entities, and authority (Motoko Hunt, Search Engine Land, Jan 2026). Anchor cross-lingual entity recognition to a language-stable Wikidata Q-ID (see `geo-entity-clarity.md`).
