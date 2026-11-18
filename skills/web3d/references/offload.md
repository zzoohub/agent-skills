# Offload: Workers, Shared Memory, WASM

The main thread owns input, the DOM, rendering and the XR frame loop. Every extra thread adds latency, a build target and a failure mode, and WASM adds a boundary that costs per call. Move work only when the floor device's numbers say so.

## Placement

- **Rendering and the scene graph:** main thread. OffscreenCanvas can render in a worker, but input, DOM sync and WebXR stay on the main thread. Worth it only when the host page's long tasks, not the scene, drop frames, and input reduces to forwarded pointer deltas. Never for XR or UI overlaid in the DOM.
- **Per-element math on many elements:** the GPU first (`shaders.md` § Compute), not a worker.
- **Physics and pure-data ECS systems:** main thread until the step's p95 passes about 15% of the frame budget on the floor device (about 2.5 ms at 60 Hz, 1.7 ms at 90 Hz). Then `physics.md` § The worker path.
- **Pathfinding, procedural generation, mesh processing:** a worker for any one-off job longer than a frame. Results land frames later.
- **Asset decoding:** Draco and KTX2 already decode in worker pools; meshopt only after `MeshoptDecoder.useWorkers(n)`. The usual stall is GPU upload and shader compile instead (`assets.md` § Pre-warm).

## Workers

- **Long-lived.** Never spawn a worker per task. A pool keeps one persistent `onmessage` per worker and routes replies by a request id the worker echoes back. Reassigning `worker.onmessage` per request clobbers in-flight resolvers as soon as tasks outnumber workers.
- **A worker that imports WASM is not listening yet.** Its module awaits the WASM before it reaches the line that sets `onmessage`, and a message posted in that window is dropped, silently. The worker posts `ready` as its last line and the main thread sends its first message in reply (`physics.md` § The worker path).
- **Transfer, do not copy.** Per-step data moves in transferable buffers, ping-ponging two preallocated ones. WASM memory must be copied out first: a view over it cannot be transferred.
- **Pause with the page.** A hidden tab stops `requestAnimationFrame`, not workers. Post `pause` and `resume` on `visibilitychange`, and reset the worker's accumulator and timestamp on resume so it does not fast-forward.

## Cross-origin isolation

Only `SharedArrayBuffer` and WASM threads need `crossOriginIsolated === true`, and it costs:

- **COOP `same-origin`** severs `window.opener`, which breaks OAuth and payment popups that report back. Send it on the 3D route only.
- **COEP `require-corp`** blocks every cross-origin subresource (images, iframes, decoders, HDRIs, fonts) that lacks CORP or CORS. **`credentialless`** loads no-cors resources without cookies instead, but not every browser has it (`landscape.md` § Platform support): where it is missing the page stays unisolated and needs the `postMessage` path. Check each host the scene loads from, and self-host what you can.

```ts
const canShare = typeof SharedArrayBuffer !== 'undefined' && self.crossOriginIsolated === true
// false: take the transfer path. Headers "being set" proves nothing
```

Keep the transfer path working and tested. It is the fallback on every browser and host where isolation is missing.

## Bundler config

```ts
// vite.config.ts
import { defineConfig } from 'vite'

const isolation = { // only if SharedArrayBuffer was chosen (SKILL.md § Size the stack)
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'credentialless', // or 'require-corp'
}

export default defineConfig({
  worker: { format: 'es' }, // a module that imports WASM uses top-level await, which the default iife worker cannot hold
  optimizeDeps: { exclude: ['@dimforge/rapier3d'] }, // every dependency that imports a .wasm file: pre-bundled, its glue loads twice in dev
  build: { target: 'esnext' }, // native top-level await
  server: { headers: isolation },
  preview: { headers: isolation }, // dev and preview only: production needs the host to send them
})
```

- **This is Vite 8.** It loads WASM module imports natively, on the main thread and in workers. Vite 7 and older need `vite-plugin-wasm`, in `plugins` and again in `worker.plugins` (the top-level `plugins` reach workers only in dev).
- **Test the production build, not only dev.** The two paths differ: without the `optimizeDeps.exclude` line above, a WASM package from `node_modules` works in the build and fails in dev (`landscape.md` § Tooling).
- **Dev and preview headers never ship.** The production host must send the isolation headers on the 3D route's document.
- **An inlined build sidesteps the bundler.** Rapier's `-compat`, or a wasm-pack `--target web` build with `await init()`, loads anywhere, at the price of a larger download. Also the way out for older iOS, whose Safari mishandles a top-level-await module imported by several modules at once.

## Shared memory

One layout module, imported by both threads, owns stride and offsets. The worker fills the slot that is not published, then publishes it by bumping a counter; the reader copies the published slot and reads again if the counter moved.

