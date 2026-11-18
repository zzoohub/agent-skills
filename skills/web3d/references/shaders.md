# Shaders: TSL, Compute, Post-processing

TSL is three's shading language, written as JavaScript. Under `WebGPURenderer` it compiles to WGSL on the WebGPU backend and to GLSL on the WebGL 2 fallback, so one source serves both. Node materials also render under the classic `WebGLRenderer` through a compatibility layer (r184+, § Migrating from GLSL). Hand-written GLSL (`ShaderMaterial`, `onBeforeCompile`) runs only under `WebGLRenderer`.

## Imports

- Renderer, node materials, `RenderPipeline`: `three/webgpu`.
- Nodes and functions (`Fn`, `uniform`, `time`, `pass`, `renderOutput`, `instancedArray`, …): `three/tsl`.
- Display effects: `three/addons/tsl/display/*` (r170+), such as `bloom` from `BloomNode.js`. Importing them from `three/tsl` is a SyntaxError at module load from r170, which blanks the whole scene, not just the effect.

## Node materials

Built-in classic materials still render under `WebGPURenderer`, which converts them. Reach for a `*NodeMaterial` when you need its slots: `colorNode`, `positionNode` (local space), `normalNode` and so on. `fragmentNode` replaces the whole fragment stage, lighting included.

```ts
// shaders/materials.ts
import * as THREE from 'three/webgpu'
import { Discard, Fn, If, Loop, float, int, normalLocal, positionLocal, sin, texture, time, uniform, uv } from 'three/tsl'

export const uStrength = uniform(0.1) // set uStrength.value; never rebuild the graph per frame

export function wobble(material: THREE.MeshStandardNodeMaterial) {
  material.positionNode = Fn(() => {
    const p = positionLocal.toVar() // copy before mutating a shared input
    p.addAssign(normalLocal.mul(sin(time.mul(3).add(p.y.mul(5))).mul(uStrength)))
    return p
  })()
}

export function alphaClip(material: THREE.MeshStandardNodeMaterial, map: THREE.Texture) {
  material.colorNode = Fn(() => { // an alpha clip that keeps the lighting
    const c = texture(map, uv())
    If(c.a.lessThan(0.5), () => { Discard() })
    return c
  })()
}

export const tenth = Fn(() => {
  const s = float(0).toVar()
  Loop({ start: int(0), end: int(10), type: 'int', condition: '<' }, ({ i }) => { s.addAssign(float(i).div(10)) })
  return s
})
```

- **`Fn()` opens a scope** that allows assignment and control flow; call the result to get a node. `If`, `ElseIf`, `Else` and `Loop` work only inside it; `select(condition, a, b)` works anywhere.
- **Assign only to `toVar()` variables and storage elements.** Copy a shared input such as `positionLocal` before changing it.
- **A uniform is created once and its `.value` is set per frame.** A node graph rebuilt per frame, or per React render, is a new shader compile each time.
- **`wgslFn`** is the raw-WGSL escape hatch. Every input arrives as a parameter, and it runs on the WebGPU backend only: the fallback needs a `glslFn` twin, or stay in TSL.
- **`renderer.debug.getShaderAsync(scene, camera, object)`** returns the generated code. Its output changes with every release, so never assert on it in a test.

## With React Three Fiber

```tsx
// shaders/NodeMaterialElement.tsx
import { extend, type ThreeElement } from '@react-three/fiber'
import { MeshStandardNodeMaterial } from 'three/webgpu'
import { useMemo } from 'react'
import { Fn, normalLocal, positionLocal, sin, time } from 'three/tsl'

// Register only the node classes used as JSX: extend(THREE) would pull the whole namespace into the bundle.
extend({ MeshStandardNodeMaterial })
declare module '@react-three/fiber' {
  interface ThreeElements { meshStandardNodeMaterial: ThreeElement<typeof MeshStandardNodeMaterial> }
}

export function Breathing() {
  const positionNode = useMemo(() => Fn(() => positionLocal.add(normalLocal.mul(sin(time.mul(3)).mul(0.1))))(), []) // built once, never per render
  return (
    <mesh>
      <sphereGeometry args={[1, 48, 24]} />
      <meshStandardNodeMaterial color="#44aa88" positionNode={positionNode} />
    </mesh>
  )
}
```

## Compute

Per-element state that lives on the GPU: positions, velocities, lifetimes. Nothing is read back, and nothing crosses to JavaScript per frame.

```ts
// shaders/particles.ts
import * as THREE from 'three/webgpu'
import { Fn, float, hash, instanceIndex, instancedArray, vec3 } from 'three/tsl'

export function createParticles(count: number) {
  const positions = instancedArray(count, 'vec3'), velocities = instancedArray(count, 'vec3')

  const init = Fn(() => {
    const i = float(instanceIndex)
    positions.element(instanceIndex).assign(vec3(hash(i), hash(i.add(0.1)), hash(i.add(0.2))).sub(0.5).mul(4))
    velocities.element(instanceIndex).assign(vec3(0))
  })().compute(count)

  const step = Fn(() => {
    const v = velocities.element(instanceIndex)
    v.addAssign(vec3(0, -0.0002, 0))
    positions.element(instanceIndex).addAssign(v)
  })().compute(count)

  const material = new THREE.SpriteNodeMaterial() // sized particles are instanced sprites
  material.positionNode = positions.toAttribute()
  material.scaleNode = float(0.02)
  const points = new THREE.Sprite(material)
  points.count = count
  points.frustumCulled = false

  return { points, init, step }
}
```

