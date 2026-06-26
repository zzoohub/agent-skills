# Upstream & fork posture

`browse` is a **frozen vendored snapshot** of the `browse/` directory from
[garrytan/gstack](https://github.com/garrytan/gstack/tree/main/browse).

- **Upstream:** `https://github.com/garrytan/gstack` → `browse/`
- **Fork point:** added to this repo on **2026-03-16** (commit `4e2dde1`,
  "add browse skill").
- **Tracking policy:** this snapshot does **not** track upstream. There is no
  git remote, no submodule, and no sync script.

## Why it doesn't auto-sync

Upstream `gstack` is a large monorepo; `browse/` is one leaf that depends on a
parent CLI (`bin/gstack-config`, `bin/gstack-update-check`, a top-level
`VERSION` / `config.yaml`, a root `setup`). This fork vendored **only**
`browse/`, renamed its install path from `skills/gstack/browse/` to
`skills/browse/`, and dropped the parent. Because of that structural
divergence, `git merge` / `git subtree pull` are not mechanically possible —
any upstream pickup is a manual, file-by-file cherry-pick against a moving
target.

## What this fork deliberately dropped or changed vs upstream

- Deleted the gstack-CLI test suites (`test/gstack-config.test.ts`,
  `test/gstack-update-check.test.ts`) — they targeted parent scripts that were
  never vendored here.
- Removed `getRemoteSlug()` / `bin/remote-slug` (gstack project-registry
  machinery with no caller in this fork).
- Renamed the per-project state directory `.gstack/` → `.browse/`.
- Replaced the upstream doc-generation pipeline (`SKILL.md.tmpl` +
  `gen:skill-docs`) with a hand-maintained `SKILL.md` (keep its command tables
  in sync with `src/commands.ts`).
- Added a self-contained `./setup` (the upstream build lived in the gstack
  root `setup`).
- Local doc-string touch-ups (2026-06): pruned the `commands.ts` header's
  references to unvendored files (`gen-skill-docs` / `skill-parser` /
  `skill-check`), documented `wait`'s optional `[timeoutMs]` arg in the
  registry + CLI help, and added "macOS only" to `cookie-import-browser`'s
  registry description. No behavior changes.

> The list above is the canonical **Local Deltas** checklist — the intentional divergences to
> re-confirm on every re-sync. It is mirrored, with sync tooling, in
> [`maintenance/UPSTREAM-SYNC.md`](./maintenance/UPSTREAM-SYNC.md). **Record any new local patch
> there the moment you make it** (each local edit is a line you must re-reconcile on every future
> pull).

## If you ever want a specific upstream fix

Browse-relevant upstream changes land in the gstack CHANGELOG under entries
like daemonization, WebSocket re-attach, idle-shutdown, and long-session memory.
The recommended default is still to **stay frozen** and only pull a fix when you hit the
bug it addresses — but the pull is no longer archaeology. Use the maintenance module:

```bash
cd skills/browse/maintenance
./vendor-sync.sh diff        # read-only: our src/ vs current upstream browse src/
./vendor-sync.sh stage       # scrubbed upstream → temp dir for manual cherry-pick (never overwrites src/)
```

See [`maintenance/UPSTREAM-SYNC.md`](./maintenance/UPSTREAM-SYNC.md) for the cadence, the
daemon-fix decision matrix (which upstream fixes are worth pulling), and the
re-adopt-`gen:skill-docs` note (delta #6 is the source of silent `SKILL.md`↔`commands.ts` drift).
