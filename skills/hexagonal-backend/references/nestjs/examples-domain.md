# NestJS examples: domain

The publishing context's domain and use cases: plain TypeScript, no `@nestjs/*` import (the boundary gate in `guide.md` § 8 enforces it). Every block with a `file=` path is a complete file of one project that compiles, lints and passes its tests on PostgreSQL 18.

## Contents

1. [Errors and shared ports](#errors-and-shared-ports)
2. [The Article aggregate](#the-article-aggregate)
3. [Publishing ports and the event contract](#publishing-ports-and-the-event-contract)
4. [Use cases](#use-cases)
5. [Domain tests](#domain-tests)
6. [Use-case tests with hand-rolled doubles](#use-case-tests-with-hand-rolled-doubles)

## Errors and shared ports

A closed set of error kinds that every adapter maps exhaustively; ports as abstract classes, which double as DI tokens.

```ts file=src/domain/shared/errors.ts
export type ErrorKind =
  | "invalid"
  | "malformed" // a token this service issued (a cursor) cannot be read
  | "forbidden"
  | "not_found"
  | "conflict"
  | "precondition_failed"
  | "unavailable"; // a dependency failed transiently: retry later

export class DomainError extends Error {
  readonly code: string;
  readonly field: string | undefined;

  constructor(
    readonly kind: ErrorKind,
    message: string,
    options: { code?: string; field?: string; cause?: unknown } = {},
  ) {
    super(message, { cause: options.cause });
    this.name = "DomainError";
    this.code = options.code ?? kind;
    this.field = options.field;
  }
}

export const invalid = (field: string, code: string, message: string) =>
  new DomainError("invalid", message, { field, code });

export const conflict = (code: "already-exists" | "invalid-transition" | "version-conflict", message: string) =>
  new DomainError("conflict", message, { code });
```

```ts file=src/domain/shared/ports.ts
export abstract class Clock {
  abstract now(): Date;
}

export abstract class IdGenerator {
  abstract next(): string;
}

/** A nested run() joins the open transaction. */
export abstract class UnitOfWork {
  abstract run<T>(work: () => Promise<T>): Promise<T>;
}

export interface Actor {
  readonly tenantId: string;
  readonly subject: string;
  readonly roles: readonly string[];
}

export interface Page<T> {
  readonly items: readonly T[];
  readonly nextCursor: string | null;
}
```

The idempotency port sits between the inbound interceptor and the outbound store; it lives in the domain so neither adapter depends on the other.

```ts file=src/domain/shared/idempotency.ts
export interface StoredResponse {
  readonly status: number;
  readonly headers: Readonly<Record<string, string>>;
  readonly body: unknown;
}

export type Acquired =
  | { readonly kind: "new"; readonly lease: string }
  | { readonly kind: "replay"; readonly response: StoredResponse }
  | { readonly kind: "mismatch" }
  | { readonly kind: "in_flight" };

export abstract class IdempotencyStore {
  abstract acquire(scope: string, key: string, requestHash: string): Promise<Acquired>;
  /** Inside the unit of work that holds the result; throws if the lease was taken over. */
  abstract complete(scope: string, key: string, lease: string, response: StoredResponse): Promise<void>;
  abstract release(scope: string, key: string, lease: string): Promise<void>;
  abstract purgeExpired(): Promise<number>;
}
```

## The Article aggregate

Immutable state behind a brand: only `createArticle` (validates) and `rehydrateArticle` (trusts storage) can mint an `Article`, and every transition returns a new version.

```ts file=src/domain/publishing/article.ts
import { conflict, invalid } from "../shared/errors.js";
import type { Actor } from "../shared/ports.js";

export type ArticleStatus = "draft" | "published" | "archived";

export interface ArticleState {
  readonly id: string;
  readonly tenantId: string;
  readonly authorId: string;
  readonly slug: string;
  readonly title: string;
  readonly body: string;
  readonly status: ArticleStatus;
  readonly version: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly publishedAt: Date | null;
}

declare const sealed: unique symbol;
export type Article = ArticleState & { readonly [sealed]: true };

// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- the one place an Article is minted
const seal = (state: ArticleState) => Object.freeze({ ...state }) as Article;

export interface NewArticle {
  readonly slug: string;
  readonly title: string;
  readonly body: string;
}

export function parseSlug(raw: string): string {
  if (raw.length > 100 || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(raw)) {
    throw invalid("slug", "invalid_format", "slug must be lowercase kebab-case, at most 100 characters");
  }
  return raw;
}

export const parseTitle = (raw: string) => text("title", raw.trim(), 1, 200);
export const parseBody = (raw: string) => text("body", raw, 0, 20_000);

/** Lengths in code points, as the CHECK constraints count them. */
function text(field: string, value: string, min: number, max: number): string {
  const length = Array.from(value).length;
  if (length < min || length > max) throw invalid(field, "invalid_length", `${field} must be ${min}-${max} characters`);
  if (value.includes("\u0000")) throw invalid(field, "invalid_characters", `${field} must not contain U+0000`);
  return value;
}

export function createArticle(input: NewArticle & { id: string; tenantId: string; authorId: string }, now: Date): Article {
  return seal({
    id: input.id,
    tenantId: input.tenantId,
    authorId: input.authorId,
    slug: parseSlug(input.slug),
    title: parseTitle(input.title),
    body: parseBody(input.body),
    status: "draft",
    version: 1,
    createdAt: now,
    updatedAt: now,
    publishedAt: null,
  });
}

export const rehydrateArticle = (state: ArticleState): Article => seal(state);

export function editArticle(article: Article, changes: { title?: string; body?: string }, now: Date): Article {
  return next(article, now, {
    title: changes.title === undefined ? article.title : parseTitle(changes.title),
    body: changes.body === undefined ? article.body : parseBody(changes.body),
  });
}

export function publishArticle(article: Article, now: Date): Article {
  requireStatus(article, "draft", "publish");
  return next(article, now, { status: "published", publishedAt: now });
}

export function archiveArticle(article: Article, now: Date): Article {
  requireStatus(article, "published", "archive");
  return next(article, now, { status: "archived" });
}

export const canEdit = (actor: Actor, article: Article) =>
  actor.subject === article.authorId || actor.roles.includes("editor");

function requireStatus(article: Article, from: ArticleStatus, action: string): void {
  if (article.status !== from) {
    throw conflict("invalid-transition", `cannot ${action} an article in status '${article.status}'`);
  }
}

const next = (article: Article, now: Date, changes: Partial<ArticleState>) =>
  seal({ ...article, ...changes, version: article.version + 1, updatedAt: now });
```

## Publishing ports and the event contract

```ts file=src/domain/publishing/ports.ts
import type { Page } from "../shared/ports.js";
import type { Article, ArticleStatus } from "./article.js";

/** Tenant-scoped: another tenant's article looks exactly like a missing one. */
export abstract class ArticleRepository {
  abstract insert(article: Article): Promise<void>;
  abstract findById(tenantId: string, id: string): Promise<Article | null>;
  abstract list(tenantId: string, cursor: string | null, limit: number): Promise<Page<Article>>;
  abstract update(article: Article, expectedVersion: number): Promise<boolean>;
  /** Applies `next.status` only while the stored status is `from`. */
  abstract transition(next: Article, from: ArticleStatus): Promise<Article | null>;
}

export interface DomainEvent {
  readonly tenantId: string;
  readonly aggregateType: string;
  readonly aggregateId: string;
  readonly aggregateSeq: number; // the aggregate version: consumers apply events in this order
  readonly type: string;
  readonly version: number;
  readonly payload: Readonly<Record<string, unknown>>;
}

export abstract class Outbox {
  abstract append(events: readonly DomainEvent[]): Promise<void>;
}

/** false when the message was already processed. */
export abstract class Inbox {
  abstract claim(consumer: string, messageId: string): Promise<boolean>;
}

/** A published contract: change it additively, or ship v2 beside it. */
export const articlePublished = (article: Article): DomainEvent => ({
  tenantId: article.tenantId,
  aggregateType: "article",
  aggregateId: article.id,
  aggregateSeq: article.version,
  type: "article.published",
  version: 1,
  payload: {
    article_id: article.id,
    tenant_id: article.tenantId,
    slug: article.slug,
    title: article.title,
    published_at: article.publishedAt?.toISOString() ?? null,
  },
});
```

## Use cases

Each command runs in one `uow.run()`; a nested `run()` (moderation calling `archive`, the idempotency interceptor around `create`) joins the open transaction.

```ts file=src/domain/publishing/article-service.ts
import { conflict, DomainError } from "../shared/errors.js";
import type { Actor, Clock, IdGenerator, Page, UnitOfWork } from "../shared/ports.js";
import {
  archiveArticle, canEdit, createArticle, editArticle, publishArticle, type Article, type NewArticle,
} from "./article.js";
import { articlePublished, type ArticleRepository, type Inbox, type Outbox } from "./ports.js";

export const MAX_PAGE_SIZE = 100;

export class ArticleService {
  constructor(
    private readonly articles: ArticleRepository,
    private readonly outbox: Outbox,
    private readonly uow: UnitOfWork,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
  ) {}

  async create(actor: Actor, input: NewArticle): Promise<Article> {
    const article = createArticle(
      { ...input, id: this.ids.next(), tenantId: actor.tenantId, authorId: actor.subject },
      this.clock.now(),
    );
    await this.uow.run(() => this.articles.insert(article));
    return article;
  }

  list(actor: Actor, cursor: string | null, limit: number): Promise<Page<Article>> {
    return this.articles.list(actor.tenantId, cursor, Math.min(Math.max(1, limit), MAX_PAGE_SIZE));
  }

  /** A merge patch (`body: null` clears). `expected`: the versions If-Match names; else the one read here. */
  update(actor: Actor, id: string, patch: { title?: string; body?: string | null }, expected?: readonly number[]) {
    return this.uow.run(async () => {
      const current = await this.editable(actor, id);
      if (expected && !expected.includes(current.version)) throw stale();
      const changes = { title: patch.title, body: patch.body === null ? "" : patch.body };
      const updated = editArticle(current, changes, this.clock.now());
      if (await this.articles.update(updated, current.version)) return updated;
      throw expected ? stale() : conflict("version-conflict", "the article changed meanwhile; retry");
    });
  }

  publish(actor: Actor, id: string): Promise<Article> {
    return this.uow.run(async () => {
      const current = await this.editable(actor, id);
      const published = await this.articles.transition(publishArticle(current, this.clock.now()), "draft");
      if (!published) throw conflict("invalid-transition", "the article is no longer a draft");
      await this.outbox.append([articlePublished(published)]);
      return published;
    });
  }

  archive(actor: Actor, id: string): Promise<Article> {
    return this.uow.run(async () => {
      const current = await this.get(actor, id);
      if (!actor.roles.includes("moderator")) throw new DomainError("forbidden", "only moderation archives articles");
      const archived = await this.articles.transition(archiveArticle(current, this.clock.now()), "published");
      if (!archived) throw conflict("invalid-transition", "the article is no longer published");
      return archived;
    });
  }

  async get(actor: Actor, id: string): Promise<Article> {
    const article = await this.articles.findById(actor.tenantId, id);
    if (!article) throw new DomainError("not_found", `article '${id}' not found`);
    return article;
  }

  private async editable(actor: Actor, id: string): Promise<Article> {
    const article = await this.get(actor, id);
    if (!canEdit(actor, article)) throw new DomainError("forbidden", "only the author or an editor may change it");
    return article;
  }
}

const stale = () => new DomainError("precondition_failed", "the article changed since the version you read; re-read it");

export type ModerationOutcome = "archived" | "approved" | "duplicate" | "ignored";

export class ModerationService {
  constructor(
    private readonly articles: ArticleService,
    private readonly inbox: Inbox,
    private readonly uow: UnitOfWork,
  ) {}

  handle(message: { id: string; tenantId: string; articleId: string; verdict: "approved" | "rejected" }) {
    const moderator: Actor = { tenantId: message.tenantId, subject: "system:moderation", roles: ["moderator"] };
    return this.uow.run(async (): Promise<ModerationOutcome> => {
      if (!(await this.inbox.claim("moderation", message.id))) return "duplicate";
      if (message.verdict === "approved") return "approved";
      try {
        await this.articles.archive(moderator, message.articleId);
        return "archived";
      } catch (error) {
        // Permanent: a redelivery cannot succeed, so keep the inbox row and acknowledge.
        if (error instanceof DomainError && ["not_found", "conflict"].includes(error.kind)) return "ignored";
        throw error;
      }
    });
  }
}
```

## Domain tests

```ts file=test/domain/article.spec.ts
import { describe, expect, it } from "vitest";
import {
  archiveArticle, createArticle, editArticle, publishArticle, rehydrateArticle,
} from "../../src/domain/publishing/article.js";

const created = new Date("2026-10-08T09:00:00Z");
const later = new Date("2026-10-08T10:00:00Z");
const input = { id: "0199c4e0-0000-7000-8000-000000000001", tenantId: "t1", authorId: "ada", slug: "hello", title: "Hi", body: "" };
const draft = () => createArticle(input, created);
const invalidAt = (field: string) => expect.objectContaining({ kind: "invalid", field });

describe("Article", () => {
  it("normalizes on creation and starts as a version-1 draft", () => {
    expect(createArticle({ ...input, title: "  Hello  " }, created)).toMatchObject({
      title: "Hello", status: "draft", version: 1, publishedAt: null,
    });
  });

  it.each(["", "Hello", "a--b", "-a", "a-", "a_b", "x".repeat(101)])("rejects the slug %j", (slug) => {
    expect(() => createArticle({ ...input, slug }, created)).toThrow(invalidAt("slug"));
  });

  it.each(["", "   ", "x".repeat(201), "😀".repeat(201), "a\u0000b"])("rejects the title %j", (title) => {
    expect(() => createArticle({ ...input, title }, created)).toThrow(invalidAt("title"));
  });

  it("counts characters as code points, as PostgreSQL does, not UTF-16 units", () => {
    expect(createArticle({ ...input, title: "😀".repeat(200) }, created).title).toHaveLength(400);
  });

  it("publishes a draft once and archives only a published article", () => {
    const published = publishArticle(draft(), later);
    expect(published).toMatchObject({ status: "published", version: 2, publishedAt: later, updatedAt: later });
    const refused = expect.objectContaining({ kind: "conflict", code: "invalid-transition" });
    expect(() => publishArticle(published, later)).toThrow(refused);
    expect(() => archiveArticle(draft(), later)).toThrow(refused);
    expect(archiveArticle(published, later)).toMatchObject({ status: "archived", version: 3 });
  });

  it("rehydrates stored rows without re-running creation rules", () => {
    const legacy = rehydrateArticle({ ...draft(), title: "x".repeat(300) }); // stored before the rule tightened
    expect(editArticle(legacy, { body: "edited" }, later)).toMatchObject({ title: "x".repeat(300), version: 2 });
  });
});
```

## Use-case tests with hand-rolled doubles

No database: the fake repository keeps the unique-slug and guarded-write promises, the fake unit of work restores state on failure, and a Saboteur proves the use case fails as a whole. The same behaviors run again on PostgreSQL in `examples-bootstrap.md`.

```ts file=test/domain/article-service.spec.ts
import { beforeEach, describe, expect, it } from "vitest";
import { rehydrateArticle, type Article, type ArticleStatus } from "../../src/domain/publishing/article.js";
import { ArticleService } from "../../src/domain/publishing/article-service.js";
import { ArticleRepository, type Outbox } from "../../src/domain/publishing/ports.js";
import { conflict } from "../../src/domain/shared/errors.js";
import type { Actor, UnitOfWork } from "../../src/domain/shared/ports.js";

/** Keeps the database's promises: a unique slug per tenant, guarded writes. */
class FakeArticles extends ArticleRepository {
  rows = new Map<string, Article>();

  async insert(a: Article) {
    if ([...this.rows.values()].some((r) => r.tenantId === a.tenantId && r.slug === a.slug)) {
      throw conflict("already-exists", "slug taken");
    }
    this.rows.set(a.id, a);
  }
  async findById(tenantId: string, id: string) {
    const row = this.rows.get(id);
    return row?.tenantId === tenantId ? row : null;
  }
  async list() {
    return { items: [...this.rows.values()], nextCursor: null };
  }
  async update(a: Article, expectedVersion: number) {
    const ok = this.rows.get(a.id)?.version === expectedVersion;
    if (ok) this.rows.set(a.id, a);
    return ok;
  }
  async transition(next: Article, from: ArticleStatus) {
    const row = this.rows.get(next.id);
    if (row?.tenantId !== next.tenantId || row.status !== from) return null;
    const saved = rehydrateArticle({ ...next, version: row.version + 1 });
    this.rows.set(saved.id, saved);
    return saved;
  }
}

const actor = (subject: string, roles: string[] = [], tenantId = "8d1e2f40-0000-4000-8000-000000000001"): Actor =>
  ({ tenantId, subject, roles });
const [ada, bob, editor] = [actor("ada"), actor("bob"), actor("eve", ["editor"])];
const stranger = actor("ada", ["editor"], "8d1e2f40-0000-4000-8000-000000000002"); // another tenant
const input = { slug: "hello", title: "Hello", body: "" };

let articles: FakeArticles;
let sequence = 0;
/** Restores the rows when the work fails, as a rollback would. */
const rollback: UnitOfWork = {
  run: async (work) => {
    const before = new Map(articles.rows);
    return work().catch((error: unknown) => {
      articles.rows = before;
      throw error;
    });
  },
};
const service = (outbox: Outbox = { append: async () => {} }) =>
  new ArticleService(articles, outbox, rollback, { now: () => new Date() }, {
    next: () => `0199c4e0-0000-7000-8000-${String(++sequence).padStart(12, "0")}`,
  });

beforeEach(() => {
  articles = new FakeArticles();
});

describe("ArticleService", () => {
  it("refuses a second article with the same slug in a tenant", async () => {
    await service().create(ada, input);
    await expect(service().create(bob, input)).rejects.toMatchObject({ kind: "conflict", code: "already-exists" });
    await expect(service().create(stranger, input)).resolves.toMatchObject({ slug: "hello" });
  });

  it("lets the author and editors write, forbids other members, hides the article from other tenants", async () => {
    const { id } = await service().create(ada, input);
    await expect(service().update(bob, id, { title: "Mine" })).rejects.toMatchObject({ kind: "forbidden" });
    await expect(service().update(editor, id, { title: "Edited" }, [1])).resolves.toMatchObject({ version: 2 });
    await expect(service().update(ada, id, { title: "Stale" }, [1])).rejects.toMatchObject({ kind: "precondition_failed" });
    await expect(service().publish(stranger, id)).rejects.toMatchObject({ kind: "not_found" });
  });

  it("fails as a whole when the outbox write fails (a Saboteur)", async () => {
    const { id } = await service().create(ada, input);
    const saboteur: Outbox = { append: () => Promise.reject(new Error("outbox down")) };
    await expect(service(saboteur).publish(ada, id)).rejects.toThrow("outbox down");
    expect(articles.rows.get(id)).toMatchObject({ status: "draft", version: 1 });
  });
});
```
