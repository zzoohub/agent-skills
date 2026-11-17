---
name: react-architecture
description: |
  Client-side React architecture for web and React Native: Feature-Sliced structure, thin routes, headless screens with logic in hooks delivered by render props, compound blocks and HoCs, request functions, query key factories, state tool choices, and functional programming (currying, pipe and compose). Use when starting or restructuring a Next.js, TanStack Start, Vite or Expo app, or adding a screen, feature, block, hook or HoC: "folder structure", "FSD", "where should this go", "render props", "query keys", "refactor the frontend".
  Do NOT use for: tokens and `shared/ui` component APIs (design-system); native lists or gestures (Expo's official skills); system design (software-architecture).
---

# React Architecture

Functional everywhere. Screens compose, hooks hold the logic, and patterns deliver it: HoCs wrap screens, render props and compound parts hand state to markup. Code stays where it's used until something else needs it.

This skill fixes where code goes and what shape it takes. Framework APIs change between releases, so check those in version-matched sources: `node_modules/next/dist/docs/`, the `skills/` folders inside installed `@tanstack/*` packages, the Expo docs.

**Correctness and performance outrank style.** Where the framework's docs, or Expo's official skills on mobile (if available), disagree about how code behaves or how fast it runs, follow them.

Paths are defaults (root `src/`, alias `@/`); the caller may redirect them. An app with another structure keeps it while you're only adding to it: follow its layout and write new logic in the functional style. Move code to this structure only when asked to restructure, and say what moved. A restructure changes where code lives, not what users or outside systems see (markup, URLs, requests, events): a rule here that would change behavior, such as a cache time or an effect moved into an HoC, ships as its own change and says so. Examples use `product`; use your domain's names.

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
├── blocks/                   # UI sections two screens reuse: ui/ composes, model/ holds the logic
├── features/                 # User actions two screens or blocks share: request, hook, UI
│   └── toggle-favorite/
├── entities/                 # Business objects two slices share: types, query definitions, stores
│   └── product/
└── shared/                   # No business logic
    ├── ui/                   # Design system: import @/shared/ui/button, no barrel
    ├── lib/                  # fp.ts, small utilities
    ├── api/                  # http.ts (the transport) and createQueryKeys, never a request file
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

**Rule: Other slices import only a slice's `index.ts`.** Server-only exports go in `index.server.ts`, because one server-only module in `index.ts` breaks the build of every Client Component importing the slice. Server-only code (`*.server.ts`, server entry points) imports a slice through `index.server.ts` as well, which re-exports the pure model it needs (types, constants, pure functions): `index.ts` is the client's entry point and can pull in UI, hooks and client SDKs.

### Placement

| Code | Lives in |
|---|---|
| Used by one screen | That screen's slice |
| A UI section two screens reuse | `blocks/<section>/`: its components only compose, and its state and derived values sit in its own `model/` |
| A user action two screens or blocks share | `features/<action>/`: its request, hook and UI. Other slices use the hook or the headless component, never the request function |
| A business object two slices share | `entities/<object>/`: types, pure logic, queries, stores, and the `ui/` that draws one |
| A component with no business logic (props in, markup out), at its second slice | `shared/ui` |
| A hook, HoC or helper, at its second consumer | The lowest layer that can import what it reads |

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
3. **Composition.** Arrays use built-in method chains. Several steps on any other value use `pipe(value, f, g)`. A function built before its data exists uses `compose(g, f)` over named functions (an unannotated lambda infers `unknown` there). Generic functions infer only forward, so an HoC stack is `pipe(Screen, inner, outer)`. On a per-input path over a large array, one loop replaces the chain, and mutation that stays local to it is fine.
4. **Currying by hand.** Config first, data last, written as arrows. Curry when a call site stores or passes the partial; a lone `f(a)(b)` means uncurry. Request functions (path first), HoCs (config first) and handlers passed per item (`select(id)`) are the standing cases. No `curry()` helper: it loses generics and misreads default parameters.
5. **No `class`, `this` or inheritance,** except Error Boundaries. Errors come from a factory and are told apart by a guard (`ApiError`, `isApiError`).
6. **Hooks are called directly, at the top level.** Never pass one as a value: `pipe(x, useY)` and `xs.map(useY)` both pass the hooks lint, and the second crashes when the length changes. HoCs and render props pass components and functions, never hooks.
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

// HoCs are curried too and stack with pipe, inner first
export default pipe(CheckoutScreen, withPageView(CHECKOUT_PAGE_VIEW), withSignInGate)
```

A curried function is new on each render. That's fine for cheap work; without the React Compiler, memoize a heavy `select`, a handler passed to a `memo` child, and each context slice split from one hook's value.

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

**Rule: Each hook keeps one responsibility. A flow hook is for real coordination.** Two or three hooks in the main component are fine; a hook or context that only merges their returns adds a file for nothing.

**Rule: Hook interfaces are clean and predictable.** Data hooks return the query result as is (`{ data, isPending, error }`); state hooks return the state and named actions (`{ isFavorited, isPending, toggle }`).

**Rule: Hooks stay on the client.** A Server Component composes the same way with `await` in place of hooks, and hooks move to the interactive leaf. On Next.js, a mostly static screen stays a Server Component with `'use client'` on its interactive leaves; a screen interactive throughout can be a Client Component, with its data loaded in the route.

### Patterns

Hooks are the unit of logic. Every pattern here delivers a hook's value to markup and holds no logic the hook doesn't. Pick the lightest one that does the job.

| Pattern | Use when | Not when |
|---|---|---|
| Hook in the lowest component | The default: one component reads the value | |
| Headless component with a render prop | A block or feature ships behavior and the screen owns the markup; a fast-changing value (a countdown, a live count) must re-render only the subtree that reads it | One screen uses it: call the hook in a leaf |
| Compound parts with render props | A multi-part block (`PurchasePanel.Root/.Options/.Price/.Buy`) whose parts the screen arranges and restyles | One part: a render prop is enough |
| HoC | A cross-cutting concern around a client screen: page views, gates, slow context values as props (`withCheckoutCore(pick)`) | Logic the screen's markup computes: that's a hook |
| Narrow contexts | Values a subtree reads, split by how often they change | Server data (Query), app state (Zustand) |
| Pure mapper, `pipe` | Turning domain values into what a component renders (`toVisibleCards(filters)`) | |
| State reducer, controlled props, slots | A screen must change a block's transitions or fill its regions without forking it | |

**Rule: A render prop receives exactly its hook's value, or one part's state, and is a plain function: UI = f(state).** It calls no hooks; a row that needs one renders a component. A function can't cross from a Server Component, so the file that passes one is a Client Component.

**Rule: Multi-part blocks are compound parts over narrow contexts.** Root calls the block's hook and, when it splits one value into several contexts, provides one per change rate, each slice memoized on the fields it carries and on handlers whose identity is stable. A part renders its default UI when it has no children, or calls children with exactly its state: the block owns behavior, the screen owns markup, and a part re-renders only when its own context changes. A part keeps the markup its policy needs (a consent line, a platform split) outside the children call, so a screen's markup can't drop it. Parts are exported by name and re-exported as one namespace (`export * as PurchasePanel`), so a Server Component can dot into them too.

**Rule: HoCs are curried, config first (`withPageView(spec)(Screen)`), and stacked with `pipe`.** Define them at module scope, never in render; call hooks before any early return; set `displayName`. An HoC's effects run after the wrapped screen's own (children first), so moving an effect into one changes its order: order-sensitive effects stay in the screen.

A screen uses them together: an HoC stack for what wraps it, hooks for what it computes, render-prop and compound blocks for what it shows.

→ `references/components.md`, `references/compound.md`, `references/hocs.md`.

---

## Server State

**Rule: Query keys form a hierarchy, come from one factory per domain and hold every variable the query function reads. Never write a key inline.**

```ts
// entities/product/api/queries.ts
const fetchProducts = getJson<Product[], ProductFilters>(`${API_URL}/api/products`)

export const productKeys = createQueryKeys('products')

export const productListOptions = (filters: ProductFilters) =>
  queryOptions({
    queryKey: productKeys.list(filters),
    queryFn: ({ signal }) => fetchProducts(filters, { signal }),
    staleTime: 60_000,
  })

// entities/product/api/useProducts.ts
export const useProducts = <T = Product[],>(filters: ProductFilters, select?: (products: Product[]) => T) =>
  useQuery({ ...productListOptions(filters), select })

// screens/products/api/useCreateProduct.ts: lists() invalidates every list
    onSuccess: () => queryClient.invalidateQueries({ queryKey: productKeys.lists() }),

// features/toggle-favorite/api/useToggleFavorite.ts: a cache write goes through the options' key, which carries the data type
    onSuccess: ({ isFavorited }) =>
      queryClient.setQueryData(favoriteIdsOptions().queryKey, setFavorited(productId, isFavorited)),
```

**Rule: Query definitions and mutation hooks start in the screen's `api/`.** At the second consumer, queries move to `entities/<object>/api/` and actions to `features/<action>/api/`. A `queryOptions` factory is a pure function from the query's variables to its definition, cache behavior included (`staleTime`), so the hook, a loader and a server prefetch agree.

**Rule: Components call hooks. Loaders and server prefetches use the options directly,** because a hook can't run there.

### Request Functions

**Rule: Client code never calls `fetch` itself. Each route and method gets one request function in the `api/` of the slice that calls it: a one-line curried partial over the transport (`shared/api/http.ts`).** A GET is `fetch<Noun>`, beside its `queryOptions`; any other action is named by its verb, beside the mutation hook named after it (`createProduct`, `useCreateProduct`). Neither leaves the slice through `index.ts`.

**Rule: The transport rejects `!ok` and non-JSON bodies with an `ApiError` carrying `status` and the body.** Call sites never check `res.ok` or call `res.json()`; hooks get the rejection as `error` and read it through `isApiError`.

**Rule: A request function knows the path and the types, nothing else.** Toasts, retries, error reporting and fallbacks live in the hook that calls it.

→ Full slice: `references/examples.md`. `createQueryKeys` and the transport: `references/lib.md`.

---

## State Management

| State | Solution |
|---|---|
| Server data | Server Component or route loader where the framework has one; TanStack Query in client code |
| Filters, tabs, pagination | The URL, parsed once with a fallback |
| Values one subtree reads (a block's parts, a flow's steps) | Narrow contexts, split by change rate |
| App-wide client state, or a fast-changing value many components read | Zustand |
| Local UI | `useState` |
| Simple form | Server entry point + Zod |
| Complex form (dynamic fields, instant validation) | React Hook Form + Zod |

**Rule: A Zustand store holds state and nothing else.** Transitions are pure functions outside it, bound once into named actions; components subscribe with selectors; API calls stay out. A selector returns a stored value or a primitive; one that builds an object needs `useShallow`. On Next.js, never write to a store on the server: a module-level store is shared across requests.

**Rule: If it should survive a shared link, it belongs in the URL.**

---

## Server Code

| Caller | Choose |
|---|---|
| Web form | Server Action or server function |
| Mobile app, external client | Route Handler or server route (React Native can't call Server Actions) |
| Webhook | Route Handler or server route |

**Rule: Server code lives in the owning slice's `api/`, told apart by file name** (Stack Map), so `*.actions.ts` and `*.functions.ts` find every public entry point.

**Rule: Every server entry point is a public endpoint.** Who is calling, and whether they may touch that record, is checked in its handler or the backend it forwards to. Middleware, route guards, HoC gates and hidden UI only decide what renders.

**Rule: With a separate backend, server code is a thin relay:** forward auth, call the API, shape the response. Without one, it owns data access. Domain logic never grows twice.

---

## Reuse and Dependencies

**Rule: Before creating UI, search `blocks/`.** Keep a catalog there (`BLOCKS.md`, generated from the folder: name, path, purpose from each component's JSDoc line). Reuse what fits, and extend a block's props instead of cloning it.

**Rule: Industry-standard tools for hard jobs stay: TanStack Query, Zustand, Zod, React Hook Form. Anything else the language covers, or a few dozen lines can do, is written in-house.** No utility or HTTP client libraries. A project's installed equivalent wins over any of these; never add a parallel library.

---

## Anti-Patterns

- **Business logic in a route file** → routes are thin; logic goes in the screen slice
- **Top-level `components/`, `hooks/`, `contexts/`, `types/`, `utils/`, `stores/`, `services/`** → code goes in the slice that owns it, and the design system in `shared/ui`
- **An entity, feature or block with one consumer** → it stays in the screen until a second one appears
- **`useQuery({ queryKey: ['products', id], queryFn })`** → key factory plus `queryOptions`
- **`fetch(…)`, `if (!res.ok)` or `res.json()` at a call site, or a request file in `shared/api`** → a request function in the calling slice's `api/`; the transport rejects
- **A fetch or an action inside a Zustand store** → the store holds state; a hook does the request
- **A `useEffect` that fetches, a module-level response cache, or an effect that copies props or state into other state** → TanStack Query or the route loader; compute derived values during render
- **`useCartStore((state) => ({ count: …, total: … }))`** → select a stored value or a primitive, or wrap the selector in `useShallow`
- **A hook or context that merges narrow ones back (one `useCheckout()` over all of them)** → read only the narrow hook you need
- **A hook inside a render prop, or a default renderer that calls one** → render a component that calls it
- **An HoC applied inside render (`const Gated = withSignInGate(Screen)` in a component)** → module scope; a new component type each render remounts the subtree
- **`compose(withSignInGate, withPageView(spec))(Screen)`** → `pipe(Screen, withPageView(spec), withSignInGate)`; `compose` infers `unknown` for generic HoCs
- **One hook's value split into several contexts with inline objects** → memoize each slice on the fields it carries, or every part re-renders on any change
- **`items.sort()` on state or props** → `toSorted`, or copy first; never mutate
- **`class ProductService`, `class ApiError extends Error`** → functions in `api/`; an error factory and a guard
- **`lodash`, `remeda`, `ramda`, `curry()`, `axios`, `ky`** → built-in methods, arrows, `shared/lib/fp.ts`, `shared/api/http.ts`
- **`shared/` importing `features/`, or a screen reaching past a slice's `index.ts`** → move the code down, or export it

---

## Checklist

### Architecture
- [ ] Every file sits in the layer and segment the structure names; imports only point down
- [ ] Nothing moved down before it had a second consumer
- [ ] Route files, main components and block components only compose
- [ ] The layer test passes (`references/lib.md`), or the notes say why it wasn't run

### Functional
- [ ] Calculations are pure; effects sit in hooks and handlers
- [ ] No mutation, no `class`, no hook passed as a value
- [ ] Curried functions take config first, and something stores or passes the partial; no new helper for a one-liner

### Patterns
- [ ] Logic is in hooks; render props, parts and HoCs only deliver it, and a render prop receives exactly its hook's value or its part's state and calls no hooks
- [ ] Fast-changing values are read in the smallest subtree; context slices are split by change rate and memoized on stable handlers
- [ ] HoCs are curried config first, defined at module scope and stacked with `pipe`; a part's policy markup sits outside its children call

### Data
- [ ] Query keys come from the factory, and every variable a query function reads is in its key
- [ ] Requests go through request functions over the transport; no `res.ok` or `res.json()` at a call site
- [ ] Mutation hooks invalidate through the factory and write the cache through the options' `queryKey`
- [ ] Store selectors return a stored value or a primitive
- [ ] URL-worthy state is in the URL, parsed once with a fallback
- [ ] No new utility dependency

---

## References

Read the one the task needs.

| File | Read when | Contents |
|---|---|---|
| `references/examples.md` | Adding a screen, query, mutation, form, store or route file | One vertical slice, file by file: entity, screen, feature action, Server Action form, store, flow hook, route files per stack |
| `references/components.md` | Writing a headless component, slot or context | Render props, function slots, narrow contexts split by change rate |
| `references/compound.md` | Writing a multi-part block, or letting a screen change a block's transitions | `PurchasePanel` (compound parts over narrow contexts), `StepForm` (state reducer) |
| `references/hocs.md` | Writing or stacking an HoC | Page view, gate, context values as props, `pipe` stacks and their order |
| `references/lib.md` | Copying in shared code | `fp.ts`, `createQueryKeys`, the transport, `useUrlState`, the layer test |

Siblings, if available: design-system (tokens, `shared/ui`, component APIs), Expo's official skills (lists, gestures, native behavior), i18n, hexagonal-backend (a dedicated backend).
