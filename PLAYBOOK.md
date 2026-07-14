# PLAYBOOK.md

The agent **sequencing** playbook — how the agents chain end to end. (The sequences below are
referred to throughout the library as the *workflow chains*; this file is their home.) Companion to
[`AGENTS.md`](AGENTS.md) (the always-on core: skill/agent conventions + the Intent → agent decision
table) and [`REFERENCE.md`](REFERENCE.md) (the static lookup tables: agent roster, doc locations,
external dependencies, known gaps). Read this when you need to know **what runs after what**.

Each chain below is a sequence the human or main session runs step by step. Each arrow is a handoff:
the next agent reads the file the prior one wrote (see **Default doc locations** in
[`REFERENCE.md`](REFERENCE.md)). Check each output before continuing. **Agents never call each
other** — the main session drives the chain and owns the handoffs.

---

## 1. Full product launch (idea → production)
```
product-manager   → docs/prd/prd.md (+ product brief, feature specs)
architect         → docs/arch/system.md (+ ADRs, schema)
ux-designer       → docs/ux/ux-design.md (+ screen specs)
task-manager      → tasks/board.md (+ feature task files)
backend-developer ┐
frontend-developer├ implement tasks (mobile/desktop as the product needs)
                  ┘
reviewer          → security + correctness + maintainability (blocking gate)
verifier          → real-browser / API verification (behavior gate)
adversary          → runtime exploit reproduction, isolated env (high-risk tasks only)
release-engineer   → ship to production + post-deploy health check
```

**Who writes task status, and when.** No builder self-certifies its own task `done`.
The main session owns the status edges and drives them through `task-manager` (agents
never call each other):
- *Before* a builder runs, the main session has `task-manager` move the task
  `backlog` → `active` and set the assignee (`task-manager` owns this left edge; the
  board ships assignees as `—`).
- A builder leaves its task `active` and returns a verdict; it only ever moves the task
  to `blocked` itself, when it couldn't finish.
- The main session marks the task `done` (via `task-manager`) **only after reviewer
  and verifier pass** (plus `adversary` on high-risk changes) — `verifier` proves behavior,
  `adversary` reproduces exploits, and neither writes status by design.

This keeps the closer unambiguous and matches `task-status`'s rule that completion is
verified before `done` is written.
Optionally insert a plan review: `plan-ceo-review` (scope/vision) after product-manager,
while scope is still negotiable; `plan-eng-review` (execution rigor) between architect
and task-manager, once the design doc locks scope.

## 2. Feature on an existing product
```
product-manager (feature-spec) → architect (arch-decision, if it shifts architecture)
→ ux-designer (screen-design) → task-manager (task-add)
→ developer(s) → reviewer → verifier → (adversary, if high-risk) → release-engineer
```

## 3. Growth optimization cycle
```
data-analyst (find the drop-off / Aha / retention gap)
→ growth-optimizer (design the CRO / loop / churn fix)
→ ux-designer (screen-design) + frontend-developer (implement)
→ reviewer → verifier → (adversary, if high-risk) → release-engineer
→ data-analyst (measure the result)
```

## 4. Go-to-market / launch
```
marketer (positioning, launch strategy, pricing)
→ content-marketer (social, email, blog, launch content)
→ data-analyst (instrument + track launch)
```

## 5. Architecture / UX review (no new build)
```
architect (software-architecture in review mode)  — or —  ux-designer (ux-design in review mode)
→ reviewer (if code is implicated)
```

**Connecting build ↔ GTM ↔ product:** when `data-analyst` or `growth-optimizer` surface a
product-level insight (new persona, requested feature, retention driver), route it back through
`product-manager` (feature-spec) → `architect` → dev, closing the loop instead of patching
marketing around a product gap.

---

## Solo founder critical path (minimum spine)

You don't need every agent on day one. The minimum spine from idea to live product:

```
product-manager → architect → ux-designer → task-manager
→ (one) developer → reviewer → verifier → (adversary, if high-risk) → release-engineer
```

Defer until you actually need them: `mobile-developer` / `desktop-developer` (web-only start),
the full biz layer until you have something to launch, `plan-*-review` skills until scope feels
risky. Add the GTM chain (#4) once the product is verifiable, then the growth cycle (#3) once
you have users and tracking.
