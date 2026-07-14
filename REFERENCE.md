# REFERENCE.md

Static-lookup companion to [`AGENTS.md`](AGENTS.md) — the reference detail that does **not** need to
load every turn. `AGENTS.md` holds the always-on core: what this repo is, the build commands, how the
system works, the skill/agent **conventions** (the load-bearing rules), and the **Intent → agent
decision table**. This file holds the on-demand lookup tables: each agent's **skill palette** (agent
roster), the **Default doc locations** table, the **external dependencies**, and the **known gaps**.
For agent **sequencing** — the workflow chains and the solo-founder critical path — see
[`PLAYBOOK.md`](PLAYBOOK.md).

> The `apps/*`, `db/`, `docs/`, `tasks/`, and `biz/` paths below describe the **consuming project**
> an agent operates on — never this library's own contents (whose only top-level dirs are `agents/`
> and `skills/`).

---

## Agent roster

Each bullet is the agent's **routable skill palette**, not its frontmatter — most of these load on
demand via the `Skill` tool; only a subset (often one) is preloaded in the agent's `skills:` array
(e.g. `backend-developer` preloads `[postgresql]`, `mobile-developer` preloads `[react-native-skills]`,
`growth-optimizer` preloads `[copywriting]`).
Skill names with a colon (`vercel:deploy`) are the runtime Skill-tool namespace; the same skills
appear under hyphenated dir names in `skills/` when repo-owned.

**Plan layer (routers — no skills of their own):**
- `product-manager` → product-brief · prd-craft · feature-spec
- `architect` → software-architecture · arch-decision · database-design · llm-app-design
- `ux-designer` → ux-design (incl. 3D/XR UX) · screen-design · cro (when conversion-driven)
- `task-manager` → task-craft · task-add · task-status

**Dev layer (doers):**
- `backend-developer` → postgresql + one of axum-hexagonal / fastapi-hexagonal / hono-hexagonal / nestjs-hexagonal (by stack) · database-design · correctness-checklists
- `frontend-developer` → frontend-design + tanstack-start / composition-patterns / react-best-practices / react-view-transitions (by stack) · design-system · motion · i18n · web3d
- `mobile-developer` → react-native-skills · expo-app-design (Expo-managed) · design-system · motion · i18n
- `desktop-developer` → same web UI skill as frontend + Tauri-specific work
- `reviewer` → security-checklists · correctness-checklists · maintainability-checklists
- `verifier` → qa (browse) + playwright (preferred) / claude-in-chrome fallbacks
- `adversary` → adversarial-execution · security-checklists · correctness-checklists (executes their catalog at runtime) + playwright
- `release-engineer` → vercel:deploy · vercel:env · vercel:deployments-cicd · vercel:status · cloudflare:wrangler · cloudflare:workers-best-practices · Supabase MCP (by target)

**Biz layer (doers):**
- `marketer` → copywriting · competitor-pages · pricing · ad-creative · marketing-psychology
- `content-marketer` → copywriting · social-content · email-marketing · search-visibility
- `growth-optimizer` → cro · growth-loops · churn-prevention · pricing · marketing-psychology · copywriting
- `data-analyst` → product-analytics · churn-prevention (health-score framework, loaded on demand) + PostHog MCP

> Agent **sequencing** — how these chain end to end — lives in [`PLAYBOOK.md`](PLAYBOOK.md).

---

## Default doc locations

The conventional file locations the agents follow by default — a reference map of where each
artifact lives, not a runtime override point. Agents do **not** read this table at boot; to
change paths for a real project, set the conventions in that project's `CLAUDE.md`. Every file
an agent reads or writes has a row here. A trailing `/` denotes a directory family authored by
one agent.

