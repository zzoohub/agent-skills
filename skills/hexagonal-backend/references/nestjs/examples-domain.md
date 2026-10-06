# Examples: Domain Layer

Models, errors, ports (abstract classes), and service implementation.

---

## Table of Contents

1. [Domain Models](#domain-models)
2. [Domain Errors](#domain-errors)
3. [Cross-Cutting Port: UnitOfWork](#cross-cutting-port-unitofwork)
4. [Ports (Abstract Classes)](#ports-abstract-classes)
5. [Service Implementation](#service-implementation)


## Domain Models

```typescript
// src/domain/authors/models.ts

import { AuthorNameEmptyError } from "./errors";

/**
 * Validated, trimmed author name. Value object.
 * Immutable — construct via AuthorName.create().
 */
export class AuthorName {
  private constructor(readonly value: string) {}

  static create(raw: string): AuthorName {
    const trimmed = raw.trim();
    if (!trimmed) {
      throw new AuthorNameEmptyError();
    }
    return new AuthorName(trimmed);
  }

  toString(): string {
    return this.value;
  }

  equals(other: AuthorName): boolean {
    return this.value === other.value;
  }
}

/**
 * A uniquely identifiable author of blog posts.
 */
export interface Author {
  readonly id: string;
  readonly name: AuthorName;
}

/**
 * Fields required to create an Author. Separate from Author — they WILL diverge.
 */
export interface CreateAuthorRequest {
  readonly name: AuthorName;
}

/**
 * Cursor-based pagination result.
 */
export interface CursorPage<T> {
  readonly items: T[];
  readonly nextCursor: string | null;
  readonly hasMore: boolean;
}
```

## Domain Errors

```typescript
// src/domain/shared/errors.ts
//
// Base class for every domain error. The exception filter does
// `instanceof DomainError` (safe inside a single bundle/repo), then
// switches on `tag` for the exhaustive mapping to RFC 9457 ProblemDetails.
//
// Why both a base class AND a tag?
//   - `instanceof DomainError` rules out third-party Error objects that
//     happen to carry a `tag` field (otherwise the filter would match them).
//   - `tag` as a string-literal discriminant gives TypeScript exhaustive
//     `switch` checking and survives any future bundling split where the
//     base class might be duplicated across chunks.
export abstract class DomainError extends Error {
  abstract readonly tag: string;
}
```

```typescript
// src/domain/authors/errors.ts
import { DomainError } from "../shared/errors";

export class AuthorNameEmptyError extends DomainError {
  readonly tag = "AuthorNameEmptyError" as const;
  constructor() {
    super("author name cannot be empty");
    this.name = "AuthorNameEmptyError";
  }
}

export class DuplicateAuthorError extends DomainError {
  readonly tag = "DuplicateAuthorError" as const;
  constructor(readonly authorName: string) {
    super(`author with name "${authorName}" already exists`);
    this.name = "DuplicateAuthorError";
  }
}

export class AuthorNotFoundError extends DomainError {
  readonly tag = "AuthorNotFoundError" as const;
  constructor(readonly authorId: string) {
    super(`author with id "${authorId}" not found`);
    this.name = "AuthorNotFoundError";
  }
}

export class UnknownAuthorError extends DomainError {
  readonly tag = "UnknownAuthorError" as const;
  constructor(readonly cause: unknown) {
    super("unexpected error");
    this.name = "UnknownAuthorError";
  }
}

/**
 * Union type for all create-author failures.
 * Exception filters switch on `error.tag` for exhaustive matching.
 * Scoped to the create path: find/list path errors (e.g. AuthorNotFoundError)
 * belong to their own per-operation union.
 */
export type CreateAuthorError = DuplicateAuthorError | UnknownAuthorError;
```

## Cross-Cutting Port: UnitOfWork

Domain-level abstraction for "run these writes atomically." The outbound
adapter implements it with `DataSource.transaction(...)` + `nestjs-cls`;
the domain doesn't know which.

```typescript
// src/domain/shared/unit-of-work.ts
export abstract class UnitOfWork {
  /**
   * Run a callback inside a single database transaction. Repositories
   * called inside the callback automatically pick up the scoped
   * EntityManager (via CLS) and participate in the same tx.
   * Commits on resolved promise; rolls back if the callback throws.
   *
   * Use this whenever a service needs cross-repository atomicity —
   * e.g. aggregate write + outbox enqueue, or transferring state
   * between two aggregates. For a single-repository write, the
   * repository's internal `manager.transaction(...)` is enough.
   */
  abstract run<T>(fn: () => Promise<T>): Promise<T>;
}
```

## Ports (Abstract Classes)

```typescript
// src/domain/authors/ports.ts

import type { Author, CreateAuthorRequest, CursorPage } from "./models";

/**
 * Abstract classes serve as BOTH interface contract AND DI injection token.
 * NestJS resolves `AuthorRepository` in constructors to whichever class
 * is registered with `{ provide: AuthorRepository, useClass: ... }`.
 *
 * No @nestjs/* imports — these are plain TypeScript.
 */

/**
 * Port shaped by use cases. Implementors MUST throw DuplicateAuthorError if name exists.
 */
export abstract class AuthorRepository {
  abstract createAuthor(req: CreateAuthorRequest): Promise<Author>;
  abstract findAuthor(authorId: string): Promise<Author | null>;
  abstract listAuthors(
    cursor: string | null,
    limit: number,
  ): Promise<CursorPage<Author>>;
}

export abstract class AuthorMetrics {
  abstract recordCreationSuccess(): Promise<void>;
  abstract recordCreationFailure(): Promise<void>;
}

export abstract class AuthorNotifier {
  abstract authorCreated(author: Author): Promise<void>;
}

/**
 * Business API consumed by inbound adapters (controllers).
 */
export abstract class AuthorService {
  abstract createAuthor(req: CreateAuthorRequest): Promise<Author>;
  abstract findAuthor(authorId: string): Promise<Author | null>;
  abstract listAuthors(
    cursor: string | null,
    limit: number,
  ): Promise<CursorPage<Author>>;
}
```

## Service Implementation

```typescript
// src/domain/authors/service.ts
//
// @Injectable() is allowed — it's a metadata-only marker, and accepting
// one @nestjs/common import in exchange for half the wiring code is the
// pragmatic trade-off. Pair it with `{ provide: AuthorService, useClass:
// AuthorServiceImpl }` in the feature module.
//
// If you want zero NestJS imports in domain/, drop the decorator and wire
// via `useFactory` in the module — both patterns are supported.

import { Injectable } from "@nestjs/common";
import type { Author, CreateAuthorRequest, CursorPage } from "./models";
import type { AuthorMetrics, AuthorNotifier, AuthorRepository } from "./ports";
import { AuthorService } from "./ports";
import { DomainError } from "../shared/errors";
import { UnknownAuthorError } from "./errors";

/**
 * Orchestrates: repo -> metrics -> notifications -> return result.
 */
@Injectable()
export class AuthorServiceImpl extends AuthorService {
  constructor(
    private readonly repo: AuthorRepository,
    private readonly metrics: AuthorMetrics,
    private readonly notifier: AuthorNotifier,
  ) {
    super();
  }

  async createAuthor(req: CreateAuthorRequest): Promise<Author> {
    try {
      const author = await this.repo.createAuthor(req);
      // Notification is best-effort — the author is already persisted, so a
      // failed notify must NOT flip the metric to "failure" or fail the
      // request. Swallow + log here; for guaranteed delivery use the Outbox
      // port (DB write + event row commit atomically) — see
      // references/nestjs/examples-adapters.md → "Outbox via UoW".
      try {
        await this.notifier.authorCreated(author);
      } catch (notifyError) {
        // eslint-disable-next-line no-console
        console.error("authorCreated notification failed", notifyError);
      }
      // Record success only after the write succeeded. The catch below owns
      // the failure metric, so a path can never record BOTH success and
      // failure for the same call.
      await this.metrics.recordCreationSuccess();
      return author;
    } catch (error) {
      await this.metrics.recordCreationFailure();
      // Re-throw any expected DomainError (DuplicateAuthorError etc) as-is;
      // wrap anything else so the controller layer sees a single, mapped type.
      if (error instanceof DomainError) {
        throw error;
      }
      throw new UnknownAuthorError(error);
    }
  }

  async findAuthor(authorId: string): Promise<Author | null> {
    return this.repo.findAuthor(authorId);
  }

  async listAuthors(
    cursor: string | null,
    limit: number,
  ): Promise<CursorPage<Author>> {
    return this.repo.listAuthors(cursor, limit);
  }
}
```
