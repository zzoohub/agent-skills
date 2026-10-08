# Components

SKILL.md's API table in React, Tailwind and `class-variance-authority`; the shapes carry to any framework. Utilities come from `platform-web.md`'s bridge; a shadcn project keeps its generated components and vocabulary (`shadcn.md`); React Native: `react-native/platform.md`.

**No headless library yet?** Adopt one before the first widget that needs it: React Aria when RTL, many locales, date widgets or screen-reader parity are core; else Base UI (shadcn's default) or Radix. Keep one polymorphism mechanism per system, the library's (`render` or `asChild`, below). Break: canvas and other non-DOM 2D renderers have no library, so ship the APG keyboard map as tests.

## One Look Union, Separate Contracts

Every color pair below is in `tokens.md`'s table.

```tsx
'use client';
import { useState } from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/shared/ui/lib/cn';

export const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 rounded-md font-medium transition-colors ' +
    'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ' +
    'disabled:pointer-events-none disabled:opacity-(--ds-opacity-disabled)',
  {
    variants: {
      variant: {
        primary: 'bg-accent text-on-accent hover:bg-accent-hover',
        secondary: 'border border-line bg-raised text-fg hover:bg-subtle',
        ghost: 'text-fg hover:bg-subtle',
        danger: 'bg-danger text-on-danger hover:bg-danger-hover',
      },
      size: { sm: 'h-8 px-3 text-body-sm', md: 'h-10 px-4 text-body-md' },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  },
);

type ButtonProps = React.ComponentProps<'button'> & VariantProps<typeof buttonVariants>;

// type="button" by default: a bare <button> submits its enclosing form. Changing an existing
// Button's default is a call-site delta (SKILL.md § Guards and Change Management).
export function Button({ variant, size, className, type = 'button', ...props }: ButtonProps) {
  return <button type={type} className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}

// A different contract: an accessible name is required and text children are not accepted.
export function IconButton({ label, icon, ...props }: Omit<ButtonProps, 'children' | 'aria-label'> & { label: string; icon: React.ReactNode }) {
  return (
    <Button aria-label={label} {...props}>
      <span aria-hidden="true">{icon}</span>
    </Button>
  );
}

// A different contract: it owns the pressed state and renders aria-pressed after the spread, so a
// call site cannot override it; the on look follows that attribute and adds a border, a cue beyond color at ≥3:1.
type ToggleButtonProps = Omit<ButtonProps, 'variant' | 'onClick' | 'aria-pressed'> & {
  pressed?: boolean;
  defaultPressed?: boolean;
  onPressedChange?: (pressed: boolean) => void;
};

export function ToggleButton({ pressed, defaultPressed = false, onPressedChange, className, ...props }: ToggleButtonProps) {
  const [uncontrolled, setUncontrolled] = useState(defaultPressed);
  const isPressed = pressed ?? uncontrolled;
  const toggle = () => {
    if (pressed === undefined) setUncontrolled(!isPressed);
    onPressedChange?.(!isPressed);
  };
  return (
    <Button variant="ghost" {...props} aria-pressed={isPressed} onClick={toggle}
      className={cn('border border-transparent aria-pressed:border-input aria-pressed:bg-subtle', className)} />
  );
}
```

- **Split axes only when the grid is designed.** Two axes (`tone` × `emphasis`) earn their place when most cells are designed and call sites choose each independently. Then every cell gets a `compoundVariants` entry with gated pairs, or the type admits only the designed cells (`{ tone: 'danger'; emphasis: 'solid' } | …`): a value added without its entries renders unstyled. Otherwise each designed look is one `variant` value.
- **Names:** keep the repo's prop and value names. A new component calls its look union `variant` and names values by designed look (`primary`, `ghost`); never `colorScheme`, which collides with CSS `color-scheme` and React Native's `useColorScheme`.
- **Wrap the library's toggle when there is one** (Base UI and Radix `Toggle`, React Aria `ToggleButton`) and style its state attribute. One choice among several is its toggle group or a radio group, never independent toggles kept in sync by the caller.
- **A link that looks like a button stays a link:** `<a href="/pricing" className={buttonVariants({ variant: 'ghost' })}>`, or the router's Link; never a navigating `<button>`, nor a button primitive rendered as `<a>` (Base UI forbids it).
- **`render` and `asChild` merge library behavior onto your element:** `<Dialog.Trigger render={<Button />}>` (Base UI), `<Dialog.Trigger asChild><Button /></Dialog.Trigger>` (Radix). React Aria's `render` is a function of DOM props that must return the same element type: `render={(domProps) => <motion.button {...domProps} />}`. Your component must spread props and pass `ref` through, as `React.ComponentProps<'button'>` does in React 19.
- **Logical properties, content sizing:** primitives use `ps-`, `ms-`, `inset-s-` (`start-` before Tailwind 4.2) and size to content, because translation flips direction and grows short labels 2–3× (i18n's length bands, if available).

## Compound Parts

The root supports the controlled trio, memoizes its context value and exports parts by name: a static `Card.Header` throws when a Server Component dots into it; `import * as Card` works. Per-item identity (`value`, `id`) is a part's prop and shared state comes from context; content is `children`, and a render function only passes computed data down.

```tsx
'use client';
import { createContext, use, useId, useMemo, useState } from 'react';

type CardContextValue = {
  state: { expanded: boolean };
  actions: { setExpanded: (expanded: boolean) => void };
  meta: { contentId: string };
};
const CardContext = createContext<CardContextValue | null>(null);

function useCard() {
  const ctx = use(CardContext);
  if (!ctx) throw new Error('Card parts must render inside <Card>');
  return ctx;
}

export function Card({ expanded, defaultExpanded = false, onExpandedChange, children }: {
  expanded?: boolean;
  defaultExpanded?: boolean;
  onExpandedChange?: (expanded: boolean) => void;
  children: React.ReactNode;
}) {
  const [uncontrolled, setUncontrolled] = useState(defaultExpanded);
  const isExpanded = expanded ?? uncontrolled;
  const contentId = useId();
  const value = useMemo<CardContextValue>(() => ({
    state: { expanded: isExpanded },
    actions: {
      setExpanded: (next) => {
        if (expanded === undefined) setUncontrolled(next);
        onExpandedChange?.(next);
      },
    },
    meta: { contentId },
  }), [isExpanded, expanded, onExpandedChange, contentId]);
  return (
    <CardContext value={value}>
      <div className="rounded-lg bg-raised shadow-card">{children}</div>
    </CardContext>
  );
}

// A real <button>: keyboard-reachable, and it announces its state.
export function CardHeader({ children }: { children: React.ReactNode }) {
  const { state, actions, meta } = useCard();
  return (
    <button type="button" aria-expanded={state.expanded} aria-controls={meta.contentId}
      onClick={() => actions.setExpanded(!state.expanded)}>
      {children}
    </button>
  );
}

export function CardContent({ children }: { children: React.ReactNode }) {
  const { state, meta } = useCard();
  return <div id={meta.contentId} hidden={!state.expanded}>{children}</div>;
}
```

`hidden` keeps the `aria-controls` target in the DOM.

## States Checklist

| State | Visual | Behavior |
|---|---|---|
| Hover | hover token (never an opacity change) | pointer only; never the only affordance |
| Focus-visible | 2px outline in `border.focus` | in the tab order; inside a composite widget (menu, tabs, listbox), one tab stop and arrow keys (APG) |
| Active (pointer down) | the hover token, or an admitted `…Pressed` token with its pairs | fires on release |
| Pressed or selected (toggles, options, current page) | a cue beyond color (border, check, weight) at ≥3:1 against its surroundings | the owning component's `aria-pressed`, `aria-selected`, `aria-checked` or `aria-current`, never added at call sites |
| Disabled | `opacity.disabled` | native `disabled`, or focusable `aria-disabled` (SKILL.md) |
| Invalid | `fg.dangerStrong` message with an icon | `aria-invalid`; message tied by `aria-describedby` |
| Loading | label kept, spinner overlaid, width unchanged | `aria-busy`; repeat presses ignored |

## React Versions

The examples use React 19 (`ref` as a prop, `<Context value>`, `use(Context)`); on React 18, use `forwardRef`, `<Context.Provider>` and `useContext`. Without the React Compiler, memoize context values. Form and action wiring (`useActionState`, `useOptimistic`) belongs to the react-best-practices capability, if available; form parts here stay presentational.
