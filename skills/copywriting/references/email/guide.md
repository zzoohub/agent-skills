# Email

Lifecycle, broadcast and cold email: what to send, to whom and when, and how to tell whether it worked. Every email task starts here.

An email program earns its place by causing behavior that would not have happened anyway, and every send spends sender reputation. Most underperforming email is a trigger, audience or offer problem that looks like a copy problem: fix it in that order.

| Read next when you are… | File |
|---|---|
| Choosing or designing a program: welcome, onboarding, trial, nurture, re-engagement, win-back, lapsed trial, newsletter; branching on behavior | `references/email/sequence-templates.md` |
| Writing or editing an email: from, subject, preview, body and voice, CTA, personalization, A/B tests | `references/email/copy-guidelines.md` |
| Prospecting cold, or checking consent law by country | `references/email/cold-outreach.md` |
| Setting up a domain or stream, fixing spam placement, unsubscribe and suppression policy, consent capture | `references/email/deliverability.md` |

**Boundaries.** Billing-event notices (dunning, card-expiry alerts, renewal reminders, the cancellation confirmation) and cancel flows belong to the churn-prevention capability, if available (`churn-prevention/references/dunning-playbook.md`, `churn-prevention/references/cancel-flow-patterns.md`); win-back starts after its confirmation. Price-change notices are written here, with the terms from pricing and the notice window from churn-prevention; never invent either. Popup and signup-form design, and in-product onboarding flows, go to cro (popup copy: `references/copy-frameworks.md` § Promo units and paywalls); lift readouts and cohort analysis to product-analytics.

## 1. Frame

Inspect first: the current emails with their per-provider numbers, the tracking plan, the list itself (how each person joined, their consent record, last activity, plan; check that counts and dates agree before trusting them), and for win-back the cancel reasons already captured. Then ask once, in one batch, only what the inputs don't answer; otherwise assume the default and list it under Assumptions (≤3 lines, at the top of the output).

