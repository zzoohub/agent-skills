# Pre-vetted House Stack

A **swappable house profile**, not a neutral catalog of technology options: a **curated house stack** built around Cloudflare Workers/Containers, GCP (Cloud Run, Cloud SQL, BigQuery), Supabase for Postgres, and a short list of proven external services. Choices reflect operational familiarity, regional constraints (Korea), and cost discipline.

This file is **opinionated and deliberately non-portable** — it encodes one shop's procurement, not universal guidance. On another runtime or org, treat it as a worked example, not a mandate.

**Applies only when adopted**: a project opts in with one line in its project conventions file naming this path (e.g. `House profile: the software-architecture skill's references/house-stack.md`), or the caller names it. Once adopted and checked against the target environment, its defaults fill the choices that the caller's or the existing system's constraints leave open, and Profile Context is copied into `context.md` §5 (`design-flow.md` § Technology Baseline & Selection). To swap profiles, point that line at another file with the same sections; general files never name these rows.

Last verified: 2026-10-06

**Maturity tags**: (beta)/(RC)/(WIP)/(pre-1.0) = pre-GA under design-flow Stage 5; 'fixed' = not open to deviation ADRs. Pre-GA rows are fine as defaults; where a row names an inline GA fallback, prefer it when the guarantee matters.

**Deviations** follow the general rule in design-flow Stage 5 plus this profile's extra criteria. 

---

## Profile Context

Copied into `context.md` §5 when adopted.

- **Who builds and operates**: primarily AI agents; small team.
- **Regions, residency & cloud split — read first**: Cloudflare and GCP are *not* interchangeable co-equals; the relationship is **hub-and-spoke**. Default to **Cloudflare** for the edge / serverless / agent fabric and the global front door; reach for **GCP** for regional heavy compute (Cloud Run GPUs, Cloud SQL, BigQuery, Pub/Sub) and the **Korea data-residency anchor** (`asia-northeast3`). Workers VPC + Hyperdrive stitch the two into one private network (Workers in front, Cloud SQL behind). When a row lists both, the CF option is the primary and the GCP option is the heavy-or-Korea trigger.
- **Cost posture**: cost discipline — a short list of proven services, and nothing per-seat for what is just code (build-vs-buy posture below).
- **Build-vs-buy posture**: **Build or self-host by default** — agentic dev collapsed the build cost, and generic subdomains are an agent's best-documented territory. **Buy only what you cannot write**; each vendor adopted carries an ADR. Agentic dev deflated one cost: writing and changing code. A vendor is worth a permanent dependency only when it sells something else — the test in `design-flow.md` § Subdomain Classification & Build-vs-Buy. House verdicts on that test: someone else's pager → buy when there's no rotation (an agent writes it once; a human still wakes at 3am); spec conformance under attack → audited library, self-hosted; just code → build (the agent can read and test the whole path). External Services below is the shortlist where buying still wins.
- **Extra selection criteria — agentic operability**: this stack is built and operated primarily by AI agents, so selections also weigh three properties — a first-class local dev loop (`wrangler dev`, emulators, `bun test`) an agent can iterate against; typed SDKs and declarative config an agent can read, edit, and diff (files, not dashboard clicks); and failures observable from the CLI (logs/errors reachable without a browser). The IaC-first rows (OpenTofu, Wrangler, GitHub Actions) are load-bearing for this, not conveniences — a dashboard-only service would need an ADR arguing why losing agent operability is worth it.

---

## Role Defaults

The house default (or ordered options) per role. A role with no row has no house technology default — select per ASR; its sourcing still follows the build-vs-buy posture above.

### Language & Runtime

| Role | Choice |
|---|---|
| Language | TypeScript, Rust, Python |
| JS runtime / toolchain | **Bun** (runtime, package manager, bundler, test) |
| Python toolchain | **uv** (env, dependency resolution, lock) |

Go is **deliberately excluded** — Rust covers the performance/CLI niche, TypeScript covers services. Add Go only via an ADR if a team lacks the Rust depth for stateless Container/Cloud Run services.

### Framework

| Role | Options |
|---|---|
| Server (Workers) | Hono, workers-rs **(WIP — reserve for wasm-on-Workers)** |
| Server (Container) | Axum, FastAPI |
| Frontend | TanStack Start **(RC — pin exact versions)** (React or Solid), Next.js |
| Mobile | React Native (Expo) + Expo Router + EAS |
| Desktop | Tauri |
| CLI | Rust |
| Game | Godot, Bevy **(pre-1.0)** |
| Data Pipeline | Basin Pipelines (formerly Cloudflare Pipelines), Cloud Dataflow, dbt (Core v2 / Fusion engine) |

### Infrastructure

| Role | Options |
|---|---|
| Edge API | Workers, Cloud Run |
| Stateful / WebSocket | Durable Objects, Cloud Run |
| Async workflows | Workflows + Queues, Cloud Tasks + Pub/Sub |
| Container / agent sandbox | CF Containers, CF Sandboxes, Cloud Run |
| Cron | Cron Triggers, Cloud Scheduler |
| Multi-tenant | Workers for Platforms |
| DNS + CDN | Cloudflare, Cloud CDN + Cloud DNS |
| CI/CD | GitHub Actions + Workers Builds |
| Config (IaC) | **OpenTofu** — fixed; not Terraform (BSL) or Pulumi. Wrangler stays for the Workers surface (`wrangler.jsonc`) |
| Secrets | Worker Secrets (GA), Secrets Store **(beta)**, Secret Manager |
| Zero Trust / private net | CF Zero Trust (GA), Workers VPC **(beta)** — fall back to Tunnel + Access if GA is required |

