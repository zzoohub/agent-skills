# Email Deliverability

Getting emails into the inbox instead of spam. None of the copy or strategy guidance matters if your emails aren't being delivered.

> **Last reviewed:** 2026-05. Deliverability rules change — verify against current Google Postmaster Tools / Yahoo / Microsoft sender guidelines before any large-volume launch.

---

## Table of Contents

1. [Why Deliverability Matters](#why-deliverability-matters)
2. [Gmail / Yahoo / Microsoft Sender Requirements (mandatory for bulk senders)](#gmail--yahoo--microsoft-sender-requirements-mandatory-for-bulk-senders)
3. [DNS Authentication](#dns-authentication)
4. [Domain & IP Warm-Up](#domain--ip-warm-up)
5. [Consent Capture](#consent-capture)
6. [List Hygiene](#list-hygiene)
7. [Spam Trigger Avoidance](#spam-trigger-avoidance)
8. [Monitoring](#monitoring)
9. [Cold Email Deliverability](#cold-email-deliverability)


## Why Deliverability Matters

Email providers (Gmail, Outlook, etc.) use sender reputation, authentication, and engagement signals to decide whether your email reaches the inbox, lands in the promotions tab, or goes straight to spam. A sender with bad reputation can have 30-50% of emails silently dropped. Most senders don't realize this is happening because bounce rates only measure hard bounces, not spam filtering.

---

## Gmail / Yahoo / Microsoft Sender Requirements (mandatory for bulk senders)

If you send **5,000+ messages per day** to a given provider's addresses (Gmail and Yahoo since Feb 2024; Microsoft consumer mailboxes since May 5, 2025), you must comply with these rules or get throttled/rejected. The 5,000+/day threshold is evaluated per-provider. Non-bulk senders should still follow them — they're now the baseline.

### Authentication (all required)
- **SPF** and **DKIM** must both be set up and pass, and the From: domain must be **aligned with at least one of them** (DMARC alignment — relaxed alignment, i.e. same organizational domain, is enough). Aligning both is recommended, but only one is required.
- **DMARC** policy of at least `p=none` published on the From: domain.
- Yahoo follows the same playbook. **Microsoft** (Outlook.com, Hotmail.com, Live.com) enforces the same SPF + DKIM + DMARC (p=none minimum, aligned with SPF or DKIM) for senders of 5,000+/day to its **consumer** mailboxes as of May 5, 2025 — non-compliant mail is rejected with `550 5.7.515 Access denied`. This does not apply to enterprise Microsoft 365 tenants.
- As of late 2025, Gmail moved from soft enforcement to active SMTP-level deferrals/rejections (4xx/5xx) of non-compliant bulk mail — compliance is no longer optional.

### One-Click Unsubscribe (RFC 8058)
Mandatory headers for marketing/promotional mail:
```
List-Unsubscribe: <https://yourapp.com/unsub?u=...>, <mailto:unsub@yourapp.com>
List-Unsubscribe-Post: List-Unsubscribe=One-Click
```
- Unsubscribe must process the request without requiring a login or extra confirmation page.
- Unsubscribe within **2 days** maximum.

> **Transactional vs marketing:** transactional/relationship mail (receipts, password resets, security alerts, account/billing notices) is exempt from the opt-out / one-click-unsubscribe requirement and from marketing consent — which is why these headers are scoped to marketing/promotional mail. **Warning:** under the FTC "primary purpose" test, a receipt or reset that carries a promotion is reclassified as commercial and loses the exemption. Send transactional and marketing on separate streams/subdomains so a marketing reputation problem can't sink critical transactional delivery like password resets.

### Spam Complaint Rate Cap
- Keep the complaint rate **below 0.1%** (target) and **never let it reach 0.3% or higher** (measured in Google Postmaster Tools).
- Spam-rate impact is graduated — there is no single clean cutoff. Reaching 0.3% or higher sharply degrades inbox delivery and makes you ineligible for Gmail delivery mitigation until you stay under 0.3% for 7 consecutive days (per Google's Email sender guidelines).

### Valid From, Reply-To, return-path
- All authenticated and resolvable.
- No spoofed reply-to that goes nowhere.

### Practical Checklist (Gmail/Yahoo/Microsoft baseline)
- [ ] SPF set up and passing for the sending domain
- [ ] DKIM signs with a key of at least 1024 bits (2048-bit recommended where your DNS provider supports it)
- [ ] From: domain DMARC-aligned with SPF or DKIM (at least one)
- [ ] DMARC published at `p=none` (or stricter) with `rua=` reporting
- [ ] `List-Unsubscribe` + `List-Unsubscribe-Post: List-Unsubscribe=One-Click` on every marketing email
- [ ] One-click unsubscribe endpoint processes the POST without login
- [ ] Google Postmaster Tools account set up; complaint rate monitored weekly — daily during warm-up or volume changes; a single-day jump past ~0.2% → pause marketing sends and audit before resuming
- [ ] All marketing sent from a subdomain (e.g., `mail.yourapp.com`), not root

### Downstream Benefit: BIMI
Once DMARC is at `p=quarantine` or `p=reject` (and you have a Verified Mark Certificate), Gmail/Yahoo/Apple Mail can display your brand logo next to the sender — a real trust signal. Optional but cheap once DMARC is enforced.

---

## DNS Authentication

These three records prove to email providers that you're allowed to send email from your domain. Without them, your emails look like they could be spoofed — and inbox providers treat them accordingly.

### SPF (Sender Policy Framework)
- DNS TXT record that lists which servers can send email on behalf of your domain
- Include your email service provider's servers
- Keep it simple — SPF has a 10 DNS lookup limit, and exceeding it silently fails

### DKIM (DomainKeys Identified Mail)
- Cryptographic signature that proves the email wasn't altered in transit
- Your email provider generates the keys; you add the public key as a DNS record
- Use a 2048-bit key where your DNS provider supports it; Gmail requires at least 1024 bits and recommends 2048 (Google Email sender guidelines)

### DMARC (Domain-based Message Authentication, Reporting & Conformance)
- Policy that tells receiving servers what to do when SPF/DKIM fail
- Start with `p=none` (monitor only), then move to `p=quarantine`, then `p=reject`
- Set up DMARC reporting to see who is sending email using your domain

### Verification Checklist
Most email providers (Customer.io, Resend, SendGrid, etc.) walk you through this during setup. Verify:
- [ ] SPF record includes your sending service
- [ ] DKIM is configured and verified
- [ ] DMARC policy is set (at minimum `p=none` with reporting)
- [ ] Custom return-path / envelope sender domain is configured
- [ ] Test with mail-tester.com or MXToolbox to confirm passing scores

---

## Domain & IP Warm-Up

New sending domains and IPs have no reputation. Email providers are suspicious of senders they haven't seen before. Sending a large volume from a cold domain triggers spam filters.

### Warm-Up Process
1. **Week 1**: Send 50-100 emails/day to your most engaged contacts (people who opened recently) — cold outreach starts lower (30-50/day per mailbox; see Cold Email Deliverability below)
2. **Week 2**: Double volume, still targeting engaged contacts
3. **Week 3-4**: Gradually increase volume and broaden audience
4. **Week 5+**: Full volume if engagement metrics look healthy

### Warm-Up Rules
- Only send to opted-in, engaged contacts during warm-up
- Monitor bounce rate (<2%), spam complaints (keep below the List Hygiene healthy bar of < 0.05%, and lower still during warm-up since you're sending only to engaged contacts), and click/engagement rates during each phase (treat opens as directional only, since Apple MPP inflates them)
- If metrics dip, slow down — don't push through bad signals
- Use a subdomain for marketing email (e.g., `mail.yourapp.com`) to protect your root domain reputation

---

## Consent Capture

Permission quality upstream determines complaint rate and deliverability downstream.

- **Single vs double opt-in:** double opt-in costs signup-conversion friction but yields cleaner lists, lower complaint rates, and stronger deliverability/legal footing (effectively expected for EU/CASL audiences). Single opt-in maximizes list growth where deliverability risk is low. Validate addresses at signup either way.
- **Separate consent by stream** — transactional vs product/lifecycle vs marketing newsletter. Don't fold marketing into transactional consent.
- **Record proof of consent** — timestamp, source/form, the opt-in text shown, and IP where applicable — for audit and compliance.
- **Re-permission stale or acquired lists** before mailing them; never import a purchased list.

(Opt-in form UI/conversion is the cro skill's domain; detailed legal bases live in `references/email/cold-outreach.md`.)

---

## List Hygiene

A dirty list tanks deliverability because bounces and spam complaints are the strongest negative signals.

### Regular Maintenance
- **Remove hard bounces immediately** — most providers do this automatically
- **Sunset inactive subscribers** — if someone hasn't clicked or engaged (replies, site activity) in ~60 days, move them to the re-engagement sequence (see `references/email/sequence-templates.md`); if they still don't engage by ~90 days, remove them. Don't sunset on opens alone — Apple Mail Privacy Protection inflates/auto-triggers opens, so opens are at best a fallback signal where click data is sparse.
- **Watch for spam traps** — recycled email addresses that ISPs use to catch senders with bad practices. They never click, never open. Regular list cleaning catches them.
- **Validate emails on signup** — use double opt-in or email validation APIs to prevent typos and fake addresses from entering your list

### Healthy List Indicators
| Signal | Healthy | Warning |
|--------|---------|---------|
| Hard bounce rate | < 0.5% | > 2% |
| Spam complaint rate | < 0.05% | > 0.1% |
| Unsubscribe rate | < 0.3% | > 0.5% |
| List growth rate | Positive | Shrinking |

The spam complaint rate above is an **internal hygiene target**; the **Gmail enforcement limit** is a different scale (< 0.1% target / 0.3% cliff — see the Gmail / Yahoo / Microsoft Sender Requirements section above).

### Suppression-List Management
- Maintain a **single global suppression list** as the source of truth, synced across every ESP and your product DB.
- Distinguish **global suppression** (unsubscribes, complaints, hard bounces — apply everywhere, including transactional unless legally exempt) from **per-stream suppression** (e.g. opted out of nurture but still receives onboarding).
- Propagate complaints, unsubscribes, and hard bounces to **all** tools, not just the one that sent the message.
- Hard rule: no tool may import or re-add a suppressed address.

---

## Spam Trigger Avoidance

Modern spam filters are sophisticated — they look at sender reputation, engagement, and content together. Single words rarely trigger spam on their own, but patterns do.

### Content Patterns to Avoid
- ALL CAPS in subject lines
- Excessive exclamation marks (!!!)
- Image-only emails with no text (spam filters can't read the image)
- URL shorteners (bit.ly, etc.) — they mask destinations and look suspicious
- Large attachments — use links to hosted files instead
- Misleading subject lines ("Re:" or "Fwd:" when it's not a reply)

### Structural Best Practices
- Include a plain-text version alongside HTML
- Include a visible, working unsubscribe link (required by law, and hiding it hurts reputation)
- Include your physical mailing address (CAN-SPAM requirement)
- Keep HTML clean — avoid copy-pasting from Word/Docs which adds hidden markup
- Maintain a healthy text-to-image ratio (at least 60% text)

---

## Monitoring

### Key Deliverability Metrics
| Metric | What it tells you |
|--------|------------------|
| Inbox placement rate | % of emails reaching inbox vs. spam (use tools like GlockApps or Inbox Monster) |
| Bounce rate | Hard = bad addresses, Soft = temporary issues |
| Spam complaint rate | Subscribers marking you as spam (most damaging signal) |
| Engagement rate | Opens + clicks — high engagement improves future deliverability |

### Google Postmaster Tools (v2)
Free tool from Google that reports how Gmail treats mail from your domain. Note: the old Domain/IP Reputation dashboards (the High/Medium/Low/Bad rating) were retired in the v1→v2 transition (rollout/redirect from late 2025) — Gmail still evaluates reputation internally but no longer exposes that rating to senders. Monitor instead:
- **Compliance status** — whether your domain meets Gmail's bulk-sender requirements
- **Spam rate** — your most important signal: keep below 0.10% and never let it reach 0.30%
- **Authentication results** (SPF / DKIM / DMARC pass rates)
- **Encryption (TLS)** and **delivery errors**

If spam rate trends toward 0.30% or compliance status flags an issue, reduce volume immediately and send only to your most engaged segments until the metrics recover.

---

## Cold Email Deliverability

Cold outreach has stricter deliverability challenges because recipients didn't opt in.

- **Use a separate domain** — never send cold email from your main product domain
- **Warm the domain** for 2-3 weeks before any outreach
- **Keep volume low** — 30-50 emails/day per mailbox to start
- **Rotate sending accounts** — spread modest volume across multiple mailboxes, not fresh-mailbox rotation at scale (see the mailbox-rotation warning in `references/email/cold-outreach.md`)
- **Personalize meaningfully** — identical emails sent to many recipients look like spam to filters
- **Monitor replies and bounces daily** — fast feedback loops prevent domain damage
