# Rapier Physics

Physics enters when bodies must collide or respond to forces. A turntable, a door or a camera move is animation (`animation.md`), not physics. Rapier's WASM is the largest download in the stack (`landscape.md` § Download weight): load it on demand, behind the poster.

## Pick one build

- **`@dimforge/rapier3d-compat`:** the WASM is inlined, so it loads with any bundler, in a worker and in Node. `await RAPIER.init()` first. The price is a larger download.
- **`@dimforge/rapier3d`:** the WASM is a separate file imported as a module, so it needs the bundler's support (`offload.md` § Bundler config). It initializes on import, and `RAPIER.init()` does not exist there ("init is not a function").
- **`-simd`** variants step faster and need WASM SIMD. **`-deterministic`** makes results match across machines. Each has a `-compat` twin.
- **One stack per app.** `@react-three/rapier` bundles its own pinned `rapier3d-compat`, older than the raw package (`landscape.md` § Verified versions). A raw-Rapier worker beside the React bindings ships two different WASM builds.

**Determinism.** At a fixed step Rapier is locally deterministic: same build, same machine, same inputs in the same order. It has no seed. Snapshot tests compared between CI and laptops, lockstep netcode and shared replays need the `-deterministic` build. `world.takeSnapshot()` returns bytes and `RAPIER.World.restoreSnapshot(bytes)` rebuilds the world.

## The loop

The default: a fixed step on the main thread, fed the clamped frame delta, with the picture interpolated between the last two states.

```ts
// physics/sim.ts
import RAPIER from '@dimforge/rapier3d-compat'

export const STEP = 1 / 60
const STRIDE = 7 // px py pz qx qy qz qw

export async function createSim(count: number) {
  await RAPIER.init() // -compat builds only; @dimforge/rapier3d initializes on import and has no init()
  const world = new RAPIER.World({ x: 0, y: -9.81, z: 0 })
  world.timestep = STEP // change both together, or the simulation runs at the wrong speed
  const events = new RAPIER.EventQueue(true)
  const bodies: RAPIER.RigidBody[] = [] // your own stable order: world.bodies iteration order is not identity
  const prev = new Float32Array(count * STRIDE), curr = new Float32Array(count * STRIDE)
  let acc = 0

  function write(out: Float32Array) {
    for (let i = 0; i < bodies.length; i++) {
      const p = bodies[i].translation(), q = bodies[i].rotation(), o = i * STRIDE
      out[o] = p.x; out[o + 1] = p.y; out[o + 2] = p.z
      out[o + 3] = q.x; out[o + 4] = q.y; out[o + 5] = q.z; out[o + 6] = q.w
    }
  }

  function add(desc: RAPIER.RigidBodyDesc, collider: RAPIER.ColliderDesc) {
    const body = world.createRigidBody(desc)
    world.createCollider(collider, body)
    bodies.push(body)
    write(curr); prev.set(curr) // both buffers hold the spawn pose before the first frame
    return body
  }

  // Feed the clamped frame delta. Returns t in 0..1: render lerp(prev, curr, t).
  function advance(dt: number, onCollision?: (a: number, b: number, started: boolean) => void) {
    acc = Math.min(acc + dt, STEP * 5) // a stall cannot spiral
    while (acc >= STEP) {
      prev.set(curr)
      world.step(events)
      if (onCollision) events.drainCollisionEvents(onCollision)
      write(curr)
      acc -= STEP
    }
    return acc / STEP
  }

  const dispose = () => { events.free(); world.free() }
  return { world, bodies, prev, curr, add, advance, dispose }
}
```

```ts
// physics/interpolate.ts
import * as THREE from 'three'

const qa = new THREE.Quaternion(), qb = new THREE.Quaternion() // reused every frame

// prev and curr hold 7 floats per body (position, quaternion); mesh i is body i, in the simulation's stable order.
export function applyInterpolated(meshes: THREE.Object3D[], prev: Float32Array, curr: Float32Array, t: number) {
  for (let i = 0, o = 0; i < meshes.length; i++, o += 7) {
    meshes[i].position.set(prev[o] + (curr[o] - prev[o]) * t, prev[o + 1] + (curr[o + 1] - prev[o + 1]) * t, prev[o + 2] + (curr[o + 2] - prev[o + 2]) * t)
    meshes[i].quaternion.slerpQuaternions(qa.fromArray(prev, o + 3), qb.fromArray(curr, o + 3), t)
  }
}
```

```ts
const sim = await createSim(meshes.length)
viewer.ticks.add((dt) => {
  const t = sim.advance(dt)
  applyInterpolated(meshes, sim.prev, sim.curr, t)
  return true // a running simulation needs every frame
})
```

