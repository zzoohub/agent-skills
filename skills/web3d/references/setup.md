# Scene Setup: Skeleton, Page, Color

The skeleton comes before content. It carries rules 1, 5 and 7 of SKILL.md in code: a loop that sleeps, one clock, a picture for every failure, and a teardown.

## The skeleton (three.js)

Everything that moves is a tick:

```ts
// setup/tick.ts
export type Tick = (dt: number) => boolean | void // return true while still moving
```

```ts
// setup/viewer.ts
import * as THREE from 'three/webgpu'
import type { Tick } from './tick.ts'

export async function createViewer(host: HTMLElement, { maxDpr = 2, forceWebGL = false, onLost = () => {} } = {}) {
  const renderer = new THREE.WebGPURenderer({ antialias: true, forceWebGL })
  await renderer.init() // rejects without WebGPU and WebGL 2: the caller keeps the poster
  renderer.toneMapping = THREE.NeutralToneMapping
  host.append(renderer.domElement)

  const scene = new THREE.Scene()
  const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 100)
  const timer = new THREE.Timer()
  timer.connect(document) // a hidden tab is not a time step
  const ticks = new Set<Tick>()
  let dirty = true, awake = false, onscreen = false

  function frame(t: number) {
    timer.update(t) // every frame, idle ones too: waking never sees the pause as a time step
    const immersive = renderer.xr.isPresenting // a headset needs every frame
    if (!immersive && !(awake && onscreen)) return // idle: nothing runs, nothing draws
    const dt = Math.min(timer.getDelta(), 0.1)
    let moving = false
    for (const tick of ticks) if (tick(dt) === true) moving = true
    if (dirty || moving || immersive) renderer.render(scene, camera)
    dirty = false
    awake = moving // settled: sleep until the next invalidate()
  }
  const invalidate = () => { dirty = awake = true }

  const resize = new ResizeObserver(([entry]) => {
    const { width, height } = entry.contentRect
    if (width === 0 || height === 0 || renderer.xr.isPresenting) return
    renderer.setPixelRatio(Math.min(devicePixelRatio, maxDpr))
    renderer.setSize(width, height)
    camera.aspect = width / height
    camera.updateProjectionMatrix()
    renderer.render(scene, camera) // in the same frame as the resize, or the cleared buffer flashes
  })
  const visibility = new IntersectionObserver(([entry]) => {
    onscreen = entry.isIntersecting
    if (onscreen) invalidate()
  })
  resize.observe(host)
  visibility.observe(host)

  const halt = renderer.onDeviceLost.bind(renderer) // three's handler stops rendering: keep it
  renderer.onDeviceLost = (info) => { halt(info); onLost() } // the caller shows the poster and remounts

  renderer.setAnimationLoop(frame) // the one loop; it also carries XR frames

  function dispose() {
    renderer.setAnimationLoop(null)
    resize.disconnect()
    visibility.disconnect()
    timer.dispose()
    renderer.dispose() // after the scene's own resources (assets.md § Dispose)
    renderer.domElement.remove()
  }

  return { renderer, scene, camera, ticks, invalidate, dispose }
}
```

- **The contract.** A tick returns `true` while it still has somewhere to go (`animation.md` § Motion on demand). Anything that changes the picture outside a tick calls `invalidate()`: a loaded model, a swapped material, an option the user picked.
- **On demand means skipping `render()`, not stopping the loop.** The callback still runs each frame and returns at once. Under `WebGPURenderer` three keeps one `requestAnimationFrame` alive for its own bookkeeping after the first render in any case (`landscape.md` § three.js).
- **The timer advances on idle frames too,** so the first frame after a sleep steps by one frame, not by the whole sleep. `timer.connect(document)` does the same for a hidden tab.
- **The poster.** A rejected `createViewer` leaves the poster the page already shows. Once the model is in and pre-warmed, give the scene an opaque `scene.background`: the canvas then covers the poster from its first complete frame, with nothing to cross-fade.
- **Device loss.** Keep three's handler, show the poster, dispose and mount again.
- **A `WebGLRenderer` skeleton** differs in three places: no `await renderer.init()`, loss arrives as `webglcontextlost` and `webglcontextrestored` on the canvas, and `setAnimationLoop(null)` really stops the loop.

