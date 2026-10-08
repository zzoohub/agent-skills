# Lists

When to virtualize, chat, row re-renders, recycling, per-row cost.

## List or ScrollView

**Default.** Virtualize data-driven or unbounded content with the project's list library; FlashList v2 or Legend List v3 when it has none. Neither needs `estimatedItemSize` (FlashList v2 dropped it; Legend List v3 treats it as an optional hint and has no `getEstimatedItemSize`). Use a `ScrollView` for bounded content you author (settings, forms).
**Why.** A virtualizer mounts only the visible rows plus a draw distance, so a virtualized form loses off-screen input focus and state, and layout animation gets harder.
**Break:** bounded but heavy rows (images, video, charts) that drop frames on the slowest device. Measure, then virtualize.

**Chat:** a bottom-anchored list, not `inverted` (a flip transform over reversed data): Legend List `alignItemsAtEnd` + `maintainScrollAtEnd` + `initialScrollAtEnd`; FlashList v2 `maintainVisibleContentPosition={{ startRenderingFromBottom: true }}` (`autoscrollToBottomThreshold` follows new messages). Composer: `rules/platform-layout.md`. **Break:** an existing inverted list stays unless the bug comes from the flip.

## Row re-renders

**Default.** Rows get stable references: the item from `data`, or primitives, never objects or closures built in `renderItem`. Values that change often and touch many rows (search text, selection) reach each row through a store selector returning a primitive, not through re-mapped `data` or a prop on every row. Rarely-changing context (theme, locale) is fine.
**Why.** Re-mapping `data` per keystroke re-renders the list and every visible row; a selector re-renders only rows whose output changed. The React Compiler memoizes `renderItem`, not objects created inside it.
**Compiler off:** `useCallback` for `renderItem` and the shared handler, `useMemo` for derived `data`, `memo` for rows.

```tsx
import { Pressable, Text } from 'react-native'
import { LegendList } from '@legendapp/list/react-native'
import { useRouter } from 'expo-router'
import { useSearchStore } from './search-store' // any store with selectors

function DomainList({ tlds }: { tlds: Tld[] }) {
  const router = useRouter()
  const open = (id: string) => router.push(`/domains/${id}`) // one handler, every row
  // New array, same items: fine
  const sorted = [...tlds].sort((a, b) => a.name.localeCompare(b.name))
  return (
    <LegendList
      data={sorted}
      keyExtractor={(t) => t.id}
      renderItem={({ item }) => <DomainRow tld={item} onOpen={open} />}
    />
  )
}

function DomainRow({ tld, onOpen }: { tld: Tld; onOpen: (id: string) => void }) {
  // Typing re-renders visible rows, never the list
  const domain = useSearchStore((s) => `${s.keyword}.${tld.name}`)
  const selected = useSearchStore((s) => s.selectedId === tld.id) // 2 rows per change
  // Accessibility props in the house spelling (role/aria-* or accessibility*)
  return (
    <Pressable role="button" aria-selected={selected} onPress={() => onOpen(tld.id)}>
      <Text>{domain}</Text>
    </Pressable>
  )
}
```

## Recycling

FlashList always recycles; Legend List does with `recycleItems`. A recycled row is the same instance rendered with another item, so its state and effects carry over.

- No `key` inside rows; in a row's `.map()`, take keys from FlashList's `useMappingHelper`.
- Derive what a row shows from its item. UI-only row state (expanded, a selected tab) resets per item with the list's `useRecyclingState` (FlashList: `useRecyclingState(initial, [item.id])`; Legend List resets on recycle, no deps); server values never enter row state (below).
- Give expo-image in rows `recyclingKey={item.id}`, or the previous item's image shows until the new one loads.
- One item type per row layout (`getItemType`), so a header never recycles into a message. Legend List skips measuring sizes returned from `getFixedItemSize`.

**Break:** heavy per-instance state (video, inputs) gets its own item type, or recycling off.

```tsx
<LegendList
  data={feed} // a union discriminated on `type`
  recycleItems
  keyExtractor={(item) => item.id}
  getItemType={(item) => item.type}
  getFixedItemSize={(item, index, type) => (type === 'header' ? 48 : undefined)} // undefined: measure
  renderItem={renderFeedItem} // switch on item.type: one component per type
/>
```

## Row state and optimistic updates

**Default.** Server-backed values (saved, counts, status) are read from the item or the query cache, never copied into row state. An optimistic write records only the user's intent, in the cache or a store keyed by item id; counts derive from it. Each mutation clears only its own intent, never a newer tap's: on error at once, telling the user; on success when its response or a refetch of that item lands, whatever it says (server wins). Refresh that item, not every loaded page of the list.
**Why.** Row state seeded from the item (`useRecyclingState(item.saved, …)`) copies the server value once, so a refetch for the same item never reaches the row. A mutation callback can resolve after the row shows another item: row state would apply it there. And an intent kept until the server agrees outlives a server that never will (another device, a rejected write).
**Break:** no cache or store holds the value: keep only the user's override, `undefined` until they act, render `override ?? item.saved`, reset it per item, clear it as above, and drop callbacks whose item id is no longer the row's.

```tsx
// In the row: pending saves live in a store keyed by item id, not in row state
const pending = usePendingSaves((s) => s.byId[item.id]) // the user's intent; undefined: none
const saved = pending ?? item.saved // server truth whenever nothing is pending
const saveCount = item.saveCount + Number(saved) - Number(item.saved) // derived, never stored
// The mutation sets byId[id] and clears only its own entry, never a newer tap's: on error
// at once (and says so), on success when the response or that item's refetch lands
```

## Per-row work

- No network fetch per row: fetch the page in the parent; a row may read a cached entry by id.
- Create `Intl` formatters once per (locale, options). `toLocaleString()` in a row behaves as if it builds one per call. Constructors Hermes lacks need a polyfill loaded first.
- Blank cells on a fast fling (release build): rows render slower than the scroll. Cut row cost (SKILL.md §3), then raise `drawDistance`; re-measure (FlashList reports blank area via `onBlankArea`).

Docs: [FlashList performance](https://shopify.github.io/flash-list/docs/fundamentals/performance) · [recycling](https://shopify.github.io/flash-list/docs/recycling) · [Legend List v3](https://www.legendapp.com/open-source/list/v3/api/)
