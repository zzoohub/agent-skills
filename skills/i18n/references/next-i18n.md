# Next.js App Router with next-intl

Verified against next-intl 4.14 and Next.js 16.4 on 2026-10-08. If the lockfile majors differ, follow that version's docs (next-intl.dev). Locale lists are placeholders.

## Routing

```ts
// src/i18n/routing.ts
import { defineRouting } from 'next-intl/routing';

export const routing = defineRouting({
  locales: ['en', 'de', 'ar', 'pt-BR'], // placeholder: the project's locales
  defaultLocale: 'en',
});
```

`src/i18n/navigation.ts` exports `createNavigation(routing)`'s `Link`, `redirect`, `usePathname`, `useRouter` and `getPathname`; use that `Link`, not next/link.

- **URL strategy:** `localePrefix` defaults to `'always'`. `'never'` keeps the locale out of the URL (cookie-driven, no alternate links: not for indexable pages). `'as-needed'` leaves the default locale unprefixed, yet detection still redirects `/about` to `/de/about` by cookie or `Accept-Language`, against SKILL.md §2b's explicit-URL rule: keep `'always'` or set `localeDetection: false`. `domains` maps each locale to one domain; for public pages, search-visibility picks the structure (SKILL.md §1, question 5).
- **`localeCookie` vs `localeDetection`:** the cookie remembers a choice; detection negotiates from `Accept-Language` and the cookie. Disable the cookie with `localeCookie: false`, not `localeDetection: false`. It is a session cookie by default; a long `maxAge` is an opt-in with consent implications.

## Proxy

```ts
// src/proxy.ts (Next 16+; middleware.ts before)
import createMiddleware from 'next-intl/middleware';
import type { NextRequest } from 'next/server';
import { routing } from './i18n/routing';

const handleI18nRouting = createMiddleware(routing);

// next-intl best-fits the whole Accept-Language list (`en-GB,de;q=0.9` → de); each tag's
// language-script (en-Latn, zh-Hant) lets the first preference win without crossing scripts
const hint = (part: string) => {
  const [tag, ...q] = part.trim().split(';');
  try {
    const { language, script } = new Intl.Locale(tag).maximize();
    return `${part},${[`${language}-${script}`, ...q].join(';')}`;
  } catch {
    return part; // `*` or a malformed tag
  }
};

export default function proxy(request: NextRequest) {
  const header = request.headers.get('accept-language');
  if (header) request.headers.set('accept-language', header.split(',').map(hint).join(','));
  // NEXT_LOCALE follows the last locale URL opened; for signed-in users the profile decides `/`
  const profile = request.cookies.get('profile_locale')?.value; // yours: set at sign-in and by the picker
  if (profile) request.cookies.set('NEXT_LOCALE', profile);
  return handleI18nRouting(request);
}

export const config = { matcher: '/((?!api|trpc|_next|_vercel|.*\\..*).*)' };
```

Test negotiation with `curl -I -H 'Accept-Language: en-GB,de;q=0.9' <origin>/`: the redirect must go to `/en`. `proxy.ts` runs on Node.js only (setting `runtime` throws); a deployment that needs the Edge runtime keeps the deprecated `middleware.ts`.

## Request config

`[locale]/layout.tsx` is the root layout (no `app/layout.tsx` above it), which makes `locale` a root param. Catalogs live in `messages/` at the project root.

```ts
// src/i18n/request.ts (Next ≥ 16.3)
import * as rootParams from 'next/root-params';
import { notFound } from 'next/navigation';
import { getRequestConfig } from 'next-intl/server';
import { hasLocale } from 'next-intl';
import deepmerge from 'deepmerge';
import { routing } from './routing';

const load = (l: string) => import(`../../messages/${l}.json`).then((m) => m.default);
const script = (l: string) => new Intl.Locale(l).maximize().script;
const READABLE = 'en'; // every chain's last hop: a language all your markets read, not always the source

export default getRequestConfig(async ({ locale }) => {
  // `locale` is set only when a caller passes one (Route Handlers, Server Actions)
  if (!locale) {
    const param = await rootParams.locale();
    if (!hasLocale(routing.locales, param)) notFound();
    locale = param;
  }
  const parent = new Intl.Locale(locale).language; // pt under pt-BR, if it ships; never zh (Hans) under zh-TW
  const [source, readable, inherited, own] = await Promise.all([
    load(routing.defaultLocale), // holds every key: the last resort, never a raw key
    load(READABLE).catch(() => ({})),
    script(parent) === script(locale) ? load(parent).catch(() => ({})) : {},
    load(locale),
  ]);
  return {
    locale,
    messages: deepmerge.all([source, readable, inherited, own]), // deep: a spread drops a half-translated namespace's keys
    timeZone: 'UTC', // see the timeZone note below
  };
});
```

