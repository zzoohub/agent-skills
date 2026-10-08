# WebXR

R3F bindings: `react/web-xr.md`. Comfort and interaction rules come from the UX spec (SKILL.md, Build step 6).

## Backend first

Read the installed three version before choosing (SKILL.md, Version gates and probes). Until WebGPU XR is verified on the target headset, render XR on a WebGL backend.
- **Before r173** `WebGPURenderer` has no XR: use `WebGLRenderer`.
- **r173–r184:** `WebGPURenderer` XR runs only on its WebGL backend (`forceWebGL: true`); entering XR on a WebGPU backend throws.
- **r185+:** a WebGPU-backend session needs the `'webgpu'` session feature and a browser with `XRGPUBinding`, else it throws; WebGPU XR has no multiview yet (checked r186), so every draw runs once per eye. `setupWebGLXRFallback` (`three/addons/webxr/WebGLXRFallback.js`, r185+) swaps, at session start, to a WebGL-backend renderer you construct where `XRGPUBinding` is missing; request `optionalFeatures: ['webgpu']` so browsers that have it use WebGPU. The swap is a second renderer with its own canvas, and every resource uploads again: install it in `onFallback` and retire the first.
- **Multiview** (both eyes in one pass): `WebGPURenderer({ forceWebGL: true, multiview: true })`, r176+, where the device exposes `OVR_multiview2`. Classic `WebGLRenderer` has none (checked r186).

## Adding XR to an existing scene

The non-XR experience is the baseline (SKILL.md § Add a mode): nothing in it changes until the user enters XR, and leaving restores it.
- **Entry.** Load the XR code on demand. three's `VRButton`, `ARButton` and `XRButton` call `isSessionSupported` when created and, where the browser implements `navigator.xr.offerSession`, offer a session at once (checked r186): create them with the XR entry UI, not at startup.
- **Units.** 1 unit = 1 m: head pose, eye separation, controller rays and hit tests arrive in meters. Convert at the content root (a group scaled on session start and restored on end, or a meters conversion the whole app adopts), then each dependent value (SKILL.md § Add a mode, step 4). Scaling the camera does nothing: `updateCamera` overwrites its transform from the pose every frame. Scaling its parent rig pushes the scale into view space, where three computes fog and light falloff, while `camera.near` and `far` still reach the device as meters (`depthNear`, `depthFar`): give the session its own near and far.
- **Camera.** In session the engine owns pose, projection and FOV, and the user starts at the reference-space origin at real eye height. Put the camera in a rig placed at floor level where the desktop view stood; disable OrbitControls and camera tweens on `sessionstart`; move the user by moving the rig; restore camera and controls on `sessionend` (system UI can end the session).
- **Output transform.** XR usually renders without the post stack (Performance levers). The renderer then tone-maps and converts color for built-in materials in the XR framebuffer, so set `renderer.toneMapping` to the operator the stack used; custom GLSL on `WebGLRenderer` needs `#include <tonemapping_fragment>` and `#include <colorspace_fragment>` to match; grading passes (bloom, LUT, vignette) vanish: bake them into materials or report the difference. Compare one reference view in and out of XR.
- **Overlays.** A headset shows no DOM: HTML labels, `CSS2DRenderer` or `CSS3DRenderer` output and HUDs need in-canvas versions (MSDF text, canvas textures); handheld AR can use `dom-overlay`.
- **Input.** Route picking through one function that takes a ray: pointer NDC outside XR, the controller's target ray (`select` events, transient inputs) inside.
- **Loop and size.** XR frames come only through `renderer.setAnimationLoop`, never a `window.requestAnimationFrame` loop. Both renderers ignore `setSize` while presenting: run the resize handler again on `sessionend`. Gate offscreen and hidden-tab pauses on `!renderer.xr.isPresenting`.

## Support and features

