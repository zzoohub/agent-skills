# Performance: Budget, Diagnosis, Levers

Framework-agnostic. R3F specifics: `react/performance.md`.

## Budget

Frame budget = 1000 / refresh rate ms on the floor device (16.7 at 60 Hz, 11.1 at 90, 8.3 at 120); an interval over 1.5× the target is a dropped frame.

**Frame probe.** Ship it with the first build; every gate reads it.

```ts
// frameProbe.ts: begin(t) first and end(t) last in the loop callback, t = its timestamp
const N = 1024, gap = new Float32Array(N), work = new Float32Array(N)
let gaps = 0, frames = 0, prev = -1, hz = 60
export const setHz = (v: number) => { hz = v }               // in XR: the session's frame rate
export function calibrate(done: () => void) {                // behind the poster, before the scene mounts
  const d: number[] = []; let last = -1
  const tick = (t: number) => {
    if (last >= 0) d.push(t - last)
    last = t
    if (d.length < 60) { requestAnimationFrame(tick); return }
    hz = 1000 / d.sort((a, b) => a - b)[30]; done()          // median interval: the display's rate
  }
  requestAnimationFrame(tick)
}
export const begin = (t: number) => { if (prev >= 0) gap[gaps++ % N] = t - prev; prev = t }
export const end = (t: number) => { work[frames++ % N] = performance.now() - t }
export const reset = () => { prev = -1 }                      // after any pause
export function report() {                                   // never per frame: it sorts
  const n = Math.min(gaps, N), m = Math.min(frames, N), late = 1.5 * 1000 / hz
  let drops = 0
  for (let i = 0; i < n; i++) if (gap[i] > late) drops++
  const w = Array.from(work.subarray(0, m)).sort((a, b) => a - b)
  return { hz, onTimePct: 100 * (1 - drops / Math.max(n, 1)), p95WorkMs: w[Math.floor(0.95 * (m - 1))] }
}
;(globalThis as any).__frameProbe = report                   // remote DevTools and Playwright
```

**Evidence**, best first: the floor device over remote debugging; a real-device cloud lab; desktop at the floor device's viewport and DPR with DevTools CPU throttling, labeled proxy. Throttling slows the CPU, not the GPU, so a proxy catches regressions but passes no gate.

**Headroom and the asset brief.** Draw calls and triangles have no portable limit. In the spike (SKILL.md, Build step 4), add copies of the heaviest asset until frames drop: under two copies held means it alone takes over half the budget. The breakpoint caps the scene; per-asset shares of it brief the artists. Before any device number exists, brief phone hero assets to Google's Scene Viewer guidance (developers.google.com/ar/develop/scene-viewer, 2026-10: ≤ 100k triangles, 30–50k ideal; ≤ 10 materials; textures ≤ 2048 px) and Quest assets below Meta's native-app ranges (developers.meta.com/horizon/documentation/unity/unity-perf/), since WebXR adds JavaScript cost per draw.

**Counters**, read once per frame:

| | `WebGPURenderer` | `WebGLRenderer` |
|---|---|---|
| Draws this frame | `info.render.drawCalls` (`calls` counts `render()` calls since start) | `info.render.calls` |
| Triangles | `info.render.triangles` | `info.render.triangles` |
| GPU memory | `info.memory.total`, `texturesSize` (bytes) | `info.memory.geometries`, `textures` (counts only) |

On `WebGLRenderer`, GPU memory is an estimate and labeled one: `inspect` `gpuSize` totals, plus the drawing buffer ((w·DPR) × (h·DPR) × 8 B × MSAA samples), plus each render target and environment map (w × h × bytes per texel, × 1.33 with mipmaps).

**Draw-call model.** Each visible mesh costs one draw per material group per pass. Each shadow-casting light adds a shadow pass, transmission adds a pass, and XR without multiview draws everything once per eye (`web-xr.md` § Backend first). Sharing geometry and materials saves state changes and shader compiles, not draws; instancing and merging cut the count. `BatchedMesh` (many geometries, one material) is one multi-draw on WebGL 2; on the WebGPU backend it issues one draw per item while `info` counts one (checked r186), saving JavaScript and state changes there, not GPU draws.

## Diagnosis

**Slow to interactive** is a loading problem: in the network waterfall, the three.js chunk, model, decoder and transcoder WASM and HDRI should start in parallel (`<link rel="preload">`, `useGLTF.preload`) and weigh what `inspect` predicts. `.glb` files should arrive with `content-encoding: br` or `gzip` (meshopt output is built to compress further) from hashed URLs cached immutable. Then check main-thread parse, then compile and upload (pre-warm, `assets.md`). Slow or janky frames:

