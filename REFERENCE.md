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
| Backend build | hexagonal-backend (Axum / FastAPI / Hono / NestJS guide, by stack) · database-design (incl. PostgreSQL operations) · review-checklists (correctness section) |
| Web build | react-best-practices / react-view-transitions (by stack) · design-system (incl. component composition) · i18n · web3d |
| Mobile build | react-native-skills · design-system · i18n |
| Marketing | copywriting (incl. persuasion psychology) · competitor-pages · pricing · ad-creative; content: copywriting (social, email) · search-visibility |
| Growth | cro · growth-loops · churn-prevention · pricing · copywriting (incl. persuasion psychology) |
| Analytics | product-analytics · churn-prevention (via the `data-analyst` agent) |
| Ship / deploy | the deploy platform's own skills/CLI (e.g. vercel:* · cloudflare:wrangler · Supabase) · database-design (PostgreSQL operations: lock-safe migration execution) |

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
| Product brief | `docs/prd/product-brief.md` | product-brief | prd-craft, software-architecture, copywriting (persuasion psychology, social), data-analyst |
| PRD | `docs/prd/prd.md` | prd-craft | feature-spec, software-architecture, database-design, ux-design, plan-review (scope mode) |
| Feature spec | `docs/prd/features/{feature}.md` | feature-spec (new product: prd-craft) | software-architecture (incl. AI Feature Mode), arch-decision, database-design, ux-design, screen-design, implementers |
| Arch context (greenfield sentinel) | `docs/arch/context.md` | software-architecture | software-architecture (brownfield detection, together with implementation presence), arch-decision, implementers |
| Architecture | `docs/arch/system.md` | software-architecture (patched by arch-decision) | implementers (hexagonal-backend), database-design, plan-review (execution mode), reviewer |
| Architecture decisions (ADRs) | `docs/arch/adr/ADR-NNN-{slug}.md` | software-architecture, arch-decision | implementers |
| Risks & open questions | `docs/arch/risks.md` | software-architecture | arch-decision, implementers, reviewer |
| Database design | `docs/arch/database.md` | database-design | backend implementers, reviewer |
| AI feature design | `docs/arch/ai-features/{feature}.md` | software-architecture (AI Feature Mode) | ux-design, implementers |
| Recovered as-is (re-architecture / system migration; retired when the transition completes) | `docs/arch/as-is.md` | software-architecture (Build Mode on an existing system) | software-architecture (Transition Plan), implementers |
| App UX | `docs/ux/ux-design.md` | ux-design | screen-design, web/mobile implementers |
| Screen specs | `docs/ux/screens/{screen}.md` | ux-design (initial set), screen-design | web/mobile implementers |
| Project checklist (optional) | `checklist.md` (repo root or `docs/`) | *(project-defined)* | reviewer |
| QA reports + regression baseline | `.qa/reports/` | qa skill (callers with file-write; verifier returns findings inline instead) | qa (regression mode) |
| Marketing strategy | `biz/marketing/strategy.md` | main session (copywriting fills its Brand Voice section) | copywriting (incl. persuasion psychology, social), data-analyst |
| Launch materials | `biz/marketing/launch/` | main session | — |
| Pricing (public tiers) | `biz/marketing/pricing.md` | pricing | growth work (cro, growth-loops) |
| Competitor analysis | `biz/marketing/competitors.md` | main session | competitor-pages |
| Competitor page drafts | `biz/marketing/competitor-pages/{slug}.md` | competitor-pages | search-visibility |
| Marketing assets | `biz/marketing/assets/` | ad-creative | — |
| Content strategy | `biz/marketing/content/strategy.md` | main session | — |
| Content (social/email/blog/changelog) | `biz/marketing/content/{social,email,blog,changelog}/` | copywriting (social, email), search-visibility (blog); changelog: main session | — |
| SEO/AEO/GEO audits + search strategy | `biz/marketing/seo/` | search-visibility | — |
| Tracking plan + Aha moment | `biz/analytics/tracking-plan.md` | data-analyst (product-analytics) | cro, marketing and growth work |
| Funnels + retention | `biz/analytics/funnels.md` | data-analyst (product-analytics) | ux-design, growth work |
| Dashboards | `biz/analytics/dashboards.md` | data-analyst (product-analytics) | — |
| Kill/Keep/Scale + CC | `biz/analytics/kill-criteria.md` | data-analyst (product-analytics) | marketing work |
| Customer health score | `biz/analytics/health-score.md` | data-analyst (product-analytics; churn-prevention scoring model) | churn-prevention |
| Analytics reports | `biz/analytics/reports/` | data-analyst (product-analytics) | marketing and growth work |
| Growth experiments log | `biz/growth/experiments.md` | cro (experiment designs) | data-analyst |
| Referral / viral loop | `biz/growth/referral-program.md` | growth-loops | — |
| Churn prevention strategy | `biz/growth/churn-prevention.md` | churn-prevention | — |
| Dunning / payment recovery | `biz/growth/dunning.md` | churn-prevention | — |
| Paywall / upgrade pricing | `biz/growth/paywall-pricing.md` | pricing | — |
| CRO analyses | `biz/growth/cro/{page-or-flow}-analysis.md` | cro | — |
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

- **Run-the-business operations** — finance (runway, P&L, unit economics, tax), legal/compliance
  (ToS, privacy policy, GDPR/CCPA, entity), and founder operations (weekly cadence, OKRs,
  prioritization, decision log) have **no agent or skill**. Handle these outside the system.
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
- **Launch execution & GTM gate** — no skill owns launch *strategy* (it is main-session work drawing
  on the marketing skills), and there is no day-of launch playbook or pre-launch go/no-go readiness
  checklist.
- **Release / deploy** — no agent or skill owns shipping: the main session deploys with the
  platform's own skills/CLI (vercel, wrangler, supabase), with `database-design` (PostgreSQL operations) covering lock-safe
  migration execution. There is no in-house release gate (preview → smoke → promote, env/secret
  diff, rollback runbook), and mobile release (Expo EAS, deep links, push) has no dedicated skill.
- **Security/compliance ops** — code-level security is covered, static *and* runtime (`reviewer` +
  `review-checklists` security pass; `adversary` + `adversarial-execution` for runtime DAST on high-risk changes),
  but SOC2/ISO, secrets-rotation policy, and vendor risk are not.
- **Validation/PMF method** — `product-brief` captures the problem; it does not prescribe how to
  validate it (interviews, landing-page smoke tests, Sean Ellis survey).
- **Vercel-Labs `web-design-guidelines` / `writing-guidelines` not internalized** — unlike the four
  React/RN skills vendored in from vercel-labs/agent-skills (three still skills; `composition-patterns`
  now lives in `design-system/references/composition/`), these two only *wrap* a live WebFetch of
  Vercel-Labs-hosted rulesets, so internalizing them as-is would keep a runtime Vercel-Labs dependency;
  they were left out. `design-system` remains the primary UI-guidance authority for web UI
  work. To adopt them, vendor the remote rulesets into a real skill dir first, then route them.
- **Stale `.gitignore` whitelist** — the ignore-all-then-allow list still whitelists `!commands/`
  (no such dir exists) and duplicates `!README.md` (no README exists either). Harmless no-ops, but
  worth pruning on the next pass.
