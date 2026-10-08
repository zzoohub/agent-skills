# Upstream sync — operating manual

How to keep this **frozen fork** of [garrytan/gstack](https://github.com/garrytan/gstack) `browse/`
cheap to maintain. Posture (*why* frozen) lives in [`../UPSTREAM.md`](../UPSTREAM.md); this file is
the *how*. Tool: [`vendor-sync.sh`](./vendor-sync.sh).

> **Principle:** minimize local deltas and record each one in the table below the moment you make
> it; each must be re-reconciled on every sync, so prefer "pull from gstack" or "fix in the agent
> layer" over "patch the fork."

## Cadence — pull on a bite, not on a schedule

You do **not** track every gstack release. Re-sync only when:

1. A **daemon/stability fix** you need landed upstream (see the decision matrix below), or
2. A **Playwright / Chromium bump** is due: a security or rendering need, or a bundled Chromium
   over ~3 months old (versions in `../UPSTREAM.md`). Playwright passes `--no-sandbox` unless
   `chromiumSandbox: true`, which `browser-manager.ts` doesn't set, so pages render in that old
   build unsandboxed. Each Playwright release pins its own browsers, so `playwright install
   chromium` alone reinstalls the old one. Instead: `bun update playwright` (a Local Delta) →
   `./setup` → `bun test` + "Verifying a fix" below → record version and date in `../UPSTREAM.md`.

## Procedure

```bash
cd skills/browse/maintenance
./vendor-sync.sh info        # fork point, built version, cache state
./vendor-sync.sh diff        # read-only: our src/ vs current upstream browse src/ (core files)
./vendor-sync.sh diff server.ts   # narrow to one file
./vendor-sync.sh stage       # scrubbed upstream → temp dir for manual review (never touches our src/)
```

`stage` applies the mechanical scrub (`.gstack`→`.browse`, drop parent-CLI bits) and prints a
`diff -ru` command. **Nothing auto-overwrites `src/`** — you cherry-pick by hand, re-apply the Local
Deltas below, then rebuild with `./setup`.

## Local Deltas — re-apply on every re-sync

The only list of intentional divergences from upstream. After a `stage`, confirm each still holds:

| # | Local delta | Type |
|---|---|---|
| 1 | Vendor **only** the `browse/` leaf; drop the parent gstack CLI (`bin/gstack-config`, `bin/gstack-update-check`, root `VERSION`/`config.yaml`/`setup`) | structural |
| 2 | Install path `skills/gstack/browse/` → `skills/browse/` | structural |
| 3 | Per-project state dir `.gstack/` → `.browse/` (scripted in `vendor-sync.sh stage`) | rename |
| 4 | Deleted parent-targeted tests (`test/gstack-config.test.ts`, `test/gstack-update-check.test.ts`) | drop |
| 5 | Removed `getRemoteSlug()` / `bin/remote-slug` (project-registry, no caller here) | drop |
| 6 | Replaced upstream doc-gen (`SKILL.md.tmpl` + `gen:skill-docs`) with a **hand-maintained `SKILL.md`** | divergence — see ⚠️ below |
| 7 | Self-contained `./setup` (upstream build lived in the gstack root `setup`) | add |
| 8 | `commands.ts` header pruned of unvendored refs; `wait [timeoutMs]` documented; `cookie-import-browser` marked "macOS only" | doc touch-up |
| 9 | `flushBuffers` → `fs.appendFileSync` (O(1) append) for console/network/dialog logs — `server.ts` | port-in 2026-06-26 |
| 10 | Per-PID `tmpStatePath` (`${stateFile}.tmp.${pid}.${rand4}`) for the atomic state-file rename — `server.ts` `start()` | port-in 2026-06-26 |
| 11 | `acquireServerLock()` + health-check-first `ensureServer()` + `isServerHealthy()` single-instance lock — `cli.ts`. **Local hardening:** a fresh empty (mid-init) lock file counts as a live holder (wait), not stale, with a 10s age fallback; this closes a concurrent-cold-start race upstream still has (verified: 2 daemons → 1) | port-in + local fix 2026-06-26 |
| _+_ | **Any further local patch — record it here the moment you make it** | (see matrix) |

⚠️ **Delta #6 is our one recurring tax:** `SKILL.md`'s command reference is hand-synced to
`src/commands.ts` and drifts **silently**. A generator must not overwrite its descriptions, which
correct the registry on purpose (Known defects below); a CI check should assert only that every
registry usage string and every `SNAPSHOT_FLAGS` short and long form appears in `SKILL.md`.

## Daemon-fix decision matrix

Candidates surfaced by the hang diagnosis, **resolved against a live upstream diff on 2026-06-26**
(gstack **v1.58.5.0**, HEAD `11de390`; our fork base `4e2dde1`, 2026-03-16 — right *before*
v0.11.1.0 where the lock fix landed). Re-confirm with `./vendor-sync.sh diff <file>` before porting.

> **Dated:** citations refer to `11de390`; upstream `main` moves fast (read its `VERSION` at sync
> time) and has not been re-diffed. In 2026-10 its `server.ts`, `browser-manager.ts` and `cli.ts`
> were ~100 KB each (headed mode, PTY agent, stealth, tunnels) against our ~15 KB: cherry-pick,
> never file-copy.

| Concern (our file:line) | Upstream (gstack v1.58.5.0) | Verdict |
|---|---|---|
| **`MAX_START_WAIT`=8s** `cli.ts:17`; cold launches pass 8s under load (upstream's `cli.ts` comment: ~5.7s at load avg 10, over 8s at 12+) | PARTIAL → CI/Windows only; **default still 8s** (gstack `cli.ts:24`). `main` (2026-10): `resolveStartTimeout()` = **15s** (30s in CI), `BROWSE_START_TIMEOUT` (ms) override; on expiry it re-checks health, kills its half-started daemon, reads an on-disk startup log | **MAYBE, leaning yes** — also fixes Known defect 10; re-diff first |
| **`chromium.launch` no `timeout`** `browser-manager.ts:45` | **NO upstream fix** — gstack also omits it | **LOCAL only if wanted** — add `timeout`, coordinated with `MAX_START_WAIT` |
| **CDP disconnect → `process.exit(1)`** `browser-manager.ts:48` | **No headless re-attach**: exit codes feed a supervisor (`gbd`) we don't run; reconnect is headed-only | **SKIP**: the CLI restarts the daemon on the next command |
| **Idle-shutdown race** `server.ts:149` | **No upstream fix; ours is ahead**: `shutdown()` bounds flush+close with `Promise.race(1500ms)` (`server.ts:278-284`); gstack's can stall exit | **KEEP OURS**: never regress to upstream here |
| `find-browse.ts:15` git `rev-parse` no timeout | sibling `config.ts:33` has `timeout:2000` | **LOCAL** — match the sibling (tiny) |
| `wait --load`/`--domcontentloaded` ignore `[timeoutMs]` `write-commands.ts:134/138` | — | **LOCAL hygiene** — bounded by Playwright's 30s default; low value |

**Remaining pull candidate:** the start-timeout change (`MAX_START_WAIT` row). Already ported: the
O(n²) log rewrite and the single-instance lock (deltas #9–#11).

> **The forever-hang is not in this binary.** Every CLI call is bounded (8s start, 30s per command,
> 2s health check), but daemon work has only Playwright's timeouts (none for `js`/`eval`), so an
> abandoned step, or the rest of a `chain`, keeps running. The only unbounded hang on the verify
> path is the **claude-in-chrome fallback** (blocks on JS dialogs and permission grants), handled
> in the agent layer (`agents/dev/verifier.md` §2b).

## Known defects — candidate local fixes, not applied

Owner decision; each fix becomes a Local Delta. Until then `SKILL.md` documents the real behavior;
fixing 1, 2, 3, 9 and 10 would retire about 200 words of its workarounds (and qa's copies).

1. **Refs** (`snapshot.ts`): names match as case-insensitive substrings (no `exact: true`); an
   unnamed ref's `nth()` counts unnamed elements but its locator matches the whole role; `-d` skips
   nodes without advancing the count; refs survive a tab switch. Playwright 1.59 added `depth`/`mode`
   to `ariaSnapshot` and 1.64 `page.getByRef()` for `'ai'`-mode refs: the likely replacement.
2. **Dialogs** (`browser-manager.ts`, `commands.ts:78-79`): accept-all by default (Playwright
   dismisses), and the registry says "next" dialog where the setting persists.
3. **Errors** (`browser-manager.ts`): no `pageerror` or `requestfailed` listeners; failed requests
   stay `pending`. Playwright 1.56 added `page.pageErrors()` and `page.requests()`.
4. **Cookie picker** (`server.ts:314-317`, `cookie-picker-routes.ts`): `/cookie-picker/*` skips the
   auth token and parses any body as JSON, so any page that learns the port can trigger an import,
   silently once the Keychain key is cached. Security finding: route it to review.
5. **Timeout messages**: the CLI checks `AbortError`, but `AbortSignal.timeout` raises
   `TimeoutError` (`cli.ts:320`). `wrapError` matches `locator.click`, but Playwright names the call
   from stack frames, which lose the class under Bun (`click:`; Node prints `locator.click:`), so the
   hint never fires and a Playwright bump won't fix it: match `/\b(click|fill|hover):/`.
6. **Screenshot target** (`meta-commands.ts:141`): `screenshot h1 <path>` ignores `h1`.
7. **Annotation** (`snapshot.ts`): `-a` boxes shift by the scroll offset; `-C` skips
   `position:fixed` and role-bearing elements.
8. **Popups**: `target=_blank` and `window.open` pages are not tracked as tabs.
9. **Selectors** (`write-commands.ts`, `read-commands.ts`): CSS and text selectors in `click`, `fill`,
   `hover`, `select`, `wait`, `attrs`, `css` and `html` use non-strict `page.*` or `querySelector`
   calls and take the first match; only refs, `is`, `scroll`, `upload` and `screenshot` reject
   several. Fix: `page.locator()`.
10. **Start timeout** (`cli.ts` `startServer`): past 8s a healthy but slow daemon leaves the CLI
    printing only `Starting server...` and exiting 0 without running the command (it waits on empty
    stderr); a rerun spawns a second daemon whose later state-file write wins, silently blanking the
    session. Reproduced 2026-10-08 with a delayed `BROWSE_SERVER_SCRIPT`. `restart` also spawns
    without taking the start lock.

## Verifying a fix actually worked

The Bun suite (`test/*.test.ts`) runs the command handlers against an in-process Chromium, plus
registry, config, snapshot and cookie logic and one CLI test (restart from a dead state file).
Nothing covers the start lock, slow starts, the CLI's 30s timeout or shutdown, so a daemon/hang
patch has no automated proof. Confirm by hand, from the repo root:

```bash
BIN=skills/browse/dist/browse
"$BIN" stop
time "$BIN" goto "file://$PWD/skills/browse/test/fixtures/basic.html"   # cold start: seconds; output, not a bare "Starting server..."
"$BIN" status                                                            # healthy
"$BIN" stop; n=$(pgrep -f src/server.ts | wc -l)
for i in 1 2 3 4; do "$BIN" status >/dev/null & done; wait
echo $(( $(pgrep -f src/server.ts | wc -l) - n ))                        # 1: one daemon under concurrent cold start
"$BIN" stop; ps aux | grep -iE 'chromium|server\.ts' | grep -v grep      # no orphan daemons of ours after `stop`
```
