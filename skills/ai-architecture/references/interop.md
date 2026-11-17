# Interop

Decides what crosses the edges of an agent system and by which protocol: tools offered to or taken from other parties, peer agents, the user interface, payments. Read when a tool server, another organization's agent, an agent-driven interface or a purchase is in scope. Revision dates and maturity of each protocol are in `landscape.md`.

Four seams: agent ↔ tools, agent ↔ agent, agent ↔ user interface, and someone else's assistant ↔ your product. Decide per seam whether interoperability is needed at all. Capabilities stay internal ports; each protocol is a thin adapter at the edge, pinned to a dated revision, and these specifications revise about twice a year (`landscape.md`).

- **In-app tool calls by default.** Tools coupled to your authorization and data stay inside your trust boundary. Adopt a tool protocol when hosts you do not control must use your tools, or users must plug in their own.
- **A remote tool server is an ordinary stateless service.** Any request can land on any instance. State across calls lives behind opaque, expiring handles the server mints and binds to the authenticated caller; holding a handle is never authentication. Nothing depends on a stream surviving: long work is your own durable job (create, status, cancel, result) that the caller polls, and since cancellation is best-effort, operations are idempotent.
- **The tool surface is a published contract**: names, schemas, error classes and their order are versioned. Other parties' tool descriptions are untrusted input.
- **Each server is a resource server.** It checks the token's audience on every request, never accepts or passes through a token minted for another service, and uses its own credentials downstream.
- **Tool or peer agent?** A tool when the caller wants a bounded, structured result. A peer agent over a network protocol only across an ownership or trust boundary; inside one deployable, a call or a queue.
- **Agent-to-UI protocols are serializers at the edge.** Own the event schema. The agent emits declarative UI that the client renders from an allow-listed component catalog; HTML supplied by a server runs sandboxed.
- **Other people's assistants are becoming callers of your product.** Operating systems and browsers let their assistant invoke functions an app or site declares, and fall back to driving the interface when none are declared. Publish a narrow, typed, versioned set of functions that are idempotent and safe to retry, treat the assistant as a distinct principal acting for the user, confirm irreversible actions with the user, and re-authorize on the server; an action taken by an agent must be distinguishable from one taken by the person.
- **Agents that buy things** touch four separate concerns, each behind its own port: checkout, the evidence of what the user authorized (a signed mandate bound to amounts, merchants and expiry), the payment rail, and proof to the merchant of which agent is calling. Enforce the mandate outside the model and store the signed evidence with the order. A payment is the canonical irreversible action.

## Red flags

- 🔴 A tool server that accepts a token minted for another service, or treats a handle as proof of identity.
- 🟠 A protocol's request types used inside the domain instead of behind an adapter, or an adapter with no pinned revision.
- 🟠 Long work held open on a stream with no durable job behind it.
- 🟠 An agent that can pay with no mandate bound to amount, merchant and expiry, or with the evidence stored nowhere.
- 🟡 A network protocol between components in one codebase.
