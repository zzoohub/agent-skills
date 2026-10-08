# Expo / React Native with i18next

Verified against Expo SDK 57 (58 in beta), i18next 26 and react-i18next 17 on 2026-10-08. If the lockfile majors differ, follow that version's docs (docs.expo.dev/guides/localization, i18next.com, react.i18next.com). Locale lists are placeholders.

## Install

```bash
npx expo install expo-localization expo-sqlite i18next react-i18next \
  @formatjs/intl-locale @formatjs/intl-pluralrules @formatjs/intl-localematcher
```

`expo-sqlite` is only for an in-app language picker.

## Polyfills

Hermes implements only `Intl.Collator`, `NumberFormat`, `DateTimeFormat` and `getCanonicalLocales` (`NumberFormat.formatToParts` on Android only); check `doc/IntlAPIs.md` in the Hermes repo for your version. `PluralRules`, `Locale`, `RelativeTimeFormat`, `ListFormat`, `DisplayNames`, `Segmenter` and `DurationFormat` throw. Load polyfills first, in this order (checked 2026-10):

```ts
// src/lib/i18n/polyfills.ts: imported before i18next and the matcher
import '@formatjs/intl-locale/polyfill-force.js'; // pluralrules and the matcher need Intl.Locale
import '@formatjs/intl-pluralrules/polyfill-force.js'; // -force: feature detection is slow on Android
import '@formatjs/intl-pluralrules/locale-data/en.js'; // and one per other shipped language; pt covers pt-BR
// then only the constructors the app calls, e.g. @formatjs/intl-relativetimeformat + its locale-data
```

Skip what you can avoid: language names come from a static map of endonyms ("Deutsch", "Português (Brasil)"), and number input is parsed with `getLocales()[0].decimalSeparator`, not `formatToParts`.

## Resolve and init

```ts
// src/lib/i18n/index.ts: the first import in app/_layout.tsx
import './polyfills';
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { getLocales } from 'expo-localization';
import { match } from '@formatjs/intl-localematcher';
import { resources, supportedLocales, type SupportedLocale } from './resources'; // { en: { common, auth }, de: {…}, 'pt-BR': {…} }

export function resolveLocale(tags = getLocales().map((l) => l.languageTag)): SupportedLocale {
  for (const tag of tags) { // one tag at a time: a best fit over [es-MX, en-US] returns en
    try {
      const hit = match([tag], supportedLocales, 'und'); // es-MX → es, pt-PT → pt-BR, zh-TW → zh-Hant
      if (hit !== 'und') return hit as SupportedLocale;
    } catch {} // malformed device tag
  }
  return 'en'; // no match: a language those users read (SKILL.md §2b), not automatically the source
}

i18n.use(initReactI18next).init({
  resources,
  lng: resolveLocale(),
  fallbackLng: 'en', // the default load: 'all' walks pt-BR → pt → en; end in a language every market reads
  defaultNS: 'common',
  returnEmptyString: false, // an empty translation falls back instead of rendering blank
  interpolation: { escapeValue: false }, // React already escapes
  initAsync: false, // bundled resources are ready on first render
});

export default i18n;
```

- Don't set `load: 'languageOnly'` while you ship regional bundles: it reads `pt` for pt-BR and never the `pt-BR` bundle. Object `fallbackLng` is for chains across languages (`{ 'de-CH': ['fr', 'it'], default: ['en'] }`).
- `react: { useSuspense: false }` is optional with bundled resources; with lazy namespaces, keep Suspense or render after `ready`.
- Format numbers and dates with the first device tag whose `languageCode` is the UI's language (en-GB under `en`), else the UI locale; a tag in another language puts its month names in your UI.
- The 24-hour clock and week start are device settings `Intl` can't see: pass `hourCycle: 'h23'` or `'h12'` from `getCalendars()[0].uses24hourClock`, and start calendars on `firstWeekday` (1 = Sunday).