- **`timeZone`:** unset, next-intl formats in the host's zone, so moving the deployment shifts dates. Whose clock is a decision (SKILL.md §4, Time). The root layout's `getLocale()` runs this file on every route, so keep it on a constant zone, which keeps static routes static: the main market's or `'UTC'`, with times labeled (`timeZoneName: 'short'` beside component options; `dateStyle`/`timeStyle` throw with it, though `timeStyle: 'long'` prints the zone). Reading the session or a cookie here makes every route dynamic, marketing pages included: do it only if every route is dynamic anyway. Signed-in pages are dynamic already: pass the profile's zone per call (`format.dateTime(at, { dateStyle: 'medium', timeZone: user.timeZone })`) and to a `<NextIntlClientProvider timeZone={user.timeZone}>` in the signed-in layout, so dates stay in the server HTML. An event at a place passes its own zone the same way (`timeZone: event.timeZone`). Re-formatting in the browser's zone after hydration changes text after load, so choose it explicitly; to serve that zone on later requests, store it on the profile, or in a cookie read only where routes are dynamic anyway.
- Root params don't work in Route Handlers or Server Actions: pass the locale (`getTranslations({ locale, namespace: 'Errors' })`).
- Server-rendered relative times need `now` here, so hydration uses the same instant; the client provider inherits `locale`, `messages`, `timeZone`, `now` and `formats`.
- **Next < 16.3:** 15.5–16.2 run this file once the Next config sets `experimental.rootParams: true`. Older versions use the still-supported legacy path: read `await requestLocale` (falling back to `defaultLocale` when `hasLocale` fails), and call `setRequestLocale(locale)` in every layout and page before any next-intl call to stay static.

## Plugin and layout

```ts
// next.config.ts
import createNextIntlPlugin from 'next-intl/plugin'; // default export only

const withNextIntl = createNextIntlPlugin({
  experimental: { createMessagesDeclaration: './messages/en.json' }, // typed ICU arguments and tags
});
export default withNextIntl({});
```

```ts
// src/i18n/dir.ts: script, not language (sd-IN is Devanagari, LTR; pa-Arab and ug are RTL). Web and Node only.
const RTL_SCRIPTS = new Set(['Arab', 'Hebr', 'Thaa', 'Syrc', 'Nkoo', 'Adlm', 'Rohg']);
export const dirOf = (locale: string) =>
  RTL_SCRIPTS.has(new Intl.Locale(locale).maximize().script ?? '') ? 'rtl' : 'ltr';
```

```tsx
// src/app/[locale]/layout.tsx, which also exports generateStaticParams: routing.locales.map((locale) => ({ locale }))
export default async function LocaleLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale(); // next-intl/server
  return (
    <html lang={locale} dir={dirOf(locale)}>
      <body><NextIntlClientProvider>{children}</NextIntlClientProvider></body>
    </html>
  );
}
```

## Messages and formatting

Translate in Server Components (`await getTranslations('Dashboard')`); use `useTranslations` only where a Client Component needs it.

```tsx
t('count', { count }); // "{count, plural, =0 {No followers yet} one {# follower} other {# followers}}"
t.rich('terms', { terms: (chunks) => <Link href="/terms">{chunks}</Link> }); // "Agree to our <terms>Terms</terms>."

const format = await getFormatter(); // useFormatter() in Client Components
format.number(price.amount, { style: 'currency', currency: price.currency }); // currency travels with the price
format.relativeTime(comment.createdAt); // relative to the configured `now`
```

ICU arguments can't be `null`, `undefined` or booleans in v4.

## Types

Augment next-intl's `AppConfig` in `global.d.ts` with `Locale: (typeof routing.locales)[number]` and `Messages: typeof messages` (from `messages/en.json`). Typed ICU arguments and `t.rich` tags also need the plugin's `createMessagesDeclaration` plus `"allowArbitraryExtensions": true` in tsconfig; gitignore the generated `messages/*.d.json.ts`. Both type the base file only: a key missing from `de.json` compiles. The gates below catch it.

## CI gates 1–3 for ICU catalogs

