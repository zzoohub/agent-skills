---
name: react-view-transitions
description: |
  Animate React UI changes with `<ViewTransition>`, `addTransitionType` and the browser View Transitions API: route transitions, shared-element morphs, forward/back slides, Suspense reveals, list reorder and enter/exit, in React 19.3+ or the Next.js App Router. Use for "view transition", "page transition", "animate route change", "shared element", "morph", or a view transition that doesn't fire, flickers, blocks clicks or animates the wrong thing.
  Do NOT use for: hover, toggle or open/close effects on elements that stay mounted, motion tokens or reduced-motion policy (design-system); React Native / Expo (react-native-skills).
license: MIT
source: https://github.com/vercel-labs/agent-skills/tree/main/skills/react-view-transitions
---

# React View Transitions

> Fork of [`vercel-labs/agent-skills`](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-view-transitions) (MIT), host-agnostic and frozen: merge upstream only per `UPSTREAM.md`.

A view transition (VT) costs the user time and clicks, so each must teach one spatial fact: the same object, where it went, what arrived, forward or back. Use the fewest that do, wire them exactly, and prove them by watching.

## Frame the request

**Precedence.** The user's spec, signed-off choices and working code outrank this skill's defaults, which decide only motion nobody specified: keep their durations, easings, classes, tokens and motion choices, and report a default that disagrees as a proposal. Break: their choice causes the bug; change only that, and say so.

Settle the rest from the code; ask only what it can't answer, else state the default you assumed.

