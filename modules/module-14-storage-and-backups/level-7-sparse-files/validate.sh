#!/bin/bash
# originals untouched (content and allocation), sizes.txt exact, vm2-copy.img
# identical and sparse, vm-backup.tar small, GNU-sparse, extracts to vm1.img.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! (cd vm && sha256sum -c --quiet ../.lm-state/orig.sums >/dev/null 2>&1); then
  echo "❌ vm/vm1.img or vm/vm2.img was changed; the originals must stay as they are (type 'reset' to get them back)"
  exit 1
fi
a1=$(stat -c %s vm/vm1.img); a2=$(stat -c %s vm/vm2.img)
k1=$(du -k vm/vm1.img | cut -f1); k2=$(du -k vm/vm2.img | cut -f1)
if [ "$k2" -lt $((a2 / 1024 * 9 / 10)) ] || [ "$k1" -gt $((a1 / 1024 / 5)) ]; then
  echo "❌ the original images' allocation changed (holes were punched in vm2.img or vm1.img was filled); reset and work on copies"
  exit 1
fi

if [ ! -f sizes.txt ]; then echo "❌ sizes.txt does not exist yet"; exit 1; fi
GOT=$(tr -d '\r' < sizes.txt | awk 'NF { $1 = $1; print }' | sort)
WANT=$(printf 'vm1.img %s %s\nvm2.img %s %s\n' "$a1" "$k1" "$a2" "$k2" | sort)
if [ "$GOT" != "$WANT" ]; then
  while read -r name app kib; do
    row=$(printf '%s\n' "$GOT" | awk -v n="$name" '$1 == n')
    [ -n "$row" ] || { echo "❌ sizes.txt has no line for $name"; exit 1; }
    set -- $row
    if [ "$2" != "$app" ]; then
      echo "❌ sizes.txt: the apparent size of $name is wrong (bytes of the file's length, what ls -l shows)"; exit 1
    fi
    if [ "$3" != "$kib" ]; then
      if [ "$3" = $((kib * 1024)) ]; then echo "❌ sizes.txt: the allocated size of $name looks like bytes; the column is KiB"
      else echo "❌ sizes.txt: the allocated size of $name is wrong (disk blocks really used, in KiB)"; fi
      exit 1
    fi
  done <<< "$WANT"
  echo "❌ sizes.txt has extra or malformed lines: it must have exactly one line per image, 'NAME APPARENT_BYTES ALLOCATED_KIB'"
  exit 1
fi

if [ ! -f vm2-copy.img ]; then echo "❌ vm2-copy.img does not exist yet"; exit 1; fi
if ! cmp -s vm/vm2.img vm2-copy.img; then
  echo "❌ vm2-copy.img is not identical to vm/vm2.img"
  exit 1
fi
kc=$(du -k vm2-copy.img | cut -f1)
if [ "$kc" -gt $((a2 / 1024 / 8)) ]; then
  echo "❌ vm2-copy.img uses $kc KiB for ${a2} bytes: the copy still has every block allocated (a plain cp keeps the zero blocks of this image)"
  exit 1
fi

if [ ! -f vm-backup.tar ]; then echo "❌ vm-backup.tar does not exist yet"; exit 1; fi
if [ "$(head -c 2 vm-backup.tar | xxd -p)" = 1f8b ] || ! tar -tf vm-backup.tar >/dev/null 2>&1; then
  echo "❌ vm-backup.tar is not a plain tar archive (no compression wanted, the holes must be stored as holes)"
  exit 1
fi
members=$(tar -tf vm-backup.tar)
if [ "$members" != "vm1.img" ]; then
  echo "❌ vm-backup.tar must contain exactly one member named vm1.img"
  exit 1
fi
ts=$(stat -c %s vm-backup.tar)
if [ "$ts" -gt $((a1 / 8)) ]; then
  echo "❌ vm-backup.tar is $((ts / 1024 / 1024)) MiB: the holes of vm1.img were written out in full"
  exit 1
fi
if ! { [ "$(dd if=vm-backup.tar bs=1 skip=156 count=1 2>/dev/null)" = S ] || head -c 4096 vm-backup.tar | grep -aq 'GNU.sparse'; }; then
  echo "❌ vm-backup.tar is small, but the member is not stored as a sparse file (tar must be told to look for holes)"
  exit 1
fi
W=$(mktemp -d "$SANDBOX/.lm-state/val.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
if ! tar -xf vm-backup.tar -C "$W" 2>/dev/null || ! cmp -s "$W/vm1.img" vm/vm1.img; then
  echo "❌ vm-backup.tar does not extract to a copy identical to vm1.img"
  exit 1
fi
echo "✅ sizes are right, vm2-copy.img keeps the holes, and vm-backup.tar stores vm1.img as a sparse file"
exit 0
