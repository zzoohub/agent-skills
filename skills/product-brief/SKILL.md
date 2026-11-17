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

## Premise

**An idea is a chain of beliefs, and it fails at the weakest one.** Someone has the problem often enough to care. Your way beats what they do today by enough to switch. You can reach them. Someone pays. It can be delivered at their quality bar for less than it earns. Nothing forbids it. Building a working version has become cheap, which tempts people to skip this page, but a build only shows that it can be built. Whether anyone has the problem, can be reached and will pay costs as much to learn as it ever did.

The brief is one page that answers **"Should we build this, and what would prove us wrong?"** It ends in a Decision, not a pitch, so it argues against the idea as plainly as for it. Four rules follow:

1. **Problem before product.** The problem is written so that it stays true if the solution changes.
2. **Evidence is graded by what it cost the person who gave it.** Money outranks behavior, behavior outranks stories, and the rest is assumption, future intent included.
3. **Test the weakest link first, the cheapest way that could prove it wrong.** A working build is one such test, and only for the links it exercises.
4. **Numbers before data.** Kill and pass thresholds are written before the test runs. A number chosen afterwards only describes the result.

## Route

Defaults (the caller may redirect): brief `docs/prd/product-brief.md`, PRD `docs/prd/prd.md`; read whichever exist. Sibling skills named here are used if available.

- **Nothing exists** (no product, brief or PRD): write the brief, even when a PRD was asked for. PRD authoring (e.g. `prd-craft`) follows, whatever the Decision.
- **A live product or a PRD:** only a new direction gets a brief (a changed problem, target user or success metric), with today's product as context. A feature, however big, goes to `feature-spec`.
- **Several ideas:** one line each in your report (who struggles, the best evidence, the likeliest killer), ranked by evidence, then by reach you already have. Brief the top one.
- **A test result, or a brief to review:** Updates and Self-Review, below.
- **Not a brief:** a pitch, a deck, a business or go-to-market plan. Offer the brief as their input.

## 1. Frame the problem

Read the caller's notes and data first. If you can search, find what people use today, what it costs, what they complain about, and what they already pay to work around it (templates sold, job posts for the manual role). Write the pain, the moment it bites and what it costs: "studios need a booking app" is a solution.

Ask at most three questions, in one batch, only where all of that is silent. Each has a default, so the draft never waits:

1. Who hits this, when, and what do they do about it today? *Default: the segment as stated; the workaround [Assumed].*
2. What have you seen: someone struggling, paying, or hacking around it? *Default: nothing beyond what you found.*
3. What is it for (your own tool, one team's, a startup, a company's new line), and what bar must it clear? *Default: self-funded, where the first segment alone must pay a founder's salary; otherwise state the bar you assume.*

**Grade every claim the Decision rests on**, with its source:

- **[Committed: …]** money, a signed pilot on their own data, or a letter of intent naming price and terms, signed by whoever owns the budget.
- **[Observed: …]** behavior seen or recorded: a workaround, time or money spent, a log, a cited dataset.
- **[Said: …]** their own account of a specific past instance.
- **[Assumed]** everything else: future intent ("I'd pay for that"), compliments, answers to a pitch, sign-ups from your own circle, synthetic users, forecasts, unsourced market knowledge, every default you applied.

A founder's own pain is [Observed] for one person. Count people, not quotes. Never invent a source or present an estimate as a fact.

## 2. Find the weakest link

Run a pre-mortem: "A year from now this failed. Why?" Turn each reason into the link it breaks (inside a company, reach means adoption), and keep the three that are most lethal and least evidenced, worst first. Feasibility leads only when a technical unknown would kill the idea outright.

| The idea | Look first at |
|---|---|
| Consumer | Repeat use and cheap reach: the second use, not the first |
| The user isn't the buyer | Budget and urgency: who signed for the last tool bought for this job? |
| "AI can now do this" | Whether the job already costs someone time or money, and whether your edge survives the next model release |
| Two-sided | Liquidity on the hard side, in one niche (hand-match the first deals) |
| A company's new line | Whether today's channel sells to this buyer without cannibalizing |

## 3. Design the test

Test row 1, and set every field of Next test before it runs.

| Row 1 is about | Cheapest honest test | Counts as evidence |
|---|---|---|
| The problem | Ask about the last time it happened, never "would you use this?" | A specific recent instance, and what it cost them |
| Value over today's way | Deliver the outcome by hand to 3–5 target users | They come back for it unprompted |
| Reach | Recruit the first 10 through the channel you named | How many came, and what each cost |
| Payment | A pre-sale, a priced letter of intent or a paid pilot | Money, or a signature under a price |
| Feasibility | Real cases at the user's quality bar | Results on cases you didn't pick, not a demo |

