---
title: Don't Define Components Inside Components
tags: rerender, components, remount, keys
---

React matches elements by type and key. A component defined inside another is a new type on every render, so React unmounts the old instance and mounts a new one: state is lost, Effects re-run and DOM nodes are recreated. An unstable `key` does the same (`key={Math.random()}`, or a key built from values that change each render); keys come from the data's identity, such as `item.id`.

**Incorrect (remounts on every render):**

```tsx
function UserProfile({ user, theme }: Props) {
  const Avatar = () => <img src={user.avatarUrl} className={`avatar-${theme}`} />   // a new type each render
  return <div><Avatar /><Stats user={user} /></div>
}
```

**Correct:** define `Avatar` at module scope and pass what it reads as props: `<Avatar src={user.avatarUrl} theme={theme} />`.

Symptoms: an input loses focus on every keystroke, animations restart, Effects clean up and re-run on every parent render, scroll position resets.
