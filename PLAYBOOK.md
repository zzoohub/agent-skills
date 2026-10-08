# PLAYBOOK.md

The **sequencing** playbook — how the skills and agents chain end to end. (The sequences below are
referred to throughout the library as the *workflow chains*; this file is their home.) Companion to
[`AGENTS.md`](AGENTS.md) (the always-on core: skill/agent conventions + the Intent → skill or agent
table) and [`REFERENCE.md`](REFERENCE.md) (the static lookup tables: agent roster, skill map by area,
doc locations, external dependencies, known gaps). Read this when you need to know **what runs after what**.

Each chain below is a sequence the human or main session runs step by step. Planning, design,
implementation and marketing steps are **skills**, run by the main session or by general-purpose
subagents it spawns; the gates and the analytics read are the four remaining **agents** (`reviewer`,
`verifier`, `adversary`, `data-analyst`), and shipping is a main-session step using the deploy
platform's own skills/CLI. Each arrow is a handoff: the next step
reads the file the prior one wrote (see **Default doc locations** in [`REFERENCE.md`](REFERENCE.md)).
Check each output before continuing. **Agents never call each other** — the main session drives the
chain and owns the handoffs.

---

## 1. Full product launch (idea → production)
```
product-brief         → docs/prd/product-brief.md (the why and whether: a Decision + its Next test)
prd-craft             → docs/prd/prd.md (+ feature specs: full for the first release users get,
                        stubs for later ones)
software-architecture → docs/arch/system.md (+ arch-decision ADRs, database-design schema,
                        its AI Feature Mode for LLM/AI features — docs/arch/ai-features/, as needed)
ux-design             → docs/ux/ux-design.md (+ initial screen specs via screen-design: critical-path
                        and costly-to-fail screens plus one exemplar per screen class; the rest pending)
implement             → main session / general-purpose subagents loading the stack skills
                        (e.g. hexagonal-backend, react-best-practices, react-native-skills, design-system)
reviewer              → security + correctness (blocking gate) + maintainability (informational)
verifier              → real-browser / API verification (behavior gate)
adversary             → runtime exploit reproduction, isolated env (high-risk changes only)
ship                  → main session with the deploy platform's skills/CLI: preview → smoke check
                        → promote, then a post-deploy health check (database-design's PostgreSQL
                        operations for lock-safe migrations)
```

**Test first.** When the brief's Decision is Test first, the main session runs its Next test
(copywriting or cro for a smoke page) and records the result in the brief (product-brief) before
prd-craft runs; an explicit PRD request may instead go ahead, with prd-craft carrying the untested
rows as assumptions.

**Gates return verdicts; the main session decides done.** `reviewer`, `verifier`, and (on
high-risk changes) `adversary` each return a verdict to the main session, which decides whether the
change is done. The implementer never self-certifies its own work — `verifier` proves behavior and
`adversary` reproduces exploits, but the call to ship rests with the main session. After fixes,
re-run `reviewer` as a re-review (prior blocking and Unconfirmed items, then the fix commits only).

Optionally insert a plan review: `plan-review` in scope mode (scope/vision) after prd-craft, while
scope is still negotiable; `plan-review` in execution mode (execution rigor) after
software-architecture, once the design doc locks scope and before implementation starts. Each run
returns its verdict and findings to the main session.

## 2. Feature on an existing product
```
feature-spec
→ as needed: arch-decision (one architectural decision) · software-architecture on the existing
  system (several, or a re-architecture, modernization or system migration; AI Feature Mode for a
  model in the loop) · database-design (new or changed data)
→ ux-design Flow pass (only for a new multi-screen flow) → screen-design, once per screen
→ plan-review, execution mode (when the change trips one of its depth triggers: money, persisted
  data, permissions, personal data, a public contract, a new external dependency such as an LLM)
→ implement (main session / general-purpose subagents + stack skills)
→ reviewer → verifier → (adversary, if high-risk) → ship
```

## 3. Growth optimization cycle
```
data-analyst (find the drop-off / Aha / retention gap)
→ cro / growth-loops / churn-prevention (design the conversion / loop / churn fix)
→ screen-design + implement
→ reviewer → verifier → (adversary, if high-risk) → ship
→ data-analyst (measure the result)
```

## 4. Go-to-market / launch
```
main session: positioning in biz/marketing/strategy.md (copywriting can draft the proposal)
→ pricing / competitor-pages / ad-creative / copywriting (message hierarchy, launch-day copy)
→ copywriting (social, email) / search-visibility (blog/SEO) — launch and ongoing content
→ data-analyst (instrument + track launch)
```

## 5. Architecture / UX review (no new build)
```
software-architecture (review mode)  — or —  ux-design (review mode)
→ reviewer (if code is implicated)
```

**Connecting build ↔ GTM ↔ product:** when `data-analyst` or the growth skills (`cro`,
`growth-loops`, `churn-prevention`) surface a product-level insight, route it back instead of
patching marketing around a product gap: a new persona or problem (a new direction) →
`product-brief`; a requested feature or retention driver → `feature-spec` → `arch-decision` (if it
shifts an architectural decision) → implement. At a release checkpoint, `prd-craft` (Checkpoint)
records the result from `data-analyst`'s kill-criteria read and re-plans the next release, whose
stub specs `feature-spec` then deepens.

---

## Solo founder critical path (minimum spine)

You don't need every skill or agent on day one. The minimum spine from idea to live product:

```
product-brief (+ its Next test, on Test first) → prd-craft → software-architecture → ux-design
→ implement → reviewer → verifier → (adversary, if high-risk) → ship
```

Defer until you actually need them: mobile (`react-native-skills`) on a web-only start, the
biz/GTM skills until you have something to launch, `plan-review` until a plan carries a one-way
door or an unevidenced core assumption. Add the GTM chain (#4) once the product is verifiable, then
the growth cycle (#3) once you have users and tracking.
