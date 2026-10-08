# Email Deliverability

Getting wanted mail into the inbox and keeping the domain able to do it. Reputation works like a budget: every complaint, bounce and unread send draws on it, and only mail people act on rebuilds it, slowly.

Last verified: 2026-10. Provider rules change: before a large launch, re-check Google's email sender guidelines and FAQ, Yahoo's sender best practices and Microsoft's sender requirements.

Name the job first. **Setup:** a new domain, ESP or stream. **Triage:** placement or engagement dropped (start at Triage below). **Policy:** suppression, consent, sunset. While diagnosing, change one thing at a time.

## Provider rules (the floor)

| Provider | Rule |
|---|---|
| Gmail, every sender | SPF or DKIM; valid forward and reverse DNS; TLS; spam rate under 0.3% |
| Gmail, bulk: ~5,000+ messages to Gmail accounts in 24 hours, counted across the primary domain and its subdomains; the status is permanent | SPF and DKIM; DMARC (p=none allowed) aligned with one of them; one-click unsubscribe on marketing and subscribed mail plus a visible unsubscribe link; spam rate below 0.1%, never reaching 0.3%. At 0.3% or above, mitigation is unavailable until the rate stays under it for 7 consecutive days. Since November 2025 non-compliant mail gets temporary and permanent rejections |
| Yahoo | The same playbook with no published volume threshold: unsubscribes honored within 2 days, spam rate below 0.3%; enrolling DKIM domains in its Complaint Feedback Loop is recommended |
| Microsoft consumer (Outlook.com, Hotmail, Live) | Domains sending 5,000+ a day need SPF, DKIM and aligned DMARC (since 2025-05-05); non-compliant mail is junked or rejected with 550 5.7.515. Microsoft 365 business tenants filter separately |
| Others | Regional providers apply their own filters; check them when they hold a large share of the list |

## Setup

1. **Inventory every sender.** ESP, product, billing, helpdesk, CRM and calendar tools all send as your domain. Publish DMARC at p=none with aggregate reports (rua) and read 2-4 weeks of them before tightening anything.
2. **Authenticate each source,** aligned with the From domain: SPF (at most 10 DNS lookups, beyond which SPF fails outright) and DKIM (2048-bit where supported; Gmail's floor is 1024), plus a custom return-path.
3. **Enforce DMARC in steps.** Leave p=none only when every legitimate source passes aligned, then move to quarantine and then reject, reading reports at each step. DMARC is now RFC 9989 (May 2026), which replaced RFC 7489: there is no `pct` ramp; trial a stricter policy with `t=y`, and set the policy for non-existent subdomains with `np=`. Domains that send no mail get p=reject and a null SPF record (`v=spf1 -all`) now.
4. **Separate streams.** Transactional, lifecycle and marketing mail each get their own subdomain and From address; cold outreach gets a separate registered domain (`references/email/cold-outreach.md`). Break: below a few thousand sends a month, two streams (transactional, everything else) are enough. Subdomains separate the signals you diagnose with but don't lower Gmail's bulk count. Marketing never sends from the subdomain or From address that carries transactional mail (password resets, receipts, alerts): Gmail's Manage subscriptions unsubscribes a user from all of a sender's lists at once and sends that sender's later mail to spam.
5. **One-click unsubscribe (RFC 8058)** on every stream a reader can leave, never on transactional mail: a `List-Unsubscribe` HTTPS URI that identifies recipient and list, plus `List-Unsubscribe-Post: List-Unsubscribe=One-Click`, both signed by DKIM; the endpoint takes a POST with no cookies, login or redirect; honor it within 2 days.
6. **Monitoring:** Google Postmaster Tools (spam rate, compliance status, delivery errors), Microsoft SNDS and JMRP, Yahoo's feedback loop, and the DMARC aggregate reports.
7. **BIMI** is a brand extra, not a deliverability fix: it needs DMARC at quarantine or reject on all mail and a paid, recurring mark certificate (a VMC requires a registered trademark).

## Ramp

For a new domain, IP or ESP, or a large volume jump: start with the most engaged recipients (recent clickers, product-active users) and raise volume 1.5-2× per step only while spam rate, deferrals and bounces stay clean; hold or step back when they don't. Send a one-off blast to the whole list (a launch, a policy change) in waves over several hours, most engaged first. Take a dedicated IP only at sustained, steady high volume; below that, a well-run shared pool carries you better.

## Suppression

| Event | Suppress from |
|---|---|
| Hard bounce | Everything, immediately |
| Spam complaint | All non-transactional streams |
| Unsubscribe through a stream's own link or preference center | That stream; the page also offers "all marketing", which CAN-SPAM requires of any opt-out menu |
| Unsubscribe through the mailbox's own control (one-click, Gmail's Manage subscriptions) | All marketing streams: the reader can't see your streams from the inbox |
| Past the sunset rule | Marketing streams |

