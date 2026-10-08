# Competitor Page Templates

Sections are a menu: omit what doesn't apply to this buyer, heading included.

## Filling These Templates So They Get Cited

Retrieval is not citation, and citation is not recommendation: answer engines lift named, specific, fair sentences and discount self-promotion, and review-style answers mostly cite third-party sites (hence the handoff's off-site follow-ups). So every slot below must read alone, to a skimming buyer and to an engine quoting one sentence:

1. **The TL;DR is the answer, not a trailer.** Name both products. Carry at least one hard number. If a reader could stop there and act, it is right.
2. **Every bracketed heading becomes a question a buyer asks.** `[Category 1: e.g., Features]` is a slot, not a heading — ship "Which handles [job] better?", not "Detailed Comparison". First sentence under it is the answer.
3. **Claim sentences name products; connective prose can use "we".** "[Your Product] imports [Competitor] projects in one step" survives being lifted; "we import everything automatically" does not.
4. **Every comparison slot takes a number and a source.** Prices at the page's team sizes, a migration time range, a plan gate with a link to the competitor's own docs. Adjectives are not comparisons.
5. **Restate the decisive table rows in prose.** Two or three sentences under each table, products named.

**Budgets** are drafting ceilings, not ranking rules: exceed one only where the pages that rank and get cited for this query are deeper on substance, never to pad. TL;DR 40–60 words · question sections 60–180 words, answer first · tables at most 12 rows, only rows this buyer weighs · whole page: the budget in its template header.

**Trust line** under every H1: `By [Author, role] · Updated [date] · [Competitor] prices and features checked [date] from their public pages`, the oldest check date among the page's sources (unchecked: see Markers). **Footer** closing every page, below the sources block: `[Competitor names] are trademarks of their owners; [Your Product] is not affiliated with them.`

**Price slot**, in every template with prices: each side's cheapest plan meeting the stated must-haves at 3–4 team sizes (2–3 in a multi-vendor table) covering both sides of every crossover (SKILL.md Stage 2), one row per billing basis whose crossover differs, captioned `List prices in [currency], checked [date]`; then one sentence saying where each side costs less, naming every crossover: "[Competitor] costs less below [N] seats billed annually; from [N] seats [Your Product] does, $X versus $Y a month at [M]." [M] is the median deal size against [Competitor] (sales notes), else the range's midpoint. If one side wins across the range, say that instead.

**Headings from evidence:** sales-call questions, review phrases, Search Console queries, and the grounding queries in Bing Webmaster Tools' AI Performance report. Cover the few questions that decide, in the buyers' words; exhaustive coverage gets cited less (AirOps, Apr 2026, ChatGPT).

**Markers** are literal, so a draft can be grepped before publishing: `[TODO: …]` an input only the caller has; `[VERIFY: claim — URL to check]` a fact from memory or a secondary source (the caller's notes, a source you didn't fetch), or one two sources contradict; `[SOURCE NEEDED: what]` proof no source gives yet. An unchecked source is marked once, never per claim: each `checked [date]` it backs (its sources line, the price caption, the trust line) reads `checked [VERIFY: <the data's date>, <whose data>]` until you fetch it. Other markers go inline only where a gap blocks publishing; a gap that blocks nothing is cut. Any marker left means not publishable.

**Render** verdicts, tables and prices as text in the initial HTML, never as images or content loaded on click: crawlers that skip JavaScript see only that HTML.

**Title and meta description** go in the page's opening comment. Google sets no length limit but truncates both to the device's width and may rewrite them (Search Central, "title links" and "snippets", checked 2026-10-08). Title: the H1's query words first, then segment or key difference, then brand, about 55 characters (F1: `[Competitor] Alternative for [Segment] | [Your Product]`). Description: the verdict and one number first, since truncation varies by device; about 155 characters in all. Check both in a current SERP preview. `[Year]` = the year of the last substantive refresh, only where a template allows it.

---

## Format 1: [Competitor] Alternative (Singular)

**URL**: `/alternatives/[competitor]` · **Budget**: 1,200–2,000 words; sections are a menu

```
# Looking for a [Competitor] Alternative?
[Trust line]

## TL;DR
[40-60 words. Both products named, at least one hard number, verdict stated outright.
 Shape: "Teams leave [Competitor] mainly when they need [need]. [Your Product] [meets it how]
 and costs less from [N] seats ($X versus $Y/mo for [M] users, billed annually). Best for
 [segment]; [Competitor] remains the better fit for [honest case]."]

## Why Teams Leave [Competitor]
[The top 2-3 triggers as needs, in the buyers' words, each with source, count and date window:
 "In 40 of 212 1-3★ G2 reviews from Jan 2025-Jun 2026, reviewers say they needed [need]."
 Paraphrased: no quoted reviews, no adjectives about [Competitor].]

### [One question per trigger: e.g., "Does [Your Product] [meet need] without [cost]?"]
[Answer first, both products named; then the proof: a number, a doc link, a first-hand test.]

## [Your Product] vs [Competitor]: Features and Price

| | [Your Product] | [Competitor] |
|--|---------------|--------------|
| [Deciding criterion] | [What is true, on which plan] | [What is true, on which plan] |
| [At least two rows where [Competitor] wins or ties] | ... | ... |
| Price at [A] / [B] / [C] seats, billed [basis] | $X / $X / $X ([plan]) | $Y / $Y / $Y ([plan]) |
| Same sizes, billed [other basis], if its crossover differs | ... | ... |

[Price-slot caption. Restate the 2-3 decisive rows in prose, products named: "[Your Product]
 includes [Feature A] on every plan; [Competitor] gates it behind [tier] at $Y/seat." Then the
 price slot's sentence, the most-quoted fact on the page: where each side costs less. Beside the
 table, answer switching cost with what you offer: importer, assisted migration, contract-overlap credit.]

## Who Should Switch (and Who Shouldn't)

**Switch if you:** [criteria tied to the triggers]
**Stay with [Competitor] if you:** [honest criteria]

## How to Switch
[What transfers automatically, what needs manual setup, a time range, support offered;
 link the switching page if one exists.]

> "[Real quote from a customer who switched]" — [Name, role, company]

## [CTA heading]
[Trial, demo or migration help, matched to the reader's stage]
[Sources block]
[Footer]
```

---

## Format 2: [Competitor] Alternatives / Best [Category] Tools (Roundup)

**URL**: `/alternatives/[competitor]-alternatives` or `/best/[category]-tools` · **Budget**: up to 3,000 words; sections are a menu

```
# [N] [Competitor] Alternatives for [Segment]   <!-- or "Best [Category] Tools for [Segment]"; [Year] only if re-tested every year -->
[Trust line]
[Disclosure, first two sentences: "[Your Product]'s team publishes this guide, and [Your Product]
 is one of the entries, labeled as ours. We compared each tool on [criteria] in [month year]."]

## TL;DR
[40-60 words naming the top 3 options and who each is best for, with one price or limit:
 the block an AI answer to "best [Competitor] alternatives" lifts whole.]

## Why Teams Look Beyond [Competitor]
[Triggers as needs, in the buyers' words, with source, count and date window]

## How We Chose and Tested
[The criteria, in the order they decide; what was tested hands-on, and when; what came from vendor docs.]

## The Alternatives

### [Tool] — Best for [segment]
[Open with a liftable verdict you would defend to that vendor; then what it does, how it
 compares, where it falls short.]
- **Pricing**: [plan and price at the page's team sizes, date checked]
- **Best for**: [segment]

[4-7 real entries in criteria order, each with first-hand evidence]

### [Your Product] (our product) — Best for [segment]
[Same shape and scrutiny, shortfalls included. Placed where the criteria put it, never first by default.]

## Quick Comparison

| | [Tool A] | [Your Product] (ours) | [Tool B] |
|--|---------|-----------------------|---------|
| Best for | ... | ... | ... |
| Price at [2-3 team sizes], billed [basis] | ... | ... | ... |
| [Deciding criterion] | ... | ... | ... |

[Restate the decisive differences in prose beneath the table, each option named.]

## Which Is Right for You?

**Choose [Tool A] if:** [criteria]
**Choose [Your Product] if:** [criteria]

## [CTA heading]
[Sources block]
[Footer]
```

---

## Format 3: You vs [Competitor]

**URL**: `/vs/[competitor]` · **Budget**: 1,200–2,000 words; sections are a menu

```
# [Your Product] vs [Competitor]: [Key Difference in One Phrase]
[Trust line]

## TL;DR
[40-60 words. The core difference stated outright, both products named, one hard number,
 and who each wins for. Not "they take different approaches" — say which, and for whom.]

## At a Glance

| | [Your Product] | [Competitor] |
|--|---------------|--------------|
| Best for | ... | ... |
| Price at [A] / [B] / [C] seats, billed [basis] | ... | ... |
| Same sizes, billed [other basis], if its crossover differs | ... | ... |
| [Deciding criteria] | ... | ... |
| [At least two rows where [Competitor] wins or ties] | ... | ... |

[Two or three sentences restating the decisive rows in prose, both products named.]

## [Your Product] vs [Competitor] for [Segment]

<!-- Keyword H2, not "Detailed Comparison"; below it, 3-4 question H3s,
     one per deciding criterion, worded the way buyers ask. -->

### [e.g., "Which costs less for a team that needs [feature]?"]
[Answer first with the price slot's sentence (where each side costs less), then the arithmetic.]

### [Deciding criterion 2, as the buyer asks it]
[Answer first — the concrete difference. Then why it matters.]

## Who [Your Product] Is Best For
[A liftable verdict first ("[Your Product] is the better choice for [segment] because [reason]"),
 then the bullets.]

## Who [Competitor] Is Best For
[Same shape, just as honest.]

## Switching from [Competitor]?
[What transfers, how long it takes, support offered; link the switching page.]

> "[Real quote from someone who switched]" — [Name, role, company]

## [CTA heading]
[Sources block]
[Footer]
```

---

## Format 4: [A] vs [B] (Third-Party Comparison)

**URL**: `/compare/[a]-vs-[b]` · **Budget**: 1,000–1,800 words; sections are a menu

```
# [Competitor A] vs [Competitor B]: Which Is Better for [Segment]?   <!-- [Year] only if re-tested every year -->
[Trust line]
[Disclosure, first two sentences: "[Your Product]'s team publishes this comparison; we make a
 competing tool, covered at the end. We compared both on [criteria] in [month year]."]

## TL;DR
[40-60 words. Answer the question the title asks — which wins, for whom, on what number —
 then name the third option. A page that refuses to pick gets read and never quoted.]

## What Is [Competitor A]?
[Definition first: "[Competitor A] is [category] for [audience]; unlike [common confusion],
 it [key distinction]." Then who it's for and its strengths.]

## What Is [Competitor B]?
[Same shape]

## [Competitor A] vs [Competitor B] for [Use Case]

### [e.g., "Which is better for [primary use case]?"]
[Balanced comparison, verdict first]

### [e.g., "Which costs less for a [segment] team?"]
[The price slot's sentence, both products named]

## Comparison Table

| | [Competitor A] | [Competitor B] | [Your Product] (ours) |
|--|---------------|---------------|-----------------------|
| Best for | ... | ... | ... |
| Price at [2-3 team sizes], billed [basis] | ... | ... | ... |

[Prose restatement of the decisive rows, all three named.]

## Which Should You Choose?

**Choose [A] if:** [criteria]
**Choose [B] if:** [criteria]

## Where [Your Product] Fits
[The segment it serves better than both, and one it doesn't. Don't oversell.]

## [CTA heading]
[Sources block]
[Footer]
```

---

## Format 5: Switching from [Competitor] (Migration Guide)

**URL**: `/switch/[competitor]` or `/migrate/[competitor]` · **Budget**: 800–1,500 words; sections are a menu

```
# Switching from [Competitor] to [Your Product]
[Trust line]

## TL;DR
[40-60 words with the actual numbers: how long a typical switch takes, what transfers automatically,
 what doesn't, and the support you offer. Both products named — "Migrating from [Competitor] to
 [Your Product] takes [range] for a typical [size] team; [what] transfers automatically, [what] needs
 reconfiguration." It answers "is it hard to migrate off [Competitor]?"]

## Who Should Switch (and Who Shouldn't)
**Switch if you:** [criteria]
**Stay with [Competitor] if you:** [honest criteria]

## What Transfers
| Data / Setting | Transfers automatically | Needs manual setup |
|----------------|-------------------------|--------------------|
| [e.g., Projects] | Yes — via importer | — |
| [e.g., Integrations] | — | Reconnect after import |
| [e.g., Custom fields] | Partial | Map remaining fields |
| [What doesn't transfer at all] | No | [Workaround, or none] |

## Migration Steps
[In the order the importer runs them; each step names who does it (an admin, your team,
 each user) and how long it takes.]

**Estimated time:** [realistic range]
**Downtime:** [none / ~X min] — [rollback plan if something fails]

## Migration Support
[What you actually offer: importer, assisted migration, credit for contract overlap, docs links.]

> "[Real quote from a customer who migrated — time taken, what was hard]" — [Name, role, company]

## [CTA heading]
[Start the import, or book a migration call]
[Sources block]
[Footer]
```

Each What Transfers row is a comparative claim: source it from the competitor's current export docs and your importer's docs (a sources-block line, or a register row in a program), and re-check both on every refresh.

---

## Liftable Verdict Blocks

Every "Who it's for" block, roundup entry and recommendation slot opens with one sentence an engine can quote alone: "[Product] is the best fit for [segment] because [reason with a number]", or "[A] [does X] while [B] [does Y]; choose [A] when [use case], [B] when [use case]." Read each out of context: if it needs the paragraph above, or its subject is "we" or "it", rewrite it.

---

## Sources Block

Closes every page, above the footer, visible: one line per source, not per claim, at most about 12 lines. It shows buyers and counsel where each fact came from and when.

```
## Sources
Prices are list prices in [currency], checked [date].
- [Competitor] pricing and plans: [URL], checked [date]
- [Competitor] [feature or limit] documentation: [URL], checked [date]
- [Your Product] pricing: [URL], checked [date]
- Review themes: [N] 1-3★ reviews of [Competitor] on [site], [date window]
- [A source you didn't fetch]: [URL], checked [VERIFY: <the data's date>, <whose data>]
<!-- Kept in the draft file, stripped from the published page: an archive capture per price
     and plan-gate source ([source URL] → [capture URL or saved copy]) -->
```

---

## Claims Register

For a page program or scheduled refresh cycle (SKILL.md Stage 2); a single page needs only its sources block. One file per competitor, plus one for [Your Product] whose rows every page cites (defaults `biz/marketing/competitor-pages/claims/{competitor}.md` and `claims/{your-product}.md`; caller may redirect). Counsel reviews this file, then the rendered page (title, TL;DR, table, verdicts) for its net impression. Budget: one row per fact, no commentary.

```
# Claims Register: [Competitor]
Owner: [name] · Refresh by: [date] · Markets: [US, EU, …]

| # | Claim as written | Type | Source URL | Snapshot | Verified | Pages using it |
|---|------------------|------|------------|----------|----------|----------------|
| C1 | "[Competitor] includes SSO only on its Enterprise plan, priced by sales" | Plan gate | [their pricing page URL] | [capture URL or saved copy] | [YYYY-MM-DD] | vs-[competitor], alternatives-[competitor] |
```

Types: price, limit, plan gate, feature, integration, certification, export, performance, superlative, opinion, customer result, implied (its source: the rows that prove it, e.g. "C3 + C7").

**Snapshot:** the URL an archive capture returned when you verified (e.g., the Wayback Machine's Save Page Now) or a dated PDF or HTML copy saved beside the register; never a guessed archive URL. Once their page changes, the snapshot is your only proof of what it said; a row without one stays unverified, `[VERIFY]` in its Verified cell, and blocks every page using it. **Pages using it** holds page slugs, as in the output path.

---

## Markup

- `Article` (author, `datePublished`, `dateModified`) or `WebPage`, plus `BreadcrumbList`. `dateModified` matches the visible "Updated" date, which changes only on substantive updates.
- No `Product`, `Offer`, `SoftwareApplication`, `Review` or `AggregateRating` on vs, alternative, roundup or switching pages. Google's review-snippet guidelines bar ratings aggregated from other websites and reviews of a category or list of items, and product rich results support only single-product pages (checked 2026-10-08). An `Offer` on a competitor's plan also implies you sell it.
- Ratings never go in markup. Your own, where shown, is visible, dated text in the review site's required citation format, linked and sourced; a competitor's, only as SKILL.md Stage 2 allows.
- No `ItemList` (Google's list carousels don't cover software) or `FAQPage` (the FAQ/HowTo rule lives with search-visibility, if available).
- Every fact lives in visible HTML text; markup never states anything the page doesn't.
