# XR Spatial Design

UX decisions for experiences the user is inside: headset mixed reality (passthrough) and VR, and display glasses. Screen 3D and phone AR: `3d-design.md`. Implementation goes to the web3d capability (WebXR), if available, and the spec's numbers are its acceptance criteria. Sections follow the spatial spec's order; Diagnose serves reviews.

Platform numbers below were checked against Apple, Google and Meta guidelines in 2026-10; before putting one in a spec, check the current guideline and cite it with the date. Angles and acceleration don't change.

## Context

| Framing answer | Design consequence |
|---|---|
| Display glasses | Glanceable: brief, high-contrast, shown only when relevant, off-center, paired with audio; no immersion ladder. Additive displays render black as transparent: use bright, heavy text, not dark panels |
| Seated, or a non-rotating chair | Everything interactive in front, within reach from the seat, at seated eye height; snap turn instead of turning the body |
| Standing or room-scale | Declare the space needed; keep every interaction inside the play area; design the boundary state |
| Shared or public room | No voice-only actions; small gestures; stay in passthrough |
| First-time XR users | Teach input inside the first real task, not in a separate tutorial |
| Long sessions | Lower immersion, natural break points, settings that persist |

## Experience ladder

panel in the room → bounded 3D volume → unbounded content in passthrough → full immersion (VR)

- Start on the lowest rung that does the job, in passthrough (Apple: launch in the shared space or mixed immersion).
- Climb only on an explicit user action; never auto-immerse.
- Every rung has a visible one-step way back labeled with where it goes (back to the window, or quit). Never make people use system controls to leave.
- Fade between passthrough and virtual; never cut. Loading, errors and mode changes keep passthrough visible, never a black void.
- If people must walk, stay in passthrough: platforms fade full immersion near a boundary (visionOS: about 1.5 m from where the user started).
- *Break when* the environment is the product (a game, a meditation): still enter through a passthrough start, then immerse on the user's go.

## Placement & anchoring

**Distance follows input.**
- Direct touch: within arm's reach (Meta: ≈45 cm, ≈70 cm when hands and controllers both work), for brief use only.
- Indirect input (eyes or ray, then pinch) and anything read or watched for long: at least 1 m (Apple). Platform defaults run about 1–2 m: Meta ≈1 m, Android XR 1.75 m, visionOS ≈2 m for a new window.

**Angle.** Keep frequent content in the central field (Android XR: the center 41°, about ±20°). People turn their heads sideways more easily than up or down, so secondary content goes to the sides rather than above or below. Center primary content slightly below eye level (Android XR: 5°), measured from the user's current eye height, never a fixed height above the floor. Nothing viewed for long sits above eye level (neck strain), and nothing touched often sits at or above it (arm fatigue).

**Size by angle.** 1° ≈ 1.75 cm per metre of distance. Size UI in platform units, which already scale with distance (visionOS points are angles; Android XR uses distance-independent units). UI and interactive objects use dynamic scale; fixed (true) scale is for objects that must look life-size, which Apple keeps non-interactive. Check custom 3D targets on the device against a system button at the same distance.

*Example:* a 3 cm button reads well at 0.5 m (≈3.4°) but shrinks to ≈1° at 1.75 m, below any system target: give it dynamic scale or size it for its farthest distance.

**Anchoring**

| Content | Anchor |
|---|---|
| Panels, objects | World-locked: where the system or the user put them |
| Toolbars, palettes | Lazy-follow: catch up after the user turns, never every frame |
| Brief alerts | Head-locked for seconds only, small, off-center |
| Labels for physical things | On the thing (surface or object anchor) |

- Nothing else stays head-locked: it feels confining and blocks assistive pointers (Apple).
- Check reserved hand gestures before anchoring UI to the hand or wrist: visionOS keeps the palm and hand turn for system overlays.
- *Break when* the device is display glasses: head-locked is the medium there (Context).
- **Who places what:** in shared spaces the system places windows and the user moves them; you place only your own immersive content, so design layouts that survive being moved.
- **Persistence:** room-anchored content is easy to move and remove, may differ per room, and has an "anchor not found" state.
- **Respect the room:** virtual content never intersects walls or furniture; anything that rests on something sits on a detected surface.

## Input map

Write each core action against each target device's inputs. Meta treats controllers and hands as primary and defaults to gaze plus hands on eye-tracking devices without controllers; visionOS is eyes plus hands.

- **Eyes target; hands, voice or buttons commit.** Gaze alone never activates, least of all a destructive action. Never build dwell-to-activate: dwell is the platform's accessibility setting, not an app pattern. visionOS tells an app where people looked only when they act, so no feature may depend on gaze before a tap.
- **Indirect first, hands resting low.** Direct touch only for nearby objects handled briefly.
- **Hands have no haptics and lose tracking.** Every target shows a press state and plays a click at the target; controllers add haptics but keep the visual press; spatial audio tells where to look.
- **Targets** meet the platform minimum: visionOS 60 pt hit regions with 16 pt margins (or centers 60 pt apart); Android XR 56 dp with 8 dp gaps. Rounded shapes are easier to hold with the eyes.
- **Gestures:** standard gestures for standard actions; a custom gesture is a shortcut, distinct from system gestures (alternatives and one-hand use: Accessibility).
- **Text entry:** use the system text field (dictation, physical keyboards and autofill come with it) and design typing out of flows. Voice is an option, never the default in shared rooms and never for secrets.

