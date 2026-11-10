#!/bin/bash
# inventory.csv must equal the derived inventory: header, one row per port, sorted
# numerically, unit = last cgroup component or the service behind the .socket file.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -s capture/ss.txt ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f inventory.csv ] || { echo "❌ inventory.csv does not exist yet"; exit 1; }
got=$(tr -d '\r' < inventory.csv | sed 's/[[:space:]]*,[[:space:]]*/,/g; s/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
want=$(cat .lm-state/expected)
[ -n "$got" ] || { echo "❌ inventory.csv is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ inventory of $(($(wc -l <<< "$want") - 1)) ports is correct"; exit 0
fi
if [ "$(head -1 <<< "$got")" != "port,proto,unit" ]; then
  echo "❌ the first line must be the header port,proto,unit"; exit 1
fi
body=$(tail -n +2 <<< "$got")
if [ "$(cut -d, -f1 <<< "$body" | sort -u | wc -l)" -ne "$(wc -l <<< "$body")" ]; then
  echo "❌ a port appears more than once: IPv4 and IPv6 listeners of one port make one row"; exit 1
fi
if grep -qE ',(systemd|init\.scope)$|,systemd,' <<< "$body"; then
  echo "❌ a row names systemd (PID 1) as the unit: it only holds that socket for another unit, look at the .socket files"; exit 1
fi
if grep -qE ',user@[0-9]+\.service$' <<< "$body"; then
  echo "❌ user@1000.service is the manager of the user's session; the unit that runs the program is the last part of the cgroup path"; exit 1
fi
if ! grep -qE '^[0-9]+,tcp,[^,]+$' <<< "$body" ; then
  echo "❌ rows must look like port,tcp,unit"; exit 1
fi
if [ "$(cut -d, -f1 <<< "$body")" != "$(cut -d, -f1 <<< "$body" | sort -n)" ]; then
  echo "❌ the rows must be sorted by port number (numerically)"; exit 1
fi
wp=$(tail -n +2 <<< "$want" | cut -d, -f1); gp=$(cut -d, -f1 <<< "$body")
if [ "$wp" != "$gp" ]; then
  n=$(comm -3 <(sort <<< "$wp") <(sort <<< "$gp") | wc -l | tr -d ' ')
  echo "❌ the set of ports is not right ($n port(s) missing or too many: only listening TCP ports of ss.txt count)"; exit 1
fi
bad=$(diff <(tail -n +2 <<< "$want") <<< "$body" | grep '^>' | head -1 | cut -d, -f1 | tr -d '> ')
echo "❌ the unit for port $bad is wrong"
exit 1
