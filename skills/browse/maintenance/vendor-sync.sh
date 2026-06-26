#!/usr/bin/env bash
# vendor-sync.sh — make re-vendoring `browse/` from upstream gstack a command, not archaeology.
#
# This is a FROZEN vendored fork (see ../UPSTREAM.md). There is no git remote / submodule /
# subtree, by design. When you need an upstream daemon/stability fix, this script fetches the
# current gstack `browse/` leaf, applies the known path-scrub, and shows you the diff against
# our fork so you can cherry-pick by hand. It NEVER overwrites our src/ — staging goes to a
# temp dir for manual review, so your Local Deltas (see UPSTREAM-SYNC.md) are never clobbered.
#
# Usage:
#   ./vendor-sync.sh fetch            # shallow-clone/refresh upstream gstack into the cache
#   ./vendor-sync.sh diff [file]      # diff our src/ vs upstream browse src/ (read-only)
#   ./vendor-sync.sh stage            # copy scrubbed upstream browse/ into a staging dir for review
#   ./vendor-sync.sh info             # show fork point, cache state, upstream commit
#
# Env overrides:
#   GSTACK_URL    upstream repo (default: https://github.com/garrytan/gstack.git)
#   CACHE_DIR     where to clone upstream (default: $TMPDIR/gstack-upstream — never inside the repo)
set -euo pipefail

GSTACK_URL="${GSTACK_URL:-https://github.com/garrytan/gstack.git}"
CACHE_DIR="${CACHE_DIR:-${TMPDIR:-/tmp}/gstack-upstream}"

# Our fork root = the parent of this maintenance/ dir.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORK_ROOT="$(cd "$HERE/.." && pwd)"          # .../skills/browse
OUR_SRC="$FORK_ROOT/src"

# Files we care about reconciling (daemon / stability / resolution core).
CORE_FILES=(server.ts browser-manager.ts cli.ts config.ts find-browse.ts commands.ts)

log()  { printf '\033[1;34m[vendor-sync]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[vendor-sync]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[vendor-sync]\033[0m %s\n' "$*" >&2; exit 1; }

fetch() {
  if [ -d "$CACHE_DIR/.git" ]; then
    log "Refreshing cache: $CACHE_DIR"
    git -C "$CACHE_DIR" fetch --depth 1 origin >/dev/null 2>&1 \
      && git -C "$CACHE_DIR" reset --hard origin/HEAD >/dev/null 2>&1 \
      || warn "fetch/reset failed; using existing cache"
  else
    log "Cloning $GSTACK_URL (shallow) into $CACHE_DIR"
    rm -rf "$CACHE_DIR"
    git clone --depth 1 "$GSTACK_URL" "$CACHE_DIR" 2>&1 | tail -3 >&2 \
      || die "clone failed. Check network, or fetch the raw browse/ files from GitHub by hand."
  fi
}

# Locate the upstream browse-tool root: the dir that actually contains src/server.ts +
# src/browser-manager.ts. Robust to upstream layout changes (browse/, skills/browse/, etc.).
find_upstream_browse() {
  [ -d "$CACHE_DIR" ] || die "no cache. Run: $0 fetch"
  local hit
  hit="$(find "$CACHE_DIR" -type f -path '*/src/browser-manager.ts' 2>/dev/null | head -1 || true)"
  [ -n "$hit" ] || die "could not find src/browser-manager.ts in upstream — layout may have changed. Inspect $CACHE_DIR by hand."
  cd "$(dirname "$(dirname "$hit")")" && pwd   # the dir holding src/
}

cmd_fetch() { fetch; log "Done. Upstream at: $(git -C "$CACHE_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"; }

cmd_info() {
  log "Fork root:      $FORK_ROOT"
  log "Built version:  $(cat "$FORK_ROOT/dist/.version" 2>/dev/null || echo '<not built>')"
  log "Upstream URL:   $GSTACK_URL"
  if [ -d "$CACHE_DIR/.git" ]; then
    log "Cache:          $CACHE_DIR @ $(git -C "$CACHE_DIR" rev-parse --short HEAD 2>/dev/null)"
    local up; up="$(find_upstream_browse)"
    log "Upstream browse src: $up/src"
  else
    log "Cache:          <none> — run: $0 fetch"
  fi
}

cmd_diff() {
  fetch
  local up; up="$(find_upstream_browse)"
  local only="${1:-}"
  local files=("${CORE_FILES[@]}")
  [ -n "$only" ] && files=("$only")
  log "Diffing OUR src/  <  UPSTREAM $up/src/  (only: ${only:-core files})"
  log "Left = ours (fork), Right = upstream. Lines marked > are upstream-only changes to consider."
  local f ours theirs
  for f in "${files[@]}"; do
    ours="$OUR_SRC/$f"; theirs="$up/src/$f"
    if [ ! -f "$theirs" ]; then warn "upstream missing: $f (renamed/moved upstream?)"; continue; fi
    if [ ! -f "$ours" ];  then warn "ours missing: $f"; continue; fi
    if diff -q "$ours" "$theirs" >/dev/null 2>&1; then
      printf '  = %-22s identical\n' "$f" >&2
    else
      printf '\n\033[1;36m──── %s ────\033[0m\n' "$f"
      diff -u "$ours" "$theirs" || true
    fi
  done
}

# Stage scrubbed upstream into a temp dir for manual review/merge — never touches our tree.
cmd_stage() {
  fetch
  local up; up="$(find_upstream_browse)"
  local stage; stage="$(mktemp -d "${TMPDIR:-/tmp}/browse-stage.XXXXXX")"
  log "Staging scrubbed upstream browse/ → $stage"
  cp -R "$up/." "$stage/"
  # --- Apply the known scrub (keep in lock-step with UPSTREAM-SYNC.md "Local deltas") ---
  # 1) rename per-project state dir references .gstack/ → .browse/
  grep -rl '\.gstack' "$stage" 2>/dev/null | while read -r m; do
    sed -i.bak 's/\.gstack/.browse/g' "$m" && rm -f "$m.bak"
  done
  # 2) drop parent-CLI bits never vendored here (best-effort; ignore if absent)
  rm -f  "$stage/bin/remote-slug" 2>/dev/null || true
  rm -f  "$stage/test/gstack-config.test.ts" "$stage/test/gstack-update-check.test.ts" 2>/dev/null || true
  log "Scrub applied (.gstack→.browse, parent-CLI test/registry bits dropped)."
  warn "NOT applied automatically — review and merge by hand:"
  warn "  • Restore our self-contained ./setup if upstream replaced it."
  warn "  • Re-apply every entry in UPSTREAM-SYNC.md 'Local Deltas' that touches a changed file."
  warn "  • Keep our hand-maintained SKILL.md unless re-adopting gen:skill-docs (see the doc)."
  log "Review:  diff -ru '$FORK_ROOT/src' '$stage/src'"
  log "Then cherry-pick by hand into $OUR_SRC and rebuild: (cd '$FORK_ROOT' && ./setup)"
}

case "${1:-}" in
  fetch) cmd_fetch ;;
  diff)  shift; cmd_diff "${1:-}" ;;
  stage) cmd_stage ;;
  info)  cmd_info ;;
  *) awk 'NR>1 && /^#/{sub(/^# ?/,"");print;next} NR>1{exit}' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
