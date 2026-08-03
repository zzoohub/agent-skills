# Pre-vetted House Stack

This is not a neutral catalog of technology options — it is a **curated house stack** built around Cloudflare Workers/Containers, GCP (Cloud Run, Cloud SQL, BigQuery), Supabase for Postgres, and a short list of proven external services. Choices reflect operational familiarity, regional constraints (Korea), and cost discipline.

This file is **opinionated and deliberately non-portable** — it encodes one shop's procurement, not universal guidance. On another runtime or org, treat it as a worked example, not a mandate.

**When to use these**: Default to the options below. They require no additional justification.

**When to deviate**: A choice outside this list requires an ADR in `docs/arch/adr/` that explicitly documents:
1. Why the house option was insufficient (specific capability gap, not "I prefer X")
2. What the deviation costs — operational burden, new runtime, extra billing surface
3. Revisit condition — when should we reconsider going back to the house option?

Deviation is fine when justified. Unjustified deviation is tech debt.

**Maturity tags**: items tagged **(beta)** / **(RC)** are pre-GA — fine as defaults, but a production-critical dependency on one should be a conscious choice, not an accident. Prefer the inline GA fallback when the guarantee matters.

**Agentic operability**: this stack is built and operated primarily by AI agents, so selections also weigh three properties — a first-class local dev loop (`wrangler dev`, emulators, `bun test`) an agent can iterate against; typed SDKs and declarative config an agent can read, edit, and diff (files, not dashboard clicks); and failures observable from the CLI (logs/errors reachable without a browser). The IaC-first rows (OpenTofu, Wrangler, GitHub Actions) are load-bearing for this, not conveniences — a dashboard-only service would need an ADR arguing why losing agent operability is worth it.

**Cloud split — read first**: Cloudflare and GCP are *not* interchangeable co-equals; the relationship is **hub-and-spoke**. Default to **Cloudflare** for the edge / serverless / agent fabric and the global front door; reach for **GCP** for regional heavy compute (Cloud Run GPUs, Cloud SQL, BigQuery, Pub/Sub) and the **Korea data-residency anchor** (`asia-northeast3`). Workers VPC + Hyperdrive stitch the two into one private network (Workers in front, Cloud SQL behind). When a row lists both, the CF option is the primary and the GCP option is the heavy-or-Korea trigger.

## Table of Contents

1. [Language & Runtime](#language--runtime)
2. [Framework](#framework)
3. [Infrastructure](#infrastructure)
4. [Data](#data)
5. [AI](#ai)
6. [External Services](#external-services)

---

## Language & Runtime

| Role | Choice |
|---|---|
| Language | TypeScript, Rust, Python |
| JS runtime / toolchain | **Bun** (runtime, package manager, bundler, test) |
| Python toolchain | **uv** (env, dependency resolution, lock) |

Go is **deliberately excluded** — Rust covers the performance/CLI niche, TypeScript covers services. Add Go only via an ADR if a team lacks the Rust depth for stateless Container/Cloud Run services.

---

## Framework

| Role | Options |
|---|---|
| Server (Workers) | Hono, workers-rs **(WIP — reserve for wasm-on-Workers)** |
| Server (Container) | Axum, FastAPI |
| Frontend | TanStack Start **(RC — pin exact versions)** (React or Solid), Next.js |
| Mobile | React Native (Expo) + Expo Router + EAS |
| Desktop | Tauri |
| CLI | Rust |
| Game | Godot, Bevy **(pre-1.0)** |
| Data Pipeline | Cloudflare Pipelines **(beta)**, Cloud Dataflow, dbt (Core v2 / Fusion engine) |

---

## Infrastructure

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

---

## Data

| Role | Options |
|---|---|
| Postgres (global) | Cloud SQL + Hyperdrive |
| Postgres (Korea) | Supabase + Hyperdrive, Cloud SQL |
| SQLite | D1 (read replication **beta**), Durable Objects (SQLite storage) |
| Cache (eventual) | KV |
| Cache (strong) | Upstash Redis (Valkey if self-managed) |
| Queue | CF Queues, Cloud Tasks |
| Streaming | Cloudflare Pipelines **(beta)** (-> R2 / Iceberg), Cloud Pub/Sub |
| Objects | R2 |
| Analytics / DW | BigQuery, Pipelines + R2 SQL (ClickHouse if self-hosted / cost-controlled) |
| Vector | Vectorize **(beta — no BM25/keyword; small corpora only)**, pgvector |
| Search (full-text / hybrid) | Postgres FTS, Typesense, Meilisearch |
| Images | CF Images |
| Video | CF Stream + Media Transformations |

---

## AI

| Role | Options |
|---|---|
| LLM inference | Workers AI, Gemini Enterprise Agent Platform (formerly Vertex AI); frontier via AI Gateway (Claude, OpenAI) |
| Gateway | AI Gateway |
| RAG | AI Search (formerly AutoRAG) — hybrid vector + BM25 + rerank; Vectorize **(beta)** as the raw vector primitive |
| Eval / observability | Langfuse (OSS), Braintrust, PostHog LLM analytics |
| Security | AI Security for Apps (formerly Firewall for AI), AI Gateway DLP |
| Crawlers | AI Crawl Control, Firecrawl |
| Browser | Browser Run (formerly Browser Rendering), Playwright (CF Containers) |
| Agent (Workers) | CF Agents SDK |
| Agent (TypeScript) | LangGraph (TS), Mastra |
| Agent (Python) | PydanticAI, LangGraph |
| Agent (durable) | CF Workflows + (PydanticAI \| LangGraph); Temporal / Inngest off-edge |
| Agent (protocol) | MCP on Workers; A2A (agent-to-agent); Claude Managed Agents (hosted) |

---

## External Services

Shortlist for the minority of generic subdomains where buying still wins (`design-flow.md` § Subdomain Classification). Not a default menu — anything outside these rows is built or self-hosted in-repo. "Auth" is the protocol, implemented with an audited library, not a hosted identity vendor.

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
