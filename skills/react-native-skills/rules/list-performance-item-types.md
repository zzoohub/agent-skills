---
title: Use Item Types for Heterogeneous Lists
impact: HIGH
impactDescription: efficient recycling, less layout thrashing
tags: list, performance, recycling, heterogeneous, LegendList
---

## Use Item Types for Heterogeneous Lists

When a list has different item layouts (messages, images, headers, etc.), use a
`type` field on each item and provide `getItemType` to the list. This puts items
into separate recycling pools so a message component never gets recycled into an
image component.

**Incorrect (single component with conditionals):**

```tsx
type Item = { id: string; text?: string; imageUrl?: string; isHeader?: boolean }

function ListItem({ item }: { item: Item }) {
  if (item.isHeader) {
    return <HeaderItem title={item.text} />
  }
  if (item.imageUrl) {
    return <ImageItem url={item.imageUrl} />
  }
  return <MessageItem text={item.text} />
}

function Feed({ items }: { items: Item[] }) {
  return (
    <LegendList
      data={items}
      renderItem={({ item }) => <ListItem item={item} />}
      recycleItems
    />
  )
}
```

**Correct (typed items with separate components):**

```tsx
type HeaderItem = { id: string; type: 'header'; title: string }
type MessageItem = { id: string; type: 'message'; text: string }
type ImageItem = { id: string; type: 'image'; url: string }
type FeedItem = HeaderItem | MessageItem | ImageItem

function Feed({ items }: { items: FeedItem[] }) {
  return (
    <LegendList
      data={items}
      keyExtractor={(item) => item.id}
      getItemType={(item) => item.type}
      renderItem={({ item }) => {
        switch (item.type) {
          case 'header':
            return <SectionHeader title={item.title} />
          case 'message':
            return <MessageRow text={item.text} />
          case 'image':
            return <ImageRow url={item.url} />
        }
      }}
      recycleItems
    />
  )
}
```

**Why this matters:**

- **Recycling efficiency**: Items with the same type share a recycling pool
- **No layout thrashing**: A header never recycles into an image cell
- **Type safety**: TypeScript can narrow the item type in each branch
- **Fixed sizes per type**: When a type's size is known exactly, return it from
  `getFixedItemSize` (receives `itemType`) to skip measuring; return `undefined`
  for dynamic-size types. (Legend List v3 removed `getEstimatedItemSize`.)

```tsx
<LegendList
  data={items}
  keyExtractor={(item) => item.id}
  getItemType={(item) => item.type}
  getFixedItemSize={(item, index, itemType) => {
    switch (itemType) {
      case 'header':
        return 48
      case 'image':
        return 300
      default:
        return undefined // messages vary in height: measure them
    }
  }}
  renderItem={({ item }) => {
    /* ... */
  }}
  recycleItems
/>
```

Reference:
[Legend List v3 API (getItemType, getFixedItemSize, recycleItems)](https://www.legendapp.com/open-source/list/v3/llms/api.md)
