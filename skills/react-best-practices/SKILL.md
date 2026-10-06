---
name: react-best-practices
description: |
  React and Next.js performance optimization guidelines. Use when writing, reviewing, or refactoring React/Next.js code to ensure optimal performance patterns. Triggers on tasks involving React components, Next.js pages, data fetching, bundle optimization, re-render reduction, or load-time improvements. Also covers the server boundary of Next.js Server Actions and TanStack Start server functions (input validation, auth, tenant scoping, client-exposed env vars).
  Do not use for: design tokens / theming / motion (use design-system), React Native / Expo apps (use react-native-skills), or backend/API architecture.
license: MIT
source: https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices
---

# React Best Practices

> **Cloned & internalized** from [`vercel-labs/agent-skills` → `react-best-practices`](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) (MIT), with Vercel-infrastructure-dependent content stripped and host-specific notes (Fluid Compute, `@vercel/analytics`, vercel.com citations) genericized for portability.
> **To update this skill:** always pull the latest from the original above (or re-clone it), then remove *only* the parts that depend on Vercel infrastructure before applying changes — keep everything else host-agnostic. Re-apply this repo's local additions and corrections on top of the pull: the **Server boundary** section below and the 2026-10 snippet fixes (`next/dynamic` `ssr: false` only in client components, SWR import shapes, `preinit` stylesheet `precedence`, `next/script` `beforeInteractive` in the root layout, Next's default `optimizePackageImports` list, React 19.2 floors for `useEffectEvent`/`<Activity>`).

Comprehensive performance optimization guide for React and Next.js applications. Contains 70 rules across 8 categories, prioritized by impact to guide automated refactoring and code generation.

## When to Apply

Reference these guidelines when:
- Writing new React components or Next.js pages
- Implementing data fetching (client or server-side)
- Reviewing code for performance issues
- Refactoring existing React/Next.js code
- Optimizing bundle size or load times
- Writing Next.js Server Actions or TanStack Start server functions (see **Server boundary**)

## Server boundary (Next.js and TanStack Start)

These rules are about security, not speed, and apply before any performance rule:

- **Every server entry point is a public endpoint.** A Next.js Server Action (`'use server'`) is reachable by a direct POST, and a TanStack Start server function (`createServerFn`) is an HTTP-reachable RPC route, whether or not your UI calls it. Inside the handler: validate the input at runtime with a schema, authenticate, authorize (role and ownership, not just "has a session"), and tenant-scope the read or write (e.g. `where: { id, orgId }`, returning not-found across tenants). See `rules/server-auth-actions.md`.
- **Middleware/proxy, route guards (`beforeLoad`), layout checks and hidden UI are UX only.** They decide what renders, not who may call the endpoint.
- **Never keep request- or user-scoped data in mutable module scope.** On a long-lived server, module scope is shared by concurrent requests; pass such data through props, context or arguments. Immutable static I/O and config at module scope are fine (see `rules/server-no-shared-module-state.md`, `rules/server-hoist-static-io.md`).
- **Only public-prefixed env vars reach the client** (`NEXT_PUBLIC_` in Next.js, `VITE_` in TanStack Start), and every one of them does, so keep secrets unprefixed and read them only in server-only code. TanStack Start route loaders are isomorphic (they also run in the browser on client navigation), so put DB access and secrets in a server function, not in a loader.
- **Return only what the client renders.** RSC props and server action / server function return values are serialized to the client (see `rules/server-serialization.md`). TanStack Start also serializes thrown server-function errors to the client, so throw generic messages and log the details server-side.

For TanStack Start project conventions (FSD layering, URL as first-class state), see the TanStack Start house taste in the software-architecture skill's `references/house-stack.md`, if available.

## Rule Categories by Priority

| Priority | Category | Impact | Prefix |
|----------|----------|--------|--------|
| 1 | Eliminating Waterfalls | CRITICAL | `async-` |
| 2 | Bundle Size Optimization | CRITICAL | `bundle-` |
| 3 | Server-Side Performance | HIGH | `server-` |
| 4 | Client-Side Data Fetching | MEDIUM-HIGH | `client-` |
| 5 | Re-render Optimization | MEDIUM | `rerender-` |
| 6 | Rendering Performance | MEDIUM | `rendering-` |
| 7 | JavaScript Performance | LOW-MEDIUM | `js-` |
| 8 | Advanced Patterns | LOW | `advanced-` |

## Quick Reference

### 1. Eliminating Waterfalls (CRITICAL)

- `async-cheap-condition-before-await` - Check cheap sync conditions before awaiting flags or remote values
- `async-defer-await` - Move await into branches where actually used
- `async-parallel` - Use Promise.all() for independent operations
- `async-dependencies` - Use better-all for partial dependencies
- `async-api-routes` - Start promises early, await late in API routes
- `async-suspense-boundaries` - Use Suspense to stream content

### 2. Bundle Size Optimization (CRITICAL)