Mount it when the section is about to be seen, so three.js stays out of the page's first chunk:

```ts
const host = document.querySelector<HTMLElement>('#viewer')! // already shows the poster
const seen = new IntersectionObserver(async ([entry]) => {
  if (!entry.isIntersecting) return
  seen.disconnect()
  try {
    const { createViewer } = await import('./viewer.ts') // three.js arrives in its own chunk
    const viewer = await createViewer(host)
    // load, pre-warm, add to viewer.scene, set viewer.scene.background, viewer.invalidate()
  } catch { /* no WebGPU, no WebGL 2 or a failed chunk: the poster stays */ }
}, { rootMargin: '200px' })
seen.observe(host)
```

## React Three Fiber

The same skeleton for React Three Fiber 9 on React 19. Version 10 changes the defaults: `landscape.md` § React Three Fiber.

```tsx
// setup/Viewer.tsx
import * as THREE from 'three/webgpu'
import { Canvas, useThree } from '@react-three/fiber'
import { Component, Suspense, useEffect, useState, type ReactNode } from 'react'

class Boundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false }
  static getDerivedStateFromError = () => ({ failed: true })
  render() { return this.state.failed ? null : this.props.children } // nothing: the poster underneath stays
}

function SleepOffscreen() { // off screen nothing runs, whatever the ticks say
  const canvas = useThree((s) => s.gl.domElement)
  const setFrameloop = useThree((s) => s.setFrameloop)
  const invalidate = useThree((s) => s.invalidate)
  useEffect(() => {
    const seen = new IntersectionObserver(([entry]) => {
      setFrameloop(entry.isIntersecting ? 'demand' : 'never')
      if (entry.isIntersecting) invalidate() // back in view: one frame, and the ticks take it from there
    })
    seen.observe(canvas)
    return () => seen.disconnect()
  }, [canvas, setFrameloop, invalidate])
  return null
}

export default function Viewer({ children, forceWebGL = false }: { children: ReactNode; forceWebGL?: boolean }) {
  const [generation, remount] = useState(0)
  return (
    <Boundary key={generation}>
      <Canvas
        frameloop="demand" // draws only after invalidate(): a still scene costs nothing
        dpr={[1, 2]}
        gl={async (props) => {
          const renderer = new THREE.WebGPURenderer({ ...props, antialias: true, forceWebGL } as never)
          await renderer.init() // a rejection reaches the boundary: the poster stays
          return renderer
        }}
        onCreated={({ gl }) => {
          const renderer = gl as unknown as THREE.WebGPURenderer
          renderer.toneMapping = THREE.NeutralToneMapping // R3F sets ACES Filmic before this runs
          const halt = renderer.onDeviceLost.bind(renderer) // three's handler stops rendering: keep it
          renderer.onDeviceLost = (info) => { halt(info); remount((n) => n + 1) }
        }}
      >
        <SleepOffscreen />
        <Suspense fallback={null}>{children}</Suspense>
      </Canvas>
    </Boundary>
  )
}
```

```tsx
// setup/ViewerGate.tsx
import { lazy, Suspense, useEffect, useRef, useState, type ReactNode } from 'react'

const Viewer = lazy(() => import('./Viewer.tsx')) // three.js stays out of the page's first chunk

export function ViewerGate({ poster, alt, children, forceWebGL }: { poster: string; alt: string; children: ReactNode; forceWebGL?: boolean }) {
  const host = useRef<HTMLDivElement>(null)
  const [near, setNear] = useState(false)
  useEffect(() => {
    const seen = new IntersectionObserver(([entry]) => { if (entry.isIntersecting) setNear(true) }, { rootMargin: '200px' })
    seen.observe(host.current!)
    return () => seen.disconnect()
  }, [])
  return (
    <div ref={host} style={{ position: 'relative', aspectRatio: '4 / 3' }}>
      <img src={poster} alt={alt} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      {near && (
        <div style={{ position: 'absolute', inset: 0 }}>
          <Suspense fallback={null}><Viewer forceWebGL={forceWebGL}>{children}</Viewer></Suspense>
        </div>
      )}
    </div>
  )
}
```

