#!/bin/bash
SANDBOX="$1"
OUT="$SANDBOX/interfaces.txt"

if [ ! -f "$OUT" ]; then
  echo "❌ interfaces.txt does not exist yet"
  exit 1
fi

# Normalise: drop CR, trim, squeeze blanks, drop empty lines.
actual="$(tr -d '\r' < "$OUT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g' | sed '/^$/d')"
expected="lo 127.0.0.1
eno1 10.20.4.17
eno1 10.20.4.50
wlp2s0 192.168.1.73
eno1.120 172.16.120.5
docker0 172.17.0.1
wg0 10.66.0.2"

if [ "$actual" = "$expected" ]; then
  echo "✅ interfaces.txt lists every IPv4 address with its interface"
  exit 0
fi

n_act="$(printf '%s\n' "$actual" | sed '/^$/d' | wc -l | tr -d ' ')"
if printf '%s\n' "$actual" | grep -q '/'; then
  echo "❌ interfaces.txt still contains /prefix lengths; write the bare address (10.0.0.1, not 10.0.0.1/24)"
elif printf '%s\n' "$actual" | grep -q ':.*:'; then
  echo "❌ interfaces.txt contains IPv6 addresses; only IPv4 (inet) addresses are wanted"
elif printf '%s\n' "$actual" | grep -q '@'; then
  echo "❌ an interface name still has its @parent suffix; use the name the address is assigned to"
elif [ "$n_act" != "7" ]; then
  echo "❌ interfaces.txt has $n_act lines, but the capture has a different number of IPv4 addresses"
else
  echo "❌ interfaces.txt has the right number of lines, but some INTERFACE ADDRESS pairs are wrong or out of order"
fi
exit 1
