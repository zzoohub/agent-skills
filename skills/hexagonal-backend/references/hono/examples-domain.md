# Hono examples — domain and use cases

The publishing context in plain TypeScript; no framework, ORM or driver import. Each `file=` block is a complete file of the verified project.

## Contents

1. [Errors and shared ports](#errors-and-shared-ports)
2. [Article aggregate](#article-aggregate)
3. [Publishing ports](#publishing-ports)
4. [Use cases](#use-cases)
5. [Test doubles and tests](#test-doubles-and-tests)

## Errors and shared ports

```ts file=src/domain/shared/errors.ts
export type ErrorCode =
  | "invalid"
  | "malformed"
  | "not_found"
  | "forbidden"
  | "already_exists"
  | "invalid_transition"
  | "version_conflict"
  | "precondition_failed"
  | "unavailable";

export type Issue = Readonly<{ field: string; code: string; detail: string }>;

export class DomainError extends Error {
  override readonly name = "DomainError";
  readonly code: ErrorCode;
  readonly issues: readonly Issue[];

  constructor(code: ErrorCode, message: string, options: { cause?: unknown; issues?: readonly Issue[] } = {}) {
    super(message, { cause: options.cause });
    this.code = code;
    this.issues = options.issues ?? [];
  }
}
```

```ts file=src/domain/shared/ports.ts
export type Actor = Readonly<{ tenantId: string; subject: string; roles: readonly string[] }>;

export const systemActor = (tenantId: string, name: string): Actor => ({
  tenantId,
  subject: `system:${name}`,
  roles: ["moderator"],
});

export interface Clock {
  now(): Date;
}

/** UUIDv7 (time-ordered). */
export interface IdGenerator {
  next(): string;
}

export type PageRequest = Readonly<{ cursor?: string | undefined; limit: number }>;
export type Page<T> = Readonly<{ items: readonly T[]; nextCursor: string | null; hasMore: boolean }>;

export type DomainEvent = Readonly<{
  type: string;
  version: number;
  tenantId: string;
  aggregateType: string;
  aggregateId: string;
  aggregateSeq: number;
  payload: Record<string, unknown>;
}>;

export type OutboxMessage = DomainEvent & Readonly<{ id: string; headers: Record<string, string> }>;

export interface EventPublisher {
  publish(message: OutboxMessage): Promise<void>;
}
```

```ts file=src/domain/shared/idempotency.ts
export type StoredResponse = Readonly<{ status: number; headers: Record<string, string>; body: Uint8Array }>;

export type Acquired =
  | Readonly<{ kind: "execute"; lease: string }>
  | Readonly<{ kind: "replay"; response: StoredResponse }>
  | Readonly<{ kind: "mismatch" }>
  | Readonly<{ kind: "in_flight" }>;

export interface IdempotencyStore {
  /** "execute" only when this request's INSERT, or its takeover of an expired lease, won. */
  acquire(scope: string, key: string, requestHash: string): Promise<Acquired>;
  release(scope: string, key: string, lease: string): Promise<void>;
  purgeExpired(): Promise<number>;
}

/** Runs in the use case's transaction; throws LeaseLostError when another request took the lease over. */
export interface IdempotencyCompletion {
  complete(scope: string, key: string, lease: string, response: StoredResponse): Promise<void>;
}

export class LeaseLostError extends Error {
  override readonly name = "LeaseLostError";
}
```

## Article aggregate

```ts file=src/domain/publishing/article.ts
import { DomainError, type Issue } from "../shared/errors.ts";
import type { Actor } from "../shared/ports.ts";

export type ArticleStatus = "draft" | "published" | "archived";

export type Article = Readonly<{
  id: string;
  tenantId: string;
  authorId: string;
  slug: string;
  title: string;
  body: string;
  status: ArticleStatus;
  version: number;
  createdAt: Date;
  updatedAt: Date;
  publishedAt: Date | null;
}>;

export const LIMITS = { slug: 100, title: 200, body: 20_000 } as const;
export const SLUG_PATTERN = "^[a-z0-9]+(?:-[a-z0-9]+)*$";
const SLUG = new RegExp(SLUG_PATTERN, "u");
/** Lengths in code points (PostgreSQL's char_length); no NUL, which text cannot store. */
const text = (min: number, max: number) => (v: string) => {
  const length = Array.from(v).length;
  return length >= min && length <= max && !v.includes("\0");
};

const RULES = {
  slug: [(v: string) => SLUG.test(v) && v.length <= LIMITS.slug, "lowercase kebab-case, at most 100 characters"],
  title: [text(1, LIMITS.title), "1-200 characters after trimming, no NUL"],
  body: [text(0, LIMITS.body), "at most 20000 characters, no NUL"],
} as const;

function validate(fields: Partial<Record<keyof typeof RULES, string | undefined>>): void {
  const issues: Issue[] = [];
  for (const field of ["slug", "title", "body"] as const) {
    const value = fields[field];
    const [ok, detail] = RULES[field];
    if (value !== undefined && !ok(value)) issues.push({ field, code: "invalid_value", detail });
  }
  if (issues.length > 0) throw new DomainError("invalid", `${String(issues.length)} field(s) invalid`, { issues });
}

export function newArticle(input: Pick<Article, "id" | "tenantId" | "authorId" | "slug" | "title" | "body">, now: Date): Article {
  const article: Article = {
    ...input,
    title: input.title.trim(),
    status: "draft",
    version: 1,
    createdAt: now,
    updatedAt: now,
    publishedAt: null,
  };
  validate(article);
  return article;
}

export type ArticlePatch = Readonly<{ title?: string | undefined; body?: string | undefined }>;

export function editArticle(article: Article, patch: ArticlePatch, now: Date): Article {
  const title = patch.title?.trim();
  validate({ title, body: patch.body });
  return { ...article, title: title ?? article.title, body: patch.body ?? article.body, updatedAt: now };
}

function move(article: Article, from: ArticleStatus, to: ArticleStatus, now: Date): Article {
  if (article.status !== from) {
    throw new DomainError("invalid_transition", `Cannot move an article from '${article.status}' to '${to}'`);
  }
  return { ...article, status: to, updatedAt: now, publishedAt: to === "published" ? now : article.publishedAt };
}

export const publish = (article: Article, now: Date): Article => move(article, "draft", "published", now);
export const archive = (article: Article, now: Date): Article => move(article, "published", "archived", now);

/** Trusted path for stored rows: never re-validated, so a tightened rule cannot break reads. */
export const rehydrate = (state: Article): Article => state;

export const canEdit = (actor: Actor, article: Article): boolean =>
  actor.subject === article.authorId || actor.roles.includes("editor");

export const canModerate = (actor: Actor): boolean =>
  actor.roles.includes("editor") || actor.roles.includes("moderator");
```

## Publishing ports

```ts file=src/domain/publishing/ports.ts
import type { IdempotencyCompletion } from "../shared/idempotency.ts";
import type { DomainEvent, Page, PageRequest } from "../shared/ports.ts";
import type { Article, ArticleStatus } from "./article.ts";

export interface ArticleReader {
  get(tenantId: string, id: string): Promise<Article | null>;
  /** Newest first; an undecodable cursor fails with DomainError("malformed"). */
  list(tenantId: string, page: PageRequest): Promise<Page<Article>>;
}

/** Conditional writes: null when the stored version (update) or status (transition) no longer matches. */
export interface ArticleRepository extends Pick<ArticleReader, "get"> {
  /** A taken slug fails with DomainError("already_exists"). */
  insert(article: Article): Promise<void>;
  update(next: Article, expectedVersion: number): Promise<Article | null>;
  transition(next: Article, from: ArticleStatus): Promise<Article | null>;
}

export interface Outbox {
  append(event: DomainEvent): Promise<void>;
}

export interface Inbox {
  /** false: the message was already processed. */
  claim(consumer: string, messageId: string): Promise<boolean>;
}

export type Tx = Readonly<{ articles: ArticleRepository; outbox: Outbox; inbox: Inbox; idempotency: IdempotencyCompletion }>;

export interface UnitOfWork {
  /** One transaction; a nested run joins the open one. */
  run<T>(work: (tx: Tx) => Promise<T>): Promise<T>;
}
```

## Use cases

```ts file=src/domain/publishing/use-cases.ts
import { DomainError } from "../shared/errors.ts";
import type { Actor, Clock, DomainEvent, IdGenerator, Page, PageRequest } from "../shared/ports.ts";
import {
  archive,
  type Article,
  type ArticlePatch,
  canEdit,
  canModerate,
  editArticle,
  newArticle,
  publish,
} from "./article.ts";
import type { ArticleReader, Tx, UnitOfWork } from "./ports.ts";

export const MAX_PAGE = 100;

export type PublishingDeps = Readonly<{ uow: UnitOfWork; reader: ArticleReader; clock: Clock; ids: IdGenerator }>;

const notFound = (id: string): never => {
  throw new DomainError("not_found", `Article ${id} not found`);
};
const stale = (): DomainError =>
  new DomainError("precondition_failed", "The article changed since the ETag you sent; re-fetch and retry");

const publishedEvent = (a: Article): DomainEvent => ({
  type: "article.published",
  version: 1,
  tenantId: a.tenantId,
  aggregateType: "article",
  aggregateId: a.id,
  aggregateSeq: a.version,
  payload: { article_id: a.id, slug: a.slug, title: a.title, published_at: a.publishedAt?.toISOString() ?? null },
});

export class Publishing {
  readonly #deps: PublishingDeps;

  constructor(deps: PublishingDeps) {
    this.#deps = deps;
  }

  async create(actor: Actor, input: Pick<Article, "slug" | "title" | "body">): Promise<Article> {
    const { ids, clock, uow } = this.#deps;
    const article = newArticle({ ...input, id: ids.next(), tenantId: actor.tenantId, authorId: actor.subject }, clock.now());
    await uow.run((tx) => tx.articles.insert(article));
    return article;
  }

  async get(actor: Actor, id: string): Promise<Article> {
    return (await this.#deps.reader.get(actor.tenantId, id)) ?? notFound(id);
  }

  list(actor: Actor, page: PageRequest): Promise<Page<Article>> {
    return this.#deps.reader.list(actor.tenantId, { ...page, limit: Math.min(Math.max(page.limit, 1), MAX_PAGE) });
  }

  /** `precondition` (If-Match) is checked after the 404 and 403 decisions. */
  update(actor: Actor, id: string, patch: ArticlePatch, precondition?: (version: number) => boolean): Promise<Article> {
    return this.#deps.uow.run(async (tx) => {
      const current = await this.#editable(tx, actor, id);
      if (precondition && !precondition(current.version)) throw stale();
      const saved = await tx.articles.update(editArticle(current, patch, this.#deps.clock.now()), current.version);
      if (saved) return saved;
      throw precondition ? stale() : new DomainError("version_conflict", "The article changed concurrently");
    });
  }

  publish(actor: Actor, id: string): Promise<Article> {
    return this.#deps.uow.run(async (tx) => {
      const current = await this.#editable(tx, actor, id);
      const saved = await tx.articles.transition(publish(current, this.#deps.clock.now()), "draft");
      if (!saved) throw new DomainError("invalid_transition", "The article is no longer a draft");
      await tx.outbox.append(publishedEvent(saved));
      return saved;
    });
  }

  archive(actor: Actor, id: string): Promise<Article> {
    return this.#deps.uow.run(async (tx) => {
      const current = (await tx.articles.get(actor.tenantId, id)) ?? notFound(id);
      if (!canModerate(actor)) throw new DomainError("forbidden", "Only an editor or a moderator may archive");
      const saved = await tx.articles.transition(archive(current, this.#deps.clock.now()), "published");
      if (!saved) throw new DomainError("invalid_transition", "The article is no longer published");
      return saved;
    });
  }

  async #editable(tx: Tx, actor: Actor, id: string): Promise<Article> {
    const article = (await tx.articles.get(actor.tenantId, id)) ?? notFound(id);
    if (!canEdit(actor, article)) throw new DomainError("forbidden", "Only the author or an editor may change it");
    return article;
  }
}
```

## Test doubles and tests

`SaboteurOutbox` and `draft()` (fresh input per test) are shared with the PostgreSQL and HTTP tests.

```ts file=test/support/doubles.ts
import type { Article } from "../../src/domain/publishing/article.ts";
import type { ArticleReader, Outbox, Tx, UnitOfWork } from "../../src/domain/publishing/ports.ts";
import { DomainError } from "../../src/domain/shared/errors.ts";
import type { Page } from "../../src/domain/shared/ports.ts";

export const SaboteurOutbox: Outbox = { append: () => Promise.reject(new Error("outbox unavailable")) };
const NoOpOutbox: Outbox = { append: () => Promise.resolve() };
export const draft = () => ({ slug: `post-${crypto.randomUUID().slice(0, 8)}`, title: "Hello", body: "" });

/** A fake that enforces what the database enforces and rolls a failed unit back. */
export class MemoryStore implements UnitOfWork, ArticleReader {
  articles = new Map<string, Article>();
  readonly #outbox: Outbox;

  constructor(outbox = NoOpOutbox) {
    this.#outbox = outbox;
  }

  async run<T>(work: (tx: Tx) => Promise<T>): Promise<T> {
    const before = new Map(this.articles);
    try {
      return await work(this.#tx());
    } catch (error) {
      this.articles = before;
      throw error;
    }
  }

  get(tenantId: string, id: string): Promise<Article | null> {
    const found = this.articles.get(id);
    return Promise.resolve(found?.tenantId === tenantId ? found : null);
  }

  list(): Promise<Page<Article>> {
    return Promise.resolve({ items: [...this.articles.values()], nextCursor: null, hasMore: false });
  }

  #tx(): Tx {
    const save = (next: Article, guard: (stored: Article) => boolean): Promise<Article | null> => {
      const stored = this.articles.get(next.id);
      if (stored?.tenantId !== next.tenantId || !guard(stored)) return Promise.resolve(null);
      const saved = { ...next, version: stored.version + 1 };
      this.articles.set(saved.id, saved);
      return Promise.resolve(saved);
    };
    const taken = (a: Article) => [...this.articles.values()].some((b) => b.tenantId === a.tenantId && b.slug === a.slug);
    return {
      articles: {
        get: (tenantId, id) => this.get(tenantId, id),
        insert: (a) =>
          taken(a) ? Promise.reject(new DomainError("already_exists", "slug taken")) : Promise.resolve(void this.articles.set(a.id, a)),
        update: (next, expected) => save(next, (s) => s.version === expected),
        transition: (next, from) => save(next, (s) => s.status === from),
      },
      outbox: this.#outbox,
      inbox: { claim: () => Promise.resolve(true) },
      idempotency: { complete: () => Promise.resolve() },
    };
  }
}
```

```ts file=test/domain.test.ts
import { describe, expect, it } from "vitest";
import { archive, editArticle, newArticle, publish, rehydrate } from "../src/domain/publishing/article.ts";
import { DomainError } from "../src/domain/shared/errors.ts";

const now = new Date("2026-10-08T09:00:00.000Z");
const input = { id: "a1", tenantId: "t1", authorId: "alice", slug: "hello-world", title: "  Hello  ", body: "" };

function invalidFields(fn: () => unknown): string[] {
  try {
    fn();
  } catch (error) {
    if (error instanceof DomainError) return error.issues.map((i) => i.field);
  }
  return [];
}

describe("article", () => {
  it("trims the title and starts as a version-1 draft", () => {
    expect(newArticle(input, now)).toMatchObject({ title: "Hello", status: "draft", version: 1, publishedAt: null });
  });

  it.each(["Hello", "a--b", "-a", "a_b", "x".repeat(101), ""])("rejects slug %j", (slug) => {
    expect(invalidFields(() => newArticle({ ...input, slug }, now))).toEqual(["slug"]);
  });

  it("reports every invalid field, counts code points and refuses NUL", () => {
    expect(invalidFields(() => newArticle({ ...input, slug: "Bad", title: "   " }, now))).toEqual(["slug", "title"]);
    expect(invalidFields(() => newArticle({ ...input, title: "😀".repeat(200) }, now))).toEqual([]);
    expect(invalidFields(() => editArticle(newArticle(input, now), { title: "😀".repeat(201), body: "a\0" }, now))).toEqual(["title", "body"]);
  });

  it("publishes only drafts and archives only published articles", () => {
    const draft = newArticle(input, now);
    expect(archive(publish(draft, now), now)).toMatchObject({ status: "archived", publishedAt: now });
    expect(() => publish(publish(draft, now), now)).toThrow(expect.objectContaining({ code: "invalid_transition" }));
    expect(() => archive(draft, now)).toThrow(expect.objectContaining({ code: "invalid_transition" }));
  });

  it("rehydrates stored rows without re-validating them", () => {
    expect(rehydrate({ ...newArticle(input, now), title: "x".repeat(500) }).title).toHaveLength(500);
  });
});
```

```ts file=test/use-cases.test.ts
import { describe, expect, it } from "vitest";
import { Publishing } from "../src/domain/publishing/use-cases.ts";
import type { Actor } from "../src/domain/shared/ports.ts";
import { draft, MemoryStore, SaboteurOutbox } from "./support/doubles.ts";

const alice: Actor = { tenantId: "t1", subject: "alice", roles: [] };
const bob: Actor = { tenantId: "t1", subject: "bob", roles: [] };
let n = 0;
const setup = (store = new MemoryStore()) =>
  new Publishing({ uow: store, reader: store, clock: { now: () => new Date() }, ids: { next: () => `id-${String(++n)}` } });

describe("publishing use cases", () => {
  it("refuses a second article with the same slug, as the unique constraint does", async () => {
    const [publishing, input] = [setup(), draft()];
    await publishing.create(alice, input);
    await expect(publishing.create(bob, input)).rejects.toMatchObject({ code: "already_exists" });
  });

  it("fails as a whole when the outbox write fails", async () => {
    const store = new MemoryStore(SaboteurOutbox);
    const { id } = await setup(store).create(alice, draft());
    await expect(setup(store).publish(alice, id)).rejects.toThrow("outbox unavailable");
    expect(store.articles.get(id)).toMatchObject({ status: "draft", version: 1 });
  });

  it("decides 403 before the If-Match precondition, and lets only an editor or moderator archive", async () => {
    const publishing = setup();
    const { id } = await publishing.create(alice, draft());
    await expect(publishing.update(bob, id, { title: "Mine" }, () => false)).rejects.toMatchObject({ code: "forbidden" });
    await expect(publishing.update({ ...bob, roles: ["editor"] }, id, { title: "Ok" })).resolves.toMatchObject({ version: 2 });
    await expect(publishing.archive(alice, id)).rejects.toMatchObject({ code: "forbidden" });
  });
});
```
