#!/bin/bash
# One Library: three ops scripts each carry their own drifted copy of log,
# die and require_cmd. The player moves them into lib/common.sh and makes the
# scripts source it, from any directory and through the bin/ symlinks (where
# $0 is the link, not the script). The library must be safe to source: no
# output, no set options, no exit, and loaded only once.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p scripts bin lib demo/logs demo/inbox demo/assets demo/public

cat > scripts/rotate_logs.sh <<'SCRIPT'
#!/bin/bash
# rotate_logs.sh DIR - compress every *.log in DIR to NAME.log.1.gz and empty it
set -euo pipefail

log() {
  echo "$(date '+%H:%M:%S') rotate: $*"
}
die() {
  echo "rotate: ERROR $*" >&2
  exit 1
}
require_cmd() {
  command -v "$1" >/dev/null || die "need $1"
}

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

log() {
  printf '%s: %s\n' "${0##*/}" "$*" >&2
}
die() {
  printf '%s: error: %s\n' "${0##*/}" "$*" >&2
  exit 2
}
require_cmd() {
  local c
  for c in "$@"; do
    type "$c" >/dev/null 2>&1 || die "missing command: $c"
  done
}

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

log() { echo "[sync] $*" >&2; }
die() { echo "[sync] FATAL: $*" >&2; exit 1; }
require_cmd() {
  for c in "$@"; do
    which "$c" >/dev/null || die "$c not installed"
  done
}

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
chmod +x scripts/*.sh

ln -s ../scripts/rotate_logs.sh bin/rotate-logs
ln -s ../scripts/check_inbox.sh bin/check-inbox
ln -s ../scripts/sync_assets.sh bin/sync-assets

echo "GET /index.html 200" > demo/logs/access.log
echo "worker started" > "demo/logs/queue worker.log"
touch demo/inbox/a.eml demo/inbox/b.eml demo/inbox/c.eml
echo "body { color: #222 }" > demo/assets/site.css
echo "console.log('hi')" > demo/assets/app.js

cat > STYLE.txt <<'TXT'
Ops scripts: shared helpers                         (agreed in the ops sync)

All three scripts must use ONE copy of these helpers, in lib/common.sh:

  log MSG...          stderr:  <prog>: MSG
  die MSG...          stderr:  <prog>: error: MSG     then exit status 1
  require_cmd CMD...  for every CMD that cannot be found:
                      die "missing command: CMD"

<prog> is the name the script was started as (basename of $0), so
bin/rotate-logs logs as "rotate-logs" and scripts/rotate_logs.sh as
"rotate_logs.sh". Nothing goes to stdout.

lib/common.sh is a library, not a program:
  - sourcing it defines functions and prints nothing
  - it does not change shell options (no set -e etc.), cd, or exit
  - sourcing it a second time changes nothing (include guard)
  - it works in scripts that use set -euo pipefail

The scripts are started in three ways: by full path from anywhere, as
scripts/NAME.sh from the repo, and through the symlinks in bin/ (which
admins also link into their own PATH).
TXT
