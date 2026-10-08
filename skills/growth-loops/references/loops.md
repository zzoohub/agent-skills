# Growth Loops: reference

Depth behind `SKILL.md`; sibling skills named here are used if available.

## Loop types

| Loop | Dominant term (usually the lever) | Forcing question |
|---|---|---|
| Exposure (shared links, forms, files, embeds, badges) | Non-user views per active user; c | Does normal use show non-users the product, naming the source? |
| Collaboration | p; who pays the seat | `SKILL.md` question 3; joins to the inviter's account are expansion, not acquisition |
| Referral | p | `SKILL.md` Gate row 3 |
| Content | Own visits per indexed page (answer engines erode it: measure) | What share of artifacts is meant to be public (forms, templates)? Personal data starts private |
| Paid | Marginal CAC at the next spend tier, not average; payback | Does recycled margin fund the next cycle within the cash cycle? Else: a funnel with an ad budget |
| Marketplace | Scarce-side liquidity | Which side is scarce? Seed it by hand or with single-player value |

Peer-dependent loops (collaboration, marketplace) grow per cluster (team, campus, city, niche): seed one to density and read in-cluster K (marketplaces: scarce-side match rate) before spreading; thin seeding reads as K ≈ 0.

## Model

**Events** (tracking-plan names): p from `invite_sent` (share intent, not delivery; `invite_method`) or exposure views; k from `invite_clicked` (observable sends: invites per sharer × clicks per invite); c from `referral_completed` (`referrer_id`); a from the qualifying event joined on `referrer_id`; payouts from `reward_granted`. Request only missing events; add no synonyms. They see tracked paths only (§ Measurement).

- **Cycle time** runs from the inviter's signup to the invitee's qualifying event, and **sets when, not how much**: within m cycles the multiplier reaches (1−K^(m+1))/(1−K), so 90% of the ceiling takes about 2.3 cycles at K = 0.5, 21 at K = 0.9. It dominates near 1 (where 0.9 → 0.8 also halves the ceiling), in one-shot launches and in experiment read time.
- **Never trust a blended K**: it decays by cohort (saturation, fatigue), grows with retention (usage loops: K90 > K30; one-shot programs plateau), and a launch to the installed base inflates week-one K by draining latent referrals; compare cohorts at equal age. In a finite pool (niche B2B, one city), recompute K each cycle as K × (1 − share of the reachable pool reached); 1/(1−K) overstates.

Example: paid CAC = CAC_c = $60 per qualified user, K30 0.3, r $20 → q_min 0.33 (Go with holdout); effective CAC is $48 at q = 1, $56.5 at q = 0.5, and $60, no saving, at q_min. Interrogated, it moves both ways: if half of paid's credited conversions would have come anyway (lift test), paid's incremental CAC is $120 and q_min 0.17 (Go), payback permitting; if a third of rewarded referrals joined existing accounts, K in new accounts is 0.2 and r per new account $30: q_min 0.5 (Test first).

## Choose

Gate each running or candidate loop. Attribute last period's qualified new units by entry point (artifact landing, referral link; joins to an existing account are expansion, their own row), else "how did you hear"; unattributed is a row, and exposure also arrives as direct and brand-search traffic: bound it, never zero it. Columns: loop, units/period, K range, lever, headroom, cost to lift (the users' cost included), cycle time, moat, fund/hold/drop. Headroom: extra qualified units within the horizon if the lever term reached your best segment's rate, capped by the unreached pool. Rank by headroom ÷ cost; ties go to the loop that leaves an asset.

## Design decisions

### Trigger

Ask at the first value moment and once more after a positive signal (promoter score, high rating, completed outcome), with a persistent entry point; other successes make a shareable artifact, not another ask (repeated asks train dismissal). Break: where the invite is the activation (collaboration), ask during setup.

### Incentive