### Data

| Role | Options |
|---|---|
| Postgres (global) | Cloud SQL + Hyperdrive |
| Postgres (Korea) | Supabase + Hyperdrive, Cloud SQL |
| SQLite | D1 (read replication **beta**), Durable Objects (SQLite storage) |
| Cache (eventual) | KV |
| Cache (strong) | Upstash Redis (Valkey if self-managed) |
| Queue | CF Queues, Cloud Tasks |
| Streaming | Basin Pipelines (formerly Cloudflare Pipelines; -> R2 / Iceberg), Cloud Pub/Sub |
| Objects | R2 |
| Analytics / DW | BigQuery, Basin (Pipelines + Basin SQL, formerly R2 SQL) (ClickHouse if self-hosted / cost-controlled) |
| Vector | Vectorize (vector-only — no BM25/keyword; ≤20M vectors/index as of 2026-10), pgvector |
| Search (full-text / hybrid) | Postgres FTS, Typesense, Meilisearch |
| Images | CF Images |
| Video | CF Stream + Media Transformations |

### AI

| Role | Options |
|---|---|
| LLM inference | Workers AI, Gemini Enterprise Agent Platform (formerly Vertex AI); frontier via AI Gateway (Claude, OpenAI) |
| Gateway | AI Gateway |
| RAG | AI Search (formerly AutoRAG) — hybrid vector + BM25 + rerank; Vectorize as the raw vector primitive |
| Eval / observability | Langfuse (OSS), Braintrust, PostHog LLM analytics |
| Security | AI Security for Apps (formerly Firewall for AI), AI Gateway DLP |
| Crawlers | AI Crawl Control, Firecrawl |
| Browser | Browser Run (formerly Browser Rendering), Playwright (CF Containers) |
| Agent (Workers) | CF Agents SDK |
| Agent (TypeScript) | LangGraph (TS), Mastra |
| Agent (Python) | PydanticAI, LangGraph |
| Agent (durable) | CF Workflows + (PydanticAI \| LangGraph); Temporal / Inngest off-edge |
| Agent (protocol) | MCP on Workers; A2A (agent-to-agent); Claude Managed Agents (hosted) |

### External Services

Shortlist for the minority of generic subdomains where buying still wins (`design-flow.md` § Subdomain Classification & Build-vs-Buy). Not a default menu — anything outside these rows is built or self-hosted in-repo. "Auth" is the protocol, implemented with an audited library, not a hosted identity vendor.

| Role | Options |
|---|---|
| Auth | OAuth2 + JWT |
| Social (global) | Google |
| Social (Korea) | Google, Kakao |
| Payments (global) | Stripe |
| Payments (Korea) | Toss Payments |
| Billing / metering | Stripe Billing (subscriptions), Orb / Lago (usage-based) |
| Email (transactional) | Resend |
| Email (notification) | Resend, CF Email Service **(beta)** |
| Errors | Sentry, OTel |
| Tracing + Logging | OTel, CF Workers Logpush |
| Analytics | PostHog |
| Feature flags | KV + PostHog |

---

## House Conventions

House instances of rules that live in the general files; they apply wherever this profile is adopted.

**Diagrams** — D2 in C4 notation, written as source directly in the doc; D2 classes give consistent styling (`person` for actors, `cylinder` for databases, `queue` for message brokers, dashed borders for system boundaries). If a D2 rendering tool/skill is installed, use it; otherwise leave the D2 source as-is, or fall back to Mermaid or ASCII. Which views to draw: `SKILL.md` § Writing Style.

**Fitness-function tooling** — the tools behind the checks in `design-flow.md` § Fitness Functions, per house language:

| Check | TypeScript | Rust | Python | Cadence |
|---|---|---|---|---|
| No circular dependencies | `madge --circular` | `cargo-modules` / `cargo-depgraph` | `pydeps --show-cycles` | Pre-commit + CI |
| Domain independence (import rules) | `eslint-plugin-boundaries` | Workspace crate boundaries (domain crate has no infra deps in `Cargo.toml`) | `import-linter` contracts | CI |
| Bundle / binary size | `size-limit`, `bundlesize` (frontend) | Binary size threshold (WASM) | — | CI |
| Dependency drift | `bun audit` | `cargo-deny` | `pip-audit` | CI |

Any language: response time — a k6 / autocannon / wrk smoke test with the p99 threshold from the ASR, post-deploy; dependency updates — Renovate/Dependabot policies.

**Observability** — the house pick is OTel + CF Workers Logpush, with no third-party logging vendor by default (the Errors and Tracing + Logging rows). The architectural rules live in `observability.md`.

**TanStack Start house taste** (explicit over magic, end-to-end types):
- **FSD layering** — route files are thin routing glue (loader, guard, head); page UI lives in `views/`; server functions live in the owning slice's `api/`; layers import only downward (`views` → `widgets` → `features` → `entities` → `shared`).
- **URL is first-class state** — filters, tabs, and pagination live in validated, typed search params, not client state, so views stay shareable and bookmarkable.
- **Every server function is a public endpoint** — the build exposes each as an HTTP-reachable RPC route, so validate input and authenticate, authorize (ownership, not just a session), and tenant-scope *inside* the function; route guards are navigation UX only. Only `VITE_`-prefixed env vars reach the client — all of them do — so secrets stay unprefixed and server-side.
