---
name: competitor-pages
description: |
  Competitor comparison pages, alternative pages, and vs pages — built to rank in search, get cited in AI answers, and convert.
  Use when: creating "[Competitor] alternative" pages, "vs" comparison pages, competitor
  comparison tables, migration guides, or when user mentions "competitor page", "alternative page",
  "vs page", "comparison page", "switching from", "migrate from", "competitor alternative".
  Do NOT use for: general competitive analysis strategy (use marketer agent — this skill produces the published
  page artifact; competitive analysis is the internal strategy doc biz/marketing/competitors.md), pricing strategy
  or competitor-pricing analysis (use pricing skill — this skill only renders a pricing-comparison table from prices you already have),
  site-wide SEO/AEO/GEO strategy, keyword research, technical SEO, or cross-engine AI-citation measurement
  (use search-visibility skill — this skill bakes page-level GEO into the comparison page itself; search-visibility
  owns the site-wide, off-site, and measurement layers), or page conversion optimization (use cro skill).
---

# Competitor Comparison Pages

Create high-converting competitor comparison, alternative, and migration pages that capture high-intent demand — from typed search queries and from the AI answers buyers increasingly ask instead.

---

## Why Competitor Pages Matter

- **High-intent traffic** — Users searching "[X] alternative" are ready to switch
- **Bottom-of-funnel** — These visitors have the highest conversion potential
- **Intent over volume** — Competitor and "alternative" keywords convert because of buyer intent, not volume; some big competitors have meaningful volume, but many terms are low-volume and extremely high-converting. Prioritize by intent, not raw volume
- **The formats AI answers cite most** — "best [category]" roundups and "[A] vs [B]" comparisons sit at the top of the content types generative engines cite, because a comparison page's sections map directly onto the sub-questions AI search decomposes a query into. Write these pages to be **lifted**, not only ranked
- **Brand positioning** — Define how your product compares on your terms

**Set expectations honestly, though: this page is necessary, not sufficient.** "Alternative" and "vs" queries are review-style queries, and for those, generative engines draw the majority of brand citations from *earned and third-party* sources (G2, Capterra, Reddit, press, roundups) rather than the brand's own domain — own-site content is roughly a quarter of brand citations overall, and less on review-style queries (directional, methodology-dependent). This page is the slice you fully control and the one AI engines quote for concrete pricing/feature facts; it does not substitute for off-site presence. Route that workstream to the search-visibility capability (site-wide/off-site/measurement) and the marketer role (review-site and community presence), if available.

---

## Five Page Formats

| Format | Use When | Example | Template |
|--------|----------|---------|----------|
| **[Competitor] Alternative** (singular) | Single competitor, strong differentiator | "Notion Alternative" | Format 1 |
| **[Competitor] Alternatives / Best [Category] Tools** (roundup) | Multiple options; category leadership; earlier-stage research | "Best Project Management Tools" | Format 2 |
| **[You] vs [Competitor]** | Head-to-head, both well-known | "Linear vs Jira" | Format 3 |
| **[A] vs [B]** (third-party) | User comparing two others; you're the relevant third option | "Asana vs Monday" | Format 4 |
| **Switching from [Competitor]** (migration) | Migration-ready users, technical product | "Switching from Heroku" | Format 5 |

The formats do different jobs and you should not rank them on one axis. Formats 1 and 5 (singular Alternative, Switching-from) are the **conversion** plays — narrowest audience, highest intent. Format 2 (roundup / "Best [Category]") is the **visibility** play — it is the shape AI answers cite most often, because a ranked list of options with per-option verdicts is exactly what a "best X for Y" prompt is asking for. A portfolio usually wants both, not the highest-intent format alone.

---

## When to Use Which Reference

| Scenario | Reference |
|----------|-----------|
| Writing for AI answer engines (fan-out section architecture, liftable blocks, chunk sizing), classic SEO/heading/schema strategy, research process, competitor-data model, handling incomplete data, data-freshness discipline | `references/content-architecture.md` |
| Copy-paste page skeletons per format, liftable-block and section copy patterns, meta-tag templates, JSON-LD schema examples | `references/templates.md` |

---

