#!/bin/bash
# memory.csv: MemAvailable (MiB, rounded down) and the largest non-app
# consumer for each captured host.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && ls capture/*.meminfo >/dev/null 2>&1 || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f memory.csv ] || { echo "❌ memory.csv does not exist yet"; exit 1; }
want=$(cat .lm-state/expected)
got=$(tr -d '\r' < memory.csv | sed 's/[[:space:]]*,[[:space:]]*/,/g; s/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
if [ "$got" = "$want" ]; then
  echo "✅ memory.csv matches all four servers"; exit 0
fi
if [ "$(head -1 <<< "$got")" != "host,available_mib,consumer" ]; then
  echo "❌ the first line must be the header host,available_mib,consumer"; exit 1
fi
if [ "$(tail -n +2 <<< "$got" | wc -l | tr -d ' ')" -ne 4 ]; then
  echo "❌ memory.csv needs exactly 4 data rows, one per host"; exit 1
fi
while IFS=, read -r h a c; do
  w=$(grep "^$h," <<< "$want")
  [ -n "$w" ] || { echo "❌ '$h' is not one of the captured hosts"; exit 1; }
  IFS=, read -r _ wa wc <<< "$w"
  if [ "$a" != "$wa" ]; then
    f=$(awk '/^MemFree:/ { printf "%d", $2 / 1024 }' "capture/$h.meminfo")
    if [ "$a" = "$f" ]; then
      echo "❌ $h: that is MemFree, not MemAvailable (cache the kernel can give back is not 'used')"
    elif ! [[ $a =~ ^[0-9]+$ ]]; then
      echo "❌ $h: available_mib must be a whole number"
    else
      echo "❌ $h: available_mib is wrong (MemAvailable is in kB: divide by 1024 and round down)"
    fi
    exit 1
  fi
  if [ "$c" != "$wc" ]; then
    case $c in
      HugePages|Shmem|SUnreclaim) echo "❌ $h: $c is not the largest of the three (HugePages is Total x Hugepagesize, in kB)";;
      *) echo "❌ $h: consumer must be HugePages, Shmem or SUnreclaim";;
    esac
    exit 1
  fi
done < <(tail -n +2 <<< "$got")
echo "❌ the values are right but the rows are not sorted by host"
exit 1
