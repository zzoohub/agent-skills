# Animation

A moving thing is a function of time, evaluated every frame. Its cost is where the function is evaluated and how many things it touches, so the two decisions are the rung it runs on and the clock it reads. Motion in the DOM around the canvas (hover, open and close, CSS 3D, view transitions) belongs to the design-system capability, if available. This file is motion inside the canvas.

## Where motion runs

Start at the top. Go down a rung only when the one above cannot express the motion.

| Rung | The motion is… | Costs per frame | Use for |
|---|---|---|---|
| **Baked** | already in the asset: lightmaps, baked occlusion, a shadow rendered once | nothing | whatever never changes |
| **Shader time** | a function of the `time` node in the vertex or fragment stage | no CPU; a little GPU per vertex or pixel | wind, water, shimmer, scrolling UVs, idle loops, particles (`shaders.md` § Compute) |
| **A few transforms** | objects, the camera or uniforms mutated in the loop | per object | a turntable, a door, a camera move: tens to a few hundred objects |
| **Skeletal and morph** | `AnimationMixer` driving bones or morph targets | per track on the CPU, per vertex per pass on the GPU | characters and rigs: tens on a phone |
| ~~Framework state~~ | `setState` or a changing prop every frame | a React render per frame | never |

## Time

**Everything that moves advances by elapsed time.** A value added per frame, or a fraction applied per frame, runs at the display's rate: twice as fast at 120 Hz, half as fast on a phone throttled to 30. `value = lerp(value, target, 0.1)` is the common disguise: that one line takes 0.18 s to cover 90% of the gap on a 120 Hz display, 0.36 s at 60 Hz and 0.73 s on a phone throttled to 30.

```ts
// anim/motion.ts
import type { Quaternion, Vector3 } from 'three'

// Exponential approach: the same curve at 30, 60 and 120 Hz. lambda is speed: about 63% of the gap closes every 1 / lambda seconds.
// For one number, three has it built in: MathUtils.damp(current, target, lambda, dt).
export const dampVec = (v: Vector3, target: Vector3, lambda: number, dt: number) => v.lerp(target, 1 - Math.exp(-lambda * dt))
export const dampQuat = (q: Quaternion, target: Quaternion, lambda: number, dt: number) => q.slerp(target, 1 - Math.exp(-lambda * dt))

// Critically damped spring, exact for any dt: it eases in as well as out and keeps its velocity when the target moves.
export function springTo(s: { x: number; v: number }, target: number, omega: number, dt: number) {
  const d = s.x - target, e = Math.exp(-omega * dt), c = (s.v + omega * d) * dt
  s.x = target + (d + c) * e
  s.v = (s.v - omega * c) * e
}
```

- **Velocity:** `position += velocity * dt`.
- **Following a target** (a camera, a hovered scale, scroll progress): `damp`. It needs no start time, so the target can move at any moment.
- **Motion with weight** (something released, something that should ease in): `springTo`. It keeps its velocity when the target changes, where a restarted tween would jerk.
- **Authored moves** with a fixed duration: progress is `(now - start) / duration`, clamped and eased. It is rate-independent by construction.
- **Cycles:** `Math.sin(timer.getElapsed() * speed)`, never a phase accumulated per frame.
- **Simulation** (physics, anything whose result depends on the step size) runs at a fixed step, and the picture interpolates between the last two states (`physics.md` § The loop).

**Converting what is there.** Existing motion was tuned at some refresh rate, almost always 60 Hz: assume that, and say so. A step per frame becomes a speed: `speed = step × 60`, so `rotation.y += 0.01` is 0.6 rad/s. A per-frame lerp factor `k` becomes `lambda = -60 × Math.log(1 - k)`, so `lerp(…, 0.1)` is `damp(…, 6.3, dt)`. The motion then looks as it did at 60 Hz, everywhere.

