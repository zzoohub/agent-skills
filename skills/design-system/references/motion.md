# Motion

## Tokens

| Token | Value | Use |
|---|---|---|
| `duration.instant` | 100ms | toggles, checkboxes, switch thumbs |
| `duration.fast` | 200ms | hover, color and opacity, tooltips, exits |
| `duration.normal` | 300ms | modals, drawers and menus entering; page transitions |
| `duration.slow` | 500ms | complex choreography and emphasis only |
| `easing.default` | `[0.4, 0, 0.2, 1]` | state changes in place |
| `easing.enter` | `[0, 0, 0.2, 1]` | elements arriving (decelerate) |
| `easing.exit` | `[0.4, 0, 1, 1]` | elements leaving (accelerate) |
| `easing.overshoot` | `[0.175, 0.885, 0.32, 1.275]` | playful emphasis, sparingly; never on exits |

Easings are cubic-bezier control points: CSS gets `cubic-bezier(…)`, React Native `Easing.bezier(…)`. Exits run one step shorter than their entrance (enter `normal`, leave `fast`): the user has already decided. Page transitions stay at `normal`, because input waits for them.

## Reduced Motion

SKILL.md § Motion states the policy for every platform and engine. Its basis is WCAG's definition of motion: movement and size changes count, color and opacity changes do not, and an erratum now counts blur.

Implement it in tokens: distances scale by a multiplier that drops to 0, so the same keyframes become a fade.

```css
:root { --ds-motion-distance: 1; }
@media (prefers-reduced-motion: reduce) {
  :root { --ds-motion-distance: 0; }
  html { scroll-behavior: auto; }
}
.toast[data-open] { animation: toast-in var(--ds-duration-normal) var(--ds-easing-enter); }
@keyframes toast-in {
  from { opacity: 0; translate: 0 calc(var(--ds-motion-distance) * 16px); }
}
```

A global `*` reset instead kills the fades the policy keeps, and with `animation-iteration-count: 1` it freezes every spinner, so a loading app looks hung. View transitions need their own rule (the react-view-transitions capability, if available, ships one); React Native: `react-native/platform.md`.

## Implementation Rules

For any animation consuming these tokens:

- **Honor reduced motion live:** re-read the setting when it changes, never a one-shot check.
- **One animation engine per surface.** Two engines animating one property on one element fight and flicker.
- **Animate `transform` and `opacity`.** They stay on the compositor; layout properties cause layout shift and input jank. Breaks: a one-shot expand or collapse (accordion, disclosure) may animate height via `grid-template-rows: 0fr → 1fr` or a measured FLIP, never on scroll or gestures; a brief blur on view-transition morph snapshots is fine.
- **Overlays animate through the library's state attributes,** which hold the unmount until the exit ends: Base UI `data-starting-style`/`data-ending-style`, Radix `data-state` (keyframes only; a transition is cut), React Aria `data-entering`/`data-exiting`. A native `<dialog>` or `popover` needs `@starting-style` for entry, and `display` plus `overlay` in its transition with `allow-discrete`, or the exit is cut.
- **Never server-render content at `opacity: 0`.** Content must be fully visible without JS; animation enhances, never gates.
- **Tear down on unmount:** timelines, scroll triggers, scroll and gesture listeners.
- **Scroll smoothing (e.g. Lenis) only at the app root, never nested**, and only where the feel earns it (marketing, portfolio), never on docs or dashboards.
- **Every gesture needs a non-gesture path** (a visible button or tap target) so the action stays reachable for assistive tech.
- **Motion explains a change, or it is optional.** Keep motion that shows where something came from; make decorative motion (a background shimmer) optional.
