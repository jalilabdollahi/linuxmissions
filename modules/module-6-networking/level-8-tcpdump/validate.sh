#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/scanner.txt" ]; then
  echo "❌ scanner.txt does not exist yet"
  exit 1
fi
scanner="$(tr -d '\r' < "$SANDBOX/scanner.txt" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d')"
case "$scanner" in
  203.0.113.66) ;;
  198.51.100.23)
    echo "❌ scanner.txt: 198.51.100.23 sends the most SYN packets, but always to the same port; a scanner tries many different ports"
    exit 1 ;;
  *)
    echo "❌ scanner.txt does not hold the address that probed many different ports"
    exit 1 ;;
esac

if [ ! -f "$SANDBOX/open_ports.txt" ]; then
  echo "❌ open_ports.txt does not exist yet"
  exit 1
fi
ports="$(tr -d '\r' < "$SANDBOX/open_ports.txt" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d')"
expected="22
80
443
8080
9100"
if [ "$ports" = "$expected" ]; then
  echo "✅ scanner found, and you know which ports it saw open"
  exit 0
fi
if printf '%s\n' "$ports" | grep -qv '^[0-9][0-9]*$'; then
  echo "❌ open_ports.txt should hold only port numbers, one per line"
elif [ "$(printf '%s\n' "$ports" | sort -n)" = "$expected" ]; then
  echo "❌ open_ports.txt has the right ports, but not sorted from low to high"
elif printf '%s\n' "$ports" | grep -qx '41922'; then
  echo "❌ 41922 is the scanner's own source port, not a port on web-03"
elif [ "$(printf '%s\n' "$ports" | wc -l | tr -d ' ')" -gt 5 ]; then
  echo "❌ open_ports.txt lists ports that did not answer the scanner with SYN-ACK"
else
  echo "❌ open_ports.txt is missing some ports that answered the scanner with SYN-ACK"
fi
exit 1
