---
name: qa
description: |
  Tests a running web app and returns a ship or merge verdict with evidence:
  blockers with fixes or stopgaps, reproducible bug reports with screenshots,
  a health score and a regression baseline. Use when asked to "qa" or "QA
  this", "test this site", "smoke test", "dogfood", "find bugs in the app",
  "test it before launch", or to verify a branch in a real browser. For
  one-off browser commands without a report, use browse. Do NOT use for:
  code or diff review (reviewer agent, review-checklists); reproducing
  exploits (adversarial-execution).
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
compatibility: Drives the browse tool (a host-coupled headless browser; resolved via `${BROWSE_BIN}` or a `find-browse` resolver). Degrades gracefully without a file-write or user-prompt tool.
---

# QA: Testing a Running Web App

QA informs a decision: merge this change, ship this release, launch on a date. A run is done when every in-scope critical journey and changed behavior has a result (pass, fail, or not tested and why) backed by saved evidence, and the decider has a verdict with a path to green. Untested is never reported as passed. Budgets size what you write, never what you check. Not for code review, exploits (adversarial-execution capability), E2E suites, load tests or native apps.

Read `references/issue-taxonomy.md` to rate severity and tier, triage console or network noise, and run performance or accessibility checks. Write the reply, report, health score, regression and baseline from `templates/qa-report-template.md`.

## Modes

