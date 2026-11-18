# Landscape: Dated Facts

**Last verified: 2026-11-18.** Everything in this skill that can go stale lives here: versions, platform support, measurements, lists of what is WebGL-only, and what is about to change. The other files hold what does not move. A "(rNNN+)" tag elsewhere is permanent, because an API introduced in a release stays introduced; a "not yet" belongs here, because it expires.

Each entry says how it was established: **ran** (executed or measured for this file), **source** (read in the installed package), **BCD** (MDN browser-compat-data 8.1.9, 2026-11-12), **notes** (vendor release notes or documentation). Refresh this file instead of scattering new facts: re-check versions with `npm view`, read three's Migration Guide from the last verified release forward, and re-run what is marked ran.

## Verified versions

| Package | Version | Notes |
|---|---|---|
| three | 0.187.0 (r187, 2026-10-30) | Every example in this skill ran on it, on both backends where it has two |
| @react-three/fiber | 9.8.2 | 10.0.0-alpha.6 exists (§ React Three Fiber) |
| @react-three/drei | 10.7.9 | 11.0.0-alpha.7 exists, for fiber 10 |
| @react-three/xr | 6.6.32 | Never requests the `'webgpu'` session feature (source) |
| @react-three/rapier | 2.2.0 | Pins `@dimforge/rapier3d-compat` 0.19.2 (source) |
| @dimforge/rapier3d, -compat | 0.21.0 | `convexHull` on a degenerate point set returns a descriptor and `createCollider` throws `expected instance of …` (ran). Adds soft bodies (notes) |
| koota | 0.6.6 | The change-detection table in `ecs.md` (ran) |
| @gltf-transform/cli | 4.5.1 | `optimize` flags as in `assets.md` (ran). Needs KTX-Software 4.4 or later (notes) |
| meshoptimizer | 1.3.0 | Decoder used by the CI gate (ran) |
| vite | 8.3.8 | § Tooling |
| gsap | 3.15.1 | Driven from the loop as in `animation.md` (ran). Free for commercial use, former Club plugins included (notes) |
| react | 19.3.1 | |
| Browser | Chrome 157 on macOS, Apple M5 Pro | WebGPU (Metal) and the WebGL 2 fallback |

## three.js

- **An internal loop that never stops.** `WebGPURenderer.render()` starts an internal `requestAnimationFrame` loop for bookkeeping, and `setAnimationLoop(null)` only clears the callback: one callback per display frame keeps running until `dispose()` (source, ran). `WebGLRenderer.setAnimationLoop(null)` does stop. On-demand rendering therefore means skipping `render()`.
- **An intermediate target.** `WebGPURenderer` draws into a half-float target and copies it to the canvas whenever tone mapping or an sRGB output is on (source). It costs 12 bytes per canvas pixel with depth: 11 MB at 1280×720, 44 MB at 2560×1440, and 29.5 MB there with `outputBufferType: UnsignedByteType` (ran).
- **`renderer.info.memory` counts a compressed texture as 1 byte** (source). With KTX2 assets, add the `gpuSize` that `gltf-transform inspect` reports. Counts still work for the leak test.
- **A 2048² shadow map adds about 33 MB** to `info.memory.total` under `WebGPURenderer` (ran): 8 bytes per texel, so about 8 MB at 1024² and 134 MB at 4096² by the same arithmetic.
- **`compileAsync` yields to the main thread** between pipelines (r184+, source).
- **XR.** A WebGPU-backend session needs the `'webgpu'` session feature and `XRGPUBinding`. WebGPU XR has no multiview yet, and classic `WebGLRenderer` has no multiview option; `WebGPURenderer({ forceWebGL: true, multiview: true })` is the one path to it (source). `VRButton`, `ARButton` and `XRButton` call `isSessionSupported` and `offerSession` when created; controller and hand models load from cdn.jsdelivr.net (source).
- **Node materials under `WebGLRenderer`:** `renderer.setNodesHandler(new WebGLNodesHandler())`, r184+, beside GLSL materials in one scene (ran).
- **New addons since r184** (source, not run except where noted): `HTMLTexture` (r184, a DOM element as a texture), `GaussianSplat` and its loaders (r186, ran), glTF `KHR_gaussian_splatting` (r187), meshlet and visibility-buffer drawing pipelines, clustered lighting, light-probe grids, TAAU and FSR upscaling nodes, `JXLLoader` (r187). New renderer features land as TSL for `WebGPURenderer`; `WebGLRenderer` gets fixes.
- **`Object3D.dispose()`** exists from r186 and frees per-object GPU data only. The renderers' use of `WeakRef` (r187) is bookkeeping: nothing is freed on garbage collection (source).

## Look-changing releases

