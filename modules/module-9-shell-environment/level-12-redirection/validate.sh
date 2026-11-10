#!/bin/bash
# out.log/err.log: one stream each, from the same real run.
# all.log: both streams of exactly two real runs, in printing order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f nightly.sh ] || [ ! -f .runs ]; then
  echo "❌ nightly.sh or its run register is missing; type reset to start over"
  exit 1
fi

# The lines one run prints, per stream and combined in printing order.
out_of() { printf '[%s] %s\n' "$1" "nightly start" "$1" "backup: 1423 files copied" "$1" "vacuum: 3 tables compacted" "$1" "nightly done"; }
err_of() { printf '[%s] %s\n' "$1" "WARN disk /srv is 81% full" "$1" "ERROR mirror host backup-02 unreachable, will retry" "$1" "WARN 2 stale lock files removed"; }
all_of() { printf '[%s] %s\n' "$1" "nightly start" "$1" "WARN disk /srv is 81% full" "$1" "backup: 1423 files copied" \
             "$1" "ERROR mirror host backup-02 unreachable, will retry" "$1" "vacuum: 3 tables compacted" \
             "$1" "WARN 2 stale lock files removed" "$1" "nightly done"; }
ids_in() { sed -n 's/^\[\([0-9a-f]\{8\}\)\].*/\1/p' "$1" | uniq; }
known() { grep -qxF "$1" .runs; }
pos() { grep -nxF "$1" .runs | head -1 | cut -d: -f1; }

# Part 1: out.log and err.log
for f in out.log err.log; do
  if [ ! -s "$f" ]; then
    echo "❌ $f does not exist yet (or is empty)"
    exit 1
  fi
done
oid="$(ids_in out.log)"
if [ "$(printf '%s\n' "$oid" | grep -c .)" -ne 1 ] || ! known "$oid"; then
  echo "❌ out.log should hold the output of exactly one real run of nightly.sh"
  exit 1
fi
if grep -qE 'WARN|ERROR' out.log; then
  echo "❌ out.log contains warnings/errors: stderr went into it too; send only stdout there"
  exit 1
fi
if [ "$(cat out.log)" != "$(out_of "$oid")" ]; then
  echo "❌ out.log is not exactly the stdout of run $oid"
  exit 1
fi
eid="$(ids_in err.log)"
if grep -qE 'nightly (start|done)|backup:|vacuum:' err.log; then
  echo "❌ err.log contains normal progress lines; send only stderr there"
  exit 1
fi
if [ "$eid" != "$oid" ]; then
  echo "❌ out.log and err.log come from different runs; split ONE run into both files"
  exit 1
fi
if [ "$(cat err.log)" != "$(err_of "$oid")" ]; then
  echo "❌ err.log is not exactly the stderr of run $oid"
  exit 1
fi

# Part 2: all.log
if [ ! -s all.log ]; then
  echo "❌ all.log does not exist yet (or is empty)"
  exit 1
fi
ids="$(ids_in all.log)"
n="$(printf '%s\n' "$ids" | grep -c .)"
for id in $ids; do
  if ! known "$id"; then
    echo "❌ all.log has lines that no real run of nightly.sh produced"
    exit 1
  fi
done
if ! grep -qE 'WARN|ERROR' all.log; then
  echo "❌ all.log has no warnings or errors: stderr still went to the terminal (with 2>&1 >>file the order matters)"
  exit 1
fi
if [ "$n" -lt 2 ]; then
  echo "❌ all.log holds only one run; the second run must be appended, not overwrite the first"
  exit 1
fi
if [ "$n" -gt 2 ]; then
  echo "❌ all.log holds $n runs, expected exactly two (start it over and run nightly.sh twice)"
  exit 1
fi
set -- $ids
if [ "$1" = "$2" ] || [ "$(sort -u <<< "$ids" | wc -l | tr -d ' ')" -ne 2 ]; then
  echo "❌ the runs in all.log are mixed together; run nightly.sh twice, one after the other"
  exit 1
fi
if [ "$(cat all.log)" != "$(all_of "$1"; all_of "$2")" ]; then
  echo "❌ all.log has both runs, but not every line of both streams in the order they were printed"
  exit 1
fi
if [ "$(pos "$1")" -gt "$(pos "$2")" ]; then
  echo "❌ the two runs in all.log are in the wrong order"
  exit 1
fi

echo "✅ out.log and err.log split one run, and all.log holds two complete runs in order"
exit 0