Never suppress transactional mail on an unsubscribe: password resets, receipts and security alerts must still arrive. Keep one suppression list, synced within 2 days across every ESP, sending tool and the product database. A suppressed address returns only with a new, recorded opt-in.

## Sunset

Sunset marketing mail after ~10-15 consecutive sends without a click or reply, never sooner than 90 days and never later than 12 months, after one re-engagement attempt (`references/email/sequence-templates.md`). Product activity doesn't count here: it keeps someone on lifecycle and transactional streams, not on marketing. Recycled spam traps never click, so the sunset removes them too.

## Consent

- Consent is per stream. Transactional mail needs none; lifecycle mail rides the account relationship where the law allows; marketing needs its own opt-in or a lawful soft opt-in (country rules: the law table in `references/email/cold-outreach.md`). Never bundle it into accepting the terms, and never pre-tick it.
- Declined or unknown means no, for anyone who gave you their address: whoever unticked marketing at signup, or has no consent record, gets transactional and lifecycle mail only, even where the law would allow marketing (cold prospecting: `references/email/cold-outreach.md`). Ask again in the product at a moment of value, never by email to people who declined or whose consent you can't show: an email asking for marketing consent is itself marketing (UK ICO fines against Flybe and Honda, 2017).
- Record proof for every opt-in: timestamp, source form, the exact text shown, IP address.
- Use double opt-in where you must prove consent (standard practice in Germany) or where signups attract typos and bots.
- Never mail a bought or rented list. Re-permission addresses with no engagement in 12+ months before a campaign, and schedule any periodic reconfirmation the law table requires.

## Message hygiene

- A plain-text part with every HTML message; the message reads fully with images off.
- Links on your own branded tracking domain, never a shared ESP domain or a URL shortener: every linked domain carries reputation.
- Reply-to is a monitored inbox, never noreply@: replies are a positive signal, and some of them are unsubscribe requests.
- Gmail clips HTML bodies over ~102KB, hiding the footer and its unsubscribe link.
- No fake "Re:" or "Fwd:", no attachments on marketing mail, and a postal address on commercial mail (CAN-SPAM).

## Triage: "our mail goes to spam"

1. **Split by mailbox provider.** One provider down means placement there; all providers down means audience, content or offer (Diagnosis in `references/email/guide.md`).
2. **Read a real message's Authentication-Results header** at the affected provider: SPF, DKIM and DMARC pass, aligned to the From domain.
3. **Read the deferral and bounce text** in the ESP logs: Gmail's 4.7.x and 5.7.x replies name the cause (rate limit, authentication, reputation).
4. **Check the provider's own data:** Postmaster Tools spam rate and compliance status; SNDS and JMRP for Microsoft. ESP complaint counts miss Gmail, which reports complaints only in aggregate, so a near-zero ESP rate can sit beside a high Postmaster rate.
5. **List what changed in the last 14 days:** volume, list source, ESP or IP, link or tracking domain, template, cadence.
6. **Recover:** mail only recent clickers and product-active users, then ramp 1.5-2× per step while spam rate and deferrals stay clean. Content scorers and seed lists check authentication and content, not placement at Gmail, which filters per user.

Gmail's Promotions tab is the inbox, not spam: never strip a marketing email of its images, links or offer to dodge the tab.

Act at: a Gmail spam rate of 0.1% → find the cause this week; 0.3% → mail Gmail only recent clickers until the rate holds under 0.3% for 7 days; hard bounces above 2% of a send → pause that list source; unsubscribes above ~2× your trailing median → check frequency and relevance.