Read the Migration Guide entry before tuning anything after crossing one of these: r152 (color management on, sRGB output), r155 (physical lights by default; tone mapping only on screen output), r163 (`environmentIntensity`), r181 (PBR indirect specular and energy conservation: rough materials brighter), r183 (`WebGPURenderer` shadows: old bias values over-correct; `RoomEnvironment`; `Sky` loses its legacy gamma), r184 (environment and background rotation), r185 (`WebGPURenderer` premultiplied alpha: prefer an opaque background; ambient occlusion darker), r186 (`PCFSoftShadowMap` removed under `WebGPURenderer`), r187 (prefiltered environment maps rebuilt: materials shift slightly), r188, upcoming (environment irradiance on rough materials).

## React Three Fiber

- **9.8.2 on r187** renders through `WebGPURenderer` with an async `gl` factory on both backends (ran). It logs two warnings that come from its own defaults, not from application code: `THREE.Clock … deprecated` and `PCFSoftShadowMap has been removed`.
- **The first `delta` after an idle `frameloop="demand"` canvas is the whole pause:** 2.1 s measured (ran).
- **`interface ThreeElements extends ThreeToJSXElements<typeof THREE>`** for `three/webgpu` no longer type-checks against @types/three 0.187 (ran). Register node classes one by one (`shaders.md`).
- **Version 10** (10.0.0-alpha.6, 2026-10-17; source): `<Canvas>` renders with `WebGPURenderer` by default and WebGL moves to `@react-three/fiber/legacy`; `state.gl` becomes `state.renderer`; `state.clock` is gone (`state.elapsed`, `state.delta`); `useFrame` takes phases and a fixed-step physics phase from a new scheduler; peer three ≥ 0.185. drei 11 alpha splits into `/webgpu` and `/legacy` entries. Not a production target yet.

## WebGL-only helpers

Fail the grep in SKILL.md § Size the stack, so they need `WebGLRenderer`. Lists go stale: re-run the grep.