```tsx
<ViewerGate poster="/chair.avif" alt="Oak lounge chair, three-quarter view">
  <color attach="background" args={['#f3f1ee']} /> {/* opaque, and inside Suspense: the canvas covers the poster only once the model is in */}
  <Model url="/chair.glb" />
</ViewerGate>
```

The loop contract, as a hook:

```ts
// setup/use-tick.ts
import { useFrame } from '@react-three/fiber'
import type { Tick } from './tick.ts'

// The same contract inside a frameloop="demand" Canvas: frames keep coming while the tick returns true.
export function useTick(tick: Tick) {
  useFrame((state, delta) => {
    const dt = delta > 0.1 ? 1 / 60 : delta // after an idle demand loop R3F's delta is the whole pause
    if (tick(dt) === true) state.invalidate()
  })
}
```

- **The renderer.** R3F 9 awaits an async `gl` factory before the first frame, and a rejected `init()` fails the root, which the boundary catches. R3F 8 calls the factory synchronously: construct `new WebGPURenderer({ canvas })` there and hold `frameloop="never"` until `init()` resolves.
- **Tone mapping** goes in `onCreated`. R3F sets ACES Filmic when it configures the renderer, after the factory returns.
- **Off screen nothing runs.** `SleepOffscreen` switches the loop to `never` while the canvas is out of view, which silences even a tick that never settles, and back to `demand` with one `invalidate()` on return. In XR, gate it on the session (`xr.md`).
- **`frameloop="demand"`** draws after `invalidate()`. R3F calls it when props change and drei's controls call it while they move; your own motion calls it from a tick. `useFrame` callbacks run only on drawn frames, so something must wake the loop first.
- **The first delta after an idle demand loop is the whole pause,** seconds long. Clamping it to 0.1 still jumps a hundred milliseconds at the start of every interaction, which is why `useTick` substitutes one nominal frame.
- **No `extend(THREE)`.** Meshes, lights, geometries and classic materials are already JSX elements, and `WebGPURenderer` converts classic materials itself. Registering the whole `three/webgpu` namespace pulls all of it into the bundle. Register only the node classes used as JSX (`shaders.md` § With React Three Fiber).
- **In the loop, mutate refs.** `setState` inside `useFrame`, or a prop that changes every frame, re-renders React at the display's rate. Read `useThree` through a selector (`useThree((s) => s.camera)`), or the component re-renders on every store change.
- **Unmount.** R3F disposes objects it created from JSX. It does not dispose `<primitive>` objects, objects passed as props, or loader caches: call `useGLTF.clear(url)` for models that will not return. A resource made in `useMemo` is disposed in an effect cleanup; that survives StrictMode's double mount, because `dispose()` frees only the GPU copy and three uploads it again on next use.
- **Next.js.** `ViewerGate` is a Client Component, and the `lazy` import keeps three.js out of the server render and the first chunk.
- **Events.** R3F raycasts every object that has pointer handlers on each pointer move: keep handlers on few objects, and wrap dense meshes in drei's `<Bvh>` or use `raycast={meshBounds}`. `onClick` also fires after an orbit drag: ignore clicks whose `e.delta` exceeds a few pixels.

## A guest on the page

- **The poster** is a sized `<img>` in the HTML with `fetchpriority="high"`, matching the default view. It is the LCP element; the canvas mounts over it.
- **Scroll.** OrbitControls sets `touch-action: none` on the canvas, which traps page scroll on phones. Inline on a scrolling page, set `canvas.style.touchAction = 'pan-y'`, lock the polar angle so a drag only rotates horizontally, and turn wheel zoom off (`controls.enableZoom = false`); full orbit and zoom live in an expanded mode or behind a tap-to-interact gate. The UX spec's input map decides.
- **One renderer per page.** Browsers cap live contexts. Several views share one canvas through scissored viewports (drei `<View>`).
- **Accessible.** The canvas has `role="img"` and an `aria-label`, or is `aria-hidden` beside a DOM alternative that carries the same facts. Controls live in the DOM, not in the scene.
- **Reduced motion:** `animation.md` § Motion on demand.

