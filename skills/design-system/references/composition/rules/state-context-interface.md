---
title: Define Generic Context Interfaces for Dependency Injection
impact: HIGH
impactDescription: enables dependency-injectable state across use-cases
tags: composition, context, state, typescript, dependency-injection
---

## Define Generic Context Interfaces for Dependency Injection

Define a **generic interface** for your component context with three parts:
`state`, `actions`, and `meta`. This interface is a contract that any provider
can implement—enabling the same UI components to work with completely different
state implementations.

**Incorrect (UI coupled to specific state implementation):**

```tsx
function ComposerInput() {
  // Tightly coupled to a specific hook
  const { input, setInput } = useChannelComposerState()
  return <TextInput value={input} onChangeText={setInput} />
}
```

**Correct (generic interface enables dependency injection):**

```tsx
// Define a GENERIC interface that any provider can implement
interface ComposerState {
  input: string
  attachments: Attachment[]
  isSubmitting: boolean
}

interface ComposerActions {
  update: (updater: (state: ComposerState) => ComposerState) => void
  submit: () => void
}

interface ComposerMeta {
  // @types/react 19: useRef<T>(null) returns RefObject<T | null>
  inputRef: React.RefObject<TextInput | null>
}

interface ComposerContextValue {
  state: ComposerState
  actions: ComposerActions
  meta: ComposerMeta
}

const ComposerContext = createContext<ComposerContextValue | null>(null)
```

Because the context defaults to `null`, production code reads it through a guard
hook; the rules' examples destructure `use(ComposerContext)` directly for brevity:

```tsx
function useComposer() {
  const ctx = use(ComposerContext)
  if (!ctx) throw new Error('Composer parts must render inside a Composer provider')
  return ctx
}
```

Parts read the context, as `ComposerInput` does in `architecture-compound-components`,
so any provider that implements the interface drives them.

**A provider implements the interface:**

```tsx
// Local state for an ephemeral form
function ForwardMessageProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState(initialState)
  const inputRef = useRef<TextInput>(null)
  const submit = useForwardMessage()

  return (
    <ComposerContext
      value={{
        state,
        actions: { update: setState, submit },
        meta: { inputRef },
      }}
    >
      {children}
    </ComposerContext>
  )
}
```

A `ChannelProvider` backed by a global synced store implements the same interface, and
the same `<Composer.Frame>` tree renders inside either provider.

The provider boundary is what matters, not the visual nesting: a component inside the provider
but outside `Composer.Frame` can read state and call actions (see `state-lift-state`).
