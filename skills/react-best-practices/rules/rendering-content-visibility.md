---
title: Scale Long Lists with content-visibility, Then Virtualization
tags: rendering, css, content-visibility, long-lists, virtualization
---

`content-visibility: auto` lets the browser skip style, layout and paint for off-screen items. It doesn't reduce React's render work or the number of DOM nodes. `contain-intrinsic-size: auto 80px` reserves an estimated height, then remembers each item's real one, so the scrollbar doesn't jump.

| List | Do |
|---|---|
| Up to ~200 simple rows | Nothing |
| Hundreds of heavy rows | `content-visibility: auto` |
| Thousands of rows, or unbounded | Paginate or virtualize |

Treat these as starting points and confirm in the Performance panel under CPU throttling.

```css
.message-item {
  content-visibility: auto;
  contain-intrinsic-size: auto 80px;
}
```

*Break:* items skipped by `content-visibility` stay in the DOM and the accessibility tree, so find-in-page, anchors and crawlers still reach them; virtualized rows don't. Prefer it until the row count forces virtualization.

Source: https://web.dev/articles/content-visibility
