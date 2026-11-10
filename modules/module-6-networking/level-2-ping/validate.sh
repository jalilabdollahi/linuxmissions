#!/bin/bash
SANDBOX="$1"
OUT="$SANDBOX/reachable.txt"
LOG="$SANDBOX/.netsim/ping.log"

if [ ! -f "$OUT" ]; then
  echo "❌ reachable.txt does not exist yet"
  exit 1
fi

actual="$(tr -d '\r' < "$OUT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d' | LC_ALL=C sort -u)"
expected="$(printf '%s\n' web-1 web-2 db-2 cache-1 mon-1 lb-1 | LC_ALL=C sort)"

# Every host in the inventory must actually have been pinged.
for h in web-1 web-2 db-1 db-2 cache-1 backup-1 mon-1 lb-1 old-ftp; do
  if ! grep -qx "$h" "$LOG" 2>/dev/null; then
    echo "❌ not every host in hosts.txt has been pinged with ./ping yet"
    exit 1
  fi
done

if [ "$actual" = "$expected" ]; then
  echo "✅ reachable.txt lists exactly the hosts that answer ping"
  exit 0
fi

extra="$(comm -23 <(printf '%s\n' "$actual") <(printf '%s\n' "$expected") | sed '/^$/d' | wc -l | tr -d ' ')"
missing="$(comm -13 <(printf '%s\n' "$actual") <(printf '%s\n' "$expected") | sed '/^$/d' | wc -l | tr -d ' ')"
if [ "$extra" != "0" ]; then
  echo "❌ reachable.txt lists $extra name(s) that did not answer (or are not host names)"
else
  echo "❌ reachable.txt is missing $missing host(s) that do answer"
fi
exit 1
