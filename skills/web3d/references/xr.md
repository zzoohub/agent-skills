# WebXR

In a headset the frame budget is a comfort floor: a dropped frame is discomfort, not jank. Comfort and interaction rules come from the UX spec (SKILL.md § Build, step 8); this file is the implementation. Which browser and device supports what, today: `landscape.md` § Platform support.

## Backend first

Read the installed three version before choosing. Until WebGPU XR is verified on the target headset, render XR on a WebGL backend.

- **Before r173** `WebGPURenderer` has no XR: use `WebGLRenderer`.
- **r173 to r184:** `WebGPURenderer` XR runs only on its WebGL backend (`forceWebGL: true`). Entering XR on a WebGPU backend throws.
- **r185+:** a WebGPU-backend session needs the `'webgpu'` session feature and a browser with `XRGPUBinding`, else it throws. `setupWebGLXRFallback` (`three/addons/webxr/WebGLXRFallback.js`) swaps, at session start, to a WebGL-backend renderer you construct where the binding is missing; request `optionalFeatures: ['webgpu']` so browsers that have it use WebGPU. The swap is a second renderer with its own canvas, and every resource uploads again: install it in `onFallback` and retire the first.
- **Multiview** (both eyes in one pass): `WebGPURenderer({ forceWebGL: true, multiview: true })`, r176+, where the device exposes `OVR_multiview2`. Without it every draw runs once per eye. Whether the WebGPU backend or classic `WebGLRenderer` has it yet: `landscape.md` § three.js.

## Adding XR to an existing scene

The non-XR experience is the baseline (SKILL.md § Change a working scene): nothing in it changes until the user enters XR, and leaving restores it.

- **Entry.** Load the XR code on demand. three's `VRButton`, `ARButton` and `XRButton` call `isSessionSupported` when created and, where the browser implements `navigator.xr.offerSession`, offer a session at once: create them with the XR entry UI, not at startup.
- **Units.** One unit is one meter: head pose, eye separation, controller rays and hit tests arrive in meters. Convert at the content root (a group scaled on session start and restored on end, or a meters conversion the whole app adopts), then each dependent value (SKILL.md § Change a working scene, step 4). Scaling the camera does nothing, because the engine overwrites its transform from the pose every frame. Scaling its parent rig pushes the scale into view space, where three computes fog and light falloff, while `camera.near` and `far` still reach the device as meters: give the session its own near and far.
- **Camera.** In a session the engine owns pose, projection and field of view, and the user starts at the reference-space origin at real eye height. Put the camera in a rig placed at floor level where the desktop view stood. Disable orbit controls and camera tweens on `sessionstart`, move the user by moving the rig, and restore camera and controls on `sessionend` (system UI can end the session).
- **Output transform.** XR renders without the post stack (§ Performance levers). The renderer then tone-maps and converts color for built-in materials in the XR framebuffer, so set `renderer.toneMapping` to the operator the stack used. Grading passes (bloom, LUT, vignette) vanish: bake them into materials or report the difference. Compare one reference view in and out of XR.
- **Overlays.** A headset shows no DOM. HTML labels, `CSS2DRenderer` output and HUDs need in-canvas versions (§ Text and UI); handheld AR can use `dom-overlay`.
- **Input.** Route picking through one function that takes a ray: pointer coordinates outside XR, the controller's target ray inside.
- **Loop and size.** XR frames come only through `renderer.setAnimationLoop`, never a `window.requestAnimationFrame` loop. The renderer ignores `setSize` while presenting: run the resize handler again on `sessionend`. A loop that sleeps off screen or in a hidden tab keeps running while `renderer.xr.isPresenting` (the skeleton in `setup.md` does).

## Support and features

- **Probe where the mode is entered:** `await navigator.xr?.isSessionSupported('immersive-vr')` (or `'immersive-ar'`) when the Enter button mounts, before showing it. It reports capability, not device class: phones and headsets both pass.
- **Request only what the experience uses** (`hand-tracking`, `hit-test`, `anchors`, `plane-detection`, `layers`, `depth-sensing`), as `optionalFeatures`, and check `session.enabledFeatures` before use. A missing `requiredFeatures` entry fails the whole session. Extras cost: a headset may ask the user to share room data when a page requests plane detection, and depth sensing adds per-frame occlusion work.
- **Controller and hand models.** three's `XRControllerModelFactory` and `XRHandModelFactory` fetch from a public CDN at runtime. Self-host `@webxr-input-profiles/assets` and call `setPath()`, or ship your own models: availability, version pinning, isolation.

## Apple AR

iPhones have no WebXR. AR there is Quick Look: a USDZ opened from `<a rel="ar">` wrapping a single `<img>`. `<model-viewer>` generates one; a hosted `ios-src` adds fidelity. A custom renderer exports the current state with three's `USDZExporter` (`parseAsync` into a blob URL) or links pre-baked files per variant. USDZ keeps standard PBR only: check each variant in Quick Look. The native `<model>` element is the other route on Apple platforms (`landscape.md` § Platform support).

## Session

- **Reference space:** request `local-floor`, fall back to `local`; `bounded-floor` for room scale. Only reticles live in `viewer` space.
- **Frame rate sets the budget.** Where `session.supportedFrameRates` exists, `await session.updateTargetFrameRate(rate)` with the rate the floor headset holds; elsewhere the session runs at the device's rate. Tell the frame probe (`setHz`).
- **Driving the session without `renderer.xr`:** the GL context must be XR-compatible (`xrCompatible: true`, or `await gl.makeXRCompatible()`) before you create the `XRWebGLLayer`, or it throws `InvalidStateError`.

