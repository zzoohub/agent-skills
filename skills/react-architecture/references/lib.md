# In-House Code

Copy into the project only what its code uses; these are not a package. Paths are defaults; the caller may redirect them.

## Table of Contents

1. [fp.ts](#fpts)
2. [createQueryKeys](#createquerykeys)
3. [http](#http)
4. [useUrlState (Next.js)](#useurlstate-nextjs)
5. [Layer test](#layer-test)

## fp.ts

Only what the language doesn't have. Add a step overload if a real pipeline needs one.

```ts
// src/shared/lib/fp.ts
export function pipe<A>(a: A): A
export function pipe<A, B>(a: A, ab: (a: A) => B): B
export function pipe<A, B, C>(a: A, ab: (a: A) => B, bc: (b: B) => C): C
export function pipe<A, B, C, D>(a: A, ab: (a: A) => B, bc: (b: B) => C, cd: (c: C) => D): D
export function pipe<A, B, C, D, E>(a: A, ab: (a: A) => B, bc: (b: B) => C, cd: (c: C) => D, de: (d: D) => E): E
export function pipe(value: unknown, ...fns: Array<(x: unknown) => unknown>): unknown {
  return fns.reduce((acc, f) => f(acc), value)
}

export function compose<A, B>(ab: (a: A) => B): (a: A) => B
export function compose<A, B, C>(bc: (b: B) => C, ab: (a: A) => B): (a: A) => C
export function compose<A, B, C, D>(cd: (c: C) => D, bc: (b: B) => C, ab: (a: A) => B): (a: A) => D
export function compose<A, B, C, D, E>(de: (d: D) => E, cd: (c: C) => D, bc: (b: B) => C, ab: (a: A) => B): (a: A) => E
export function compose(...fns: Array<(x: unknown) => unknown>) {
  return (value: unknown): unknown => fns.reduceRight((acc, f) => f(acc), value)
}
```

## createQueryKeys

Partial application over the domain name. The hierarchy is what lets `lists()` invalidate every list. A list with no filters uses `lists()` as its key; don't pass a placeholder to `list()`.

```ts
// src/shared/api/createQueryKeys.ts
export const createQueryKeys = <const D extends string>(domain: D) => {
  const all = [domain] as const
  const lists = [...all, 'list'] as const
  const details = [...all, 'detail'] as const
  return {
    all: () => all,
    lists: () => lists,
    list: <F,>(filters: F) => [...lists, filters] as const,
    details: () => details,
    detail: (id: string) => [...details, id] as const,
  }
}
```

## http

The path is fixed first; the call comes later. An empty 201 or 204 is a success, so the body is read as text first. Encode path segments that come from a route or a user. A query that also runs on the server (a prefetch, a loader) needs an absolute URL, so paths start from `API_URL`; use your stack's public prefix (`NEXT_PUBLIC_`, `VITE_`, `EXPO_PUBLIC_`).

```ts
// src/shared/config/env.ts
export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? ''
```

```ts
// src/shared/api/http.ts
export const rejectIfNotOk = (response: Response) => {
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return response
}

const readJson = <T,>(response: Response) =>
  response.text().then((text) => (text ? JSON.parse(text) : undefined) as T)

export const getJson = <T,>(path: string) => (params: Record<string, string>): Promise<T> =>
  fetch(`${path}?${new URLSearchParams(params)}`)
    .then(rejectIfNotOk)
    .then((response) => readJson<T>(response))

export const postJson = <I, O>(path: string) => (body: I): Promise<O> =>
  fetch(path, { method: 'POST', body: JSON.stringify(body) })
    .then(rejectIfNotOk)
    .then((response) => readJson<O>(response))
```

## useUrlState (Next.js)

`parse` is a module-level function, so its identity is stable. Native `history.replaceState` stays in sync with `useSearchParams`. The route file puts a `<Suspense>` above the screen, or `next build` fails on `useSearchParams` in a static route. TanStack Start and Expo Router don't need this: see the route file variants in `examples.md`.

```ts
// src/shared/lib/useUrlState.ts
'use client'

import { usePathname, useSearchParams } from 'next/navigation'
import { useMemo } from 'react'

export const useUrlState = <T extends Record<string, string>>(parse: (params: URLSearchParams) => T) => {
  const searchParams = useSearchParams()
  const pathname = usePathname()
  const state = useMemo(() => parse(new URLSearchParams(searchParams.toString())), [searchParams, parse])

  const update = (patch: Partial<T>) => {
    const next = new URLSearchParams(searchParams.toString())
    Object.entries(patch).forEach(([key, value]) => (value == null ? next.delete(key) : next.set(key, String(value))))
    const query = next.toString()
    window.history.replaceState(null, '', query ? `${pathname}?${query}` : pathname)
  }

  return [state, update] as const
}
```

## Layer test

The layer rules as a test, so they hold without a reviewer. It reads every import, aliased or relative, including `import type`, re-exports and dynamic imports. Set the route folder per the Stack Map. With these rules passing, an import cycle can only sit inside one slice or `shared/`. During a refactor, existing violations go in `KNOWN`, and that list only shrinks.

```ts
// src/test/layers.test.ts
import { readdirSync, readFileSync } from 'node:fs'
import { dirname, join, relative, resolve, sep } from 'node:path'
import { expect, it } from 'vitest' // Jest: drop this line

const SRC = resolve('src')
const LAYERS = ['app', 'providers', 'screens', 'blocks', 'features', 'entities', 'shared'] // top to bottom
const SLICED = new Set(['screens', 'blocks', 'features', 'entities'])
const KNOWN = new Set<string>([])

const IMPORT = /(?:from|import)\s*\(?\s*['"]([^'"]+)['"]/g
const PUBLIC_API = /^index(\.server)?(\.tsx?)?$/

const sourceFiles = (dir: string): string[] =>
  readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) return sourceFiles(path)
    return /\.tsx?$/.test(entry.name) && !/\.(test|spec)\.tsx?$/.test(entry.name) ? [path] : []
  })

const targetOf = (file: string, specifier: string) => {
  if (specifier.startsWith('@/')) return join(SRC, specifier.slice(2))
  return specifier.startsWith('.') ? resolve(dirname(file), specifier) : null
}

const place = (path: string) => {
  const [layer = '', slice = '', ...rest] = relative(SRC, path).split(sep)
  return { layer, slice, rest }
}

const problemWith = (file: string, target: string) => {
  const from = place(file)
  const to = place(target)
  const fromRank = LAYERS.indexOf(from.layer)
  const toRank = LAYERS.indexOf(to.layer)
  if (fromRank < 0 || toRank < 0) return null
  if (toRank < fromRank) return 'imports up'
  if (!SLICED.has(to.layer)) return null
  if (from.layer === to.layer) return from.slice === to.slice ? null : 'imports a sibling slice'
  const isPublic = to.rest.length === 0 || (to.rest.length === 1 && PUBLIC_API.test(to.rest[0] ?? ''))
  return isPublic ? null : 'bypasses the public API'
}

const violations = sourceFiles(SRC).flatMap((file) =>
  [...readFileSync(file, 'utf-8').matchAll(IMPORT)].flatMap(([, specifier = '']) => {
    const target = targetOf(file, specifier)
    const problem = target && problemWith(file, target)
    return problem ? [`${relative(SRC, file)} -> ${specifier}: ${problem}`] : []
  }),
)

it('layers import only downward, through public APIs', () => {
  expect(violations.filter((violation) => !KNOWN.has(violation))).toEqual([])
})
```
