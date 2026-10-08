# Upstream: composition-patterns

Vendored from [`vercel-labs/agent-skills` → `composition-patterns`](https://github.com/vercel-labs/agent-skills/tree/main/skills/composition-patterns) (MIT) on 2026-06-04 (commit `f85be53` in this repo), minus Vercel-infrastructure content; formerly the standalone `composition-patterns` skill.

**Frozen fork.** Never re-clone over these files. Port substantive upstream changes by hand, then re-apply the local changes:
- deleted `state-decouple-implementation` (a duplicate of `state-context-interface`) and one of `state-context-interface`'s two provider-boundary examples (`state-lift-state` keeps the other);
- deleted `react19-no-forwardref` (`../components.md` § React Versions covers React 19 and its React 18 equivalents) and `patterns-children-over-render-props` (`../components.md` § Compound Parts states the rule and its break);
- merged `patterns-explicit-variants` into `architecture-avoid-boolean-props`;
- `architecture-compound-components` exports parts by name; context refs are typed `RefObject<T | null>`;
- commodity examples and closing summaries cut to a line or less: `architecture-compound-components`' render-prop example, `state-context-interface`'s second provider, usage block and duplicate `ComposerInput`, `state-lift-state`'s `useEffect`-sync and ref-read examples;
- `guide.md` states the corrections that apply to every rule (memoized provider values; named exports in React Server Components apps).
