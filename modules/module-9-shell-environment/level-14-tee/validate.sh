#!/bin/bash
# events.raw must be the exact output of one gen-events run (its checksum is in
# .gen/runs), errors.log exactly its level=error lines, error_count.txt their count.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f events.raw ]; then
  echo "❌ events.raw does not exist yet"
  exit 1
fi
if [ ! -s events.raw ]; then
  echo "❌ events.raw is empty"
  exit 1
fi

runs="$(grep -o 'run=[0-9a-f]*' events.raw | sort -u | sed 's/^run=//')"
nruns="$(printf '%s' "$runs" | grep -c .)"
if [ "$nruns" -eq 0 ]; then
  echo "❌ events.raw does not contain gen-events output (no run= field)"
  exit 1
fi
if [ "$nruns" -gt 1 ]; then
  echo "❌ events.raw mixes events of $nruns different runs; save one run only"
  exit 1
fi
logged="$(awk -v r="$runs" '$1 == r { print $2 }' .gen/runs 2>/dev/null | tail -1)"
if [ -z "$logged" ]; then
  echo "❌ run $runs is not a run of gen-events (or .gen/runs was removed; type reset)"
  exit 1
fi
if [ "$(cksum < events.raw | tr ' ' ':')" != "$logged" ]; then
  echo "❌ events.raw is not exactly what run $runs printed (lines missing, added or changed)"
  exit 1
fi

if [ ! -f errors.log ]; then
  echo "❌ errors.log does not exist yet"
  exit 1
fi
other="$(grep -o 'run=[0-9a-f]*' errors.log | sort -u | sed 's/^run=//' | grep -vx "$runs" | head -1)"
if [ -n "$other" ]; then
  echo "❌ errors.log has events of run $other, but events.raw is run $runs; a second run of gen-events sees different traffic"
  exit 1
fi
want="$(grep 'level=error' events.raw)"
got="$(cat errors.log)"
if [ "$got" != "$want" ]; then
  if [ "$got" = "$(grep -i 'error' events.raw)" ]; then
    echo "❌ errors.log also has events whose level is not error (their msg just mentions an error); match the level field"
  else
    echo "❌ errors.log is not exactly the level=error lines of events.raw, in their original order"
  fi
  exit 1
fi

if [ ! -f error_count.txt ]; then
  echo "❌ error_count.txt does not exist yet"
  exit 1
fi
n="$(tr -d '[:space:]' < error_count.txt)"
expect="$(printf '%s\n' "$want" | grep -c .)"
case "$n" in
  ''|*[!0-9]*) echo "❌ error_count.txt should contain just a number"; exit 1 ;;
esac
if [ "$n" -ne "$expect" ]; then
  echo "❌ error_count.txt says $n, but errors.log has a different number of events"
  exit 1
fi

echo "✅ run $runs: $(wc -l < events.raw | tr -d ' ') events saved, $expect of them errors, all from one capture"
exit 0
