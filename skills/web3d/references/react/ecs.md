# Koota in React Three Fiber

Traits, queries, relations and system order: `../ecs.md`.

## Hooks: which ones re-render

- Wrap the app, outside `<Canvas>`, in `<WorldProvider world={world}>` (R3F bridges context into the canvas); `useWorld()` throws without it.
- `useQuery(...traits)` re-renders when entities join or leave the query, not when their values change: use it to mount and unmount views.
- `useTrait(entity, Trait)` re-renders on every change: only for low-frequency traits shown in UI (health in a HUD), never for per-frame traits like `Position`.
- `useTraitEffect(entity, Trait, fn)` runs `fn` on add, remove or change without re-rendering, for imperative updates.

## View injection

A view mounts the mesh and hands the reference to its entity. Call `add` before `set`: the entity joins the `MeshRef` archetype only through `add`, and `set` alone updates a trait it already has. Remove it on unmount so no stale reference survives.

```tsx
function EnemyView({ entity }: { entity: Entity }) {
  const world = useWorld()
  const ref = useRef<THREE.Mesh>(null)
  useEffect(() => {
    if (!ref.current) return
    entity.add(MeshRef)
    entity.set(MeshRef, ref.current)
    return () => { if (world.has(entity)) entity.remove(MeshRef) }
  }, [world, entity])
  return <mesh ref={ref}><boxGeometry /><meshStandardMaterial /></mesh>
}

const Enemies = () => useQuery(IsEnemy).map((e) => <EnemyView key={e.id()} entity={e} />)
```

## Game loop

Run systems from one `useFrame`, in the order `../ecs.md` § Loop gives, with the clamped delta:

```tsx
function GameSystems() {
  const world = useWorld()
  useFrame((_, delta) => frame(world, Math.min(delta, 0.1)))
  return null
}
```

The sync system writes transforms through `MeshRef`; React never re-renders per frame.
