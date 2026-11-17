# HoCs

An HoC adds one effect or one decision around the screen it wraps: page views, gates, guards, or slow context values handed in as props. It is not for logic the markup computes (that's a hook), or for anything that varies per render. Each block's first line is its path.

**Functional:** an HoC is a curried higher-order function, config first. `withPageView(spec)` is a partial waiting for a component; applying it at module scope builds the wrapped screen once.

Why the rules in SKILL.md hold:

- **Module scope, never in render:** a new component type each render remounts the subtree and loses its state.
- **Hooks before any early return:** a gate decides after its hook, never before, or the hook count changes between renders.
- **Effects run after the wrapped screen's (children first).** An effect that must stay ordered against the screen's own effects stays in the screen.
- **`displayName` is `with<Name>(<Inner>)`,** for React DevTools and error component stacks.
- **Client only:** an HoC that calls hooks lives in a client file and wraps a client screen. On a Server Component screen the same concern is a client leaf (`<PageView spec={…} />`).
- **Placement:** an HoC starts in the screen file that uses it; at the second consumer it moves to the lowest layer that can import what it reads.

## Table of Contents

1. [Page view](#page-view)
2. [Gate](#gate)
3. [Context values as props](#context-values-as-props)
4. [Stacking](#stacking)
5. [Pitfalls](#pitfalls)

## Page view

`withPageView` reads nothing but the analytics sink, so it lives in `shared/`. The spec is a constant in the screen file, so its identity is stable and the effect fires once per mount. A screen whose own entry effect must come after the page view calls `usePageView` itself, first. `track` is the project's own.

```tsx
// src/shared/lib/analytics/withPageView.tsx
'use client'

import { useEffect, type ComponentType } from 'react'

import { track } from './track'

export type PageViewSpec = { page: string }

export const usePageView = (spec: PageViewSpec) => {
  useEffect(() => {
    track('page_view', spec)
  }, [spec])
}

/** The screen's entry event. The wrapped screen's own effects run before this one (children first) */
export const withPageView =
  (spec: PageViewSpec) =>
  <P extends object>(Screen: ComponentType<P>) => {
    const WithPageView = (props: P) => {
      usePageView(spec)
      return <Screen {...props} />
    }
    WithPageView.displayName = `withPageView(${Screen.displayName ?? Screen.name})`
    return WithPageView
  }
```

## Gate

The hook runs on every render; the decision comes after it. A gate only decides what renders: the server still checks who may read the data. `useSession` is an entity's query hook.

```tsx
// src/features/sign-in/ui/withSignInGate.tsx
'use client'

import type { ComponentType } from 'react'

import { useSession } from '@/entities/session'

import { SignInPrompt } from './SignInPrompt'

/** Draws the sign-in prompt in place of the screen. The hook is called before any return */
export const withSignInGate = <P extends object>(Screen: ComponentType<P>) => {
  const WithSignInGate = (props: P) => {
    const { data: session, isPending } = useSession()
    if (isPending) return null
    return session ? <Screen {...props} /> : <SignInPrompt />
  }
  WithSignInGate.displayName = `withSignInGate(${Screen.displayName ?? Screen.name})`
  return WithSignInGate
}
```

## Context values as props

`pick` is a pure function from a context to props, so the wrapped screen renders from props alone and tests without the provider. Only slow values belong here: the HoC renders the whole screen again when what it picks changes, so a value that ticks is read in a leaf. The Core context is the checkout's slow slice (`components.md`).

```tsx
// src/features/checkout/ui/withCheckoutCore.tsx
'use client'

import type { ComponentType } from 'react'

import { useCheckoutCore, type CheckoutCore } from '../model/checkoutContext'

/** Hands the screen what pick takes from the Core context */
export const withCheckoutCore =
  <C extends object>(pick: (core: CheckoutCore) => C) =>
  <P extends C>(Screen: ComponentType<P>) => {
    const WithCheckoutCore = (props: Omit<P, keyof C>) => {
      const picked = pick(useCheckoutCore())
      // Omit<P, keyof C> & C is P. TypeScript can't prove that for a generic P, so the one assertion lives here
      return <Screen {...({ ...props, ...picked } as P)} />
    }
    WithCheckoutCore.displayName = `withCheckoutCore(${Screen.displayName ?? Screen.name})`
    return WithCheckoutCore
  }
```

## Stacking

Stack with `pipe(Screen, inner, outer)`. The screen exists, so it's functional rule 3's `pipe`, and TypeScript infers each generic HoC forward from the screen's props. `compose` infers right to left, so a generic HoC there gets `unknown`.

```tsx
// ❌ 'unknown' is not a valid JSX element type
export default compose(withSignInGate, withPageView(CHECKOUT_PAGE_VIEW))(CheckoutScreen)

// ✅ Inner first: the screen, the page view, the gate
export default pipe(CheckoutScreen, withPageView(CHECKOUT_PAGE_VIEW), withSignInGate)
```

Order is behavior. The last HoC is the outermost and renders first: here the gate decides before the page view mounts, so only signed-in visitors fire it. Swap them and every visitor counts.

The file's default export is the screen with its stack, and the slice's `index.ts` re-exports it under the screen's name (`export { default as CheckoutScreen } from './ui/CheckoutScreen'`). `CheckoutSteps` is in `compound.md`.

```tsx
// src/screens/checkout/ui/CheckoutScreen.tsx
'use client'

import { withCheckoutCore, type CheckoutCore } from '@/features/checkout'
import { withSignInGate } from '@/features/sign-in'
import { withPageView, type PageViewSpec } from '@/shared/lib/analytics/withPageView'
import { pipe } from '@/shared/lib/fp'

import { CheckoutSteps } from './CheckoutSteps'

const CHECKOUT_PAGE_VIEW: PageViewSpec = { page: 'checkout' }

const pickCheckoutProps = ({ currency, isDigital }: CheckoutCore) => ({ currency, isDigital })

/** Core values arrive as props, so this component reads no context of its own */
function CheckoutScreen({ currency, isDigital }: ReturnType<typeof pickCheckoutProps>) {
  return <CheckoutSteps currency={currency} isDigital={isDigital} />
}

// Inner first: the screen, its Core values, the page view, the gate
export default pipe(
  CheckoutScreen,
  withCheckoutCore(pickCheckoutProps),
  withPageView(CHECKOUT_PAGE_VIEW),
  withSignInGate,
)
```

A stack many screens share is itself a curried function, placed by the same layer rule as its parts:

```tsx
export const withMemberPage =
  (spec: PageViewSpec) =>
  <P extends object>(Screen: ComponentType<P>) =>
    pipe(Screen, withPageView(spec), withSignInGate)
```

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| A subtree remounts and loses its state | An HoC applied inside render | Apply HoCs at module scope |
| `'unknown' is not a valid JSX element type` | `compose(outer, inner)(Screen)` with generic HoCs | `pipe(Screen, inner, outer)` |
| "Rendered more hooks than during the previous render" | A hook after a gate's early return | Hooks first, decision after |
| Events fire in a different order after a refactor | An effect moved into an HoC, which runs after the screen's effects | Keep order-sensitive effects in the screen |
| "Attempted to call withPageView() from the server" | An HoC applied in a Server Component file | Apply it in the client screen's file, or use a client leaf |
