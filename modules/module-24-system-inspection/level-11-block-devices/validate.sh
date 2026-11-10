#!/bin/bash
# disk.txt = /dev/NAME of the disk with the ticket's serial + all real mount
# paths below it, sorted.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -s capture/lsblk.json ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f disk.txt ] || { echo "❌ disk.txt does not exist yet"; exit 1; }
got=$(tr -d '\r' < disk.txt | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
want=$(cat .lm-state/expected)
[ -n "$got" ] || { echo "❌ disk.txt is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ right disk, and all $(( $(wc -l <<< "$want") - 1 )) mounts found"; exit 0
fi
wdisk=$(head -1 <<< "$want"); gdisk=$(head -1 <<< "$got")
if [ "$gdisk" != "$wdisk" ]; then
  if [ "${gdisk#/dev/}" = "$gdisk" ]; then
    echo "❌ the first line must be the disk's device path, /dev/NAME"
  else
    echo "❌ $gdisk is not the disk with the serial from TICKET.md (check the SERIAL field, not the model)"
  fi
  exit 1
fi
rest=$(tail -n +2 <<< "$got"); wrest=$(tail -n +2 <<< "$want")
if grep -qE 'SWAP|null' <<< "$rest"; then
  echo "❌ swap and null are not mount paths; leave them out"; exit 1
fi
extra=$(comm -13 <(sort <<< "$wrest") <(sort -u <<< "$rest") | head -1)
miss=$(comm -23 <(sort <<< "$wrest") <(sort -u <<< "$rest") | wc -l | tr -d ' ')
if [ -n "$extra" ]; then
  echo "❌ $extra is not mounted from that disk"
elif [ "$miss" -gt 0 ]; then
  echo "❌ $miss mount path(s) of that disk are missing (mounts can sit several levels down: partition, LVM, logical volume; and a device can have two)"
else
  echo "❌ the mount paths are right, but they must be sorted and listed once"
fi
exit 1
