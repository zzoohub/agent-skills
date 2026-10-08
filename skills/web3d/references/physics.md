# Rapier Physics (raw API)

R3F bindings: `react/physics.md`. Thread placement and the shared-buffer protocol: `threading.md`.

## Pick one build

- `@dimforge/rapier3d`, the default with `vite-plugin-wasm` (`threading.md` § Vite config): the WASM initializes on import, and `RAPIER.init()` doesn't exist ("init is not a function").
- `@dimforge/rapier3d-compat`: `await RAPIER.init()` first; the WASM is inlined, so a larger download. For bundlers that can't serve a separate `.wasm`, or older Safari's top-level-await bug.
- `-simd` variants step faster and need Wasm SIMD; `@dimforge/rapier3d-deterministic` makes results match across machines. Each `-compat` twin needs `init()`.

`@react-three/rapier` bundles its own pinned `rapier3d-compat` (0.19.x at 2.2, older than raw Rapier), so a raw-Rapier worker beside the React bindings ships two different WASM builds. One stack per app.

**Determinism.** At a fixed step Rapier is locally deterministic: same build, machine and inputs in the same order. It has no seed. Snapshot tests compared between CI and laptops, lockstep netcode and shared replays need the `-deterministic` build. `world.takeSnapshot()` returns bytes; `RAPIER.World.restoreSnapshot(bytes)` rebuilds the world.

## API traps

- **Shapes.** `ColliderDesc.convexHull(points)` returns `null` on degenerate input; guard it. `trimesh` belongs on fixed bodies; dynamic bodies use primitives, convex hulls or a convex decomposition. `capsule(halfHeight, radius)`.
- **Forces.** `addForce` persists across steps until `resetForces(true)`; `applyImpulse` is one-off.
- **Events are opt-in per collider** (default `ActiveEvents.NONE`: silence). Sensors report through `drainCollisionEvents`; there is no separate intersection drain. The default collision types skip pairs of non-dynamic bodies, so a kinematic player never trips a fixed sensor without `KINEMATIC_FIXED`:

```ts
const events = new RAPIER.EventQueue(true)
world.createCollider(
  RAPIER.ColliderDesc.cuboid(5, 5, 1).setSensor(true)
    .setActiveEvents(RAPIER.ActiveEvents.COLLISION_EVENTS)
    .setActiveCollisionTypes(RAPIER.ActiveCollisionTypes.DEFAULT | RAPIER.ActiveCollisionTypes.KINEMATIC_FIXED),
  zoneBody)
world.step(events)
events.drainCollisionEvents((h1, h2, started) => { /* started: enter, false: exit */ })
```

- **Collision groups** are 32 bits: membership in the high 16, filter in the low 16. A pair interacts only if each one's filter includes the other's membership, so for players (group 0) to hit enemies (group 1), widen both filters: player `0x00010003`, enemy `0x00020003`.
- **Iteration order is not identity.** `world.bodies.forEach` passes only the body, in an order that is not spawn order and shifts on removal. Never derive a buffer slot from it; keep your own array of bodies in a stable order.
- **Characters** use Rapier's kinematic character controller, not a dynamic capsule pushed with `setLinvel`: `react/physics.md` § Character controller, whose calls work without React.

## Main-thread loop

The default: a fixed-step accumulator fed the clamped `dt` (SKILL.md, Frame loop), with these rules:
- Set `world.timestep = STEP` (Rapier's default is 1/60) and change both together, or the simulation runs at the wrong speed.
- Cap the accumulator at 5 steps, so a stall can't spiral.
- Before each step copy `curr` into `prev`; after it, write the transforms into `curr`. Render with `t = acc / STEP`.
- Fill `curr` and `prev` from the spawned bodies before the first frame; `bodies[i]` drives `meshes[i]`.

```ts
const qa = new THREE.Quaternion(), qb = new THREE.Quaternion() // reused every frame
export function lerpSlerp(obj: THREE.Object3D, a: Float32Array, b: Float32Array, o: number, t: number) {
  obj.position.set(a[o] + (b[o] - a[o]) * t, a[o + 1] + (b[o + 1] - a[o + 1]) * t, a[o + 2] + (b[o + 2] - a[o + 2]) * t)
  obj.quaternion.slerpQuaternions(qa.fromArray(a, o + 3), qb.fromArray(b, o + 3), t)
}
function applyInterpolated(a: Float32Array, b: Float32Array, t: number) {
  for (let i = 0; i < meshes.length; i++) lerpSlerp(meshes[i], a, b, i * 7, t)
}
// writeTransforms(out, base = 0): out[base + i*7 ..] = bodies[i].translation() xyz, rotation() xyzw
```

## Worker path

Only past the threshold in SKILL.md's Physics row. Bodies the user holds or drives stay on the main thread as kinematic bodies mirrored to the worker. Buffers follow `threading.md` § SharedArrayBuffer layout and sync.

```ts
// physics.worker.ts: no requestAnimationFrame in workers; same accumulator on a timer, world.timestep = STEP_MS / 1000.
// At init, write the spawn transforms into prev and curr of both slots; seq = 0.
function tick() {
  const now = performance.now()
  acc = Math.min(acc + (now - last), STEP_MS * 5); last = now
  while (acc >= STEP_MS) {
    world.step(events); acc -= STEP_MS
    const pub = seq & 1, slot = 1 - pub                  // write only the unpublished slot
    data.copyWithin(slotOffset(slot, 0, N), slotOffset(pub, 1, N), slotOffset(pub, 1, N) + N * STRIDE) // prev = last curr
    writeTransforms(data, slotOffset(slot, 1, N))
    time[slot] = performance.timeOrigin + performance.now()
    Atomics.store(ctrl, 0, ++seq)                        // publish: the newest slot is seq & 1
  }
  if (running) setTimeout(tick, Math.max(0, STEP_MS - (performance.now() - now)))
}

// main thread, once per frame. slotViews (per-slot subarrays), frame and its halves framePrev/frameCurr: made once at init.
export function readLatest(): number {                    // copies the newest slot into frame; returns t
  let seq: number, stamp: number
  do { seq = Atomics.load(ctrl, 0); frame.set(slotViews[seq & 1]); stamp = time[seq & 1] }
  while (Atomics.load(ctrl, 0) !== seq)                   // published mid-copy: the copy may be torn, so retry
  return Math.min((performance.timeOrigin + performance.now() - stamp) / STEP_MS, 1)
}
applyInterpolated(framePrev, frameCurr, readLatest())
```

**No isolation:** transfer `curr` each step, ping-ponging two preallocated buffers. 60 bodies × 7 floats × 4 B × 60 Hz ≈ 98 KB/s, which is negligible; the cost is a frame of latency, not bandwidth. **Pausing:** `threading.md` § SharedArrayBuffer layout and sync.
