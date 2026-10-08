---
name: react-best-practices
description: |
  Build, review and fix React web code (Next.js App Router, TanStack Start, Vite): correctness first, performance by evidence. Covers data and state placement, Effects, hydration, mutations, the server boundary of Server Functions/Actions and createServerFn (validation, auth, tenant scoping, public env vars), waterfalls, bundle size, re-renders and INP.
  Use for "hydration mismatch", "too many re-renders", "useEffect", "Server Action", "slow page", "bundle too big".
  Do NOT use for: tokens, theming, motion or component APIs (design-system); route or view transitions (react-view-transitions); React Three Fiber (web3d); React Native (react-native-skills); backend services (hexagonal-backend).
license: MIT
source: https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices
---

# React Best Practices

> Fork of [`vercel-labs/agent-skills` → `react-best-practices`](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) (MIT), scrubbed of Vercel-infrastructure coupling and frozen: update policy in `UPSTREAM.md`.

Siblings, if available: i18n (locale logic); review-checklists (general pre-landing review).

## Frame

Settle these from the repo first; ask only what it can't answer, in one batch, else state the default you assumed. Budgets size the write-up, never the checks.

- **Job.** *Build:* placement first (where each part runs, where its data and state live). *Fix:* reproduce (a failing test where one fits), then rank the candidate causes by cost, each tied to the symptom by mechanism (measured, else the Symptom index prior × how often the path runs), and fix from the top; a requested technique ("add `useMemo`") is a symptom report. *Upgrade:* one version or flag per step, codemods first. *Review:* touched server entry points, then correctness, then performance.
- **Solve the outcome.** A cause or needed part outside the named file (a parent's unstable props, an outbox row's worker, a write's missing invalidation): fix it, or hand it off with what, where and the check that proves it.
- **Defaults when unanswered:** data scale, the most the source returns (else 10× the fixture); route and device, the top-traffic route on mid-tier Android at 4× CPU throttling; a mutation's callers and invariants, tenant members by role, all or nothing, a repeat is a no-op.
- **Stack facts that flip advice:** React version; framework, router, RSC; the React Compiler as configured (Next `reactCompiler` or the Babel plugin; `compilationMode`) and the `eslint-plugin-react-hooks` preset; Next `cacheComponents`; installed data, state and validation libraries; runtime (Node, serverless, Workers). Check APIs in the version-matched docs (Next 16.2+: `node_modules/next/dist/docs/`), and installed `next`, `react-server-dom-*` and TanStack Start against current security advisories (`npm audit`, GitHub advisories), rated by exposure under Severity. A house profile the project adopted (software-architecture's `references/house-stack.md`, if available) applies on top.
- **Depth.** A component or small fix: `package.json`, the touched files, where their inputs come from and who consumes their output; Performance's evidence gate always, its measured steps only if something is slow. A route or app audit: all of it.
- **Done.** *Build or fix:* each async region has loading, empty and retryable error states; no hydration or key warnings; the reproducing test passes. *Performance:* LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1 at p75, or a measured gain (TTFB, route JS, commit time), on the target route and device.

## Server boundary (Next.js and TanStack Start)

- **Every server entry point is a public endpoint.** A Server Function (`'use server'`, Server Actions included) takes direct POSTs; a TanStack Start `createServerFn` is an HTTP RPC route. Inside each handler: authenticate (the actor comes from the session, never from input), validate input with a runtime schema, load with tenant scope (`where: { id, orgId }`; foreign ids get the same not-found), then authorize on the loaded record (role and ownership). Rate-limit the ones that send, charge or enumerate. Order, code and tests: `rules/server-auth-actions.md`.
- **Middleware/proxy, route guards (`beforeLoad`), layout checks and hidden UI are UX only.** They decide what renders, not who may call the endpoint.
- **No request- or user-scoped data in mutable module scope:** concurrent requests share it (`rules/server-no-shared-module-state.md`).
- **Only public-prefixed env vars reach the client, and all of them do:** `NEXT_PUBLIC_` (inlined at build); in TanStack Start, `VITE_`, or `PUBLIC_` with Rsbuild. TanStack Start loaders also run in the browser, so DB access goes in a server function.
- **Return only what the client may see.** RSC props, Server Function results, loader data and TanStack Start's thrown server-function errors all reach the client: send minimal DTOs (`rules/server-serialization.md`) and generic errors; log details on the server.
- **Patch level is part of the boundary:** the RSC runtime has shipped an unauthenticated RCE, exploitable without Server Functions, and repeated DoS fixes.

## Write-time defaults

Apply these without measuring; deviate only where a *Break* says.

- **Own the lines you rewrite:** fix their Blocker and High defects and settle their semantics before optimizing (what a filter matches, how a sort compares types, units, locales and ties, which time zone a rendered value uses: `rules/js-hot-paths.md`); disclose behavior changes, and flag defects elsewhere with `file:line`.
- **Data loads where the route loads:** a Server Component or route loader, never a `'use server'` function (one call at a time, uncached); in an SPA, the router's loader or the installed query library; failing those, an Effect that ignores stale responses. Cache a slow read that everyone or a tenant shares at that scope, keyed by the session's tenant id, invalidated by the write (`rules/server-cache-cross-request.md`); streaming only hides it. *Break:* browser-only sources.
- **One home per state:** shareable state in validated search params, server data in its cache, ephemeral UI in local state; derive the rest during render. No props mirrored into state (reset with `key`), no mutation (`toSorted`, `with`, spread), the updater form when the next state depends on the last.
- **`'use client'` on the smallest interactive leaf,** with server content passed as `children`. *Break:* interaction-dense subtrees (editors, canvases).
- **Effects only synchronize with external systems** (`rules/rerender-derived-state-no-effect.md`). Never remove Strict Mode to hide a double run; add the missing cleanup.
- **The first client render equals the server render** (`rules/rendering-hydration-no-flicker.md`).
- **Mutations:** a form action or Server Function through `useActionState`, or the installed query library's mutation. Return expected failures as values, with the submitted fields (not passwords) for `defaultValue`: React resets an uncontrolled form once its action resolves, even with an error value. Show pending until the server confirms; `useOptimistic` only for reversible updates that rarely fail. Creates and charges are idempotent on the server; a disabled button is not protection. Invalidate before returning; a side effect that must happen goes in an outbox row in the write's transaction, shipped with its worker (`rules/server-after-nonblocking.md`).
- **Next `cacheComponents` on:** a cached shell with request-time holes. Shared reads go in `'use cache'`, request values passed as arguments; each remaining request-time read (`cookies()`, `headers()`, `searchParams`, uncached I/O) goes in the smallest `<Suspense>`, which the build otherwise flags as blocking (`rules/server-cache-cross-request.md`).
- **Compiler gate.** The compiler does re-render hygiene, not fixes that need work skipped. On: no new `memo`, `useMemo` or `useCallback` for hygiene; keep existing ones (removal changes the compiled output). Off: memoize only memoized children's props, context values and work ≥ 1 ms (`rules/rerender-memo.md`). Either way, compiled scopes can key slow work on the fast input, so a fix that needs work skipped gets the boundary that skips it: `useMemo` keyed on its slow inputs for a slow step beside a fast input; a `memo` child with no fast-changing prop for a slow subtree or work behind an early return; both for a deferred or Transition render (`rules/rerender-use-deferred-value.md`). A value whose identity an Effect or a library (charts, maps) compares gets `useMemo` too. Prove any skip with the Profiler or the compiled output. Name each Rules-of-React break and whether the compiler sees it: lint-reported, it skips the component (lost optimization); hidden in a helper or module, it compiles and can show stale values (a bug).

## Performance

**Evidence gate.** Without measurements, fix only costs the code itself shows: serial independent awaits, N+1 queries, a heavy dependency on first paint, an unbounded list rendered whole, and per-item work on a per-input path (every row, on each keystroke, frame or render). There, build formatters, collators and `RegExp` once, normalize keys once per data change, look up by `Map` or `Set`, make one pass, and never sort for a min or max (`rules/js-hot-paths.md`); label its cost (rows × work × events) an estimate. Other micro-optimizations only inside a profiled task over 50 ms.

1. Start from field data when it exists (CrUX, or RUM with web-vitals attribution); reproduce on a production build on the target device.
2. Split the failing metric (LCP into its four subparts) and work on its largest part:
   - **TTFB:** render mode (per request where a cached shell would do: `next build` route table); server time by phase (Server-Timing); sequential queries × distance to the database; a slow query shared by all users or a tenant, uncached; cold starts.
   - **INP:** input delay (hydration, split by Suspense boundaries; third-party tasks), processing (React Profiler), presentation (DOM size, layout); replay the attributed interaction in the lab.
3. Apply the matching Symptom index rows, highest prior first; re-measure, and revert a change that didn't move the metric.

## Symptom index

Rows read "symptom (first suspect): rules", each at `rules/<id>.md`; untagged rules work across frameworks on React 19+.

**Correctness**, by Severity:
- Server entry points (missing check, module state, oversized payload): `server-auth-actions`, `server-no-shared-module-state`, `server-serialization`
- Input loses focus on every keystroke (inline component, unstable key): `rerender-no-inline-components`
- Render loop ("Too many re-renders", "Maximum update depth exceeded"); an Effect that double-runs or reads stale values: `rerender-derived-state-no-effect`, `advanced-effect-event-deps`
- Hydration warning; theme or time flash: `rendering-hydration-no-flicker`
- Stale data after a mutation (invalidation missing, or in `after()`); a lost side effect: `server-cache-cross-request`, `server-after-nonblocking` [Next]
- A toggled panel loses its state: `rendering-activity` [19.2+]

**Performance**, prior when unmeasured (C: delays every load; H: delays each hot-path interaction, or adds small work to every request; M: some renders) × how often the path runs:
- C · Waterfalls: serial awaits, a parent's await or N+1 on the server (slow TTFB); client fetches chained parent to child (late LCP): `async-parallel`, `async-defer-await`, `server-parallel-fetching`
- C · A page or region waits on one slow query (its result shared by users or a tenant, uncached; no Suspense boundary); wrong status after streaming: `server-cache-cross-request`, `async-suspense-boundaries`
- C · Large route JS, early third-party scripts, clicks lagging during hydration (heavy dependency, client boundary too high, barrels, dynamic paths): `bundle-dynamic-imports`, `bundle-barrel-imports`, `bundle-analyzable-paths`, `bundle-defer-third-party`
- C · LCP resource discovered late: `rendering-resource-hints`
- H · Work or file reads repeated per request: `server-cache-react` [RSC], `server-hoist-static-io`
- H · Typing lags behind heavy results; a filter or sort slow per keystroke; a tab switch freezes: `rerender-use-deferred-value`, `js-hot-paths`, `rerender-transitions`
- H · Slow interaction (work before paint, forced layout): `js-yield-to-main`
- H · Scroll or pointer jank: `rerender-use-ref-transient-values`
- H · Long list rendered whole: `rendering-content-visibility`
- M · Slow re-renders (state held too high, context churn, an uncompiled component, a compiled scope keyed on a fast input): `rerender-memo`

## Output

**Code change.** Notes after the diff: ≤ 150 words, plus ≤ 150 for a shipping plan; parts are a menu. Budgets limit the record, not the analysis: a material finding over budget still goes in, one line.
1. **Causes**, ranked by cost: symptom ← mechanism ← `file:line`, with the measured or estimated cost.
2. **Each change:** the failure it removes and the precondition it relies on ("`items` keeps its identity between keystrokes"); before → after, or "write-time default".
3. **Behavior changes** made on purpose; defects flagged elsewhere; checks run or skipped, with the evidence for any skip claim; assumed stack facts.
4. **Shipping plan** (server entry point, mutation, cache, schema or auth): a test per fixed hole, calling the endpoint directly (no session, another tenant's id, a repeat); the metric to watch after deploy; deploy order (schema, consumers, then writers; accept the previous build's input until its clients reload); rollback; follow-ups the guarantees need.

**Review or audit** (≤ 400 words for a component or PR, ≤ 1,200 for a route or app; parts are a menu, omit what doesn't apply, heading included):
1. **Verdict**, one line: ship, fix first, or no change needed.
2. **Findings**, Blocker → High → Medium: `file:line`, mechanism, evidence, user effect, fix; past 10, one line each, never dropping a Blocker or High.
3. **Measurements** (performance work): metric, route, device, before → after.
4. **Assumptions**: stack facts you couldn't confirm.

Write for the code's owner: no rule ids or method narration.

**Severity.** *Blocker:* a Server boundary violation other than a missing rate limit, a critical or high advisory on a path the app exposes, cross-tenant access, unsanitized untrusted HTML in `dangerouslySetInnerHTML`, an open redirect, mutated props or state, a hydration mismatch showing wrong data, lost user input. *High:* a correctness bug on a normal path (a stale response winning, a missing cleanup, pending or error state, wrong filter or sort results, a losable side effect), an unthrottled send, charge or enumeration open to anonymous callers or any member, or a measured or code-evident hot-path cost. *Medium:* an edge-case bug, a plausible but unmeasured cost, any other missing rate limit or advisory.

## Self-Review

Fix every no before returning.

- APIs exist in the installed versions, checked against current advisories; no dependency the platform or an installed library covers.
- Each touched server entry point passes the Server boundary checks in its handler, and a test calls it directly; every started promise is joined; nothing durable runs in `after()` or `waitUntil`; every outbox row has a consumer.
- No Effect derives state, handles an event, or fetches what a loader or query library could; nothing browser-only is read during server render or hydration outside `use(browser())` or a client-only boundary.
- Each fix that needs work skipped has the explicit boundary the Compiler gate names for its case, a stated precondition, and Profiler or compiled-output proof, or says it's unverified.
- Notes rank causes by cost, each tied to its symptom by mechanism, name the failure each change removes, disclose behavior changes, and show before → after or say write-time default or estimate; rewritten lines carry no Blocker or High defect.
- Typecheck, hooks lint and production build pass, or the notes say which didn't; each bug fix has a reproducing test (in a browser for hydration, streaming and async Server Components); a shipping change has its plan.
- Footprint: notes ≤ 150 words, plus ≤ 150 for a shipping plan; a review ≤ 400 or 1,200 words, verdict first; an overrun carries only material findings, one line each.
