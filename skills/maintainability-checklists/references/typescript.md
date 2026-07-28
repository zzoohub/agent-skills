# TypeScript / JavaScript instantiation

The per-language spellings of the SKILL.md smells. Same judgment, same Before-You-Report gates,
same output contract — this file only tells you what each category *looks like* in TS/JS.

## Modularity, Cohesion & Coupling

- **Barrel-file coupling** — `index.ts` re-export webs make every module import "the package", hiding real dependencies and breeding import cycles (`import { a } from ".."`); cycles surface as `undefined` at runtime, not compile errors. Import from concrete modules; keep barrels for the public package edge only.
- **`utils.ts` gravity well** — the junk-drawer module every feature imports; any change rebuilds/retests the world. Split by domain, not by "misc".
- **Module-scope singleton as hidden coupling** — `export const db = new Pool(...)` imported everywhere couples every consumer to construction-at-import-time (breaks tests, ordering-sensitive). Construct in an entrypoint, pass down.

## Abstraction Fit

- **Type-level cleverness** — conditional/mapped/recursive types where a plain union or overload would do; the type machinery becomes its own maintenance burden and error messages turn unreadable. Clever types are code too — apply the same cost test.
- **Premature generic** — `function process<T extends Record<string, unknown>>(...)` with exactly one instantiation. Write the concrete version; generalize on the third caller.

## Inheritance & Interfaces

- **Class inheritance for reuse** — `extends BaseService` to borrow `log`/`retry` helpers; prefer composition (import the function, inject the collaborator). JS classes add `this`-binding traps on top of the usual fragile-base cost.
- **Optional-method interfaces** — `interface Handler { onError?(...): void }` as a fat-interface dodge: every caller now needs runtime existence checks. Split the interface by role instead.

## Extensibility

- **String-keyed dispatch scattered** — `switch (type)` on the same string union in N files; adding a variant means finding them all (exhaustiveness helps only where a `never` check exists). Centralize dispatch or use a handler map/registry.

## State & Side Effects

- **`export let` / module-scope mutable state** — mutated by importers or per request; invisible coupling between every consumer (and a correctness race under concurrency — hand that part to correctness-checklists).
- **In-place mutation of shared references** — `array.sort()`, `splice`, object spread-then-mutate on values received from elsewhere; React props/state mutated directly. Use `toSorted`/copies; treat inputs as borrowed.
- **CQS in TS clothing** — a getter (`get total()`) or `isX()`/`getX()` that lazily writes, caches to a DB, or fires analytics. Property access should never have observable side effects.

## Error-Handling Design

- **Three contracts in one module** — sibling functions that throw, return `null`, and return `{ ok, error }`; plus the async twin: some reject, some resolve to `undefined`. One style per layer; convert at the boundary.
- **`catch (err)` rethrow that drops the cause** — `throw new Error("failed")` loses stack and context; use `new Error(msg, { cause: err })` (ES2022) and keep one boundary handler.
- **Swallowing rejections** — `.catch(() => {})`, empty `catch {}`, or a fire-and-forget promise (the data-loss half belongs to correctness-checklists; the design half — no error strategy — is yours).
- **Throwing non-`Error` values** — `throw "bad input"` / `throw { code: 400 }`; no stack, breaks `instanceof` handling downstream.

## Domain Modeling

- **Discriminated union is the fix** — `status: string` + independent optional fields → model as `{ kind: "done"; result: R } | { kind: "error"; error: E }` and let exhaustiveness checking (`never` default arm) enforce handling.
- **Branded ids** — `type UserId = string & { __brand: "UserId" }` (or a zod brand) where raw `string` ids cross-assign silently.
- **Escape hatches** — `any`, `as` (especially `as unknown as T`), non-null `!`, `@ts-ignore` / `@ts-expect-error` without a reason comment, and raw `JSON.parse` handed to typed code. Parse at the edge with a schema (zod/valibot) into a real type.

## Testability

- **`vi.mock` / `jest.mock` as a way of life** — module-mocking every import is the test suite telling you the code has no seams; each mock couples the test to the module graph. Inject the collaborator instead, mock at the process edge only.

## Test Quality

- **`mock.calls` order assertions** on internal collaborators (structure-coupled), **`toMatchSnapshot()`** as the only assertion, **`toBeDefined()`/`toBeTruthy()`** hollow checks, and **shared `beforeAll` state** mutated across `it` blocks (suite-order dependence). The SKILL.md items apply verbatim; these are their vitest/jest spellings.
