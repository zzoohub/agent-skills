---
name: product-brief
description: |
  One-page product brief that decides whether a NEW product or direction is
  worth building: the problem, who has it, the evidence so far, and the
  riskiest assumption with the cheapest test that could kill it. Upstream of
  the PRD (the why and whether). Use when: "product one-pager", "I have an
  idea for an app", "I want to build a new product", "is this worth
  building", "which idea should I build", "validate my idea"; also to review
  a brief or record a test result. Do NOT use for: a feature on an existing
  product (feature-spec); a PRD or PRD review (prd-craft); challenging an
  existing brief's or PRD's premise or scope (plan-review); post-launch PMF
  (product-analytics).
---

# Product Brief

One page answering **"Should we build this, and what would prove us wrong?"** It ends in a Decision, never a pitch: argue against the idea as plainly as for it.

## Route first

Defaults (caller may redirect): brief `docs/prd/product-brief.md`, PRD `docs/prd/prd.md`; read whichever exist. Sibling skills are used if available.

- **No product, brief or PRD:** brief first, even for a PRD request, which then goes to PRD authoring (e.g. `prd-craft`) whatever the Decision.
- **Live product or PRD:** a new direction (changed problem, target user or success metric) gets a brief, today's product as context.
- **Several ideas:** one line each (who struggles, best evidence, likeliest killer) in your report, ranked by evidence, then reach you already have; brief the top one.
- **Review or test result:** Self-Review or Output.
- **Not here:** a PRD (PRD authoring); a feature, however big (`feature-spec`); a pitch, deck, business or GTM plan (offer the brief as input).

## 1. Frame the decision

First read the caller's notes and data; if you can search, find today's alternatives, prices, complaints and paid workarounds (templates sold, job posts for the manual role). Then ask at most three questions, in one batch, only where all that is silent, each with its default:

