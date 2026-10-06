# Email Marketing

Strategy, sequence design, and execution for email marketing across SaaS lifecycle stages (welcome, nurture, onboarding, re-engagement, win-back, newsletters, cold outreach, subject lines, deliverability).

**Scope:** in-app copy goes to the copywriting core (`SKILL.md`); popup/modal design to the cro skill; churn-specific emails such as dunning to the churn-prevention skill; analytics to the product-analytics skill.

---

## Email Marketing Framework

### 1. Assess
- **Sequence type**: Welcome, nurture, onboarding, re-engagement, win-back, cold outreach?
- **Audience context**: Where are they in the journey? What do they know? What do they need?
- **Goals**: Activation, conversion, retention, re-engagement, sales?

### 2. Core Principles

- **One Email, One Job** — Every email has exactly one purpose and one CTA. When an email tries to do two things, neither gets done well — and you can't tell from metrics which one failed. If you need to accomplish two goals, that's two emails.

- **Value Before Ask** — Provide value in early emails before asking for conversion. People ignore emails from senders who only take. The first 2-3 emails in any sequence should make the reader's life better with zero strings attached — that builds the trust that makes later conversion emails work.

- **Relevance Over Volume** — Better to send fewer, targeted emails than many generic ones. Every irrelevant email trains the reader to stop opening your emails. One well-timed, behavior-triggered email outperforms five time-based blasts.

- **Clear Path Forward** — Every email tells the reader exactly what to do next. Ambiguity kills action. If the reader finishes your email thinking "nice, but what now?", the email failed regardless of how good the copy was.

### 3. Sequence Strategy
- **Length**: Match sequence length to the buying cycle (SaaS trial: 5-7 emails, Enterprise: 8-12)
- **Timing**: Respect frequency. Day 0, 1, 3, 5, 7 for intensive onboarding. Weekly for nurture.
- **Subject lines**: Curiosity > benefit > urgency. Keep them tight — 40-60 characters, with ~35-40 visible on mobile (see `references/email/copy-guidelines.md`). Test personalization.
- **Preview text**: Complement the subject line, don't repeat it. Use as a second hook.

### 4. Segmentation & Engagement Tiers

- **Segmentation axes (send-side):** lifecycle stage, activation/Aha state, plan tier, engagement recency, behavioral trigger, persona/industry. "Segment harder" in the diagnosing table means cutting along one of these axes — not blasting the whole list.
- **Engagement tiers:** treat the list as `engaged (0-30d)`, `cooling (31-90d)`, `dormant (90d+)`. Mail engaged segments most freely, throttle cooling, route dormant into re-engagement then sunset (see `references/email/deliverability.md` — List Hygiene and Consent Capture).
- **Dynamic blocks vs separate sends:** use dynamic content blocks (e.g. case study by industry) when the core message is shared; split into separate sends when the goal or CTA differs by segment.
- Cohort/segment **analysis** (who retains, why) belongs to the product-analytics skill; this section owns the email-sending *application* of segments.

### 5. Send Timing & Frequency Governance

- **Frequency cap:** set a per-user marketing cap (~3-5 marketing emails/week, tighter for cooling/dormant tiers). Exceeding it is the upstream cause of the ">0.5% unsubscribe" and complaint-rate rows in the diagnosing table.
- **Priority when a user qualifies for multiple sends:** behavioral/lifecycle-triggered > broadcast/promo. Hold marketing sends while a user is in an active onboarding or transactional-critical branch.
- **Always exempt transactional and dunning** from the cap (dunning itself is owned by the churn-prevention skill).
- **Wall-clock:** send at recipient-local time where the ESP supports it; use built-in send-time optimization as a directional aid, not a substitute for relevance. Day-of-week and region matter for broadcasts; behavior-triggered emails fire when the trigger occurs regardless of clock. Define explicit send windows for global lists.

---

## When to Use Which Reference

| Scenario | Reference |
|----------|-----------|
| Designing sequence flows and timing | `references/email/sequence-templates.md` |
| Writing email copy, subject lines, CTAs, A/B test design | `references/email/copy-guidelines.md` |
| Catalog of email types by lifecycle category (triggers and goals) | `references/email/email-types.md` |
| B2B cold outreach and follow-ups | `references/email/cold-outreach.md` |
| Deliverability, DNS, warm-up, list hygiene | `references/email/deliverability.md` |

---

## Sequence Design Process

1. **Define the goal** — One clear outcome for the entire sequence
2. **Map the flow** — Each email's job and how it connects to the next
3. **Add branch points** — Where should the sequence split based on user behavior? (See `references/email/sequence-templates.md` for branching patterns)
4. **Set timing** — Delays between emails based on urgency and user behavior
5. **Write emails** — Use `references/email/copy-guidelines.md` for structure and tone
6. **Set up measurement** — Track clicks, conversions, unsubscribes per email (opens directional only). Tag email links with UTMs so the product-analytics skill can attribute conversions; per-send engagement lives in the ESP, cohort/retention analysis goes to product-analytics. Sync unsubscribes/complaints/bounces to a global suppression list (see `references/email/deliverability.md`).