## Picking

```ts
// setup/pick.ts
import * as THREE from 'three'

const raycaster = new THREE.Raycaster(), ndc = new THREE.Vector2() // reused: picking allocates nothing

export function pick(event: PointerEvent, canvas: HTMLCanvasElement, camera: THREE.Camera, pickables: THREE.Object3D[]) {
  const r = canvas.getBoundingClientRect() // the canvas, never window.inner*: the scene is a section of a page
  ndc.set(((event.clientX - r.left) / r.width) * 2 - 1, -((event.clientY - r.top) / r.height) * 2 + 1)
  raycaster.setFromCamera(ndc, camera)
  return raycaster.intersectObjects(pickables, true)[0] // only what can be picked, never the whole scene
}

// A tap is a pointerup within a few pixels of its pointerdown; anything longer was a drag on the controls.
export function onTap(canvas: HTMLCanvasElement, handler: (event: PointerEvent) => void, slop = 6) {
  let x = 0, y = 0
  canvas.addEventListener('pointerdown', (e) => { x = e.clientX; y = e.clientY })
  canvas.addEventListener('pointerup', (e) => { if (Math.hypot(e.clientX - x, e.clientY - y) <= slop) handler(e) })
}
```

Raycast on pointer events, never per frame. Dense meshes need three-mesh-bvh, or each ray tests every triangle. In XR the same function takes the controller's ray instead of pointer coordinates (`xr.md` § Adding XR to an existing scene).

## Color

Wrong color is a fault in a chain. Check the links in order and stop at the first wrong one.

1. **Texture tags.** Color maps (base color, emissive) are `SRGBColorSpace`; data maps (normal, occlusion, roughness, metalness) stay `NoColorSpace`. `GLTFLoader` sets both; a texture loaded by hand needs it set.
2. **Colors in code.** `setHex` and CSS strings read sRGB. `setRGB(r, g, b)` reads the linear working space, so values from a design tool need `SRGBColorSpace` as the fourth argument.
3. **Lights and environment.** Light units are physical. `scene.environmentIntensity` (r163+) scales the environment; `envMapIntensity` scales only a material's own `envMap`.
4. **Tone mapping,** set explicitly. Neutral keeps saturated product hues that ACES Filmic shifts. `toneMapped = false` on UI and unlit brand colors.
5. **Output.** The sRGB conversion happens once, on the final write. With a post stack, every pass before the last stays linear and the last one tone-maps and converts (`shaders.md` § Post-processing). Custom GLSL that writes to the screen on `WebGLRenderer` needs `#include <tonemapping_fragment>` and `#include <colorspace_fragment>`.

**After an upgrade,** read the Migration Guide for every release crossed before tuning anything (`landscape.md` § Look-changing releases). Code written before a default changed often carries compensations: intensity multipliers, gamma passes, hand-converted colors, exposure tweaks. Remove them with the fix, then re-baseline the screenshots once the look is approved.

## Audio

three's `AudioListener` plus `PositionalAudio` cover sample playback and 3D panning. Add the listener to the camera; in XR it then follows the head with no manual sync.

- **Unlock on a gesture.** Browsers start the `AudioContext` suspended: call `listener.context.resume()` in the first `pointerdown`. In XR, the Enter VR or AR click is that gesture.
- **Pause with the page.** Suspend the context on `visibilitychange` and when the canvas leaves the viewport. A hidden tab stops the render loop, not audio.
- **Budget voices.** Spatial panning costs CPU per source: cap simultaneous positional sources on phones, and play music and UI sounds through non-positional `THREE.Audio`.
