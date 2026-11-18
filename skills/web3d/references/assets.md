# Assets: Pipeline, Loading, Memory

Most of the load time and nearly all of the GPU memory are decided here, before any scene code runs. The format is glTF (`.glb`).

## Inspect, then optimize

1. **Inspect first.** `npx @gltf-transform/cli inspect model.glb` lists scenes, meshes, materials, textures with a `gpuSize` (the memory each takes on the GPU) and animations. Budget against these numbers, not the file size.
2. **Optimize.**

   ```bash
   npx @gltf-transform/cli optimize in.glb out.glb --compress meshopt --texture-compress ktx2 --texture-size 2048
   ```

   `ktx2` needs KTX-Software's `ktx` tool installed (`landscape.md` § Tooling). It encodes UASTC for normal, occlusion and metal-rough maps and ETC1S for the rest. Each compression acts on one budget: meshopt (or Draco) on bytes, KTX2 on GPU memory and upload time, the size cap on both.
3. **Know what `optimize` does by default:** it flattens the scene graph, joins meshes (named ones too), builds palette textures, simplifies geometry, turns five or more nodes sharing a mesh into one instanced node, resamples animation and prunes what nothing references. Anything code addresses by name (configurator parts, animated or pickable nodes) needs `--flatten false --join false --palette false --instance false`, plus `--prune false` when code addresses empty nodes (anchors, mount points) and `--simplify false` for hero assets. Then load the output and assert `getObjectByName` for every name the code uses.
4. **gltfjsx `--transform`** always flattens and prunes, and by default joins meshes, merges materials into palettes and writes Draco geometry with 1024 px WebP textures. For name-addressed assets, optimize with gltf-transform as above and run gltfjsx without `--transform`, with `--keepnames --keepgroups`.

## The CI gate

Budgets hold only when a build fails on them. One script, run over every asset:

```js
// assets/gate.mjs
// node gate.mjs public/models/*.glb
import { NodeIO } from '@gltf-transform/core'
import { ALL_EXTENSIONS } from '@gltf-transform/extensions'
import { inspect } from '@gltf-transform/functions'
import { MeshoptDecoder } from 'meshoptimizer'

const BUDGET = { triangles: 100_000, textures: 8, textureGpuBytes: 64 * 2 ** 20, drawCalls: 30 } // per asset, from the spike on the floor device
await MeshoptDecoder.ready
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder })

let failed = false
for (const file of process.argv.slice(2)) {
  const report = inspect(await io.read(file))
  const sum = (rows, key) => rows.reduce((n, row) => n + row[key], 0)
  const actual = {
    triangles: sum(report.meshes.properties, 'glPrimitives'),
    textures: report.textures.properties.length,
    textureGpuBytes: sum(report.textures.properties, 'gpuSize'),
    drawCalls: sum(report.meshes.properties, 'meshPrimitives'),
  }
  for (const [key, max] of Object.entries(BUDGET)) {
    if (actual[key] > max) { failed = true; console.error(`${file}: ${key} ${actual[key]} > ${max}`) }
  }
}
process.exit(failed ? 1 : 0)
```

The budget numbers come from the spike on the floor device (SKILL.md § Budget and proof), shared out per asset. Add the name assertions for name-addressed assets to the same step.

## Loading

```ts
// assets/loader.ts
import * as THREE from 'three/webgpu'
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js'
import { KTX2Loader } from 'three/addons/loaders/KTX2Loader.js'
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js'

export function createLoader(renderer: THREE.WebGPURenderer, onError: (url: string) => void) {
  const manager = new THREE.LoadingManager()
  manager.onError = onError // a texture that fails inside a model is otherwise silent
  const ktx2 = new KTX2Loader(manager).setTranscoderPath('/basis/').detectSupport(renderer) // after await renderer.init()
  return new GLTFLoader(manager).setMeshoptDecoder(MeshoptDecoder).setKTX2Loader(ktx2)
  // Draco files only: .setDRACOLoader(new DRACOLoader(manager).setDecoderPath('/draco/'))
}
```

