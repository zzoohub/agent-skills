# @react-three/rapier

Raw Rapier, build choice and the worker path: `../physics.md`.

## Setup and defaults

```tsx
<Canvas>
  <Suspense fallback={null}>   {/* Physics suspends while its WASM loads */}
    <Physics>
      <Scene />
    </Physics>
  </Suspense>
</Canvas>
```

- It steps on the main thread at a fixed `timeStep` of 1/60 with `interpolate` on; keep both. A scene past the offload threshold moves to the raw worker path (`../physics.md` § Worker path, one Rapier stack per app), never to `timeStep="vary"`.
- Every `RigidBody` gets a `cuboid` auto-collider by default: pass `colliders={false}` and explicit colliders for anything not box-like. `colliders="trimesh"` only with `type="fixed"`; dynamic bodies use `hull` or primitives.
- Event props (`onCollisionEnter`, and `onIntersectionEnter` on a `sensor` collider) switch on Rapier's active events for you; raw Rapier doesn't.
- `interactionGroups(memberships, filters)` builds the collision-group mask (rules: `../physics.md`).
- Many identical bodies: `<InstancedRigidBodies>` around one `instancedMesh`.

## Character controller

Rapier's kinematic character controller, stepped before each physics step, slides along walls, climbs steps and holds slopes, where a dynamic capsule pushed with `setLinvel` sticks to walls and jitters on slopes. Its grounded flag needs neither collision events nor React state.

```tsx
function Player({ input }: { input: { x: number; z: number; jump: boolean } }) { // input: mutable, written by handlers
  const body = useRef<RapierRigidBody>(null), collider = useRef<RapierCollider>(null)
  const { world } = useRapier()
  const cc = useRef<ReturnType<typeof world.createCharacterController> | null>(null)
  const vy = useRef(0), grounded = useRef(false)

  useEffect(() => {
    const c = world.createCharacterController(0.01)          // skin offset
    c.enableSnapToGround(0.3); c.enableAutostep(0.3, 0.2, false); c.setMaxSlopeClimbAngle(Math.PI / 4)
    cc.current = c
    return () => { world.removeCharacterController(c); cc.current = null }
  }, [world])

  useBeforePhysicsStep((w) => {
    if (!cc.current || !body.current || !collider.current) return
    const dt = w.timestep
    vy.current = grounded.current ? (input.jump ? 5 : 0) : vy.current - 9.81 * dt // gravity is yours to apply
    cc.current.computeColliderMovement(collider.current, { x: input.x * 4 * dt, y: vy.current * dt, z: input.z * 4 * dt })
    const m = cc.current.computedMovement(), p = body.current.translation()
    body.current.setNextKinematicTranslation({ x: p.x + m.x, y: p.y + m.y, z: p.z + m.z })
    grounded.current = cc.current.computedGrounded()
  })

  return (
    <RigidBody ref={body} type="kinematicPosition" colliders={false}>
      <CapsuleCollider ref={collider} args={[0.5, 0.3]} />
    </RigidBody>
  )
}
```

Without React the calls are the same: create the controller after the world, run the step body inside the fixed-step loop before `world.step()`, and call `world.removeCharacterController` on teardown.
