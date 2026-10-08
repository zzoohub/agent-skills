# {Product} — UX Design

**Updated:** {date} · **State:** new | as-is recovered {date} | patched · **Tier:** Lite | Standard | Full · **PRD:** {link} · **Architecture:** {link}

<!-- Rules for the writer; leave them out of the file.
- Budget below this header, tables included: Lite ≈800 · Standard ≈1,500 · Full ≈2,500 · recovered as-is ≈1,000 words, plus one line per row of the Screens group, route table, feature map and §7 tables. The budget sizes the record, never the analysis. Over budget, cut restated conventions and whatever the PRD or architecture already says; never a costly-to-fail path, a conflict, a blocker or a material finding: compress it to a line, move detail to a screen spec, or run over and say why in the report.
- Keep every numbered section so numbers stay stable across patches (nothing to say: `N/A — reason`). Fields within a section are a menu, except §1's success criteria and ⚠ marks, §5's accessibility line, and §7's conflict and Blocker rows.
- Link the PRD and architecture by section, never restate them; no law names, rule names or method notes.
- Recovered as-is: tag each claim walked (seen in the product) or inferred (from code or docs). -->

## Contents

1. Frame · 2. Objects & glossary · 3. Navigation & routes · 4. Critical flows · 5. Conventions · 6. Decisions · 7. Validation & open questions

**Screens**
- [{Screen}](screens/{screen}.md) [v0.1]
- {Screen} [v0.2] — pending: as {exemplar} except {deviation}

<!-- One entry per screen, with its PRD release, and one §3 route row per screen. A pending entry is plain text; screen-design turns it into the link. -->

## 1. Frame

Archetype and why; roles × top tasks (frequency, cost of failure, ⚠ where failure can hurt someone), people reached only by messages included; a measurable success criterion per top task (target); calibration defaults applied.

| A-nn | Assumption | Confidence | Test | If wrong |
|---|---|---|---|---|

## 2. Objects & glossary

| Object | Relationships | States | Roles × actions | Home route |
|---|---|---|---|---|

| Term | Meaning | Never call it |
|---|---|---|

## 3. Navigation & routes

Navigation model and the top tasks it serves; each role's landing (its top tasks, the items awaiting it, their badges); settings scopes; window sizes; with separate apps, the top tasks first-class in each (a responsive web app keeps every task usable down to 320 CSS px). After a restructure, a Redirects-from column.

| Route | Screen | Object | Access | Deep-link cases |
|---|---|---|---|---|

| PRD feature or architecture obligation | Screens, or "no UI" |
|---|---|

## 4. Critical flows

One per top task, rare costly ones included, plus a first run per arrival path → its first-value event, each tagged by release: entry points → steps (the decision at each) → done; the unhappy paths that change the flow; hand-offs between people (notice, acknowledgement, what the waiting person sees, timeout, escalation, outcome); messages outside the app (channel, trigger, content, landing, if never acted on); exit and resume.

## 5. Conventions

Accessibility, always: the conformance target, floors, text scaling and a reduced-motion variant per motion, as requirements for design-system.

Then, as needed: feedback channels · containers per object (dialog, panel, page) · unavailable actions · destructive ladder · loading, refresh, error and offline per object (as the architecture allows) · forms · notifications · platform deviations · AI presentation · spatial.

## 6. Decisions

| Decision | Runner-up | Gives up | Revisit when |
|---|---|---|---|

## 7. Validation & open questions

| Hypothesis (assumption or proposed structure) | Roles × tasks | Method | Pass criterion |
|---|---|---|---|

| After ship: signal per top task | Baseline | Action threshold | Action |
|---|---|---|---|

| Open question or upstream conflict | Owner · upstream section | Blocks | Default or fallback until answered |
|---|---|---|---|

<!-- Default or fallback until answered: where a wrong guess can hurt someone, the fail-safe one (a human route, narrower autonomy, the manual path), and the row starts with **Blocker**. A conflict row names the upstream choice and proposes the safer answer; its fallback is what the screens use until the upstream doc changes. -->
