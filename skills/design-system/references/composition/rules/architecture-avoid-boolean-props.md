---
title: Avoid Boolean Prop Proliferation
impact: CRITICAL
impactDescription: prevents unmaintainable component variants
tags: composition, props, architecture, variants
---

## Avoid Boolean Props; Create Explicit Variants

Don't customize one component's behavior with flags like `isThread`, `isEditing`
or `isDMThread`. Each flag doubles the states to reason about and allows
impossible combinations. Give each use case its own component that names what
it renders and composes shared parts.

**Incorrect (flags fork one component):**

```tsx
function Composer({ isThread, channelId, isEditing, isForwarding }: Props) {
  return (
    <form>
      <Input />
      {isThread ? <AlsoSendToChannelField id={channelId} /> : null}
      {isEditing ? <EditActions /> : isForwarding ? <ForwardActions /> : <DefaultActions />}
    </form>
  )
}
```

**Correct (explicit variants over shared parts):**

```tsx
function ThreadComposer({ channelId }: { channelId: string }) {
  return (
    <ThreadProvider channelId={channelId}>
      <Composer.Frame>
        <Composer.Input />
        <AlsoSendToChannelField channelId={channelId} />
        <Composer.Footer>
          <Composer.Submit />
        </Composer.Footer>
      </Composer.Frame>
    </ThreadProvider>
  )
}

function EditMessageComposer({ messageId }: { messageId: string }) {
  return (
    <EditMessageProvider messageId={messageId}>
      <Composer.Frame>
        <Composer.Input />
        <Composer.Footer>
          <Composer.CancelEdit />
          <Composer.SaveEdit />
        </Composer.Footer>
      </Composer.Frame>
    </EditMessageProvider>
  )
}
```

Each variant states its provider (where its state comes from), its parts and its
actions. The internals stay shared without a monolithic parent.
