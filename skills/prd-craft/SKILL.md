---
name: prd-craft
description: |
  Write the PRD for a new or undocumented product as a testable bet: outcome
  metrics with counter-metrics, a v0.1 that tests the riskiest assumption,
  has a stop rule and can run with real users, non-goals, the envelope
  architecture needs, and a spec per feature. Reads the product brief first.
  Also reviews a PRD for readiness and records a release's checkpoint result.
  Use when: "write a PRD", "product requirements document", "spec out a
  product", "review my PRD", "is this PRD ready", "the v0.1 results are in".
  Do NOT use for: one feature on an existing product (feature-spec, once per
  feature; never re-run this to add features); premise or scope challenges
  (plan-review).
---

# PRD Craft

A PRD turns a validated direction into a testable bet: who has the problem, the numbers that prove it moved, the smallest release that tests the riskiest assumption and when to stop, what we won't build, and what architecture must know. It also carries what that release needs to run with real people: a way in and out, the operator's work, the legal duties, the move off today's tool. A bet its real audience can't use tests nothing. It never invents precision.

## Modes & Routing

Defaults; the caller may redirect the `docs/prd/` root: brief `docs/prd/product-brief.md` (or a `product-brief-*.md` variant), PRD `docs/prd/prd.md`, one spec per feature at `docs/prd/features/{feature}.md`. Sibling skills named here are used if available.

| Situation | Mode |
|---|---|
| Unbuilt idea, no brief and no PRD | Brief first via product-brief, even if a PRD was asked for, then **Write**; without it, ask the caller, else write with the core bet [Assumed] |
| A brief exists, no PRD | **Write**; several variants → confirm which (default: the canonical file). Over a Test first, Park or Kill Decision, an explicit PRD request proceeds with untested rows as assumptions; otherwise ask, or, unattended, write nothing and report the Decision |
| A brief exists, but newer evidence contradicts its problem, segment, metric or an ask | **Write** on the evidence, deciding each departure (Calibrate) |
| Live product, no PRD, a PRD is asked for | **Write**; usage data is evidence |
| Review, audit or improve a PRD; "is it ready?" | **Review / Audit Mode** |
| A release reached its checkpoint | **Checkpoint** (below) |
| Add or change features (a PRD exists, or the product is live) | feature-spec, once per feature. Never re-run this skill to add features; a feature is not a pivot, however big |
| Pivot: the problem, target users or success metric changed | Confirm the pivot scope, then **Write** over the vision in place |
| A PRD exists, any other request ("write", "rewrite", "update") | Never regenerate it: patch a named change (price, appetite, envelope, a risk) through every section it touches, with Last Updated; unclear → ask what changed; unattended → Review, and say so |
| Challenge the premise; cut, hold or expand scope | plan-review, scope mode |

**A pivot** marks each existing spec keep, revise (via feature-spec) or retire, after confirmation; retiring deletes only an unbuilt spec nothing cites (with its §5 row and §6 entry), else sets its status to `Retired (date): reason` and moves its key to a §7 `[never]` line. It refreshes the brief via product-brief, the brief's one writer; without it, patch only the brief's header, Problem and Direction. Otherwise write only the PRD and its specs.

**Checkpoint.** Take the result from the kill-criteria record (default `biz/analytics/kill-criteria.md`, via product-analytics if available) or the caller. No data is not a pass; a threshold moved after the data is a new test; a primary that moved while a counter-metric broke its floor means change, not continue. Under the release add `Result (YYYY-MM-DD): [metric] = [value] (measured: source) → continue | change | stop, called by [who]`; measured values replace §4's unknowns. Continue or change: re-plan later releases by the next assumption to retire. The next release is planned like v0.1: its own lines from Tests to Transition, tags and a cut line, the step 4 walk for its audience, and its stubs deepened via feature-spec. Opening to everyone adds a launch bar (support, docs, pricing, legal and security review, §8 bars met). Stop: Status `Stopped: [reason]`, and pilot users get what the stop rule promised. A changed problem, segment or metric is a pivot.

## Calibrate

