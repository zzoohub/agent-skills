# Spatial Audio

three's `AudioListener` plus `PositionalAudio` (a Web Audio `PannerNode` that three sets to HRTF) covers sample playback and 3D panning. Add the listener to the camera; in XR, to the camera `renderer.xr` drives, so it follows the head pose with no manual sync. A `PositionalAudio` added to a mesh emits from its world position. Drop to an AudioWorklet only for custom DSP: procedural synthesis, custom HRTF, reverb driven by scene geometry.

- **Unlock on a gesture.** Browsers start the `AudioContext` suspended; call `listener.context.resume()` in the first `pointerdown`. In XR the Enter VR or AR click is that gesture, so resume there.
- **Pause with the page.** Suspend the context on `visibilitychange` together with the render loop, and resume on return.
- **Budget voices.** HRTF costs CPU per source: cap simultaneous positional sources on phones, and play music and UI sounds through non-positional `THREE.Audio`.
