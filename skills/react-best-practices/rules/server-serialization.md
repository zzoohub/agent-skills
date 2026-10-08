---
title: Send the Client a Minimal DTO, Once
tags: server, rsc, serialization, server-functions, security
---

Everything that crosses to the client (the Server boundary in SKILL.md lists it) is serialized into the page or the payload, and the user can read all of it. React dedupes by reference, not by value: a derived copy (`.toSorted()`, `.filter()`, `{...obj}`) is a new container whose primitives are sent again, while objects already sent go as references. Duplicated string or number arrays cost the most.

Build a minimal DTO on the server and send each value once. Derive on the client only when the derivation is cheap and its source already crosses.

**Incorrect (every column crosses, internal fields included, and the names twice):**

```tsx
// app/team/page.tsx (Server Component)
const user = await getUser(id)
return <Team user={user} names={names} sortedNames={names.toSorted()} />
```

**Correct:**

```tsx
// app/team/page.tsx (Server Component)
const user = await getUser(id)
return <Team user={{ name: user.name, avatarUrl: user.avatarUrl }} names={names} />
```

```tsx
// app/team/team.tsx
'use client'
export function Team({ user, names }: { user: { name: string; avatarUrl: string }; names: string[] }) {
  const sorted = names.toSorted()   // cheap, and its source already crosses
  // ...
}
```

*Break:* send the derived value instead when deriving it is expensive or the client never needs the source.
