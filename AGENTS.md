# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**What this file is:** the auto-loaded **core** of this agent + skill library — what the repo is, the
build commands, how the system works, the **skill/agent conventions** (the load-bearing rules), and
the **Intent → agent decision table** (which agent to call). The on-demand reference detail — each
agent's full skill palette, **how the agents chain end to end**, **where each agent reads and writes
files by convention**, and **what external tools the system depends on** — lives in
[`REFERENCE.md`](REFERENCE.md), read only when needed. (This core content lives here in `AGENTS.md`;
`CLAUDE.md` is a one-line `@AGENTS.md` import stub, so Claude Code still auto-loads this file as
project instructions.)

> The plan agents are the domain owners of their doc trees: `product-manager` owns `docs/prd/`,
> `architect` owns `docs/arch/`, `ux-designer` owns `docs/ux/`, `task-manager` owns `tasks/`.

---

## What this repository is

This repo is **not an application** — it is a **portable skill library + a Claude Code agent layer**.
There is no product source code here. It ships three things:

- **`skills/`** — **46** framework-agnostic skills, each `skills/<kebab-name>/SKILL.md` plus optional
  `references/` (deep-dive docs loaded on demand — 32 skills), `rules/` (per-rule guideline files —
  `composition-patterns`, `react-best-practices`, `react-native-skills`), `templates/` (output scaffolds
  — `qa`, `software-architecture`), and `scripts/` (helpers — `database-design`, `postgresql`; both `.sql`).
  A `SKILL.md` runs on any Agent-Skills-compatible runtime; only `name` + `description` frontmatter
  is load-bearing.
- **`agents/`** — **16** Claude-Code-only subagent definitions, split `agents/plan/` (4) ·
  `agents/dev/` (8) · `agents/biz/` (4). Each `.md` carries `name`, `description`, `tools`, `model`,
  `skills`, `color` frontmatter (+ an `mcpServers` array on the 5 MCP-bound agents: `verifier`, `adversary`,
  `release-engineer`, `data-analyst`, `desktop-developer`). `agents/` is the source of truth; Claude
  Code consumes agents from `.claude/agents/` — this repo does **not** vendor that mapping (deploy or
  symlink per environment). The only `.claude/` content here is `settings.local.json`.
- **`AGENTS.md`** + **`REFERENCE.md`** — this auto-loaded core map (imported by the one-line
  `CLAUDE.md` stub) and its on-demand reference companion.

**The `apps/*`, `db/`, `docs/`, `tasks/`, and `biz/` paths referenced throughout describe the
consuming project an agent operates on — never this library's own contents** (whose only top-level
dirs are `agents/` and `skills/`). Don't look for app code or those doc trees here.

