# {Experience} — Spatial UX [{release}]

**Class:** {object | configurator | space | map/data | editor | narrative | phone AR | headset | glasses} · **Devices:** {weakest first, each with its input} · **Entry:** {route or launch point}

<!-- Rules for the writer; leave them out of the file.
- Budget, tables included: ≈900 words; ≈500 as a section of an existing screen's file (headings one level down). Sections are a menu: omit what doesn't apply, heading included, except States and Test & measure.
- Defaults when no one can answer (record each as A-nn): the PRD's devices, else a mid-range phone browser; seated, stationary, short sessions; mostly first-time users.
- Sizes are angles, or sizes at a stated distance; platform numbers cite their guideline and the date checked.
- Defaults and recoveries live in the 3D and XR references: write only this experience's choices and deviations. -->

## 1. Job & baseline

The task 3D/XR improves, the 2D baseline it must beat, and the metric. No gain → recommend 2D and stop.

## 2. Context

Posture, space, session length, bystanders, share of first-time users; each sensor used, why, and the path without it.

## 3. Experience ladder

3D: fallback → inline → AR or immersive. XR: the immersion rungs in `references/xr-design.md`. What each level ships, and how people enter and leave it.

## 4. Camera (3D) or Placement & anchoring (XR)

3D: camera model, default view, limits, reset. XR, per element: distance, angle from eye level, anchoring, scale.

## 5. Input map

| Action | {Device} | {Device} | Alternative |
|---|---|---|---|

Conflicts with page scroll or system gestures, and how each resolves.

## 6. Comfort

Locomotion, or none; motion the user didn't start (none, or idle motion that stops on input); the reduced-motion variant; the frame-rate floor on the weakest device.

## 7. States

The base states that apply, plus each spatial state that can occur, with its recovery. 3D: unavailable, asset failed, graphics context lost, throttled. XR: tracking lost, hands not tracked, anchor not found, outside the boundary, permission denied, headset removed, recentered, throttled.

## 8. Accessibility

A text equivalent of what the 3D shows; single-pointer and keyboard paths; posture and one-hand alternatives; visual cues for audio.

## 9. Test & measure

Weakest device, first-time users, target session length; a discomfort rating with its stop threshold; the job metric against the baseline.

<!-- Self-check before presenting: metric and baseline named; sizes as angles or at stated distances; XR frequent content within about ±20° of forward, nothing long-viewed above eye level, reading content at least 1 m away; no view motion the user didn't start (idle motion stops on input), and a reduced-motion variant; each action mapped per target device, with a single-pointer or keyboard path; no scroll or system-gesture clash; gaze never confirms; every state recovers; tested on the weakest device with first-time users and a stop rule; platform numbers dated; within budget. -->
