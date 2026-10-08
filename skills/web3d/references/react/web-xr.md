# @react-three/xr (v6)

Raw WebXR, the backend versions, adding XR to an existing scene, support probes and XR performance levers: `../web-xr.md`.

**Backend.** @react-three/xr never requests the `'webgpu'` session feature (checked 6.6.31), so on a WebGPU backend `store.enterVR()` throws inside three, in every version that has `WebGPURenderer` XR. XR apps use R3F's default `WebGLRenderer`, or `WebGPURenderer` with `forceWebGL: true` (r173+) and `multiview: true` (r176+) when they need TSL (factory in `setup.md`).

## Store

```tsx
const store = createXRStore({           // module scope: one store per app
  frameRate: false,                     // keep the browser's default rate (below)
  offerSession: false,                  // no browser-initiated session offer when <XR> mounts
  planeDetection: false, meshDetection: false, anchors: false, hitTest: false, domOverlay: false, // a VR viewer uses none
  controller: { teleportPointer: true },
  hand: { teleportPointer: true },
})
<button onClick={() => store.enterVR()}>Enter VR</button>
<Canvas><XR store={store}><Scene /></XR></Canvas>   {/* default WebGLRenderer; see Backend */}
```

- **Defaults ask for a lot** (checked @pmndrs/xr 6.6.31): optional `anchors`, `hand-tracking` (not on Vision Pro), `layers`, `mesh-detection`, `plane-detection`, `dom-overlay` and `hit-test`. Turn off each one the experience doesn't use, or Quest users meet a room-data prompt for a feature you never read. `offerSession` (default `true`) has the browser offer a session as soon as `<XR>` mounts, where it implements `navigator.xr.offerSession`; with it off, a mounted `<XR>` only configures three's XR manager until entry (on localhost it also probes, for `emulate`).
- Controller and hand models load from cdn.jsdelivr.net unless `baseAssetPath` points at a self-hosted copy of `@webxr-input-profiles/assets`.
- `frameRate`: the default `'high'` requests the maximum supported rate and `'mid'` the middle one (about 90 Hz on Quest 3), both possibly above the browser's default. Keep `false`, or pass a function over the supported rates that returns the one the floor headset holds.
- `emulate` defaults to an emulated Quest 3 on localhost when WebXR is missing: a no-headset dev and test tier.
- `customSessionInit` replaces the generated session request; you then own every feature flag.

## Existing scene

- Convert units on a content `<group scale>` switched by `useXR((s) => s.session != null)`, never on `<XROrigin>`; then the dependent values (`../web-xr.md` § Adding XR to an existing scene).
- Wrap what XR must not run in `<IfInSessionMode deny={['immersive-vr', 'immersive-ar']}>`: OrbitControls, the post-processing `EffectComposer`, DOM-based `<Html>` labels. The renderer's own tone mapping then applies in XR: set it to the operator the composer used.
- Gate the offscreen `frameloop` switch (`setup.md` § Lifecycle) on `useXR((s) => s.session == null)`, so it never stops a session.

## Locomotion: comfort defaults

Called bare, `useXRControllerLocomotion(originRef)` moves the user smoothly (translation on) and snap-turns 45°. Unless the UX spec asks for smooth locomotion, turn translation off, `useXRControllerLocomotion(originRef, false, { type: 'snap' })`, and teleport instead: wrap the walkable floor in `<TeleportTarget onTeleport={(point) => …}>` and set the `<XROrigin>` position to that `point`, which is already corrected for the head's offset. No teleport in passthrough AR unless the spec says otherwise.

## Input

- Pointer events (`onClick`, `onPointerEnter`) work the same for mouse, touch, controllers and hands; `pointerEventsType={{ deny: 'grab' }}` filters by pointer type.
- State: `useXRInputSourceState('controller', 'right')?.gamepad['xr-standard-thumbstick']` gives `xAxis` and `yAxis`.
- Events: `useXRInputSourceEvent('all', 'select', (e) => { if (e.inputSource.handedness !== 'right') return; act(e) }, [act])`; the first argument is an input source, `'all'` or `undefined`, and the last is a deps array.

## AR

AR features (`hit-test`, `anchors`, `plane-detection`, `dom-overlay`) must be requested and supported; probe first (`../web-xr.md`).

- Reticle: `useXRHitTest((results, getWorldMatrix) => …, 'viewer')` (the v6 name; v5's `useHitTest` is gone). On a result, `getWorldMatrix(m, results[0])` into a module-scope `Matrix4`, then `m.decompose` into the reticle's ref.
- Anchors: `const [anchor, requestAnchor] = useXRAnchor()`, then `requestAnchor({ relativeTo: 'hit-test-result', hitTestResult })`; render content inside `<XRSpace space={anchor.anchorSpace}>`.
- Planes: `useXRPlanes('floor')`.
- Desktop-only controls go inside `<IfInSessionMode deny={['immersive-vr', 'immersive-ar']}>`.

## Spatial UI

A headset shows no DOM: `<Html>` and `XRDomOverlay` (handheld AR only) don't render in immersive sessions, so in-headset UI lives in the canvas, built with the same design tokens as the page. `@react-three/uikit` 1.x uses `<Container>` as the root (`Root` is deprecated) and patches shaders through `onBeforeCompile`, so it needs `WebGLRenderer`; it breaks under `WebGPURenderer` even with `forceWebGL`.