```js
// scripts/check-messages.mjs: parity, parse with the source's arguments and tags, reachable plural forms
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { parse, TYPE } from '@formatjs/icu-messageformat-parser';

const DIR = 'messages', BASE = 'en';
const load = (l) => JSON.parse(readFileSync(`${DIR}/${l}.json`, 'utf8'));
const flat = (o, p = '') => Object.entries(o).flatMap(([k, v]) =>
  v && typeof v === 'object' ? flat(v, `${p}${k}.`) : [[p + k, v]]);
const entries = (l) => (existsSync(`${DIR}/${l}.json`) ? flat(load(l)) : []);
const script = (l) => new Intl.Locale(l).maximize().script;
function scan(nodes, out = { names: new Set(), plurals: [] }) {
  for (const n of nodes) {
    if (n.type === TYPE.literal || n.type === TYPE.pound) continue;
    out.names.add(n.type === TYPE.tag ? `<${n.value}>` : n.value);
    if (n.type === TYPE.tag) scan(n.children, out);
    if (n.type === TYPE.plural) out.plurals.push(n);
    if (n.options) for (const o of Object.values(n.options)) scan(o.value, out);
  }
  return out;
}
const sig = (s) => [...scan(parse(s)).names].sort().join();
const COUNTS = [...Array(1001).keys(), 1e4, 1e5, 1e6, 2e6, 1e9]; // integers reach every category (millions: fr/es/it/pt `many`)
const memo = {};
// Categories a count reaches past the exact matches: en `=1` leaves `one` nothing; an offset shifts categories only.
function reached(locale, { options, offset, pluralType }) {
  const exact = Object.keys(options).filter((k) => k.startsWith('='));
  return (memo[[locale, pluralType, offset, exact]] ??= (() => {
    const rules = new Intl.PluralRules(locale, { type: pluralType });
    const counts = new Set([...COUNTS, ...COUNTS.map((n) => n + offset)]);
    return new Set([...counts].filter((n) => !exact.includes(`=${n}`)).map((n) => rules.select(n - offset)));
  })());
}
const source = new Map(flat(load(BASE)));
let failed = 0;
for (const file of readdirSync(DIR).filter((f) => /^[^.]+\.json$/.test(f))) {
  const locale = file.slice(0, -5);
  const parent = new Intl.Locale(locale).language; // pt-BR is checked merged over pt; zh-TW never over a Simplified zh
  const target = new Map([...(script(parent) === script(locale) ? entries(parent) : []), ...entries(locale)]);
  for (const [key, src] of source) {
    let problem = null;
    try {
      const msg = target.get(key);
      if (!msg) problem = 'missing or empty';
      else if (sig(msg) !== sig(src)) problem = 'arguments or tags differ from the source';
      else for (const p of scan(parse(msg)).plurals) {
        const keys = Object.keys(p.options), cats = reached(locale, p);
        const lacking = [...cats].filter((c) => !keys.includes(c));
        const dead = keys.filter((k) => k !== 'other' && !k.startsWith('=') && !cats.has(k));
        if (lacking.length) problem = `plural lacks ${lacking.join(', ')}`;
        if (dead.length) console.warn(`${locale} ${key}: ${dead.join(', ')} never renders; drop it`);
      }
    } catch { problem = 'does not parse'; }
    if (problem) { console.error(`${locale} ${key}: ${problem}`); failed++; }
  }
}
process.exit(failed ? 1 : 0);
```

Prove it red: delete a key, blank another, rename an argument, drop `few` from a Russian plural, and leave a zh-Hant key missing next to a Simplified `zh.json`. Prove it green on known-good messages: `=0 {…} =1 {…} other {…}` in en and de, an `other`-only ja plural, and Arabic `=0`/`=1`/`=2` beside few/many/other. The warnings name branches that never render (`one` in ja, en `one` beside `=1`); counts are sampled as integers, so a branch only decimals reach (lt `many`) warns too.

## SEO

- The proxy emits hreflang as an HTTP `Link` response header (with `x-default`), on by default (`alternateLinks`). Check it with `curl -I <url>`, not in the HTML `<head>`.
- One method is enough: keep the header, or set `alternateLinks: false` and emit `alternates.languages` from `generateMetadata` (needed when a page doesn't exist in every locale or its pathnames come from a CMS). If you use both, keep them identical.
- hreflang correctness (reciprocity, codes, `x-default` target) is search-visibility's (via that capability, if available).

## Language switcher

Picker rules are in SKILL.md §2b. Label each option `new Intl.DisplayNames([l], { type: 'language' }).of(l)` with `lang={l}`, and switch through the navigation router, which keeps the path: `router.replace(pathname + window.location.search, { locale })`.

## Pitfalls

| Pitfall | Fix |
|---|---|
| `INVALID_KEY` | A JSON key contains `.`; nest it |
| A key renders as `Namespace.key` | It is missing from the base, or a Client Component's namespace isn't in the picked `messages` |
| The whole catalog ships to the client | Pass `<NextIntlClientProvider messages={picked}>` only the namespaces its Client Components render; this replaces the inherited full set (next-intl's docs pick with `lodash/pick`, which keeps the `Messages` type) |
