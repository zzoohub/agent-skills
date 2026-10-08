# React Composition Patterns

> Vendored from `vercel-labs/agent-skills` `composition-patterns` (MIT); the fork record and re-apply list are in `UPSTREAM.md`.

**Scope:** feature components with several call sites and state sources (a composer, an editor). Primitives follow SKILL.md's API table; a component with one call site needs neither.

The examples use React Native primitives and React 19 APIs (`use`, `<Context value>`, `ref` as a prop; React 18 equivalents in `../components.md` § React Versions); the patterns are the same with DOM elements. In every rule, memoize the provider's value unless the React Compiler is on, and in React Server Components apps export parts by name (`import * as Composer` keeps the dotted syntax), because dotting into a client object throws.

## Rules

| Rule | Read when |
|---|---|
| `architecture-avoid-boolean-props` | flags such as `isThread` or `isEditing` fork one component's behavior, or each use case should name what it renders (`ThreadComposer`, `EditMessageComposer`) |
| `architecture-compound-components` | consumers need to arrange a feature's parts themselves |
| `state-context-interface` | several state sources (local, store, server) must drive the same parts |
| `state-lift-state` | a sibling outside the frame needs the state (a preview, a dialog's submit button) |
