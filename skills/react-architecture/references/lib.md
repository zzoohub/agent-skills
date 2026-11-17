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

`compose` infers right to left, so a generic function passed to it (an HoC, an unannotated lambda) gets `unknown`. `pipe` starts from a value and infers forward, which is why an HoC stack is `pipe(Screen, inner, outer)`. Use `compose` for non-generic functions built before their data, such as state transitions.

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

A domain that needs a key the factory doesn't have extends it in one place, under `all()`, so `all()` still covers every query:

```ts
const keys = createQueryKeys('products')

export const productKeys = { ...keys, summary: () => [...keys.all(), 'summary'] as const }
```

## http

The transport. The path is fixed first and the call comes later, so a request function is one partial; a path that carries an id takes the id first:

```ts
const fetchProducts = getJson<Product[], ProductFilters>(`${API_URL}/api/products`)
const fetchProduct = (id: string) => getJson<Product>(`${API_URL}/api/products/${encodeURIComponent(id)}`)
const createProduct = postJson<{ name: string }, Product>(`${API_URL}/api/products`)
const deleteProduct = (id: string) => deleteJson<void, void>(`${API_URL}/api/products/${encodeURIComponent(id)}`)

fetchProducts(filters, { signal })
fetchProduct(id)(undefined, { signal })
createProduct({ name })
deleteProduct(id)()
```

What it does, so that no call site checks `res.ok` or calls `res.json()`:

- `!ok` rejects with an `ApiError` carrying `status` and the failure body (parsed JSON, or the text), built by a factory and told apart by `isApiError`. A 2xx body that isn't JSON rejects the same way instead of leaking a `JSON.parse` error: a proxy's HTML page, or a static host answering a wrong path with `index.html`.
- An empty 201 or 204 is a success and resolves to `undefined`. A connection failure rejects as `fetch` threw it.
- A body goes out as JSON with `Content-Type: application/json`; an `undefined` body sends the method alone.
- A GET takes `init` after its params, so a query passes its `signal` and a superseded request is cancelled. Body methods take the body alone, so `mutationFn: createProduct` is safe as is: the mutation's second argument has nowhere to land.

Encode path segments that come from a route or a user. A params type is a `type` alias: an `interface` has no implicit index signature and fails the `Record<string, string>` constraint. A query that also runs on the server (a prefetch, a loader) needs an absolute URL, so paths start from `API_URL`; use your stack's public prefix (`NEXT_PUBLIC_`, `VITE_`, `EXPO_PUBLIC_`).

```ts
// src/shared/config/env.ts
export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? ''
```

```ts
// src/shared/api/http.ts
export type ApiError = Error & { name: 'ApiError'; status: number; body: unknown }

const createApiError = (status: number, body: unknown): ApiError =>
  Object.assign(new Error(`HTTP ${status}`), { name: 'ApiError' as const, status, body })

export const isApiError = (error: unknown): error is ApiError =>
  error instanceof Error && error.name === 'ApiError'

type Parsed = { ok: true; value: unknown } | { ok: false }

const parseJson = (text: string): Parsed => {
  try {
    return { ok: true, value: JSON.parse(text) }
  } catch {
    return { ok: false }
  }
}

const rejectIfNotOk = async (response: Response) => {
  if (response.ok) return response
  const text = await response.text()
  const parsed = parseJson(text)
  throw createApiError(response.status, parsed.ok ? parsed.value : text || undefined)
}

const readJson = async <T,>(response: Response): Promise<T> => {
  const text = await response.text()
  if (!text) return undefined as T
  const parsed = parseJson(text)
  if (!parsed.ok) throw createApiError(response.status, text)
  return parsed.value as T
}

const withParams = (path: string, params?: Record<string, string>) => {
  const query = new URLSearchParams(params).toString()
  return query ? `${path}?${query}` : path
}

export const getJson =
  <T, P extends Record<string, string> = Record<string, string>>(path: string) =>
  (params?: P, init?: RequestInit): Promise<T> =>
    fetch(withParams(path, params), init)
      .then(rejectIfNotOk)
      .then((response) => readJson<T>(response))

const sendJson =
  (method: 'POST' | 'PUT' | 'PATCH' | 'DELETE') =>
  <I, O>(path: string) =>
  (body: I): Promise<O> =>
    fetch(
      path,
      body === undefined
        ? { method }
        : { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) },
    )
      .then(rejectIfNotOk)
      .then((response) => readJson<O>(response))

export const postJson = sendJson('POST')
export const putJson = sendJson('PUT')
export const patchJson = sendJson('PATCH')
export const deleteJson = sendJson('DELETE')
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