- **`world.timestep` and `STEP` change together,** or the simulation runs at the wrong speed. Rapier's default is 1/60.
- **Cap the accumulator** (five steps here), so a stall cannot spiral: each catch-up step makes the next frame later.
- **Without the interpolation,** bodies move in 60 Hz increments and judder on 90 and 120 Hz displays while the frame rate reads fine.
- **Sleep with the scene.** When every body is asleep (`body.isSleeping()`), return `false` from the tick and let the loop sleep too.

## API traps

- **Shapes.** A degenerate point set (collinear, or fewer than three points) has no convex hull. Older builds return `null` from `ColliderDesc.convexHull(points)`; current ones return a descriptor and throw an opaque `expected instance of …` from `createCollider` (`landscape.md` § Verified versions). Validate the points, and guard both. `trimesh` belongs on fixed bodies; dynamic bodies use primitives, convex hulls or a convex decomposition. `capsule(halfHeight, radius)`.
- **Forces.** `addForce` persists across steps until `resetForces(true)`; `applyImpulse` is one-off.
- **Events are opt-in per collider.** The default is `ActiveEvents.NONE`: silence. Sensors report through `drainCollisionEvents`; there is no separate intersection drain. The default collision types skip pairs of non-dynamic bodies, so a kinematic player never trips a fixed sensor without `KINEMATIC_FIXED`:

  ```ts
  const events = new RAPIER.EventQueue(true)
  world.createCollider(
    RAPIER.ColliderDesc.cuboid(5, 5, 1).setSensor(true)
      .setActiveEvents(RAPIER.ActiveEvents.COLLISION_EVENTS)
      .setActiveCollisionTypes(RAPIER.ActiveCollisionTypes.DEFAULT | RAPIER.ActiveCollisionTypes.KINEMATIC_FIXED),
    zoneBody,
  )
  world.step(events)
  events.drainCollisionEvents((a, b, started) => { /* started true: entered, false: left */ })
  ```

- **Collision groups** are 32 bits: membership in the high 16, filter in the low 16. A pair interacts only if each one's filter includes the other's membership. For players (group 0) to hit enemies (group 1), widen both filters: player `0x00010003`, enemy `0x00020003`.
- **Iteration order is not identity.** `world.bodies.forEach` passes bodies in an order that is not spawn order and shifts on removal. Never derive a buffer slot from it; keep your own array, as `createSim` does.
- **Characters** use Rapier's kinematic character controller, not a dynamic capsule pushed with `setLinvel`, which sticks to walls and jitters on slopes. The calls in `Player` below work without React: create the controller after the world, run the step body before `world.step()`, and remove it on teardown.
- **Free what you create.** `world.free()` and `events.free()` on teardown: WASM memory is not garbage collected either.

## With React Three Fiber

```tsx
// physics/World.tsx
import { Physics } from '@react-three/rapier'
import { Suspense, type ReactNode } from 'react'

export const World = ({ children }: { children: ReactNode }) => (
  <Suspense fallback={null}>{/* Physics suspends while its WASM loads */}
    <Physics timeStep={1 / 60} interpolate>{children}</Physics>
  </Suspense>
)
```

- `@react-three/rapier` steps on the main thread at a fixed `timeStep` of 1/60 with `interpolate` on. Keep both. A scene past the worker threshold moves to the raw worker path below, never to `timeStep="vary"`.
- Every `RigidBody` gets a `cuboid` auto-collider by default: pass `colliders={false}` and explicit colliders for anything not box-like. `colliders="trimesh"` only with `type="fixed"`; dynamic bodies use `hull` or primitives.
- Event props (`onCollisionEnter`, and `onIntersectionEnter` on a `sensor` collider) switch on Rapier's active events for you; raw Rapier does not.
- `interactionGroups(memberships, filters)` builds the collision-group mask.
- Many identical bodies: `<InstancedRigidBodies>` around one `instancedMesh`.

