# Rust WASM Integration Reference

Use Rust WASM for compute-heavy tasks: particle systems, terrain generation, pathfinding, spatial queries, custom physics, IK solvers, audio processing.

> For framework-specific integration patterns (R3F components, hooks): `react/wasm.md`

## Table of Contents

1. [Setup](#setup)
2. [wasm-bindgen Patterns](#wasm-bindgen-patterns)
3. [Typed Array Patterns](#typed-array-patterns)
4. [Memory Safety Rules (Critical)](#memory-safety-rules-critical)
5. [Web Workers + WASM](#web-workers--wasm)
6. [Parallel Computation (wasm-bindgen-rayon)](#parallel-computation-wasm-bindgen-rayon)
7. [Performance Rules](#performance-rules)
8. [Key Crates](#key-crates)

## Setup

### Prerequisites

```bash
rustup target add wasm32-unknown-unknown
cargo install wasm-pack
bun add -d vite-plugin-wasm vite-plugin-top-level-await
```

### Cargo.toml

```toml
[package]
name = "my-wasm-3d"
version = "0.1.0"
edition = "2024"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"
serde = { version = "1", features = ["derive"] }
serde-wasm-bindgen = "0.6"
console_error_panic_hook = "0.1"

[dependencies.web-sys]
version = "0.3"
features = ["console"]

[profile.release]
opt-level = "z"
strip = true
lto = true
codegen-units = 1
```

### Build

```bash
# For Vite bundler
wasm-pack build --target bundler --release

# For direct browser ESM
wasm-pack build --target web --release
```

### Project Structure

```
crates/
  my-wasm-3d/
    Cargo.toml
    src/lib.rs
src/
  main.ts
  workers/compute.worker.ts
vite.config.ts
```

Import in TypeScript (with `--target bundler` + `vite-plugin-wasm`):

```typescript
import { MyStruct, my_function } from '../crates/my-wasm-3d/pkg'
```

### Init with Panic Hook

```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen(start)]
pub fn init() {
    console_error_panic_hook::set_once();
}
```

## wasm-bindgen Patterns

### Basic Exports

```rust
#[wasm_bindgen]
pub fn add(a: f64, b: f64) -> f64 { a + b }

#[wasm_bindgen]
pub fn greet(name: &str) -> String { format!("Hello, {}!", name) }
```

Common supported types: `i32`, `u32`, `i64`/`u64` (marshalled as JS `BigInt`), `f32`, `f64`, `bool`, `String`, `&str`, `Vec<f32>`, `Vec<u8>`, `Option<T>`, `JsValue`.

### Structs

```rust
#[wasm_bindgen]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[wasm_bindgen]
impl Vec3 {
    #[wasm_bindgen(constructor)]
    pub fn new(x: f32, y: f32, z: f32) -> Vec3 { Vec3 { x, y, z } }

    pub fn length(&self) -> f32 {
        (self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
    }
}
```

### C-style Enums

```rust
#[wasm_bindgen]
pub enum SimMode { Particles = 0, Fluid = 1, Cloth = 2 }
```

For enums with data, use `serde-wasm-bindgen`:

```rust
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
pub enum Shape {
    Sphere { radius: f32 },
    Box { half_extents: [f32; 3] },
}

#[wasm_bindgen]
pub fn create_shape(val: JsValue) -> Result<JsValue, JsValue> {
    let shape: Shape = serde_wasm_bindgen::from_value(val)?;
    serde_wasm_bindgen::to_value(&shape).map_err(|e| e.into())
}
```

`serde_wasm_bindgen` serializes enums **externally-tagged** by default (`{ Sphere: { radius } }` on the JS side, which differs from `serde_json`). Add `#[serde(tag = "type")]` for a flatter discriminated-union shape (`{ type: "Sphere", radius }`).

### Error Handling

```rust
#[wasm_bindgen]
pub fn divide(a: f64, b: f64) -> Result<f64, JsValue> {
    if b == 0.0 { Err(JsValue::from_str("Division by zero")) }
    else { Ok(a / b) }
}
```

## Typed Array Patterns

### Approach 1: Vec (copies data)

```rust
#[wasm_bindgen]
pub fn process(positions: Vec<f32>) -> Vec<f32> {
    let mut result = positions; // data was COPIED from JS
    for i in (0..result.len()).step_by(3) {
        result[i] *= 2.0;
    }
    result // returns as new Float32Array (another copy)
}
```

Simple but doubles memory for large arrays. Fine for one-time operations.

### Approach 2: Zero-Copy Memory View

```rust
#[wasm_bindgen]
pub struct ParticleSystem {
    count: usize,
    positions: Vec<f32>,
    velocities: Vec<f32>,
}

#[wasm_bindgen]
impl ParticleSystem {
    #[wasm_bindgen(constructor)]
    pub fn new(count: usize) -> Self {
        Self {
            count,
            positions: vec![0.0; count * 3],
            velocities: vec![0.0; count * 3],
        }
    }

    pub fn update(&mut self, dt: f32) {
        for i in 0..self.positions.len() {
            self.positions[i] += self.velocities[i] * dt;
        }
    }

    pub fn positions_ptr(&self) -> *const f32 { self.positions.as_ptr() }
    pub fn count(&self) -> usize { self.count }
}
```

TypeScript side (zero-copy via WASM memory):

```typescript
import { ParticleSystem } from '../crates/my-wasm-3d/pkg'
import { memory } from '../crates/my-wasm-3d/pkg/my_wasm_3d_bg.wasm'

const COUNT = 1_000_000
const particles = new ParticleSystem(COUNT)

// Zero-copy view into WASM linear memory
let posArray = new Float32Array(memory.buffer, particles.positions_ptr(), COUNT * 3)

const geo = new THREE.BufferGeometry()
const attr = new THREE.BufferAttribute(posArray, 3)
attr.setUsage(THREE.DynamicDrawUsage)
geo.setAttribute('position', attr)

// In render loop:
particles.update(delta)

// Re-create view if WASM memory grew
if (posArray.buffer !== memory.buffer) {
  posArray = new Float32Array(memory.buffer, particles.positions_ptr(), COUNT * 3)
  const attr = new THREE.BufferAttribute(posArray, 3)
  attr.setUsage(THREE.DynamicDrawUsage)   // a fresh attribute reverts to StaticDrawUsage — re-apply
  geo.setAttribute('position', attr)
}
geo.attributes.position.needsUpdate = true
```

### Approach 3: Safe Copy via js_sys

```rust
use js_sys::Float32Array;

pub fn positions_copy(&self) -> Float32Array {
    let arr = Float32Array::new_with_length(self.positions.len() as u32);
    arr.copy_from(&self.positions);
    arr
}
```

## Memory Safety Rules (Critical)

WASM linear memory can grow at any time. When it does, every existing `Float32Array` view into that memory becomes **detached** (zero-length, silently broken). This is the #1 source of invisible bugs in WASM+Three.js apps.

**Every render frame that reads from a WASM pointer view MUST include the buffer check:**

```typescript
// In render loop -- ALWAYS do this check
if (positionView.buffer !== memory.buffer) {
  // Memory grew -- old view is dead, create new one
  positionView = new Float32Array(memory.buffer, system.positions_ptr(), count * 3)
  const attr = new THREE.BufferAttribute(positionView, 3)
  attr.setUsage(THREE.DynamicDrawUsage)   // re-apply — a fresh attribute reverts to StaticDrawUsage
  geometry.setAttribute('position', attr)
}
geometry.attributes.position.needsUpdate = true
```

Rules:
1. Pointer-based JS views (`new Float32Array(memory.buffer, ptr, len)`) are **invalidated** when WASM memory grows (any Rust allocation can trigger this). (The Rust-side `js_sys::Float32Array::view` is an even more dangerous primitive — its own docs warn the view must not outlive any allocation — so this skill uses the JS-side reconstruction pattern shown here instead.)
2. After calling any WASM function, check `view.buffer !== memory.buffer` and re-create the view if they differ
3. Pre-allocate all buffers in the Rust constructor to minimize growth during the render loop
4. For stable views: allocate everything upfront, never `push`/`resize` in `update()`
5. If you skip the buffer check, the app will silently render stale/zero data with no error
6. Long-lived wasm structs must be `.free()`d on teardown — `FinalizationRegistry` auto-free is non-deterministic and unsafe for large buffers (the R3F example frees in its cleanup effect)

## Web Workers + WASM

For heavy compute that would block rendering, move WASM to a Web Worker.

### Worker File

```typescript
// workers/compute.worker.ts — built with `wasm-pack build --target web` (note the `init` default export).
// The `--target bundler` build used on the main thread has NO init export; there you
// `import { TerrainGenerator } from '...'` directly and skip `await init()`.
import init, { TerrainGenerator } from '../crates/my-wasm-3d/pkg'

self.onmessage = async (e: MessageEvent) => {
  const { type, payload } = e.data

  if (type === 'init') {
    await init()
    self.postMessage({ type: 'ready' })
  }

  if (type === 'generateTerrain') {
    const { width, depth, scale, heightScale } = payload
    const terrain = new TerrainGenerator(width, depth, scale, heightScale)
    // positions()/normals()/indices() MUST return OWNED copies (Rust Vec<f32> or a js_sys
    // copy — see Approach 3), NOT zero-copy views over wasm memory: the wasm-memory
    // ArrayBuffer (and SharedArrayBuffer under threads) is not transferable and will throw.
    const positions = terrain.positions()
    const normals = terrain.normals()
    const indices = terrain.indices()
    terrain.free()

    // Transfer ArrayBuffers (zero-copy to main thread)
    self.postMessage(
      { type: 'terrainResult', payload: { positions, normals, indices } },
      [positions.buffer, normals.buffer, indices.buffer]
    )
  }
}
```

### Main Thread

```typescript
const worker = new Worker(
  new URL('./workers/compute.worker.ts', import.meta.url),
  { type: 'module' }
)

worker.postMessage({ type: 'init' })
worker.onmessage = (e) => {
  if (e.data.type === 'ready') {
    worker.postMessage({
      type: 'generateTerrain',
      payload: { width: 512, depth: 512, scale: 0.5, heightScale: 20 }
    })
  }
  if (e.data.type === 'terrainResult') {
    const { positions, normals, indices } = e.data.payload
    // Build BufferGeometry from transferred arrays
  }
}
```

## Parallel Computation (wasm-bindgen-rayon)

For multi-threaded WASM via Web Workers + SharedArrayBuffer:

```toml
[dependencies]
wasm-bindgen-rayon = "1.3"
rayon = "1.10"
```

```rust
use rayon::prelude::*;
pub use wasm_bindgen_rayon::init_thread_pool;

fn compute_height(x: f32, z: f32) -> f32 { /* plug in your noise/height function */ 0.0 }

#[wasm_bindgen]
pub fn parallel_terrain(width: usize, depth: usize, scale: f32) -> Vec<f32> {
    let mut positions = vec![0.0f32; width * depth * 3];
    positions.par_chunks_mut(width * 3).enumerate().for_each(|(z, row)| {
        for x in 0..width {
            row[x * 3] = x as f32 * scale;
            row[x * 3 + 1] = compute_height(x as f32 * scale, z as f32 * scale);
            row[x * 3 + 2] = z as f32 * scale;
        }
    });
    positions
}
```

Build with nightly + atomics. This needs the `rust-src` component, and the exact flag set tracks the wasm-bindgen-rayon README (it drifts across nightly versions — verify before relying on it):

```bash
rustup component add rust-src --toolchain nightly

RUSTFLAGS='-C target-feature=+atomics,+bulk-memory' \
  rustup run nightly wasm-pack build --target web -- -Z build-std=panic_abort,std
```

Init in JS:

```typescript
await init()
// initThreadPool requires a cross-origin-isolated page (self.crossOriginIsolated === true):
// set COOP: same-origin + COEP: require-corp. See references/threading.md for headers/dev config.
await initThreadPool(navigator.hardwareConcurrency)
const terrain = parallel_terrain(1024, 1024, 0.5) // runs across Web Workers
```

## Performance Rules

**DO:**
- Pre-allocate all buffers in Rust constructor
- Batch: one `update(dt)` call per frame, not per-particle
- Use `DynamicDrawUsage` hint on BufferAttribute for per-frame updates
- Transfer ArrayBuffer ownership via postMessage (zero-copy)
- Use pointer-based views for zero-copy main-thread access

**DON'T:**
- Don't cross the WASM/JS boundary per-element — each call adds per-call overhead (especially for non-numeric args that need marshalling); batch into one `update(dt)` call per frame
- Don't use `Vec<f32>` params for large arrays in hot paths (copies entire array)
- Don't use `serde_wasm_bindgen` in per-frame hot paths (setup/config only)
- Don't assume WASM is always faster than JS -- WASM wins on large datasets, SIMD-friendly work, and GC-free deterministic perf

## Key Crates

| Crate | Purpose |
|---|---|
| `wasm-bindgen` | Rust-JS bindings |
| `js-sys` | JS built-in types (Array, TypedArrays, Math) |
| `web-sys` | Web APIs (DOM, WebGL, Canvas) |
| `serde-wasm-bindgen` | Serde for complex types |
| `console_error_panic_hook` | Better panic messages in console |
| `wasm-bindgen-rayon` | Rayon parallelism over Web Workers |
| `noise` | Perlin/Simplex/FBM noise |
