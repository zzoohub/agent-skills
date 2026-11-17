---
name: prd-craft
description: |
  Write the PRD for a new or undocumented product as a testable bet: outcome
  metrics with counter-metrics, a first release (v0.1) that tests the
  riskiest assumption with real users under a stop rule fixed in advance,
  what waits or is never built, and the constraints architecture and design
  need. Reads the product brief first. Also reviews a PRD and records a
  release's checkpoint result. Use when: "write a PRD", "product
  requirements document", "spec out a product", "review my PRD", "is this
  PRD ready", "the v0.1 results are in". Do NOT use for: one feature on an
  existing product (feature-spec, once per feature; never re-run this to add
  features); premise or scope challenges (plan-review).
---

# PRD Craft

## Premise

**A PRD is a bet, and its first release is the test.** A product is a belief about what people will do, and the expensive way to be wrong is to find out late. What a PRD was always for stays: the problem before the solution, numbers that say where they came from, an outcome someone can measure, a line between what is in and what is out. What changed is the limit on scope. Building has become cheap, so what fits before the deadline is rarely the limit any more. The limit is what the test needs: every extra feature blurs the signal, must be verified, supported and kept true, and may commit data or promises that can't be taken back. Ceremony that informs no decision goes: estimates nobody can ground, a ladder of releases nobody rereads, specs for features that may never be built.

Five rules follow:

1. **The first release is a test, not a small product.** It retires the riskiest belief, takes its shape from that risk, and ends in a rule for continuing, changing or stopping that is fixed before any data.
2. **One segment finishes one job, end to end, with real people.** A release its audience can't get into, get help with or leave tests nothing. Neither does one layer of everything.
3. **Nothing enters the release unless the test needs it, or running it lawfully with real people does.** However cheap it is to build.
4. **Never invent.** Every number and claim the scope rests on says where it came from. An unknown is written as unknown, with how it gets measured.
5. **Follow the evidence, and say so.** When it contradicts what was asked, the draft follows it and names the departure for the owner to approve.

Done means the owner can approve the stake and the rule, an architect can size the system from §6, a designer knows which job comes first, an operator can run the release from first invite to deletion, and none of them needs the conversation that produced it.

## Route

Defaults (the caller may redirect the `docs/prd/` root): brief `docs/prd/product-brief.md` or a `product-brief-*.md` variant, PRD `docs/prd/prd.md`, one spec per feature at `docs/prd/features/{feature}.md`. Sibling skills named here are used if available.

- **Nothing built, no brief:** a brief first (`product-brief`), even when a PRD was asked for. Without that skill, ask the caller; failing that, write with the core bet [Assumed].
- **A brief, no PRD:** write. Several variants: confirm which (default: the canonical file). A Decision other than Pursue goes ahead only on an explicit PRD request, its untested rows carried as assumptions; otherwise ask, or, unattended, write nothing and report the Decision.
- **A live product, no PRD:** write. What shipped goes under Shipped, usage is evidence, and existing specs keep their keys and REQ IDs.
- **A PRD exists:** never regenerate it. Patch a named change (a price, the appetite, a constraint, a risk) through every section it touches. Unclear what changed: ask, or, unattended, review instead and say so. A new or changed feature goes to `feature-spec`, however big.
- **A pivot** (the problem, the target users or the primary metric changed): confirm it with the owner, then write over the bet in place. Each existing feature is kept, revised or retired; a retired one moves to Never with its date and reason. The brief is refreshed through its own skill.
- **"Is it ready?", review, audit, improve:** Review. **A release reached its checkpoint:** Checkpoint.
- **Challenge the premise; cut or expand the scope:** `plan-review`, scope mode.

## 1. Read and reconcile

Read the brief's Decision, Core bet, Success Signal, Riskiest Assumptions, Next test and Open Questions. The Success Signal defines the §4 primary. Row 1 is what v0.1 tests, and an unrun Next test that costs less than building runs first. The other rows seed §7, and the open questions go to §8. Then read anything newer: research, usage, pilot and sales notes, stakeholder asks.

- **The request is a guessed solution.** Name the pain behind it, who has it, how often and at what cost. If a setting, a process change or an existing tool would solve it, say so first. If the evidence puts part of the problem outside the request (a step before or after it), the PRD covers it or names who must.
- **Evidence against the brief** wins in the draft when it is graded at least as strong as what it contradicts, and never silently: each departure (an ask dropped or changed; a different segment, metric or scope) gets a §3 line with its approver, marked proposed. Weaker contrary evidence becomes a risk or an open question. Recommend revising the brief through its own skill, because marketing, architecture and analytics read it.
- **Grades** are the brief's, strongest first: [Committed] money, a signed pilot or a priced letter of intent; [Observed] behavior seen or recorded; [Said] an account of a specific past instance; [Assumed] the rest, future intent and an unsigned "we'll try it" included.

