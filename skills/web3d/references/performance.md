# Performance: Probe, Bound, Levers

The cost model is in SKILL.md § The cost of a frame. This file is how to measure it, how to tell which term binds, and what to pull for each. Measured numbers behind the claims: `landscape.md` § Measurements.

## The frame probe

Ship it with the first build. Every gate in SKILL.md § Budget and proof reads it.

```ts
// perf/frame-probe.ts
// begin(t) first and end(t) last in the loop callback, t = its timestamp
const N = 1024, gap = new Float32Array(N), work = new Float32Array(N)
let gaps = 0, frames = 0, prev = -1, hz = 60

export const setHz = (v: number) => { hz = v } // in XR: the session's frame rate

export function calibrate(done: () => void) { // behind the poster, before the scene mounts
  const d: number[] = []
  let last = -1
  const tick = (t: number) => {
    if (last >= 0) d.push(t - last)
    last = t
    if (d.length < 60) { requestAnimationFrame(tick); return }
    hz = 1000 / d.sort((a, b) => a - b)[30] // median interval: the display's rate
    done()
  }
  requestAnimationFrame(tick)
}

export const begin = (t: number) => { if (prev >= 0) gap[gaps++ % N] = t - prev; prev = t }
export const end = (t: number) => { work[frames++ % N] = performance.now() - t }
export const reset = () => { prev = -1 } // after any pause, and when an on-demand loop restarts

export function report() { // never per frame: it sorts
  const n = Math.min(gaps, N), m = Math.min(frames, N), late = 1.5 * 1000 / hz
  let drops = 0
  for (let i = 0; i < n; i++) if (gap[i] > late) drops++
  const w = Array.from(work.subarray(0, m)).sort((a, b) => a - b)
  return { hz, frames: n, onTimePct: 100 * (1 - drops / Math.max(n, 1)), p95WorkMs: w[Math.floor(0.95 * (m - 1))] ?? 0 }
}

;(globalThis as { __frameProbe?: typeof report }).__frameProbe = report // remote DevTools and Playwright
```

- **Wiring.** `begin(t)` first and `end(t)` last in the loop callback. In React Three Fiber, `addEffect(begin)` and `addAfterEffect(end)`: both receive the frame timestamp and return an unsubscribe.
- **An on-demand loop** has long gaps by design. Call `reset()` whenever the loop goes to sleep, or every wake-up counts as a late frame.
- **`calibrate()`** runs behind the poster, before the scene mounts. A busy main thread during load stretches the intervals, so calibrate before the heavy imports, not during them.
- **What the display rate is not.** A 120 Hz phone does not always give the page 120 frames (`landscape.md` § Frame rate), and a headset's rate is the session's. The probe measures what the page actually gets.

**GPU time.** `new WebGPURenderer({ trackTimestamp: true })`, then `await renderer.resolveTimestampsAsync('render')` every few frames returns the GPU milliseconds of the render passes, where the browser exposes timer queries. In development, three's Inspector (r181+: `renderer.inspector = new Inspector()` from `three/addons/inspector/Inspector.js`) shows the same per pass. Without timer queries GPU time is unmeasured: timing `render()` on the CPU measures submission only.

**Counters**, read once per frame:

| | `WebGPURenderer` | `WebGLRenderer` |
|---|---|---|
| Draws this frame | `info.render.drawCalls` (`calls` counts `render()` calls since start) | `info.render.calls` |
| Triangles | `info.render.triangles` | `info.render.triangles` |
| GPU memory | `info.memory.total` in bytes, with a gap: `landscape.md` § Measurements | `info.memory.geometries` and `textures`, counts only |

Where the renderer cannot say, GPU memory is an estimate and labeled one: the `gpuSize` totals from `gltf-transform inspect`, plus the drawing buffer (canvas pixels × bytes per pixel × MSAA samples), plus each render target, shadow map and environment map (w × h × bytes per texel, × 1.33 with mipmaps).

## Find the bound

Reproduce first: 30 s of the slow interaction on the device where it was seen, recording late frames and p95 main-thread work (the probe), the counters, and a DevTools Performance trace over remote debugging. Then run the experiments in order and stop at the first that moves the frame time.

| Experiment | If the frame time… | The bound is |
|---|---|---|
| Halve the resolution: `renderer.setPixelRatio(dpr / 2)` | drops roughly in proportion | **pixels** |
| Look at the main thread in the trace | stays flat, and the thread is busy for most of the interval | **script** or **draw submission**: time inside `render()` is draws, time in your own code is script |
| | stays flat, and the thread is idle while frames are late | GPU work that ignores resolution: **vertices**, fixed-size shadow maps, compute, a synchronous readback |
| Hide half of the objects | halves | draws or vertices, by the row above |
| `scene.overrideMaterial = new MeshBasicMaterial()` | drops | shading: lights, material features, textures |
| Turn off one pass at a time: shadows (`light.shadow.autoUpdate = false`), each post effect | drops | that pass |
| Look at the frame-time graph | is fine except single long frames | a **hitch**: compile, upload, garbage collection, readback |

