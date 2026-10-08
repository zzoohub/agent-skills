# Translation workflow

Read before drafting, ordering or reviewing translations. SKILL.md §5 decides who owns the targets; this is the work in each case.

## TMS-owned targets

- Add the source string with its translator note; a hand edit to a target file is lost at the next sync.
- Gate 6: re-uploading a changed source must mark its translations outdated; confirm the TMS does this for edited strings, not only new keys.

## Git-only targets

- Draft in the same PR and list the drafts for each locale's reviewer (CODEOWNERS on locale files, if set).
- Gate 6: CI fails when a base value changed since the merge base but a target did not, until the target is updated or the key is listed for re-review.

## Drafting

- Read the component behind each key: where it shows, what fills each argument, how much room it has.
- Apply the glossary and do-not-translate list; with none, derive one from how the catalog already renders each product term.
- Fix the register per locale (ko 해요체/합니다체, ja です/ます, de du/Sie) and keep it product-wide.
- Keep arguments and tags; give each plural the categories a count reaches in the target locale (SKILL.md §4, Plurals), not the source's branch set; flag length overruns, never abbreviate.
- Unreviewed machine translation ships only where the project already accepts it, never in payment, legal, consent or safety text.

## Reviewing

Review in context (each locale's screenshots or the running app), not in the catalog: truncation, register drift, glossary terms, locale punctuation (« », „ “, 「」), arguments placed where the grammar breaks, machine-translation literalisms. Each finding is a key plus its fix.

## Translator notes

A source of three words or fewer, or with an argument, gets a note: where it shows, part of speech, max length, what each argument holds. Put it where the project already keeps translator context (the TMS key note, the format's description field, an existing notes file); with none, put it in the hand-off and propose a convention instead of creating one.