- **Self-host the decoders** of the installed three: copy `node_modules/three/examples/jsm/libs/basis/` to `/basis/` (and `libs/draco/` for Draco files). A CDN copy is a third-party fetch at runtime, a version that drifts from the loader, and a request cross-origin isolation blocks.
- **A failed load is a designed state.** `loadAsync` rejects on a 404 or a decode failure: catch it and show the poster with a retry. Without `manager.onError`, a texture that fails inside a model is silent.
- **A shared loader is shared setup.** On a working app, repointing decoders or changing the loader is its own change: deploy the files first, then re-test every existing model.
- **Count the runtime fetches a change adds:** drei's `<Environment preset>` (an HDRI from a CDN), XR controller and hand models, CDN decoders. Self-host them or list them in the report.

In React Three Fiber:

```tsx
// assets/Model.tsx
import { Clone, useGLTF } from '@react-three/drei'
import { useThree } from '@react-three/fiber'
import { KTX2Loader } from 'three/addons/loaders/KTX2Loader.js'
import type { WebGPURenderer } from 'three/webgpu'

let ktx2: KTX2Loader | undefined // one transcoder pool for the app

export function Model({ url }: { url: string }) {
  const renderer = useThree((s) => s.gl) as unknown as WebGPURenderer
  const { scene } = useGLTF(url, false, true, (loader) => { // no Draco (drei would fetch its decoder from a CDN), meshopt on
    ktx2 ??= new KTX2Loader().setTranscoderPath('/basis/').detectSupport(renderer)
    loader.setKTX2Loader(ktx2 as never)
  })
  return <Clone object={scene} /> // the cached scene is shared: clone per placement
}
```

`useGLTF` suspends, so the model sits inside the `Suspense` and the error boundary of `setup.md`; a 404 without a boundary crashes the tree. `useGLTF.preload(url)` starts the fetch at module load. drei turns Draco on by default and fetches its decoder from a Google CDN: pass `false` as above, or self-host it with `useGLTF.setDecoderPath('/draco/')`.

## Textures

- **KTX2 for anything a phone will hold in memory.** UASTC for normal maps, packed occlusion-roughness-metalness and hero color; ETC1S for the rest; at most 2048 px on phones. WebP or AVIF only when download size binds and memory does not: both decode to full RGBA on the GPU.
- **What the numbers look like:** a 4096² color map as ETC1S is under a megabyte to download and about 11 MB on the GPU. The same map as PNG, JPEG, WebP or AVIF is 89 MB there, whatever its file size.
- **Gradients, hero color and printed labels band in ETC1S,** which `optimize` uses for base color. Encode those first with `gltf-transform uastc --slots baseColorTexture --resize 2048` (or `--pattern` by texture name); `optimize` leaves textures already in KTX2 alone.
- **Pack occlusion, roughness and metalness into one texture** (R occlusion, G roughness, B metalness). glTF's `metallicRoughnessTexture` already reads G and B.
- **Tags.** Color maps are `SRGBColorSpace`, data maps stay `NoColorSpace`, the default. `LinearSRGBColorSpace` is the renderer's working space, not a tag for data textures.
- KTX2 dimensions must be multiples of 4. Power of two matters only for full mip chains.
- **A texture drawn in code** (`CanvasTexture`, `DataTexture`) is uncompressed: w × h × 4 × 1.33 bytes. Size it to the pixels it covers on screen at the DPR cap, not to a round number, and dispose it with the component that made it.
- **Environment maps** light the scene from a small prefiltered copy, so a 1k source is enough for lighting; a sharp visible background is a separate, cheaper decision (a color, a gradient, a compressed image). Formats: `landscape.md` § Tooling.

## Scanned, converted and generated assets

A photogrammetry scan, a CAD export and the output of a text-to-3D or image-to-3D generator share one property: nobody made them for real time. Treat each as raw material, whatever the tool's marketing says, and expect:

- hundreds of thousands to a million triangles, with no level of detail;
- 2k to 8k textures, uncompressed, often with lighting baked into the base color;
- no names, no hierarchy, arbitrary scale and axes;
- one mesh that cannot be taken apart, or thousands of parts.

The cleanup is a pipeline stage, not a manual favor: simplify or remesh to the triangle budget, regenerate normals and tangents, resize and compress textures, fix scale and axes once at export, and build physics on a separate coarse collider mesh, never the render mesh. The CI gate above is what keeps a raw export from shipping. Check the generator's license before the asset reaches production. Typical outputs per tool: `landscape.md` § Generated assets.

## Configurators

