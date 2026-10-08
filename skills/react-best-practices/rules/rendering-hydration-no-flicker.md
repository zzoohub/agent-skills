---
title: Make the First Client Render Match the Server Render
tags: rendering, ssr, hydration, theme, storage, timezone
---

Hydration assumes the first client render matches the server HTML. React doesn't promise to patch mismatches, so one can leave wrong UI on screen. For each value that can differ, ask who can know it:

- **The server** (theme, locale, auth, flags): keep it in a cookie or the session and render it on the server. Auth state never comes from storage. *Break:* a statically generated page can't read cookies.
- **The browser, at first paint** (a stored theme): the installed theme library, or a blocking inline script in the root layout's `<head>` that sets a class on `<html>`, with `suppressHydrationWarning` on `<html>` only. Only server-rendered HTML runs the script; an inline `<script>` React renders on the client never runs.
- **The browser, in a subtree:** on React 19.3+, `use(browser())` (from `react-dom`) in a Client Component inside `<Suspense>`: the server sends the fallback and the client renders the value. Earlier: `useSyncExternalStore` with a `getServerSnapshot`, or a client-only boundary.
- **Ids:** `useId`, never random values. **Dates and numbers:** an explicit `timeZone` and locale. Suppress a text mismatch (`suppressHydrationWarning` on that element) only when showing the server's value until the next render is acceptable.
- **Storage:** versioned keys, minimal non-sensitive fields, try/catch around every access (`SecurityError` when storage is blocked, a quota error on write).

**Incorrect (throws during SSR; moved into an Effect, it flashes the default):**

```tsx
function ThemeWrapper({ children }: { children: ReactNode }) {
  const theme = localStorage.getItem('theme') ?? 'light'
  return <div className={theme}>{children}</div>
}
```

**Correct (React 19.3+, a subtree that needs storage):**

```tsx
'use client'
function SavedDraft() {
  use(browser())                                         // server: stop here and send the fallback
  const [draft, setDraft] = useState(() => readDraft())   // readDraft: try/catch around localStorage
  return <textarea value={draft} onChange={e => setDraft(e.target.value)} />
}
// <Suspense fallback={<DraftSkeleton />}><SavedDraft /></Suspense>
```

Mismatch checklist: a browser-only read during render (`window`, storage, `Date.now()`, `Math.random()`), invalid HTML nesting (`<div>` inside `<p>`), time-zone or locale formatting and sorting (pass both explicitly), browser extensions that edit the DOM.

Sources: https://react.dev/reference/react-dom/client/hydrateRoot · https://react.dev/reference/react-dom/browser
