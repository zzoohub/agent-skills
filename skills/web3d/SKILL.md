---
name: web3d
description: |
  Implements real-time 3D and XR on the web: three.js (WebGPU or WebGL, TSL
  shaders), React Three Fiber and drei, glTF pipelines (meshopt, KTX2), Rapier
  physics, Koota ECS, Rust WASM, workers and WebXR. Use when building, debugging,
  profiling, upgrading or migrating a 3D scene, product viewer or configurator,
  shader or GPU particles, physics, adding VR/AR to an existing scene, or a
  frame-rate, color or GPU-memory problem, or when code touches three,
  @react-three/*, koota, @dimforge/rapier3d or navigator.xr. Do NOT use for
  3D/XR UX, IA or comfort design (ux-design), or CSS 3D effects and view
  transitions (design-system, react-view-transitions).
---

# Web 3D & XR

## Premise

Real-time 3D on the web is a budget problem under device and backend fragmentation: frame time at the display's refresh rate, GPU memory, seconds to the first interactive frame, and heat (phones throttle within minutes). The weakest device you promise sets the budget. Build the smallest stack that does the job; every layer past renderer and scene graph needs a trigger. In XR the budget is a comfort floor: a dropped frame is nausea, not jank. On an existing scene, what works today is the baseline every change keeps.

## Modes

- **Build** (default): a new scene or feature. Stage 0, Decide, Build.
- **Add a mode** to a working scene (XR or AR, a WebGPU path, post-processing, a second view): Stage 0, § Add a mode, then the Build steps it touches.
- **Diagnose** (slow, janky, leaking, black, off-color, broken after an upgrade): § Diagnose, before changing code.
- **Migrate** (WebGL to WebGPU, GLSL to TSL) only for a payoff the Renderer row names: `references/shaders.md` § Migrating from GLSL, run as an added mode until the switch.

**Proportionality.** Budgets size the reply, never the analysis: every request gets the framing, the numbers and the trap checks. A local change (a material, a light, one bug) reads the renderer setup and the code it touches, skips the Stage 0 questions and Decide rows it doesn't cross, and makes the smallest patch: no blind retuning; an open decision states its predicted effect. A prototype renders on the floor device with its poster and failure paths and ships the tooling its gates need (frame probe, remount loop, visual baseline); only device runs may stay open, named.

**Version gates and probes.** A tag such as (r185+) marks a three.js API that exists only from that release: check the installed version (`node_modules/three/package.json`) and each tagged or non-default API in its source or typings before building on it; below the gate, use the fallback given; never upgrade unasked. Drift fastest: three's WebGPU, TSL and XR APIs (its Migration Guide), @react-three/xr options, drei under `WebGPURenderer`, Koota, @react-three/rapier. Probe a capability where it is used (`isSessionSupported` when the XR entry mounts), never at startup for every visitor, never as a device tier: phones and headsets both support XR; tiers come from measured frame time or the user.

**Another engine** (Babylon.js, PlayCanvas): engine-neutral parts only; never port unasked.

**Ownership.** 3D/XR experience and comfort design belong to ux-design (if available); this skill implements. UX specs are acceptance criteria: never redesign them or write `docs/ux/`; report gaps.

## Stage 0 — Frame

**Read first** (defaults; the caller may redirect): the UX doc and screen specs (`docs/ux/ux-design.md`, `docs/ux/screens/*.md`); the feature spec (`docs/prd/features/*.md`); `package.json`, the lockfile and the renderer setup (engine and version, R3F, GLSL, EffectComposer, header control, XR). On an existing scene, also its loop, shared loader, camera, controls and units.

**Ask once, in one batch,** only what code and specs can't answer, each with its default. A subagent that can't prompt applies the defaults and lists the questions in its report.
- **Job:** what 3D does that a poster, video or turntable can't (showcase, configurator, spatial data, simulation, XR). Default: the feature spec's job, else a viewer; "look impressive" means a poster or video, the canvas loaded on interaction.
- **Floor device:** default a mid-range Android phone 3–4 years old; for XR, the lowest headset in scope at the rate the session runs. Measure its rate (often 90–120 Hz) with the frame probe (`references/performance.md` § Budget).
- **Host:** a page section (LCP, scroll, SSR, auth popups, embeds) or a dedicated app. Default: a section of an existing page, the stricter case.
- **Assets:** source, `gltf-transform inspect` totals, and whether code addresses parts by name. Default: inspect what exists, else placeholder primitives with the gap listed.
- **Reach:** WebGL 2 is the guarantee; WebGPU isn't Baseline (MDN BCD, 2026-10: missing in Firefox on Linux and Android). iOS has no WebXR, so Apple AR means Quick Look with USDZ (`references/web-xr.md` § Support and features).

**Done means** (defaults; the UX spec overrides), on the floor device:
- Smooth: ≥ 99% of frame intervals within 1.5× the target interval over a 5-minute soak. Count dropped frames; never average fps.
- Headroom: p95 main-thread work per frame ≤ 70% of the budget; GPU time where timer queries exist, else reported unmeasured.
- Poster first, interactive within 5 s on throttled 4G; host LCP and INP no worse.
- GPU memory ≤ 256 MB on phones, back to baseline after 10 remounts.
- No GPU, a failed load and device loss each render something.

## Decide

Default, then when to choose otherwise.

- **Custom renderer at all.** One product with AR: `<model-viewer ar>`. A renderer only for custom shading, composition or interaction; its Apple AR is then a USDZ export (`references/web-xr.md` § Quick Look).
- **Renderer** (hard to reverse). Greenfield: `WebGPURenderer` from `three/webgpu` (r167+; TSL, compute, automatic WebGL 2 fallback). `WebGLRenderer` when code depends on GLSL, `onBeforeCompile` or an EffectComposer (three's or pmndrs `postprocessing`), or a needed helper fails the grep rule. Migrate a working WebGL app only for a named payoff (TSL, compute, a WebGPU-only feature, a win measured on the floor device): WebGPU isn't automatically faster, and phones without it run the fallback. XR: a WebGL backend until WebGPU XR is verified on the headset (`references/web-xr.md` § Backend first).
- **State** (hard to reverse). Scene graph plus a small store; Koota at roughly 1k+ entities or many composable behaviors. The world stays on the main thread (traits hold `Object3D`s).
- **Physics.** Rapier on the main thread: fixed 60 Hz step, rendered interpolated. A worker only when the step's p95 tops about 15% of the frame budget on the floor device; bodies the user holds or drives stay on the main thread (a worker adds ≥ 1 frame of latency).
- **Compute.** JS first. GPU-resident per-element work: TSL compute (limited on WebGL 2). Heavy CPU numerics after a measured JS baseline: Rust WASM; rayon only with isolation and a measured win.
- **Threads** (hard to reverse). `postMessage` plus transferables; no COOP/COEP. Isolation only when SharedArrayBuffer is measured necessary, on the 3D route only, keeping the `postMessage` path: it breaks OAuth and payment popups and blocks cross-origin assets (`references/threading.md`).
- **Geometry.** meshopt; Draco only for static payloads where geometry dominates (needs a `DRACOLoader`).
- **Textures.** KTX2: UASTC for normal, ORM and hero color, ETC1S for the rest; ≤ 2048 px on phones. WebP or AVIF (full RGBA in VRAM) only when download, not VRAM, binds. Uncompressed ≈ w×h×4×1.33 bytes: one 4096² texture ≈ 89 MB.
- **Look.** Explicit tone mapping: Neutral for product color, AgX for cinematic. A small prefiltered environment map; static shadows baked or rendered once. Break for stylized or unlit art.
- **Content.** glTF (`.glb`); configurators and Gaussian splats: `references/assets.md` § Configurators, § Splats.

**Grep rule.** Under `WebGPURenderer` (either backend, even with `forceWebGL`), a helper is WebGL-only when its source, or the file defining a binding it imports (not three core or a package index), matches `ShaderMaterial|RawShaderMaterial|onBeforeCompile|createDerivedMaterial|ShaderChunk`. It fails about 35 drei 10.7.9 helpers and uikit 1.0 (list and replacements: `references/react/drei.md`). Re-run it after upgrades; never trust a list.

## Add a mode

1. **Baseline.** Record what the existing path does and measures (frames, memory, LCP, one reference view). Until the user enters the mode, that path runs exactly as before: no new startup probe or download, no changed renderer flag, shared loader or material. The mode loads and applies its settings on entry and restores them on exit; changing shared setup is a separate, named change with its own verification.
2. **Invariants.** Check each one the mode imposes against the existing code: units, camera ownership, the output transform (who tone-maps, and what a bypassed post stack did), DOM overlays, input, who owns the loop and the drawing-buffer size, the mode's budget. XR: `references/web-xr.md` § Adding XR to an existing scene.
3. **Engine first.** Before writing code, read what the installed engine does with each value you will change (XR: three's `WebXRManager.updateCamera` or `XRManager`).
4. **One boundary.** Convert content once (a root group or the asset pipeline), never the engine-owned side (camera, XR rig, reference space); then convert or justify each value the boundary doesn't carry. For a scale s: camera near/far, fog range, point and spot intensity (× s²) and `distance`, shadow-camera bounds and `normalBias`, LOD distances, raycaster `far`, physics gravity and speeds, audio distances, control limits.
5. **Spike** the mode with the heaviest existing view on the target device: scale, color, overlays, input, frame rate.
6. **Name the rejected alternative** and its reason (units: scaling the camera or rig, which the engine overwrites or leaks into view-space fog and lighting).

## Diagnose

1. **Symptom and history.** The symptom in the user's words, and what changed before it appeared (an upgrade, an asset, a browser, a device; the lockfile diff and git history show most); reproduce it where it was seen.
2. **After an upgrade, diff defaults before tuning**: read the migration guide for every version crossed (three's look-changing ones: `references/performance.md` § Color and output). Then find the cause (same file, § Diagnosis).
3. **Strip compensations** stacked on the root error (exposure, light multipliers, manual gamma, color hacks, a lowered DPR) with the fix, or it double-corrects.
4. **Fix at the cause**, smallest patch; each fix's isolated effect, before → after on the same device.
5. **Side effects and a guard.** List what else the fix touches (other materials, custom shaders, brand colors, routes sharing the renderer or loader, visual baselines); ship the guard that would have caught it (`references/testing.md` § Guards).

## Build

1. **Budget first.** Write the Done-means targets, floor device named, before scene code.
2. **Lifecycle skeleton before content.**
   - Init failure (no WebGL 2, adapter denied, `init()` rejects) shows the poster and a message.
   - Size from the container (`ResizeObserver`), not `window`; cap DPR at 2 (1.5 on fill-bound phones).
   - Pause the loop, workers and audio when the tab hides or the canvas leaves the viewport: hidden tabs stop `requestAnimationFrame`, not workers or AudioWorklets.
   - Device loss: on `WebGPURenderer` wrap `renderer.onDeviceLost` (r170+), keeping three's halting handler; on `WebGLRenderer` listen for `webglcontextlost`/`restored`; then rebuild.
   - Teardown frees GPU resources, loader caches and workers, then the renderer (`references/assets.md` § Dispose).
3. **Page citizenship.** Code-split three.js. The poster is the LCP image; mount the canvas on visibility, idle or interaction. OrbitControls sets `touch-action: none`, trapping page scroll on phones: use `pan-y` with horizontal-only rotation, or a tap-to-interact gate. Honor `prefers-reduced-motion`. One renderer per page; several views share one canvas through scissored viewports (drei `<View>`). The canvas gets an accessible name and a DOM alternative.
4. **Assets, then the spike.** Inspect, optimize, load with matching decoders, and pre-warm behind the poster so the first interaction never compiles or uploads (`references/assets.md`). Before feature work, spike the skeleton plus the heaviest asset at target DPR on the floor device; if that alone takes half the frame budget or memory cap, re-decide now: model-viewer, lower DPR, baked lighting, smaller textures (`references/performance.md` § Budget).
5. **Frame loop.**
   - `THREE.Timer` (core r179+, addons before; `Clock` deprecated r183) with `timer.connect(document)`; per frame `timer.update(t)`, then `dt = Math.min(timer.getDelta(), 0.1)`.
   - Fixed-step simulation, rendered by interpolating the last two states; otherwise 90 and 120 Hz displays judder.
   - Per frame: no allocation, no framework `setState`, no scene-wide raycast.
   - Picking: raycast pickables only, on pointer events; NDC from `canvas.getBoundingClientRect()`, never `window.inner*`; three-mesh-bvh for dense meshes; a movement threshold separates tap from drag.
6. **XR comfort.** Implement the UX spec's numbers. Where it is silent, ship teleport plus snap turn (smooth locomotion opt-in, none in passthrough) at a rate the floor headset holds, and list the gap.
7. **Verify on the floor device, then test.** Measure every Done-means number there. Tests: simulation first, GPU by visual diff (`references/testing.md`).

## Report back

Write for whoever asked, in their terms. The budget limits the record, not the content: ≤ 120 words for a local fix, ≤ 300 otherwise, tables included; every material finding (a trap, a side effect, a risk to the existing path, an unverified assumption) gets a line, over budget if need be, saying why. Sections are a menu: omit what doesn't apply, heading included.
- **Answer** in the user's framing: symptom → cause → fix → what they will see change; for a non-engineer, two or three plain sentences on how it got this way.
- **Numbers**: target vs measured, or each change's isolated effect before → after on the same device, ranked; each labeled measured, proxy or unmeasured.
- **Decisions**: choice, reason, rejected alternative, when to revisit; what was left untouched on purpose; each non-default flag or tagged API and where it was confirmed.
- **Limits and open questions**: unsupported platforms, what each failure path shows, UX-spec gaps; each question with its default and predicted effect.

A table only where rows compare values; no private notation; never narrate this skill's steps.

## Self-Review

- Every Done-means item checked on the floor device, failure paths included; a proxy number is labeled and passes nothing.
- Helpers pass the grep rule; both backends ran (`forceWebGL: true` for the second).
- Each non-default flag and tagged API confirmed in the installed version, file named; the fallback below its gate.
- Added mode: existing path unchanged (no new startup probe or download, same loader and flags, same numbers); reference view matches across modes; five enter/exit cycles restore everything.
- XR: WebGL backend unless WebGPU XR was verified on the headset; one unit boundary, dependents listed; only used session features; no new runtime third-party fetch; locomotion per spec, else teleport plus snap turn.
- Diagnosis: cause and history stated; compensations removed; side effects listed; guard shipped.
- Per frame: no allocation, `setState` or scene-wide raycast; `dt` clamped; fixed-step simulation, interpolated; the first interaction compiles and uploads nothing (trace).
- three.js code-split; loop, workers and audio pause when hidden or offscreen; reduced motion honored.
- COOP/COEP only for SharedArrayBuffer: 3D route only, set in production, `postMessage` fallback exercised.
- Footprint: reply within its word budget, tables counted, every material finding present; no private notation or tutorial code.

## Reference Files

Read a file when the task reaches it: `references/performance.md` (frame probe, diagnosis, color and output, levers), `references/assets.md` (pipeline, configurators, splats, pre-warm, dispose), `references/shaders.md` (TSL, compute, post-processing, migration), `references/threading.md` (workers, isolation, Vite config), `references/web-xr.md` (backend, adding XR to a scene, features, Quick Look), `references/testing.md` (tiers, mode parity, guards, GPU CI), `references/physics.md` (Rapier), `references/ecs.md` (Koota), `references/wasm.md`, `references/audio.md`. R3F projects also read each core file's `references/react/` twin, plus `references/react/setup.md` (Canvas, loading, `useFrame`, events) and `references/react/drei.md` (drei or uikit under `WebGPURenderer`).
