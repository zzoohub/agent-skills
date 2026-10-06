# Onboarding CRO

Reduce time-to-value and drive new users to their Aha Moment as quickly as possible, then build habits that lead to long-term retention.

## Table of Contents

1. [Initial Assessment](#initial-assessment)
2. [Core Principles](#core-principles)
3. [Defining Activation](#defining-activation)
4. [Onboarding Flow Design](#onboarding-flow-design)
5. [Multi-Channel Onboarding](#multi-channel-onboarding)
6. [Handling Stalled Users](#handling-stalled-users)
7. [Measurement](#measurement)
8. [Benchmarks](#benchmarks)
9. [Output Format](#output-format)
10. [Common Patterns by Product Type](#common-patterns-by-product-type)
11. [Experiment Ideas](#experiment-ideas)

## Initial Assessment

Before providing recommendations, understand:

1. **Product Context** - What type of product? B2B or B2C? Core value proposition?
2. **Activation Definition** - What's the "aha moment"? What action indicates a user "gets it"?
3. **Current State** - What happens after signup? Where do users drop off?

---

## Core Principles

### 1. Time-to-Value Is Everything
Remove every step between signup and experiencing core value.

### 2. One Goal Per Session
Focus first session on one successful outcome. Save advanced features for later.

### 3. Do, Don't Show
Interactive > Tutorial. Doing the thing > Learning about the thing.

### 4. Progress Creates Motivation
Show advancement. Celebrate completions. Make the path visible.

---

## Defining Activation

### Aha Moment

The Aha Moment methodology (discovery process, retention-predictive-value metric, the multiple-comparisons/FDR guard on parameter sweeps, canonical product examples) is canonical in **`product-analytics/references/aha-moment-discovery.md`**. Run that analysis to find your Aha Moment before designing onboarding.

For onboarding CRO, you need only the outcome: a specific user action that predicts retention. Common shapes:
- Project management: create first project + add team member
- Analytics: install tracking + see first report
- Design tool: create first design + export/share
- Marketplace: complete first transaction

### Activation Metrics (onboarding-side)
- % of signups who reach the Aha Moment
- Time-to-Aha (median + p90)
- Steps-to-Aha (drop-off per step)
- Activation rate by acquisition cohort / source

---

## Onboarding Flow Design

### Immediate Post-Signup (First 30 Seconds)

| Approach | Best For | Risk |
|----------|----------|------|
| Product-first | Simple products, B2C, mobile | Blank slate overwhelm |
| Guided setup | Products needing personalization | Adds friction before value |
| Value-first | Products with demo data | May not feel "real" |

**Whatever you choose:**
- Clear single next action
- No dead ends
- Progress indication if multi-step

### Onboarding Checklist Pattern

**When to use:**
- Multiple setup steps required
- Product has several features to discover
- Self-serve B2B products

**Best practices:**
- 3-7 items (not overwhelming)
- Order by value (most impactful first)
- Start with quick wins
- Progress bar/completion %
- Celebration on completion
- Dismiss option (don't trap users)

### Empty States

Empty states are onboarding opportunities, not dead ends.

**Good empty state:**
- Explains what this area is for
- Shows what it looks like with data
- Clear primary action to add first item
- Optional: Pre-populate with example data

### Tooltips and Guided Tours

**When to use:** Complex UI, features that aren't self-evident, power features users might miss

**Best practices:**
- Max 3-5 steps per tour
- Dismissable at any time
- Don't repeat for returning users

---

## Multi-Channel Onboarding

### Email + In-App Coordination

**Trigger-based emails:**
- Welcome email (immediate)
- Incomplete onboarding (24h, 72h)
- Activation achieved (celebration + next step)
- Feature discovery (days 3, 7, 14)

**Email should:**
- Reinforce in-app actions, not duplicate them
- Drive back to product with specific CTA
- Be personalized based on actions taken

Specify only the in-app triggers and the in-product action each email should reinforce; for the sequence copy, cadence, and automation itself, use the `copywriting` skill's email section (it owns onboarding and re-engagement sequences).

---

## Handling Stalled Users

### Detection
Define "stalled" criteria (X days inactive, incomplete setup)

### Re-engagement Tactics

1. **Email sequence** - Reminder of value, address blockers, offer help
2. **In-app recovery** - Welcome back, pick up where left off
3. **Human touch** - For high-value accounts, personal outreach

---

## Measurement

### Key Metrics

| Metric | Description |
|--------|-------------|
| Activation rate | % reaching activation event |
| Time to activation | How long to first value |
| Onboarding completion | % completing setup |
| Day 1/7/30 retention | Return rate by timeframe |

### Funnel Analysis

Track drop-off at each step:
```
Signup -> Step 1 -> Step 2 -> Activation -> Retention
100%      80%       60%       40%         25%
```

Identify biggest drops and focus there.

---

## Benchmarks

| Metric | Typical | Good | Excellent |
|--------|---------|------|-----------|
| Signup → Activation | 20-40% | 40-60% | 60%+ |
| Onboarding completion | 30-50% | 50-70% | 70%+ |
| Day 1 retention | 25-40% | 40-60% | 60%+ |
| Day 7 retention | 10-20% | 20-35% | 35%+ |
| Time to first value | Minutes to days | < 5 min | < 1 min |

These figures are directional and vary by industry, product, and period — validate against your own data. B2B products tend toward lower activation rates but higher retention once activated. Products with strong empty-state design consistently outperform those with blank-slate experiences.

---

## Output Format

### Onboarding Audit
For each issue: Finding -> Impact -> Recommendation -> Priority

### Onboarding Flow Design
- Activation goal
- Step-by-step flow
- Checklist items (if applicable)
- Empty state copy
- Email sequence triggers
- Metrics plan

---

## Common Patterns by Product Type

| Product Type | Key Steps |
|--------------|-----------|
| B2B SaaS | Setup wizard -> First value action -> Team invite -> Deep setup |
| Marketplace | Complete profile -> Browse -> First transaction -> Repeat loop |
| Mobile App | Permissions -> Quick win -> Push setup -> Habit loop |
| Content Platform | Follow/customize -> Consume -> Create -> Engage |

---

## Experiment Ideas

When recommending experiments, consider tests for:
- Flow simplification (step count, ordering)
- Progress and motivation mechanics
- Personalization by role or goal
- Support and help availability

**For comprehensive experiment ideas**: See [experiments.md](experiments.md)
