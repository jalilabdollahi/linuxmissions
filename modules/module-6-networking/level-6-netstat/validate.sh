#!/bin/bash
SANDBOX="$1"
OUT="$SANDBOX/top_talker.txt"

if [ ! -f "$OUT" ]; then
  echo "❌ top_talker.txt does not exist yet"
  exit 1
fi

line="$(tr -d '\r' < "$OUT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g' | sed '/^$/d')"

if [ "$line" = "203.0.113.77 37" ]; then
  echo "✅ top_talker.txt names the client with the most open HTTPS connections"
  exit 0
fi

if [ "$(printf '%s\n' "$line" | wc -l | tr -d ' ')" != "1" ]; then
  echo "❌ top_talker.txt should hold exactly one line: IP COUNT"
elif [ "$line" = "37 203.0.113.77" ]; then
  echo "❌ right answer, wrong order: write the IP first, then the count"
else
  case "$line" in
    198.51.100.23*) echo "❌ that client has many connections, but are they all ESTABLISHED?" ;;
    10.20.4.30*)    echo "❌ those connections are not to port 443 on this server; look at which side has port 443" ;;
    203.0.113.77*)  echo "❌ right client, wrong count: count only its ESTAB connections to local port 443" ;;
    *)              echo "❌ that is not the client with the most ESTABLISHED connections to port 443" ;;
  esac
fi
exit 1
