#!/bin/bash
# Split the Streams: nightly.sh writes to both stdout and stderr and records
# every run id in .runs, so the validator can tell real runs apart.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > nightly.sh <<'EOF'
#!/bin/bash
# nightly.sh - nightly maintenance.
# Progress goes to stdout, warnings and errors go to stderr.
here="$(cd "$(dirname "$0")" && pwd)"
run="$(printf '%04x%04x' $RANDOM $RANDOM)"
echo "$run" >> "$here/.runs"

say()  { echo "[$run] $*"; }
warn() { echo "[$run] $*" >&2; }

say  "nightly start"
warn "WARN disk /srv is 81% full"
say  "backup: 1423 files copied"
warn "ERROR mirror host backup-02 unreachable, will retry"
say  "vacuum: 3 tables compacted"
warn "WARN 2 stale lock files removed"
say  "nightly done"
exit 1
EOF
chmod +x nightly.sh
: > .runs
