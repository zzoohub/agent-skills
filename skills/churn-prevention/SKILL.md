---
name: churn-prevention
description: |
  Churn prevention, cancel flows, payment recovery, and customer health scoring.
  Carve-out: dunning emails ARE owned here, not copywriting (email).
  Use when: designing cancel flows, creating save offers, implementing dunning sequences,
  building customer health scores, reducing involuntary churn, diagnosing churn patterns,
  or when user mentions "churn", "retention", "payment failed", "payment recovery",
  "downgrade", "at-risk customers", "subscription cancellation", "why are users leaving".
  Do NOT use for: onboarding optimization (use cro); marketing email sequences including
  win-back (use copywriting — email); pricing/tier design, including a downgrade tier's cost
  (use pricing; "downgrade" here means a save-offer lower tier); or deep retention analytics
  — cohort analysis, retention curves, segmentation, Carrying Capacity, PMF, Aha-Moment
  (use product-analytics). This skill owns intervention-tied churn diagnosis:
  voluntary-vs-involuntary split, cancel-reason themes, at-risk scoring.
---

# Churn Prevention

Strategies for reducing both voluntary and involuntary churn through proactive intervention, cancel flow optimization, and payment recovery.

**Output:** Write the churn-prevention strategy to the growth docs root (default `biz/growth/churn-prevention.md`; caller may redirect the `biz/<area>/` root) and the dunning / payment-recovery playbook to `biz/growth/dunning.md`. If no file-write tool is present, return the content inline. Update an existing file in place rather than creating a duplicate.

---

## Churn Prevention Framework

### Understand Churn Types

**Voluntary churn** — Customer actively decides to cancel
- Causes: unmet expectations, found alternative, budget cuts, outgrew product
- Prevention: health monitoring, save offers, feature education, value reinforcement

**Involuntary churn** — Payment fails, customer didn't intend to leave
- Causes: expired card, insufficient funds, bank decline, billing errors
- Prevention: dunning sequences, card update prompts, retry logic
- **This is the easiest win** — often a large share (roughly 20-40%) of total churn

### Prevention Priority Order
1. Fix involuntary churn (dunning) — highest ROI, lowest effort
2. Identify at-risk users early (health scoring)
3. Intervene before they decide to cancel (proactive outreach)
4. Optimize the cancel flow (save offers, alternatives)

---

## When to Use Which Reference

| Scenario | Reference |
|----------|-----------|
| Cancel flow design, save offers, exit surveys, proactive retention | `references/cancel-flow-patterns.md` |
| Payment failure recovery, dunning emails, retry logic | `references/dunning-playbook.md` |

Read the relevant reference when you need implementation details for a specific area. The sections below provide the strategic framework.

---

## Core Principles

### Prevention > Recovery
Catch at-risk users before they decide to leave. A user considering cancellation has already emotionally detached.

