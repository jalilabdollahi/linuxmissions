#!/bin/bash
# eol_hosts.txt: "host ID VERSION_ID" for every host at or past EOL, by host.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -d fleet ] || { echo "❌ the fleet capture is gone; type 'reset'"; exit 1; }
[ -f eol_hosts.txt ] || { echo "❌ eol_hosts.txt does not exist yet"; exit 1; }
want=$(cat .lm-state/expected)
got=$(tr -d '\r' < eol_hosts.txt | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | grep -v '^$')
[ -n "$got" ] || { echo "❌ eol_hosts.txt is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ $(echo "$want" | wc -l | tr -d ' ') hosts past end of life reported"; exit 0
fi
if printf '%s\n' "$got" | grep -q '"'; then
  echo "❌ the values must be written without quotes"; exit 1
fi
if printf '%s\n' "$got" | awk 'NF != 3 { bad = 1 } END { exit !bad }'; then
  echo "❌ every line needs exactly three fields: host ID VERSION_ID"; exit 1
fi
extra=$(comm -13 <(echo "$want") <(echo "$got" | sort -u) | head -1)
miss=$(comm -23 <(echo "$want") <(echo "$got" | sort -u) | wc -l | tr -d ' ')
if [ -n "$extra" ]; then
  h=${extra%% *}
  if [ -n "$(grep "^$h " <<< "$want")" ]; then
    echo "❌ '$extra' has a wrong ID or VERSION_ID for that host"
  else
    echo "❌ '$extra' is not past its end-of-life date (compare the date, and the major version, not the full VERSION_ID)"
  fi
elif [ "$miss" -gt 0 ]; then
  echo "❌ $miss end-of-life host(s) missing (hosts whose os-release is a symlink, or has quoted values, are easy to lose)"
else
  echo "❌ the lines are right but not sorted by host (or one is repeated)"
fi
exit 1
