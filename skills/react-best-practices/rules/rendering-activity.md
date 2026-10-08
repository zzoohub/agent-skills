---
title: Preserve Toggled UI with Activity
tags: rendering, activity, visibility, state-preservation
---

`<Activity>` (React 19.2+) hides a subtree without unmounting it, so its state and DOM survive while hidden. Use it for expensive tabs, panels or menus that users switch back to often.

```tsx
import { Activity } from 'react'

function Tabs({ tab }: { tab: 'feed' | 'settings' }) {
  return (
    <>
      <Activity mode={tab === 'feed' ? 'visible' : 'hidden'}><Feed /></Activity>
      <Activity mode={tab === 'settings' ? 'visible' : 'hidden'}><Settings /></Activity>
    </>
  )
}
```

While hidden, the subtree's Effects are cleaned up and its updates are deferred; the Effects run again when it becomes visible. Anything that must stop while hidden (media playback, timers) belongs in an Effect with a cleanup.

*Break:* hidden trees keep their DOM and memory. Don't keep many heavy or rarely revisited panels alive; unmount those.

Source: https://react.dev/reference/react/Activity
