# Persuasion Frameworks

Canonical copywriting frameworks. Single source of truth for the structures — channel-specific applications (the ad-creative skill; this skill's social reference, `references/social/`) apply them to their medium; the email reference (`references/email/`) and the persuasion-psychology reference (`references/psychology/`) cross-reference them.

---

## Table of Contents

1. [Framework Selection Matrix](#framework-selection-matrix)
2. [PAS — Problem, Agitate, Solve](#pas--problem-agitate-solve)
3. [AIDA — Attention, Interest, Desire, Action](#aida--attention-interest-desire-action)
4. [BAB — Before, After, Bridge](#bab--before-after-bridge)
5. [4Ps — Promise, Picture, Proof, Push](#4ps--promise-picture-proof-push)
6. [SSS — Star, Story, Solution](#sss--star-story-solution)
7. [Psychological Triggers Reference](#psychological-triggers-reference)
8. [Applying These Frameworks](#applying-these-frameworks)
9. [Related Files](#related-files)


## Framework Selection Matrix

| Audience State | Best Framework | Copy Length | Why |
|----------------|---------------|-------------|-----|
| Unaware (doesn't know they have the problem) | Story-led, no rigid framework | Long | Must create awareness from zero |
| Problem-Aware (feels pain, no solution yet) | **PAS** | Medium-Long | Pain-first resonates with current mental state |
| Solution-Aware (knows solutions exist, comparing) | **AIDA** or **4Ps** | Medium | Need differentiation + proof |
| Product-Aware (knows your product, hasn't bought) | **4Ps** | Short-Medium | Stack proof, overcome objections |
| Most Aware (ready to buy) | Direct offer | Very Short | Just give them the deal |

Schwartz's 5 Awareness Levels (Eugene Schwartz, *Breakthrough Advertising*, 1966) are the master framing behind framework selection. You don't create desire — you channel existing desire by meeting the prospect where they already are.

---

## PAS — Problem, Agitate, Solve

The workhorse of direct response (folklore formula, popularized by Dan Kennedy). Draws on loss aversion: losses often loom larger than equivalent gains (λ≈2.25 in lab estimates; Tversky & Kahneman, 1992 — the concept was introduced in Kahneman & Tversky, 1979), though the size varies by context (Gal & Rucker, 2018).

| Step | Purpose | Technique |
|------|---------|-----------|
| **Problem** | Name the pain specifically | Use the reader's exact words — harvest from reviews, interviews, support tickets, Reddit |
| **Agitate** | Intensify the emotional stakes | Show hidden costs, future consequences, what they're missing |
| **Solve** | Present your product as the relief | Connect the solution to the specific pain you agitated |

**Structure template:**
```
Problem:  [Specific pain in their language — 1 sentence]
Agitate:  [2-3 sentences showing hidden cost or emotional toll]
Solve:    [Product + one proof point]
CTA:      [Single action]
```

**Works best for:** Problem-aware audiences, paid ads, landing pages, cold email opens.

---

## AIDA — Attention, Interest, Desire, Action

The oldest framework (conventionally attributed to E. St. Elmo Lewis, 1898 — the historical record is murkier). Still effective when you need to create awareness and desire from mild interest.

| Step | Purpose | Technique |
|------|---------|-----------|
| **Attention** | Stop the scroll | Pattern interrupt, surprising stat, bold claim |
| **Interest** | Engage with relevance | Connect to their world, tell them something they didn't know |
| **Desire** | Create want | Paint the outcome, show social proof, trigger emotion |
| **Action** | Direct the click | Single, clear CTA |

**Works best for:** Broad-audience social feed, homepage hero, sequence opener emails.

---

## BAB — Before, After, Bridge

Best for transformation-based messaging (copywriting folklore; popularized by Buffer's content team, ~2014). The brain processes contrast — showing the gap between current pain and desired outcome creates motivation, and the product is the bridge.

| Step | Purpose | Technique |
|------|---------|-----------|
| **Before** | Current painful reality | Specific, sensory, visceral |
| **After** | Dream state achieved | Tangible and believable |
| **Bridge** | Your product connects the two | Explain the mechanism briefly |

**Works best for:** Transformation products (fitness, education, career), case studies, carousels, before/after ads.

---

## 4Ps — Promise, Picture, Proof, Push

Effective for product-aware audiences where trust and skepticism management are the bottleneck (credited to Henry Hoke Sr.; the P-order varies by teacher). Each P builds on the last.

| Step | Purpose | Technique |
|------|---------|-----------|
| **Promise** | Bold, specific claim | Concrete and measurable |
| **Picture** | Visualize the result | Help them see themselves succeeding |
| **Proof** | Back it up | Data, testimonials, case studies, logos |
| **Push** | Drive action | Urgency, scarcity, or strong CTA |

**Works best for:** Product-aware retargeting, pricing page, upgrade pages, BOF email.

---

## SSS — Star, Story, Solution

The framework for UGC and testimonial-style copy (popularized by Gary Halbert). A relatable protagonist (the Star) tells their story of struggle and discovery.

| Step | Purpose | Technique |
|------|---------|-----------|
| **Star** | Relatable protagonist | Must mirror the target audience's identity |
| **Story** | Their struggle and journey | Authentic language, specific details |
| **Solution** | How the product changed things | Natural, not salesy — show don't tell |

**Works best for:** UGC ads, customer story blog posts, testimonial sections, case study emails.

---

## Psychological Triggers Reference

The mechanisms below are owned by the persuasion-psychology reference (`references/psychology/guide.md` and `references/psychology/mental-models-reference.md` — the single source of truth for the biases themselves); this table is the copy-application layer — how to phrase each trigger, not the canonical definition. See it for full mechanisms, ethical guardrails, and the dark-pattern anti-catalog.

Stack 1-2 per piece of copy, never more. Only use where the trigger is *real* (fake scarcity destroys trust).

| Trigger | Mechanism | Copy Application |
|---------|-----------|------------------|
| **Loss Aversion** | Losses often loom larger than equal gains (~2x in lab estimates, Tversky & Kahneman, 1992; context-dependent, Gal & Rucker, 2018) | Frame what they'll lose by not acting ("Don't miss out") — but loss framing isn't reliably better than gain framing ("Get access"), so test both |
| **Social Proof** | People follow the crowd | Numbers ("12,847 teams"), logos, testimonials, ratings |
| **Scarcity** | Limited availability → perceived value | "Only 23 spots left" (real limits only) |
| **Urgency** | Deadlines create action pressure | "Offer ends Friday", real countdown timers |
| **Authority** | Experts + credentials build trust | "Recommended by [expert]", certifications, media logos |
| **Reciprocity** | Free value creates obligation | Lead magnets, free tools, value-first outreach |
| **Curiosity Gap** | Open loops demand closure | "The 3-step method that...", incomplete information |
| **Anchoring** | First number frames subsequent judgment | Show high price first, then discount |
| **Novelty** | Brains stop for the unexpected | Unusual visuals, contrarian claims, pattern interrupts |
| **Identity** | People act consistently with self-image | "For founders who...", "If you're the kind of person who..." |

### Ethical Usage
These triggers work because they tap real human psychology. Use them to help people decide in ways that genuinely benefit them. Fake countdowns, manufactured scarcity, and identity traps destroy trust and frequently violate platform policies (and consumer-protection law — see the Dark Pattern Anti-Catalog in `references/psychology/mental-models-reference.md`).

---

## Applying These Frameworks

Channel-specific skills apply these frameworks to their medium:

- **ad-creative** — ad format templates (search, feed, video, carousel, display) per framework
- **social** (`references/social/`) — hook structures + post-level applications (HSO, Hook-Retain-Reward are platform-native riffs on AIDA/PAS)

(The email reference (`references/email/`) and the cro skill defer copy to this skill but do not currently template these frameworks; the psychology reference (`references/psychology/`) cross-references the triggers above.)

When writing copy:
1. Diagnose the audience's awareness level
2. Pick the framework matching that level (see matrix above)
3. If the deliverable is an ad, organic post, email, or landing page, apply the template of whatever owns that medium — organic posts and email are produced here from `references/social/` and `references/email/`; ads (ad-creative) and landing-page/paywall structure (cro) belong to separate skills, so hand off to them rather than producing it here
4. Layer 1-2 psychological triggers
5. Run the editing sweeps from `editing-sweeps.md`

---

## Related Files

These are side pointers only (each is also linked directly from SKILL.md — no nested reference chain):

- `copy-frameworks.md` — Page structure and CTA formulas (different scope — page-level layout, not persuasion framework)
- `editing-sweeps.md` — Editing discipline applied to any framework's output
- `plain-english.md` — Voice and jargon elimination
