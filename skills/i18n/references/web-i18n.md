# Vite web apps with Paraglide JS

Verified against @inlang/paraglide-js 2.26 on 2026-10-08. If the lockfile major differs, follow that version's docs (paraglidejs.com). Locale lists are placeholders. The v1 adapters (`@inlang/paraglide-sveltekit`, `-next`, `-astro`) are deprecated; v2 is one package.

Paraglide compiles each message into a typed function: unused messages drop out of the bundle, and an unknown message or missing parameter fails the type check, but a missing translation falls back silently by truncation (pt-BR → pt), then to `baseLocale`, the source language. When some markets can't read the source, gate 1 at the release cut is what keeps them from seeing it (gates below).

## Init

`npx @inlang/paraglide-js@latest init` adds the dependency without installing it (install afterwards) and writes `project.inlang/settings.json`, including `modules` (the message-format plugin) and that plugin's `pathPattern` (`./messages/{locale}.json`). Edit `baseLocale` and `locales` there; let `init` write the rest. To share ICU or i18next catalogs with another app, swap the format plugin (`@inlang/plugin-icu1`, `@inlang/plugin-i18next`).

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import { paraglideVitePlugin } from '@inlang/paraglide-js';

export default defineConfig({
  plugins: [
    paraglideVitePlugin({
      project: './project.inlang',
      outdir: './src/paraglide', // generated, ships its own .gitignore; never edit
      strategy: ['url', 'cookie', 'baseLocale'], // see Strategy
    }),
  ],
});
```

Other bundlers: Paraglide's webpack, Rspack, Rollup, Rolldown or esbuild plugins; without a plugin, run the compiler with `--watch` in development.

Bundle size grows with locale count, since each used message carries every locale: measure past ~10 locales; the experimental `experimentalStaticLocale` compiler option builds one locale per bundle.

## Messages

```json
{
  "greeting": "Hello, {name}!",
  "follower_count": [{
    "declarations": ["input count", "local countPlural = count: plural"],
    "selectors": ["countPlural"],
    "match": { "countPlural=one": "{count} follower", "countPlural=*": "{count} followers" }
  }],
  "order_total": [{
    "declarations": ["input amount", "input currency", "local total = amount: number style=currency currency=$currency"],
    "match": { "amount=*": "Total: {total}" }
  }],
  "terms": "Agree to our {#link}Terms{/link}."
}
```

- **End every plural `match` with a `*` variant.** A count in a category you didn't list (es/fr/it/pt `many` for 1,000,000; ru `few`) otherwise renders the message key. Translators list their locale's categories before `*`.
- **Currency is an input** (`currency=$currency`; without `$` it's a literal code baked into every locale): `m.order_total({ amount, currency: order.currency })`.
- **Rich text is markup**: `{#link}…{/link}` in the message, rendered by `ParaglideMessage` from `@inlang/paraglide-js-react` (Svelte, Vue and Solid adapters exist), which type-checks tag names. Don't parse tags out of strings.
- Flat keys (`m.greeting()`); dotted keys compile to `m["auth.login.title"]()`.

```ts
import { m } from './paraglide/messages.js';
import { getLocale, setLocale, localizeHref } from './paraglide/runtime.js';

m.greeting({ name }, { locale: 'de' }); // explicit locale, e.g. for an email rendered server-side
setLocale('de'); // reloads the page by default; { reload: false } leaves re-rendering to you
localizeHref('/about'); // "/de/about" under the url strategy
```

## Strategy

`strategy` is the resolution precedence of SKILL.md §2b; the first strategy that yields a locale wins.

- **Public routes: `url` first.** Its default pattern serves the base locale unprefixed, so `/` resolves to `baseLocale` and later strategies never run there: a returning visitor on `/` gets the base locale.
- **To negotiate, prefix every locale, base included**, so only locale-less URLs negotiate: `urlPatterns: [{ pattern: '/:path(.*)?', localized: [['de', '/de/:path(.*)?'], ['en', '/en/:path(.*)?']] }]` with `strategy: ['url', 'cookie', 'preferredLanguage', 'baseLocale']`. The middleware 307-redirects document requests for `/` or `/about` to the stored or negotiated prefix; `/de/about` stays German. Not `routeStrategies` on `/`: it also matches de-localized URLs, so `/de/` would follow the visitor's cookie or browser language. Don't share-cache locale-less URLs; the redirect also depends on the cookie.
- **Signed-in, non-indexed routes:** `routeStrategies` with `['cookie', 'baseLocale']` or a custom strategy that reads the profile; `exclude: true` skips the middleware for API routes.
- **Client-only SPA:** `['localStorage', 'preferredLanguage', 'baseLocale']`.
- `preferredLanguage` tries each tag, then its bare language; it doesn't map zh-TW to zh-Hant. Name Chinese locales by region (zh-TW, zh-HK; Simplified as zh-CN, never a bare `zh`, whose fallback would cross scripts) or match with a custom strategy.
- Cookie across subdomains: `cookieDomain: 'example.com'`.

## SSR middleware

`paraglideMiddleware` scopes the locale to each request through AsyncLocalStorage; outside it, server code sees the base locale. Keep AsyncLocalStorage on (Vercel Edge; Cloudflare Workers with `nodejs_compat`): `disableAsyncLocalStorage` leaks one request's locale into another unless the runtime isolates every request.

```ts
// SvelteKit: src/hooks.server.ts (app.html: <html lang="%lang%" dir="%dir%">)
import type { Handle } from '@sveltejs/kit';
import { paraglideMiddleware } from '$lib/paraglide/server';
import { getTextDirection } from '$lib/paraglide/runtime';

export const handle: Handle = ({ event, resolve }) =>
  paraglideMiddleware(event.request, ({ request, locale }) => {
    event.request = request;
    return resolve(event, {
      transformPageChunk: ({ html }) =>
        html.replace('%lang%', locale).replace('%dir%', getTextDirection(locale)),
    });
  });

// SvelteKit: src/hooks.ts (not .server.ts); without it /de/about is a 404
import type { Reroute } from '@sveltejs/kit';
import { deLocalizeUrl } from '$lib/paraglide/runtime';
export const reroute: Reroute = (request) => deLocalizeUrl(request.url).pathname;

// TanStack Start: src/server.ts. Pass the ORIGINAL request: the router de-localizes URLs
// itself (rewrite.input/output with deLocalizeUrl/localizeUrl), so the modified one loops.
import handler from '@tanstack/react-start/server-entry';
import { paraglideMiddleware } from './paraglide/server.js';
export default { fetch: (req: Request) => paraglideMiddleware(req, () => handler.fetch(req)) };

// Astro (output: 'server'): src/middleware.ts
import { defineMiddleware } from 'astro:middleware';
import { paraglideMiddleware } from './paraglide/server.js';
export const onRequest = defineMiddleware((context, next) =>
  paraglideMiddleware(context.request, ({ request }) => next(request)));
```

## SEO

Set `<html lang dir>` from `getLocale()` and `getTextDirection()` on every page. Through the framework's head API, render one absolute `<link rel="alternate" hreflang>` per entry of `locales`, its `href` from `localizeHref(path, { locale })`, plus `x-default` on the unprefixed path.

This reference owns the implementation mechanics only. Which locales to target, hreflang correctness (reciprocity, codes, the `x-default` target) and localized keyword strategy belong to a search-visibility capability (the `search-visibility` skill, if available).

## Gates

The inlang CLI v3 removed `lint`, and the Sherlock extension checks only in the editor, so CI needs its own:
- **Parity:** compare each `messages/{locale}.json`'s keys, `{inputs}` and `{#markup}` tags with the base file's; fail on a missing or empty value.
- **Plurals:** each locale's plural `match` lists every category a count reaches in that locale (the ordinal set under `type=ordinal`) and ends with `*` (standing in for `other`); a variant for a category the locale lacks never renders, so flag it.
- **ICU catalogs** (via `@inlang/plugin-icu1`): the gate script in `next-i18n.md` covers parity, parsing and plural forms.

Prove each red on a seeded defect and green on a known-good catalog.
