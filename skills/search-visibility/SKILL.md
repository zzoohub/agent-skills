---
name: search-visibility
description: |
  Search visibility strategy unifying SEO (Search Engine Optimization), AEO
  (Answer Engine Optimization), and GEO (Generative Engine Optimization).
  Use when: SEO/AEO/GEO work, search or AI visibility, keyword research,
  on-page/technical SEO, backlinks, content strategy, AI citations, content
  extractability, entity clarity, multi-platform presence, or mentions "SEO",
  "AEO", "GEO", "AI search", "search optimization", "ranking", "organic traffic",
  "generative engine", "answer engine", "featured snippet", "voice search",
  "People Also Ask", "zero-click", "FAQ schema", "direct answers", "schema
  markup", "structured data", "llms.txt", "AI Overviews", "AI Mode", "ChatGPT
  citations", "Perplexity", "Core Web Vitals", "hreflang".
  Do NOT use for: social media content (use social-content), email content (use
  email-marketing), ad copy (use ad-creative), UX copy or microcopy (use
  copywriting), or competitor comparison page formats (use competitor-pages).
  This skill only adds the SEO/AEO/GEO layer on top of those.
---

# Search Visibility Skill

A unified skill for optimizing brand and content visibility across traditional search engines, answer engines, and AI-generated answer platforms.

**SEO** (Search Engine Optimization) optimizes for rankings, clicks, and organic traffic in Google, Bing, etc.
**AEO** (Answer Engine Optimization) optimizes for featured snippets, voice search responses, People Also Ask boxes, and zero-click answer formats.
**GEO** (Generative Engine Optimization) optimizes for citations, mentions, and recommendations inside AI-generated answers from ChatGPT, Google AI Overviews/AI Mode, Perplexity, Claude, etc.

These are not separate disciplines. They form a continuum: SEO builds the foundation, AEO captures direct-answer opportunities on that foundation, and GEO extends visibility into AI-generated experiences. Each layer builds on the one before it.

**Output:** optimized articles and content briefs ship to the blog-content dir (default `biz/marketing/content/blog/`); audits, keyword research, and SEO/AEO/GEO strategy docs to the search dir (default `biz/marketing/seo/`; caller may redirect the `biz/<area>/` root). If no file-write capability is present, return results inline.

---

## When to Apply This Skill

- SEO audits, keyword research, content strategy, on-page/technical optimization, link building
- AEO audits, featured snippet optimization, voice search strategy, FAQ optimization, zero-click strategy
- GEO audits, AI visibility strategy, content extractability optimization
- Combined SEO+AEO+GEO content creation or site-wide optimization
- Competitive analysis across traditional search, answer features, and AI platforms
- Measurement strategy covering SEO, AEO, and GEO metrics

---

## Core Principles

### SEO Foundations (Detail: `references/seo-fundamentals.md`)

1. **Keyword Research and Search Intent**: Understand what users search for, why, and how to map content to intent types (informational, navigational, commercial, transactional)
2. **On-Page Optimization**: Title tags, meta descriptions, heading structure, internal linking, content quality, E-E-A-T signals
3. **Content Strategy**: Topic clusters, hub-and-spoke architecture, content gaps, editorial calendar
4. **Link Building**: Earning authoritative backlinks through outreach, digital PR, linkable assets, and relationship building
5. **User Experience**: Core Web Vitals, mobile-friendliness, site navigation, engagement signals

### Technical SEO Foundations (Detail: `references/technical-seo.md`)

1. **Crawling and Indexing**: robots.txt, sitemaps, crawl budget, log analysis
2. **Site Architecture**: URL structure, internal linking hierarchy, faceted navigation
3. **Rendering**: Server-side rendering vs. client-side JS, AI crawler compatibility
4. **Core Web Vitals**: LCP, INP, CLS optimization
5. **Canonicalization and Redirects**: Duplicate content management, redirect chains

### AEO Principles (Detail: `references/aeo-answer-optimization.md`)

1. **Direct Answer Formatting**: Structure content so search engines can extract precise, concise answers to user questions. Place the answer first, then supporting detail.
2. **Featured Snippet Optimization**: Target paragraph, list, table, and video snippet formats with content structured to match each type.
3. **Voice Search Readiness**: Optimize for conversational, question-based queries that voice assistants pull from. Content must be speakable and natural.
4. **Zero-Click Strategy**: Build brand visibility even when users never click through, by owning answer positions in SERPs.
5. **FAQ and Structured Answer Content**: Use question-based headings and concise answers (40-60 words) to capture People Also Ask and feed AI answer extraction. Note FAQ/HowTo schema no longer produces SERP rich results — keep such markup for AI/LLM extraction, not rich results (canonical deprecation timeline: `references/technical-seo.md` §6 — FAQ removed for all sites May 7 2026; HowTo 2023).

