---
name: growth-loops
description: |
  Designs, models and debugs growth loops and affiliate or ambassador programs:
  whether a loop is worth building, which to fund, its incentive structure and
  fraud guardrails, why it stalled.
  Use when: "referral program", "refer a friend", "invite flow", "viral loop",
  "K factor", "affiliate program".
  Do NOT use for: page or signup-flow conversion (cro); reward or commission
  amounts (pricing; this skill owns the incentive structure); measuring a live
  loop (product-analytics; this skill owns the K model).
---

# Growth Loops

## Premise

A loop is an investment, judged by what each incremental customer costs through it, the moat it leaves (exposure, collaboration and network loops leave assets; pure-incentive referral, none) and its cost to the people it runs through; not by K. Assume K < 1: a loop amplifies other channels and rarely sustains itself. "No-go, do X instead" is a complete answer. Solve the problem behind the ask, not its wording: when the evidence puts it elsewhere (retention, pricing, the invitee's first session, a wrong premise), say so and solve it or hand it off with enough detail to act on; state any scope cut and why.

## Frame the request

**Read first** (defaults; caller may redirect): in `biz/analytics/`, `tracking-plan.md` (qualifying and referral events), `funnels.md` (retention), `kill-criteria.md` and the latest `reports/` (live K, signups by source); `biz/marketing/pricing.md`; `biz/growth/experiments.md`; the referral doc.

**Ask once, in one batch, only what those lack and the answer turns on**; a subagent that cannot ask applies the defaults as labeled assumptions and lists the questions in its return.
1. What decision does this feed, who makes it, can it be undone, must someone be persuaded? (The asker decides; Check 5 says what is one-way.)
2. Does cohort retention flatten, and at what level? (Unproven.)
3. What does a non-user see during normal use, and who must join for the inviter to get value? (Nothing; no one.)
4. The decision's unit, what it buys (new paying accounts, seats, active users); ARPU or ACV; value unit for rewards (credits, storage, plan months); gross margin, payback target, next-best channel's incremental CAC, horizon? (New accounts reaching the qualifying event; the billed unit; unknown economics: state break-even conditions, not targets; 12-month payback; two quarters.)
5. Signups by source over the last 2–3 months, the share citing a friend; app install in the path; markets; regulated category? (q unmeasured; web only, one market, unregulated.)

**Size by stakes, never by phrasing.** Checks, gate and model run on every request; budgets cap prose, never the analysis or a material finding (compress it to one line, or exceed the budget and name it). A one-line question about a costly or one-way move (Check 5: a reward, a channel cut, partner terms, pricing) gets the full analysis and a short answer.

## Checks

Run before any number or verdict; restate each biased input corrected or bounded. Each check that matters is one line of the answer, the one that could flip the verdict first.
1. **Trace the product**: who acts, what they send or make, what a non-user sees, how they arrive and reach value, where the chain breaks.
2. **Reconcile**: recompute each rate from its counts. K ≈ (a cycle's qualified referred units ÷ its new units) × (1 + growth per cycle); a claimed K far above that is a definition problem, and K ≥ 1 with flat inflow an artifact. One meaning per word across documents (signup, active, qualified, referred, window, user or account); where they differ, use the decision's.
3. **Incrementality on every side**, the loop's (q) and every compared channel's: last-click credit flatters branded search, retargeting and coupon or review sites, which harvest demand others created (referrals included); strip or bound it (lift test, else a stated range). A new reward starts paying for existing word of mouth.
4. **The decision's unit**: for a revenue decision, new paying accounts; an invitee joining the inviter's account is expansion (seat revenue, via pricing), on its own line.
5. **Reversibility**: published reward terms, partner commissions, pricing that taxes a loop and an installed-base launch can't be taken back cleanly; a cut channel's inflow stops at once, its referrals fade over a few cycles (loops.md § Model), and restarting means relearning. Start time-boxed, on a slice.
6. **Who else pays**: users the mechanism taxes, invitees, cannibalized channels, partners, fraud and payout ops, market rules (loops.md § Risks and side effects).

## Gate

Gate before any design; the verdict leads the output. A caller who overrides a no-go gets the no-cash version, flagged.

| Condition | Verdict (break when) |
|---|---|
| Retention unproven or declining | No-go for cash rewards: share-the-result and word-of-mouth capture only; fix retention first (pre-launch waitlist: gate on waitlist-to-active conversion) |
| Normal use reaches no non-user | Referral is the only direct loop, judged as a channel by q_min |
| A typical user can't name several reachable people with the same need | No-go for referral: use exposure, content, paid or sales (stigmatized need: discreet 1:1 invites that never name the category) |
| One-off or episodic purchase | A channel, not a loop, judged by q_min: long attribution window, ask when value is realized |
| Regulated category (investments, crypto, lending, health) | Check the market's incentive rules; some ban referral bonuses (e.g. high-risk investments) |

## Model

```
K_W = qualified referred units ÷ cohort size in that unit, within W days of the cohort's signup  (K30, K90);
      unit: the decision's unit, what it buys (default: new accounts reaching the qualifying event)
    = p·k·c·a   p share of the cohort who share or expose; k clicks (or non-user views) per sharer;
                c click (or view) → signup, matching k; a signup → qualifying event
Amplification ceiling 1/(1−K) for K < 1, on non-referral inflow only
q = incrementality: share of qualified referred units that would not have come anyway
Effective CAC = [(1−K)·CAC_paid + K·r] ÷ [(1−K) + q·K]   r: both sides' reward, fraud leakage and payout ops, per qualified referral
q_min = r ÷ CAC_c  (× LTV_next ÷ LTV_referred when they differ)
CAC_c = min(next-best channel's incremental marginal CAC, payback months × monthly gross profit per unit);
        no paid channel yet: the payback term alone. CAC_paid is incremental too.
```

- Tag every rate measured, benchmark or assumption, low / base / high; a single-point K is a guess. Unlaunched: p from existing sharing (link copies, exports), c from cold-traffic landing conversion, never a case study.
- q from a holdout; before one, q ≈ 1 − friend-cited new units per month before launch ÷ referred new units per month after, at equal total volume (projected if unlaunched); usually optimistic, as surveys undercount word of mouth.
- A signup-level K is gross: label it, never target it.
- **Worth building** only if horizon months × monthly new units × K × (q·CAC_c − r) covers build, vendor and fraud-ops cost (break-even K: where they match); else No-go: a share link and "how did you hear" capture until volume clears it.
- **q_min sets the verdict**: above 1, No-go for cash (product value or nothing); 0.5–1, Test first (cash on a randomized slice, with a holdout); 0.2 to under 0.5, Go with holdout; below 0.2, Go, and measure. Break when the product or market is new, with no word of mouth yet (q ≈ 1).

Event mapping, cycle time, decay, finite pools, worked example: `references/loops.md` § Model.

## Procedure

**Decide or review** (a go/no-go, a live-program change, a proposed design): the verdict in plain words, the corrected number it rests on (ranged), one line per check that matters, what would change the verdict, and ranked fixes for a design. Cheap and reversible: ≤ 150 words; costly or one-way: ≤ 400, plus a forwardable note if someone must be persuaded (§ Output).

**Model** (≤ 150 words): model table and economics. **Choose** (≤ 400 words): which loops to fund, ranked (loops.md § Choose).

**Design** (loops.md § Loop spec; affiliates: loops.md § Affiliates and ambassadors):
1. Classify the loop by its forcing question (loops.md § Loop types); fund one primary loop, as two under-invest in both.
2. Fill the model table from evidence; the lever is the term whose relative lift is cheapest (K is a product), often participation, not the largest absolute drop. Break when the term is structurally capped (OS prompts, app install, payment walls).
3. Set trigger, incentive (on the limiting term), mechanism and attribution, invitee path to first value (loops.md § Design decisions) and Abuse Guardrails (loops.md § Abuse Guardrails).
4. Price the side effects of a mechanism that taxes users: their activation, conversion and retention, tested by user stage and tier (loops.md § Risks and side effects).
5. Pre-register the experiment (loops.md § Measurement); it stays a proposal until its owner approves (§ Output).

**Diagnose** (≤ 400 words: ranked causes, each with its check and fix): follow loops.md § Diagnose; never propose incentives or copy before decomposing.

## Output

Write a loop design to the referral doc (default `biz/growth/referral-program.md`; caller may redirect the `biz/<area>/` root) as a loop spec, updating it in place; with no file-write capability, return it inline. Other jobs answer inline unless asked to save; Diagnose also updates the doc's measured Model rows if it exists.

**Never edit a record another owner keeps** (experiment log, tracking plan, pricing doc, anyone's status): list proposed changes in the answer or the referral doc, each with its owner. Once the owner approves a test, its card goes to the experiment log (default `biz/growth/experiments.md`; caller may redirect) as a cro test card, if available: this skill sets the randomization unit, program holdout, primary metric and Decision line; cro sizes the test.

**Write for the reader who acts**: plain words and counts ("about 3 in 10 new customers came through an invite"); symbols only in the Model, Economics and Decision lines, each glossed once in plain words. Each recommendation names an owner, a checkpoint date and the metric threshold that confirms or reverses it. When people disagree, state each position at its strongest, credit what it gets right, answer it with evidence. When the asker must persuade someone, end with a note they can forward (≤ 200 words): recommendation, the numbers that carry it, main risk, the ask.

## Boundary

This skill owns the K model (definition, amplification, targets) and the incentive structure. Each if available: **pricing** sets reward and commission amounts, packaging and seat prices (hand it side, value unit, r_max); **product-analytics** measures the live loop; **cro** owns page and signup conversion; **search-visibility**, content-loop SEO; **copywriting**, invite and referral copy.

## Self-Review

- Verdict first, per the gate, worth-building and q_min rules; a no-go names what to do instead and what reopens it.
- Every check ran, whatever the phrasing; biased inputs restated corrected or bounded; no material finding cut for budget.
- K, CAC and q in the decision's unit, incremental on every side, tagged and ranged; K names window, qualifying event and cohort; signup-level K labeled gross; Choose ranked by headroom ÷ cost; Diagnose decomposed before any fix.
- Each rewarded side tied to the term it lifts, none where normal use shares; any inviter reward paid after a hold on a costly-to-fake event in the decision's unit (first payment for paying accounts); any invitee value bounded, usable at once, only through use; Abuse Guardrails exactly when the reward has value; each taxed user group has a guardrail metric.
- The experiment's primary metric is the decision's unit across all entry paths, so an untracked effect still shows, or its blind spot named; smallest detectable effect stated against q_min; with an app install in the path, attribution tested per platform.
- No other owner's record changed; plain words outside the Model, Economics and Decision lines, each symbol glossed once; owners and checkpoints set; each contested position answered; a forwardable note when someone must be persuaded.
- **Footprint**: prose within the job's budget (§ Procedure; loops.md § Loop spec), or the overrun names its finding.
- No brand precedent without its enabling condition; no narration of this skill's steps.
