# Competitor Page Templates

Copy structures and section templates for each competitor page format.

## Table of Contents

1. [Filling These Templates So They Get Cited](#filling-these-templates-so-they-get-cited)
2. [Format 1: [Competitor] Alternative (Singular)](#format-1-competitor-alternative-singular)
3. [Format 2: [Competitor] Alternatives / Best [Category] Tools (Roundup)](#format-2-competitor-alternatives--best-category-tools-roundup)
4. [Format 3: You vs [Competitor]](#format-3-you-vs-competitor)
5. [Format 4: [A] vs [B] (Third-Party Comparison)](#format-4-a-vs-b-third-party-comparison)
6. [Format 5: Switching from [Competitor] (Migration Guide)](#format-5-switching-from-competitor-migration-guide)
7. [Section Copy Patterns](#section-copy-patterns)
8. [Meta Tags Template](#meta-tags-template)
9. [Schema Templates](#schema-templates)

> **Placeholders:** Fill every bracketed placeholder before publishing. `[Year]` = the current year (2026) — year-stamped titles only help time-sensitive roundup / "which is better" listicles, and they decay, so re-stamp the year **and** refresh the underlying content each January, or omit the year if you can't commit to refreshing. Mark data you don't have yet with `[TODO: ...]` (see `content-architecture.md` → Handling Incomplete Data).

---

## Filling These Templates So They Get Cited

A filled-in skeleton ranks; a filled-in skeleton **built from liftable blocks** also gets quoted in AI answers. The difference is entirely in how you write the slots, so apply these five rules to every template below. Rationale and evidence: `content-architecture.md` → Writing for AI Answer Engines.

1. **The TL;DR is the answer, not a trailer.** 40-60 words. Name both products. Carry at least one hard number. If a reader could stop there and act, it is right.
2. **Every bracketed heading becomes a question a buyer asks.** `[Category 1: e.g., Features]` is a slot, not a heading — ship "Which handles [job] better?", not "Detailed Comparison". First sentence under it is the answer.
3. **Claim sentences name products; connective prose can use "we".** "[Your Product] imports [Competitor] projects in one step" survives being lifted; "we import everything automatically" does not.
4. **Every comparison slot takes a number and a source.** A worked total for a named team size, a migration time range, a plan price with a link to the competitor's own pricing page. Adjectives are not comparisons.
5. **Restate the decisive table rows in prose.** Two or three sentences under each table, products named.

---

## Format 1: [Competitor] Alternative (Singular)

**URL**: `/alternatives/[competitor]`
**Intent**: User actively looking to switch from a specific competitor.

### Page Template

```
# Looking for a [Competitor] Alternative?

## TL;DR
[40-60 words. Both products named, at least one hard number, verdict stated outright.
 Shape: "[Your Product] is [positioning]. Teams leave [Competitor] mainly for [specific reason].
 [Your Product] costs $X/mo for a [N]-person team vs [Competitor]'s $Y, and migration takes [range].
 Best for [persona]; [Competitor] remains the better fit for [honest case]."]

## Why People Look for [Competitor] Alternatives
[Validate their pain — don't attack the competitor, empathize with the user]

Common reasons:
- [Pain point 1 — from review mining, stated concretely enough to be quoted]
- [Pain point 2]
- [Pain point 3]

## [Your Product] as a [Competitor] Alternative

### [Question-shaped: e.g., "How does [Your Product]'s pricing compare to [Competitor]'s?"]
[Answer first — the difference and the number. Then why it matters. Name both products in the answer sentence.]

### [Question-shaped: e.g., "Which works better for a team under [N] people?"]
[Answer-first paragraph comparison]

### [Question-shaped differentiator 3]
[Answer-first paragraph comparison]

## Feature Comparison

| Feature | [Your Product] | [Competitor] |
|---------|---------------|--------------|
| [Feature A] | [How you do it] | [How they do it] |
| [Feature B] | ... | ... |
| Pricing starts at | $X/mo | $Y/mo |

[Restate the 2-3 decisive rows in prose, products named — some engines parse tables poorly:
 "[Your Product] includes [Feature A] on every plan; [Competitor] gates it behind [tier] at $Y/seat."]

## Pricing Comparison

[Tier-by-tier breakdown. Include hidden costs, per-seat pricing, what's included. Link [Competitor]'s own pricing page as the source.]

**Sample cost for a 10-person team:**
- [Your Product]: $X/mo
- [Competitor]: $Y/mo

[State the total as a sentence too — this is the most-quoted fact on the page:
 "A 10-person team pays $X/mo on [Your Product] versus $Y/mo on [Competitor], a difference of $Z per year."]

## Who Should Switch (and Who Shouldn't)

**Switch if you:**
- [Criteria 1]
- [Criteria 2]

**Stay with [Competitor] if you:**
- [Honest criteria — builds trust]

## How to Switch

[Step-by-step migration path]
1. [What transfers automatically]
2. [What needs manual setup]
3. [Support offered]

> "[Quote from customer who switched]" — [Name], [Company]

## Ready to Try [Your Product]?

[CTA — free trial, demo, or migration help]
```

---

## Format 2: [Competitor] Alternatives / Best [Category] Tools (Roundup)

**URL**: `/alternatives/[competitor]-alternatives` (competitor-anchored) or `/best/[category]-tools` (category-anchored)
**Intent**: User researching options, earlier in journey.
**Note**: This one template covers both roundup variants — a competitor-anchored "[N] Best [Competitor] Alternatives" and a category-anchored "Best [Category] Tools". Swap the H1 and the "Why look for…" framing accordingly; the section skeleton is the same.

### Page Template

```
# [N] Best [Competitor] Alternatives in [Year]   <!-- [Year]: re-stamp + refresh content each January, or omit if you can't commit to refreshing -->

## TL;DR
[40-60 words naming the top 3 options and who each wins for, with one price or limit.
 This is the block an AI answer to "best [Competitor] alternatives" lifts wholesale — make it the answer.]

## Why Look for [Competitor] Alternatives?

[Common pain points validated by reviews — specific enough to quote]

## What to Look for in a [Competitor] Alternative

Before evaluating, consider:
1. [Criterion 1 — e.g., pricing model]
2. [Criterion 2 — e.g., team size fit]
3. [Criterion 3 — e.g., specific feature needs]

## The Best [Competitor] Alternatives

### 1. [Your Product] — Best for [use case]
[Open with a self-contained verdict sentence, product named:
 "[Your Product] is the best [Competitor] alternative for [persona] because [concrete reason, with a number]."
 Then 2-3 paragraphs: what it does, how it compares, who it's for.]
- **Pricing**: Starting at $X/mo
- **Best for**: [Persona]
- **Key differentiator**: [What makes you unique]

### 2. [Alternative B] — Best for [use case]
[Same shape: verdict sentence first, then an honest, helpful description]
- **Pricing**: ...
- **Best for**: ...

### 3. [Alternative C] — Best for [use case]
[Continue for 4-7 real alternatives]

## Quick Comparison

| | [You] | [Alt B] | [Alt C] | [Alt D] |
|--|-------|---------|---------|---------|
| Best for | ... | ... | ... | ... |
| Pricing | ... | ... | ... | ... |
| [Key Feature] | ... | ... | ... | ... |

[Restate the decisive differences in prose beneath the table, each option named.]

## Which Alternative Is Right for You?

**Choose [Your Product] if:** [criteria]
**Choose [Alt B] if:** [criteria]
**Choose [Alt C] if:** [criteria]

## Start Your Free Trial

[CTA]
```

**Important**: Include 4-7 real alternatives. Being genuinely helpful builds trust and ranks better.

**This is the highest-citation format.** A ranked list where each entry opens with a named, self-contained "best for X because Y" verdict is the exact shape of the answer an engine is assembling for "best [category]" prompts. The per-entry verdict sentence is what makes it liftable — a numbered list of paragraphs that bury the recommendation is a roundup that never gets quoted.

---

## Format 3: You vs [Competitor]

**URL**: `/vs/[competitor]`
**Intent**: User directly comparing you to a specific competitor.

### Page Template

```
# [Your Product] vs [Competitor]: [Key Difference in One Phrase]

## TL;DR
[40-60 words. The core difference stated outright, both products named, one hard number,
 and who each wins for. Not "they take different approaches" — say which, and for whom.]

## At a Glance

| | [Your Product] | [Competitor] |
|--|---------------|--------------|
| Best for | ... | ... |
| Pricing | ... | ... |
| Free plan | ... | ... |
| [Key Feature 1] | ... | ... |
| [Key Feature 2] | ... | ... |
| [Key Feature 3] | ... | ... |

[Two or three sentences restating the decisive rows in prose, both products named.]

## Detailed Comparison

<!-- Each H3 is a question a buyer asks, not a category label. Answer in the first sentence,
     then explain. These headings are what fan-out sub-queries match against. -->

### [e.g., "Which has the features a [persona] actually needs?"]
[Answer first — the concrete difference. Then why it matters. Don't just list.]

### [e.g., "Which costs less for a [N]-person team?"]
[Tier comparison, hidden costs, worked total as a sentence]

### [e.g., "Which is easier to get started with?"]
[UX comparison, learning curve, onboarding — with a time estimate if you have one]

### [e.g., "Which offers better support?"]
[Support channels, response times, documentation]

### [e.g., "Which integrates with [the tools this audience uses]?"]
[Ecosystem comparison]

## Who [Your Product] Is Best For
[One self-contained verdict sentence first — "[Your Product] is the better choice for [persona] because [reason]." — then the bullets.]
- [Persona/use case 1]
- [Persona/use case 2]

## Who [Competitor] Is Best For
[Same shape. Honest, and named: "[Competitor] is the better choice for [persona] because [reason]."]
- [Persona/use case 1 — be honest]
- [Persona/use case 2]

## What Customers Say

> "[Testimonial from someone who switched]" — [Name], [Role]

> "[Another testimonial]" — [Name], [Role]

## Switching from [Competitor]?
[Migration support, what transfers, how long it takes]

## Try [Your Product] Free
[CTA]
```

---

## Format 4: [A] vs [B] (Third-Party Comparison)

**URL**: `/compare/[a]-vs-[b]`
**Intent**: User comparing two competitors (not you directly).

### Page Template

```
# [Competitor A] vs [Competitor B]: Which Is Better in [Year]?   <!-- [Year]: re-stamp + refresh content each January, or omit if you can't commit to refreshing -->

## TL;DR
[40-60 words. Answer the question the title asks — which wins, for whom, on what number —
 then hint at the third option. A page that refuses to pick gets read and never quoted.]

## What Is [Competitor A]?
[Definition block: "[Competitor A] is [category] for [audience]. It [primary capability].
 Unlike [common confusion], it [key distinction]." Then who it's for and key strengths.]

## What Is [Competitor B]?
[Same definition-block shape]

## Head-to-Head Comparison

<!-- Question-shaped H3s, answer in the first sentence, both products named. -->

### [e.g., "Which is better for [primary use case]?"]
[Balanced comparison, verdict first]

### [e.g., "Which costs less at [N] seats?"]
[Balanced comparison, worked total]

### [e.g., "Which is easier to adopt?"]
[Balanced comparison, verdict first]

## Comparison Table

| | [Competitor A] | [Competitor B] | [Your Product] |
|--|---------------|---------------|---------------|
| Best for | ... | ... | ... |
| Pricing | ... | ... | ... |
| [Feature] | ... | ... | ... |

[Prose restatement of the decisive rows, all three named.]

## Which Should You Choose?

**Choose [A] if:** [criteria]
**Choose [B] if:** [criteria]

## Consider [Your Product] Too

[Brief positioning — why you're a relevant alternative. Don't oversell.]

## Try [Your Product] Free
[CTA]
```

---

## Format 5: Switching from [Competitor] (Migration Guide)

**URL**: `/migrate/[competitor]` or `/switch/[competitor]`
**Intent**: User has decided to switch and needs to know how — the highest-intent format. Best for technical products where migration effort is the main objection.

### Page Template

```
# Switching from [Competitor] to [Your Product]

## TL;DR
[40-60 words with the actual numbers: how long a typical switch takes, what transfers automatically,
 what doesn't, and the support you offer. Both products named — "Migrating from [Competitor] to
 [Your Product] takes [range] for a typical [size] team; [what] transfers automatically, [what] needs
 reconfiguration." This is the block that answers "is it hard to migrate off [Competitor]?"]

## Who Should Switch (and Who Shouldn't)
**Switch if you:** [criteria]
**Stay with [Competitor] if you:** [honest criteria — builds trust]

## What Transfers
| Data / Setting | Transfers automatically | Needs manual setup |
|----------------|-------------------------|--------------------|
| [e.g., Projects] | Yes — via importer | — |
| [e.g., Integrations] | — | Reconnect after import |
| [e.g., Custom fields] | Partial | Map remaining fields |

## Migration Steps
1. [Export from [Competitor] — where/how]
2. [Import into [Your Product] — tool, CLI, or assisted]
3. [Reconnect integrations / invite team]
4. [Verify and go live]

**Estimated time:** [realistic range]
**Downtime:** [none / ~X min] — [rollback plan if something fails]

## Migration Support
[White-glove onboarding, migration credits, dedicated support channel, docs links.]

> "[Quote from a customer who migrated — time saved, how smooth it was]" — [Name], [Company]

## Start Your Migration
[CTA — "Start migrating — we'll help" / book a migration call]
```

**Important**: A "transfers automatically" promise that breaks erodes trust fast — and it's a comparative claim subject to the same truthfulness bar as the rest of the page. Verify the "What Transfers" table against the competitor's *current* export options and date-stamp it (see `content-architecture.md` → Keeping Data Accurate).

---

## Section Copy Patterns

### TL;DR Formulas

- "[Your Product] is [positioning]. Unlike [Competitor], which [their approach], [Your Product] [your approach]. Best for [persona]."
- "The biggest difference: [Your Product] [key differentiator], while [Competitor] [their approach]. Choose [Competitor] for [use case], [Your Product] for [use case]."
- With a number (prefer this — the figure is what makes it quotable): "[Your Product] costs $X/mo for a [N]-person team versus [Competitor]'s $Y, and includes [feature] that [Competitor] gates behind [tier]. Best for [persona]; [Competitor] remains the better fit for [honest case]."

### Liftable Verdict Blocks

One self-contained sentence an engine can quote without any surrounding context. Use one per option in every "Who it's for" / roundup entry / recommendation slot — these are what AI answers reach for on "which should I use for X" prompts.

- **Recommendation:** "[Product] is the best fit for [specific persona] because [concrete reason with a number]. [Key distinction from the alternative]."
- **Comparison:** "[Product A] [does X] while [Product B] [does Y]. Choose [A] when [use case]; choose [B] when [use case]."
- **Definition (for third-party/overview sections):** "[Product] is [category] for [audience]. It [primary capability]. Unlike [common confusion], it [key distinction]."

Test each one by reading it alone, out of context. If it needs the paragraph above it to make sense, or if the subject is "we" or "it", rewrite it.

### Honest Weakness Patterns

Frame weaknesses as scope decisions, not failures — and name the products, because these sentences are unusually quotable and a first-person version lands in an AI answer with no idea who "we" is:

- "[Your Product] is deliberately narrow. If you need [feature], [Competitor] is the better choice."
- "[Competitor] has more [category] features; [Your Product] focuses on [your strength] instead."
- "For teams larger than [N], [Competitor]'s enterprise features are the better fit."

(First person is fine in the surrounding voice — "we built it this way because…". Keep it out of the claim sentence itself.)

### Social Proof Patterns

- Direct quotes from switchers, with name and role (most powerful — and quoted attribution is one of the strongest citability signals)
- "[N]% of [Your Product] customers previously used [Competitor]" — name the product rather than "our customers", so the stat survives being lifted
- Before/after metrics: "[Company] reduced [metric] by X% after switching from [Competitor] to [Your Product]"
- Third-party ratings and badges (G2, Capterra) alongside first-party quotes — independent validation is both more persuasive and the only compliant source for `aggregateRating`
- Named companies with logos (with permission)

### CTA Patterns

- "See why [N] teams switched from [Competitor]"
- "Try [Your Product] free — no credit card required"
- "Get a personalized demo comparing [Your Product] to [Competitor]"
- "Start migrating from [Competitor] today — we'll help"

---

## Meta Tags Template

```html
<!-- Alternative page -->
<title>[Competitor] Alternative — [Your Product] | [Benefit]</title>
<meta name="description" content="Looking for a [Competitor] alternative? [Your Product] offers [key benefit]. Compare features, pricing, and see why teams switch.">

<!-- Alternatives page ([Year]: re-stamp + refresh each January, or omit if you can't commit to refreshing) -->
<title>[N] Best [Competitor] Alternatives in [Year]</title>
<meta name="description" content="Compare the best [Competitor] alternatives including [Alt 1], [Alt 2], and [Your Product]. Features, pricing, and honest recommendations.">

<!-- Vs page -->
<title>[Your Product] vs [Competitor] — [Key Difference]</title>
<meta name="description" content="[Your Product] vs [Competitor] compared: features, pricing, and who each is best for. See the detailed breakdown.">

<!-- Third-party comparison ([Year]: re-stamp + refresh each January, or omit if you can't commit to refreshing) -->
<title>[A] vs [B] — Detailed Comparison [Year]</title>
<meta name="description" content="[A] vs [B] compared: features, pricing, pros and cons. Plus a third option you might not have considered.">
```

---

## Schema Templates

> **FAQ schema (updated May 2026):** Google fully deprecated FAQ rich results on May 7, 2026 — they no longer appear in Search for any site (the 2023 health/gov carve-out is gone; Rich Results Test support removed June 2026, Search Console API Aug 2026). FAQPage is still valid and Google still parses it to understand the page, so it's harmless to keep — but expect zero SERP rich result, and don't add it expecting an AI-citation lift either: a 602-prompt citation study found Q&A/FAQ pages carry no more answer-influence than non-Q&A pages. What earns citations is the *content* in the answers — comparisons, statistics, definitions — not the Q&A wrapper. Prefer Product + ItemList + Review schema below. (This is the canonical FAQ-schema caveat; `content-architecture.md` points here.)

### Product + Offer (per product compared)

> **Only include `aggregateRating` if the rating is genuinely displayed on the page AND comes from real reviews.** Don't self-rate your own product or paste placeholder numbers — fake or markup-only ratings risk a Google manual action that strips ALL your rich results, and self-controlled reviews on `Organization`/`LocalBusiness` types are outright ineligible for the star feature. The compliant source is independent third-party reviews you're licensed to display (e.g., aggregated G2/Capterra). For pure SaaS, `SoftwareApplication` (with `Offer`/`AggregateRating` nested) models the product more precisely than bare `Product` — to use it, swap `@type` in the example below and add `applicationCategory` + `operatingSystem`; the rest of the shape is identical. The `price` must match the price shown on the page.

```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "[Your Product]",
  "description": "...",
  "offers": {
    "@type": "Offer",
    "price": "[your price — also shown on the page]",
    "priceCurrency": "USD",
    "availability": "https://schema.org/InStock"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "[from real, on-page, third-party reviews]",
    "reviewCount": "[must match the count shown on the page]"
  }
}
```

### ItemList (ranked alternatives)

```json
{
  "@context": "https://schema.org",
  "@type": "ItemList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "[Your Product]", "url": "https://yoursite.com" },
    { "@type": "ListItem", "position": 2, "name": "[Competitor B]", "url": "https://competitor-b.com" }
  ]
}
```

### FAQPage (no SERP rich result since May 2026, and not a citation lever — see caveat above)

Add entries only where a real buyer sub-question needs answering, and put a number in every answer. The value is the answer text, which must also appear as visible on-page content — engines that read structured data read it alongside the visible HTML, and markup-only answers are both invisible to most retrieval and a policy problem.

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "What is the best alternative to [Competitor]?",
      "acceptedAnswer": { "@type": "Answer", "text": "[Balanced answer, products named, with a concrete number — mirrors the visible on-page answer verbatim]" }
    },
    {
      "@type": "Question",
      "name": "How long does it take to migrate from [Competitor] to [Your Product]?",
      "acceptedAnswer": { "@type": "Answer", "text": "[Realistic range, what transfers automatically, what needs reconfiguration]" }
    }
  ]
}
```
