# SEO Fundamentals

Read when researching queries, sizing clusters, mapping them to URLs, choosing to create, update, merge or prune, telling a content gap from an authority gap, fixing on-page elements, planning a hub, earning links, or checking E-E-A-T and spam risk. SKILL.md states the rules; this file holds the procedures. Google facts checked 2026-10-08.

## 1. Research: results first

Keyword tools estimate; the live results decide.

1. **Start from money and real demand:** the pages that convert, the queries already reaching them in Search Console (the cheapest wins rank just below the positions that earn clicks on your CTR curve, `measurement.md` §3), the words buyers use in sales calls, support tickets and site search; only then a keyword tool to expand. Every volume carries its tool and date.
2. **Read the live results** for each candidate, logged out, in the target country and language: the dominant page type and format, how fresh the top results are, and whether an AI Overview shows and what it cites. Who ranks reveals intent: forums on top mean searchers want first-hand experience; brands on top mean they are buying.
3. **Cluster by overlap,** using the shared-results test in SKILL.md's "one intent cluster per URL" rule; check borderline pairs by hand. *Break:* results that haven't settled (a new topic): cluster by meaning and re-check in a month.
4. **Prioritize** by revenue proximity × winnability × demand, each with its source. Judge winnability from the results: can you add what the top pages lack (§3), and are they beatable (thin, dated, forum threads, referring domains within reach)? A vendor difficulty score breaks ties; it doesn't decide.
5. **Size each cluster and fix the checkpoint now.** Expected clicks, as a low–high range over reachable positions: demand (Search Console impressions, or a tool's volume for a new cluster) × (your curve's CTR at that position − current CTR), on the curve's AI-Overview split where an Overview shows; × the landing template's conversion rate gives key events. No curve or data: call the cluster unsized and list the pull that would size it. Targets sit inside this band; one above it names the lever that closes the gap, or it isn't a target. New pages rarely earn clicks by day 90, so the checkpoint reads leading indicators, each with a stop-or-re-plan threshold: indexed share of new URLs, impressions and top-20 entries per cluster, panel appearance.

Intent comes from the results, not the words: "CRM pricing" may reward a comparison table rather than your pricing page.

## 2. The keyword→URL map

The single record of which URL owns which cluster: `keyword-map.md` in the search dir (default `biz/marketing/seo/`; caller may redirect), updated in place; created when keyword research is the request or the map already exists. One row per cluster, each cell a phrase; a column with no data stays out and its pull is listed, never a column of "unknown". Columns: cluster · queries (head query first, at most five; the full list stays in the tool export) · intent · rewarded page type and format, AI Overview yes or no · target URL (existing, "new", or "merge A → B") · status with date · source and date of every number.

- One target URL per cluster; "new" only after the information-gain test (§3).
- Target queries from each competitor-page draft's opening comment, or a handoff the caller passes, enter as rows owned by those pages; no other URL targets them.

## 3. Create, update, merge or prune

**Cannibalization needs evidence.** In Search Console, filter one query (exact match) over three months or more and open Pages: it is cannibalization only when two or more of your URLs take meaningful impressions, swapping over time, while neither holds a stable top position. Two of your URLs on page 1 are a win.
- Same intent (their results overlap): merge into the stronger URL (more clicks and links for the cluster, closer to the rewarded type); move the unique content, 301 the other, update internal links and the sitemap.
- Different intents: retarget each URL to its own cluster in title, H1, body and inbound anchors.
- Conversion needs both (a plan page and a feature page): differentiate titles, H1s and anchors, and link one to the other.

**Refresh on a trigger,** never on a calendar alone: facts changed, the rewarded type shifted, or clicks decay at a stable position. Answer the sub-questions the results answer, add what they lack, fix the title; judge it as `measurement.md` §6 describes and revert losers.

**Content gap or authority gap.** For a page of the rewarded type stalled below the top results, run the information-gain grid below against the top five and compare referring domains to their URLs and sites with yours (from a link tool; without one, a labeled hypothesis). Missing or thin rows: add them. Comparable content but far fewer referring domains: internal links from your strongest pages, a linkable asset pitched for links (§6), or a narrower sub-cluster where forums or thin, dated pages rank; another rewrite won't move it.

