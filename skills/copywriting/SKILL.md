---
name: copywriting
description: |
  Hub for marketing and product copy: landing pages, headlines, CTAs, UX
  microcopy, brand voice, push notifications; single source of truth for
  persuasion frameworks (PAS, AIDA, BAB, 4Ps, SSS). Also email (welcome,
  onboarding, nurture, win-back, cold sequences, drips, newsletters, subject
  lines, deliverability, SPF/DKIM/DMARC), organic social (LinkedIn, X,
  Instagram, TikTok, YouTube posts, threads, content calendars, pillars,
  repurposing, build in public, Product Hunt / Hacker News / Reddit launch
  posts), and persuasion psychology (mental models, cognitive biases,
  anchoring, scarcity, loss aversion, ethical persuasion vs dark patterns).
  Use when writing or improving any of these, picking a persuasion principle,
  or optimizing copy for conversion.
  Do NOT use for: ad copy (use ad-creative), dunning emails and cancel flows
  (use churn-prevention), SEO (use search-visibility), page/flow CRO and
  popups (use cro), pricing tiers (use pricing), analytics (use
  product-analytics), technical/API docs, or code comments.
---

# Copywriting & Content Strategy Guide

Guidelines for creating high-converting digital product copy, UX microcopy, brand messaging, and user-facing text. Apply these principles and processes whenever writing or reviewing marketing copy, onboarding text, CTAs, push notifications, or landing pages.

This skill is also the hub for written marketing: email, organic social, and persuasion psychology each have their own guide under `references/` (see the table below). Load the guide for the channel before writing for it; the core principles, process, and quality checklist here still apply.

## References

| File | When to Use |
|------|------------|
| `references/persuasion-frameworks.md` | Choosing and applying PAS / AIDA / BAB / 4Ps / SSS + psychological triggers (single source of truth — templated by ad-creative and the social reference; cross-referenced by the email and psychology references) |
| `references/copy-frameworks.md` | Writing new pages, restructuring copy, CTA optimization |
| `references/editing-sweeps.md` | Reviewing/editing existing copy, quality improvement |
| `references/plain-english.md` | Simplifying language, removing jargon, tone checks |
| `references/transitions.md` | Improving flow, connecting sections, long-form content |
| `references/email/guide.md` | **Email** — sequences (welcome, nurture, onboarding, re-engagement, win-back), newsletters, cold outreach, subject lines, measurement (never judge on opens), output format. Routes to `references/email/` `sequence-templates.md` (flows, branching), `copy-guidelines.md` (subject/preview, A/B design), `email-types.md` (catalog), `cold-outreach.md` (cold law + copy), `deliverability.md` (SPF/DKIM/DMARC, bulk-sender rules, consent, suppression) |
| `references/social/guide.md` | **Social** — posts, threads, carousels, scripts, content pillars and calendars, repurposing, build in public, HN / Product Hunt / Reddit launch posts. Routes to `references/social/` `platforms.md` (per-platform mechanics, launch-platform rules incl. the vote-solicitation ban), `post-templates.md` (hooks, templates), `reverse-engineering.md` (why content spreads), `topic-clusters.md` (pillars, calendars, waterfall), `metrics-benchmarks.md` (benchmarks, denominators) |
| `references/psychology/guide.md` | **Persuasion psychology** — diagnose the barrier, pick 2-3 principles, ethical guardrails. Routes to `references/psychology/mental-models-reference.md` (~70 mental models, pricing psychology, the Dark Pattern Anti-Catalog with regulatory hooks) |

## Task Routing

Match the task to the right workflow:

