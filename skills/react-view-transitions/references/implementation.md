# App-wide pass

For app-wide or multi-flow scope; one interaction needs none of this.

## 1. Audit

Search the codebase, then open only the files a navigation or reveal touches:

- **Navigation triggers:** `<Link>`, `router.push/replace/back`, custom routers; which pass types; whether the router calls `startViewTransition` itself.
- **Routes:** every page, which layouts wrap `{children}`, which segments have a `loading` file.
- **Suspense boundaries:** each fallback, and whether its content re-renders on refresh or polling.
- **Persistent chrome:** sticky headers, tab bars and sidebars that stay on screen.
- **Shared visuals:** the same image, card or avatar on two views; whether both use the same image URL, and whether the source stays mounted under a modal.
- **Skeleton and content control pairs:** a control (search input, tab bar) drawn in both a fallback and its content.
- **Existing motion:** view-transition CSS, motion tokens, a motion spec, animation libraries, CSS transitions or `element.animate` on the same elements. Theirs wins (SKILL.md § Frame the request, Precedence): build on it, one engine per element, and list any default you'd change as a proposal.
- **Installed versions and config flags:** build within them, unedited unless asked (`nextjs.md` § Setup by version).

## 2. Nav map

A deliverable returned with the report: one row per navigation the user can make, up-links and browser back included; a row with no purpose says "none". Cells stay under eight words.

| Route | To | Kind | Pattern | Pair forms? | Fallback |
|---|---|---|---|---|---|
| `/` | `/photo/[id]` | forward | Morph, page fades (`nav-morph`) | If prefetched and the hero decoded | Reveal on arrival |
| `/photo/[id]` | `/` | up ("← Gallery") | Reverse morph (`nav-morph`) | If the grid item is in the viewport | Page fade |
| `/photo/[id]` | `/` | browser back | None (Next.js: `popstate`) | — | Instant |
| `/c/[a]` | `/c/[b]` | lateral | Cross-fade, constant name | If the data is cached | `enter="auto"` |

For each named element, list every row where its pair forms and every row where it doesn't; the second list decides which enter or exit fallback it needs.

## 3. Wire in this order

Each step depends on the one before; semantics live in SKILL.md § Wire it.

1. **Pin** persistent chrome (`css-recipes.md` § Pinned) first, or every later slide draws over it.
2. **Pages:** `DirectionalTransition` on the pages of each hierarchical, sequential or morph row, above their Suspense boundaries (Next.js with `loading.tsx`: in `template.tsx`); type each link.
3. **Reveals:** React's reveal where a boundary should animate, the split reveal where content revalidates in place; one named VT per skeleton and content control pair.
4. **Shared elements:** named in the consumer, `share="morph"` on both sides (`"image-morph"` for one picture), same box geometry; check each row's readiness (prefetch, a decoded image).
5. **In-place motion:** gate keyed lists and tab cross-fades on a type; same-route swaps get the constant-name cross-fade (`nextjs.md`).
6. **CSS** last: extend the project's view-transition CSS; recipes from `css-recipes.md` only where none exists.
7. **Walk every row** per SKILL.md Self-Review 6; on a warm navigation no reveal may replay. Mark a row you couldn't run "not observed", with the reason.
