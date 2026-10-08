---
title: Use Effects Only to Synchronize with External Systems
tags: effects, useEffect, derived-state, events, subscriptions
---

An Effect runs after React commits and again whenever its dependencies change. Used for anything except synchronizing with an external system, it adds a render, lets state drift and repeats actions. Classify the need before writing `useEffect`:

| Need | Where it goes |
|---|---|
| A value computed from props or state | Render ([rerender-memo](./rerender-memo.md) only if it costs ≥ 1 ms) |
| A response to a user action | The event handler |
| Resetting state when a prop changes | A `key` on the component |
| An external store with a current value (media query, online status, a held modifier key) | `useSyncExternalStore`, one module-level subscription per source |
| App data | The route loader, a Server Component or the installed query library |
| One-time app init | Module scope, or a module-level `didInit` guard |
| An external system (socket, widget, DOM API, global shortcuts through one shared listener) | An Effect with cleanup and primitive deps (`user.id`, not `user`), one Effect per concern |

Strict Mode runs each Effect's setup and cleanup an extra time in development, during hydration too on React 19.3+; code that breaks under it is missing a cleanup.

Render loops: "Too many re-renders" means a setter runs during render (`onClick={setOpen(true)}` calls it; pass `() => setOpen(true)`). "Maximum update depth exceeded" means an Effect sets state it depends on, often through an object or function dependency recreated every render: derive the value, or depend on primitives.

**Incorrect (derived state in an Effect):** `useEffect(() => setFullName(first + ' ' + last), [first, last])`. **Correct:** `const fullName = first + ' ' + last`.

**Incorrect (an action modeled as state plus an Effect; it also re-fires when `theme` changes):**

```tsx
const [submitted, setSubmitted] = useState(false)
useEffect(() => {
  if (submitted) { post('/api/register'); showToast('Registered', theme) }
}, [submitted, theme])
return <button onClick={() => setSubmitted(true)}>Submit</button>
```

**Correct:**

```tsx
function handleSubmit() {
  post('/api/register')
  showToast('Registered', theme)
}
return <button onClick={handleSubmit}>Submit</button>
```

Sources: https://react.dev/learn/you-might-not-need-an-effect · https://react.dev/blog/2026/09/09/react-19-3
