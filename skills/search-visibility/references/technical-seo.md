# Technical SEO Reference

Detailed reference for technical SEO covering crawling, indexing, site architecture, Core Web Vitals, rendering, and AI crawler considerations.

## Table of Contents

1. [Crawling and Indexing](#1-crawling-and-indexing)
2. [Site Architecture](#2-site-architecture)
3. [Rendering](#3-rendering)
4. [Core Web Vitals](#4-core-web-vitals)
5. [HTTPS and Security](#5-https-and-security)
6. [Structured Data (Schema Markup)](#6-structured-data-schema-markup)
7. [International SEO (hreflang)](#7-international-seo-hreflang)
8. [Image and Video SEO](#8-image-and-video-seo)
9. [Site Migration Checklist](#9-site-migration-checklist)
10. [Common Technical SEO Issues Checklist](#10-common-technical-seo-issues-checklist)

---

## 1. Crawling and Indexing

### How Search Engines Discover Content

Search engines use crawlers (bots) to discover pages by following links and reading sitemaps. A page must be crawled before it can be indexed, and indexed before it can appear in search results.

The process: **Discovery → Crawl → Render → Index → Rank**

### robots.txt

Controls which URLs crawlers can access on your site. Located at `yoursite.com/robots.txt`.

Key rules:
- `User-agent: *` applies to all crawlers
- `Disallow: /path/` blocks crawling of that directory
- `Allow: /path/page` overrides a broader Disallow
- `Sitemap: https://yoursite.com/sitemap.xml` points crawlers to your sitemap

Common mistakes:
- Accidentally blocking CSS/JS files that crawlers need to render pages
- Blocking entire sections of the site without realizing it
- Using robots.txt to try to remove pages from the index (it does not work, use noindex instead)
- Forgetting to update robots.txt after site migrations

### AI Crawler Considerations

AI platforms use their own crawlers. If these are blocked, your content will not appear in AI-generated answers.

This is the canonical AI user-agent table for the skill (measurement.md and ai-platform-optimization.md reference it). The function column matters more than the name: the bots that get you **cited** in AI answers are the search/retrieval agents, not the training crawlers.

| User-agent | Platform | Function |
|---|---|---|
| Googlebot | Google | Search index — also powers AI Overviews and AI Mode |
| OAI-SearchBot | OpenAI | ChatGPT Search citation/inclusion (this controls ChatGPT Search visibility) |
| ChatGPT-User | OpenAI | User-initiated live fetches from ChatGPT |
| GPTBot | OpenAI | Model training |
| PerplexityBot | Perplexity | Search index / citation |
| Perplexity-User | Perplexity | User-initiated live fetches |
| Claude-SearchBot | Anthropic | Search indexing for Claude |
| Claude-User | Anthropic | User-initiated live fetches |
| ClaudeBot | Anthropic | Model training |
| Google-Extended | Google | Opt-out *token* for Gemini training and for grounding in Gemini Apps / Vertex AI (not a fetcher; does NOT affect Search, AI Overviews, or AI Mode) |
| Applebot-Extended | Apple | Opt-out *token* for Apple Intelligence training |
| Bytespider | ByteDance | Training |
| CCBot | Common Crawl | Bulk crawl, commonly used as training data |

Important:
- For AI-search **citation** (usually the goal), the agents that matter are the search/retrieval bots — OAI-SearchBot, PerplexityBot, Claude-SearchBot, and Googlebot — not the training crawlers (GPTBot, ClaudeBot, CCBot, Bytespider). You can allow OAI-SearchBot for ChatGPT Search visibility while disallowing GPTBot for training.
- Blocking Google-Extended blocks Gemini training data and grounding in Gemini Apps / Vertex AI but does NOT block AI Overviews or AI Mode (those use Googlebot). Google-Extended and Applebot-Extended are opt-out tokens, not crawlers.
- Check your CDN/bot settings as well as robots.txt: some CDNs (e.g., Cloudflare) block AI crawlers by default, so you may be blocking the search bots you want to be cited by (see `ai-platform-optimization.md`). Note also that robots.txt directives do not reliably control every vendor — PerplexityBot has been documented using undeclared stealth crawlers.

**Cloudflare Content Signals Policy (Sept 24 2025)** — distinct from Content Independence Day. A new `Content-Signal:` robots.txt directive lets operators set yes/no per category — **search**, **ai-input** (real-time generative answers), **ai-train** — auto-applied to 3.8M+ managed domains with a recommended default of search=yes, ai-train=no, and **ai-input deliberately left unspecified**. The policy text is CC0 and references EU Directive 2019/790 Article 4 (potential EU legal weight). **Decision:** if you want AI-answer citations, verify `ai-input` is not set to `no` on your managed robots.txt — a managed default can silently opt you out of generative answer engines. Pair with **Pay Per Crawl** (HTTP 402, customers issuing 1B+/day): an engine that won't pay a charged crawler simply won't fetch and therefore can't cite, so decide which *citation* bots to grant free access to, separately from *training* bots you may monetize or block.

### XML Sitemaps

A file that lists all URLs you want search engines to index.

Best practices:
- Include only canonical, indexable URLs (200 status, no noindex)
- Keep under 50,000 URLs per sitemap file, under 50MB uncompressed
- Use sitemap index files for large sites
- Include `<lastmod>` dates and keep them accurate (only update when content meaningfully changes)
- Submit via Google Search Console and reference in robots.txt
- Exclude URLs blocked by robots.txt or set to noindex

### Indexation Management

**noindex**: Prevents a page from appearing in search results while still allowing crawling.
- Use `<meta name="robots" content="noindex">` in the HTML head
- Or use the `X-Robots-Tag: noindex` HTTP header
- Use for: thank you pages, internal search results, thin tag/category pages, staging environments

**Canonical tags**: Tell search engines which version of a page is the main one when duplicate or near-duplicate versions exist.
- Use `<link rel="canonical" href="https://yoursite.com/preferred-url">` in the HTML head
- Self-referencing canonicals (a page pointing to itself) are a best practice
- Do not canonical to a completely different page, that is a redirect use case

### Crawl Budget

For large sites (100K+ pages), crawl budget becomes important. Google allocates a finite number of crawls per site per day.

Optimize crawl budget by:
- Ensuring important pages are easily reachable (shallow click depth)
- Removing or noindexing low-value pages (thin content, parameter variations, outdated content)
- Fixing soft 404s and redirect chains
- Keeping server response times fast
- Using internal linking to prioritize important pages
- Monitoring crawl stats in Google Search Console

---

## 2. Site Architecture

### URL Structure Principles

- **Flat but logical**: Important pages should be 2-3 clicks from homepage
- **Consistent hierarchy**: `example.com/category/subcategory/page`
- **Human-readable**: Users should understand the page topic from the URL
- **Hyphens between words**: `example.com/blue-widgets` not `example.com/blue_widgets`
- **Lowercase only**: Avoid mixed case to prevent duplicate URL issues
- **No unnecessary parameters**: Keep URLs clean

### Internal Linking Architecture

Internal links serve three purposes:
1. **Navigation**: Help users find content
2. **Hierarchy**: Signal to search engines which pages are most important
3. **Authority distribution**: Pass link equity from strong pages to pages that need it

Architecture patterns:
- **Pyramid**: Homepage → Category pages → Detail pages (most common)
- **Hub and spoke**: Pillar content → Cluster content (for content-driven sites)
- **Flat**: All pages roughly equal depth (for smaller sites)

Key principles:
- Every important page should be reachable within 3 clicks from homepage
- Use descriptive anchor text (not "click here")
- Link related content to each other (contextual internal links within body content are most valuable)
- Navigation menus, breadcrumbs, and footer links all count
- Identify and fix orphan pages (no internal links pointing to them)

### Faceted Navigation (E-commerce)

Faceted navigation (filters for size, color, price, etc.) can create massive URL bloat.

Handle with:
- `noindex` on low-value filter combinations
- Canonical tags pointing filter pages to the main category
- robots.txt blocking of parameter-heavy URLs
- AJAX-based filtering that does not create new URLs
- Strategic indexing of only the most valuable filter combinations (those with search volume)

### Pagination

For paginated content (category pages, blog archives):
- `rel="next"`/`rel="prev"` is no longer used by Google for indexing (dropped ~2019); it may still be a minor signal for other engines. Prioritize crawlable, internally-linked paginated pages with self-referencing canonicals instead
- Ensure all paginated pages are crawlable and linked
- Consider a "view all" page if the total content is manageable
- Include self-referencing canonical on each paginated page

---

## 3. Rendering

### Server-Side Rendering (SSR) vs Client-Side Rendering (CSR)

| Aspect | SSR | CSR |
|--------|-----|-----|
| How it works | Server generates complete HTML | Browser downloads JS, then renders |
| SEO friendliness | Excellent, crawlers get complete content immediately | Risky, crawlers may not execute JS |
| AI crawler compatibility | High, all crawlers can read HTML | Low, many AI crawlers do not execute JS |
| Initial load speed | Faster first contentful paint | Slower initial load, faster subsequent navigation |

**Recommendation**: Use SSR or pre-rendering for any content you want discoverable by search engines and AI systems. If your site is built with React, Vue, Angular, or similar frameworks, ensure critical content is server-rendered.

### AI Crawlers Execute Zero JavaScript (a binary extractability prerequisite)

The dedicated AI crawlers **fetch JavaScript files but never execute them**: the Vercel/MERJ study (Dec 17 2024, 500M+ GPTBot fetches) found GPTBot, OAI-SearchBot, ChatGPT-User, ClaudeBot, and PerplexityBot do no JS rendering; independent hands-on tests (Glenn Gabe, gsqi.com) confirmed ChatGPT/Claude/Perplexity could not read JS-dependent pages. Only Google (Gemini via Googlebot/Chromium) renders JS; Bingbot renders partially and inconsistently (so ChatGPT Search — which historically leaned on Bing's index but now increasingly runs on OpenAI's own crawl/index — is at most a partial exception). **Consequence:** any content that appears only after client-side JS (React/Vue/Angular SPAs — pricing tables, FAQ answers, comparison data) is **invisible** to the largest AI engines unless it is in server-delivered HTML. **Decision:** for JS-framework sites, move every citation-worthy passage into SSR/SSG/prerendered HTML — this is the difference between being citable and being absent from ChatGPT, Claude, and Perplexity, not a nice-to-have.

### Pre-rendering / Static Site Generation (SSG)

Generate HTML at build time rather than per request. Best of both worlds for content that does not change frequently. Frameworks: Next.js (React), Nuxt (Vue), Astro, Hugo, Gatsby.

### Dynamic Rendering

Serve pre-rendered HTML to crawlers while serving the SPA to users. Google **no longer recommends** dynamic rendering — it relies on unreliable user-agent detection, risks serving different content to bots than to users, and Google has removed most of its guidance for it. Prefer SSR, SSG, or hydration; treat dynamic rendering only as a last-resort legacy stopgap. (Note: many AI crawlers execute no JS at all, so dynamic rendering that only targets Googlebot still leaves you invisible to them.)

### Testing Rendering

- Use Google Search Console URL Inspection tool to see how Google renders your pages
- Check "View Source" vs. rendered DOM in browser DevTools
- Test with JavaScript disabled to see what crawlers with limited JS support see

---

## 4. Core Web Vitals

Google page experience metrics. They are ranking signals (though relatively modest compared to content relevance and links).

### LCP (Largest Contentful Paint)
- **What**: Time until the largest visible element (image, video, text block) is rendered
- **Target**: 2.5 seconds or less
- **Common issues**: Large unoptimized images, slow server response, render-blocking resources, client-side rendering delays
- **Fixes**: Optimize and properly size images (WebP/AVIF), use CDN, preload critical resources, implement lazy loading for below-fold images, reduce server response time (TTFB)

### INP (Interaction to Next Paint)
- **What**: Responsiveness to user interactions (clicks, taps, key presses). Replaced FID in March 2024.
- **Target**: 200 milliseconds or less
- **Common issues**: Long JavaScript tasks blocking the main thread, heavy event handlers, excessive DOM size
- **Fixes**: Break up long tasks, defer non-critical JS, reduce DOM size, use web workers for heavy computation, optimize event handlers

### CLS (Cumulative Layout Shift)
- **What**: Visual stability, how much content shifts unexpectedly during loading
- **Target**: 0.1 or less
- **Common issues**: Images/embeds without dimensions, dynamically injected content, web fonts causing FOIT/FOUT, ads resizing
- **Fixes**: Always set width/height on images and videos, reserve space for ads and embeds, use `font-display: swap` with preloaded fonts, avoid injecting content above existing content

### Measuring Core Web Vitals

- **Field data (real users)**: Google Search Console, PageSpeed Insights (CrUX data), web-vitals JavaScript library
- **Lab data (synthetic)**: Lighthouse, WebPageTest, Chrome DevTools Performance panel
- Field data is what Google uses for ranking. Lab data helps diagnose issues.

---

## 5. HTTPS and Security

- HTTPS is a confirmed (minor) ranking signal
- All pages should be served over HTTPS
- Ensure HTTP to HTTPS redirects are in place
- Avoid mixed content (HTTPS page loading HTTP resources)
- Keep SSL certificates valid and up to date

---

## 6. Structured Data (Schema Markup)

### What It Does

Structured data (typically JSON-LD) helps search engines understand the content type and relationships on your pages. It can enable rich results (star ratings, breadcrumbs, product info, etc.) in SERPs for *currently supported* types — note that Google has retired several rich-result types (FAQ, HowTo), so always confirm a type is still supported before implementing for SERP appearance.

### Implementation Principles

- Use JSON-LD format (Google recommended format)
- Schema must accurately reflect visible page content. Do not add schema for content that is not on the page
- Validate with Google Rich Results Test and Schema Markup Validator
- Do not add schema for rich results you are not eligible for

### Common Schema Types

| Schema Type | Use For | Rich Result |
|-------------|---------|-------------|
| Article | Blog posts, news articles | Article appearance |
| Product | Product pages | Price, availability, reviews |
| FAQPage | FAQ sections | ⚠️ No Google rich result. Restricted to gov/health sites Aug 2023, then fully removed for all sites May 7 2026. Still valid schema; aids AI/LLM answer extraction |
| HowTo | Tutorial/guide content | ⚠️ No Google rich result (deprecated/removed 2023). Optional semantic markup for AI extraction only |
| Organization | Homepage/about page | Knowledge panel, brand info |
| LocalBusiness | Physical business locations | Local pack, business details |
| BreadcrumbList | Site navigation | Breadcrumb trail in SERPs |
| Review | Review content | Star ratings |
| VideoObject | Video content | Video thumbnails in SERPs |
| Speakable | Voice search priority content | Limited beta: US-English news publishers only, read aloud via Google Assistant |

### Schema and AEO/GEO Connection

This subsection is the **canonical FAQ/HowTo deprecation timeline for the skill** — other references point here rather than restating dates, so update them in one place.

For AEO purposes, note that FAQPage and HowTo schema **no longer produce Google SERP rich results**. HowTo rich results were removed in 2023; FAQ rich results were restricted to government/health sites in Aug 2023 and fully deprecated for all sites on May 7, 2026 (the FAQ report and Rich Results Test support drop in June 2026, the Search Console API in Aug 2026). The structured Q&A and step markup can still help AI answer engines and LLMs parse, extract, and cite content — so treat it as AEO/GEO *extraction* value, not a Google SERP feature. Speakable schema is a limited beta (US-English news publishers, Google Assistant), not a general voice-search signal.

For GEO purposes, structured data provides machine-readable entity signals that AI systems can cross-reference when determining brand identity and category.

Ensure your schema markup, visible page content, and any external data feeds (e.g., Google Merchant Center) describe the same information consistently.

---

## 7. International SEO (hreflang)

For sites serving multiple languages or regions, hreflang tells Google which language/region version to show.

- **Reciprocity is mandatory**: every hreflang annotation must be returned by all the pages it references. If page A points to B, B must point back to A (and to itself). Missing return tags are the most common hreflang error and cause Google to ignore the cluster.
- **Always include a self-referencing tag** plus an **`x-default`** entry for the fallback/locale-selector page.
- **Use correct codes**: ISO 639-1 language (`en`), optional ISO 3166-1 Alpha-2 region (`en-gb`). Region without language is invalid.
- **Pick one placement** and be consistent: HTML `<head>` link tags, an XML sitemap `xhtml:link` annotation (best for large sites), or HTTP headers (for non-HTML files like PDFs). Do not mix methods for the same URLs.
- hreflang is a targeting signal, **not** a duplicate-content fix — pair it with self-referencing canonicals (canonical to self, not to another language).
- This section owns the search-signal layer; the application-side implementation (locale routing, URL strategy, translation structure, generating the tags) belongs to an i18n capability (the `i18n` skill, if available). Localized content must be net-new per locale to earn AI citations — see `ai-platform-optimization.md` § Non-English Surfaces.

## 8. Image and Video SEO

AI Overviews, Google Images, and YouTube are all cited surfaces, so media is part of visibility, not an afterthought.

**Images**: descriptive filenames and `alt` text (real description, not keyword stuffing), responsive `srcset`, modern formats (WebP/AVIF), explicit width/height (CLS), lazy-load below-fold, and an image sitemap for large libraries. `ImageObject` schema and on-page captions help AI systems associate the image with its subject.

**Video**: host with a transcript and chapters; add `VideoObject` schema (`name`, `description`, `thumbnailUrl`, `uploadDate`, `duration`, and `clip`/`SeekToAction` for key moments). Transcripts are what AI systems actually read — a video without a transcript is largely invisible to text-based retrieval. YouTube descriptions and chapters are independently crawled (see `geo-multi-platform.md`).

---

## 9. Site Migration Checklist

When moving to a new domain, redesigning, or restructuring:

1. **Pre-migration**: Crawl and document all existing URLs, rankings, and backlinks
2. **Redirect mapping**: Create 1:1 redirect map from old URLs to new URLs (301 redirects)
3. **Preserve structure**: Maintain URL patterns where possible
4. **Update internal links**: Point to new URLs directly, do not rely solely on redirects
5. **Update sitemaps**: Submit new sitemap, remove old one
6. **Update Search Console**: Verify new property, use Change of Address tool if domain change
7. **Monitor**: Watch for crawl errors, indexation drops, and ranking changes for 3-6 months
8. **Preserve backlinks**: Redirects pass link equity, but reach out to high-value linking sites to update URLs

---

## 10. Common Technical SEO Issues Checklist

- [ ] No accidental noindex on important pages
- [ ] robots.txt not blocking critical resources or AI crawlers
- [ ] XML sitemap submitted and up to date
- [ ] All important pages return 200 status
- [ ] No redirect chains (A to B to C; should be A to C)
- [ ] No redirect loops
- [ ] Canonical tags present and correct
- [ ] No mixed HTTP/HTTPS content
- [ ] Mobile-friendly / responsive design
- [ ] Core Web Vitals passing (LCP 2.5s or less, INP 200ms or less, CLS 0.1 or less)
- [ ] Hreflang implemented correctly (for multi-language sites)
- [ ] Structured data valid and accurate
- [ ] No soft 404s (pages returning 200 but showing error/empty content)
- [ ] Server response time under 200ms (TTFB)
- [ ] Content accessible without JavaScript execution (for AI crawlers)
