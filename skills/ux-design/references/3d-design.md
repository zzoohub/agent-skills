# 3D Interface Design

UX decisions for 3D on a screen (viewers, configurators, spaces, maps, editors, scroll stories) and the hand-off to phone AR. Headsets and glasses: `xr-design.md`. Implementation goes to the web3d capability, if available, and the spec's numbers are its acceptance criteria. Sections follow the spatial spec's order; Diagnose serves reviews.

## Job & baseline

3D costs load time, battery, accessibility work and a learning curve. It pays only when the user's decision depends on shape seen from many angles, fit or scale in a real place (phone AR), more option combinations than you can photograph (configurator), spatial relationships (layouts, routes, assemblies), or making 3D things (an editor). Otherwise a photo set, a 360° image spin, a video or a diagram wins: faster, works everywhere, accessible by default. "It looks impressive" is not a job; ship a poster or a video.

Name the baseline the 3D must beat and the metric that shows it: questions answered without support, add-to-cart, returns, task time.

## Experience ladder

| Level | Ships | Rule |
|---|---|---|
| 0 Fallback | Images or a 360° spin, plus the facts as text | Always present; enough to decide |
| 1 Inline 3D | The viewer in the page | Complete on its own |
| 2 AR, immersive | Phone AR (below) or a headset session | A bonus, offered only where it works |

- Each step up is an explicit action (tap to interact, expand, view in AR) with a visible way back to the same configuration and view.
- Never show an error for a capability the device lacks: hide the entry point (desktop AR gets a QR hand-off).

## Camera

The content class picks the camera model.

| Class | Camera model | Default view |
|---|---|---|
| Object, product | Turntable orbit, fixed target, pan off | Three-quarter, slightly above |
| Space, interior | First-person look plus click-to-move hotspots | Eye height at the entrance |
| Map, data | Map controls: drag pans, wheel zooms to the cursor, modifier-drag tilts | Top-down, north up |
| Editor | The host tool's convention plus gizmos | The working view |
| Narrative | A scroll-linked path | The first story frame |

*Break when* users bring a habit from a tool (CAD, games): give them that tool's mapping.

- **Clamp before you free:** never below the ground or inside the object; zoom from the nearest useful detail out to the object in context.
- **The camera moves only for the user:** in response to their action (focus the part they picked), interruptible by any input. Idle auto-rotation is the one exception: it stops for good on the first input, and past 5 s it needs a visible pause (WCAG 2.2.2).
- **Reduced motion:** no auto-rotation or animated camera moves; view changes cut or crossfade.
- **Reset is a visible button**, never only a double-click or double-tap, which users read as "zoom to here".
- **One gesture, one meaning:** wherever the viewer takes the wheel or pinch (Input map), they move the camera, never an object; objects move or scale with handles or in an edit mode.

## Input map

Map each action for mouse, touch and keyboard, plus its single-pointer alternative (Accessibility).

- **Inline on a scrolling page, the page owns scrolling.** Touch: one-finger horizontal drag rotates, vertical drag scrolls the page. Desktop: the wheel scrolls the page; zoom with buttons, Ctrl/⌘ + wheel, or after the user engages the viewer, as embedded maps do. Full orbit, pan and pinch live in an expanded mode with a visible close. *Break when* the viewer is the page (a configurator): pin the canvas and scroll the options beneath it.
- **Cue the first interaction** with a short gesture hint on the viewer ("Drag to rotate") that disappears on first use.
- **Selection** shows an outline plus a label, never color alone. Inflate small parts until their on-screen hit area meets the touch-target floor in `ergonomics.md`.
- **Manipulation** (editors, room planners): handles or gizmos, snapping, a contact shadow on anything resting on a surface, undo for every transform.
- **Controls live in the 2D layer** beside or over the viewer, not inside the scene, where they stay readable, focusable and findable. *Break for* hotspots pinned to parts, each with a list or text equivalent.

## Patterns by class

**Configurator**
- Never change another option silently: when a choice invalidates others, say which and why, with one-tap resolve or revert.
- Order steps by constraint (size before fabric), not by catalog taxonomy; jumping between steps stays allowed.
- Show each option's price and lead-time difference before it is chosen, and the running total always.
- Large option sets: group, filter, preselect a recommended default; never truncate the catalog.
- The view frames the part that changed; on phones the viewer stays visible while options scroll.
- The URL holds the full configuration; the cart receives the exact SKU or build.
- Where color drives returns, check renders against product photos and offer physical swatches.

**Phone AR**
- Label by outcome ("View in your room"). Show it on AR-capable phones, on desktop as a QR code carrying the configuration, and nowhere else.
- Open at true scale with the current configuration; coach the surface scan with animation, not text.
- Tap places, drag moves, twist rotates; if scaling is allowed, show the scale and snap to 100% near true size.
- States: no surface found (keep coaching, offer exit); camera permission denied (explain, stay on the page). Leaving returns to the page unchanged.
- *Break when* size and placement don't affect the decision: skip AR.

**Scroll-linked story:** native scroll drives the timeline, so the scrollbar is the progress indicator and skipping is scrolling. Every scene's message also exists as text, in order; reduced motion shows static key frames.

**Photoreal capture** (Gaussian splats): capture edges read as broken, so constrain the camera to the captured volume, start at the best-captured viewpoint and mask the edges. Ship compressed and progressive, with an image fallback.

## Loading & states

- The poster is a real image matching the default view (above the fold, the page's LCP candidate). Load the 3D on visibility or first interaction; allow orbit as soon as a low-detail model is up, never behind a blocking overlay.
- States beyond the 7 base states (`interaction-patterns.md`): 3D unavailable → Level 0; asset failed → poster plus retry; graphics context lost → poster, then restore view and configuration; throttled → lower detail, not frame rate.
- Done: the host page's LCP and INP do not regress, and interaction stays smooth on the weakest target device (web3d owns the frame budget).

## Accessibility

- **Text first.** Everything the 3D tells (dimensions, materials, the chosen configuration) also exists as text beside the viewer; for a screen-reader user, keyboard orbit is no substitute.
- Announce state changes ("Color: forest green") in a polite status region.
- **Single-pointer alternatives:** rotate, zoom and reset buttons for every drag and pinch (WCAG 2.2 SC 2.5.7, AA; SC 2.5.1, A).
- **Keyboard:** visible focus on the viewer; arrows orbit, +/− zoom; Tab always leaves it (SC 2.1.2).
- Swatches carry names, and zoom reaches the detail low-vision users need.

## Test & measure

Test on the weakest target phone, on the real page, with people new to 3D viewers: do they find the interaction, scroll past it and answer the job's question? Measure the job metric against the baseline, and the share of sessions that use the viewer.

## Diagnose

Severity follows the review scale in SKILL.md.

| Symptom | Likely cause → check | Default |
|---|---|---|
| Viewer ignored | No interaction cue, a static-looking poster → watch first sessions | 🟡 |
| Phone users can't scroll past it | Canvas captures vertical drag or the wheel → test the gesture policy | 🟠 |
| Users lose the object | Unclamped camera, no visible reset → try to fly inside or under it | 🟡 |
| Configurator abandonment, returns | Silent invalidation, late price, off-color renders → walk a conflicting combination | 🟠 |
| AR unused or quickly abandoned | Shown where unsupported, no scan coaching, wrong scale → try two phones | 🟡 |
| Screen-reader or keyboard users stuck | No text alternative, focus trap, drag-only controls | 🔴 |
| Jank, heat | Over the frame budget on the weakest device → measure; web3d fixes | 🟠 |