1. **Installed stack:** read the versions (`npm ls react next`, the lockfile) and confirm the API exists. *Default:* build within them (React ≥ 19.3; Next.js: `references/nextjs.md` § Setup by version). Unless asked, never edit manifests, lockfiles or framework config, or install canary: upgrades and stale flags are proposals with their exact change; if nothing installed can do the job, ask first. If the typecheck can't find `ViewTransition` (`@types/react` before 19.3), add `/// <reference types="react/canary" />` to a project `.d.ts` and propose the types upgrade.
2. **Router:** how do back and forward run? *Default:* unanimated. Anything else calling `startViewTransition` (a router's `viewTransition` option, hand-rolled code) is a second owner: turn it off where it overlaps.
3. **Scope:** a fix, one interaction, one flow, or app-wide? *Default:* a fix or one interaction gets no audit and touches only the code its causes live in, even outside the named component (a layout VT, the destination page); app-wide follows `references/implementation.md`.
4. **Purpose:** what does each motion tell the user? *Default:* no answer, no VT. Never fake motion the platform skips (§ Back vs up): say so and offer what works.
5. **Readiness:** does the destination render in the same commit, its hero image decoded (shown before at that URL, or preloaded)? *Default for dynamic routes:* no, so every morph gets an enter fallback. Never fake readiness with a fixed delay: wait on the real signal (the data, the image's `decode()`) and report the added latency. Cap an image wait near 100 ms so the click still feels instant; a longer or uncapped wait (the router fetching data) needs a pending cue (`references/patterns.md` § Wait for the destination).
6. **Existing motion:** which view-transition CSS, motion tokens and reduced-motion rule exist; does another engine animate this surface? *Default:* extend what exists; recipe CSS only where none does, using only tokens you found; one engine per element.

**Done** means: the symptom is gone or each requested row plays as mapped, the Self-Review passes, and the reply names what the user will notice (what stays unanimated, any new wait).

## What a view transition costs

React animates snapshots of the old and new UI in an overlay, so:
- **It can't be interrupted.** The next one waits; updates arriving meanwhile batch (A→B, then one B→D). Its duration is latency on the next click.
- **It freezes the screen first** while React commits and waits for new fonts and in-viewport images (up to 500 ms) and any pending Navigation API navigation, but not for lazy images or any `<img>` with an `onLoad` handler (every `next/image`): a morph onto one can land on a blank frame.
- **It blocks input.** Clicks over animating snapshots are swallowed; snapshots don't scroll. Don't add the Next.js guide's `::view-transition { pointer-events: none }`: React already keeps the rest of the page clickable, and a click through a moving snapshot hits whatever is under it.
- **Snapshots are flat images above the page:** they cover sticky chrome, ignore ancestor clipping, and distort when aspect ratio or text size changes.
- **It needs View Transitions level 2** (`startViewTransition({ update, types })`): Chromium 125+, Safari 18.2+, Firefox 147+ (MDN browser-compat-data `startViewTransition.options_parameter`, as of 2026-10). Elsewhere React commits unanimated, so never put focus, scroll or analytics logic in VT callbacks.

**Tool choice.** VTs suit DOM that is replaced or changes container. Mounted DOM (open/close, toggles, hover) gets CSS transitions or `@starting-style`, which interrupt and never block input, unless a toggle swaps whole subtrees (grid ↔ detail). Drag and swipe need an interruptible engine (FLIP, a layout-animation library), not React's experimental gesture transitions.

## Decide what moves

| Change | Motion | Wiring |
|---|---|---|
| Hierarchical nav, nothing shared | Directional slide | `DirectionalTransition` per page; links typed `nav-forward` / `nav-back` |
| Nav where an element persists | Morph; page cross-fades | Same `name` on both sides, `share="morph"` (`"image-morph"` for one picture); link typed `nav-morph` |
| Modal or lightbox over a mounted page | Morph in; a `router.back()` close is instant | The source drops the open item's VT: `references/patterns.md` |
| Ordered sequence (prev/next) | Slide by position | `nav-forward` = next |
| Lateral (tabs, sibling segments) | Cross-fade (a slide implies depth) | In place: a gated `update`; new segment: `references/nextjs.md` § Same-route swaps |
| Fallback → content | React's reveal | § Wire it |
| Discrete filter or sort | Items glide | A gated `<ViewTransition key={item.id}>` per item (`references/patterns.md`) |
| Element added or removed by a user action | Enter/exit; siblings decided | Recipe classes, gated |
| Revalidation, polling, streaming, typing | None | — |

Defaults for motion nobody specified (Precedence):

- **Silence.** Animate only changes the user started and is watching; background motion steals attention and blocks input. Break: the background change is the news (an incoming message); animate only that item's enter.
- **One traveller per navigation.** The shared element travels if one is on screen, else the page; the rest is opacity-only and ends no later. Don't slide the page under a morph: two spatial motions compete. Break: the project already pairs them.
- **Neighbours.** `"none"` isn't stillness (Prop resolution). For each element that enters, exits or resizes, decide how its siblings reach their places (glide via keyed VTs with a gated `update`, move with the page, or jump) and say which in the report.
- **Morphs.** Capture the same box on both sides (aspect ratio, radius on the captured element), or crop on purpose where the ratios must differ. The same picture on both sides gets no cross-fade or blur. Readiness: Frame 5. CSS: `references/css-recipes.md` § Morph, § Image morph.
- **Timing yardstick.** Toggles and in-place enter/exit 100–200 ms; page slides and fades 150–300 ms; Suspense reveals 200–400 ms; morphs 300–500 ms. Input waits, so authored motion never runs past its range; exits are shorter and accelerate, entrances decelerate. Project values in range stay; outside it, flag them, and change them only if they cause the bug.
- **Naming.** Names are global while mounted (`photo-${id}`). Name in the consumer, never in a reusable component that can render twice (modal and page).
- **Back vs up.** Back stays `router.back()` or the browser's back, untyped: unanimated in Next.js (through 16.4), at most a morph elsewhere, and skipped when the browser animated a swipe-back (`hasUAVisualTransition`). Only up-links to a fixed parent ("← Gallery") push, typed `nav-back` (`nav-morph` when an element persists); a Back control that pushes adds a history entry and loses scroll restoration.

## Wire it

**Activation.** Only Transitions animate (`startTransition`, `useDeferredValue`, Suspense reveals, router navigations that run as Transitions, as the Next.js App Router's do); `setState`, `useOptimistic` and `flushSync` commit unanimated. After an `await` in an async Transition, wrap updates in their own `startTransition`; earlier types still apply.

**Placement.** enter/exit fire only when the VT comes before any DOM node: `<ViewTransition><div>`, never `<div><ViewTransition>`.

**Triggers.**
- `enter`/`exit`: the outermost VT of a subtree inserted or removed in the Transition. Nested VTs join only through `share`, even when the outermost resolves to `"none"`.
- `update`: React mutates DOM inside the boundary, or the boundary moves or resizes because of an immediate sibling. The innermost VT takes it.
- `share`: a named VT unmounts while another with the same name mounts. It wins over enter/exit; where no pair forms, enter/exit fire instead.
- A boundary outside the viewport in both states doesn't animate. A new `key` remounts the VT; keying one that wraps `<Suspense>` also refetches.

**Prop resolution.** Each trigger uses its own prop, else `default`: `"auto"` is the browser cross-fade, any other string your class, and `"none"` gives the boundary no animation group of its own: its pixels move with the nearest ancestor that animates (a page wrapper's fade), or, with none, show the new state at once, unless a boundary resized with no VT above it and the whole page cross-fades (`references/patterns.md` § Diagnose).
- So `default="none"` turns off every trigger you don't name, `share` (pairs stop morphing) and `update` (keyed items stop gliding) included: put it on page, Suspense and named boundaries, then name what you want (`share` on every named VT, `update` where a sibling should glide).
- A bare VT cross-fades on every trigger of every Transition, background ones included; use one only when that is its whole job.

**Type maps** (`{ 'nav-forward': 'nav-forward', default: 'none' }`) fit any trigger prop and `default`: matching types join their classes, a `'none'` match wins, and no match uses the map's `default` key (TypeScript requires it). Types reset after each commit, so reveals and back/forward carry none: use plain strings there.

**Gate in-place motion** (keyed items, in-place cross-fades, user-added elements) on a type the handler adds: `default={{ 'list-change': 'auto', default: 'none' }}` plus `addTransitionType('list-change')`; `router.refresh()`, revalidation and polling carry no type, so they commit silently. A trigger with its own class gates in its own map: `enter={{ 'list-change': 'fade-in', default: 'none' }}`.

**Directional pages.** One wrapper per participating page, never in a layout. It sets enter and exit together: without an exit, the old page vanishes while the new one slides in.

```tsx
import { ViewTransition } from 'react';

// nav-morph: page fade under a morph (default; the project's own choice wins).
export function DirectionalTransition({ children }: { children: React.ReactNode }) {
  return (
    <ViewTransition default="none"
      enter={{ 'nav-forward': 'nav-forward', 'nav-back': 'nav-back', 'nav-morph': 'nav-morph', default: 'none' }}
      exit={{ 'nav-forward': 'nav-forward', 'nav-back': 'nav-back', 'nav-morph': 'nav-morph', default: 'none' }}>
      {children}
    </ViewTransition>
  );
}
```

Type a navigation through the router's option (Next.js: `references/nextjs.md`) or in your own Transition, `startTransition(async () => { addTransitionType('nav-forward'); await navigate(to); })`: the `await` carries the type to a router that commits later. Keep the page's Suspense boundaries inside the wrapper: if the whole page suspends, the untyped reveal inserts the wrapper as `"none"` and the content's enter never plays.

**React's reveal**, the default for a Suspense boundary that should animate: wrap it in `<ViewTransition update="auto" default="none">`. The fallback appears at once, fallback→content cross-fades, and content that never suspended appears unanimated. Break: content that re-renders in background Transitions would cross-fade on each refresh; use the split reveal (`references/patterns.md`). Streamed first loads play these reveals too, each freezing the page and swallowing clicks: leave the VT off boundaries that resolve after the user starts interacting.

## Procedure

Frame → map the changes (app-wide: `references/implementation.md`) → a table row per change → wire (Next.js: `references/nextjs.md`; lists, modals, tabs, skeleton controls, readiness waits, callbacks: `references/patterns.md`) → style (extend the project's transition CSS, else `references/css-recipes.md`) → observe (Self-Review 6) → self-review, then report.

**Fix path** (a VT misbehaves):
1. **Diagnose first:** which boundary fired, with which class and types (`references/patterns.md` § Diagnose). Find every cause: one flicker often has two (no pair forms, and the image isn't decoded).
2. **Fix each cause where it lives,** in the user's code and CSS: their values, classes and tokens stay; new CSS only for a class the fix introduces, on their variables, its travel and blur off under reduced motion; no recipe blocks, token aliases, manifest or config edits. A reduced-motion gap in their CSS is a proposal.
3. **Knock-on check per change:** identity (keys and names you added stay unique among everything mounted at once; a changed key remounts: state resets, Suspense refetches); async ordering (does motion now wait on data or an image; does a later click still win); first load and history (cold cache, streamed reveals, browser back).
4. **Re-observe** the symptom and its neighbours; run Self-Review 2–7 on what you touched.

**Report.** Budgets size the reply, never the analysis: a material finding gets its line even past the budget, with the reason.
- **Fix:** one line per cause, `cause (evidence) → what the user saw → change`, ≤ 40 words each. Then **Trade-offs**, required, ≤ 60 words: what the user will now notice (a wait, what stays unanimated and why), invariants the change creates (unique keys or names), proposals not applied (upgrades, stale flags, defaults unlike theirs). Then what you observed, or couldn't.
- **Build:** one interaction or flow ≤ 150 words, app-wide ≤ 300 plus the nav map: files changed; a "communicates X" line per VT; what stays unanimated and why; trade-offs and proposals; rows not observed; version or browser caveats.

## Self-Review

1. **Purpose:** each added VT has a "communicates X" line; refreshes, revalidations and keystrokes animate nothing.
2. **Scope:** each changed line traces to a named cause or requested row; nothing added goes unused (class, keyframe, variable, hook, helper); manifests, lockfiles and framework config untouched unless asked; the user's values and choices stand unless they caused the bug, as reported.
3. **Integrity:** every JSX class has a CSS rule; every named VT under `default="none"` has a `share`; added keys and names are unique among everything mounted at once; every added type is listened for and every type map has a `default`; page wrappers sit above their page's Suspense boundaries; typecheck passes.
4. **Timing:** authored motion sits inside its yardstick range, exit shorter than enter; blur only on `.morph` in CSS you added.
5. **History:** browser back still goes back; no Back control you added pushes.
6. **Observed** via the qa or browse capability, if available (else list rows not observed): each changed row, cold and warm, and browser back pass the gates in `references/patterns.md` § Diagnose, reduced motion included; each morph lands on a painted image, geometry matched.
7. **Footprint:** the reply fits its budget or says why, covers its items, and a fix has its Trade-offs line.
