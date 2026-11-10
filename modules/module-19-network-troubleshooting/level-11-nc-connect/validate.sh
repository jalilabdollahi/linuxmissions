#!/bin/bash
SANDBOX="$1"
NET="$SANDBOX/.net"
. "$NET/expected"

for f in open.txt token.txt; do
  if [ ! -f "$SANDBOX/$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
done

got=$(tr -d '\r' < "$SANDBOX/open.txt" | sed 's/[[:space:]]*$//' | grep -o '[0-9]\+$' | sort -n -u | tr '\n' ' ')
want=$(echo $OPEN | tr ' ' '\n' | sort -n | tr '\n' ' ')
if [ "$got" != "$want" ]; then
  for p in $got; do
    if [ "$p" = "$REFUSED" ]; then
      echo "❌ open.txt lists $p, but connections to it are refused"; exit 1
    elif [ "$p" = "$FILTERED" ]; then
      echo "❌ open.txt lists $p, but connections to it never complete (they time out)"; exit 1
    elif ! echo " $OPEN " | grep -q " $p "; then
      echo "❌ open.txt lists $p, which is not a backend port"; exit 1
    fi
  done
  echo "❌ open.txt is missing $(( $(echo $want | wc -w) - $(echo $got | wc -w) )) port(s) that accept connections"
  exit 1
fi

if ! grep -q '^[^ ]* status [0-9.:]* C: STATUS' "$NET/backends.log" 2>/dev/null; then
  echo "❌ nobody has sent STATUS to the status backend yet"
  exit 1
fi
tok=$(tr -d '\r\n ' < "$SANDBOX/token.txt")
tok=${tok#token=}
if [ "$tok" != "$TOKEN" ]; then
  echo "❌ token.txt does not hold the token from the STATUS reply (just the value after token=)"
  exit 1
fi
echo "✅ $(echo $OPEN | wc -w | tr -d ' ') backends accept connections, and the status token is recorded"
