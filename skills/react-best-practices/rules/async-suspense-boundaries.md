---
title: Stream Slow Regions Behind Suspense Boundaries
tags: async, suspense, streaming, rsc
---

An await before returning blocks everything up to the nearest `<Suspense>` boundary. Move it into the component that uses the data and wrap that component: the shell renders now and the slow region streams in.

**Incorrect (the whole page waits for one query):**

```tsx
async function Page() {
  const data = await fetchData()
  return <Layout><Header /><DataDisplay data={data} /><Footer /></Layout>
}
```

**Correct (only the data region waits):**

```tsx
function Page() {
  return (
    <Layout>
      <Header />
      <Suspense fallback={<DataSkeleton />}><DataDisplay /></Suspense>
      <Footer />
    </Layout>
  )
}

async function DataDisplay() {
  const data = await fetchData()
  return <div>{data.content}</div>
}
```

**Alternative (one request, several consumers):** start the fetch without awaiting and pass the promise down; Client Components unwrap it with `use()`, Server Components with `await`. In TanStack Start, return the unawaited promise from the loader and unwrap it the same way.

```tsx
function Page() {
  const dataPromise = fetchData()
  return (
    <Suspense fallback={<DataSkeleton />}>
      <DataDisplay dataPromise={dataPromise} />
      <DataSummary dataPromise={dataPromise} />
    </Suspense>
  )
}

function DataSummary({ dataPromise }: { dataPromise: Promise<Data> }) {
  const data = use(dataPromise)
  return <div>{data.summary}</div>
}
```

Streaming moves the wait; it doesn't remove it. If the region's query returns the same result for every user or every member of a tenant, also cache it at that scope ([server-cache-cross-request](./server-cache-cross-request.md)).

Await whatever decides the status code or a redirect (`notFound()`, auth) before the first boundary streams; once streaming starts, the status is 200. Use one boundary per independently slow region, with a fallback sized to the final layout so nothing shifts, inside an error boundary with a retry; siblings that should appear together share one boundary.

*Break:* await data that reliably arrives in under ~150 ms; a fallback that flashes is worse than the wait.

Source: https://nextjs.org/docs/app/api-reference/file-conventions/loading
