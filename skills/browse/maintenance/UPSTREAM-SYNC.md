# Upstream sync — operating manual

How to keep this **frozen fork** of [garrytan/gstack](https://github.com/garrytan/gstack) `browse/`
cheap to maintain. Posture (*why* frozen) lives in [`../UPSTREAM.md`](../UPSTREAM.md); this file is
the *how*. Tool: [`vendor-sync.sh`](./vendor-sync.sh).

> **Principle:** minimize local deltas, pull fixes from upstream rather than hand-writing them, and
> keep every intentional local change on the checklist below so re-applying after a pull is a
> checklist — not detective work. Every line you patch locally is a line you must re-reconcile on
> every future sync, so prefer "pull from gstack" or "fix in the agent layer" over "patch the fork."

## Cadence — pull on a bite, not on a schedule

You do **not** track every gstack release. Re-sync only when:

1. A **daemon/stability fix** you need landed upstream (see the decision matrix below), or
2. A **Chromium / Playwright security bump** matters (the bundled Chromium rots — security + render
   fidelity; see `../UPSTREAM.md`). A periodic `playwright install chromium` + rebuild covers most
   of this without a full re-vendor.

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

The canonical list of intentional divergences from upstream (consolidated from `../UPSTREAM.md`).
After a `stage`, confirm each still holds:

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
| 9 | **Ported gstack (f):** `flushBuffers` → `fs.appendFileSync` (O(1) append) for console/network/dialog logs — `server.ts` | port-in 2026-06-26 |
| 10 | **Ported gstack (e):** per-PID `tmpStatePath` (`${stateFile}.tmp.${pid}.${rand4}`) for the atomic state-file rename — `server.ts` `start()` | port-in 2026-06-26 |
| 11 | **Ported gstack (e):** `acquireServerLock()` + health-check-first `ensureServer()` + `isServerHealthy()` single-instance lock — `cli.ts`. **Local hardening:** an empty/unparseable (mid-init) lock file is treated as a *live holder → wait*, not stale→unlink, with a 10s age fallback — closes a concurrent-cold-start race the verbatim upstream logic still carries (verified: 2 daemons → 1) | port-in + local fix 2026-06-26 |
| _+_ | **Any further local patch — record it here the moment you make it** | (see matrix) |

⚠️ **Delta #6 is the root of our one real recurring tax:** dropping `gen:skill-docs` means the
`SKILL.md` command tables are hand-synced to `src/commands.ts` and drift **silently**. Strongly
consider re-adopting a minimal generator (or a CI check that asserts the `SKILL.md` tables match the
`commands.ts` registry). See the decision matrix.

## Daemon-fix decision matrix

Candidates surfaced by the hang diagnosis, **resolved against a live upstream diff on 2026-06-26**
(gstack **v1.58.5.0**, HEAD `11de390`; our fork base `4e2dde1`, 2026-03-16 — right *before*
v0.11.1.0 where the lock fix landed). Re-confirm with `./vendor-sync.sh diff <file>` before porting.

> **Scale check:** upstream `server.ts` is 145KB (ours 14KB), `browser-manager.ts` 75KB (ours 15KB),
> `cli.ts` 56KB (ours 12KB) — gstack added headed mode, PTY agent, stealth, tunnels, a security
> sidecar, multi-agent tab ownership. So this is **cherry-pick, never file-copy**; the small
> self-contained daemon fixes port cleanly, anything entangled with those features does not.

| Concern (our file:line) | Upstream (gstack v1.58.5.0) | Verdict |
|---|---|---|
| **O(n²) whole-file log rewrite** every 1s `server.ts:107/118/129` | **FIXED** → `fs.appendFileSync` (gstack `server.ts:591/602/613`) | ✅ **APPLIED 2026-06-26** (delta #9). Safe: we truncate the 3 logs at startup, so append-only won't accrete across restarts |
| **No single-instance lock** `cli.ts:136` → concurrent-spawn zombie daemons | **FIXED** → `acquireServerLock()` atomic `openSync(…,'wx')` + health-check-first `ensureServer` + loser-waits (gstack `cli.ts:379-502`; landed **v0.11.1.0, 2026-03-22 — 6 days after our fork**) | ✅ **APPLIED 2026-06-26** (deltas #10–11) + companion per-PID `tmpStatePath`. **Note:** verbatim upstream had a mid-init empty-lock race (reproduced 2 daemons); our port hardens the read side (empty lock = live holder→wait). Verified 1 daemon under concurrent cold-start ×4 |
| **`MAX_START_WAIT`=8s** vs ~30s launch `cli.ts:17` | PARTIAL → `IS_WINDOWS?15000:(CI?30000:8000)`; **default still 8s** (gstack `cli.ts:24`) | **MAYBE** — trivial CI/Windows one-liner hedge; doesn't fix the normal-cold-start mismatch |
| **`chromium.launch` no `timeout`** `browser-manager.ts:45` | **NO upstream fix** — gstack also omits it (`browser-manager.ts:372-382`) | **LOCAL only if wanted** — our own improvement (add `timeout` + coordinate with `MAX_START_WAIT`); nothing to pull |
| **CDP disconnect → `process.exit(1)`** `browser-manager.ts:48` | **NO re-attach for headless** — upstream is exit-code-aware but only to feed an external Go supervisor (`gbd`) we don't run; reconnect is headed-mode only | **SKIP** — our posture *matches* upstream; the CLI auto-restarts on next command regardless. (Earlier "pull WebSocket re-attach" assumption was wrong — it does not exist for headless.) |
| **Idle-shutdown race** `server.ts:149` | **NO upstream fix** — and **ours is AHEAD**: our `shutdown()` wraps flush+close in `Promise.race(1500ms)` (`server.ts:278-284`); gstack's `await flushBuffers(); await close()` is **unbounded** and can stall exit | **KEEP OURS** — do not regress to upstream here |
| `find-browse.ts:15` git `rev-parse` no timeout | sibling `config.ts:33` has `timeout:2000` | **LOCAL** — match the sibling (tiny) |
| `wait --load`/`--domcontentloaded` ignore `[timeoutMs]` `write-commands.ts:134/138` | — | **LOCAL hygiene** — bounded at Playwright's 30s default; low value, not a hang |

**Pull order (value/effort):** (f) `appendFileSync` → (e) `acquireServerLock` + per-PID `tmpStatePath` → (d) CI/Windows `MAX_START_WAIT` branch. **Skip (a)/(b)/(c).** Each pulled fix becomes a Local Delta — record it in the checklist above the moment you port it.

**Validated by the same diff:** gstack still ships the `bun --compile` binary (`scripts/build.sh:27-28`, identical approach) → our binary path is upstream-current, not a dead end. `gen:skill-docs` **still exists and is CI-gated** upstream (`scripts/gen-skill-docs.ts` + `browse/SKILL.md.tmpl` + `.github/workflows/skill-docs.yml`); re-adoptable for delta #6 but monorepo-shaped (multi-skill, host variants, gstack-brand preamble) — needs trimming, not a drop-in.

> **The actual forever-hang is NOT in this binary.** Every browse path is hard-bounded (8s start /
> 30s command / 15s goto / 2s health) and the live upstream diff confirms gstack's headless daemon
> behaves the same. The only unbounded hang on the verify path is the **claude-in-chrome fallback**
> (permanent block on JS dialogs / permission grants). That fix lives in the **agent layer**
> (`agents/dev/verifier.md` §2b), **not here** — `browse` intentionally knows nothing about
> claude-in-chrome. See that file's "Fallback" section.

## Verifying a fix actually worked

The Bun test suite (`test/*.test.ts`) covers the command **registry / config / snapshot / cookie**
logic — **not** live browser behavior or daemon stability. So a daemon/hang patch has no automated
proof. Confirm by hand:

```bash
BIN=skills/browse/dist/browse
"$BIN" stop
time "$BIN" goto https://example.com          # cold start should be a few seconds, not an 8s failure
ps aux | grep -iE 'chromium|server\.ts' | grep -v grep   # no orphan daemons after `stop`
"$BIN" status                                  # healthy
```
