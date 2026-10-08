---
name: copywriting
description: |
  Writes and edits marketing and product copy: positioning and messaging;
  landing, home and pricing pages, headlines, CTAs, paywall, popup, push and
  in-app promo copy, brand voice, changelogs; email (onboarding, trial,
  re-engagement, win-back, newsletter, cold, deliverability); organic social
  and launch posts (Product Hunt, Show HN, Reddit); persuasion psychology.
  Use when: "landing page copy", "headline ideas", "onboarding emails",
  "LinkedIn post", "is this a dark pattern?".
  Do NOT use for: ad copy (ad-creative); billing-event notices, cancel flows
  (churn-prevention); SEO or blog articles (search-visibility); comparison or
  alternative pages (competitor-pages); conversion diagnosis (cro).
---

# Copywriting

Most copy fails before its first sentence: the reader can't tell what it is or who it's for, the promise is every rival's, the proof is missing, or the page breaks the promise that brought them. Settle those first, then write the strongest claim your proof supports, in the customer's words, to one reader taking one action.

## Routing

| Request | Path | Read |
|---|---|---|
| New page: landing, home, pricing, feature, about, smoke test | §1-3, §6 | `references/copy-frameworks.md` |
| Positioning, message hierarchy, tagline, headline or CTA | §1, §3 | Positioning or tagline: `references/copy-frameworks.md` § Positioning |
| Banner, push, in-app upsell, paywall or popup | §1 lean | `references/copy-frameworks.md` § Promo units and paywalls |
| Variants from a cro copy-direction brief | Its problem statement is the acceptance test; its fields seed §1; one variant per angle; don't re-diagnose | |
| Brand voice; changelog entries | Voice: §1 Read first only; changelog: §1 lean | `references/copy-frameworks.md` |
| Edit or review existing copy | §5 | `references/editing-sweeps.md` |
| Another market or language | Keep the message; redo §1 and §3 from that market's customer words, proof and rules; never translate headlines; native review | |
| A persuasive structure (PAS, AIDA, BAB, 4Ps, SSS) | §2 picks it | `references/persuasion-frameworks.md` |
| A trigger or lever, "is this a dark pattern?", a funnel's levers | The guide | `references/psychology/guide.md` |
| Any email | The guide first; it routes onward | `references/email/guide.md` |
| Social posts and calendars, build in public, launch-day copy | The guide first; it routes onward | `references/social/guide.md` |

Email, social and psychology use their guide's frame, output spec and self-review; §1's proof and reframe rules, the reject list and Guardrails still apply.

**Not here** (via each capability, if available): ad copy (ad-creative); billing-event notices (dunning, card expiry, renewal) and cancel flows (churn-prevention); SEO and blog articles (search-visibility); comparison and alternative pages (competitor-pages); conversion diagnosis, layout, tests, paywall and checkout UI (cro); prices and offer terms (pricing; worded here); functional UI copy in screen or app specs (screen-design, ux-design).

## 1. Frame

