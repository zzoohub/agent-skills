---
title: Make Per-Item Work Cheap and Its Semantics Explicit
tags: javascript, hot-path, filter, sort, intl, lookups
---

Work inside a per-item callback runs rows × events: filtering 10,000 rows on each keystroke calls the callback 10,000 times per character, with every allocation inside it. On such a path the cost is visible in the code, so fix it without waiting for a profile, and state your estimate (rows × work per row × events).

| Per item, per event | Instead |
|---|---|
| `new Intl.Collator`, `NumberFormat` or `DateTimeFormat`; `toLocaleString` or `localeCompare` with options | One instance per locale and options, at module scope or memoized on the locale; reuse its `compare` or `format` |
| `new RegExp(query)` | Build it once per query, outside the loop (escape user input) |
| Lowercasing, normalizing or parsing the same fields again | A key per item, precomputed when the data changes |
| `.find`, `.includes` or `.indexOf` over another array | A `Map` by id or a `Set`, built once |
| Chained `.filter().map().filter()` over a large array | One loop, or `flatMap` |
| Sorting to take a min, max or top few | One pass |

Settle semantics before speed, and disclose any change you make:

- **A filter matches what users see:** the displayed fields, as formatted; not ids, hidden fields or `JSON.stringify(item)`.
- **A sort compares one type in one unit:** parse sizes, durations and amounts to a base unit, dates to timestamps, numeric strings to numbers. A comparator returns a number, never a boolean, and breaks ties on a unique key so the order doesn't depend on input order.
- **The locale and time zone are explicit:** pass the locale to `Intl` and `toLocale*`, and a `timeZone` to every date format. A default locale or time zone can differ between the server and the browser (a hydration mismatch) and between users.

```ts
const collator = new Intl.Collator('en', { numeric: true })   // once, not per comparison
const byId = (a: Item, b: Item) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0)   // string or numeric ids

function useVisibleRows(items: Item[], deferredQuery: string) {
  const rows = useMemo(() => items
    .map(item => ({
      item,
      // visible fields; '' not "null"; '\n' so no match spans two fields
      key: [item.title, item.assignee ?? ''].join('\n').toLowerCase(),
    }))
    .sort((a, b) => collator.compare(a.item.title, b.item.title) || byId(a.item, b.item)),
  [items])                                                       // once per data change
  return useMemo(() => {
    const q = deferredQuery.trim().toLowerCase()
    return rows.filter(r => r.key.includes(q))                   // filtering keeps the order
  }, [rows, deferredQuery])
}
```

*Break:* still over ~50 ms per keystroke after this, filter on the server or in a Worker, and virtualize what renders.

Sources: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/localeCompare · https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date/toLocaleString