### GEO Principles (Detail: `references/geo-content-extractability.md`, `references/geo-entity-clarity.md`, `references/geo-multi-platform.md`)

1. **Content Extractability**: AI systems retrieve specific passages, not whole pages. Content must retain meaning when read in isolation. Images are invisible to this retrieval — every content `<img>` must carry descriptive `alt` text stating what the image shows.
2. **Entity Clarity**: AI systems must unambiguously identify what your brand is, what category it belongs to, and what it is authoritative for.
3. **Multi-Platform Presence**: AI systems pull from YouTube, Reddit, review sites, LinkedIn, industry publications, not just your website.
4. **Owned and Earned Signals**: Owned content demonstrates expertise; earned mentions (reviews, press, community) validate credibility.

### AI Platform Optimization (Detail: `references/ai-platform-optimization.md`)

Beyond GEO principles, specific tactics for maximizing visibility in AI-powered search and answer platforms. Covers platform-specific optimization for ChatGPT, Perplexity, Google AI Mode/AI Overviews, and Claude, plus practical audit methodology and monitoring for AI citations.

Key focus areas:
1. **Platform-Specific Signals**: Each AI platform weighs different content signals — optimize for the platforms your audience uses
2. **Citation Triggers**: Patterns that increase the probability of being cited in AI-generated answers (citing sources and adding statistics are the highest-leverage — see the GEO study in the reference)
3. **Monitoring & Measurement**: Tracking brand mentions and citations across AI platforms (Profound, Otterly, Peec AI, ZipTie)
4. **Content Structure for AI**: Beyond extractability — how to format content that AI systems prefer to reference
5. **Agentic Commerce**: For transactable brands, being *purchasable* by AI shopping agents (machine-readable product feeds + agentic-checkout protocols — OpenAI/Stripe ACP, Google UCP) is a workstream distinct from citation GEO
6. **Non-English / Korea**: Naver's AI Briefing draws most citations from Naver's own walled-garden UGC, so Korean GEO needs an in-ecosystem playbook; machine-translated mirrors do not inherit citations

### Content Type Mapping (Detail: `references/content-type-mapping.md`)

Not every page needs every optimization. A brand manifesto optimized like an FAQ loses its soul. A comprehensive guide without any optimization is invisible. The content type mapping provides page-by-page and purpose-by-purpose guidance on which optimization layers to apply and at what intensity (Full, Moderate, Light, None). Always identify the content's primary purpose first, then apply optimization that supports rather than overrides that purpose.

### Measurement (Detail: `references/measurement.md`)

Traditional SEO metrics (rankings, clicks, traffic) + AEO metrics (featured snippet ownership, voice search visibility, People Also Ask presence) + GEO metrics (AI citation frequency, share of voice, sentiment, context tracking) are all required for a complete picture.

---

## How SEO, AEO, and GEO Relate

| Aspect | SEO | AEO | GEO |
|--------|-----|-----|-----|
| Primary goal | Rank in top positions | Be the direct answer in search features | Be referenced in AI-generated answers |
| Success metrics | Rankings, clicks, traffic | Featured snippet ownership, PAA presence, voice search wins | AI citations, share of voice, sentiment |
| How users find you | Click through to site | See your answer without clicking (or click from snippet) | AI includes you in responses |
| Content optimization | Title tags, keywords, site speed | Concise answers, question headings, FAQ/HowTo schema | Self-contained paragraphs, clear facts, structured data |
| Credibility signals | Backlinks, domain authority | Structured data, answer accuracy, content freshness | Positive mentions across trusted platforms |
| Key platforms | Google, Bing organic results | Featured snippets, PAA, voice assistants | Google AI Mode, ChatGPT, Perplexity |
| Content format | Comprehensive, keyword-optimized | Concise Q&A, lists, tables (40-60 word answers) | In-depth, authoritative, self-contained passages |
| Volatility | Relatively stable | Moderate (snippets can flip) | High (citation sources shift substantially month to month) |

**These build on each other.** Strong SEO is the foundation AEO builds on. Strong SEO+AEO content is what GEO extends into AI visibility. You cannot skip layers.

---

## Integrated Workflows

### Workflow 1: Full SEO + AEO + GEO Site Audit

1. **Technical SEO Audit** → Consult `references/technical-seo.md`
   - Crawlability (including AI crawler access)
   - Indexation status
   - Core Web Vitals
   - Site architecture and internal linking
   - Rendering method (SSR vs CSR)

2. **On-Page and Content Audit** → Consult `references/seo-fundamentals.md`
   - Title tags, meta descriptions, heading structure
   - Content quality, E-E-A-T signals
   - Keyword coverage and search intent alignment
   - Internal linking structure

