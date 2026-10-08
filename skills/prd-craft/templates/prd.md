# [Product] — PRD

**Status:** Draft | In review | Approved | Stopped: [reason] | Superseded by [path]
**Author:** [name] · **Approver:** [who owns the appetite] · **Last Updated:** [today, YYYY-MM-DD]
**Builds on:** [brief path | none] · **Reach:** personal | team | external · **Appetite:** [time × people to the v0.1 call]

<!-- Comments are rules for the writer; leave them out of the file.
- Word ceiling below this header, not a target: personal 600 · team 1,200 · external or high-stakes team 2,000. Hard cap 400 lines; over it, consolidate before adding. The ceiling limits the record, never the checks: never cut a material finding to fit. Compress it to a line, move its detail into a spec, or run over and say why in the report.
- Keep every numbered section (other skills read them), as `n/a — reason` if it doesn't apply; labels within one are a menu.
- Write for a stakeholder reading cold: plain sentences, no internal shorthand. A list of things to cover in a comment is a checklist, not a line to copy.
- Tag only what the scope rests on. A number stating a fact or a goal: (measured: source) · (est.: inputs → arithmetic) · (target: why this bar) · (unknown → measure by <milestone>). Never invent a baseline: an unknown one is a v0.1 measurement task. A target for behavior that doesn't exist yet is judgment: tag it target, with a review date.
- A claim the scope rests on carries the brief's evidence grade and its source: [Committed: …] [Observed: …] [Said: …] [Assumed]. If grades or markers (⚠ arch, [never], [later: …]) appear, one line under the header says what they mean.
- No rule names or checklists from the method. -->

## 1. Problem / Opportunity
<!-- Who hurts, how often, at what cost, and how they cope today (workaround, tool, competitor, nothing); never a requested feature. Evidence that cuts against the brief or the request belongs here too. -->
[Problem, with graded evidence]

**Why now:** [what changed]

## 2. Target Users
<!-- The narrowest reachable group with the most acute pain that would adopt or pay first, by situation, not demographics; everyone else waits. Two-sided: both sides, and which you acquire first; a mandated internal tool: the workflow. Motion sets scope: sales-led brings SSO, roles, an audit log, security reviews and invoicing; self-serve, onboarding, activation, card billing and a trial. -->
**First segment:** [who, in what situation, doing what today; the buyer, if not the user; what makes them drop the workaround]

**Motion:** [self-serve | sales-led | internal rollout]; price hypothesis [graded]

**Job story:** "When [situation], I want to [motivation], so I can [outcome]." <!-- names no product or feature -->

## 3. Proposed Solution
**Elevator pitch:** [2–3 plain sentences]

**Value propositions:** [each maps to a §1 problem and is false of competitors; one is fine]

**Alternatives considered:** [approaches weighed, an existing tool and doing nothing included, each with why not]

**Departures from the brief:** <!-- Only when this PRD drops or overturns something the brief or its approver asked for: one line each, "proposed" until approved. A changed problem, segment or primary metric also needs the brief revised by its owner. -->
- [What the brief said] → [what this PRD does instead], because [evidence]. Approver: [who], [proposed | approved YYYY-MM-DD].

## 4. Success Metrics
<!-- The primary decides: the behavior or business change that proves §1's problem moved; the leading indicator reads within 2–4 weeks. Every other outcome the brief or the caller named keeps an "Also" row or, under the table, the reason it was dropped. A metric that can be gamed or hit at someone's expense gets a counter-metric and the floor it must hold (time saved vs error rate; sign-ups vs 30-day retention); "none" only when nothing trades against it. Each baseline measures the same quantity as its §1 figure; no data source yet → instrumenting it is a v0.1 requirement. Quality bars (latency, accuracy, data loss) go in the specs, or §8 when product-wide. Break when personal (one sentence of observable behavior) or two-sided (a primary per side, or the transaction needing both). -->
| Metric (exact definition) | Baseline | Target | By | Counter-metric (floor) | Data source |
|---|---|---|---|---|---|
| Primary: | | | | | |
| Leading: | | | | | |
| Also: | | | | | |

