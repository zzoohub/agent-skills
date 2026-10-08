# REFERENCE.md

Static-lookup companion to [`AGENTS.md`](AGENTS.md) — the reference detail that does **not** need to
load every turn. `AGENTS.md` holds the always-on core: what this repo is, the build commands, how the
system works, the skill/agent **conventions** (the load-bearing rules), and the **Intent → skill or
agent table**. This file holds the on-demand lookup tables: each agent's **skill palette** (agent
roster), the **skill map by area**, the **Default doc locations** table, the **external dependencies**,
and the **known gaps**.
For agent **sequencing** — the workflow chains and the solo-founder critical path — see
[`PLAYBOOK.md`](PLAYBOOK.md).

> The `apps/*`, `db/`, `docs/`, and `biz/` paths below describe the **consuming project**
> an agent operates on — never this library's own contents (whose only top-level dirs are `agents/`
> and `skills/`).

---

## Agent roster

Each bullet is the agent's **routable skill palette**, not its frontmatter — some of these load on
demand via the `Skill` tool; only a subset is preloaded in the agent's `skills:` array
(e.g. `verifier` preloads `[qa]`, `data-analyst` preloads `[product-analytics]`).
Skill names with a colon (e.g. `vercel:*`, `cloudflare:wrangler` below) are plugin skills in the
runtime's Skill-tool namespace, not directories in `skills/`.

**Dev layer:**
- `reviewer` → review-checklists (Pass 1 security + correctness, blocking; Pass 2 maintainability, informational)
- `verifier` → qa (browse) + playwright (preferred) / claude-in-chrome fallbacks
- `adversary` → adversarial-execution · review-checklists (security + correctness sections; executes their catalog at runtime) · database-design migration references (migration dry-runs, on demand) + playwright

**Biz layer:**
- `data-analyst` → product-analytics · churn-prevention (health-score framework, loaded on demand) + PostHog MCP

> Agent **sequencing** — how these chain end to end — lives in [`PLAYBOOK.md`](PLAYBOOK.md).

### Skill map by area

Planning, design, implementation, and marketing work has no dedicated agent: the main session (or a
general-purpose subagent it spawns) loads the skills for the area directly.

| Area | Skills |
|---|---|
| Plan (product) | product-brief · prd-craft · feature-spec; plan reviews: plan-review (scope mode · execution mode) |
| Architecture | software-architecture (incl. AI Feature Mode) · arch-decision · database-design |
| UX | ux-design (incl. 3D/XR UX) · screen-design · cro (when conversion-driven) |
| Backend build | hexagonal-backend (Axum / FastAPI / Hono / NestJS guide, by stack) · database-design (incl. PostgreSQL operations) · review-checklists (pre-mortem mode while building) |
| Web build | react-best-practices · react-view-transitions (route, shared-element and Suspense-reveal transitions) · design-system (incl. component composition) · i18n · web3d |
| Mobile build | react-native-skills · design-system · i18n |
| Marketing | copywriting (incl. persuasion psychology) · competitor-pages · pricing · ad-creative; content: copywriting (social, email, launch-day copy, changelog) · search-visibility |
| Growth | cro · growth-loops · churn-prevention · pricing · copywriting (incl. persuasion psychology) |
| Analytics | product-analytics · churn-prevention (via the `data-analyst` agent) |
| Ship / deploy | the deploy platform's own skills/CLI (e.g. vercel:* · cloudflare:wrangler · Supabase) · database-design (PostgreSQL operations: lock-safe migrations, major-version upgrades) |

---

## Default doc locations

The conventional file locations the skills and agents follow by default — a reference map of where
each artifact lives, not a runtime override point. Skills and agents do **not** read this table at
boot; to change paths for a real project, set the conventions in that project's `CLAUDE.md`. A
project adopts the software-architecture house profile the same way — one line there naming the
profile path (`references/house-stack.md`); without it, technology is selected per driver. Every
file a skill or agent reads or writes has a row here. A trailing `/` denotes a directory family
authored by one owner. "Main session" means the artifact has no producing skill: whoever does that
work (the main session or a subagent it spawns) writes it.

