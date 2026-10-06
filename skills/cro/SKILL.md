---
name: cro
description: |
  Conversion Rate Optimization for pages, forms, signup flows, onboarding, popups, paywalls, and checkout.
  Use when: analyzing page conversion, optimizing signup/checkout flows, improving onboarding activation,
  reducing form abandonment, creating/optimizing popups/modals, optimizing paywall/upgrade flows,
  designing A/B tests, or when user mentions "conversion", "CRO", "drop-off", "friction", "paywall",
  "popup", "improve my pricing page", "bounce rate", "cart abandonment", "funnel optimization".
  Do NOT use for: writing final copy (use copywriting skill — cro identifies copy problems/directions, copywriting produces variants),
  psychological principles (use copywriting skill — persuasion psychology), email optimization (use copywriting skill — email),
  pricing strategy/tier design (use pricing skill — cro covers only paywall/pricing-page UI),
  referral/viral-loop design (use growth-loops skill), or A/B test analysis and Aha-Moment/retention analytics
  (use product-analytics skill — cro owns experiment design only).
---

# Conversion Rate Optimization

Systematic approach to improving conversion rates across pages, flows, forms, popups, and paywalls.

---

## Unified CRO Framework

Every conversion optimization follows this process:

### 1. Identify the Conversion Goal
What is the ONE primary action? Be specific: "signup", "upgrade to paid", "submit form", "complete onboarding step 3."

### 2. Map the Current Funnel
Document every step from entry to conversion. Identify where users enter, what they see, and where they drop off.

If funnel- or field-level data doesn't exist yet, instrument it first — drawing on a product-analytics capability (tracking-plan and GA4/event-setup guidance) if one is available. You can't optimize what you can't measure; absent data, fall back to a heuristic audit and flag that lift estimates are unvalidated — never promise a measured lift from heuristic mode.