## Comfort

- **Remove locomotion first.** Bring content to the person ("pull it closer" beats walking over); design for stationary and seated use unless movement is the point.
- **If the world must move:** teleport plus snap turn by default, with the snap angle a setting (Meta suggests 30, 45 or 90°); smooth movement and smooth turning are opt-ins. Smooth movement keeps a constant speed, starts and stops at once, never rolls or bobs, and narrows the view with an adjustable vignette while moving.
- **The head is the camera.** Never move, rotate, zoom or rescale the user's view without their input; keep the horizon level; no camera shake.
- **No teleport in passthrough**, for the user or for content: it scrambles their sense of the real room.
- **Frame rate:** hold the headset's native refresh rate on the weakest device; a dropped frame here is discomfort, not jank.
- **Calm periphery:** no fast motion, flicker or bright high-contrast objects at the edges of view.
- **Depth:** text stays flat on its surface; don't make people refocus between depths often or fast.
- *Break when* experienced players choose smooth locomotion: save it as their preference.

## States

The 7 base states (`interaction-patterns.md`) plus these, each with a designed recovery:

| State | Recovery |
|---|---|
| Tracking lost | Freeze content with a short reason ("Too dark to track"); resume in place; never let it drift |
| Hands not tracked | Fade virtual hands and show the real ones; keep targets still; hint to bring hands into view |
| Anchor not found | Say so and offer "Place again" from the last spot; never respawn at the origin or lose the user's content |
| Outside the boundary | Pause anything timed; resume exactly where it was on return |
| Permission denied | Fall back to a path without the sensor (ray, manual placement); say what the permission adds and link to Settings |
| Headset removed | Pause and save; on return, resume with a one-line summary of what changed |
| Recentered; seated ↔ standing | Re-place UI in front at the current eye height; room-anchored content stays put |
| Throttled (heat, battery) | Lower detail before frame rate; say so only if a feature turns off |

## Shared space & privacy

- **Ask for each sensor at the moment of use**, with the reason, and design the "no" path.
- **Declare what the experience needs** (posture, play space, comfort level) in the store listing and at launch; handle "not enough space".

| Data | Reveals | Design rule |
|---|---|---|
| Eye tracking | Attention, interest, cognitive and health signals | Targeting only; never store or send gaze |
| Room scan | Home layout, belongings, who lives there | Keep on device; users can see and delete scans |
| Hand and body tracking | Biometrics, physical ability | Only for features that need it; process on device |
| Bystanders | Faces and voices of people who did not consent | No room capture by default; a visible indicator while capturing |

- **Shared content:** show who is present and where they point; attribute changes ("Alex moved this"); keep personal panels private; let each person navigate shared content on their own.

## Accessibility

- **Posture:** a seated mode wherever the task allows; nothing core behind the user or above the head.
- **One hand:** every core action works with either hand alone.
- **Alternative inputs:** system components let the platform's pointer, switch, dwell and voice controls work unchanged; custom gestures and direct-only interactions need an alternative.
- **Vision:** text over passthrough sits on a backing material; text scales with a user setting; legibility is checked in bright and dim rooms.
- **Hearing:** every audio cue has a visual one; captions sit near the speaker.
- **Reduced motion:** honor the platform setting: no autonomous motion; crossfades instead of flights.

## Test & measure

- On the weakest target device, never only in a simulator; with first-time XR users; in each supported posture; for the target session length.
- Discomfort: a verbal 0–10 rating every few minutes, stopping at a threshold set before the test; the Simulator Sickness Questionnaire (SSQ) before and after when comparing builds.
- The job metric against the 2D baseline (task time, errors, completion), with a frame-time log from the session.
- Record which comfort settings testers change; a default most people change is the wrong default.

## Diagnose

Severity follows the review scale in SKILL.md.

| Symptom | Check first | Default |
|---|---|---|
| Nausea, eye strain | View moved, accelerated or rolled without input; dropped frames on the weakest device; long-viewed content too close; frequent depth jumps | 🔴 |
| Bumping into furniture or people | Interaction required outside the play area; full immersion while walking | 🔴 |
| UI or alerts missed | Outside the central field; above eye level; placed for standing height while seated; head-locked toasts at the edge | 🟠 |
| Missed or accidental selections | Targets under the platform minimum or crowded; gaze used to commit; clashes with system gestures; relaxed hands read as pinches | 🟠 |
| Content gone next session | Anchor not found, with no recovery | 🟠 |
| Tired arms or neck | Frequent direct touch; targets at or above eye level; tall vertical layouts | 🟡; 🟠 on a core task |