**Internalized React/RN skills (formerly external symlinks).** Four skills here were vendored in
from [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (MIT) and scrubbed of
Vercel-infrastructure coupling so they are self-contained and host-agnostic: `composition-patterns`,
`react-best-practices`, `react-native-skills` (each ships a `rules/` library) and
`react-view-transitions` (ships `references/`). They replaced four dangling symlinks into an external
Vercel/Expo store, so every entry under `skills/` is now a real, repo-owned directory — no symlinks.
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
compiles into a ~63MB standalone binary. `dist/` is gitignored, so it must be rebuilt after clone.
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
See `skills/browse/UPSTREAM.md` for its frozen-fork posture.

**SQL helper scripts** — psql-ready diagnostics, run by hand against a target Postgres DB (not a
script runner):

```bash
psql <conn> -f skills/postgresql/scripts/query_diagnostics.sql   # slow queries/locks/bloat (needs pg_stat_statements)
psql <conn> -f skills/database-design/scripts/schema_review.sql  # unindexed FKs, unused indexes, missing constraints
```

`.gitignore` uses an ignore-all-then-whitelist pattern (comments are in Korean) and excludes build
outputs: `skills/**/dist/`, `skills/**/node_modules/`, `skills/**/*.bun-build`.

---

## How the system works

- **Two kinds of agents.** *Routers* (the plan layer) own no skills themselves — they read your
  intent and invoke the right skill. *Doers* (dev + biz) do the work, calling skills as needed.
- **Agents never call other agents.** Each agent invokes *skills* only. Sequencing across agents
  is orchestrated by the main conversation (you, or the top-level assistant). The **workflow
  chains** in [`PLAYBOOK.md`](PLAYBOOK.md) are the intended sequences — run them step by step,
  checking each output before the next agent consumes it.
- **Skills load on demand.** An agent pulls a skill into context only when the task needs it.
  Skills hold the method, the format, and the quality bar; agents hold the routing and judgment.
- **Files are the handoff medium.** product-manager writes `docs/prd/`, architect reads it and
  writes `docs/arch/`, and so on. The **Default doc locations** table in `REFERENCE.md` records the
  conventional layout these agents follow, so a later agent can find where an earlier one left off.
  It is a reference of where things live by default, not a contract this file enforces.

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
- **Body cross-references are soft** ("via the X capability, if available"). The
  `description` block's "use the Y skill" routing text is harmless metadata other
  runtimes ignore — leave it.
- **Host-coupled skills declare it** via the standard `compatibility:` frontmatter
  (e.g. `browse`/`qa` ship a binary; resolve it via `${BROWSE_BIN}`, not a fixed path).

### Agent conventions (own the orchestration the skills don't)

- **Agents never call other agents.** Cross-agent sequencing is the main session's
  job; sequencing an agent's *own* skills in dependency order is fine.
- **The agent owns the three things a decoupled skill hands back:**
  1. **Input provisioning.** Read `CLAUDE.md` first (it may redirect roots), resolve
     and pass the doc paths the skill needs, so the skill's "ask the caller" never
     dead-ends in a subagent that cannot prompt. A genuinely missing input becomes a
     *text question in the return summary*, never an interactive prompt. Each plan
     agent lists these in a **Required Inputs** section.
  2. **Output paths.** The agent owns where artifacts land (the skill's path is a
     caller-overridable default). See the Default doc locations table in `REFERENCE.md`.
  3. **Sequencing / build.** The agent drives the skill to produce + place the
     artifact and reports back. Chains removed from skill bodies (e.g.
     `software-architecture` → `arch-decision` per decision) live in the owning agent.
- **Task lifecycle has one owner per transition.** `task-manager` writes the **left
  edge** (`backlog`→`active` + assignee, on dispatch) and the **close**
  (`active`→`done`) — the close only after the main session confirms reviewer *and*
  verifier passed (plus `adversary` on high-risk changes). Builder agents never
  self-certify `done` (they leave the task `active`, or mark `blocked` if they couldn't
  finish); the verifier *proves* behavior (and the adversary, high-risk only,
  *reproduces exploits*) — neither writes status. The main session sequences the chain
  and triggers the close.
- **Model policy is intentionally uniform `opus`** (reviewer/verifier = `sonnet`).
  Not a cost oversight — leave it.
- **Frontmatter fields.** Every agent sets `name`, `description`, `tools`, `model`, `skills`,
  `color`. The 5 MCP-dependent agents (`verifier`, `adversary`, `release-engineer`, `data-analyst`,
  `desktop-developer`) additionally declare an `mcpServers:` array plus the matching `mcp__*` globs
  in `tools:`. "Agents never call other agents" is enforced *structurally* — no agent is granted a
  subagent-spawning tool (`Task`/`Agent`), routers included; a router's `tools:` are file-I/O +
  `Skill` (`Read, Write, Edit, Grep, Glob, Skill`) — the skills it invokes do the reads and writes.
  (Two *skills*, `plan-ceo-review` and
  `plan-eng-review`, pin `allowed-tools` too, though they are not host-coupled — only `browse`/`qa`
  carry `compatibility:`.)

### Why this lives here

This file (`AGENTS.md`, auto-loaded via the `@AGENTS.md` import in `CLAUDE.md`) is the reference
map for **this library**. Conventions belong here — never baked into a skill, which must stay
portable; a *consuming* project layers its own runtime overrides in its own `CLAUDE.md`. Several
conventions above were chosen by blind A/B experiment, not assertion.

---

## Intent → agent decision table

Find the row that matches what you want, call that agent.

| You want to… | Agent | Layer |
|---|---|---|
| Validate a new product idea / write a one-pager (the *why*) | `product-manager` | plan |
| Write a full PRD, or spec a single feature on an existing PRD | `product-manager` | plan |
| Design the system architecture, an ADR, a DB schema, or an LLM/AI app | `architect` | plan |
| Design app-wide UX/IA, a single screen, or audit existing UX | `ux-designer` | plan |
| Generate the task board, add/revise a task, move task status, audit the board | `task-manager` | plan |
| Build/modify backend: APIs, domain logic, DB queries, workers (`apps/api`, `apps/worker`, `db/`) | `backend-developer` | dev |
| Build/modify web frontend: pages, components, state, styling (`apps/web`) | `frontend-developer` | dev |
| Build/modify a mobile app: Expo / React Native screens (`apps/mobile`) | `mobile-developer` | dev |
| Build/modify a desktop app: Tauri core + web UI (`apps/desktop`) | `desktop-developer` | dev |
| Pre-landing code review: security + correctness + maintainability | `reviewer` | dev |
| Verify behavior in a real browser / smoke-test endpoints before merge | `verifier` | dev |
| Red-team a high-risk change: reproduce exploits against a running app in an isolated env | `adversary` | dev |
| **Ship to production: deploy, env/secrets, migrations, CI/CD, rollback** | **`release-engineer`** | dev |
| Marketing strategy, launch, positioning, competitor angle, pricing strategy, ad creative | `marketer` | biz |
| Ongoing content: social, email sequences, blog/SEO, changelog, build-in-public | `content-marketer` | biz |
| Conversion (CRO), referral/viral loops, churn/retention, paywall/upgrade | `growth-optimizer` | biz |
| Analytics: tracking plan, funnels, retention/PMF, weekly reports, A/B analysis | `data-analyst` | biz |

For a plan review *before* writing code, the main agent can invoke the `plan-ceo-review`
(scope/vision) or `plan-eng-review` (locked-scope execution rigor) skills directly — these are
not owned by an agent. The review skill **proposes** task rows but does not place them: after the
review, the main session renders the structured issue list interactively (it is the runtime that
supplies the question UI) and carries any approved tasks to `task-manager`, which appends them via
`task-add`.

---

## Companion files (read on demand)

Detail that doesn't belong in every turn's context lives in two companions. These are plain
markdown links, **not** `@imports` — Claude Code does not auto-load them; they cost nothing until an
agent chooses to open one:

- [`PLAYBOOK.md`](PLAYBOOK.md) — how the agents chain end to end: the 5 workflow sequences (full
  launch, feature, growth, GTM, review), the task-status ownership rules, and the solo-founder
  minimum spine.
- [`REFERENCE.md`](REFERENCE.md) — static lookup tables: the agent skill-palette **roster**,
  **Default doc locations**, **external dependencies** (MCP/plugins + fallbacks), and **known gaps**.
