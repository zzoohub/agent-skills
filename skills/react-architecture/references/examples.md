# React Architecture Examples

One vertical slice, file by file. Each block's first line is its path, and imports are shown because layering is the point. `product` and `cart` are examples; use your domain's names. Presentational components (`FilterBar`, `ProductGrid`, `ProductsSkeleton`, `HeartButton`) are left out; `ProductGrid` renders the loading, empty and retryable error states. Headless components, compound blocks and HoCs have their own files: `components.md`, `compound.md`, `hocs.md`.

## Table of Contents

1. [Layout](#layout)
2. [Entity: types, pure logic, query definitions](#entity-types-pure-logic-query-definitions)
3. [Screen: headless composition](#screen-headless-composition)
4. [Feature: an action with a headless component](#feature-an-action-with-a-headless-component)
5. [Feature: a form with a Server Action](#feature-a-form-with-a-server-action)
6. [Store: state, pure transitions, selectors](#store-state-pure-transitions-selectors)
7. [Flow hook](#flow-hook)
8. [Route files per stack](#route-files-per-stack)

## Layout

Placement follows consumers. `toVisibleCards` and `useCreateProduct` live in the screen because only that screen uses them. `entities/product` exists because a second screen, `product-detail`, reads the same data. `features/toggle-favorite` exists because both screens toggle a favorite, and its query stays inside it because nothing else reads the favorite ids. `features/send-message` exists because two screens embed that form.

```
src/
├── app/products/page.tsx
├── screens/products/
│   ├── ui/ProductsScreen.tsx
│   ├── ui/ProductCardItem.tsx
│   ├── model/filters.ts
│   ├── model/useProductFilters.ts
│   ├── model/useProductCards.ts
│   ├── model/toVisibleCards.ts
│   ├── api/useCreateProduct.ts
│   └── index.ts
├── features/toggle-favorite/
│   ├── ui/FavoriteToggle.tsx
│   ├── model/favorite.ts
│   ├── model/useFavorite.ts
│   ├── api/queries.ts
│   ├── api/useToggleFavorite.ts
│   └── index.ts
├── features/send-message/
│   ├── ui/SendMessageForm.tsx
│   ├── api/sendMessage.actions.ts
│   ├── api/message.server.ts
│   └── index.ts
├── entities/product/
│   ├── model/product.ts
│   ├── api/queries.ts
│   ├── api/useProducts.ts
│   ├── api/product.server.ts
│   ├── index.ts
│   └── index.server.ts
└── shared/
```

## Entity: types, pure logic, query definitions

```ts
// src/entities/product/model/product.ts
export type Product = {
  id: string
  name: string
  category: string
  stock: number
  price: number
  discountRate: number
}

export type ProductFilters = { category: string }

export const isInStock = (product: Product) => product.stock > 0

export const isInCategory = (category: string) => (product: Product) =>
  category === 'all' || product.category === category
```

The request function fixes the path and the types and knows nothing else. The options add the key, cancellation (`signal`) and the cache time, so the hook, a loader and a server prefetch share one definition.

```ts
// src/entities/product/api/queries.ts
import { queryOptions } from '@tanstack/react-query'

import { createQueryKeys } from '@/shared/api/createQueryKeys'
import { getJson } from '@/shared/api/http'
import { API_URL } from '@/shared/config/env'

import type { Product, ProductFilters } from '../model/product'

const fetchProducts = getJson<Product[], ProductFilters>(`${API_URL}/api/products`)

export const productKeys = createQueryKeys('products')

export const productListOptions = (filters: ProductFilters) =>
  queryOptions({
    queryKey: productKeys.list(filters),
    queryFn: ({ signal }) => fetchProducts(filters, { signal }),
    staleTime: 60_000,
  })
```

Components call the hook. `select` takes a partial, so a screen can shape the data without a second query.

```ts
// src/entities/product/api/useProducts.ts
'use client'

import { useQuery } from '@tanstack/react-query'

import type { Product, ProductFilters } from '../model/product'
import { productListOptions } from './queries'

export const useProducts = <T = Product[],>(filters: ProductFilters, select?: (products: Product[]) => T) =>
  useQuery({ ...productListOptions(filters), select })
```

Server-only code goes through `index.server.ts`, so importing the slice from a Client Component can't pull it in. It is also the entry point for other server-only files, so it re-exports the pure model they need: `index.ts` can pull in hooks, UI and client SDKs. The backend call is a request function too: a path that carries an id takes the id first, and the caller adds the credential the request function doesn't know.

```ts
// src/entities/product/api/product.server.ts
import 'server-only'

import { getJson } from '@/shared/api/http'

import type { Product } from '../model/product'

const fetchProduct = (id: string) => getJson<Product>(`${process.env.API_URL}/products/${encodeURIComponent(id)}`)

export const findProductById = (id: string) =>
  fetchProduct(id)(undefined, { headers: { authorization: `Bearer ${process.env.API_KEY}` } })
```

```ts
// src/entities/product/index.server.ts
export { findProductById } from './api/product.server'
export { isInStock } from './model/product'
export type { Product } from './model/product'
```

```ts
// src/entities/product/index.ts
export { productKeys, productListOptions } from './api/queries'
export { useProducts } from './api/useProducts'
export { isInCategory, isInStock } from './model/product'
export type { Product, ProductFilters } from './model/product'
```

## Screen: headless composition

Pure logic stays in the screen until a second consumer appears. Arrays use built-in chains; a single value going through several steps uses `pipe`. Field names stay as the data has them: renaming `name` here would force every consumer to rename it back. Formatters are built once at module scope, because these functions run per item, and a sort breaks ties on a unique key.

```ts
// src/screens/products/model/toVisibleCards.ts
import { isInCategory, isInStock, type Product, type ProductFilters } from '@/entities/product'
import { pipe } from '@/shared/lib/fp'

export type ProductCard = { id: string; name: string; priceLabel: string }

const collator = new Intl.Collator('ko')
const wonFormat = new Intl.NumberFormat('ko-KR')

const byName = (a: Product, b: Product) => collator.compare(a.name, b.name) || collator.compare(a.id, b.id)
const applyDiscount = (rate: number) => (price: number) => Math.round(price * (1 - rate))
const formatWon = (price: number) => `${wonFormat.format(price)}원`

const toCard = (product: Product): ProductCard => ({
  id: product.id,
  name: product.name,
  priceLabel: pipe(product.price, applyDiscount(product.discountRate), formatWon),
})

export const toVisibleCards = ({ category }: ProductFilters) => (products: Product[]): ProductCard[] =>
  products.filter(isInStock).filter(isInCategory(category)).toSorted(byName).map(toCard)
```

Hooks compose hooks and pass partials to them.

```ts
// src/screens/products/model/useProductCards.ts
'use client'

import { useProducts, type ProductFilters } from '@/entities/product'

import { toVisibleCards } from './toVisibleCards'

export const useProductCards = (filters: ProductFilters) => useProducts(filters, toVisibleCards(filters))
```

`parseFilters` is pure and has no directive, because the route calls it on the server. These two files are the only stack-specific ones in the screen (Next.js here; see [Route files per stack](#route-files-per-stack)).

```ts
// src/screens/products/model/filters.ts
import type { ProductFilters } from '@/entities/product'

export const parseFilters = (params: URLSearchParams): ProductFilters => ({
  category: params.get('category') ?? 'all',
})
```

```ts
// src/screens/products/model/useProductFilters.ts
'use client'

import type { ProductFilters } from '@/entities/product'
import { useUrlState } from '@/shared/lib/useUrlState'

import { parseFilters } from './filters'

export const useProductFilters = () => {
  const [filters, update] = useUrlState(parseFilters)
  const setFilter = (key: keyof ProductFilters) => (value: string) => update({ [key]: value })
  return { filters, setFilter, clear: () => update({ category: undefined }) }
}
```

The mutation hook lives with the one screen that uses it, and invalidates through the entity's factory. A second screen moves it to `features/`. The endpoint is shared with the mobile app, so this goes over HTTP; a web-only form uses a Server Action (below).

```ts
// src/screens/products/api/useCreateProduct.ts
'use client'

import { useMutation, useQueryClient } from '@tanstack/react-query'

import { productKeys, type Product } from '@/entities/product'
import { postJson } from '@/shared/api/http'
import { API_URL } from '@/shared/config/env'

const createProduct = postJson<{ name: string }, Product>(`${API_URL}/api/products`)

export const useCreateProduct = () => {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: createProduct,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: productKeys.lists() }),
  })
}
```

```tsx
// src/screens/products/ui/ProductsScreen.tsx
'use client'

import { Screen } from '@/shared/ui/screen'

import { useProductCards } from '../model/useProductCards'
import { useProductFilters } from '../model/useProductFilters'
import { FilterBar } from './FilterBar'
import { ProductGrid } from './ProductGrid'

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

```ts
// src/screens/products/index.ts
export { parseFilters } from './model/filters'
export { ProductsScreen } from './ui/ProductsScreen'
export { ProductsSkeleton } from './ui/ProductsSkeleton'
```

## Feature: an action with a headless component

A feature holds one user action end to end: its request functions, its query, its hooks and a headless component. The products screen and `product-detail` both toggle a favorite, and each draws its own heart.

Predicates and transitions are curried, config first. An unloaded list stays unloaded: `setFavorited` returns `undefined` for it, because writing one id there would cache that id as the whole list.

```ts
// src/features/toggle-favorite/model/favorite.ts
export const hasFavorited = (productId: string) => (favoriteIds: string[]) => favoriteIds.includes(productId)

export const setFavorited = (productId: string, isFavorited: boolean) => (favoriteIds?: string[]) => {
  const others = favoriteIds?.filter((id) => id !== productId)
  return others && (isFavorited ? [...others, productId] : others)
}
```

```ts
// src/features/toggle-favorite/api/queries.ts
import { queryOptions } from '@tanstack/react-query'

import { createQueryKeys } from '@/shared/api/createQueryKeys'
import { getJson } from '@/shared/api/http'
import { API_URL } from '@/shared/config/env'

const fetchFavoriteIds = getJson<string[]>(`${API_URL}/api/favorites`)

export const favoriteKeys = createQueryKeys('favorites')

export const favoriteIdsOptions = () =>
  queryOptions({
    queryKey: favoriteKeys.lists(),
    queryFn: ({ signal }) => fetchFavoriteIds(undefined, { signal }),
    staleTime: 60_000,
  })
```

The mutation hook owns what a result means: here it writes the new state into the cache. The write goes through the options' `queryKey`, which carries the data type, so `setQueryData` checks the transition against it; a bare key from the factory leaves the write unchecked. Invalidation needs no type and uses the factory's prefix keys, as `useCreateProduct` does.

```ts
// src/features/toggle-favorite/api/useToggleFavorite.ts
'use client'

import { useMutation, useQueryClient } from '@tanstack/react-query'

import { postJson } from '@/shared/api/http'
import { API_URL } from '@/shared/config/env'

import { setFavorited } from '../model/favorite'
import { favoriteIdsOptions } from './queries'

const toggleFavorite = postJson<{ productId: string }, { isFavorited: boolean }>(`${API_URL}/api/favorites/toggle`)

export const useToggleFavorite = (productId: string) => {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: () => toggleFavorite({ productId }),
    onSuccess: ({ isFavorited }) =>
      queryClient.setQueryData(favoriteIdsOptions().queryKey, setFavorited(productId, isFavorited)),
  })
}
```

The state hook joins the query and the mutation into state and one named action. `select` takes the partial, so a card re-renders only when its own answer changes.

```ts
// src/features/toggle-favorite/model/useFavorite.ts
'use client'

import { useQuery } from '@tanstack/react-query'

import { favoriteIdsOptions } from '../api/queries'
import { useToggleFavorite } from '../api/useToggleFavorite'
import { hasFavorited } from './favorite'

export const useFavorite = (productId: string) => {
  const { data: isFavorited = false } = useQuery({ ...favoriteIdsOptions(), select: hasFavorited(productId) })
  const { mutate, isPending } = useToggleFavorite(productId)
  return { isFavorited, isPending, toggle: () => mutate() }
}
```

The headless component is one expression: it hands the hook's value to a function and draws nothing of its own.

```tsx
// src/features/toggle-favorite/ui/FavoriteToggle.tsx
'use client'

import type { ReactNode } from 'react'

import { useFavorite } from '../model/useFavorite'

export type FavoriteState = ReturnType<typeof useFavorite>

export const FavoriteToggle = ({
  productId,
  children,
}: {
  productId: string
  children: (favorite: FavoriteState) => ReactNode
}) => children(useFavorite(productId))
```

The request functions stay inside the slice; other slices use the hook or the component.

```ts
// src/features/toggle-favorite/index.ts
export { useFavorite } from './model/useFavorite'
export { FavoriteToggle } from './ui/FavoriteToggle'
export type { FavoriteState } from './ui/FavoriteToggle'
```

The behavior is the feature's and the markup is the screen's. `ProductGrid` renders one of these per card.

```tsx
// src/screens/products/ui/ProductCardItem.tsx
'use client'

import { FavoriteToggle } from '@/features/toggle-favorite'

import type { ProductCard } from '../model/toVisibleCards'
import { HeartButton } from './HeartButton'

export function ProductCardItem({ card }: { card: ProductCard }) {
  return (
    <article>
      <h3>{card.name}</h3>
      <p>{card.priceLabel}</p>
      <FavoriteToggle productId={card.id}>
        {({ isFavorited, isPending, toggle }) => (
          <HeartButton isFilled={isFavorited} disabled={isPending} onClick={toggle} />
        )}
      </FavoriteToggle>
    </article>
  )
}
```

## Feature: a form with a Server Action

A web-only form. The checks run inside the action, in order: who is calling, whether they may send now, whether the input is valid. A failure is a value carrying what the form needs back, because React resets the form when the action resolves. `currentUserId` and `isWithinRateLimit` are the project's own.

```ts
// src/features/send-message/api/message.server.ts
import 'server-only'

import { postJson } from '@/shared/api/http'

export const saveMessage = postJson<{ userId: string; email: string; body: string }, void>(
  `${process.env.API_URL}/messages`,
)
```

```ts
// src/features/send-message/api/sendMessage.actions.ts
'use server'

import { z } from 'zod'

import { currentUserId, isWithinRateLimit } from '@/shared/api/auth.server'

import { saveMessage } from './message.server'

const messageSchema = z.object({
  email: z.string().email(),
  body: z.string().min(10),
})

export type SendMessageResult = { ok: true } | { error: string; fields?: { email: string; body: string } }

export const sendMessage = async (_previous: SendMessageResult | null, formData: FormData): Promise<SendMessageResult> => {
  const userId = await currentUserId()
  if (!userId) return { error: 'Sign in again.' }
  if (!(await isWithinRateLimit(userId, 'send-message'))) return { error: 'Too many messages. Try again later.' }

  const fields = { email: String(formData.get('email') ?? ''), body: String(formData.get('body') ?? '') }
  const parsed = messageSchema.safeParse(fields)
  if (!parsed.success) return { error: 'Check your email and message.', fields }

  return saveMessage({ userId, ...parsed.data }).then(
    (): SendMessageResult => ({ ok: true }),
    (): SendMessageResult => ({ error: 'Could not send. Try again.', fields }),
  )
}
```

```tsx
// src/features/send-message/ui/SendMessageForm.tsx
'use client'

import { useActionState } from 'react'

import { sendMessage } from '../api/sendMessage.actions'

export function SendMessageForm() {
  const [result, submit, isPending] = useActionState(sendMessage, null)

  if (result && 'ok' in result) return <p>Message sent.</p>

  return (
    <form action={submit}>
      <fieldset disabled={isPending}>
        <input name="email" type="email" defaultValue={result?.fields?.email} required />
        <textarea name="body" defaultValue={result?.fields?.body} required />
        {result?.error && <p role="alert">{result.error}</p>}
        <button type="submit">{isPending ? 'Sending...' : 'Send'}</button>
      </fieldset>
    </form>
  )
}
```

```ts
// src/features/send-message/index.ts
export { SendMessageForm } from './ui/SendMessageForm'
```

## Store: state, pure transitions, selectors

Transitions are plain curried functions, so they test without React. The store holds state only, each component subscribes to what it needs, and nothing writes to it on the server.

```ts
// src/entities/cart/model/cart.ts
export type CartItem = { id: string; price: number; quantity: number }
export type CartState = { items: CartItem[] }

export const addItem = (item: CartItem) => (state: CartState): CartState => ({ items: [...state.items, item] })

export const removeItem = (id: string) => (state: CartState): CartState => ({
  items: state.items.filter((item) => item.id !== id),
})

export const selectTotal = ({ items }: CartState) => items.reduce((total, item) => total + item.price * item.quantity, 0)
```

```ts
// src/entities/cart/model/useCartStore.ts
'use client'

import { create } from 'zustand'

import { compose } from '@/shared/lib/fp'

import { addItem, removeItem, selectTotal, type CartItem, type CartState } from './cart'

export const useCartStore = create<CartState>()(() => ({ items: [] }))

export const useCartTotal = () => useCartStore(selectTotal)

export const removeFromCart = (id: string) => useCartStore.setState(removeItem(id))

export const swapItem = (oldId: string, item: CartItem) =>
  useCartStore.setState(compose(addItem(item), removeItem(oldId)))
```

```ts
// src/entities/cart/index.ts
export { removeFromCart, swapItem, useCartTotal } from './model/useCartStore'
export type { CartItem } from './model/cart'
```

Components read through selector hooks and change state through the bound actions, never `setState`. A selector returns a stored value or a primitive: Zustand re-renders when the result changes by `Object.is`, and a selector that builds an object changes on every call.

```ts
export const useCartTotal = () => useCartStore(selectTotal) // a primitive
export const useCartItems = () => useCartStore((state) => state.items) // the stored array itself

// ❌ A new object on every call: Zustand v5 loops until React throws
export const useCartSummary = () => useCartStore((state) => ({ count: state.items.length, total: selectTotal(state) }))

// ✅ Values that must travel together are compared shallowly (useShallow is in zustand/react/shallow)
export const useCartSummary = () =>
  useCartStore(useShallow((state) => ({ count: state.items.length, total: selectTotal(state) })))
```

## Flow hook

For real coordination: here the coupon's validity depends on the cart total, so the two concerns can't sit side by side in the screen. A hook that only merged two returns wouldn't earn its file.

```ts
// src/screens/cart/model/useCartFlow.ts
'use client'

import { useState } from 'react'

import { removeFromCart, useCartTotal } from '@/entities/cart'

const MINIMUM_FOR_COUPON = 10000

const useCoupon = (total: number) => {
  const [code, setCode] = useState('')
  return { code, setCode, isApplicable: code !== '' && total >= MINIMUM_FOR_COUPON }
}

export const useCartFlow = () => {
  const total = useCartTotal()
  const coupon = useCoupon(total)
  return { total, coupon, remove: removeFromCart }
}
```

## Route files per stack

The route file stays thin everywhere. On TanStack Start and Expo Router, only `filters.ts` and `useProductFilters` change, and the hook keeps the same interface, so the screen stays as written.

**Next.js.** Data loads with the route. The `await` sits in a child under Suspense so the shell renders first, and the options defined for the hook work here unchanged, `staleTime` included, so the hydrated data isn't fetched again on mount. `error.tsx` beside this file gives the region its error boundary.

```tsx
// src/app/products/page.tsx
import { dehydrate, HydrationBoundary, QueryClient } from '@tanstack/react-query'
import { Suspense } from 'react'

import { productListOptions } from '@/entities/product'
import { parseFilters, ProductsScreen, ProductsSkeleton } from '@/screens/products'

type Props = { searchParams: Promise<Record<string, string>> }

async function ProductsData({ searchParams }: Props) {
  const filters = parseFilters(new URLSearchParams(await searchParams))
  const queryClient = new QueryClient()
  await queryClient.prefetchQuery(productListOptions(filters))

  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <ProductsScreen />
    </HydrationBoundary>
  )
}

export default function Page(props: Props) {
  return (
    <Suspense fallback={<ProductsSkeleton />}>
      <ProductsData {...props} />
    </Suspense>
  )
}
```

**TanStack Start.** `getRouteApi` lets the hook reach route state without importing the route file, which would be an upward import. Load data in the route's `loader` with `productListOptions`; for the API, see the `router-query` skill inside the installed `@tanstack/react-router`.

```tsx
// src/routes/products.tsx (TanStack Start)
import { createFileRoute } from '@tanstack/react-router'

import { parseFilters, ProductsScreen } from '@/screens/products'

export const Route = createFileRoute('/products')({
  validateSearch: parseFilters,
  component: ProductsScreen,
})
```

```ts
// src/screens/products/model/filters.ts (TanStack Start)
import type { ProductFilters } from '@/entities/product'

export const parseFilters = (search: Record<string, unknown>): ProductFilters => ({
  category: typeof search.category === 'string' ? search.category : 'all',
})
```

```ts
// src/screens/products/model/useProductFilters.ts (TanStack Start)
import { getRouteApi } from '@tanstack/react-router'

import type { ProductFilters } from '@/entities/product'

const route = getRouteApi('/products')

export const useProductFilters = () => {
  const filters = route.useSearch()
  const navigate = route.useNavigate()
  const setFilter = (key: keyof ProductFilters) => (value: string) =>
    navigate({ search: (previous) => ({ ...previous, [key]: value }) })
  return { filters, setFilter, clear: () => navigate({ search: { category: 'all' } }) }
}
```

**Expo Router.** Every file in the route folder becomes a route, so nothing but route files goes there. A `_layout` is routing too: its navigator and route names stay in it, and it imports providers from below. Deep-link params are untrusted, so they go through `parseFilters`.

`toSorted` and `Intl` in `toVisibleCards` need the app's Hermes to ship them; otherwise copy before sorting and load a polyfill first. Wire TanStack Query's `focusManager` to `AppState` and `onlineManager` to NetInfo or `expo-network` once in `providers/`, or queries won't refetch when the app returns or reconnects.

```tsx
// src/app/products.tsx (Expo Router)
export { ProductsScreen as default } from '@/screens/products'
```

```ts
// src/screens/products/model/filters.ts (Expo Router)
import type { ProductFilters } from '@/entities/product'

export const parseFilters = ({ category }: { category?: string | string[] }): ProductFilters => ({
  category: typeof category === 'string' ? category : 'all',
})
```

```ts
// src/screens/products/model/useProductFilters.ts (Expo Router)
import { router, useLocalSearchParams } from 'expo-router'

import type { ProductFilters } from '@/entities/product'

import { parseFilters } from './filters'

export const useProductFilters = () => {
  const filters = parseFilters(useLocalSearchParams())
  const setFilter = (key: keyof ProductFilters) => (value: string) => router.setParams({ [key]: value })
  return { filters, setFilter, clear: () => router.setParams({ category: undefined }) }
}
```
