# Orchestration

Decides who controls the flow of an AI feature, code or a model, and what surrounds it: workflows, graphs, pipelines, agent loops, tools, multiple agents, and runs that survive a crash. Protocols at the edges live in `interop.md`; authority and containment in `security.md`; budgets and caps in `production.md`.

## The ladder

The axis is **who decides the next step**. Take the lowest rung that passes the seed tasks and record why each rung below was not enough.

| Rung | Shape | Next step chosen by | Climb when |
|---|---|---|---|
| 0 | Code | code | the step needs judgment over open-ended input |
| 1 | Typed decision (`models.md`) | code, on a typed answer | the answer space is open |
| 2 | One generative call, with retrieval or examples | — | it fails the seed tasks as one call; if it passes, stop |
| 3 | **Workflow**: a fixed path through several calls | code | the path has cycles, waits or branches that must be resumed and audited |
| 4 | **Graph**: an explicit state machine over typed state | code, at each edge | the steps cannot be drawn before running |
| 5 | **Agent loop**: a model with tools | the model | one agent demonstrably fails and multi-agent admission holds |
| 6 | Multiple agents | models, under an orchestrator | — |

- **If you can draw the flowchart before running, build it.** A workflow or graph is cheaper, faster and far easier to debug than an agent. *Break when* the path is unknown: explore with an agent in a sandbox, then compile the discovered path into a workflow.
- **Two shapes dominate production.** For business processes, a deterministic skeleton with agentic leaves: a workflow or graph owns sequencing, approvals and budgets, and a node that needs open-ended work runs a bounded agent loop. For open-ended work such as coding or research, one agent loop in a sandbox, working from files, with the gates (tests, review, budgets) outside the loop.
- **The model proposes, code disposes.** At any rung the loop never executes a proposal itself: code decides to execute, pause for approval, reject or stop on budget, and every effect passes a policy check outside the model.

## Workflows

Five building blocks; compose them, and keep each call's task narrow enough to evaluate alone.

| Pattern | Use when | Watch for |
|---|---|---|
| **Chain**: each call consumes the last one's output | The task decomposes into fixed stages | Errors compound: validate between stages |
| **Route**: classify, then dispatch to a specialized path | Inputs fall into distinct kinds | The router is a decision; give it the decision tier and a none/other path |
| **Parallel**: fan out and aggregate, or run one task several times and vote | Independent subtasks, or confidence through agreement | Spend and concurrency caps; an aggregator that validates |
| **Orchestrator-workers**: one call plans subtasks, code dispatches them | Subtasks depend on the input but are independent of each other | The plan is untrusted output: bound its width and depth |
| **Evaluator loop**: generate, grade, revise | A clear criterion exists that a grader can check | A bounded number of rounds; a grader validated per `evals.md`, not the producer grading itself |

## Graphs

A graph is a workflow whose state, nodes and edges are explicit: typed state, nodes that are code or a model call, edges that are code. It pays for itself when the flow has **cycles**, **durable waits** (a human approval, an external callback, a timer), **checkpoints** to resume from, or **branches that must be auditable**. It is overhead when a one-page loop does the job.

