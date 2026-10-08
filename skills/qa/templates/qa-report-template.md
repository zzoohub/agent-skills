<!-- Two outputs. The REPLY is for the person deciding: always written, verdict first, never a paste of
     the file. The FILE (<run>/report.md, with file-write) is the record for the engineer who fixes it.
     Budgets cap words, never findings: every material finding keeps at least one line (group by root
     cause, move detail to the file, or run over and say why). Sections are a menu: omit what doesn't
     apply, heading included. -->

## Reply (to the asker; not part of the file)

<!-- ≤120 words for one behavior or a quick check, ≤250 for a small target or a merge, ≤350 for a release. -->

**{FAIL, INCOMPLETE, PASS WITH ISSUES or PASS}: {the decision in plain words, e.g. "don't launch yet"}.** {The worst open issue, or what couldn't be verified, with who it hits.}

**Fix before {decision}:**
- {ISSUE-NNN}: {what breaks, for whom, how many} → {the fix (`fixes/ISSUE-NNN.patch`, or the change and where), or a stopgap that fits {deadline} and its cost} <!-- one to three lines each -->

**Judgment calls:** {ISSUE-NNN}: {option} ({cost}) or {option} ({cost}).
**Fix soon:** {ISSUE-NNN} {title} · …
**Escalate** (pre-existing): {ISSUE-NNN} {title} · …
**Not verified, and it matters:** {gap}: {why}; {who or what can close it}.
**Undo:** {how this is rolled back}; {rollback hazard, or none found}. <!-- merges and releases -->
**Record:** {report path} · created {`qa-…` records to clean up, or none}

<!-- No file-write: the reply is the record. After it, each issue above low as title, severity and tier,
     start state, steps, expected vs actual, evidence path (≤60 words each); lows one line each; then one
     line per Coverage row (result and its evidence) and the Not tested list; no score or baseline. -->

<!-- FILE budget: verdict block ≤150 words; each issue ≤120 (a low: one line); all other sections together
     ≤250 words for quick, one behavior or a small target, ≤500 diff-aware, ≤900 full or regression. -->

# QA Report: {APP} · {MODE} · {YYYY-MM-DD HH:MM}

## Verdict: {FAIL, INCOMPLETE, PASS WITH ISSUES or PASS}

{One or two sentences: the worst open issue or what couldn't be verified, and why; name any pre-existing critical or high.}

**Path to green** (tier order): {ISSUE-NNN}: {fix or stopgap} · … · **Judgment calls:** {ISSUE-NNN}: {the trade-off}

**Undo:** {how this is rolled back}; {rollback hazard, or none found} <!-- merges and releases -->

- **Scope:** {the mode's coverage, or the caller's scope or time box} · {URL}, {local, preview, staging or production}, data {seeded, real or shared} · {role, or anonymous} · created {`qa-…` records, or none}
- **Build:** {SHA}, proven by {change marker, SHA match or worktree check} <!-- only where the served code may differ from what ships -->
- **Limits:** {only those a result or a Not tested row rests on: viewport-only mobile, a patched fetch, errors before the hook}
- **Open issues:** critical {n} · high {n} · medium {n} · low {n} ({n} pre-existing) · **Health score:** {N}/100, trend only <!-- tracked runs -->

<!-- Health score: the weighted mean of assessed categories (functional 20, ux 15, accessibility 15, console 15,
     visual 10, performance 10, links 10, content 5); unassessed ones are n/t, outside the mean and categoryScores.
     A category scores 100 − 25 per critical, 15 per high, 8 per medium, 3 per low (floor 0); console instead
     counts distinct signals left by the noise rule (0 → 100, 1–3 → 70, 4–9 → 40, 10+ → 10); links lose 15 per
     broken same-origin link, never also under functional. Cap at 49 while a critical is open, 79 while a high is. -->

## Coverage

| Changed behavior or critical journey | How verified | Result | Evidence |
|---|---|---|---|
| {intent line or journey} → {where} | {steps or probe} | pass, fail (ISSUE-NNN) or not tested: {why} | {saved output or screenshot path} |

## Issues

### ISSUE-001: {flow or page}: {failure} when {condition}

**Severity:** {level}: {anchor}; exposure {who, what share, how often}{; why it moved from the anchor} · **Tier:** {fix before {decision}, fix soon or judgment call} · **Category:** {taxonomy category} · **Repro rate:** {n/5}, {conditions}

**Oracle:** {spec, PR, ticket, app elsewhere, convention or previous version} · **Route:** {URL}, key `{category|route template|signature}` · **Origin** (diff-aware): {changed ({file}), pre-existing (reproduced on {base}) or unverified}

**Start state:** {account, data, viewport}

**Steps** (≤8): 1. {action} …

**Expected:** {per the oracle, worked out before observing} · **Actual:** {observed}

**Evidence:** {visual: a screenshot you opened, ![Result](screenshots/issue-001-result.png); interaction: ≤5 changed diff lines and a result screenshot; console: exact text and trigger; network: method, path, status, body excerpt; race: a timestamped sequence of diffs and reads}

**Fix:** {`fixes/ISSUE-001.patch` (proven in the page, not applied), the change and where, a stopgap, or where to look}

## Not tested

- {journey, state, role or category}: {why}; {what it would take, or the contract a mocked dependency must honor}

## Questions

- {question} (assumed: {default})

## Console & network

- {message, or METHOD path → status} ×{N}, first after {action}

## Regression

<!-- Match issues by `key` = `category|route template|element-or-error signature` (e.g. `functional|/orders/:id|button
     "Cancel order" no-op`), keyless baseline issues by category and title; sort every baseline issue into an
     outcome below (absence is not a fix); compare accessibility only on the same axeVersion. -->

**Health score** {N} → {N} ({±N}, categories assessed in both) · **Open issues** {N} → {N}

**Fixed** (re-checked and passing; intermittent: 5/5): {keys} · **Still open:** {keys} · **Not re-checked:** {keys} · **New:** {keys} · **First seen** (outside the baseline's coverage): {keys}

<!-- <run>/baseline.json. After a full or regression run, promote it to the reports root (default
     .qa/reports/baseline.json; caller may redirect), or to baseline-<host>.json there when the existing
     baseline's url has another origin. Carry forward each prior issue this run neither reported nor
     re-checked, adding "rechecked": false.
{ "date": "YYYY-MM-DD", "url": "<target>", "commit": "<sha or unproven>", "healthScore": 0, "axeVersion": "<axe.version>",
  "coverage": ["<journey or route template>"],
  "issues": [{ "id": "ISSUE-001", "key": "<key>", "title": "...", "severity": "...", "category": "..." }],
  "categoryScores": { "functional": 0, "console": 0 } }
-->
