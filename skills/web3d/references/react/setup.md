# React Three Fiber: Setup and Lifecycle

The R3F side of SKILL.md's Build steps, for R3F 9 on React 19.

## WebGPU Canvas

```tsx
import * as THREE from 'three/webgpu'
import { Canvas, extend, type ThreeToJSXElements } from '@react-three/fiber'

declare module '@react-three/fiber' { interface ThreeElements extends ThreeToJSXElements<typeof THREE> {} }
extend(THREE as any)

const glFactory = async (props) => {
  const renderer = new THREE.WebGPURenderer({ ...props, antialias: true } as any) // XR: forceWebGL (r173+), multiview (r176+)
  await renderer.init()
  return renderer
}

<ErrorBoundary fallback={<Poster />}>
  <Canvas gl={glFactory} dpr={[1, 2]} onCreated={({ gl }) => {
    gl.toneMapping = THREE.NeutralToneMapping       // R3F's default is ACES Filmic
    const stop = gl.onDeviceLost.bind(gl)           // r170+; three's handler halts rendering: keep it
    gl.onDeviceLost = (info) => { stop(info); showPosterAndRemount() }
  }}>
    <Scene />
  </Canvas>
</ErrorBoundary>
```

- R3F 9 waits for an async `gl` factory before the first frame (checked 9.8); a rejected `init()` fails the root, so the error boundary shows the poster. R3F 8 calls the factory synchronously with the canvas, and an async factory silently yields a plain `WebGLRenderer`: construct `new WebGPURenderer({ canvas })` there and hold `frameloop="never"` until `init()` resolves.
- R3F sets ACES Filmic tone mapping on first configure (`NoToneMapping` with `flat`), overriding anything set inside the factory: set yours in `onCreated`.
- XR apps without TSL can keep R3F's default `WebGLRenderer` (`web-xr.md`). Build config: `../threading.md` § Vite config, plus `react()`.
- Next.js: code-split the Canvas with `next/dynamic` and `ssr: false`, called inside a Client Component.

## Lifecycle

- Render on demand, adaptive DPR and frame pacing: `performance.md`.
- Animated scenes switch to `frameloop="never"` while an IntersectionObserver reports the canvas offscreen; workers and audio need their own pause.
- On unmount R3F disposes objects it created from JSX, but not `<primitive>` objects, objects passed as props, or loader caches: call `useGLTF.clear(url)` for models that won't return.

## useFrame

Mutate refs inside `useFrame`; never `setState` there, which re-renders the component at the display's rate (60, 90, 120 Hz or more). R3F's `delta` comes unclamped from its clock: `const dt = Math.min(delta, 0.1)`.

## Loading

```tsx
function Model({ url }: { url: string }) {
  const { scene } = useGLTF(url)        // suspends; Draco and meshopt decoders are wired automatically
  return <Clone object={scene} />       // the cached scene is shared: clone per placement
}

<ErrorBoundary fallback={<Poster />}>
  <Suspense fallback={<Poster />}><Model url="/model.glb" /></Suspense>
</ErrorBoundary>
```

- Without the error boundary, a 404 or decode failure crashes the tree. `useGLTF.preload(url)` starts the fetch at module load.
- Draco decoders load from a CDN by default; self-host with `useGLTF.setDecoderPath('/draco/')` in new code (on a working app that is a shared-loader change: `../assets.md` § Loading). KTX2 textures need a `KTX2Loader` set through `useGLTF`'s `extendLoader` argument.
- `gltfjsx` generates typed components; what its `--transform` does to the asset, and the flags for name-addressed parts: `../assets.md` § Inspect, then optimize.

## Events

- R3F raycasts every object that has pointer handlers on each pointer move: keep handlers on few objects, and wrap dense meshes in drei's `<Bvh>` or use `raycast={meshBounds}`.
- `onClick` also fires after an orbit drag; ignore clicks whose `e.delta` (pixels between down and up) exceeds a few pixels.