| Artifact | Path | Written by | Read by |
|---|---|---|---|
| Product brief | `docs/prd/product-brief.md` (+ `product-brief-{slug}.md` sibling directions beside it) | product-brief | prd-craft, feature-spec, plan-review (scope mode), pricing, software-architecture, copywriting, data-analyst |
| PRD | `docs/prd/prd.md` | prd-craft (incl. Checkpoint results; patched by feature-spec: §5 row, §6 entry, Last Updated) | feature-spec, software-architecture, database-design, ux-design, plan-review (scope mode), pricing, product-brief, data-analyst (§4 metrics, v0.1 decision rule) |
| Feature spec | `docs/prd/features/{feature}.md` | feature-spec (new product: prd-craft, full specs via feature-spec batch mode and `Depth: stub` specs for the rest, which feature-spec deepens in place) | software-architecture (incl. AI Feature Mode), arch-decision, database-design, ux-design, screen-design, web3d, plan-review (scope mode), qa (acceptance criteria as test oracle), implementers |
| Arch context (greenfield sentinel) | `docs/arch/context.md` | software-architecture (arch-decision appends to §6 only: Dependent ADRs, new assumptions) | software-architecture (brownfield detection, together with implementation presence), arch-decision, database-design (§2–§4), ux-design, i18n (reach), plan-review (execution mode), implementers |
| Architecture | `docs/arch/system.md` | software-architecture (patched by arch-decision, Accepted ADRs only) | implementers (hexagonal-backend), database-design, ux-design, screen-design (backend capabilities), pricing (§4 Cost & Unit Economics), plan-review (execution mode), reviewer |
| Architecture decisions (ADRs) | `docs/arch/adr/ADR-NNN-{slug}.md` (arch-decision: else an existing log, e.g. `doc/adr/`, keeping its numbering and format) | software-architecture, arch-decision | implementers, ux-design, plan-review (execution mode), reviewer |
| Risks & open questions | `docs/arch/risks.md` | software-architecture (arch-decision closes answered Open Questions and appends accepted risks) | implementers, plan-review (execution mode), reviewer |
| Database design | `docs/arch/database.md` | database-design | backend implementers, plan-review (execution mode, when data changes) |
| Migrations | the project migration tool's directory and format (no tool: `db/migrations/<UTC timestamp>_<verb>_<domain>.sql` + `.down.sql` for reversible steps) | database-design | backend implementers (hexagonal-backend wiring), reviewer, adversary (migration dry-runs) |
| AI feature design | `docs/arch/ai-features/{feature}.md` | software-architecture (AI Feature Mode) | ux-design, screen-design (AI surface states), pricing (§7 cost per successful task), implementers |
| Recovered as-is (re-architecture / system migration; retired when the transition completes) | `docs/arch/as-is.md` | software-architecture (Build Mode on an existing system) | software-architecture (Transition Plan), implementers |
| App UX | `docs/ux/ux-design.md` | ux-design | screen-design, design-system (accessibility requirements), web3d, web/mobile implementers |
| Screen specs | `docs/ux/screens/{screen}.md` (3D/XR: `{experience}.md`) | ux-design (initial set: critical-path and costly-to-fail screens + one exemplar per screen class, via screen-design), screen-design | screen-design (redesigns, a pending entry's exemplar), web3d, qa (screen-spec states as test oracle), web/mobile implementers |
| Project checklist (optional) | `checklist.md` (repo root or `docs/`) | *(project-defined)* | reviewer |
| QA reports + regression baseline | `.qa/reports/<YYYYMMDD-HHMM>/` per run (`report.md`, `screenshots/`, `baseline.json`) + `.qa/reports/baseline.json` (promoted) | qa skill (callers with file-write; verifier returns findings inline instead) | qa (regression mode) |
| Browse state + evidence | `.browse/` at the git root (daemon state, logs with full URLs; appended to an existing `.gitignore`); evidence in `/tmp/<run>/` (redirect only under `/tmp` or the daemon's start directory) | browse | browse (session); callers (evidence) |
| Marketing strategy | `biz/marketing/strategy.md` | main session (copywriting fills its Brand Voice section and proposes Positioning for the owner to approve) | copywriting, competitor-pages, search-visibility (Brand Voice), ux-design (tone map for functional copy), data-analyst |
| Launch materials | `biz/marketing/launch/` | copywriting (launch-day copy: Product Hunt, Show HN, Reddit); main session (launch plan) | — |
| Price book (public tiers) | `biz/marketing/pricing.md` | pricing | cro, growth-loops, churn-prevention, copywriting, competitor-pages (context only; price claims come from the live page) |
| Competitor analysis | `biz/marketing/competitors.md` | main session | competitor-pages, copywriting, pricing, search-visibility |
| Competitor page drafts | `biz/marketing/competitor-pages/{slug}.md` (`{slug}` = the page's URL path without slashes, e.g. `vs-linear`) | competitor-pages | search-visibility (target query and tracked prompts from each draft's opening comment) |
| Competitor claims registers | `biz/marketing/competitor-pages/claims/{competitor}.md` (+ `claims/{your-product}.md`) | competitor-pages (page programs, refresh cycles) | competitor-pages (refresh), counsel |
| Marketing assets | `biz/marketing/assets/{campaign-slug}.md` (one per campaign, incl. its creative-test log) | ad-creative | — |
| Content strategy | `biz/marketing/content/strategy.md` | main session | — |
| Content (social/email/blog/changelog) | `biz/marketing/content/{social,email,blog,changelog}/` (blog: `{slug}.md`, `briefs/{slug}.md`) | copywriting (social, email, changelog), search-visibility (blog) | — |
| SEO/AEO/GEO audits, plans + AI visibility | `biz/marketing/seo/` (living: `seo-strategy.md`, `keyword-map.md`, `ai-visibility-log.md`, `change-plan-{topic}.md`; dated: `audit-YYYY-MM-DD-{topic}.md`, `ai-visibility-YYYY-MM-DD.md`) | search-visibility | competitor-pages (`keyword-map.md`) |
| Tracking plan + Aha moment | `biz/analytics/tracking-plan.md` | data-analyst (product-analytics) | cro, growth-loops, copywriting (email goal event), marketing and growth work |
| Funnels + retention | `biz/analytics/funnels.md` | data-analyst (product-analytics) | ux-design, cro, growth-loops, churn-prevention, pricing, copywriting (persuasion psychology) |
| Dashboards | `biz/analytics/dashboards.md` | data-analyst (product-analytics) | — |
| Kill/Keep/Scale + CC | `biz/analytics/kill-criteria.md` | data-analyst (product-analytics; criteria seeded from the PRD's v0.1 decision rule) | prd-craft (Checkpoint), growth-loops, marketing work |
| Customer health score | `biz/analytics/health-score.md` | data-analyst (product-analytics backtest and scoring of churn-prevention's model) | churn-prevention |
| Analytics reports | `biz/analytics/reports/` | data-analyst (product-analytics) | growth-loops, marketing and growth work |
| Growth experiments log | `biz/growth/experiments.md` | cro (test-card schema, experiment designs); growth-loops, churn-prevention and copywriting log their tests as cro test cards | data-analyst (product-analytics readout); cro, growth-loops, churn-prevention (prior tests) |
| Growth loops / referral | `biz/growth/referral-program.md` | growth-loops | pricing (reward ceiling, value unit, side), data-analyst (K definition and targets) |
| Churn prevention strategy | `biz/growth/churn-prevention.md` (incl. § Cancel flow, § Renewals, § Health-score model) | churn-prevention | pricing, data-analyst (§ Health-score model) |
| Dunning / payment recovery | `biz/growth/dunning.md` | churn-prevention | — |
| Paywall / upgrade pricing | `biz/growth/paywall-pricing.md` | pricing | cro, copywriting |
| CRO analyses | `biz/growth/cro/{page-or-flow}-analysis.md` | cro | screen-design (a finding as its brief) |
| Customer feedback log | `biz/ops/feedback-log.md` | *(currently unowned — see Known gaps)* | data-analyst |

**Source layout (monorepo convention):** `apps/web` · `apps/api` · `apps/worker` ·
`apps/mobile` · `db/`.

---

## External dependencies (MCP servers & plugins)

These power specific agents. If one is unavailable, the agent falls back as noted. Deploy-platform
MCPs (Vercel, Cloudflare, Supabase) are no longer bound to any agent; the main session uses them
directly when shipping.

| Dependency | Used by | Purpose | Fallback if missing |
|---|---|---|---|
| PostHog MCP | data-analyst | Live funnels, insights, cohorts, experiments | methodology only (no live data) |
| claude-in-chrome / playwright MCP | verifier, adversary | Real-browser verification & E2E; adversary drives playwright for runtime attacks | the other of the two (verifier) |

---

## Known gaps (not yet covered)

Be honest about what this library does **not** do yet, so you don't assume an owner exists:

- **Run-the-business operations** — finance (runway, P&L, tax), legal programs (ToS, privacy
  policy, GDPR/CCPA, entity), and founder operations (weekly cadence, OKRs, prioritization,
  decision log) have **no agent or skill**. Handle these outside the system. Unit economics is
  split, not unowned: `pricing` owns price, margin floor and cost per account; `product-analytics`
  owns LTV, CAC and payback; `software-architecture` owns cost per unit (`system.md` §4).
  Point-of-use marketing law has one dated home per topic: subscriptions and auto-renewal →
  `churn-prevention` `references/compliance.md` (re-check after the BGH hearing of 2026-11-05 and
  once the UK DMCC subscription rules are published); endorsements, reviews and reference prices →
  `copywriting` persuasion psychology; comparative claims → `competitor-pages`
  `references/claims.md`; price display → `pricing` `references/tier-packaging.md`; ad-platform
  policy and AI labels → `ad-creative` `references/ad-policy-compliance.md`.
- **Task / work tracking** — removed by choice. The library ships no task board, task IDs, or
  status lifecycle; agents and review skills return verdicts, findings, and proposed follow-ups to
  the caller. Track work with the harness's built-in task list or an external tracker.
- **Dedicated builder agents** — none. Implementation (backend, web, mobile), planning, design, and
  marketing work runs in the main session or in general-purpose subagents it spawns, loading the
  skills for the area (see **Skill map by area**).
- **Desktop / Tauri apps** — not supported (dropped on purpose); there is no desktop skill, agent,
  or `apps/desktop` convention.
- **Customer support / success** — ticket triage, help-center/FAQ ownership, NPS/CSAT, and the
  customer-feedback loop are unowned. `biz/ops/feedback-log.md` is read by `data-analyst` but nothing
  creates or curates it.
- **Launch strategy & GTM gate** — `copywriting` owns launch-day copy and a default launch calendar
  (`references/social/topic-clusters.md` § Launch calendar), and `prd-craft`'s Checkpoint adds a
  launch bar to a release that opens to everyone. No skill owns launch *strategy* (it is
  main-session work drawing on the marketing skills), and nothing runs a pre-launch go/no-go
  readiness check.
- **Release / deploy** — no agent or skill owns shipping: the main session deploys with the
  platform's own skills/CLI (vercel, wrangler, supabase), with `database-design` (PostgreSQL
  operations) covering lock-safe migration execution and major-version upgrades. There is no
  in-house release gate (preview → smoke → promote, env/secret diff, rollback runbook). Mobile
  delivery is only partly owned: `react-native-skills` (`rules/dependencies-delivery.md`) covers
  binary vs OTA, runtime-version compatibility, staged store and OTA rollouts and rollback; EAS
  Build/Submit setup, store submission, universal/app-link setup and push notifications have no
  owner.
- **Security/compliance ops** — code-level security is covered, static *and* runtime (`reviewer` +
  `review-checklists` security pass; `adversary` + `adversarial-execution` for runtime DAST on high-risk changes),
  but SOC2/ISO, secrets-rotation policy, vendor risk and mobile-client security (MASVS: storage,
  transport, pinning, binary hardening, root/jailbreak) are not. `review-checklists` scopes MASVS
  out; `react-native-skills` covers only secret storage, public `EXPO_PUBLIC_` values, deep-link
  input validation and system-browser sign-in.
- **Validation/PMF method** — pre-build validation is in `product-brief`: graded evidence, a
  riskiest-assumption test with kill and pass thresholds set before it runs, and a Test first /
  Pursue / Park / Kill Decision. Post-launch PMF (retention plateau, Sean Ellis survey) is in
  `product-analytics` via `data-analyst`. Still unowned: running the test (interview recruiting and
  synthesis, building the smoke page), which is main-session work with `copywriting` (smoke-test
  page copy) and `cro`.
- **Paid media buying and measurement** — campaign structure, targeting, bidding, budgets,
  attribution modeling, incrementality and geo-lift, and MMM have no owner: `ad-creative` stops at
  creative, creative-test design and in-flight kill/promote rules, and `product-analytics` owns
  creative-test readouts and tagging.
- **Non-React or cross-document view transitions** — `react-view-transitions` covers React
  same-document transitions only; plain-JS `startViewTransition` and cross-document (MPA)
  `@view-transition` have no owner.
- **Device and cross-browser verification** — `browse` and `qa` drive headless desktop Chromium
  only (no Safari or Firefox; `viewport` resizes without touch or a mobile user agent), and nothing
  runs a mobile change on a simulator or device: `react-native-skills` runs device-free checks and
  reports a platform it did not run as `not run on <platform>`, which gates should treat as
  unverified.
- **Vercel-Labs `web-design-guidelines` / `writing-guidelines` not internalized** — unlike the four
  React/RN skills vendored in from vercel-labs/agent-skills (three still skills; `composition-patterns`
  now lives in `design-system/references/composition/`), these two only *wrap* a live WebFetch of
  Vercel-Labs-hosted rulesets, so internalizing them as-is would keep a runtime Vercel-Labs dependency;
  they were left out. `design-system` remains the primary UI-guidance authority for web UI
  work. To adopt them, vendor the remote rulesets into a real skill dir first, then route them.
- **Stale `.gitignore` whitelist** — the ignore-all-then-allow list still whitelists `!commands/`
  (no such dir exists) and duplicates `!README.md` (no README exists either). Harmless no-ops, but
  worth pruning on the next pass.
