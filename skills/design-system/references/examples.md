# Design System Examples

One system, file by file: the token file, the theme at first paint, five primitives, then a screen and a form built from them. Each block's first line is its path; *(shape)* marks code with details left out. The stack is Tailwind v4, `class-variance-authority` and Base UI on React 19; another engine or library keeps the shapes and changes the syntax (`stack.md`). Hex values are placeholders: swap in the product's and run the token test (`lib.md`).

## Table of Contents

1. [Tokens](#tokens)
2. [Theme at first paint](#theme-at-first-paint)
3. [Button: one look union, separate contracts](#button-one-look-union-separate-contracts)
4. [Field: the wiring is built in](#field-the-wiring-is-built-in)
5. [Dialog: bought behavior](#dialog-bought-behavior)
6. [Card: parts without state](#card-parts-without-state)
7. [In a screen](#in-a-screen)
8. [States](#states)

## Tokens

The only file that holds values. Three layers, top to bottom: scales no theme changes, one block of roles per theme, and the bridge that turns roles into utilities. The app's global stylesheet imports it right after the engine (`@import 'tailwindcss'; @import '../shared/ui/tokens.css';`).

```css
/* src/shared/ui/tokens.css */

/* Scales that no theme changes */
:root {
  --ds-duration-instant: 100ms;
  --ds-duration-fast: 200ms;
  --ds-duration-normal: 300ms;
  --ds-motion-distance: 1rem; /* how far things slide in */
  --ds-motion-scale: 0.96; /* how small things start */
  --ds-z-sticky: 200;
  --ds-z-overlay: 300;
  --ds-z-modal: 400;
  --ds-z-toast: 500;
}

/* Reduced motion removes movement and keeps fades: every animation built on these two stops moving */
@media (prefers-reduced-motion: reduce) {
  :root {
    --ds-motion-distance: 0rem;
    --ds-motion-scale: 1;
  }
}

/* One block per theme. Every theme defines every role */
:root,
[data-theme='light'] {
  color-scheme: light;
  --ds-bg-base: #f9fafb;
  --ds-bg-raised: #ffffff;
  --ds-bg-subtle: #f3f4f6;
  --ds-bg-accent: #2563eb;
  --ds-bg-accent-hover: #1d4ed8;
  --ds-bg-danger: #dc2626;
  --ds-bg-danger-hover: #b91c1c;
  --ds-bg-danger-subtle: #fef2f2;
  --ds-bg-overlay: rgba(0, 0, 0, 0.5);
  --ds-fg-default: #111827;
  --ds-fg-muted: #6b7280;
  --ds-fg-link: #2563eb;
  --ds-fg-danger: #b91c1c;
  --ds-fg-on-accent: #ffffff;
  --ds-fg-on-danger: #ffffff;
  --ds-border-default: #e5e7eb;
  --ds-border-input: #6b7280;
  --ds-border-danger: #b91c1c;
  --ds-border-focus: #3b82f6;
}

[data-theme='dark'] {
  color-scheme: dark;
  --ds-bg-base: #111827;
  --ds-bg-raised: #1f2937;
  --ds-bg-subtle: #374151;
  --ds-bg-accent: #3b82f6;
  --ds-bg-accent-hover: #60a5fa;
  --ds-bg-danger: #ef4444;
  --ds-bg-danger-hover: #f87171;
  --ds-bg-danger-subtle: rgba(239, 68, 68, 0.15);
  --ds-bg-overlay: rgba(0, 0, 0, 0.7);
  --ds-fg-default: #f9fafb;
  --ds-fg-muted: #9ca3af;
  --ds-fg-link: #60a5fa;
  --ds-fg-danger: #f87171;
  --ds-fg-on-accent: #030712;
  --ds-fg-on-danger: #030712;
  --ds-border-default: #374151;
  --ds-border-input: #6b7280;
  --ds-border-danger: #f87171;
  --ds-border-focus: #60a5fa;
}

/* The bridge: a utility's prefix is its token's category, so `text-accent` and `bg-red-500` do not compile */
@theme inline {
  --color-*: initial;

  --background-color-base: var(--ds-bg-base);
  --background-color-raised: var(--ds-bg-raised);
  --background-color-subtle: var(--ds-bg-subtle);
  --background-color-accent: var(--ds-bg-accent);
  --background-color-accent-hover: var(--ds-bg-accent-hover);
  --background-color-danger: var(--ds-bg-danger);
  --background-color-danger-hover: var(--ds-bg-danger-hover);
  --background-color-danger-subtle: var(--ds-bg-danger-subtle);
  --background-color-overlay: var(--ds-bg-overlay);

  --text-color-default: var(--ds-fg-default);
  --text-color-muted: var(--ds-fg-muted);
  --text-color-link: var(--ds-fg-link);
  --text-color-danger: var(--ds-fg-danger);
  --text-color-on-accent: var(--ds-fg-on-accent);
  --text-color-on-danger: var(--ds-fg-on-danger);

  --border-color-default: var(--ds-border-default);
  --border-color-input: var(--ds-border-input);
  --border-color-danger: var(--ds-border-danger);
  --outline-color-focus: var(--ds-border-focus);

  --default-transition-duration: var(--ds-duration-fast);
}

@layer base {
  * {
    border-color: var(--ds-border-default); /* a bare `border` draws the default line */
  }
  body {
    background-color: var(--ds-bg-base);
    color: var(--ds-fg-default);
    accent-color: var(--ds-bg-accent); /* native checkboxes, radios and ranges take the brand */
  }
  /* A theme change lands at once: without this, every `transition-colors` element fades while the page around it jumps */
  [data-theme-change] *,
  [data-theme-change] *::before,
  [data-theme-change] *::after {
    transition: none !important;
  }
  /* One focus ring for every focusable element: a real outline, which forced colors keeps */
  :focus-visible {
    outline: 2px solid var(--ds-border-focus);
    outline-offset: 2px;
  }
}
```

- **The bridge is typed.** `--background-color-*` feeds only `bg-` (and gradient stops), `--text-color-*` only `text-`, `--border-color-*` only `border-`, `--outline-color-*` only `outline-`. `bg.danger` and `fg.danger` share a name and never meet: `bg-danger` is the fill, `text-danger` is the text that passes on a surface.
- **`inline` is what lets a scope work.** Utilities emit `var(--ds-…)` directly, so a theme block on any element reaches the utilities inside it.
- **Other scales are not renamed.** `text-sm`, `p-4`, `rounded-md` and `shadow-sm` are the engine's. Retune one by setting its variable in the same `@theme` block (`--radius-md: 0.5rem`); close one by resetting its namespace and listing the steps the product uses.
- **Layers and durations are used by variable:** `z-(--ds-z-modal)`, `duration-(--ds-duration-normal)`. A bare `z-50` or `duration-300` is a literal.

## Theme at first paint

Theme input arrives three ways: a stored choice (at first paint), the OS setting (live) and the toggle or another tab (live). One inline script handles all three, so nothing else in the app sets the attribute.

```tsx
// src/shared/ui/theme.tsx
const STORAGE_KEY = 'theme'

// Runs while the HTML is parsed, so the first paint is already right; then follows the OS setting and other tabs live
const script = `(function () {
  var root = document.documentElement
  var media = matchMedia('(prefers-color-scheme: dark)')
  function apply() {
    var choice = null
    try { choice = localStorage.getItem('${STORAGE_KEY}') } catch (e) {}
    var theme = choice === 'light' || choice === 'dark' ? choice : media.matches ? 'dark' : 'light'
    if (root.dataset.theme === theme) return
    root.dataset.themeChange = '' // tokens.css turns transitions off while this is set: a theme change is not an animation
    root.dataset.theme = theme
    void root.offsetHeight // the new colors land in this frame
    delete root.dataset.themeChange
  }
  apply()
  media.addEventListener('change', apply)
  addEventListener('storage', apply)
})()`

/** Goes in <head>. The <html> element takes suppressHydrationWarning, because this script changes it before React hydrates */
export const ThemeScript = () => <script dangerouslySetInnerHTML={{ __html: script }} />

/** 'system' forgets the stored choice. The script above is the only code that sets the attribute */
export const setTheme = (choice: 'light' | 'dark' | 'system') => {
  if (choice === 'system') localStorage.removeItem(STORAGE_KEY)
  else localStorage.setItem(STORAGE_KEY, choice)
  window.dispatchEvent(new StorageEvent('storage', { key: STORAGE_KEY }))
}
```

```tsx
// src/app/layout.tsx (shape: Next.js. Other frameworks put the same script first in <head>)
<html lang="en" suppressHydrationWarning>
  <head>
    <ThemeScript />
  </head>
  <body>{children}</body>
</html>
```

- A product with one theme needs none of this: its values go on `:root` with the matching `color-scheme`.
- A product that only follows the OS, with no toggle, keeps the script and drops its storage lines. The attribute is what a scoped theme and the token test key on. A `@media (prefers-color-scheme: dark)` block would need no script, but it cannot theme one element.
- Canvas, charts, maps and third-party widgets copy colors when they start, so they re-read them when the attribute changes.
- A strict CSP gives the script a nonce. A cookie the server reads can render explicit choices into the HTML, but it makes the layout dynamic, and the system setting still resolves in the script.

## Button: one look union, separate contracts

```ts
// src/shared/lib/cn.ts
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export const cn = (...inputs: ClassValue[]) => twMerge(clsx(inputs))
```

```ts
// src/shared/ui/button-variants.ts
import { cva, type VariantProps } from 'class-variance-authority'

// Its own file, with no 'use client', so a Server Component can call it to style a link
export const buttonVariants = cva(
  // Every variant has a border, so they share one size. min-h, not h: a long or translated label wraps and the button grows
  'relative inline-flex max-w-full items-center justify-center gap-2 rounded-md border text-center font-medium transition-colors ' +
    'pointer-coarse:min-h-11 disabled:pointer-events-none disabled:opacity-50 aria-busy:cursor-progress',
  {
    variants: {
      variant: {
        primary: 'border-transparent bg-accent text-on-accent hover:bg-accent-hover',
        secondary: 'border-input bg-raised text-default hover:bg-subtle',
        ghost: 'border-transparent text-default hover:bg-subtle',
        danger: 'border-transparent bg-danger text-on-danger hover:bg-danger-hover',
      },
      size: { sm: 'min-h-8 px-3 py-1 text-sm', md: 'min-h-10 px-4 py-1.5 text-base' },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  },
)

export type ButtonVariants = VariantProps<typeof buttonVariants>
```

```tsx
// src/shared/ui/button.tsx
'use client'

import type { ComponentProps } from 'react'

import { cn } from '@/shared/lib/cn'

import { buttonVariants, type ButtonVariants } from './button-variants'

export type ButtonProps = ComponentProps<'button'> & ButtonVariants & { loading?: boolean }

/**
 * type="button" by default: a bare <button> submits the form around it. On an existing Button that default
 * is a call-site delta: a form that relied on the implicit submit now needs type="submit".
 * While loading it keeps its width, its name and the focus, and ignores presses.
 * A Client Component, so a headless part can hand it children when a Server Component passes it to `render`
 */
export function Button({ variant, size, loading = false, className, type = 'button', onClick, children, ...props }: ButtonProps) {
  return (
    <button
      {...props}
      type={loading ? 'button' : type}
      aria-busy={loading || undefined}
      onClick={loading ? undefined : onClick}
      className={cn(buttonVariants({ variant, size }), className)}
    >
      <span className={cn('inline-flex items-center gap-2', loading && 'opacity-0')}>{children}</span>
      {loading && <span aria-hidden className="absolute size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />}
    </button>
  )
}

/** Another contract, not a flag: the name is required, because an icon has none */
export function IconButton({ label, className, ...props }: Omit<ButtonProps, 'aria-label'> & { label: string }) {
  return <Button {...props} aria-label={label} className={cn('aspect-square p-0', className)} />
}
```

```ts
// src/shared/lib/useControllableState.ts
'use client'

import { useState } from 'react'

/** State a component owns until its parent passes `value`: the controlled trio in one hook */
export const useControllableState = <T,>(value: T | undefined, defaultValue: T, onChange?: (next: T) => void) => {
  const [inner, setInner] = useState(defaultValue)
  const set = (next: T) => {
    if (value === undefined) setInner(next)
    onChange?.(next)
  }
  return [value === undefined ? inner : value, set] as const
}
```

```tsx
// src/shared/ui/toggle-button.tsx
'use client'

import { cn } from '@/shared/lib/cn'
import { useControllableState } from '@/shared/lib/useControllableState'

import { Button, type ButtonProps } from './button'

type ToggleButtonProps = Omit<ButtonProps, 'variant' | 'onClick' | 'aria-pressed'> & {
  pressed?: boolean
  defaultPressed?: boolean
  onPressedChange?: (pressed: boolean) => void
}

/**
 * Owns the pressed state and its ARIA. aria-pressed comes after the spread, so a call site can't override it;
 * the pressed look follows that attribute and adds a border, a cue beyond color
 */
export function ToggleButton({ pressed, defaultPressed = false, onPressedChange, className, ...props }: ToggleButtonProps) {
  const [isPressed, setPressed] = useControllableState(pressed, defaultPressed, onPressedChange)
  return (
    <Button
      variant="ghost"
      {...props}
      aria-pressed={isPressed}
      onClick={() => setPressed(!isPressed)}
      className={cn('aria-pressed:border-input aria-pressed:bg-subtle', className)}
    />
  )
}
```

```tsx
// A link that looks like a button stays a link: never a <button> that navigates, nor a button rendered as <a>
import { buttonVariants } from '@/shared/ui/button-variants'

<Link href="/pricing" className={buttonVariants({ variant: 'ghost' })}>
  Pricing
</Link>
```

- **One `variant` union of the designed looks.** Split it into two axes (`tone` × `emphasis`) only when most cells are designed and call sites choose each one independently. Then style every cell or exclude it in the type, because a combination nobody styled renders bare.
- **Names:** keep the repo's prop names and values. A new component calls its look `variant` and names values by look (`primary`, `ghost`); never `colorScheme`, which collides with CSS `color-scheme` and React Native's `useColorScheme`.
- **What the component owns comes after the spread** (`type`, `aria-busy`, `aria-pressed`), so a call site cannot override it.
- **Every variant is the same size.** Each one sets a border color, transparent where none shows, so a bordered button and a filled one line up. No two classes in one variant set the same property: a link styled by `buttonVariants` has no merger to settle a conflict, and stylesheet order would.
- **`min-h`, not `h`.** A long or translated label wraps and the button grows with it; a fixed height clips it. `pointer-coarse:min-h-11` lifts every size to the touch floor under a finger.
- **Two files, for two reasons.** `buttonVariants` has no `'use client'`, so a Server Component can call it. `Button` is a Client Component because headless parts hand it children through `render`: a Server Component is rendered before that happens, and its label comes out empty.
- **One choice among several** is a radio group or the library's toggle group, never separate toggles the caller keeps in sync.

## Field: the wiring is built in

The control is a render prop: it receives exactly the attributes that tie it to its label, hint and error, and the screen decides which control to draw.

```tsx
// src/shared/ui/field.tsx
import { useId, type ComponentProps, type ReactNode } from 'react'

import { cn } from '@/shared/lib/cn'

const ErrorIcon = () => (
  <svg aria-hidden viewBox="0 0 16 16" className="size-4 shrink-0" fill="currentColor">
    <path d="M8 1a7 7 0 1 0 0 14A7 7 0 0 0 8 1Zm-.75 3.5h1.5v5h-1.5v-5Zm0 6.5h1.5v1.5h-1.5V11Z" />
  </svg>
)

export type FieldControl = { id: string; 'aria-describedby': string | undefined; 'aria-invalid': true | undefined }

/** Wires a label, a hint and an error to one control. The error is an icon and text, never color alone, and every string arrives as a prop */
export function Field({
  label,
  description,
  error,
  children,
}: {
  label: ReactNode
  description?: ReactNode
  error?: ReactNode
  children: (control: FieldControl) => ReactNode
}) {
  const id = useId()
  const describedBy = [description && `${id}-description`, error && `${id}-error`].filter(Boolean).join(' ')
  return (
    <div className="grid gap-1.5">
      <label htmlFor={id} className="text-sm font-medium text-default">
        {label}
      </label>
      {children({ id, 'aria-describedby': describedBy || undefined, 'aria-invalid': error ? true : undefined })}
      {description && (
        <p id={`${id}-description`} className="text-sm text-muted">
          {description}
        </p>
      )}
      {error && (
        <p id={`${id}-error`} className="flex items-center gap-1 text-sm text-danger">
          <ErrorIcon />
          {error}
        </p>
      )}
    </div>
  )
}

/** 16px text: iOS zooms the page when a focused input is smaller */
export function Input({ className, ...props }: ComponentProps<'input'>) {
  return (
    <input
      className={cn(
        'h-10 w-full rounded-md border border-input bg-raised px-3 text-base text-default placeholder:text-muted',
        'pointer-coarse:h-11 aria-invalid:border-danger disabled:opacity-50',
        className,
      )}
      {...props}
    />
  )
}
```

Validation, submission and what an error says belong to the feature. `Field` only wires and draws.

## Dialog: bought behavior

The headless library is imported here and nowhere else. The wrapper re-exports the parts it leaves alone, styles the popup from tokens, and makes the accessible name a required prop.

```tsx
// src/shared/ui/dialog.tsx
'use client'

import { Dialog } from '@base-ui/react/dialog'
import type { ComponentProps, ReactNode } from 'react'

import { cn } from '@/shared/lib/cn'

// Behavior is bought: focus trap, Escape, scroll lock, focus return. This file adds the look
export const Root = Dialog.Root
export const Trigger = Dialog.Trigger
export const Close = Dialog.Close

/** `title` is required, so a dialog can't ship without its accessible name */
export function Content({
  title,
  description,
  className,
  children,
  ...props
}: Omit<ComponentProps<typeof Dialog.Popup>, 'title' | 'className'> & {
  title: ReactNode
  description?: ReactNode
  className?: string
}) {
  return (
    <Dialog.Portal>
      <Dialog.Backdrop className="fixed inset-0 z-(--ds-z-overlay) bg-overlay transition-opacity data-ending-style:opacity-0 data-starting-style:opacity-0" />
      <Dialog.Popup
        className={cn(
          'fixed inset-x-4 top-1/2 z-(--ds-z-modal) mx-auto grid max-w-md -translate-y-1/2 gap-4 rounded-lg bg-raised p-6 text-default shadow-lg',
          // Movement comes from the motion tokens, so reduced motion leaves only the fade. Exits run one step shorter
          'transition-[opacity,scale] duration-(--ds-duration-normal) ease-out data-starting-style:scale-(--ds-motion-scale) data-starting-style:opacity-0',
          'data-ending-style:scale-(--ds-motion-scale) data-ending-style:opacity-0 data-ending-style:duration-(--ds-duration-fast) data-ending-style:ease-in',
          className,
        )}
        {...props}
      >
        <div className="grid gap-1">
          <Dialog.Title className="text-lg font-semibold">{title}</Dialog.Title>
          {description && <Dialog.Description className="text-sm text-muted">{description}</Dialog.Description>}
        </div>
        {children}
      </Dialog.Popup>
    </Dialog.Portal>
  )
}
```

```tsx
// Any screen (shape). The trigger is the system's Button: the library's behavior lands on it through `render`
import { Button } from '@/shared/ui/button'
import * as Dialog from '@/shared/ui/dialog'

<Dialog.Root>
  <Dialog.Trigger render={<Button variant="secondary" />}>Delete project</Dialog.Trigger>
  <Dialog.Content title="Delete this project?" description="Its 3 files are removed for everyone. This can't be undone.">
    <div className="flex justify-end gap-2">
      <Dialog.Close render={<Button variant="ghost" />}>Keep project</Dialog.Close>
      <Button variant="danger" onClick={deleteProject}>
        Delete project
      </Button>
    </div>
  </Dialog.Content>
</Dialog.Root>
```

- **Parts are exported by name** and imported as a namespace, so a Server Component can render them: it cannot dot into an object exported from a client module.
- **No copy inside.** The close control is the caller's, with the caller's words; a built-in "Close" would be a string nobody translates.
- **A component passed to `render`** spreads its props, passes `ref` through and is a Client Component, as `Button` is.
- **When the action removes its own trigger** (a row's delete button), focus has nowhere to return. The screen sends it to the next row or the list's heading.

## Card: parts without state

Compound parts need a context only when they share state. These share none, so they are plain components.

```tsx
// src/shared/ui/card.tsx
import type { ComponentProps } from 'react'

import { cn } from '@/shared/lib/cn'

// Parts the screen arranges. They share no state, so there is no context: import * as Card from '@/shared/ui/card'
export const Root = ({ className, ...props }: ComponentProps<'article'>) => (
  <article className={cn('@container grid gap-3 rounded-lg bg-raised p-4 text-default shadow-sm', className)} {...props} />
)

export const Header = ({ className, ...props }: ComponentProps<'header'>) => (
  <header className={cn('flex items-start justify-between gap-2', className)} {...props} />
)

export const Title = ({ className, ...props }: ComponentProps<'h3'>) => (
  <h3 className={cn('text-base font-semibold', className)} {...props} />
)

// The card answers to its own width, not the viewport's: it keeps working when it moves into a sidebar
export const Actions = ({ className, ...props }: ComponentProps<'footer'>) => (
  <footer className={cn('flex flex-col gap-2 @sm:flex-row @sm:justify-end', className)} {...props} />
)
```

Parts that share state (tabs, an accordion, a menu) come from the headless library. A multi-part block with its own logic follows react-architecture's compound blocks, if available.

## In a screen

The slices below are react-architecture's examples, if that skill is in use: `FavoriteToggle` is a headless feature component whose render prop hands over `{ isFavorited, isPending, toggle }`, and `sendMessage` is a Server Action. The logic stays theirs. The markup is built from the system, and a hook's value plugs straight into a primitive's props.

```tsx
// src/screens/products/ui/ProductCardItem.tsx
'use client'

import { FavoriteToggle } from '@/features/toggle-favorite'
import * as Card from '@/shared/ui/card'
import { ToggleButton } from '@/shared/ui/toggle-button'

import type { ProductCard } from '../model/toVisibleCards'
import { HeartIcon } from './HeartIcon'

export function ProductCardItem({ card }: { card: ProductCard }) {
  return (
    <Card.Root>
      <Card.Header>
        <Card.Title>{card.name}</Card.Title>
        <FavoriteToggle productId={card.id}>
          {({ isFavorited, isPending, toggle }) => (
            <ToggleButton aria-label="Favorite" size="sm" pressed={isFavorited} loading={isPending} onPressedChange={toggle}>
              <HeartIcon filled={isFavorited} />
            </ToggleButton>
          )}
        </FavoriteToggle>
      </Card.Header>
      <p className="text-sm text-muted">{card.priceLabel}</p>
    </Card.Root>
  )
}
```

```tsx
// src/features/send-message/ui/SendMessageForm.tsx
'use client'

import { useActionState } from 'react'

import { Button } from '@/shared/ui/button'
import { Field, Input } from '@/shared/ui/field'

import { sendMessage } from '../api/sendMessage.actions'

export function SendMessageForm() {
  const [result, submit, isPending] = useActionState(sendMessage, null)

  if (result && 'ok' in result) return <p>Message sent.</p>

  return (
    <form action={submit} className="grid gap-4">
      <Field label="Email">
        {(control) => <Input {...control} name="email" type="email" defaultValue={result?.fields?.email} required />}
      </Field>
      <Field label="Message" description="At least 10 characters." error={result?.error}>
        {(control) => <Input {...control} name="body" defaultValue={result?.fields?.body} required />}
      </Field>
      <Button type="submit" loading={isPending} className="justify-self-start">
        Send
      </Button>
    </form>
  )
}
```

- No literal, no `dark:`, no ARIA written by hand: the screen composes roles and primitives.
- `className` on a primitive is layout only (`justify-self-start`). The price is a plain `<p>` in role utilities.
- `loading={isPending}` replaces a disabled button: the button keeps the focus, and a second press does nothing.
- The screen holds the copy (`"Favorite"`, `"Send"`), so it is the screen's to translate.

## States

Every interactive primitive answers each row, or says why it has no such state.

| State | Look | Behavior |
|---|---|---|
| Hover | The hover token, never an opacity change | Pointer only; never the only way to find an action |
| Focus-visible | The global 2px outline in `border.focus` | In the tab order. Inside a composite widget (menu, tabs, listbox): one tab stop, then arrow keys |
| Active (pointer down) | The hover token, or an admitted pressed token with its pairs | Fires on release |
| Pressed, selected, current | A cue beyond color (border, check, weight) at 3:1 against its surroundings | `aria-pressed`, `aria-selected`, `aria-checked` or `aria-current`, rendered by the component that owns the state |
| Disabled | `opacity-50`. Disabled controls are exempt from contrast, so nothing else may fade text | Native `disabled`, or focusable `aria-disabled` when the user must learn why |
| Invalid | The danger border; the message in `fg.danger` with an icon | `aria-invalid`, and the message tied by `aria-describedby` |
| Loading | Label kept in place and hidden, spinner over it, width unchanged | `aria-busy`; presses ignored; focus stays |
