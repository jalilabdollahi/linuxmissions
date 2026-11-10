#!/bin/bash
SANDBOX="$1"
export LC_ALL=C
NET="$SANDBOX/.net"
OUT="$SANDBOX/fcrdns-fail.txt"

if [ ! -f "$OUT" ]; then
  echo "❌ fcrdns-fail.txt does not exist yet"
  exit 1
fi
while read -r ip; do
  rev=$(echo "$ip" | awk -F. '{print $4"."$3"."$2"."$1}')
  if ! grep -q " $rev\.in-addr\.arpa\. PTR " "$NET/query.log" 2>/dev/null; then
    echo "❌ nobody has asked the DNS server for the PTR record of $ip yet"
    exit 1
  fi
done < "$SANDBOX/senders.txt"

got=$(tr -d '\r' < "$OUT" | awk '{$1=$1} NF' | sort -u)
want=$(sort "$NET/expected")
if [ "$got" = "$want" ]; then
  echo "✅ $(echo "$want" | wc -l | tr -d ' ') senders fail FCrDNS and fcrdns-fail.txt lists exactly them"
  exit 0
fi
bad=$(comm -23 <(echo "$got") <(echo "$want") | head -n 1)
missing=$(comm -13 <(echo "$got") <(echo "$want") | wc -l | tr -d ' ')
if [ -n "$bad" ]; then
  if grep -qx "$bad" "$SANDBOX/senders.txt"; then
    echo "❌ $bad passes FCrDNS: its PTR name has an A record with exactly that address (check all of them, and follow CNAMEs)"
  else
    echo "❌ $bad is not one of the IPs in senders.txt"
  fi
else
  echo "❌ fcrdns-fail.txt is missing $missing sender(s) that would be rejected"
fi
exit 1