- **diff-aware**, automatic with no URL and a change set (a feature branch, uncommitted work or the caller's files): each changed behavior, plus the critical journeys and routes using changed code.
- **full**, when a URL is given: every critical journey, then page templates (≤15 unless widened).
- **quick** (`--quick`): the core-job journey to the first blocker: load, sign in, key action, reload and verify, clean console and network (no credentials: landing page, top nav); no checklist.
- **regression** (`--regression <baseline>`, default `.qa/reports/baseline.json`): baseline issues first, then as full.

Critical journeys: money, sign-up and sign-in, the core job; only those a mode covers count toward Not tested and the verdict. URL plus change set: diff-aware if the URL serves this branch (local or the PR's preview), else full; neither: full on the local app.

**Size ceremony to the target, never the checks.** A single behavior ("does the new filter work?") covers its states and the routes using it; a small target (a landing page, one form) gets the whole checklist everywhere. Both skip the Map ranking and get the short reply. Score and baseline are for tracked runs (full, regression, an existing baseline, or on request); a single behavior or small target gets them only on request, whatever the mode.

## Frame

Settle these before the browser. Ask once, in one batch, only what you can't infer and a risky step depends on, each with the default you'll otherwise apply. Unattended, never wait on a human: apply the defaults, list the questions under Questions, make human-only steps blockers; without file-write, the reply is the record (template).

1. **Decision and constraints.** Restate the ask as the decision it serves, and test for that: "QA the signup page before launch" asks whether launch traffic can sign up, on its devices, in time. Record who decides, by when, for which audience (devices, locales, roles; the traffic mix if known) and how a bad ship is undone (a fast, safe undo lowers what a miss costs). Defaults: decision, merge readiness (diff-aware), release readiness (full, regression) or a live critical path (quick); deadline, the next deploy; audience, mobile and desktop alike and every role the change touches; undo, redeploying the previous build. A caller's scope or time box wins, but evidence that the risk sits outside it (the form posts to a service you weren't pointed at; the target isn't what ships) leads the reply, with what testing it would take.
2. **Change set** (diff-aware): the caller's file list, else:
   ```bash
   BASE=${BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo main)}  # caller or CLAUDE.md may set it
   git diff --name-only "$(git merge-base HEAD "$BASE")"   # committed + uncommitted
   git ls-files --others --exclude-standard                # untracked
   git log --oneline "$BASE"..HEAD
   ```
   No merge-base (shallow clone, wrong BASE): ask for the base; unattended, diff the last commit and say so.
3. **Intent, before testing.** From the PR, ticket, commits and known issues, one line per changed behavior, "expected observable → where and how to see it", with any expected value (a total, a date) computed from the spec before you look: the Coverage rows. Mark a line inferred only from the diff `inferred`, its assumption under Questions. Reproduce each bug the branch fixes on the base build first (production, a main-branch preview, or `git worktree add --detach /tmp/qa-base-<YYYYMMDD-HHMM> <base>` served on its own port; never switch the user's working tree), same role and data; one that never reproduces reads `pass (bug never reproduced)`.
4. **Oracle.** Every issue cites one: the spec (feature-spec acceptance criteria, screen-spec states), PR or ticket; the app's behavior elsewhere; a platform convention; or the previous version. Never the code under test: where it disagrees with the spec, the code is the finding. No oracle → Questions, not Issues. *Break for* crashes, error pages, data loss and uncaught exceptions.
5. **Write safety.** Classify the target (local, preview, staging, production) and its data (seeded, real, shared). Production or unknown: reads and sign-in only, unless the caller approves writes (sign-up is one). Elsewhere, reversible writes on data you create are in scope; name it `qa-<YYYYMMDD-HHMM>…` and list it for cleanup. Irreversible or external actions (delete, pay, send, invite, publish, unsubscribe) need test data and test-mode keys, or the caller naming them; else Not tested.

## Setup

Run before any browse command. It is browse's SETUP block verbatim, comment included: change both together.

```bash
# Shared with qa/SKILL.md: keep identical.
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
FIND=""
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/browse/bin/find-browse" ] && FIND="$_ROOT/.claude/skills/browse/bin/find-browse"
[ -z "$FIND" ] && [ -n "$_ROOT" ] && [ -x "$_ROOT/skills/browse/bin/find-browse" ] && FIND="$_ROOT/skills/browse/bin/find-browse"
[ -z "$FIND" ] && [ -x ~/.claude/skills/browse/bin/find-browse ] && FIND=~/.claude/skills/browse/bin/find-browse
B="${BROWSE_BIN:-$([ -n "$FIND" ] && "$FIND" 2>/dev/null)}"
if [ -n "$B" ] && [ -x "$B" ]; then
  echo "READY: $B"
else
  echo "NEEDS_SETUP"
fi
```

- **`READY: <path>`**: use that absolute path as `$B` in every command (shell variables may not survive between calls). A first command failing with `Executable not found in $PATH: "bun"` or `Cannot find server.ts` means NEEDS_SETUP. One daemon serves the repo; a parallel run sets `BROWSE_STATE_FILE=/tmp/qa-<id>/.browse/browse.json` on every call.
- **`NEEDS_SETUP`**: run `./setup` in the browse folder whose `bin/find-browse` the check found, asking first if you can prompt; the first build downloads a browser (hundreds of MB). It needs `bun`, which you never install (nor any toolchain): ask the user to. Then re-check.
- **browse cannot run** (no browse folder, no `bun`, no consent, sandboxed, failed build): stop and return `NEEDS_SETUP: <reason>`; browser fallbacks are the caller's.

**Run folder** (default `.qa/reports/<YYYYMMDD-HHMM>/`; caller may redirect):
```bash
RUN_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.qa/reports/$(date +%Y%m%d-%H%M)"
mkdir -p "$RUN_DIR/screenshots" "$RUN_DIR/evidence" "$RUN_DIR/fixes" && echo "$RUN_DIR"
```
Use the printed absolute path (`<run>` below). browse writes only under literal `/tmp/…` or its daemon's start folder; on `Path must be within`, use `/tmp/qa-<YYYYMMDD-HHMM>/` and say so. Keep earlier runs; flag a `.qa/` that isn't git-ignored (screenshots hold user data).

## Workflow

### Phase 1: Initialize

1. Regression: copy the baseline to `<run>/baseline-before.json`; read it before writing anything.
2. **Find the app** (no URL): the port from the caller, CLAUDE.md or the dev script; else each listener (`lsof -nP -iTCP -sTCP:LISTEN`; Linux `ss -ltnp`; neither: ports 3000 3001 4000 4173 4200 4321 5000 5173 8000 8080 8787 9000) whose title (`curl -s -m 2 http://localhost:<port> | grep -o '<title>[^<]*'`) or a changed route matches: monorepo siblings, Storybook and macOS AirPlay (:5000) answer too. Never probe with `$B goto` (it succeeds on 404s). Nothing local: the PR's preview, else ask (unattended: a blocker).
3. `$B dialog-dismiss`: browse accepts every `confirm()` by default. Run `$B dialog-accept` only right before a confirm you mean to accept, then dismiss again.

### Phase 2: Authenticate (if needed)

Sign in through the UI with credentials from environment variables (`$B fill @e4 "$QA_PASSWORD"`) and confirm the signed-in state. A failed `fill` prints its value: fill secrets only into a `[textbox]` ref from a fresh `snapshot -i`, and keep failed output out of the report.
- **Cookie file**: `$B goto <target>`, `$B cookie-import <file>` (under `/tmp` or browse's start folder), `$B reload`; on `about:blank`, domain-less cookies fail.
- **2FA, CAPTCHA, passkey**: ask for a code or a cookie file; unattended, a blocker (headless browse can't do CAPTCHAs).
- **One cookie jar**: never log out mid-run. Logged-out pages, other roles (after `$B restart`) and session expiry on a long form (fill it, sign out in a second tab, submit: lost input is a finding) come last.
- **Fresh daemon** (after `$B restart`, or any `[browse]` line about starting, restarting or waiting for a server): logged out, accepting dialogs: `$B dialog-dismiss`, sign in again.

### Phase 3: Orient

1. **Prove the build** when the served code may differ from what you judge (diff-aware, a fix or deploy check, a preview). Find one observable marker of the change (copy, route, element, API field). If none is expected (refactor, performance) or it is absent, match the deploy's commit SHA or confirm the dev server runs from this worktree (`lsof -a -d cwd -p $(lsof -t -iTCP:<port> -sTCP:LISTEN | head -1)`). An expected marker absent from a proven build: a flag may hide it (test both states); else the missing change is the first finding. Unproven: diff-aware stops at `INCOMPLETE`. A target judged as served needs only its SHA, if exposed; if it isn't what will ship (another branch, test keys, no email), say which results carry over.
2. **Map.** `$B goto <url>`, then `$B snapshot -i` (it finds client-side routes `$B links` misses). Rank in-scope critical journeys and page templates by impact (money, data, access) × likelihood (churn in `git log --since=30.days --name-only`, integrations, many states, past bugs).

### Phase 4: Explore

**Coverage.** The unit is journey × state, not URL: in-scope critical journeys end to end first, entered by the links real users will click (campaign, email, shared), then one instance per page template plus one with edge data (empty, very long, many items); card fields in iframes are Not tested. Depth follows the Map rank: critical journeys and changed surfaces get the whole checklist; other templates get the primary action, one control per widget type, empty and error states, Visual and Rendered text. Stop when every in-scope critical journey and changed behavior has a result and two templates in a row found nothing new, or at the time box; the rest is Not tested. Zero issues is a valid result.

**Diff-aware test design.** The diff chooses tests; it never proves something works. Map each changed file to what a user observes: routes → paths; components → the routes importing them (repeat `grep -rl` up to a route file; grep the exported name too: barrels and `@/` aliases hide paths); services → flows using them; API handlers → the calling flow plus `$B js "fetch('/api/x').then(async r => r.status+' '+(await r.text()).slice(0,200))"` (no top-level `await`). Each new conditional, boundary, error branch, state or permission check is a test (`qty > 0` → 0, -1, 1.5, 1e6). Use records that predate the change; test a flagged change as production will get it, then flipped. *Break for* global CSS, token or layout changes: one instance per page template at two viewports. Origin: `pre-existing` only once reproduced on the base build; otherwise `changed` (on the changed surface, or plausibly caused by it) or `unverified`.

**Persisted data, both directions** (any run judging a change). When the change writes what another version reads (a column or enum value, a payload, a storage key, a URL, a queued job), the new build must read pre-change records and the base build (Frame item 3) what the new build wrote: what a rollback meets. Carry client state either way: `$B js "localStorage.getItem('<key>')" | tee <run>/evidence/<key>.txt` on the build that wrote it, then `$B storage set <key> "$(cat <run>/evidence/<key>.txt)"` (or `cookie <name>=<value>`) on the other, and reload (`$B storage` escapes values: never paste from it). No base to run: reason it from the diff, under Judgment calls.

**Per-action evidence loop**, around each action under test (`goto` and `click` return before the app settles); setup steps need only the action and a `wait`:
```bash
$B console --clear; $B network --clear; $B dialog --clear
$B js "window.__qaErr=[];if(!window.__qaHook){window.__qaHook=1;addEventListener('error',e=>__qaErr.push(e.message));addEventListener('unhandledrejection',e=>__qaErr.push(String(e.reason)))}0"   # array resets; listeners attach once
$B snapshot -c > <run>/before.txt; grep -niF '<target name>' <run>/before.txt   # the "before", and the target's ref
$B click @e5                      # one action; no other line of its role may contain its name
$B wait "<result selector>"       # or --networkidle 5000 (not with a stream open)
diff <(sed -E 's/@[ec][0-9]+ //' <run>/before.txt) <($B snapshot -c | sed -E 's/@[ec][0-9]+ //') | tee <run>/evidence/NN-<what>.diff   # what changed (renumbered refs ignored), kept as proof
$B js "JSON.stringify(window.__qaErr||[])"       # uncaught errors: browse's console never sees them
$B console --errors               # errors and warnings: triage before counting
$B network | grep -E '→ ([45][0-9]{2}|pending)'  # pending after the wait = failed (streams excepted)
$B dialog                         # a dismissed confirm explains a no-op
```
A page load is an action too: clear, `goto`, `wait`, then read console and network; its uncaught errors precede the hook, unseen. A dead control with a clean console is still a bug: judge by the diff.

**Controls and provenance.** A clean probe counts only once its control has fired on this app, once per run with the hook armed: `$B js "setTimeout(()=>{throw new Error('qa-control')});fetch('/qa-control-404');0"` must put `qa-control` in `__qaErr` and the request in `network`; then `$B reload` (a dev error overlay can swallow later clicks). On production or an unknown target never throw (error trackers alert on it): run only the `fetch`, and list the error hook as unverified under Limits. A pass cites saved output (a diff, a read-back, a screenshot), else its quoted deciding line; a result resting on a non-default capture or tool limit (patched `fetch`, viewport-only mobile, errors before the hook) says so in a clause.

**Per-page checklist**, function first:
1. **Function**: each control does what its label says (state diff, network); irreversible ones only as Frame item 5 allows.
2. **Persistence**: after every write, reach the view that shows it by in-app navigation (stale client cache), then reload. A toast is not evidence. No view shows it (a waitlist, a contact form): read it back where its owner will (admin, API, export, inbox), else it is not verified.
3. **Inputs**: empty, invalid, boundaries, max length, emoji and RTL, double submit.
4. **States**: empty, loading, error, overflow, permission denied. Force an error by patching `fetch` for one path (lasts until the next full load; a request that still succeeds used another transport: Not tested):
   `$B js "window.__qaF=window.__qaF||fetch;window.fetch=(u,o)=>String(u.url||u).includes('/api/orders')?Promise.resolve(new Response('{}',{status:500})):__qaF(u,o);0"`; for a slow state, return `new Promise(r=>setTimeout(r,5000)).then(()=>__qaF(u,o))` instead.
5. **Navigation**: Back and refresh mid-flow, a deep link mid-flow, a stale second tab (`$B newtab <url>`, `$B tab <id>`); in SPAs, click rather than `goto`. Last on the page, check same-origin links, skipping links that act (read the console first: this logs its own 404s; production: only with write approval):
   `$B js "Promise.all([...new Set([location.origin+'/qa-control-404',...[...document.links].filter(a=>a.origin===location.origin&&!a.dataset.method&&!a.dataset.turboMethod&&!/(log|sign)[-_]?out|unsubscribe|delete|remove|revoke|cancel|confirm|verify|accept|invite|impersonat|export|download/i.test(a.pathname+a.search)).map(a=>a.href.split('#')[0])])].slice(0,100).map(u=>fetch(u).then(r=>r.status+' '+u,()=>'ERR '+u))).then(a=>a.filter(s=>/^(404|410|5|ERR)/.test(s)).join('\n')||'none broken')"`; the control's 404 prints first, else unknown paths answer 200 (an SPA): judge links by the not-found view. Then confirm the session with one authenticated `fetch`.
6. **Visual**: a plain `$B screenshot <path>`, opened with the image reader (`snapshot -a` overlays hide real overlaps). `$B viewport 375x812` (and 320 wide, for reflow) only narrows a desktop window: no touch, desktop user agent, hover still matches; restore `$B viewport 1280x720` after. Dark mode only via the app's toggle.
7. **Accessibility**: the taxonomy's keyboard pass, `-C` check and axe scan.
8. **Rendered text**: `$B js "document.body.innerText" | grep -nE 'undefined|NaN|\[object Object\]|Invalid Date|\{\{'` (`$B text` includes hidden elements).
9. **Auth boundary** (pages showing private data, changed endpoints): replay the page's GET data requests from `$B network` with `curl`, with no cookie, then a lower role's session: protected data in the body is critical; a 401, 403, HTML shell or redirect is not. Never replay a write: write authorization, guessed IDs and token replay are exploit work (adversarial-execution capability).

### Phase 5: Document

Before filing, rule out the harness: from a fresh `goto`, re-run on a CSS selector for which `$B is visible` prints `true` (it errors unless unique), up to 5 times (irreversible steps: once). Vary one factor at a time (input, role, viewport, fresh or warm session) until the failing condition is the title's "when". Seen once with evidence = intermittent, never discarded (usually a race); deterministic static defects need no retries. Merge issues sharing a root cause ("also affects …"). A defect predicts its neighbors: try the same component on its other routes and the same input class elsewhere.

**Rate, tier, hand over.** Rate each issue by consequence × exposure for the Frame's audience and tier it for this decision (taxonomy). A small, certain fix (copy, an attribute, a CSS rule, a visible off-by-one) goes over paste-ready: prove a front-end one in the page (inject it with `$B js`, re-run the failing check), then write `<run>/fixes/ISSUE-NNN.patch` from a copy edited under `<run>/fixes/` (`diff -u --label a/<path> --label b/<path> <path> <copy>`; `git apply --check` passes), or without file-write, the change and where. Never edit the target's files; an uncertain cause gets where to look, not a guessed patch.

Write each issue as found (with file-write, into `<run>/report.md`), with the template's typed evidence; screenshots go to `<run>/screenshots/issue-NNN-<step>.png`.

### Phase 6: Wrap up

**Verdict** (a recommendation; the caller decides). Every open issue counts, except diff-aware `pre-existing` ones:
- `FAIL`: an open fix-before issue (taxonomy tiers).
- `INCOMPLETE`: otherwise, an in-scope critical journey or changed behavior is Not tested, or (diff-aware) the build wasn't proven.
- `PASS WITH ISSUES`: any other open issue above low.
- `PASS`: no open issue above low.

**Path to green.** Each fix-before issue gets its fix or, when the deadline can't absorb it, a stopgap (flag off, hide or disable the entry point, revert, a notice) and its cost; `INCOMPLETE` names who must supply what. A merge or release gets **Undo**: how it is rolled back, and any rollback hazard from Phase 4.

**Reply** from the template's Reply block.

**Health score, regression and baseline** (tracked runs): the template's rubric and Regression notes (trend only); with file-write, write `<run>/baseline.json` and promote it as the notes say (default `.qa/reports/baseline.json`; caller may redirect).

## Self-Review

Before returning, check:
1. The verdict follows the rule and names pre-existing criticals and highs; each fix-before issue has a fix or a stopgap fitting the deadline; build proof stated wherever the served code could differ.
2. One Coverage row per in-scope critical journey and changed behavior (pass, fail, or not tested: why), each pass citing saved output; every clean probe's control fired, or the gap is under Limits; no `n/t` category scored.
3. Each issue above low passed the harness check and has an oracle, start state, ≤8 steps, expected, actual, repro rate, typed evidence and a Fix line; root causes merged; every evidence and patch path exists (`ls`).
4. Each severity names its anchor, its exposure for the stated audience and any move's reason; tiers order the Path to green; each `pre-existing` issue and fixed bug was reproduced on the base.
5. Persisted-data changes checked both ways, or the rollback hazard named.
6. No secrets or real users' data in text or screenshots (grep the values used); created `qa-` records listed; a base worktree removed (`git worktree remove --force <dir>`) and its server stopped.
7. Footprint: the reply leads with the verdict, fits its budget yet names every material finding, and links the file, never pastes it; the file fits its budget; no method narration, but provenance wherever a result rests on a non-default capture or tool limit.
