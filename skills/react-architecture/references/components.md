# Component Patterns

Hooks are the unit of logic. Everything here delivers a hook's value to markup and holds no logic the hook doesn't: a render prop hands it to a function, a slot to the region it fills, a context to the subtree that reads it. Each entry says when to use it, when not, and how it stays functional. Each block's first line is its path; *(shape)* marks code with details left out. Multi-part blocks and state reducers are in `compound.md`, HoCs in `hocs.md`, and the slice these sit beside in `examples.md`.

## Table of Contents

1. [Hooks first](#hooks-first)
2. [Headless components with render props](#headless-components-with-render-props)
3. [Slots](#slots)
4. [Narrow contexts split by change rate](#narrow-contexts-split-by-change-rate)
5. [Pitfalls](#pitfalls)

## Hooks first

- **Use:** always, before any other pattern. One responsibility per hook; the main component calls two or three and composes.
- **Not:** a hook that only merges other hooks' returns, or one that returns markup.
- **Functional:** the hook is the effect edge. What it computes is a pure function beside it in `model/`, testable without React.

```ts
// A data hook returns the query result as is. select takes a partial
const { data: cards = [], isPending, error, refetch } = useProducts(filters, toVisibleCards(filters))

// A state hook returns the state and named actions
const { isFavorited, isPending, toggle } = useFavorite(productId)
```

Call the hook in the lowest component that reads its value. The patterns below exist for the cases a leaf can't cover cleanly.

## Headless components with render props

- **Use:** a block or feature ships behavior and the screen owns the markup; or a fast-changing value must re-render only the subtree that reads it.
- **Not:** one screen reads the value and its markup is fixed: call the hook in a leaf component.
- **Functional:** UI = f(state). `children` is a function of exactly the hook's value, the component draws nothing of its own, and the whole component is one expression: `({ children, ...config }) => children(useX(config))`.

A sale countdown ticks every second. Read at the top of a screen it re-renders the whole screen on each tick; a render prop scopes it to the subtree that shows it, the same way on every screen, without a one-off leaf. `useRemainingSec` is an interval subscription in the block's `model/`.

```tsx
// src/blocks/sale/ui/SaleCountdown.tsx
'use client'

import type { ReactNode } from 'react'

import { useRemainingSec } from '../model/useRemainingSec'

/** Seconds left in the sale. It changes every second, so only what's under children renders again */
export const SaleCountdown = ({
  endsAt,
  children,
}: {
  endsAt: number
  children: (remainingSec: number) => ReactNode
}) => children(useRemainingSec(endsAt))
```

```tsx
// src/screens/products/ui/ProductsScreen.tsx (shape: the countdown added to the screen in examples.md)
    <Screen>
      <SaleCountdown endsAt={saleEndsAt}>
        {(remainingSec) => <SaleBanner remainingSec={remainingSec} />}
      </SaleCountdown>
      <FilterBar category={filters.category} onCategoryChange={setFilter('category')} onClear={clear} />
      <ProductGrid cards={cards} isPending={isPending} error={error} onRetry={refetch} />
    </Screen>
```

The banner renders every second; the filter bar and the grid don't.

A feature ships an action the same way. `toggle-favorite` owns the query, the mutation and the cache write, and every screen draws its own heart: `FavoriteToggle` and a screen using it are in `examples.md`.

A render prop is a plain function, so it calls no hooks. A row that needs one renders a component:

```tsx
// ❌ A hook inside a render prop: the hooks lint rejects it, and the number of calls can change between renders
<PurchasePanel.Options>
  {({ option, isSelected, select }) => {
    const stock = useStock(option.id)
    return <OptionCard option={option} stock={stock} isSelected={isSelected} onSelect={select} />
  }}
</PurchasePanel.Options>

// ✅ The row is a component, and the component calls the hook
<PurchasePanel.Options>
  {({ option, isSelected, select }) => <StockedOptionCard option={option} isSelected={isSelected} onSelect={select} />}
</PurchasePanel.Options>
```

A function can't cross from a Server Component to a Client Component, so the file that passes a render prop is a Client Component: a leaf under a server screen, or the screen itself.

## Slots

- **Use:** a layout block with regions the screen fills. A slot is a prop: `ReactNode` for fixed markup, a function when the slot needs the block's state.
- **Not:** parts the screen reorders or leaves out: those are compound parts (`compound.md`).
- **Functional:** the layout is a function of its slots; a function slot is a render prop scoped to one region.

```tsx
// src/blocks/product-page/ui/ProductPageLayout.tsx
'use client'

import type { ReactNode } from 'react'

import { useScrolledPast } from '../model/useScrolledPast'

const HERO_HEIGHT = 480

export type ProductPageLayoutState = { isPastHero: boolean }

export function ProductPageLayout({
  header,
  action,
  children,
}: {
  header: ReactNode
  action: (layout: ProductPageLayoutState) => ReactNode
  children: ReactNode
}) {
  const isPastHero = useScrolledPast(HERO_HEIGHT)
  return (
    <div>
      {header}
      <main>{children}</main>
      <footer>{action({ isPastHero })}</footer>
    </div>
  )
}
```

```ts
// src/blocks/product-page/model/useScrolledPast.ts
'use client'

import { useSyncExternalStore } from 'react'

const subscribeToScroll = (onChange: () => void) => {
  window.addEventListener('scroll', onChange, { passive: true })
  return () => window.removeEventListener('scroll', onChange)
}

/** Subscribes to the boolean, not the pixel value, so it renders again only when the offset is crossed */
export const useScrolledPast = (offset: number) =>
  useSyncExternalStore(
    subscribeToScroll,
    () => window.scrollY > offset,
    () => false,
  )
```

```tsx
// src/screens/product-detail/ui/ProductDetailScreen.tsx (shape)
    <ProductPageLayout
      header={<ProductHeader name={product.name} />}
      action={({ isPastHero }) => <BuyBar isCompact={isPastHero} />}
    >
      <ProductGallery productId={product.id} />
      <ProductPurchase productId={product.id} options={options} />
    </ProductPageLayout>
```

The layout renders again when the hero scrolls out; `header` and `children` are the screen's elements, so they don't.

## Narrow contexts split by change rate

- **Use:** values a subtree reads that change at different speeds: a checkout's settings (rarely), its quote (on each address or coupon change), the cart hold timer (every second).
- **Not:** server data (TanStack Query), app-wide state (Zustand), or a value one component reads (a hook).
- **Functional:** each context value is a function of the provider's inputs, memoized on exactly those inputs; consumers are pure functions of the slice they read.

```tsx
// src/features/checkout/ui/CheckoutProvider.tsx (shape)
export function CheckoutProvider({ cart, children }: { cart: Cart; children: ReactNode }) {
  const core = useCheckoutCore(cart) // rarely changes within the flow
  const quote = useCheckoutQuote(cart) // on each address or coupon change
  return (
    <CheckoutCoreContext value={core}>
      <CheckoutQuoteContext value={quote}>
        <CartHoldProvider cartId={cart.id}>{children}</CartHoldProvider>
      </CheckoutQuoteContext>
    </CheckoutCoreContext>
  )
}

/** The hold timer ticks every second, so it counts in a provider of its own: only this component renders again */
function CartHoldProvider({ cartId, children }: { cartId: string; children: ReactNode }) {
  const hold = useCartHoldTimer(cartId)
  return <CartHoldContext value={hold}>{children}</CartHoldContext>
}

export const useCartHold = () => {
  const hold = use(CartHoldContext)
  if (!hold) throw new Error('useCartHold must be used inside <CheckoutProvider>')
  return hold
}
```

Screens read only the narrow hook they need. A hook or context that merges them back renders every reader again whenever any of them changes. A block that splits one hook's value across its parts does the same thing with memoized slices: `compound.md`.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| "Rendered more hooks than during the previous render" | A hook inside a render prop | A row that needs a hook is a component |
| The whole screen renders again every second | A countdown or live count read at the top of the screen | A leaf, a render prop (`SaleCountdown`), or a provider of its own |
| Every reader renders again when any flow value changes | A hook or context that merges the narrow ones back | Read only the narrow hook you need |
| "Functions cannot be passed directly to Client Components" | A render prop passed from a Server Component | Pass it from a client leaf |
