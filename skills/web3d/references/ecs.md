# Koota ECS

An ECS pays off past roughly a thousand entities, when behaviors must compose (status effects, AI states, pickups), or when game rules should be testable without a renderer. Below that, a scene graph and a small store are less to carry.

Simulation state goes in Koota; menus, HUD and settings stay in the app's store. Neither mirrors the other every frame.

## World, traits and systems

```ts
// ecs/world.ts
import { createChanged, createWorld, Not, relation, trait, type World } from 'koota'
import type { Object3D } from 'three'

export const Position = trait({ x: 0, y: 0, z: 0 }) // schema trait: numbers that change every frame
export const Velocity = trait({ x: 0, y: 0, z: 0 })
export const Health = trait({ value: 100 })
export const MeshRef = trait(() => null as Object3D | null) // callback trait: holds a reference
export const IsEnemy = trait() // tags carry no data
export const IsFrozen = trait()
export const Time = trait({ delta: 0 }) // singleton: lives on the world
export const ChildOf = relation({ exclusive: true, autoDestroy: 'orphan' }) // destroying a parent destroys its children

export const world = createWorld(Time)
const Changed = createChanged()

export function movementSystem(world: World) {
  const { delta } = world.get(Time)!
  world.query(Position, Velocity, Not(IsFrozen)).updateEach(([p, v]) => {
    p.x += v.x * delta
    p.y += v.y * delta
    p.z += v.z * delta
  })
}

// The one place that writes transforms into the scene graph. Moving things sync every frame.
export function syncSystem(world: World) {
  world.query(Position, MeshRef).readEach(([p, mesh]) => { mesh?.position.set(p.x, p.y, p.z) })
}

// State that changes rarely: only the entities whose Health changed since this query last ran.
export function damageFlashSystem(world: World, flash: (mesh: Object3D) => void) {
  world.query(Changed(Health), MeshRef).readEach(([, mesh]) => { if (mesh) flash(mesh) })
}

export function frame(world: World, dt: number, flash: (mesh: Object3D) => void) {
  world.set(Time, { delta: dt })
  movementSystem(world)
  syncSystem(world)
  damageFlashSystem(world, flash)
}
```

- **Schema traits** store numbers in flat arrays, the right shape for values that change every frame. `entity.get(Position)` returns a snapshot: writing to it changes nothing. Write through `updateEach` or `entity.set`.
- **Callback traits** (`trait(() => value)`) hold references. `MeshRef` stays `null` until a view attaches a mesh, so every consumer null-guards.
- **Systems are plain functions,** and their order is a design decision: input (devices to intent traits), simulation on the fixed step (`physics.md` § The loop), the sync into the scene graph, then cleanup of dead entities.
- **One sync system writes transforms** into the scene graph. Nothing else touches them.
- **Workers.** Callback traits hold `Object3D`s a worker cannot reach, so the world stays on the main thread. Only pure-data systems may move, past the threshold in `offload.md`.

## Change detection

A `Changed(Trait)` query returns the entities whose trait changed since that query last ran. What counts as a change is narrower than it looks:

| The write | Seen by a `Changed` query elsewhere |
|---|---|
| `entity.set(Trait, value)` | yes |
| `entity.changed(Trait)` after mutating an object or array in place | yes |
| `updateEach` on a query that itself includes `Changed(Trait)`, or while an `onChange(Trait)` subscription exists | yes |
| `updateEach` on any other query | **no**, unless called with `{ changeDetection: 'always' }` |

So a movement system's `updateEach` does not feed a `Changed(Position)` sync in another system: nothing would ever sync. Things that move every frame sync every frame, as `syncSystem` does, and `Changed` is for state that changes rarely, as in `damageFlashSystem`. Detection is shallow: an object or array mutated in place needs `entity.changed(Trait)`.

`world.onAdd`, `onRemove` and `onChange(Trait, fn)` return an unsubscribe function. Call it on teardown.

## Relations

- `relation({ exclusive: true })` allows one target per source: a parent.
- `autoDestroy: 'orphan'` destroys sources when their target is destroyed (a hierarchy); `autoDestroy: 'target'` destroys targets when their source is destroyed (a container's items).
- `ordered(ChildOf)` keeps an ordered child list: spawn the parent with it, then read it with `parent.get(OrderedChildren)`.

## With React Three Fiber

```tsx
// ecs/EnemyView.tsx
import { useFrame } from '@react-three/fiber'
import type { Entity } from 'koota'
import { useQuery, useWorld } from 'koota/react'
import { useEffect, useRef } from 'react'
import type { Mesh } from 'three'
import { frame, IsEnemy, MeshRef } from './world.ts'

function EnemyView({ entity }: { entity: Entity }) {
  const world = useWorld()
  const mesh = useRef<Mesh>(null)
  useEffect(() => {
    entity.add(MeshRef) // add before set: set alone only updates a trait the entity already has
    entity.set(MeshRef, mesh.current)
    return () => { if (world.has(entity)) entity.remove(MeshRef) } // no stale reference survives the view
  }, [world, entity])
  return <mesh ref={mesh}><boxGeometry /><meshStandardMaterial /></mesh>
}

// Re-renders when entities join or leave the query, never when their values change.
export const Enemies = () => useQuery(IsEnemy).map((entity) => <EnemyView key={entity.id()} entity={entity} />)

export function Systems() { // one loop runs every system, in order; React never re-renders per frame
  const world = useWorld()
  useFrame((_, delta) => frame(world, delta > 0.1 ? 1 / 60 : delta, () => {}))
  return null
}
```

- Wrap the app, outside `<Canvas>`, in `<WorldProvider world={world}>`. R3F bridges the context into the canvas; `useWorld()` throws without it.
- **`useQuery(...traits)`** re-renders when entities join or leave the query, not when their values change: use it to mount and unmount views.
- **`useTrait(entity, Trait)`** re-renders on every change: only for low-frequency traits shown in UI (health in a HUD), never for per-frame traits like `Position`.
- **`useTraitEffect(entity, Trait, fn)`** runs `fn` on add, remove or change without re-rendering, for imperative updates.