Compare a fix with its baseline on the same device in the same thermal state (run until the frame time stops climbing), alternating the order. A cold run against a hot baseline is noise.

## Levers by term

**Frames not drawn** (always first)
- Draw on demand: the loop sleeps when nothing moves (`setup.md`). A product viewer is still most of the time.
- No work off screen or in a hidden tab, workers and audio included.
- Outside XR, a scene that cannot hold the display's rate after every cut below renders every second frame and lets the fixed-step loop absorb the longer interval. A steady 60 on a 120 Hz screen beats a wandering 70 to 120.

**Pixels**
- Cap DPR at 2, at 1.5 or lower on fill-bound phones, and let the governor below find the level a device holds.
- Count the full-screen passes and cut them: each post effect, each transmission pass, each reflection. Run an effect at half resolution where it survives it (`pass.setResolutionScale(0.5)`, r181+).
- Cut overdraw: stacked transparent layers and screen-filling particles pay per layer per pixel.
- Cheaper shading: every light, and each of clearcoat, transmission, sheen and iridescence, is paid per pixel.
- Antialias with MSAA on the canvas; a post-processing antialias is one more full-screen pass.
- `WebGPURenderer` draws into an intermediate target whenever tone mapping or an sRGB output is on, which is always. It is half float by default; `outputBufferType: UnsignedByteType` cuts that buffer's memory by a third for a small GPU gain, at the price of banding in dark gradients and under bloom. A lever for a memory-bound phone, not a default.

**Draw submission**
- `InstancedMesh` for copies of one geometry, `BatchedMesh` for different geometries under one material, merged geometry for static sets that never move apart. Sharing geometry and materials without these saves shader compiles, not draws.
- Fewer material groups: a texture atlas lets many meshes share one material and then merge.
- Static objects: `matrixAutoUpdate = false` after placing them.
- Every shadow-casting light submits its casters again, a point light six times. One shadow-casting light, and only the casters that matter.
- `BundleGroup` (WebGPU backend only) records a static group once. It moves the draw cost off the main thread; it does not remove it.
- On phones plan for hundreds of draws, not thousands. The spike gives the real number: add copies of the heaviest asset until frames drop.

**Vertices**
- Level of detail (`THREE.LOD`) and simplification in the asset pipeline; brief artists from the spike's breakpoint.
- Shadow casters are drawn again: a tight shadow camera, low-detail casters for dense meshes, and the smallest map that looks right. Start at 1024 for a single product and go up only when the edge shows: each doubling is four times the memory (`landscape.md` § three.js).
- Skinning and morph targets cost per vertex per pass: `animation.md` § Skeletal animation.

**Script**
- No allocation in the loop: module-scope scratch vectors, typed arrays allocated once.
- Per-entity work in flat arrays (`ecs.md`), per-element math on the GPU (`shaders.md` § Compute), heavy numerics in WASM, long one-off jobs in a worker (`offload.md`). Each only past its trigger.
- React: nothing in the loop re-renders (`setup.md` § React Three Fiber).

**Hitches**
- Compile and upload behind the poster (`assets.md` § Pre-warm). KTX2 uploads without a decode on the main thread.
- No synchronous readback: `readRenderTargetPixelsAsync`, and never per frame.

**Memory**
- KTX2 and a texture size cap come first; then DPR (the drawing buffer), shadow-map sizes and the number of render targets.
- Dispose what a scene created (`assets.md` § Dispose) and prove it with the remount test.

**Load**
- Poster first; three.js and the scene in their own chunk, fetched on visibility or interaction (`setup.md`).
- The chunk, the model, the transcoder and decoder WASM and the environment map start in parallel (`<link rel="preload">`), from hashed URLs cached immutable. A `.glb` should arrive with `content-encoding: br` or `gzip`: meshopt output is built to compress further.
- Know what each dependency weighs before adding it (`landscape.md` § Download weight).

**Heat**
- The soak test finds it: frame time that climbs with elapsed time. Lower resolution and detail first, then pace to a divisor of the display rate. In XR, lower the session's frame rate rather than miss it.

## The resolution governor

Frame intervals cannot show headroom under vsync, so stepping resolution up is always a guess. This governor steps down after sustained late frames, tries one step up only after a long calm, and remembers a level that failed its trial, so it settles instead of oscillating.

```ts
// perf/dpr-governor.ts
// Lowers resolution after sustained late frames, raises it only after a long calm, and never returns to a level that failed its trial.
export function createDprGovernor(apply: (dpr: number) => void, max = Math.min(devicePixelRatio, 2), min = Math.min(1, max), step = 0.25) {
  let dpr = max, ceiling = max, frames = 0, late = 0, calm = 0, proven = false
  apply(dpr)
  return (intervalMs: number, budgetMs: number) => { // once per drawn frame, while the loop runs
    if (intervalMs > budgetMs * 1.5) late++
    if (++frames < 60) return
    if (late > 6) { // over 10% of the window was late: this level does not hold
      if (!proven) ceiling = Math.max(min, dpr - step) // it never held, so never come back to it
      if (dpr > min) apply(dpr = Math.max(min, dpr - step))
      calm = 0
      proven = false
    } else if (late > 0) calm = 0
    else if (++calm >= 10) { // ten clean windows: the level holds, try the next one up
      calm = 0
      proven = dpr >= ceiling
      if (!proven) apply(dpr = Math.min(ceiling, dpr + step))
    }
    frames = late = 0
  }
}
```

