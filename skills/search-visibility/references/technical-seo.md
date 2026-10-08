# Technical SEO

Read when the work touches any section below. Other files point here by number: crawler table §2, FAQ/HowTo rule §7. Platform facts were checked on 2026-10-08 against the primary docs named: cite them with that date. CDN defaults and program terms change fastest; re-check one a decision rides on, and when you can't, list it as a check before the decision, with an owner.

## Triage order

For each template that carries traffic or revenue, check one URL, then count the affected URLs. Stop at the first failing stage and fix it before anything below.

1. **Fetch.** Each target engine's search bot gets a 200 through robots.txt, the CDN/WAF and the origin; a valid, auto-renewed certificate; HTML under 2 MB. Evidence: the live URL Inspection tests in Search Console and Bing Webmaster Tools; logs filtered to each operator's published IP ranges (§1, §2). A curl with a borrowed user agent is a hint, never a finding: WAFs judge bots by IP and network.
2. **Index controls.** Money URLs are self-canonical, not noindexed or snippet-blocked, not Disallowed; links, sitemap and hreflang agree (§1, §2).
3. **Indexed.** Each template's sitemap is mostly indexed, and exclusions are intended (§3).
4. **Rendered.** Content, links, canonical and markup survive rendering; quotable text is in the raw HTML (§4).
5. **Discovered.** Money pages are linked from pages Google crawls often; no orphans (§5).
6. **Experience.** The smartphone page, which Google indexes, keeps desktop's main content, links, structured data, title and robots meta (tabs and accordions are fine); Core Web Vitals pass at p75 on money templates (§6).
7. **Enhancements.** Valid markup for live features, reciprocal hreflang, indexable media (§7, §8, §10).

Symptoms that point straight to a stage:
- A template's clicks collapse right after a release → noindex, canonical, Disallow or 5xx shipped with it → diff the release's `<head>` and robots.txt.
- Ranks in Google and Bing, never cited by ChatGPT → OAI-SearchBot blocked in robots.txt or at the CDN → its status codes in logs.
- Ranks for the head query, never an AI Overview supporting link → a snippet control, the Search generative AI exclusion, or no ranking for the sub-queries (§2).

## 1. Index controls and crawl

| Goal | Use | Not for |
|---|---|---|
| Never fetch a URL pattern (internal search, cart, sort orders, facets without demand) | robots.txt `Disallow` | Deindexing: a linked, blocked URL can be indexed without a snippet |
| Keep a crawlable page out of the index | `noindex` (meta or `X-Robots-Tag`) | Saving crawl: Google still fetches it |
| Consolidate duplicates | `rel=canonical`, matched by links, sitemap and hreflang | Forcing Google: it is a hint |
| Hide a URL now (leak, legal) | Search Console Removals plus a permanent control | Permanence: it lapses after about six months |

- **Never stack controls on one URL.** Google cannot see the noindex or canonical on a Disallowed URL, so it lingers as "Indexed, though blocked by robots.txt". To deindex it, lift the Disallow until Google has recrawled the noindex.
- **Never change URLs outside a migration** (§9).

