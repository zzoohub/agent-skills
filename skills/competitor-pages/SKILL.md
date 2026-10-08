---
name: competitor-pages
description: |
  Comparison pages for buyers mid-decision: "[Competitor] alternative(s)",
  "[You] vs [Competitor]", "[A] vs [B]", own-site "best [category]" roundups
  and "switching from [Competitor]" guides, with every competitor claim
  sourced and dated and page-level SEO/AEO/GEO built in. Use when creating,
  refreshing or auditing these pages, their comparison tables or a
  competitor page set, or when the user says "competitor page",
  "alternative page", "vs page" or "comparison page". Do NOT use for:
  competitive analysis (the caller's), pricing strategy (pricing), site-wide
  SEO or AI-citation tracking (search-visibility), page CRO (cro), or your
  own system migration (software-architecture, arch-decision).
---

# Competitor Comparison Pages

## Premise

Behind the requested page is a buyer's decision. The page has four readers: the buyer mid-decision, the competitor's sales rep hunting for an error to forward, their counsel, and answer engines that quote single sentences. It is good when a defined buyer can decide from it alone where [Your Product] wins, where it doesn't and what switching costs, every competitor fact holds up on its check date, and it is the one URL of yours for its query. Sometimes the right call is no page.

## Modes

| Mode | When | Do | Return |
|---|---|---|---|
| **New page** (default) | One page, one competitor or query | Stages 1–3 | The page with its sources block; handoff |
| **Refresh / audit** | An existing page; "still accurate?"; a competitor change | Stage 1 items 1 and 4; patch in place, never fork; rebuild at its URL only on request or when its format or most claims fail (`references/portfolio.md` § Refresh) | The patched or rebuilt page, a change list, handoff |
| **Portfolio** | Several competitors; an existing page set; "which pages should we build?" | URL map, triage, Stage 1 for the top 3–5 (`references/portfolio.md`) | URL map, ranked plan, one exemplar page and its register |
| **Fragment** | One block: a table, TL;DR or migration section | Stage 1 items 1–3 (defaults allowed); Stage 2 for its facts | That block and its source lines |

**The request sets the deliverables; the mode adds to them.** Whatever the caller names (a template, a redirect map) ships, or the handoff says why not. Budgets cap what is written, never what is checked: a finding that changes the buyer's answer or the URL plan reaches the caller unasked.

## Stage 1 — Frame the decision

**Read first** (defaults; caller may redirect): the competitor analysis (`biz/marketing/competitors.md`), pricing (`biz/marketing/pricing.md`), marketing strategy (`biz/marketing/strategy.md`), any page or claims register for this competitor under `biz/marketing/competitor-pages/`, the keyword map (`biz/marketing/seo/keyword-map.md`), and Search Console data for your comparison URLs, if shared.

**Ask once** for what those files leave open, each question with its default, plus internal facts (migration time, importer scope) and switcher quotes. Unable to ask, apply the defaults and list them as handoff assumptions.

1. **Reader, stage (query map below) and price range.** The price range is the team sizes the segment's deals against X span (sales notes; default the segment's band, such as 5–50 seats), on each billing basis buyers use, in the market's currency; never a range picked because you win there.
2. **Trigger:** why buyers leave X now. Default: X's 1–3★ reviews from the last 12–18 months and your customers' answers to "what did you use before?" Keep the buyers' words.
3. **Deciding criteria, scored.** The 3–4 criteria that decide deals against X, in buyers' words (loss notes and sales calls first, reviews second), each marked win, tie or loss with its proof; the wedge is the win this segment weighs most. At least two are ties or losses; if not, add what X's 4–5★ reviews praise. Default: inferred from reviews, for the caller to confirm.
4. **What already answers the query.** Per candidate query (singular, plural, vs, switch, pricing): the top-10 formats and any URL of yours that ranks or draws impressions for it. For 3–5 buyer prompts in answer engines, if tools allow (else listed for the caller): the sources cited and each wrong fact about [Your Product], which the page corrects, sourced. Without search data, URL decisions stay conditional.
5. **A first-hand artifact** the top pages lack. Default: item 1's price comparison across the range.
6. **Job, markets, owner.** The job sets the measure: *acquire* (trials and demos from the page), *enable* (sales sends it; win rate against X where buyers saw it) or *defend* (accuracy and recommendation in answers to item 4's prompts). Defaults: vs pages enable and defend, others acquire; US + EU, strictest rule governs; the requester owns a 90-day refresh.

**Query map.** Template URLs are defaults for new pages only.

| Query | Reader | Format |
|---|---|---|
| "[X] alternative" | Leaving X; not yet sold on you | F1 alternative |
| "[X] alternatives", "best [X] alternatives", "best [category]" | Building a shortlist | F2 roundup |
| "[You] vs [X]", "[X] vs [You]" | Has shortlisted you, often mid-sales-cycle | F3 vs |
| "[A] vs [B]" | Hasn't considered you | F4 third-party vs |
| "switch from [X]", "migrate from [X]", "[X] to [You]" | Decided; worried about the effort | F5 switching guide |
| "[X] pricing" | Checking X's cost; may not know you | A dated price section on your page already drawing these impressions; else, if X's pricing is hard to read, an F1 variant at `/compare/[competitor]-pricing` |

**Pick the build from the situation, not from search volume.**

| Situation | Build | Break when |
|---|---|---|
| Clear win for a segment leaving X | F1 led by its trigger, plus F3 | — |
| Feature parity, different business model | F3 on the scored criteria; no checkmark war | — |
| X wins on breadth, you win a niche | F1 as "[X] alternative for [niche]" | No demand, no deals in the niche |
| Buyers compare two others | F4 or F2, disclosed | No first-hand knowledge of both |
| Migration effort is the objection | F5 | Nothing transfers: answer it in F1/F3 |
| X announced a price rise, sunset or acquisition | F1 or F5 within days, linking the announcement | Rumor only |
| X is also your partner, reseller or key integration | Criteria-only F3 or no page; the partnership owner decides | — |
| No defensible wedge | No F1/F3; return the positioning gap | Caller insists: a criteria-only F3, flagged |

**One URL per intent**, checked before any page, merge or redirect. A URL's intent is the query it was built to answer (format, title, H1), usually where it ranks best; its impressions elsewhere are spillover, not ownership.

- **What ranks decides.** The URL built for an intent and ranking for its query, or the keyword map's owner, is its page: refresh it in place, whatever its path; moving it needs a reason worth a 301's risk. Never add a rival (a reversed-name or `/compare/` twin of a vs page, a second F1): the two split rankings, and answer engines pick one.
- **Singular or plural is a results question.** "[X] alternative" and "[X] alternatives" are one intent when their top 10s share at least 3 URLs (search-visibility's test): one page targets both, in the format those results reward (lists mean F2). Otherwise they are separate intents, one URL each when built, cross-linked.
- **Plural, "best" and list-dominated queries stay multi-vendor.** When the query asks for options, or 6 or more of its top 10 are lists, a single-vendor page neither ranks nor converts: build or fix a fair F2 (Stage 3); if you can't, target the singular, vs or switch query and earn a place on the ranking lists (off-site follow-up). *Break:* a list-dominated vs or singular query may still get a vendor page to enable or defend, aimed at that query alone, never at a plural or "best" query or a roundup's URL or redirect.
- **Merge only within one intent, on evidence:** two URLs built for it, both taking meaningful impressions for its query over three months or more, trading places, neither holding a stable top position. Keep the one closer to the format the results reward, then the one with more clicks and links; fold in the other's unique content and 301 it. Different intents sharing a query: retarget each URL (title, H1, anchors) and cross-link; never 301 a roundup into a single-vendor page or back.
- **Own the vs page** for every competitor in at least 10% of competitive deals, whatever its search volume; otherwise answer engines describe you from their page and reviews. *Break:* no wedge yet; fix positioning first.

The Frame is done when the six answers (or defaults), the build and each page's URL decision are recorded.

## Stage 2 — Research into sources

**Never from memory.** Every competitor fact on the page comes from a source fetched in the last 30 days (research order and hard cases: `references/claims.md`). The competitor analysis and sales notes are leads, not sources; [Your Product]'s facts need sources too.

**Scale the record to the request.** A single page or fragment carries a sources block, one dated line per source (template: `references/templates.md`). A page program or scheduled refresh cycle keeps a claims register per competitor, so a changed source reopens every page it feeds. Without web access, draft from the caller's data: every check date no fetch of yours backs becomes `[VERIFY: <the data's date>, <whose data>]`, once per source, never per claim. Mark inline only a missing or disputed fact; cut a fact the page doesn't need.

- **✗ only** when the capability is missing on every plan, natively and via official add-ons, per current docs; otherwise write what is true ("Enterprise only", "add-on $X/user/mo", "beta", "via Zapier").
- **Like-for-like prices across the range.** On each side, the cheapest plan meeting this buyer's must-haves (SSO, say) at dated list price, for every size in item 1's range on each billing basis. Find each crossover, where the cheaper side flips (flat fee against per-seat, seat minimums, tier jumps, unequal annual discounts); state it, and show sizes on both sides of it, never only where one side wins. If you lose across the range, say so and win on the criteria. No estimated "contact sales" prices; usage pricing and a worked example: `references/claims.md`; your own price response: the pricing capability, if available.
- **Claim types.** Performance: a reproducible test on current versions, if their terms allow (`references/claims.md`); else cut. "Best", "only", "#1": a named, current, independent source, or cut. Opinions: attributed. Customer results, switcher counts and quotes: real, attributed, dated, incentives disclosed; never one customer's result as typical, never a placeholder quote that could ship as real. Internal data (win rates, deal counts, sales anecdotes, which customer left which tool) stays off the page unless its owner, and any customer named, cleared it.
- **Net impression.** Rows picked to win mislead even when each is true: include the rows this buyer weighs, losses too. Whatever the title, TL;DR or table implies ("cheaper for teams like yours") needs the proof an outright claim would; if you couldn't state it, don't imply it.
- **Review-site content:** by default no competitor rating, review quote or badge (the sites' vendor rules: `references/claims.md`); paraphrase themes with count, site and date window.
- **No denigration.** Never their breaches, outages, lawsuits or layoffs. *Break:* a change they announced themselves (a price rise, an end of life), linked and stated neutrally.
- **Trademarks.** Plain-text competitor names, no logos without counsel's approval, the template's footer; market rules and disputes: `references/claims.md`.

## Stage 3 — Draft

Write from the matching template in `references/templates.md`, inside its word budget.

- **Structure follows the decision.** Alternative pages: the top 2–3 triggers as buyers' needs → how [Your Product] resolves each → proof; vs pages: the scored criteria as question headings. The naive page tours features and never says why the reader is leaving. *Break:* without trigger evidence, criteria only and fewer claims.
- **Concede specifically.** At least two rows or verdicts where [Competitor] wins or ties, from the scored ties and losses, one stated plainly ("[Competitor] has native Gantt charts; [Your Product] does not"), plus who should stay with [Competitor]. Never concede the wedge; no token concessions ("[Competitor] has been around longer"). *Break:* switching pages say what doesn't transfer instead.
- **Own-site roundups and A-vs-B pages (F2, F4)** open with the template's disclosure. No self-awarded "#1" or "best overall"; [Your Product]'s labeled entry sits where the criteria place it, never first by default. Every entry needs first-hand evidence and a "best for [segment]" verdict you would defend to that vendor. Why: `references/claims.md`.
- **Specifics, not adjectives,** about either product. Reject "enterprise-grade", "no bloat" and "clunky" (nothing to quote, easy to mock), checkmark grids (they hide plan gates) and undated screenshots.

## Output

1. **The page**, opening with an HTML comment holding the title, meta description, target query and item 4's prompts (search-visibility reads them there, if available) and closing with its sources block. With file-write: `biz/marketing/competitor-pages/{slug}.md` (default; caller may redirect the `biz/<area>/` root; publishing is the caller's), `{slug}` being the page's URL path without slashes (`vs-linear`, `switch-linear`), updated in place; otherwise inline.
2. **Portfolio or a scheduled refresh cycle only: register rows**, merged into `biz/marketing/competitor-pages/claims/{competitor}.md`, [Your Product]'s into `claims/{your-product}.md` (defaults; same redirect).
3. **Every other artifact the request named**, outside the handoff's budget.
4. **Handoff, at most 150 words:** assumptions applied; publish blockers (open markers by type; counsel's sign-off on the sources and rendered page, naming every performance, superlative, implied and customer-result claim); URL decisions and the evidence they await; job, measure, target query and prompts; refresh owner and date, with a change monitor on each price and plan-gate source; off-site follow-ups; proposed changes to the competitor analysis, which this skill never edits.

The page never narrates this method: no "wedge", "liftable" or register IDs in the copy.

## Self-Review

Run on the finished work; fix and re-run. A fragment checks only the items its block touches.

1. Every artifact the request named is delivered, or the handoff says why not.
2. TL;DR: 40–60 words, names the products and who should choose each (F5: switch time, what transfers and what doesn't), with at least one sourced number.
3. Concessions: F1/F3 at least two plus "Stay with [Competitor] if" (F3: "Who [Competitor] Is Best For"); F5 what doesn't transfer; F2/F4 each entry's shortfall, yours included. Never the wedge.
4. Every competitor fact traces to a sources line checked within 30 days of publishing, or that line's date is a `[VERIFY]`; inline markers sit only on missing or disputed facts; the handoff counts every marker.
5. No ✗ where any plan or official add-on has the capability.
6. Prices span item 1's range on each billing basis, each crossover stated and shown from both sides, with seats, billing basis, parity plan, currency and check date beside them.
7. No unsubstantiated superlative, "only", performance or implied claim; no uncleared testimonial or internal fact; incentives disclosed.
8. At least one first-hand artifact.
9. Question headings answered in their first sentence, products named; decisive rows restated in prose; trust line under the H1, footer at the end; markup, if any, only Article or WebPage plus BreadcrumbList; title about 55 characters, query first; description opening with the verdict and a number.
10. F2/F4: disclosure first, published criteria, no self-awarded #1, yours not first by default, a year only if re-tested.
11. URLs: no new URL rivals a ranking one; no single-vendor page takes a plural or "best" query or a roundup's redirect; every merge joins two URLs of one intent.
12. Competitor-PMM test: their product marketer would accept every fact about their product as of the check date, and find no adjective about it, nor any review-site rating or quote of theirs.
13. Portfolio: with another competitor's name swapped in, most sentences on each page become false (`references/portfolio.md`).
14. **Footprint:** the page is within its template's budget and every section answers a question this buyer has; the handoff is at most 150 words; a portfolio plan at most 300 plus its URL map, one row per URL.

## Reference Files

| File | Read when |
|---|---|
| `references/templates.md` | Drafting any page or block; title and meta; the sources block or a register; markup |
| `references/claims.md` | Stage 2 research; pricing cases; review-site rules; performance, "best" or market-law questions; disputes |
| `references/portfolio.md` | Portfolio or Refresh mode; URL maps and redirects; an underperforming page |