**Read first** the brief's Decision, Core bet, Success Signal, Riskiest Assumptions, Next test and Open Questions: the Success Signal defines the §4 primary; riskiest-assumption row 1 is what v0.1 tests (an unrun Next test cheaper than building runs first); the other rows seed §8; open questions go to §9. Then anything newer: research, usage, pilot or sales notes, stakeholder asks. A live product adds what shipped, usage and support data and every spec in `features/`; a pivot, the existing PRD.

**Evidence against the brief**, graded at least as strong as the evidence it contradicts, wins in the draft, never silently: each departure (an ask dropped or changed; a different segment, metric or scope) gets a decided §3 line with its approver. Weaker contrary evidence becomes a §8 risk or a §9 question. Recommend revising the brief through its owner (product-brief, if available): marketing, architecture and analytics read it, and a stale one misleads them all.

**The problem behind the request.** A described product is a guessed solution: name the pain, who has it, how often and what it costs them. If a setting, a process change or an existing tool would solve it, say so first. If the evidence puts part of the problem outside the request (a step before or after it, a need nobody asked for), the PRD covers it or names who must.

**Reach** sets depth and the template's word ceiling: personal (your own tool; specs optional), team (internal users), external (customers or the public). Regulated or sensitive data, money movement or an appetite over a team-quarter give a team PRD external depth. The ceiling limits what you write, never what you check.

**Evidence** uses the brief's grades, strongest first: [Committed] (money, a pilot, a priced LOI), [Observed] (behavior seen or recorded), [Said] (their account of a specific past instance), [Assumed] (all else, future intent included). The assumption that would kill the product with the weakest evidence is the **dominant risk**; it decides what v0.1 is:

| Dominant risk | v0.1 is | Exit evidence |
|---|---|---|
| Value: will they choose or buy it? | the thinnest end-to-end path for one segment's core job; a manual back end is fine | the primary or leading metric moves for real users |
| Usability: demand proven, workflow not | the core flow at production quality, the rest stubbed | task success and time beat today's workaround |
| Feasibility: AI quality, a hard integration | a spike on representative inputs, before any shell, its fallback (narrower scope, a person in the loop, stop) agreed before it runs | AI: the bar met on a held-out set nobody tuned on; integration: the real system at expected volume, failures included |
| Viability: who pays, unit cost, legal | a pre-sale, pricing or compliance test before breadth | paid pilots or LOIs naming price and terms; cost per task under the ceiling |
| Adoption: replacing a tool or process | one complete workflow, with the imports and integrations it needs, that lets one segment drop the old tool | that segment fully off it: no dual-running, no double entry |

