# Examples: Domain Layer

Models, errors, ports, and service implementation.

---

## Table of Contents

1. [Domain Models](#domain-models)
2. [Domain Errors](#domain-errors)
3. [Ports (Interfaces)](#ports-interfaces)
4. [Service Implementation](#service-implementation)


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
// src/domain/authors/errors.ts

/**
 * Use a readonly `tag` discriminant on each error class.
 * This enables exhaustive switch/case matching in error handlers
 * without relying on instanceof (which breaks across module boundaries).
 */

export class AuthorNameEmptyError extends Error {
  readonly tag = "AuthorNameEmptyError" as const;
  constructor() {
    super("author name cannot be empty");
    this.name = "AuthorNameEmptyError";
  }
}

export class DuplicateAuthorError extends Error {
  readonly tag = "DuplicateAuthorError" as const;
  constructor(readonly authorName: string) {
    super(`author with name "${authorName}" already exists`);
    this.name = "DuplicateAuthorError";
  }
}

export class AuthorNotFoundError extends Error {
  readonly tag = "AuthorNotFoundError" as const;
  constructor(readonly authorId: string) {
    super(`author with id "${authorId}" not found`);
    this.name = "AuthorNotFoundError";
  }
}

export class UnknownAuthorError extends Error {
  readonly tag = "UnknownAuthorError" as const;
  constructor(readonly cause: unknown) {
    super("unexpected error");
    this.name = "UnknownAuthorError";
  }
}

/**
 * Union type for all create-author failures.
 * Handlers can switch on `error.tag` for exhaustive matching.
 */
export type CreateAuthorError =
  | DuplicateAuthorError
  | UnknownAuthorError;
```

## Ports (Interfaces)

```typescript
// src/domain/authors/ports.ts

import type { Author, CreateAuthorRequest, CursorPage } from "./models";
import type { CreateAuthorError } from "./errors";

/**
 * Port shaped by use cases. MUST throw DuplicateAuthorError if name exists.
 */
export interface AuthorRepository {
  createAuthor(req: CreateAuthorRequest): Promise<Author>;
  findAuthor(authorId: string): Promise<Author | null>;
  listAuthors(cursor: string | null, limit: number): Promise<CursorPage<Author>>;
}

export interface AuthorMetrics {
  recordCreationSuccess(): Promise<void>;
  recordCreationFailure(): Promise<void>;
}

export interface AuthorNotifier {
  authorCreated(author: Author): Promise<void>;
}

/**
 * Business API consumed by inbound adapters.
 */
export interface AuthorService {
  createAuthor(req: CreateAuthorRequest): Promise<Author>;
  findAuthor(authorId: string): Promise<Author | null>;
  listAuthors(cursor: string | null, limit: number): Promise<CursorPage<Author>>;
}
```

## Service Implementation

```typescript
// src/domain/authors/service.ts

import type { Author, CreateAuthorRequest, CursorPage } from "./models";
import type { AuthorMetrics, AuthorNotifier, AuthorRepository, AuthorService } from "./ports";
import { DuplicateAuthorError, UnknownAuthorError } from "./errors";

/**
 * Orchestrates: repo -> metrics -> notifications -> return result.
 */
export class AuthorServiceImpl implements AuthorService {
  constructor(
    private readonly repo: AuthorRepository,
    private readonly metrics: AuthorMetrics,
    private readonly notifier: AuthorNotifier,
  ) {}

  async createAuthor(req: CreateAuthorRequest): Promise<Author> {
    try {
      const author = await this.repo.createAuthor(req);
      await this.metrics.recordCreationSuccess();
      await this.notifier.authorCreated(author);
      return author;
    } catch (error) {
      await this.metrics.recordCreationFailure();
      if (error instanceof DuplicateAuthorError) {
        throw error;
      }
      throw new UnknownAuthorError(error);
    }
  }

  async findAuthor(authorId: string): Promise<Author | null> {
    return this.repo.findAuthor(authorId);
  }

  async listAuthors(cursor: string | null, limit: number): Promise<CursorPage<Author>> {
    return this.repo.listAuthors(cursor, limit);
  }
}
```
