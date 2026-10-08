# Threading: Placement, Isolation, Build Config, Sync

The main thread owns input, the DOM, rendering and the XR frame loop. Every extra thread adds latency, a build target and a failure mode, so move work only when the floor device's numbers say so. R3F consumers of worker data: `react/performance.md`.

## Placement

- **Rendering and scene graph:** main thread. OffscreenCanvas renders WebGL 2 in a worker in every engine (Safari 17+; MDN BCD, 2026-10), but input, DOM sync and WebXR stay on the main thread. Worth it only when the host page's long tasks, not the scene, drop frames and input reduces to forwarded pointer deltas; never for XR or DOM-overlaid UI.
- **ECS, physics, per-element math:** SKILL.md's State, Physics and Compute rows; past the threshold, pure-data ECS systems and the physics step (`physics.md` § Worker path) may move.
- **Pathfinding, procedural generation, mesh processing:** a worker or pool for one-shot jobs over a frame budget; results land frames later.
- **Asset decoding:** Draco and KTX2 already decode in worker pools; meshopt only after `MeshoptDecoder.useWorkers(n)`. The usual stall is GPU upload and shader compile instead: KTX2 + `initTexture`, `compileAsync` (`assets.md`).

**Threshold.** Offload recurring work whose p95 exceeds about 15% of the frame budget on the floor device (≈ 2.5 ms at 60 Hz, ≈ 1.7 ms at 90 Hz), and one-shot work longer than one frame budget.

## Transfer

Per-step transforms ping-pong in two preallocated transferred buffers, or sit in a SharedArrayBuffer (below); WASM memory must be copied out first (`wasm.md`). Workers are long-lived; never spawn one per task. A pool keeps **one persistent `onmessage` per worker** and routes replies by a request id the worker echoes back; reassigning `worker.onmessage` per request clobbers in-flight resolvers once tasks outnumber workers.

## Cross-origin isolation

Only SharedArrayBuffer and WASM threads need `crossOriginIsolated === true`, and it costs:
- **COOP `same-origin`** severs `window.opener`, breaking OAuth and payment popups that report back. Send it on the 3D route only.
- **COEP `require-corp`** blocks every cross-origin subresource (images, iframes, decoders, HDRIs, fonts) without CORP or CORS. **`credentialless`** instead loads no-cors resources without cookies (Chromium and desktop Firefox; not Safari or Firefox for Android, which then stay unisolated and need the `postMessage` path; MDN BCD, 2026-10). Check each host the scene loads from; self-host what you can.

```ts
const canShare = typeof SharedArrayBuffer !== 'undefined' && self.crossOriginIsolated === true
// false → the transfer path; headers "being set" proves nothing
```

## Vite config

The one copy in this skill; other files point here.

```ts
// vite.config.ts
import { defineConfig } from 'vite'
import wasm from 'vite-plugin-wasm'

const isolation = { // only if SharedArrayBuffer was chosen (SKILL.md, Threads row)
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'credentialless', // or 'require-corp'
}

export default defineConfig({
  plugins: [wasm()],                                 // add react() in R3F apps
  worker: { format: 'es', plugins: () => [wasm()] }, // config.plugins reaches workers only in dev
  build: { target: 'esnext' },                       // native top-level await: no TLA plugin
  // server: { headers: isolation }, preview: { headers: isolation },
})
```

- Dev and preview headers never ship: the production host must send them on the 3D route's document.
- Safari before 27 mishandles a top-level-await module imported by several modules at once (MDN BCD; WebKit bug 242740), which is how bundled WASM glue loads. For older iOS, use init-style builds (wasm-pack `--target web` plus `await init()`, Rapier's `-compat`) and test the production build on an iPhone.

## SharedArrayBuffer layout and sync

One layout module, imported by both threads, owns stride and offsets; one stride per buffer.

```ts
// shared/layout.ts
export const STRIDE = 7 // px py pz qx qy qz qw
export const slotOffset = (slot: number, buf: 0 | 1, n: number) => (slot * 2 + buf) * n * STRIDE // buf 0 prev, 1 curr
// views over SharedArrayBuffers: data Float32Array, 2 slots × (prev, curr) × n × STRIDE;
// time Float64Array(2), each slot's step time; ctrl Int32Array(1), seq: the publish count (newest slot = seq & 1)
```

- **Publish by sequence number** (code: `physics.md` § Worker path). The worker fills the unpublished slot, then `Atomics.store`s `seq + 1`; the reader copies slot `seq & 1` and retries if `seq` moved, since a catch-up loop can be rewriting that slot.
- **Unsynchronized reads tear** (this step's position, last step's rotation). Tolerable only for independent bodies; jointed or attached bodies, alive flags and state changes need the sequence check.
- **`Atomics` need an integer view** (`Int32Array`) and throw `TypeError` on a `Float32Array`. Keep flags in their own `Int32Array`, indexed through the layout, never by a bare entity index.
- **`Atomics.wait` throws on the main thread**; use `Atomics.waitAsync`, or read once per frame.
- **Clocks differ per thread**: compare times as `performance.timeOrigin + performance.now()`.
- **Pause with the page.** On `visibilitychange`, post `pause`/`resume` to every simulation worker; on resume, reset its accumulator and last timestamp so it doesn't fast-forward. Preallocate every SharedArrayBuffer at startup; attributes fed from one are `DynamicDrawUsage`.
