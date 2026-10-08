# Rust WASM

R3F integration: `react/wasm.md`. Bundler and worker config: `threading.md` § Vite config.

## When WASM wins

Profile a JS baseline on the floor device first, then measure the WASM version against it; keep WASM only for a clear win. It wins on hot numeric kernels over large typed arrays (particles, terrain, spatial queries, IK, grid pathfinding) that keep their data inside WASM between calls, on SIMD-friendly loops, and where GC pauses hurt. It loses when work per call is small, when it touches three.js objects, or when it crosses the boundary per element: make one `update(dt)` call per frame, and never pass a `Vec<f32>` in a hot path, since each call copies the whole array.

## Build

- **One wasm-pack target per output directory.** `--target bundler` for main-thread imports through `vite-plugin-wasm`; `--target web` (an `init()` default export) for workers without the plugin, for wasm-bindgen-rayon, and wherever top-level await must be avoided. Never import both from one `pkg`: give the second its own `--out-dir pkg-web`.
- **Compute crates** build with `opt-level = 3` (`"z"` only for cold, size-bound modules: it slows hot loops), plus `RUSTFLAGS='-C target-feature=+simd128'` when the kernel vectorizes (Wasm SIMD is Baseline).
- `serde-wasm-bindgen` for setup and config only, never per frame.

## Memory views and growth

JS views a Rust-owned buffer through a pointer. Any Rust allocation can grow linear memory, and growth detaches every such view: zero length, stale or zero data, no error.

```rust
#[wasm_bindgen]
impl Particles {
    pub fn update(&mut self, dt: f32) { /* mutate in place: no push or resize */ }
    pub fn positions_ptr(&self) -> *const f32 { self.positions.as_ptr() }
}
```

```ts
// memory: `import { memory } from '<pkg>/<name>_bg.wasm'` (bundler target) or `(await init()).memory` (web target)
let view = new Float32Array(memory.buffer, sim.positions_ptr(), COUNT * 3)

function syncPositions(geometry: THREE.BufferGeometry) { // after every call into WASM
  if (view.buffer !== memory.buffer) {                  // memory grew: the old view is dead
    view = new Float32Array(memory.buffer, sim.positions_ptr(), COUNT * 3)
    const attr = new THREE.BufferAttribute(view, 3)
    attr.setUsage(THREE.DynamicDrawUsage)               // a fresh attribute reverts to static usage
    geometry.setAttribute('position', attr)
  }
  geometry.attributes.position.needsUpdate = true
}
```

1. Allocate every buffer in the constructor; never `push` or `resize` in per-frame calls.
2. Run the buffer check after every call into WASM, every frame. Without it the scene silently renders stale data.
3. Don't use `js_sys::Float32Array::view` from Rust: its view must not outlive any allocation. Rebuild views on the JS side as above.
4. `.free()` long-lived structs on teardown; `FinalizationRegistry` cleanup is non-deterministic and unsafe for large buffers.

## Workers

- Return **owned copies** (`Vec<f32>` results or explicit copies) from WASM before transferring them: a view over WASM memory can't be transferred, because that `ArrayBuffer` (a SharedArrayBuffer under threads) cannot be detached.
- `free()` the struct before posting the result.
- Load the module in the worker with `--target web` and `await init()`, or the bundler build through `worker.plugins`.

## Threads (wasm-bindgen-rayon)

Only with cross-origin isolation (`threading.md`) and a measured win over single-threaded WASM.
- Build with `--target web` and the flags the wasm-bindgen-rayon README gives (atomics, bulk memory, `build-std`), on the nightly it names, pinned in `rust-toolchain.toml` (floating nightlies break); re-check them on upgrade.
- Call `await init()` then `await initThreadPool(navigator.hardwareConcurrency)` only when `crossOriginIsolated` is true; otherwise load a single-threaded build. Safari is isolated only under `require-corp`, since it lacks `credentialless` (MDN BCD, 2026-10).
- Thread hand-off has overhead; parallelize large batches, not per-frame slivers.
