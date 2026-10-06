# Agent Architecture

**Layer:** system-level (protocols, durable execution, multi-agent orchestration, state management, infrastructure). For agent **design** (when an agent is the right shape vs a pipeline, agent evaluation, context engineering at the prompt layer), see `references/llm-app/agents.md`.

Architecture patterns, protocols, and infrastructure for LLM-powered autonomous agents. This reference is language-agnostic — it covers architectural decisions, not implementation details.

**Important**: The agent ecosystem evolves rapidly. This document covers **stable architectural patterns and emerging standards**. For specific framework comparisons and SDK features, verify current state via web search before committing.

---

## Table of Contents

1. [When to Use Agents vs. Pipelines](#1-when-to-use-agents-vs-pipelines)
2. [Agent Patterns](#2-agent-patterns)
3. [Agent Protocols & Standards](#3-agent-protocols--standards)
4. [Context Engineering](#4-context-engineering)
5. [State Management & Durable Execution](#5-state-management--durable-execution)
6. [Multi-Agent Systems](#6-multi-agent-systems)
7. [Evaluation & Observability](#7-evaluation--observability)
8. [Safety & Guardrails](#8-safety--guardrails)
9. [Decision Flowchart](#9-decision-flowchart)
10. [Anti-Patterns](#10-anti-patterns)

---

## 1. When to Use Agents vs. Pipelines

The workflow-vs-agent decision is **design discipline** — see `references/llm-app/agents.md` (and the shape table in `references/llm-app/guide.md`). The one-line rule: if you can draw the flowchart before running, build a workflow (cheaper, faster, debuggable); reach for an autonomous agent only when the *model* must choose the next step at runtime. Everything below assumes you've decided an agent is warranted and covers the **system-level** concerns of running one.

---

## 2. Agent Patterns

The pattern hierarchy — Augmented LLM → Prompt Chaining → Routing → Parallelization → Orchestrator-Workers → Evaluator-Optimizer → ReAct (plus Plan-and-Execute, Tool-Use-First, Agentic RAG, Sub-Agents) — is **design discipline**, owned by `references/llm-app/agents.md`. Start at the top of the ladder; move down only when a simpler pattern can't meet requirements. This file picks up at the infrastructure those patterns need: protocols (§3), durable state (§4-5), multi-agent orchestration (§6), and safety (§8).

---

## 3. Agent Protocols & Standards

### The Protocol Triangle

Three complementary protocols are converging as the standard stack for agent systems:

```
           MCP
      (Agent <-> Tools)
          /        \
         /          \
      A2A    <->    AG-UI
(Agent <-> Agent)  (Agent <-> User)
```

These three protocols have **different governance** (a common misconception is that one body owns all three):
- **MCP** was donated by Anthropic to the **Agentic AI Foundation (AAIF)**, a Linux Foundation directed fund formed Dec 2025 (alongside `goose` and `AGENTS.md`).
- **A2A** is a *separate, standalone* Linux Foundation project (the Agent2Agent Protocol Project, donated by Google in June 2025) — not part of AAIF.
- **AG-UI** is an open protocol created and maintained by **CopilotKit**, not under any foundation.

### MCP (Model Context Protocol)

**Scope**: Agent <-> Tools/Resources. "USB-C for AI."

**Core primitives**:
- **Tools** — Functions the agent can invoke (with JSON Schema input/output). Supports structured output via `outputSchema`.
- **Resources** — Data the agent can read (files, DB records, API responses)
- **Prompts** — Reusable prompt templates exposed by the server
- **Sampling** — Server can request the client's LLM to generate completions
- **Elicitation** — Server can request information from the user
- **Roots** — Client exposes the filesystem/URI boundaries the server may operate within

**Transport**:
- **stdio** — Local transport via JSON-RPC over stdin/stdout. For local tools.
- **Streamable HTTP** — Remote transport over HTTP with SSE for streaming.

**Auth**: OAuth 2.1 for HTTP transports. MCP servers act as OAuth Resource Servers.

### MCP as Product API

MCP is becoming a **product distribution channel**. By exposing your product's capabilities as an MCP server, AI agents can discover and use your product without custom integration code.

**Architecture implication**: Design your API surface with two consumers in mind:
1. **Human users** via your web/mobile UI
2. **AI agents** via MCP server

**Decision**: Expose MCP alongside (not instead of) your REST/GraphQL API. Both can share the same backend service layer.

### A2A (Agent-to-Agent Protocol)

**Scope**: Agent <-> Agent. Enables agents built by different vendors to discover, communicate, and collaborate.

**Key concepts**:
- **Agent Cards** — JSON metadata describing capabilities, skills, endpoints, and auth
- **Task lifecycle** — submitted -> working -> completed/failed. Supports long-running async tasks
- **Messages and Parts** — Agents exchange typed parts (text, files, structured data). Multimodal.

### AG-UI (Agent-User Interaction Protocol)

**Scope**: Agent <-> User. Defines how agents communicate with humans in real time.

**Key concepts**:
- Streams JSON events over a standard HTTP transport (SSE, or other streaming transports)
- Event types: text messages, tool calls, state snapshots/deltas, lifecycle signals

### How They Relate

| Protocol | Direction | Creator | Status |
|---|---|---|---|
| **MCP** | Agent <-> Tools (vertical) | Anthropic -> AAIF | Production |
| **A2A** | Agent <-> Agent (horizontal) | Google -> Linux Foundation (Agent2Agent Project) | Maturing |
| **AG-UI** | Agent <-> User (presentation) | CopilotKit | Emerging |

An agent uses MCP to access its tools, A2A to collaborate with peer agents, and AG-UI to communicate with users.

---

## 4. Context Engineering

Context engineering is the discipline of designing the full information environment an agent operates in — not just the prompt, but the schemas, retrieved data, memory, tool definitions, and conversation history that shape behavior.

**Key insight**: A well-structured context window has more impact on agent reliability than clever prompt phrasing.

*Reference: Anthropic, "Effective Context Engineering for AI Agents" (Sep 2025)*

### Memory Architectures

| Type | What It Stores | Persistence | Implementation |
|---|---|---|---|
| **Working Memory** | Current conversation, recent tool results | Session | Context window itself |
| **Short-Term Memory** | Recent interaction history | Session | In-memory buffer or Redis |
| **Long-Term Memory** | Factual knowledge, user preferences | Persistent | Vector store or knowledge graph |
| **Episodic Memory** | Past experiences, action outcomes | Persistent | Vectorized event logs with metadata |
| **Procedural Memory** | Learned workflows, reusable strategies | Persistent | Stored procedures, code modules |

**Design decisions**:
- What persists across turns vs. across sessions vs. across users?
- When to summarize vs. when to retrieve verbatim?
- How to handle contradictions between stored memory and new information?

### Context Window Management

| Strategy | When to Use |
|---|---|
| **Summarization** | Long conversations. Incremental beats retroactive. |
| **Sliding Window** | Fixed-size recent history. Simple but loses important context. |
| **RAG-Based** | Large knowledge bases. Dynamically fetch relevant chunks. |
| **Priority-Based** | Score context elements by relevance, include only high-signal items. |
| **Sub-Agent Delegation** | Offload sub-tasks to isolated agents to keep main context clean. |

### Tool Schema Design

Tool/function-schema design (naming, descriptions, input/output schemas, self-correcting error messages) is **design discipline** — see `references/llm-app/tool-use.md`. At the system level what matters is that tool schemas are validated at the trust boundary and scoped to the agent's permissions (§8).

---

## 5. State Management & Durable Execution

### Why This Matters

Agents can run for minutes to hours. Without state management, a crash means lost progress and wasted cost. Durable execution is becoming as important to agents as databases are to web applications.

### Checkpointing Patterns

| Pattern | How It Works | When to Use |
|---|---|---|
| **Database checkpointing** | Serialize state to DB after each step. Resume from last checkpoint on failure. | Default. Simple, no new infrastructure. |
| **Node-level (graph-based)** | State saved before/after each graph node. | When using graph-based orchestration. |
| **Event-history replay** | Record all events in durable log. Reconstruct state by replaying. | Complex workflows with exactly-once requirements. |
| **State snapshot + delta** | Capture snapshots with incremental deltas. | When you need automatic retries and crash-safe execution. |

### Durable Execution Platforms

For agents that run long enough to need crash recovery, search for current platform capabilities and integrations — this space evolves quickly. Common approaches:
- Deterministic workflow execution with event sourcing
- Event-driven harnesses decoupled from agent logic
- Lightweight runtimes with composable AI patterns and automatic recoverability

### Long-Running Agent Patterns

- **Heartbeat and progress reporting** — periodically signal alive-ness
- **Context compaction** — periodically summarize/compress to prevent window overflow
- **Sub-agent delegation** — spawn sub-agents for sub-tasks, keep main context clean
- **Idempotent tool calls** — retrying a tool call must not cause double-effects

### Error Recovery

- **Exponential backoff with jitter** for transient failures
- **Granularity matters**: tool-level retries -> step-level retries -> workflow-level restarts
- **Error context injection** — include the error in the next prompt so the agent adapts
- **Human escalation** — after N retries, hand off to a human

---

## 6. Multi-Agent Systems

### Core Orchestration Patterns

| Pattern | How It Works | Best For |
|---|---|---|
| **Supervisor** | Central orchestrator delegates to workers, consolidates results | Complex task decomposition |
| **Scatter-Gather** | Distribute independent sub-tasks in parallel, aggregate | Embarrassingly parallel work |
| **Pipeline** | Agents chained sequentially, output feeds into next | Ordered, dependent steps |
| **Hierarchical** | Multiple layers: strategic -> planning -> execution agents | Multi-dimensional problems |
| **Handoff** | Agent transfers control to specialized agent (no return) | Domain-specific expertise |

### Communication Patterns

| Pattern | How It Works | Trade-offs |
|---|---|---|
| **Shared State (Blackboard)** | Agents read/write to common knowledge base | Fast iteration, but contention risk |
| **Message Passing** | Explicit messages, sync or async | Flexible, but requires schema design |
| **A2A Protocol** | Standardized agent-to-agent via HTTP/JSON-RPC | Interoperable, but adds protocol overhead |

### When Multi-Agent vs. Single Agent?

**Favor single agent**:
- Task is straightforward or well-bounded
- Low latency is critical
- Debugging simplicity matters
- Cost sensitivity is high (multi-agent multiplies token costs)

**Favor multi-agent**:
- Task requires diverse expertise that would bloat a single context
- Context isolation is needed
- Parallel execution would significantly speed things up
- Security boundaries require separation

### The 17x Error Trap

Naive ("bag of agents") multi-agent systems amplify errors. Google DeepMind & MIT (Kim et al., "Towards a Science of Scaling Agent Systems," 2025) found unstructured/decentralized agent networks amplify a single agent's error by up to ~17.2x relative to a single-agent baseline, while centralized orchestration contains it to ~4.4x by acting as a circuit breaker.

Separately, serial chains compound failure multiplicatively (90%-reliable steps: 5 ≈ 59%, 10 ≈ 35%, 17 ≈ 17%, per 0.9^n — the ~17% here is a coincidence, unrelated to the 17.2x amplification figure). Mitigation:
- Structured orchestration over loose coupling
- Verification steps after critical actions
- Feedback loops for self-correction
- Reduce serial dependencies — parallelize where possible

---

## 7. Evaluation & Observability

### Evaluation (design — pointer)

Agent eval **metrics** (task completion, step efficiency, pass^k, trajectory eval) and **approaches** (offline golden sets, LLM-as-judge calibration, online A/B) are eval design — see `references/llm-app/evaluation.md`. The system-level half — what to emit and watch in production — is below.

### What to Trace

- Every LLM call (input/output tokens, latency, model, cost)
- Every tool call (parameters, result, latency, success/failure)
- Agent decision points (why this tool? what was the reasoning?)
- State transitions (what changed in working memory?)
- Human interventions (when and why did a human step in?)

### Production Monitoring

- Token usage and cost dashboards with budget alerts
- Quality metrics tracked over time for regression detection
- Safety violation alerts
- OpenTelemetry with GenAI semantic conventions for unified tracing

---

## 8. Safety & Guardrails

The design-level rails every agent loop needs (hard iteration cap, token and wall-clock budgets, scope checks) are in `references/llm-app/agents.md` § Safety rails, and the tool-authorization rules (authorize server-side from the authenticated context, confirm side-effecting tools, no arbitrary-query tool) in `references/llm-app/tool-use.md` § Security and § Common anti-patterns. This section covers the system-level controls around them.

### Human-in-the-Loop Spectrum

| Level | Description | Use When |
|---|---|---|
| **Full human control** | Agent suggests, human executes | Initial deployment, high-risk domain |
| **Human approval** | Agent proposes, waits for approval | Irreversible actions (payments, emails, deletes) |
| **Human oversight** | Agent acts, human notified, can intervene | Medium-risk, building trust |
| **Autonomous with audit** | Agent acts freely, actions logged for review | Low-risk, established trust |
| **Full autonomy** | Agent operates independently | Only after extensive validation |

**Key principle**: Irreversible actions require human approval until trust is established. The approval step should be **asynchronous** — persist agent state, notify human, resume via callback.

### Sandboxing & Isolation

From lightest to heaviest:
1. **Process isolation** — Separate OS process
2. **Docker containers** — Namespace isolation
3. **gVisor** — Syscall interception layer
4. **Micro-VMs (Firecracker/E2B)** — Lightweight hardware virtualization
5. **Confidential computing** — Hardware-level memory encryption

### Permission Models

- **Tool-level permissions** — which tools can this agent access?
- **Scope-limited tokens** — agent gets credentials that can only do X, Y, Z
- **Rate limiting** per agent/tool combination
- **Approval workflows** for high-risk operations
- **Agent identity** — agents need identities (not just user tokens) for audit and access control

### Input/Output Guardrails

Same layered defense pattern as general LLM systems — see `references/ai-architecture.md` § Guardrails & Safety. Agent-specific additions:

- **Tool call validation**: Verify tool parameters against schemas before execution. Reject calls that exceed the agent's permission scope.
- **Action audit trail**: Log every tool invocation with input, output, and the agent's reasoning.
- **Escalation triggers**: Define conditions that halt autonomous execution and require human review.

---

## 9. Decision Flowchart

```
Does the task need adaptive, multi-step behavior?
+-- NO -> Pipeline or prompt chaining (`references/llm-app/agents.md` § Workflows)
+-- YES -> Continue below

Can the steps be predetermined?
+-- YES -> Workflow orchestration (routing, parallel, chain)
+-- NO -> Agent with tool loop (ReAct or Plan-and-Execute)

Does the agent need to collaborate with other agents?
+-- YES -> Multi-agent with A2A protocol (Section 6)
+-- NO -> Single agent with MCP tools

Is the agent long-running (minutes+)?
+-- YES -> Add durable execution + checkpointing (Section 5)
+-- NO -> Stateless agent loop is fine

Does the agent take irreversible actions?
+-- YES -> Human-in-the-loop + sandboxing (Section 8)
+-- NO -> Autonomous with audit logging

Is this going to production?
+-- YES -> Add evaluation + observability + guardrails (Sections 7-8)
+-- NO -> Prototype freely, but plan for the above
```

---

## 10. Anti-Patterns

See also the general AI anti-patterns in `references/ai-architecture.md` § Anti-Patterns.

**Bag of Agents**: Throwing multiple agents at a problem without structured orchestration. Error amplification makes this worse than a single agent.

**Ignoring State Management**: Running long agent workflows without checkpointing. A crash 2 hours in means starting over.

**Autonomous Everything**: Granting agents full autonomy from day one. Start with human approval for high-risk actions, progressively automate as trust builds.

**Framework Lock-In**: Choosing an agent framework before understanding the architecture. The harness (infrastructure) matters more than the framework.

**Monolithic Context**: Stuffing everything into a single agent's context window instead of using sub-agents, RAG, or memory tiers.
