---
name: search-visibility
description: |
  SEO, AEO and GEO: visibility in Google, Bing and Naver results and in AI
  answers (AI Overviews, AI Mode, ChatGPT, Perplexity). Audits, traffic-drop
  diagnosis, keyword research and keyword maps, briefs and blog articles
  meant to rank or be cited, technical SEO (indexing, rendering, migrations,
  hreflang strategy), AI crawler access policy, AI-citation tracking.
  Use when: "SEO audit", "organic traffic dropped", "keyword research",
  "get cited by ChatGPT", "block AI crawlers", "Search Console".
  Do NOT use for: competitor, alternative, vs or roundup pages incl. their
  page-level SEO (competitor-pages); hreflang tag code or locale routing
  (i18n); GA4 setup or funnel analytics (product-analytics).
---

# Search Visibility

## Premise

Search visibility is one pipeline per engine: **access** (fetch allowed, snippets permitted, content survives rendering and the fetch limit) → **index** → **retrieve and rank**, for the query and the sub-queries an AI answer fans out to → **select** (shown, quoted or cited) → **click or mention** → **convert**. AI answers also draw on third-party consensus and model memory. For Google, AI optimization is SEO: its AI features run on its core ranking systems and need no special markup, AI files or chunking. The job: fix the earliest broken stage on the pages and prompts that carry revenue, and name the metric that will prove it.

Some goals run the other way, keeping content from a use (training, AI answers, an index): a leak-path problem, not a config edit. Cover every path the content leaves by, what each control can't stop, and the residual risk (`technical-seo.md` §2).

Hand off, via each capability if available: comparison, alternative and own-site roundup pages (competitor-pages); social, email and brand copy (copywriting); conversion (cro); GA4 and funnels (product-analytics); hreflang tags and locale routing (i18n).

**Output:** articles and briefs to the blog dir (default `biz/marketing/content/blog/`); audits, keyword research, plans and AI-visibility work to the search dir (default `biz/marketing/seo/`; caller may redirect the `biz/<area>/` root). Update living files in place, never duplicate them; dated files are baselines. Without a file-write capability, return results inline.

## Modes & Routing

Requests arrive as solutions ("more blog posts", "block the AI bots"): restate each as the outcome behind it and its mode's forcing question, and test the premise against the evidence first. When the real problem sits outside the literal ask, solve it or hand it off with enough detail to act on.
- **Inline** (one question): what decides it on this site?
- **Fix** (one bounded change: a robots.txt or CDN rule, redirects, canonicals, markup, a title): is this the broken stage, and what smallest change passes a check today?
- **Page** (brief, write or rework one page): which cluster does this URL own, and what do results and AI answers reward?
- **Audit** (a site, section or template): which revenue templates fail at which stage, on how many URLs?
- **Diagnose** ("organic traffic dropped"): how big is the real change, net of reporting artifacts, and which stage and segment moved, when?
- **Change** (migration, replatform, new locales): where is the URL map, and what triggers a rollback?
- **Access policy** (which crawlers and AI uses to allow or refuse; a single robots.txt or CDN change is a Fix plus a verdict line per agent role): what does each agent role cost or protect, and which paths out stay open?
- **AI visibility** (citations, recommendations, wrong facts): which prompts, what gets cited, which gap classes (`ai-platform-optimization.md` § Classify the gap), from panel runs (`measurement.md` §5)?
- **Plan** (strategy, content plan, keyword research): which clusters can we win nearest revenue?

**Proportionality.** Budgets size the record, never the analysis: run every check the mode needs (the real problem, the numbers, the traps, who else is affected) before choosing what to write, and let every material finding reach the reader, in one line if that is enough. Inline: no frame or file, ≤200 words (the answer, its deciding condition, the confirming check). Fix: no baseline, plan or panel. Page reads only its cluster. A one-cluster or one-engine AI question runs the `measurement.md` §5 pilot in ≤400 words. Several modes run in pipeline order into one deliverable, named and budgeted as the largest-budget mode, appendices included; a material finding that won't fit goes in anyway, with the reason in the report back.

## Step 0 — Frame

**Read first** (defaults; caller may redirect; note absent files and continue): the search dir's living files and latest audit; the blog dir; competitor-page drafts (default `biz/marketing/competitor-pages/`, read-only; each opens with an HTML comment naming its target query and tracked prompts); the competitor analysis (`biz/marketing/competitors.md`); before drafting, the Brand Voice section of `biz/marketing/strategy.md`.