**Read first** (defaults; caller may redirect; read-only except the Brand Voice section): the marketing strategy (`biz/marketing/strategy.md`: positioning, Brand Voice), the product brief (`docs/prd/product-brief.md`), the competitor analysis (`biz/marketing/competitors.md`), the price book (`biz/marketing/pricing.md`), the current copy, and customer language (reviews, tickets, sales notes; else competitors' three-star reviews). Sort verbatim phrases into pain, desired outcome, objection and trigger moment: the most repeated pain picks the topic, its most vivid phrasing the words. Missing files become assumptions. Check inputs against each other: an impossible figure (a rate above 100%, more users than signups, a past deadline) is a finding to raise, never copy material.

**Settle five things.** Ask once, in one batch, only what the inputs don't answer, each with its default; a subagent that can't ask applies the defaults and puts its questions under Questions for you (§6).
1. **Reader and moment.** Default: the brief's best-fit buyer, cold from search. In B2B above self-serve prices, also who approves next (default: manager and finance).
2. **The one action.** Default: the page's primary CTA.
3. **Their current alternative, and the top reason they'd stay with it.** Default: the manual status quo (a spreadsheet, an agency, nothing), and "switching costs more than it saves".
4. **Proof inventory**: the proof rule below.
5. **Hard limits**: surface, characters, locales, regulated claims. Default: web, one locale, none.

**Is copy the bottleneck?** If you can't say in one sentence why this beats the reader's alternative, positioning is unsettled: draft that sentence, flag it for the owner, then write the copy. If the ask outruns cold traffic (a demo, a payment), keep it primary, add the smallest useful step as secondary (a sample, a calculator, a no-signup trial) and flag the mismatch. If the real problem sits past the asked surface (data puts the drop at a form, a price or a slow page; the destination breaks the promise; the offer doesn't fit the audience), deliver the asked copy anyway and hand the fix off under Beyond this copy (§6).

**The proof rule.** Before drafting, list what you can cite: sourced numbers, named customers, quotes used with permission, ratings, and policies the owner confirms (guarantee, trial terms, cancellation, certifications). Every claim maps to one item, and so does what a line implies: "works with your tools" claims the reader's tools, "real-time" claims seconds, "replaces your agency" claims all the agency did. Bound the implication ("Syncs with QuickBooks and Xero") or tag it. Rank proof by how checkable it is and how closely it matches the reader: a named customer like them, with a number, beats a count with its denominator, which beats logos, ratings and unnamed quotes; the strongest sits beside its claim. A gap becomes a visible tag, never a plausible number, name, quote, policy or story: `[SOURCE NEEDED: what]` for missing proof, `[VERIFY: claim]` for anything from memory, a secondary source, or awaiting the owner.

**Reframe to true; don't delete.** A false, unprovable or risky claim was doing a job (lowering risk, showing speed, proving trust, giving a reason to act now). Keep the job and write the strongest true claim that does it: a narrower true version, the mechanism, a concrete scene, the effort you remove, or what the reader already owns and keeps (their data, saved work, a locked price). Keep the stakeholder's wording when a stated condition makes it true ("Live in a day once Stripe is connected"). Delete only when nothing true does the job, and say what went and why; if the sources are silent rather than contrary, also ask the owner under Questions for you. Cut a hedge only if the sentence stays true without it.

*Example.* "Never lose a file again", over 30-day version history, is false; deleting it leaves the CTA bare. True rewrite, same job: "Every version kept for 30 days. Restore any of them in two clicks."

**Size and risk.** Size limits what you write, never what you check: claims and their implications, the destination's promise, consent and eligibility, the reader's traps. A single string (CTA, push, banner, popup line): read its screen, destination and Brand Voice; ask only if the destination is unknown. A section or short page: §1-3 lean, skipping what the brief answers. A full page or campaign: everything. **Regulated claims** raise the bar claim by claim, not page by page (health, earnings, credit, insurance or investments, children, named competitors, results testimonials, conditional "free", environmental claims): each needs its proof and a flag naming the claim and its rule ("results testimonial: state what typical customers get, US 16 CFR 255.2(b)"), never a generic "check with legal"; a rule cited from memory carries `[VERIFY: in force]`.

**Done**: the Self-Review passes; on a page, headline and subhead alone tell a stranger from the segment what it is, who it's for and why it beats what they use now.

## 2. Decide the opening

Awareness follows the traffic: cold social and display → unaware or problem-aware; problem searches → problem-aware; category and comparison searches → solution-aware; brand search, retargeting, users → product-aware or most aware. Crowded: rivals already make your main claim.

| Reader | Open with | Claim | Structure (`references/persuasion-frameworks.md`) |
|---|---|---|---|
| Unaware | A scene they recognize; name the problem once they nod | The problem, then your answer | SSS |
| Problem-aware | Their problem, in their words | Your answer | PAS |
| Solution-aware, crowded | How it works differently, or "for X who Y" | A mechanism or an identity, never a bigger promise | 4Ps, mechanism first |
| Solution-aware, new category | What it is and does, plainly | The category explanation | AIDA or BAB |
| Product-aware | The offer, plus proof against the top objection | Proof | 4Ps |
| Most aware | Offer, price, CTA | None | Direct |

Break: a page reached from an ad or email opens on its promise (message match), whatever the row says.

## 3. Message, then words

**Message.** One sentence: who it's for, what it does, why it beats their alternative. Then at most three supporting points, each tied to an inventory item. Every section expands one point; a section that serves none goes. For a message-hierarchy request, this is the deliverable.

**Headlines.** For a hero or campaign headline, draft at least 15 across at least 5 angles (outcome, mechanism, the alternative or enemy, a number you hold, "for X who Y", the top objection, the customer's own phrase); keep 3-5 finalists from different angles. **Swap test:** if a named competitor could run it unchanged and stay truthful, rewrite it. Breaks: most-aware traffic, where the offer is the headline; a true claim no rival makes yet, made specific, is yours to preempt. **Pick** after drafting any body copy: among finalists a stranger from the segment gets in one read, the biggest claim you can prove; at a tie, clear beats clever.

*Example.* Crowded bookkeeping category: "Effortless bookkeeping, powered by AI" fits any rival. Reviews repeat "month-end takes me a week", so lead with the mechanism: "Month-end, already reconciled. [Product] matches every bank line to its invoice overnight and flags the few it can't." `[SOURCE NEEDED: median close time]`. AI claims name the job, the work removed and how errors get caught.

**The line beside a CTA** answers the reader's hesitation at that moment, truthfully: the effort ("Set up in 10 minutes"), the risk ("No card needed", "Cancel anytime"), the fit with their tools, or what happens next. Each moment gets its own line; none repeats down the page. Billing terms belong where money or consent is taken (Guardrails); beside a signup or demo button they add friction and protect no one.

**Register.** The best salesperson talking to one customer: their jargon is fine, yours isn't.

**Reject on sight:** unlock, elevate, seamless, supercharge, empower, revolutionize, game-changer, cutting-edge, delve; "not just X, it's Y"; adjective triplets; "Tired of…?" and "What if you could…?" openers; "Here's the thing"; three fragments in a row; more than one em dash in a paragraph. A buzzword marks a missing fact: use the number, mechanism or example, or cut the sentence. Break: product names and literal uses.

## 4. Functional UI copy

Outside a screen spec, follow the ux-design capability's ux-writing method, if available.

## 5. Editing

**Rank before you rewrite.**
- **Critical**: a false, unsupported or unconfirmed claim, stated or implied; invented proof; a dark pattern; marketing or an offer aimed at people who didn't agree to it or don't qualify; the reader can't tell what it is or who it's for.
- **High**: fails the swap test; mismatches the traffic source; the CTA doesn't predict the next screen; written to the wrong reader.
- **Medium**: features without their "which means"; proof far from its claim; voice drift.
- **Low**: word level.

Fix in that order; a Critical claim gets its true rewrite (§1), not a gap. **The author decides:** change only what a finding needs, keep their wording where it works, show each Critical and High change as before → after with a one-line reason, and offer the original back. **Stay on the asked surface:** elsewhere, fix only Critical issues, minimally and flagged; list other material issues under Beyond this copy, unedited. Break: a line-edit request gets the Low pass but still flags any Critical.

## 6. Copy deck

The deliverable for pages, short-form copy and edits: copy first, short notes after. **Copy budget**: headline ≤12 words (sales letters and advertorials: pre-head plus headline ≤20), subhead ≤25, button ≤5, section block ≤60, long-form sized by the reader's open questions. **Notes budget** (all that isn't copy): a string or line edit ≤60 words; a section, short page or page edit ≤200; a full page or campaign ≤350. Budgets cap the record, never the checks: each material finding (a false or risky claim, a legal flag, a consent or eligibility problem, a broken promise) reaches the user in one line, past the budget if need be, overrun noted. Sections are a menu: omit what doesn't apply, heading included. Never name this skill's rules, frameworks or awareness levels in the deck.

- **Assumptions** (≤2 lines, top): only defaults that change the copy.
- **Copy**, by section in page order; a **Show** line (≤15 words) where a screenshot or clip must carry the proof; an edit returns the revised copy, changed lines marked.
- **Alternatives**: hero headline, the pick plus two from other angles; primary CTA, one plus one; others only when asked. A dictated line that fails the swap test or the proof rule ships as asked (tags included), with your rewrite and a one-line reason.
- **What changed** (edits): Critical and High, ranked, one line each (before → after, why); one line on what you left alone.
- **Beyond this copy**: each problem past the asked surface in one line: what, where, the fix, the owner (cro, pricing).
- **Decisions for you**: calls only the owner can make (a claim's condition, who gets an offer, positioning), each with your recommendation.
- **Questions for you**: each tag, and each claim cut for silent sources, as a direct question ("Do most new accounts finish setup within 10 minutes?"); legal flags too.
- **Bet** (≤12 words): only for a real uncertainty about the reader; at most two.

## Guardrails

- **Drafts only.** Never publish, send, schedule or post anything without the caller's explicit approval.
- **Output paths** (defaults; caller may redirect the `biz/<area>/` root): email, social and changelog entries in `biz/marketing/content/{email,social,changelog}/`, launch-day copy in `biz/marketing/launch/`, brand voice in the Brand Voice section of `biz/marketing/strategy.md`. Update in place; with no file-write capability, return inline.
- **Persuade, never manipulate.** Never fabricate scarcity, urgency, reference prices, social proof or metrics. Never pre-select what costs money or grants consent (a pricier plan, an add-on, a post-trial charge, marketing consent). Where money or consent is taken (checkout, a purchase button, a trial that takes a card), state the amount, when billing starts, renewal and how to cancel, plainly, before the customer commits. Every lever passes the persuasion gate in `references/psychology/guide.md`, whose Dark Pattern Anti-Catalog holds the dated rules.
- **Consent decides, not the legal floor.** People who gave you their address get marketing (email, push, messages) only if they agreed to it: declined or unrecorded means none, whatever the law allows. Split a mixed list by relationship, each group getting what it signed up for (`references/email/guide.md`; cold prospecting: `references/email/cold-outreach.md`).
- **Never manufacture engagement**, launch emails included: no vote asks anywhere, no Hacker News comment asks or item links, no pods, timed comments or extra accounts; insiders disclose the connection in the post.

## Self-Review

Fix before delivering; don't report the checks; skip items the piece doesn't have.
1. Headline and three main claims pass the swap test; the opening keeps the source's promise; on a page, the Done test (§1) passes and headings plus first lines carry the argument alone.
2. Every claim, stated or implied, traces to the inventory, is bounded, or is tagged; nothing invented.
3. Every cut or changed claim kept its job through a true replacement, or the notes say what went and why; stakeholder wording kept where a stated condition makes it true.
4. Every tag, and every claim cut for silent sources, is a direct question under Questions for you; every legal flag names the claim and its rule, tagged if from memory.
5. Each CTA predicts its next screen; its line answers that moment's top hesitation; no line repeats; billing terms sit only where money or consent is taken.
6. Edits stay on the asked surface (outside it, Critical only, flagged); each Critical and High change shows before → after.
7. Alternatives differ by angle, not synonym; zero reject-list hits; every lever passes the persuasion gate; nothing costly or consenting is pre-selected.
8. **Footprint**: copy first; every element and the notes within budget, or an overrun noted for a material finding; every problem past the asked surface handed off; every section answers a question the reader asks before acting; Bets only for real uncertainty; nothing names this skill's machinery.
