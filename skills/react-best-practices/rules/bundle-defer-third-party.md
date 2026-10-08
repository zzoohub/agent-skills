---
title: Load Third-Party Scripts by When Their Job Starts
tags: bundle, third-party, scripts, analytics, error-tracking
---

A third-party script in the initial bundle, or a parser-blocking `<script>`, competes with LCP and hydration, and its long tasks during input hurt INP.

- **Error tracking:** load it early, or a small stub that buffers errors until the SDK arrives. Errors during load and hydration are the ones you most need.
- **Analytics, chat and feedback widgets:** after hydration, or on idle.
- **A/B tests that change what renders:** assign the variant on the server; a client script that must run before paint costs LCP and flickers.
- **Plain tags:** `async` for independent scripts, `defer` for scripts that need the DOM or run in order; never a bare `<script src>` in `<head>`.
- **Next.js:** `next/script` with `afterInteractive` (the default) or `lazyOnload`; `beforeInteractive` only in the root layout, for critical site-wide scripts.

**Incorrect:** importing the analytics SDK's component into the root layout, which puts it in the initial bundle.

**Correct (Next.js App Router):** `ssr: false` is not allowed in a Server Component such as the root layout, so wrap the dynamic import in a client file.

```tsx
// app/deferred-analytics.tsx
'use client'
import dynamic from 'next/dynamic'

export const DeferredAnalytics = dynamic(
  () => import('your-analytics-sdk/react').then(m => m.Analytics),
  { ssr: false },
)
// app/layout.tsx renders <DeferredAnalytics /> inside <body>
```

Outside Next.js, render the SDK's component lazily once the app has mounted.

Sources: https://nextjs.org/docs/app/api-reference/components/script · https://nextjs.org/docs/app/guides/lazy-loading