## 5. Feature Overview
<!-- The whole product this PRD commits to: each capability the core job, a user's way in and out, the operator's work, a duty or the transition needs is a row; depth varies by release, coverage doesn't. One kebab-case key per feature, identical in §6 and the spec filename, naming what a user can do (`deploy-verdict`), never the part that does it; if no user could say they used it, merge it into the capability it serves. Break when the part is a developer tool's user-facing surface (`watch-mode`). Live product: shipped capabilities are rows too, with a spec only where one exists; a planned change to one is its own row (depends on: the shipped key). No specs (personal) → no Spec column. -->
| Feature | Description | Spec |
|---|---|---|
| [feature-key] | [what the user can do] | [features/feature-key.md](features/feature-key.md) |

## 6. Dev Order
<!-- Each §5 key appears once. Live product: open with `### Shipped — as of [YYYY-MM-DD]` and the shipped keys on one line, untagged; v0.1 is then the first planned release, its baselines measured from usage. -->
### v0.1 — [name] — [why first]
**Tests:** [the assumption, and its risk: value, usability, feasibility, viability or adoption]
**Audience:** [who or what (users, a held-out set, prospects), how many, how recruited]
**Checkpoint:** [date]
**Build bar:** [what may be manual, faked or unscaled, each manual step with who does it and the volume where that breaks; what must be production-grade: customer data, money, identity, consent, anything irreversible]
**Decision** ([who calls it]): continue if […]; change if […]; stop if […], and then [what pilot users keep, and when their data is deleted].
**Transition:** [only when it replaces a tool, sheet or process]
<!-- Decide on the §4 primary, or its leading indicator if the primary can't move by then. Few adopters → count them (≥2 of 3 teams …), never pool a rate across them; a rare event needs a longer window (at 2 a month, a month of ≤1 comes up 4 times in 10 by chance). Ranges don't overlap; the rule and who calls it are fixed before data arrives. A mandated or compliance build states an acceptance gate instead.
Lifecycle stages to walk before listing features, for one member of the audience: join (invite, sign-up, sign-in, identity check), bring their data in, use and change it (edit, undo, roles), get help or dispute (support, corrections, refunds, appeals), leave (export, deletion, the pilot ending). Then the operator's week: accounts and access, support, moderation, billing, data requests, incidents. Then anyone it records, scores or contacts without an account: notice, consent or objection, access, correction and deletion.
Transition covers: the records that move and how dirty ones are handled (duplicates, gaps, conflicts: fixed, flagged or dropped, and who decides); the go/no-go check before cutover (a dry run on a copy whose counts reconcile); the cutover date for each segment; in-flight work (finished in the old tool, or moved with its state); how long both run, if at all; when the old tool goes read-only, then off, and where its records are kept; how to roll back. -->
1. [feature-key] — [why here] [Must] ([estimate range])
2. [feature-key] — [why here] [Must] ([estimate range]) (depends on: [feature-key])

**Musts:** [sum of the ranges] of [the appetite] (est., confirmed by [whoever builds])

*Cut line: what follows is dropped first to hold the checkpoint.*

3. [feature-key] — [why here] [Should] (depends on: [feature-key])
<!-- Tags and the cut line go in v0.1, or, after a spike or no-build v0.1, in the first release users get, which then has its own Tests-to-Transition lines. A feature enters if the test needs it or running the test with real people needs it; nothing else, however cheap: each extra one blurs the signal and adds support. Must: the release is pointless or unlawful without it. A workaround demotes a Must only if the exit evidence survives it: someone doing the work by hand at pilot volume can (it goes in the build bar); users re-entering data they keep elsewhere can't, when double entry is what sends them back to the old tool. Musts take at most ~60% of the appetite, unless the estimates are proven, the approach known, the team has done this work before and the risk is low. Estimate each as a whole-job range (build, data move, integrations, legal work, testing, support), confirmed by whoever builds. High end over the cap but within the appetite → move the Must with the best surviving workaround below the line, or say here, plainly, that the plan is tight and what gives if it slips. High end over the appetite → not tight but over: cut below the line or move work into the build bar until it fits; keeping that work is a §9 question to the approver for more appetite. Never trim an estimate to fit. -->

