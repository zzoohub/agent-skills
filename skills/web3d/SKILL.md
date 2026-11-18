---
name: web3d
description: |
  Implements real-time 3D, in-canvas animation and XR on the web against a frame budget: three.js (WebGPU or WebGL, TSL shaders), React Three Fiber, glTF pipelines (meshopt, KTX2), Gaussian splats, Rapier physics, Koota ECS, WASM, workers and WebXR.
  Use when building, animating, debugging, profiling, upgrading or migrating a 3D scene, product viewer or configurator, scroll-linked scene, shader or GPU particles, physics or VR/AR, on a frame-rate, load-time, color or GPU-memory problem, or when code touches three, @react-three/*, koota, @dimforge/rapier3d or navigator.xr.
  Do NOT use for: 3D/XR UX, IA or comfort design (ux-design); DOM and CSS motion, CSS 3D or view transitions (design-system).
---

# Web 3D & XR

## Premise

**A real-time scene is a deadline that comes due every frame.** A 60 Hz display leaves 16.7 ms per frame, a 120 Hz one 8.3, a 90 Hz headset 11.1, and the browser spends part of that itself. A frame that misses is not slower output but broken output: a stutter on a screen, nausea in a headset. And the frame is one of four budgets. The others are the seconds before the first interactive frame, GPU memory, and heat, which on a phone turns a scene that passes in its first minute into one that fails in its fifth. All four are set by the weakest device you promise, never by the machine you develop on.

So performance here is a budget to meet, not a number to maximize. A frame that arrives early looks the same as one that arrives on time: meet the four budgets, then stop, and spend what is left on the look or give it back as battery.

Eight rules, in the order they bite:

1. **The cheapest frame is the one never drawn.** 3D ships only where it does a job an image or a video cannot, loads only when it is about to be seen, and draws only when something changed. A viewer nobody is touching costs nothing.
2. **A budget before a scene, proved where it is promised.** Four numbers for a named floor device come before any content, and the probe that measures them ships with the first build. A number from another machine is a proxy and passes nothing.
3. **Find the bound before pulling a lever.** At any moment one stage limits the frame: script, draw submission, vertices, pixels, or a one-off hitch. Each lever moves one of them, so run the experiment that names the stage first. Work on any other stage changes nothing you can see.
4. **Nothing is built without its trigger.** A renderer and a scene graph are the whole stack until a named fact calls for more. A post-processing pass, a physics engine, an ECS, a worker, WASM, a second animation library: each costs bytes, a build target or a failure mode for as long as it stays.
5. **The loop is hot code, and time is its only clock.** Per frame nothing allocates and nothing goes through framework state. Everything that moves advances by elapsed time, so it looks the same at 30, 60 and 120 Hz. Simulation runs at a fixed step and the picture interpolates.
6. **Assets decide load time and memory.** Most of the seconds and nearly all of the megabytes are settled in the asset pipeline, before any code runs. Inspect, compress for the stage that binds, gate it in CI, and compile and upload behind the poster so the first interaction does neither.
7. **Every failure draws something, and everything allocated is freed.** No GPU, a failed download and a lost device each have a designed picture. GPU memory is never garbage collected: what a scene creates, its teardown releases.
8. **The installed version is the truth, and the working scene is the baseline.** three.js changes its API and its look every month, and your memory of it is older than the lockfile: read the installed source before using an API. On a scene that works, measure first, change one thing, and leave every path you were not asked to change exactly as it was.

## Read first

**Inputs** (defaults; the caller may redirect). The UX doc and screen specs (`docs/ux/ux-design.md`, `docs/ux/screens/*.md`): 3D and XR experience design belongs to the ux-design capability, if available, and its numbers are acceptance criteria here. Implement them and report gaps; never redesign them. Then the feature spec (`docs/prd/features/*.md`), and the code: `package.json` and the lockfile, the renderer setup, and on an existing scene its loop, loader, camera, controls and units.

**Versions.** `references/landscape.md` holds everything dated: the versions this skill's examples ran on, browser support, what changed recently and what is about to. A tag such as (r184+) marks an API that exists only from that three.js release. Check the installed version (`node_modules/three/package.json`) and read a tagged or unfamiliar API in the installed source before building on it. Below a gate, use the fallback given. Never upgrade unasked. three's Migration Guide lists the breaking and look-changing changes of every release.

**Ask once, in one batch,** only what the code and specs cannot answer, each with its default. A subagent that cannot prompt applies the defaults and lists them as assumptions in its report.

- **Job.** What 3D does here that a poster, a video or an image spin cannot. Default: the feature spec's job, else a product viewer. "Look impressive" is a poster or a video, with the canvas loaded on interaction.
- **Floor device.** Default: a mid-range Android phone three to four years old. For XR, the lowest headset in scope.
- **Host.** A section of an existing page (the default, and the stricter case) or a dedicated app.
- **Assets.** Where they come from (a DCC tool, a scan, a generator) and whether code addresses parts by name. Default: inspect what exists, else placeholder primitives with the gap listed.
- **Reach.** Which browsers must show the 3D and which may get the fallback (`references/landscape.md` § Platform support).

**A small change stays small.** One material, one light, one bug: read the renderer setup and the code the change touches, skip the questions it does not cross, and make the smallest patch. The rules still apply; the ceremony does not. Gaps you notice outside the change (no poster, three.js in the first chunk, a scroll trap) are reported with what they cost, not fixed unasked.

**Another engine** (Babylon.js, PlayCanvas): the premise, the cost model, the budgets and the asset pipeline apply as written; the API examples do not. Never port unasked.

## The cost of a frame

A frame costs the sum of five terms, and the largest one sets the frame time.

| Term | Grows with | Paid on | First levers |
|---|---|---|---|
| **Script** | entities × work per entity, plus garbage | main thread | no allocation, data in typed arrays, per-element math moved to the GPU |
| **Draw submission** | visible objects × material groups × passes | main thread, inside `render()` | instancing, batching, merging; fewer shadow casters and passes |
| **Vertices** | triangles × passes, more with skinning and morph targets | GPU | level of detail, simplification, fewer shadow casters |
| **Pixels** | canvas area × DPR² × overdraw × shader cost × full-screen passes | GPU | a DPR cap, fewer passes, fewer transparent layers, cheaper materials |
| **Hitches** | first use (shader compile, texture upload), garbage collection, synchronous readback | both, as single long frames | compile and upload behind the poster, KTX2, no allocation |

What to reason with:

- **Passes multiply.** Each shadow-casting light draws its casters again, transmission draws the scene again, a headset without multiview draws everything once per eye, and every post effect is one more fill of the whole screen.
- **Pixels grow with the square of DPR.** DPR 2 is four times the fragment work and four times the drawing-buffer memory of DPR 1; a phone at DPR 3 pays nine times. This is why the first experiment is always the resolution.
- **Draws are CPU time, not GPU time.** Thousands of separate meshes are slow with trivial shaders, because the cost is the renderer walking, sorting and submitting them. The same objects as one instanced draw cost almost nothing, and the gap is wider under `WebGPURenderer` (`references/landscape.md` § Measurements).
- **A texture's memory is its pixels, not its file.** PNG, JPEG, WebP and AVIF all decode to w × h × 4 × 1.33 bytes with mipmaps: one 4096² texture is 89 MB however small the download. KTX2 stays compressed on the GPU at roughly an eighth of that.
- **The drawing buffer is memory too.** Canvas pixels × bytes per pixel, again per render target and per shadow map.
- **Load is bytes, then decode, then upload, then compile.** Each compression acts on one stage: meshopt and Draco on bytes, KTX2 on memory and upload, pre-warming on compile.
- **Heat has one fix.** A phone under sustained load throttles within minutes, and only doing less brings it back: fewer frames, fewer pixels, less work per frame.

Levers by term, the experiments that tell the terms apart and the symptom table: `references/performance.md`.

## Budget and proof

Write these before scene code, with the floor device named. They are defaults; the UX spec overrides them.

- **Smooth.** At least 99% of frame intervals within 1.5× the display interval, over a five-minute soak at the heaviest interaction. Count late frames: an average frame rate hides them.
- **Headroom.** p95 main-thread work per frame at most 70% of the interval.
- **Still is free.** With nothing moving, no frames are drawn.
- **First interaction.** The poster is the page's LCP image, the scene is interactive within 5 s on throttled 4G, and the host page's LCP and INP are no worse than without it.
- **Memory.** At most 256 MB of GPU memory on phones, back to baseline after ten mount and unmount cycles.
- **Failure.** No GPU, a failed load and a lost device each render something.

**Evidence, best first:** the floor device over remote debugging; a real-device lab; a desktop at the floor device's viewport and DPR with CPU throttling, which is a proxy. Throttling slows the CPU and not the GPU, so a proxy catches regressions and passes no gate. Label every number measured, proxy or unmeasured.

**Nothing to measure on?** A code-only task, or a subagent with no device and no browser, cannot produce these numbers, and must not invent them. State the cause from the code, label every figure unmeasured or arithmetic, and hand over the one measurement that would confirm it: which device, which interaction, which number.

**The spike comes before the features.** Put the skeleton and the heaviest asset on the floor device at the target DPR. If that alone takes half the frame or half the memory, re-decide now, while it is cheap: a lighter asset, a lower DPR cap, baked lighting, or no custom renderer at all.

## Size the stack

Start from the left column. A row whose trigger is absent is not built.

| The scene… | Add | Default, and what it costs |
|---|---|---|
| shows one model, with no custom shading or interaction | no renderer | `<model-viewer>`, or `<model>` where it exists. Its AR entry comes free |
| needs custom shading, composition or interaction | a renderer (hard to reverse) | Greenfield: `WebGPURenderer` from `three/webgpu`, which falls back to WebGL 2 by itself. `WebGLRenderer` when the code depends on GLSL, `onBeforeCompile` or an EffectComposer, when a needed library is WebGL-only, when thousands of draws cannot be batched, or for XR until WebGPU XR is verified on the headset |
| lives in a React app | React Three Fiber | The scene is declared in JSX; the loop stays imperative (`references/setup.md`) |
| needs a look no built-in material gives | TSL node materials | One source for both backends. GLSL only on a `WebGLRenderer` that stays one (`references/shaders.md`) |
| needs bloom, depth of field, ambient occlusion | a post-processing pipeline | Every effect is a full-screen pass: budget each on the floor device, none in XR |
| repeats an object more than a few dozen times | instancing, batching or merging | One draw for the group. Sharing geometry and materials alone saves no draws |
| moves | the cheapest rung that can do it | Shader time, then a few transforms, then skeletal animation; never framework state (`references/animation.md`) |
| has bodies that collide | Rapier, main thread | Fixed 60 Hz step, rendered interpolated. Its WASM is the largest download in the stack |
| holds roughly 1,000+ entities, or many composable behaviors | Koota ECS | State as data, systems as functions (`references/ecs.md`) |
| does per-element work on 10,000+ elements | TSL compute | The data never leaves the GPU. Limited on the WebGL 2 fallback |
| runs heavy CPU numerics, after a measured JavaScript baseline | Rust WASM | One call per frame over data that stays inside WASM |
| has a recurring job over about 15% of the frame, or a one-off longer than a frame | a worker | `postMessage` with transferables. Latency of a frame or more: never for what the user holds |
| needs shared memory between threads, measured | cross-origin isolation | Breaks OAuth and payment popups and blocks cross-origin assets: the 3D route only, with the `postMessage` path kept |
| enters VR or AR | WebXR | A mode added to a working scene (`references/xr.md`). Apple AR is Quick Look, not WebXR |
| shows a photoreal capture | Gaussian splats | The renderer choice decides the library (`references/assets.md` § Splats) |

The renderer row decides most of the others. Under `WebGPURenderer`, on either backend, a helper is WebGL-only when its source, or the file defining a binding it imports, matches `ShaderMaterial|RawShaderMaterial|onBeforeCompile|createDerivedMaterial|ShaderChunk`. Run that grep on every third-party helper before relying on it and again after upgrades; the lists in `references/landscape.md` go stale. Migrating a working WebGL scene needs a payoff you can name (TSL, compute, a WebGPU-only feature, a win measured on the floor device), because WebGPU is not automatically faster. It can go one material at a time (`references/shaders.md` § Migrating from GLSL).

## Build

1. **Budget and probe.** The targets above, the floor device named, the frame probe wired into the loop (`references/performance.md`).
2. **Skeleton before content** (`references/setup.md`).
   - Init failure shows the poster: no WebGPU and no WebGL 2, a denied adapter, a rejected `init()`.
   - Size comes from the container, never the window. DPR is capped at 2, lower on fill-bound phones.
   - One loop. It sleeps when nothing moves, when the canvas is off screen and when the tab is hidden. Workers and audio need their own pause: a hidden tab stops `requestAnimationFrame`, not them.
   - Device loss shows the poster and remounts.
   - Teardown frees GPU resources, loader caches and workers, then the renderer.
3. **A guest on the page.** three.js is code-split and loads on visibility or interaction. The poster is in the HTML and is the LCP image. The canvas never traps page scroll: horizontal drag rotates, vertical drag scrolls, or a tap-to-interact gate. One renderer per page; several views share one canvas. The canvas has an accessible name and a DOM alternative, and the scene honors `prefers-reduced-motion`.
4. **Assets, then the spike** (`references/assets.md`). Inspect, optimize, load with matching decoders, pre-warm behind the poster. Then run the spike from Budget and proof.
5. **The loop.** One clock, advanced once per frame, with its delta clamped: a gap over 100 ms is a pause, not a time step. No allocation, no framework `setState`, no scene-wide raycast per frame. Simulation at a fixed step, rendered by interpolating the last two states, or 90 and 120 Hz displays judder. Picking raycasts only pickable objects, on pointer events, with coordinates from the canvas rectangle.
6. **Motion** (`references/animation.md`). Each moving thing sits on the cheapest rung that can do it, advances by elapsed time and reports when it has settled, so the loop can sleep.
7. **Look.** On a new scene, tone mapping is set explicitly: Neutral where product color must match, AgX for a cinematic image. A small prefiltered environment map; static shadows baked or rendered once. Color is a chain that converts once, at the end (`references/setup.md` § Color). On an existing scene the look in place is the baseline: it changes only when asked.
8. **XR comfort.** Implement the UX spec's numbers. Where it is silent, ship teleport plus snap turn at a rate the floor headset holds, and list the gap.
9. **Verify.** Every Budget and proof number on the floor device, both backends where the renderer has two, then the tests (`references/testing.md`).

## Change a working scene

What works today is the baseline every change keeps.

1. **Record the baseline** before touching code: frames, memory, LCP, one reference view as an image.
2. **One change at a time,** compared on the same device in the same thermal state. A cold run against a hot baseline is noise.
3. **A new mode leaves the old path alone.** XR, a WebGPU path, a post-processing stack, a second view: until the user enters it, the existing path runs exactly as before, with no new startup probe or download and no changed renderer flag, shared loader or material. The mode applies its settings on entry and restores them on exit. Changing shared setup is a separate, named change with its own verification.
4. **Convert at one boundary.** When a mode imposes units, color handling or input the scene does not have, convert the content once, at a root group or in the asset pipeline, and never the engine-owned side (the camera, the XR rig, the reference space). Then list every value the boundary does not carry. For a scale s: camera near and far, fog range, point and spot intensity (× s²) and distance, shadow-camera bounds and bias, LOD distances, raycaster far, gravity and speeds, audio distances, control limits.
5. **Read what the engine does** with each value you will change, in the installed source, before writing code.

## Diagnose

Before changing code:

1. **Symptom and history.** The symptom in the user's words, and what changed before it appeared: an upgrade, an asset, a browser, a device. The lockfile diff and the git history show most of it. Reproduce it where it was seen.
2. **After an upgrade, diff the defaults.** Read the Migration Guide for every release crossed before tuning anything.
3. **Name the bound** (`references/performance.md` § Find the bound). Halve the resolution first. Where nothing can be run, fix only what is waste under any bound (a loop that never sleeps, an uncapped DPR, a 4096² texture, state set or memory allocated every frame), and leave every judgment call to the measurement.
4. **Strip the compensations** stacked on the root error (an exposure tweak, a light multiplier, a manual gamma, a lowered DPR) in the same change as the fix, or it corrects twice.
5. **Fix at the cause** with the smallest patch, and state each fix's isolated effect, before and after, on the same device.
6. **List the side effects** (other materials, custom shaders, brand colors, routes sharing the renderer or loader, visual baselines) and ship the guard that would have caught it (`references/testing.md` § Guards).

## Anti-patterns

| What gets written | Why it fails | Instead |
|---|---|---|
| `mesh.rotation.y += 0.01` in the loop | Speed follows the refresh rate: twice as fast at 120 Hz, half as fast on a throttled phone | `+= speed * dt` |
| `value = lerp(value, target, 0.1)` per frame | The same bug in disguise: the ease takes four times longer at 30 Hz than at 120 | `MathUtils.damp(value, target, lambda, dt)` |
| `setState` in `useFrame`, or a prop that changes every frame | React re-renders at the display's rate | Mutate a ref |
| A render loop that runs while nothing moves | Burns battery and heats the phone for an unchanged picture | Draw on demand; sleep when settled |
| "Optimizing" before finding the bound | Merging geometry does nothing for a fill-bound scene, and a lower DPR nothing for a draw-bound one | Halve the DPR, then decide |
| Average fps as the pass criterion | 55 fps on average hides a dropped frame every second | Late frames against the interval |
| A desktop number reported as the result | A desktop GPU hides every phone problem | The floor device, or the word proxy |
| PNG or JPEG textures in a GLB, 4096² | 89 MB of GPU memory each, and an upload hitch | KTX2, capped at 2048 on phones |
| `new Vector3()` inside the loop | Garbage collection pauses arrive as dropped frames | Module-scope scratch objects |
| A second `requestAnimationFrame` loop, or a tween library on its own ticker | Two clocks: updates land a frame late, and an on-demand loop never wakes | One loop drives everything |
| An API written from memory | It was renamed, deprecated or changed its default since | Read it in `node_modules` first |
| Exposure and light multipliers added to "fix" color after an upgrade | The root error stays and the next fix double-corrects | Find the link in the color chain |
| `removeFromParent()` as cleanup | Frees no GPU memory | Dispose geometry, materials and textures |
| A capability probe for every visitor at startup | Costs everyone for a mode few enter | Probe where the mode is entered |
| A device tier from the user agent | Wrong within a year, and wrong today for half the devices | Tiers from measured frame time |

## Report

Write for whoever asked, in their terms, and lead with what they will see change.

- **Numbers:** target against measured, or each change's isolated effect before and after on the same device, each labeled measured, proxy or unmeasured.
- **Decisions:** the choice, its reason, what was rejected, and what was left untouched on purpose.
- **Limits:** unsupported platforms, what each failure path shows, UX-spec gaps, and each open question with its default.

Never report a proxy as a pass, and never narrate this skill's steps.

## Checklist

For a small change, check the rows it touches and report the rest.

- [ ] The budget is written with the floor device named, and every number is labeled measured, proxy or unmeasured.
- [ ] Nothing moving means no frames drawn; off screen and hidden mean no work.
- [ ] The bound was named by experiment before any optimization, and each fix states its isolated effect.
- [ ] Per frame: no allocation, no `setState`, no scene-wide raycast; one clock with a clamped delta; fixed-step simulation, interpolated.
- [ ] Every motion advances by elapsed time and looks the same at 30, 60 and 120 Hz.
- [ ] Assets were inspected and compressed, the first interaction compiles and uploads nothing, and teardown returns memory to baseline.
- [ ] No GPU, a failed load and a lost device each render something.
- [ ] three.js is code-split, the poster is the LCP image, page scroll is never trapped, and reduced motion is honored.
- [ ] Every tagged or non-default API was confirmed in the installed version; third-party helpers pass the grep; both backends ran.
- [ ] On an existing scene: baseline recorded, existing paths unchanged, compensations removed, side effects listed, guard shipped.
- [ ] Every layer beyond renderer and scene graph names its trigger.

## References

Read a file when the task reaches it.

| File | Holds |
|---|---|
| `references/performance.md` | The frame probe, finding the bound, levers by term, the resolution governor, the symptom table |
| `references/animation.md` | Where motion runs, time-based math, on-demand motion, scroll-linked scenes, skeletal cost, one clock |
| `references/setup.md` | The scene skeleton in three.js and in React Three Fiber, the poster gate, picking, color, audio |
| `references/assets.md` | The glTF pipeline, the CI gate, loading, textures, generated and scanned assets, splats, pre-warm, dispose |
| `references/shaders.md` | TSL, node materials, compute, post-processing, migrating from GLSL |
| `references/physics.md` | Rapier: the fixed-step loop, API traps, React bindings, the worker path |
| `references/ecs.md` | Koota: traits, queries, change detection, React hooks |
| `references/offload.md` | Workers, shared memory and isolation, bundler config, Rust WASM |
| `references/xr.md` | WebXR backends, adding XR to a scene, session and input, React bindings, Quick Look |
| `references/testing.md` | Test tiers, guards, a GPU in CI |
| `references/landscape.md` | Dated facts: verified versions, platform support, measurements, WebGL-only helpers, what is changing |
