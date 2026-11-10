#!/bin/bash
# modules.txt = exact .ko basenames from the image; initrd-root/ = only etc/,
# identical to the image's copy; nothing extracted elsewhere.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/initrd.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -f initrd.img ] || [ "$(cksum < initrd.img)" != "$(cat .lm-state/initrd.sum)" ]; then
  echo "❌ initrd.img is gone or was changed; type 'reset'"
  exit 1
fi
for d in etc usr bin scripts conf init; do
  if [ -e "$d" ] || [ -L "$d" ]; then
    echo "❌ $d was unpacked into the sandbox root: cpio extracts into the current directory, so cd into initrd-root/ first (remove ./$d)"
    exit 1
  fi
done

if [ ! -f modules.txt ]; then
  echo "❌ modules.txt does not exist yet"
  exit 1
fi
want=$(gzip -dc initrd.img | cpio -it --quiet 2>/dev/null | grep '\.ko$' | sed 's|.*/||' | LC_ALL=C sort)
got=$(tr -d '\r' < modules.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')
if printf '%s\n' "$got" | grep -q /; then
  echo "❌ modules.txt holds paths; write only the file names (nvme.ko, not usr/lib/modules/.../nvme.ko)"
  exit 1
fi
dup=$(printf '%s\n' "$got" | LC_ALL=C sort | uniq -d | head -1)
if [ -n "$dup" ]; then
  echo "❌ $dup is listed more than once in modules.txt"
  exit 1
fi
got=$(printf '%s\n' "$got" | LC_ALL=C sort)
if [ "$got" != "$want" ]; then
  wrong=$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)
  if [ -n "$wrong" ]; then
    echo "❌ modules.txt lists '$wrong', which is not a .ko module in initrd.img"
  else
    echo "❌ modules.txt lists $(printf '%s\n' "$got" | grep -c .) modules, but initrd.img ships $(printf '%s\n' "$want" | grep -c .)"
  fi
  exit 1
fi

nmods=$(printf '%s\n' "$want" | grep -c .)
if [ ! -d initrd-root/etc ]; then
  echo "❌ modules.txt is right; initrd-root/etc does not exist yet"
  exit 1
fi
other=$(cd initrd-root && find . -mindepth 1 -maxdepth 1 ! -name etc | sed 's|^\./||' | head -1)
if [ -n "$other" ]; then
  echo "❌ initrd-root/$other was extracted too; only etc/ was wanted"
  exit 1
fi

ref=$(mktemp -d)
trap 'rm -rf "$ref"' EXIT
(cd "$ref" && gzip -dc "$SANDBOX/initrd.img" | cpio -idm --quiet 'etc/*' 2>/dev/null)
want=$(cd "$ref/etc" && find . | LC_ALL=C sort)
got=$(cd initrd-root/etc && find . | LC_ALL=C sort)
if [ "$want" != "$got" ]; then
  miss=$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)
  if [ -n "$miss" ]; then
    echo "❌ initrd-root/etc/${miss#./} is missing"
  else
    echo "❌ initrd-root/etc/$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1 | sed 's|^\./||') is not part of the image's etc/"
  fi
  exit 1
fi
while IFS= read -r p; do
  if [ -L "$ref/etc/$p" ]; then
    if [ "$(readlink "$ref/etc/$p")" != "$(readlink "initrd-root/etc/$p" 2>/dev/null)" ]; then
      echo "❌ initrd-root/etc/${p#./} should be a symlink to $(readlink "$ref/etc/$p")"
      exit 1
    fi
  elif [ -f "$ref/etc/$p" ] && ! cmp -s "$ref/etc/$p" "initrd-root/etc/$p"; then
    echo "❌ initrd-root/etc/${p#./} differs from the copy in initrd.img"
    exit 1
  fi
done <<< "$want"
echo "✅ modules.txt lists all $nmods modules and initrd-root/etc matches the image"
exit 0