**The delta is clamped, and a pause is not a step.** A gap over 100 ms means the tab was hidden, the loop slept or a frame hitched. Stepping through it teleports whatever was moving. The skeleton in `setup.md` advances its timer on idle frames too, so waking never sees the sleep as a time step. React Three Fiber's `delta` does include it: after an idle `frameloop="demand"` canvas the first delta is the whole pause, seconds long (`setup.md` § React Three Fiber).

## Motion on demand

A loop that sleeps needs to know when motion ends. Each moving thing is a tick that returns `true` while it still has somewhere to go:

```ts
let scale = 1, target = 1
viewer.ticks.add((dt) => {
  scale = MathUtils.damp(scale, target, 12, dt)
  if (Math.abs(target - scale) < 1e-3) scale = target // settle exactly, or the loop never sleeps
  mesh.scale.setScalar(scale)
  return scale !== target
})
canvas.addEventListener('pointerenter', () => { target = 1.1; viewer.invalidate() }) // an event wakes the loop
```

- **Events wake, ticks sustain.** An input handler changes a target and calls `invalidate()`. The tick keeps the loop awake until the value settles.
- **Orbit controls with damping:** `controls.addEventListener('change', invalidate)` and a tick that returns `controls.update()`, which is true while the camera is still gliding.
- **Motion that never settles** (a turntable, a playing clip, shader-time motion) draws every frame for as long as it is on screen. That is a design decision, never a default: keep it where the UX spec or the existing look asks for it, gate it by visibility and by reduced motion, and say what it costs. Auto-rotation normally stops for good on the first input.
- **Reduced motion.** Under `prefers-reduced-motion: reduce`, nothing moves by itself: no auto-rotation, no idle loop, no parallax, and camera moves cut or cross-fade (the UX spec may say more). Read the setting live with `matchMedia(...).addEventListener('change', …)`, never once.

The common viewer, a turntable that grows on hover, in React Three Fiber (`useTick`: `setup.md`):

```tsx
// anim/Turntable.tsx
import { useThree } from '@react-three/fiber'
import { useEffect, useRef, type ReactNode } from 'react'
import { MathUtils, type Group } from 'three'
import { useTick } from '../setup/use-tick.ts'

function useReducedMotion() { // read live: the setting can change while the page is open
  const reduced = useRef(false)
  useEffect(() => {
    const query = matchMedia('(prefers-reduced-motion: reduce)')
    const read = () => { reduced.current = query.matches }
    read()
    query.addEventListener('change', read)
    return () => query.removeEventListener('change', read)
  }, [])
  return reduced
}

export function Turntable({ children, speed = 0.6 }: { children: ReactNode; speed?: number }) { // radians per second
  const group = useRef<Group>(null)
  const scale = useRef(1), target = useRef(1)
  const reduced = useReducedMotion()
  const invalidate = useThree((s) => s.invalidate)

  useTick((dt) => {
    const g = group.current!
    if (!reduced.current) g.rotation.y += speed * dt
    scale.current = MathUtils.damp(scale.current, target.current, 12, dt)
    if (Math.abs(target.current - scale.current) < 1e-3) scale.current = target.current // settle exactly
    g.scale.setScalar(scale.current)
    return !reduced.current || scale.current !== target.current // a spin never settles: it draws for as long as it is on screen
  })

  const grow = (to: number) => () => { target.current = to; invalidate() } // an event wakes the loop
  return <group ref={group} onPointerOver={grow(1.08)} onPointerOut={grow(1)}>{children}</group>
}
```

## Camera moves

The camera moves in answer to the user and yields to any new input. Damp toward a target pose instead of running a fixed tween: a new input only changes the target, and nothing has to be cancelled.

```ts
const goal = new THREE.Vector3(), look = new THREE.Vector3(), lookGoal = new THREE.Vector3()
viewer.ticks.add((dt) => {
  dampVec(camera.position, goal, 6, dt)
  dampVec(look, lookGoal, 6, dt)
  camera.lookAt(look)
  return camera.position.distanceToSquared(goal) > 1e-6 || look.distanceToSquared(lookGoal) > 1e-6
})
```

