#!/bin/bash
# Recompute both answers from the status file with dpkg-query itself and compare.
SANDBOX="$1"
ST="$SANDBOX/prod/var/lib/dpkg/status"
if [ "$(sha256sum "$ST" | cut -d' ' -f1)" != "$(cat "$SANDBOX/.lm/status.sha")" ]; then
  echo "❌ prod/var/lib/dpkg/status was modified: type reset and read it without editing it"
  exit 1
fi
DUMP="$(/usr/bin/dpkg-query --admindir="$SANDBOX/prod/var/lib/dpkg" -W -f='${db:Status-Abbrev}|${Package}|${Installed-Size}|${Section}\n' 2>/dev/null)"
EXP_BROKEN="$(echo "$DUMP" | awk -F'|' '{s=substr($1,2,1); if (s != "i" && s != "n") print $2}' | sort -u)"
EXP_KIB="$(echo "$DUMP" | awk -F'|' 'substr($1,1,2) ~ /^[ih]i$/ && $4 == "libs" {t += $3} END {print t+0}')"

if [ ! -f "$SANDBOX/broken.txt" ]; then
  echo "❌ broken.txt does not exist yet"
  exit 1
fi
GOT="$(tr -s '[:space:]' '\n' < "$SANDBOX/broken.txt" | grep . | sort -u)"
if [ -z "$GOT" ]; then
  echo "❌ broken.txt is empty"
  exit 1
fi
for n in $GOT; do
  if ! echo "$EXP_BROKEN" | grep -qx -- "$n"; then
    if echo "$DUMP" | cut -d'|' -f2 | grep -qx -- "$n"; then
      echo "❌ '$n' is in broken.txt but dpkg says it is fine (installed, or on hold)"
    else
      echo "❌ '$n' in broken.txt is not a package name from the status file (names only, one per line)"
    fi
    exit 1
  fi
done
M=$(comm -23 <(echo "$EXP_BROKEN") <(echo "$GOT") | wc -l)
if [ "$M" -gt 0 ]; then
  echo "❌ broken.txt lists $(echo "$GOT" | wc -l) packages, but $M more are not cleanly installed"
  exit 1
fi
if [ ! -f "$SANDBOX/libs-mib.txt" ]; then
  echo "❌ libs-mib.txt does not exist yet"
  exit 1
fi
V="$(tr -d '[:space:]' < "$SANDBOX/libs-mib.txt")"
if ! [[ "$V" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "❌ libs-mib.txt should hold one number (MiB), not '$V'"
  exit 1
fi
if ! awk -v v="$V" -v k="$EXP_KIB" 'BEGIN {d = v - k/1024; if (d < 0) d = -d; exit !(d <= 1.0)}'; then
  echo "❌ libs-mib.txt says $V MiB; that is not the size of the installed libs packages (Installed-Size is in KiB)"
  exit 1
fi
echo "✅ $(echo "$EXP_BROKEN" | wc -l) stuck packages found, and libs add up to about $V MiB"
