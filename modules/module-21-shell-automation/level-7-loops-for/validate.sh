#!/bin/bash
# Runs missing_backups.sh in two validator-built backup directories over
# ranges that cross a month end, a year end and Feb 29 of a leap year, plus a
# one-day range, and compares stdout and the exit status exactly. Then checks
# the usage errors (exit 2, stderr only).
SANDBOX="$1"
SCRIPT="$SANDBOX/missing_backups.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ missing_backups.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"
export TZ=UTC

dump() { printf 'dump %s\n' "$2" | gzip -c > "$1/backups/db-$2.sql.gz"; }

A="$WORK/a"; B="$WORK/b"
mkdir -p "$A/backups" "$B/backups"
for d in 2026-10-25 2026-10-26 2026-10-27 2026-10-28 2026-10-30 2026-11-04 2026-11-06 2026-11-07 2026-11-08 2026-11-09; do
  dump "$A" "$d"
done
: > "$A/backups/db-2026-11-03.sql.gz"
printf 'x' > "$A/backups/db-2026-11-02.sql.gz.part"
printf 'x' > "$A/backups/db-2026-11-05.sql"
for d in 2026-12-27 2026-12-28 2026-12-29 2026-12-30 2027-01-02 2027-01-03 2028-02-27 2028-02-28 2028-03-01; do
  dump "$B" "$d"
done
: > "$B/backups/db-2027-01-01.sql.gz"
cp "$SCRIPT" "$A/missing_backups.sh"
cp "$SCRIPT" "$B/missing_backups.sh"

# expect DIR START END EXIT DAY...
expect() {
  dir=$1 start=$2 end=$3 code=$4; shift 4
  (cd "$dir" && $LIMIT bash ./missing_backups.sh "$start" "$end" </dev/null >"$WORK/out" 2>"$WORK/err")
  got=$?
  if [ "$#" -eq 0 ]; then : > "$WORK/want"; else printf '%s\n' "$@" > "$WORK/want"; fi
  if ! cmp -s "$WORK/out" "$WORK/want"; then
    shown=$(tr '\n' ' ' < "$WORK/out" | cut -c1-120)
    echo "❌ ./missing_backups.sh $start $end printed '${shown% }', expected '$*'"
    exit 1
  fi
  if [ "$got" != "$code" ]; then
    echo "❌ ./missing_backups.sh $start $end exited with $got, expected $code"
    exit 1
  fi
}

expect "$A" 2026-10-28 2026-11-03 1 2026-10-29 2026-10-31 2026-11-01 2026-11-02 2026-11-03
expect "$A" 2026-11-06 2026-11-09 0
expect "$A" 2026-10-22 2026-10-26 1 2026-10-22 2026-10-23 2026-10-24
expect "$A" 2026-11-03 2026-11-03 1 2026-11-03
expect "$A" 2026-11-04 2026-11-06 1 2026-11-05
expect "$B" 2026-12-29 2027-01-02 1 2026-12-31 2027-01-01
expect "$B" 2028-02-27 2028-03-01 1 2028-02-29

usage() {  # usage LABEL ARG...
  label=$1; shift
  (cd "$A" && $LIMIT bash ./missing_backups.sh "$@" </dev/null >"$WORK/out" 2>"$WORK/err")
  got=$?
  if [ "$got" != 2 ] || [ -s "$WORK/out" ] || [ ! -s "$WORK/err" ]; then
    echo "❌ ./missing_backups.sh $label must be rejected: message on stderr, nothing on stdout, exit 2 (got exit $got)"
    exit 1
  fi
}
usage "(no arguments)"
usage "2026-11-01 (one argument)" 2026-11-01
usage "2026-11-05 2026-11-01 (END before START)" 2026-11-05 2026-11-01
usage "2026-02-30 2026-03-02 (no such date)" 2026-02-30 2026-03-02

echo "✅ missing_backups.sh finds every missing or empty dump, across month and year ends, and rejects bad ranges"
exit 0
