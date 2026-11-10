#!/bin/bash
# Reference solution: one guarded library with the STYLE.txt behaviour, and
# each script finds it through its own resolved path (readlink -f on
# BASH_SOURCE), which works by full path, relative path and via symlinks.
cat > lib/common.sh <<'LIB'
# lib/common.sh - shared helpers for the ops scripts. Source it, don't run it.
[ -n "${_OPS_COMMON_LOADED:-}" ] && return 0
_OPS_COMMON_LOADED=1

log() {
  printf '%s: %s\n' "${0##*/}" "$*" >&2
}

die() {
  printf '%s: error: %s\n' "${0##*/}" "$*" >&2
  exit 1
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: $c"
  done
}
LIB

cat > scripts/rotate_logs.sh <<'SCRIPT'
#!/bin/bash
# rotate_logs.sh DIR - compress every *.log in DIR to NAME.log.1.gz and empty it
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

[ $# -eq 1 ] || die "usage: rotate-logs DIR"
dir=$1
[ -d "$dir" ] || die "no such directory: $dir"
require_cmd gzip
n=0
for f in "$dir"/*.log; do
  [ -e "$f" ] || continue
  gzip -c "$f" > "$f.1.gz"
  : > "$f"
  n=$((n + 1))
done
log "rotated $n file(s) in $dir"
SCRIPT

cat > scripts/check_inbox.sh <<'SCRIPT'
#!/bin/bash
# check_inbox.sh DIR MAX - fail when DIR holds more than MAX files
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

[ $# -eq 2 ] || die "usage: check-inbox DIR MAX"
dir=$1
max=$2
[ -d "$dir" ] || die "no such directory: $dir"
require_cmd find wc
n=$(find "$dir" -maxdepth 1 -type f | wc -l | tr -d ' ')
if [ "$n" -gt "$max" ]; then
  die "$dir has $n files (max $max)"
fi
log "$dir: $n file(s), ok"
SCRIPT

cat > scripts/sync_assets.sh <<'SCRIPT'
#!/bin/bash
# sync_assets.sh SRC DEST - copy the asset tree SRC into DEST
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

[ $# -eq 2 ] || die "usage: sync-assets SRC DEST"
src=$1
dest=$2
[ -d "$src" ] || die "no such directory: $src"
require_cmd rsync find
mkdir -p "$dest"
rsync -a "$src/" "$dest/"
n=$(find "$src" -type f | wc -l | tr -d ' ')
log "synced $n file(s) to $dest"
SCRIPT

cd / && "$OLDPWD/bin/rotate-logs" "$OLDPWD/demo/logs"