Before treating funnel/drop-off numbers as exact, account for measurement gaps: consent-banner opt-outs (declined users aren't tracked), Safari/Firefox cookie restrictions and ad-blockers (lost sessions), and GA4 Consent Mode modeled (estimated, not observed) conversions. For high-stakes calls, reconcile against server-side or order-level data.

### 3. Diagnose Before You Prescribe
Don't jump from "where users drop off" to a fix. At the drop-off point, gather evidence about *why* before recommending changes:
- **Behavioral** — funnel/path analytics, field- and step-level drop-off.
- **Qualitative** — session replays and heatmaps/scroll maps (e.g., Microsoft Clarity, Hotjar, FullStory), on-page exit surveys, and 3–5 quick user tests.
- **Technical** — page-load/LCP and console/payment errors at the failing step.

Form an explicit hypothesis ("users drop here because X") before writing recommendations. Prescribing from a checklist without diagnosing the real failure mode produces generic, often-wrong fixes (e.g. "shorten the form" when the real blocker is a confusing payment error). Tie the ICE Confidence score (below) to whether a recommendation is backed by this evidence rather than best practice alone.

### 4. Prioritize by Impact
Analyze in this priority order (highest impact first):
1. **Value Proposition Clarity** — Can users understand what they get in 5 seconds?
2. **CTA Effectiveness** — Is the desired action visible, clear, and compelling?
3. **Friction Points** — What unnecessary steps, fields, or confusion exist?
4. **Trust Signals** — Is there enough social proof and credibility?
5. **Objection Handling** — Are common concerns addressed before the CTA?

Score each recommendation using **ICE**:
- **Impact** (1-10): How much will this move the conversion rate?
- **Confidence** (1-10): How sure are we this will work? (data > best practice > gut)
- **Ease** (1-10): How quickly can this be implemented?

ICE Score = (Impact + Confidence + Ease) / 3. Rank recommendations by score. Present the top items first. (When a reference's output format uses Priority: High/Medium/Low, bucket the ICE ranking into those bands — top third = High.)

### 5. Generate Recommendations
Structure output as:
- **Quick Wins** — Changes implementable in < 1 day
- **High-Impact Changes** — Larger changes with significant expected lift
- **Test Ideas** — Hypotheses to validate with A/B tests

---

## When to Use Which Reference

| Scenario | Reference |
|----------|-----------|
| Landing/marketing page conversion | `references/page-cro.md` |
| Signup/registration flow | `references/signup-flow-cro.md` |
| Post-signup onboarding/activation | `references/onboarding-cro.md` |
| Lead capture / contact / demo / survey / application forms | `references/form-cro.md` |
| Popups/modals/overlays/banners | `references/popup-cro.md` |
| In-app upgrade/paywall/upsell | `references/paywall-upgrade-cro.md` |
| Checkout/cart/purchase flow (incl. checkout/payment forms) | `references/checkout-cro.md` |
| Pricing page content defaults (plan order, annual toggle/discount depth, tier count) | `pricing` skill (separate) — cro diagnoses that page's conversion via `references/page-cro.md` |
| Referral programs, viral loops, K Factor | `growth-loops` skill (separate) |
| A/B test design (hypothesis, sample size, variants, ramp) | `references/experiments.md` |
| A/B test analysis (significance, segments, revenue impact) | `product-analytics` skill |

**Multi-area requests** (e.g., "optimize my SaaS funnel"): Read the most relevant reference first, then pull in additional references as needed. For full-funnel work, read in the order the funnel demands: SaaS/subscription → page → signup → onboarding → paywall; e-commerce/transactional → page → form → checkout. Synthesize into a single cohesive analysis — don't produce separate reports per area. When choosing which stage to fix first, work bottom-up: retention → activation → acquisition (pouring traffic into a leaky funnel wastes it).

---

## Core CRO Principles

### Every Interaction Has a Cost
Every form field, every click, every page load reduces the percentage of users who continue. Justify every element.

### Value Before Ask
Show users what they get before asking them to commit. Experience before signup. Benefits before pricing.

### Reduce Perceived Effort
Progress indicators, smart defaults, pre-filled fields, and "just 2 minutes" messaging all reduce the feeling of work.

### One Primary Action Per Screen
Don't compete with yourself. One CTA, one goal, one message. Save secondary actions for after the primary conversion.

### Respect the User's Decision
No dark patterns. Easy to dismiss, easy to cancel, easy to go back. Trust builds long-term conversion.

### Test, Don't Assume
Every hypothesis needs validation. What works on one site may fail on another. See `references/experiments.md` for rigorous test design — and, when traffic is too low to power an A/B test, for how to validate another way instead of defaulting to an unrunnable test.

### Accessibility Is Conversion Recovery
Contrast (~4.5:1 text, 3:1 UI), a visible focus ring, and errors announced to screen readers recover users who would otherwise fail silently — treat them as conversion fixes, not compliance chores. Specifics: `form-cro.md` / `checkout-cro.md`; token/system details belong to a design-system capability.

---

## CRO Analysis Output Template

This is the default shape. When a reference defines its own Output Format (e.g. `page-cro.md`, `signup-flow-cro.md`, `onboarding-cro.md`, `form-cro.md`), follow the reference's format and treat this template as the fallback.

**Output:** When asked to save a written CRO analysis (if a file-write capability is available), write it to the growth-output root (default `biz/growth/cro/{page-or-flow}-analysis.md`; caller may redirect the `biz/<area>/` root). Update an existing file in place rather than creating a duplicate.

**Recommend, don't ship.** This skill produces analyses, recommendations, and experiment designs; it never edits application code itself — implementation goes back to the caller.

**Growth experiment log.** When an experiment is designed or concludes, record it in the experiment log (default `biz/growth/experiments.md`; caller may redirect) — the analytics side (the data-analyst agent, or the product-analytics skill) reads it for significance analysis. Update the file in place; one entry per experiment with: a falsifiable hypothesis, one primary metric, a guardrail metric, the pre-committed sample size or stopping rule (see `references/experiments.md`), and the outcome (filled in when it concludes). If no file-write capability is present, return the entry inline.

```markdown
## CRO Analysis: [Page/Flow Name]

### Current State
- Conversion rate: X%
- Key drop-off point: [where]
- Primary issue: [what]

### Quick Wins (< 1 day)
1. [Change] — Expected impact: [high/medium/low]
2. [Change] — Expected impact: [high/medium/low]

### High-Impact Changes
1. [Change] — Rationale: [why]
2. [Change] — Rationale: [why]

### A/B Test Ideas
1. Hypothesis: [if we X, then Y, because Z]
2. Hypothesis: [if we X, then Y, because Z]

### Copy Direction (hand to copywriting for final variants)
- Element: [headline / CTA / etc.]
- Problem: [why the current copy underperforms]
- Direction: [angle/message to pursue — final variants come from the copywriting skill]
```

---

## Key Metrics by CRO Type

| Type | Primary Metric | Secondary Metrics |
|------|---------------|-------------------|
| Page | Visit → CTA click rate | Scroll depth, time on page, bounce rate |
| Signup | Form start → completion rate | Field drop-off, time to complete, error rate |
| Onboarding | Signup → Aha Moment rate | Time to first action, step completion |
| Form | Form view → submission rate | Field-level drop-off, error rate |
| Popup | Impression → conversion rate | Close rate, time to close |
| Paywall | View → upgrade rate | Click-through to pricing, plan selection |
| Checkout | Cart → purchase completion rate | Checkout-start rate, step drop-off, payment failure rate, AOV |

---