**Calibrate once**, in one batch, asking only what changes the output; unanswered items take their defaults as labeled assumptions (a run that cannot ask states them in one line).
1. **Site and demand** (default: judge from the site), setting where to look first: new or low-link domain → access, indexing, narrow winnable clusters; catalog or UGC → index controls, facets; content library → decay, cannibalization, pruning; local → Business Profile (Naver SmartPlace), reviews; publisher → Top Stories, Discover, an AI-use policy for the archive. No search demand yet? Say so first (search captures demand; it doesn't create it) and scope to problem-aware, comparison and brand-fact queries.
2. **Money pages** and their URL counts (default: pricing, signup or demo, product and category templates).
3. **Market and engines** (default: the site's main language and country; Google with AI Overviews and AI Mode, ChatGPT, and Naver for Korean).
4. **Stack and data:** rendering, CDN; Search Console, Bing and Naver consoles, GA4, logs; crawler, keyword, link and AI-tracking tools (default: none, so read the raw HTML yourself; findings are hypotheses).
5. **Last 90 days:** releases, migrations, tracking or consent changes (default: unknown, so a diagnosis rules them out first).
6. **Capacity** for development, content and PR (default: one small team, so effort weighs heavily).
7. **Reader** (default: whoever implements it); a leader, client or budget owner who decides gets the decision-memo shape (Step 3).

**Evidence.** With a fetch or browse capability, look before diagnosing: live results and AI answers for the target queries (logged out, target market), raw and rendered HTML, robots.txt and responses per bot. Without one, say once what you couldn't see and make each gap that matters a check with an owner; no access disclaimers elsewhere.

**Done:** a Fix, decision memo or access policy meets its Step 3 spec, with no ask or agent role left without a verdict. In an audit, diagnosis, AI-visibility memo or plan, every finding names its stage, scope (template, affected URLs, traffic or revenue share) and evidence, or is a labeled hypothesis with its confirming check, and every action has an effort and the metric that proves it, read at its lever's lag: access, index and title fixes, weeks after recrawl; new or merged pages, months; links, PR and consensus, a quarter or more; AI answers, the next one or two panel waves.

## Step 1 — Baseline and diagnose

Work per template or cluster, ranked by affected URLs × traffic or revenue share (unless one URL carries most of the value). Fix the first broken stage before anything downstream: retitling an unindexed page is waste, and an intentional block (Disallowed internal search, a noindexed thank-you page) is not a finding.

| Stage | First evidence | Typical failure |
|---|---|---|
| Access | robots.txt, CDN rules and status codes per bot; robots meta; raw HTML | Target search bot blocked; `nosnippet` or `max-snippet:0` on money pages; facts only after JavaScript runs |
| Index | Page Indexing per template sitemap; URL Inspection; Manual actions and Security issues | Stacked index controls; another canonical chosen; a manual action or hacked pages |
| Retrieve and rank | Search Console queries per cluster; live results; referring domains vs the top five | Wrong page type; cannibalization; outside the top 10 for sub-queries; outgunned on links |
| Select | Live SERP features and AI answers beside your passage | Fact not stated in one visible sentence |
| Click or mention | CTR against your curve (`measurement.md` §3); panel appearance | An AI Overview takes the click; absent from the cited pages |
| Convert | Key events per landing template | No next step on the page (cro) |

**Broad requests** (a site-wide audit, strategy or diagnosis memo): cover every stage on the money templates, plus measurement integrity (tracking and reporting changes), access for every agent role, and the off-site layer (what engines cite, brand facts in answers), even when the ask names one; each gets a finding or a "checked, fine" line.

## Step 2 — Decide

- **The live result decides the page type.** Take type, format and angle from the top results and AI answer; never aim a page at a query rewarding another type, or flatten conversion or narrative copy into answer blocks to chase one. *Break:* split intent (serve the slice nearest revenue), or unsettled results.
- **One intent cluster per URL.** Queries share a URL when their top-10 results share at least 3 URLs; merge or retarget only on cannibalization evidence (`seo-fundamentals.md` §3). *Break:* both already rank on page 1, or conversion needs both pages.
- **Update before you create; no new information, no page.** Improve the URL already earning impressions (a top-3 page at or above your CTR curve gets additions only); a stalled page of the rewarded type may lack links, not content (`seo-fundamentals.md` §3). A new page must add what the top results and cited sources lack (first-hand data, tests, prices or limits, a tool, a worked example), or it isn't built. *Break:* changed intent or wrong facts justify a rewrite; brand-fact pages (pricing, plans, integrations, docs) exist regardless.
- **Read the citations before writing for AI.** Per prompt cluster and engine, tabulate cited domains across runs: 60% or more third-party → off-site work on those exact pages; 40% or more competitors' own pages → on-site; in between, split by the shares. *Break:* uncited answers come from memory: build consensus and keep the facts page ready.
- **Visible text or it doesn't exist.** Quotable facts live in server-rendered, visible HTML; markup pays only through live search features and entity data (`technical-seo.md` §7). *Break:* shopping surfaces read merchant feeds; there the feed is the truth.
- **Stay in Google's AI features unless the visit is the product:** opting out drops your links, not the Overview (the narrow case and its test: `technical-seo.md` §2).
- **Scale only with unique value.** Location, glossary, programmatic and per-sub-query pages each need unique data and real demand, or they are scaled-content or doorway abuse. No break: LLMs make exactly this cheap.
- **Recommend a default on every contested call,** including one another function owns (legal, finance, product): your verdict, default, trade-off and decider, with the draft artifact (robots.txt groups, a rule, a policy line); "ask legal" alone is not a recommendation.
- **An access policy covers every agent role** (search, user fetch, training, opt-out tokens) and unnamed agents (`technical-seo.md` §2). Default: allow each target engine's search and user-fetch agents; allow training on pages meant to make you known, refuse it on content you sell or license. *Break:* a no-training decision already made (by the caller, legal or the content owner) is implemented for every training agent and token on every path out, with its cost in one line (memory answers may lack your facts; Gemini grounding ends). A licensing publisher may refuse search bots too.

**Reject list.** Never recommend these; file any raised under "Not worth doing" with the reason:
- keyword density, "LSI keywords", meta keywords, word-count targets as a ranking lever; FAQ or HowTo markup for rich results or AI; llms.txt as a priority;
- toxic-score disavows; URL changes outside a migration; date changes without real edits; roundups that rank you first by default;
- unsourced statistics, invented quotes, hidden text or instructions aimed at AI; editing your own Wikipedia article; seeded threads or undisclosed paid mentions;
- DA or DR as a KPI; AI "ranks" or single-run results.

## Step 3 — Deliver

Write from the matching spec (budget in words, appendices included; file; sections in order). Sections are a menu: omit what doesn't apply, heading included. A side file only when asked for or already there (update in place); missing data becomes a list of data pulls (what, which tool, who), never a table of unknowns.
- **Fix** (≤300 + the changed artifact, applied in place when its file is in the workspace or the caller names it, else inline as a diff): the broken stage and its evidence, briefly; the acceptance check (tool or command, and the passing result); for a control, what it can't do; the lagging-metric line; next steps, one line each.
- **Brief, Article** (`answer-writing.md` § Briefs and articles), **Access policy** (`technical-seo.md` §2), **Change plan** (`technical-seo.md` §9): the specs there.
- **Audit or diagnosis** (≤1,500, a traffic diagnosis ≤800; `audit-YYYY-MM-DD-{topic}.md`): summary ≤150 words, opening, when traffic changed, with the corrected change in the reader's metric; findings by severity (🔴 a money template fails access or indexing, or spam-policy exposure; 🟠 demand lost at scale on top clusters (index bloat, overridden canonicals, orphaned money pages, intent mismatch, proven cannibalization, demand with no page), Core Web Vitals poor at p75 on money templates, absence from pages cited on shortlist prompts, wrong brand facts in AI answers; 🟡 CTR below your curve at a stable position, gaps without index impact; 🟢 the rest), each with evidence, scope, fix, effort and validation (10 in full at most, the rest one line each, grouped by cause); Not worth doing; the baseline read (metrics, sources, dates).
- **AI-visibility memo** (≤1,200; `ai-visibility-YYYY-MM-DD.md`; raw runs go to `ai-visibility-log.md` when it exists or tracking is wanted, never into the memo): target per cluster; baseline (cluster × engine: appearance %, cited %, top cited domains); gap class and evidence; actions by impact × confidence ÷ effort, each with its metric (7 in full at most, the rest one line each); re-test plan with the noise floor; Not worth doing.
- **Plan** (≤2,000; `seo-strategy.md`; `keyword-map.md` when keyword research is the ask or the map exists): goal and money pages; prioritized clusters, each with sources and an expected-clicks range; create, update and merge map; a dated publishing order sized to capacity; technical prerequisites; AI and off-site plan; targets inside the forecast band, citing it (a stretch names the lever that closes the gap); a 90-day checkpoint on leading indicators, stop thresholds set in advance (`seo-fundamentals.md` §1); Not worth doing.

**Decision-memo shape** (decisions first, within the mode's budget; it replaces the spec's order and summary, the spec's other sections folding into Decisions or Evidence, none repeated): **Bottom line** (≤120 words): the answer in the reader's metric (clicks, sign-ups, revenue); for a reported change, its size as reported and as corrected for artifacts, with range, window and cause; the main recommendation. **Decisions**, one per ask: verdict, recommended default, trade-off, decider, date, draft artifact. **Targets** inside the forecast band. **Acceptance tests** per decision: the pass-or-fail check now, the lagging metric and its read date. **Checks before the decision:** each open fact or data pull, with owner and how to settle it. **Not worth doing**, with reasons. **Evidence**, compressed.

Every run:
- **Claims by tier.** State established policy and mechanics plainly, naming the policy (Google's spam, structured-data and review rules; robots.txt, noindex and canonical behavior); never hedge a known violation. Date the platform facts the references verified. Check volatile claims (program terms, CDN defaults, limits) with a fetch; failing that, a brief or article marks `[VERIFY: claim]` and any other deliverable lists it as a check before the decision, with an owner. Site metrics come only from caller material or a tool; a missing one is a data pull, or `[SOURCE NEEDED: what]` in a brief or article. No inline markers outside briefs and articles; never invent or attribute a quote.
- **Say what it can't do,** one line per recommended control or tactic: answer and snippet work raises the odds of selection, never guarantees it; citations shift monthly; robots.txt binds only compliant agents, from now on; noindex doesn't stop crawling; a citation promises no clicks.
- **Write for the reader:** pair every fact with the decision it drives, and cut facts that drive none; no step labels, rule names or reference-file names in deliverables; name broken stages in plain words.
- **Report back** (not for Inline; ≤150 words): files written, mode, top findings, assumptions, open questions, any scope cut or budget overrun and why, and the count of open checks and marks.

## Self-Review

Fix and re-run until all hold.
- **Done** (Step 0) holds; every material finding appears, at least as one line, even outside the literal ask; a Fix carries no baseline, plan or panel.
- **Numbers reconcile:** a number that appears twice matches; totals add up; each target sits inside its forecast band or names the lever beyond it; a reported change is corrected for artifacts, in the reader's metric.
- **Decisions are made:** each ask has a verdict, default, trade-off, decider and draft artifact; an access policy covers every agent role and unnamed agents, and implements a no-training decision already made; an exclusion covers every path out and its residual risk.
- **Claims:** no hedged policy, undated platform fact, inline marker outside a brief or article, `[SOURCE NEEDED]` the caller's material could fill, or reject-list item.
- No fix sits downstream of an unfixed earlier stage; no URL pairs a Disallow with a noindex or canonical; AI figures come from at least 5 consumer-interface runs per prompt, noise floor stated, no ranks.
- Pages and articles pass their spec's checks (`answer-writing.md`).
- **Footprint:** one deliverable within its budget, appendices included (over it only for a material finding, reason given); side files only when asked for or already there; no table of unknowns.

## Reference Files

In `references/`; read those tagged with your mode.
- `technical-seo.md` (Fix, Audit, Diagnose, Change, Access policy): triage; agent roles, AI controls, exclusion paths; rendering, markup, locales, migrations; access-policy and change-plan specs.
- `seo-fundamentals.md` (Page, Audit, Plan; §4 for a title or copy Fix): query research, keyword map, sizing, create, merge or prune, on-page, links, spam.
- `answer-writing.md` (Page; a copy Fix): brief and article specs; drafting sections.
- `ai-platform-optimization.md`, `consensus-and-accuracy.md` (AI visibility; broad requests; Plan when AI is in scope): engines, gap classes, llms.txt, off-site and accuracy work.
- `measurement.md` (Audit, Diagnose, Change, AI visibility, Plan; elsewhere only to measure or prove a result): data, traffic changes, baselines, the prompt panel.