## One language source of truth

Choose by when switching must work, and on which devices:
- **The OS per-app setting:** declare `supportedLocales` in the plugin (Native config) and follow the OS; `useLocales()` re-renders on a change (iOS restarts the app). It is native config, so it, and every locale added to it later, ships only in a new binary after store review; Android offers the setting from Android 13, so older devices get the device language only.
- **An in-app picker** when users need the switch before that build, on Android 12 or older, in a language other than the OS's, or as one choice across devices. It is JavaScript (`i18n.changeLanguage`, no restart unless direction flips), so it ships over the air while its storage module is already in the binary; adding expo-sqlite or any other native module needs a build. Store the choice on the profile, cache it with `import 'expo-sqlite/localStorage/install'` (synchronous, so no first-render flash; read `globalThis.localStorage`), and treat an OS language change since the last launch as a new choice.

Either way, report the resolved locale and the device zone with the push-token registration so push renders in them; email reads the profile, which the report fills until the user chooses explicitly:

```tsx
// app/_layout.tsx
const locales = useLocales();
const calendars = useCalendars();
useEffect(() => {
  const stored = readStoredLocale(); // yours: the picker's choice; null when following the OS or after an OS language change
  const locale = resolveLocale(stored ? [stored] : locales.map((l) => l.languageTag));
  i18n.changeLanguage(locale);
  if (user) reportDeviceLocale({ locale, timeZone: calendars[0]?.timeZone }); // your API: token row; profile if unset
}, [locales, calendars, user]);
```

## RTL

Layout follows the device by default: React Native allows RTL, so an Arabic or Hebrew device mirrors the app (on iOS only when that language is in `supportedLocales`).
- **No RTL locale shipped:** set the plugin's `"supportsRTL": false`, or Android devices set to Arabic mirror your English UI.
- **Testing:** `"forcesRTL": true` in a development build.
- **Direction** comes from `getLocales()[0].textDirection` or `I18nManager.isRTL`, never a hand-kept language list.
- **Switching between an LTR and an RTL language at runtime** needs a reload; Expo Go resets RTL, so test in a development build. Expo Router's `LocaleProvider direction={…}` flips navigation (headers, gestures) only.

```ts
if (shouldBeRTL !== I18nManager.isRTL) {
  I18nManager.allowRTL(shouldBeRTL);
  I18nManager.forceRTL(shouldBeRTL);
  await Updates.reloadAsync(); // expo-updates
}
```

## Plurals and rich text

```json
// locales/es/common.json: JSON v4 (v3 is removed); suffixes come from Intl.PluralRules; the variable must be `count`
{ "items_one": "{{count}} artículo", "items_many": "{{count}} de artículos", "items_other": "{{count}} artículos" }
```