| Artifact | Path | Written by | Read by |
|---|---|---|---|
| Product brief | `docs/prd/product-brief.md` | product-manager | architect, ux-designer, biz agents |
| PRD | `docs/prd/prd.md` | product-manager | architect, ux-designer, task-manager |
| Feature spec | `docs/prd/features/{feature}.md` | product-manager | architect, task-manager, developers |
| Arch context (greenfield sentinel) | `docs/arch/context.md` | architect (software-architecture) | architect (brownfield detection), developers |
| Architecture | `docs/arch/system.md` | architect (software-architecture) | developers, release-engineer, reviewer |
| Architecture decisions (ADRs) | `docs/arch/adr/ADR-NNN-{slug}.md` | architect (software-architecture, arch-decision) | developers |
| Risks & open questions | `docs/arch/risks.md` | architect (software-architecture) | developers, reviewer |
| Database design | `docs/arch/database.md` | architect (database-design) | backend-developer, reviewer, task-manager |
| AI feature design | `docs/arch/ai-features/{feature}.md` | architect (llm-app-design) | backend-developer, developers |
| App UX | `docs/ux/ux-design.md` | ux-designer | frontend/mobile/desktop developers |
| Screen specs | `docs/ux/screens/{screen}.md` | ux-designer | frontend/mobile/desktop developers |
| Task board | `tasks/board.md` | task-manager | developers, release-engineer |
| Task details | `tasks/features/{feature}.md` | task-manager | developers |
| Project checklist (optional) | `checklist.md` (repo root or `docs/`) | *(project-defined)* | reviewer |
| QA reports + regression baseline | `.qa/reports/` | qa skill (callers with file-write; verifier returns findings inline instead) | qa (regression mode) |
| Deploy runbook | `docs/ops/runbook.md` | release-engineer | release-engineer (next release) |
| Marketing strategy | `biz/marketing/strategy.md` | marketer | content-marketer, growth-optimizer, data-analyst |
| Launch materials | `biz/marketing/launch/` | marketer | content-marketer |
| Pricing (public tiers) | `biz/marketing/pricing.md` | marketer | growth-optimizer |
| Competitor analysis | `biz/marketing/competitors.md` | marketer | content-marketer |
| Competitor page drafts | `biz/marketing/competitor-pages/{slug}.md` | marketer (competitor-pages) | content-marketer (search-visibility layer) |
| Marketing assets | `biz/marketing/assets/` | marketer, content-marketer | — |
| Content strategy | `biz/marketing/content/strategy.md` | content-marketer | — |
| Content (social/email/blog/changelog) | `biz/marketing/content/{social,email,blog,changelog}/` | content-marketer | — |
| SEO/AEO/GEO audits + search strategy | `biz/marketing/seo/` | content-marketer (search-visibility) | — |
| Tracking plan + Aha moment | `biz/analytics/tracking-plan.md` | data-analyst | marketer, content-marketer, growth-optimizer |
| Funnels + retention | `biz/analytics/funnels.md` | data-analyst | ux-designer, growth-optimizer |
| Dashboards | `biz/analytics/dashboards.md` | data-analyst | — |
| Kill/Keep/Scale + CC | `biz/analytics/kill-criteria.md` | data-analyst | marketer |
| Customer health score | `biz/analytics/health-score.md` | data-analyst | growth-optimizer |
| Analytics reports | `biz/analytics/reports/` | data-analyst | all biz agents |
| Growth experiments log | `biz/growth/experiments.md` | growth-optimizer | data-analyst, content-marketer |
| Referral / viral loop | `biz/growth/referral-program.md` | growth-optimizer | — |
| Churn prevention strategy | `biz/growth/churn-prevention.md` | growth-optimizer | — |
| Dunning / payment recovery | `biz/growth/dunning.md` | growth-optimizer | — |
| Paywall / upgrade pricing | `biz/growth/paywall-pricing.md` | growth-optimizer | — |
| CRO analyses | `biz/growth/cro/{page-or-flow}-analysis.md` | growth-optimizer | — |
| Customer feedback log | `biz/ops/feedback-log.md` | *(currently unowned — see Known gaps)* | all biz agents |

