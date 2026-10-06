# React 19 API Changes

If the project uses React 19+, apply these changes to all component patterns.

## ref is a regular prop — no forwardRef

```tsx
// ❌ React 18 — forwardRef wrapper
const Button = forwardRef<HTMLButtonElement, ButtonProps>((props, ref) => {
  return <button ref={ref} {...props} />;
});

// ✅ React 19 — ref in props directly
function Button({ ref, ...props }: ButtonProps & { ref?: React.Ref<HTMLButtonElement> }) {
  return <button ref={ref} {...props} />;
}
```

## use(Context) — an addition, not a replacement for useContext

```tsx
// ✅ Still supported in React 19 (not deprecated)
const ctx = useContext(CardContext);

// ✅ Also available in React 19
const ctx = use(CardContext);
```

`use()` can be called conditionally and in loops (e.g. after an early return), unlike `useContext()`, which must run at the top level. Prefer `use()` where that flexibility helps; existing `useContext()` calls do not need migrating.

## `<Context>` is the provider

```tsx
// React 18
<CardContext.Provider value={ctx}>{children}</CardContext.Provider>

// React 19
<CardContext value={ctx}>{children}</CardContext>
```

`<Context.Provider>` still works in React 19 but is slated for deprecation in a future version.

## When to Apply

- Update all headless hooks and compound components accordingly
- No `forwardRef` — `ref` is a regular prop. Just accept `ref` in the props interface
- Read context with `use(Context)` or `useContext(Context)` — both are valid; `use()` additionally allows conditional reads
- Render `<Context value>` as the provider instead of `<Context.Provider>`
- Type refs from `useRef<T>(null)` as `React.RefObject<T | null>` (in `@types/react` 19, `useRef<T>(null)` returns `RefObject<T | null>` and `MutableRefObject` is deprecated)

## Form & action APIs (out of scope for the design system)

React 19 also adds the form/action model: `<form action={fn}>`, `useActionState(fn, initialState)` (the stable replacement for the canary-era `useFormState`, imported from `react`), `useFormStatus` (from `react-dom`), and `useOptimistic`. These drive form submission and server actions — wiring that belongs with the consumer/feature layer, not the design-system primitives. A styled `Form`/`Field` here should stay presentational and let the consumer own the action.
