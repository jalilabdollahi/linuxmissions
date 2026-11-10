#!/bin/bash
# failing_disk.txt must be "sdb 14.201332" (whitespace-insensitive).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cksum dmesg.txt 2>/dev/null | cmp -s - .lm-state/sum; then
  echo "❌ dmesg.txt was changed; it is the evidence, so type 'reset' to get it back"
  exit 1
fi
[ -s failing_disk.txt ] || { echo "❌ failing_disk.txt does not exist yet (or is empty)"; exit 1; }
if [ "$(grep -c . failing_disk.txt)" -ne 1 ]; then
  echo "❌ failing_disk.txt must contain exactly one line: DEVICE SECONDS"
  exit 1
fi
LINE=$(tr -d '\r' < failing_disk.txt | tr -s '[:space:]' ' ' | sed -e 's/^ //' -e 's/ $//')
WANT=$(cat .lm-state/want)
[ "$LINE" = "$WANT" ] && { echo "✅ $WANT: the failing disk and the time of its first error"; exit 0; }

set -- $LINE
if [ $# -ne 2 ]; then
  echo "❌ the line must have two words: the device name and the timestamp"
  exit 1
fi
dev=$1; ts=${2#[}; ts=${ts%]}
case "$dev" in
  sd[a-z]|sd[a-z][a-z]) ;;
  ata*|scsi*) echo "❌ '$dev' is a kernel port or host name; the answer needs the sdX device name that goes with it"; exit 1 ;;
  *) echo "❌ '$dev' does not look like an sdX disk name"; exit 1 ;;
esac
if [ "$dev" != "sdb" ]; then
  if grep -q "\[$dev\]" dmesg.txt; then
    echo "❌ $dev is a healthy disk in this log: look for the errors and follow them back to a disk"
  else
    echo "❌ $dev does not appear in the log"
  fi
  exit 1
fi
if ! grep -q "^\[ *$ts\]" dmesg.txt; then
  echo "❌ '$ts' is not a timestamp that appears in dmesg.txt; copy it exactly as printed"
  exit 1
fi
first=$(grep -n "^\[ *$ts\]" dmesg.txt | head -1 | cut -d: -f1)
if grep -q "^\[ *$ts\].*\(sdb\|I/O error\|EXT4-fs\)" dmesg.txt; then
  echo "❌ that is the first line that names sdb in an error, but the kernel complained earlier under another name"
elif [ "$ts" \> "14.201332" ]; then
  echo "❌ $dev is right, but there is an earlier error message about that disk than $ts"
else
  echo "❌ $dev is right, but $ts is not the first error about it (the line at $ts is not an error for this disk, or comes too early)"
fi
exit 1