**Inventory a content library** per URL over the last 12 months: clicks or key events → keep, refreshing on a trigger; referring domains but no clicks → 301 to the closest relevant page, if one exists; neither → 410 if no one uses it, noindex if customers or site navigation still need it; same intent as a stronger URL → merge (above). Pruning serves quality and crawl focus on large libraries; on a small site it is rarely the fix.

**The information-gain test.** Before drafting, grid the sub-questions (from the results, People Also Ask and the AI answer) against the top five results and the cited AI sources, marking each cell covered, thin or missing. The page exists for a row nobody answers well, or for evidence nobody else has: your data, tests, prices or limits, a tool, a worked example. If you can't point to one, don't create it (exceptions: SKILL.md's no-new-information rule).

## 4. On-page

- **Title:** front-load what sets this page apart from the other results; there is no character limit, only truncation to check. A rewrite in the results shows what Google thinks the page is about. Judge the meta description by CTR; Google mostly builds snippets from page content.
- **Dates:** change the visible date and `lastmod` only with a substantial edit; Google flags changing dates "to make them seem fresh".
- Internal links and click depth: `technical-seo.md` §5.

## 5. Topic clusters (hub and spoke)

Build a hub only when the broad term's results reward a guide or overview; when they reward a category, product or tool page, that page is the hub. Each spoke owns one intent cluster and passes the information-gain test. Link the hub to every spoke and each spoke back; spoke to spoke only where a reader needs the next step. "Topical authority" is no reason to publish thin spokes: they add nothing and tend to end up "Crawled – currently not indexed".

## 6. Links

- **Links remain a ranking input** (PageRank is still part of Google's core systems). Judge a link by topical relevance and the referral traffic it sends, not by count. DA and DR are vendor scores: use them to sort prospects, never as a target or KPI.
- **Earn them** with assets others cite (original data, tools, benchmarks); for AI answers, a mention on the pages engines cite counts with or without a link (`consensus-and-accuracy.md`).
- **Paid, sponsored or gifted links** must carry `rel="sponsored"` or `rel="nofollow"`; that is a policy requirement.
- **Disavow** only under a manual action for unnatural links, or for links you know were bought; Google says "most sites will not need to use this tool". Disavowing on a tool's "toxic" score wastes time and can cut links that help.

## 7. E-E-A-T, YMYL and spam

- **E-E-A-T is not a ranking factor;** use Google's Who/How/Why test: a named author with a real author page; how it was made, AI use disclosed where readers would expect it; made for readers, not to rank. YMYL topics (health, money, safety) need qualified authors or reviewers and primary sources.
- **Spam policies an LLM-assisted program trips** (Google's spam policies): *scaled content abuse*, many pages made mainly to rank or to sway AI answers, including per-variation pages for fan-out queries (the test is value per page, not whether AI wrote it); *doorways*, near-duplicate pages per city or keyword funnelling to one destination; *site reputation abuse*, third-party content hosted to borrow the host's signals. Bing's guidelines also bar prompt injection aimed at its models.

## 8. Page types models misjudge

| Page | Correct treatment |
|---|---|
| Pricing | Prices, plan limits and inclusions in visible HTML text; hide them and AI answers quote third-party price pages, often stale |
| Docs and help | Often a SaaS product's largest non-brand surface: indexable, titled for the problem searched, linked from product pages |
| Glossary | Commodity definitions are what AI Overviews answer directly; build one only with product-specific data, examples or a tool |
| Careers | A JobPosting-marked page per open role, expired when filled; check region support (technical-seo.md §7) |
| Events | Event markup only for events with a physical location; online-only events are ineligible |
| Own-site "best X for Y" roundups naming competitors | Owned by competitor-pages, if available, under the guardrails in consensus-and-accuracy.md (disclosure, published criteria, no self-awarded #1). Being cited is not being recommended: an AI answer can cite your roundup and still name a competitor |