| Task | Approach | Reference |
|------|----------|-----------|
| **Choose/apply a persuasion framework** (diagnose audience awareness) | Match awareness state → pick PAS / AIDA / BAB / 4Ps / SSS → apply structure | `references/persuasion-frameworks.md` |
| **Write new page** (landing, homepage, pricing, feature) | Gather context → Pick persuasion framework → Structure the page → Write sections → Apply 8 Principles | `references/copy-frameworks.md` |
| **Write headlines & CTAs** | Generate 3+ variations → Apply Principles 1-4 → Pick strongest | `references/copy-frameworks.md` (CTA section) |
| **Edit/improve existing copy** | Run Seven Sweeps in order → Fix issues per sweep → Re-check | `references/editing-sweeps.md` |
| **Write UX microcopy** (tooltips, errors, empty states, buttons) | Clarity over cleverness → Anticipate questions → Progressive disclosure | UX Standards below |
| **Develop brand voice** | Define traits → Set tone spectrum → Create do's/don'ts | Brand Voice section below |
| **Write long-form content** (blog, narrative, long-form email body — flow only) | Build narrative arc → Use transitions → Maintain scannable flow | `references/transitions.md` |
| **Simplify/clarify copy** | Cut jargon → Use plain alternatives → Read aloud test | `references/plain-english.md` |
| **Email sequence or campaign** (welcome, onboarding, nurture, re-engagement, win-back, newsletter) | Assess → One email, one job → Branch on behavior → Sequence Overview + Per-Email output | `references/email/guide.md` |
| **Cold email / outreach** | Check the law per region → Peer voice, 50-100 words → Interest CTA → Separate warmed domain | `references/email/cold-outreach.md` |
| **Deliverability / sender compliance** | Authentication → One-click unsubscribe → Complaint-rate caps → Consent + suppression | `references/email/deliverability.md` |
| **Social post, thread, carousel, script** | Pick 2-3 platforms → Hook first → Platform-native format → Specific closing question | `references/social/guide.md` |
| **Content calendar / pillars / repurposing** | 3-5 pillars → Hub-and-waterfall → Batch weekly → Measure on one denominator | `references/social/topic-clusters.md` |
| **Launch posts** (Hacker News, Product Hunt, Reddit) and **build in public** | Platform rules first → Announce, never solicit votes → Named reply owners in the early window | `references/social/platforms.md` + `references/social/guide.md` |
| **Choose a persuasion principle** / **judge persuasion vs dark pattern** | Diagnose the barrier from data → Pick 2-3 principles → Treat each as a test hypothesis → Run the dark-pattern test | `references/psychology/guide.md` |

Boundaries: dunning / payment-failure emails and cancel flows belong to the churn-prevention skill; ad copy to ad-creative; SEO on-page optimization to search-visibility; page/flow conversion design to cro.

## 8 Principles for High-Converting Copy

Apply these as a checklist for promotional copy — banners, CTAs, push and in-app messages, and other user-facing promotional text. Principles 3 and 5 come from consumer-app banner tests; on B2B landing pages and long-form copy, treat them as test ideas rather than rules.

### Principle 1: One Message Only

Do not list every benefit in a single line. Give the user exactly one reason to click right now. Save the rest for after the click.

- Bad: "Check your spending type, share with your partner, and win up to $5"
- Good: "Take the 10-question test and see your result"

Why: When benefits pile up, the sentence becomes complex and the message blurs. A single focused action reads as one concept, even if it contains multiple words.

### Principle 2: Certainty Beats Maximum Reward

Users respond more to small guaranteed rewards than large uncertain ones. "You'll definitely get X" consistently outperforms "Up to Y".

- Bad: "Get up to $100 in random points"
- Good: "Get $1 to $100 — guaranteed"

Why: "Up to" feels like a gamble. Certainty removes hesitation. Even a tiny confirmed reward triggers action.

### Principle 3: Novelty Is Enough

Simply telling users something is new can outperform detailed benefit explanations. This is an anecdotal finding from a consumer fintech's (Toss) in-app banner tests, with no public data on the size of the effect — treat it as a test idea, not a universal constant.

- Bad: "Save up to 10% at convenience stores with this membership"
- Good: "There's a new convenience store benefit for you"

Why: Novelty triggers curiosity. The explanation can happen after the click.

### Principle 4: Specify the Concrete Action

Tell users exactly what they need to do and how much effort it takes. Remove the "how much will this take?" hesitation.

- Bad: "Fill in the blanks and get points"
- Good: "Fill 8 boxes and get points"
- Also good: "Just tap the button", "Takes 10 seconds"

Why: Specific numbers, time estimates, and familiar everyday actions eliminate the moment of pause before clicking.

### Principle 5: Power of Aggregation

Words like "list," "browse all," and "see everything in one place" consistently perform well. They signal completeness and reduce the user's fear of missing out.

- Example: "See the full list of loans you qualify for" sustained high CTR over time.

Why: Aggregation language promises comprehensive, organized information — users trust they won't need to look elsewhere.

### Principle 6: Write So It Reads as One Message

Even if copy contains multiple elements, it must feel like a single cohesive thought — not fragmented bullet points crammed into a sentence.

- Bad: "Test your spending, share with partner, check compatibility, win prizes"
- Good: "Take the spending compatibility test with your partner"

Why: The human brain processes one concept at a time. If the reader has to parse multiple ideas, they skip it.

### Principle 7: Write for the Skimmer (Eyeball Monkey Bars)

Most internet readers scan rather than read top-to-bottom. Make copy effortless to navigate — short paragraphs, bullet brigades, snappy sentences, and disproportionate time spent on the hook. See `references/transitions.md` → Scannable Flow for the full guidance, the NN/g source, and rules of thumb.