## 2. Ask once

One batch, only what the brief, the evidence and the request leave open, each with its default:

1. **Appetite and owner:** how much time, people and money before the continue/change/stop call, and who makes it? *Six weeks (a personal tool: one), called by the requester.*
2. **Pain and segment:** who hurts most, how often, at what cost; have they paid, hacked around it or left, or only said so; who pays, self-serve or through sales? *The brief's target user, self-serve; frequency and cost unknown, measured in v0.1.*
3. **Decision rule:** which result means continue, change or stop, and what must not get worse? *Thresholds by judgment, tagged target.*
4. **Hard constraints:** a deadline, jurisdictions, regulated data or outputs, mandated platforms, a contracted build? *None known; an external product holds personal data, so privacy duties start with its first real user.*
5. **Systems:** what must it read from or write to, and what tool, sheet or process does it replace, holding how much live data and open work? *It replaces today's workaround, whose live records move at cutover.*

If nobody can answer, or the caller says "just write it", draft on the defaults, marked [Assumed], and list the questions in §8 and the report, those gating v0.1 first.

**Reach** is who the product can affect: `personal` (your own tool), `team` (internal users) or `external` (customers, the public). A personal PRD fits a page and may skip specs. Regulated or sensitive data, money movement, or an appetite beyond a team-quarter give a team product external depth.

## 3. Shape the bet

The belief that would kill the product and has the weakest evidence is the **dominant risk**. It decides what v0.1 is:

| Dominant risk | v0.1 is | It passes when |
|---|---|---|
| Value: will they choose it, or buy it? | The thinnest end-to-end path for one segment's core job; a manual back end is fine | The primary or leading metric moves for real users |
| Usability: demand is proven, the workflow isn't | The core flow at production quality, the rest stubbed | Task success and time beat today's workaround |
| Feasibility: AI quality, a hard integration | A spike on representative inputs before any shell, its fallback agreed first (narrower scope, a person in the loop, stop) | AI: the bar is met on a held-out set nobody tuned on. Integration: the real system at expected volume, failures included |
| Viability: who pays, unit cost, legal | A pre-sale, pricing or compliance test before breadth | Paid pilots or letters of intent naming price and terms; cost per task under the ceiling |
| Adoption: it replaces a tool or process | One complete workflow, with the imports and integrations it needs, that lets one segment drop the old tool | That segment is fully off it: no dual-running, no double entry |

Exceptions: a hard dependency gates the test (build only what it needs); the build is mandated or for compliance (an acceptance gate replaces the thresholds); the tool is personal (v0.1 is what you would use this week).

**The decision rule** reads the §4 primary, or its leading indicator when the primary can't move by the checkpoint. Set the checkpoint by how long the signal takes to show, not by how long the build takes. The rule must be settleable at its sample: with few adopters, count them ("at least 2 of 3 teams") and never pool a rate; a rare event needs a longer window (at two a month, a month with one or none comes up four times in ten by chance). Continue, change and stop don't overlap, and who calls it is named before the data arrives.

## 4. Make it runnable

Before listing features, walk three people through the release:

- **One member of the audience,** from first contact to leaving: join (invite, sign-up, sign-in), bring their data in, use and change it (edit, undo, roles), get help or dispute (support, corrections, refunds), leave (export, deletion, the release ending).
- **The operator,** through a week: accounts and access, support, moderation, billing, data requests, incidents.
- **Anyone it records, scores or contacts who has no account:** notice, consent or objection, access, correction, deletion.

Each step they will hit becomes a feature in Now, a manual step in the build bar (who does it, and the volume where that breaks), or a Never line whose reason holds for this audience ("invite-only: no public sign-up"). It is never left to a later release. At this volume most steps are manual and cost one line. Build what touches customer data, money, identity or consent, anything irreversible, and what users would quit over.

**Duties.** Classify what it stores and what it outputs. An output can be regulated when the data isn't: a decision or recommendation about a person (credit, hiring, housing, insurance, care), advice, a health, safety or financial claim, a record a law or contract makes you keep. Each law or contract that applies, checked at its source when writing, becomes a requirement in the release that first incurs it, never only a citation. A test on real people's data incurs its duties in v0.1. What you can't check or settle goes to §8 (owner: counsel; default: the duty applies).

**Replacing a tool, sheet or process** adds the Transition line. An import or integration is a Must when double entry is what would send users back to the old tool.

**A spike or no-build v0.1** lists only what is under test; the end-to-end job and this walk then belong to the first release users get. Duties don't wait.

## 5. Draw the lines

Every capability someone might expect lands in exactly one place in §5: Shipped, Now, Later or Never.

