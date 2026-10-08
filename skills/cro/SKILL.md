---
name: cro
description: |
  Conversion rate optimization for existing pages, signup, onboarding, forms,
  popups, paywalls, pricing pages and checkout: find why a step
  under-converts, size the leak, prescribe fixes and design A/B tests, low
  traffic included (sample size, guardrails, the experiment-log entry). Use
  when: "CRO", "conversion rate", "fix drop-off", "cart abandonment",
  "improve my pricing page", "design an A/B test". Do NOT use for: a new
  landing page or final copy (copywriting); tiers or prices (pricing); test
  readouts or funnel measurement (product-analytics); referral loops
  (growth-loops); in-product screen specs (screen-design).
---

# Conversion Rate Optimization

## Premise

A step under-converts because the measurement is wrong, the traffic was promised something else, the offer doesn't fit, or the flow gets in the way. Find which, size it in lost outcomes, pick the strongest validation the traffic allows, and judge every change on the outcome that pays, guarded against harm.

**Scope**: the conversion mechanics of existing pages and flows, field sets and popup triggers included; cancel flows go to churn-prevention, a new product's onboarding to ux-design, if available.

**Every request gets the full checks** (measurement, numbers, traps), including who else the change touches: sales, support, fraud, legal, finance.

## Stage 0 — Frame the request

**Read first** (defaults; caller may redirect): `biz/growth/experiments.md` and `biz/growth/cro/` (never re-propose a settled test); `biz/analytics/funnels.md`; `biz/analytics/tracking-plan.md` (the activation event); for paywalls and pricing pages, `biz/marketing/pricing.md` and `biz/growth/paywall-pricing.md`. Missing files are gaps, not blockers.

**Classify the request**:
- **Quick question** ("remove the phone field?"): a few lines from the surface file: what the element protects, the guardrail, the fact that would change the answer.
- **Dropped** ("signups fell 30%"): confirm the drop in the system of record (orders, billing, CRM; none there means measurement) and against the same weeks last year, comparing only cohorts whose outcome window has closed; date it (product-analytics' explain-a-move method, if available). A rate down with counts flat means the denominator changed (bots, a low-intent source). Then check, by browser × device: tracking and consent changes, deploys and running tests, traffic mix, the calendar, third-party steps (payments, auth, captcha), browser and OS releases. No ideas before the cause; none found: report what was ruled out and the next diagnostic.
- **Low, or "improve it"**: Stages 1–3.
- **Review without data**: walk it as a visitor from the named source and device, against the surface file's signatures (pages: page-cro's walk order); separate defects from hypotheses.
- **Add a popup or form**: Stage 1, then the surface file's judgment calls and field set.
- **Design a test**, solution-first ideas included ("test a sticky CTA"): Stage 1; name the evidence behind the idea (none: a best-practice guess, for spare capacity only); then Stage 3's validation design and a test card (`references/experiments.md`).
- **Redesign**: Stages 1–3; test it whole for non-inferiority (`references/experiments.md`), never before/after.

**Ask once, in one batch**; unanswered, apply the default and list it under Assumptions: the outcome that pays (default: the next completed step, judged by its quality); weekly users and conversions at the step (default: unknown; give the volume each design needs); source × device mix, recent changes, evidence on hand (default: unknown); self-serve or sales-led (default: self-serve unless the CTA books a call); constraints (default: what protects something stays until replaced); who decides, by when (default: the requester, no deadline).

## Stage 1 — The metric that pays

**Primary metric** = the outcome the surface exists to produce, per user who reaches it; never a rate whose denominator the change can move (a scarier form gets fewer starters and a better start→submit rate). Clicks, starts, scroll and dwell time are diagnostics. Use revenue or margin per exposed user when the change can shift plan mix, order value, discounts or payment cost; else the count outcome, which needs less traffic. Too rare or slow to decide on? It stays primary; a proxy may decide on Stage 3's terms.

| Surface | Primary, per exposed user | Guardrail against a fake win |
|---|---|---|
| Page | completed next step | its quality: activation, SQL rate, purchase |
| Signup | verified signups | activation |
| Lead form | SQLs | lead→SQL rate; sales capacity |
| Popup | site primary outcome vs a no-popup holdout | bounce, unsubscribes, discount cost |
| Paywall | paid conversions (revenue if plan mix can shift) | refunds, chargebacks, month-2 retention |
| Checkout | orders (revenue or margin) | AOV, payment failures, returns |
| Onboarding | activation | D30 retention |

