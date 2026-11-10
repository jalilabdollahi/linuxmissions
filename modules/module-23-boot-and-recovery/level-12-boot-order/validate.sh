#!/bin/bash
# BootOrder = the ubuntu entry whose PARTUUID is in blkid.txt, then the other
# entries in their original relative order. Entries untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
N=.efi/nvram

if ! cksum bin/efibootmgr blkid.txt 2>/dev/null | cmp -s - .lm-state/sums; then
  echo "❌ the efibootmgr mock or blkid.txt was changed; type 'reset' to get them back"
  exit 1
fi
if ! grep '^entry|' $N | cmp -s - .lm-state/entries; then
  echo "❌ the boot entries themselves changed; only the BootOrder should be edited"
  exit 1
fi
# The right entry: label ubuntu and a PARTUUID that blkid.txt knows (case-insensitive).
GOODN=""
while IFS='|' read -r _ num flag label path; do
  [ "$label" = ubuntu ] || continue
  pu=$(printf '%s' "$path" | sed -n 's/^HD([0-9]*,GPT,\([^,]*\),.*/\1/p' | tr 'A-F' 'a-f')
  if [ -n "$pu" ] && grep -qi "PARTUUID=\"$pu\"" blkid.txt; then GOODN=$num; fi
done < <(grep '^entry|' .lm-state/entries)
ORIG=$(sed 's/^BootOrder: *//' .lm-state/order0)
WANT=$(printf '%s' "$GOODN"; for n in $(echo "$ORIG" | tr ',' ' '); do [ "$n" = "$GOODN" ] || printf ',%s' "$n"; done)
GOT=$(sed -n 's/^BootOrder: *//p' $N)
if [ "$GOT" = "$WANT" ]; then
  echo "✅ BootOrder is $GOT: Boot$GOODN (ubuntu on the current disk) first, the rest in their old order"
  exit 0
fi
first=${GOT%%,*}
if [ "$first" != "$GOODN" ]; then
  label=$(awk -F'|' -v n="$first" '$2 == n { print $4 }' $N)
  case "$first" in
    "") echo "❌ BootOrder is empty" ;;
    *) if [ "$label" = ubuntu ]; then
         echo "❌ Boot$first is an ubuntu entry, but its PARTUUID is not in blkid.txt: that disk is not in the server any more"
       else
         echo "❌ BootOrder starts with Boot$first ($label), which is not the working Ubuntu entry"
       fi ;;
  esac
  exit 1
fi
cnt=$(echo "$GOT" | tr ',' '\n' | wc -l)
total=$(echo "$ORIG" | tr ',' '\n' | wc -l)
if [ "$cnt" -ne "$total" ]; then
  echo "❌ BootOrder has $cnt entries, but it had $total: the other entries must stay in the list"
else
  echo "❌ the right entry is first, but the others are not in their original relative order"
fi
exit 1
