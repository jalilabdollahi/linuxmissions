#!/bin/bash
SANDBOX="$1"
OUT="$SANDBOX/resolved.txt"
LOG="$SANDBOX/.dns/query.log"

if [ ! -f "$OUT" ]; then
  echo "❌ resolved.txt does not exist yet"
  exit 1
fi

for h in app.internal www.internal api.internal db.internal legacy.internal cache.internal; do
  if ! grep -qx "$h\.\{0,1\}" "$LOG" 2>/dev/null; then
    echo "❌ not every name in hosts.txt has been looked up with ./dig yet"
    exit 1
  fi
done

actual="$(tr -d '\r' < "$OUT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g; s/\. / /' | sed '/^$/d' | LC_ALL=C sort)"
expected="$(printf '%s\n' \
  'app.internal 10.10.0.5' \
  'www.internal 10.10.0.30' \
  'api.internal 10.10.0.41' \
  'api.internal 10.10.0.42' \
  'db.internal 10.10.0.8' \
  'legacy.internal NXDOMAIN' \
  'cache.internal 10.10.0.9' | LC_ALL=C sort)"

if [ "$actual" = "$expected" ]; then
  echo "✅ resolved.txt has every address, CNAMEs followed, and the missing name marked"
  exit 0
fi

if printf '%s\n' "$actual" | grep -q '[a-z]\.internal\.\{0,1\}$'; then
  echo "❌ resolved.txt contains a CNAME target name where an IP address belongs"
elif ! printf '%s\n' "$actual" | grep -qx 'legacy.internal NXDOMAIN'; then
  echo "❌ the name that does not exist should appear as 'NAME NXDOMAIN'"
elif [ "$(printf '%s\n' "$actual" | grep -c '^api.internal ')" != "2" ]; then
  echo "❌ one name has two A records; it needs one line per address"
else
  echo "❌ some lines in resolved.txt are wrong or missing (format: NAME ADDRESS)"
fi
exit 1