3. **AEO Answer Audit** → Consult `references/aeo-answer-optimization.md`
   - Identify high-value question queries with snippet opportunity
   - Assess answer formatting (concise, front-loaded, under 60 words)
   - Check FAQ/HowTo schema implementation
   - Evaluate heading structure against question-based patterns
   - Review voice search readiness (natural language, speakable content)
   - Assess People Also Ask coverage for target topics

4. **GEO Extractability Audit** → Consult `references/geo-content-extractability.md`
   - Identify key pages/passages that should appear in AI answers
   - Assess self-containedness of paragraphs
   - Check front-loading of information
   - Flag context-dependent passages that need rewriting

5. **Entity Clarity Audit** → Consult `references/geo-entity-clarity.md`
   - Schema markup alignment with visible content
   - Brand consistency across platforms
   - Entity ambiguity risks

6. **Multi-Platform Presence Audit** → Consult `references/geo-multi-platform.md`
   - Owned presence gaps (YouTube, LinkedIn, Reddit, etc.)
   - Earned mention landscape (reviews, press, community)
   - Sentiment assessment

7. **Measurement Setup** → Consult `references/measurement.md`
   - Traditional SEO tracking (GSC, GA4, rank tracking)
   - AEO tracking (featured snippet monitoring, PAA tracking, voice search)
   - GEO tracking (AI citation monitoring, share of voice)

### Workflow 2: Content Creation (SEO + AEO + GEO Optimized)

1. **Content Purpose and Optimization Scope** → Consult `references/content-type-mapping.md`
   - Identify the content's primary purpose (inform, persuade, entertain, convert, guide, etc.)
   - Determine appropriate optimization intensity for each layer (SEO, AEO, GEO)
   - Do not apply optimization that conflicts with the content's purpose

2. **Keyword and Query Research**
   - Traditional keyword research (search volume, difficulty, intent)
   - Question-based query identification (People Also Ask, AnswerThePublic, Google autocomplete)
   - AI query patterns ("best X for Y", "how does X compare to Y", "what is X")
   - Map content to traditional SERP, answer features, and AI answer opportunities

3. **Content Architecture**
   - Topic cluster placement (hub or spoke?)
   - Heading structure matching user queries, answer engine patterns, and AI retrieval
   - Internal linking plan

4. **Writing for Triple Optimization**
   - Strong on-page SEO (title, meta, headings, keyword placement)
   - AEO answer blocks: concise 40-60 word direct answers under question headings, followed by supporting detail
   - GEO self-contained paragraphs for AI extractability
   - Specific facts, data, and concrete examples with sources
   - Front-loaded answers under each heading
   - Descriptive `alt` text on every content image — never empty; AI systems read the text, not the pixels
   - E-E-A-T signals (author credentials, citations, experience)

5. **Structured Data**
   - Organization/Product/Article schema for entity and content-type signals (still supported rich results)
   - FAQPage / HowTo markup only as AI/LLM extraction aids — their Google SERP rich results are deprecated (canonical timeline in `references/technical-seo.md` §6)
   - Speakable schema only for qualifying news publishers (limited Google beta)

6. **Distribution Plan**
   - On-site publishing and internal linking
   - Multi-platform content (YouTube, LinkedIn, Reddit, etc.)
   - Outreach for earned mentions and backlinks

### Workflow 3: Competitive Analysis (SEO + AEO + GEO)

1. **Traditional SEO Competitive Analysis**
   - Keyword gap analysis
   - Backlink profile comparison
   - Content gap identification
   - SERP feature ownership

2. **AEO Competitive Analysis**
   - Which competitors own featured snippets for target queries?
   - Which competitors appear in People Also Ask for target topics?
   - What content formats are winning snippets (paragraph, list, table)?
   - Voice search answer attribution analysis

3. **GEO Competitive Analysis**
   - Which competitors appear in AI answers for target queries?
   - What content/platforms are they being cited from?
   - Share of voice comparison in AI responses
   - Entity clarity comparison

---

## Important Caveats

Always communicate to users:
- AEO and GEO increase probability of appearing in answer features and AI answers, but there are no guarantees
- Featured snippets can flip between sites; AI citation sources shift substantially month to month
- Different AI platforms weigh signals differently
- No "rank number one" equivalent in GEO; it is brand building across many visibility moments
- All three (SEO, AEO, GEO) are ongoing disciplines, not one-time projects
- E-E-A-T is not a direct ranking factor, but the qualities it describes (experience, expertise, authoritativeness, trustworthiness) influence SEO, AEO, and GEO outcomes
- Zero-click searches are growing; visibility without clicks still has brand value
- Voice search optimization requires content that sounds natural when read aloud
