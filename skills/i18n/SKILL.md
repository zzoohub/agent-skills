---
name: i18n
description: |
  Internationalization (i18n) architecture and patterns for web and mobile apps.
  Use when: adding multi-language support, setting up translation structure, configuring locale routing, language switching, pluralization, date/number/currency formatting, translation key design. Also use when user says "translate my app", "make it multilingual", "add Korean/English support", "localize my app", or mentions hreflang, locale detection, or language picker.
  Do not use for: general React/Next.js patterns (use composition-patterns / react-best-practices), general mobile patterns (use react-native-skills), UX copy decisions (use copywriting).
---

# i18n Architecture

**For latest APIs, verify against each platform's official docs (linked at the top of every reference file) before writing code.**

## Platform → Library Matrix

| Platform | Library | Architecture |
|---|---|---|
| Next.js | `next-intl` v4 | ICU MessageFormat — first-class Server Component support, built-in type safety |
| Web (Vite-based) | `@inlang/paraglide-js` v2 | Compiler — translations become tree-shakable functions |
| Expo / React Native | `expo-localization` + `react-i18next` + `i18next` | Runtime — i18next JSON v4 |

Next.js: next-intl v4 provides ICU MessageFormat with first-class Server Component support, built-in type safety via `AppConfig`, and automatic locale routing.

Web (Vite-based): Paraglide JS v2 compiles translation files into tree-shakable functions with automatic TypeScript type safety. Works with SvelteKit, TanStack Start, Astro, React Router, or any Vite-based framework. v2 merged all framework adapters into the core package.

Mobile: react-i18next provides runtime i18n with React Native constraints (no Suspense, localStorage persistence, RTL via I18nManager).

These are recommended defaults — branch when the project differs: **Next.js Pages Router** needs the different next-intl Pages setup (provider in `_app`, `getStaticProps` messages), not the App Router guide; **non-Vite React** (CRA/webpack) can use Paraglide via its CLI/bundler plugin or fall back to react-i18next.

> **Variable syntax differs between platforms.** Web/Next (ICU MessageFormat via next-intl/Paraglide) uses single braces: `Hello, {name}`. Expo/mobile (i18next) uses double braces: `Hello, {{name}}`. Same string sources across web + mobile require either a syntax-conversion build step or maintaining separate message files. Most teams keep them separate.

## Retrofitting an Existing App ("translate my app")

Order matters — translation is the *last* step, not the first:

1. **Wire the library + a pseudolocale first** (§10), before extracting
   anything — now every unextracted string is visibly un-mangled.
2. **Extract feature-by-feature, not file-by-file** — `feature.context.purpose`
   keys fall out naturally, and each PR ships a fully-switchable feature
   instead of a half-translated layer.
3. **Turn on the no-literal-string lint** (§7) once a feature is extracted, so
   it can't regress while the rest migrates.
4. **Order translations last**, when keys have stopped churning — translating
   mid-extraction pays twice.

---

## Core Principles

### 1. Organize Keys by Feature

Group keys by domain/feature using the access path `feature.context.purpose`. Features are stable; pages change.

**Store messages as nested JSON objects.** Do *not* use a literal flat key like `"auth.login.title"`: next-intl and i18next reserve `.` for nesting, so a flat key is parsed as `auth → login → title` and won't resolve.

```json
{
  "auth": { "login": { "title": "Sign In", "submit": "Sign In" } },
  "common": { "save": "Save", "cancel": "Cancel" }
}
```

For mobile (i18next), the same structure split into namespace files: `locales/en/auth.json`, `locales/en/common.json`. (Paraglide is the exception — it also accepts flat dotted keys and compiles them to `m.auth_login_title()`; see `references/web-i18n.md`.)

**Rules:**
- Key describes purpose, not the text: `auth.login.submit` not `auth.login.signInButton`
- Never concatenate translated strings — full sentences only
- One key per unique UI instance (even if English text is identical — translations may differ)
- `common.*` for truly shared strings only
- 2-3 levels max: `feature.context.purpose`
- Casing is stylistic but be consistent per project: next-intl examples here use PascalCase namespaces (`Auth.login`); Paraglide/i18next use lowercase.

### 2. Type Safety Is Mandatory

- Next.js (next-intl): Augment the `AppConfig` interface (`declare module 'next-intl'`). See `references/next-i18n.md`.
- Web (Paraglide): Automatic — compiler generates typed functions. No configuration needed.
- Mobile (react-i18next): Module augmentation with `CustomTypeOptions`. See `references/expo-i18n.md`.

### 3. Format via Intl, Never Hand-Format in Text

Do number/date/currency formatting through `Intl` formatters — in code, or via a library's message-level formatters (next-intl ICU `{x, number}`, Paraglide `number`/`datetime` declarations). Never bake formatted values into literal text.
Exception: Pluralization belongs in the translation string.

### 4. Plural Categories by Language