**Source layout (monorepo convention):** `apps/web` · `apps/api` · `apps/worker` ·
`apps/mobile` · `apps/desktop` · `db/`. Each developer agent owns its `apps/*` directory.

---

## External dependencies (MCP servers & plugins)

These power specific agents. If one is unavailable, the agent falls back as noted.

| Dependency | Used by | Purpose | Fallback if missing |
|---|---|---|---|
| `frontend-design` plugin | frontend-developer, desktop-developer | Production-grade UI design | `design-system` + general best practice |
| `expo-app-design` plugin (Expo-managed) | mobile-developer | Native Expo/RN UI patterns. Expo-managed upstream, always installed — fall back briefly only if absent | `react-native-skills` (internalized) + `design-system` |
| Vercel MCP | release-engineer | Auth session for `vercel:*` skills + CLI (MCP exposes auth only; deploy/env/state run through the skills) | `vercel` CLI via Bash |
| Cloudflare MCPs (bindings/builds/observability) | release-engineer | Workers/Pages deploy, build logs, runtime logs | `wrangler` CLI via Bash |
| Supabase MCP | release-engineer | Migrations, edge functions, advisors, logs | `supabase` CLI via Bash |
| PostHog MCP | data-analyst | Live funnels, insights, cohorts, experiments | methodology only (no live data) |
| `@hypothesi/tauri-mcp-server` | desktop-developer | Tauri dev/inspection | `design-system` + general Tauri practice |
| claude-in-chrome / playwright MCP | verifier, adversary | Real-browser verification & E2E; adversary drives playwright for runtime attacks | the other of the two (verifier) |

---

## Known gaps (not yet covered)

Be honest about what this library does **not** do yet, so you don't assume an owner exists:

- **Run-the-business operations** — finance (runway, P&L, unit economics, tax), legal/compliance
  (ToS, privacy policy, GDPR/CCPA, entity), and founder operations (weekly cadence, OKRs,
  prioritization, decision log) have **no agent or skill**. Handle these outside the system.
- **Customer support / success** — ticket triage, help-center/FAQ ownership, NPS/CSAT, and the
  customer-feedback loop are unowned. `biz/ops/feedback-log.md` is read by biz agents but nothing
  creates or curates it.
- **Launch execution & GTM gate** — `marketer` owns launch *strategy*, but there is no day-of
  launch playbook or pre-launch go/no-go readiness checklist.
- **Native release depth** — mobile (Expo EAS, deep links, push) and desktop (Tauri signing,
  notarization, auto-update) lean on the developer agents + `release-engineer` without a dedicated
  in-house skill; expect more hands-on steps.
- **Security/compliance ops** — code-level security is covered, static *and* runtime (`reviewer` +
  `security-checklists`; `adversary` + `adversarial-execution` for runtime DAST on high-risk changes),
  but SOC2/ISO, secrets-rotation policy, and vendor risk are not.
- **Validation/PMF method** — `product-brief` captures the problem; it does not prescribe how to
  validate it (interviews, landing-page smoke tests, Sean Ellis survey).
- **Vercel-Labs `web-design-guidelines` / `writing-guidelines` not internalized** — unlike the four
  React/RN skills vendored in from vercel-labs/agent-skills, these two only *wrap* a live WebFetch of
  Vercel-Labs-hosted rulesets, so internalizing them as-is would keep a runtime Vercel-Labs dependency;
  they were left out. `design-system` remains the primary UI-guidance authority for frontend/desktop
  developers. To adopt them, vendor the remote rulesets into a real skill dir first, then route them.
- **Stale `.gitignore` whitelist** — the ignore-all-then-allow list still whitelists `!commands/`
  (no such dir exists) and duplicates `!README.md` (no README exists either). Harmless no-ops, but
  worth pruning on the next pass.
