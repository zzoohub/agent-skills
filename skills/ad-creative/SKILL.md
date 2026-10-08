---
name: ad-creative
description: |
  Paid ad creative: concepts, hooks, ad copy, video and UGC scripts, creative
  and creator briefs, and platform asset sets for Meta (Facebook, Instagram),
  TikTok, Google, YouTube, LinkedIn, display and retail media, plus creative
  test plans and fatigue diagnosis.
  Use when writing, iterating or adapting ads, filling RSA or PMax slots, planning
  creative tests or fixing tired ads: "ad copy", "ad creative", "ad variations",
  "Meta ads", "creative testing", "ad fatigue".
  Do NOT use for: organic social or landing-page copy (copywriting); targeting, bids,
  budgets or attribution (the caller's media plan); creative-test significance
  readouts (product-analytics).
---

# Ad Creative

## Premise

Under automated delivery the creative is the targeting: each ad finds the people it speaks to, and near-identical ads reach the same people and teach one lesson. The job: a small portfolio of genuinely different concepts, each for one person in one moment, judged on the outcome the business is paid for by rules set before launch, with known odds of a wrong call. Reject reworded clones, calendar refreshes, benchmark-chasing, unproven claims (the advertiser's own included) and "wins" that only show where the optimizer put the money.

**Scope.** Elsewhere, each via that capability if available: campaign structure, targeting, bids, budgets, optimization events, attribution, incrementality, MMM (the caller's media plan); significance readouts, tracking (product-analytics); landing-page conversion (cro); offer, price (pricing); organic social, landing-page copy, choosing or ethics-judging persuasion principles (copywriting).

**Lane: ad drafts only.** Never launch, publish or schedule an ad, or change live budgets, targeting or settings, without the caller's explicit approval; never edit anything outside the ads unasked (site code, tracking, the offer, the live feed: catalog titles are drafted here), even with access: an outside need becomes a Handoff. **Output**: `biz/marketing/assets/{campaign-slug}.md` (default; caller may redirect the `biz/<area>/` root), updated in place; inline without file-write.

## Stage 0 — Classify & Calibrate

Behind a format request ("10 hooks", "make it work on TikTok") sits one of three problems: no proven concept yet, a proven concept wearing out, or a cause outside the creative (auction, page, offer, tracking, the event the optimizer chases) that more ads will not fix. Classify first; diagnose a performance complaint before writing anything.

| Job | Inspect first | Produce (Output blocks) |
|---|---|---|
| Asset batch or set: headlines, hooks, one ad; RSA, PMax, catalog | landing page (read only); the ad or asset group it joins; asset report | Asset batch or set |
| Variations ("10 versions of this") | is the control proven? its tags, metrics, why it won | proven: Variant family + Test plan; unproven: Asset batch of distinct concepts |
| New concepts | customer words; top ads, last 30–90 days | 3–5 Concept cards + Test plan |
| Program (launch, new platform, a quarter) or 20+ ads | unit economics, capacity, customer research, account history | Program + wave-1 Concept cards + Test plan |
| Test design ("how should we test", "new ads never spend") | the optimizer's event vs the outcome judged; structure; conversions per week | Test plan |
| Performance problem ("CPA is up", "ads are tired") | per-ad and per-segment funnel metrics and outcome quality; when it changed, what else did | Diagnosis; Concept cards + Test plan for creative's share |
| Adapt to a platform or market | the source ad; why it won | rewritten fields + Adaptation notes |

Every job adds a Header, plus a Claims log and Handoffs when needed; creator-shot concepts add a Creator brief (asked for alone, the deliverable).

**Small requests** (asset batches and sets, adaptations, a brief for a given concept) skip the work of Stages 1, 2 and 4, never the checks: claims, compliance, auto-generation, message match, counts, and any real problem the evidence shows. A contested choice gets a one-line test (tool, metric, read date), not a ruling. Variations of an unproven ad skip 1 and 4, keep the clone test and name the test that reads them.

**Large asks** ship in waves: wave 1 complete and launch-ready (the concepts answering the first learning question), then a queue of later waves, each with what releases it; never skeletons.

**Calibrate** in one batch, only what changes the output, each question with its default; unable to ask, apply the defaults, list them in the Header, return the questions. Block only on a missing offer or a restricted category with unknown rules.
- *Objective and metric*: conversions at target CPA; reach or awareness: cost per completed view and hold rate.
- *Target CPA (or ROAS), spend, conversions per week*: CPA = order value ÷ ROAS; test budget 10–20% of spend; weekly conversions ≈ weekly spend ÷ target CPA.
- *The optimizer's event vs the outcome judged, and its lag*: they differ when the event fires before quality or payment is known (lead, trial, install, discounted first order); judge the matured outcome (Stage 4).
- *What runs and has won; production capacity*: cold start, 6 executions (3 concepts × 2).
- *Delivery*: automated (Advantage+, PMax, Smart+): concepts span personas; manual targeting (titles, keywords) fixes the audience, so concepts span beliefs.
- *Category, disclosures, evidence, brand mandatories*: inferred from the product and page, stated in the Header; gaps go in the Claims log. Restricted categories (housing, employment, financial, health, political…) limit the concepts: read `references/ad-policy-compliance.md` first.

**Goal arithmetic.** When targets conflict (more spend at a lower CPA, a CPA never hit, a deadline inside the outcome's lag), show what creative must deliver: CPA = CPM ÷ (1,000 × CTR × CVR), so x% off CPA at flat CPM needs CTR × CVR × 1 ÷ (1 − x), and added spend usually lifts CPM. If no past winner moved those rates that far, say who else must.

**Done**: the Self-Review passes; every material finding reaches the deliverable; every test judges the business outcome by rules with stated odds.

## Stage 1 — Evidence before ideas

1. **The account's winners**: top ads by the judged outcome per dollar (by spend share only when the optimizer's event is that outcome), tagged, each with one line on why it won.
2. **Customer words** (default: public reviews and the landing page, labelled hypotheses): 3-star reviews hold desire and objection together; "what almost stopped you?" answers, tickets and sales calls add objections. Top objections become product-aware concepts; before-state phrases become hooks.
3. **Ad libraries** (if browsing is available; else ask): a competitor ad live 30–60+ days in several variants is a probable winner (*break:* big brands run ads regardless); they show saturated messages, not scripts.

Working output, not delivered: 3–6 persona-moments, each with a belief and evidence.

## Stage 2 — Concepts

- **Concept** = who (one persona in one moment, which fixes the awareness stage) + the belief or desire sold + proof (show > cite > claim). **Execution** = format × style × creator × hook.
- **Ad name**: `{date}_{concept}_{persona}_{belief}_{format}_{style}_{hook}_{creator}_v{n}`, passed in `utm_content` (Meta: `{{ad.name}}`) so results join to cohorts and learnings roll up by tag.

**Explore** (cold start, a fatigued persona, a new market): concepts differ in who stops, the belief sold, or how it looks, spread across awareness stages (a pain, a mechanism, an objection). **Iterate** (a proven concept): one execution element at a time, cheapest first (ladder: `references/creative-testing.md`).

- **Clone test**: hooks that could trade places without changing who stops are one concept. *Break:* iterate mode, on purpose.
- **One belief per ad.** *Break:* retargeting ads that answer 2–3 objections in sequence.
- **Cheapest credible execution first**: a static, lo-fi video or screen recording proves a belief before anyone pays for a shoot. *Break:* beliefs only motion can carry.
- **Qualify** with price or "not for X" when lead quality matters, accepting the lower CTR (*break:* a volume-starved funnel where sales filters cheaply); otherwise price leads only when it beats the viewer's alternative.
- **B2B cold**: most buyers are out of market; judge reach into target accounts and later pipeline, not CTR. *Break:* in-market retargeting.
- **Permutation matrices** only for catalog ads, localization and resizes of winners.

> Clones: "Tired of invoicing?" / "Invoicing eating your Fridays?" (same freelancer, same belief). Distinct: a freelancer chasing a client 60 days late (paid without the awkward email; reminder screen recording); an agency owner at month-end (invoices built from tracked hours); a first-year founder (tax set aside as you go; demo).

## Stage 3 — Write

- **Three tracks**: the first frame (inside the safe zone), the on-screen text and the VO each carry the hook alone.
- **Hooks from the palette** (`references/hook-science.md`): draft five or more per concept across three or more archetypes, at least one in a native format for each platform it runs on; keep the best 3–5. Shapes vary; the person and belief don't.
- **Promise and payoff**: the hook's promise is kept within ~5 s (static: the next line), in words no competitor could run, and the brand lands natively by then: product in hand, spoken name or a distinctive asset; never a logo bumper, never stripped out to look organic. *Break:* entertainment formats may pay off later, but the brand still lands by ~5 s.
- **Claims log**: every factual claim (number, rating, ranking, speed, saving, result, "only", "#1", "clinically") needs evidence on file, logged with source and date: the underlying data, not a page or deck repeating it. The advertiser's own claims count: request it or tag `[SOURCE NEEDED: what]`; recalled or secondhand: `[VERIFY: claim]`. Unsubstantiated at launch: cut or qualify. Comparative claims are dated too; competitor facts via competitor-pages' claims reference, if available.
- **Compliance at the line** (detail: `references/ad-policy-compliance.md`):
  - Never link "you" to a sensitive attribute (health, finances, race, religion, sexuality…): "Diabetes-friendly meals, delivered", not "Managing your diabetes?"; roles are fine.
  - Special ad categories (housing, employment, financial): the creative says who the offer is for, never preferring or excluding a group.
  - Results shown are typical, or the generally expected result is disclosed beside them ("results not typical" alone fails).
  - No testimonial from anyone who does not exist (AI avatars, actors posing as customers) or never used the product; paid, gifted or employed creators disclose it in the creative.
  - Synthetic people, voices and realistic scenes are labelled as platform and law require; no fake UI or buttons; urgency and "was" prices only when real; trial and renewal terms beside the offer.
  - A live ad that breaks any of these: a Handoff to pause it now, ahead of new work.
- **Transform, don't resize**: only the concept travels across platforms and languages (how: `references/platform-specs.md`).
- **Asset sets** (RSA, PMax and Demand Gen asset groups, Meta's flexible format): every asset reads alone in any order; one concept per asset group or flexible ad, or no one can tell which belief won; pin only what legal or the brand fixes (`references/copywriting-frameworks.md`).
- **Auto-generation** (Google's text customization, Meta's Advantage+ creative enhancements) rewrites copy from your page and assets; assume it is on until checked per ad. In a restricted category, or when the page says what you would not run, turn it off for those ads (a settings Handoff before launch) or review every output; the page's fix is a Handoff.
- **Creator content** runs from the creator's handle (partnership ads, Spark Ads) when rights allow, with audio licensed for ads.

## Stage 4 — Test plan

**Judge the outcome, not the allocation.** Name each ad set's optimization event and the outcome the business judges. When they diverge, the optimizer funds whichever ad wins the event, often through cheap converters who never qualify, pay or return; spend share and event CPA there prove nothing. Test in protected cells (optimized on the deepest event with enough volume) judged on the true outcome per dollar, graduate winners into the scaling ad set, and hand the event fix (a deeper or value event, qualified outcomes sent back) to the media buyer. *Break:* the event converts to the outcome at similar rates across ads (per ad, from the CRM or log): judge it, spot-check the outcome.

**Structure** (tools per platform: `references/creative-testing.md`):
- One concept per cell, equal budgets, one version per person where the tool allows. Cells answer the learning questions; contested preferences (polished or lo-fi, price in the hook or not) and open questions become cells, not arguments.
- Every round has a concurrent control: the current best ad, unchanged, in its own cell; iterations change one element against it. *Break:* cold start (nothing proven): the target CPA stands in for the control, and each line below needs half its conversions (≥28% at ~15); the round's winner becomes the next control.
- Launch straight into a scaling ad set only when its event is the judged outcome and it already spreads spend across ≥5 distinct concepts; an ad it won't fund is then a weak negative. Elsewhere, new ads the incumbents starve are untested, not losers.

**What the budget can detect.** Expected conversions per cell = cell budget ÷ the control's CPA. Head-to-head, at ~10% odds of promoting an ad merely equal to the control:

| Conversions per cell | Promote when CPA beats the control's by | Catches, ~3 times in 4, a true CPA cut of |
|---|---|---|
| ~15 | ≥37% | ~50% |
| ~30 | ≥28% | ~40% |
| ~60 | ≥21% | ~30% |
| ~165 | ≥13% | ~20% |

New concepts can differ that much; hook tweaks rarely do. When the budget can't reach the expected gap, say so and choose fewer cells, a longer window, an earlier event shown to predict the outcome, or leading indicators alone for iterations; never more cells with less spend each. Under ~50 conversions a week: the small-account methods (`references/creative-testing.md`).

**Rules, set before launch**, each with its odds of a wrong kill or promote (defaults labelled; method: `references/creative-testing.md`):
- **Triage** on leading indicators: after ~1,000 impressions (video) or ~30 expected clicks at the median CTR (static), kill an execution with hook rate or CTR under half the account median for its format and placement; they kill duds, never crown winners. *Break:* qualifying hooks (price, "not for X"): judge cost per qualified result.
- **Outcome kill**: zero conversions by 2.5× target CPA kills ~8% of at-target ads; "≤1 conversion at 2×" kills 41%.
- **Promote** only at the read date, on outcome per dollar against the control, past the table's line. Its ~10% is per cell, ~20–35% for a 3–5-cell round: rerun a winner before a costly bet (stricter lines: `references/creative-testing.md`). Ahead of the control but short of the line: provisional, a second round, never straight to scale; level or behind: retire as inconclusive.
- **Read dates**, whole weeks, fixed before launch: triage, outcome, and a matured-cohort read when the outcome lags; younger cohorts stay out.
- **After a non-creative shift** (CPM, price, site, tracking, season): read against the concurrent control, not the pre-shift target.
- **Kill executions fast, concepts slowly**: retire a concept only after 2–3 distinct executions fail. *Break:* a concept with no customer evidence behind it.
- **Offer ads, harvesting wins, reach tests**: `references/creative-testing.md`.

**Win condition**: outcome per dollar beats the concurrent control past the promote line, on matured cohorts; spend share is a delivery observation, never the win. Most new concepts lose; a winless round with a written why is normal.

## Diagnose

Judge each ad against its own peak, the account's trailing 60–90-day median for its placement and format (a published benchmark only without history, labelled) and the platform's fatigue flag; never a calendar. One cause rarely explains a whole change: run every step before naming one.

1. **Locate**: when it changed, where (ads, placements, segments, new vs returning), and what else changed then (budget, event, price, site, tracking, policy, season); a step on one date points there first.
2. **Decompose**: cost per judged outcome = CPM ÷ (1,000 × CTR × CVR × event-to-outcome rate); log changes add, so each factor's share is its log change over the cost's.
3. **Mix or rate**: recompute this period's CPA at last period's spend mix; the gap is mix (spend moved to weaker ads, placements or audiences), the rest is rate change.
4. **Stage per segment**: where the change sits, which stage failed (hook, hold, CTR, CVR, outcome quality).
5. **Controls**: ads launched after the change; if they drop too, it is the environment, not wear-out.
6. **Maturity**: drop cohorts whose outcome hasn't matured; lags inflate recent CPA.

> CPA +42% = CPM +15%, CTR −5%, CVR −15%: CPM explains ~40%, CTR ~15%, CVR ~45%. Creative can win back the CTR share and the part of CVR that is message match; the CPM share is the auction's only if fresh ads' CPMs rose too.

Signatures: **fatigue** is one ad below its own peak on CTR or hook rate, CVR holding, frequency up, fresh ads fine (a new concept for that persona, not a re-skin); **marginal reach**, CPA up after a budget rise with per-ad CTR flat (the media buyer's call; only new personas widen reach); **proxy drift**, event cost steady while outcome quality falls (event fix to the media buyer; qualifying concepts); **outside the ad**, CTR steady while CVR falls (a Handoff). CPM up on every ad, fresh ones too, is the auction: say plainly new creative won't fix it. If the creative is the cause, the funnel in `references/hook-science.md` locates the weak part.

## Output

Budgets size the record, never the analysis: run every check the job implies first, and state each material finding, one line if the job is small. A block with more decisions than its budget (causes, waves) adds a line per extra decision; cut repetition, never a finding. Budgets count prose, not ad copy, scripts or tables. The blocks are a menu: produce those Stage 0 names; omit the rest, headings included.

**Header** (≤80 words; every job): category and disclosures · defaults assumed · open questions · launch blockers, one line each.

**Handoffs** (a line each, ordered by when): what and why · owner by role (site owner, media buyer, legal, analytics) · the exact change · when: before launch, before the first read, or in parallel.

**Program** (≤300 words, plus a line per queued wave): persona × belief grid, evidence per cell · learning questions in the order rounds answer them · new ads a month from demand (winners needed, lifespan, hit rate) against budget and production · new vs iterated share · peak windows · production mix, cost per usable ad (`references/creative-testing.md`) · the queue.

**Concept card** (≤200 words of prose each), headed `### {concept tag}`: who & moment · belief · proof (Claims log rows) · hooks, each as frame / on-screen / VO · video script (`| Time | Shot | On-screen | VO |`); static: what the eye lands on first, then the on-image line · CTA · message match (the page headline it needs; a gap is a Handoff).

**Export table** (outside budgets): `| Ad name | Placement | Field | Text | n/visible, n/max |`, then each ad's ratios; safe zones once per ratio.

**Asset batch or set** (≤100 words of notes): every line with (n/limit); per image ad, the on-image line and what the eye lands on first; RSA and PMax: headlines grouped by message type, then descriptions and paths; pins with their reasons. Variations of an unproven ad: a who · belief line above each ad.

**Variant family** (≤60 words plus one line per variant): why the winner won; per variant, what changes and what stays.

**Test plan** (≤200 words, plus a cell table, control first: `| Cell | Hypothesis | Budget | Expected conversions | Detectable gap |`): optimizer check and the structure it implies · rules with their odds (promote: one-sided α 0.10 per cell, ~75% power) · read dates · win condition · graduation · where results are logged; it is the readout's design record.

**Diagnosis** (≤200 words, +40 per cause beyond two): Diagnose steps 1–6 in brief · per cause: confirming check, action, owner · what creative alone can fix.

**Claims log** (table, outside budgets): `| Claim | Ads | Evidence on file (what, source, date) | Status: on file · requested from [role] · qualified as … · cut |`.

**Adaptation notes** (≤60 words per target): what changed and why, beside the rewritten fields.

**Creator brief** (≤150 words): persona, belief, must-say and must-not-say, 3 hooks, shot list, specs and safe zones, licensed audio, usage term, disclosure.

## Self-Review

Before returning, check and fix:
1. Every limited field shows its count and fits, counted as the platform counts (Google Ads: each CJK character is 2).
2. Explore concepts and variations of unproven ads pass the clone test; each concept's hooks span ≥2 archetypes and a native format per platform; every promise pays off within ~5 s or the next line.
3. Every factual claim, the advertiser's own included, has evidence on file in the Claims log, or is tagged, qualified or cut; every ad passes each Stage 3 compliance bullet.
4. Asset sets read alone in any order, pins only where required, one concept per group; each concept ships in every ratio its placements render; image ads carry the hook in the on-image line; video has captions, safe-zone text, self-sufficient tracks and the brand natively by ~5 s.
5. Test plans: the optimizer's event checked, a concurrent control (cold start: the target), each rule's odds (promote: per round too), the detectable gap, read dates (matured cohorts for lagging outcomes), a win on outcome per dollar, never spend share.
6. Diagnoses: all six steps shown, creative's share apart from the rest.
7. Nothing edited outside the ads unasked; every outside need is a Handoff with owner, exact change and timing; no skill names, method labels (framework, awareness stage, "angle") or self-review tallies in the deliverable.
8. **Footprint**: every block within its word budget or stated per-decision allowance; no material finding cut to fit; nothing the job's Stage 0 row did not ask for.

## Reference Files

- `references/copywriting-frameworks.md`: writing a feed, video, search, carousel or display ad.
- `references/hook-science.md`: before writing hooks (archetypes, native formats); hook metrics; the funnel.
- `references/creative-testing.md`: any test plan or program.
- `references/platform-specs.md`: always, before export; adapting across platforms.
- `references/generative-tools.md`: producing with AI.
- `references/ad-policy-compliance.md`: restricted-category, creator, testimonial or AI-made ads; claims and evidence.