Why: Long copy still works — but only when every paragraph earns its place. People visit your site to find info, not to read prose. Make the finding effortless.

### Principle 8: Specificity Over Kitchen-Sink Promises

Solve one acute, pressing problem — not a vague, catch-all solution. Tailored solutions beat generic bundles every time.

- Bad: "The all-in-one solution for your business"
- Good: "Fix your checkout abandonment rate in 3 steps"

Why: Audiences are more savvy than ever. Algorithms serve hyper-personalized ads, so vague messaging feels outdated. Speak directly to one pain point and deliver a focused solution. Personalized beats generic.

## Voice & Authenticity

For detailed voice guidelines (plain English alternatives, jargon elimination, conversational tone, the "EveryPerson" factor), consult `references/plain-english.md`.

Core rule: Write like a real person talking to another real person. Proof everything. Have an opinion.

## Process

### 1. Context Gathering

Ask briefly for missing context, but don't block on it. If the user provides minimal info, state your assumptions and proceed.

**Ask for:**
- Target audience and desired action
- Constraints (character limits, tone, platform)
- Brand voice guidelines if they exist

**Defaults when not provided:**
- Audience: infer from the product/context described
- Tone: professional but friendly
- Goal: conversion (clicks, signups) unless clearly informational
- Constraints: standard web copy lengths

State assumptions at the top of your output so the user can correct them.

### 2. Brand Voice Development

When creating or refining brand voice guidelines, deliver:
- **Personality traits**: 3-5 adjectives that define the brand character (e.g., friendly, confident, straightforward)
- **Tone spectrum**: How voice shifts across contexts (celebration vs error vs onboarding)
- **Do's and Don'ts**: Specific examples of language that fits vs doesn't
- **Vocabulary preferences**: Preferred terms and terms to avoid
- **Formatting standards**: Punctuation, capitalization, emoji usage rules

Output a reusable reference document that any team member can apply consistently. Its default home is the marketing strategy doc's Brand Voice section (`biz/marketing/strategy.md`, owned by the caller's marketing-strategy context; caller may redirect) — if no file-write capability is present, return it inline.

### 3. Writing Approach

- Lead with the user's action, not your product's features
- Use active voice and present tense
- Keep sentences short and scannable
- Apply all 8 Principles as a checklist on every draft
- Write 2-3 variations minimum for any key copy
- Use AI as a brainstorming partner for ideas and draft refinement, but always ensure the final voice feels unmistakably human

### 4. UX Microcopy Standards

- Clarity over cleverness — users should never be confused
- Anticipate user questions and address them proactively
- Use progressive disclosure to avoid overwhelming users
- Maintain consistent terminology throughout the experience
- Write error messages that help, not frustrate
- Frame negatives as positives ("You can do X" instead of "You can't do Y")

### 5. Output Format

For every copy deliverable, provide:

1. **The copy itself** — organized by section (headline, subheadline, body, CTA)
2. **Annotations** — brief notes on key choices and which principles apply
3. **2-3 alternatives** — for headlines and CTAs, always provide variations with rationale
4. **Assumptions stated** — if context was missing, list what you assumed

For page-level copy, follow the section structure in `references/copy-frameworks.md`.

**Drafts only.** Produce copy as drafts for the caller; never publish, ship, send, schedule, or post it anywhere (CMS, app store listing, live site, ESP, social account, launch platform) without the caller's explicit approval.

**Output paths.** Email deliverables default to `biz/marketing/content/email/` and social deliverables to `biz/marketing/content/social/` (caller may redirect the `biz/<area>/` root); with no file-write capability, return them inline. See the email and social guides.

**Persuade, never manipulate.** Never fabricate scarcity, urgency, reference prices, testimonials, quotes, or metrics; never pre-select a subscription, paid add-on, upgrade, or marketing consent; never ask anyone to upvote on Hacker News, Product Hunt, or Reddit. Test: if a tactic only works when the user doesn't notice it, it is a dark pattern — see `references/psychology/guide.md` and its anti-catalog.

### 6. Quality Checklist

Before delivering any copy, verify:
- [ ] Does it pass all 8 Principles? (for conversion/promotional copy — skip for neutral UX microcopy like errors and tooltips)
- [ ] Is there exactly one clear message?
- [ ] Is the desired action obvious?
- [ ] Does it align with brand voice?
- [ ] Is it appropriate for the target audience?
- [ ] Is it concise without losing meaning?
- [ ] Would this sound natural if spoken aloud?
- [ ] Is it accessible and inclusive (no jargon, slang, or in-group terms)?
- [ ] Is it scannable? Can a skimmer get the point in 3 seconds?
- [ ] Is every claim either backed by real proof/social validation, or softened to what's truthfully supportable? (Never fabricate proof.)
