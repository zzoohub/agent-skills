# Component Patterns

## Table of Contents

1. [Pattern 1: Flat API (Simple Components)](#pattern-1-flat-api-simple-components)
2. [Pattern 2: Explicit Variant Components](#pattern-2-explicit-variant-components)
3. [Pattern 3: Compound API (Flexible Layout)](#pattern-3-compound-api-flexible-layout)
4. [Pattern 4: Headless (Reusable Behavior)](#pattern-4-headless-reusable-behavior)
5. [When to Upgrade](#when-to-upgrade)
6. [States Checklist](#states-checklist)

## Pattern 1: Flat API (Simple Components)

Best for components with few visual variations and no behavioral differences between variants. Use constrained props for appearance (size, colorScheme), but never boolean props for modes.

```typescript
// Button — flat with constrained visual props.
interface ButtonProps {
  size?: 'sm' | 'md' | 'lg';
  colorScheme?: 'primary' | 'secondary' | 'danger';
  disabled?: boolean;
  children: unknown; // framework-specific child type
}
```

```
// Pseudo-code usage (any framework)
Button(size="lg", colorScheme="primary") → "Save"
```

Good candidates for flat: Button, Badge, Avatar, Input, Chip, Tag, Switch, Spinner.

## Pattern 2: Explicit Variant Components

When a prop changes **behavior** — not just appearance — split into a separate component. Don't add a boolean or mode prop to an existing component.

```
// ❌ Boolean mode prop — changes behavior inside one component
Button(icon=Trash, iconOnly=true)
Button(href="/about")
Button(type="submit", loading=true)

// ✅ Explicit variant components — each owns its behavior
IconButton(icon=Trash, label="Delete")
LinkButton(href="/about") → "About"
SubmitButton(loading=true) → "Save"
```

Why separate components: Each variant has different ARIA needs, event handling, and rendered elements. `LinkButton` renders `<a>`, `SubmitButton` renders `<button type="submit">`, `IconButton` needs `aria-label`. Cramming these into one component with booleans creates untestable branching logic.

### Implementation: Share a base, diverge on behavior

Create a shared base component that resolves tokens (size, colorScheme → styles), then each variant wraps it with the appropriate element and behavior.

When to split: A prop changes the rendered element, ARIA role, event handling, or required children. If the difference is purely visual (color, size), keep it as a prop on the same component.

## Pattern 3: Compound API (Flexible Layout)

Best when internal structure varies between uses. Sub-components share state via a **structured context interface** with `{ state, actions, meta }`.

```typescript
// Structured context — state, actions, and meta are always separate.
// The provider is the ONLY place that knows how state is managed.
interface CardContextValue {
  state: {
    variant: 'elevated' | 'outlined';
    expanded: boolean;
  };
  actions: {
    toggleExpand: () => void;
  };
  meta: {
    id: string;
  };
}
```

The root component creates and provides this context. Sub-components (Header, Content, Footer) consume it through the framework's context mechanism.

### Why structured context `{ state, actions, meta }`

The provider is the **only** place that knows how state is managed. Sub-components and consumers interact through the context interface — they never know if state comes from a hook, store, or URL param. This makes the state implementation swappable without changing any consumers.

- `state` — read-only current values
- `actions` — functions to mutate state (the "how" is hidden); keep the set small and generic (`update`, `submit`, optional `cancel`) rather than per-feature actions
- `meta` — derived/stable values like IDs, computed labels, refs (React 19: typed `RefObject<T | null>`)

### Children over render props

Always compose via children. Avoid render-function props. Render props are only acceptable when the parent must pass **computed data** to the child (e.g., a virtualizer passing item + index).

Good candidates for compound: Card, Dialog, Dropdown, Accordion, Tabs, Form, NavigationMenu.

## Pattern 4: Headless (Reusable Behavior)

Separates behavior from appearance entirely. The behavior module handles a11y, keyboard, and state. The styled component applies tokens.

```typescript
// headless/toggle.ts — framework-agnostic behavior
interface ToggleOptions {
  defaultValue?: boolean;
  value?: boolean;           // controlled mode
  onChange?: (value: boolean) => void;
  disabled?: boolean;
}

interface ToggleResult {
  toggleProps: {
    role: 'switch';
    'aria-checked': boolean;
    'aria-disabled': boolean | undefined;
    onClick: () => void;
    onKeyDown: (e: KeyboardEvent) => void;   // framework-specific event type
    tabIndex: number;
  };
  state: { isOn: boolean; isDisabled: boolean };
  toggle: () => void;
}

// Implement as a function, class, or framework-specific hook
// The interface is the same regardless of framework
```

Every headless module must support:
- **Controlled + uncontrolled**: `value` (controlled) and `defaultValue` (uncontrolled)
- **ARIA attributes**: role, aria-checked/aria-expanded/etc
- **Keyboard**: Enter/Space for actions, Escape for dismiss, Tab for navigation
- **Disabled state**: No interaction, removed from tab order

Good candidates for headless: Toggle, Dialog, Dropdown, Accordion, Tooltip, Combobox — anything with complex keyboard/focus patterns.

> For React-specific implementations (JSX, hooks, Context API): `references/react/components.md` (also linked directly from SKILL.md)

## When to Upgrade

A flat component should split into **explicit variant components** when:
- A prop changes the rendered element (`<a>` vs `<button>`)
- A prop changes ARIA roles or required attributes
- A prop changes event handling or interaction model
- You're adding boolean modes like `iconOnly`, `asLink`, `isSubmit`

A flat component should become **compound** when:
- It has 5+ configuration props for layout control
- Consumers need different internal arrangements
- You're adding `showHeader`, `headerTitle`, `showFooter` type props

A standalone component should get a **headless module** when:
- The same behavior appears in multiple visual forms
- Keyboard/focus logic is complex enough to be buggy if duplicated
- You need the behavior without any specific UI (e.g., form validation state)

## States Checklist

Every interactive component covers these states:

| State | Visual | Behavior |
|-------|--------|----------|
| Default | Base appearance | Responds to interaction |
| Hover | Subtle highlight | Cursor pointer |
| Focus | Visible outline (2px+) | Keyboard reachable |
| Active/Pressed | Depressed appearance | Action fires |
| Disabled | Reduced opacity (0.5) | No interaction, no tab |
| Loading | Spinner or skeleton | No interaction during |
