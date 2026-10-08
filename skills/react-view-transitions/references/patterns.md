# Patterns and diagnosis

## Filter or sort a list

Discrete choices (filter chips, a sort menu) animate under their own type; type-ahead stays silent, since neither plain state nor `useDeferredValue` adds one. `useOptimistic` keeps the control's label out of the animation; the list renders from committed state so its items glide:

```jsx
const [sort, setSort] = useState('newest');
const [optimisticSort, setOptimisticSort] = useOptimistic(sort);

function cycleSort() {
  const next = getNextSort(optimisticSort);
  startTransition(() => {
    addTransitionType('list-change');
    setOptimisticSort(next); // commits before the snapshot: the label doesn't animate
    setSort(next);           // commits inside the transition: the items glide
  });
}

<button onClick={cycleSort}>Sort: {LABELS[optimisticSort]}</button>
{[...items].sort(comparators[sort]).map(item => (
  <ViewTransition key={item.id} default={{ 'list-change': 'auto', default: 'none' }}> {/* list identity */}
    <Link href={`/items/${item.id}`}>
      <ViewTransition name={`item-${item.id}`} share="morph" default="none">            {/* shared element */}
        <img src={item.image} alt={item.name} />
      </ViewTransition>
    </Link>
  </ViewTransition>
))}
```

Drop the inner VT when items don't morph. Keep a DOM node (here the link) between the two: an update stops at nested VTs, so an outer VT with no DOM of its own can't glide. Per-item stagger (`parentEnter`/`parentExit`) is experimental-channel only; don't ship it.

## Card expand and collapse

A card expanding into its detail is a named pair swapped inside `startTransition`. Save `scrollY` on open and restore it on close in a `useLayoutEffect` with `behavior: 'instant'`: a layout effect runs before React captures the new state, while a timer runs after it and makes the card jump.

## Modal over a mounted source

A pair forms only when one side unmounts: a grid that stays mounted under a modal or lightbox collides with it on the name, and nothing morphs. In the opening Transition, render the open item without its named VT (Next.js `@modal` routes: `usePathname() === href`); the modal names its image (`share="morph"`) and fades its shell in. A client-side close pairs back the same way; a route modal closes with `router.back()`, unanimated: accept that rather than push.

## Cross-fade in place

A mounted VT whose `update` cross-fades new content in (tabs, a panel, a carousel); nothing remounts, so nothing refetches. Gate it so refreshes stay silent, with `addTransitionType('tab-change')` in the tab's handler:

```jsx
<ViewTransition update={{ 'tab-change': 'auto', default: 'none' }} default="none"><TabPanel tab={activeTab} /></ViewTransition>
```

Nested VTs inside take the update from it. If they do, or the content's state must reset, key the VT instead (`nextjs.md` § Same-route swaps). Panels kept in `<Activity>` fire exit when hidden and enter when shown, state kept.

## Split reveal

For content that re-renders in background Transitions, which React's reveal would cross-fade. Both VTs set `default="none"`:

```jsx
<Suspense fallback={<ViewTransition exit="slide-down" default="none"><Skeleton /></ViewTransition>}>
  <ViewTransition enter="slide-up" default="none"><Content /></ViewTransition>
</Suspense>
```

Without a page-level VT above it, the content VT also plays its enter on warm navigations, where nothing suspended.

## A control in both skeleton and content

Wrap it on both sides in the same named VT: it pairs on the reveal and stays put; unpaired, it resolves to none and moves with its page.

```jsx
<ViewTransition name="search-input" share="auto" default="none"><input … /></ViewTransition> {/* in the fallback and the content */}
```

A raw `viewTransitionName` is captured in every transition, so the control would fade in place while its page slides away.

## Wait for the destination

A morph needs the destination image painted when React captures the new state, and React doesn't wait for lazy or `onLoad` images, every `next/image` included. Unless the destination shows a URL already on screen, decode it before the navigation commits, capped so a slow network falls back to the enter animation instead of a dead click:

```tsx
function decoded(src: string, cap = 100) {        // settles on decode or after `cap` ms; never rejects
  const img = new Image();
  img.src = src;                                    // the exact URL the destination will request
  return Promise.race([img.decode().catch(() => {}), new Promise((r) => setTimeout(r, cap))]);
}

function openPhoto(photo: Photo) {                  // latest = useRef(0)
  const ticket = ++latest.current;
  startTransition(async () => {
    addTransitionType('nav-morph');                 // still applies after the await
    await decoded(photo.heroSrc);
    if (ticket !== latest.current) return;          // a later click wins
    startTransition(() => navigate(`/photo/${photo.id}`)); // after an await, updates need their own Transition
  });
}
```

- The cap is click latency you add on a cold cache: the page stays interactive, but the click shows nothing until the wait ends. Report it as a trade-off.
- With `srcset`, give the probe the destination's `srcset` and `sizes` too, or it decodes a candidate the page never uses (`next/image`: take them from `getImageProps()`).
- Data works the same way: content that suspends forms no pair. Either the click waits for the data inside this Transition (the old page stays put with no feedback, so add a pending cue and report the wait) or the morph falls back to the enter animation.

## Event callbacks

`onEnter`, `onExit`, `onUpdate` and `onShare` receive `(instance, types)`; animate `instance.old`, `.new`, `.group` or `.imagePair` with `.animate()`. One fires per VT per Transition (`onShare` wins over enter/exit). Return a cleanup that cancels your animation, and skip it yourself under `matchMedia('(prefers-reduced-motion: reduce)')`: the CSS media query never reaches animations started from script.

