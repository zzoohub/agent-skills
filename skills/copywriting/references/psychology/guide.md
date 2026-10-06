# Marketing Psychology & Mental Models

~70 mental models organized for marketing application (the reference's `###` headers count slightly higher because Social Proof and Mental Accounting (Pricing) are explicit aliases and the AIDA/PAS/BAB/4Ps/SSS group are copywriting frameworks, not standalone models). Use these to understand why people buy, influence behavior ethically, and make better marketing decisions.

**Scope:** this reference picks which principle to apply and explains the behavioral why. Writing the copy goes to the copywriting core (`SKILL.md`); page-level CRO and flow design/testing to the cro skill; pricing tier design and what to charge to the pricing skill; loop/referral mechanics and K-factor modeling to the growth-loops skill; churn intervention, cancel flows, save offers and health scoring to the churn-prevention skill; retention cohorts and analytics to the product-analytics skill.

**Product context**: read the product brief (default `docs/prd/product-brief.md`) and the marketing strategy doc (`biz/marketing/strategy.md`) first if they exist, to tailor recommendations to the specific product and audience. Treat them as read-only context — never author the product brief from here; if absent, ask the caller or proceed on stated assumptions.

---

## How to Apply

1. **Diagnose the barrier** — What behavior are you trying to influence, and what's preventing it?
2. **Match models** — Which mental models explain the barrier? Use the Quick Reference table below.
3. **Select 2-3 models** — Don't overload; pick the most applicable.
4. **Design within guardrails** — Apply the models within the Ethical Guardrails below.
5. **Implement** — Use the copywriting core (`SKILL.md`, `references/persuasion-frameworks.md`) for messaging, the cro skill for flow changes.
6. **Measure** — Validate with cro experiments; track impact via product-analytics.

---

## Ethical Guardrails

These models are for influence, not manipulation. The line:

- **Never fabricate scarcity** — Fake countdown timers, invented "only 3 left" claims, or artificial urgency erode trust and may violate consumer protection laws.
- **Never exploit vulnerability** — Don't target people in distress, financial hardship, or emotional states to push decisions they'd regret.
- **Disclose honestly** — If something is sponsored, paid, or an ad, say so. If a "sale" price is the permanent price, it's not a sale.
- **Preserve autonomy** — Dark patterns (hiding unsubscribe, pre-checked boxes for charges, confusing opt-out flows) are manipulation, not persuasion.
- **The regret test** — If a customer understood exactly what you did and why, would they feel respected or deceived?

**Specific dark patterns to avoid (with regulatory hooks):** see `references/psychology/mental-models-reference.md` § Dark Pattern Anti-Catalog for the 10 most-enforced patterns (pre-ticked opt-in, roach motel, confirmshaming, fake countdown, hidden subscription, friend spam, disguised ads, forced continuity, sneak into basket, misdirection) — each with its regulatory hooks (GDPR consent rules, EU UCPD and Consumer Rights Directive, FTC Act / ROSCA, CA AB 2863, UK DMCC Act; the EU DSA only where the seller is an online platform).

---

## Mental Model Categories

### Foundational Thinking Models
Strategy and problem-solving frameworks:
- **First Principles** — Break problems to basic truths, build up
- **Jobs to Be Done** — People hire products for outcomes, not features
- **Circle of Competence** — Stay where you have genuine advantage
- **Inversion** — Ask "what would guarantee failure?" and avoid those
- **Occam's Razor** — Simplest explanation is usually correct
- **Pareto Principle** — 80% of results from 20% of efforts
- **Theory of Constraints** — Find and fix the ONE bottleneck
- **Second-Order Thinking** — Consider effects of effects
- **Barbell Strategy** — 80% proven + 20% experimental

Also in reference: Opportunity Cost, Law of Diminishing Returns, Local vs Global Optima, Map ≠ Territory, Probabilistic Thinking

### Understanding Buyers & Psychology
How customers think and decide:
- **Mere Exposure Effect** — Familiarity breeds preference
- **Confirmation Bias** — People seek info confirming beliefs
- **Mimetic Desire** — People want what others want
- **Endowment Effect** — People value what they already own more
- **IKEA Effect** — People value what they helped create
- **Zero-Price Effect** — "Free" is psychologically different from cheap
- **Status-Quo Bias** — Change feels risky; defaults are powerful
- **Paradox of Choice** — Fewer options lead to more decisions
- **Peak-End Rule** — Experiences judged by peak moment and ending
- **Sunk Cost Fallacy** — Past investment shouldn't justify future spend

Also in reference: Fundamental Attribution Error, Availability Heuristic, Lindy Effect, Hyperbolic Discounting, Default Effect, Goal-Gradient Effect, Zeigarnik Effect, Pratfall Effect, Curse of Knowledge, Regret Aversion, Mental Accounting, Bandwagon Effect

### Influencing Behavior & Persuasion
Ethical influence techniques:
- **Reciprocity** — Give first, people feel obligated to return
- **Commitment & Consistency** — Small commitments lead to larger ones
- **Authority Bias** — People defer to experts and credentials
- **Social Proof** — People follow what others do
- **Scarcity/Urgency** — Limited availability increases perceived value
- **Loss Aversion** — Losses tend to feel more painful than equivalent gains (~2x in lab tasks; varies by context)
- **Anchoring** — First number seen influences all subsequent judgments
- **Decoy Effect** — Third option makes preferred choice look better
- **Framing Effect** — Same facts, different presentation, different perception
- **Foot-in-the-Door** — Small request → larger request compliance

Also in reference: Liking/Similarity Bias, Unity Principle, Door-in-the-Face, Contrast Effect

### Pricing Psychology
- **Charm Pricing** — $99 can feel cheaper than $100 (a modest, context-dependent effect)
- **Rounded-Price Effect** — Round numbers signal premium ($100 vs $99)
- **Rule of 100** — Under $100: use %; over $100: use absolute discount
- **Price Relativity** — Middle tier seems reasonable between cheap and expensive
- **Mental Accounting** — "$1/day" feels cheaper than "$30/month"

### Design & Delivery Models
- **Hick's Law** — More choices = slower decisions = more abandonment
- **AIDA** — Attention → Interest → Desire → Action
- **BJ Fogg Model** — Behavior = Motivation × Ability × Prompt
- **EAST Framework** — Easy, Attractive, Social, Timely
- **Activation Energy** — Reduce starting friction for action

Also in reference: Rule of 7, Nudge Theory/Choice Architecture, COM-B Model, North Star Metric, Cobra Effect

### Growth & Scaling Models
- **Feedback Loops** — Output becomes input, creating cycles
- **Network Effects** — Product value increases with more users
- **Flywheel Effect** — Sustained effort creates self-maintaining momentum
- **Switching Costs** — High switching costs create retention
- **Critical Mass** — Threshold where growth becomes self-sustaining

Also in reference: Compounding, Exploration vs Exploitation, Survivorship Bias

Full descriptions with marketing applications: `references/psychology/mental-models-reference.md`

---

## Quick Reference

| Marketing Challenge | Models to Apply |
|---------------------|----------------|
| Low conversions | Hick's Law, Activation Energy, BJ Fogg, EAST Framework |
| Price objections | Anchoring, Framing, Mental Accounting, Loss Aversion |
| Building trust | Authority, Social Proof, Reciprocity, Pratfall Effect |
| Increasing urgency | Scarcity, Loss Aversion, Zeigarnik Effect |
| Retention/churn | Endowment Effect, Switching Costs, Status-Quo Bias |
| Growth stalling | Theory of Constraints, Local vs Global Optima, Compounding |
| Decision paralysis | Paradox of Choice, Default Effect, Nudge Theory |
| Onboarding | Goal-Gradient, IKEA Effect, Commitment & Consistency |
| Pricing feels wrong | Charm Pricing, Decoy Effect, Price Relativity, Rule of 100 |
| Users not activating | IKEA Effect, Endowment Effect, Foot-in-the-Door |
| High churn | Sunk Cost awareness, Switching Costs, Status-Quo Bias |

---

## Worked Example: Improving Onboarding Activation

**Challenge**: Users sign up for a project management tool but 60% never create their first project.

**Models selected**: Foot-in-the-Door + Goal-Gradient Effect + IKEA Effect

**How they combine**:
1. **Foot-in-the-Door**: Don't ask users to set up their whole workspace. Start with one tiny ask: "Name your first project." This small commitment makes the next step feel natural.
2. **Goal-Gradient Effect**: Show a progress bar — "3 of 5 steps complete." As users approach the finish, they accelerate. The bar creates pull toward completion.
3. **IKEA Effect**: Let users customize their project (choose a color, add a description, invite one teammate). The effort they invest makes the project feel like *theirs*, increasing reluctance to abandon it.

**Result framing**: Instead of "Set up your workspace" (high activation energy, vague), the flow becomes a series of small, visible, personally invested steps that compound into commitment.

---
