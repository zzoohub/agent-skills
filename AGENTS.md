# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**What this file is:** the auto-loaded **core** of this agent + skill library — what the repo is, the
build commands, how the system works, the **skill/agent conventions** (the load-bearing rules), and
the **Intent → skill or agent table** (what to load or call). The on-demand reference detail — each
agent's full skill palette, **how the skills and agents chain end to end**, **where each skill reads
and writes files by convention**, and **what external tools the system depends on** — lives in
[`REFERENCE.md`](REFERENCE.md) (the chains in [`PLAYBOOK.md`](PLAYBOOK.md)), read only when needed.
(This core content lives here in `AGENTS.md`; `CLAUDE.md` is a one-line `@AGENTS.md` import stub, so
Claude Code still auto-loads this file as project instructions.)

> The planning skills are the conventional owners of their doc trees: `product-brief` / `prd-craft` /
> `feature-spec` write `docs/prd/`, `software-architecture` / `arch-decision` (plus `database-design`
> for its own file) write `docs/arch/`, `ux-design` / `screen-design` write
> `docs/ux/` (all caller-overridable defaults).

---

## What this repository is

This repo is **not an application** — it is a **portable skill library + a Claude Code agent layer**.
There is no product source code here. It ships three things:

- **`skills/`** — **29** framework-agnostic skills, each `skills/<kebab-name>/SKILL.md` plus optional
  `references/` (deep-dive docs loaded on demand — 21 skills), `rules/` (guideline files:
  `react-best-practices` per rule, `react-native-skills` per decision area), `templates/`
  (output scaffolds — `prd-craft`, `qa`, `software-architecture`, `ux-design`), `scripts/` (helpers —
  `database-design` only; two `.sql` files), `evals/` (`review-checklists` only) and the vendored
  forks' `UPSTREAM.md` records (see below). Not counted: the untracked `skills/synced/` folder, a
  local sync cache that is not part of the library.
  A `SKILL.md` runs on any Agent-Skills-compatible runtime; only `name` + `description` frontmatter
  is load-bearing.
- **`agents/`** — **4** Claude-Code-only subagent definitions, split `agents/dev/` (3: `reviewer`,
  `verifier`, `adversary`) · `agents/biz/` (1: `data-analyst`). Each `.md` carries
  `name`, `description`, `tools`, `model`, `skills`, `color` frontmatter (+ an `mcpServers` array on the
  3 MCP-bound agents: `verifier`, `adversary`, `data-analyst`). `agents/` is the source of truth; Claude
  Code consumes agents from `.claude/agents/` — this repo does **not** vendor that mapping (deploy or
  symlink per environment). The repo tracks no `.claude/` content (`.gitignore` does not whitelist it).
- **`AGENTS.md`** + **`REFERENCE.md`** — this auto-loaded core map (imported by the one-line
  `CLAUDE.md` stub) and its on-demand reference companion.

**The `apps/*`, `db/`, `docs/`, and `biz/` paths referenced throughout describe the
consuming project a skill or agent operates on — never this library's own contents** (whose only top-level
dirs are `agents/` and `skills/`). Don't look for app code or those doc trees here.

