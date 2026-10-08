---
name: i18n
description: |
  Internationalization and localization for web and mobile apps (Next.js, Vite, Expo): locale resolution and routing, language pickers, catalogs and keys, plurals, date/number/currency and time-zone formatting, RTL and CJK, hreflang tag generation, translation workflow, CI gates.
  Use when: "add a language", "translate my app", "localize", "multilingual", hardcoded strings, RTL/Arabic support, a plural bug in one locale, dates off by one day or in the wrong time zone, i18n audit.
  Do NOT use for: writing source copy (screen-design for UI copy, copywriting for brand and promotional copy); hreflang strategy or SEO URL structure (search-visibility).
---

# i18n

i18n is a pipeline: locale resolution → catalog → formatting → script and layout → text sent outside requests → CI gates. The costly failures are structural; translation comes last. Siblings named here are used if available; general React, component APIs and mobile patterns belong to react-best-practices, design-system, react-native-skills.

**Budgets size the record, never the analysis:** run every applicable check (§4's traps on each affected surface and locale) first; a short answer still states each material finding in a line. **Solve the problem behind the request**, even when its cause sits outside the files named, **and change nothing else:** work in the project's conventions, test runner and note locations; unrelated defects and new infrastructure (caches, runners, notes files, extra messages) become proposals.

## 1. Frame the request

**Classify first; the class sets method and deliverable (§6):**
- **Format or API question:** rule + code, naming any decision it hides (whose zone, which currency); skip the rest of §1.
- **Feature in an internationalized app:** its library, keys, catalogs and note conventions; targets by owner (§5).
- **Greenfield:** §2, the platform reference, §5 gates. One locale, none dated within a year: library strings, `lang`/`dir`, logical CSS, explicit-locale formatters, whole sentences; defer translation and gates 3, 5, 6.
- **Retrofit or launch plan:** §3, walking every §4 trap across every surface and locale.
- **Add a locale:** its plural set, script, fonts, direction and expansion (§4), plus the pipeline it joins: library majors, removed formats (§2c), fallback chain (§5).
- **Locale bug:** reproduce in that locale and zone; find every cause (often several) by running the old code on §6's boundary inputs, never by matching the symptom.
- **Audit:** §6 findings across the §5 matrix.

**Establish.** Read the architecture context's Reach line (default `docs/arch/context.md`; caller may redirect), then the code. Ask once, in one batch, only what neither answers; if you cannot ask, apply the bracketed defaults as listed assumptions.

1. Locales and markets now and within a year, with launch dates; any RTL, CJK or Thai? [ask; wire `lang`/`dir` and logical CSS regardless]
2. Surfaces that carry text: web, mobile, email, push/SMS, PDFs and exports, API errors, OG images, store listings, market-specific channels? [every user-facing one, each with its findings]
3. Who translates, in what tool? [the repo's TMS; else agent drafts, native-speaker approval, catalogs in git; a TMS once vendors translate]
4. Where does a user's locale come from? [the §2b precedence]
5. URL strategy for indexable pages? [path prefix; SEO structure is search-visibility's call; never cookie-only]
6. Text beyond UI strings: DB/CMS records, user content, provider-sent email, legal, help? [inventory each; storage and fallback per `references/launch-plan.md`]

**Inspect first:** library majors in the lockfile and the catalog format (`compatibilityJSON`, `_plural` keys); TMS config (`crowdin.yml`, `.phrase.yml`, `.tx/config`), bot commits and CODEOWNERS on locale files; literal JSX text and `aria-label|alt|title|placeholder` values; concatenation around `t(`; `=== 1 ?`; `toLocale*String()` without a locale; `new Date('YYYY-MM-DD')`; `.toUpperCase()` or `.sort()` on display text; physical CSS (`margin-left`, `ml-`), fixed widths, single-line truncation, a global `word-break: keep-all`; Enter-key handlers; `.slice(0, n)`, `maxlength`; fonts in non-browser renderers; per-locale columns (`title_en`); email and push templates.

**Done means:** setup or retrofit: §5 gates in CI, each proven red and green. Add a locale: reachable plural forms complete, launch namespaces 100% reviewed, fallback chain tested, pseudo-locale and RTL screenshots of top flows. Locale bug: a regression test per root cause in the existing runner (none: the before/after run is the evidence; propose the test).

## 2. Decide

### 2a. Catalog format, then library

**One product, one catalog format and one key set**, so web and mobile share translation memory, glossary and review; ICU MessageFormat is the portable default. *Break:* apps that share little copy, or a TMS or native pipeline that dictates the format.

| Platform | Default | Catalog | Read for setup, bugs, audits |
|---|---|---|---|
| Next.js App Router | next-intl | ICU | `references/next-i18n.md` |
| Vite web (SvelteKit, TanStack Start, Astro, React Router) | Paraglide JS | inlang format; ICU or i18next files via plugins | `references/web-i18n.md` |
| Expo / React Native | i18next + react-i18next + expo-localization | i18next JSON v4; ICU via use-intl (next-intl's core) when sharing with Next.js | `references/expo-i18n.md` |

Elsewhere: Pages Router → next-intl's Pages setup; webpack or Rspack SPAs → Paraglide's bundler plugins (`references/web-i18n.md`); other stacks → their standard library plus §2b–§5.

### 2b. Locale resolution

Write the precedence down and test it with a regional tag: **URL locale > profile (signed in) > stored choice > negotiated (`Accept-Language`, device list) > default.** A URL locale wins, so shared links render as sent; the profile decides locale-less URLs and email. One writer per store: two that disagree make the language revert after reload or sign-in.

- **Match each preference in order, one tag per matcher call (e.g. `@formatjs/intl-localematcher`: es-MX → es, zh-HK → zh-Hant); never compare `languageCode`.** One best-fit call over the whole list lets a later exact match win: [es-MX, en-US] gets en although es ships. Format with the tag that matched: en-GB on an `en` bundle shows 8/10, not 10/8.
- **The default and every fallback chain end in a language those users read**, per market (often English, not automatically the source): Korean source text for an unmatched visitor, or Simplified for a Traditional reader, is a regression.
- **Language ≠ region ≠ currency:** currency comes with the price or account, never the UI language; minor units follow its exponent (JPY 0, KWD 3), never `/100`; price per market is pricing's call.
- **Redirect by `Accept-Language` only on locale-less entry URLs, never by geo-IP** (country ≠ language; Googlebot crawls mostly from US IPs without `Accept-Language`). **Don't share-cache a response whose URL lacks the locale** unless the cache keys on the resolved locale (raw `Vary: Accept-Language` fragments it). *Break:* private caches.
- **Text rendered outside a request** (jobs, email, push, PDFs) takes the recipient's stored locale and IANA zone, never the trigger's or the server's; APIs return error codes + params for clients to render. Data read in another locale (exports, admin views, notifications to others) is stored canonical (numbers, ISO 8601, codes), formatted for its reader; names the reader can't read may need a stored reading (furigana, Latin).
- **Picker:** endonyms, each with its own `lang` ("Deutsch", "日本語"), never flags; a pick keeps path and query and is stored.

### 2c. Keys

**Keys are IDs** named by purpose (`auth.login.submit`): a wording change keeps the key and re-queues its translations (gate 6); a new meaning gets a new key. One key per UI instance; share (in `common.*`) only when meaning and UI role match (a dialog's Cancel); split on part of speech, length budget or grammatical slot. *Break:* an existing catalog's convention wins unless upstream removed it (a format the current major no longer loads) or it can't express the new locale (`_plural` pairs for few/many languages): migrate with the launch; never pin an old major to keep it.

## 3. Retrofit and launch plans

Size it first: the no-literal lint in report mode counts strings per feature; source words × locales set cost and turnaround. Then, in order:

1. **Wire the library, a pseudo-locale and a `dir=rtl` toggle before extracting anything**, so unextracted strings stand out.
2. **Extract feature by feature, not file by file**: each PR ships a fully switchable feature; take the first end to end through German and one RTL or CJK locale.
3. **Turn on the no-literal lint (gate 4) per extracted feature**, so it cannot regress while the rest migrates.
4. **Translate only after keys stop churning, no exception:** under a launch date, freeze and hand off one namespace at a time while the next is extracted.

Before writing the plan, read `references/launch-plan.md` (pseudo-locale, surface checks, release paths, lead times, cut lines, template).

## 4. Traps

- **Assembled sentence** [wrong word order, particle or gender]: concatenation, a link splitting a sentence, or a variable noun before a particle (`{name}을(를)`). One message per sentence; links as tags; variables in label position (`삭제됨: {name}`); address users neutrally or `select` on the gender they chose, never a guessed one. *Break:* a closed noun set → `select` with full sentences.
- **Plurals** [wrong form at 0, 1.5, 21 or 1,000,000; a branch that never shows]: exact matches (`=0`, `=1`) are tried before the number's CLDR category (`Intl.PluralRules(l).select(n)`), so a branch for a category the locale lacks (`one` in ja) or that exact matches fully cover (en `one` beside `=1`) never renders: leave it out. Sets: en, de one/other; fr, es, it, pt one/many/other (1,000,000 is many; fr, pt-BR: 0 and 1.5 are one); ru, pl one/few/many/other (ru: 21 is one); ar all six; ja, ko, zh, th other only; else `resolvedOptions().pluralCategories`. `#` in branches; wording that names a number goes in `=0`/`=1`; select on the number as shown (en `1.0` is other); ordinals via `selectordinal`.
- **Time** [a day early west of UTC; server and browser disagree; dates missing from server HTML]: **whose clock** is a stated decision: the viewer's, the recipient's (email, push) or the record's (an event at a venue, a deadline in its owner's zone). Instant → UTC, shown in that zone; future wall-clock event → local datetime + IANA zone; date-only → `YYYY-MM-DD`, never `new Date('2026-10-08')` (Oct 7 in Los Angeles). Server-rendered web formats on the server, deterministically: explicit `timeZone` (the user's stored zone, else a fixed, labeled zone) and a fixed `now`; browser-only formatting is a stated trade-off. Column types: database-design.
- **Intl defaults are product decisions** [year 2569, unexpected digits]: th-TH shows the Buddhist year, fa the Persian calendar, ar-EG Arabic-Indic digits: choose per market (`-u-ca-`, `-u-nu-`); codes, OTPs and inputs stay Latin; week start follows the region (`getWeekInfo()` where supported); on mobile, device settings win (expo reference).
- **Names, addresses, input** [rejected names, failed addresses, wrong digits]: one full-name field, no `[A-Za-z]` checks; E.164 phones; per-country address rules; parse numbers with the locale's separators; normalize per field: NFC for text shown, NFKC for identifiers, codes, numbers and search keys (it folds full-width `１２３` from Japanese IMEs; NFC doesn't); `maxlength` counts UTF-16 units, so cap visible length in graphemes.
- **Formatters** [`TypeError` on device only; a list sorted wrong]: the library's formatter, or `Intl.*` with an explicit locale (one per locale and options, created outside lists and render loops); never `toLocale*String()` without a locale or a formatted value baked into a message; sort with `Intl.Collator` or a per-locale ICU collation in SQL (database-design). Hermes ships only Collator, NumberFormat, DateTimeFormat: polyfill the rest (expo reference).
- **Direction and `lang`** [punctuation at the wrong end in RTL; wrong Han glyphs]: root `lang`/`dir` from the resolved locale, `lang` on foreign-language runs, `dir="auto"` only on user-generated runs; logical CSS (`ps-`, not `pl-`); mirror only icons and motion that imply direction (not clocks or media playback); `<bdi>` or FSI/PDI around names, URLs and numbers in RTL sentences.
- **Scripts and fonts** [tofu □ in a PDF or image; CJK text that won't wrap; clipped Thai marks; the last syllable doubles; Enter submits mid-word]: PDF libraries and server-side image renderers use only the fonts you give them, and canvas and SVG text never wraps: embed fonts per script and break lines at `Intl.Segmenter` word boundaries, or render HTML. Tall scripts (th, vi, hi, ar) need line height, never fixed heights with `overflow: hidden`. Skip Enter while composing (`isComposing || keyCode === 229`); `word-break: keep-all` only under `:lang(ko)` (applied globally, ja and zh stop wrapping); ja `line-break: strict`.
- **Expansion** [clipped or cut-off labels]: no fixed widths or single-line truncation on translated text; buttons and tabs grow or wrap. Budget by source length (W3C, English → European languages): ≤10 chars ×2–3, 11–30 ×1.6–2, longer ×1.3–1.6. Tokens: design-system. *Break:* hard caps (push titles, store listings, SMS): check each locale.
- **Over-extraction** [a translated enum breaks logic]: only text people see or hear (accessible names, toasts, titles, metadata) goes through `t()`; enum values, payloads, analytics events, logs and test IDs never do.

## 5. Fallback, gates, translation

Never crash or show raw keys: fall back along the regional chain (pt-BR → pt), never to another script of the same language (no bare `zh` or `sr` bundle; name the script or region: zh-Hant, zh-TW). Log keys the whole chain lacks (next-intl `onError`, i18next `saveMissing` + `missingKeyHandler`). A raw key is missing from the base or its namespace isn't loaded; fallback-language text on a translated screen is a gap the fallback hid (gate 1). Fallback covers drift between syncs, not launches. *Break:* a locale labeled beta.

**Gates** (CI; prove each red on a seeded defect and green on known-good messages; tools per stack in the references):
1. Key parity with the base: a deleted and a blanked value both fail (TMS-owned targets: at the release cut, not per PR); keys in code are typed against the base.
2. Every message parses in every locale with the source's arguments and tags.
3. Every plural category a count can reach in that locale (ordinals included) has a branch, exact matches counting as coverage; branches nothing reaches are reported.
4. No literal strings in JSX text or attributes (eslint-plugin-i18next `no-literal-string`, `mode: 'jsx-only'`; its default skips attributes).
5. Pseudo-locale and `dir=rtl` screenshots of changed screens (the `qa` skill, on web).
6. A changed base value re-queues its key in every locale, or targets go stale while parity stays green (mechanics: `references/translation.md`).

**Test matrix:** en-XA, ar, de, ja, pl, tr, th, pt-BR, zh-TW; zones America/Los_Angeles, Asia/Kolkata, Pacific/Kiritimati and a DST transition; date tests run under a non-UTC `TZ`.

**Targets.** A TMS owns them when §1 inspection finds one: never edit target files. Git-only: draft every shipped locale, labeled pending native review. Before drafting, ordering or reviewing translations, read `references/translation.md`. Marketing copy is transcreated (copywriting; ads: ad-creative).

## 6. Output and Self-Review

**Deliver** (word budgets exclude code, catalogs and tables; sections are a menu: omit what doesn't apply, heading included). Every deliverable states its **decisions** (choice, alternative, why; scope cuts included) and **other findings** (one line each, file:line), never dropped to fit a budget.
- **Small change or format question:** code + ≤60 words. **Feature:** source entries with notes where the project keeps them (git-only: plus flagged drafts in every shipped locale) + ≤80 words.
- **Locale bug:** code + ≤250 words: per root cause, mechanism (from a run) → fix → the rule that prevents its class; a before/after table from running old and new code on boundary inputs per affected locale and zone (plurals: 0, 1, 2, 5, 21, 1.5, 1,000,000; dates: either side of midnight UTC and a DST change, in §5's zones); regression tests; other places with the same cause, as proposals.
- **Setup, retrofit, launch plan, add a locale:** the template and budget in `references/launch-plan.md`.
- **Audit:** read-only, ≤600 words; findings ranked Critical (wrong language, broken flow, wrong money or dates), High (plurals, formats, direction, untranslated accessible names), Medium (missing gate), Low, each with file:line, failing input and fix.

Propose an ADR via `arch-decision` for costly-to-reverse choices (catalog format, URL strategy, locale source of truth, TMS, content storage). Write for the reader; never narrate this skill's steps.

**Self-Review** (check the items the change touches):
- Changed lines hold no literal user-visible strings (accessible names and toasts included) or assembled sentences; other literals are findings, not edits.
- New messages: in the base, with notes where the project keeps them; git-only: drafted in every shipped locale, parsing, reachable plural categories covered, no branch that never renders; no TMS-owned target edited.
- Every `toLocale*String()` and `Intl.*` call names its locale; whose clock is stated; web dates in the server HTML with explicit `timeZone` (and `now`), or a stated browser-only trade-off; mobile: device or record zone; no date-only string becomes a `Date`; money follows its currency's exponent.
- Precedence tested with [es-MX, en-US] and zh-TW; default and fallback readable by those users; no shared cache without the locale in the URL; email, push and jobs in the recipient's locale and zone.
- Pseudo-locale and RTL pass on touched screens.
- The output carries every element its deliverable lists, each decision with its alternative, and every material finding.
- **Footprint:** prose within its class budget, or over it only for a material finding, reason stated.