## Input

- A `select` event's frame supports only `getPose()` and `getJointPose()`; `getViewerPose()` throws there.
- `xr-standard` gamepads keep absent inputs' slots, so the thumbstick is `axes[2..3]`: `const [, , x, y] = gamepad.axes`. Haptics are optional: `gamepad.hapticActuators?.[0]?.pulse?.(0.5, 100)`.
- Transient inputs (gaze and pinch, handheld-AR screen taps) exist only during the gesture. In AR, hit-test them with `requestHitTestSourceForTransientInput`.
- AR content placed from a hit test drifts as tracking refines: anchor it (`hit.createAnchor()`) and read the anchor's pose each frame.

## Performance levers, in order

1. Run a rate the headset holds, not its maximum.
2. Multiview (§ Backend first).
3. Fixed foveation: `renderer.xr.setFoveation(0..1)`.
4. Framebuffer scale 0.8 to 0.9 (`renderer.xr.setFramebufferScaleFactor`, before the session), as a last resort.
5. No full-screen post-processing: each pass runs per eye. MSAA (`antialias: true`), not a post-processing antialias.
6. Text as MSDF or a WebXR layer, which stay sharp.

## Text and UI

In-headset UI lives in the canvas, built with the same design tokens as the page. What works depends on the renderer: text and UI libraries built on GLSL patches need `WebGLRenderer`, and the DOM-as-texture route is new (`landscape.md` § WebGL-only helpers, § What is changing). A `CanvasTexture` label on a plane works everywhere.

## With React Three Fiber

`@react-three/xr` 6.

```tsx
// xr/store.tsx
import { Canvas } from '@react-three/fiber'
import { createXRStore, IfInSessionMode, XR } from '@react-three/xr'
import type { ReactNode } from 'react'

export const xr = createXRStore({ // module scope: one store per app
  frameRate: false, // keep the browser's default rate
  offerSession: false, // no browser-initiated session offer when <XR> mounts
  anchors: false, planeDetection: false, meshDetection: false, hitTest: false, domOverlay: false, // a VR viewer uses none of them
  controller: { teleportPointer: true },
  hand: { teleportPointer: true },
})

export function Experience({ scene, desktopOnly }: { scene: ReactNode; desktopOnly: ReactNode }) {
  return (
    <>
      <button onClick={() => xr.enterVR()}>Enter VR</button>
      <Canvas>{/* R3F's default WebGLRenderer: @react-three/xr never asks for the 'webgpu' session feature */}
        <XR store={xr}>
          {scene}
          <IfInSessionMode deny={['immersive-vr', 'immersive-ar']}>{desktopOnly /* orbit controls, post-processing, DOM labels */}</IfInSessionMode>
        </XR>
      </Canvas>
    </>
  )
}
```

- **Backend.** The library does not request the `'webgpu'` session feature (`landscape.md` § Verified versions), so on a WebGPU backend `enterVR()` throws inside three. XR apps use R3F's default `WebGLRenderer`, or `WebGPURenderer` with `forceWebGL: true` and `multiview: true` when they need TSL.
- **The defaults ask for a lot:** optional `anchors`, `hand-tracking`, `layers`, `mesh-detection`, `plane-detection`, `dom-overlay` and `hit-test`. Turn off each one the experience does not use, or users meet a room-data prompt for a feature you never read.
- **`offerSession`** (default `true`) has the browser offer a session as soon as `<XR>` mounts. With it off, a mounted `<XR>` only configures three's XR manager until entry.
- **`frameRate`:** the default `'high'` requests the maximum supported rate. Keep `false`, or pass a function over the supported rates that returns the one the floor headset holds.
- **`emulate`** defaults to an emulated headset on localhost when WebXR is missing: a no-headset dev and test tier. Controller and hand models load from a CDN unless `baseAssetPath` points at a self-hosted copy.
- **Existing scene.** Convert units on a content `<group scale>` switched by `useXR((s) => s.session != null)`, never on `<XROrigin>`. Wrap what XR must not run in `<IfInSessionMode deny={…}>` as above. Gate any off-screen pause on `useXR((s) => s.session == null)`, so it never stops a session.
- **Locomotion.** Called bare, `useXRControllerLocomotion(originRef)` moves the user smoothly and snap-turns. Unless the UX spec asks for smooth locomotion, turn translation off (`useXRControllerLocomotion(originRef, false, { type: 'snap' })`) and teleport instead: wrap the walkable floor in `<TeleportTarget onTeleport={(point) => …}>` and set the `<XROrigin>` position to that point. No teleport in passthrough AR unless the spec says otherwise.
- **Input.** Pointer events (`onClick`, `onPointerEnter`) work the same for mouse, touch, controllers and hands. State: `useXRInputSourceState('controller', 'right')`. Events: `useXRInputSourceEvent('all', 'select', handler, deps)`.
- **AR.** Reticle: `useXRHitTest((results, getWorldMatrix) => …, 'viewer')`. Anchors: `useXRAnchor()`, with content inside `<XRSpace space={anchor.anchorSpace}>`. Planes: `useXRPlanes('floor')`. Each feature must be requested and supported.

## Device testing

Develop against an emulator (the Immersive Web Emulator extension, or `emulate` above), then test on the headset over HTTPS, or over `adb reverse tcp:5173 tcp:5173` with the dev server on localhost, inspecting through `chrome://inspect`. Frame timing counts only when measured on the headset. The reference-view comparison (`testing.md` § Tiers) runs on the headset once before release.
