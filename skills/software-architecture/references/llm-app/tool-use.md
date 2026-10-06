# Tool Use / Function Calling

**Layer:** design-level (when tools are right, tool/schema design, the tool-calling loop, error handling). For tool/function-calling **system architecture** (tool gateways, MCP server deployment, agent protocols), see `references/ai-agents.md` § Tool Schema Design and § Agent Protocols.

Tool use lets the model call your functions during a conversation. Well-designed tools turn LLMs from talkers into doers — badly designed ones turn them into expensive random-function-call generators.

## Table of Contents

1. [When tools are right](#when-tools-are-right)
2. [Tool design principles](#tool-design-principles)
3. [The tool-calling loop](#the-tool-calling-loop)
4. [Error handling in tool results](#error-handling-in-tool-results)
5. [Parallel vs sequential tool calls](#parallel-vs-sequential-tool-calls)
6. [Streaming and tool use](#streaming-and-tool-use)
7. [Tool use vs structured output](#tool-use-vs-structured-output)
8. [MCP (Model Context Protocol) — when tools live outside your app](#mcp-model-context-protocol--when-tools-live-outside-your-app)
9. [Security: model-sourced inputs](#security-model-sourced-inputs)
10. [Common anti-patterns](#common-anti-patterns)

## When tools are right

Use tools when the model needs to:

- Fetch fresh data (search, database, APIs) that wasn't in training.
- Compute something the model is bad at (exact math, code execution, date arithmetic).
- Take actions with side effects (send email, update record, trigger workflow).
- Look things up in your specific system (user's orders, their calendar, internal docs).

Don't use tools for things the model can already do well (summarize text, classify, rewrite). A tool call is ~2 API calls of overhead and extra latency — skip it if a direct answer works.

## Tool design principles

**One tool, one job.** A tool called `user_management` that accepts an `action` parameter (`create`, `update`, `delete`) confuses the model. Split into `create_user`, `update_user`, `delete_user` — the model picks correctly more often, and the schemas stay simple.

**Name tools like functions, not features.** `search_knowledge_base(query)` beats `KnowledgeBase`. Names should suggest "verb + object."

**Describe when to use it, not what it is.** The `description` field is a trigger pattern:

- Bad: "This tool searches the knowledge base."
- Better: "Search internal product documentation. Use when the user asks about features, pricing, or how to do something in the product. Do NOT use for general knowledge questions — answer those directly."

The model picks tools by matching the user's intent against descriptions. Write descriptions as routing rules.

**Minimize parameters.** Every parameter is a decision the model has to make correctly. Optional parameters with sensible defaults beat required ones. Enums beat free-form strings. 3 parameters is manageable, 10 is a roll of the dice.

**Validate inputs server-side, always.** Even with strict schemas, assume the model will send malformed or hallucinated values eventually. Validate and return a clear error that the model can recover from.

## The tool-calling loop

A single "agent-less" tool use cycle looks like:

1. User sends message.
2. Model decides: respond directly, or call a tool.
3. If tool call: execute the tool, return result to model.
4. Model sees the tool result and either calls another tool or responds.
5. Repeat until model responds with final answer.

The loop terminates when the model stops calling tools. Most providers auto-handle this; you set `max_iterations` to prevent infinite loops (usually 5-10 is safe for task-level tools).

## Error handling in tool results

When a tool fails, what you return back to the model determines whether it recovers gracefully or panics.

**Bad:** Throwing an exception that the harness surfaces as "tool call failed."

**Better:** Return a structured error result that explains what happened and how to recover:

```json
{
  "error": "USER_NOT_FOUND",
  "message": "No user exists with id 'u_12345'.",
  "suggestion": "Use search_users to find the correct user id."
}
```

The model can read that and try again. A raw stack trace leaves it guessing.

## Parallel vs sequential tool calls

Many modern APIs (Anthropic, OpenAI) support parallel tool calls — the model emits multiple tool calls in one turn, you execute them concurrently, return all results together. Use this when:

- Tool calls are independent (fetching user + fetching their orders).
- Latency matters.

Don't fight it for sequential dependencies (fetch X, then use X to fetch Y) — the model handles that across turns.

## Streaming and tool use

Tool-use flows are harder to stream than pure text. The model produces partial tool-call JSON that isn't valid until complete, so you typically:

- Stream text portions to the user.
- Wait for tool-call blocks to complete before executing.
- Stream the model's next text response after tool results come back.

Most SDKs handle this abstraction — but if you're building a UX with "the AI is thinking / the AI is searching...", wire those states to the tool-call lifecycle, not to text deltas.

## Tool use vs structured output

These are different mechanisms with overlapping use cases.

**Structured output** (JSON mode, schema-constrained decoding) — the model's direct response is a structured object. One call, no tool. Use when you want a single structured answer.

- **OpenAI Structured Outputs** — strict JSON-Schema-enforced output, recommended over the older JSON mode (the request parameter differs between the Chat Completions and Responses APIs).
- **Anthropic** — native structured outputs enforce a strict JSON Schema on the response on current Claude models; tool-use (define a tool with the target schema and force the model to call it) remains a portable fallback and is still the right mechanism when the structured object *is* a tool call.
- **Local / OSS models** — `xgrammar`, `llguidance`, `outlines`, `guidance` enforce JSON Schema, regex, or context-free grammars at the token-sampling layer. Free correctness at the cost of some latency.

(Exact request/response shapes for each are SDK mechanics — see the `claude-api` skill for Anthropic, if available, or the provider's or multi-provider SDK's docs (e.g. the Vercel AI SDK for TypeScript). Verify the current structured-output API against provider docs; this surface changes often.)

Even with constrained decoding, **validate every output**. The schema can be satisfied while the *content* is wrong (right shape, wrong category).

**Tool use** — the model decides to call a function, and the function's return shape is a structured object. Use when the model might also respond directly, or might need to call multiple tools.

For "classify this ticket into a JSON schema", structured output is simpler. For "help the user, and sometimes classify tickets", tool use is correct.

## MCP (Model Context Protocol) — when tools live outside your app

MCP standardizes how external tool servers expose tools/resources/prompts to LLM hosts (Claude Desktop, Claude Code, Cursor, etc.). If your tools are reusable across multiple hosts, ship them as an MCP server instead of an in-app function registry.

When MCP is the right fit:
- The same tool will be called from multiple hosts (your app + Claude Desktop + Cursor)
- You want users to bring their own tool servers
- You're building a third-party integration to expose to LLM-host users

When in-app function calling is still right:
- Tools are tightly coupled to your app's auth, DB, and business logic
- You don't want third-party MCP servers in your trust boundary

**Security**: MCP server tool descriptions are part of the prompt context — treat untrusted MCP servers as a prompt-injection surface. See the security pass of a review-checklists capability (`review-checklists/references/security/llm-security.md` § MCP Server Security), if available.

## Security: model-sourced inputs

Tool calls driven by user prompts are a privilege escalation risk. The model can be tricked (via prompt injection) into calling tools it shouldn't. Rules:

- **Read-only tools are safer than write tools.** A `search_docs` misfire is annoying; a `delete_user` misfire is a ticket.
- **Gate destructive actions.** Confirm with the user before `delete_*`, `send_*`, `pay_*`. Don't let the model execute them autonomously based on untrusted input alone.
- **Authorize server-side.** Pass the user's auth context with the call; don't trust any user-id or permission the model puts in the parameters.
- **Rate-limit.** A runaway model calling `send_email` in a loop costs real money and angers real users.

See `references/llm-app/agents.md` for more on tool-use safety when tools are chained in autonomous loops.

## Common anti-patterns

**Tool descriptions that overlap.** Two tools with descriptions that could both match the same user intent. The model picks inconsistently. Write descriptions with explicit "use this when / don't use this for" to disambiguate.

**Tools that do too much.** A single `query(sql: string)` tool that lets the model write arbitrary SQL. Tempting, but it puts the entire safety burden on the model. Prefer a small number of curated tools with bounded parameters.

**Giving every function as a tool.** If you expose 40 tools, the model struggles to pick the right one and hallucinates tool names. Curate. Group under logical roles. Use agent hierarchies if you need scale (orchestrator agent picks a sub-agent; sub-agent has its own smaller toolset).

**No timeout on tool execution.** A slow tool blocks the whole conversation. Set per-tool timeouts (5-30s typical) and return a clear timeout error the model can handle.
