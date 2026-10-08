# View transitions in Next.js (App Router)

## Setup by version

Read the installed version (`npm ls next`, or the lockfile; on a canary, check the API: `grep -rl transitionTypes node_modules/next/dist`) and build within it. Leave `package.json`, the lockfile and `next.config.*` alone unless the request asks: an upgrade or a stale flag goes in the report as a proposal, with the exact change and what it buys.

- **16.2+:** the App Router bundles a React canary that exports `<ViewTransition>`: install no React runtime (`npm ls react` showing a stable version is expected). Type links with `<Link transitionTypes>` and pushes with `router.push/replace(href, { transitionTypes })`. A leftover `experimental.viewTransition` is inert (nothing read it in 16.x; 16.3 dropped it from the config schema): leave it and list it as removable.
- **16.0–16.1:** `<ViewTransition>` works without config, but `transitionTypes` doesn't exist yet: type links through `onNavigate` (below). Typed links alone don't justify an upgrade; mention 16.2 as an option.
- **15.x:** only behind `experimental.viewTransition`, which switches the app to experimental React and its `unstable_` exports (`unstable_ViewTransition`, `unstable_addTransitionType`). If the flag is on, build with those and `onNavigate` (15.3+); if not, don't add it: propose the flag or the upgrade with its risk (experimental React in production) and ask.

## Typed links and programmatic navigation

16.2+:

```tsx
<Link href={`/photo/${id}`} transitionTypes={['nav-forward']}>Open</Link>
<button onClick={() => router.push(href, { transitionTypes: ['nav-forward'] })}>Next</button> {/* router = useRouter() */}
```

`router.push` and `router.replace` start their own Transition, so `router.replace('?sort=price', { transitionTypes: ['list-change'] })` re-sorts a server-rendered list with its gated items gliding, no wrapper needed. `<ViewTransition>` and `<Link transitionTypes>` work in Server Components; `addTransitionType`, `startTransition`, `useRouter` and `onNavigate` need a Client Component.

Before 16.2, or when the push must first wait for its destination (`patterns.md` § Wait for the destination), take the push over in `onNavigate`. It runs only for client-side navigations, so the link keeps its `href`, prefetching, and Cmd/Ctrl-click to a new tab:

```tsx
'use client';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { startTransition, addTransitionType } from 'react';

type Props = Omit<React.ComponentProps<typeof Link>, 'href'> & { href: string; type: string };

export function TypedLink({ href, type, replace, scroll, ...props }: Props) {
  const router = useRouter();
  return (
    <Link href={href} replace={replace} scroll={scroll} {...props}
      onNavigate={(e) => {
        e.preventDefault(); // cancels only Link's own push
        startTransition(() => {
          addTransitionType(type);
          if (replace) router.replace(href, { scroll });
          else router.push(href, { scroll });
        });
      }} />
  );
}
```

A wait goes inside this Transition, before the push, guarded as in `patterns.md`. For a pending cue around it, take `startTransition` from `useTransition` and show `isPending`.

## Back and forward

Back and forward commit unanimated, morphs included, whatever the Next.js guide says: through 16.4 the App Router runs them in a `popstate` listener, and React renders `popstate` updates synchronously with view transitions off. For an animated return, see SKILL.md "Back vs up".

## Layouts

Layouts persist across navigations, so enter/exit never fire there: put `DirectionalTransition` in each page, or in the segment's `template.tsx` (§ `loading.tsx`). A layout VT around `{children}` doesn't block page VTs, but a bare one cross-fades whenever a navigation resizes it; give it `default="none"` or remove it.

## Readiness for morphs

A pair forms only when the destination renders in the navigation's own commit with its image painted.

- **Data.** With the default `prefetch`, a dynamic route prefetches only down to its nearest `loading.js`, so the navigation commits that loading state first: no pair forms, and the content arrives with its reveal. `prefetch={true}` on the morphing links fetches each visible link's full route, a server and bandwidth cost on a large grid to report; with `partialPrefetching` on, it carries only the App Shell and cached content, so the morphing element's data must be cached too. Otherwise a pair forms only if the navigation waits for the server (no `loading.js` above the morphing element): the click then shows nothing until the data arrives, so report the wait and add a pending cue (`useLinkStatus` under a plain `<Link>`), or keep the skeleton and the enter fallback.
- **Image.** `next/image` renders its `<img>` with an `onLoad` handler and lazy by default, so React never waits for it: unless the hero's exact URL is already decoded, the morph lands on an empty box. Make the hero eager (`loading="eager"`) and decode it before the push (`patterns.md` § Wait for the destination, with `srcSet` and `sizes` from `getImageProps()`).
- Prefetching runs only in production builds, so test morphs with `next build && next start`.

## Shared elements across routes

Wrap the list thumbnail (inside its `<Link transitionTypes={['nav-morph']}>`) and the detail hero in `` <ViewTransition name={`product-${p.id}`} share="image-morph" default="none"> `` when both show the same picture (`share="morph"` when they differ), around boxes of the same aspect ratio. With `next/image`, two sizes are two image URLs: see § Readiness for morphs. Intercepting `@modal` routes: `patterns.md` § Modal over a mounted source.

## `loading.tsx`

`loading.tsx` is a Suspense boundary around the page, so use the split reveal: the skeleton VT in `loading.tsx`, the content VT in the page. React's reveal would have to wrap the whole segment (in the layout or `template.tsx`), where every refresh and search-param change would cross-fade it.

```tsx
// loading.tsx
<ViewTransition exit="slide-down" default="none"><PhotoGridSkeleton /></ViewTransition>
// page.tsx
<ViewTransition enter="slide-up" default="none"><PhotoGrid photos={photos} /></ViewTransition>
```

A `DirectionalTransition` in that page swallows the reveal, because the whole page suspends (SKILL.md § Wire it). Put the wrapper in the segment's `template.tsx` instead: it wraps `loading.tsx` and remounts when the segment or its params change, so it takes the navigation's enter and exit. Or drop `loading.tsx` and put `<Suspense>` in the page, below the wrapper.

## Same-route swaps

The App Router keys each segment by its param values, so `/collection/a` → `/collection/b` replaces the page (unmounted, or hidden in `<Activity>` under Cache Components). Page VTs see exit and enter, never an update, and the page's own `<Suspense>` is new, so it shows its fallback unless the data is prefetched or cached. A constant name pairs old and new content into a cross-fade:

```tsx
<Suspense fallback={<Skeleton />}>
  <ViewTransition name="collection-content" share="auto" enter="auto" default="none">
    <Content slug={slug} />
  </ViewTransition>
</Suspense>
```

- The pair forms only when old and new render in one commit; otherwise `enter="auto"` fades the content in after the fallback.
- A VT that stays mounted (in a layout, or switching on client state) needs `key={slug}` to swap rather than update.