- **Reward the limiting term.** Low p or k: reward the sender (capacity, status, credit). Low c: reward the receiver, which turns the ask into a gift. Break when a personal reward reads as a kickback (a B2B user recommending a vendor to their employer): reward the account.
- **Split the timing** for each side you reward. Invitee value is bounded, usable at once and redeemable only through real use (time-boxed credit, trial or capacity): it lifts c without paying for signups. An inviter reward shows pending at once and pays, after the hold, on a costly-to-fake event in the decision's unit: the invitee's first payment when that unit is paying accounts, else the qualifying event under § Abuse Guardrails.
- **Pay in product value unless cash is the value unit**: it draws people who want the product and pays only if they stay (break: affiliates, non-user partners). Cost r by its form (pricing's rule).
- **No incentive when normal use already shares** (exposure, collaboration): a reward adds only fraud and reward-seekers.
- **Per-seat pricing taxes collaboration loops**: an invite that costs the admin money dies at approval; keep exposure roles (viewer, guest, commenter) free. Price paid badge removal against the exposure it strips from your heaviest users.
- **Structure**: one- or two-sided, or a milestone at N qualified referrals (launches, waitlists). Consumer rewards stay flat and capped (escalating tiers pay most where fraud rings sit); tiers suit only ambassadors and B2B partners.

Hand pricing the side, the value unit and the reward-only ceiling r_max = q × CAC_c (× LTV_referred ÷ LTV_next) − fraud leakage − payout ops, at q_low until a holdout measures q (rewards are hard to cut).

### Mechanism and attribution

- Prefer links users send from their own channels: an invite your servers send, or one you reward, is your commercial message (consent, anti-spam and disclosure rules apply per market).
- Contact import: the user picks individual recipients (system picker) and previews message and sender; no select-all, auto-send, auto-remind, or uploaded or stored address book.
- Attribution survives install, device switch and delayed signup: a deferred deep link, with a typed code as fallback (capped per inviter; a leaked code becomes a public discount), tested per platform and app version.
- Put the code in the URL path and record it server-side at landing: cross-site Referer carries only the origin, and some browsers block known tracking scripts from reading query parameters.
- Set the credit rule before launch (first or last inviter; referral, affiliate or paid last click), or you pay twice for one user.

### Invitee path

The invitee's first session sets c and a; page-level conversion goes to cro.
- Land on the inviter's object, inviter named; the invitee acts (reply, comment, book, sign) before signing up.
- Prefill what the invite already says (name, email, team); never an empty product; one screen to the first action.
- Defer costly steps (verification, payment, app install, contact or notification permissions) until after first value.

## Risks and side effects

Each that applies gets who pays, a guardrail metric and the mitigation.
- **Users the mechanism taxes** (branding on their work, an invite step before value, contact or notification access, messages in their name) pay in activation, conversion and retention; paid removal of branding can also lift upgrades. Read it by user stage (new vs established) and tier (free vs paid). Keep steps before first value (invite walls, permission prompts) out of new users' path; for branding, test a new-user exemption read on both sides: the taxed users' activation and upgrades, and the loop's total new units (§ Measurement); never decide on one side's readout.
- **Invitees**: a poor first session spends the inviter's credibility; reward-seekers retain worse (referred-cohort retention vs organic).
- **Other channels**: organic and word of mouth now paid for (q); double payment (the credit rule above).
- **Rules, brand, ops**: consent, disclosure and regulated-category rules; a reward that reads as a kickback; payout, support and fraud-review load.

## Abuse Guardrails

Before launch:
- **Pay on a qualified action that is costly to fake**: a first payment on a new instrument, or the qualifying event on an attested device (apps) or with a verified non-VoIP mobile number (web). Never on signup or a scriptable step: that is a fraud subsidy, not a growth loop. The invitee may activate before verifying; the reward may not.
- **Pending, then hold**: show the reward pending at once; grant it after the hold; claw it back on chargeback or churn in the window.
- **Dedupe on keys that are expensive to create**: payment-instrument fingerprint; in apps, Apple DeviceCheck bits or Play Integrity device recall (check your app's access). Email and IP are weak keys (strip +tags where supported, dots only on consumer gmail.com; expect relay addresses). Never fingerprint in iOS apps (Apple's license terms); web device signals stay secondary, after a privacy-law check (EU cookie rules cover fingerprinting).
- **Per-inviter caps** per period, minimum account age or activity, no self-referral; spikes go to review (a creator's spike is an affiliate candidate).

## Measurement

- Randomize mechanics tests by inviter, or by cluster (workspace, company domain, school, geo) when inviters share recipients; credit each invitee to the inviter's arm. Never by invitee (it leaks and biases toward zero), except on surfaces the inviter never sees (landing layout, signup steps), offer held fixed.
- **Primary metric: the decision's unit** (new paying accounts, revenue) per eligible user or cluster, from all entry paths: signups or tracked referrals alone count reward-seekers who never pay and miss untracked paths. Inviter-level arms see only tracked and self-reported ("who referred you?") arrivals; when the change can act untracked (a bigger reward also lifts talk without a code), randomize by cluster or geo, or name the blind spot.
- Measure q with a cluster holdout (market, company domain, team) on that metric. An inviter-level holdout, with identical unrewarded share links and "who referred you?" capture in both arms, compares referred new units per eligible user: an upper bound on q (rewards raise attribution).
- **Exposure you can't track** (badges, shared files, embeds): randomize where total inflow is observable (geo or market; alternating periods only if exposure converts within one) and read total new units, direct and brand search included; else triangulate tracked clicks, "how did you hear" and brand-search trends across exposed and unexposed groups, as a range.
- **Power first**: state the smallest effect the test can detect at its volume and length (few clusters, little power); if that misses q_min, say so and decide on the cheapest reversible version (a time-boxed reward, a small slice).
- Guardrails: referred-cohort retention vs organic; fraud and rejection rates; for a taxing mechanism, activation and conversion of the users carrying it, by stage and tier.
- Pre-register the card's Decision line: Kill if q < q_min; Iterate on the lever if K is below break-even (ongoing costs only: the build is sunk); else Ship. Read no earlier than one window W after the last cohort enrolls.

## Diagnose

1. Rule out measurement (an event, attribution or dedupe change on the drop date), then normalize per active user: flat per active user means the inputs fell, not the loop.
2. Decompose K by term, platform, app version, cohort age, inviter source and top-inviter share (a mix shift or lost head referrers lower K with no loop change); compare second-generation K with first.
3. Match the symptom, then rank fixes by the lever rule (`SKILL.md`, Design step 2):

| Symptom | Likely cause | Check; fix |
|---|---|---|
| A step drops on one date, platform or version | Broken link, deep link, attribution or deliverability | Click → install → open per platform (shutdowns fail silently: Firebase Dynamic Links stopped on 2025-08-25); restore, then alert per platform |
| Slow decline across cohorts; more recipients already invited or users | Saturation | Repeat-recipient rate; a new segment, not new copy |
| Invites per sharer up, conversion per invite down | Fatigue | Conversion by invite ordinal; a frequency cap |
| Signups up; referred retention or second-generation K below organic | Reward-seeking or fraud | Device and payment clustering; a later qualifying event |
| Referred users up, new paying accounts flat | Invitees joining existing accounts, or reward-seekers | New-account share and paid conversion of referred users; count in the decision's unit |
| Rewards pending longer or rejected more after a guardrail change | False positives starving real referrers | Rejection rate and pending age by cohort; a review queue |
| Participation down after a release | The ask left the value moment | Prompt impressions per active (p = exposure × take-rate); move the ask back |
| Referral share up, total signups flat | Cannibalized organic | Holdout; a smaller cash reward |

## Affiliates and ambassadors

A paid channel with no K: model each partner type's qualified acquisitions, new-customer share (its q) and commission, judged by q_min and payback. Pay for introduction, not interception: full rate where buyers had no prior visit, reduced or none for checkout-stage partners; test the largest partners' incrementality by pausing them by geo or period. Commission on qualified revenue after the guardrail hold, with clawback; ban brand-term bidding, cookie stuffing and self-purchase. Disclose beside every link ("paid link"; "affiliate link" alone may not suffice under US FTC guidance; free product counts; rules via copywriting). Ambassadors: organic top referrers, paid in access and status, cash only per qualified acquisition.

## Loop spec

The referral doc's format. **Budget: Design ≤ 900 words per loop; No-go ≤ 250**, prose ceilings: compress a material finding, never drop it. Sections are a menu: omit what doesn't apply, heading included.

```markdown
## Loop: [name] — Go | Go with holdout | Test first | No-go: [reason in plain words]
Summary (plain, ≤ 120 words): recommendation; cost per extra customer vs the next-best channel; main risk; next step, owner
Shape: who acts → what they send or make → what a non-user sees → how they arrive → where it breaks
Inputs corrected: [claim] → [corrected or bounded figure], because [reason]
Model (K30 at [qualifying event], in [decision's unit]; affiliates: per partner type, no K; ≤ 8 rows): term, baseline, source, low / base / high
Economics (gloss each symbol once in plain words): effective CAC vs next-best incremental CAC at q low / base / high; q_min; break-even K; cycle time (median, p75); amplification realized within [horizon]
Lever: [term], and why its relative lift is cheapest
Decisions: trigger; incentive (none, or structure and side, each tied to the term it lifts; any inviter reward paid on [costly-to-fake event in the decision's unit] after [hold]; any invitee value bounded, usable at once; ceiling + value unit for pricing); mechanism, attribution precedence; invitee path to first value
Abuse Guardrails (reward with value only): one per fraud vector
Risks and side effects: who pays, by user stage or tier; guardrail metric; mitigation
Experiment (Proposed until its owner approves): randomization unit; primary metric (decision's unit, all entry paths); guardrails; smallest detectable effect; Decision line; read date; missing events (tracking-plan names)
Positions (if contested): each position, what it gets right, the evidence, the answer
Owners and checkpoints: owner, date, metric and threshold, action
Do instead (No-go): [channel or fix]; reopen when [measurable condition]
Open questions and assumptions
```