**Crawl budget** matters only at 1M+ unique pages changing weekly, 10k+ changing daily, or many URLs in "Discovered – currently not indexed" (Google's crawl-budget guide). Elsewhere, slow indexing is a quality or linking problem (§3, §5). Levers: Disallow URLs never worth fetching, 404/410 removed pages, no redirect chains, fast responses without 5xx.

**Faceted navigation.** A facet with search demand ("red running shoes") gets an indexable static URL: its own title and H1, internal links, a stable parameter order, a 404 when empty. Disallow the rest, or keep those filters in URL fragments (`#`); Google calls canonical and nofollow "generally less effective in the long term" here. *Break:* a facet URL that already earns traffic stays open until its static replacement is live and redirected.

**Sitemaps.** One per template, so indexing can be read per template (§3); only canonical, indexable 200 URLs; `lastmod` changed only with real edits, since Google trusts it only when consistently accurate. For Bing, Naver and other IndexNow engines, ping IndexNow on publish, update and delete; Google does not use it.

## 2. Crawler access and AI controls

The role decides what a block costs. The table is not exhaustive: new agents appear every month, so extend it from your logs (the user agents and IPs fetching money templates) and each operator's bot page.

| Role | Agents (operator) | Honors robots.txt | Blocking costs |
|---|---|---|---|
| Search | Googlebot, incl. AI Overviews and AI Mode | Yes | Google Search and its AI features |
| Search | Bingbot: Bing and Copilot | Yes | Bing and Copilot citations |
| Search | OAI-SearchBot: ChatGPT search | Yes; ~24 h to apply | ChatGPT search answers; navigational links may remain |
| Search | PerplexityBot; Claude-SearchBot (Anthropic); Meta-WebIndexer (Meta AI); Applebot (Siri, Spotlight, Safari); DuckAssistBot (DuckDuckGo's AI answers); Amzn-SearchBot (Alexa; unnamed, it follows your other search bots' rules); Yeti (Naver) | Yes | That engine's results and citations |
| User fetch | ChatGPT-User ("may not apply"); Perplexity-User ("generally ignores"); Google-Agent and Google's other user-triggered fetchers ("generally ignore"); Meta-ExternalFetcher (may bypass); Amzn-User ("may not follow all"); Claude-User (honors) | Mostly no | Live fetches while answering; control at the CDN/WAF |
| Training | GPTBot (OpenAI), ClaudeBot (Anthropic), CCBot (Common Crawl, an open corpus many model builders train on), Bytespider (ByteDance); Amazonbot (improves Amazon's products; may train its models); Meta-ExternalAgent (training, and "improving products by indexing content directly") | Yes, per their docs; Bytespider is repeatedly reported ignoring it | Training; for Amazonbot and Meta-ExternalAgent, possibly product features too |
| Token, not a crawler | Google-Extended (Gemini training and grounding in Gemini Apps and Vertex AI; not Search, AI Overviews or AI Mode); Applebot-Extended (Apple's foundation-model training) | Set in robots.txt | Training, and Gemini grounding |

Sources: developers.google.com/crawling, developers.openai.com/api/docs/bots, docs.perplexity.ai/guides/bots, support.claude.com/en/articles/8896518, support.apple.com/en-us/119829, developers.facebook.com/docs/sharing/webmasters/web-crawlers, developer.amazon.com/amazonbot, duckduckgo.com/duckduckgo-help-pages/results/duckassistbot, commoncrawl.org/faq, searchadvisor.naver.com.

**Tokens never fetch.** Google-Extended and Applebot-Extended have no user agent of their own: they govern how Google and Apple use what Googlebot and Applebot already fetched. A CDN rule for them does nothing and they never show in logs; only their robots.txt group counts.

- **Allow the search and user-fetch agents of every engine you target.** *Break:* a publisher that licenses its content may block search bots on purpose; record that as a business decision, not a finding.
- **Training follows the content's job** (the default to recommend when no one has decided; the content owner decides, with legal). Pages meant to make you known (marketing, product, pricing, docs) allow training: engines answering from memory then know your facts, and blocking GPTBot doesn't change ChatGPT search. Content you sell, license or meter refuses every training agent and token, and gets the exclusion review below. Blocking Google-Extended also ends grounding in Gemini apps.
- **Name every group you mean.** An unnamed agent follows the `User-agent: *` group. A blocklist lets each new agent in until you add it; an allowlist (`*` disallowed, wanted agents named) keeps new compliant agents out, new search engines and tools included. Choose per content class and say why.
- **robots.txt is a request, not access control.** It binds only compliant agents, and only from now on. User fetchers may ignore it and user agents can be spoofed: enforce at the CDN/WAF, verifying bots by reverse DNS or the operator's published IP ranges. Cloudflare reported a declared AI bot switching to undeclared, browser-like crawlers when blocked (Perplexity, August 2025).
- **CDN rules sort bots by class, and defaults change;** read yours before and after any change. A training block can catch mixed-use crawlers that search and feed AI from one crawl: on Cloudflare (September 2026), "Block" for training also blocks Googlebot, Bingbot and Applebot, search included ("Block on pages with ads" does so on ad-serving pages), while "Disallow AI Training" refuses training and keeps search (blog.cloudflare.com/accountable-mixed-use-ai-crawlers). A CDN-managed robots.txt can add a `Content-Signal` line (`search`, `ai-input`, `ai-train`): read every value; `ai-input=no` asks engines not to use your pages in AI answers.

**Exclusion.** To keep content from training, AI answers or reuse, a robots.txt edit covers one path. Cover each, and state what's left:

| Path out | Control | What it can't stop |
|---|---|---|
| Named agents | A group per agent and role; a reservation line (Content-Signal or similar) | Agents you didn't name |
| Unnamed or new agents | An allowlist, or a monthly log review that adds them | Use before you notice them |
| Non-compliant or spoofed fetchers | CDN/WAF rules, verified-bot lists, rate limits | Scrapers posing as browsers on residential IPs |
| User-triggered fetches | CDN/WAF rules per agent | Blocking them also fails users who ask an assistant about your page |
| Data already collected | Removal requests (Common Crawl filters such URLs from later crawls and its public indices but can't edit published archives, per its November 2025 statement) | Published archives; models already trained on it |
| Copies elsewhere | Syndication and API terms that pass your restrictions on; takedowns | Copies you never find |
| Feeds and bulk exports | Excerpt-only RSS; no `llms-full.txt`; authenticated APIs and downloads | Exports partners already hold |
| Client-side paywalls | Gate on the server; full text only to verified, licensed bots, with paywalled-content markup so Google doesn't read it as cloaking | — |
| Google's AI features | The Search Console setting or snippet controls (below) | Answers built from other sources about you |

**Legal weight.** In the EU, Article 4(3) of the DSM Directive (2019/790) lets rightsholders reserve text-and-data mining by machine-readable means (robots.txt, a Content-Signal line, TDMRep), and the AI Act obliges general-purpose model providers to identify and honor such reservations (Article 53(1)(c), applying since 2 August 2025; the GPAI Code of Practice commits signatories to follow robots.txt). Elsewhere its force is unsettled: put the reservation in your terms of use too, and weigh licensing or pay-per-crawl (charging AI crawlers per request at the CDN) against blocking. The IETF's AI-preferences vocabulary is still a draft; check its status before relying on it.

**Google's AI controls.** No robots.txt token takes a site out of AI Overviews but keeps it in Search. A supporting link must be "indexed and eligible to be shown in Google Search with a snippet", nothing more (Google's AI features doc).
- Leave AI Overviews, AI Mode and Discover's AI features but stay in Search: Search Console › Settings › Search generative AI (all sites since 2026-08-31; default include; child properties inherit unless their owner overrides; a few days to apply; no effect on other ranking or on training).
- Keep a page out of AI features: `nosnippet`, `max-snippet:0` or `noindex`, at the cost of the classic snippet or the page. Keep passages out of quotes: `data-nosnippet`.
- Opt out of Gemini training and grounding: Disallow Google-Extended; Search is unaffected.

**Opting out rarely pays.** It removes your supporting links; the Overview still shows, built from other sources. Consider it only for per-visit revenue (ads, metering) when the AI-Overview split of your CTR curve (`measurement.md` §3) shows clicks lost. Test first: exclude one section's URL-prefix property for 4–6 weeks against a matched section, and judge on clicks and revenue, not impressions. *Break:* licensing or legal terms require it.

**Audit step:** read the Search generative AI setting on the top-level property and any child that overrides it; the CDN's rules per bot class and its Content-Signal values; the robots.txt group of every agent role you target or refuse (Google-Extended when Gemini matters). Confirm in logs that wanted bots get 200s on money templates and refused ones get the response you chose.

**The access-policy deliverable** (≤800 + the artifacts, applied in place when their files are in the workspace and the change is decided, else drafted inline; the policy itself inline unless a policy file exists): the goal per content class (pages meant to make you known, content sold or licensed, private); a verdict per agent role (search, user fetch, training, tokens, unnamed), with its default and trade-off; the artifacts, ready to apply (robots.txt groups, CDN or WAF rules, meta or header controls, console settings, a reservation line for your terms); for exclusion, each path out with its control and the residual risk; acceptance checks per agent (the robots.txt verdict for its token from a tester or parser, then verified-IP log lines showing the chosen response within the operator's stated delay); what the controls can't do.

## 3. Indexing diagnostics

Read Page Indexing per template, filtered by that template's sitemap. Google never indexes every URL: the "Not indexed" total is not a KPI; the indexed share of each money template is.

| Status | Usual cause | Fix |
|---|---|---|
| Crawled – currently not indexed | Quality or duplication: read and declined | Improve or merge; resubmitting does nothing |
| Discovered – currently not indexed | Low priority: few links from crawled pages, or too many URLs | Link from pages Google crawls; cut the URL count (§1) |
| Duplicate, Google chose different canonical than user | Links, sitemap, redirects or hreflang point elsewhere | Align every signal on one URL, or accept Google's pick |
| Indexed, though blocked by robots.txt | Disallow on a linked URL | Lift the Disallow until the noindex is seen |
| Soft 404 | Thin pages, or SPA "not found" views served with 200 | Return a real 404, or add substance |

## 4. Rendering and fetch limits

**Google** queues every 200 page for rendering and may skip non-200 pages. Its JavaScript risks are specific (Google's JavaScript SEO basics): a noindex in the raw HTML may stop rendering, so JavaScript cannot remove it; a JavaScript-set canonical must equal the raw one; only `<a href>` elements are links; a client-side "not found" view served with 200 is a soft 404 (redirect to a URL that returns 404, or add noindex); content that loads only after a click, swipe or typing is never seen.

**Fetch cap.** Googlebot indexes only the first 2 MB of an HTML file, uncompressed (PDF: 64 MB). Put the `<head>` tags early and move large inline state, CSS and base64 images out.

**Other AI crawlers.** In Vercel/MERJ's December 2024 log study, crawlers from OpenAI, Anthropic, Meta, ByteDance and Perplexity fetched JavaScript without running it; Googlebot and Applebot rendered. Text you want quoted by ChatGPT, Claude or Perplexity must be in the server-delivered HTML: SSR, SSG or prerendering for content, pricing and docs. Google calls dynamic rendering "a workaround and not a long-term solution".

**Test:** diff the raw HTML (curl) against URL Inspection's rendered HTML. A key sentence missing from the raw HTML is invisible to non-Google AI crawlers.

## 5. Architecture and internal links

- **Depth follows value.** Measure click depth and inlinks per template with a crawler. Money pages and revenue clusters sit close to the navigation, hubs and category pages Google crawls most; archives may sit deep. Google publishes no click-depth threshold.
- **Orphans** (in sitemaps, analytics or logs, with no internal inlinks) get a link from a relevant crawled page, or are dropped.
- **Pagination.** Link each page to the next with `<a href>`, give each its own canonical (never page 1), never put page numbers in `#` fragments; Google ignores `rel=next/prev`. Behind "load more" or infinite scroll, also expose paginated URLs, or list the items in a sitemap or Merchant Center feed.

## 6. Core Web Vitals

Field data at the 75th percentile (CrUX, Search Console) counts; lab tools diagnose.

- **CWV break ties.** Ranking uses them, but relevance comes first. Act when CrUX shows a money template failing at p75; a passing template gains nothing from a better score. *Break:* when the case for speed is conversion, judge it by conversion.

## 7. Structured data

Google's AI features need no markup: "there's no special schema.org markup you need to add" (Google's AI optimization guide). Markup pays only through a live Google or Bing feature or entity facts (Organization `sameAs`, Product/Offer).

- **Mark up only gallery types that match the page's main entity,** and check Google's Search Gallery the day you implement: features get retired. Markup matches visible content (and, for products, the merchant feed); validate with the Rich Results Test.
- **FAQPage and HowTo get no Google display.** FAQ rich results ended for all sites on May 7 2026, HowTo in 2023, and neither is in Google's gallery. Keep valid existing markup; never add it for rich results or AI citations. Engines read the visible Q&A text. (Canonical rule: other files point here.)
- **Reviews.** A business's own pages marked up as LocalBusiness or another Organization type get no review stars (self-serving); fake or undisclosed incentivized reviews are prohibited.
- **LocalBusiness** feeds the knowledge panel and business carousels; the local pack comes from Google Business Profile. **Breadcrumbs** display on desktop only.
- **Regions.** Many features are region-limited; when checked, Event and Job posting were not offered in Korea. Read the feature's availability list before scoping work.

## 8. International

**Ownership.** This skill decides whether locales get separate URLs, the URL structure, which locales to build, and the hreflang rules. An i18n capability (the `i18n` skill, if available) implements routing, locale resolution, tag generation and caching, and alone decides for authenticated, non-indexed app surfaces.

- **Which locales:** those with measured demand (keyword research per market, in its language, never translated keywords) and the capacity to keep content current. Machine-translated mirrors rarely earn rankings or AI citations (ai-platform-optimization.md, Korea).
- **Structure.** Default to subfolders (`example.com/ko/`): one host, least maintenance, links accruing to one domain. *Break:* a separate legal entity or operation, or a market where a local domain earns trust; then a ccTLD. Never URL parameters.
- **No automatic redirects by IP or browser language:** Googlebot crawls mostly from the US and would see one version; offer a locale switcher.
- **hreflang.** Every page lists itself and each alternate. Tags between two pages that don't both point to each other are ignored: the non-reciprocal pair fails, not the whole set. Codes are language first, then an optional region: `ko`, not the country code `kr`; `en-gb`, not `en-uk`. `x-default` is recommended for the fallback or selector page. One method is enough (`<head>` tags, HTTP headers or the sitemap); if you use more, keep them identical. Every alternate returns 200 and is canonical to itself.

## 9. Migrations

Any change of domain, URL pattern, platform or templates at scale.

- **Change one thing at a time:** sequence a move, a replatform and a redesign rather than combining them; on a large site, move one section first and watch it (Google's site-move guide).
- **Map before launch.** Every old URL with traffic, links or rankings gets its closest new equivalent: 301 or 308, one hop, ending in a 200. No equivalent: 404/410, never a homepage redirect.
- **Save the baseline before launch** (a full crawl, Search Console page and query exports, a log sample): the post-launch diffs need it. Crawl the old URL list against staging to test the redirect map.
- **Staging stays behind a login;** robots.txt and noindex leak, and a staging noindex tends to ship.
- **Agree the rollback trigger before launch:** metric (redirect errors on money URLs, indexed money URLs, organic clicks to money templates), threshold and window.
- **After launch,** crawl the old URL list again (each must 301 to a 200 in one hop); diff titles, canonicals, robots, hreflang and body copy per template against the baseline; watch Page Indexing and logs daily for the first weeks.
- **Keep redirects at least a year.** On a domain move, file Change of Address for every verified variant of the old domain. Expect "a few weeks or more" before Google shows the new URLs on a medium site, longer on a large one; rankings fluctuate meanwhile.

**The change-plan deliverable** (≤1,000 + URL map; `change-plan-{topic}.md` in the search dir, updated until launch): sequence, one change at a time; URL-map rules and coverage; pre-launch baseline; launch checks; rollback trigger (metric, threshold, window).

## 10. Images and video

Images: `answer-writing.md`. Each video gets an indexable watch page with a visible transcript and chapters, plus `VideoObject` markup (`Clip` or `SeekToAction` for key moments). The transcript is the text AI engines read.
