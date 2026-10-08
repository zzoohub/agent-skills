---
title: Use Compound Components
impact: HIGH
impactDescription: enables flexible composition without prop drilling
tags: composition, compound-components, architecture
---

## Use Compound Components

Structure complex components as compound components with a shared context. Each
subcomponent accesses shared state via context, not props. Consumers compose the
pieces they need.

**Incorrect:** one monolithic `Composer` whose layout is steered by `renderHeader`-style
slots and `showAttachments`-style flags, so every new layout adds a prop.

**Correct (compound components with shared context):**

```tsx
const ComposerContext = createContext<ComposerContextValue | null>(null)
// (read it through a null-guard hook in real code — see state-context-interface)

function ComposerProvider({ children, state, actions, meta }: ProviderProps) {
  return (
    <ComposerContext value={{ state, actions, meta }}>
      {children}
    </ComposerContext>
  )
}

function ComposerFrame({ children }: { children: React.ReactNode }) {
  return <form>{children}</form>
}

function ComposerInput() {
  const {
    state,
    actions: { update },
    meta: { inputRef },
  } = use(ComposerContext)
  return (
    <TextInput
      ref={inputRef}
      value={state.input}
      onChangeText={(text) => update((s) => ({ ...s, input: text }))}
    />
  )
}

function ComposerSubmit() {
  const {
    actions: { submit },
  } = use(ComposerContext)
  return <Button onPress={submit}>Send</Button>
}

// Export each part by name; consumers write `import * as Composer from './composer'`.
// A `const Composer = {…}` object throws when a Server Component dots into it.
export {
  ComposerProvider as Provider,
  ComposerFrame as Frame,
  ComposerInput as Input,
  ComposerSubmit as Submit,
  ComposerHeader as Header,
  ComposerFooter as Footer,
  ComposerAttachments as Attachments,
  ComposerFormatting as Formatting,
  ComposerEmojis as Emojis,
}
```

**Usage:**

```tsx
<Composer.Provider state={state} actions={actions} meta={meta}>
  <Composer.Frame>
    <Composer.Header />
    <Composer.Input />
    <Composer.Footer>
      <Composer.Formatting />
      <Composer.Submit />
    </Composer.Footer>
  </Composer.Frame>
</Composer.Provider>
```

Consumers compose exactly the parts they need, with no hidden conditionals.
