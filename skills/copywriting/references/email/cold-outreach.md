# Cold Email Outreach

B2B prospecting by email: who to write to, whether the law allows it, and the copy and sending rules that keep the domain alive. Output uses the Default Output Format in `references/email/guide.md`, bodies at most 80 words.

Last verified: 2026-10. Law rows and the benchmark change: re-check each source before a launch. A starting map, not legal advice.

## Before writing

- **Relevance test, per segment:** why this person, why now (a trigger you can cite: a hire, a launch, a funding round, a stack change, a public post), and why us (a result for a similar company). If any answer is generic, fix the list, not the copy.
- **Law:** classify every recipient country with the table below before the first send. Unknown country → treat it as opt-in.
- **Kill rule:** if positive replies stay under ~1% after ~300 delivered to one segment, change the segment or the offer before touching the copy.

## Consent law by country

The middle column is the legal floor for marketing to your own users, trial signups and former customers, not a permission: anyone who declined marketing, or whose consent you can't show, gets none, whatever the column allows (`references/email/deliverability.md` § Consent).

| Country | Own customers and signups (the floor) | Cold B2B | Source |
|---|---|---|---|
| US | Opt-out (CAN-SPAM) | Same: the Act has no B2B exemption | ftc.gov, CAN-SPAM compliance guide |
| Canada | Consent (CASL): express, or implied for 2 years after a purchase and 6 months after an inquiry | Implied only from a conspicuously published business address with no "no solicitations" notice, and only for mail relevant to the role | crtc.gc.ca |
| UK | Individuals and sole traders: opt-in, or soft opt-in (similar products, refusal offered at collection and in every email); company addresses as in the next column | Companies, LLPs and public bodies: no PECR consent, but UK GDPR legitimate interest with a recorded assessment and easy opt-out. Sole traders and some partnerships: opt-in | ico.org.uk (PECR amended by the Data (Use and Access) Act 2025; guidance under review) |
| Germany | Opt-in; existing-customer exception for similar products (UWG §7(3)) | Opt-in: B2B is not exempt (UWG §7(2)) | gesetze-im-internet.de |
| France | Opt-in, except existing customers offered similar products | Opt-out: allowed when relevant to the recipient's job, with notice and an easy objection | cnil.fr |
| Other EU | National ePrivacy rules differ; GDPR legitimate interest never overrides a national consent rule | Same | The national regulator |
| Korea | Prior explicit opt-in (정보통신망법 §50); exception: the same kind of goods within 6 months of a transaction; reconfirm consent every 2 years | Same: the Act names no B2B exemption | law.go.kr, KISA; verify before launch |
| Australia | Express or inferred consent (Spam Act 2003) | Inferred from a conspicuously published work address only when relevant to the role | acma.gov.au |
| Brazil | A lawful basis under LGPD: consent, or legitimate interest with an assessment | Same | gov.br/anpd |

Every commercial email, everywhere: a truthful sender and subject; a one-step opt-out that keeps working for at least 30 days after the send and is honored within 2 days in every stream (faster than most laws require); one suppression list across every tool (`references/email/deliverability.md`); a record of the basis for each contact. The US adds a postal address and, without prior consent, a clear statement that the email is an ad. Korea adds "(광고)" at the very start of the subject, with the sender's name, contact details and opt-out in the body.

## Writing

- A peer who noticed something, not a vendor: contractions, read it aloud, more "you" than "we". Never "I hope this finds you well", "My name is", "just checking in" or "circle back".
- At most 80 words; the best campaigns in Instantly's 2026 report average under 80 on the first touch. Shapes: observation → what it usually costs → a result from a similar company → ask; or trigger → implication → ask.
- **Personalization test:** delete the personalized opening. If the email still makes sense, the personalization was decoration; it has to connect to the problem.
- One proof point from a similar company beats ten features. Real results only; a gap gets the core proof rule's tag.
- One low-friction ask: interest ("Worth a look?") rather than a 30-minute call on the first touch.
- Subject: 2-4 plain words that could be internal ("reply rates", "hiring ops"); no pitch, urgency, emoji, first name or fake "Re:".

## Sequence

- Most replies come from the first email (58% at step one in Instantly's 2026 report), so spend the effort there.
- At most 4 touches over about 3 weeks, with widening gaps, each adding something new (an angle, a proof point, a useful resource); the last closes the loop politely. The same vendor recommends 4-7; past the fourth, each touch adds fewer replies and more complaint risk on a domain you need, so stop at four.
- A reply from anyone at an account stops the sequence for every contact there. An opt-out, including a reply asking to stop, suppresses that person everywhere.

## Sending

- A separate registered domain, never the product domain or one of its subdomains: cold complaints would land on the reputation your product mail depends on. Authenticate it fully (`references/email/deliverability.md`) and put a real website and a monitored inbox behind it.
- Tracking off, plain text, no link in the first email.
- Verify addresses before sending. Keep volume per mailbox low and raise it only while bounces and replies stay healthy; pause the domain when a batch hard-bounces above 2%.
- Rotating many fresh mailboxes or domains to dodge limits trips provider filters and may breach their terms; it treats the symptom, not the list.

## Measure

Primary: positive replies and meetings per segment, against your own baseline. Instantly's 2026 benchmark (its platform, January to December 2025) puts the average reply rate at 3.43% and the top quartile at 5.5%+, counting every reply, positive or not. Opens mean nothing with tracking off.

## Before you hand it back

Relevance test answered per segment; every recipient country classified; each email ≤80 words, one ask, no link in the first; every proof point real or tagged; the personalization survives the deletion test; ≤4 touches with an account-level stop.
