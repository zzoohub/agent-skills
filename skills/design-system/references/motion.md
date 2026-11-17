# Motion

## Tokens

| Token | Value | Use |
|---|---|---|
| `duration.instant` | 100ms | Toggles, checkboxes, switch thumbs |
| `duration.fast` | 200ms | Hover, color and opacity, tooltips, exits. The default for every transition |
| `duration.normal` | 300ms | Dialogs, drawers and menus arriving; page transitions |
| `motion.distance` | 1rem, and 0 under reduced motion | How far a thing slides in |
| `motion.scale` | 0.96, and 1 under reduced motion | How small a thing starts |

Easings are the engine's three: `ease-out` for what arrives (it decelerates), `ease-in` for what leaves, `ease-in-out` for a change in place. React Native writes the same curves as `Easing.bezier(0, 0, 0.2, 1)`, `(0.4, 0, 1, 1)` and `(0.4, 0, 0.2, 1)`. Exits run one step shorter than their entrance, because the user has already decided. Page transitions stay at `normal`, because input waits for them. One distance and one scale for the whole product is the point: motion is a vocabulary too.

## Reduced motion

The policy: remove translation, rotation, scaling, parallax, blur and scroll-linked or autoplaying movement; keep color and opacity changes, spinners and progress. It follows WCAG's definition of motion, where movement and size changes count and color changes do not.

The mechanism is the two motion tokens. An animation built on them needs no reduced-motion branch of its own:

```css
/* In tokens.css: the whole policy */
@media (prefers-reduced-motion: reduce) {
  :root {
    --ds-motion-distance: 0rem;
    --ds-motion-scale: 1;
  }
}

/* Anywhere: a slide that becomes a fade by itself */
@keyframes toast-in {
  from {
    opacity: 0;
    translate: 0 var(--ds-motion-distance);
  }
}
.toast[data-open] {
  animation: toast-in var(--ds-duration-normal) ease-out;
}
```

A global `* { animation: none; transition: none }` reset is the common shortcut and the wrong one: it removes the fades the policy keeps, and it freezes every spinner, so a loading app looks hung. Smooth scrolling is movement too: turn `scroll-behavior` back to `auto` in the same media query if the app sets it. React Native: `react-native.md`.

## Rules

- **Motion explains a change, or it is optional.** Keep motion that shows where something came from or went. Decorative motion (a shimmer, a drifting background) can be turned off.
- **Animate `transform` and `opacity`.** They stay on the compositor; layout properties shift the page and make input stutter. Two breaks: a one-shot expand or collapse may animate height (`grid-template-rows: 0fr → 1fr`, or a measured FLIP), never on scroll or a gesture; a brief blur on a view-transition snapshot is fine.
- **A theme change is not an animation.** Turn transitions off for the frame in which the theme attribute changes (`examples.md` § Theme at first paint), or every element with a color transition fades while the page around it jumps.
- **Overlays animate through the headless library's state attributes,** which keep the element mounted until its exit ends (`stack.md`). Prefer transitions to keyframes there: a transition reverses smoothly when the user closes a popup that is still opening.
- **Never server-render content at `opacity: 0`.** Content is visible without JavaScript; animation adds to it and never gates it.
- **One animation engine per element.** Two engines driving one property fight and flicker.
- **Honor the setting live.** Re-read reduced motion when it changes; never check it once.
- **Tear down on unmount:** timelines, scroll triggers, scroll and gesture listeners.
- **Every gesture has a path without it:** a visible button or tap target that does the same thing.
- **Scroll smoothing lives at the app root only,** never nested, and only where the feel earns it (a marketing page), never on docs or dashboards.

## React `<ViewTransition>`

Checked 2026-11-06 on Next.js 16.4; re-check against the installed version's docs.

It is for DOM that gets replaced (a route change, a shared element), not for hover or open and close. It freezes the screen and blocks input while it runs, so keep it rare.

- It fires only inside a Transition, and enter and exit also need it to come before any DOM node.
- A page wrapper sits above the page's Suspense, never in a layout. Use `default="none"`, then name each trigger.
- In Next.js (through 16.4) back and forward don't animate, whatever its guide says. Skip the guide's `::view-transition { pointer-events: none }`: clicks would pass through moving snapshots.
- A `*` reset does not reach its pseudo-elements. Under reduced motion, `::view-transition-group(*) { animation-name: none !important; }` stops morphs from travelling and keeps the cross-fade; slides take their distance from `--ds-motion-distance`.
