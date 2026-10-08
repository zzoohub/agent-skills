# Launch and retrofit plans

Read before writing a setup, retrofit, launch or add-a-locale plan. SKILL.md holds the decisions and traps; this file holds the pseudo-locale, what a plan checks per surface, its release paths and lead times, and the template it is written from.

## Pseudo-locale

The pseudo-locale (`en-XA`) accents every message, pads it by SKILL.md §4's length bands and wraps it in ⟦…⟧: a lost ⟧ is truncation, ⟧⟦ inside one sentence is concatenation, and unaccented text was never extracted. Transform parsed messages (ICU: `@formatjs/icu-messageformat-parser`), never arguments, plural syntax or tags.

## Findings per surface

Walk SKILL.md §4 on every surface the product has, in every planned locale, and write each finding that applies as one line: surface, locale, what breaks, fix.

| Surface | Checks beyond the screens |
|---|---|
| Web | locale in the URL of indexable pages; shared caches keyed by locale; dates in the server HTML with a stated zone; font subsets per script |
| Mobile | OS language list vs in-app picker (release paths below); Hermes polyfills; `supportsRTL`; the device's 24-hour clock and week start; store listing per locale |
| Email, push, SMS | rendered in the recipient's stored locale and zone; subject, preview and title caps per locale; one SMS character outside GSM-7 (any CJK, Cyrillic, Arabic or Thai) cuts a segment from 160 characters to 70; sender IDs or templates that a market requires registered with the provider |
| PDFs, exports, images | fonts embedded per script; line breaking and direction inside the renderer; exports read by machines stay canonical, those read by people are opened in the target locale's spreadsheet app (separators, decimal comma, encoding) |
| API errors | stable codes + params rendered by the client, added beside the existing message until app versions that read it age out; server-built text only in the recipient's locale |
| Content and data | inventory every source (CMS pages, product names, templates, user content, provider-sent email, legal, help); translatable records get a translations table or per-locale rows with a fallback rule, an untranslated state and the source version each translation came from (a source edit marks it stale), per-locale columns only for two or three fixed locales (schema: database-design); user content keeps its language tag, never silently machine-translated; who translates each source, and its publishing per locale |
| Market channels | the channel a market actually uses (a messaging app instead of SMS or email), its sender registration and template review |

## Release paths and lead times

Order phases by the longest lead time and start those first.
- **Web:** ships on deploy.
- **Mobile JS** (catalogs, formatting, an in-app picker): ships over the air while the build already contains every native module it needs; adding one, expo-sqlite included, needs a build.
- **Mobile native config** (the OS per-app language list, `supportsRTL`, localized app name and permission strings): only in a new binary, after store review, reaching users as they update. Never make the language switch users need at launch depend on this path.
- **Translation:** vendor onboarding, a glossary and style guide before the first batch; the vendor's quoted turnaround per batch (source words × locales); per locale, a query round and an in-context review round.
- **Legal and consent text:** sign-off in each language by whoever owns legal review.
- **Fonts:** licensing and subsetting for each new script.
- **Store listings:** translated text and screenshots per locale, through store review.

## String freeze

Freeze one namespace at a time. After handoff, a key or wording change goes only through a logged change that re-queues it in every locale (gate 6). Hand off with screenshots or a build plus translator notes (`references/translation.md`), and extract the next namespace while the frozen one is translated. Batch changes after a freeze: each one costs a round in every locale.

## Cut lines

- **May slip past launch or ship labeled beta:** low-traffic namespaces, help content, marketing pages beyond the entry pages, secondary export formats.
- **Never ship untranslated or unreviewed:** payment, legal, consent and safety text; transactional email, push and SMS; RTL mirroring in an RTL launch; locale-correct money and dates.

## Plan template

Budget: ≤700 words for one surface, +≤200 per further surface, at most 1,500, excluding tables. The budget limits the record, not the analysis: a material finding that doesn't fit becomes a table row, never a cut. Sections are a menu: omit what doesn't apply, heading included; say each thing once.

1. **Decisions:** table of Decision | Choice | Why (over which alternative) | Revisit when (catalog format, library, URL strategy, precedence, default and fallback per market, content storage, TMS, whose clock).
2. **Findings per surface:** one line each.
3. **Phases:** each with scope, owner, start and end dates, size (source words × locales), lead time, release path and checkpoint; string freezes marked.
4. **Gates:** which of SKILL.md §5's six, and when each turns on.
5. **Launch checklist per locale:** gates 1–3 green; launch namespaces 100% reviewed; pseudo-locale and RTL screenshots of top flows reviewed; fonts render in every renderer; calendar, digits and week start chosen; fallback chain tested; store, template and message text translated; legal sign-off; missing-key logging alerts someone.
6. **Cut lines:** what slips, what never does.
7. **Assumptions and open questions.**
