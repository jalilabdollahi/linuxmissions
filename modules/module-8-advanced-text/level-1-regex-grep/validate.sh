#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/ips.txt"

if [ ! -f "$FILE" ]; then
  echo "❌ ips.txt not found"
  exit 1
fi

EXPECTED='10.0.0.12
10.0.0.7
10.0.3.250
100.64.0.1
127.0.0.1
172.16.4.20
172.16.4.21
192.168.1.10
192.168.1.200
192.168.10.5
198.51.100.23
203.0.113.77
203.0.113.9
8.8.8.8'

LINES="$(tr -d '\r' < "$FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
n="$(printf '%s\n' "$LINES" | sed '/^$/d' | wc -l | tr -d ' ')"

if printf '%s\n' "$LINES" | grep -Evq '^([0-9]{1,3}\.){3}[0-9]{1,3}$|^$'; then
  echo "❌ every line of ips.txt should be just one IPv4 address, nothing else"
  exit 1
fi
if printf '%s\n' "$LINES" | grep -q '^024\.04\.08\.'; then
  echo "❌ ips.txt contains a piece of a build number (2024.04.08.x), not an IP address"
  exit 1
fi
if [ "$(printf '%s\n' "$LINES" | sort | uniq -d | head -n 1)" != "" ]; then
  echo "❌ ips.txt has duplicates; list each address once"
  exit 1
fi
if [ "$(printf '%s\n' "$LINES" | LC_ALL=C sort)" = "$(printf '%s\n' "$EXPECTED" | LC_ALL=C sort)" ]; then
  echo "✅ ips.txt lists all 14 distinct IPv4 addresses from app.log"
  exit 0
fi
extra="$(printf '%s\n' "$LINES" | LC_ALL=C sort | LC_ALL=C comm -23 - <(printf '%s\n' "$EXPECTED" | LC_ALL=C sort) | head -n 1)"
if [ -n "$extra" ]; then
  echo "❌ ips.txt contains $extra, which is not an address that appears in app.log"
else
  echo "❌ ips.txt has $n distinct addresses, but app.log contains more"
fi
exit 1
