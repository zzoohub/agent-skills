# Next.js i18n with next-intl v4

**Docs: [next-intl.dev](https://next-intl.dev/docs/getting-started/app-router)**

next-intl v4 is ESM-only, requires React 17+ and TypeScript 5+. Uses ICU MessageFormat with first-class Server Component support and built-in type safety via `AppConfig`.

## Table of Contents

1. [Setup](#setup)
2. [Usage Patterns](#usage-patterns)
3. [Type Safety](#type-safety)
4. [ICU Message Syntax](#icu-message-syntax)
5. [Formatting](#formatting)
6. [Static Rendering](#static-rendering)
7. [SEO](#seo)
8. [Language Switcher](#language-switcher)
9. [Common Pitfalls](#common-pitfalls)

---

## Setup

### 1. Install

```bash
bun add next-intl
```

### 2. File Structure

```
src/
├── app/
│   └── [locale]/
│       ├── layout.tsx
│       └── page.tsx
├── i18n/
│   ├── routing.ts          # Locale routing config
│   ├── request.ts          # Per-request i18n config
│   └── navigation.ts       # Localized Link, redirect, etc.
├── proxy.ts                # Next.js 16+ (was middleware.ts)
└── messages/
    ├── en.json
    ├── es.json
    ├── id.json
    ├── ja.json
    ├── ko.json
    └── pt-BR.json
```

### 3. Routing Config

```typescript
// src/i18n/routing.ts
import { defineRouting } from 'next-intl/routing';

export const routing = defineRouting({
  locales: ['en', 'es', 'id', 'ja', 'ko', 'pt-BR'],
  defaultLocale: 'en',
  // v4: localeCookie controls persistence (false to disable, or customize)
  localeCookie: {
    maxAge: 60 * 60 * 24 * 365,
  },
});
```

**v4 note:** Use `localeCookie: false` to disable the locale-persistence cookie. `localeCookie` and `localeDetection` coexist with distinct jobs — `localeCookie` controls the cookie, `localeDetection` controls automatic locale negotiation. (Previously `localeDetection: false` ambiguously also disabled the cookie.)

### 4. Proxy (Middleware)

On **Next.js 16+** name this file `proxy.ts` (`middleware.ts` is deprecated but still runs in 16.x — rename it, e.g. with the `middleware-to-proxy` codemod). The `next-intl/middleware` import path and `createMiddleware` API are unchanged.

```typescript
// src/proxy.ts  (was src/middleware.ts before Next.js 16)
import createMiddleware from 'next-intl/middleware';
import { routing } from './i18n/routing';

export default createMiddleware(routing);

export const config = {
  matcher: ['/((?!api|_next|_vercel|.*\\..*).*)'],
};
```

### 5. Request Config

```typescript
// src/i18n/request.ts
import { getRequestConfig } from 'next-intl/server';
import { hasLocale } from 'next-intl';
import { routing } from './routing';

export default getRequestConfig(async ({ requestLocale }) => {
  const requested = await requestLocale;
  const locale = hasLocale(routing.locales, requested)
    ? requested
    : routing.defaultLocale;

  return {
    locale,
    messages: (await import(`../../messages/${locale}.json`)).default,
  };
});
```

**v4 change:** Read the segment locale from `requestLocale` (async) and explicitly return `locale`. The `locale` argument is only set when a call site passes one explicitly (e.g. `getTranslations({locale})`), so don't rely on it for routing. Use `hasLocale()` for type-safe locale validation instead of `.includes()`.

**Missing-key fallback:** A missing message logs an error and renders the key path (`Namespace.key`) — next-intl does *not* fall back to another locale. To degrade partial translations to the base locale instead, deep-merge the default-locale messages under the requested locale:

```typescript
const base = (await import(`../../messages/${routing.defaultLocale}.json`)).default;
const localeMessages = (await import(`../../messages/${locale}.json`)).default;
return { locale, messages: { ...base, ...localeMessages } }; // deep-merge for nested namespaces
```

Or customize per-key via `getMessageFallback` / `onError` (inspect `IntlErrorCode.MISSING_MESSAGE`).

### 6. Next Config Plugin

```typescript
// next.config.ts
import { createNextIntlPlugin } from 'next-intl/plugin';

const withNextIntl = createNextIntlPlugin();

const nextConfig = {};
export default withNextIntl(nextConfig);
```

### 7. Layout

```tsx
// src/app/[locale]/layout.tsx
import { NextIntlClientProvider } from 'next-intl';
import { getMessages, setRequestLocale } from 'next-intl/server';
import { hasLocale } from 'next-intl';
import { routing } from '@/i18n/routing';
import { notFound } from 'next/navigation';

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }

  setRequestLocale(locale);
  const messages = await getMessages();

  return (
    <html lang={locale}>
      <body>
        <NextIntlClientProvider messages={messages}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```

**v4 note:** `NextIntlClientProvider` auto-inherits `messages` and `formats` from server config. You can omit the `messages` prop if preferred — but passing it explicitly still works and is clearer.

---

## Usage Patterns

### Server Components (default)

```tsx
import { getTranslations } from 'next-intl/server';

export default async function DashboardPage() {
  const t = await getTranslations('Dashboard');
  return <h1>{t('title')}</h1>;
}
```

### Client Components

```tsx
'use client';
import { useTranslations } from 'next-intl';

export default function LoginForm() {
  const t = useTranslations('Auth.login');
  return (
    <form>
      <h2>{t('title')}</h2>
      <button type="submit">{t('submit')}</button>
    </form>
  );
}
```

**Rule:** Prefer Server Components for translations. Only use `useTranslations` in Client Components when interactivity requires it.

### Localized Navigation

```typescript
// src/i18n/navigation.ts
import { createNavigation } from 'next-intl/navigation';
import { routing } from './routing';

export const { Link, redirect, usePathname, useRouter, getPathname } =
  createNavigation(routing);
```

```tsx
// Use localized Link instead of next/link
import { Link } from '@/i18n/navigation';

<Link href="/about">{t('nav.about')}</Link>
```

---

## Type Safety

### Option A: `AppConfig` interface (recommended)

v4 uses a unified `AppConfig` interface with strictly-typed locale, messages, and ICU arguments:

```typescript
// global.d.ts
import messages from './messages/en.json';
import { routing } from './src/i18n/routing';

declare module 'next-intl' {
  interface AppConfig {
    Locale: (typeof routing.locales)[number];
    Messages: typeof messages;
  }
}
```

This gives you:
- Autocompletion for `t('...')`
- Compile-time error if key doesn't exist
- **Strictly-typed ICU arguments** — `t('followers', {})` errors if `count` is missing
- Rich text arguments are typed too: `t.rich('terms', {})` checks for required tag handlers
- `useLocale()`, `Link`, `redirect` all respect the typed `Locale`

The `Locale` type can be imported for custom functions:
```typescript
import { Locale } from 'next-intl';
function getPosts(locale: Locale) { /* ... */ }
```

### Option B: Auto-generated declarations (experimental)

```typescript
// next.config.ts
import { createNextIntlPlugin } from 'next-intl/plugin';

const withNextIntl = createNextIntlPlugin({
  experimental: {
    createMessagesDeclaration: './messages/en.json',
  },
});
```

Requires `"allowArbitraryExtensions": true` in `tsconfig.json`. Generates `.d.json.ts` declaration files on `next dev` / `next build`.

Add to `.gitignore`:
```
*.d.json.ts
```

---

## ICU Message Syntax

### Interpolation

```json
{ "greeting": "Hello, {name}!" }
```
```tsx
t('greeting', { name: 'Alice' })
```

### Pluralization

```json
{
  "followers": "{count, plural, =0 {No followers} one {# follower} other {# followers}}"
}
```
```tsx
t('followers', { count: 42 })
```

### Select (enum-based)

```json
{
  "notification": "{type, select, comment {New comment} like {New like} follow {New follower} other {Notification}}"
}
```
```tsx
t('notification', { type: 'comment' })
```

### Rich Text

```json
{
  "terms": "By signing up, you agree to our <terms>Terms</terms> and <privacy>Privacy Policy</privacy>."
}
```
```tsx
t.rich('terms', {
  terms: (chunks) => <Link href="/terms">{chunks}</Link>,
  privacy: (chunks) => <Link href="/privacy">{chunks}</Link>,
})
```

**v4 note:** `null`, `undefined`, and `boolean` are no longer accepted as ICU arguments.

---

## Formatting

### Using `useFormatter`

```tsx
import { useFormatter } from 'next-intl';

function PriceDisplay({ amount, date }: { amount: number; date: Date }) {
  const format = useFormatter();

  return (
    <div>
      <p>{format.number(amount, { style: 'currency', currency: 'USD' })}</p>
      <p>{format.dateTime(date, { dateStyle: 'medium' })}</p>
      <p>{format.relativeTime(date)}</p>
    </div>
  );
}
```

### Server-side formatting

```tsx
import { getFormatter } from 'next-intl/server';

export default async function Invoice() {
  const format = await getFormatter();
  return <span>{format.number(1299, { style: 'currency', currency: 'USD' })}</span>;
}
```

---

## Static Rendering

By default, `useTranslations` in Server Components opts into dynamic rendering. To enable static rendering:

```tsx
import { setRequestLocale } from 'next-intl/server';
import { getTranslations } from 'next-intl/server';
import { hasLocale } from 'next-intl';
import { routing } from '@/i18n/routing';

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export default async function Page({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) notFound();
  setRequestLocale(locale);

  const t = await getTranslations('Page');
  return <h1>{t('title')}</h1>;
}
```

**Rule:** Call `setRequestLocale(locale)` before any `getTranslations`/`useTranslations` call in statically rendered pages.

---

## SEO

### Localized Metadata

```tsx
import { getTranslations } from 'next-intl/server';
import type { Metadata } from 'next';

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: 'Metadata' });

  return {
    title: t('title'),
    description: t('description'),
  };
}
```

### Alternate Links

With locale-based routing, the proxy/middleware automatically sets an HTTP **`Link` response header** advertising alternate language versions (e.g. `link: <https://example.com/en>; rel="alternate"; hreflang="en", <https://example.com/de>; rel="alternate"; hreflang="de", <https://example.com/>; rel="alternate"; hreflang="x-default"`). Google accepts hreflang via HTTP headers, so this is valid for SEO.

- These are **HTTP headers, not `<head>` tags** — verify with `curl -I <url>`, not by inspecting the rendered HTML `<head>`.
- Controlled by the `alternateLinks` routing option (default `true`). Set `alternateLinks: false` in `defineRouting` for pages not available in every locale, or when pathnames come from a CMS.
- If you also need hreflang as `<head>` tags (e.g. for tools that only scrape HTML), add them via `alternates.languages` in `generateMetadata`.

---

## Language Switcher

```tsx
'use client';
import { useLocale } from 'next-intl';
import { useRouter, usePathname } from '@/i18n/navigation';
import { routing } from '@/i18n/routing';

export function LocaleSwitcher() {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();

  function onChange(nextLocale: string) {
    router.replace(pathname, { locale: nextLocale });
  }

  return (
    <select value={locale} onChange={(e) => onChange(e.target.value)}>
      {routing.locales.map((loc) => (
        <option key={loc} value={loc}>{loc}</option>
      ))}
    </select>
  );
}
```

---

## Common Pitfalls

| Pitfall | Solution |
|---|---|
| Dynamic rendering when you want static | Call `setRequestLocale()` + `generateStaticParams()` |
| Client bundle bloated with all translations | Pass only needed namespaces via `pick()` to `NextIntlClientProvider` (see below) |
| Using `t()` outside React components | Use `getTranslations` from `next-intl/server` in Server Actions, Route Handlers, metadata |
| String concatenation for translated text | Use ICU interpolation: `{name}`, rich text: `<bold>text</bold>` |
| Forgetting `await` on `getTranslations` | It's async in Server Components — always `await` |
| Disabling the locale cookie | Use `localeCookie: false` (not `localeDetection: false`, which controls negotiation) |
| `middleware.ts` on Next.js 16+ | Rename to `proxy.ts`; import path stays `next-intl/middleware` |
| Expecting hreflang in `<head>` | It's an HTTP `Link` header (`curl -I`); add `<head>` tags via `generateMetadata` if needed |
| Using `.includes()` for locale checks | Use `hasLocale()` for type-safe narrowing |
| Old `declare global` type augmentation | v4 uses `declare module 'next-intl'` with `AppConfig` interface |
| Passing `null`/`undefined` as ICU args | v4 disallows — use empty string or omit |

### Reducing Client Bundle by Picking Namespaces

By default, passing all messages to `NextIntlClientProvider` sends every translation to the client. Pick only the namespaces Client Components need:

```tsx
import { NextIntlClientProvider } from 'next-intl';
import { getMessages } from 'next-intl/server';

const messages = await getMessages();
const needed = ['Auth', 'common'] as const;
const clientMessages = Object.fromEntries(
  Object.entries(messages).filter(([k]) => (needed as readonly string[]).includes(k))
);

<NextIntlClientProvider messages={clientMessages}>
  {children}
</NextIntlClientProvider>
```

No external dependency needed — native `Object.fromEntries` / `filter` does the job. (next-intl's docs show `pick(messages, ['Auth', 'common'])` from `lodash/pick`, which preserves the typed `Messages` shape; the native version widens the picked subset's type.)
