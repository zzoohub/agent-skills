---
title: Load Static Assets Once per Process, Not per Request
tags: server, io, module-scope, og-image
---

Read fonts, logos, templates and config that are identical for every request once, and reuse them; reading them per request adds I/O to every response.

**Incorrect:** `await readFile(...)` inside the `GET` handler, which reads the font again on every request.

**Correct (read once; a failed read is retried, not cached):**

```tsx
// app/api/og/route.tsx
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { ImageResponse } from 'next/og'

let fontP: Promise<Buffer> | undefined
const loadFont = () =>
  (fontP ??= readFile(join(process.cwd(), 'assets/Inter.ttf')).catch(err => {
    fontP = undefined   // otherwise the rejected promise is cached forever
    throw err
  }))

export async function GET() {
  return new ImageResponse(<Card />, { fonts: [{ name: 'Inter', data: await loadFont() }] })
}
```

A promise started at import time (`const fontP = readFile(...)`) has no handler until the first request awaits it, so a failed read becomes an unhandled rejection at startup. For a small file the app can't run without, `readFileSync` at module scope is fine: it fails fast at boot.

Keep the path literal so bundling and output tracing include the file ([bundle-analyzable-paths](./bundle-analyzable-paths.md)). On a runtime without the project's files on disk, import the asset through the bundler instead (check the runtime's docs).

*Break:* don't hoist assets that vary per request or user, files that change at runtime, large files you can't afford to keep in memory, or secrets that shouldn't stay in memory.
