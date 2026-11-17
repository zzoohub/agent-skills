---
name: hexagonal-backend
description: |
  Hexagonal (ports & adapters) backend implementation, with verified guides for Axum, FastAPI, Hono and NestJS: a domain that imports no framework, ports only where earned, one transaction per command, races decided by the database, outbox and idempotency keys when triggered, actor and tenant enforced twice, RFC 9457 errors, cursor pagination, deadlines, probes and shutdown, tests on real PostgreSQL.
  Use when: building or changing a backend API, domain logic, DB adapters, queue / webhook / cron handlers, workers or an agent tool surface.
  Do NOT use for: system or technology choice (software-architecture); schema design or live migrations (database-design); code review (review-checklists).
---

# Hexagonal Backend

## Premise

**A backend is a set of rules that must stay true while everything around them misbehaves.** Requests arrive twice, and at the same instant. A process dies between two statements. The caller may not be who it claims to be. The framework, the driver and the provider all get replaced, now mostly by an agent that knows only what the code in front of it shows. The hexagon is the arrangement that survives this: the rules sit in the middle and import nothing, everything that performs I/O sits at the edge behind an interface the rules own, and one use case per command decides what commits together.

Seven rules, in the order they bite:

1. **Dependencies point at the rules.** The domain imports no framework, driver, ORM or SDK, and a build check fails when it does. That is what lets the rules be tested in milliseconds and the edge be replaced without touching them.
2. **Nothing is built without its trigger.** A port, a layer, an outbox, an idempotency store: each exists because a named fact calls for it ([Size the change](#size-the-change)). Structure the change does not need is weight on every later change.
3. **The database decides races.** Whatever two requests can race on is settled by a constraint or a conditional write, in the statement that changes the data. A check in application code only buys a better error message.
4. **A command commits whole, and once.** One transaction per command, owned by the use case. What must happen afterwards is a row in that transaction. A retry of the same intent finds the first result.
5. **The edge trusts nothing and answers in one shape.** Identity becomes an explicit `Actor` at the edge, the use case decides authorization, the tenant is enforced twice, input is bounded, and every failure, the framework's own included, leaves as the same error document.
6. **Every wait has a bound.** A deadline at the edge, a timeout on every dependency inside it, retries in exactly one layer, a shutdown that drains inside the platform's grace period. Slow is the common failure, and an unbounded wait turns one slow dependency into an outage.
7. **Proved by running.** Rules get table tests; everything else runs against the real database with the race actually raced. A guard nobody has seen fail is a hope.

**The rules alone are not enough to write code.** Each stack breaks some of them silently (a framework error that bypasses your handler, a timeout that cancels nothing), so read the stack guide before the first line.

## Read first

**Binding inputs** (defaults; the caller may redirect). The architecture doc `docs/arch/system.md`: §1 Service Pattern (the declared style per context), §2 Core Technology and Published Contracts, §3 Data and Tenancy, §4 Release Model, §5 Write-path Integrity, Observability Contract, Security and Resilience. Also `docs/arch/database.md`, the feature spec, and the AI feature doc (`docs/arch/ai-features/{feature}.md`) when a model is in the path. Where one is absent, apply this skill's defaults and list them as assumptions in the report.

**Existing code and published contracts win.** Mirror the service's conventions (paths, envelopes, error shape, naming, test style); the defaults here are for new surfaces. Changing a published contract is a versioned change, never a cleanup.

**The stack** is whatever the manifest of the package being changed depends on. Never add a second web framework to a service.

| Manifest | Stack | Guide |
|---|---|---|
| `Cargo.toml` depends on `axum` | Axum (Rust) | `references/axum/guide.md` |
| `pyproject.toml` depends on `fastapi` | FastAPI (Python) | `references/fastapi/guide.md` |
| `package.json` depends on `hono` | Hono (TypeScript on Node, Bun, Deno or Workers) | `references/hono/guide.md` |
| `package.json` depends on `@nestjs/core` | NestJS (TypeScript) | `references/nestjs/guide.md` |

Another framework (Express, Fastify, Actix, Django, Spring, Go): apply the rules in its idiom, and reproduce the guard each guide ships before trusting it.

**Greenfield**, first match wins: the architecture doc's Core Technology row and its ADRs → the caller's or the organization's constraints, runtime target included → the adopted house profile (software-architecture `references/house-stack.md`, if available) → Workers or another edge runtime: Hono; a core on the Python data or model stack: FastAPI; any other container service: Axum, or NestJS when the team wants framework dependency injection and modules. Still open: ask. A subagent takes the fallback and reports it as an open question.

## Size the change

Before writing code, say in a few lines what this change triggers. Most changes trigger two or three rows; a read endpoint added to an existing service triggers almost none.

| The change… | Build | Lighter when |
|---|---|---|
| holds a rule beyond field validation, moves money, decides authorization or cannot be undone | a model, a use case and ports ([Shape](#shape)) | supporting CRUD: the same layout with no model, only a use-case function and a repository |
| touches tenant data, or writes more than one row that must agree | a unit of work the use case owns: it names the tenant and holds every write of the command | one statement on a table with no tenant policy is its own transaction |
| can race with itself or another command | the guard that fits the write ([Write path](#write-path)) | never skipped; choose it by the write's shape |
| pairs a state change with an effect that must happen elsewhere | an outbox or job row in the same transaction, and a relay or worker | losing the effect is acceptable: call it after commit in its own try-and-log |
| may be retried, and a duplicate would cost something | natural idempotency first, an idempotency key when the first response must be replayed | reads; writes that set a state |
| consumes messages, webhooks or schedules | a verified sender, dedup where the effect commits, an ack after the commit | |
| calls something outside the process (an API, a model, another service) | a port, an adapter with a deadline and the one retry layer, a deterministic fake | |
| returns a collection | a keyset cursor with a bounded limit | a small admin set may page by offset |
| starts a new service | the edge (error pipeline, auth, limits, deadline), probes, shutdown, telemetry, the boundary check | an existing service: reuse its edge unchanged |
| serves agents as callers | a tool adapter over the same use cases ([Agents on both sides](#agents-on-both-sides)) | |

The architecture doc's Write-path Integrity and Resilience tables name these per command and per dependency. Where they exist, they decide.

## Shape

| Location | Holds |
|---|---|
| `domain/<context>/` | the model and its rules, errors, ports, use cases |
| `inbound/<transport>/` | `http`, `tools`, `tasks`, `webhooks`: parsing, authentication, mapping to and from the wire |
| `outbound/<target>/` | `postgres`, one folder per provider: queries, row mapping, error translation |
| bootstrap | config validation, wiring, start, shutdown |
| migrations | outside every layer |

**Dependencies point inward.** `domain/` imports nothing from `inbound/`, `outbound/` or any package that does I/O. Inbound and outbound never import each other, and only bootstrap names concrete adapters. Each stack guide ships the check that fails the build on a violation.

**Inside the domain, decisions are pure and use cases do the I/O.**

- The **model** is data plus functions that decide: given the current state and a request, return the next state or an error. It performs no I/O and never reads the clock or generates an id; time and ids are arguments. This is the part worth a table of cases, and it needs no test doubles.
- A **use case** is one command or query: load, decide, save, inside one transaction. It takes the `Actor` as its first argument and returns domain values, never wire or row types.
- A **port** is an interface the domain owns for something outside the process or non-deterministic: a store, a broker, a provider, a model, the clock, id generation. It speaks the use case's language (`transition(article, from)`, not `save(entity)`), and its adapter is the only code that knows the driver.

```ts
// domain/publishing/article.ts: a decision is a pure function
export function publish(article: Article, now: Date): Article {
  if (article.status !== "draft") throw new DomainError("invalid_transition", `Only a draft can be published; this article is ${article.status}`);
  return { ...article, status: "published", publishedAt: now, updatedAt: now };
}

// domain/publishing/use-cases.ts: the use case does the I/O around it
publish(actor: Actor, id: string): Promise<Article> {
  return this.#uow.run(actor, async (tx) => {                      // one transaction, scoped to the actor's tenant
    const current = (await tx.articles.get(id)) ?? notFound(id);   // another tenant's row is invisible: 404
    if (!canEdit(actor, current)) throw new DomainError("forbidden", "Only the author or an editor may publish");
    const saved = await tx.articles.transition(publish(current, this.#clock.now()), "draft");
    if (!saved) throw new DomainError("invalid_transition", "The article is no longer a draft"); // the database decided the race
    await tx.outbox.append(articlePublished(saved));               // commits with the state change, or not at all
    return saved;
  });
}
```

**What a port is not**: a wrapper around a pure function; an interface with one implementation that no test replaces and that hides no call out of the process; a generic repository that mirrors the ORM; a mapper class between two shapes that never differ. Delete them (rule 2).

**Depth follows the declared style.** Core contexts get the full shape. A supporting context keeps the layout and drops what it has no use for: no model functions when the only rules are field validation (the schema at the edge and the constraints on the table carry them), no events, reads that return the wire shape from one query. Where the architecture doc declares a context a transaction script, its handler and SQL may share a module outside `domain/`, listed in the boundary check as its own layer. Every shape keeps the non-negotiables: the dependency direction, the Actor and the tenant scope, one transaction per command, the error contract. Promote a context to the full shape when a real rule, a second adapter or a second inbound surface appears.

## Domain

- **An invariant lives in the narrowest place that can hold it.** A type, when a value can be wrong on its own (a slug, an amount): validate at construction, so an invalid one cannot exist. A model function, when a transition can be wrong. A constraint or conditional write, when two requests can make it wrong together (rule 3). Reconciliation, when it spans services.
- **Values that cross a boundary.** Money is integer minor units or decimal, never float. Instants are UTC. 64-bit ids and amounts travel as JSON strings, because JavaScript rounds above 2^53. Text carries no U+0000 (PostgreSQL rejects it), and lengths count code points.
- **Errors are a closed set of kinds**: invalid, malformed (input that cannot be read at all, such as an undecodable cursor), not found, forbidden, conflict (already exists, invalid transition, version), precondition failed, unavailable. Anything else is a bug and keeps its cause. The domain never raises a transport error, and adapters translate driver errors into these kinds. A closed set lets one mapping render every failure and makes an unmapped new kind a compile or test failure.
- **Stored rows are trusted.** Rehydrate them without creation-time validation, or tightening a rule breaks every read of older data.
- **Boundaries.** What must change atomically shares a context and a transaction. Across contexts nothing is atomic: reference by id, call, or publish an event. Start with few, large contexts and split on friction you can point to.

## Write path

The architecture doc's Write-path Integrity default and rows are binding. The logical patterns are in software-architecture `reliability-patterns.md`, the tables and claim statements in database-design `references/integrity.md` (both if available). This section says where each piece lives in code.

**The use case owns the transaction** through a unit-of-work port. `run(actor, work)` opens it, sets the tenant for it, hands `work` repositories bound to that transaction and tenant, and commits or rolls back (a `begin(actor)` and `commit` pair where the language cannot type the closure). Repositories, the outbox and the idempotency completion run inside and never begin or commit. An edge wrapper that must commit with the use case (the idempotency completion, a webhook's inbox row) shares that transaction: a nested `run` for the same tenant joins the open one, and one for another tenant is refused. Nothing leaves the process while it is open: no API call, no model call, no publish.

**The guard follows the shape of the write.**

| The write | Guard | A lost race is |
|---|---|---|
| must be unique | a UNIQUE constraint, its violation mapped by constraint name | that conflict |
| computes a new value from the old (stock, balance, counter) | one conditional update: `SET qty = qty - $2 WHERE … AND qty >= $2` | a domain outcome |
| changes state | a guarded transition: `… WHERE id = $1 AND status = 'draft'` | an invalid transition |
| edits what the client read | a `version` column, the write conditional on the version read; `If-Match` over HTTP | a version conflict, or 412 under `If-Match` |
| depends on other rows | a constraint, a lock on a row every writer touches, or SERIALIZABLE with the whole transaction retried | what database.md says |

Zero rows affected is the answer, never a reason to retry. Reading in the application and then writing is a race however short the gap. Let the statement assign the new version (`SET version = version + 1 … RETURNING`) and continue with the stored row. A version computed in memory is safe only in a statement guarded on the version read; under a status guard it collides with a concurrent edit. Take a row lock only for a short decision over several rows that one conditional statement cannot express, and never across a call out of the process. Reads that must see the write go to the primary.

A deadlock or a serialization failure aborts the whole transaction, never one statement. The default answer is a 503 with `Retry-After`, and the client retries under its idempotency key. Where database.md chooses SERIALIZABLE, or the stack can re-run the outermost unit from the top, the unit of work retries the whole transaction instead, bounded and with jitter. Each stack guide says which it does.

**Effects that must happen** are rows in the command's transaction: an outbox row for something to publish, a job row for something to do, each carrying the aggregate's new version as its sequence and the trace context. A relay or worker claims rows with `FOR UPDATE SKIP LOCKED`, acts outside any transaction, backs off with jitter and dead-letters after N attempts. Event payloads are published contracts: additive changes only, a breaking one ships as a new type beside the old. An effect whose loss is acceptable is called after commit, in its own try-and-log, and never changes the result.

**Retried commands**, lightest rung first:

1. **Make the command naturally idempotent**: a client-chosen id as the key of the insert, an upsert, a transition that treats "already there" as success.
2. **An idempotency key** when the first response must be replayed or no natural key exists (payments, creates with server-made ids). One wrapper at the edge applies it, never per-handler code. Only this request's insert, or its conditional takeover of an expired lease, grants execution; a read never does. The stored response commits in the use case's transaction under the lease. A 2xx, and a 4xx that the body or the state decided, are stored and replayed. A 5xx, a failure before commit, and an outcome decided by a header outside the request hash (406, 412, 415, 428) release the key instead, or the corrected retry would replay the error. The same key with a different request is a client bug (422); a live lease is a 409 with `Retry-After`.
3. **An effect outside the database** cannot join the transaction: commit the intent with a lease first, call with a key derived from it, record the outcome, and let a retry resume instead of restart.

**Bounded work.** Every list, include and bulk path has a hard maximum in the port's contract. Related rows load in batches (a join, `IN`, a loader), never per item.

## Edge

**A handler parses, calls one use case and maps the result.** No SQL, no ORM and no domain types on the wire; OpenAPI derives from the inbound types alone. One app factory builds the same app for production and for tests, which serve it without binding a port.

**One error pipeline.** Every failure leaves as `application/problem+json` (RFC 9457): domain errors, validation, and the 400, 404, 405, 413 and 415 that the framework and its libraries raise by themselves, which arrive in their own shape and bypass a naive handler. Each stack guide shows where they escape. An unmapped error is logged once with the request id and answered with a generic 500, never exception text or SQL. The status mapping, the problem registry and the wire conventions for a new API are in `references/http-api.md`.

**Whatever can answer is wrapped by what must mark every answer.** Request id and CORS go outermost, and the error renderer sits inside them, whether it is a layer or the framework's error hook. The deadline and any panic handling come next, then authentication, then routes. A 503 produced outside CORS reaches a browser as a CORS failure, and a 500 produced outside the request id cannot be found in the logs.

**Input is bounded before it is believed.** Every route has a body limit, and schemas cap items, length and depth. Write bodies refuse unknown members, and so does the query string of every route that reads one. That keeps owner, tenant and role out of requests, and a client never mistakes an ignored filter for an applied one. Refusing any query string on a route that reads none is stricter still, and worth it where the schema library makes it one line. Sort and filter names come from an allow-list mapped to indexed columns. A sender's webhook payload is the exception: parse it tolerantly, because providers add fields.

**Who is calling.**

- **Authentication** builds the `Actor` at the edge: tenant, subject and roles. The use case receives it as an argument, never from ambient state. Pin the token algorithms and require `iss`, `aud`, `exp` and `sub`. A key source that cannot be reached, or that answers something other than a key set, is a dependency failure (503), not a 401. The rest of the checklist: review-checklists `security/auth.md` and `security/api.md`, if available.
- **Authorization** is decided in the use case, where the resource's state is known.
- **The tenant is enforced twice.** The transaction-bound repository puts the tenant predicate in every query, and row-level security catches the query that forgot: the unit of work sets the tenant as the transaction's first statement, and the application connects as a role that neither owns the tables nor bypasses RLS (database-design `references/access.md`, if available). A policy shows a query nothing until its transaction names a tenant, so a read of tenant data runs in a unit of work as well. Infrastructure tables (outbox, inbox, idempotency keys) are worked across tenants by relays and workers, so they carry no policy and no request path exposes them. The tenant scope covers by-id reads, lists, search, exports, bulk, sub-resources, job payloads (the worker re-establishes the tenant) and cache keys. Another tenant's resource is a 404. Where database.md records a decision against RLS, the tenant-bound repository stands alone and the cross-tenant tests carry the weight. A single-tenant service skips all of this: its Actor names no tenant and its unit of work sets none.

**Lists page by keyset.** The port takes `(cursor, limit)` and returns the items and the next cursor; the adapter fetches `limit + 1`. The cursor carries every sort key at the database's precision: a JavaScript `Date` drops PostgreSQL's microseconds, and pages repeat or loop, which is why creation order pages on a UUIDv7 id alone. It is opaque, bound to its sort and filters, and decoded only in the store adapter. A cursor is a position, not a permission, and not a change feed.

**Other triggers are inbound adapters too.** Queues, webhooks, schedules and streams sit on an internal router, outside public auth and OpenAPI, and call the same use cases.

- **Verify the sender** cryptographically, over the raw bytes, before parsing: a signature with a timestamp window, or an OIDC token with an audience check. A queue header is not an identity.
- **Acknowledge after the commit** of the effect or of its inbox or job row. A transient failure answers 429 or 503 so the sender backs off. A permanent one is recorded and acknowledged, or dead-lettered, because the sender would otherwise retry it forever. A signed payload that fails its schema is permanent too, and a log line is its record when it names no tenant to record it under.
- **Dedup where the effect commits**: an inbox row in the same transaction, or an idempotent upsert, so a redelivery acknowledges without a second effect.
- **A slow effect is recorded and processed later**, so the sender's timeout never decides the outcome. A scheduled job runs one instance at a time, in an explicit time zone, under a lease longer than its slowest run.

## Agents on both sides

The hexagon exists so that one core can serve several kinds of caller and use several kinds of provider. Agents are now both.

**An agent calling in** (a tool server, an in-app tool call, another party's assistant) gets its own inbound adapter over the same use cases. Its tool schemas are inbound types and a published contract. The `Actor` then carries both the person and the agent acting for them, so policy and audit can tell them apart, and the use case authorizes exactly as it does for HTTP. Tools are idempotent and safe to retry, long work is a job the caller polls, and no protocol type enters the domain.

**A model called out to** is a provider behind a port. The port is task-level (`draftReply(ticket)`, never `chat(messages)`). Its adapter owns the SDK, the pinned model version, the deadline and the retry layer, and a deterministic fake stands in for it in tests. Its output is untrusted input: the adapter parses it into domain types, branching on truncation and refusal, before any rule sees it. A model call never runs inside a transaction. What the model may do is decided by code: the use case authorizes each proposed action with the Actor, and caps stop the work instead of reporting it. The design of the feature itself belongs to the ai-architecture capability, if available.

## Bounds

The architecture doc's Resilience default and rows are binding.

- **A deadline per request**, set at the edge. Every outbound call gets a connect and a total timeout inside what remains. A deadline cannot undo a commit, so whatever must follow a commit goes through the outbox.
- **The database is bounded too**: `statement_timeout`, `idle_in_transaction_session_timeout` and UTC on every session, set as role defaults where a transaction-mode pooler refuses startup options; acquire and connect timeouts on the pool; pool size × instances inside the database's connection budget. Cancelling a request rarely cancels its query. The statement timeout does. A `transaction_timeout` ends the session, not the statement, so keep it above the statement timeout.
- **Retries live in one layer**, usually the dependency's adapter: idempotent operations only, exponential backoff with full jitter, a budget, `Retry-After` honored, never inside an open transaction.
- **Shed early.** A concurrency cap per dependency, and a 429 or 503 with `Retry-After` instead of a queue that grows.

## Run

- **Liveness** answers 200 when the process can answer and checks nothing else.
- **Readiness** is local. At startup, validate config, make one database round-trip and refuse a role that bypasses RLS, then latch. Afterwards report only "initialized and not draining". A readiness probe that queries a shared dependency removes every replica at once when that dependency slows; its health belongs in metrics and alerts. On a platform without probes, an external synthetic check that touches the database replaces it.
- **Shutdown** on SIGTERM: mark draining (readiness 503) → keep serving while the load balancer deregisters → stop accepting and close idle connections → drain in-flight requests under the deadline → stop relays and workers, finishing or releasing their leases → close pools → flush telemetry → exit. The sum stays below the platform's grace period.
- **Config and secrets** are validated at startup and fail loudly, without quoting the values they reject. An unset environment name never means development, and no placeholder secret works outside it.
- **Telemetry from the first deploy**: server, database and client spans named by route template; JSON logs carrying `request_id`, `trace_id` and `span_id`, with a redaction list at the logger; the age of the oldest pending outbox row and the dead-letter depth as metrics; trace context carried through the outbox. The domain records events through a port or the stack's standard facade. Sampling, cardinality and SLOs come from the architecture doc's Observability Contract.
- **Migrations** run as a release step before the code that needs them, never from every replica at startup, and the code works on both schema versions. database-design's SQL is the source of truth where it exists; ORM models mirror it, and CI fails on drift. Lock-safe execution belongs to the database-design capability, if available.

## Proof

Write the test before the behavior it proves, at the level where the risk lives.

| Level | Proves | Runs on |
|---|---|---|
| Model | each rule and transition, as a table of cases | nothing: no doubles |
| Use case and adapter | queries, constraints, guards, transaction scope, tenant isolation | real PostgreSQL, migrated from empty by the release step |
| HTTP | the wire contract, the error pipeline, authentication | the app factory in process, on the same database |

**Fake only what cannot run here**: a provider, a model, a broker, a key source, the clock. The database can run here. An in-memory repository that imitates its constraints is a second implementation that drifts and cannot race. To inject a failure, wrap the real adapter and make one call fail, or make the database itself refuse the call.

**The test pool connects as the application's role.** On the owner or a superuser, row-level security is off without an error and every tenant test passes while testing nothing. Startup refuses such a role for the same reason.

**The risk set for a write path.** Two concurrent duplicate creates end in one success and one conflict. A stale version is refused. An idempotency key replays, rejects a mismatch and reports an in-flight request. A failure at the outbox step rolls the state change back with it. Another tenant's id answers 404 and never appears in a list, and a count with no tenant predicate, run inside a unit of work, sees only that tenant's rows. A cursor walk over rows that tie on the sort key visits each once. Every error in the registry, the framework's 401, 404 and 405 included, is a problem document. Run each guard once without its mechanism to see the test fail; a guard against a rare plan or interleaving needs a test that forces it.

**Standing checks in CI.** The boundary check, whose failure message says how to fix the import, and which fails when it examined no modules or skipped one that exists on disk. Migrations forward from empty. The generated OpenAPI document, committed, with a breaking-change diff against the base branch.

## Anti-patterns

| Looks like | Why it fails | Instead |
|---|---|---|
| `IUserRepository`, `UserRepositoryImpl`, `UserMapper`, `UserDto` and `UserEntity` for one table | five files that change together and hide nothing | one port where a store is crossed; map rows in the adapter |
| a use case that only forwards to the repository | a hop on every change | drop the model for that context, or put the rule there |
| `if (await repo.exists(slug)) throw …` before the insert | two requests pass the check together | the UNIQUE constraint, mapped by name |
| `await tx.commit()` then `await bus.publish(event)` | a crash between them loses the event | an outbox row in the transaction |
| a model function that reads the clock, makes an id or calls a provider | the rules need doubles to test | time and ids as arguments; providers behind ports, called by the use case |
| the ORM entity as the model and as the response body | a column rename becomes an API change | three shapes at two boundaries: row, model, wire |
| the `Actor` read from request context inside the domain | a queue, a tool call or a test cannot supply it, and a missing one fails late | an explicit first argument |
| a mocked repository under a use-case test | the test passes while the SQL is wrong | real PostgreSQL |
| an outbox, idempotency keys and a relay for a settings form | machinery without a trigger | rule 2 |

## Hand-off

Report what the change triggered and what was built for each trigger, the assumptions taken where a binding input was absent, which test proves which risk, and anything not run.

- [ ] The domain imports no framework, driver or SDK, and the boundary check is green on a non-zero module count
- [ ] Every port crosses the process boundary or hides non-determinism; nothing only forwards
- [ ] Every use case takes an Actor; every query on tenant data is tenant-bound and runs as a role RLS applies to; a foreign id answers 404
- [ ] One transaction per command, owned by the use case, with nothing leaving the process inside it
- [ ] Each write has the guard its shape calls for; must-happen effects are rows in the transaction
- [ ] Every error is a problem document, the framework's own included; the request id is on every response
- [ ] Lists page by keyset at the database's precision, with a bounded limit
- [ ] The deadline, the database timeouts and the pool bounds are set; retries live in one layer
- [ ] Liveness checks nothing; readiness is latched and local; shutdown fits the platform's grace
- [ ] The risk set runs green on real PostgreSQL and each guard was seen to fail; published contracts are unchanged or versioned

## Reference files

Read the section a change touches, not the whole file.

| File | Read when |
|---|---|
| `references/http-api.md` | Defining or changing routes: wire conventions, the problem registry, status mapping, worked exchanges for idempotency, `If-Match`, pagination, async jobs, bulk, SSE, webhooks |
| `references/<stack>/guide.md` | Always, before writing code: the decisions the stack forces, where it breaks the rules, its traps, and the dated version baseline |
| `references/<stack>/slice.md` | Adding a command or query: model, use cases, ports, the PostgreSQL adapter with its tenant wiring, routes, error mapping |
| `references/<stack>/reliability.md` | A trigger calls for it: idempotency wrapper and store, outbox and relay, inbox and webhook receiver |
| `references/<stack>/service.md` | Starting a service or changing its edge: app factory and layer order, authentication, config, probes, shutdown, telemetry, migrations, the boundary check |
| `references/<stack>/tests.md` | Writing the proof: harness on real PostgreSQL, model tests, the risk set over HTTP and adapters |

The four example files of a stack are one project that compiles and passes its tests on the versions in the guide's baseline. Library APIs drift faster than this file: check the baseline's date, and verify against the official docs with a doc-lookup tool if one is available.