- **State is a schema you own**, not a transcript: the fields each node reads and writes, versioned, small enough to checkpoint at every edge.
- **Every cycle has a bound** (iterations, tokens, money, wall clock) and an exit that is not "the model said it was done".
- **Human interrupts are edges**, with the exact parameters shown and a timeout that blocks.
- **Keep the graph definition static per run.** A graph the model can restructure mid-run is an agent with extra steps and no verifiable trace.
- **Durability sits below the framework**: a graph library gives structure, a durable-execution runtime gives survival across process death. Decide each separately (the software-architecture capability's durable-execution rules, if available).

## Pipelines

Offline and batch AI (ingestion, enrichment, classification backfills, embedding, eval runs) is a data pipeline with a model in a stage. It is the cheapest, most reliable shape whenever the answer is not needed in the request.

- **Precompute what can be precomputed**; the online path then reads a stored answer.
- **Stages are idempotent**, keyed by input hash plus the release unit (model, prompt, schema versions), so a replay or a model change reprocesses exactly what it must, and outputs are versioned, not overwritten.
- **Use the discounted batch tier** where the deadline allows, with a job budget instead of per-request caps.
- **A batch tier usually has its own quota**, separate from the synchronous limits: bulk work there leaves interactive headroom untouched.
- **The batch window is a target, not a guarantee.** A batch can end partly done or expire with nothing: reconcile by request id, resubmit the remainder, and leave slack before your own deadline.
- **A bad record goes to a dead-letter path** with its reason; a sample of each run goes to review; output validity and cost per item are tracked per run.
- **A model upgrade is a backfill decision**: reprocess everything, new items only, or neither, recorded with its cost.

## Agents

An agent is a model plus a **harness**: the loop, model access, tools, context policy, permissions and sandbox, sub-agents and extensions. Most of an agent's reliability is in the harness.

- **For each failure mode, name the guide that prevents it** (instruction, tool constraint, template, example) **and the sensor that detects it**. Prefer computational sensors on every step (schema validation, tests, invariant checks); use a model grader only for semantic properties, and only once validated. When the agent is wrong, what tells it, how fast, how deterministically?
- **Keep a scaffold register.** Every harness component (a planner, an evaluator loop, a forced decomposition, a context reset) encodes an assumption about what the model cannot do alone, and a heavy harness can cost many times a plain loop. Record the weakness each one covers, the eval that shows it, and re-test it at every model change; delete what no longer moves the outcome. Convert any instruction that can be checked into a check.
- **Own the loop, build on a coding agent's runtime, or rent a managed one.** A managed agent runtime sells sandboxes, session storage and durable runs: someone else's pager. Adopt one when it replaces machinery you would otherwise build and operate, and record in an ADR what it fixes: data retention (hosted loops are often outside zero-retention terms), where sessions live, the session length cap, the models it supports, and how sessions export. Keep your own session log as the exit. Write the loop yourself when it is short, or when you need control of context policy and permissions. Either way the prompts, tools and procedures are still yours to own, and you record which behaviors are designed and which are a framework's defaults.
- **Design the outer loop.** The agent runs the inner loop; an outer loop of triggers, budgets, independent checks, evidence logs and people directs and corrects it. Name the signal that says the system is degrading and who acts on it. A loop that improves the harness may propose changes; it never edits its own grader, acceptance criteria or permissions, and a person chooses which proposals ship.
- **The harness's own control decisions** (a risk check on each proposed tool call, per-turn screening, narrowing the tool list, stop or continue) go to the decision tier. Gates fail closed, sit in front of server-side authorization and never replace it.

### Tools

- **Task-shaped, few, disjoint.** One tool per agent task, not per API endpoint. Each description says when to use it and when not. Constrain arguments (enums, typed identifiers, bounded ranges) so whole classes of mistakes are impossible. One tool multiplexed by an "action" parameter blurs selection; one free-form query or shell tool puts the whole safety burden on the model.
- **Outputs spend the context budget**: concise by default, paginated, truncated with a hint on how to narrow. Tool output is untrusted input.
- **Definitions spend it too.** When tool definitions crowd the context or overlap, load them on demand behind a small always-loaded core before splitting the work across agents.
- **Errors return as errors, recoverable**: a code, a message and a suggested fix, never a string the agent can mistake for data. Step reliability multiplies down a chain: 90% per step is 59% over five.
- **Code as the action layer.** When a task fans out over many items, chains dependent calls or moves bulky intermediates, let the model write a program that a sandboxed runtime executes, returning only aggregates. Generated code passes the same permission gates as direct tool calls. *Break when* every intermediate result should inform judgment.
- **Procedures as files.** Reusable know-how (a workflow, a quality bar, a checklist) lives in versioned instruction files loaded on demand, not in orchestration code. An on-demand file is often never loaded: what every task needs goes in a short always-loaded index, and each procedure file gets two evals, whether it is invoked when it should be and whether the task still passes without it. Few and small beats a library. They are prompt input and sometimes executable: admit them like dependencies, and revisit them at each model change.
- **Prefer a structured tool to driving a GUI** where one exists: cheaper, faster and easier to permission. Where none exists, computer use has become workable on short, bounded tasks, while long ones still fail more often than not: run it in an isolated session, where speed is not critical, and keep a person's confirmation on consequential actions.

## Multiple agents

Default: one agent, with sub-agents used only to isolate context; they read, search or review and return condensed results, and the gain counts only if the orchestrator's context actually shrinks. **Topology follows the shape of the task.** In published measurements, every multi-agent variant did worse than one agent on sequential work, a coordinator helped substantially on work that splits into parallel parts, and agents with no coordinator multiplied each other's errors. Multi-agent runs also cost several times the tokens. Admit several agents only when **all** hold:

- a hard boundary exists (security isolation, separately owned domains), or the work splits into independent breadth-first branches that exceed one context window;
- the token multiplier is budgeted and compared against a token-matched single agent;
- the gain shows on your own eval, and a measured verifier can tell good worker output from bad;
- exactly one agent, or code, writes each artifact: parallelize reading, serialize writing;
- an orchestrator or aggregator validates worker output before merge.

Then: roles in a hierarchy (planner, workers, judge), never peers coordinating through shared locks or a shared store. Every delegation carries a brief: objective, output format, sources and tools, boundaries. A reviewing agent starts without the producer's context. Escalation to a stronger model fires on an outside, objective trigger, never on the cheaper model's own judgment of its work. When the right handler is predictable from the input, dispatch in code. Role names never justify an agent; a role that maps to a real permission difference is a security split.

## Runs

- **Separate the loop, the executors and the session log.** The log is the source of truth, the loop is stateless, executors (sandboxes, browsers, workers) are disposable, and credentials stay outside executors. What is lost if the executor dies mid-task, or the loop process does? *Break when* a sub-minute request needs no persistence.
- **Durable runs.** Model and tool calls are non-deterministic steps whose results are persisted; replay re-reads them and never re-invokes. A side effect may run again on resume, so it carries an idempotency key. An in-flight run finishes on the code, prompts, tool schemas and model it started with.
- **Recovery escalates** tool → step → run under one retry budget, never nested; past the budget the run hands off to a person.
- **Long-horizon work** keeps its plan, progress log and acceptance checklist in durable files, starts each session by reading them, and works one verifiable unit at a time. If this run is killed now, can a fresh agent resume from the files alone? Whether to compact a long context or reset it and hand off through those files depends on the model: test both at each model change.
- **"Done" is verified state**, checked against acceptance criteria fixed before the work began and kept outside the agent's write scope, by something other than the producer: a deterministic check first, a separate grader with no shared context second. A test the agent can rewrite proves nothing. A self-check before exit still helps; it is not the verification.
- **Background agents are jobs, not chats.** A trigger starts a durable run with explicit stop conditions (a goal check by an independent grader, plus token and time budgets) that ends with an artifact and a report. Goal loops without fast deterministic checks converge on plausible junk.
- **Oversight mechanics**: approval is a durable wait resumed by callback, not polling; interrupt works in one step at any point; an activity ledger records every tool call with inputs, outputs, decision and actor.

## Red flags

- 🔴 The loop executes whatever the model proposes, or one free-form tool carries the whole safety burden.
- 🟠 An agent where a drawn flowchart would do; a graph where a one-page loop would do.
- 🟠 A cycle with no bound, or an exit condition that is the model's own claim.
- 🟠 Multi-agent justified by role names, with no token-matched single-agent baseline, or with shared mutable state.
- 🟠 Run state only in an executor's memory or a provider's server-side conversation.
- 🟠 A batch stage that overwrites its outputs, so a model change cannot be compared or rolled back.
- 🟡 A framework silently owning context policy or permissions.