## Stage 2 — Locate, then explain

**Check the measurement first, every time.** Reconcile the analytics count of the outcome with the system of record (orders, billing, CRM, server logs) for the same weeks, by browser and device: client-side tools undercount (consent, blockers, Safari storage limits) and fill gaps with modeled conversions. State the gap; one that varies by browser, device or step can fake a leak.

**Locate before explaining.** Start from the funnel doc; without one, segment by source (AI assistants included) × device × new vs returning, bots and agents excluded.
- One source or device carries the gap → its message match, or that device's UX.
- Every segment under-converts and users say "too expensive" or "not for me" → the offer or targeting (pricing, positioning), not the page.
- Users convert but don't activate or retain → downstream: onboarding here; retention to churn-prevention or product-analytics.

**A cause outside the surface asked about** (the ad's promise, the offer, a later step, a payment provider) leads the answer, handed off with its evidence, size, owner and the metric to judge the fix by.

**Break when** segments hold under ~100 conversions: lean on qualitative evidence. No funnel or field data: instrument first (product-analytics, if available) and promise no measured lift meanwhile.

**Diagnose before you prescribe**, with evidence of *why*: drop-off by step and field; errors; replays (EEA and UK: consenting users only, so decliners go unseen); 3–5 user tests; an open question at the leak ("What, if anything, is stopping you from [X] today?") and after conversion ("What almost stopped you?"), coded into counted themes. State each cause as a hypothesis; checklist fixes miss: "shorten the form" when the blocker is a payment error.

## Stage 3 — Rank and act

**Size each leak in lost outcomes**: weekly users entering the step × (reference rate − current rate) × the rate from the completed step to the outcome that pays. Reference: the rate before a break, the best segment of similar intent, or a comparable flow; never an external benchmark. A ceiling, not a forecast; cross-device journeys make mobile look worse.

**Tag the evidence**: *observed* = this funnel's data at scale, or two independent sources agreeing (a poll theme and a replay pattern; a lone replay, ticket or quote is a Research lead); *analog* = a past test here or a pattern validated on this surface; else *best-practice*. Rank by size, then evidence, then effort; effort never lifts best-practice above observed.

**Classify every action:**
- **Fix**: any defect, even in a small segment (errors, a broken device or browser, missing information users ask for, failing Core Web Vitals). Ship untested, to everyone: before a test launches or to every arm of a running one (a fix inside one arm gets credited to the variant), unless it can hurt something else (dropping a field sales routes on).
- **Test**: direction uncertain, stakes material, within the surface's quarterly test capacity (`references/experiments.md` § Sizing) → design the validation (below), then a test card.
- **Ship & watch**: uncertain, cheap to reverse, and no design below decides in time: a comparison, never a plain before/after, and a rollback rule (default: two weeks running below the prior 8 weeks' low, or a comparison gap outside its pre-period range; options: `references/experiments.md` § Rollouts without a test).
- **Research**: no observed or analog explanation; name the evidence to collect (an exit poll, 20 abandoner replays, 5 user tests).

**Friction is often a control.** Before removing a field, step or check, name what it protects (fraud, abuse, spam, sales routing, consent, data quality, deliverability) and the control that replaces it (verification at the first risky action, rate limits, invisible bot scoring, enrichment, a conditional field); its metric becomes a guardrail.

**Design the validation before calling anything untestable.** At default error rates (two-sided α 0.05, 80% power) and baselines under ~10%, a two-arm test detects a 10% lift in 4 weeks with ~800 conversions a week, 20% with ~200. Short of that, price each rung of the ladder (`references/experiments.md`) in weeks to a decision: a bolder variant; error rates set by what each mistake costs (for a cheap, reversible change, one-sided α 0.10–0.20 needs 0.57–0.36× the sample and ships 10–20% of no-effect changes, but an MDE-sized loss under 1% of the time); a higher-volume proxy, validated here or deciding only if the outcome also leads; variance reduction; a longer window, bounded by identity loss and calendar drift; pre-registered sequential or Bayesian looks. State the chosen rule's three ship rates (the card's Ships line). Lead with the best design that still learns, the cheap rollout as its fallback; "no test" only after every rung is priced, prices shown.

**Guardrails in every mode**, each with a numeric threshold (the largest loss the expected gain pays for), a breach action, and its miss rate at the smallest loss worth catching. The default rollback rule false-alarms ~1 time in 10 over 8 weeks and, within 8 weeks, reliably catches only losses above ~1.7× the week-to-week variation (at least 1 ÷ √weekly conversions: at 100 a week, a 10% loss is a coin flip). Name that blind spot or narrow it.

**Holdouts**: judge discounts, popups, recovery incentives and financing offers against a no-treatment holdout, on revenue or margin per visitor (attributed conversions include people who'd have bought anyway), unless the treatment costs nothing and annoys no one.

**Accessibility failures are Fixes** (WCAG 2.2 AA; EU e-commerce law: `references/checkout-cro.md`), above all 3.3.8 (paste, password managers), 3.3.7 (no re-entry), 2.4.11 (sticky bars never hide focus), 2.5.8 (target size).

## References

Read the file for the leaking surface: `references/page-cro.md` (any marketing page, pricing included), `references/signup-flow-cro.md`, `references/onboarding-cro.md`, `references/form-cro.md`, `references/popup-cro.md`, `references/paywall-upgrade-cro.md`, `references/checkout-cro.md`. Tests, low-traffic designs, rollouts and the log entry: `references/experiments.md`. Full funnel: one synthesis, in funnel order.

## Output

**Recommend, don't ship**: never edit application code; implementation returns to the caller, via screen-design for a changed in-product screen.

**Files** (with file-write; otherwise inline), defaults the caller may redirect: the analysis to `biz/growth/cro/{page-or-flow}-analysis.md`; one test card (`references/experiments.md`) per test, designed or concluded, in the experiment log `biz/growth/experiments.md`. Update both in place.

**Template** — budget by class: Quick question ≤150, no template; Dropped ≤400; Low, Review without data, Add a popup or form: one surface ≤600, full funnel or test roadmap ≤1,200 plus cards, ≤7 actions (roadmaps add program impact: `references/experiments.md` § Sizing); Redesign ≤800; Design a test: the card (≤320) plus ≤150 words (why this design; at low traffic, the priced options and the fallback). Material findings go in past the budget, one line each, overrun noted. Sections are a menu: omit what doesn't apply, heading included. Plain sentences for the named reader, verdict first; no method jargon, coined labels or unfilled brackets; never narrate this method.

```markdown
## [Page or flow]: [the verdict in one sentence]
### What's happening
- [The result that matters (e.g. paid signups): rate, weekly volume, measurement gap; where it leaks; outcomes lost a week]
- [Why, how sure, the evidence: seen in your data | proven here before | common practice, unproven here]
### What to do, ranked
1. [Action] ([fix now | test (who sees it, decision date; full card in the log) | roll out against a comparison, with a rollback trigger | research first]); owner [role]; judged on [primary]; guardrails [metric, threshold]; [what this validation can't see]
### Decisions needed (when the request names an audience or deadline)
- [Decision]: [who], by [when]; if undecided, [default]
### Copy direction (final variants: copywriting)
- [Element]: [what fails] → [angle]; source [traffic]; proof [user-supplied only]
### Field set or steps (redesign only; each removed item: what it protected → its replacement)
### Screens affected (spec: screen-design)
### Not recommended (≤3, with why)
### Assumptions and open questions
- [Default applied] → [question]; numbers that would re-rank the list: [2–3]
```

## Self-Review

- Outcome count reconciled with the system of record, gap stated, before any funnel number is used.
- Each action: class, owner, plain-worded evidence (no lone replay, ticket or quote as observed), an outcome-per-exposed-user metric; observed outranks best-practice of similar size.
- Each test, rollout and holdout: a comparison (never a plain before/after), numeric guardrail thresholds, the breach action, its miss rate for the smallest loss worth catching.
- No "no test" until every rung is priced in weeks; the best learning design first, the rollout as fallback.
- Each card: N sized for its metric and kind (revenue, A/B/n, non-inferiority), outcome window from first exposure, Ships filled; Eligible, Multiplicity, Calendar and Checks filled or n/a with why; no settled test repeated.
- An outside cause leads, handed off with evidence, size, owner and judging metric; scope cuts named, with why.
- No defect filed as a Test or fixed in one arm only; bundles name what they can't attribute; costly treatments have holdouts.
- Each removed field, step or check names what it protected and its replacement.
- Nothing the user didn't supply (lifts, counts, quotes, testimonials); no benchmark as a target; copy only as direction; nothing that works only if unnoticed.
- Defaults listed under Assumptions with their questions; a named audience or deadline gets Decisions needed.
- **Footprint**: within the class's budget, or over only for material findings, overrun noted; list items cut before evidence.
