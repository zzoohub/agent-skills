# Email Copy Guidelines

Writing effective email copy — what makes email different from other copywriting, and how to use that.

---

## Table of Contents

1. [Why Email Copy Is Different](#why-email-copy-is-different)
2. [The Inbox Trifecta](#the-inbox-trifecta)
3. [Email Copy Structure](#email-copy-structure)
4. [Formatting for the Inbox](#formatting-for-the-inbox)
5. [Accessibility](#accessibility)
6. [Tone](#tone)
7. [Length by Type](#length-by-type)
8. [CTA Guidelines](#cta-guidelines)
9. [Personalization](#personalization)
10. [A/B Testing](#ab-testing)
11. [Common Mistakes](#common-mistakes)


## Why Email Copy Is Different

Email competes in a uniquely hostile environment. Your message sits in an inbox alongside 50+ unread emails, and the reader decides in about 2 seconds whether to open, skip, or delete. Three things are visible before the email is opened — the **from name**, **subject line**, and **preview text**. These three form a trifecta that must work together, because the best body copy in the world is worthless if nobody opens the email.

Once opened, the first line does the heaviest lifting. On mobile (where 60%+ of emails are read), only 3-4 lines are visible without scrolling. If those lines don't hook, the reader is gone. Email copy earns attention line by line in a way that blog posts and landing pages don't — there's no layout, no hero image, no navigation to orient the reader. It's just your words.

---

## The Inbox Trifecta

### From Name
- Use a real person's name for relationship emails ("Sarah from Acme")
- Use the brand name for transactional or newsletter ("Acme")
- Consistency matters — changing the from name confuses recipients and hurts open rates

### Subject Line
- 40-60 characters ideal (mobile truncates around 35-40)
- Clear > Clever. Specific > Vague.
- Benefit or curiosity-driven — give people a reason to open
- Test different hooks: question, how-to, number, direct, story tease

| Pattern | Example |
|---------|---------|
| Question | "Still struggling with X?" |
| How-to | "How to [outcome] in [timeframe]" |
| Number | "3 ways to [benefit]" |
| Direct | "[First name], your [thing] is ready" |
| Story tease | "The mistake I made with [topic]" |

### Preview Text
- 90-140 characters
- Complements the subject line — adds a second hook or completes the thought
- Never repeat the subject line
- If you leave it blank, email clients show the first line of the body — which is often "View in browser" or other junk. Always set it intentionally.

---

## Email Copy Structure

> For the underlying persuasion frameworks (PAS, AIDA, BAB, 4Ps, SSS) applied within these emails — e.g. PAS for a problem-aware nurture email — see the copywriting core, `references/persuasion-frameworks.md` (the single source of truth). This file covers email-specific structure only.

1. **Hook** — First line grabs attention. This is the most important line in the email because it's visible in the preview and it determines whether the reader keeps going. Lead with something relevant to them, not about you.
2. **Context** — Why this matters to them right now
3. **Value** — The useful content, insight, or offer
4. **CTA** — What to do next (one clear action)
5. **Sign-off** — Human, warm close

---

## Formatting for the Inbox

Email rendering is unpredictable — different clients strip styles, break layouts, and resize images differently. Write for the worst case:

- **Short paragraphs** (1-3 sentences) — walls of text are unreadable on mobile
- **White space between sections** — breathing room helps scanning
- **Bullet points for scanability** — but don't overuse them or the email feels like a list
- **Bold for emphasis** (sparingly) — one bolded phrase per section maximum
- **Left-aligned text** — centered text is harder to read beyond a headline
- **Single-column layout** — multi-column breaks on mobile
- **Dark mode consideration** — avoid images with transparent backgrounds on dark colors; text-based emails perform more consistently

---

## Accessibility

Many clients block images by default and some readers use screen readers — write for that worst case:

- **Meaningful alt text on every image** — it's the fallback that keeps the message readable when images don't load (and it helps spam filters and screen readers). Ties to the 60% text ratio in `references/email/deliverability.md`.
- **Descriptive link/button text** ("Start your free trial", not "click here") — reinforces the CTA guidance below.
- **Logical reading order** — content should make sense read linearly (the single-column rule already helps).
- **Sufficient color contrast** for body text and CTA buttons; **readable sizes** (~14px+ body, ~22px+ headings on mobile).
- **Don't rely on color alone** to convey meaning.

---

## Tone

- Conversational, not formal — read it out loud, and if it sounds like a corporate memo, rewrite it
- First-person (I/we) and second-person (you)
- Active voice
- Match the tone to the relationship stage: warmer and more personal in onboarding, more direct in re-engagement

---

## Length by Type

| Type | Length | Why |
|------|--------|-----|
| Transactional | 50-125 words | Functional — confirm and move on |
| Welcome/Onboarding | 100-200 words | Friendly but focused — guide to one action |
| Educational | 150-300 words | Enough to teach one thing well |
| Story-driven | 300-500 words | Narrative needs room, but earn every paragraph |
| Cold outreach | 50-100 words | Shorter = higher reply rate |

---

## CTA Guidelines

- **One primary CTA per email** — this is the most violated rule in email. When you add a second CTA, both perform worse because the reader has to choose.
- Buttons for primary actions, links for secondary
- Button text: Action + outcome ("Start your free trial", "Download the guide")
- Place the primary CTA after the value section, not buried at the bottom
- For long emails, repeat the CTA at the end

---

## Personalization

- Use first name sparingly (not in every email) — overuse feels robotic
- Behavior-based personalization is far more powerful than name insertion: "I noticed you set up your first project" beats "Hi [First name]"
- Reference their specific actions or segments
- Dynamic content blocks for different audiences (e.g., show different case studies by industry)
- **Validate every merge token before send** and set a graceful fallback for missing fields — default to a neutral greeting rather than rendering "Hi {FirstName}," or an empty token. Broken merge data destroys trust instantly.
- When generating per-recipient variations at scale, ensure **genuine variation** in body content — near-identical mass sends look like bulk/spam to filters regardless of how they were produced (see `references/email/deliverability.md` and `references/email/cold-outreach.md`).

---

## A/B Testing

Design only — analyzing results (significance, lift, retention) belongs to the product-analytics skill.

- **Test hierarchy (impact order):** subject line > preview text > from-name > offer/CTA > body > send-time. Test the highest-leverage variable first.
- **One variable at a time** so the result is attributable. Hypothesis template: "I believe [variant] beats [control] because [audience insight], measured by [click/reply/conversion]."
- **Run variants simultaneously** (not sequentially) to avoid day-of-week confounds.
- **Small-list caveat:** below a few thousand sends per variant, statistical significance is usually unreachable — test only the single highest-leverage variable (subject) and treat results as directional.
- **Never judge subject-line tests on open rate** — MPP inflates opens. Use click, reply, or conversion as the success metric.
- Decide **kill / keep / scale** on the winning metric, then fold the winner into the template.

---

## Common Mistakes

- **Burying the lead** — the key message is in paragraph 3 instead of the first line
- **Multiple CTAs** — "Read our blog, also join our webinar, and don't forget to upgrade"
- **Subject/body mismatch** — subject promises one thing, body delivers another. This kills trust.
- **No preview text** — letting the email client auto-fill with "View in browser" or HTML artifacts
- **Desktop-first writing** — long lines and complex layouts that break on mobile