**Internalized React/RN content (formerly external symlinks).** Four skills were vendored in
from [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (MIT) and scrubbed of
Vercel-infrastructure coupling so they are self-contained and host-agnostic. Three remain skills:
`react-best-practices`, `react-native-skills` (each ships a `rules/` library) and
`react-view-transitions` (ships `references/`). The fourth, `composition-patterns`, is no longer a
skill: its guide and `rules/` library now live in `design-system/references/composition/` (provenance
note kept there). They replaced four dangling symlinks into an external Vercel/Expo store, so every
skill under `skills/` is a real, repo-owned directory — no symlinks.
**Vendored content is a frozen fork** (these four and `browse`): never re-clone over it; merge
upstream changes selectively by hand, per its `UPSTREAM.md` (provenance, divergence, re-apply list).
(The Vercel-Labs `web-design-guidelines` / `writing-guidelines` skills were deliberately **not**
internalized; `design-system` remains the UI-guidance authority — see **Known gaps** in `REFERENCE.md`.)

**Adding to the library:** a new skill → `skills/<kebab-name>/SKILL.md` (name + description
frontmatter; follow **Skill conventions** below). A new agent → `agents/<layer>/<name>.md` (follow
**Agent conventions** below).

## Commands

This is a **documentation/config library — there is no repo-wide build, test, lint, or format
step** (no root `package.json`, Makefile, `justfile`, or CI). Skills and agents are markdown. There
are exactly two exceptions:

**`skills/browse`** — the only buildable/testable component: a TypeScript + Playwright tool that Bun
compiles into a ~63MB binary, not standalone: it starts its daemon with `bun run src/server.ts`, so
it needs `bun` and the built skill folder at runtime. `dist/` is gitignored, so it must be rebuilt
after clone.
Run from `skills/browse/`:

```bash
./setup            # one-time, idempotent: bun install + Playwright Chromium + build + git-SHA stamp
bun install        # deps only
bun run build      # compile dist/browse + dist/find-browse (bun build --compile)
bun run typecheck  # tsc --noEmit
bun test           # Bun's runner auto-discovers test/*.test.ts (there is no `test` script)
```

Requires `bun` (`curl -fsSL https://bun.sh/install | bash`) and `git`. `skills/qa` *drives* this
binary (resolved via `$BROWSE_BIN` or the bundled `bin/find-browse`) but has no build of its own.

**SQL helper scripts** — read-only, psql-ready diagnostics, run by hand against a target Postgres DB
(not a script runner):

```bash
psql <conn> -f skills/database-design/scripts/query_diagnostics.sql  # runtime: waits, blocker tree, xmin horizon and wraparound, top statements (pg_stat_statements), replica lag
psql <conn> -f skills/database-design/scripts/schema_review.sql  # structural: unindexed FKs, unused-index candidates, key headroom, risky types, RLS gaps
```

`.gitignore` uses an ignore-all-then-whitelist pattern (comments are in Korean) and excludes build
outputs: `skills/**/dist/`, `skills/**/node_modules/`, `skills/**/*.bun-build`.

---

## How the system works

- **The main session does the work; skills supply the method.** Planning, design, implementation
  and marketing are done by the main session (or general-purpose subagents it spawns) loading the
  relevant skills directly — skills auto-load from their `description`. There are no router or
  builder agents.
- **The remaining agents are narrow, independent roles.** Gates: `reviewer` (static pre-landing
  review), `verifier` (proves behavior in a real browser / against endpoints), `adversary`
  (high-risk only, reproduces exploits in an isolated env). An analytics reader: `data-analyst`.
  Each returns its verdict or findings to the main session. Shipping is the main session's job too,
  with the deploy platform's own skills/CLI.
- **Agents never call other agents.** Each agent invokes *skills* only. Sequencing across skills
  and agents is orchestrated by the main conversation (you, or the top-level assistant). The
  **workflow chains** in [`PLAYBOOK.md`](PLAYBOOK.md) are the intended sequences — run them step by
  step, checking each output before the next step consumes it.
- **Skills load on demand.** The session or agent pulls a skill into context only when the task
  needs it. Skills hold the method, the format, and the quality bar; the caller holds the routing
  and judgment.
- **Files are the handoff medium.** `prd-craft` writes `docs/prd/`, `software-architecture` reads it
  and writes `docs/arch/`, `ux-design` writes `docs/ux/`, the marketing skills write under `biz/`,
  and so on. The **Default doc locations** table in `REFERENCE.md` records the conventional layout
  these skills follow, so a later step can find where an earlier one left off. It is a reference of
  where things live by default, not a contract this file enforces.

---

## Design philosophy & conventions

The split below is the load-bearing idea; the rest follows from it.

**Orchestrator ⊥ capability.** A **skill** is a portable, framework-agnostic
*capability* (the method, format, and quality bar). An **agent** is a
Claude-Code-only *orchestrator* (routing, judgment, file I/O, sequencing). This is
separation of mechanism (skill) from policy (agent) — ports & adapters: the skill is
the dependency-free core, each runtime is an adapter. **The portable unit is the
skill, not the agent.** A `SKILL.md` runs on any Agent-Skills-compatible runtime
(Claude Code, Hermes, OpenClaw, Codex, …); a `.claude/agents/*.md` runs only in
Claude Code, by design.

### Skill conventions (keep skills portable)

- **Framework-agnostic.** No `$ARGUMENTS`, no harness-only tools, no `AskUserQuestion`
  as a requirement. Only `name` + `description` are load-bearing frontmatter; the body
  is plain instructions any runtime reads.
- **Paths are defaults, not contracts.** Write "the X (default `docs/…`; caller may
  redirect)" — never a hardcoded destination. The default preserves current behavior;
  the caller (an agent) may override.
