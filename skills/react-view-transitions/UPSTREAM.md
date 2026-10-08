# Upstream and fork posture

A frozen, host-agnostic fork of [`vercel-labs/agent-skills` → `react-view-transitions`](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-view-transitions) (MIT), forked 2026-06-04 (commit `f85be53` in this repo). Upstream has since renamed it `vercel-react-view-transitions` and restructured it.

**Policy:** never re-clone over this directory. Merge upstream changes by hand, porting fixes rather than text and dropping anything that depends on Vercel infrastructure. Re-verify every version, browser and API claim against primary sources (react.dev and the React source, the Next.js docs and source, MDN browser-compat-data), keep the divergence below, then run SKILL.md's Self-Review against the examples.

## Local divergence to keep

- SKILL.md's Frame (with Precedence: the user's spec and working code outrank every default), cost model, decision table, heuristics and timing yardstick, fix path with its knock-on check, per-cause report with a Trade-offs line, and Self-Review; upstream's "implement all patterns", mandatory audit and copy-every-recipe step are gone on purpose.
- Prop resolution, including where a `"none"` boundary's pixels go; the corrected `update` and nested enter/exit rules; type-gated in-place motion.
- React's reveal by default, the split reveal for revalidating content, page wrappers above the page's Suspense (Next.js with `loading.tsx`: in `template.tsx`).
- Back vs up; Next.js back/forward run in `popstate` and never animate (the Next.js guide says morphs still play); Next.js segments remount on param change (upstream assumed same-route pages stay mounted).
- Version-bound Next.js setup that never edits manifests or config, with `onNavigate` typing before 16.2.
- Readiness: React doesn't wait for lazy or `onLoad` images (every `next/image`); capped `decode()` waits; morph geometry checks and `image-morph`.
- Modal over a mounted source; gated triggers that carry their own class; streamed first-load reveals block the page.
- patterns.md § Diagnose: the agent probe and its gates (React always leaves a hidden `group(root)`; `new(root)` marks a leak), whole-transition errors (`InvalidStateError`, `AbortError`), Safari's inline-wrapper bug. Re-run the probe against the current React before trusting its gates.
- View Transitions level 2 floor; no `::view-transition { pointer-events: none }` (React blocks clicks on running animations on purpose).
- Snippets: the constant same-route `name`, `pinned`, only `nav-*` types for navigations, named VTs for skeleton controls, layout-effect scroll restore.
- CSS: installed only where the project has no view-transition CSS; plain 100/200/300 ms (upstream: 150/210/400), pointed at project tokens only when they exist; forward `to` keyframes for exits (upstream's `reverse` inverted their easing); an undelayed in-place `fade-in` (upstream delays it), the staggered page fade being `nav-morph`; blur on `.morph` only; `vt-` prefixes; RTL; reduced motion that drops travel and blur but keeps fades.