| Library | Status | Under `WebGPURenderer` instead |
|---|---|---|
| drei 10.7.9: about 35 helpers (ran: 16 match directly, the rest through an imported binding) | Materials (`MeshTransmissionMaterial`, `MeshReflectorMaterial`, `MeshDistortMaterial`, `MeshWobbleMaterial`, `shaderMaterial`); shadows (`ContactShadows`, `AccumulativeShadows`, `SoftShadows`, and so `Stage`); `Line`, `Edges`, `Segments`; `Sky`; `Sparkles`, `Stars`, `Cloud`, `Grid`, `Outlines`, `Image`, `Caustics`, `SpotLight`; `Text` | Node materials (`MeshPhysicalNodeMaterial` with `transmission`, a `positionNode` displacement); a baked shadow, or a plane with `ShadowNodeMaterial`; `Line2` from `three/addons/lines/webgpu/`; `SkyMesh`; TSL rebuilds |
| troika-three-text 0.53 | No `WebGPURenderer` support; a TSL port is an open issue (notes) | A `CanvasTexture` label, or `<Html>` outside XR |
| @react-three/uikit 1.x | Stays `WebGLRenderer`-only; 2.0 is planned for `WebGPURenderer` with HTML-in-canvas (notes) | Nothing equivalent yet |
| Spark 2.4 (Gaussian splats) | `WebGLRenderer` only (notes) | three's `GaussianSplat` addon |
| EffectComposer stacks (three's, pmndrs `postprocessing` 6) | `WebGLRenderer` only | `RenderPipeline` |

drei's scene utilities (`Bounds`, `Center`, `Float`, `Instances`, `Html`, `useGLTF`, `Environment` without `ground`) pass. `<Environment preset>` fetches its HDRI from a third-party CDN at runtime.

## Platform support

**WebGPU is not Baseline** (BCD, notes).

| Browser | WebGPU |
|---|---|
| Chrome, Edge | Windows, macOS, ChromeOS since 113; Linux on Intel Gen12+ since 144 and NVIDIA on Wayland since 147. Android 12+ on ARM and Qualcomm GPUs since 121 |
| Safari | 26, on macOS 26, iOS 26, iPadOS 26 and visionOS 26 only |
| Firefox | Windows since 141, Apple-silicon Macs since 147. Not on Linux, Intel Macs or Android |

About 87% of global usage has it (caniuse, October 2026). The WebGL 2 fallback remains the guarantee. A "compatibility" feature level for older Android devices shipped in Chrome 146 as an opt-in (notes).

**WebXR** (BCD, notes): Chromium browsers including Quest Browser, Samsung Internet and Chrome on Android XR. Not Firefox, and not Safari on iOS or macOS. Safari on visionOS runs `immersive-vr`; no WebKit note mentions `immersive-ar` there, so treat it as unsupported. WebGPU inside a WebXR session: Safari on visionOS 26.2 and Quest Browser 156 (listed as new on 2026-11-13), not Chrome. `supportedFrameRates` and `updateTargetFrameRate`: Quest Browser only.

**Apple.** Safari 27 (2026-09) brings the `<model>` element to iOS, iPadOS and macOS, taking USDZ or GLB sources; AR Quick Look remains the AR path (notes). `<model-viewer>` 4.4 reaches Quick Look in third-party iOS browsers without `ios-src` (notes).

**Frame rate.** Safari on iPhone gives pages 60 fps by default even on a 120 Hz display, halves to 30 under Low Power Mode and thermal mitigation, and in a cross-origin iframe until its first interaction (WebKit source and bug 173434, notes). Measure the rate the page gets; never assume the display's.

**Cross-origin isolation** (BCD). COEP `credentialless`: Chrome 96, Firefox desktop 119; not Safari, not Firefox for Android. `Document-Isolation-Policy`, which isolates one document without breaking popups, exists in Chrome only (desktop 137, Android 146). Safari's bug with a top-level-await module imported by several modules is fixed in 27.

**Workers.** OffscreenCanvas renders WebGL in every engine (Safari 17+). WebGPU in a worker: Chrome 113, Safari 26, Firefox 141 on the platforms where it has WebGPU (BCD).

**Scheduling and diagnostics** (BCD). Long Animation Frames: Chrome 123 only. `scheduler.yield()`: Chrome 129, Firefox 142, not Safari. The Compute Pressure API is desktop Chrome only, so no thermal signal on phones.

**New in the page.** CSS scroll-driven animations are in all three engines since Firefox 159 (Baseline newly available 2026-10-27); Safari runs them on the compositor from 26.4. HTML-in-canvas (a DOM element drawn into a 2D, WebGL or WebGPU canvas, still laid out and accessible) is stable in Chrome 157 (2026-11-03) and nowhere else.

Chrome and Firefox now release every two weeks: version numbers move fast, so compare dates.

## Measurements

All ran on 2026-11-18: three r187, Chrome 157, Apple M5 Pro, 1280×720 at DPR 1 unless noted. A fast desktop: the ratios carry to a phone, the absolute numbers do not.

**Draw submission.** 8,000 boxes, 96k triangles, one geometry and one material. CPU time inside `render()`, median:

| | `WebGLRenderer` | `WebGPURenderer`, WebGPU backend | `WebGPURenderer`, WebGL 2 fallback |
|---|---|---|---|
| 8,000 separate meshes | 6.6 ms (120 fps held) | 27.9 ms (30 fps) | 34.7 ms (30 fps) |
| the same, matrices frozen | 5.2 ms | 13.5 ms (60 fps) | not run |
| one `InstancedMesh` | 0.1 ms | 0.4 ms | 0.3 ms |
| one `BatchedMesh` | 1.6 ms | 2.1 ms | 1.7 ms |
| merged into one geometry | 0.1 ms | 0.3 ms | not run |
| a static `BundleGroup` | not available | 1.3 ms, but 60 fps: the cost moves to the GPU process | no gain, per its documentation |

GPU time for the 8,000 meshes was 1.3 ms: the scene was bound by submission alone. Per draw, `WebGPURenderer` cost about four times what `WebGLRenderer` did.

**Pixels.** 150 full-screen transparent layers, WebGPU backend, GPU time: 22 ms at DPR 1, 100 ms at DPR 2 (4.5×), 89 ms at DPR 2 with an 8-bit output buffer.

**Pre-warm.** A 332k-triangle model with five 4096² KTX2 textures, CPU time of the first `render()` after load: 2 ms pre-warmed against 26.5 ms without (WebGPU backend); 0.7 ms against 62.4 ms (WebGL 2 fallback).

**Texture memory.** A 4096² ETC1S color map: 746 KB in the file, 11.2 MB on the GPU (`inspect`). Uncompressed it is 89 MB.

**Motion.** `MathUtils.damp` reaches the same value after one second at 30, 60, 90 and 120 Hz. `lerp(x, target, 0.1)` per frame covers 95.8% of the gap in that second at 30 Hz and 99.9997% at 120 Hz.

**Skeletal animation.** Synthetic characters of 40 bones, 80 tracks and 3.1k vertices. 100 of them: 0.9 ms in `mixer.update`, 1.0 ms (`WebGLRenderer`) to 1.3 ms (`WebGPURenderer`) in `render()`. 400: 4.1 to 4.4 ms and 4.9 to 6.9 ms. Updating a quarter of the mixers per frame: 0.9 ms down to 0.3 ms.

**Shared snapshots.** The protocol in `offload.md`: 16,500 reads against 12,000 publishes a second of 20,000 bodies, no torn or out-of-order read.

## Download weight

Minified production build (Vite 8.3.8), gzip, r187 (ran):

| Piece | gzip |
|---|---|
| A minimal `WebGLRenderer` scene (core plus renderer) | 191 KB |
| A minimal `WebGPURenderer` scene | 271 KB |
| react, react-dom and @react-three/fiber | 123 KB |
| GLTFLoader, KTX2Loader and the meshopt decoder | 45 KB |
| Basis transcoder WASM (KTX2 textures) | 249 KB |
| Rapier 0.21 WASM | 1.19 MB (852 KB brotli); the `-compat` build 1.65 MB |

## Tooling

- **Vite 8 and WASM** (ran, 8.3.8 with `@dimforge/rapier3d` 0.21). WASM module imports load natively on the main thread and in workers, given `worker.format: 'es'` and `build.target: 'esnext'`; with the default worker format the build fails with `INVALID_TLA_FORMAT`. In dev, a WASM package from `node_modules` breaks once it passes objects across the boundary (`Cannot read properties of undefined (reading '__wbindgen_export')`), because pre-bundling loads its glue twice: `optimizeDeps.exclude` fixes it, and so does `vite-plugin-wasm`. Vite 7.3.8 cannot load the import without the plugin.
- **A message posted to a module worker before its WASM import resolves is dropped:** three of three runs (ran).
- **KTX-Software:** 4.4.2 is stable. 5.0 is a release candidate that removes the legacy `toktx` tool in favor of `ktx create` and encodes UASTC HDR (notes).
- **meshopt in glTF:** `EXT_meshopt_compression` is what glTF-Transform 4.5 and gltfpack write by default. `KHR_meshopt_compression`, with a newer codec, is a release candidate that three r187 already reads (notes, source).
- **Environment maps:** an UltraHDR JPEG is the smallest download; KTX2 UASTC HDR is the smallest on the GPU, which three's `KTX2Loader` reads (notes, source). Lighting goes through a prefiltered half-float copy either way.
- **Rust to WASM:** wasm-bindgen (0.2.130) and wasm-pack (0.15.1) are maintained under the wasm-bindgen organization since the rustwasm organization was archived in 2025; the live wasm-bindgen-rayon is the RReverser fork (notes). WASM SIMD, threads and GC are in every engine (BCD).
- **A GPU in CI:** since Chrome 139, WebGL no longer falls back to software rendering by itself; `--enable-unsafe-swiftshader` opts back in. With a real GPU on Linux, Chrome's recipe is `--headless=new --use-angle=vulkan --disable-vulkan-surface --enable-unsafe-webgpu` (notes).

## Splats

- **Standard.** The glTF extension `KHR_gaussian_splatting` was ratified on 2026-09-03. Compression inside glTF (SPZ) is still a proposal, so compressed delivery uses SPZ or a library's own format (notes).
- **Budgets,** from Spark's defaults and guidance: about 0.5M visible splats on a Quest, 1M on Android phones, 1.5M on iPhones, 2.5M on desktops (notes).
- **Spark 2.x** adds a level-of-detail tree and a streamed format for large captures; three's addon has neither (notes, source).

## Generated assets

What current generators and world models export, per their documentation (notes):

- **Text or image to mesh** (Meshy, TRELLIS.2 and similar): remeshing is often off by default, with targets from 30k up to 300k or a million triangles, and 2k to 8k textures. PBR maps and removal of baked lighting are options, not guarantees.
- **World models** (World Labs Marble): splats of 0.5M to 2M, a collider mesh of 100k to 200k triangles, and a textured mesh of 600k to a million. The splat export looks better than the mesh.

None of it is real-time-ready as exported: `assets.md` § Scanned, converted and generated assets.

## What is changing

- **WebGPU becomes the default path.** React Three Fiber 10 renders with `WebGPURenderer` by default, new three.js features arrive as TSL, and the node-material bridge lets a `WebGLRenderer` scene migrate one material at a time. Reach is the remaining gap: Firefox on Linux and Android, and Apple systems older than 26.
- **Libraries split by renderer for a while.** Text, UI and the most capable splat renderer are WebGL-only; new three addons are WebGPU-only. Dependencies choose the renderer more often than taste does.
- **The DOM comes into the canvas.** HTML-in-canvas plus three's `HTMLTexture` point to in-scene UI built from real, accessible DOM. One engine so far.
- **Splats enter the standard pipeline** through glTF, with level of detail and streaming expected of any serious renderer.
- **Generated assets arrive raw and in volume.** The gate matters more, not less.
- **WebGPU in XR** is arriving per headset. Verify on the device before choosing it.

## Not verified here

Named so nobody mistakes silence for a pass: anything on a phone, a headset or iOS (every measurement above is a desktop); XR sessions at runtime (read in source only); Spark, `<model-viewer>` and the `<model>` element; wasm-pack builds and WASM threads; gltfjsx; KTX2 encoding (no `ktx` tool on the machine: the pipeline ran on an already-encoded model); Safari and Firefox behavior (BCD and release notes only).