- **Prerequisites degrade gracefully.** "If absent, ask the caller" — never a
  framework-specific hard-stop.
- **No `## Contract` / Inputs-Outputs / YAML block.** Decouple by editing existing
  lines in place ("Lean-inline"). A blind A/B (6-0) showed a dedicated section adds
  body surface that competes for the model's attention and *lowers craft-output
  quality* — quality, not token cost, is the reason.
- **Body cross-references are soft** ("via the X capability, if available").
- **Descriptions are routing contracts with a budget** (≤700 characters here): Claude Code's skill
  listing gets ~1% of the context window and on overflow drops whole descriptions, least-invoked
  first, so the Intent table below also carries each skill's key intents. Lead with what the skill
  does and when; Do-NOT clauses only for nearest neighbors that misroute (finer routing goes in the
  body). A boundary change edits both neighbors' descriptions together.
- **Draft gap tags.** Marketing drafts mark `[VERIFY: claim]` and `[SOURCE NEEDED: what]` (competitor-pages
  also writes `[TODO: …]` for caller input and a bare `[VERIFY]` on an unchecked date); grep
  `\[(VERIFY|SOURCE NEEDED|TODO)` before publishing.
- **Host-coupled skills declare it** via the standard `compatibility:` frontmatter
  (e.g. `browse` ships a binary and `qa` drives it; resolve it via `${BROWSE_BIN}`, not a fixed path).

### Agent conventions (own the orchestration the skills don't)

- **Agents never call other agents.** Cross-agent sequencing is the main session's
  job; sequencing an agent's *own* skills in dependency order is fine.
- **The agent owns the three things a decoupled skill hands back:**
  1. **Input provisioning.** Read `CLAUDE.md` first (it may redirect roots), resolve
     and pass the doc paths the skill needs (e.g. the diff plus any project `checklist.md`
     for `reviewer`), so the skill's "ask the
     caller" never dead-ends in a subagent that cannot prompt. A genuinely missing input
     becomes a *text question in the return summary*, never an interactive prompt.
  2. **Output paths.** The agent owns where its artifacts land (the skill's path is a
     caller-overridable default). See the Default doc locations table in `REFERENCE.md`.
  3. **Sequencing / build.** The agent drives its skills in dependency order to produce
     its verdict, report or deploy, and returns it to the main session. When the main
     session runs a skill directly, it owns this sequencing itself (e.g.
     `software-architecture` → `arch-decision` per decision).
- **Gates report; they do not certify.** `reviewer`, `verifier` and (high-risk only)
  `adversary` each return an independent verdict and findings to the main session,
  which decides whether the change is done.
- **Model policy is intentionally uniform `opus`** (reviewer/verifier = `sonnet`).
  Not a cost oversight — leave it.
- **Frontmatter fields.** Every agent sets `name`, `description`, `tools`, `model`, `skills`,
  `color`. The 3 MCP-dependent agents (`verifier`, `adversary`, `data-analyst`)
  additionally declare an `mcpServers:` array plus the matching `mcp__*` globs in `tools:`.
  "Agents never call other agents" is enforced *structurally* — no agent is granted a
  subagent-spawning tool (`Task`/`Agent`).
  (Among skills, only `browse` and `qa` declare `allowed-tools`; in Claude Code that field
  pre-approves the listed tools — it does not restrict the skill to them. `plan-review` declares
  none and relies on its prose read-only rule. Only `browse`/`qa` and `adversarial-execution` carry
  `compatibility:`.)

### Why this lives here

This file (`AGENTS.md`, auto-loaded via the `@AGENTS.md` import in `CLAUDE.md`) is the reference
map for **this library**. Conventions belong here — never baked into a skill, which must stay
portable; a *consuming* project layers its own runtime overrides in its own `CLAUDE.md`. Several
conventions above were chosen by blind A/B experiment, not assertion.

---

## Intent → skill or agent table

Find the row that matches what you want. A **skill** row means the main session (or a
general-purpose subagent it spawns) loads that skill and does the work; an **agent** row means
call that agent.

