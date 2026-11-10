#!/bin/bash
SANDBOX="$1"
OUT="$SANDBOX/exposed.txt"

if [ ! -f "$OUT" ]; then
  echo "❌ exposed.txt does not exist yet"
  exit 1
fi

actual="$(tr -d '\r' < "$OUT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d')"
expected="22
80
443
8443
9100"

if [ "$actual" = "$expected" ]; then
  echo "✅ exposed.txt lists the ports web-03 accepts connections on from the network"
  exit 0
fi

if printf '%s\n' "$actual" | grep -qv '^[0-9][0-9]*$'; then
  echo "❌ exposed.txt should contain only port numbers, one per line"
elif [ "$(printf '%s\n' "$actual" | sort | uniq -d)" != "" ]; then
  echo "❌ exposed.txt lists a port more than once (IPv4 and IPv6 sockets on the same port count once)"
elif [ "$(printf '%s\n' "$actual" | sort -n)" != "$actual" ]; then
  echo "❌ the ports in exposed.txt are not sorted from low to high"
else
  for p in 53 5432 6379 631; do
    if printf '%s\n' "$actual" | grep -qx "$p"; then
      echo "❌ exposed.txt includes a port that only listens on a loopback address"
      exit 1
    fi
  done
  for p in 3306 25 35870 44188 48810; do
    if printf '%s\n' "$actual" | grep -qx "$p"; then
      echo "❌ exposed.txt includes a port from a connection that is not in LISTEN state"
      exit 1
    fi
  done
  echo "❌ exposed.txt is missing some listening ports"
fi
exit 1
