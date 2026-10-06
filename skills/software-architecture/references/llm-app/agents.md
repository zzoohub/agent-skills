# Agent Patterns

**Layer:** design-level (when to use an agent, what defines one, evaluation, context engineering). For agent **system architecture** (protocols, durable execution, multi-agent orchestration), see `references/ai-agents.md`.

An "agent" is an LLM that runs in a loop, calling tools and deciding its next action until a goal is reached. Agents are powerful and expensive. Most LLM apps don't need one.

## Table of Contents

1. [What makes something an agent](#what-makes-something-an-agent)
2. [When agents are right](#when-agents-are-right)
3. [Workflows: the shapes before you reach for an agent](#workflows-the-shapes-before-you-reach-for-an-agent)
4. [The basic agent loop](#the-basic-agent-loop)
5. [Context management](#context-management)
6. [Memory across sessions](#memory-across-sessions)
7. [Planning vs reactive](#planning-vs-reactive)
8. [Multi-agent architectures](#multi-agent-architectures)
9. [Safety rails](#safety-rails)
10. [Common failure modes](#common-failure-modes)
11. [Evaluating agents](#evaluating-agents)

## What makes something an agent

The defining property: the model chooses what to do next at runtime. Not the code, not the developer, not a predefined workflow — the model decides each step based on what it has seen so far.

Non-agents:
- A single prompt + structured output = not an agent (no choice of next step).
- A fixed chain (retrieve → summarize → classify) = not an agent (steps are predefined).
- A single tool-use turn = borderline (one decision: call tool or answer).

Agents:
- Loop with dynamic tool selection: the model picks tool A, sees result, picks tool B or answers, repeat.
- Plan-then-execute: the model writes a plan, executes it, revises if needed.
- Multi-agent: specialized agents hand tasks off, orchestrated by a coordinator agent.

## When agents are right

Agents earn their complexity when:

- The task requires **unknown steps.** Research tasks, debugging, open-ended investigation.
- **Tool selection is combinatorial.** Many tools, and which to call depends on intermediate results.
- The problem has **variable depth.** Some inputs finish in one step, others need ten.
- **Recovery from errors matters.** The model can observe a failure and try something else.

They're the wrong tool when:

- The task has a known, fixed pipeline. Just write the pipeline.
- Latency and cost matter. Agents are multiplicatively more expensive than single-prompt approaches.
- Reliability is critical. Agents are probabilistic at every step — compound probability kills reliability.

A rule of thumb: if you can draw the flowchart of steps before running, you don't need an agent.

## Workflows: the shapes before you reach for an agent

If you *can* draw the flowchart, you want a **workflow** (also called an agentic pipeline): LLM calls wired through steps you fixed in advance. The control flow lives in your code, not in the model's runtime choices, so workflows are cheaper, lower-latency, more testable, and far easier to debug than agents. Most "AI features" are workflows, not agents. The core patterns:

- **Prompt chaining.** Decompose a task into a fixed sequence of steps, each LLM call working on the previous output (e.g., outline → draft → polish). Add a programmatic gate between steps to catch failures early. Use when the task splits cleanly into predictable subtasks.
- **Routing.** A first classification step sends the input to one of several specialized downstream prompts/models (e.g., refund vs technical vs sales → a handler tuned for each). Use when inputs fall into distinct categories that are better handled separately than by one do-everything prompt.
- **Parallelization.** Run independent subtasks concurrently and aggregate — either *sectioning* (split work into independent pieces) or *voting* (run the same task N times and take a majority/consensus). Use for speed, or to raise confidence on a hard judgment.
- **Orchestrator-workers.** A central LLM call breaks a task into subtasks, hands each to a worker call, and synthesizes the results. The subtasks aren't known up front, but the orchestration *structure* is. This is the boundary case between workflow and agent.
- **Evaluator-optimizer.** One call produces, a second evaluates against criteria and returns feedback; loop until it passes (or hits a cap). Use when you have clear evaluation criteria and iteration measurably improves quality (translation, code that must pass tests, copy against a brief).

**Workflow vs agent.** A workflow has a control flow you can draw before running; an agent decides its own next step at runtime. Always try to express the task as a workflow first — reach for an agent only when the path genuinely can't be predetermined (unknown number of steps, or tool choice that depends on intermediate results you can't anticipate). The patterns compose: an agent may *contain* workflow steps, and a workflow step may call an agent.

For the system-level view of these patterns (durable execution, multi-agent orchestration infrastructure, protocols), see `references/ai-agents.md`.

## The basic agent loop

```
while not done:
    model_response = call_model(context + history)
    if model_response.is_final_answer:
        return model_response.text
    tool_result = execute(model_response.tool_call)
    history.append(model_response, tool_result)
    if iterations > max_iterations:
        raise TimeoutError
```

Almost every agent framework (LangChain, LangGraph, Anthropic's agent loops, custom code) reduces to this. The details matter, but the shape is universal.

## Context management

Agents accumulate context fast. A 10-turn agent with long tool outputs can easily exceed 100k tokens. Without careful context management, agents get slow, expensive, and confused (the "lost in the middle" problem applies hard).

**Strategies:**

- **Summarize old turns.** After N turns, compress the history to a running summary.
- **Prune tool outputs.** Keep the tool result that informed the next decision; drop the rest.
- **Externalize state.** Write intermediate results to a scratchpad (file, DB) and pass only references in context.
- **Task-scoped context.** When delegating to a sub-agent, pass only what it needs — not the full history.

Most agent frameworks do some of this automatically. Verify what yours does before assuming.

## Memory across sessions

Context management (above) handles a single run. Chatbots, copilots, and long-lived agents also need **memory that persists across runs**: user preferences, prior decisions, facts learned in earlier sessions. Design decisions:

- **What to remember.** Don't persist whole transcripts. Extract durable facts (preferences, entities, commitments) and store those; raw history bloats context and ages badly.
- **When to write.** End-of-session summarization, or explicit "remember this" signals. Writing on every turn is expensive and noisy.
- **How to recall.** Retrieve relevant memories into context at the start of a run — often via the same embedding/retrieval machinery as RAG (see `references/llm-app/rag.md`) — not by dumping everything.
- **Scoping and privacy.** Memory is per-user (or per-org) state — never let one user's memory leak into another's context. Treat it as regulated data if it holds anything sensitive.

This is the design-level view. For memory *architectures* (working/episodic/semantic stores, durable execution, state backends), see `references/ai-agents.md` § Memory Architectures.

## Planning vs reactive

Two broad styles of agent:

**Reactive (ReAct-style).** Model decides one step at a time based on current state. Simple, flexible, but can meander. Each turn is independent; no explicit plan.

**Planning (Plan-and-Execute).** Model first writes a plan, then executes each step. Can observe the plan diverging and replan. More structured, fewer wasted steps, but planning adds overhead and can fail early if the plan is wrong.

**Hybrid.** Plan at start, reactive within steps, replan when stuck. This is how most strong agent systems work in practice.

Start with reactive for simple tasks. Add planning when you see the agent taking redundant or looping actions.

## Multi-agent architectures

When one agent can't handle everything, patterns:

**Orchestrator + workers.** A coordinator agent delegates specialized subtasks to worker agents (each with its own tool subset). The orchestrator holds the top-level goal; workers do focused work and return results.

**Peer agents.** Multiple agents with different specialties collaborate. Harder to coordinate; best for simulation-like setups (negotiation, debate).

**Pipeline of agents.** Each agent is a stage (researcher → analyst → writer). More like a fixed pipeline than a true multi-agent system, but often simpler and better.

Multi-agent systems multiply the cost and failure surface. Pick the simplest that works.

## Safety rails

Autonomous agents are the highest-risk LLM pattern. Things you must wire in:

- **Iteration cap.** Hard limit on loop iterations. No exceptions.
- **Time budget.** Kill if total wall-clock exceeds threshold.
- **Token budget.** Kill if cumulative token use exceeds threshold.
- **Tool authorization.** Destructive tools (`send_*`, `delete_*`, `pay_*`) require explicit user approval or a separate sign-off step.
- **Scope boundaries.** If an agent starts taking actions clearly outside its mandate, abort. Detect via pre-execution checks on tool inputs.
- **Observability.** Log every tool call, every model turn, every decision. Debuggability is how you survive agent failures in production.

## Common failure modes

**Loops.** Agent calls the same tool with the same (or slightly different) inputs repeatedly. Detect loops; break out and escalate to human.

**Drift.** Agent forgets the original goal. Mitigation: re-inject the goal into context periodically, or have a separate verifier check progress.

**Over-trust of tool outputs.** Agent treats a stale API result or search hit as ground truth. Tools should return confidence or timestamps when relevant; prompts should include skepticism.

**Quiet failures.** A tool returns an error message as a string, the agent treats it as valid data, produces confident output. Return errors in a structured shape (see `references/llm-app/tool-use.md`) so the agent recognizes them.

**Unbounded cost.** No iteration limit, no token budget, no monitoring. A bug lets the agent run for hours on a single request. This one happens constantly — wire limits before the first production run.

## Evaluating agents

Much harder than evaluating single-shot models. You need to eval:

- **Task success rate.** Did the agent achieve the goal?
- **Trajectory quality.** Did it take a reasonable path? (sometimes it succeeds accidentally)
- **Cost and latency per task.** How many steps, how many tokens?
- **Safety.** Did it stay within scope? Any tool misuse?

Metric definitions — pass^k vs pass@k reliability, step efficiency, trajectory scoring — live in `references/llm-app/evaluation.md` § Agent evals. Agent evaluation often requires trace analysis (not just final output comparison) — budget for that.