---

## Default Output Format

**Output:** when asked to save a sequence/campaign and a file-write capability is present, write to the email content dir (default `biz/marketing/content/email/`; caller may redirect the `biz/<area>/` root) — otherwise return inline. If the file already exists, update it in place rather than creating a duplicate.

**Drafts only.** Never send, schedule, or activate an email, campaign, or automation (in an ESP or otherwise) without the caller's explicit approval — produce the drafts and hand them back.

When creating email sequences, produce this structure unless the user requests something different:

### Sequence Overview
```
Sequence: [Name]
Trigger: [What starts the sequence]
Goal: [Primary outcome]
Length: [N emails over N days]
Timing: [Delay between emails]
Exit conditions: [When someone leaves the sequence early]
Branch points: [Key decision points based on user behavior]
```

### Per Email
```
Email [#]: [Name]
Send: [Timing / trigger]
Subject: [Subject line]
Preview: [Preview text]
---
[Full email copy]
---
CTA: [Button text] → [Destination]
Branch: [If applicable — what happens based on action/inaction]
Segment/Conditions: [If applicable]
```

For strategy-only requests (no copy), produce the overview table with timing, purpose, and subject line direction per email — skip full copy.

---

## Diagnosing Email Problems

> **Open-rate caveat (Apple Mail Privacy Protection):** Apple Mail accounts for roughly 62% of email opens, and MPP affects roughly 55–60% of all opens (Litmus email client market share, July 2026 data — re-check before quoting). For recipients who open in the **Apple Mail app with MPP enabled** (default-on since iOS 15, Sept 2021), Mail pre-fetches the tracking pixel via proxy and registers an "open" whether or not the message was read — inflating open rates and making them an **unreliable** primary signal. MPP keys on the Apple Mail *app* (on any device), not on Apple hardware: someone reading in the Gmail app on an iPhone is unaffected. Treat open rate as directional only; **prioritize click rate, reply rate, and conversion rate** for diagnosis.

**Metric definitions (the denominator matters):** rates below use **delivered** as the denominator unless noted — click rate = unique clicks / delivered; reply rate = replies / delivered; unsubscribe rate = unsubscribes / delivered; complaint rate = complaints / delivered (Google Postmaster's spam rate uses inbox-delivered, excluding mail already filtered to spam); bounce rate = bounces / sent. CTOR (clicks / unique opens) inherits opens' MPP unreliability — use it only directionally.

When metrics are underperforming, the problem usually lives in a specific layer. Work top-down:

| Symptom | Likely cause | What to check |
|---------|-------------|---------------|
| Low click rate (<2% of delivered) | Subject line, deliverability, OR copy | Click rate is the most reliable engagement signal post-MPP. Check inbox placement via Google Postmaster Tools / mail-tester. If deliverable, the subject + preview text + body aren't earning attention. |
| Opens reported but no clicks | Copy or CTA mismatch (or MPP false opens) | The email isn't delivering on the subject line's promise, the CTA is unclear/high-friction — or "opens" are MPP pre-fetches and the email was never actually read. Cross-check with reply rate / link clicks. |
| Clicks but no conversion | Landing page or offer | The email did its job — the problem is downstream. Check landing page alignment with email promise. |
| High unsubscribe (>0.5%) | Frequency or relevance | Sending too often, or content doesn't match what they signed up for. Segment harder or reduce frequency. (0.3-0.5% is a caution band — not yet "high" but worth watching; see `references/email/deliverability.md` — Healthy List Indicators.) |
| Low reply rate on cold (below the ~3.4% 2026 platform average) | Personalization or ask | The email reads like a template or asks too much. See `references/email/cold-outreach.md` (Benchmarks). |
| Declining click rates over time | List fatigue | Start re-engagement on declining clicks; sunset/remove non-clickers after 90 days if re-engagement fails (don't rely on opens). |
| Spam complaint rate > 0.1% | Relevance, frequency, or consent | Google's rule: keep complaint rate under 0.1%; reaching 0.3% or higher causes graduated delivery damage and loss of mitigation eligibility (Google Postmaster Tools). Audit how recipients consented (see `references/email/deliverability.md` — Consent Capture) and how often you send. See also its Gmail / Yahoo / Microsoft Sender Requirements section. |

---

## Tool Integrations

| Tool | Best For |
|------|----------|
| Customer.io | Behavior-triggered sequences, SaaS onboarding |
| Mailchimp | Newsletter, simple automations |
| Resend | Transactional + marketing for developers |
| SendGrid | High-volume transactional email |
| Kit (ConvertKit) | Creator-focused email marketing |
| Loops | SaaS lifecycle email — marketing + product + transactional in one, native Stripe triggers |
| Postmark | Deliverability-critical transactional (separate transactional/broadcast streams) |

---