Use only the CLDR categories a language actually has — a variant for a category the language lacks never renders. The locales below are this guide's example set; for any other locale run `new Intl.PluralRules(locale).resolvedOptions().pluralCategories` or check the [CLDR plural-rules chart](https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html).

| Language | Plural categories |
|---|---|
| en | `one`, `other` |
| es, pt-BR | `one`, `other` (+ `many` for large/compact magnitudes like 1M) |
| ja, ko, id | `other` only |

Richer systems exist: Arabic has `zero`, `one`, `two`, `few`, `many`, `other`; Polish/Russian have `one`, `few`, `many`, `other`. If you ship the RTL locales in §6 (ar/he/fa/ur), provide their full category set.

### 5. Formatting Utilities (Cross-Platform)

Platform-agnostic `Intl` wrappers. Each platform wraps this with its own locale source (Paraglide: `getLocale()`, i18next: `i18n.language`, next-intl: `useLocale()`).

```typescript
export function createFormatters(locale: string) {
  return {
    number: (v: number, opts?: Intl.NumberFormatOptions) =>
      new Intl.NumberFormat(locale, opts).format(v),
    // Currency code comes from the user's region/billing — never inferred from UI language (Principle 9).
    currency: (v: number, currency: string) =>
      new Intl.NumberFormat(locale, { style: 'currency', currency }).format(v),
    // For SSR pass an explicit timeZone (user pref or 'UTC') to avoid a server/client hydration mismatch.
    date: (d: Date, opts?: Intl.DateTimeFormatOptions) =>
      new Intl.DateTimeFormat(locale, { dateStyle: 'medium', ...opts }).format(d),
    list: (items: string[], type: Intl.ListFormatOptions['type'] = 'conjunction') =>
      new Intl.ListFormat(locale, { type, style: 'long' }).format(items),
    // Locale-aware sort — never use default Array.sort()/localeCompare() for user-visible lists.
    collator: (opts?: Intl.CollatorOptions) => new Intl.Collator(locale, opts),
    // DurationFormat types ship only in lib "esnext"; the self-contained unit type + cast work on any lib target. Drop the `as any` once `lib: ["esnext"]` is set.
    duration: (parts: Partial<Record<
      'years' | 'months' | 'weeks' | 'days' | 'hours' | 'minutes' | 'seconds'
      | 'milliseconds' | 'microseconds' | 'nanoseconds', number>>) =>
      new (Intl as any).DurationFormat(locale, { style: 'long' }).format(parts),
    relativeTime: (d: Date) => {
      const diffSec = Math.floor((Date.now() - d.getTime()) / 1000);
      const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });
      if (Math.abs(diffSec) < 60) return rtf.format(-diffSec, 'second');
      if (Math.abs(diffSec) < 3600) return rtf.format(-Math.floor(diffSec / 60), 'minute');
      if (Math.abs(diffSec) < 86400) return rtf.format(-Math.floor(diffSec / 3600), 'hour');
      // Capped at 'day' for brevity — extend with week/month/year buckets if needed.
      return rtf.format(-Math.floor(diffSec / 86400), 'day');
    },
    // Word/grapheme segmentation for ja/ko/zh/th (which don't space-separate)
    segment: (text: string, granularity: 'word' | 'sentence' | 'grapheme' = 'word') =>
      Array.from(new Intl.Segmenter(locale, { granularity }).segment(text)),
  };
}
```

`Intl.ListFormat` (Chrome 72+, Firefox 78+, Safari 14.1+ — Baseline), `Intl.Collator` (all current browsers), `Intl.Segmenter` (Chrome 87+, Safari 14.1+, Firefox 125+), `Intl.DurationFormat` (Chrome 129+, Safari 16.4+, Firefox 136+ — Baseline 2025; types require `lib: ["esnext"]`; polyfill for older).

### 6. RTL / Bidi Support

For locales like ar, he, fa, ur:

- Set `<html lang="..." dir="rtl">` based on the active locale's `Intl.Locale.prototype.getTextInfo().direction` (a method — see note below). On the root `<html>` prefer an explicit `rtl`/`ltr` from the resolved locale; reserve `dir="auto"` for user-generated runs of unknown direction (see §10), not the root.
- Use **CSS logical properties** instead of physical: `margin-inline-start` not `margin-left`, `padding-block-end` not `padding-bottom`, `inset-inline` not `left/right`. Tailwind v4 has `ps-*`/`pe-*`/`ms-*`/`me-*` utilities.
- Mirror icons that imply direction (arrows, chevrons) — leave content-meaningful icons alone (clock, search)
- Test with `dir="rtl"` on a few pages even if you don't ship RTL today — catches physical-property bugs early
- React Native: `I18nManager.forceRTL(true)` + `I18nManager.allowRTL(true)`; requires app restart to apply