Orbit controls and a camera move must not both write the camera in one frame: disable the controls for the move, or move the controls' target and let them follow.

## Scroll-linked scenes

Native scroll is the timeline, so the scrollbar stays the progress indicator and skipping is scrolling. Never hijack or smooth the page's scroll for the scene's sake: ease the scene instead.

```ts
// anim/scroll.ts
import { MathUtils } from 'three'
import type { Tick } from '../setup/tick.ts'

// How far a tall section has scrolled past: 0 when its top reaches the viewport top, 1 when its bottom reaches the viewport bottom.
export const scrollProgress = (section: HTMLElement) => {
  const r = section.getBoundingClientRect()
  return MathUtils.clamp(-r.top / (r.height - innerHeight), 0, 1)
}

// Native scroll is the timeline. The scene follows it with a time-based ease and stops drawing when it has caught up.
export function followScroll(section: HTMLElement, apply: (progress: number) => void, invalidate: () => void, signal?: AbortSignal): Tick {
  let progress = scrollProgress(section)
  apply(progress)
  addEventListener('scroll', invalidate, { passive: true, signal }) // wakes the loop; the read happens in the frame
  return (dt) => {
    const target = scrollProgress(section) // one layout read per frame, before any write
    progress = MathUtils.damp(progress, target, 10, dt)
    if (Math.abs(target - progress) < 1e-4) progress = target
    apply(progress)
    return progress !== target // false once settled: the loop sleeps until the next scroll event
  }
}
```

- **Layout:** a tall section, with the canvas `position: sticky; top: 0; height: 100vh` inside it.
- **`apply(progress)`** places the timeline: a camera on a curve (`path.getPointAt(progress, camera.position)`), a clip scrubbed with `mixer.setTime(progress * clip.duration)`, a uniform.
- **One layout read per frame, in the frame.** The scroll listener only wakes the loop. Reading layout inside a scroll handler, or writing styles before the read, forces a synchronous layout.
- **Text beside the scene** animates with CSS scroll-driven animations, on the compositor, not from this loop (`landscape.md` § Platform support).
- **Reduced motion:** static key frames, by the UX spec.

In React Three Fiber the same tick runs through `useTick` (`setup.md`):

```tsx
function ScrollCamera({ section, path }: { section: HTMLElement; path: THREE.Curve<THREE.Vector3> }) {
  const { camera, invalidate } = useThree()
  const tick = useMemo(() => {
    const stop = new AbortController()
    return Object.assign(followScroll(section, (p) => { path.getPointAt(p, camera.position); camera.lookAt(0, 0, 0) }, invalidate, stop.signal), { stop })
  }, [section, path, camera, invalidate])
  useEffect(() => () => tick.stop.abort(), [tick]) // the scroll listener leaves with the component
  useTick(tick)
  return null
}
```

## GPU-driven motion

When many things move the same way, the motion belongs in the vertex stage: one draw, and no JavaScript per object or per frame.

```ts
// anim/sway.ts
import * as THREE from 'three/webgpu'
import { Fn, hash, instanceIndex, positionLocal, sin, time, vec3 } from 'three/tsl'

// 20,000 blades, one draw call, and no JavaScript per blade or per frame: the motion is a function of time in the vertex stage.
export function createGrass(count: number, area = 20) {
  const material = new THREE.MeshStandardNodeMaterial({ color: 0x4c8a3f, side: THREE.DoubleSide })
  material.positionNode = Fn(() => {
    const phase = hash(instanceIndex).mul(6.28) // each blade starts somewhere else in the cycle
    const bend = sin(time.mul(2).add(phase)).mul(positionLocal.y.mul(positionLocal.y)).mul(0.3) // the tip moves, the root stays
    return positionLocal.add(vec3(bend, 0, 0))
  })()
  const blade = new THREE.PlaneGeometry(0.05, 1, 1, 4).translate(0, 0.5, 0)
  const grass = new THREE.InstancedMesh(blade, material, count)
  const m = new THREE.Matrix4()
  for (let i = 0; i < count; i++) grass.setMatrixAt(i, m.makeTranslation((Math.random() - 0.5) * area, 0, (Math.random() - 0.5) * area))
  grass.frustumCulled = false // the vertex stage moves it past its static bounds
  return grass
}
```