## Workflow

When triggered, follow these steps in order:

### Step 1: Gather Context

Ask the user for the information you need. Don't start drafting until you understand the basics:

- **Your product**: Name, what it does, target audience
- **Competitor(s)**: Which competitor(s) to compare against
- **Key differentiators**: What makes the user's product better for their audience
- **Available data**: Do they have pricing details, feature lists, testimonials, migration docs?
- **Page format**: Which of the five formats fits (suggest one based on their description)

If the user already provided most of this in their prompt, confirm your understanding and ask only about gaps.

### Step 2: Research

Use web search to fill knowledge gaps — see `references/content-architecture.md` for the research process. Focus on publicly available information: pricing pages, feature lists, review sites, changelogs.

### Step 3: Select Format

Pick the right format from the Five Page Formats table above (each maps to a template in `references/templates.md`). If unclear, suggest the best fit and explain why.

### Step 4: Draft

Use the matching template from `references/templates.md`. Fill in everything you can from user input and research. Mark gaps with `[TODO: ...]` placeholders — see `references/content-architecture.md` for how to handle incomplete data.

Draft to be **liftable from the start** — self-contained verdicts, named entities, sourced numbers, section headings shaped as the sub-questions buyers actually ask. This is a drafting constraint, not a cleanup pass; retrofitting extractability onto finished marketing prose means rewriting it. See `references/content-architecture.md` → Writing for AI Answer Engines.

### Step 5: Review and Refine

After drafting, review for four things:
- **Honesty** — are competitor strengths acknowledged?
- **Specificity** — vague claims replaced with sourced data?
- **Completeness** — all sections filled or marked TODO?
- **Citability** — can each key claim stand alone if an AI answer lifts that one sentence? Are the verdict and the headline numbers inside the first third of the page? Is every comparative claim attached to a named product rather than "we"/"they"? (Full checklist: `references/content-architecture.md` → Citability Checklist.)

---

## Output Format

Produce the page in **markdown** by default. Include an HTML block at the top for meta tags (title, description). If the user specifies a different format (HTML, JSX, MDX), adapt accordingly.

When asked to save the draft (and a file-write capability is present), write it to the competitor-pages dir (default `biz/marketing/competitor-pages/{slug}.md`; caller may redirect the `biz/<area>/` root) — the published page itself lives wherever the project's site content lives.

---

## Tone Calibration

Match the tone to the target audience:

- **Enterprise / B2B**: Professional, data-driven, emphasize ROI, security, compliance, and scale. Avoid casual language. Use phrases like "designed for teams of 50+", "enterprise-grade".
- **SMB / Startup**: Direct, practical, emphasize speed, simplicity, and value. OK to be conversational. Use phrases like "get started in minutes", "no bloat".
- **Developer / Technical**: Precise, no fluff, emphasize APIs, extensibility, performance. Show code examples or CLI comparisons where relevant. Avoid marketing-speak.
- **Consumer / Creative**: Friendly, benefit-focused, emphasize experience and ease. Use screenshots or visual comparisons where possible.

If the audience isn't obvious, ask. The wrong tone undermines an otherwise good page.

---

## Core Principles

### Be Honest
Don't trash competitors. Acknowledge their strengths. Users can smell bias — balanced comparisons convert better than hit pieces.

### Lead with Your Unique Strengths
Don't organize around competitor weaknesses. Lead with what makes you different and better for your target user.

### Include Specific Comparisons
Features, pricing, use cases — be specific. Vague "we're better" claims don't convince anyone. Tables and data convert.

### Write Liftable Blocks
Generative engines retrieve *passages*, not pages, and then discard most of what they retrieve during synthesis — being findable is not being cited. Every claim that matters should survive being quoted alone:

- **Self-contained.** No "as shown above", no "this is why". A lifted sentence carries its own subject, number, and source.
- **Named entities, not pronouns, near every key claim.** "[Your Product] includes SSO on the $12/seat plan" — not "we include it on our mid tier". Pronouns are fine in connective prose; they are not fine in the sentence you want quoted.
- **Front-load the verdict and the numbers.** The opening third of the page carries a disproportionate share of AI citations, so the TL;DR must contain the actual answer and the headline figures — not a tease that pays off in section 6.
- **Definitive, evidenced statements.** Assertive declaratives outperform hedged prose ("may", "might", "could") — but confidence *with* the number or source attached, not bare confidence.
- **Comparisons, definitions, and figures are the highest-value units.** They are exactly what this page type produces natively; the job is formatting them so they extract cleanly.