- **es, fr, it and pt must ship `_many`.** i18next 26 tries `key_many`, then the bare key, then the fallback language, so 1,000,000 renders in English. `i18next-cli status` reports a missing `_many` as optional and passes; a missing ru `_few` fails it.
- **Number words:** for a count of 0, i18next tries `key_zero` first in every language, so "No items yet" goes there; `_one` also covers 21 in ru, so it never says "one".
- **Sharing ICU catalogs with a Next.js app:** use-intl (next-intl's core; augment `AppConfig` on `'use-intl'`) on the same polyfills and resolver gives one API and the `next-i18n.md` gate script: `<IntlProvider locale messages timeZone>` at the root (`timeZone` from `getCalendars()`), `t.rich` chunks inside `<Text>`; `i18next-icu` only where i18next already runs.

```tsx
// "terms": "Agree to our <link>Privacy Policy</link>."
<Trans
  i18nKey="terms"
  parent={Text} // raw strings must render inside <Text>
  components={{ link: <Text style={styles.link} onPress={openPrivacy} /> }}
/>
```

A `TouchableOpacity` as the link throws: it is a View, so its text sits outside `<Text>`.

## Lazy namespaces

Metro needs literal `import()` paths; a template literal fails the build (`InvalidRequireCallError`). Use a static loader map:

```ts
import resourcesToBackend from 'i18next-resources-to-backend';

const loaders: Record<string, Record<string, () => Promise<unknown>>> = {
  de: { common: () => import('@/locales/de/common.json'), settings: () => import('@/locales/de/settings.json') }, // one row per locale
};

i18n.use(resourcesToBackend((lng: string, ns: string) => loaders[lng]?.[ns]?.()));
```

With `resources` in `init`, i18next never calls the backend and lazy keys render raw: set `partialBundledLanguages: true` to bundle `common` and lazy-load the rest, or drop `resources` and `initAsync: false` when every namespace is lazy. The JSON still ships in the binary: lazy loading saves parse time and memory, not download size.

## Types

Type keys against the base: augment i18next's `CustomTypeOptions` with `defaultNS: 'common'` and `resources: (typeof resources)['en']`, in a file inside tsconfig's `include`.

## Native config

```json
{
  "expo": {
    "ios": { "infoPlist": { "CFBundleAllowMixedLocalizations": true } },
    "locales": { "de": "./languages/de.json", "pt-BR": "./languages/pt-BR.json" },
    "plugins": [
      ["expo-localization", {
        "supportedLocales": { "ios": ["en", "de", "pt-BR"], "android": ["en", "de", "pt-BR"] },
        "supportsRTL": false
      }]
    ]
  }
}
```

Two fields, two jobs: `expo.locales` translates app metadata (`{ "ios": { "CFBundleDisplayName": "…", "NSCameraUsageDescription": "…" }, "android": { "app_name": "…" } }`); the plugin's `supportedLocales` enables the OS per-app language setting.

## Gates

`i18next-cli` (it replaces the deprecated `i18next-parser`) covers gates 1 and 4: `status` exits non-zero on a missing or blank key; `lint` flags hardcoded strings and, at `'error'`, concatenation. ICU catalogs (use-intl, `i18next-icu`) use the gate script in `next-i18n.md`.

```ts
// i18next.config.ts
import { defineConfig, recommendedAcceptedAttributes } from 'i18next-cli';

export default defineConfig({
  locales: ['en', 'de', 'pt-BR'],
  extract: { input: ['src/**/*.{ts,tsx}'], output: 'src/locales/{{language}}/{{namespace}}.json' },
  lint: {
    acceptedTags: 'all', // the default list holds HTML tags only and never checks <Text>
    acceptedAttributes: [...recommendedAcceptedAttributes, 'accessibilityLabel', 'accessibilityHint'],
    checkConcatenation: 'error',
  },
});
```

Gates 2–3 need a script for JSON v4, since `status` passes both a missing es `_many` and a renamed `{{count}}`. Per locale and key family (the `_<category>` suffix stripped), the union of `{{name}}` and `<tag>` names equals the base's, and a family with `_other` has `_<category>` for every entry of `new Intl.PluralRules(locale).resolvedOptions().pluralCategories` (`_ordinal_` families: `{ type: 'ordinal' }`). `_zero` is i18next's exact match for 0 in every language, so it is never dead (and required only where 0 is its own category, as in ar); report any other `_<category>` the locale lacks (ja `_one`): it never renders. Prove it red with both defects and green on complete families.

## Pitfalls

| Pitfall | Fix |
|---|---|
| `compatibilityJSON: 'v3'`, `key_plural` or `key_0` keys | i18next 24 removed the old JSON formats and loads only v4: convert with i18next-v4-format-converter (keys with the default `_` separator) as part of the next locale's launch; never pin i18next below 24 to keep them |
| `initImmediate` | Renamed `initAsync` in i18next 24 |
| A plural renders in the fallback language on device | No `Intl.PluralRules` for that language (polyfill or its locale-data missing): since 24, i18next falls back to the dev language |