| You want to… | Skill(s) or agent | Kind |
|---|---|---|
| Validate a new product idea or direction / write a one-pager (the *why* and *whether*) | `product-brief` | skill |
| Write or review a full PRD, or record a release checkpoint | `prd-craft` | skill |
| Spec, revise or review one feature on an existing product | `feature-spec` | skill |
| Design the system architecture | `software-architecture` | skill |
| Modernize, re-architect or migrate an existing system (as-is recovery, transition plan) | `software-architecture` (Build Mode on an existing system) | skill |
| Record or review one architecture decision (ADR) on an existing system | `arch-decision` | skill |
| Design or review a DB schema; tune queries, run lock-safe migrations or upgrade a live Postgres | `database-design` | skill |
| Design an LLM/AI feature or app | `software-architecture` (AI Feature Mode) | skill |
| Design app-wide UX/IA, a new multi-screen flow or 3D/XR UX; recover or audit a shipped app's UX | `ux-design` | skill |
| Design or redesign one screen, with or without a UX doc | `screen-design` | skill |
| Implement 3D / XR on the web | `web3d` | skill |
| Build/modify backend: APIs, domain logic, DB queries, workers (`apps/api`, `apps/worker`, `db/`) | `hexagonal-backend` (stack guide picked from build files — Axum, Hono, FastAPI or NestJS; greenfield default Axum for container services, Hono for Workers/edge) + `database-design` (incl. PostgreSQL operations) | skill |
| Build/modify web frontend: pages, components, state, styling (`apps/web`) | `react-best-practices`, `react-view-transitions` (route and shared-element transitions), `design-system` (incl. component composition), `i18n` | skill |
| Design tokens, theming or dark mode, a visual refresh ("looks dated"), component APIs; set up or audit a design system | `design-system` | skill |
| Build/modify a mobile app: Expo / React Native screens (`apps/mobile`) | `react-native-skills` (+ `design-system`, `i18n`) | skill |
| Add a language, fix a locale bug (plurals, RTL, time zones), audit i18n | `i18n` | skill |
| Pre-landing code review: security + correctness + maintainability | `reviewer` (method in `review-checklists`) | agent |
| Verify behavior in a real browser / smoke-test endpoints before merge | `verifier` (method in `qa` + `browse`) | agent |
| Red-team a high-risk change: reproduce exploits against a running app in an isolated env | `adversary` (method in `adversarial-execution`) | agent |
| Ship to production: deploy, env/secrets, migrations, CI/CD, rollback | the deploy platform's own skills/CLI (e.g. `vercel:*`, `cloudflare:wrangler`, Supabase) + `database-design` (PostgreSQL operations) for lock-safe migration execution | platform skill |
| Marketing and launch copy (landing, home and pricing pages, headlines, CTAs, brand voice), pricing, ad creative and creative tests, competitor pages | `copywriting` (page and launch-day copy, persuasion psychology; drafts positioning for the main session's `strategy.md`), `pricing`, `ad-creative`, `competitor-pages` | skill |
| Ongoing content: social, email, changelog, build-in-public, blog articles | `copywriting` (social, email, changelog), `search-visibility` (blog) | skill |
| SEO or AI-visibility audit, organic-traffic drop, keyword research, technical SEO, AI citations | `search-visibility` | skill |
| Conversion (CRO), A/B test design, referral/viral loops, affiliate programs, churn (cancel flows, failed payments), paywall/upgrade | `cro`, `growth-loops`, `churn-prevention` | skill |
| Analytics: tracking plan, funnels, retention/PMF, weekly reports, "why did X drop", test readouts | `data-analyst` (method in `product-analytics`) | agent |

For a plan review *before* writing code, the main agent can invoke the `plan-review` skill
directly — in scope mode (scope/vision, while scope is negotiable) or execution mode (locked-scope
execution rigor) — it is not owned by an agent. The review returns its verdict, ranked issue list,
proposed follow-ups and any unresolved decisions to the main session, which asks the user (with
its question UI when it has one) and decides what to act on.

---

## Companion files (read on demand)

Detail that doesn't belong in every turn's context lives in two companions. These are plain
markdown links, **not** `@imports` — Claude Code does not auto-load them; they cost nothing until the
session or an agent chooses to open one:

- [`PLAYBOOK.md`](PLAYBOOK.md) — how the skills and agents chain end to end: the 5 workflow
  sequences (full launch, feature, growth, GTM, review) and the solo-founder minimum spine.
- [`REFERENCE.md`](REFERENCE.md) — static lookup tables: the agent skill-palette **roster**, the
  **skill map by area**, **Default doc locations**, **external dependencies** (MCP/plugins +
  fallbacks), and **known gaps**.
