# CSS recipes

Install these only where the project has no view-transition CSS yet: the blocks for the classes you use, the Reduced Motion lines for what your VTs animate (`"auto"` glides and morphs included), and only the Timing variables and keyframes those reference. Where it has some, extend it in its own names, durations and easings; copy a block only for a new class that has no rule, rewritten onto its variables with its travel and blur off under reduced motion, and leave its existing rules alone (SKILL.md § Frame the request, Precedence). Names carry a `vt-` prefix because global keyframe and custom-property names collide silently.

## Timing

Plain values inside SKILL.md's timing yardstick; page motion ends by 300 ms. If the project defines motion tokens, point these at the ones you found in its CSS; never reference a token you haven't seen.

```css
:root {
  --vt-exit: 100ms;
  --vt-enter: 200ms;
  --vt-move: 300ms;
  --vt-ease-enter: cubic-bezier(0, 0, 0.2, 1); /* decelerate */
  --vt-ease-exit: cubic-bezier(0.4, 0, 1, 1);  /* accelerate */
  --vt-dir: 1;    /* horizontal direction; RTL flips it */
  --vt-travel: 1; /* 0 under reduced motion */
}
html[dir="rtl"] { --vt-dir: -1; }

/* Exits run forward to a `to` frame: `reverse` would reverse their easing too. */
@keyframes vt-fade-in { from { opacity: 0; } }
@keyframes vt-fade-out { to { opacity: 0; } }
@keyframes vt-slide-x-in { from { translate: calc(var(--vt-dir) * var(--vt-travel) * var(--vt-slide-offset)) 0; } }
@keyframes vt-slide-x-out { to { translate: calc(var(--vt-dir) * var(--vt-travel) * var(--vt-slide-offset)) 0; } }
@keyframes vt-slide-y-in { from { translate: 0 calc(var(--vt-travel) * var(--vt-slide-y-offset, 10px)); } }
@keyframes vt-slide-y-out { to { translate: 0 calc(var(--vt-travel) * var(--vt-slide-y-offset, 10px)); } }
```

## Fade

`enter="fade-in" exit="fade-out"` for in-place enter and exit, undelayed. `nav-morph` is `DirectionalTransition`'s page fade under a morph: the new page waits out the old one's fade and ends with the morph.

```css
::view-transition-old(.fade-out), ::view-transition-old(.nav-morph) { animation: var(--vt-exit) var(--vt-ease-exit) both vt-fade-out; }
::view-transition-new(.fade-in) { animation: var(--vt-enter) var(--vt-ease-enter) both vt-fade-in; }
::view-transition-new(.nav-morph) { animation: var(--vt-enter) var(--vt-ease-enter) var(--vt-exit) both vt-fade-in; }
```

## Reveal: slide-up and slide-down

The split reveal: `exit="slide-down"` on the fallback, `enter="slide-up"` on the content.

```css
::view-transition-old(.slide-down) {
  animation: var(--vt-exit) var(--vt-ease-exit) both vt-fade-out,
             var(--vt-exit) var(--vt-ease-exit) both vt-slide-y-out;
}
::view-transition-new(.slide-up) {
  animation: var(--vt-enter) var(--vt-ease-enter) var(--vt-exit) both vt-fade-in,
             var(--vt-move) var(--vt-ease-enter) both vt-slide-y-in;
}
```

## Directional: nav-forward and nav-back

Used by `DirectionalTransition`. Forward moves content toward the start edge; back reverses it.

```css
::view-transition-old(.nav-forward), ::view-transition-old(.nav-back) {
  animation: var(--vt-exit) var(--vt-ease-exit) both vt-fade-out,
             var(--vt-move) var(--vt-ease-exit) both vt-slide-x-out;
}
::view-transition-new(.nav-forward), ::view-transition-new(.nav-back) {
  animation: var(--vt-enter) var(--vt-ease-enter) var(--vt-exit) both vt-fade-in,
             var(--vt-move) var(--vt-ease-enter) both vt-slide-x-in;
}
::view-transition-old(.nav-forward), ::view-transition-new(.nav-back) { --vt-slide-offset: -60px; }
::view-transition-new(.nav-forward), ::view-transition-old(.nav-back) { --vt-slide-offset: 60px; }
```

## Morph

`share="morph"` on both sides of a named pair whose two sides look different (a card becoming a page header).

```css
::view-transition-group(.morph) { animation-duration: var(--vt-move); }
/* The only blur in these recipes: it masks the cross-fade between two different snapshots. */
::view-transition-image-pair(.morph) { animation-name: vt-blur; }
@keyframes vt-blur { 30% { filter: blur(3px); } }
```

## Image morph

`share="image-morph"` when both sides show the same picture (thumbnail → hero). Cross-fading two renderings of one image shows a soft double, so both snapshots stay opaque and unblurred, the new, sharper one on top. Each fills the moving box, so differing aspect ratios crop rather than misalign; a crop that shifts mid-flight still shows, so match the ratios where the design allows. The new snapshot must be painted when captured (`patterns.md` § Wait for the destination).

```css
::view-transition-group(.image-morph) { animation-duration: var(--vt-move); }
::view-transition-old(.image-morph), ::view-transition-new(.image-morph) {
  animation: none; mix-blend-mode: normal;
  height: 100%; object-fit: cover; overflow: clip;
}
```

## Text morph

`share="text-morph"` for text whose size changes (`<h3>` → `<h1>`): a scaled snapshot ghosts, so this hides the old one and moves the new text at full resolution.

```css
::view-transition-group(.text-morph) { animation-duration: var(--vt-move); }
::view-transition-old(.text-morph) { display: none; }
::view-transition-new(.text-morph) { animation: none; object-fit: none; object-position: left top; }
```

## Pinned

For persistent chrome (sticky header, tab bar). Snapshots draw in an overlay above the live page and cover unnamed chrome; naming it lifts it into the overlay, and this class holds it still. Pinned elements can't be clicked until the transition ends: pin only what must stay. Don't name a `<ViewTransition>`'s top-level DOM node yourself: React overwrites the name whenever that VT animates.

```jsx
<header style={{ viewTransitionName: 'site-header', viewTransitionClass: 'pinned' }}>…</header>
```

```css
::view-transition-group(.pinned) { animation: none; z-index: 100; }
::view-transition-old(.pinned) { display: none; }
::view-transition-new(.pinned) { animation: none; }
```

## Reduced Motion

Travel, morph geometry and blur stop; fades stay, and morphs cross-fade within `--vt-enter` (an image morph just swaps). A global `*` reset doesn't reach `::view-transition-*` pseudo-elements: install this with the recipes unless the project's reduced-motion CSS already targets them. Callback animations check the media query themselves (`patterns.md` § Event callbacks).

```css
@media (prefers-reduced-motion: reduce) {
  :root { --vt-travel: 0 !important; }          /* slides keep only their fade */
  ::view-transition-group(*) {                  /* morphs and glides cross-fade in place */
    animation-name: none !important;
    animation-duration: var(--vt-enter) !important;
  }
  ::view-transition-image-pair(*) { animation-name: none !important; } /* no blur */
}
```