1. Who hits this, when, and what do they do about it today? *Default:* the segment as stated; the workaround [Assumed].
2. What have you seen: someone struggling, paying or hacking around it? *Default:* nothing beyond what you found.
3. What is it for (your own tool, a team's, a startup, a company's new line), and what bar must it clear? *Default:* self-funded (the first segment alone pays a founder's salary); otherwise, state the bar you assume.

No answers? Apply the defaults, then write one complete draft.

**Evidence.** Tag each load-bearing claim with its grade and source:

- **[Committed: …]** money, a signed pilot on their data, or an LOI naming price and terms, signed by the budget owner.
- **[Observed: …]** behavior seen or recorded: a workaround, time or money spent, a log, a cited dataset.
- **[Said: …]** their own account of a specific past instance.
- **[Assumed]** everything else: future intent ("I'd pay for that"), compliments, answers to a pitch, sign-ups from your own circle, synthetic users, forecasts, unsourced market knowledge, applied defaults.

A founder's own pain is [Observed] for one person. Count people, not quotes. Never invent a source or present an estimate as fact.

## 2. Find what kills it

Run a pre-mortem: "A year from now this failed. Why?" Negate each reason into an assumption, covering the problem, reach (adoption, if internal), value over the status quo, who pays, unit cost, feasibility and permission (regulation, platform policy). Keep the three most lethal × least evidenced. Feasibility leads only when a technical unknown would kill it outright; then test real cases at the user's quality bar, not a demo.

Where the risk usually sits:

- Consumer: repeat use and cheap reach; test the second use, not the first.
- User isn't the buyer: budget and urgency; ask who signed for the last tool bought for this job.
- "AI can now…": that the job already costs someone time or money, and that your edge survives the next model release.
- Two-sided: hard-side liquidity in one niche (hand-match the first deals).
- A company's new line: today's channel sells to this buyer without cannibalizing.

Test row 1 the cheapest way that could prove you wrong. Ask about the last time it happened, never "would you use it". Payment needs a pre-sale, priced LOI or paid pilot; value, the outcome delivered by hand to 3–5 users; reach, the first 10 recruited from the named channel; a smoke test, a costly action from the named channel (say what exists; refund any charge). Set every Next test field before it runs; if 10–20 people can't separate pass from kill, ask for a costlier action, not more people. A middle result reruns once, changing one thing (segment, offer or channel); a threshold moved afterwards makes a new test. *Break:* if a working version (even AI-built) costs less than the test, build it; usage from the named channel, after a costly action, is the test.

## 3. Decide and draft

**Decision**, one, with one reason:

- **Test first:** whenever no rule below is met; the test is the deliverable.
- **Pursue → PRD:** every row at least [Observed], and the problem [Observed] in ≥5 independent target users (or the whole segment, if smaller) or [Committed] by one with money or a signed pilot. Funded by others? The Decision line adds the ask (people × weeks, and what it displaces); from a team-quarter up, payment must be [Committed]. *Break:* your own tool (not for sale) or a mandate (compliance, contract) is its own evidence; scope a mandate to its minimum.
- **Park:** a real problem shown to lack a why-now, reach, or a prize that clears the bar, or a second middle result. Name what reopens it.
- **Kill:** the test hit its kill threshold and no segment in or near the results did better, or a law or platform policy forbids the core mechanism. Keep the file so it isn't re-argued.

The Decision advises; the user decides.

```markdown
<!-- ≤500 words below the header, ≤250 for your own or one team's tool: count them. All rows [Assumed]? Keep all but the test short. Drop fields that don't apply; keep every H2. -->
# [Product] — Product Brief

**Date:** [today, YYYY-MM-DD] | **Decision:** [Test first / Pursue → PRD / Park / Kill]: [one reason]
**In one line:** For [who, at what moment], who today [workaround], [direction] so they [outcome].

## Problem

**What:** [The pain and its cost, tagged. Name no product: "users want a dashboard" is a solution.]

**Target user:** [A concrete segment and when it bites; the buyer, if different; where to reach the first 10 (unknown? Reach is row 1).]

**Why now:** [What changed, and why the incumbent or last attempt failed (a candidate row 1).]

**Size of prize:** [Bottom-up: reachable who × how often × price or hours saved, tagged, against the bar; never a market-report share.]

## Direction

[One paragraph: the experience, not features; the wedge (first segment and job where we're clearly better); who we ignore first.]

**Core bet:** We believe [segment] will [behavior] because [insight or access others lack] [grade]; we're wrong if [observation].

**Status quo to beat:** [Today's way (nothing, an adoptable tool, a general AI assistant) and the step change that makes them switch; "no competitors" means no market or no search.]

## Success Signal

[2–3 sentences: the observable change that says it works; no target, counter-metric or timeframe. "Engineers check deploy health unprompted", not "cut check time 50% by Q3".]

## Riskiest Assumptions

| # | If false, the idea dies | Evidence now |
|---|---|---|
| 1–3 | [assumption, worst first] | [grade: source] |

**Next test (row 1):** [method; who and how many, from which channel] · Kill: [number, set first, that stops you even if you like the idea] · Pass: [number that justifies the next, costlier step, per the prize math] · [timebox], [cost]

## Open Questions

- [ ] [Decision-level, e.g. "Does the ops lead or the CFO own this budget?"]
```

## Output

Write the brief to its path, updating in place; without file writes, return it inline.

- **Canonical file:** the chosen direction; alternatives are siblings `product-brief-{slug}.md` beside it. A winner swaps in; each loser gets Park or Kill and one line why.
- **Updates:** confirm before changing the canonical Problem or Target user (no answer → a sibling). A test result updates tags and Decision, adds `Tested [date]: [test] → [result]` under Next test, and re-ranks the rows.
- **Vision pivot** in the PRD: refresh the header, Problem and Direction too.
- **Report back** the path, Decision, row 1 with its test, and the user's questions, not the brief.

## Self-Review

Before presenting, and as the review rubric:

- The Decision follows its rules from the tags.
- No invented source, estimate presented as fact, or future intent above [Assumed].
- The Problem names no product; Size of prize is bottom-up; Success Signal has no target, counter-metric or timeframe.
- Row 1 is the most lethal × least evidenced; its Next test fills every field, with a numeric kill and a pass the prize math justifies.
- **Footprint:** within the template's word limit, counted; no feature list, KPI target, timeline, UI, tech, method names or tag legends. Over, shorten Direction and Open Questions first, never the test.

A review (≤300 words, verdict on the Decision first) ranks findings Critical (could flip the Decision), High (weakens row 1 or its test), Medium (a reader could misread or misuse it), Low (wording), quoting each line with its replacement; edits only on request.