## Diagnose

Find what fired before changing code. By hand, scrub DevTools' paused Animations panel at 10% speed and read the `::view-transition` tree; throttle network and CPU, emulate reduced motion, and try Safari once.

As an agent, arm this probe through the browser tool's JS evaluation (a reload drops it), act, then read `JSON.stringify(__vt)`:

```js
(()=>{const start=Document.prototype.startViewTransition;window.__vt=[];
Document.prototype.startViewTransition=function(opts){const t0=performance.now(),vt=start.call(this,opts);
vt.ready.then(()=>__vt.push({types:opts?.types,wait:Math.round(performance.now()-t0),
anims:document.documentElement.getAnimations({subtree:true}).filter(a=>a.effect?.pseudoElement?.startsWith('::view-transition'))
.map(a=>[a.effect.pseudoElement,a.animationName,Math.round(a.effect.getComputedTiming().endTime)])}),e=>__vt.push(String(e)));
return vt};return 0})()
```

One entry per transition; `group(root)` and `old(root)` alone are React hiding the old page. Gates: no error string; no `new(root)` unless the whole page should cross-fade; every `endTime` you authored inside its range in SKILL.md's timing yardstick (the project's own values are theirs); `wait` ≤ 100 ms, else a font, image or navigation froze the screen (preload it); each morph lists `old(<name>)` and `new(<name>)`; under reduced motion (emulated, else read the CSS), no slide, glide, morph flight or blur you authored plays, fades may stay, and callbacks check `matchMedia` (recipe CSS: slides multiply `--vt-travel`; Reduced Motion covers every VT you added). No reduced-motion rule in the project's own view-transition CSS: a proposal, not a failed gate.

- **Nothing animates, no probe entry:** the update ran outside a Transition, the VT sits below a DOM node, the browser lacks View Transitions level 2, or the update came from `popstate` (back/forward). A `viewTransitionName` style alone never starts a transition.
- **Nothing animates, and the probe logs an error:** `InvalidStateError` with "Unexpected duplicate view-transition-name" in the console means two VTs with one name were captured together (React warns in dev when two `<ViewTransition name=…>` mount at once); `AbortError` means something else called `startViewTransition` (a router option, a library): turn it off.
- **Nothing animates in Safari only:** a VT wraps an inline element holding text and blocks, such as a `<Link>` (React warns in dev): make that element `display: block` or move the VT inside it.
- **Typed animation never plays; `types` is empty:** the router committed outside your Transition; type it as SKILL.md § Wire it shows (Next.js before 16.2: `nextjs.md` § Typed links and programmatic navigation).
- **The whole page fades or freezes and clicks die** (`new(root)` present): a VT boundary resized, or a portal changed, with no ancestor VT to contain it. Wrap that region in a VT (`default="none"` if it shouldn't animate) or keep the boundary's size stable.
- **Morph missing:** the names differ; `share` resolved to `"none"`; one side is offscreen or never unmounted (§ Modal over a mounted source); or the destination suspended. Throttle the network and test a production build (Next.js dev builds don't prefetch).
- **Skeleton exits, content pops in:** a VT above the content was inserted by the same reveal and resolved to `"none"`, typically a page wrapper under `loading.tsx` (`nextjs.md` § `loading.tsx`).
- **Motion on refresh, polling or typing:** an ungated trigger; gate it on a type (SKILL.md § Wire it).
- **Swap cross-fades instead of exit and enter:** the VT stayed mounted, so it's an `update`. Key it.
- **Only the default cross-fade plays:** the class has no CSS rule, or a typo.
- **Header covered, sliding with the page, or its backdrop blur flickers:** pin it (`css-recipes.md` § Pinned).
- **Morph image distorts, doubles or jumps:** the two captured boxes differ, in aspect ratio or in kind (a card named on one side, a bare image on the other). Name the same box on both sides and match the ratios; where the design keeps them different, use `image-morph` (`css-recipes.md`), which crops, and say which edges crop mid-flight.
- **Morph looks soft or ghosted though both sides show one picture:** two renderings of it cross-fade under the blur. Use `image-morph`.
- **Morph lands on an empty or half-drawn box:** the destination image wasn't decoded at capture (lazy, `next/image`, or a different `srcset` candidate). Decode it first (§ Wait for the destination) or show a URL that is already on screen.
- **Neighbours ghost, jump, or slide under an exiting item:** they have no VT of their own, so they move inside the nearest animating ancestor's snapshot or snap to their new places. Give them keyed VTs with a gated `update` to glide, or report that they jump.
- **A click does nothing for a moment, then the transition plays:** the Transition is waiting on data or an image. Expected after a readiness fix; keep the cap small and add a pending cue.
- **Text ghosts:** a scaled text snapshot. Use `text-morph`.
- **Rounded corners lost:** the radius comes from an ancestor's clipping; put it on the captured element.
- **Items draw past a scroller's edges while animating:** snapshots ignore ancestor clipping. Glide only lists that fit their container, or drop that glide.
- **Scroll jumps on a hash link (`/page#id`):** navigate without the hash, then scroll to the target programmatically after the navigation.
- **Popover or tooltip vanishes mid-transition:** snapshots cover live DOM. Close it before the transition starts, or pin it (unclickable until the transition ends).
- **"A ViewTransition timed out because a Navigation stalled":** the router resolves its navigation in `useEffect`; resolve it in `useLayoutEffect`.
