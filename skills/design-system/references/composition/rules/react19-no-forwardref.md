---
title: React 19 API Changes
impact: MEDIUM
impactDescription: cleaner component definitions and context usage
tags: react19, refs, context, hooks
---

## React 19 API Changes

> **⚠️ React 19+ only.** Skip this if you're on React 18 or earlier.

In React 19, `ref` is now a regular prop (no `forwardRef` wrapper needed), `use()` can read context (including conditionally), and `<Context value>` renders as the provider.

**Incorrect (forwardRef in React 19):**

```tsx
const ComposerInput = forwardRef<TextInput, Props>((props, ref) => {
  return <TextInput ref={ref} {...props} />
})
```

**Correct (ref as a regular prop):**

```tsx
function ComposerInput({ ref, ...props }: Props & { ref?: React.Ref<TextInput> }) {
  return <TextInput ref={ref} {...props} />
}
```

**Both valid (reading context):**

```tsx
const value = useContext(MyContext) // still supported, not deprecated
// or (React 19+):
const value = use(MyContext)
```

`useContext()` is not deprecated. `use()` is an additional option whose advantage
is that it can be called conditionally (after an early return, inside `if` or a
loop), unlike `useContext()`, which must run at the top level. Either works for
the compound-component examples in these rules.

**Correct (`<Context>` as the provider):**

```tsx
<ComposerContext value={{ state, actions, meta }}>{children}</ComposerContext>
```

In React 19, render the context itself as the provider; `<Context.Provider>`
still works but is slated for deprecation in a future version. A custom
`Composer.Provider` component (as in `architecture-compound-components`) is just
a wrapper that takes `state`/`actions`/`meta` props and renders this element —
use it when callers should not touch the raw context.
