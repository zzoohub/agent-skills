# Testing Web 3D and XR

You cannot unit-test a draw call. Rendering, shaders and frame pacing need a real GPU; simulation, math and data are ordinary code. Split along that line and test the testable layer first.

## Tiers

- **Simulation (write first).** ECS systems, game rules, WASM kernels and math (buffer offsets, NDC, interpolation) are plain functions: Vitest with a fixed delta, spawn, run, assert. Test WASM with `wasm-bindgen-test` or Vitest against the built package.
- **Physics.** Step at a fixed timestep from snapshot states; results compared across machines need the deterministic build (`physics.md`, Determinism).
- **Scene graph (R3F).** `@react-three/test-renderer` asserts objects, props and events without a GPU.
- **GPU visual.** Playwright against a pinned adapter (same GPU, driver and browser build on every run), with a pixel diff and a tolerance. `forceWebGL: true` is the cheapest stable context; also run the WebGPU backend wherever CI has a GPU, since the two backends differ.
- **Mode parity.** An added mode gets one reference view captured in and out of it (XR through the emulator, then once on the headset) and compared for scale, color and overlays; the existing path's visual baseline must not move.
- **Leak.** 10 mount/unmount cycles; `renderer.info.memory` returns to baseline.
- **Soak.** 5 minutes at the heaviest interaction on the floor device, measured with the frame probe (`performance.md` § Budget).
- **XR.** An emulator for session logic, plus one pass on the headset before release; setup in `web-xr.md` § Device testing.

## GPU in CI

- Use Chrome's documented headless-GPU flags for the runner's OS (on Linux, Vulkan ANGLE plus `--enable-unsafe-webgpu` where WebGPU is not on by default), and confirm hardware acceleration on `chrome://gpu` inside the runner.
- Since Chrome 139, WebGL no longer falls back to SwiftShader automatically. On GPU-less runners pass `--enable-unsafe-swiftshader`, or gate GPU tests behind a capability probe and skip them with a stated reason.
- Expose a rendered-frame counter on `window`, wait for a few frames after load, then screenshot the canvas element only.

## Guards

A diagnosed bug ships with the test that would have caught it:
- A look or color fault: a visual baseline of a reference view, plus an assertion on the settings at fault (`toneMapping`, `outputColorSpace`, color-map `colorSpace` after load).
- A performance regression: the frame probe's on-time % and p95 against the budget in a device or lab run, failing on a drop.
- A leak: the Leak tier.
- A version-gated API: a startup check that `THREE.REVISION` meets the gate, so a downgrade fails loudly.

```ts
test('reference view keeps its look', async ({ page }) => {
  await page.goto('/viewer?view=reference')                                  // fixed camera, no animation
  await page.waitForFunction(() => (window as any).__frames > 3)              // the rendered-frame counter
  await expect(page.locator('canvas')).toHaveScreenshot('reference.png', { maxDiffPixelRatio: 0.01 })
})
```

## Tests first, here

"Tests first" means the simulation, physics, WASM and math tests come before the implementation. It does not mean a failing test for "the sphere looks right": that is a visual baseline captured once the look is approved, then guarded against drift.
