# Testing

You cannot unit-test a draw call. Rendering, shaders and frame pacing need a real GPU; simulation, math and data are ordinary code. Split along that line and test the testable layer first.

## Tiers

- **Simulation (write first).** ECS systems, game rules, WASM kernels and math (buffer offsets, coordinates, interpolation) are plain functions: a unit test with a fixed delta, spawn, run, assert.
- **Motion.** Step the same motion for one second at 30, 60 and 120 Hz and assert the same end value. A per-frame increment or a per-frame lerp fails it at once.

  ```ts
  test('a damped value lands in the same place at any frame rate', () => {
    const run = (hz: number) => { let x = 0; for (let i = 0; i < hz; i++) x = MathUtils.damp(x, 1, 4, 1 / hz); return x }
    expect(run(30)).toBeCloseTo(run(120), 6)
  })
  ```

- **Physics.** Step at a fixed timestep from snapshot states. Results compared across machines need the deterministic build (`physics.md` § Pick one build).
- **Scene graph (React Three Fiber).** `@react-three/test-renderer` asserts objects, props and events without a GPU.
- **GPU visual.** A browser test against a pinned adapter (same GPU, driver and browser build on every run), with a pixel diff and a tolerance. Run both backends wherever the renderer has two (`forceWebGL: true` for the second): they differ.
- **Still is free.** With nothing moving, the rendered-frame counter does not advance.
- **Mode parity.** An added mode gets one reference view captured in and out of it (XR through the emulator, then once on the headset) and compared for scale, color and overlays. The existing path's visual baseline must not move.
- **Leak.** Ten mount and unmount cycles; `renderer.info.memory` returns to baseline.
- **Soak.** Five minutes at the heaviest interaction on the floor device, measured with the frame probe (`performance.md`).
- **XR.** An emulator for session logic, plus one pass on the headset before release (`xr.md` § Device testing).

```ts
test('the reference view keeps its look', async ({ page }) => {
  await page.goto('/viewer?view=reference') // fixed camera, no animation
  await page.waitForFunction(() => (window as any).__frames > 3) // the rendered-frame counter
  await expect(page.locator('canvas')).toHaveScreenshot('reference.png', { maxDiffPixelRatio: 0.01 })
})

test('an idle viewer draws nothing', async ({ page }) => {
  await page.goto('/viewer?view=reference')
  await page.waitForFunction(() => (window as any).__frames > 3)
  const before = await page.evaluate(() => (window as any).__frames)
  await page.waitForTimeout(1000)
  expect(await page.evaluate(() => (window as any).__frames)).toBe(before)
})
```

## A GPU in CI

- Expose a rendered-frame counter on `window`, wait for a few frames after load, then screenshot the canvas element only. Read a WebGPU canvas in the same task as the render: after the frame is presented its contents are gone.
- A headless browser on a runner without a GPU has no hardware WebGL and no WebGPU. The flags that enable software rendering or a real GPU change between browser releases (`landscape.md` § Tooling): confirm what the runner actually got on `chrome://gpu`, or gate GPU tests behind a capability probe and skip them with a stated reason.
- A software renderer proves the look, never the frame time.

## Guards

A diagnosed bug ships with the test that would have caught it.

- **A look or color fault:** a visual baseline of a reference view, plus an assertion on the settings at fault (`toneMapping`, `outputColorSpace`, a color map's `colorSpace` after load).
- **A performance regression:** the frame probe's on-time share and p95 against the budget in a device or lab run, failing on a drop. And the asset gate (`assets.md` § The CI gate) for what an asset can regress.
- **A leak:** the Leak tier.
- **Rate-dependent motion:** the Motion tier.
- **A version-gated API:** a startup check that `THREE.REVISION` meets the gate, so a downgrade fails loudly.

## Tests first, here

"Tests first" means the simulation, motion, physics and math tests come before the implementation. It does not mean a failing test for "the sphere looks right": that is a visual baseline captured once the look is approved, then guarded against drift.
