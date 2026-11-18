# {Product} — UX Design

**Updated:** {date} · **State:** new | as-is recovered {date} | patched · **Size:** small | standard | large · **PRD:** {link} · **Architecture:** {link}

<!-- Rules for the writer; leave them out of the file.
- Budget, counted from `## 1. Frame` to the end with every table included except the route table (one line per screen): small ≈1,000 · standard ≈2,000 · large ≈3,000 · recovered as-is ≈1,200 words. Count it. The budget sizes the record, never the analysis.
- To fit: a cell is a phrase; a flow is one line per step, plus only the unhappy paths that change its structure; state a default once and list where the product departs from it; what one screen needs lives in its spec or its pending entry. Cut restated conventions and whatever the PRD or architecture already says. Never cut a costly-to-fail path, a conflict, a blocker or a material finding: compress it to a line, or run over and say in the report what the overrun kept.
- Keep every numbered section so numbers stay stable across patches (nothing to say: `N/A — reason`). Fields within a section are a menu, except §1's value lines, success criteria and ⚠ marks, §5's accessibility line, and §7's conflict and Blocker rows.
- Link the PRD and architecture by section, never restate them; no law names, rule names or method notes.
- Tag each number a success criterion, target or prediction rests on: (measured: source) · (est.: inputs) · (target: why this bar) · (unknown → measure by {milestone}); floors and platform numbers need no tag. Tag each claim the design rests on: [Observed] [Said] [Assumed].
- Recovered as-is: tag each claim walked (seen in the product) or inferred (from code or docs). -->

## Contents

1. Frame · 2. Objects & glossary · 3. Navigation & routes · 4. Critical flows · 5. Conventions · 6. Decisions · 7. Validation & open questions

**Screens**
- [{Screen}](screens/{screen}.md) [v0.1]
- {Screen} [later] — pending: as {exemplar} except {deviation}

<!-- One entry per screen, with its PRD release (`later` for a feature the PRD lists under Later), and one §3 route row per screen. A pending entry is plain text; screen-design turns it into the link. -->

## 1. Frame

- **Value:** {the progress one role makes in one situation} — value event: {what shows it happened; the first one is first value}
- **Business event:** {what the business earns, when, and how it depends on the value event}
- **Loop:** {what brings them back} → {what they do} → {what they get}; carries over: {…}; cadence: {the job's}
- **Where they pull apart:** {where the business could win while the person loses} — guard: {counter-metric and floor, or a §5 rule}

Archetype and why; roles × top tasks (frequency, cost of failure, ⚠ where failure can hurt someone), people reached only by messages included; a measurable success criterion per top task (target); calibration defaults applied.

| Stage | Arrives with | Asked of them | Got through when (event) | Target | Likeliest loss → the design's answer |
|---|---|---|---|---|---|

<!-- The primary role: arrive, first value, repeat, pay or commit, return after a gap, leave. Another role: only the rows that differ. -->

| A-nn | Assumption | Confidence | Test | If wrong |
|---|---|---|---|---|

## 2. Objects & glossary

| Object | Relationships | States | Roles × actions | Home route |
|---|---|---|---|---|

| Term | Meaning | Never call it |
|---|---|---|

## 3. Navigation & routes

Navigation model and the top tasks it serves; each role's landing (its top tasks, the items awaiting it, their badges); settings scopes; window sizes; every role's routes in the one table, token links for people without an account included; with separate apps, the top tasks first-class in each (a responsive web app keeps every task usable down to 320 CSS px). After a restructure, a Redirects-from column.

| Route | Screen | Object | Access | Deep-link cases |
|---|---|---|---|---|

| PRD feature or architecture obligation | Screens, or "no UI" |
|---|---|

## 4. Critical flows

One per top task, rare costly ones included, plus a first run per arrival path → its first value event, each tagged by release: entry points → steps (who does each: the person, code or a model; the decision at each) → done; the unhappy paths that change the flow; hand-offs to people and to agents (notice, acknowledgement, what the waiting person sees, timeout, escalation, outcome); messages outside the app (channel, trigger, content, landing, if never acted on); exit and resume.

## 5. Conventions

Accessibility, always: the conformance target, floors, text scaling and a reduced-motion variant per motion, as requirements for design-system.

Then, as needed: feedback channels · containers per object (dialog, panel, page) · unavailable actions · destructive ladder · loading, refresh, error and offline per object (as the architecture allows) · forms · notifications · platform deviations · spatial.

With a model in the loop: how people are told it is AI · each autonomy level in use and how it looks · the actions that always ask · the ledger · stop and undo · what it sees and remembers, and where that is changed · fixed copy against generated text.

## 6. Decisions

| Decision | Runner-up | Gives up | Revisit when |
|---|---|---|---|

## 7. Validation & open questions

| Hypothesis (assumption or proposed structure) | Prediction (who does what, from → to, why; wrong if) | Cheapest test | Pass criterion |
|---|---|---|---|

| After ship: signal per top task and journey stage | Baseline | Action threshold | Action |
|---|---|---|---|

| Open question or upstream conflict | Owner · upstream section | Blocks | Default or fallback until answered |
|---|---|---|---|

<!-- Default or fallback until answered: where a wrong guess can hurt someone, the fail-safe one (a human route, narrower autonomy, the manual path), and the row starts with **Blocker**. A conflict row names the upstream choice and proposes the safer answer; its fallback is what the screens use until the upstream doc changes. -->