- `bundle-barrel-imports` - Import directly, avoid barrel files
- `bundle-analyzable-paths` - Prefer statically analyzable import and file-system paths to avoid broad bundles and traces
- `bundle-dynamic-imports` - Use next/dynamic for heavy components
- `bundle-defer-third-party` - Load analytics/logging after hydration
- `bundle-conditional` - Load modules only when feature is activated
- `bundle-preload` - Preload on hover/focus for perceived speed

### 3. Server-Side Performance (HIGH)

- `server-auth-actions` - Authenticate server actions like API routes
- `server-cache-react` - Use React.cache() for per-request deduplication
- `server-cache-lru` - Use LRU cache for cross-request caching
- `server-dedup-props` - Avoid duplicate serialization in RSC props
- `server-hoist-static-io` - Hoist static I/O (fonts, logos) to module level
- `server-no-shared-module-state` - Avoid module-level mutable request state in RSC/SSR
- `server-serialization` - Minimize data passed to client components
- `server-parallel-fetching` - Restructure components to parallelize fetches
- `server-parallel-nested-fetching` - Chain nested fetches per item in Promise.all
- `server-after-nonblocking` - Use after() for non-blocking operations

### 4. Client-Side Data Fetching (MEDIUM-HIGH)

- `client-swr-dedup` - Use SWR for automatic request deduplication
- `client-event-listeners` - Deduplicate global event listeners
- `client-passive-event-listeners` - Use passive listeners for scroll
- `client-localstorage-schema` - Version and minimize localStorage data

### 5. Re-render Optimization (MEDIUM)

- `rerender-defer-reads` - Don't subscribe to state only used in callbacks
- `rerender-memo` - Extract expensive work into memoized components
- `rerender-memo-with-default-value` - Hoist default non-primitive props
- `rerender-dependencies` - Use primitive dependencies in effects
- `rerender-derived-state` - Subscribe to derived booleans, not raw values
- `rerender-derived-state-no-effect` - Derive state during render, not effects
- `rerender-functional-setstate` - Use functional setState for stable callbacks
- `rerender-lazy-state-init` - Pass function to useState for expensive values
- `rerender-simple-expression-in-memo` - Avoid memo for simple primitives
- `rerender-split-combined-hooks` - Split hooks with independent dependencies
- `rerender-move-effect-to-event` - Put interaction logic in event handlers
- `rerender-transitions` - Use startTransition for non-urgent updates
- `rerender-use-deferred-value` - Defer expensive renders to keep input responsive
- `rerender-use-ref-transient-values` - Use refs for transient frequent values
- `rerender-no-inline-components` - Don't define components inside components

### 6. Rendering Performance (MEDIUM)

- `rendering-animate-svg-wrapper` - Animate div wrapper, not SVG element
- `rendering-content-visibility` - Use content-visibility for long lists
- `rendering-hoist-jsx` - Extract static JSX outside components
- `rendering-svg-precision` - Reduce SVG coordinate precision
- `rendering-hydration-no-flicker` - Use inline script for client-only data
- `rendering-hydration-suppress-warning` - Suppress expected mismatches
- `rendering-activity` - Use Activity component for show/hide (React 19.2+)
- `rendering-conditional-render` - Use ternary, not && for conditionals
- `rendering-usetransition-loading` - Prefer useTransition for loading state
- `rendering-resource-hints` - Use React DOM resource hints for preloading
- `rendering-script-defer-async` - Use defer or async on script tags

### 7. JavaScript Performance (LOW-MEDIUM)

- `js-batch-dom-css` - Group CSS changes via classes or cssText
- `js-index-maps` - Build Map for repeated lookups
- `js-cache-property-access` - Cache object properties in loops
- `js-cache-function-results` - Cache function results in module-level Map
- `js-cache-storage` - Cache localStorage/sessionStorage reads
- `js-combine-iterations` - Combine multiple filter/map into one loop
- `js-length-check-first` - Check array length before expensive comparison
- `js-early-exit` - Return early from functions
- `js-hoist-regexp` - Hoist RegExp creation outside loops
- `js-min-max-loop` - Use loop for min/max instead of sort
- `js-set-map-lookups` - Use Set/Map for O(1) lookups
- `js-tosorted-immutable` - Use toSorted() for immutability
- `js-flatmap-filter` - Use flatMap to map and filter in one pass
- `js-request-idle-callback` - Defer non-critical work to browser idle time

### 8. Advanced Patterns (LOW)

- `advanced-effect-event-deps` - Don't put `useEffectEvent` results in effect deps (React 19.2+)
- `advanced-event-handler-refs` - Store event handlers in refs
- `advanced-init-once` - Initialize app once per app load
- `advanced-use-latest` - `useEffectEvent` (React 19.2+) to read latest values without effect re-runs

## How to Use

Read individual rule files for detailed explanations and code examples:

```
rules/async-parallel.md
rules/bundle-barrel-imports.md
```

Each rule file contains:
- Brief explanation of why it matters
- Incorrect code example with explanation
- Correct code example with explanation
- Additional context and references
