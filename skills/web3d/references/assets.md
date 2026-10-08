# glTF Asset Pipeline

## Inspect, then optimize

1. **Inspect first:** `npx @gltf-transform/cli inspect model.glb` lists scenes, meshes, materials, textures with a `gpuSize` (VRAM) estimate, and animations; it does not list nodes. Budget against these numbers, not the file size.
2. **Optimize:**

```bash
npx @gltf-transform/cli optimize in.glb out.glb --compress meshopt --texture-compress ktx2 --texture-size 2048
```

   `ktx2` needs KTX-Software's `ktx` tool installed; it encodes UASTC for normal, occlusion and metal-rough maps and ETC1S for the rest. `optimize` also flattens the scene graph, joins meshes (named ones too), builds texture palettes, simplifies geometry, replaces 5+ nodes sharing a mesh with one instanced node, and prunes empty nodes by default. Anything code addresses by name (configurator parts, animated or pickable nodes) needs `--flatten false --join false --palette false --instance false`, plus `--prune false` when code addresses empty nodes (anchors, mount points) and `--simplify false` for hero assets. Then load the output and assert `getObjectByName` for every name the code uses.
3. **Catalogs** gate this in CI: run `inspect()` from `@gltf-transform/functions` on every asset and fail any over its budget (triangles from `glPrimitives`, texture count, size and `gpuSize`), plus the name check.
4. **gltfjsx `--transform`** always flattens the graph and prunes empty nodes, and by default joins meshes, palette-merges materials and writes Draco geometry with WebP textures at 1024 px. Its Draco output needs a `DRACOLoader` outside drei. For name-addressed assets, optimize with gltf-transform as above and run gltfjsx without `--transform`, with `--keepnames --keepgroups`.

## Loading (vanilla; R3F: `react/setup.md`)

```ts
const manager = new THREE.LoadingManager()
manager.onError = (url) => showFallback(url)                // a failed asset is otherwise silent
const ktx2 = new KTX2Loader(manager).setTranscoderPath('/basis/').detectSupport(renderer) // after await renderer.init()
const loader = new GLTFLoader(manager).setMeshoptDecoder(MeshoptDecoder).setKTX2Loader(ktx2)
// Draco files only; without this line GLTFLoader throws "No DRACOLoader instance provided":
// loader.setDRACOLoader(new DRACOLoader(manager).setDecoderPath('/draco/'))
const gltf = await loader.loadAsync('/model.glb')           // rejects on 404 or decode failure: catch and fall back
```

Self-host the Basis transcoder and Draco decoder of the installed three (`examples/jsm/libs/`) for availability, version pinning and COEP. That is a rule for loaders you add: on a working app, repointing the shared loader is a separate change, never part of a feature; deploy the files first, then re-test every existing model. Runtime third-party fetches a change adds (drei `<Environment preset>`, XR controller and hand models, CDN decoders) are self-hosted or listed in the report.

## Textures

- Pack occlusion, roughness and metalness into one ORM texture (R occlusion, G roughness, B metalness); glTF's `metallicRoughnessTexture` already reads G and B.
- Color maps (base color, emissive) are `SRGBColorSpace`; data maps (normal, ORM) stay `NoColorSpace`, the default. `LinearSRGBColorSpace` is the renderer's working space, not a tag for data textures.
- KTX2 dimensions must be multiples of 4; power of two matters only for full mip chains.

## Configurators

- Options, price and selection live in the app's store and DOM controls, so the page still configures and sells without WebGL; the scene subscribes and never owns them.
- A color option is a material parameter (`color`, `roughness`) over one near-neutral albedo and one ORM. A texture set per color multiplies download and VRAM by the option count.
- Material options (finishes, prints) ship in one file as `KHR_materials_variants`: `<model-viewer>` switches them natively (`variant-name`); three needs a separately registered plugin (three's `webgl_loader_gltf_variants` example).
- Geometry options are separate files, fetched on first selection and compiled before they show (Pre-warm).
- Hero color, gradients and printed labels band in ETC1S, which `optimize` uses for base color. Encode them first with `gltf-transform uastc --slots baseColorTexture --resize 2048` (or `--pattern` by texture name); `optimize` skips textures already in KTX2.

## Splats

Photoreal captures: three's `GaussianSplat` addon (r186+, `three/addons/objects/GaussianSplat.js`; `WebGPURenderer` only, either backend); Spark (`@sparkjsdev/spark`) under `WebGLRenderer` or for splat editing and animation.

## Pre-warm

Behind the poster, after loading: `await renderer.compileAsync(scene, camera)` compiles the materials the scene needs, and `renderer.initTexture(texture)` uploads each texture. Compile skips invisible objects (and, on `WebGPURenderer`, objects outside the camera's frustum), so make hidden variants such as configurator options visible during the compile, or compile each as it becomes reachable.

## Dispose

GPU resources are never garbage-collected. `material.dispose()` frees the program, not its textures, and textures are often shared, so collect them deduplicated and dispose once:

```ts
function disposeModel(root: THREE.Object3D) {
  const textures = new Set<THREE.Texture>()
  root.traverse((o) => {
    if (!(o instanceof THREE.Mesh)) return
    o.geometry.dispose()
    for (const m of Array.isArray(o.material) ? o.material : [o.material]) {
      for (const v of Object.values(m)) if (v instanceof THREE.Texture) textures.add(v)
      m.dispose()
    }
  })
  textures.forEach((t) => t.dispose())
}
```

Still yours: `scene.environment` and `background`, render targets, PMREM environment maps, post-processing buffers, loader caches (`useGLTF.clear`), workers, and last the renderer (`await renderer.dispose()` on `WebGPURenderer`). `removeFromParent()` drops scene-graph references only; it frees no GPU memory.
