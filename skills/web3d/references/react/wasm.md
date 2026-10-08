# R3F + Rust WASM

Builds, memory growth and worker rules: `../wasm.md`.

- **Lifecycle.** Create long-lived WASM structs in `useEffect`, never during render; `free()` them in the cleanup and null the ref (`sim.current?.free(); sim.current = null`). StrictMode mounts, unmounts and remounts in development, so anything else double-frees or leaks.
- **Per frame.** In `useFrame`, one `update(dt)` call with the clamped delta, then the memory-growth check from `../wasm.md` § Memory views and growth.
- **One-shot generators** (terrain, meshes): inside `useMemo`, build the geometry from owned copies (`Vec<f32>` results) and `free()` the generator before returning. R3F doesn't dispose a geometry passed as a prop, so add `useEffect(() => () => geometry.dispose(), [geometry])`.
- **Particles from WASM.** Points draw at 1 px under `WebGPURenderer`, so render an instanced `Sprite` (`count`, r177+) whose `SpriteNodeMaterial` reads positions through `instancedDynamicBufferAttribute(attr)`, where `attr` is an `InstancedBufferAttribute` over the WASM view; set `count` and `frustumCulled = false`. After each `update(dt)`, set `attr.needsUpdate = true`, or the particles freeze. Allocate everything in the Rust constructor so memory never grows after init; if the guard still fires, rebuild the attribute and the material's `positionNode` (a one-off recompile). Particles whose state never leaves the GPU skip WASM entirely (`../shaders.md` § Compute).
