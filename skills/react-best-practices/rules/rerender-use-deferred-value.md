---
title: Keep Typing Responsive with useDeferredValue
tags: rerender, useDeferredValue, concurrent, inp, react-compiler
---

`useDeferredValue` makes each keystroke render twice: an urgent render with the old deferred value, which commits the input, then a background render with the new one, which starts at once and restarts if more input arrives. Typing stays responsive only if the urgent render skips the slow work, so make the skip explicit, compiler on or off:

- the slow derivation in a `useMemo` keyed on the deferred value and other slow inputs, never the live one;
- the slow subtree in a `memo` child whose props all keep their identity in the urgent render: the deferred value (for highlighting too), memoized data, stable callbacks.

The compiler chooses its own memo scopes and can key the derivation on the live value; then the urgent render redoes it and the deferral buys nothing. Before claiming the fix, confirm in the React Profiler that the list is absent from the urgent commit, or read the compiled output.

```tsx
const ResultsList = memo(SlowResultsList)

function Search({ items }: { items: Item[] }) {   // items must keep its identity between keystrokes
  const [query, setQuery] = useState('')
  const deferredQuery = useDeferredValue(query)
  const results = useMemo(() => filterItems(items, deferredQuery), [items, deferredQuery])
  return (
    <>
      <input value={query} onChange={e => setQuery(e.target.value)} />
      <div style={{ opacity: query !== deferredQuery ? 0.7 : 1 }}>
        <ResultsList results={results} query={deferredQuery} />
      </div>
    </>
  )
}
```

State the preconditions in your notes: `items` is stable (a parent passing `list.filter(...)` inline creates a new array each render and defeats both memos), and the child gets no live prop.

Use it for typed input, or a value that arrives as a prop you don't own; for a discrete update you own, use a Transition ([rerender-transitions](./rerender-transitions.md)).

*Break:* the background render yields only between components, so one slow computation (a 200 ms filter) still blocks: make it cheap first ([js-hot-paths](./js-hot-paths.md)), or move it to a Worker or the server.

Sources: https://react.dev/reference/react/useDeferredValue · https://react.dev/learn/react-compiler/introduction