- Options, price and selection live in the app's store and DOM controls, so the page still configures and sells without WebGL. The scene subscribes; it never owns them.
- A color option is a material parameter (`color`, `roughness`) over one near-neutral albedo and one packed texture. A texture set per color multiplies download and memory by the option count.
- Material options (finishes, prints) ship in one file as `KHR_materials_variants`. `<model-viewer>` switches them natively (`variant-name`); three needs a separately registered plugin.
- Geometry options are separate files, fetched on first selection and compiled before they show (Pre-warm).

## Splats

A Gaussian splat is a photoreal capture, not a mesh: no materials, no relighting, no hard edges, millions of sorted transparent points. The renderer already chosen decides the library.

| Under | Use | Notes |
|---|---|---|
| `WebGLRenderer` | Spark (`@sparkjsdev/spark`) | Level of detail and streaming for large captures; reads PLY, SPZ and more |
| `WebGPURenderer`, either backend | three's `GaussianSplat` addon (r186+) | A minimal renderer: GPU sort, no level of detail, no streaming. Small scenes |

```ts
// assets/splat.ts
import { GaussianSplat } from 'three/addons/objects/GaussianSplat.js'
import { GaussianSplatPLYLoader } from 'three/addons/loaders/GaussianSplatPLYLoader.js'

// r186+, WebGPURenderer only (either backend). SPZLoader, SPLATLoader and KSPLATLoader return the same geometry.
export async function loadSplat(url: string) {
  const geometry = await new GaussianSplatPLYLoader().loadAsync(url)
  return new GaussianSplat(geometry)
}
```

- **Budget in splats,** per device class (`landscape.md` § Splats). A capture over the budget needs level of detail, not a faster phone.
- **Ship a compressed format.** A raw PLY is 56 bytes per splat before spherical harmonics and several times that with them, so tens to hundreds of megabytes per million; SPZ is about a tenth.
- **In a glTF,** splats arrive through `KHR_gaussian_splatting`. three's `GLTFLoader` reads it only after `loader.register((parser) => new GLTFGaussianSplatLoaderExtension(parser))`.
- **Capture edges read as broken:** the UX spec constrains the camera to the captured volume; this skill implements the limits.

## Pre-warm

The first time a material is drawn its shader compiles, and the first time a texture is drawn it uploads. Both land as one long frame, exactly when the user first rotates or picks an option. Do both behind the poster:

```ts
// assets/resources.ts
import * as THREE from 'three/webgpu'

export function texturesOf(root: THREE.Object3D) {
  const textures = new Set<THREE.Texture>() // textures are shared between materials: collect once
  root.traverse((o) => {
    const material = (o as THREE.Mesh).material
    for (const m of Array.isArray(material) ? material : material ? [material] : [])
      for (const v of Object.values(m)) if (v instanceof THREE.Texture) textures.add(v)
  })
  return textures
}

// Behind the poster: compile and upload now, so the first interaction does neither.
export async function prewarm(renderer: THREE.WebGPURenderer, scene: THREE.Scene, camera: THREE.Camera) {
  await renderer.compileAsync(scene, camera) // skips invisible objects and, here, ones outside the frustum
  for (const t of texturesOf(scene)) renderer.initTexture(t)
}

export function disposeModel(root: THREE.Object3D) {
  for (const t of texturesOf(root)) t.dispose()
  root.traverse((o) => {
    const mesh = o as THREE.Mesh
    mesh.geometry?.dispose()
    for (const m of Array.isArray(mesh.material) ? mesh.material : mesh.material ? [mesh.material] : []) m.dispose()
    o.dispose?.() // per-object GPU data such as bone and instance textures; on every Object3D from r186
  })
  root.removeFromParent()
}
```

- Compilation skips invisible objects and, under `WebGPURenderer`, objects outside the camera's frustum. Make hidden variants visible for the compile, or compile each one when it becomes reachable.
- The effect is measurable: time the first `render()` after load with and without it (`landscape.md` § Measurements).

## Dispose

GPU resources are never garbage collected. `material.dispose()` frees the program, not its textures, and textures are shared between materials, so `disposeModel` above collects them once.

Still yours after it: `scene.environment` and `scene.background`, render targets, prefiltered environment maps, post-processing buffers, loader caches (`useGLTF.clear`), workers, and last the renderer (`renderer.dispose()`). `removeFromParent()` alone drops scene-graph references and frees no GPU memory. Prove a teardown with the remount test (`performance.md` § Soak and remount).
