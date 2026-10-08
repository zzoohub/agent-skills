# Koota ECS

R3F integration: `react/ecs.md`.

## When it pays off

Past SKILL.md's State row (roughly 1k+ entities, or many composable behaviors: status effects, AI states, pickups), or for game rules to unit-test without a renderer. Callback traits hold `Object3D`s a worker can't reach, so only pure-data systems may move to a worker, past the threshold in `threading.md`.

Simulation state goes in Koota; menus, HUD and settings stay in the framework's store. Neither mirrors the other every frame.

## Traits

- **Schema traits** (SoA storage) for numbers that change every frame: `const Position = trait({ x: 0, y: 0, z: 0 })`. `entity.get(Position)` returns a snapshot, so writing to it changes nothing; write through `updateEach` or `entity.set`.
- **Callback traits** (AoS storage) for references: `const MeshRef = trait(() => null as THREE.Object3D | null)`, which returns the stored reference. It stays `null` until a view attaches a mesh, so consumers null-guard.
- **Tags**: `trait()` with no data. **Singletons**: add a trait to the world itself (`world.add(Time)`, `world.set(Time, { delta })`).

## Queries and change detection

```ts
const Changed = createChanged()

let dt = 0
const move = ([p, v]) => { p.x += v.x * dt; p.y += v.y * dt; p.z += v.z * dt } // created once, not per frame
export function movementSystem(world: World, step: number) {
  dt = step
  world.query(Position, Velocity, Not(IsFrozen)).updateEach(move)
}

// a change-detected sync: only entities whose Position changed since the last run
world.query(Changed(Position), MeshRef).readEach(([p, mesh]) => { mesh?.position.set(p.x, p.y, p.z) })
```

- `updateEach` writes back and emits change events for traits tracked by `Changed` or `onChange` (`{ changeDetection: 'never' | 'always' }` overrides); `readEach` never writes. Detection is shallow: mutating an object or array value in place needs `entity.changed(Trait)`.
- `world.onAdd` / `onRemove` / `onChange(Trait, fn)` return an unsubscribe function; call it on teardown.
- One sync system copies ECS state into the scene graph; nothing else writes those transforms. `Changed` suits state that snaps; interpolated entities sync every frame, since `t` moves on frames without a step.

## Relations

- `relation({ exclusive: true })` allows one target per source (a parent).
- Cleanup: `autoDestroy: 'orphan'` destroys sources when their target is destroyed (hierarchies); `autoDestroy: 'target'` destroys targets when their source is destroyed (a container's items). `autoRemoveTarget` is deprecated.
- `ordered(ChildOf)` keeps an ordered child list; spawn the parent with it first: `const parent = world.spawn(OrderedChildren)`, then `parent.get(OrderedChildren)`.

## Loop

Systems are plain functions, and their order is a design decision. One `frame(world, dt)` runs input (devices → intent traits), the simulation systems on the fixed-step accumulator (`physics.md` § Main-thread loop), the sync into the scene graph, and last the cleanup of dead entities.
