# Cold Email Outreach

B2B cold email writing, personalization, and follow-up sequences.

---

## Table of Contents

1. [Legal & Compliance First](#legal--compliance-first)
2. [Writing Principles](#writing-principles)
3. [Voice & Tone](#voice--tone)
4. [Structure Frameworks](#structure-frameworks)
5. [Subject Lines](#subject-lines)
6. [Follow-Up Sequences](#follow-up-sequences)
7. [Quality Check](#quality-check)
8. [What to Avoid](#what-to-avoid)
9. [Benchmarks](#benchmarks)


## Legal & Compliance First

Cold email is restricted differently in different jurisdictions. **Verify the rules for every region you send into before launching.** Non-compliance risks fines, sender-reputation damage, and platform bans. Below is a 2026 baseline summary — not legal advice.

| Jurisdiction | Key Rule (B2B cold email) |
|---|---|
| **US — CAN-SPAM** | Allowed without prior consent. Must include: accurate From/Reply-To, identifiable subject, physical postal address, working opt-out (process within 10 business days), no header forgery. |
| **Canada — CASL** | **Explicit or implied consent required** even for B2B. "Implied consent" includes existing business relationships or publicly-posted business addresses (with limits). Penalties up to CAD $10M. |
| **UK — UK GDPR + PECR** | PECR's electronic-mail marketing rule does **not** apply to corporate subscribers (limited companies, LLPs, Scottish partnerships, public bodies) — no consent needed under PECR to email a corporate body. UK GDPR still applies because a named individual's address (`john@company.com`) is personal data, so document a legitimate-interest basis (LIA) and offer easy opt-out. Sole traders and most partnerships count as individual subscribers — PECR consent (or the soft opt-in exemption) is required. |
| **EU — GDPR + national ePrivacy** | ePrivacy is transposed per member state and varies materially. Several states (e.g. Germany via UWG §7, with double opt-in the de facto standard; France/CNIL; Netherlands) require **prior consent** even for B2B email to named individuals. A GDPR legitimate-interest basis does **not** cure an ePrivacy consent requirement. Verify the specific country before sending — don't assume legitimate interest is available. |
| **Australia — Spam Act 2003** | Express or inferred consent required. Penalties scale with volume. |
| **Brazil — LGPD** | Treats email outreach to natural persons as personal data; needs lawful basis (consent, legitimate interest with LIA, etc.). |

**Common requirements across most jurisdictions:**
- Identify yourself and your company truthfully
- Provide a working, no-friction opt-out — honor it within the CAN-SPAM legal maximum of 10 business days (and, for bulk marketing mail subject to Gmail/Yahoo/Microsoft rules, process one-click List-Unsubscribe within 2 days; see `references/email/deliverability.md`)
- Don't disguise commercial intent in the subject or body
- Maintain a suppression list across all your sending tools (see `references/email/deliverability.md` — Suppression-List Management)
- Document your basis for sending (LIA, consent record, business relationship evidence)

> **Mailbox-rotation warning:** Tools that send via many fresh mailboxes/subdomains to scale cold outreach increasingly trip Gmail/Microsoft anti-spam heuristics (and may violate provider ToS). Treat rotation as a deliverability *bandaid*, not a strategy — and verify provider ToS before adopting.

---

## Writing Principles

### Write Like a Peer, Not a Vendor
The email should read like it came from someone who understands their world. Use contractions. Read it aloud. If it sounds like marketing copy, rewrite it.

### Every Sentence Must Earn Its Place
Cold email is ruthlessly short. If a sentence doesn't move toward replying, cut it.

### Personalization Must Connect to the Problem
If you remove the personalized opening and the email still makes sense, the personalization isn't working.

### Lead with Their World, Not Yours
"You/your" should dominate over "I/we." Don't open with who you are.

### One Ask, Low Friction
Interest-based CTAs ("Worth exploring?") beat meeting requests. One CTA per email.

---

## Voice & Tone

**Target voice:** A smart colleague who noticed something relevant.

**Calibrate to audience:**
- C-suite: ultra-brief, peer-level, understated
- Mid-level: more specific value, slightly more detail
- Technical: precise, no fluff, respect their intelligence

**Never sound like:**
- A template with fields swapped in
- A pitch deck in paragraph form
- An AI-generated email ("I hope this finds you well," "leverage," "synergy")

---

## Structure Frameworks

| Framework | Shape |
|-----------|-------|
| **Observation → Problem → Proof → Ask** | You noticed X → usually means Y challenge → we helped Z → interested? |
| **Question → Value → Ask** | Struggling with X? → We do Y, Z saw [result] → worth a look? |
| **Trigger → Insight → Ask** | Congrats on X → that creates Y challenge → we've helped similar companies |
| **Story → Bridge → Ask** | [Company] had [problem] → solved it this way → relevant to you? |

---

## Subject Lines

- 2-4 words, lowercase, no punctuation tricks (the general marketing subject-line length in `references/email/copy-guidelines.md` does not apply to cold)
- Should look like it came from a colleague ("reply rates," "hiring ops")
- No product pitches, urgency, emojis, or prospect's first name

---

## Follow-Up Sequences

Each follow-up must add something new — different angle, fresh proof, useful resource.

- 3-5 total emails, increasing gaps between them
- Each email should stand alone
- The breakup email is your last touch — honor it
- Never "just checking in"

### Cadence Example

| Email | Timing | Approach |
|-------|--------|----------|
| 1 | Day 0 | Opening — observation + value |
| 2 | Day 3 | New angle — case study or social proof |
| 3 | Day 7 | Resource — share something useful |
| 4 | Day 14 | Different value prop angle |
| 5 | Day 21 | Breakup — final, graceful close |

---

## Quality Check

Before sending, gut-check:
- Does it sound like a human wrote it?
- Would YOU reply to this?
- Does every sentence serve the reader, not the sender?
- Is the personalization connected to the problem?
- Is there one clear, low-friction ask?
- If drafted with AI then scaled, has a human reviewed this exact send? (AI tells — "I hope this finds you well," "leverage," "synergy" — and near-identical mass copy both read as spam.)

---

## What to Avoid

- Opening with "I hope this email finds you well" or "My name is X"
- Jargon: "synergy," "leverage," "circle back," "best-in-class"
- Feature dumps — one proof point beats ten features
- HTML, images, or multiple links
- Fake "Re:" or "Fwd:" subject lines
- Asking for 30-minute calls in first touch
- "Just checking in" follow-ups

---

## Benchmarks

> **Open rate caveat (post-MPP, post-Gmail/Yahoo enforcement 2024):** Open rate is unreliable for recipients who read in the Apple Mail app with MPP (pre-fetched pixels — MPP affects roughly 55-60% of all opens per Litmus, 2026). Prioritize **reply rate and meeting-booked rate** for cold-outreach health.

| Metric | Typical | Good |
|--------|---------|------|
| Open rate (directional only) | ~44% platform average (Instantly 2026; MPP-inflated — not a health metric) | — |
| **Reply rate (primary signal)** | ~3.4% platform average (Instantly 2026) | 5.5%+ (top quartile); 10%+ (elite) |
| Positive reply rate | 1-3% (practitioner rule of thumb) | 3-5%+ |
| Meeting booked rate | 0.5-2% (practitioner rule of thumb) | 2-3%+ |

> Dated benchmark (as of 2026-10): reply and open figures are from Instantly's 2026 cold-email benchmark report (vendor platform data); the positive-reply and meeting rows have no primary source. Re-check before quoting and benchmark against your own baseline. Pre-2022 "30-40% open / 5-10% reply" benchmarks no longer apply — Gmail/Yahoo enforcement (Feb 2024) tightened bulk sender rules, MPP inflated/distorted opens, and inbox saturation grew.
