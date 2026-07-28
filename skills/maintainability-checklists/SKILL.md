---
name: maintainability-checklists
description: |
  Maintainability and design-quality checklists for pre-landing review — the
  "will this stay cheap to change" lens that tests, linters, and type-checkers
  are structurally blind to. Covers modularity, cohesion & coupling, abstraction
  fit, inheritance & interfaces, extensibility, state & side effects,
  error-handling design, readability/cognitive load, domain modeling,
  testability, and test quality.
  Use when: reviewing a diff before commit/PR for design smells, high coupling,
  low cohesion, leaky or wrong abstractions, hard-to-extend or hard-to-test
  code, business logic in the wrong layer, type-system escape hatches,
  feature-flag sprawl, or refactor-hostile tests. Complements
  security-checklists (OWASP) and correctness-checklists. Trigger on "code
  review", "maintainability", "refactor smell", "is this extensible", "tech
  debt", "design review", "god object", "fat controller", "coupling", "anemic
  model", "test quality", "DRY", "error handling design".
  Do NOT use for: security vulnerabilities (use security-checklists);
  correctness bugs that survive CI (use correctness-checklists); formatting,
  unused variables, or unreachable code (linters/formatters own
  those); behavioral correctness of deterministic logic (tests own that);
  reuse/simplification micro-cleanups (use /simplify or /code-review); or
  implementing the fixes.
---

# Maintainability Checklists

The review lens nothing else covers. Tests prove *behavior*; linters and type-checkers catch *mechanics*; `security-checklists` catches *exploits*; `correctness-checklists` catches the *survive-CI bugs*. None of them tell you whether the code will be **cheap to change in six months**. That is this skill.

## Scope guard — do NOT flag what tooling already owns

| Owned by | Don't review here |
|---|---|
| Formatter (prettier/black/rustfmt) | formatting, import order |
| Linter (eslint/ruff/clippy/`go vet`) | unused vars/imports, unreachable code, simple dead code |
| Type-checker (tsc strict/mypy/rustc) | within-language type errors, simple nullability |
| Tests | behavioral correctness of deterministic logic |
| `correctness-checklists` | races, idempotency, cache invalidation, partial-failure, boundary defects — and missing *runtime* validation (unchecked responses/`res.ok`, unvalidated input): that a check is absent is a correctness finding, not an error-handling-design one |
| A dedicated cleanup pass (e.g. `/simplify` in Claude Code), if available | reuse / efficiency / micro-simplification cleanups |

This skill is for **staff-level design judgment** and the **survive-prod bugs** those miss. Pick sections by what the diff changes.

**Language instantiation.** The sections below are language-agnostic categories. For the concrete per-language spellings — what reads as `any` in TypeScript reads as `unsafe`/`Rc<RefCell<T>>` sprawl in Rust — read `references/typescript.md` (TS/JS diffs) or `references/rust.md` (Rust diffs) when they exist and the diff is in that language. Other languages: instantiate by analogy — the judgment, the gates, and the output contract don't change.

---

## Modularity, Cohesion & Coupling