`apply` is `renderer.setPixelRatio` followed by a redraw. It reallocates the drawing buffer, which is why it runs only on a change. Feed the governor only while the loop is drawing continuously: an on-demand loop's idle gaps are not late frames. In React Three Fiber:

```tsx
// perf/Governor.tsx
import { useFrame, useThree } from '@react-three/fiber'
import { useMemo } from 'react'
import { createDprGovernor } from './dpr-governor.ts'

export function Governor({ hz }: { hz: number }) { // hz: the display's rate, from the frame probe's calibrate()
  const setDpr = useThree((s) => s.setDpr)
  const tick = useMemo(() => createDprGovernor(setDpr), [setDpr])
  useFrame((_, delta) => { if (delta < 0.1) tick(delta * 1000, 1000 / hz) }) // a longer gap is a pause, not a late frame
  return null
}
```

drei's `PerformanceMonitor` does a similar job with different defaults: its `[40, 60]` bounds decline only once most samples fall under 40 fps, far past the budget, and `AdaptiveDpr` moves only when something calls `regress()`.

## Soak and remount

- **Soak.** Five minutes at the heaviest interaction on the floor device, probe running. Late frames within the budget, and frame time flat rather than climbing.
- **Remount.** Ten mount and unmount cycles. `info.memory` returns to baseline; a count that grows is a leak (`assets.md` § Dispose).

## Symptoms

| Symptom | Likely cause | Check |
|---|---|---|
| Slow to interactive | Loading, not rendering | The network waterfall: do the chunk, model, decoders and environment start in parallel and weigh what `inspect` predicts? Then main-thread parse, then compile and upload |
| Stutter on the first rotation or the first option change | Shader compile or texture upload at first use | `assets.md` § Pre-warm |
| Smooth on desktop, slow full-screen on phones | Pixels | Halve the DPR |
| The page will not scroll, or scrolls badly, with a finger on the canvas | The canvas takes vertical drags: orbit controls set `touch-action: none` | `setup.md` § A guest on the page |
| Slow with a simple look and many objects | Draw submission | `info.render` draws; instancing |
| Motion faster or slower on another device | A per-frame increment or a per-frame lerp | `animation.md` § Time |
| Judder at 90 or 120 Hz while the frame rate reads fine | A fixed step rendered without interpolation | Bodies move in 60 Hz increments |
| A jump at the start of every interaction | The first delta after an idle on-demand loop is the whole pause | `setup.md` § React Three Fiber |
| Locked at exactly 30 fps on iOS | Low Power Mode, thermal mitigation, or a cross-origin iframe before its first tap | Retest outside all three; not the scene |
| Phone warm, frame time climbing over minutes | Heat | The soak; the loop running while nothing moves |
| Memory grows with every navigation | Resources never disposed | The remount test |
| "Too many active WebGL contexts" | Renderers never disposed; browsers cap live contexts | One renderer per page, disposed on unmount |
| Black or frozen canvas after minutes | Device or context loss | Did `onDeviceLost` or `webglcontextlost` fire? |
| Washed out, too dark, hues shifted | A link in the color chain, often after an upgrade | `setup.md` § Color, in order |
| The look shifted after an upgrade with no code change | A default changed | `landscape.md` § Look-changing releases |
| Model black or missing | A metal with no `scene.environment`; no lights; outside the frustum (CAD in millimeters arrives 1000× too big); a decoder or transcoder 404 | The bounding box against camera near and far; the network panel |
| Flicker on coplanar or distant surfaces | Depth precision | Raise `camera.near` first; then `reversedDepthBuffer` (`WebGLRenderer` r179+, `WebGPURenderer` r183+); `logarithmicDepthBuffer` last, since it defeats early-z |
| Objects vanish at some angles | Stale bounds after instance writes, skinning or vertex-stage displacement | `computeBoundingSphere()` after writes, or `frustumCulled = false` |
| Shadows, lines, sky or text missing under `WebGPURenderer` | A WebGL-only helper | The grep in SKILL.md § Size the stack |
| "Enter VR" throws | A WebGPU backend in XR | `xr.md` § Backend first |
| XR world giant or tiny, or clipped near the face | Scene units are not meters | `xr.md` § Adding XR to an existing scene |
| `SharedArrayBuffer` undefined in production | Isolation headers missing on the host | `crossOriginIsolated`; `offload.md` |
| WASM works in the build and fails in development, or the reverse | Bundler handling of the WASM import | `offload.md` § Bundler config |
| A worker never answers | The message was posted before the worker's module finished loading | `offload.md` § Workers |
| Console warnings about `THREE.Clock` or `PCFSoftShadowMap` in a React Three Fiber app | The library's defaults on a newer three.js | `landscape.md` § React Three Fiber; not your code |