1. **Reproduce.** Over 30 s of the slow interaction, record drops and p95 main-thread work (frame probe), `renderer.info`, and a DevTools Performance trace over remote debugging. Compare a fix with its baseline on the same device and thermal state (run until frame time stops climbing), alternating the A/B order: a cold run against a hot baseline is noise. GPU time: three's Inspector addon (r181+; `renderer.inspector = new Inspector()`, from `three/addons/inspector/Inspector.js`) or stats-gl where the browser exposes timer queries, else unmeasured. Timing `render()` on the CPU measures submission only.
2. **Halve DPR.** If frame time drops, the scene is fill-bound: cap DPR (1.5 on phones), cut overdraw and stacked transparency, full-screen passes and heavy fragment work.
3. **Flat means not fill-bound.** Main thread busy for most of the interval: CPU-bound. Many draws → instancing, `BatchedMesh`, merging, atlases; heavy script → allocations, raycasts, framework re-renders, per-element WASM calls. Main thread idle but frames late: GPU work that ignores DPR. Toggle each fixed-size job (shadow maps via `autoUpdate = false`, each post pass, compute) and look for synchronous readbacks (`readPixels`, `getBufferSubData`, awaited per-frame reads) before blaming geometry: triangles × passes (Draw-call model), skinning, morph targets → LOD, simplification, fewer casters, a tighter shadow camera.
4. **Hitches, not slowness**, by cause: shader compile → `compileAsync` before interaction; texture upload → KTX2 plus `initTexture`; garbage collection → no allocation in the loop.
5. **Soak, then remount.** Five minutes at the heaviest interaction, then 10 mount/unmount cycles: `info.memory` must return to baseline. Frame time that climbs with elapsed time is heat: lower DPR or detail first; pace to a lower divisor only outside XR and where the UX spec allows.

| Symptom | Likely cause | Check |
|---|---|---|
| Washed out, too dark, hues shifted | A link in the output chain, often after an upgrade | § Color and output, in order |
| Model black or missing | Metal with no `scene.environment`; no lights; outside the frustum (CAD in millimeters arrives 1000× too big); decoder or transcoder 404 | Bounding box against camera near and far; network panel |
| Flicker on coplanar or distant surfaces | Depth precision | Raise `camera.near` first; then a reversed depth buffer (`WebGLRenderer` `reversedDepthBuffer` r179+, `reverseDepthBuffer` r169–r178, needs `EXT_clip_control`; `WebGPURenderer` r183+); `logarithmicDepthBuffer` last, since per-fragment depth defeats early-z |
| Objects vanish at some angles | Stale bounds after instance writes, skinning or `positionNode` displacement | `computeBoundingSphere()` after writes, or `frustumCulled = false` |
| Black or frozen canvas after minutes | Device or context loss | Did `onDeviceLost` or `webglcontextlost` fire? |
| Judder at 90/120 Hz while fps reads fine | Fixed step rendered without interpolation | Bodies move in 60 Hz increments |
| Locked at exactly 30 fps on iOS | iOS Low Power Mode, or Safari throttling a cross-origin iframe until the first tap | Retest outside both; not the scene |
| "Too many active WebGL contexts" | Renderers never disposed; browsers cap live contexts | One renderer per page; dispose on unmount |
| "Enter VR" throws | WebGPU backend in XR | `renderer.backend.isWebGPUBackend`; `web-xr.md` § Backend first |
| XR world giant or tiny, or clipped near the face | Scene units aren't meters; near and far tuned for other units | `web-xr.md` § Adding XR to an existing scene |
| XR colors differ from the page | Post stack bypassed in XR; custom shaders lack the output chunks | Same section, Output transform |
| Shadows, lines, sky or text missing under WebGPU | WebGL-only helper | The grep rule (SKILL.md, Decide) |
| `SharedArrayBuffer` undefined in production | Isolation headers missing on the host | `crossOriginIsolated` |
| WASM in a worker fails only in the build | `worker.plugins` missing | `threading.md` § Vite config |

## Color and output

Wrong color is a chain fault: check the links in order and stop at the first wrong one.
1. **Texture tags.** Color maps (base color, emissive) `SRGBColorSpace`; data maps (normal, ORM) `NoColorSpace`. `GLTFLoader` sets them; textures loaded by hand need it.
2. **Colors in code.** `setHex` and CSS strings read sRGB; `setRGB(r, g, b)` reads the linear working space, so design-tool values need `SRGBColorSpace` as a fourth argument.
3. **Lights and environment.** Physical light units (legacy mode removed in r165); `scene.environmentIntensity` (r163+) scales the environment, `envMapIntensity` only a material's own `envMap`.
4. **Tone mapping.** Set `renderer.toneMapping` explicitly (R3F defaults to ACES Filmic, which shifts saturated product hues; Neutral keeps them); `toneMapped = false` on UI and unlit brand colors.
5. **Output.** sRGB conversion happens once, on the final write. With a post stack the last pass tone-maps and converts (`OutputPass`, or `RenderPipeline`'s output transform) and every earlier pass stays linear; custom GLSL writing to the screen needs `#include <tonemapping_fragment>` and `#include <colorspace_fragment>`.

**After an upgrade**, read three's Migration Guide (github.com/mrdoob/three.js/wiki/Migration-Guide) for every release crossed before tuning. Look-changing defaults so far: r152 (color management on, sRGB output, `Texture.colorSpace`), r155 (physical lights by default; tone mapping only on screen output, `OutputPass` in post stacks), r163 (`environmentIntensity`), r183 (`Sky` without its legacy gamma). Code written before each change often carries compensations (intensity multipliers, gamma passes, hand-converted colors, exposure tweaks): remove them with the fix, then re-baseline screenshots once the look is approved.

## Levers

- **Frame pacing.** Outside XR, a scene that can't hold the native rate even after DPR and detail cuts renders every second rAF (or every Nth) and lets the fixed-step loop absorb the longer interval: a steady 60 on a 120 Hz screen beats a wandering 70–120.
- **Adaptive resolution.** Step DPR down after sustained overrun and up only after sustained headroom (hysteresis); `setPixelRatio` reallocates the drawing buffer, so call it only when the value changes.
- **Shadows.** One shadow-casting light, tight shadow-camera bounds, the smallest map that looks right; a static scene renders it once (`light.shadow.autoUpdate = false`, then `needsUpdate = true` on change).
