# TSL (Three Shader Language) Reference

TSL is a node-based, JavaScript-native shader system that replaces GLSL/WGSL string writing. You compose shader graphs from JS function calls. TSL compiles to WGSL (WebGPU) or GLSL (WebGL) automatically -- same code runs on both backends.

## Table of Contents

1. [Imports](#imports)
2. [Type System & Operators](#type-system--operators)
3. [Node Materials](#node-materials)
4. [Fn() -- TSL Function Wrapper](#fn----tsl-function-wrapper)
5. [Control Flow](#control-flow)
6. [Uniforms](#uniforms)
7. [Textures](#textures)
8. [Noise & Oscillators](#noise--oscillators)
9. [Practical Examples](#practical-examples)
10. [Compute Shaders](#compute-shaders)
11. [Post-Processing](#post-processing)
12. [Raw WGSL Escape Hatch](#raw-wgsl-escape-hatch)
13. [Migration Notes (GLSL -> TSL)](#migration-notes-glsl---tsl)

## Imports

```typescript
// Node materials (from three/webgpu)
import * as THREE from 'three/webgpu'
// THREE.MeshStandardNodeMaterial, THREE.MeshPhysicalNodeMaterial, etc.

// TSL functions (from three/tsl)
import {
  // Function wrapper & control flow
  Fn, If, Loop, Break, Continue, Switch, Discard,

  // Types
  float, int, uint, bool, vec2, vec3, vec4, color,
  mat2, mat3, mat4, ivec2, ivec3, ivec4,

  // Data
  uniform, attribute, texture,

  // Built-in accessors
  positionLocal, positionWorld, positionView, normalLocal, normalWorld, normalView,
  uv, time, deltaTime, cameraPosition, modelWorldMatrix,
  screenUV, instanceIndex,

  // Math
  sin, cos, abs, pow, sqrt, floor, ceil, fract, mod,
  mix, smoothstep, step, clamp, remap,
  dot, cross, normalize, length, distance, reflect,
  min, max, round,

  // Conditional (usable outside Fn)
  select,

  // Noise (MaterialX-based)
  mx_noise_float, mx_noise_vec3,

  // Oscillators
  oscSine, oscSquare, oscTriangle, oscSawtooth,

  // Varyings
  vertexStage, varyingProperty,

  // Compute & storage
  storage, storageTexture, textureStore,

  // Post-processing
  pass, bloom, fxaa,

  // Utility
  hash,
} from 'three/tsl'
```

## Type System & Operators

TSL uses explicit type constructors and method-based operators:

```typescript
// Types
float(1.0)    vec2(1, 2)    vec3(1, 2, 3)    vec4(1, 2, 3, 1)
int(5)        ivec2(1, 2)   ivec3(1, 2, 3)
color(0xff0000)  // resolves to vec3

// Swizzling
const v = vec3(1, 2, 3)
v.x    // float
v.xy   // vec2
v.xyz  // vec3

// Arithmetic (method chaining)
a.add(b)     // a + b
a.sub(b)     // a - b
a.mul(b)     // a * b
a.div(b)     // a / b
a.mod(b)     // a % b
a.negate()   // -a

// Comparison (return bool nodes)
a.greaterThan(b)       a.lessThan(b)
a.greaterThanEqual(b)  a.lessThanEqual(b)
a.equal(b)

// Type conversion
someNode.toFloat()   someNode.toVec3()   someNode.toInt()

// Example chain:
positionLocal.y.mul(3.0).add(time).sin().mul(0.5).add(0.5)
// GLSL equivalent: sin(positionLocal.y * 3.0 + time) * 0.5 + 0.5
```

## Node Materials

Every classic material has a node equivalent:

| Classic | Node |
|---|---|
| `MeshBasicMaterial` | `MeshBasicNodeMaterial` |
| `MeshStandardMaterial` | `MeshStandardNodeMaterial` |
| `MeshPhysicalMaterial` | `MeshPhysicalNodeMaterial` |
| `MeshPhongMaterial` | `MeshPhongNodeMaterial` |
| `MeshToonMaterial` | `MeshToonNodeMaterial` |
| `PointsMaterial` | `PointsNodeMaterial` |
| `SpriteMaterial` | `SpriteNodeMaterial` |
| -- | `MeshSSSNodeMaterial` (subsurface scattering) |
| -- | `VolumeNodeMaterial` |

### Material Slots

Node materials expose slots where you inject TSL node graphs:

```typescript
const material = new THREE.MeshStandardNodeMaterial()

material.colorNode       // Base color (replaces color/map)
material.opacityNode     // Alpha/transparency
material.normalNode      // Surface normals
material.positionNode    // Vertex positions (displacement)
material.emissiveNode    // Emissive glow
material.metalnessNode   // Metalness factor
material.roughnessNode   // Roughness factor
material.outputNode      // Final fragment output
```

## Fn() -- TSL Function Wrapper

`Fn()` creates a controlled environment enabling assignment, conditionals, loops, and control flow within shaders. Invoke with trailing `()`.

```typescript
// Basic Fn usage
const displaced = Fn(() => {
  const pos = positionLocal.toVar()
  const wave = sin(time.mul(3).add(pos.y.mul(5))).mul(0.1)
  pos.addAssign(normalLocal.mul(wave))
  return pos
})()

material.positionNode = displaced

// With parameters
const fresnel = Fn(({ power = float(3.0) }) => {
  const viewDir = normalize(positionView.negate())
  return float(1).sub(dot(normalView, viewDir)).pow(power)
})

material.emissiveNode = color(0x44ccff).mul(fresnel({ power: float(2.5) }))
```

## Control Flow

All control flow requires `Fn()` context:

```typescript
// If / ElseIf / Else
const shader = Fn(() => {
  const result = vec3(0, 0, 0).toVar()
  If(uv().x.greaterThan(0.5), () => {
    result.assign(vec3(1, 0, 0))
  }).ElseIf(uv().x.greaterThan(0.25), () => {
    result.assign(vec3(0, 1, 0))
  }).Else(() => {
    result.assign(vec3(0, 0, 1))
  })
  return result
})()

// select() -- ternary, usable OUTSIDE Fn()
const clamped = select(value.greaterThan(1), float(1), value)

// Loop
const looped = Fn(() => {
  const sum = float(0).toVar()
  Loop({ start: int(0), end: int(10), type: 'int', condition: '<' }, ({ i }) => {
    sum.addAssign(float(i).div(10))
  })
  return sum
})()

// Discard (alpha clip)
material.fragmentNode = Fn(() => {
  const alpha = texture(myTex, uv()).a
  If(alpha.lessThan(0.5), () => { Discard() })
  return texture(myTex, uv())
})()
```

## Uniforms

```typescript
const uTime = uniform(0.0)
const uColor = uniform(new THREE.Color(1, 0, 0))
const uIntensity = uniform(1.0)

material.colorNode = color(uColor).mul(uIntensity)

// Update in animation loop
uTime.value += delta
uColor.value.setHSL(uTime.value * 0.1, 1, 0.5)
```

## Textures

```typescript
const map = new THREE.TextureLoader().load('diffuse.jpg')
const tint = uniform(new THREE.Color(1, 0.8, 0.6))

material.colorNode = texture(map, uv()).mul(tint)

// Tiled UVs
material.colorNode = texture(map, uv().mul(2))
```

## Noise & Oscillators

```typescript
// Perlin noise (MaterialX-based)
const n = mx_noise_float(positionLocal.mul(2))           // float
const nv = mx_noise_vec3(positionLocal.mul(3).add(time))  // vec3

// Oscillators (0..1 range)
oscSine(time)       oscSquare(time)
oscTriangle(time)   oscSawtooth(time)

// Hash (procedural randomness)
const rand = hash(float(instanceIndex))
```

## Practical Examples

### Animated color gradient

```typescript
material.colorNode = vec3(
  sin(uv().x.mul(10).add(time)).mul(0.5).add(0.5),
  cos(uv().y.mul(8).add(time.mul(1.5))).mul(0.5).add(0.5),
  oscSine(time.mul(0.5))
)
```

### Vertex displacement

```typescript
material.positionNode = Fn(() => {
  const noise = mx_noise_float(positionLocal.mul(2).add(vec3(0, time.mul(0.5), 0)))
  return positionLocal.add(normalLocal.mul(noise.mul(0.3)))
})()
```

### Fresnel rim glow

```typescript
const fresnelEffect = Fn(() => {
  const viewDir = normalize(positionView.negate())
  const f = float(1).sub(dot(normalView, viewDir)).pow(3)
  return mix(color(0x112244), color(0x44ccff), f)
})()
material.colorNode = fresnelEffect
```

### Pulsing emissive

```typescript
material.emissiveNode = color(0x00ffff)
  .mul(sin(time).mul(0.5).add(0.5))
  .mul(normalView.dot(positionView.normalize()).abs())
```

### Animated roughness/metalness

```typescript
material.roughnessNode = smoothstep(float(0), float(1),
  sin(uv().x.mul(6.28).add(time)).mul(0.5).add(0.5))
material.metalnessNode = smoothstep(float(0), float(1),
  sin(uv().y.mul(6.28).add(time.mul(1.5))).mul(0.5).add(0.5))
```

## Compute Shaders

Compute shaders run general-purpose GPU computation. Full compute is WebGPU-only: on the WebGL 2 fallback, `WebGPURenderer` emulates `compute()` with transform feedback, so each invocation can only write its own element of a buffer attribute (no random-access storage-buffer writes). Storage textures, atomics, workgroup/shared memory and indirect dispatch remain WebGPU-only — feature-detect and test compute on both backends.

```typescript
const COUNT = 100000

// Create storage buffer
const posBuffer = new THREE.StorageBufferAttribute(COUNT, 3)
const posStor = storage(posBuffer, 'vec3', COUNT)

// Init compute (run once)
const computeInit = Fn(() => {
  const i = float(instanceIndex)
  const angle = i.mul(0.01)
  const r = i.mul(0.001)
  posStor.element(instanceIndex).assign(
    vec3(cos(angle).mul(r), sin(angle).mul(r), float(0))
  )
})().compute(COUNT)

// Update compute (run every frame)
const computeUpdate = Fn(() => {
  const pos = posStor.element(instanceIndex)
  const angle = float(instanceIndex).mul(0.01).add(time)
  const r = float(instanceIndex).mul(0.001)
  pos.assign(vec3(
    cos(angle).mul(r),
    sin(angle).mul(r),
    sin(time.add(float(instanceIndex).mul(0.005))).mul(0.5)
  ))
})().compute(COUNT)

// Geometry reads from storage
const geo = new THREE.BufferGeometry()
geo.setAttribute('position', posBuffer)
const mat = new THREE.PointsNodeMaterial({ size: 0.02 })
mat.positionNode = posStor.toAttribute()
// Note: gl_PointSize is backend-clamped (small max on some WebGPU/WebGL drivers).
// For reliably-sized particles, use SpriteNodeMaterial on an InstancedMesh instead.

// Execute
await renderer.computeAsync(computeInit)

renderer.setAnimationLoop(async () => {
  await renderer.computeAsync(computeUpdate)
  renderer.render(scene, camera)
})
```

### Storage Textures (WebGPU only)

```typescript
const storageTex = new THREE.StorageTexture(256, 256)

const computeTex = Fn(() => {
  const x = instanceIndex.mod(256)
  const y = instanceIndex.div(256)
  textureStore(storageTex, ivec2(x, y), vec4(
    float(x).div(256), float(y).div(256), sin(time).mul(0.5).add(0.5), 1
  ))
})().compute(256 * 256)
```

## Post-Processing

The new system uses the `RenderPipeline` class (named `PostProcessing` before three.js r183, which still ships it as a deprecated wrapper) with TSL node chains, replacing the old `EffectComposer`:

```typescript
import { pass, bloom, fxaa } from 'three/tsl'

const renderPipeline = new THREE.RenderPipeline(renderer)
const scenePass = pass(scene, camera)

// Effects are nodes you compose with node math — there is no `.pipe()`.
// bloom(inputNode, strength = 1, radius = 0, threshold = 0): the input node is required.
const bloomPass = bloom(scenePass, 1.5 /* strength */, 0 /* radius */, 0.8 /* threshold */)
renderPipeline.outputNode = fxaa(scenePass.add(bloomPass))

renderer.setAnimationLoop(() => {
  renderPipeline.render()
})
```

## Raw WGSL Escape Hatch

For cases where TSL is insufficient:

```typescript
import { wgslFn } from 'three/tsl'

const myColor = wgslFn(`
  fn myColor(uv: vec2f) -> vec4f {
    return vec4f(uv.x, uv.y, 0.5, 1.0);
  }
`)
material.colorNode = myColor({ uv: uv() })
```

All inputs must be passed as parameters -- you cannot access Three.js uniforms from inside `wgslFn`.

## Migration Notes (GLSL -> TSL)

| GLSL/ShaderMaterial | TSL |
|---|---|
| `ShaderMaterial` with GLSL strings | Node material + TSL slots |
| `onBeforeCompile()` | Node properties (`colorNode`, `positionNode`, etc.) |
| `uniform float uTime` | `const uTime = uniform(0.0)` |
| `gl_Position = ...` | `material.positionNode = ...` |
| `gl_FragColor = ...` | `material.colorNode = ...` or `material.outputNode = ...` |
| `varying vec2 vUv` | `vertexStage()` / `varyingProperty()` |
| `EffectComposer` | `RenderPipeline` class (`PostProcessing` before r183) with node composition (function nesting / `.add()`, no `.pipe()`) |

`ShaderMaterial`, `RawShaderMaterial`, and `onBeforeCompile()` are **not supported** in WebGPURenderer.