- **A smoke test** (a page with an offer) counts when visitors come through the named channel and the action costs them something. Say what exists; refund any charge.
- **When a working version costs less than the test, build it.** Its usage is evidence only from people who came through the named channel and paid some cost to get in, and it never tests reach or payment unless it asks for them.
- **Small samples:** if 10–20 people can't separate pass from kill, ask each for a costlier action, not for more people.
- **A middle result** reruns once, changing one thing (the segment, the offer or the channel). A threshold moved afterwards makes a new test.

## 4. Decide

One Decision, with one reason. It advises; the user decides.

- **Test first:** the default whenever no rule below is met. The test is the deliverable.
- **Pursue → PRD:** every row is at least [Observed], and the problem is [Observed] in five or more independent target users (or the whole segment, if smaller) or [Committed] by one. Your own tool, not for sale, and a mandate (compliance, a contract) are their own evidence; scope a mandate to its minimum. When others fund it, the Decision line adds the ask (people × weeks, and what it displaces), and from a team-quarter up, payment must be [Committed].
- **Park:** a real problem that lacks a why-now, reach, or a prize that clears the bar; or a second middle result. Name what would reopen it.
- **Kill:** the test hit its kill number and no segment in or near the results did better, or a law or platform policy forbids the core mechanism. Keep the file, so the idea isn't argued again.

## 5. Write

Read `references/examples.md` while drafting: weak lines next to better ones.

```markdown
<!-- At most 500 words below the header (250 for your own or one team's tool): count them. When every row is [Assumed], keep everything but the test short. Drop fields that don't apply, but keep every H2 and label: other skills read them by name. -->
# [Product] — Product Brief

**Date:** [today, YYYY-MM-DD] | **Decision:** [Test first / Pursue → PRD / Park / Kill]: [one reason]
**In one line:** For [who, at what moment], who today [workaround], [direction] so they [outcome].

## Problem

**What:** [The pain and what it costs, graded. No product named.]

**Target user:** [A segment concrete enough to list by name, and the moment it bites; the buyer, if different; where the first 10 come from (unknown: reach is row 1).]

**Why now:** [What changed, and why the incumbent or the last attempt failed (a candidate for row 1).]

**Size of prize:** [Bottom-up: reachable users × how often × price or hours saved, each graded, against the bar. Never a share of a market report.]

## Direction

[One paragraph: the experience, not features; the wedge (the first segment and job where this is clearly better); who is ignored at first.]

**Core bet:** We believe [segment] will [behavior] because [insight or access others lack] [grade]; we're wrong if [observation].

**Status quo to beat:** [Today's way (nothing, a tool they could adopt, a general AI assistant) and the step change that makes them switch. "No competitors" means no market, or no search.]

## Success Signal

[2–3 sentences: what would be seen if it works. No target, counter-metric or date: "owners stop keeping a paper waitlist", not "cut no-shows 30% by Q3".]

## Riskiest Assumptions

| # | If false, the idea dies | Evidence now |
|---|---|---|
| 1–3 | [the belief, worst first] | [grade: source] |

**Next test (row 1):** [method; who and how many, from which channel] · Kill: [the number, set first, that stops you even if you like the idea] · Pass: [the number that justifies the next, costlier step, per the prize math] · [timebox], [cost]

## Open Questions

- [ ] [Decision-level only, e.g. "Does the studio owner or the franchise set the booking policy?"]
```

Write to the brief's path, updating in place; with no file access, return it inline. The canonical file holds the chosen direction, and alternatives are siblings beside it (`product-brief-{slug}.md`). When one wins it swaps in, and each loser gets Park or Kill with one line why.

**Updates.** A test result updates the grades and the Decision, adds `Tested [date]: [test] → [result]` under Next test, and re-ranks the rows. Confirm before changing the canonical Problem or Target user (no answer: write a sibling). A pivot recorded in the PRD refreshes the header, Problem and Direction.

**Report back** in 150 words or fewer: the path, the Decision, row 1 with its test in one line, and your questions. Not the brief.

## Self-Review

Before presenting, and as the rubric for a review:

- The Decision follows from the grades by step 4's rules.
- No invented source, no estimate presented as fact, no future intent above [Assumed].
- The Problem names no product. Size of prize is bottom-up. The Success Signal has no target, counter-metric or date.
- Row 1 is the most lethal and least evidenced belief. Its Next test fills every field, with a numeric kill and a pass the prize math justifies.
- **Footprint:** within the word limit, counted. No feature list, KPI target, timeline, UI, technology, method names or tag legend. Over the limit, shorten Direction and Open Questions first, never the test.

**A review** of an existing brief is a critique in 300 words or fewer, opening with a verdict on the Decision. Rank what fails: Critical could flip the Decision; High weakens row 1 or its test; Medium lets a reader misread or misuse it; Low is wording. Quote each line with its replacement, and edit only on request.
