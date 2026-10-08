---
title: Read Latest Values in Effects with useEffectEvent
tags: effects, useEffectEvent, refs, dependencies
---

When an Effect calls a callback or reads a value it shouldn't re-run for, listing it as a dependency re-subscribes on every change, and leaving it out reads a stale value. `useEffectEvent` (React 19.2+; 19.3+ inside `memo` and `forwardRef` components) returns a function that always sees the latest props and state.

Its identity changes on every render by design: never put it in a dependency array, pass it to another component or hook, or call it during render. Call it only from Effects and the subscriptions they create.

**Incorrect:** subscribing with `c.on('connected', onConnected)` and listing `[roomId, onConnected]` as deps; a parent passing an inline callback reconnects on every render.

**Correct (19.2+):**

```tsx
const onConnectedEvent = useEffectEvent(onConnected)
useEffect(() => {
  const c = createConnection(roomId)
  c.on('connected', onConnectedEvent)
  c.connect()
  return () => c.disconnect()
}, [roomId])
```

**Below 19.2 (a ref updated after each render):**

```tsx
const latest = useRef(onConnected)
useEffect(() => { latest.current = onConnected })
useEffect(() => {
  const c = createConnection(roomId)
  c.on('connected', () => latest.current())
  c.connect()
  return () => c.disconnect()
}, [roomId])
```

Sources: https://react.dev/reference/react/useEffectEvent · https://react.dev/blog/2026/09/09/react-19-3