### Respect the User's Decision
No dark patterns. Make cancellation possible (don't hide it). Offer alternatives, not obstacles. Trust builds re-subscription later.

### Understand WHY Before Offering Saves
Exit survey data should drive save offer design. Don't offer a discount to someone who found an alternative — offer a feature comparison instead. See the dynamic save offers table in `references/cancel-flow-patterns.md` for the full reason-to-offer mapping with primary and fallback offers.

### Involuntary Churn is the Easiest Win
Payment failures are mechanical problems with mechanical solutions. Fix these first before tackling harder voluntary churn.

---

## Compliance & Click-to-Cancel (2025-2026 landscape)

> **Not legal advice — verify against current law in every region you serve before launching any cancel flow.**

### US — FTC
- The FTC's federal "Click to Cancel" Rule was **vacated by the 8th Circuit on 2025-07-08** on procedural grounds (no preliminary regulatory analysis).
- The FTC submitted a draft Advance Notice of Proposed Rulemaking (ANPRM) on 2026-01-30 to restart the rulemaking with proper procedure.
- **Enforcement under existing unfair/deceptive-practices doctrine continues** (FTC Act §5, ROSCA, state UDAP laws). State AGs have also stepped up enforcement. There is no nationwide click-to-cancel mandate today — obligations come from the state patchwork below plus general UDAP enforcement.

### California — AB 2863 (Automatic Renewal Law amendments)
- **Effective 2025-07-01.** Applies to contracts entered into, amended, or extended on or after that date.
- **Same-medium cancellation** required: if a consumer signs up online, they must be able to cancel online with equal ease. No phone-only or in-person-only cancellation paths.
- "Click-to-cancel" button required for online cancellations; cannot obstruct or delay. (Presenting a skippable discount/save offer during cancellation is *not* an obstruction, provided a clear, conspicuous cancel option remains.)
- Expanded definitions of "automatic renewal" and "continuous service" cover **free trials and free-to-pay conversions**.
- **Express affirmative consent** to renewal terms required; records retained ≥3 years (or 1 year post-termination, whichever is longer).
- Enforcement by California AG, district attorneys, and private plaintiffs.

### New York — Click-to-Cancel Act (2025 Budget Bill)
- Signed 2025-05-09 as part of the state budget; **effective 2025-11-05**.
- Simple cancellation mechanism **as easy as the one used to consent, in the same medium**. If consent was online, cancellation must be online; in-person consent must also offer online or phone cancellation.
- Companies cannot impose unreasonable or unlawful conditions, refuse, obstruct, or unreasonably delay cancellation.
- **New York City** layers a municipal Click-to-Cancel Rule (DCWP) on top, **effective 2026-10-01** for auto-renewal and continuous-service subscriptions offered to NYC consumers: cancellation at least as easy as signup and in the same medium, clear disclosure, affirmative consent, renewal notices; enforced as a deceptive trade practice with per-violation fines.

### Other US states with auto-renewal rules
- **Colorado** (SB25-145): enacted 2025-08-06, but its requirements — including the one-step online cancellation link and the broadened coverage reaching B2B purchasers — apply from **2026-02-16**.
- **Vermont** (9 V.S.A. § 2454a): a long-standing auto-renewal law (enacted 2017, effective 2019) that already requires online/same-medium cancellation — *not* a 2025 law.
- **Illinois**: the current auto-renewal statute (815 ILCS 601, from 2000) does **not** mandate one-step online cancellation; a one-step online-cancel amendment (SB3562) cleared Senate committee and reached Senate 2nd Reading on 2026-03-12, with no enactment found as of 2026-10 — confirm enactment status before relying on it.

Other states impose analogous requirements. Confirm the current rule and effective date in every state you serve.

### EU / UK
- **EU:** The Unfair Commercial Practices Directive (2005/29/EC) and the Consumer Rights Directive (2011/83/EU), as implemented in national law, are the operative rules restricting deceptive cancellation "dark patterns" for ordinary subscription businesses today. The Digital Services Act additionally bans dark patterns but only for designated **online platforms** (Art. 25, which itself defers to the UCPD and GDPR where they already apply); the Digital Markets Act bans dark-pattern circumvention (Arts. 5(2), 13) only for designated **gatekeepers** (a handful of Big Tech firms) — neither reaches a typical SaaS seller. GDPR governs consent-specific dark patterns. A dedicated EU rule on subscription/cancellation dark patterns — the **Digital Fairness Act** — is planned (Commission proposal expected ~Q4 2026, may slip — confirm) but is NOT yet in force. Separately, Directive (EU) 2023/2673 adds a "withdrawal button" requirement to the Consumer Rights Directive for distance contracts concluded online, applying from 2026-06-19 (this concerns the statutory right of withdrawal, distinct from ongoing subscription cancellation). France's DGCCRF and other consumer-protection authorities (acting under national UCPD law) have stepped up enforcement on subscription-trap patterns since 2024-2025.
- **UK:** The DSA and DMA do **not** apply in the UK post-Brexit (they reach UK firms only when serving EU users). UK subscription-trap and dark-pattern rules sit under the **Digital Markets, Competition and Consumers Act 2024 (DMCC Act)** — its consumer-protection / unfair-commercial-practices provisions are in force from 2025-04-06 (CMA direct enforcement), and a dedicated subscription-contracts regime (cancel as easily as you signed up, auto-renewal reminders, cooling-off) was brought forward (announced 2026-08-10) to go live in **January 2027**; secondary legislation and CMA guidance were still unpublished as of 2026-10 — confirm the commencement date. UK GDPR also applies. Confirm separately.

### Practical cancel-flow checklist (compliance-safe)
- [ ] **Same-medium cancellation** — if signup was online, cancellation is online (no phone-only)
- [ ] **One-click path** — explicit "Cancel my subscription" button visible without forced multi-step survey
- [ ] **No required survey before cancellation** — surveys must be skippable
- [ ] **No required save-offer view** — offers are skippable, not blocking
- [ ] **Cancellation confirmed by email** with effective date
- [ ] **No re-enrollment without fresh affirmative consent**
- [ ] **Records of consent and cancellation retained** per applicable law (CA: 3 years minimum)
- [ ] **Clear cost disclosure** before any save offer
- [ ] **Refund/proration policy** at cancellation and downgrade defined and disclosed (verify jurisdictional obligations)

See `references/cancel-flow-patterns.md` for compliant UI patterns.

---

## Customer Health Score Framework

This section owns the **scoring-model design** (which signals, weights, and thresholds). The instrumented `biz/analytics/health-score.md` artifact and the live data pipeline that computes scores belong to a **product-analytics capability** (if available) — same methodology-vs-artifact split applied in § Churn Diagnosis.

Track these signals to identify at-risk users before they churn:

### Usage Signals
- Login frequency (declining = risk)
- Feature adoption breadth (using 1 feature vs 5)
- Time spent in product (declining trend)
- Key action completion rate

### Engagement Signals
- Email open/click rates (declining = disengagement)
- Support ticket patterns (many tickets OR zero tickets = risk)
- Community/forum participation
- Feature request activity

### Business Signals
- Payment failures or late payments
- Plan downgrades
- Seat/usage reduction
- Contract renewal timing

### Implementation

Use a weighted composite score whose components map 1:1 to the signal categories above, so you score exactly what you track. A good starting point (weights sum to 1.0):

```
Health Score =
  Usage score      × 0.40 +   (login frequency + feature-adoption breadth + time-in-product + key-action completion)
  Engagement score × 0.25 +   (email open/click + support-ticket pattern + community + feature-request activity)
  Business score    × 0.35     (payment/billing health + downgrade/seat trend + renewal proximity)
```

Each category score is the 0-100 average of its sub-signals; normalize raw data (e.g., logins per week) into scores using percentile ranks or simple thresholds based on your user base. These weights are starting points — calibrate them against your own retained-vs-churned cohorts.

**B2C/PLG vs B2B:** the default weights are tuned for B2C/PLG, where the user is the buyer and individual login/usage predicts churn. For B2B (especially sales-led, multi-seat, annual contracts) the economic buyer rarely logs in and churn surfaces at renewal or via seat contraction — down-weight login/usage and up-weight Business signals: seat trend, champion/power-user engagement, renewal proximity, and support/QBR cadence.

| Score | Status | Action |
|-------|--------|--------|
| 80-100 | Healthy | Nurture, upsell opportunities |
| 60-79 | At Risk | Proactive check-in, feature education |
| 40-59 | Declining | Intervention: success call, personalized help |
| 0-39 | Critical | Urgent: executive outreach, retention offer |

For risk signals with directional lead-time heuristics and proactive intervention triggers, see the "Churn Prediction & Proactive Retention" section in `references/cancel-flow-patterns.md`.

---

## Churn Diagnosis

This skill owns **operational churn diagnosis tied to intervention** — the split and the cancel-reason themes that drive save-offer and dunning design. For deep retention-cohort analysis, retention curves, segmentation, and Aha-Moment work, hand off to a **product-analytics capability** if available.

### Diagnose for intervention (owned here)
- **Voluntary vs involuntary?** Check the split first — the solutions are completely different (dunning/retry for involuntary; save offers + health monitoring for voluntary).
- **Cancel-reason themes** — group exit-survey data by reason to drive the dynamic save-offer mapping (see `references/cancel-flow-patterns.md`).

### Hand off to product-analytics (deep analysis)
Retention-cohort dimensions (time cohort, plan tier, acquisition channel, usage pattern), churn-rate-by-cohort trends, last-action-before-churn, and the "features retained users use that churned users don't" (Aha-Moment) gap are retention-analytics work — route those to a product-analytics capability if available.

### Churn Rate Benchmarks

Track **logo churn** (accounts/customers lost) separately from **revenue / net-dollar churn** (seat reductions, downgrades, contraction). Seat/usage contraction is silent revenue churn that logo-churn metrics miss; for usage- or seat-based billing, monitor contraction as its own motion alongside cancellations.

| Segment | Poor | Average | Good |
|---------|------|---------|------|
| B2C monthly | >8% | 5-8% | <5% |
| B2B monthly | >5% | 2-5% | <2% |
| B2B annual (logo churn) | >15% | 5-15% | <5% |

Annual logo churn varies sharply by segment (SMB-focused ~15-25%+, enterprise ~3-7%); a single flat row obscures this. Strict sources treat <5% as genuinely good and 5-7% as the enterprise "acceptable" floor.

---
