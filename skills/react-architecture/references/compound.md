# Compound Parts and State Reducers

A multi-part block hands each part its own slice of state, and the screen arranges the parts and owns their markup. Two blocks show it: a purchase panel (`PurchasePanel.Root / .Options / .Price / .Buy`) and a step form (`StepForm.Root / .Step`), whose transitions a screen can change with a state reducer. Each block's first line is its path; *(shape)* marks code with details left out. Single-value render props, slots and contexts are in `components.md`.

This is the logic side of a compound block: where its state lives and how each part receives it. The part API of a presentational `shared/ui` component (variants, the controlled trio, accessibility) follows design-system, if available.

## Table of Contents

1. [Compound parts with render props](#compound-parts-with-render-props)
2. [A second state source](#a-second-state-source)
3. [State reducer and controlled props](#state-reducer-and-controlled-props)
4. [Pitfalls](#pitfalls)

## Compound parts with render props

- **Use:** a block with several parts the screen arranges, leaves out or restyles.
- **Not:** a block with one part: a single render prop is enough. Not for layout regions either: those are slots (`components.md`).
- **Functional:** the block's hook computes slices with pure mappers; each part is `children(useSlice())`, a function of one context; the screen's children functions are functions of one part's state.

The anatomy:

1. **The block's hook** reads what the block needs once and returns slices split by change rate, each memoized on the fields it carries. A memo holds only while the handlers it carries keep their identity, so the hook that owns a handler keeps it stable.
2. **One context per slice**, each with a narrow hook that throws outside `Root`.
3. **`Root`** calls the hook and provides the contexts. Its `children` are the screen's elements, so when `Root` renders again only the parts whose context changed follow.
4. **Each part** is a thin headless view: with no children it renders the block's default UI, with a function as children it hands over exactly its state. Defaults are module-level pure functions.
5. **Policy stays in the part.** Markup the block must guarantee (a consent line, a platform split) sits outside the children call, so a screen's markup can't drop it.
6. **Parts are exported by name,** each with a `displayName`, and the slice's `index.ts` re-exports them as one namespace. A Server Component can dot into a namespace of named exports; it can't dot into a `const PurchasePanel = { Root, … }` object from a client module.

Pure mappers turn the block's inputs into what the parts render. Each takes only what it reads, so the hook can memoize on exactly that.

```ts
// src/blocks/purchase/model/purchasePanel.ts
export type PurchaseOption = { id: string; label: string; price: number; listPrice: number }

/** What each part reads. They change at different times, so each gets a context of its own */
export type PanelOptions = {
  options: PurchaseOption[]
  selectedId: string | undefined
  select: (id: string) => () => void
}
export type PanelPrice = { price: number; listPrice: number; discountPercent: number }
export type PanelBuy = { price: number; isPending: boolean; buy: () => void }

const toDiscountPercent = (listPrice: number, price: number) =>
  listPrice > 0 ? Math.round((1 - price / listPrice) * 100) : 0

export const toPanelPrice = (option?: PurchaseOption): PanelPrice => {
  const { price, listPrice } = option ?? { price: 0, listPrice: 0 }
  return { price, listPrice, discountPercent: toDiscountPercent(listPrice, price) }
}
```

Selecting an option changes all three slices; a pending order changes `buy` alone, so the cards and the price stay as they are while the request runs. `usePlaceOrder` is a feature's mutation hook, shaped like `useCreateProduct` in `examples.md`; its `mutate` and React's state setter keep their identity, which is what lets the memos hold.

```ts
// src/blocks/purchase/model/usePurchasePanel.ts
'use client'

import { useMemo, useState } from 'react'

import { usePlaceOrder } from '@/features/place-order'

import { toPanelPrice, type PanelBuy, type PanelOptions, type PanelPrice, type PurchaseOption } from './purchasePanel'

export const usePurchasePanel = (productId: string, purchaseOptions: PurchaseOption[]) => {
  const [pickedId, setPickedId] = useState<string>()
  const { mutate: placeOrder, isPending } = usePlaceOrder()
  // Derived, not synced: options that arrive late or change fall back to the first one without an effect
  const selected = purchaseOptions.find(({ id }) => id === pickedId) ?? purchaseOptions[0]

  const options = useMemo(
    (): PanelOptions => ({
      options: purchaseOptions,
      selectedId: selected?.id,
      select: (id) => () => setPickedId(id),
    }),
    [purchaseOptions, selected],
  )
  const price = useMemo((): PanelPrice => toPanelPrice(selected), [selected])
  const buy = useMemo(
    (): PanelBuy => ({
      price: price.price,
      isPending,
      buy: () => {
        if (selected) placeOrder({ productId, optionId: selected.id })
      },
    }),
    [price.price, isPending, placeOrder, productId, selected],
  )

  return { options, price, buy }
}
```

```ts
// src/blocks/purchase/model/purchasePanelContext.ts
'use client'

import { createContext, use, type Context } from 'react'

import type { PanelBuy, PanelOptions, PanelPrice } from './purchasePanel'

export const PanelOptionsContext = createContext<PanelOptions | null>(null)
export const PanelPriceContext = createContext<PanelPrice | null>(null)
export const PanelBuyContext = createContext<PanelBuy | null>(null)

const usePart = <T,>(context: Context<T | null>, part: string): T => {
  const value = use(context)
  if (!value) throw new Error(`<PurchasePanel.${part}> must be inside <PurchasePanel.Root>`)
  return value
}

export const usePanelOptions = () => usePart(PanelOptionsContext, 'Options')
export const usePanelPrice = () => usePart(PanelPriceContext, 'Price')
export const usePanelBuy = () => usePart(PanelBuyContext, 'Buy')
```

`Options` calls its children once per card, with `select` already applied to that card. `Buy` hands over `{ price, isPending, buy }` and keeps the terms line to itself.

```tsx
// src/blocks/purchase/ui/PurchasePanel.tsx
'use client'

import { Fragment, type ReactNode } from 'react'

import type { PanelBuy, PanelPrice, PurchaseOption } from '../model/purchasePanel'
import {
  PanelBuyContext,
  PanelOptionsContext,
  PanelPriceContext,
  usePanelBuy,
  usePanelOptions,
  usePanelPrice,
} from '../model/purchasePanelContext'
import { usePurchasePanel } from '../model/usePurchasePanel'
import { BuyButton } from './BuyButton'
import { OptionCard } from './OptionCard'
import { PriceSummary } from './PriceSummary'
import { TermsNotice } from './TermsNotice'

/** Everything one card needs. Options calls its children once per card */
export type OptionState = { option: PurchaseOption; isSelected: boolean; select: () => void }

// The default UI of a part with no children: pure functions, no hooks
const renderOption = ({ option, isSelected, select }: OptionState) => (
  <OptionCard option={option} isSelected={isSelected} onSelect={select} />
)
const renderPrice = (price: PanelPrice) => <PriceSummary {...price} />
const renderBuy = ({ price, isPending, buy }: PanelBuy) => (
  <BuyButton price={price} disabled={isPending} onClick={buy} />
)

export function Root({
  productId,
  options,
  children,
}: {
  productId: string
  options: PurchaseOption[]
  children: ReactNode
}) {
  const panel = usePurchasePanel(productId, options)
  return (
    <PanelOptionsContext value={panel.options}>
      <PanelPriceContext value={panel.price}>
        <PanelBuyContext value={panel.buy}>{children}</PanelBuyContext>
      </PanelPriceContext>
    </PanelOptionsContext>
  )
}

export function Options({ children = renderOption }: { children?: (state: OptionState) => ReactNode }) {
  const { options, selectedId, select } = usePanelOptions()
  return options.map((option) => (
    <Fragment key={option.id}>
      {children({ option, isSelected: option.id === selectedId, select: select(option.id) })}
    </Fragment>
  ))
}

export const Price = ({ children = renderPrice }: { children?: (price: PanelPrice) => ReactNode }) =>
  children(usePanelPrice())

// The terms line is policy: whatever a screen draws for the button, it can't drop the line
export function Buy({ children = renderBuy }: { children?: (buy: PanelBuy) => ReactNode }) {
  const buy = usePanelBuy()
  return (
    <>
      {children(buy)}
      <TermsNotice />
    </>
  )
}

Root.displayName = 'PurchasePanel.Root'
Options.displayName = 'PurchasePanel.Options'
Price.displayName = 'PurchasePanel.Price'
Buy.displayName = 'PurchasePanel.Buy'
```

```ts
// src/blocks/purchase/index.ts
export * as PurchasePanel from './ui/PurchasePanel'
export type { OptionState } from './ui/PurchasePanel'
export type { PanelBuy, PanelPrice, PurchaseOption } from './model/purchasePanel'
```

The screen arranges the parts and owns every pixel it cares about: here the price moves above the cards, `Options` and `Buy` take render props, and `Price` keeps the default UI.

```tsx
// src/screens/product-detail/ui/ProductPurchase.tsx
'use client'

import { PurchasePanel, type PurchaseOption } from '@/blocks/purchase'

import { BundleCard } from './BundleCard'

const wonFormat = new Intl.NumberFormat('ko-KR')

export function ProductPurchase({ productId, options }: { productId: string; options: PurchaseOption[] }) {
  return (
    <PurchasePanel.Root productId={productId} options={options}>
      <PurchasePanel.Price />
      <PurchasePanel.Options>
        {({ option, isSelected, select }) => <BundleCard option={option} isSelected={isSelected} onSelect={select} />}
      </PurchasePanel.Options>
      <PurchasePanel.Buy>
        {({ price, isPending, buy }) => (
          <button type="button" disabled={isPending} onClick={buy}>
            Buy for {wonFormat.format(price)}원
          </button>
        )}
      </PurchasePanel.Buy>
    </PurchasePanel.Root>
  )
}
```

With no children, every part draws the block's default, and that arrangement works in a Server Component too. A render prop is a function, so the arrangement above needs a Client Component.

```tsx
<PurchasePanel.Root productId={product.id} options={options}>
  <PurchasePanel.Options />
  <PurchasePanel.Price />
  <PurchasePanel.Buy />
</PurchasePanel.Root>
```

As parts, a variant is the screen's own markup, and the block carries no product branch or `variant` prop.

## A second state source

The same parts serve another source of state: a subscription checkout beside one-off orders. Each inner root calls its own hook unconditionally and fills the same three contexts; `Root` chooses which component renders, never which hook runs. The parts, and every screen's arrangement of them, stay as they are.

```tsx
// src/blocks/purchase/ui/PurchasePanel.tsx (shape: a second state source)
type RootProps = { productId: string; options: PurchaseOption[]; children: ReactNode }

// Filling the three contexts doesn't depend on where the state comes from
function PanelContexts({ panel, children }: { panel: ReturnType<typeof usePurchasePanel>; children: ReactNode }) {
  return (
    <PanelOptionsContext value={panel.options}>
      <PanelPriceContext value={panel.price}>
        <PanelBuyContext value={panel.buy}>{children}</PanelBuyContext>
      </PanelPriceContext>
    </PanelOptionsContext>
  )
}

const OrderRoot = ({ productId, options, children }: RootProps) => (
  <PanelContexts panel={usePurchasePanel(productId, options)}>{children}</PanelContexts>
)
const SubscriptionRoot = ({ productId, options, children }: RootProps) => (
  <PanelContexts panel={useSubscriptionPanel(productId, options)}>{children}</PanelContexts>
)

export function Root({ billing, ...props }: RootProps & { billing: 'once' | 'monthly' }) {
  return billing === 'monthly' ? <SubscriptionRoot {...props} /> : <OrderRoot {...props} />
}
```

## State reducer and controlled props

- **Use:** a screen must change how a block moves between states without forking it.
- **Not:** a block whose transitions never vary: keep the reducer internal.
- **Functional:** transitions are a pure reducer `(state, action) => state`. The block takes an optional `reduce`; a screen passes a reducer that wraps the default one, like a decorator.

`StepForm` is a second compound block: `Root` holds the step, and each `Step` renders only when active and hands its children `{ isLast, next, back }`.

```ts
// src/blocks/step-form/model/stepForm.ts
export type StepFormState = { step: number; stepCount: number }
export type StepFormAction = { type: 'next' } | { type: 'back' } | { type: 'go'; step: number }
export type StepFormReducer = (state: StepFormState, action: StepFormAction) => StepFormState

/** A step outside the range snaps to the first or the last one */
const clampStep = (step: number, stepCount: number) => Math.min(Math.max(step, 0), stepCount - 1)

const targetOf = ({ step }: StepFormState, action: StepFormAction) => {
  switch (action.type) {
    case 'next':
      return step + 1
    case 'back':
      return step - 1
    case 'go':
      return action.step
  }
}

export const reduceStepForm: StepFormReducer = (state, action) => ({
  ...state,
  step: clampStep(targetOf(state, action), state.stepCount),
})
```

`model/stepFormContext.ts` follows the panel's context file with a single context: `StepFormContext` holds `{ step, stepCount, dispatch }`, and `useStepForm()` throws outside `Root`. The reducer is a plain function, so `Root` decides where the state lives: here a `(prev) => next` update on `useState`; a step that should survive a shared link is read from the URL, and the same `reduce` computes the next one.

```tsx
// src/blocks/step-form/ui/StepForm.tsx
'use client'

import { useState, type ReactNode } from 'react'

import { reduceStepForm, type StepFormAction, type StepFormReducer } from '../model/stepForm'
import { StepFormContext, useStepForm } from '../model/stepFormContext'

export type StepState = { isLast: boolean; next: () => void; back: () => void }

export function Root({
  stepCount,
  reduce = reduceStepForm,
  children,
}: {
  stepCount: number
  reduce?: StepFormReducer
  children: ReactNode
}) {
  const [step, setStep] = useState(0)
  const dispatch = (action: StepFormAction) =>
    setStep((current) => reduce({ step: current, stepCount }, action).step)
  return <StepFormContext value={{ step, stepCount, dispatch }}>{children}</StepFormContext>
}

export function Step({ index, children }: { index: number; children: (state: StepState) => ReactNode }) {
  const form = useStepForm()
  if (form.step !== index) return null
  return children({
    isLast: index === form.stepCount - 1,
    next: () => form.dispatch({ type: 'next' }),
    back: () => form.dispatch({ type: 'back' }),
  })
}

Root.displayName = 'StepForm.Root'
Step.displayName = 'StepForm.Step'
```

`Root` doesn't memoize its value: it provides one context, not slices of one value, and the value changes exactly when `Root` renders for its own reason (the step); when the screen renders again, the `Step` elements are new anyway.

```ts
// src/blocks/step-form/index.ts
export * as StepForm from './ui/StepForm'
export type { StepState } from './ui/StepForm'
export { reduceStepForm } from './model/stepForm'
export type { StepFormReducer } from './model/stepForm'
```

A screen skips a step by wrapping the default reducer:

```ts
// src/screens/checkout/model/steps.ts
import { reduceStepForm, type StepFormReducer } from '@/blocks/step-form'

const SHIPPING_STEP = 1

/** A digital order has nothing to ship: a move that lands on shipping goes one step further the same way */
export const skipShipping =
  (isDigital: boolean): StepFormReducer =>
  (state, action) => {
    const next = reduceStepForm(state, action)
    return isDigital && next.step === SHIPPING_STEP
      ? reduceStepForm(next, action.type === 'back' ? action : { type: 'next' })
      : next
  }
```

```tsx
// src/screens/checkout/ui/CheckoutSteps.tsx
'use client'

import { StepForm } from '@/blocks/step-form'

import { skipShipping } from '../model/steps'
import { AddressFields } from './AddressFields'
import { PaymentFields } from './PaymentFields'
import { ShippingFields } from './ShippingFields'

export function CheckoutSteps({ currency, isDigital }: { currency: string; isDigital: boolean }) {
  return (
    <StepForm.Root stepCount={3} reduce={skipShipping(isDigital)}>
      <StepForm.Step index={0}>{({ next }) => <AddressFields onDone={next} />}</StepForm.Step>
      <StepForm.Step index={1}>
        {({ next, back }) => <ShippingFields onDone={next} onBack={back} />}
      </StepForm.Step>
      <StepForm.Step index={2}>
        {({ back, isLast }) => <PaymentFields currency={currency} isLast={isLast} onBack={back} />}
      </StepForm.Step>
    </StepForm.Root>
  )
}
```

**Controlled props** are the other way to hand a screen control: the block takes `step` and `onStepChange` and uses them over its own state when given. Pick one per block: a reducer when the screen adjusts transitions, controlled props when the screen owns the value.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Every part renders again on any change | Context slices built inline, one merged context, or a handler rebuilt every render | Split by change rate; memoize each slice on the fields it carries; keep handlers stable where they're made |
| A screen's markup dropped something the block must show | The part left it to the children function | The part renders it outside the children call |
| "Element type is invalid … got: undefined" where a Server Component renders `PurchasePanel.Root` | The parts are a `const PurchasePanel = { Root, … }` object in a client module, and a Server Component can't dot into it | Export the parts by name and re-export them as a namespace |