- **Low cohesion** — a unit does several unrelated things; its responsibility needs an "and" to describe. Split by reason-to-change (SRP).
- **High coupling** — a module reaches into another's internals (fields, private helpers, concrete types) instead of a stable interface. Change one → the other breaks.
- **Feature envy** — a method uses another object's data more than its own; the behavior lives in the wrong place. Move it to the data.
- **Shotgun surgery / change amplification** — one logical change forces edits across many files. The strongest signal a module boundary is drawn wrong.
- **Inappropriate intimacy / circular dependency** — two modules know each other's details; neither can be understood, changed, or tested in isolation.
- **God object / manager class** — one unit accumulates everything and becomes a gravity well for every future change.
- **Dependency direction violation** — domain/policy code imports infrastructure or framework (ORM entities in business logic, HTTP types in the domain). If the project carries an import-boundary CI rule (dependency-cruiser, import-linter, workspace crates), point at it; hand-review this only where no such guard exists.
- **Business logic in the transport layer** — domain rules (pricing, eligibility, state transitions) written inline in an HTTP handler / controller / resolver. The second consumer — worker, CLI, cron, the next endpoint — has to copy-paste them, and they can't be tested without standing up HTTP. Extract into a function the handler *calls*; a handler that stays a thin adapter (parse → call → serialize) is the healthy shape, not a finding.
- **Vendor SDK types spread through the codebase** — a third-party client's request/response types (Stripe, Twilio, an LLM SDK) used as parameters and returns across internal modules; an API version bump or provider swap now edits half the codebase. Wrap the vendor behind an adapter and map into your own types at the boundary (anti-corruption layer).
- **Shallow module sprawl** — layers and wrappers that add interface without adding functionality: a service that forwards to a repository that forwards to the ORM, a one-line helper per operation. Each pass-through adds a name, a file, and an indirection every reader (and every agent context load) must carry, while hiding nothing. Depth test: is the implementation meaningfully more complex than the interface? If not, inline it. This is the counterweight to god-object splitting — splitting by *count* instead of by *reason-to-change* trades one smell for N.

## Abstraction Fit

