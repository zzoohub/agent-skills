# Competitor Pages Content Architecture

Structure, data management, and search/AI-visibility approach for competitor comparison pages.

## Table of Contents

1. [Page Formats and URLs](#page-formats-and-urls)
2. [Centralized Competitor Data](#centralized-competitor-data)
3. [Research Process](#research-process)
4. [Handling Incomplete Data](#handling-incomplete-data)
5. [Keeping Data Accurate](#keeping-data-accurate)
6. [Writing for AI Answer Engines](#writing-for-ai-answer-engines)
7. [Classic SEO Structure](#classic-seo-structure)
8. [Prioritization and Scale](#prioritization-and-scale)
9. [Citability Checklist](#citability-checklist)
10. [Section Types](#section-types)

---

## Page Formats and URLs

| Format | URL Pattern | Target Keywords |
|--------|------------|-----------------|
| [Competitor] Alternative (singular) | `/alternatives/[competitor]` | "[Competitor] alternative" |
| [Competitor] Alternatives / Best [Category] Tools (roundup) | `/alternatives/[competitor]-alternatives`, `/best/[category]-tools` | "best [Competitor] alternatives", "best [category] tools" |
| You vs [Competitor] | `/vs/[competitor]` | "[You] vs [Competitor]" |
| [A] vs [B] (third-party) | `/compare/[a]-vs-[b]` | "[A] vs [B]" |
| Switching from [Competitor] (migration) | `/migrate/[competitor]` | "switch from [Competitor]", "migrate from [Competitor]" |

---

## Centralized Competitor Data

When researching, organize findings into this structure. Fill what you can from public sources and mark the rest for the user to provide:

```yaml
competitor:
  name: "[Competitor]"
  data_verified_on: "[YYYY-MM-DD]"   # Re-verify on a cadence — see "Keeping Data Accurate" below
  tagline: "[Their positioning — from their homepage]"
  target_audience: "[Who they serve — from their marketing]"
  pricing:                          # From their pricing page
    source_url: "[link to their pricing page]"
    verified_on: "[YYYY-MM-DD]"     # Pricing changes often — highest-risk field to keep current
    starter: "$X/mo"
    pro: "$Y/mo"
    enterprise: "Custom"
    hidden_costs: "[Per-seat fees, overage charges, add-ons]"
  strengths:                        # From reviews + their marketing
    - "[Strength 1]"
    - "[Strength 2]"
  weaknesses:                       # From review site complaint themes
    - "[Weakness 1]"
    - "[Weakness 2]"
  best_for: "[Ideal customer profile]"
  not_ideal_for: "[Anti-persona]"
  common_complaints:                # From G2/Capterra review themes
    - "[Recurring complaint 1]"
    - "[Recurring complaint 2]"
  migration_notes: "[TODO: Ask user — what transfers, what needs reconfiguration]"
```

---

## Research Process

When the user hasn't provided complete competitor data, research using publicly available sources. Focus on what you can actually verify.

### Research Steps

1. **Pricing page** — Web search for "[Competitor] pricing". Capture tier names, prices, what's included, per-seat vs flat pricing, free plan details.
2. **Feature/product page** — Web search for "[Competitor] features" or visit their marketing site. Document key capabilities and positioning.
3. **Review sites** — Search for "[Competitor] reviews G2" or "[Competitor] reviews Capterra". Look for recurring themes in praise and complaints — these become the "why people switch" section.
4. **Competitor's own comparison pages** — Search for "[Competitor] vs" or "[Competitor] alternatives". See how they position themselves and what they consider their strengths.
5. **Changelog / blog** — Search for "[Competitor] changelog" or "[Competitor] blog" for recent direction and feature launches.

### What to Ask the User For

Some things you can't research — ask the user directly:
- Their own product's differentiators and positioning
- Specific pricing if not public
- Customer testimonials or switch stories
- Migration details (what transfers, what doesn't, time estimates)
- Features the competitor lacks that they offer

---

## Handling Incomplete Data

Not every section can always be filled. Handle gaps in this priority order:

### Research it
If the data is publicly available (pricing, features, reviews), look it up. Don't ask the user for information you can find yourself.

### Ask the user
If the data is internal (testimonials, migration details, proprietary differentiators), ask. Be specific: "Do you have any quotes from customers who switched from [Competitor]?" is better than "Do you have testimonials?"

### Use TODO placeholders
If the user doesn't have the data yet, mark the section clearly so they can fill it later:

```
> [TODO: Add testimonial from a customer who switched from [Competitor]]

[TODO: Add migration time estimate — how long does a typical switch take?]
```

Place TODOs inline where the content should go, not in a separate list. This makes it obvious what's missing and where it belongs.

### Skip the section
If a section genuinely doesn't apply (e.g., no migration path because it's a different product category), omit it entirely rather than leaving an empty section.

---

## Keeping Data Accurate

Competitor pricing and features change constantly. A stale claim ("they charge $Y/seat", "they lack feature X") is both a conversion killer (savvy buyers catch it) and a real legal exposure — a now-false comparative claim about a named competitor is exactly what triggers Lanham Act §43(a) / FTC false-advertising risk (and state comparison-pricing statutes). Treat freshness as a discipline, not a one-time capture:

- **Date-stamp every volatile data point.** Use the `verified_on` / `source_url` fields in the competitor YAML above. Pricing and feature-presence claims are the highest-risk.
- **Re-verify on a cadence.** Review on any competitor pricing/packaging/positioning change, and at least quarterly in fast-moving categories. Update the on-page "verified as of [date]" line on each refresh.
- **Never embed undated screenshots** of competitor pricing/UI — caption any screenshot with its capture date and treat it as expiring on the same cadence.
- **Assign an owner.** Someone owns each competitor page's refresh, or the cadence won't happen.

Upside, not just risk: a visible, truthful "Last updated" date plus freshly re-verified data also strengthens content-freshness signals that both classic search and AI answer engines reward (recently-updated comparison pages earn a disproportionate share of AI citations). Only bump the displayed date on substantive updates, not cosmetic edits.

---

## Writing for AI Answer Engines

Comparison pages are among the formats generative engines cite most: a ranked list of options with per-option verdicts is the literal shape of a "best X for Y" answer, and a head-to-head table is the literal shape of an "is A or B better" answer. Extractability is worth more here than on almost any other page you own.

The economics reinforce it. On queries where an AI answer appears, being *cited inside it* is worth roughly twice the clicks of appearing but going uncited (Seer Interactive, Apr 2026; 53 brands, 5.47M queries — directional, single-source, re-verify). Citation is the objective; ranking is one road to it, not the destination.

Two mechanics drive every rule below.

**1. Retrieval is not citation.** Engines pull far more passages than they use and discard most during synthesis — one large analysis put ChatGPT's citation rate at roughly 15% of the pages it retrieved (AirOps, 548,534 pages — directional). Being indexed, even being retrieved, buys nothing on its own. You win by being the clean, *named* source of one specific claim.

**2. One prompt becomes many queries.** AI search decomposes a prompt into sub-questions and retrieves separately for each. In that same analysis ~90% of prompts triggered two or more fan-out queries, and about a third of cited pages surfaced only via a sub-query the user never typed. A page that answers only the head query loses to a page whose sections each answer one sub-question.

### Architect the page around fan-out sub-questions

Before drafting, list the sub-questions the buyer's prompt decomposes into, then give each one a heading and a self-contained answer. For "[Competitor] alternatives" that is usually:

| Sub-question | Section that answers it |
|---|---|
| Why do people leave [Competitor]? | Why People Look for Alternatives — review-mined, specific |
| What does [Competitor] actually cost at [N] seats? | Pricing Comparison, with a worked total |
| Which option is best for [persona]? | Who It's For — one verdict per option |
| What does [Competitor] do better? | Honest Acknowledgments |
| How hard is it to migrate, and how long? | Migration Path, with a time estimate |
| What are the real alternatives? | Comparison table + ranked list |

Derive the actual list from the competitor and audience at hand. Generic headings — "Overview", "Detailed Comparison", "Features" — answer no sub-question and retrieve poorly. Name the question.

### Size blocks for extraction

Converging 2025-2026 citation analyses point at a consistent shape (each single- or few-study — directional, re-verify):

- **40-60 words** per self-contained answer block, one claim each. This is the unit that gets lifted.
- **~120-180 words** per between-subhead section. One study across 216K pages found sections in that band averaged ~4.6 ChatGPT citations vs ~2.7 for sub-50-word sections.
- **150-300 words** per paragraph as a ceiling; chunks past ~300 words show marked mid-segment attention loss.
- **Structured formats extract more accurately than prose** (~43% in one six-engine test) — which is what earns the comparison table its place, subject to the restatement rule below.

### Put the answer in the top third

Position analysis of published pages puts roughly **44% of AI citations in the first 30% of a page**, ~31% in the middle, ~25% at the end (single-source, directional). The TL;DR is therefore not a courtesy for scanners — it is the highest-value block on the page. It must carry the verdict *and* at least one hard number, with both products named.

### Name entities; save pronouns for connective prose

Cited content runs far denser in named entities (brands, tools, people) than average writing — one analysis put cited pages near 20% named-entity density against a 5-8% English baseline (directional). A sentence lifted out of your page has to still say *who*:

- Weak: "We include SSO on our mid tier — they charge extra for it."
- Strong: "[Your Product] includes SSO on the $12/seat Team plan; [Competitor] sells SSO only as an Enterprise add-on."

This bites hardest in weakness and social-proof copy, which marketing instinct writes in first person ("we don't try to be everything"). Rewrite the claim sentences with product names; keep "we" for the surrounding voice.

### Write definitively, with the evidence attached

Non-hedged declaratives were cited materially more often than hedged prose in one large citation study (~36% vs ~20%, directional). But this is authority *with* evidence, not bare confidence — the three highest-leverage on-page moves in the peer-reviewed GEO work (Aggarwal et al., KDD 2024) are **citing sources, adding quotations, and adding statistics**, and citing external sources helped mid-ranked pages most. On a comparison page that means: link the competitor's own pricing or docs page as the source for each competitor claim (which defensibility requires anyway — see Keeping Data Accurate), quote real switchers with name and role, and give totals instead of adjectives.

### Restate table facts in prose

Tables extract well on some engines and poorly on others, so the two or three decisive rows must also exist as sentences. After the comparison table, write a short paragraph stating those same facts in prose with both products named. Three sentences of cost, and it covers the failure mode where an engine parses your table into nothing.

### What is *not* a citation lever

Two widely-repeated tactics do less than their reputation suggests, and over-investing in them displaces work that pays:

- **Schema markup is extraction infrastructure, not a citation multiplier.** A controlled test adding JSON-LD to ~1,885 pages against ~4,000 controls found Google AI Overviews **−4.6%**, AI Mode **+2.4%**, ChatGPT **+2.2%** — the positives indistinguishable from noise (Ahrefs, May 2026); the popular "pages with schema get cited ~3x more" correlation is confounded with site quality. Independent retrieval tests suggest the major engines read visible HTML and ignore JSON-LD at retrieval time. Schema still earns its keep for Google/Bing parsing accuracy, entity clarity, and the rich results that *do* still exist — ship it correctly, then stop optimizing it.
- **FAQ *format* alone does not lift citations.** A 602-prompt / 21,143-citation study found Q&A and FAQ pages had no higher answer-influence than non-Q&A pages. What did correlate was density of extractable **comparisons, statistics, definitions, and procedures** — comparisons alone carried roughly a +55% uplift. Q&A shape is a convenient container for those units, not a substitute for them. Add FAQ entries only where a real sub-question needs answering, and put a real number in each answer.

### The honest ceiling

A perfect comparison page cannot win the category alone. Across brand citations, earned media runs roughly half and third-party/commercial sites about a third, leaving own-domain content near a quarter — and for *review-style* queries, which is exactly what "alternative" and "vs" queries are, the earned share runs far higher (Omniscient Digital, ~23K citations — directional). Source pools also diverge by engine; B2B comparison answers lean heavily on G2, Capterra, and Reddit.

**So:** this page is the artifact you fully control and the one engines quote for concrete pricing, feature, and migration facts. Being listed and well-reviewed on the review sites your buyers use, and genuinely present in the relevant communities, is the larger half of the same job — route that, and cross-engine citation measurement, to the search-visibility capability and the marketer role, if available.

---

## Classic SEO Structure

Ranking still matters, and not as a competing discipline: Google's AI answers correlate strongly with what ranks, so classic SEO remains one of the main roads into AI citation.

### Content Length and Chunk Architecture
Cover the comparison thoroughly enough to answer the searcher's full question *and* its fan-out sub-questions. Pages that rank tend to run **~1,500–3,000 words** because they cover pricing, features, use cases, and migration in depth — not because length itself ranks (Google has confirmed word count is not a ranking factor). Match the depth of the pages currently ranking for your term; never pad to hit a count.

Total length is the weaker constraint. What the page is *made of* matters more: 2,000 words of discrete, question-headed, self-contained blocks beats 3,000 words of flowing prose on both surfaces. Size the blocks per **Size blocks for extraction** above and let the total fall out of the coverage.

### Heading Structure
- **H1**: Include the primary keyword naturally — e.g., "Best Notion Alternatives" or "Linear vs Jira"
- **H2s**: Use for major sections. Include secondary keywords where natural — "Pricing Comparison", "Feature Comparison", "Who Should Switch"
- **H3s**: Use for individual features or comparison dimensions — and for the fan-out sub-questions, phrased as the question ("How long does migrating from [Competitor] take?")
- Keyword-shaped H2s and question-shaped H3s are complements, not a conflict: the H2 serves the typed query, the H3 serves the conversational one. Either way, the first sentence under a heading must be the answer, never a wind-up.
- Don't skip heading levels (H1 → H3) — clean hierarchy mainly helps accessibility (screen-reader navigation) and scannability; it's at most a minor ranking signal, so do it for users.

### Keyword Placement
- Primary keyword in: H1, first paragraph, meta title, meta description, URL slug
- Secondary keywords in: H2s, image alt text, comparison table headers
- Don't force keywords — if it reads awkwardly, rephrase. Search engines are smart enough to understand synonyms.

### Internal Linking
- Link between related competitor pages (e.g., "vs" page links to "alternative" page for the same competitor)
- Link from feature pages to relevant comparisons
- Create a hub page (`/alternatives/` or `/compare/`) linking to all competitor content
- Link from blog posts that mention competitors to the comparison page

### Schema Markup

Ship schema for parsing accuracy and for the rich results that still exist — but calibrate first: it is not a citation lever (see **What is *not* a citation lever** above). Get it correct, keep it consistent with the visible page, and move on.

> **FAQ schema:** FAQ rich results were fully deprecated by Google on May 7, 2026 — they no longer appear in Search for any site (the 2023 health/gov carve-out is gone). FAQPage remains valid and Google still parses it to understand the page, so it is harmless to keep — but expect zero SERP rich result, and do not add it expecting an AI-citation lift. See `templates.md` → Schema Templates for the canonical caveat and JSON-LD.

Higher-value schema for comparison pages:
- **`Product`** + **`Offer`** (or **`SoftwareApplication`** for SaaS) on each product compared — makes pricing machine-readable and may aid AI-search eligibility. Note: Google AI Overview/AI Mode shopping cards and Perplexity Shopping are driven mainly by Merchant Center feeds + GTIN, so pure SaaS pages usually won't appear as shopping cards — treat this as machine-readability/AEO, not a guaranteed shopping placement.
- **`ItemList`** for the ranked alternatives list
- **`Review`** / **`AggregateRating`** only with genuine, on-page, third-party reviews — never self-controlled or markup-only ratings (manual-action risk; see the warning in `templates.md`)
- **`Article`** / **`BreadcrumbList`** + **`dateModified`** for SEO hygiene and freshness

Keep markup consistent with what the page displays. Engines that read structured data at all read the visible HTML alongside it, so a price in JSON-LD that contradicts the price in your comparison table is worse than no markup at all — and on `Offer`/`AggregateRating` it is a policy violation, not just a mismatch.

See `templates.md` for JSON-LD examples.

---

## Prioritization and Scale

### Priority Order

Rank the backlog on intent and citation opportunity, not raw search volume — most competitor terms are low-volume and high-converting, and volume is a weaker proxy still on the AI surface, where no volume metric exists:

1. **Competitors your buyers actually evaluate you against** — from sales-call notes, churn interviews, and "what were you using before?" answers. This beats any keyword tool.
2. **Competitors that already appear in AI answers for your category.** Run your top prompts through the assistants your buyers use and record who gets named. A competitor the engines already cite is a page with a live audience; one they never mention is a page nobody finds.
3. **Direct competitors before indirect.**
4. **Then split by goal, not by rank.** Singular Alternative and Switching-from pages serve conversion (narrowest audience, highest intent); roundup / "Best [Category]" pages serve AI visibility (the most-cited shape). Ship one of each early rather than exhausting one format first.

### Scaling Without Thin Content
The most common real-world use is generating one page per competitor at scale — and the dominant failure mode is templated, near-duplicate alternative/vs pages getting demoted or deindexed as thin/doorway content under Google's scaled-content-abuse policy.

The AI surface punishes the same pages more quietly. Templated clones still get *retrieved* — they are topically relevant — and then get dropped during synthesis in favor of a page carrying the actual numbers, because most retrieved pages are discarded and near-identical passages give an engine no reason to pick yours. You see no penalty, no ranking drop, and no citations. If you produce many pages:

- Each needs substantial unique, non-templatable content — genuine review-mined pain points, real migration specifics, distinct use-case fit, a real worked cost example. Don't ship name-swapped clones; the majority of each page should be unique.
- Prioritize the highest-fit competitors (per Priority Order above) over blanket coverage. Ten pages carrying real data beat fifty carrying a filled-in skeleton.
- The format playbook lives here; the site-wide ranking and citation-measurement mechanics belong to the search-visibility capability, if available.

---

## Citability Checklist

Run this after drafting, alongside the honesty/specificity/completeness pass. Every "no" is a place an engine will pass you over for a competitor's page.

- [ ] Does the TL;DR state the verdict outright, name both products, and carry at least one hard number?
- [ ] Is the verdict — plus the headline figures — inside the first third of the page?
- [ ] Does each major section answer one identifiable buyer sub-question, with the answer in the first sentence?
- [ ] Does every claim sentence you'd want quoted name the products, rather than saying "we"/"they"/"it"?
- [ ] Can each key paragraph be read alone and still make sense — no "as shown above", no "this is why"?
- [ ] Is there a "best for [persona] because [reason]" verdict for each option compared?
- [ ] Are the decisive comparison-table rows also restated in prose?
- [ ] Does every competitor claim link to that competitor's own public source page?
- [ ] Are there real numbers — worked totals, seat counts, migration hours — rather than adjectives?
- [ ] Are claims stated as definitive declaratives with the evidence attached, rather than hedged?
- [ ] Are author, last-updated date, and "competitor data verified as of" visible on the page?
- [ ] Does every content image carry descriptive `alt` text? Retrieval is text-based; a fact carried only by a screenshot is invisible.

---

## Section Types

Go beyond feature tables — use varied section types:

### TL;DR Summary
Start every page with a summary that *is* the answer, not a preview of it — it serves scanners and it is the single most-cited block on the page. Name both products, state the verdict, carry a hard number. 40-60 words.

### Paragraph Comparisons
For each dimension, write a paragraph explaining differences and when each matters. Open with the difference, then explain why it matters — never the reverse.

### Feature Comparison Table
| Feature | You | Competitor |
|---------|-----|-----------|
| Feature A | How you handle it | How they handle it |

Follow the table with a short prose restatement of the two or three decisive rows, products named.

### Pricing Comparison
Include tier-by-tier comparison, what's included, hidden costs, total cost for sample team. The worked total for a named team size is the most quotable fact on the page — state it as a sentence, not only as a table cell.

### Who It's For
Be explicit about the ideal customer for each option. Honest recommendations build trust — and this is the block AI answers reach for on "which should I use for X" prompts, so write one self-contained verdict per option: "[Product] is the better fit for [persona] because [concrete reason]."

### Migration Section
What transfers, what needs reconfiguration, support offered, quotes from switchers.

### Social Proof
Testimonials specifically from customers who switched from that competitor. Pair first-party switch quotes with third-party validation — embedded G2/Capterra ratings, badges, or awards are more persuasive than self-claims and are the only compliant source for `aggregateRating` schema (see `templates.md`). Distinguish self-claims (your differentiator copy) from independent proof, and lead trust-sensitive buyers with the latter.

### Decision-Stage CRO
These are the highest-intent BOFU pages in the funnel, so conversion treatment matters more than a single "CTA" line suggests:
- Place objection-handling and a risk-reversal block (free trial, no credit card, easy cancellation, security/compliance badges) adjacent to the comparison table.
- Repeat the primary CTA after the table and at section breaks; on long pages use a sticky compare/CTA bar.
- Route the CTA by segment — trial-led for SMB/developer, demo-led for enterprise (ties back to the SKILL's Tone Calibration).
- Put social proof near the CTA. Defer experiment mechanics to a conversion-optimization capability, if available; the comparison-page-specific placement lives here.
