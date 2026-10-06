# Popup CRO

Optimize popups, modals, overlays, slide-ins, and banners for conversion.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Trigger Strategies](#trigger-strategies)
3. [Popup Types](#popup-types)
4. [Design Best Practices](#design-best-practices)
5. [Copy Formulas](#copy-formulas)
6. [Frequency and Rules](#frequency-and-rules)
7. [Compliance and Accessibility](#compliance-and-accessibility)
8. [Benchmarks](#benchmarks)
9. [Common Strategies by Business Type](#common-strategies-by-business-type)
10. [Experiment Ideas](#experiment-ideas)

---

## Core Principles

1. **Timing Is Everything** — Too early = annoying, too late = missed, right time = helpful
2. **Value Must Be Obvious** — Clear immediate benefit, relevant to page context
3. **Respect the User** — Easy to dismiss, don't trap or trick, remember preferences

---

## Trigger Strategies

| Trigger | When | Best For |
|---------|------|----------|
| **Time-based** | 30-60 seconds (not 5 seconds) | General site visitors |
| **Scroll-based** | 25-50% scroll depth | Blog posts, long-form content |
| **Exit intent** | Cursor moving to close/leave | E-commerce, lead gen |
| **Click-triggered** | User clicks button/link | Lead magnets, gated content |
| **Page count** | After visiting X pages | Multi-page journeys |
| **Behavior-based** | Cart abandonment, pricing page visits | High-intent segments |

---

## Popup Types

### Email Capture
- Clear value prop (not just "Subscribe")
- Single field (email only)
- Consider incentive (discount, content)
- CTA: Specific action ("Get Weekly Tips")

### Lead Magnet
- Show what they get (cover image, preview)
- Specific, tangible promise
- Minimal fields (email, maybe name)

### Discount/Promotion
- Clear discount (10%, $20, free shipping)
- Deadline creates urgency
- Single use per visitor

### Exit Intent
- Acknowledge they're leaving
- Different offer than entry popup
- Address common objections
- Formats: "Wait! Before you go...", "Forget something?", "Get 10% off"

### Announcement Banner
- Top of page (sticky or static), single message, dismissable, time-limited

### Slide-In
- Enters from corner/bottom, doesn't block content, easy to dismiss

---

## Design Best Practices

### Visual Hierarchy
1. Headline (largest, first seen)
2. Value prop/offer (clear benefit)
3. Form/CTA (obvious action)
4. Close option (easy to find)

### Sizing
- Desktop: 400-600px wide typical
- Mobile: Full-width bottom or center, not full-screen
- Always: visible close button, click outside to close

### Close Button
- Always visible (top right convention)
- Large enough to tap on mobile
- "No thanks" text link as alternative

---

## Copy Formulas

(These formulas are copy *direction* — patterns to diagnose against and angles to brief. Final variant copy ships via a copywriting capability, if available.)

### Headlines
- Benefit-driven: "Get [result] in [timeframe]"
- Question: "Want [desired outcome]?"
- Social proof: "Join [X] people who..."

### CTA Buttons
- First person: "Get My Discount" vs "Get Your Discount"
- Specific: "Send Me the Guide" vs "Submit"
- Value-focused: "Claim My 10% Off" vs "Subscribe"

### Decline Options
- Polite: "No thanks" / "Maybe later"
- Avoid manipulative: "No, I don't want to save money"

---

## Frequency and Rules

### Frequency Capping
- Maximum once per session
- Remember dismissals (cookie/localStorage)
- 7-30 days before showing again

### Audience Targeting
- New vs. returning visitors (different needs)
- By traffic source (match ad message)
- Exclude converted users and recently dismissed

### Page Rules
- Exclude checkout/conversion flows
- Match offer to page context

---

## Compliance and Accessibility

- GDPR (marketing opt-in): Clear consent, link to privacy policy, don't pre-check opt-ins
- ePrivacy / UK PECR (EU/UK): popups that set non-essential tracking or profiling storage — behavior-based triggers (cart/pricing-visit detection), cross-page personalization, progressive profiling — need prior consent and should be gated behind the cookie-consent banner, separately from the email opt-in. (Storage used only to remember a dismissal or frequency cap is generally treated as strictly necessary and exempt.)
- Accessibility: Keyboard navigable, focus trap, screen reader compatible
- Google: Intrusive interstitials are a page-experience/quality risk on mobile (Google's guidance lists avoiding them, though not every page-experience signal is a direct ranking factor)

---

## Benchmarks

| Type | Typical Conversion |
|------|--------------------|
| Email popup | 2-5% |
| Exit intent | 3-10% |
| Click-triggered | 10%+ (self-selected) |

These figures are directional and vary by industry, traffic, and period — validate against your own data.

---

## Common Strategies by Business Type

| Business | Popup 1 | Popup 2 | Popup 3 |
|----------|---------|---------|---------|
| **E-commerce** | First-purchase discount (scroll) | Bigger discount (exit) | Cart abandonment |
| **B2B SaaS** | Demo/lead magnet (click) | Newsletter (scroll) | Trial reminder (exit) |
| **Content/Media** | Newsletter (scroll) | Subscribe (page count) | Don't miss (exit) |
| **Lead Gen** | List building (time) | Lead magnets (click) | Final capture (exit) |

---

## Experiment Ideas

### Placement & Format
- Center modal vs. slide-in from corner
- Full-screen overlay vs. smaller modal
- Banner with countdown timer vs. without

### Triggers
- Exit intent vs. 30-second delay vs. 50% scroll depth
- Test optimal time delay (10s vs. 30s vs. 60s)
- Return visitor vs. new visitor targeting

### Messaging
- Urgency-focused vs. value-focused copy
- Button text and color variations
- With/without images or social proof

### Personalization
- Dynamic content based on visitor data
- Industry-specific content
- Progressive profiling