```ts
await renderer.init()
renderer.compute(init) // once
renderer.setAnimationLoop(() => { renderer.compute(step); renderer.render(scene, camera) })
```

- `instancedArray` is r171+; `Sprite.count` is r177+.
- **WebGPU draws point primitives one pixel wide,** so `PointsNodeMaterial.size` on `Points` does nothing there. Sized particles are instanced sprites, as above.
- **On the WebGL 2 fallback compute is emulated** with transform feedback: each invocation writes only its own element of a buffer attribute. Storage textures, atomics, workgroup memory and indirect dispatch are WebGPU-only. Run compute on both backends before relying on it (`forceWebGL: true`).

## Post-processing

`RenderPipeline` composes nodes (it was named `PostProcessing` before r183). Anti-aliasing must run after tone mapping and the sRGB transform, so take the output transform out of the pipeline's hands and place it explicitly:

```ts
// shaders/post.ts
import * as THREE from 'three/webgpu'
import { pass, renderOutput } from 'three/tsl'
import { bloom } from 'three/addons/tsl/display/BloomNode.js'
import { fxaa } from 'three/addons/tsl/display/FXAANode.js'

export function createPipeline(renderer: THREE.WebGPURenderer, scene: THREE.Scene, camera: THREE.Camera) {
  const pipeline = new THREE.RenderPipeline(renderer)
  const color = pass(scene, camera).getTextureNode('output')
  const lit = color.add(bloom(color, 1.5, 0, 0.8)) // strength, radius, threshold
  pipeline.outputColorTransform = false // tone mapping and sRGB happen once, before the anti-aliasing
  pipeline.outputNode = fxaa(renderOutput(lit))
  return pipeline // per frame: pipeline.render() in place of renderer.render()
}
```

- **Every effect is a full-screen pass,** paid per pixel and in XR per eye. Budget each one on the floor device (`performance.md` § Levers by term), and run what survives it at half resolution.
- **XR runs without the post stack** (`xr.md`). The renderer's own tone mapping then applies: set it to the operator the pipeline used.
- An on-demand loop calls `pipeline.render()` wherever it called `renderer.render()`.

## Migrating from GLSL

| GLSL under `WebGLRenderer` | TSL |
|---|---|
| `ShaderMaterial`, `RawShaderMaterial` | a node material plus slots |
| `onBeforeCompile` | the slot it patched (`colorNode`, `positionNode`, …) |
| `uniform float uTime` | `const uTime = uniform(0)`, or the built-in `time` |
| `gl_Position = …` | `material.positionNode` |
| `gl_FragColor = …` | `material.colorNode` or `outputNode` |
| `varying vec2 vUv` | `vertexStage()` or `varyingProperty()` |
| `EffectComposer` | `RenderPipeline` with node composition |

`ShaderMaterial`, `RawShaderMaterial` and `onBeforeCompile` do not run under `WebGPURenderer` on either backend, and neither do libraries built on them (the grep in SKILL.md § Size the stack). So a renderer switch used to be all or nothing. From r184 it need not be: node materials render inside the `WebGLRenderer` you already have, beside the GLSL ones.

```ts
// shaders/webgl-bridge.ts
import * as THREE from 'three'
import { MeshStandardNodeMaterial } from 'three/webgpu'
import { WebGLNodesHandler } from 'three/addons/tsl/WebGLNodesHandler.js'
import { Fn, normalLocal, positionLocal, sin, time } from 'three/tsl'

export function createBridgedRenderer(canvas?: HTMLCanvasElement) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true })
  renderer.setNodesHandler(new WebGLNodesHandler()) // r184+: node materials render beside GLSL ones
  return renderer
}

export function nodeMaterial() {
  const material = new MeshStandardNodeMaterial({ color: 0x44aa88 })
  material.positionNode = Fn(() => positionLocal.add(normalLocal.mul(sin(time.mul(3)).mul(0.1))))()
  return material
}
```

The bridge has limits, listed at the top of the addon's source: no VSM shadows, no MRT, no transmission, no storage textures, and no `RenderPipeline` (post-processing stays on the EffectComposer until the switch). Read that list in the installed version.

The order that keeps a working scene working:

1. **Inventory:** every `ShaderMaterial`, `onBeforeCompile` and EffectComposer pass, and every library that fails the grep.
2. **Port one material at a time** to TSL under the existing `WebGLRenderer`, comparing each against its GLSL original by visual diff (`testing.md`).
3. **When no GLSL material is left,** rebuild the post stack as a `RenderPipeline` and switch the renderer behind a flag.
4. **Run both backends** before removing the flag.

A library that stays WebGL-only (`landscape.md` § WebGL-only helpers) keeps the scene on `WebGLRenderer`: that is a fine place to stay, with TSL materials on the bridge.