### v0.2 — [name] — [why next]
4. [feature-key] — [why here] (depends on: [feature-key])
<!-- Later releases are intents, untagged; a cutover, retirement or binding legal date inside one is dated. -->

## 7. Scope & Non-Goals
<!-- §5 is the scope. List only non-goals someone would argue for (a stakeholder ask, a competitor's feature, the obvious extension, a lifecycle step this audience won't hit), each with a reason and [never] or [later: trigger]. Mark ⚠ arch on a [later] item costly to retrofit: tenancy, permissions, billing, locales, offline, audit, residency, moderation, public API. Personal: one or two lines. -->
- [Non-goal] [later: trigger] ⚠ arch — [reason]

## 8. Assumptions, Constraints & Risks
**Envelope** <!-- Product facts architecture builds on; unknowns get tagged defaults. Personal: one line ("single user, local data, no uptime promise"). -->
- **Scale:** accounts at launch and in 12 months; peaks
- **Data sensitivity:** none, personal, sensitive or regulated; **tenancy:** whose data must never be visible to whom
- **Failure and quality bars:** cost of an hour down, of a lost record; product-wide latency or accuracy
- **Platforms:** devices, locales, offline use, accessibility duty
- **Abuse:** who gains by misusing it (spam, fraud, scraping); any moderation or identity-check duty
- **Systems:** what it must read from or write to; the tool or process it replaces
- **Imposed:** integrations or technology the business or a customer requires, with the reason
- **Support period** (shipped software or devices): how long you fix and patch it
- **AI tolerances**, per AI feature: tolerated error by failure type (wrong vs harmful); how users notice and recover; cost ceiling per successful task, from price and target margin; interactive or deferred; actions taken without a person's approval

**Duties** <!-- Classify the data and the outputs; an output can be regulated when the data isn't (a decision or recommendation about a person, such as credit, hiring, housing, insurance or care; advice; a health, safety or financial claim; a record a law or contract makes you keep). For each law or contract that applies (privacy, consumer, accessibility, AI, payments, product security, sector rules, a customer's data-processing or security terms), checked at its source when writing, one line: the duty, its source and binding date, and the §5 feature or spec requirement, with acceptance criteria, that meets it in the release that first incurs it. A pilot, spike or test that uses real people's data or serves real people incurs its duties at v0.1 (for data: lawful basis or consent, vendor terms, retention, deletion after the test); with nothing built, a build-bar step with its owner meets them. What you can't check or can't settle goes to §9 (owner: counsel; default: the duty applies). Personal: n/a. -->
- [Duty] — [law or contract, jurisdiction; checked YYYY-MM-DD; binding from YYYY-MM-DD] — met by [feature-key, REQ-NNN] in [release]

**Risks**

| Why it would fail (graded) | Risk | Earliest signal | Retired by |
|---|---|---|---|
<!-- A pre-mortem: assume the checkpoint came and the bet failed; give the three likeliest reasons, at least one about value or viability (cost, sales, legal, support), and one about adoption when it replaces a tool. A high value risk gets the cheapest test that can run before building. Feasibility you can't vouch for → [spike], its fallback agreed in advance. Personal: one line. -->

## 9. Open Questions
<!-- Each blocks something and has a default, so nobody waits; if only the user can answer and it reshapes v0.1, ask now. Include the calls only a stakeholder can make (approving a departure, a legal reading, retiring the old tool, staffing the manual steps). Delete resolved items; this is not a changelog. -->
- [ ] [Question] — blocks: [section or feature] · owner: [who] · default if unanswered by [milestone]: [value]

<!-- ===== Not part of the PRD: the stub spec, its own file, at most 150 words. ===== -->
```markdown
# [Feature name]
Depth: stub — provisional; deepen via feature-spec before design · PRD: [§1 problem or §4 metric served] · Release: v0.N · Depends on: [keys | none]

## Problem & Outcome
[What the user can do, and the problem it moves.]

## Requirements
- **REQ-001** [draft; 3–5 in all]
<!-- A duty or one-way-door requirement carries its acceptance criteria now, outside the 150 words. -->

## Open Questions
- [ ] [what must be settled before design]
```