- **A feature** is something a user can say they did (`cancel-and-refill`), never the part that does it (`sms-service`). Its kebab-case key is the same in §5 and in its spec's filename.
- **Now** is the release, in build order, dependencies first. Above the cut line are the Musts: what the release is pointless or unlawful without. A workaround moves an item below the line only when the exit evidence survives it: someone doing the work by hand at this volume, yes; users re-keying data they keep elsewhere, no.
- **Fit.** Size the Musts only from something real (the builder's estimate, the pace of comparable work), as a whole-job range with slack for what it missed. If they don't fit the appetite, move items below the line or into the build bar, or say plainly that the plan is tight and what gives; more appetite is the owner's call (§8). Never trim an estimate to fit. With nothing to size from, write `unconfirmed`.
- **Later** holds what waits, each with the result or event that pulls it in (a binding date is written as a date). Mark `⚠ arch` where adding it late is costly: tenancy, permissions, billing, locales, offline, audit, residency, moderation, a public API.
- **Never** holds only what someone would argue for (a stakeholder's ask, a competitor's feature, the obvious extension), each with its reason.

## 6. Write and hand off

Write from `templates/prd.md` (its comments are format rules) with `references/examples.md` beside you: weak sections next to better ones. Then run the Self-Review.

**Specs.** Each feature in Now needs a feature spec before design and build; Later features get none until a release pulls them in. Once the owner has approved the bet, or when nobody is there to ask, write them through `feature-spec`, dependencies first, handing each the §6 duties it must meet, then set each duty's "met by" to the REQ its spec gave it. Until a spec exists, its line reads `spec owed`. A personal tool may skip specs.

**Report back** in 250 words or fewer, not the document. Lead with what needs a decision: each departure from the brief, a plan that doesn't fit its appetite, a duty waiting on counsel. Then the files written, reach and appetite, the v0.1 decision rule, the defaults applied and the questions to confirm (those gating v0.1 first), and the next step: `plan-review` in scope mode when the bet is weakly evidenced or the scope still arguable, then `software-architecture` and `ux-design`; §4 and the v0.1 rule go to `product-analytics` (tracking plan, kill criteria).

## Checkpoint

When a release reaches its date, take the result from the kill-criteria record (default `biz/analytics/kill-criteria.md`) or the caller. No data is not a pass. A threshold moved after the data is a new test. A primary that moved while a counter-metric broke its floor means change, not continue.

Record it under the release: `Result (YYYY-MM-DD): [metric] = [value] (measured: source) → continue | change | stop, called by [who]`. Measured values replace §4's unknowns.

- **Continue or change:** the release's features move to Shipped with the Result line, and the next bet is planned the way v0.1 was: the next belief to retire, its own audience, rule and cut line, the step 4 walk, and features pulled from Later, each of which then needs its spec. Opening to everyone adds a launch bar: support, docs, pricing, a legal and security review, the §6 bars met.
- **Stop:** Status becomes `Stopped: [reason]`, and the audience gets what the stop rule promised.

## Review

A critique, never a rewrite. Read the PRD, its specs, the brief and any newer evidence, and report only what fails the Self-Review, in 600 words or fewer (every Critical and High, whatever the budget). Open with the verdict: **ready for architecture and UX**, **ready after the Critical fixes**, or **not ready** (no stated problem, or build scope committed before the core bet is tested). Each finding gives its severity, section, the quoted problem and the fix, with patch text for Critical and High. Judge function, not format: map a PRD of another shape onto these sections by role, and never prescribe this template unless asked. Edit only on request; "improve" or "fix" is one (apply the Critical and High patches, report the rest).

## Self-Review

Run before presenting. In a review, each failure is a finding at the severity shown.

- **Critical:** no problem or no segment; success can't be measured; v0.1 can't test the core bet, or its real audience can't run it (no way in or out, a duty it incurs with no requirement); an invented or unsourced number driving scope; something both in Now and in Never.
- **High:** an output as the primary metric ("launched", "500 texts sent"), or a gameable metric with no counter-metric; a §4 baseline that isn't the same quantity as its §1 figure; an outcome or a brief's ask dropped silently; a decision rule its sample can't settle, or thresholds that overlap; no cut line, or nothing below it and no reason; an estimate trimmed to fit; a replaced tool with no dated transition; a costly Later item without `⚠ arch`; a feature named after a part, or one that traces to no problem, metric or step of the walk; a question gating v0.1 with no owner or default; technology nobody imposed; a dead spec link.
- **Medium:** a generic segment; no build bar; only technical risks; a line a cold reader can't follow, or one just as true of a competitor ("seamless", "ensure compliance"); layouts, components or final copy; over the word ceiling with no reason given; a table of contents, a TBD, an empty section, or anything that narrates this method.
