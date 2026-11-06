---
name: react-architecture
description: |
  Client-side React architecture for web and React Native: Feature-Sliced folder structure, thin routes, headless screens with logic in hooks, query key factories, state tool choices, and functional programming (pure functions, currying, pipe and compose). Use when starting or restructuring a Next.js, TanStack Start, Vite or Expo app, or adding a screen, feature or hook: "folder structure", "FSD", "where should this go", "query keys", "refactor the frontend".
  Do NOT use for: Effects, hydration, server security or performance (react-best-practices); tokens and component APIs (design-system); native lists or gestures (Expo's official skills); system design (software-architecture).
---

# React Architecture

Functional everywhere. Screens compose, hooks hold the logic. Code stays where it's used until something else needs it.

This skill fixes where code goes and what shape it takes. Framework APIs change between releases, so check those in version-matched sources: `node_modules/next/dist/docs/`, the `skills/` folders inside installed `@tanstack/*` packages, the Expo docs.

**Correctness and performance outrank style.** Where react-best-practices, or Expo's official skills on mobile (if available), disagrees about how code behaves or how fast it runs, follow it.

Paths are defaults (root `src/`, alias `@/`); the caller may redirect them. An app with another structure keeps it while you're only adding to it: follow its layout and write new logic in the functional style. Move code to this structure only when asked to restructure, and say what moved. Examples use `product`; use your domain's names.

---

## Project Structure (FSD)

```
src/
├── app/                      # Routes only (Next.js, Expo). TanStack Start: routes/
│   └── products/page.tsx     # Loads data, renders ProductsScreen from '@/screens/products'
├── providers/                # App-wide providers and initialization
├── screens/                  # One slice per screen. XScreen composes what's below
│   └── products/
│       ├── ui/               # ProductsScreen.tsx and screen-only components
│       ├── model/            # Hooks, pure logic, types
│       ├── api/              # Screen-only requests
│       └── index.ts          # Public API
├── blocks/                   # UI sections reused across screens
├── features/                 # User actions two screens share: forms, mutations
│   └── send-message/
├── entities/                 # Business objects two slices share: types, query definitions, stores
│   └── product/
└── shared/                   # No business logic
    ├── ui/                   # Design system: import @/shared/ui/button, no barrel
    ├── lib/                  # fp.ts, small utilities
    ├── api/                  # HTTP client, createQueryKeys
    └── config/               # Environment, constants
```

### Layer Rules

| Layer | Can import from |
|---|---|
| routes, `providers` | everything below |
| `screens` | `blocks`, `features`, `entities`, `shared` |
| `blocks` | `features`, `entities`, `shared` |
| `features` | `entities`, `shared` |
| `entities` | `shared` |
| `shared` | `shared` |

**Rule: Layers only import downward. A slice never imports a sibling slice; what both need moves down a layer.**

**Rule: Screen first. Code starts in its screen slice and moves down when a second consumer appears. Never create an entity, feature or block ahead of use.** This outranks every other placement rule here.

**Rule: Route files are thin: routing, guards, head, data loading, a Suspense boundary (with any view-transition wrapper above it), the screen. Nothing else.**

**Rule: Other slices import only a slice's `index.ts`.** Server-only exports go in `index.server.ts`, because one server-only module in `index.ts` breaks the build of every Client Component importing the slice.

### Stack Map

| | Next.js App Router | TanStack Start | Expo Router |
|---|---|---|---|
| Route folder | `src/app/` | `src/routes/` | `src/app/` (every file becomes a route; a `_layout` keeps its navigator and route names) |
| Callable server code in `api/` | `x.actions.ts` (`'use server'`) | `x.functions.ts` (`createServerFn`) | none: HTTP only |
| Server-only code in `api/` | `x.server.ts` with `import 'server-only'` | `x.server.ts` | none |
| Hook files | `'use client'` as the first line, so a Server Component can still import the slice's `index.ts` | no directive | no directive |
| URL state | `useUrlState` (`references/lib.md`) | `validateSearch`, `getRouteApi` | route params |

The screen doesn't change across stacks; only the hooks and route files on this table do.

---

## Functional Programming

**Rule: Client code is functional. One paradigm, with exceptions only where React requires them.**

1. **Pure core, effects at the edge.** Calculations are pure functions in `model/`. Requests, subscriptions and events live in hooks and handlers.
2. **Immutable data.** Build new values. A state change is a `(prev) => next` function, which `useState`, Zustand's `setState` and `setQueryData` all accept. Scroll, pointer and per-frame values are the exception: they live in refs, out of state.
3. **Composition.** Arrays use built-in method chains. Several steps on any other value use `pipe(value, f, g)`. A function built before its data exists uses `compose(g, f)` over named functions (an unannotated lambda infers `unknown` there). On a per-input path over a large array, one loop replaces the chain, and mutation that stays local to it is fine.
4. **Currying by hand.** Config first, data last, written as arrows. Curry when a call site stores or passes the partial; a lone `f(a)(b)` means uncurry. No `curry()` helper: it loses generics and misreads default parameters.
5. **No `class`, `this` or inheritance,** except Error Boundaries.
6. **Hooks are called directly, at the top level.** Never pass one as a value: `pipe(x, useY)` and `xs.map(useY)` both pass the hooks lint, and the second crashes when the length changes.
7. **No monad wrappers** (`Either`, `Option`, `IO`). Expected failures are discriminated unions (`{ ok: true } | { error }`), missing values use `?.` and `??`, async state comes from the query library.
8. **No helper for a one-liner.** `shared/lib/fp.ts` holds `pipe` and `compose` only; `not`, `prop`, `identity` and the like stay inline arrows.

```ts
// Curried: config first, data last
export const isInCategory = (category: string) => (product: Product) =>
  category === 'all' || product.category === category

// Arrays: built-in method chains
export const toVisibleCards = ({ category }: ProductFilters) => (products: Product[]): ProductCard[] =>
  products.filter(isInStock).filter(isInCategory(category)).toSorted(byName).map(toCard)

// Any other value, several steps: pipe
  priceLabel: pipe(product.price, applyDiscount(product.discountRate), formatWon),

// State changes are (prev) => next, composed before the data exists
export const addItem = (item: CartItem) => (state: CartState): CartState => ({ items: [...state.items, item] })
export const swapItem = (oldId: string, item: CartItem) =>
  useCartStore.setState(compose(addItem(item), removeItem(oldId)))
```

A curried function is new on each render. That's fine for cheap work; without the React Compiler, memoize a heavy `select` or a handler passed to a `memo` child.

---

## Headless Patterns

**Rule: Separate WHAT (logic) from HOW (presentation).**

```tsx
// ❌ Before: logic mixed into the component
function ProductsScreen() {
  const [products, setProducts] = useState<Product[]>([])
  const [category, setCategory] = useState('all')
  const [isLoading, setIsLoading] = useState(true)
  // ... 300 more lines
}
```

```tsx
// ✅ After: the main component composes, hooks hold the logic
export function ProductsScreen() {
  const { filters, setFilter, clear } = useProductFilters()
  const { data: cards = [], isPending, error, refetch } = useProductCards(filters)

  return (
    <Screen>
      <FilterBar category={filters.category} onCategoryChange={setFilter('category')} onClear={clear} />
      <ProductGrid cards={cards} isPending={isPending} error={error} onRetry={refetch} />
    </Screen>
  )
}
```

**Rule: Main component does composition only. Logic goes in hooks in `model/`.** Call each hook in the lowest component that reads its value, so fast-changing state doesn't re-render the whole screen.

**Rule: Each hook keeps one responsibility. A flow hook is for real coordination.** Two or three hooks in the main component are fine; a flow hook that only merges their returns adds a file for nothing.

**Rule: Hook interfaces are clean and predictable.** Data hooks return the query result as is (`{ data, isPending, error }`); state hooks return the state and named actions (`{ selected, toggle, clear }`).

**Rule: Hooks stay on the client.** A Server Component composes the same way with `await` in place of hooks, and hooks move to the interactive leaf. On Next.js, a mostly static screen stays a Server Component with `'use client'` on its interactive leaves; a screen interactive throughout can be a Client Component, with its data loaded in the route.

---

## Server State

**Rule: Query keys form a hierarchy and come from one factory. Never write a key inline.**

```ts
// entities/product/api/queries.ts
export const productKeys = createQueryKeys('products')

export const productListOptions = (filters: ProductFilters) =>
  queryOptions({
    queryKey: productKeys.list(filters),
    queryFn: () => fetchProducts(filters),
  })

// entities/product/api/useProducts.ts
export const useProducts = <T = Product[],>(filters: ProductFilters, select?: (products: Product[]) => T) =>
  useQuery({ ...productListOptions(filters), select })

// screens/products/api/useCreateProduct.ts: lists() invalidates every list
    onSuccess: () => queryClient.invalidateQueries({ queryKey: productKeys.lists() }),
```

**Rule: Query definitions and mutation hooks start in the screen's `api/`.** At the second consumer, queries move to `entities/<object>/api/` and actions to `features/<action>/api/`.

**Rule: Components call hooks. Loaders and server prefetches use the options directly,** because a hook can't run there.

→ Full slice: `references/examples.md`. `createQueryKeys`: `references/lib.md`.

---

## State Management

| State | Solution |
|---|---|
| Server data | Server Component or route loader where the framework has one; TanStack Query in client code |
| Filters, tabs, pagination | The URL, parsed once with a fallback |
| App-wide client state, or a fast-changing value many components read | Zustand |
| Local UI | `useState` |
| Simple form | Server entry point + Zod |
| Complex form (dynamic fields, instant validation) | React Hook Form + Zod |

**Rule: A Zustand store holds state and nothing else. Transitions are pure functions outside it, components subscribe with selectors, API calls stay out.** On Next.js, never write to it on the server: a module-level store is shared across requests.

**Rule: If it should survive a shared link, it belongs in the URL.**

---

## Server Code

| Caller | Choose |
|---|---|
| Web form | Server Action or server function |
| Mobile app, external client | Route Handler or server route (React Native can't call Server Actions) |
| Webhook | Route Handler or server route |

**Rule: Server code lives in the owning slice's `api/`, told apart by file name** (Stack Map), so `*.actions.ts` and `*.functions.ts` find every public entry point.

**Rule: With a separate backend, server code is a thin relay:** forward auth, call the API, shape the response. Without one, it owns data access. Domain logic never grows twice.

---

## Reuse and Dependencies

**Rule: Before creating UI, search `blocks/`.** Keep a catalog there (`BLOCKS.md`, generated from the folder: name, path, purpose from each component's JSDoc line). Reuse what fits instead of cloning it.

**Rule: Industry-standard tools for hard jobs stay: TanStack Query, Zustand, Zod, React Hook Form. Anything else the language covers, or a few dozen lines can do, is written in-house.** No utility libraries. A project's installed equivalent wins over any of these; never add a parallel library.

---

## Anti-Patterns

- **Business logic in a route file** → routes are thin; logic goes in the screen slice
- **Top-level `hooks/`, `types/`, `utils/`, `stores/`, `services/`** → code goes in the slice that owns it
- **An entity or feature with one consumer** → it stays in the screen until a second one appears
- **`useQuery({ queryKey: ['products', id], queryFn })`** → key factory plus `queryOptions`
- **A fetch inside a Zustand store** → the store holds state; a hook does the request
- **A `useEffect` that fetches** → TanStack Query or the route loader
- **`items.sort()` on state or props** → `toSorted`, or copy first; never mutate
- **`class ProductService`** → functions in `api/`
- **`lodash`, `remeda`, `ramda`, `curry()`** → built-in methods, arrows, `shared/lib/fp.ts`
- **`shared/` importing `features/`, or a screen reaching past a slice's `index.ts`** → move the code down, or export it

---

## Checklist

### Architecture
- [ ] Every file sits in the layer and segment the structure names; imports only point down
- [ ] Nothing moved down before it had a second consumer
- [ ] Route files and main components only compose
- [ ] The layer test passes (`references/lib.md`), or the notes say why it wasn't run

### Functional
- [ ] Calculations are pure; effects sit in hooks and handlers
- [ ] No mutation, no `class`, no hook passed as a value
- [ ] Curried functions take config first, and something stores or passes the partial; no new helper for a one-liner

### Data
- [ ] Query keys come from the factory, and every variable a query function reads is in its key
- [ ] Mutation hooks invalidate through the factory
- [ ] URL-worthy state is in the URL, parsed once with a fallback
- [ ] No new utility dependency

---

## References

| File | Contents |
|---|---|
| `references/examples.md` | One vertical slice, file by file: entity, screen, mutation hook, Server Action form, store, flow hook, route files per stack |
| `references/lib.md` | Code to copy in: `fp.ts`, `createQueryKeys`, `http`, `useUrlState`, the layer test |

Siblings, if available: react-best-practices (Effects, hydration, server-boundary security, performance), design-system (tokens, `shared/ui`, component APIs), Expo's official skills (lists, gestures, native behavior), i18n, hexagonal-backend (a dedicated backend).
