#!/bin/bash
# etc/fstab must have exactly the four entries with the new UUIDs, nofail on the
# USB disk, pass 1 on / and 0 or 2 elsewhere (0 for swap); comments and the other
# settings of each entry must be kept.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
. .lm-state/spec

if ! cksum blkid.txt 2>/dev/null | cmp -s - .lm-state/blkid.sum; then
  echo "❌ blkid.txt was changed; it is the evidence, type 'reset' to get it back"
  exit 1
fi
if [ ! -f etc/fstab ]; then
  echo "❌ etc/fstab is missing"
  exit 1
fi

# comments must survive
while IFS= read -r c; do
  grep -qxF -- "$c" etc/fstab || { echo "❌ a comment line was lost from etc/fstab: $c"; exit 1; }
done < <(grep '^#' .lm-state/orig.fstab)

entries=$(grep -v '^[[:space:]]*\(#\|$\)' etc/fstab)
n=$(printf '%s\n' "$entries" | grep -c .)
if [ "$n" -ne 4 ]; then
  echo "❌ etc/fstab has $n entries, it should still have the 4 original ones (root, swap, data, usb-backup)"
  exit 1
fi
bad=$(printf '%s\n' "$entries" | awk 'NF != 6 { print; exit }')
if [ -n "$bad" ]; then
  echo "❌ an fstab entry does not have exactly six fields: $bad"
  exit 1
fi

get() { printf '%s\n' "$entries" | awk -v m="$1" '$2 == m { print; exit }'; }
orig() { grep -v '^[[:space:]]*\(#\|$\)' .lm-state/orig.fstab | awk -v m="$1" '$2 == m { print; exit }'; }

check() {  # mountpoint expected_uuid expected_type
  local mp="$1" uuid="$2" line fs
  line=$(get "$mp")
  if [ -z "$line" ]; then echo "❌ no entry for mount point $mp any more"; exit 1; fi
  set -- $line
  fs=$1; local type=$3 opts=$4 pass=$6 o
  case "$fs" in
    UUID=*) ;;
    *) echo "❌ the $mp entry does not use UUID= (found $fs)"; exit 1 ;;
  esac
  got=${fs#UUID=}
  if [ "$got" != "$uuid" ]; then
    if [ -n "$got" ] && printf '%s' "$PARTS" | grep -qwF -- "$got"; then
      echo "❌ the $mp entry uses a PARTUUID: fstab's UUID= wants the value from the UUID column of blkid.txt"
    elif grep -q "$got" .lm-state/orig.fstab; then
      echo "❌ the $mp entry still has the old disk's UUID"
    else
      echo "❌ the UUID in the $mp entry matches no disk in blkid.txt"
    fi
    exit 1
  fi
  set -- $(orig "$mp")
  if [ "$type" != "$3" ]; then echo "❌ the file system type of $mp was changed (it must stay $3)"; exit 1; fi
  for o in $(printf '%s' "$4" | tr ',' ' '); do
    case ",$opts," in *",$o,"*) ;; *) echo "❌ the option '$o' of the $mp entry was removed"; exit 1 ;; esac
  done
  case "$pass" in 0|1|2) ;; *) echo "❌ the pass column of $mp must be 0, 1 or 2"; exit 1 ;; esac
}

check / "$ROOT"
r=$(get /)
[ "$(printf '%s' "$r" | awk '{print $6}')" = 1 ] || { echo "❌ the root file system must have pass 1 so it is checked first"; exit 1; }

check none "$SWAP"
s=$(get none)
[ "$(printf '%s' "$s" | awk '{print $3}')" = swap ] || { echo "❌ the swap entry must keep type swap and mount point none"; exit 1; }
[ "$(printf '%s' "$s" | awk '{print $6}')" = 0 ] || { echo "❌ swap is never checked by fsck: its pass column must be 0"; exit 1; }

check /srv/data "$DATA"
p=$(get /srv/data | awk '{print $6}')
[ "$p" != 1 ] || { echo "❌ /srv/data has pass 1: only the root file system gets 1, others get 2 (or 0)"; exit 1; }

check /mnt/usb-backup "$USB"
u=$(get /mnt/usb-backup)
case ",$(printf '%s' "$u" | awk '{print $4}')," in
  *,nofail,*) ;;
  *) echo "❌ /mnt/usb-backup has no nofail: the server would stop at boot again when the USB disk is unplugged"; exit 1 ;;
esac
p=$(printf '%s' "$u" | awk '{print $6}')
[ "$p" != 1 ] || { echo "❌ /mnt/usb-backup has pass 1: only the root file system gets 1"; exit 1; }

echo "✅ etc/fstab points every entry at its new disk, the USB disk is optional (nofail) and the fsck order is right"
exit 0