1. **Goal event.** Which event proves the email worked? Default: the activation event in the tracking plan (default `biz/analytics/tracking-plan.md`; caller may redirect). If none exists, name the event you would need; never write against "engagement".
2. **Trigger data.** Can the ESP see the trigger and the goal event, and exit on the goal? Default no: schedule by day and give every email a "skip if already did X" condition marked "needs event X".
3. **Class.** Transactional (completes or reports on something the user already agreed to: receipt, password reset, security alert, account status), lifecycle (helps them use what they already have) or marketing (sells something new: upgrade, add-on, event, newsletter, cart recovery, a pitch to a lapsed trial). The class decides consent, the unsubscribe header, the stream and the sender address (`references/email/deliverability.md`); marketing never shares the subdomain or From address that carries transactional mail. Unsure → marketing. A message mixing transactional and marketing content stays transactional only while its subject and opening are transactional (the FTC's primary-purpose test); keep transactional mail pure anyway.
4. **Relationship and consent.** Group the recipients by how each came to you (customer, former customer, trial that never paid, lead, newsletter subscriber, unknown) and by consent (opted in, declined, no record). The country law table in `references/email/cold-outreach.md` is the floor, not the decision: anyone who gave you their address but declined marketing, or has no consent record, gets none, whatever the law allows. Each group gets the kind of mail it signed up for; a group that fits no stream gets nothing. Default when the list can't show consent: no record.
5. **Countries and mailbox providers.** Count the recipient domains: Gmail, Yahoo and Microsoft rules bind only their own mailboxes; regional providers such as Naver and Daum in Korea filter by their own.
6. **Baseline.** Per provider: click or goal-event rate, unsubscribes per send, spam rate (Postmaster Tools). None → say what to instrument first.
7. **Collisions.** In-app, push and sales touches aimed at the same people in the same week. Default: email yields to an in-app message the user will see first, and to the account's sales owner.
8. **Offers and eligibility.** An offer (discount, credit, extension) goes only to the group it was made for, on pricing's terms; who qualifies is the owner's call, under Decisions for you with your recommendation. Default: write the version without the offer, attach the offer as a variant pending that decision, and keep a newcomer discount away from customers paying full price.

**Done** = the goal-event rate of recipients minus that of a random holdout over the program window, with unsubscribes and spam complaints per send as guardrails. Every automated non-transactional program ships with a holdout: default 10%, or 5% once more than ~50k people enter a month. Record it as a test card in the cro capability's format, if available (default `biz/growth/experiments.md`; caller may redirect); the lift readout belongs to product-analytics. Break: transactional and legally required mail gets no holdout; a flow too small to detect the lift you care about within a quarter gets a time-boxed on/off test, reported as directional.

| The request | Path | Deliver |
|---|---|---|
| One email (announcement, notice, single nudge) | Frame 1-5, plus 8 if it carries an offer; copy-guidelines | One per-email block |
| A program (onboarding, trial, nurture, re-engagement, win-back) | Full frame; sequence-templates; copy-guidelines | Program spec + per-email blocks |
| A one-off send to an existing or old list (launch, promotion, "we're back") | Full frame, 4 and 8 first; one variant per relationship group; waves, warmest first (`references/email/deliverability.md` § Ramp) | Program spec with Segments + a per-email block per group |
| Newsletter or broadcast | Frame 1 and 3-5; the frequency rule | Per-email block, multi-link allowed |
| Cold outreach | cold-outreach, law first | Per-email blocks at the cold budget |
| "We're going to spam", a new domain, sender rules | deliverability: Triage or Setup | Ranked findings and fixes, ≤400 words |
| Strategy only, no copy | Frame; program spec | Program spec + one line per email |

## 2. Program rules

- **One email, one job, one primary CTA.** Break: newsletters and digests are multi-link by design.
- **Trigger on behavior, exit on the goal, skip what's done.** A scheduled email that doesn't check events nags people who already finished and congratulates people who never started. Never trigger, branch, sunset or judge on opens: Apple Mail Privacy Protection pre-fetches tracking pixels, so opens are inflated and prove nothing about reading.
- **Engaged** means a click, a reply or product activity, never an open. In B2B, a click seconds after delivery, or every link clicked at once, is a security scanner; branch on what happens after the click (signed in, finished the step).
- **Value before the ask, except at high intent.** A trial ending, a pricing-page visit or a hit usage limit asks first.
- **Per-recipient truth.** A line true only for some recipients ("your 3 reports", "your price stays locked", "20% off your first year back") carries its condition in the block's Only if field; recipients who fail it get a variant without it, or no send. One offer-first email to a mixed list fails this rule.
- **Frequency.** B2B SaaS default: at most 2 non-triggered marketing sends a week and 1 triggered email a day per person. Raise it only when holdout lift outweighs the unsubscribe and complaint cost; recipients see your volume (Gmail's Manage subscriptions lists each sender's recent count beside an Unsubscribe button). When one person qualifies for several sends, triggered beats broadcast; hold marketing while someone is in onboarding or a billing flow. Transactional mail is exempt.
- **Send windows.** Broadcasts land in each recipient's local working hours, or the hours your own click data favors; non-urgent triggered mail waits out the recipient's night.
- **Segments.** Split into separate sends when the goal or CTA differs by segment; use a dynamic block when only the proof or example differs.

## Default Output Format

Save each program to the email content directory (default `biz/marketing/content/email/`; caller may redirect), updating an existing file in place; with no file-write capability, return it inline. **Drafts only:** never send, schedule or activate an email, campaign or automation, in an ESP or anywhere else, without the caller's explicit approval.

Both blocks are menus: drop any field that doesn't apply, label included.

**Program spec** (≤200 words)
```
Program: [name] · Class: [transactional | lifecycle | marketing] · Stream: [subdomain, From address]
Goal event: [event] · Metric: [goal-event rate, recipients minus holdout, over N days]
Entry: [trigger + conditions] · Exit: [goal event; unsubscribe; higher-priority program]
Segments: [group → what it gets · consent basis · size]
Holdout: [share | none: transactional] · Guardrails: [unsubscribes and spam rate per send, with limits]
Emails: [one line each: job, trigger or delay, skip-if, branch]
Decisions for you: [offer eligibility and other owner calls, each with your recommendation]
Assumptions: [defaults applied, ≤3 lines]
```

**Per email** (body budget: transactional ≤125 words, lifecycle and marketing ≤200, cold ≤80, newsletter by section)
```
Email [#]: [job, ≤6 words] · Send: [trigger or delay; recipient-local window] · Skip if: [event]
To: [group · consent basis] · Only if: [the condition behind each line true for only some recipients]
From: [name <address>] · Reply-to: [a monitored inbox]
Subject: [the first ~30 characters carry the meaning]
Preview: [completes the subject, never repeats it]
---
[body]
---
CTA: [button text] → [destination]
Branch: [what each recipient gets next, by what they did]
Length: [N words]
```

After the blocks, **Questions for you**: each gap tag as one direct question for the owner; without a program spec, also its Decisions for you, each with your recommendation. Subject alternates only when each arm can reach ~10k recipients (smaller tests can't detect realistic lifts; `references/email/copy-guidelines.md`) or when the caller asks; then two, from different angles, one recommended. Strategy-only requests get the program spec and one line per email (job, trigger, subject direction), ≤400 words in all.

## Self-Review

Fix, don't report. Each email: (1) one job, tied to the goal event; (2) the subject says what's inside, or the first line pays off its curiosity; the preview is set and doesn't repeat the subject; (3) the first line is the hook and the first two state the point plainly, since previews and AI summaries draw on them; it reads as one person writing to one person, signed by a person when replies are welcome; (4) one primary CTA (newsletters excepted); (5) every merge token has a fallback; every number, deadline, name and quote is real or carries the core proof rule's gap tag, and an untrue line was rewritten to a true one doing the same job, not dropped, keeping the requester's wording where a stated condition makes it true; (6) every line true for only some recipients carries its Only if condition. Each program or send: (7) every group mailed has a consent basis for this class of mail, declined or unknown consent gets no marketing, and each group gets what it signed up for; offers reach only eligible groups, with eligibility under Decisions for you; (8) entry, exit on the goal, skip-ifs, branches, class and stream, holdout, metric and guardrails are set; (9) nothing triggers, branches, sunsets or is judged on opens; (10) collisions with in-app, push, sales and billing mail are resolved. (11) **Footprint:** every body within its budget; program spec ≤200 words; strategy-only ≤400; subject alternates only when powered or asked; no line names this guide's rules or steps.

## Diagnosis

First split every metric by mailbox provider. A drop at one provider is placement (Triage in `references/email/deliverability.md`); a drop everywhere is audience, offer or content. Rates use delivered mail as the denominator (unique clicks, replies, unsubscribes and complaints, each ÷ delivered; bounces ÷ sent); Postmaster's spam rate divides by mail delivered to the inbox. Compare against your own trailing median, not an industry average.

| Symptom | Likely cause | Check first |
|---|---|---|
| Clicks fell at one provider | Placement | Triage in deliverability.md |
| Clicks fell everywhere | Fatigue, audience drift or a weaker offer | Sends per person in the last 30 days; clicks by list source and tenure |
| Clicks, but no goal event | The landing step breaks the email's promise | Same promise, same offer, one step to act? (page fixes: cro) |
| Recipients convert, the holdout converts as much | Not incremental | Cut, retarget or re-time the program; never scale it |
| Unsubscribes above ~2× your median | Frequency or relevance | Sends per person; does the content match what they signed up for? |
| Spam rate at or above 0.1% | Consent source, frequency or an expectation gap | Which list sources and signup cohorts the recent sends reached; Postmaster's trend, since ESP complaint counts miss Gmail |
| Cold replies low | The list, not the copy | Relevance test and kill rule in cold-outreach.md |
