# R3F Performance

Budget, diagnosis and the general levers: `../performance.md`.

- Frame probe (`../performance.md` § Budget): `addEffect(begin)` and `addAfterEffect(end)`; both receive the frame timestamp and return an unsubscribe for unmount.
- Static scenes: `frameloop="demand"`, then `invalidate()` after every mutation, or the scene freezes.
- `<Instances limit={n}>` is one `InstancedMesh` (`limit` must cover every child rendered); `<Merged meshes={...}>` gives one draw per mesh type per material.
- Frame pacing, outside XR only: `frameloop="never"`, then call `advance(timestamp)` from your own rAF on every second frame.

## Adaptive DPR

`<AdaptiveDpr>` follows only `performance.current`, which moves when something calls `regress()`. Drive the Canvas DPR from `PerformanceMonitor` with bounds a few percent under the measured rate: its defaults (`[40, 60]` below 100 Hz) decline only once most samples fall under 40 fps, far past the budget.

```tsx
function App() {
  const [dpr, setDpr] = useState(1.5)
  return (
    <Canvas dpr={dpr}>
      <PerformanceMonitor bounds={(hz) => [hz * 0.95, hz * 0.97]}
        onChange={({ factor }) => setDpr(Math.min(window.devicePixelRatio, Math.round(10 + 10 * factor) / 10))}>
        <Scene />
      </PerformanceMonitor>
    </Canvas>
  )
}
```

`factor` moves 0.1 per evaluation (about 2.5 s), stepping DPR between 1 and 2. A numeric `dpr` is used as given, hence the `devicePixelRatio` cap. Every incline counts toward `flipflops`, even at the cap, so `flipflops={3}` with an `onFallback` that lowers DPR drops a healthy device after about 10 s.

## Worker sync

When a physics or ECS worker publishes transforms in a SharedArrayBuffer (`../threading.md` § SharedArrayBuffer layout and sync), read them in one `useFrame`, with no React state: call `readLatest()` once (`../physics.md` § Worker path), then `lerpSlerp` each mesh `i` from `framePrev` and `frameCurr` at offset `i * 7`, for `i` below both the mesh count and `framePrev.length / 7` (never read past the buffer). Mesh `i` must match body `i` in the worker's stable order: fill a `meshes` ref array from each mesh's ref callback, and skip empty slots.
