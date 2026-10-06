# Growth Loops & Referral Programs

Frameworks for designing compounding user-acquisition loops: viral, content, paid, and integration loops. This file is the canonical reference for referral/viral loop design.

## Table of Contents

1. [The Loop Mental Model](#the-loop-mental-model)
2. [Loop Types](#loop-types)
3. [Referral / Viral Loop Design (5 Stages)](#referral--viral-loop-design-5-stages)
4. [Abuse Guardrails](#abuse-guardrails)
5. [Viral Metrics](#viral-metrics) — includes K Factor (Viral Coefficient), Amplification Factor, Loop Cycle Time
6. [Paid Loop Economics](#paid-loop-economics)
7. [Two Anti-Patterns](#two-anti-patterns)
8. [When NOT to Build a Loop](#when-not-to-build-a-loop)
9. [Common Loop Patterns (Reference)](#common-loop-patterns-reference)
10. [Marketplace Cold-Start](#marketplace-cold-start)
11. [Output Format](#output-format)

---

## The Loop Mental Model

Growth loops are systems where each cycle of input produces output that feeds the next cycle. They compound; funnels don't. A loop has four parts:

1. **Input** — New user / action / content
2. **Action** — What they do
3. **Output** — Artifact their action produces
4. **Re-entry** — How the output brings the next input back in

If any step breaks, the loop collapses into a one-time funnel.

Loops also differ in how defensible they are. Content and network loops accumulate assets — public pages, data, connections — that a competitor can't copy. Pure-incentive referral loops are the most copyable thing in growth: anyone can clone "give $10, get $10." Favor loops that leave a moat behind.

---

## Loop Types

| Type | Input | Output | Examples |
|------|-------|--------|----------|
| **Viral (direct)** | User signs up | Invites people they know | WhatsApp, Dropbox, Calendly |
| **Viral (content)** | User creates public artifact | Artifact attracts new users | YouTube, Notion public pages, GitHub |
| **Paid** | Revenue | Ad spend acquires users | Most DTC |
| **Sales** | SDR contacts prospect | Prospect becomes customer | Enterprise SaaS |
| **Integration / API** | Product embedded elsewhere | New users discover via partner | Stripe, Intercom embeds, Zapier triggers |
| **UGC / Marketplace** | Supply-side user lists | Demand-side user searches | Airbnb, Etsy, Upwork |

Pick one loop to be dominant. Multiple loops can coexist but one must be primary — two "primary" loops is a way to under-invest in both.

The 5-stage framework below is written for **direct viral loops** (the most common request). Content, paid, and marketplace loops reuse the same stages, with the type-specific economics called out in *Paid loop economics* and *Marketplace cold-start* later.

---

## Referral / Viral Loop Design (5 Stages)

The canonical framework for direct viral loops:

### 1. Trigger
**When** does the user get prompted to invite? Match it to a moment of perceived value.
- Bad: immediately after signup (user hasn't experienced value yet)
- Good: right after Aha Moment (user just got the win they came for)
- Great: repeatable trigger on every success event

### 2. Incentive
**Why** would they invite? Two-sided incentives usually beat one-sided (still worth A/B testing for your audience).
- One-sided (inviter gets reward): cheap but feels transactional
- Two-sided (both get reward): aligned interests, higher conversion
- No incentive (pure value share): works only when the product is genuinely better with friends (e.g., multiplayer, collaboration)
- Milestone (reward unlocks at N qualified referrals): concentrates a burst of invites toward a goal — Dropbox's "invite friends for more storage" pattern
- Tiered (escalating reward per successful referral): pays your power-referrers more without overpaying casual ones

Match the incentive to the product's value unit. Credits for usage-priced products. Months free for subscriptions. Cash for finance products. This skill picks the **structure** (one-sided, two-sided, milestone, tiered); for the **dollar value** of a reward tied to subscription/usage pricing, consult `pricing`.

### 3. Mechanism
**How** do they invite? Reduce friction at every step.
- Shareable link (copy + send) — lowest friction
- Native share sheet — capture platform-specific apps
- Email invites — best for professional tools
- Contact import — highest absolute reach but highest friction and privacy risk
- In-product @-mention / co-edit invite — natural, contextual

Pre-fill the message where possible. Never force the inviter to compose from scratch.

### 4. Landing
**Where** does the invitee arrive? A personalized landing converts meaningfully better than a generic signup page.
- Show the inviter's name/photo
- Reference the artifact that brought them (if content loop)
- Skip signup form fields you can infer (name from invite)
- Deep-link directly to the action the inviter wanted them to take

### 5. Activation
**How fast** can the invitee hit the Aha Moment? Every extra step before the Aha Moment costs conversion — friction compounds, and the highest-friction steps cost the most.
- Skip email verification until necessary (or use magic link)
- Pre-populate sample data so the product isn't empty
- Guide to first-action within one screen
- The expensive steps to defer: email verification, payment, contact-import permission

---

## Abuse Guardrails

Any incentive with cash value will be gamed — fraud risk scales directly with the dollar value of the reward. Design the guardrails *before* launching a paid referral program:

- **Pay on a qualified action, not on signup.** Require the invitee to activate (hit the Aha Moment) or make a first payment before any reward is granted. This alone kills most fake-account farming — fake accounts don't complete real actions.
- **Dedupe aggressively** — normalize email provider-aware (strip `+tags` where the provider supports sub-addressing; drop dots only for providers that ignore them, such as Gmail — stripping dots everywhere merges distinct addresses and flags legitimate invitees), fingerprint payment method, and check device/IP. Referral rings reuse these.
- **Per-inviter caps** — cap rewards per inviter per period. A sudden spike from one account is almost always abuse, not virality.
- **Hold + clawback window** — delay payout and reverse the reward if the invitee charges back or churns inside the window.
- **Self-referral block** — the same person can't be both sides.

A loop that pays on signup with no guardrails is a fraud subsidy, not a growth loop.

---

## Viral Metrics

### K Factor (Viral Coefficient)

```
K = (invites sent per user) × (conversion rate of invitees)
```

- **K > 1** → Viral growth (each user brings more than one new user; exponential)
- **K = 1** → Stable (each user replaces themselves; linear)
- **K < 1** → Sub-viral (loop amplifies paid/organic but can't sustain alone)

Measure "conversion rate of invitees" at the **activated/retained** level, not at gross signup. A churned invitee stops inviting, so the *sustained* K is always lower than the snapshot K you see right after launch — that gap is exactly the cliff in Anti-Pattern 1.

Real K > 1 is extremely rare. Most durable growth comes from a sub-viral loop (K well below 1) that amplifies low-CAC channels rather than replacing them.

**K and cycle time are different things.** K tells you *whether* growth compounds; cycle time (below) tells you *how fast*. The same K = 0.5 is a completely different business at a 3-day cycle versus a 60-day cycle. Always report K alongside cycle time.

### Amplification Factor

```
Amplification = 1 / (1 - K)     (only valid when K < 1)
```

This is the eventual multiplier on organic/paid acquisition once the loop reaches steady state — a cumulative ceiling realized over many cycle times, not a per-period rate. Cycle time sets how fast you approach it (halving cycle time roughly doubles the rate of approach).
- K = 0.3 → 1.43x (each paid user brings 0.43 extra via viral)
- K = 0.6 → 2.5x
- K = 0.9 → 10x

Note how non-linear this gets near the top: K slipping from 0.9 to 0.8 drops the multiplier from 10x to 5x. Amplification is fragile close to K = 1.

### Why K isn't constant

K is not a fixed property of the product — it's a per-cohort number that decays over time:
- **Network saturation** — early cohorts invite into a fresh network; later cohorts find their contacts already use the product, so invites convert less.
- **Invite fatigue** — the more often someone has been invited, the less each new invite converts.

This decay is *why* sustained K > 1 is so rare, and why amplification is an idealization rather than a guarantee. Measure K by cohort and watch the trend — never trust a single blended number.

### Loop Cycle Time

Days from a user signing up to their invitees signing up. Shorter cycles compound faster — they decide how quickly you approach the amplification ceiling.
- Rough targets: consumer loops should turn over in days; B2B in weeks rather than months. Exact thresholds vary by product — the lever that matters is making each cycle faster.
- Optimize: shorten time-to-Aha Moment, surface invite UI sooner after Aha

### Referral Conversion Rate

Invite → signup → activation. Track each step separately — most loops leak at landing → signup.

---

## Paid Loop Economics

A paid loop (revenue → ad spend → users → revenue) is only a *loop* — not a leaky funnel — when the unit economics let you recycle margin into spend faster than it leaks out:

- **Contribution margin must fund the next cycle.** The loop closes only if margin from acquired users, recycled into spend, acquires more than it costs to keep running. If every cycle needs outside cash, that's a funnel with an ad budget.
- **Payback period vs. cash cycle.** If CAC payback (months to recover acquisition cost from margin) is longer than your cash cycle, the loop stalls on cash even when LTV:CAC looks healthy on paper. For loop *velocity*, fast payback beats high lifetime LTV.
- **The loop dies when LTV:CAC compresses** — rising CAC from channel saturation or falling LTV from worse retention will both break it.

This skill covers the loop *dynamics*; for what to actually charge (LTV inputs, value metric, tier design), consult `pricing`.

---

## Two Anti-Patterns

### Anti-Pattern 1: Incentive Without Value
Paying users to invite a product they don't use churns both sides. K goes up briefly, then retention cliffs. **Rule**: don't launch a referral program until you have a retention plateau.

### Anti-Pattern 2: Trigger Before Aha
Prompting for invites at signup or onboarding trains users to dismiss invite UI. You only get one "first ask." Save it for after the first success.

---

## When NOT to Build a Loop

A growth loop is the wrong investment when:
- **No retention plateau yet** (Anti-Pattern 1) — you'll just amplify churn.
- **Low network density** — your users don't know others who'd want the product (niche single-player tools).
- **Sensitive or regulated category** — health, finance, anything users won't broadcast; sharing carries privacy/compliance risk.
- **Long or episodic purchase cycle** — if people buy once every few years, the loop can't turn over fast enough to compound.
- **Single-seat B2B** — one user per account caps the natural in-product invite surface.

When these hold, paid / sales / content channels usually beat a forced viral loop.

---

**Where to look first** when improving an existing loop: the step with the lowest absolute conversion is where to *look* — it's the biggest leak. But the best fix maximizes `leak size × expected lift × value per conversion ÷ effort`: some large leaks (contact-import permission, for instance) are structurally hard to move, so the biggest leak isn't automatically the best place to *invest*. Invite sent → invitee signup is the most common leak.

---

## Common Loop Patterns (Reference)

| Product | Loop Shape | What Makes It Work |
|---------|-----------|---------------------|
| **Calendly** | Invite-to-schedule | Every meeting invite is a product demo |
| **Dropbox** | Two-sided storage | Incentive matches value unit |
| **Figma** | Collaboration | Product is better with more editors |
| **Notion** | Public docs + templates | Content loop + utility loop |
| **Linear** | In-product @-mentions | Professional context, no incentive needed |
| **Superhuman** | Keyboard shortcut cult + waitlist | Scarcity + in-signature ad |
| **Typeform** | Branded form footer | Every completed form is an ad |

---

## Marketplace Cold-Start

UGC / marketplace loops are listed above as a loop type, but they can't bootstrap with the direct-viral playbook — they face the chicken-and-egg problem (no demand without supply, no supply without demand). Design for it:

- **Seed the hard side first** — usually supply. Recruit or even manually create the first listings so the demand side finds value on arrival.
- **Single-player value before the network** — make the product useful to one side alone (e.g., a tool the supply side would use even with zero buyers), so the hard side has a reason to show up early.
- **Constrain to liquidity** — launch one geography or one vertical at a time. A dense, liquid niche beats a thin global marketplace; expand only once each segment reaches reliable match rates.

---

## Output Format

When designing a referral/viral loop, produce:

```markdown
## Loop: [Name]

### Shape
- Type: [direct viral | content | integration | paid | marketplace | ...]
- Input → Action → Output → Re-entry (one line each)

### 5 Stages
- Trigger: [when]
- Incentive: [structure — one-/two-sided, milestone, tiered — and for whom]
- Mechanism: [how]
- Landing: [where, personalization]
- Activation: [Aha path]

### Target Metrics
- K goal: [number] (reported with cycle time)
- Cycle time goal: [days]
- Per-stage conversion goals

### Instrumentation
- Events: invite_created, invite_sent, invite_clicked, invitee_signup,
  invitee_activated, reward_granted — each linking inviter ↔ invitee
- (Live K measurement methodology and the broader tracking plan: `product-analytics`)

### Abuse Guardrails
- [payout trigger, dedupe keys, caps, clawback window]

### Risks
- [what could break the loop]
- [churn cliff candidates]
- [fraud / gaming vectors]

### Test Plan
- [first experiment to validate]
```