Mechanics (block sizes, section architecture, evidence base): `references/content-architecture.md` → Writing for AI Answer Engines.

### Make Claims Defensible
Every comparative claim about a named competitor must be (1) true at publish time, (2) backed by a citable public source (link their pricing/docs page), (3) objective and verifiable rather than vague superiority, and (4) kept current. Comparative advertising is legally risky — a false or stale claim about a named competitor can create Lanham Act §43(a) and FTC exposure, not just lost trust. Date-stamp competitor data and re-verify it on a cadence (see `references/content-architecture.md`).

### Target Both Query Surfaces
The same page has to win two differently-shaped surfaces. Write for both.

**Typed search queries** (classic SEO — short, keyword-shaped):
- "[Competitor] alternative"
- "[Competitor] vs [Your Product]"
- "Best [category] tools"
- "Switch from [Competitor]"

**Conversational prompts and their fan-out sub-questions** (AEO/GEO — AI search decomposes one prompt into several sub-queries and retrieves a passage for each, so a page that only answers the head query loses to pages that answer the parts):
- "what should I use instead of [Competitor] for a [N]-person team"
- "is [Competitor] or [Your Product] better for [use case]"
- "how much does [Competitor] actually cost with [N] seats"
- "is it hard to migrate off [Competitor]"
- "why do people leave [Competitor]"

Give each sub-question its own heading and its own self-contained answer. Derive the list from the specific competitor and audience — the examples above are shapes, not a checklist.

### Include Social Proof
Real migration stories, switch testimonials, and "I switched from X" quotes are the most powerful social proof on competitor pages. If the user doesn't have these yet, add `[TODO: Add testimonial from customer who switched from [Competitor]]` placeholders.

---

## Page Structure Overview

Head-to-head pages (singular Alternative, You vs [Competitor]) typically include these sections. Roundup (plural / "Best [Category]") and third-party ([A] vs [B]) pages use a different structure — see `references/templates.md` — and omit any section that doesn't apply:

1. **Trust header** — Author or "Reviewed by [role]", "Last updated: [date]", and "Competitor pricing/features verified as of [date]" (E-E-A-T + freshness; pair with `Article`/`dateModified` schema). Visible dates and named authors are also among the cheapest citability upgrades — undated pages lose to dated ones in AI answers
2. **Hero** — Clear headline addressing the search intent
3. **TL;DR / Verdict** — The single most important block on the page. State the answer, name both products, and carry at least one hard number (price, limit, time-to-migrate). This is what gets quoted; a teaser that defers the answer to section 6 wastes the highest-citation real estate on the page
4. **Quick Comparison Table** — Feature/pricing comparison at a glance. Restate the two or three decisive rows in prose immediately after the table — table cells extract cleanly for some engines and poorly for others, so carry the key facts in both forms
5. **Key Differentiators** — 3-5 areas where you win, with specifics. One question-shaped heading each, one self-contained answer each
6. **Honest Acknowledgments** — Where the competitor is strong. Balanced pages get cited by engines that are explicitly trying to synthesize a fair comparison; hit pieces read as promotional and get discarded
7. **Who It's For** — An explicit "best for [persona] because [reason]" verdict per option, each quotable on its own. This is the block AI answers reach for on "which should I use for X" prompts
8. **Social Proof** — Testimonials from switchers + third-party ratings/badges (or TODOs if unavailable)
9. **Migration Path** — How easy it is to switch, with a realistic time estimate
10. **CTA** — Clear next step (trial, demo, import). On long pages repeat it after the comparison table and at decision points, add risk-reversal near the table (free trial, no credit card, easy cancellation, security/compliance badges), and consider a sticky compare/CTA bar. Route by segment: trial-led for SMB/developer, demo-led for enterprise (see Tone Calibration)

---
