---
title: Start Critical Fetches Early with Resource Hints
tags: rendering, preload, preconnect, lcp, resource-hints
---

The browser finds a resource late when only CSS, JavaScript or a post-hydration render references it. React DOM's hint APIs emit `<link>` tags during render, so the fetch starts with the HTML. Hint only what the first view needs, starting with the LCP resource: every extra preload competes for bandwidth.

`prefetchDNS` and `preconnect` warm an origin; `preload(href, { as })` fetches a file the page needs; `preloadModule(href, { as: 'script' })` requires its `as`; `preinit` and `preinitModule` also execute a script or apply a stylesheet, and a stylesheet passed to `preinit` needs a `precedence`.

```tsx
import { preconnect, preload, preinit } from 'react-dom'

function RootDocument({ children }: { children: React.ReactNode }) {   // outside Next.js; see below
  preconnect('https://api.example.com')
  preload('/fonts/inter.woff2', { as: 'font', type: 'font/woff2', crossOrigin: 'anonymous' })
  preinit('/styles/critical.css', { as: 'style', precedence: 'high' })
  return <html><body>{children}</body></html>
}
```

Give the LCP image `fetchPriority="high"` and never `loading="lazy"`. In Next.js, `next/image` is lazy by default, so give the LCP image `fetchPriority="high"` or `loading="eager"` (`priority` is deprecated since 16); load fonts with `next/font`, which preloads them and sizes the fallback, not a manual `preload`. For the next route's code, use the router's prefetch on intent (Next's `<Link>` prefetching, TanStack Router's `defaultPreload: 'intent'`) instead of hand-written chunk paths, which are hashed in production.

*Break:* don't preload what the HTML already references early; the preload scanner finds it.

Sources: https://react.dev/reference/react-dom#resource-preloading-apis · https://react.dev/reference/react-dom/preloadModule · https://nextjs.org/docs/app/api-reference/components/image