- **Leaky abstraction** — callers must know the implementation to use it right (must call `init()` first, must check a flag the abstraction should own).
- **Wrong / premature abstraction** — an interface generalized for cases that don't exist yet; indirection that adds cognitive cost with no payoff. Rule of three: duplicate twice before extracting.
- **Missing abstraction** — the same concept open-coded in many places, or a domain concept that has no name in the code.
- **DRY applied to coincidental similarity** — two code paths merged because they *look* alike today, though they change for different reasons (admin vs customer flow, two documents' validation); the shared helper sprouts mode flags and forks until every change to one caller risks the other. Duplication is cheaper than the wrong abstraction — let them stay separate.
- **Wrong altitude** — high-level policy and low-level mechanism mixed in one function (orchestration interleaved with byte-twiddling).

## Inheritance & Interfaces

- **Inheritance for code reuse** — subclassing to borrow helpers (base-class-as-toolbox), or behavior smeared across a deep hierarchy so no level can be understood alone; every base change risks every descendant (fragile base). Prefer composition: inject the helper, keep hierarchies for true is-a substitution.
- **Refused bequest** — a subclass stubs, no-ops, or throws on inherited methods; the type claims a contract it doesn't honor, and code written against the base breaks on this subtype (LSP). Split the hierarchy, or compose instead.
- **Fat interface** — one wide interface forces every implementer to stub methods it can't support and every test double to fake methods it never uses. Split by consumer role (interface segregation).

## Extensibility

- **Open/closed violation** — adding a new case means editing a `switch`/`if-else` in N places instead of adding one type/strategy. Every new variant re-touches old code.
- **Hardcoded assumptions** — single tenant/region/currency/limit baked into logic that will obviously need to vary.
- **Boolean/flag parameters that fork behavior** — `doThing(true, false)`; usually two functions crammed into one.
- **Feature flag forked at every use site** — the same flag checked in N modules instead of selecting an implementation once at a composition point; each flag doubles the state space everywhere it's read, and dead flags accrete because no single place owns removal. Fork once (strategy/DI at the edge), and give every flag a removal owner.

## State & Side Effects

- **Side effect behind an innocent name** — a `get`/`is`/`find`/`check` that also writes (`getAccount` creates missing accounts, `isValid` mutates state): callers can't reason about calling it twice, skipping it, or reordering it. Separate the command from the query, or name the write honestly (`ensureAccount`).
- **Temporal coupling** — methods that must be called in a specific undocumented order (`configure()` before `run()`), where the wrong order compiles fine and fails at runtime. Make the order structural: the constructor/factory takes what it needs; each step returns what the next consumes.
- **Internal mutable state leaked** — returning the internal array/map by reference, or mutating a parameter the caller still owns; distant code now edits shared structure, and every consumer is invisibly coupled to every other. Return copies or read-only views; treat inputs as borrowed.

## Error-Handling Design

The *design* of failure paths. (A failure that loses data or a write is `correctness-checklists`; here the cost is the humans debugging and extending it.) Instantiate per language: in exception languages the smells below read as throw-vs-null; in Result/Either languages the same smells appear as `unwrap()`/panic on recoverable paths and context-free stringly errors (`anyhow`-style) crossing a library boundary.

- **Inconsistent error contract** — sibling functions mix throw / return-`null` / error-code / silent-default, so every caller must memorize each function's private convention; the caller that guesses wrong ships a bug. Pick one style per layer; convert at the boundary.
- **Context-free failure** — `throw new Error("invalid input")` with no which-entity / what-value / what-limit; every production incident costs an extra deploy just to learn what happened. Errors carry identifiers and the violated expectation.
- **Wrap-and-bury** — every layer catches and rethrows with a vaguer message, dropping the original error/stack; the 3am reader gets "operation failed" five levels from the cause. Catch where you can act — usually one boundary handler — rethrow with the cause attached, let the rest propagate.

## Readability & Cognitive Load

- **Deep nesting / arrow code** — prefer guard clauses and early returns (suspect nesting ≥3 levels).
- **Long parameter lists** — group into a value object; order-dependent args invite silent mistakes (suspect ≥4 params).
- **Naming that lies or hides** — `data`, `tmp`, `manager`, `process()`; names that no longer match what the code does.
- **Magic values** — unexplained literals; intent buried in a number.
- **Comment/code drift** — comments describing behavior the code no longer has (no tool catches this). Same failure in agent context files (CLAUDE.md / AGENTS.md): stale commands or structure notes mislead every future agent session, which starts context-empty and trusts them.
- **Load-bearing hack with no why** — a workaround (retry, sleep, magic header, odd call order, disabled option) with no comment naming what breaks without it; the next editor "cleans it up" and reintroduces the bug it was holding back. One line: what breaks, and a link to the issue.

## Domain Modeling

- **Primitive obsession** — raw `string`/`map`/`int` where a domain type belongs (`Email`, `Money`, `UserId`); validation scattered instead of enforced once at the type boundary.
- **Stringly-typed** — branching on or passing magic strings where an enum/union belongs.
- **Anemic model** — data and the rules that govern it drift into separate places, so invariants aren't enforced where the data lives.
- **Illegal states representable** — the type permits combinations the domain forbids (`status: 'error'` with `data` set; independent `isLoading`/`error`/`result` fields), so every consumer re-checks invariants and eventually one forgets. Model as a union/sum type so the invalid combinations can't be constructed.
- **One concept, many names** — the same value called `userId` / `ownerId` / `accountRef` across modules (or one name meaning different things), so every reader must stop and check whether they differ. One name per concept, everywhere it appears (ubiquitous language).
- **Type-system escape hatch at a boundary** — `any`, `as` casts, `# type: ignore`, `interface{}`, unchecked `unsafe`/`transmute` on parameters, returns, or parsed input. Legal to the checker — which is why only review catches it — but it switches the language's guarantees off for everything downstream. Parse/validate into a real type at the edge; keep interior signatures honest.

## Testability

- **Hidden dependencies** — a unit reaches for globals/singletons or `new`s its own collaborators, so nothing can be substituted in a test.
- **Untestable time / randomness / IO** — `Date.now()`, RNG, direct network calls not injected → tests become flaky or impossible.
- **No seam** — you must stand up the whole world to exercise one rule. If it's hard to test, the design is telling you something.

## Test Quality (meta — do the tests actually protect us?)

Coverage % says lines ran, not that they're guarded. Tests are code too; review them.

- **Asserts status, not side effects** — "401 on bad token" passes even if the handler wrote to the DB before returning.
- **Tests the mock, not the code** — so much mocking that only the mock runs.
- **Missing error/negative-path coverage** — happy path tested; 500 / timeout / partial-failure untested.
- **Hollow assertions** — `expect(result).toBeDefined()` where the real contract goes unchecked.
- **Structure-coupled tests** — asserting internal call order, private methods, or exact collaborator interactions where only the outcome is the contract; behavior-preserving refactors now break the suite, so the tests punish improvement. Assert outcomes through the public seam — verify an interaction only when the interaction *is* the contract ("sends exactly one email").
- **Snapshot blob as the only assertion** — a huge auto-generated snapshot nobody reads, re-approved on every diff: a change detector, not a test. Assert the specific fields that carry the contract; snapshot only what a human will actually re-review.
- **Interdependent tests** — tests share mutated fixtures/state and pass only in suite order; no test can run alone, and adding one breaks a neighbor. Each test builds its own world.

> For the bugs that survive green CI — races, idempotency, cache invalidation, partial failure, boundary defects — use the **correctness-checklists** skill (Pass 1, blocking). This skill stays on design.

---

## Before You Report — Is It a Finding?

Design review dies by nitpick: the fastest way to get this checklist ignored is an opinion war on every PR. Gate every candidate finding:

1. **Name the cost, or drop it** — the Cost line must name a concrete future change that gets more expensive or riskier because of this code. "Not clean" / "I'd have written it differently" is noise, not a finding.
2. **Check the codebase's own convention first** — if the diff follows the established local pattern, it is not a finding against *this PR*; consistency is itself a maintainability asset. Raise pattern-level objections once, as a separate codebase-wide proposal, not per-diff. A convention excuses *style*, not *defects*: an established smell elsewhere in the codebase does not grandfather a new instance of the same smell.
3. **Framework idiom is not a smell — and neither is the declared paradigm** — judge code against its framework's grain: an ActiveRecord model isn't an anemic-model finding; a server route colocated with its data fetch isn't a layering violation; a CLI script printing to stdout isn't a logging smell. Likewise check the project's declared architecture style (docs/arch/system.md, the README, AGENTS.md) before applying items that assume one: a vertical-slice codebase colocating handler + logic + data access per feature is not a fat-handler finding, and a functional-core module of pure functions over plain data is not an anemic model. Flag *fighting* the declared style, not *using* it.
4. **Scale the bar to blast radius** — a one-off script or internal tool doesn't need the architecture of the module every feature imports; the same shortcut that's fine in `scripts/` is a finding in `core/`. Say why this code's position justifies the standard you're applying.
5. **Rule of three cuts both ways** — don't demand an abstraction at the second occurrence, and don't bless the fifth copy either. A single-implementation interface that exists as a test seam is a seam, not premature abstraction.
6. **Findings live in the diff** — pre-existing smells the diff didn't introduce or worsen are context notes for the author, not findings against the PR.

The gates kill findings you *can't ground* — they never excuse the ones you can. If the Cost line is fillable with a concrete future change, the finding survives every gate: report it and state the tension ("follows the house pattern, but each new instance re-pays the same cost"). Naming a smell and then waiving it through a gate is the failure mode this section exists to prevent, not an application of it.

---

## Review Output Contract

```markdown
- **[Smell / Issue Name]** — `file:line`
  - Smell: [name the design smell, one line]
  - Cost: [what future change gets expensive, or which change becomes risky]
  - Fix: [specific — "extract X behind interface Y", not "improve the design"]
```

These are Pass 2 (informational). This is the non-blocking layer within the reviewer gate — security/correctness findings block, these inform (unless project policy escalates them). Don't block a PR on them unless project policy says so — but raise high coupling and missing abstractions early, because they get exponentially more expensive to fix the longer they live.