```ts
// offload/snapshots.ts
// One layout module, imported by both threads. Two slots, each holding prev and curr transforms for every body.
export const STRIDE = 7 // px py pz qx qy qz qw

export type Shared = { data: SharedArrayBuffer; time: SharedArrayBuffer; ctrl: SharedArrayBuffer }

export const allocate = (count: number): Shared => ({ // once, at startup
  data: new SharedArrayBuffer(2 * 2 * count * STRIDE * 4),
  time: new SharedArrayBuffer(2 * 8),
  ctrl: new SharedArrayBuffer(4),
})

export function views(shared: Shared, count: number) {
  const size = count * STRIDE
  const data = new Float32Array(shared.data)
  return {
    size,
    data,
    time: new Float64Array(shared.time), // each slot's step time
    ctrl: new Int32Array(shared.ctrl), // seq, the publish count. Atomics need an integer view
    slots: [data.subarray(0, 2 * size), data.subarray(2 * size, 4 * size)], // made once: no garbage per frame
  }
}
type Views = ReturnType<typeof views>

// Worker, after each step (and twice at start, so both slots hold the spawn pose).
export function publish(v: Views, write: (curr: Float32Array) => void) {
  const seq = Atomics.load(v.ctrl, 0), slot = 1 - (seq & 1) // the published slot is never written
  const next = v.slots[slot]
  next.set(v.slots[seq & 1].subarray(v.size), 0) // prev = the last curr
  write(next.subarray(v.size))
  v.time[slot] = performance.timeOrigin + performance.now() // clocks differ per thread: share the origin
  Atomics.store(v.ctrl, 0, seq + 1) // publish: the newest slot is now seq & 1
}

// Main thread, once per frame: copies the newest slot into frame (prev, then curr) and returns t in 0..1.
export function readLatest(v: Views, frame: Float32Array, stepMs: number) {
  let seq: number, stamp: number
  do {
    seq = Atomics.load(v.ctrl, 0)
    frame.set(v.slots[seq & 1])
    stamp = v.time[seq & 1]
  } while (Atomics.load(v.ctrl, 0) !== seq) // published during the copy: it may be torn, so read again
  return Math.min((performance.timeOrigin + performance.now() - stamp) / stepMs, 1)
}
```

- **Unsynchronized reads tear:** this step's position with last step's rotation. Tolerable only for independent bodies. Jointed or attached bodies, alive flags and state changes need the counter check.
- **`Atomics` need an integer view** (`Int32Array`) and throw `TypeError` on a `Float32Array`. Keep flags in their own `Int32Array`, indexed through the layout.
- **`Atomics.wait` throws on the main thread.** Use `Atomics.waitAsync`, or read once per frame.
- **Clocks differ per thread.** Compare times as `performance.timeOrigin + performance.now()`.
- **Allocate every `SharedArrayBuffer` at startup,** and set attributes fed from one to `DynamicDrawUsage`.

## Rust WASM

**When it wins.** Profile a JavaScript baseline on the floor device first, then measure the WASM version against it, and keep WASM only for a clear win. It wins on hot numeric kernels over large typed arrays that keep their data inside WASM between calls (spatial queries, IK, grid pathfinding, mesh processing), on SIMD-friendly loops, and where garbage-collection pauses hurt. It loses when the work per call is small, when it touches three.js objects, or when it crosses the boundary per element. Per-element work whose state can live on the GPU belongs in compute instead.

**One call per frame.** `update(dt)` over data WASM owns. Never pass a `Vec<f32>` in a hot path: each call copies the whole array. `serde-wasm-bindgen` is for setup and config only.

**Build.**
- One wasm-pack target per output directory: `--target bundler` for imports through the bundler, `--target web` (an `init()` default export) for workers without bundler support, for threads, and wherever top-level await must be avoided. Never import both from one `pkg`.
- Compute crates build with `opt-level = 3` (`"z"` slows hot loops), plus `RUSTFLAGS='-C target-feature=+simd128'` when the kernel vectorizes.

**Memory views and growth.** JavaScript sees a Rust-owned buffer through a pointer. Any Rust allocation can grow linear memory, and growth detaches every such view: its length becomes 0 and its reads `undefined`, with no error.

```rust
#[wasm_bindgen]
impl Particles {
    pub fn update(&mut self, dt: f32) { /* mutate in place: no push, no resize */ }
    pub fn positions_ptr(&self) -> *const f32 { self.positions.as_ptr() }
}
```

```ts
// offload/wasm-view.ts
import * as THREE from 'three'

// sim: a wasm-bindgen struct that owns a Vec<f32> of positions; memory: the module's WebAssembly.Memory
export function createPositionSync(memory: WebAssembly.Memory, sim: { positions_ptr(): number }, count: number, geometry: THREE.BufferGeometry) {
  let view = new Float32Array(memory.buffer, sim.positions_ptr(), count * 3)
  const attach = () => {
    const attribute = new THREE.BufferAttribute(view, 3)
    attribute.setUsage(THREE.DynamicDrawUsage) // a fresh attribute reverts to static usage
    geometry.setAttribute('position', attribute)
  }
  attach()
  return () => { // after every call into WASM, every frame
    if (view.buffer !== memory.buffer) { // memory grew: the old view is detached, length 0, and reads undefined
      view = new Float32Array(memory.buffer, sim.positions_ptr(), count * 3)
      attach()
    }
    geometry.attributes.position.needsUpdate = true
  }
}
```

1. Allocate every buffer in the constructor; never `push` or `resize` in per-frame calls.
2. Run the buffer check after every call into WASM, every frame. Without it the scene silently renders stale data.
3. Rebuild views on the JavaScript side as above. A view handed out from Rust must not outlive any allocation.
4. `.free()` long-lived structs on teardown. In React, create them in `useEffect` and free them in its cleanup, never during render: StrictMode mounts twice in development, and anything else double-frees or leaks.

**In workers.** Return owned copies from WASM before transferring them, `free()` the struct before posting the result, and announce `ready` (§ Workers).

**Threads** (wasm-bindgen-rayon). Only with cross-origin isolation and a measured win over single-threaded WASM. Build with the flags and the pinned nightly its README gives, and call `initThreadPool` only when `crossOriginIsolated` is true, loading a single-threaded build otherwise. Thread hand-off has overhead: parallelize large batches, not per-frame slivers.
