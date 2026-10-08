# TSL, Node Materials, Compute, Post-Processing

TSL compiles to WGSL on the WebGPU backend and GLSL on the WebGL 2 fallback, and runs only under `WebGPURenderer`; code that stays on `WebGLRenderer` keeps GLSL.

## Imports

- Renderer, node materials, `RenderPipeline`: `three/webgpu`.
- Nodes and functions (`Fn`, `uniform`, `pass`, `renderOutput`, `instancedArray`, `mx_noise_float`, …): `three/tsl`.
- Display effects: `three/addons/tsl/display/*` (r170+; `three/tsl` exported them through r169), such as `bloom` from `BloomNode.js` and `fxaa` from `FXAANode.js`. From r170, importing them from `three/tsl` is a SyntaxError at module load, which blanks the whole scene, not just the effect.

## Node materials and uniforms

Built-in classic materials still render (the renderer converts them); reach for a `*NodeMaterial` when you need its slots (`colorNode`, `positionNode` in local space, `normalNode`, …). `fragmentNode` replaces the whole fragment stage, lighting included.

`const uTime = uniform(0)`, then set `uTime.value` each frame. Never rebuild a node graph per frame: a new graph is a new shader compile.

## Fn, variables, control flow

`Fn()` opens a scope that allows assignment and control flow; call the result to get a node. Assign to `toVar()` variables and storage elements (`.element(i)`, as in Compute); copy shared inputs such as `positionLocal` with `toVar()` before mutating them. `If`/`ElseIf`/`Else` and `Loop` work only inside `Fn`; `select(cond, a, b)` works anywhere.

```ts
material.positionNode = Fn(() => {
  const p = positionLocal.toVar()
  p.addAssign(normalLocal.mul(sin(time.mul(3).add(p.y.mul(5))).mul(0.1)))
  return p
})()

material.colorNode = Fn(() => {          // alpha clip that keeps the lighting
  const c = texture(map, uv())
  If(c.a.lessThan(0.5), () => { Discard() })
  return c
})()

const sum = Fn(() => {
  const s = float(0).toVar()
  Loop({ start: int(0), end: int(10), type: 'int', condition: '<' }, ({ i }) => { s.addAssign(float(i).div(10)) })
  return s
})()
```

`wgslFn` is the raw-WGSL escape hatch: every input arrives as a parameter, since the function can't read three.js uniforms itself. WebGPU backend only: the WebGL 2 fallback needs a `glslFn` twin, or stay in TSL.

## Compute

```ts
const COUNT = 100_000
const positions = instancedArray(COUNT, 'vec3'), velocities = instancedArray(COUNT, 'vec3')
const step = Fn(() => {
  const v = velocities.element(instanceIndex)
  v.addAssign(vec3(0, -0.0002, 0))
  positions.element(instanceIndex).addAssign(v)
})().compute(COUNT)

const material = new THREE.SpriteNodeMaterial()   // sized particles: instanced sprites
material.positionNode = positions.toAttribute()
material.scaleNode = float(0.02)
const particles = new THREE.Sprite(material)
particles.count = COUNT
particles.frustumCulled = false

await renderer.init()                             // once; then plain compute() per frame
renderer.setAnimationLoop(() => { renderer.compute(step); renderer.render(scene, camera) })
```

- `instancedArray` is r171+ (earlier: `storage()` over a `StorageInstancedBufferAttribute`); `Sprite.count` is r177+ (earlier: an `InstancedMesh` of a plane with the `SpriteNodeMaterial`).
- WebGPU draws point primitives at 1 px, so `PointsNodeMaterial.size` on `Points` does nothing there; sized particles are instanced `Sprite`s as above.
- On the WebGL 2 fallback, compute is emulated with transform feedback: each invocation writes only its own element of a buffer attribute. Storage textures, atomics, workgroup memory and indirect dispatch are WebGPU-only. Feature-detect and test compute on both backends.

## Post-processing

`RenderPipeline` (named `PostProcessing` before r183, still exported as a deprecated alias) composes nodes; there is no `.pipe()`. Anti-aliasing runs after tone mapping and the sRGB transform, so take color conversion out of the pipeline's hands and place it explicitly:

```ts
import { pass, renderOutput } from 'three/tsl'
import { bloom } from 'three/addons/tsl/display/BloomNode.js'
import { fxaa } from 'three/addons/tsl/display/FXAANode.js'

const pipeline = new THREE.RenderPipeline(renderer)
const color = pass(scene, camera).getTextureNode('output')
const lit = color.add(bloom(color, 1.5, 0, 0.8))          // strength, radius, threshold
pipeline.outputColorTransform = false
pipeline.outputNode = fxaa(renderOutput(lit))
renderer.setAnimationLoop(() => pipeline.render())
```

Full-screen passes cost per pixel and, in XR, per eye: budget them on the floor device, and avoid them in XR (`web-xr.md`). `renderer.debug.getShaderAsync(scene, camera, object)` returns the generated code; it needs an initialized renderer, and its output changes every release, so never assert on it in CI.

## Migrating from GLSL

| GLSL or WebGLRenderer | TSL |
|---|---|
| `ShaderMaterial`, `RawShaderMaterial` | Node material plus slots |
| `onBeforeCompile` | The slot it patched (`colorNode`, `positionNode`, …) |
| `uniform float uTime` | `const uTime = uniform(0)` |
| `gl_Position = …` | `material.positionNode` |
| `gl_FragColor = …` | `material.colorNode` or `outputNode` |
| `varying vec2 vUv` | `vertexStage()` or `varyingProperty()` |
| `EffectComposer` | `RenderPipeline` with node composition |

`ShaderMaterial`, `RawShaderMaterial` and `onBeforeCompile` don't run under `WebGPURenderer` on either backend, and neither do libraries built on them (the grep rule in SKILL.md). Inventory those and every EffectComposer pass first, then migrate one material at a time behind a flag and compare both backends by visual diff (`testing.md`).
