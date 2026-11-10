#!/bin/bash
# bin/render-motd must print header, sysinfo, "Disk usage (/): NN%" (NN taken
# from df, checked at two different usage values), footer, nothing else. The
# stale 20-maintenance stays, unchanged and not executable; the other original
# scripts are unchanged; 50-disk exists, is executable and starts with #!.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
D=etc/update-motd.d

if [ ! -s .lm-state/sums ] || [ ! -x bin/render-motd ] || [ ! -x bin/df ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
if ! ( cd $D && cksum 00-header 10-sysinfo 20-maintenance 90-footer 2>/dev/null ) | cmp -s - .lm-state/sums; then
  echo "❌ one of 00-header, 10-sysinfo, 20-maintenance or 90-footer is missing or was edited; they should be left as they are"
  exit 1
fi
if [ -x $D/20-maintenance ] || [ -n "$(find $D/20-maintenance -perm /111 2>/dev/null)" ]; then
  echo "❌ 20-maintenance is still executable, so it still runs at login"
  exit 1
fi

if [ ! -e $D/50-disk ]; then
  other=$(ls $D | grep -i 'disk' | head -n 1)
  if [ -n "$other" ]; then
    echo "❌ there is no 50-disk in $D (only $other); the ticket asks for a script with exactly that name"
  else
    echo "❌ no disk-usage script yet: create $D/50-disk"
  fi
  exit 1
fi
if [ -d $D/50-disk ] || [ ! -x $D/50-disk ]; then
  echo "❌ $D/50-disk is not an executable file, so run-parts skips it"
  exit 1
fi
if [ "$(head -c 2 $D/50-disk)" != '#!' ]; then
  echo "❌ 50-disk does not start with a #! line: it would not run as its own program"
  exit 1
fi

orig=$(cat .lm-state/usedpct)
for p in "$orig" 47 91; do
  echo "$p" > .lm-state/usedpct
  got=$(bin/render-motd 2>&1)
  want=$(printf '%s\n' '=== bastion-01 (Ubuntu 24.04.2 LTS) ===' 'Load average: 0.12, 0.08, 0.05 | Users logged in: 3' "Disk usage (/): ${p}%" 'Access is logged. Report problems to #infra-oncall.')
  if [ "$got" != "$want" ]; then
    echo "$orig" > .lm-state/usedpct
    if printf '%s\n' "$got" | grep -q 'failover'; then
      echo "❌ the banner still shows the maintenance notice"
    elif ! printf '%s\n' "$got" | grep -q '^Disk usage'; then
      echo "❌ bin/render-motd prints no 'Disk usage' line: is 50-disk really run? (run-parts only runs executable files whose names have no dots)"
    elif ! printf '%s\n' "$got" | grep -qx "Disk usage (/): ${p}%"; then
      echo "❌ the disk line is '$(printf '%s\n' "$got" | grep '^Disk usage' | head -n 1)' but df reports ${p}% (the number must come from df, not be typed in)"
    else
      echo "❌ the banner has the right lines in the wrong order or with extras: expected header, system info, disk usage, footer"
    fi
    exit 1
  fi
done
echo "$orig" > .lm-state/usedpct
echo "✅ the banner shows header, system info, disk usage (from df) and footer; the stale notice is parked, not deleted"
exit 0