- `time` advances by itself; `instanceIndex` gives each copy its own phase.
- The vertex stage moves geometry past its static bounds: set `frustumCulled = false` or enlarge the bounding sphere, or the group vanishes at some camera angles.
- A `positionNode` on a `SkinnedMesh` changed meaning in r185 (`positionLocal` against `positionGeometry`): read that Migration Guide entry and check the result on the installed version.
- State that must persist per element (positions, velocities, lifetimes) is a compute job: `shaders.md` § Compute.

## Skeletal animation

```ts
// anim/mixer.ts
import * as THREE from 'three'
import type { Tick } from '../setup/tick.ts'

export function playClip(model: THREE.Object3D, clip: THREE.AnimationClip, isVisible: () => boolean): Tick {
  const mixer = new THREE.AnimationMixer(model)
  mixer.clipAction(clip.optimize()).play() // optimize() drops keyframes that add nothing
  return (dt) => {
    if (!isVisible()) return true // off screen: the clock runs on, no bone is touched
    mixer.update(dt)
    return true // a playing clip needs every frame; return false when it ends to let the loop sleep
  }
}
```

What a playing character costs:

- **CPU, in `mixer.update`:** one interpolation per track per frame. A track is one animated property of one bone, so a 40-bone rig that animates rotation and position has 80.
- **CPU, in `render()`:** every bone's world matrix, and one bone-texture upload per skeleton.
- **GPU:** skinning for every vertex, again in every pass that draws the mesh. A shadow-casting character is skinned twice.

Measured costs: `landscape.md` § Measurements. Plan for tens of animated characters on a phone, not hundreds, and prove the number in the spike.

Levers, cheapest first:

1. **Do not update what is not seen.** Off-screen characters skip `mixer.update` entirely.
2. **Update far characters less often:** every Nth frame with `N × dt`. Distant motion hides the lower rate.
3. **Fewer tracks.** `clip.optimize()` at load, resampling in the asset pipeline (`gltf-transform optimize` does it by default), and no tracks for properties that never change.
4. **Fewer skinned vertices and passes:** a lower level of detail for distant characters, and no shadow from them or a shadow from a cheap proxy.
5. **Past a few dozen characters, leave the CPU.** Bake the clips into a vertex animation texture in the asset pipeline and play them per instance in the vertex stage. That is its own task with its own spike; this skill ships no baker.

Cross-fade between clips with `action.crossFadeTo(next, seconds)` instead of stopping one and starting another. Copies of a rigged model need `SkeletonUtils.clone` (drei's `<Clone>`): a plain `clone()` shares the skeleton.

## One clock

Two animation clocks disagree. A tween library on its own ticker updates outside the loop: its changes land a frame late, it keeps the page awake when the loop sleeps, and it cannot wake an on-demand loop.

**Default to no library.** `damp`, `springTo` and a clamped progress cover most motion in a scene, and they are a few lines each.

**Authored timelines** (sequenced, staggered, hand-tuned) are GSAP's job. Drive it from the loop, on scene time:

```ts
gsap.ticker.remove(gsap.updateRoot) // once: GSAP stops running its own clock
let sceneTime = 0
viewer.ticks.add((dt) => {
  gsap.updateRoot((sceneTime += dt)) // scene time stands still while the loop sleeps
  return timeline.isActive()
})
// after building a timeline: viewer.invalidate()
```

Scene time matters. Fed the wall clock, a timeline created after a five-second sleep starts five seconds late and jumps straight to its end on the first frame.