```ts
// getTextInfo() is a method (the old `textInfo` accessor was removed) and needs lib "esnext" (drop the `as any` once that lib target is set).
// Firefox doesn't implement it (any version), so fall back to a known-RTL language list.
const RTL_LANGS = new Set(['ar', 'he', 'fa', 'ur', 'ps', 'sd', 'ckb', 'yi']);
function isRtl(locale: string): boolean {
  try {
    const dir = (new Intl.Locale(locale) as any).getTextInfo?.()?.direction;
    if (dir) return dir === 'rtl';
  } catch { /* fall through */ }
  return RTL_LANGS.has(new Intl.Locale(locale).language);
}
```

### 7. Missing Keys & Fallback

Translators ship partial files, so non-base locales *will* have gaps. Configure each library to degrade to the base locale instead of crashing or showing raw keys:

- **next-intl:** a missing message logs an error and renders the key path (`Namespace.key`) — it does *not* fall back to another locale. Deep-merge `defaultLocale` messages under each locale in `request.ts`, or set `getMessageFallback` / `onError`.
- **i18next:** set `fallbackLng` (falls back automatically) and `returnEmptyString: false`; use `saveMissing` + a reporter in dev.
- **Paraglide:** a key missing in a locale falls back to `baseLocale`. Per-locale gaps are *not* a compiler error (only an unknown message id is) — catch them with inlang lint / Sherlock.

Posture: never crash, fall back to base locale, log the gap. Two CI guards keep
this true over time: a **key-parity check** (inlang CLI, `i18next-parser`, or
next-intl `createMessagesDeclaration` to turn gaps into type errors), and a
**no-literal-string lint** (`eslint-plugin-i18next`'s `no-literal-string`, or
`react/jsx-no-literals`) so new hardcoded UI strings can't land after
extraction — without it the extraction work silently regresses.

### 8. Locale Fallback Chains

Regional locales need a chain: `pt-BR → pt → en`, not a jump straight to base.

- **i18next:** native — `fallbackLng: { 'pt-BR': ['pt', 'en'], default: ['en'] }` + `load: 'languageOnly'`.
- **next-intl / Paraglide:** no automatic language-only fallback — enumerate each regional variant or build the chain in `request.ts` / a custom strategy. Decide deliberately whether you match `pt-BR` exactly or accept any `pt-*`.

### 9. Language vs Region vs Currency

Language (what to translate) is independent from region (currency, date/number conventions). A Spanish speaker may be in Mexico (MXN) or Spain (EUR). Drive currency and formatting region from a **separate** user/region setting, never from the UI language. BCP-47 structure: `language-Script-REGION` (e.g. `zh-Hant-TW`).

### 10. Test Before Translators Arrive

- **Pseudolocalization:** add a synthetic locale (e.g. `Ŝéttîngŝ [!!!]`, padded ~40%) to surface unextracted/hardcoded strings and text-expansion breakage early.
- **Layout:** budget ~30–40% expansion (de/fi run long; es/pt-BR ~20–30% over en); avoid fixed-width buttons and single-line truncation; allow wrapping.
- **A11y:** mark inline content in a different language with its own `lang` (`<span lang="ko">`) so screen readers switch pronunciation; use `dir="auto"` for user-generated / RTL runs. User-generated content is never keyed — apply correct `lang`/`dir` per item and sort it with `Intl.Collator`.

---

## Platform-Specific Guides

- **Next.js (next-intl v4):** `references/next-i18n.md`
  - Setup, proxy/middleware, Server/Client Component usage
  - ICU MessageFormat, type safety via `AppConfig`, static rendering
  - Localized navigation, SEO, language switcher
- **Web / Vite-based (Paraglide JS):** `references/web-i18n.md`
  - Setup (Vite plugin / CLI), message format, SSR middleware
  - URL localization, language switcher, rich text, SEO
  - Framework notes: SvelteKit, TanStack Start, Astro, React Router
- **Expo (react-i18next + i18next):** `references/expo-i18n.md`
  - Device detection, i18next init, JSON v4 pluralization
  - Lazy loading, RTL, language switching, native locale config

---

## Checklist

- [ ] Keys organized by feature, stored as nested objects (access path `auth.login.title` → `{ auth: { login: { title } } }`, not a literal flat dotted key)
- [ ] Type-safe keys (next-intl: `AppConfig`, Paraglide: automatic, i18next: `CustomTypeOptions`)
- [ ] Pluralization uses platform-native syntax AND only the CLDR categories each language has (ja/ko/id: `other` only)
- [ ] Formatting via `Intl`/library formatters, never hand-formatted in text; currency from region, not language
- [ ] Missing-key fallback configured per library — degrade to base locale, never crash
- [ ] CI guards on: key-parity check + no-literal-string lint (§7)
- [ ] Locale-aware sorting via `Intl.Collator`; explicit `timeZone` for SSR dates
- [ ] Language persistence: cookie (web), localStorage (mobile)
- [ ] SEO: `<html lang>`, `hreflang` alternates (web only)
- [ ] No string concatenation — full sentences always
- [ ] Generated `src/paraglide/` not manually edited (web)
