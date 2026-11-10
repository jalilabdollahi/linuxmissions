#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/want ] || [ ! -s diskstats.2 ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
. .lm-state/want
if [ ! -s busiest.txt ]; then echo "❌ busiest.txt is missing or empty"; exit 1; fi
read -r dev rate extra < busiest.txt
rate=${rate%%[!0-9.]*}
if [ -z "$dev" ] || [ -z "$rate" ]; then echo "❌ busiest.txt must look like: DEVICE KIB_PER_S"; exit 1; fi
if [ "$dev" != "$DEV" ]; then
  case "$dev" in
    loop*) echo "❌ $dev is a loop device (a file mounted as a disk), not a physical disk; look at the whole disks only"; exit 1;;
  esac
  case "$dev" in
    sd[a-z][0-9]*|nvme*p[0-9]*) echo "❌ $dev is a partition; the ticket asks for whole disks only";;
    *) echo "❌ $dev did not write the most among the whole disks in the 10 s window (compare the change in sectors written, not the totals)";;
  esac
  exit 1
fi
ok=$(awk -v r="$rate" -v d="$DELTA" 'BEGIN { e = d / 20; diff = r - e; if (diff < 0) diff = -diff; print (diff <= 1.0001) ? 1 : 0 }')
if [ "$ok" != 1 ]; then
  echo "❌ the device is right but $rate KiB/s is not: take the difference of the counters, multiply by 512 bytes, divide by 1024 and by the 10 seconds"
  exit 1
fi
echo "✅ $DEV wrote the most: about $rate KiB/s over the window"
exit 0
