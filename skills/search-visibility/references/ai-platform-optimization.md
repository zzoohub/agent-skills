# AI Platform Optimization

Read this for AI-visibility work: choosing which engines to track, diagnosing why one leaves you out, and questions about llms.txt, AI shopping or Korea. Elsewhere: per-crawler robots.txt behavior and Google's AI controls (`technical-seo.md`), the prompt panel (`measurement.md` §5), off-site and accuracy plays (`consensus-and-accuracy.md`), section writing (`answer-writing.md`).

## Engine sheet (verified 2026-10-08)

Cite cells with that date. Engines change monthly: re-check a cell a decision rides on in the vendor doc; when you can't, a brief or article marks it `[VERIFY: claim]` and any other deliverable lists it as a check before the decision.

| Engine | Answers draw on | Inclusion controls (robots.txt behavior: `technical-seo.md` §2) | First-party data |
|---|---|---|---|
| Google AI Overviews and AI Mode | Google's index and ranking systems, with query fan-out; two features that "may use different models and techniques" | Googlebot; only indexed, snippet-eligible pages; snippet controls and a site-wide opt-out in Search Console. Google-Extended has no effect | Search Console's Generative AI report (impressions only, both features combined) |
| Gemini app | Google Search grounding | Google-Extended (training and Gemini grounding) | None; referrals only |
| ChatGPT | OpenAI's search: the OAI-SearchBot crawl, third-party search providers, partner content | OAI-SearchBot; ChatGPT-User | None; cited links carry `utm_source=chatgpt.com` |
| Copilot and Bing AI | Bing index | Bingbot; `noarchive` keeps a page out of Copilot answers, `nocache` limits it to URL, title and snippet | Bing Webmaster Tools › AI Performance (sampled): citations, cited pages, grounding queries |
| Perplexity | PerplexityBot crawl plus live fetches | PerplexityBot; Perplexity-User | None; referrals only |
| Claude | Web search; index provider undocumented | Claude-SearchBot; Claude-User | None; referrals only |
| Apple (Siri, Spotlight, Safari) | Applebot crawl; sources of generative answers undocumented | Applebot; Applebot-Extended (training) | None |
| Naver AI Briefing | Naver-hosted content first, then Naver's web index (see Korea below) | Yeti; Naver Search Advisor; IndexNow | Search Advisor covers web search; AI Briefing citations undocumented |

Sources: developers.google.com/search/docs/appearance/ai-features, …/fundamentals/ai-optimization-guide; support.google.com/webmasters/answer/16908024, /16984139; developers.openai.com/api/docs/bots; OpenAI's publishers FAQ; Bing Webmaster Guidelines; Bing's AI Performance post (Feb 2026); docs.perplexity.ai/guides/bots; support.claude.com/en/articles/8896518; support.apple.com/en-us/119829; searchadvisor.naver.com; indexnow.org.

## Classify the gap

Sample the cluster on the panel first (one run is an anecdote), then check the classes in order and record every one that fits. Fix the earliest on-site class first, usually the fastest win; consensus and accuracy are off-site, so they run in parallel.

| Class | You are in it when | Confirm with | Lever |
|---|---|---|---|
| Access | An engine's search bot is blocked (robots.txt, CDN or WAF rules); the page is `noindex` or snippet-restricted; or the facts appear only after JavaScript runs, which most non-Google AI crawlers never do | robots.txt, CDN bot settings, search-bot hits in logs, a raw-HTML fetch | The technical fix (`technical-seo.md` §2, §4) |
| Retrieval | The page is missing from the engine's index, or ranks outside the top 10 for the head query and its obvious sub-queries | URL Inspection in Search Console and Bing Webmaster Tools; rank checks on the sub-queries; Bing grounding queries | SEO for the head query and its sub-queries, or a new section on the cluster's page |
| Selection | You rank or get fetched, yet another page is cited on most runs for a fact your page holds | Compare the cited passage with yours: is the fact stated in one visible, self-contained sentence (`answer-writing.md`)? | The missing fact, stated first and visibly |
| Consensus | Most cited URLs are third-party pages that leave you out, or the answers cite nothing and come from memory | The source map in `consensus-and-accuracy.md` | Placement on the exact pages engines cite |
| Accuracy | An answer names you with a wrong fact | Brand-fact prompts; trace the cited URL that carries the error | Fix the fact at its source |

## Decisions

**Rank for the fan-out.** On Google's AI surfaces, a page outside the top 10 for the head query and its obvious sub-queries is rarely a supporting link, so fix retrieval before polishing passages. Answer the sub-questions inside the page that owns the cluster: Google says separate content for "every possible variation" of a search, made to manipulate rankings or AI responses, violates its scaled-content abuse policy. *Break:* your panel shows pages beyond the top 10 cited for this cluster; then passage work on them is worth a test.

**Treat published GEO tactics as hypotheses.** The GEO paper's gains from citing sources, adding quotations and adding statistics ("up to 40%"; Aggarwal et al., KDD 2024) come from a benchmark run on a GPT-3.5-based simulated engine plus Perplexity, where keyword stuffing gave "little to no improvement"; most vendor studies are correlational. Test a tactic on panel prompts against holdout pages before rolling it out. *Break:* a fact the page is genuinely missing (a price, a limit, a named source) goes in without a test.

**Choose engines from your own data.** Rank engines by measured AI referrals (channel definition owned by product-analytics, if available) plus a "which AI tools do you use to research [category]?" question in surveys or onboarding, and re-rank quarterly; with no data yet, use SKILL.md's default engines. Market-share headlines disagree by method and describe someone else's buyers.

## llms.txt

Google says Search needs no AI text files ("You don't need to create new machine readable files, AI text files, markup, or Markdown"), and no other major engine documents using llms.txt in answers. Publish one only when it costs nothing, typically for developer docs; never list it as a priority or promise a citation lift. Its companion `llms-full.txt` is a full-text bulk export of everything it lists: leave it out wherever content is sold, licensed or kept from training (`technical-seo.md` §2, exclusion).

## AI shopping

For transactable products, agents read merchant feeds, not just pages: Merchant Center feeds for AI Mode and Gemini, with checkout through Google's Universal Commerce Protocol (UCP), and a structured product feed for ChatGPT shopping. In-chat checkout programs change (ChatGPT's Instant Checkout was reported discontinued in March 2026), so confirm in each program's docs whether buyers can check out in the answer or finish on your site; the feed is needed either way. Run feed accuracy (price, availability, variants) as its own workstream. Browser agents read the rendered page, its DOM and accessibility tree (Google's AI optimization guide): keep prices, stock and limits as text, label form controls, and don't block user-triggered agents at the WAF without logged abuse.

## Non-English Surfaces — Korea / Naver

Naver leads Korean search and Google holds most of the rest, so plan for both, sized from your own referral data. Naver's AI Briefing leans on Naver-hosted content (Blog, Cafe, KnowledgeiN; check the mix on your panel's Korean prompts), so own-domain SEO alone rarely reaches it: publish inside Naver too (an official blog, expert KnowledgeiN answers, participation in Cafes under their rules, and a SmartPlace listing for a physical location). Register in Naver Search Advisor, allow Yeti, and push changes with IndexNow, which reaches Naver and Bing but not Google. Target AI Briefing and Naver's other current AI surfaces (check Naver's notices); Cue: and Clova X shut down in April 2026. A machine-translated mirror adds no information, so it rarely earns citations: each locale needs its own facts (prices, payment, support, local reviews and sources), and a Wikidata Q-ID keeps the entity identical across languages (`consensus-and-accuracy.md`).
