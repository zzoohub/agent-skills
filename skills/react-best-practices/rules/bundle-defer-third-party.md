---
title: Defer Non-Critical Third-Party Libraries
impact: MEDIUM
impactDescription: loads after hydration
tags: bundle, third-party, analytics, defer
---

## Defer Non-Critical Third-Party Libraries

Analytics, logging, and error tracking don't block user interaction. Load them after hydration.

**Incorrect (blocks initial bundle):**

```tsx
import { Analytics } from 'your-analytics-sdk/react'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  )
}
```

**Correct (loads after hydration):**

In the App Router, `next/dynamic` with `{ ssr: false }` is not allowed in a Server Component (the root layout is one) and throws an error, so put the dynamic call in a small `'use client'` wrapper and render that from the layout:

```tsx
// app/deferred-analytics.tsx
'use client'

import dynamic from 'next/dynamic'

export const DeferredAnalytics = dynamic(
  () => import('your-analytics-sdk/react').then(m => m.Analytics),
  { ssr: false }
)
```

```tsx
// app/layout.tsx (Server Component)
import { DeferredAnalytics } from './deferred-analytics'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <DeferredAnalytics />
      </body>
    </html>
  )
}
```

Reference: [Next.js lazy loading — skipping SSR](https://nextjs.org/docs/app/guides/lazy-loading)
