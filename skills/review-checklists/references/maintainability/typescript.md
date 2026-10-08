# TypeScript / JavaScript instantiation

TS/JS spellings of `references/maintainability.md` (gates and output: `SKILL.md`). Not findings: `as const` and `satisfies` (neither is a cast), `@ts-expect-error` with a reason comment, a `never` default enforcing exhaustiveness, and `!` right after a check the compiler can't follow (`map.has(k)`, then `map.get(k)!`).

## Modules & state
- **Barrel-file coupling** — `index.ts` re-export webs hide dependencies and breed import cycles, which surface at runtime as `undefined` or a TDZ `ReferenceError`. Import from concrete modules; barrels only at the package's public edge.
- **Construction at import time** — `export const db = new Pool(...)` couples every importer to construction order, and tests can't substitute it. Construct in the entry point; pass it down.
- **Module-scope mutable state** — `export let`, or a module-level object mutated by importers or per request: invisible coupling between consumers (the cross-request race is correctness).
- **In-place mutation of borrowed values** — `sort()`, `reverse()` or `splice()` on arrays received from elsewhere, or props and state mutated directly. Use `toSorted()` and copies.

## Types & interfaces
- **Type-level cleverness** — conditional, mapped or recursive types where a union or an overload would do: unreadable errors, and a second program to maintain.
- **Optional-method interfaces** — `onError?(...)` as a fat-interface dodge forces an existence check at every call. Split the interface by role.
- **Escape hatches** — `any`, `as` (especially `as unknown as T`), `!` on external data, `@ts-ignore`, raw `JSON.parse` handed to typed code. Parse at the edge with a schema validator.

## Errors
- **Rethrow that drops the cause** — `throw new Error("failed")` inside a `catch`; use `new Error(msg, { cause: err })`.
- **Swallowed rejections** — `.catch(() => {})`, an empty `catch {}`, a floating promise: no error strategy (the lost write is correctness).

## Tests
- **Module mocking as a way of life** — `vi.mock` or `jest.mock` on every import means no seams; inject collaborators, mock only at the process edge.
