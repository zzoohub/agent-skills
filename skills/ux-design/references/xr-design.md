# XR Spatial Design

UX principles for spatially embodied experiences — AR, VR, and MR. The user is *inside* the interface, interacting with their body (gaze, hands, head, voice) rather than through a screen and pointer. Covers headset-native platforms (visionOS, Quest, Android XR) and WebXR.

Scope: spatial UX decisions (comfort zones, interaction models, passthrough MR, content persistence, text input, multi-user, cybersickness, onboarding, privacy). Technical implementation (renderers, APIs, frameworks) is outside this skill's scope.

## Table of Contents

1. [Core Paradigm Shift](#core-paradigm-shift)
2. [Spatial Comfort Zones](#spatial-comfort-zones)
3. [Interaction Models](#interaction-models)
4. [Text Input in XR](#text-input-in-xr)
5. [Passthrough Mixed Reality Design](#passthrough-mixed-reality-design)
6. [Content Persistence](#content-persistence)
7. [Spatial UI Patterns](#spatial-ui-patterns)
8. [Spatial Feedback](#spatial-feedback)
9. [XR Onboarding](#xr-onboarding)
10. [Multi-User / Social XR](#multi-user--social-xr)
11. [Cybersickness Prevention](#cybersickness-prevention)
12. [Spatial Information Architecture](#spatial-information-architecture)
13. [Privacy Considerations](#privacy-considerations)
14. [Platform Design Languages (2026)](#platform-design-languages-2026)
15. [Accessibility](#accessibility)
16. [When NOT to Use XR](#when-not-to-use-xr)
17. [Anti-Patterns](#anti-patterns)
18. [Validation Checklist](#validation-checklist)

---

## Core Paradigm Shift

> In 2D, you design within a frame. In 3D viewport design, the user looks *through* a window into a 3D world. In XR, the user exists *inside* the interface. The space is the canvas. The body is the input device.

### What Changes from 2D and 3D Viewport

| 2D / 3D Viewport | XR (Spatial / Embodied) |
|-------------------|-------------------------|
| Fixed viewport | Infinite canvas, limited by human vision |
| Mouse/touch pointer | Eye gaze, hand tracking, head, controllers, voice |
| Flat layout grid (or camera-viewed 3D) | Depth, distance, elevation, curvature — all physical |
| Scroll/orbit to reveal | Walk, turn, or teleport to discover |
| Hover state / raycast highlight | Gaze dwell + highlight |
| Single viewing angle | 360° potential viewing — user is surrounded |
| Pixel-based sizing | Physical-scale sizing (meters, angular degrees) |
| User sits at a desk/holds a phone | User stands, sits, moves, reaches with arms |

### What Stays the Same

These 2D fundamentals transfer directly — and matter even more:
- Cognitive load limits (Hick's Law, Miller's Law) — spatial overload is more disorienting than screen overload
- One primary action per context
- Feedback for every user action
- Consistency with platform-standard patterns
- Error prevention and recovery
- Accessibility is not optional

---

## Spatial Comfort Zones

The most critical constraint in XR. All content placement starts here.

### Horizontal Field of View

```
                    ┌─────────────────────────────────┐
                    │         IMPOSSIBLE (>50°)        │
                    ├─────────────────────────────────┤
                    │     UNCOMFORTABLE (30°–50°)      │
                    │   Neck strain, occasional use    │
                    ├─────────────────────────────────┤
                    │                                  │
                    │     COMFORTABLE (±30° center)    │
                    │   Primary content lives here     │
                    │                                  │
                    ├─────────────────────────────────┤
                    │     UNCOMFORTABLE (30°–50°)      │
                    ├─────────────────────────────────┤
                    │         IMPOSSIBLE (>50°)        │
                    └─────────────────────────────────┘
                              ← User →
```

- **±30° from center**: Comfortable. All primary content and frequent interactions.
- **30°–50°**: Straining. Occasional secondary content only.
- **>50°**: Physically impossible for most users. Never place content here.

### Vertical Field of View

- **Ideal**: Slightly above center of vision (horizon line)
- **Comfortable**: 0° to +20° above horizon
- **Acceptable**: –15° to +35° from horizon
- **Avoid**: Looking straight up or down for extended periods

### Content Distance Zones

| Distance | Zone | Use Case |
|----------|------|----------|
| <0.5m | Danger | NEVER place content here. Collision risk, eye strain. |
| 0.5–1.2m | Personal | Hand-reach tools, object manipulation, wrist-anchored UI |
| 1.25–2m | **Optimal** | Primary UI panels, menus, dashboards. DEFAULT ZONE. |
| 2–5m | Social / Reference | Shared content, presentations, environmental storytelling |
| >5m | Background | Environments, skyboxes, ambient. Not interactive. |

**Rule**: Essential interactive UI → 1.25–2m from user. Apple, Meta, and Google all converge on this range.

### Platform Default Distances

| Platform | Default Panel Distance | Vertical Offset |
|----------|----------------------|-----------------|
| visionOS | 1.5m | Slightly below eye level |
| Android XR | 1.75m | 5° below eye level |
| Meta Quest | 1.5m | Eye level |

---

## Interaction Models

### Input Modalities

| Input | Strengths | Limits | Best For |
|-------|-----------|--------|----------|
| Eye gaze + pinch | Hands-free pointing, fastest targeting | Low precision, fatigue from prolonged pinching | Menu selection, navigation, browsing |
| Hand tracking (direct) | Natural, intuitive manipulation | Arm fatigue ("gorilla arm"), occlusion | Object manipulation, sliders, close-range tools |
| Hand tracking (indirect) | Comfortable distance interaction | Less intuitive than direct | Pointing at distant content |
| Controllers | Precise, haptic feedback, buttons | Requires physical device | Gaming, precise tools, extended sessions |
| Voice | Hands-free, natural | Privacy concerns, ambient noise, latency | Commands, search, dictation, accessibility |
| Head gaze | Hands-free fallback | Imprecise, can cause neck fatigue | Accessibility fallback, coarse targeting |

### Design Rules

1. **Never rely on a single modality.** Always provide at least one fallback (gesture + voice, gaze + controller).
2. **Match modality to precision need.** Eye gaze for coarse targeting → hand for fine manipulation → voice for text input.
3. **Allow modality switching at any time.** Users should never feel locked into one input method.

### Gesture Design

**Good gestures:**
- Tap (pinch thumb + index) — familiar, low effort
- Drag — grab + move, natural physics
- Scale — two-hand pinch to resize
- Rotate — wrist twist for objects

**Bad gestures:**
- Complex multi-finger combinations (high cognitive load)
- Sustained arm-raised positions ("gorilla arm" fatigue)
- Hidden gestures with no visual affordance (undiscoverable)
- Fast, precise gestures required for core functions (error-prone)

**Rule**: Frequent interactions must be brief, simple, and achievable with minimal physical effort. Less frequent interactions can require more effort.

---

## Text Input in XR

Text input is a major pain point. No single method works well for all contexts — design for multimodal input.

### Input Methods (by throughput)

| Method | Speed | Best For | Limitations |
|--------|-------|----------|-------------|
| Physical keyboard (MR passthrough) | Highest | Long-form writing, productivity | Requires a physical keyboard nearby |
| Voice dictation | Fast | Short queries, commands, messages | Privacy, ambient noise, accuracy |
| Virtual keyboard (tap) | Moderate | Passwords, short text, search | Slower than physical, arm fatigue |
| Gaze-based keyboard | Slow | Accessibility, hands-free use | Very slow, fatigue from prolonged use |

### Design Rules

- Default to voice for short input (search, names, commands)
- Show virtual keyboard as fallback, never as the only option
- In MR, support physical keyboard passthrough — users can see and use their real keyboard
- Never require long-form text entry as a core interaction (redesign the flow if possible)
- Provide autocomplete and prediction to minimize keystrokes

---

## Passthrough Mixed Reality Design

MR (passthrough) is now the default starting mode on modern headsets — not full VR. Users see their real environment with virtual content layered on top.

### Core Principles

1. **Start in passthrough.** Users should see their room first, then virtual content appears. Dropping users into a fully virtual space is disorienting.
2. **Use real surfaces as canvas.** Place virtual content on walls, tables, and floors. It should feel like the content belongs in the room.
3. **Smooth transitions between MR and VR.** If the app supports both, fade between modes. Never cut abruptly — users lose spatial orientation.
4. **Respect the room.** Content should not clip through walls or furniture. Adapt to the physical environment.

### MR-Specific Rules

- **No teleportation in MR.** Users know where they are in their room. Teleportation conflicts with that physical awareness and is disorienting.
- **Passthrough in loading screens.** Never show a black screen while loading an MR app. Keep passthrough visible.
- **Lighting awareness.** Virtual objects should be lit consistently with the room. Mismatched lighting breaks the illusion.
- **Moderate room lighting.** Guide users: "Use in a well-lit room." Dark rooms degrade passthrough quality and tracking.
- **Persistence matters.** Virtual content placed on a surface should remain there across sessions (see Content Persistence below).

---

## Content Persistence

Modern XR platforms (visionOS 26, Quest spatial anchors) support content that persists across sessions — virtual objects stay where you put them and reappear when you return to the same space.

### Design Implications

- **Design for "installed" content, not just ephemeral windows.** Spatial widgets, dashboards, and reference panels can live in specific rooms permanently.
- **Surface-locked content.** Panels can snap to walls and tables, blending into the physical environment.
- **Room-specific layouts.** Users may want different content in their office vs. living room. Support per-room spatial arrangements.
- **Clear removal.** Users must be able to easily remove or relocate persistent content. Never leave virtual clutter in someone's space.

---

## Spatial UI Patterns

### UI Anchoring Types

| Type | Behavior | Use Case |
|------|----------|----------|
| **World-anchored** | Fixed in 3D space, stays in place | Dashboards, maps, reference panels |
| **Body-anchored** | Follows user position, stays relative to body | HUD elements, persistent controls |
| **Hand/wrist-anchored** | Attached to hand or wrist | Quick-access tools, contextual menus |
| **Gaze-anchored** | Follows gaze direction (tag-along) | Tooltips, notifications (use sparingly) |
| **Surface-anchored** | Attached to real-world surface (AR/MR) | Instructions on machines, labels on objects |

**Default**: World-anchored for primary content. Body-anchored for persistent controls.

**Anti-pattern**: Gaze-anchored UI that blocks content or feels "sticky." If UI follows gaze, add dampening (gentle follow with delay) and let users dismiss or pin it.

### Depth as Hierarchy

```
Closest to user (foreground):
  → Active controls, modals, urgent feedback
  → Sparingly — too much close content is claustrophobic

Mid-distance (primary):
  → Main content panels, workspace
  → Keep interactive content at consistent depth

Far (background):
  → Environmental context, reference content
  → Non-interactive or infrequent
```

**Rule**: Maintain interactive content at consistent depth to reduce eye refocusing strain. Subtle depth differences (not large jumps) communicate hierarchy.

### Curved UI Panels

Flat panels at wide angles create uneven viewing distances. Use curved panels to match the user's natural visual arc.
- Curve radius ≈ distance to user (panel at 2m → radius ~2m)
- Use when panels span wider than 60° of FOV
- Skip for small panels or single-action modals

### Window Management

Users may have multiple floating panels open simultaneously. Design for spatial arrangement:
- Allow users to freely position, resize, and stack panels
- Provide snap-to-grid or alignment guides for tidy arrangements
- Remember panel positions across sessions
- Don't overwhelm — start with one panel, add more on demand (progressive disclosure)

### Orbiters (Android XR Pattern)

Floating control panels anchored to the edge of a content panel — like floating action buttons in 3D. They hover ~20dp from their parent panel, separating controls from content.
- Use for contextual actions (edit, share, delete)
- Keep at the panel's edge, not floating freely in space
- Follow the parent panel when it moves

---

## Spatial Feedback

### Multisensory Feedback Model

Every interaction needs feedback across multiple channels:

| Channel | Purpose | Examples |
|---------|---------|---------|
| **Visual** | Confirm action, show state | Highlight, glow, particle effect, material change |
| **Audio** | Spatial confirmation | Sound from the interaction point, ambient cues |
| **Haptic** | Physical confirmation (controllers) | Pulse on selection, resistance on limits |

**Rule**: Audio feedback is more important in XR than on flat screens. Spatially-positioned sound confirms actions and increases presence.

### Focus States Without a Cursor

| Trigger | Response | Notes |
|---------|----------|-------|
| Eye gaze dwell (visionOS) | Subtle highlight + depth lift | Don't trigger actions on gaze alone |
| Hand ray intersection | Outline glow or material shift | Visible from interaction distance |
| Proximity (hand near object) | Object "breathes" or reacts | Direct manipulation objects only |
| Controller ray | Highlight + audio tick | Standard controller-based UI |

### State Transitions in XR

| 2D Pattern | XR Equivalent |
|------------|---------------|
| Page transition | Panel swap (dissolve or slide in z-depth) |
| Modal overlay | Panel floats forward, background dims |
| Dropdown menu | Orbiter that expands from anchor point |
| Toast notification | Spatial bubble at source + audio from that direction |
| Loading spinner | Skeleton shimmer or ambient particle |

---

## XR Onboarding

First-time XR users need spatial interaction training that 2D/3D users don't.

### Patterns

| Pattern | When | How |
|---------|------|-----|
| **Interactive tutorial** | First app launch | Teach key gestures by doing (not reading). "Pinch to select", "drag to move". |
| **Progress + skip** | Always | Show how much onboarding remains. Let users skip. |
| **Passthrough-first launch** | MR apps | Start in passthrough, then layer virtual content gradually. |
| **Contextual tooltips** | After onboarding | Just-in-time hints when users encounter new features. |
| **Device fit guidance** | First headset use | Guide physical adjustment (IPD, strap tightness) before the experience starts. |
| **Boundary setup** | Standing/room-scale | Guide users to clear their play area before starting. |

### Rules

- Teach through interaction, not text walls
- Keep onboarding under 60 seconds for consumer apps
- Always offer skip — experienced users should not be forced through tutorials
- Start in the safest mode (passthrough, seated) and let users opt into more immersive modes

---

## Multi-User / Social XR

Shared spatial experiences are now technically mature (spatial anchors, colocation APIs, SharePlay). The design challenge is making shared space intuitive.

### Colocation (Same Physical Space)

- Shared spatial anchors ensure all users see virtual content in the same physical position
- Design for **distinct roles** if applicable (presenter vs. audience, instructor vs. student)
- Show each user's position/gaze as an avatar or indicator — spatial awareness of others is critical
- Allow each user to have private UI (personal panels) alongside shared content

### Remote Presence

- Avatars or video representations placed at conversation-distance (1.5–2m)
- Spatial audio makes multi-person conversations natural — voices come from where the avatar is
- Shared content (documents, 3D models) placed between participants
- Allow independent navigation of shared content — don't force synchronized views

### Design Rules

- Never assume users are in the same physical space — support both colocation and remote
- Provide clear indicators of who is present and where they are looking/pointing
- Shared content changes need attribution ("Alex moved this panel")
- Private space must be respected — not everything should be visible to everyone

---

## Cybersickness Prevention

The #1 design failure in XR. If users feel sick, nothing else matters.

### Root Cause

Sensory mismatch between what eyes see (motion) and what the vestibular system feels (no motion). The greater the mismatch, the faster symptoms onset.

### Hard Rules (Never Violate)

1. **Never move the camera without user initiation.** No camera shake, no forced head turns, no cutscene head movement.
2. **Maintain high frame rate.** Dropped frames cause immediate discomfort.
3. **The horizon must stay stable.** If the world tilts, users feel sick.
4. **Never change field of view programmatically** without user control.

### Locomotion (Safest → Riskiest)

1. **Teleportation** (safest) — point and blink to new location. No continuous motion.
2. **Snap turning** — discrete rotation increments (30°/45°/90°). Avoids continuous rotation.
3. **Room-scale movement** (safe) — user physically walks. 1:1 motion = zero mismatch.
4. **Smooth locomotion with vignette** — reduce peripheral FOV during movement.
5. **Smooth continuous movement** (riskiest) — opt-in only for experienced users.

**Rule**: Ship teleport + snap turn as defaults. Smooth locomotion = opt-in.

**MR exception**: Never use teleportation in mixed reality passthrough mode — it conflicts with the user's physical awareness of their room.

### Comfort Settings (Must Provide)

- Locomotion mode (teleport / snap / smooth)
- Turning mode (snap angle / smooth)
- Vignette intensity during movement
- Seated / standing / room-scale toggle
- Movement speed adjustment

---

## Spatial Information Architecture

### Navigation in XR

| 2D Pattern | XR Equivalent |
|------------|---------------|
| Tab bar | Spatial tab bar (visionOS) or orbiter navigation |
| Sidebar | Detachable side panel with depth offset |
| Breadcrumb | Spatial trail or minimap |
| Back button | Gesture (swipe back) or persistent control |
| Hamburger menu | Avoid — use spatial tab bar or wrist menu |

### Content Organization

- **Spatial grouping**: Related items physically close together
- **Depth layering**: Primary content forward, secondary behind
- **Environmental zones**: Different functional areas mapped to spatial regions
- **Progressive disclosure**: Start with minimal UI, reveal more based on context

---

## Privacy Considerations

XR devices collect unprecedented amounts of sensitive data. Design with privacy as a core concern.

### Data Types at Risk

| Data | What It Reveals | Risk |
|------|----------------|------|
| Eye tracking | Attention patterns, cognitive state, emotional reactions | Can infer health conditions, interests, intent |
| Room scanning | 3D map of physical space, belongings, household composition | Exposes private environments |
| Hand/body tracking | Biometric data, physical capabilities | Uniquely identifying information |
| Bystander capture | Images/video of non-consenting third parties | Privacy violation of others |

### Design Rules

- **Granular consent.** Ask permission separately for each data type (eye tracking, room scanning, hand tracking). Never bundle consent.
- **On-device processing.** Process sensitive data (especially eye tracking) locally when possible. Minimize what leaves the device.
- **Visual indicators.** Show when cameras/sensors are active (recording indicators).
- **Bystander awareness.** Consider how non-users in the room are affected. Provide indicators that the device is capturing the environment.
- **Data deletion.** Let users delete room scans and environmental maps.
- **Minimization.** Collect only what the experience genuinely needs. If you don't need eye tracking, don't request it.

---

## Platform Design Languages (2026)

### visionOS (Apple Vision Pro)

**Core concepts**: Windows, Volumes, Full Spaces

| Container | Description | Use Case |
|-----------|-------------|----------|
| **Window** | 2D panel in 3D space (glass material) | Apps, documents, browsing |
| **Volume** | Bounded 3D content box | 3D models, data visualizations |
| **Full Space** | Immersive, single-app environment | Games, immersive experiences |

**Key design rules (visionOS 26)**:
- Use system glass material for window backgrounds (adapts to lighting, blends with environment)
- Content can be surface-locked — snapped to walls and tables, persisting across sessions
- Spatial widgets snap to physical surfaces and persist in place
- Volumetric UI: alerts and menus can appear on top of 3D volumes
- System handles chrome (close button, grab bar) — don't override
- Eye scrolling is a native interaction
- Nearby SharePlay: share apps with people in the same room, no code changes needed

### Meta Quest (Horizon OS)

**Three app paradigms:**
1. **Fully Immersive VR** — complete virtual environments
2. **Blended Mixed Reality** — passthrough with virtual content on physical surfaces
3. **2D Panel Apps** — native Android apps as floating panels

**Key design rules:**
- Controller-first interaction with hand tracking fallback
- Respect Guardian boundary — never place content beyond it
- For MR: use physical surfaces as canvas, passthrough in loading screens
- Smooth transitions between VR and MR modes (gradual opacity, not binary)
- Honestly assign comfort rating: Comfortable / Moderate / Intense

### Android XR (Samsung Galaxy XR)

**Key design rules:**
- Material Design adapted for spatial — same components, spatial elevation added
- Spatial Panels: primary container for UI, placed in user's space
- Orbiters: floating controls anchored to panel edges (~20dp distance)
- Panels launch 1.75m from the user (fixed in Home Space; the recommended default in Full Space) — size content for legibility at that distance
- Font minimum: 14dp for legibility at distance
- Eye tracking and hand tracking as primary input
- Glasses form factor (lighter eyewear with AR overlays): first Android XR glasses (Warby Parker) ship Oct 2026, other partners follow in 2027 (as of 2026-10)

---

## Accessibility

### Requirements Beyond 2D

| Concern | Requirement |
|---------|-------------|
| **Seated use** | All interactions reachable from seated position. Never require standing. |
| **One-handed use** | Core functions must work with single hand. |
| **Reduced motion** | Respect preferences. Provide static alternatives for all animations. |
| **Vision** | Minimum contrast 4.5:1 text, 3:1 UI. Distance magnifies the need. |
| **Hearing** | Never rely on spatial audio alone. Visual indicators for all audio cues. |
| **Motor** | Provide controller, voice, and gaze alternatives. No precision-dependent core functions. |
| **Cognitive** | Minimize simultaneous stimuli. Progressive disclosure is even more critical in XR. |
| **Photosensitivity** | No strobing, rapid flashing, or high-contrast flickering in peripheral vision. |

### Eye Targeting

- Minimum target area: 60×60pt (larger than 2D touch targets because eye gaze is less precise)
- Spacing: ≥8pt between targets in all directions
- Shape: Round or rounded-rectangle targets improve gaze accuracy
- Dwell time: Provide adjustable gaze dwell timers

---

## When NOT to Use XR

Stay in 2D (or 3D viewport) if:

- The task is primarily text-heavy (reading, writing, data entry)
- Speed of execution matters more than spatial understanding
- The user base lacks access to XR hardware
- The spatial dimension adds no functional value
- A 3D viewport achieves the same goal without requiring a headset

**Rule**: XR should solve a problem that a screen cannot. The embodied, spatial nature must provide genuine value — not just novelty.

---

## Anti-Patterns

| Anti-Pattern | Why It Fails | Alternative |
|-------------|-------------|-------------|
| Flat 2D screens floating in 3D space | No spatial benefit ("floating monitors") | Redesign for depth, spatial grouping, environment |
| UI behind user or requiring full body rotation | Physically demanding for core functions | Keep primary UI within ±30° FOV |
| Camera shake, forced camera motion | Cybersickness trigger | Never move camera without user initiation |
| Smooth locomotion as default | Most users feel sick | Ship teleport + snap turn as defaults |
| Gaze-triggered actions without confirmation | Accidental activation from natural looking | Require gaze + explicit confirm (pinch, dwell) |
| Too many simultaneous floating panels | Cognitive + visual overload | Start minimal, progressive disclosure |
| Content clipping through walls/furniture (MR) | Breaks spatial coherence | Respect room boundaries, adapt to environment |
| Sustained arm-raised interactions | "Gorilla arm" fatigue within minutes | Move frequent actions to comfortable zones |
| Black screen on MR app launch | Disorienting, user loses spatial context | Keep passthrough visible during loading |
| Binary passthrough on/off | Jarring transition between real and virtual | Gradual opacity transition between modes |
| Teleportation in MR passthrough | Conflicts with physical room awareness | Physical movement only in MR mode |
| Bundled privacy consent ("allow all sensors") | Users can't make informed choices | Separate consent for each data type |
| No text input alternatives | Users struggle with any single input method | Multimodal: voice + virtual keyboard + physical keyboard |
| Building XR for novelty | 3D for 3D's sake, no functional benefit | Only use XR when it solves a problem 2D cannot |

---

## Validation Checklist

### Comfort & Safety
- [ ] All interactive content within 1.25–2m comfort zone
- [ ] Primary content within ±30° horizontal FOV
- [ ] No camera movement without user initiation
- [ ] Horizon stays stable — no world tilt
- [ ] Comfort settings provided (locomotion, turning, seated mode)
- [ ] Comfort rating honestly assigned

### Input & Interaction
- [ ] At least 2 input modalities for all core functions
- [ ] Gestures are simple, brief, and low-effort for frequent actions
- [ ] No sustained arm-raised positions for core tasks
- [ ] Modality switching possible at any time
- [ ] Eye-gaze targets ≥60pt with ≥8pt spacing

### Text Input
- [ ] Voice input available for short text
- [ ] Virtual keyboard available as fallback
- [ ] Physical keyboard passthrough supported in MR
- [ ] No core flows require long-form text entry

### Spatial UI
- [ ] UI anchoring type appropriate for each element
- [ ] Curved panels for content wider than 60° FOV
- [ ] Depth used consistently for hierarchy (no large random jumps)
- [ ] Audio feedback from spatial position of interaction
- [ ] Window management supports positioning, resizing, and persistence

### Mixed Reality (if applicable)
- [ ] App starts in passthrough (not black screen)
- [ ] Virtual content placed on real surfaces
- [ ] Transitions between MR/VR are gradual (not abrupt)
- [ ] No teleportation in passthrough mode
- [ ] Content adapts to room boundaries

### Content Persistence (if applicable)
- [ ] Placed content persists across sessions
- [ ] Users can easily remove or relocate persistent content
- [ ] Different rooms can have different layouts

### Multi-User (if applicable)
- [ ] Clear indicators of who is present and where they're looking
- [ ] Private and shared content clearly distinguished
- [ ] Shared content changes attributed to specific users
- [ ] Works for both colocation and remote scenarios

### Privacy
- [ ] Granular consent per data type (eye tracking, room scanning, etc.)
- [ ] Active sensor indicators visible to user
- [ ] Data deletion controls available
- [ ] Only necessary data collected

### Onboarding
- [ ] First-time users taught key gestures through interaction (not text)
- [ ] Onboarding is skippable
- [ ] Under 60 seconds for consumer apps
- [ ] Device fit guidance provided before experience starts

### Platform
- [ ] Tested in-headset (not simulator only)
- [ ] Tested seated AND standing
- [ ] Platform design language followed (visionOS glass, Quest panels, Android XR Material)
- [ ] Content doesn't extend past physical room boundaries (MR)

### Accessibility
- [ ] All interactions reachable from seated position
- [ ] Core functions work with one hand
- [ ] Reduced-motion preferences respected
- [ ] Visual indicators for all audio cues
- [ ] No precision-dependent core functions
- [ ] No strobing or flickering in peripheral vision
