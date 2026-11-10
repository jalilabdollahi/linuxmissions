#!/bin/bash
# fatal-reqs.txt = the req id on the line before each FATAL block, in order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/fatal-reqs ] || [ ! -s .lm-state/log.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -f worker.log ] || [ "$(cksum < worker.log)" != "$(cat .lm-state/log.sum)" ]; then
  echo "❌ worker.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f fatal-reqs.txt ]; then
  echo "❌ fatal-reqs.txt does not exist yet"
  exit 1
fi
GOT=$(tr -d '\r' < fatal-reqs.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')
WANT=$(cat .lm-state/fatal-reqs)
if [ "$GOT" = "$WANT" ]; then
  echo "✅ fatal-reqs.txt has the 15 request ids that crashed the worker, in order"
  exit 0
fi
if [ -z "$GOT" ]; then
  echo "❌ fatal-reqs.txt is empty"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -q -- '^--$'; then
  echo "❌ fatal-reqs.txt contains '--' lines: grep prints those between context groups; keep only the ids"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -q '='; then
  echo "❌ write only the id on each line, e.g. 3fa9c01b, not req=3fa9c01b"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -qv '^[0-9a-f]\{8\}$'; then
  echo "❌ every line must be one request id (8 hex digits); this one is not: $(printf '%s\n' "$GOT" | grep -v '^[0-9a-f]\{8\}$' | head -1)"
  exit 1
fi
while IFS= read -r id; do
  printf '%s\n' "$WANT" | grep -qx "$id" && continue
  if grep -q "parent_req=$id " worker.log; then
    echo "❌ $id is a parent_req=, not the req= of that line"
  else
    echo "❌ $id is not the request on the line before a FATAL"
  fi
  exit 1
done <<< "$GOT"
n=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
if [ "$n" -gt 15 ]; then
  echo "❌ fatal-reqs.txt has $n lines for 15 crashes; is an id listed twice?"
elif [ "$n" -lt 15 ]; then
  echo "❌ fatal-reqs.txt has $n ids, but the worker crashed 15 times"
else
  echo "❌ the right ids, but not in the order of the log"
fi
exit 1