```tsx
// physics/Player.tsx
import { CapsuleCollider, RigidBody, useBeforePhysicsStep, useRapier, type RapierCollider, type RapierRigidBody } from '@react-three/rapier'
import { useEffect, useRef } from 'react'

export function Player({ input }: { input: { x: number; z: number; jump: boolean } }) { // input: a mutable object the key handlers write
  const body = useRef<RapierRigidBody>(null), collider = useRef<RapierCollider>(null)
  const { world } = useRapier()
  const controller = useRef<ReturnType<typeof world.createCharacterController> | null>(null)
  const vy = useRef(0), grounded = useRef(false)

  useEffect(() => {
    const c = world.createCharacterController(0.01) // skin offset
    c.enableSnapToGround(0.3)
    c.enableAutostep(0.3, 0.2, false)
    c.setMaxSlopeClimbAngle(Math.PI / 4)
    controller.current = c
    return () => { world.removeCharacterController(c); controller.current = null }
  }, [world])

  useBeforePhysicsStep((w) => {
    if (!controller.current || !body.current || !collider.current) return
    const dt = w.timestep
    vy.current = grounded.current ? (input.jump ? 5 : 0) : vy.current - 9.81 * dt // gravity is yours to apply
    controller.current.computeColliderMovement(collider.current, { x: input.x * 4 * dt, y: vy.current * dt, z: input.z * 4 * dt })
    const m = controller.current.computedMovement(), p = body.current.translation()
    body.current.setNextKinematicTranslation({ x: p.x + m.x, y: p.y + m.y, z: p.z + m.z })
    grounded.current = controller.current.computedGrounded()
  })

  return (
    <RigidBody ref={body} type="kinematicPosition" colliders={false}>
      <CapsuleCollider ref={collider} args={[0.5, 0.3]} />
    </RigidBody>
  )
}
```

## The worker path

Only when the step's p95 tops about 15% of the frame budget on the floor device (SKILL.md § Size the stack). A worker adds at least a frame of latency, so bodies the user holds or drives stay on the main thread as kinematic bodies mirrored to the worker.

```ts
// physics/physics.worker.ts
import RAPIER from '@dimforge/rapier3d'
import { publish, STRIDE, views, type Shared } from '../offload/snapshots.ts'

const STEP_MS = 1000 / 60
const world = new RAPIER.World({ x: 0, y: -9.81, z: 0 })
world.timestep = STEP_MS / 1000
const bodies: RAPIER.RigidBody[] = []
let v: ReturnType<typeof views>, running = false, last = 0, acc = 0

function write(curr: Float32Array) {
  for (let i = 0; i < bodies.length; i++) {
    const p = bodies[i].translation(), q = bodies[i].rotation(), o = i * STRIDE
    curr[o] = p.x; curr[o + 1] = p.y; curr[o + 2] = p.z
    curr[o + 3] = q.x; curr[o + 4] = q.y; curr[o + 5] = q.z; curr[o + 6] = q.w
  }
}

function tick() { // workers have no requestAnimationFrame: the same accumulator on a timer
  if (!running) return
  const now = performance.now()
  acc = Math.min(acc + (now - last), STEP_MS * 5)
  last = now
  while (acc >= STEP_MS) { world.step(); acc -= STEP_MS; publish(v, write) }
  setTimeout(tick, Math.max(0, STEP_MS - (performance.now() - now)))
}

self.onmessage = ({ data: m }: MessageEvent<{ type: 'init'; shared: Shared; count: number } | { type: 'pause' | 'resume' }>) => {
  if (m.type === 'init') {
    v = views(m.shared, m.count)
    world.createCollider(RAPIER.ColliderDesc.cuboid(50, 0.1, 50))
    for (let i = 0; i < m.count; i++) {
      const body = world.createRigidBody(RAPIER.RigidBodyDesc.dynamic().setTranslation((i % 20) - 10, 2 + Math.floor(i / 20) * 1.2, 0))
      world.createCollider(RAPIER.ColliderDesc.ball(0.4), body)
      bodies.push(body)
    }
    publish(v, write); publish(v, write) // both slots hold the spawn pose
  }
  if (m.type === 'pause') running = false
  if (m.type === 'init' || m.type === 'resume') { // never fast-forward through a pause
    running = true; last = performance.now(); acc = 0
    tick()
  }
}
postMessage({ type: 'ready' }) // the module awaited its WASM: anything posted before this line ran was dropped
```

```ts
const shared = allocate(count), v = views(shared, count), frame = new Float32Array(2 * v.size)
const prev = frame.subarray(0, v.size), curr = frame.subarray(v.size) // made once
const worker = new Worker(new URL('./physics.worker.ts', import.meta.url), { type: 'module' })
worker.onmessage = ({ data }) => { if (data.type === 'ready') worker.postMessage({ type: 'init', shared, count }) }
// once per frame:
applyInterpolated(meshes, prev, curr, readLatest(v, frame, 1000 / 60))
```

- The shared-buffer protocol (`allocate`, `views`, `publish`, `readLatest`), the `ready` handshake and isolation: `offload.md`.
- **Without isolation,** transfer `curr` each step, ping-ponging two preallocated buffers. Sixty bodies at 60 Hz is under 100 KB/s: the cost is the frame of latency, not the bandwidth.
- **Pause with the page.** On `visibilitychange`, and when the canvas leaves the viewport, post `pause`; on return post `resume`. The worker resets its accumulator there, so it never fast-forwards through the pause.
- In React Three Fiber, read the snapshot in one `useFrame` with no React state, with mesh `i` matching body `i` through a ref array.