- `await navigator.xr?.isSessionSupported('immersive-vr')` (or `'immersive-ar'`) when the Enter button mounts, before showing it. It reports capability, not device class.
- Request only the modules the experience uses (`hand-tracking`, `hit-test`, `anchors`, `plane-detection`, `layers`, `depth-sensing`), as `optionalFeatures`, and check `session.enabledFeatures` before use; a missing `requiredFeatures` entry fails the whole session. Extras cost: Quest Browser asks the user to share room data when a page requests plane detection (developers.meta.com/horizon/documentation/web/webxr-mixed-reality), and depth sensing adds per-frame occlusion work.
- Controller and hand models: three's `XRControllerModelFactory` and `XRHandModelFactory` (`'mesh'`) fetch from cdn.jsdelivr.net at runtime (checked r186). Self-host `@webxr-input-profiles/assets` and call `setPath()`, or ship your own models: availability, version pinning, COEP.
- Per MDN browser-compat-data (2026-10): no WebXR in Firefox or in Safari on iOS and macOS; Chromium browsers have it, including Quest Browser and Chrome on Android XR. visionOS Safari runs immersive VR but not `immersive-ar` (Apple developer forums thread 826845, 2026). Re-check before promising a platform.

## Quick Look

Apple AR opens a USDZ from `<a rel="ar">` wrapping a single `<img>`. `<model-viewer>` generates it; a hosted `ios-src` adds fidelity and is the only AR path in third-party iOS browsers. A custom renderer exports the current state with three's `USDZExporter` (`parseAsync` into a blob URL; Safari only) or links pre-baked per-variant files. USDZ keeps standard PBR only: check each variant in Quick Look.

## Session

- Reference space: request `local-floor`, fall back to `local`; `bounded-floor` for room scale. Only reticles live in `viewer` space.
- **Frame rate sets the budget.** If `session.supportedFrameRates` exists (Quest Browser only; MDN BCD, 2026-10), `await session.updateTargetFrameRate(rate)` with the rate the floor headset holds; otherwise the session runs at the device's rate.
- Driving the session without `renderer.xr`: the GL context must be XR-compatible (`xrCompatible: true`, or `await gl.makeXRCompatible()`) before you create the `XRWebGLLayer`, or it throws `InvalidStateError`.

## Input

- A `select` event's frame supports only `getPose()` and `getJointPose()`; `getViewerPose()` throws there.
- `xr-standard` gamepads keep absent inputs' slots, so the thumbstick is `axes[2..3]`: `const [, , x, y] = gamepad.axes`. Haptics are optional: `gamepad.hapticActuators?.[0]?.pulse?.(0.5, 100)`.
- Transient inputs (Vision Pro gaze and pinch, handheld-AR screen taps) exist only during the gesture; in AR, hit-test them with `requestHitTestSourceForTransientInput` and `getHitTestResultsForTransientInput`.
- AR content placed from a hit test drifts as tracking refines: anchor it (`hit.createAnchor()`) and read the anchor's pose each frame.

## Performance levers, in order

1. Run a rate the headset holds, not its maximum.
2. Multiview (Backend first) draws both eyes in one pass.
3. Fixed foveation: `renderer.xr.setFoveation(0..1)`.
4. Framebuffer scale 0.8–0.9 (`renderer.xr.setFramebufferScaleFactor`, before the session) as a last resort.
5. No full-screen post-processing: each pass runs per eye. Dropping it moves its output transform and grading (Adding XR, Output transform). MSAA (`antialias: true`), not FXAA.
6. Text as MSDF or a WebXR layer, which stay sharp.

## Device testing

Develop against an emulator (the Immersive Web Emulator extension, or @react-three/xr's `emulate`), then test on the headset over HTTPS, or over `adb reverse tcp:5173 tcp:5173` with the dev server on localhost, inspecting through `chrome://inspect`. Frame timing counts only when measured on the headset; the reference-view comparison (`testing.md` § Tiers, mode parity) runs on the headset once before release.
