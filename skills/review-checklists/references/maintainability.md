# Maintainability Checklists (Pass 2 — informational)

The "will this stay cheap to change" catalog. Gates, ranking by cost of reversal, the three-finding cap and the output shape: `SKILL.md`. For the TS/JS or Rust spelling of an item, also read `references/maintainability/typescript.md` or `references/maintainability/rust.md`; other languages, by analogy.

Three more gates apply to this catalog:
- **Framework idiom and the declared paradigm are not smells** — an ActiveRecord model isn't anemic; a vertical slice the architecture doc declares (default `docs/arch/system.md`; caller may redirect) isn't a fat handler. Flag *fighting* the declared style, not *using* it.
- **Scale the bar to blast radius** — a shortcut fine in `scripts/` is a finding in `core/`.
- **Rule of three cuts both ways** — don't demand an abstraction at the second occurrence or bless the fifth copy; a single-implementation interface kept as a test seam is a seam.

**Classic smells** are listed under their headings in one line each: you know them, so report one only with a Cost line naming the change it blocks, best shown by the diff itself (one logical change that had to edit N modules).

---

## Contracts & Persisted Formats

Rank these first: once a client, stored row or other service depends on a shape, changing it takes a migration or a deprecation (breakage during a rolling deploy is correctness).

- **Internals in a public contract** — a response, event or SDK type that mirrors table columns, ORM entities or internal enums: every refactor becomes a breaking change. Map to a contract type at the edge.
- **Persisted data bound to code layout** — enum ordinals or display strings stored instead of stable codes; an internal class serialized natively (pickle, Java serialization) into a column, cache or queue; an event with no schema version. A reorder or rename silently rewrites history. Store stable names; version the envelope.
- *Not a finding*: an internal endpoint with one consumer deployed in lockstep.

## Modularity, Cohesion & Coupling

- **Classic smells** (low cohesion, coupling to another module's internals, feature envy, shotgun surgery, circular dependencies, a god object): only with a Cost line.
- **Dependency direction** — domain code importing infrastructure or framework types (ORM entities in business rules, HTTP types in the domain). If CI already enforces import boundaries, it owns this.
- **Business logic in the transport layer** — pricing, eligibility or state transitions inline in a handler, controller or resolver: the next consumer (worker, CLI, cron) copies them, and they can't be tested without HTTP. A thin handler (parse → call → serialize) is the healthy shape, not a finding.
- **Vendor SDK types across internal modules** — a provider's request and response types (payments, messaging, an LLM SDK) in internal signatures: a version bump or a provider swap edits half the codebase. Map to your own types in one adapter.
- **Shallow module sprawl** — pass-through layers (service → repository → ORM) that add indirection but hide nothing: if the implementation is no more complex than its interface, inline it. Splitting by count rather than by reason to change trades one god object for N shallow modules.

## Abstraction Fit

- **Classic smells** (a leaky abstraction callers must understand to use, an interface generalized for cases that don't exist, policy and mechanism interleaved in one function): only with a Cost line.
- **Missing abstraction** — one concept open-coded where the copies must change together (a rule already fixed in one copy and not the others), or a domain concept with no name in the code.
- **DRY across coincidental similarity** — two paths merged because they look alike today but change for different reasons (admin vs customer flow): the shared helper sprouts mode flags until every change to one caller risks the other. Keep them separate.

## Inheritance & Interfaces

- **Classic smells** (inheritance to borrow helpers, a hierarchy where every base change risks every descendant, a subtype that stubs or throws on inherited methods, a wide interface every implementer stubs): only with a Cost line. The fix is composition, or an interface split by consumer role.

## Extensibility

- **Dispatch copied at N sites** — the same `switch` on a variant in N places with no exhaustiveness check: a new variant silently misses some. Centralize it, or let the compiler find every site (an exhaustive `match`, a `never` default). *Not a finding*: one exhaustive `match` where operations are added more often than variants.
- **Hardcoded assumptions** — one tenant, region, currency or limit baked into logic when the codebase or roadmap already varies it; otherwise YAGNI.
- **Flag parameters that fork behavior** — `doThing(true, false)`: two functions in one signature.
- **Feature flag forked at every use site** — one flag read in N modules instead of choosing an implementation once at a composition point: it doubles the state space wherever it is read, and nobody owns its removal. Fork once; give each flag a removal owner.

## State & Side Effects

- **Side effect behind an innocent name** — a `get`, `is`, `find` or `check` that also writes (`getAccount` creates missing accounts): callers can't reason about calling it twice or skipping it. Separate the command from the query, or name the write (`ensureAccount`).
- **Classic smells** (a required call order the compiler doesn't enforce, an internal collection returned by reference, a caller's argument mutated): only with a Cost line.

## Error-Handling Design

The cost falls on whoever debugs and extends failure paths; a failure that loses data or a write is correctness.

- **Inconsistent error contract** — sibling functions mix throwing, `null`, error codes and silent defaults: every caller must memorize each one, and the one that guesses wrong ships a bug. One style per layer; convert at the boundary.
- **Context-free or buried failure** — `throw new Error("invalid input")` with no entity, value or limit, or each layer rethrowing something vaguer with the cause dropped: the next incident needs a deploy just to learn what happened. Attach identifiers and the cause; catch only where you can act.

## Readability & Cognitive Load

Linters own nesting depth, parameter counts, magic numbers and placeholder names; don't report them here.

- **Names that lie** — a name that no longer matches what the code does, or one name meaning two things.
- **Comment and doc drift** — comments, READMEs or agent context files (CLAUDE.md, AGENTS.md) that still describe behavior, commands or structure this diff changed: every later reader, human or agent, trusts them.
- **Load-bearing hack with no why** — a retry, sleep, odd call order or disabled option with no note on what breaks without it: the next editor removes it and the bug returns. One line: what breaks, and the issue link.

## Domain Modeling

- **Classic smells** (primitive obsession, branching on magic strings, one concept under several names, rules living apart from the data they govern): only with a Cost line.
- **Illegal states representable** — the type permits combinations the domain forbids (`status: 'error'` with `data` set; independent `isLoading`, `error` and `result`): every consumer re-checks, and one eventually forgets. Model a union or sum type.
- **Type escape hatch at a boundary** — `any`, `as`, `# type: ignore`, `interface{}` or unchecked `unsafe` on parameters, returns or parsed input switches the checker off downstream. Parse into a real type at the edge.

## Testability

- **Classic smells** (hidden dependencies on globals or self-constructed collaborators; time, randomness or IO not injected; no seam short of standing up the world): only when the Cost names the test this diff couldn't write or made flaky.

## Test Quality (meta — do the tests actually protect us?)

Review tests as code. A bug on an untested path is a correctness finding whose Fix names the test; don't report the gap again here.

- **Passes on revert** — would any test fail if the change were reverted? A race or idempotency fix needs a duplicate- or concurrent-delivery test; a test that mocks the guard the fix relies on can never fail.
- **Asserts status, not effects** — "401 on bad token" passes even if the handler wrote to the DB first.
- **Structure-coupled tests** — internal call order or private methods asserted where only the outcome is the contract, so behavior-preserving refactors break the suite. Verify an interaction only when it is the contract ("sends exactly one email").
- **Classic smells** (tests that exercise only the mock, hollow assertions like `toBeDefined()`, happy path only, a snapshot blob as the sole assertion, tests that pass only in suite order): only with a Cost line.
