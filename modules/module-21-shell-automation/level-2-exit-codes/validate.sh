#!/bin/bash
# Runs check_queue.sh against stats files the player has not seen (boundaries
# 99/100/499/500, a missing file, a file without deferred=, a non-numeric
# value, a name with a space) and checks the exit status and that stdout is
# exactly the one expected line.
SANDBOX="$1"
SCRIPT="$SANDBOX/check_queue.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ check_queue.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/check_queue.sh"
cd "$WORK" || exit 1
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

snap() {  # snap FILE DEFERRED-LINE
  printf '%s\n' '# mailq snapshot' 'active=3' "$2" 'hold=1' > "$1"
}
snap quiet.stats  'deferred=0'
snap edge99.stats 'deferred=99'
snap edge100.stats 'deferred=100'
snap edge499.stats 'deferred=499'
snap edge500.stats 'deferred=500'
snap "big queue.stats" 'deferred=12040'
snap broken.stats 'deferred=n/a'
printf '%s\n' '# mailq snapshot' 'active=3' 'hold=1' > nodeferred.stats
: > empty.stats

# FILE | expected exit | expected line
CASES=(
  "quiet.stats|0|OK - 0 deferred"
  "edge99.stats|0|OK - 99 deferred"
  "edge100.stats|1|WARNING - 100 deferred"
  "edge499.stats|1|WARNING - 499 deferred"
  "edge500.stats|2|CRITICAL - 500 deferred"
  "big queue.stats|2|CRITICAL - 12040 deferred"
  "gone/mx9.stats|3|UNKNOWN - no queue data in gone/mx9.stats"
  "nodeferred.stats|3|UNKNOWN - no queue data in nodeferred.stats"
  "empty.stats|3|UNKNOWN - no queue data in empty.stats"
  "broken.stats|3|UNKNOWN - no queue data in broken.stats"
)

for c in "${CASES[@]}"; do
  IFS='|' read -r file want_code want_line <<< "$c"
  $LIMIT bash ./check_queue.sh "$file" </dev/null >out 2>/dev/null
  code=$?
  lines=$(wc -l < out | tr -d ' ')
  if [ "$code" != "$want_code" ]; then
    echo "❌ ./check_queue.sh '$file' exited with $code; for ${want_line%% *} monitoring needs exit $want_code"
    exit 1
  fi
  if [ "$lines" != 1 ] || [ "$(cat out)" != "$want_line" ]; then
    echo "❌ ./check_queue.sh '$file' printed $lines line(s) starting '$(head -n 1 out)'; expected exactly one line: $want_line"
    exit 1
  fi
done

echo "✅ check_queue.sh gives monitoring the right line and exit status (0/1/2/3) in all ${#CASES[@]} cases"
exit 0
