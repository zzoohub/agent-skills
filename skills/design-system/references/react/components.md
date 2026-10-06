# React Component Patterns

React-specific implementations of the component patterns defined in `../components.md`.

## Table of Contents

1. [Pattern 1: Flat API](#pattern-1-flat-api)
2. [Pattern 2: Explicit Variant Components](#pattern-2-explicit-variant-components)
3. [Pattern 3: Compound API](#pattern-3-compound-api)
4. [Pattern 4: Headless Hook](#pattern-4-headless-hook)

## Pattern 1: Flat API

```tsx
interface ButtonProps {
  size?: 'sm' | 'md' | 'lg';
  colorScheme?: 'primary' | 'secondary' | 'danger';
  disabled?: boolean;
  children: React.ReactNode;
  ref?: React.Ref<HTMLButtonElement>;   // React 19: ref is a regular prop
}

export function Button({
  size = 'md',
  colorScheme = 'primary',
  disabled,
  children,
  ref,
  ...props
}: ButtonProps) {
  return <button ref={ref} disabled={disabled} {...props}>{children}</button>;
}

// Usage
<Button size="lg" colorScheme="primary">Save</Button>
```

## Pattern 2: Explicit Variant Components

```tsx
// ✅ Explicit variant components — each owns its behavior
<IconButton icon={<Trash />} label="Delete" />
<LinkButton href="/about">About</LinkButton>
<SubmitButton loading>Save</SubmitButton>
```

### Share a base, diverge on behavior

```tsx
function ButtonBase({
  size = 'md',
  colorScheme = 'primary',
  className,
  children,
  ref,
  ...props
}: ButtonBaseProps) {
  const styles = resolveButtonTokens(size, colorScheme);
  return <Slot ref={ref} className={cn(styles, className)} {...props}>{children}</Slot>;
}

export function Button({ children, ref, ...props }: ButtonProps) {
  return <ButtonBase ref={ref} {...props}><button>{children}</button></ButtonBase>;
}

export function LinkButton({ href, children, ref, ...props }: LinkButtonProps) {
  return <ButtonBase ref={ref} {...props}><a href={href}>{children}</a></ButtonBase>;
}

export function IconButton({ icon, label, ref, ...props }: IconButtonProps) {
  return (
    <ButtonBase ref={ref} {...props}>
      <button aria-label={label}>{icon}</button>
    </ButtonBase>
  );
}
```

## Pattern 3: Compound API

```tsx
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

const CardContext = createContext<CardContextValue | null>(null);

function CardRoot({
  variant = 'elevated',
  defaultExpanded = false,
  children,
}: {
  variant?: 'elevated' | 'outlined';
  defaultExpanded?: boolean;
  children: React.ReactNode;
}) {
  const [expanded, setExpanded] = useState(defaultExpanded);
  const id = useId();

  const ctx: CardContextValue = {
    state: { variant, expanded },
    actions: { toggleExpand: () => setExpanded(prev => !prev) },
    meta: { id },
  };

  return (
    <CardContext value={ctx}>
      <div className={cn(styles.card, variant === 'elevated' && styles.elevated)}>
        {children}
      </div>
    </CardContext>
  );
}

// Sub-components read context via use() (React 19)
function CardHeader({ children }: { children: React.ReactNode }) {
  const { state, actions, meta } = use(CardContext)!;
  // A real <button>, not a clickable <div>: keyboard-reachable and announces expanded state
  return (
    <button
      type="button"
      className={styles.header}
      aria-expanded={state.expanded}
      aria-controls={`${meta.id}-content`}
      onClick={actions.toggleExpand}
    >
      {children}
      {state.expanded ? <ChevronUp aria-hidden /> : <ChevronDown aria-hidden />}
    </button>
  );
}

function CardContent({ children }: { children: React.ReactNode }) {
  const { state, meta } = use(CardContext)!;
  if (!state.expanded) return null;
  return <div id={`${meta.id}-content`} className={styles.content}>{children}</div>;
}

function CardFooter({ children }: { children: React.ReactNode }) {
  return <div className={styles.footer}>{children}</div>;
}

export const Card = Object.assign(CardRoot, {
  Header: CardHeader,
  Content: CardContent,
  Footer: CardFooter,
});

// Usage
<Card variant="elevated">
  <Card.Header>Title</Card.Header>
  <Card.Content>Body text</Card.Content>
</Card>
```

## Pattern 4: Headless Hook

```typescript
interface UseToggleProps {
  defaultValue?: boolean;
  value?: boolean;
  onChange?: (value: boolean) => void;
  disabled?: boolean;
}

export function useToggle(props: UseToggleProps) {
  const { defaultValue = false, value: controlled, onChange, disabled } = props;
  const [internal, setInternal] = useState(defaultValue);

  const isControlled = controlled !== undefined;
  const isOn = isControlled ? controlled : internal;

  const toggle = useCallback(() => {
    if (disabled) return;
    const next = !isOn;
    if (!isControlled) setInternal(next);
    onChange?.(next);
  }, [isOn, isControlled, onChange, disabled]);

  return {
    toggleProps: {
      role: 'switch' as const,
      'aria-checked': isOn,
      'aria-disabled': disabled || undefined,
      onClick: toggle,
      onKeyDown: (e: React.KeyboardEvent<HTMLElement>) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggle(); }
      },
      tabIndex: disabled ? -1 : 0,
    },
    state: { isOn, isDisabled: !!disabled },
    toggle,
  };
}
```
