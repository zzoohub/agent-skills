# Form CRO

Optimize any form that is NOT signup/registration — lead capture, contact, demo request, application, survey. (Checkout/payment forms are covered in checkout-cro.md.)

## Table of Contents

1. [Core Principles](#core-principles)
2. [Field-by-Field Optimization](#field-by-field-optimization)
3. [Form Layout](#form-layout)
4. [Multi-Step Forms](#multi-step-forms)
5. [Error Handling](#error-handling)
6. [Submit Button Optimization](#submit-button-optimization)
7. [Trust and Friction Reduction](#trust-and-friction-reduction)
8. [Form Types: Specific Guidance](#form-types-specific-guidance)
9. [Benchmarks](#benchmarks)
10. [Before/After Example: Demo Request Form](#beforeafter-example-demo-request-form)
11. [Mobile Optimization](#mobile-optimization)
12. [Key Metrics](#key-metrics)
13. [Output Format](#output-format)
14. [Experiment Ideas](#experiment-ideas)

---

## Core Principles

### 1. Every Field Has a Cost
Each field reduces completion rate:
- 3 fields: Baseline
- 4-6 fields: 10-25% reduction
- 7+ fields: 25-50%+ reduction

For each field, ask: Is this necessary? Can we get this another way? Can we ask later?

### 2. Value Must Exceed Effort
Clear value proposition above form. Make what they get obvious.

### 3. Reduce Cognitive Load
One question per field. Clear labels. Logical grouping. Smart defaults.

---

## Field-by-Field Optimization

| Field | Best Practice |
|-------|--------------|
| **Email** | Single field, no confirmation, inline validation, typo detection, proper mobile keyboard |
| **Name** | Test single "Name" vs First/Last — single reduces friction |
| **Phone** | Make optional if possible, explain why if required, auto-format |
| **Company** | Auto-suggest, enrichment after submission, infer from email domain |
| **Job Title** | Dropdown if categories matter, free text if wide variation, consider optional |
| **Message** | Make optional, reasonable character guidance, expand on focus |
| **Dropdowns** | "Select one..." placeholder, searchable if many options, radio buttons if < 5 |

---

## Form Layout

### Field Order
1. Start with easiest fields (name, email)
2. Build commitment before asking more
3. Sensitive fields last (phone, company size)

### Labels and Placeholders
- Labels: Always visible (not just placeholder)
- Placeholders: Examples, not labels
- Help text: Only when genuinely helpful

### Visual Design
- Single column preferred (higher completion, mobile-friendly)
- Multi-column only for short related fields (First/Last name)
- Sufficient spacing, clear hierarchy, CTA stands out
- Mobile-friendly tap targets (44px+)
- Accessibility is conversion recovery: sufficient CTA contrast (WCAG ~4.5:1 text, ~3:1 large/UI), a visible focus ring, and inline errors announced to screen readers (aria-live / role=alert)

---

## Multi-Step Forms

### When to Use
- More than 5-6 fields
- Logically distinct sections
- Conditional paths based on answers

### Best Practices
- Progress indicator (step X of Y)
- Start with easy, end with sensitive
- One topic per step
- Allow back navigation
- Save progress

### Progressive Commitment Pattern
1. Low-friction start (just email)
2. More detail (name, company)
3. Qualifying questions
4. Contact preferences

---

## Error Handling

### Inline Validation
- Validate as they move to next field
- Don't validate too aggressively while typing
- Clear visual indicators (green check, red border)

### Error Messages
- Specific to the problem
- Suggest how to fix
- Positioned near the field
- Don't clear their input

**Good:** "Please enter a valid email address (e.g., name@company.com)"
**Bad:** "Invalid input"

---

## Submit Button Optimization

### Button Copy
Weak: "Submit" | "Send"
Strong: "[Action] + [What they get]"
- "Get My Free Quote"
- "Download the Guide"
- "Request Demo"

### Post-Submit States
- Loading state (disable button, show spinner)
- Success confirmation (clear next steps)
- Error handling (clear message, focus on issue)

---

## Trust and Friction Reduction

### Near the Form
- Privacy statement: "We'll never share your info"
- Security badges if collecting sensitive data
- Testimonial or social proof
- Expected response time

### Reducing Perceived Effort
- "Takes 30 seconds"
- Field count indicator
- Remove visual clutter

---

## Form Types: Specific Guidance

| Type | Key Optimization |
|------|-----------------|
| **Lead Capture** | Minimum fields (often just email), clear value prop, enrichment post-download |
| **Contact** | Email + Name + Message essential, phone optional, set response expectations |
| **Demo Request** | Name/Email/Company required, calendar embed increases show rate |
| **Quote Request** | Multi-step works well, start easy, technical details later |
| **Survey** | Progress bar essential, one question per screen, skip logic |

---

## Benchmarks

| Form Type | Typical Completion | Good | Excellent |
|-----------|-------------------|------|-----------|
| Lead capture (email only) | 30-50% | 50-70% | 70%+ |
| Contact form (3-4 fields) | 15-30% | 30-45% | 45%+ |
| Demo request (5-6 fields) | 10-20% | 20-35% | 35%+ |
| Quote/application (7+ fields) | 5-15% | 15-25% | 25%+ |
| Survey (10+ questions) | 10-25% | 25-40% | 40%+ |

These figures are directional and vary by industry, audience, and period — validate against your own data. Each additional field beyond 3 typically reduces completion by 5-10%. Multi-step forms with progress bars can recover 10-20% of that loss.

---

## Before/After Example: Demo Request Form

**Before (high friction):**
```
Request a Demo
[First Name]  [Last Name]
[Email]
[Phone Number]
[Company]
[Job Title]
[Company Size ▼]
[Industry ▼]
[What are you looking for? ____________]
[How did you hear about us? ▼]
[Submit]
```
Problems: 10 fields, many of which can be enriched post-submission or collected on the call. "Submit" CTA communicates nothing. No trust signals. No expectation setting.

**After (optimized):**
```
See [Product] in Action
Book a 15-min demo tailored to your workflow.

[Work Email]
[Company]
[What challenge are you trying to solve? (optional) ___]
[Book My Demo]

"We'll email you a calendar link within 1 hour."
⭐ "The demo sold us immediately." — VP Eng, Acme Corp
```
Why it works: 3 fields (email + company is enough to enrich name, title, size via an enrichment tool such as Apollo, or HubSpot Breeze Intelligence — the former Clearbit, now a HubSpot add-on). Optional free-text shows interest without blocking. CTA sets expectation. Social proof and response time promise reduce uncertainty.

---

## Mobile Optimization

- Larger touch targets (44px minimum)
- Appropriate keyboard types (email, tel, number)
- Autofill support
- Single column only
- Sticky submit button

---

## Key Metrics

| Metric | Description |
|--------|-------------|
| Form start rate | Page views → Started form |
| Completion rate | Started → Submitted |
| Field drop-off | Which fields lose people |
| Error rate | By field |
| Time to complete | Total and by field |

---

## Output Format

### Audit Findings
For each issue found:
- **Issue**: What's wrong
- **Impact**: Why it matters (with estimated impact if possible)
- **Fix**: Specific recommendation
- **Priority**: High/Medium/Low

### Recommended Changes
Organized by:
1. Quick wins (same-day fixes)
2. High-impact changes (week-level effort)
3. Test hypotheses (things to A/B test)

### Form Redesign (if requested)
- Recommended field set with rationale
- Field order
- Copy direction for labels, placeholders, buttons, errors (hand to the copywriting skill for final variants)

---

## Experiment Ideas

### Layout & Flow
- Single-step vs. multi-step with progress bar
- Form embedded on page vs. separate page
- Form above fold vs. after content

### Field Optimization
- Reduce to minimum viable fields
- Add or remove phone/company field
- Progressive profiling (ask more over time)
- Hide fields for returning/known visitors

### CTAs & Trust
- Button text variations ("Submit" vs. "Get My Quote")
- Add privacy assurance near form
- Display expected response time
