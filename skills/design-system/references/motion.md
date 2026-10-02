# Motion Tokens

## Values

```json
{
  "duration": {
    "instant": { "$value": "100ms", "$type": "duration" },
    "fast":    { "$value": "200ms", "$type": "duration" },
    "normal":  { "$value": "300ms", "$type": "duration" },
    "slow":    { "$value": "500ms", "$type": "duration" }
  },
  "easing": {
    "default": { "$value": "cubic-bezier(0.4, 0, 0.2, 1)", "$type": "cubicBezier" },
    "enter":   { "$value": "cubic-bezier(0, 0, 0.2, 1)",   "$type": "cubicBezier" },
    "exit":    { "$value": "cubic-bezier(0.4, 0, 1, 1)",    "$type": "cubicBezier" },
    "spring":  { "$value": "cubic-bezier(0.175, 0.885, 0.32, 1.275)", "$type": "cubicBezier" }
  }
}
```

## When to Use What

| Duration | Easing | Use Case |
|----------|--------|----------|
| `instant` | `default` | Toggle, checkbox, radio, switch |
| `fast` | `default` | Hover states, tooltips, color changes |
| `fast` | `enter` | Small elements appearing (badge, dot) |
| `normal` | `enter` | Modals opening, drawers sliding in, dropdown menus |
| `normal` | `exit` | Modals closing, elements dismissing |
| `normal` | `spring` | Playful bounces (use sparingly) |
| `slow` | `enter` | Page transitions, complex choreography |

## Reduced Motion

Non-negotiable. `prefers-reduced-motion: reduce` → skip animation entirely, don't just shorten duration.

Platform-specific implementation lives in this skill's platform references: the CSS `@media (prefers-reduced-motion: reduce)` reset in `references/platform-web.md`, and `AccessibilityInfo.isReduceMotionEnabled()` (plus the `reduceMotionChanged` listener) in `references/react-native/platform.md`. (both also linked directly from SKILL.md)

## Implementation Rules

Engine-agnostic rules for any animation that consumes these tokens (scroll reveals, parallax, gestures, page transitions):

- **Reduced motion renders the final state.** Skip the animation and jump to the end state; never "fake" it by speeding up — a 100x flash still triggers vestibular issues. Listen for live OS-setting changes, not a one-shot check.
- **One animation engine per surface.** Never animate the same property on the same element with two engines — they fight and flicker. Choose per component.
- **Animate `transform` and `opacity` only.** They stay on the compositor; animating layout properties causes layout shift (CLS) and input jank.
- **Never server-render content at `opacity: 0`.** Content must be fully visible without JS — animation enhances, never gates content.
- **Tear down on unmount.** Kill timelines, scroll triggers, and scroll/gesture listeners when their component or element goes away.
- **Scroll smoothing (e.g. Lenis) only at the app root, never nested** — and only where the feel earns it (marketing/portfolio), not on blogs, docs, or dashboards.
- **Every gesture needs a non-gesture fallback** (a visible button or tap target) so the action stays reachable for assistive tech.

## Principle

Animation should communicate, not decorate. If removing an animation makes the interaction confusing (modal appearing from nowhere), keep it. If it's purely aesthetic (background shimmer), make it optional.
