# [Product] — PRD

**Status:** Draft | Approved | Stopped: [reason] · **Owner:** [who approves the stake and calls the checkpoint] · **Updated:** [today, YYYY-MM-DD]
**Builds on:** [brief path | none] · **Reach:** personal | team | external · **Appetite:** [time, people and money to the checkpoint]

<!-- Comments are rules for the writer; leave them out of the file.
- Word ceiling below this header, not a target: personal 600 · team 1,200 · external 2,000. It limits the record, never the checks: compress a material finding to a line, move its detail into a spec, or run over and say why in the report.
- Keep every numbered section (other skills read them by number); write `n/a — reason` where one doesn't apply.
- Write for someone reading cold: plain sentences, no shorthand from the conversation. A labeled line that outgrows two sentences (Build bar, Transition) becomes a short list under its label.
- Tag each number the scope rests on: (measured: source) · (est.: inputs → arithmetic) · (target: why this bar) · (unknown → measure by <milestone>). An unknown baseline is a v0.1 measurement task, never an invention.
- Tag each claim the scope rests on with its grade and source: [Committed: …] [Observed: …] [Said: …] [Assumed]. -->

## 1. Problem
<!-- Who hurts, when, how often, at what cost, and how they cope today. Never a requested feature. Evidence that cuts against the brief or the request belongs here too. -->
[The problem, with graded evidence]

**Why now:** [what changed]

## 2. Users
<!-- The narrowest reachable group with the sharpest pain, by situation and not demographics; everyone else waits. Two-sided: both sides, and which comes first. A mandated internal tool: the workflow. Motion sets scope: sales-led brings SSO, roles, an audit log and invoicing; self-serve brings onboarding, a trial and card billing. -->
**First segment:** [who, in what situation, doing what today; the buyer, if not the user; what would make them drop the workaround]

**Motion:** self-serve | sales-led | internal rollout · **Price hypothesis:** [graded]

**Job story:** When [situation], I want to [motivation], so I can [outcome]. <!-- names no product or feature -->

## 3. Bet
[The product in two or three plain sentences: what someone does with it, and what changes for them.]

**We believe** [segment] will [behavior] because [insight] [grade]. **We're wrong if** [what the checkpoint would show].

**Instead of:** [what else was weighed, an existing tool and doing nothing included, each with why not]

**Departures from the brief:** <!-- Only when this PRD drops or overturns something the brief or its approver asked for. -->
- [What was asked] → [what this does instead], because [evidence]. Approver: [who], proposed | approved [YYYY-MM-DD].

## 4. Success
<!-- The primary is the change in behavior or business result that proves §1 moved. The leading indicator can be read by the checkpoint. A metric that can be gamed, or hit at someone's expense, gets a counter-metric and the floor it must hold; "none" only when nothing trades against it. No data source yet: instrumenting it is a v0.1 requirement. Under the table, one line for each outcome that was asked for and dropped. Quality bars (speed, accuracy, data loss) go in the specs, or in §6 when product-wide. A personal tool: one sentence of observable behavior. Two-sided: a primary per side, or the transaction that needs both. -->
| Metric (exact definition) | Baseline | Target | By | Counter-metric (floor) | Data source |
|---|---|---|---|---|---|
| Primary: | | | | | |
| Leading: | | | | | |
| Also: | | | | | |

## 5. Scope
<!-- Every feature appears once: Shipped, Now, Later or Never. A key is kebab-case, names what a user can do, and matches its spec's filename. A live product between bets lists what is being built under a plain `### Now`, without the release lines. -->

### Shipped
<!-- Only for a live product, or after a checkpoint: the keys (a spec link where one exists), and each past release's Result line. Otherwise leave this heading out. -->

### Now — v0.1: [name]
**Tests:** [the belief, and its risk: value, usability, feasibility, viability or adoption]
**Audience:** [who (users, prospects, a held-out set), how many, how they are recruited]
**Checkpoint:** [date]
**Decision** ([who calls it]): continue if […]; change if […]; stop if […], and then [what the audience keeps, and when their data is deleted].
**Build bar:** [what is manual, faked or unscaled, each with who does it and the volume where it breaks; what must be production-grade]
**Transition:** [only when it replaces a tool, sheet or process: the records that move and what happens to dirty ones; the go/no-go check before cutover; the cutover date; work in flight; how long both run; when the old one goes read-only, then off; how to roll back]

1. `feature-key` — [what the user can do] — [why the test needs it] · [spec](features/feature-key.md)
2. `feature-key` — [what the user can do] — [why the test needs it] (depends on: `feature-key`) · spec owed

*Cut line: above it, the Musts. What follows is dropped first to hold the checkpoint.*

3. `feature-key` — [what the user can do] — [why it is here] · spec owed

**Fit:** [the Musts' size against the appetite (est.: whose, from what) | unconfirmed]

### Later
- `feature-key` — [what the user can do] — when [the result or event that pulls it in] ⚠ arch

### Never
- [What someone will ask for] — [why not]

## 6. Constraints
**Envelope** <!-- Product facts that architecture and design build on; an unknown gets a tagged default. A personal tool: one line ("single user, local data, no uptime promise"). -->
- **Scale:** accounts at launch and in 12 months; peaks
- **Data:** none, personal, sensitive or regulated; whose data must never be visible to whom
- **Failure:** the cost of an hour down and of a lost record; product-wide speed or accuracy bars
- **Platforms:** devices, locales, offline use, accessibility duty; for software others install, how long a version is supported
- **Abuse:** who gains by misusing it (spam, fraud, scraping); any moderation or identity-check duty
- **Systems:** what it reads from or writes to; the tool or process it replaces
- **Imposed:** technology or integrations the business or a customer requires, with the reason
- **AI**, per AI feature: tolerated error by type (wrong vs harmful); how users notice and recover; cost ceiling per successful task; interactive or deferred; what it may do without a person's approval

**Duties** <!-- One line per law or contract that applies. A personal tool: n/a. -->
- [Duty] — [law or contract, jurisdiction; checked YYYY-MM-DD; binding from YYYY-MM-DD] — met by [`feature-key` REQ-NNN | a build-bar step and its owner] in [release]

## 7. Risks
<!-- A pre-mortem: the checkpoint came and the bet failed; the three likeliest reasons. At least one about value or viability (cost, sales, legal, support), and one about adoption when it replaces a tool. Feasibility you can't vouch for is a spike, its fallback agreed in advance. -->
| Why it would fail (graded) | Kind | Earliest signal | Retired by |
|---|---|---|---|

## 8. Open Questions
<!-- Each blocks something and has a default, so nobody waits. Include the calls only a stakeholder can make (approving a departure, a legal reading, more appetite). Delete resolved ones; this is not a changelog. -->
- [ ] [Question] — blocks: [section or feature] · owner: [who] · default if unanswered by [milestone]: [value]
