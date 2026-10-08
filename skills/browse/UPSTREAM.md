# Upstream & fork posture

`browse` is a **frozen vendored snapshot** of the `browse/` directory from
[garrytan/gstack](https://github.com/garrytan/gstack/tree/main/browse): it does not track upstream,
and selected fixes are ported by hand as Local Deltas.

- **Upstream:** `https://github.com/garrytan/gstack` → `browse/`
- **Fork point:** added to this repo on **2026-03-16** (commit `4e2dde1`, "add browse skill").
- **Tracking policy:** no git remote, no submodule, no automatic sync — only the manual, read-only
  `maintenance/vendor-sync.sh` diff/stage helper, which never writes to `src/`.
- **Pinned (checked 2026-10-08):** Playwright 1.58.2 per `bun.lock` (published 2026-02-06;
  Chromium 145.0.7632.6). Latest on npm: 1.64.0 (2026-10-07; Chromium 156.0.8078.4). The pin is
  past the ~3-month age trigger, so a bump is due (Cadence #2 in `maintenance/UPSTREAM-SYNC.md`).

## Why it doesn't auto-sync

Upstream `gstack` is a large monorepo; `browse/` is one leaf that depends on a parent CLI (its
`gstack-config` and `gstack-update-check` scripts, a top-level `VERSION` / `config.yaml`, a root
`setup`). This fork vendored **only** `browse/`, renamed its install path from
`skills/gstack/browse/` to `skills/browse/`, and dropped the parent. Because of that structural
divergence, `git merge` / `git subtree pull` are not mechanically possible: any upstream pickup is a
manual, file-by-file cherry-pick against a moving target.

## Local changes

Every intentional divergence from upstream (structural changes, drops, ported fixes) is listed in
one place: the **Local Deltas** table in [`maintenance/UPSTREAM-SYNC.md`](./maintenance/UPSTREAM-SYNC.md).
Record a new local patch there the moment you make it; each one must be re-reconciled on every
future pull.

## If you ever want a specific upstream fix

Stay frozen by default, and pull a fix only when you hit the bug it addresses:

```bash
cd skills/browse/maintenance
./vendor-sync.sh diff        # read-only: our src/ vs current upstream browse src/
./vendor-sync.sh stage       # scrubbed upstream → temp dir for manual cherry-pick (never overwrites src/)
```

[`maintenance/UPSTREAM-SYNC.md`](./maintenance/UPSTREAM-SYNC.md) holds the cadence and Playwright
bump procedure, the daemon-fix decision matrix, the known defects, and the drift note for the
hand-maintained `SKILL.md` (delta #6).