*Break when* a hard dependency gates the test (build only what it needs), the build is mandated or for compliance (an acceptance gate replaces the thresholds), or the tool is personal (v0.1 is what you'd use this week).

**Ask once**, in one batch, only what the brief, the evidence and the request leave open, each with its default and the sections it gates:
1. **Appetite**: time and people before the continue/change/stop call? *Default:* ~6 weeks, one small team (personal: a week). §6.
2. **Pain and evidence**: how often, at what cost; seen them pay, hack around it or leave over it, or only told? *Default:* unknown, measured in v0.1; told, so value is the dominant risk. §1, §6.
3. **Segment and motion**: who hurts most, doing what today, switching for what; who pays, self-serve or sales? *Default:* the brief's target user; workaround and price [Assumed]; self-serve (team: internal rollout). §2, §6, §8.
4. **Decision rule**: which checkpoint result means continue, change or stop, who calls it, and what must not get worse? *Default:* thresholds and counter-metrics by judgment, tagged target; called by the requester, who owns the appetite. §4, §6.
5. **Hard constraints**: deadline, jurisdictions, regulated data or output (a decision about a person, advice, a health or financial claim, a record the law makes you keep), mandated platforms, a contracted build? *Default:* none known; an external product holds personal data, so privacy duties start with its first real user. §8, spec depth.
6. **Systems**: what must it read from or write to, and what tool, sheet or process does it replace, holding how much live data and open work? *Default:* it replaces §1's workaround, whose live records move at cutover; re-keying into a system that stays is manual at pilot volume (build bar), unless only users can do it and evidence says double entry sends them back: then its integration is a Must. §5, §6, §8.

If no one can answer, or the caller says "just write it", draft now on the defaults, marked [Assumed], with the questions in §9 and the report, v0.1-gating first. *Break when* the user wants to think aloud: converse, then converge on a draft.

**Done**: the Self-Review passes, so an architect can size the system from §8, an engineer can tell what v0.1 may fake, a designer can tag screens by §6 release, an operator can run the pilot from first invite to deletion, and anyone can name the date, number and person that decide v0.1.

## Write

1. **Read `templates/prd.md`**; its comments are your format rules. Read `references/examples.md` while drafting §1, §4, §6, §7 and §8.
2. **§1–§4** from the brief, the newer evidence and the answers; a gap is a v0.1 measurement, never an invention.
3. **v0.1, the bet**, shaped by the dominant-risk row, on the template's v0.1 lines. Reject a v0.1 that builds one layer of everything (all plumbing, no finished job): one segment must complete the core job end to end. *Break when* v0.1 is a spike or no-build test: it lists only what is under test, and the end-to-end job and steps 4 and 5 move to the first release users get, except duties: a test that uses real people's data or serves real people meets its §8 Duties in v0.1.
4. **What running it takes.** The first release users get holds what is under test plus what running the test with real people, lawfully, needs. Walk one member of its audience from first contact to leaving, the operator through a week, and anyone it records, scores or contacts without an account (the stages are in the template's §6 comment). Each step they will hit becomes a §5 row, a manual build-bar step with an owner and the volume where it breaks, or a §7 non-goal whose reason holds for this audience ("invite-only: no public sign-up"); never a later stub. At pilot volume most steps are manual and cost a line; build what touches customer data, money, identity, consent or anything irreversible, and what users would quit over. Classify what it stores and outputs, and turn each duty into requirements per the template's §8 Duties, never only a citation or an open question. Replacing a tool, sheet or process adds the Transition line; an import or integration goes above the cut line when the exit evidence would not survive double entry (the template's §6 Must rule).
5. **The cut line**, per the template's §6 rules: whole-job estimates, never trimmed to fit.
6. **Later releases**, ordered by the assumption each retires next and never ahead of what they depend on, dated where the template says. Work waiting on a nameable condition goes to §7 as `[later: trigger]`.
7. **Features** cover the whole product (template §5). A row that moves no §1 problem or §4 metric, and that nothing in step 4 needs, is a non-goal.
8. **§7–§9**, then **specs at depth** (below), the **Self-Review** and the **report back**.

### Specs at depth

One spec file per §5 row, so every link resolves; a shipped row links one only if it exists. When someone can answer, get a go on §1–§6 before full specs if reach is external or v0.1 rests on [Assumed] answers; unattended, write them.
- **Full**: every feature of the first release users get (and of v0.1, if that is a spike). Depth follows obligation, not release: a later feature that carries a duty, moves customer data or money, or decides a one-way door now (the ⚠ arch kinds) gets a full spec, or a stub plus those requirements with acceptance criteria.
- **Stub** for the rest, on the template's stub format.
- **Existing specs** (a live product, a pivot): adopt each kept or revised spec as its §5 row, keeping its key and REQ IDs (a module-named key too: list it in the report); never overwrite one or cut it to a stub.
- *Break when* the build is contracted, fixed-bid, a regulated submission or a single release: full specs throughout. Personal reach may skip specs (then no Spec column, never dead links).

Write full specs through the feature-spec capability in batch mode, on its template, Quality Bar and word budget, handing each spec the §8 duties it must meet. It asks nothing, only proposes splits, renames or reordering, and checks each PRD row, Dev Order entry and filename without changing them; the PRD's Last Updated is set once. Without it, give each spec, within 1,200 words, Problem & Outcome, Behavior, Requirements (`REQ-NNN`, each with acceptance criteria), Edge Cases, Decisions (product choices, marked proposed), Rollout & Existing Data, Out of Scope and Open Questions (missing facts and calls above the spec's authority, each with a default). Once the specs exist, set each §8 "met by" to the REQ ID its spec gave the duty.

**Report back** within 250 words, a summary, not the document. Lead with what needs a decision: each departure from the brief with its approver, and the recommendation to revise the brief; a tight plan, or a bigger appetite to approve; a duty awaiting counsel. Then the files written (full or stub); reach and appetite; the v0.1 decision rule; defaults applied and questions to confirm, v0.1-gating first; the next step. A material finding the budget can't hold still gets its line.

## Review / Audit Mode

A critique by default, never a rewrite: edit only on request, one targeted patch per finding; "improve" or "fix" is such a request (apply the Critical and High patches, report the rest).

1. **Read** the PRD, its specs, the brief if present, and any newer evidence the caller gives.
2. **Audit** against the Self-Review and `references/anti-patterns.md` (its anti-patterns, severity table and trouble map), by function, not format: map a PRD of another shape onto these sections by role; a house convention is a finding only where its function is missing (an unsourced number driving scope, not an untagged one; no cut line, not a missing [Should]). Never prescribe this template unless asked.
3. **Report** failures only, within 600 words, opening with the verdict: **ready for architecture and UX**, **ready after the Critical fixes**, or **not ready** (no stated problem, or build scope committed before the core bet is tested). Each finding gives severity, section, the quoted problem and the fix; patch text only for Critical and High. Every Critical and High finding is reported, whatever the budget.

## Self-Review

Run before presenting; in a review, each failure is a finding.
1. **Problem and segment.** §1 names the pain behind any requested solution, its frequency and cost (tagged) and today's workaround; §2, one first segment by situation, not demographics, and (team or external) the motion. Each difference from the brief (problem, segment, metric, an ask) is decided in §3 with evidence and approver, and the report recommends revising the brief.
2. **Numbers.** Every number the scope rests on is tagged; each §4 baseline is the same quantity as its §1 figure; no invented baseline, statistic, quote or persona.
3. **Metrics.** The primary is a change in behavior or business result, not an output ("launched", "% auto-verified"); each outcome the brief or caller named has a row or a reason it was dropped; each gameable row has a counter-metric with a floor; every column filled, an unknown baseline as its measurement task.
4. **v0.1.** Assumption and risk, audience, checkpoint, build bar, and continue/change/stop thresholds with who calls them (or an acceptance gate), disjoint and settleable at its sample. The first release users get lets one segment finish the core job end to end, with a Should or Could below the cut line or the exception stated; its Musts' high-end whole-job estimates fit ~60% of the appetite, or the whole appetite with §6 giving the reason (proven estimates, low risk) or calling the plan tight and saying what gives.
5. **Runs with real people.** Each lifecycle step its audience and the people it records, scores or contacts will hit, and each operator job, is a row, an owned manual step with its breaking volume, or an argued non-goal; the stop rule covers pilot users and their data; a replaced tool has a dated Transition line, and no integration whose absence the evidence says sends users back sits below the cut line.
6. **Features.** Each §5 row traces to §1, §4 or what running v0.1 needs, and names a user capability (adopted keys stay), with no layouts, components or final copy; §5, §6 and `features/` match one-to-one on the key (no orphan file but a retired spec; no spec-less row unless specs were skipped or the row is shipped); `depends on:` targets exist and sit earlier in §6; spec depth follows release and obligation.
7. **Non-goals.** Each one someone would argue for, tagged `[never]` or `[later: trigger]`, contradicting nothing in §5; costly `[later]` items carry ⚠ arch.
8. **§8.** The envelope present, unknowns as tagged defaults; each duty has its checked source and is met, in the release that first incurs it, by a REQ that exists in the cited spec and states the duty with acceptance criteria (nothing built: a build-bar step with its owner); at least one value or viability risk; technology only where imposed, with its reason.
9. **§9.** Every question names what it blocks, an owner and a default.
10. **Specific and plain.** No §3 value proposition stays true with a competitor's name in place of ours; no sentence states what no one would dispute ("seamless", "ensure compliance"); a stakeholder reading cold follows every line, with no undefined shorthand.
11. **Footprint.** Words below the header counted: within the reach ceiling and each stub ≤150, or over with the reason stated; no material finding cut to fit; no ToC, TBD or empty section; nothing narrates this skill.

## Next Steps

- A weakly evidenced core bet or negotiable scope → plan-review, scope mode; then software-architecture and ux-design.
- §4's metrics and the v0.1 rule → product-analytics (tracking plan, kill criteria); its read returns as a **Checkpoint**.
