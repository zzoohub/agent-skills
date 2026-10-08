---
title: Keep Scroll, Pointer and Resize Values Out of React State
tags: rerender, useRef, scroll, pointer, passive-listeners
---

Scroll, pointer, resize and per-frame values change dozens of times a second; storing them in state re-renders the subtree on every event. Decide by what the value drives:

| The value drives | Use |
|---|---|
| Nothing rendered (last position, velocity) | A ref |
| A style (position, transform) | A ref plus a `requestAnimationFrame` write, or CSS (`position: sticky`; scroll-driven animations where supported) |
| A threshold (past the header, in view) | An IntersectionObserver, or a `matchMedia` boolean through `useSyncExternalStore`; it changes rarely |
| Layout by viewport size | CSS media or container queries, no JavaScript |

**Incorrect:** `setX(e.clientX)` in a `pointermove` listener, rendered as `style={{ transform: ... }}`: the subtree re-renders on every move.

**Correct (no re-render; at most one write per frame):**

```tsx
const dot = useRef<HTMLDivElement>(null)
useEffect(() => {
  let frame = 0
  const onMove = (e: PointerEvent) => {
    cancelAnimationFrame(frame)
    frame = requestAnimationFrame(() => {
      if (dot.current) dot.current.style.transform = `translateX(${e.clientX}px)`
    })
  }
  window.addEventListener('pointermove', onMove)
  return () => { cancelAnimationFrame(frame); window.removeEventListener('pointermove', onMove) }
}, [])
return <div ref={dot} className="dot" />
```

**Passive listeners:** `wheel`, `touchstart` and `touchmove` listeners on `window`, `document` and `body` are already passive; pass `{ passive: true }` on other scroll containers. React's `onWheel`, `onTouchStart` and `onTouchMove` props are passive too, so `preventDefault()` in them does nothing; to cancel scrolling for a custom gesture, add a native listener with `{ passive: false }` through a ref.

Sources: https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener · https://github.com/facebook/react/pull/19654
