#!/bin/bash
# bad_initrd.txt must name the one image without nvme.ko. Images unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cksum sysroot/boot/initrd.img-* 2>/dev/null | cmp -s - .lm-state/sums; then
  echo "❌ an initrd image was changed or removed; type 'reset' to get the originals back"
  exit 1
fi
[ -s bad_initrd.txt ] || { echo "❌ bad_initrd.txt does not exist yet (or is empty)"; exit 1; }
GOT=$(tr -d '\r' < bad_initrd.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')
WANT=$(cat .lm-state/want)
if [ "$(printf '%s\n' "$GOT" | wc -l)" -ne 1 ]; then
  echo "❌ bad_initrd.txt must contain exactly one file name"
  exit 1
fi
[ "$GOT" = "$WANT" ] && { echo "✅ $WANT is the image without nvme.ko"; exit 0; }

case "$GOT" in */*) GOT=${GOT##*/}; ;; esac
if [ ! -f "sysroot/boot/$GOT" ]; then
  echo "❌ '$GOT' is not one of the files in sysroot/boot/"
  exit 1
fi
case "$GOT" in
  initrd.img-*) ;;
  *) echo "❌ '$GOT' is not an initrd image"; exit 1 ;;
esac
# Does the named image really contain nvme.ko? (decompress by magic bytes)
if [ "$(head -c4 "sysroot/boot/$GOT" | xxd -p)" = "28b52ffd" ]; then
  names=$(zstd -dc "sysroot/boot/$GOT" | cpio -t 2>/dev/null)
else
  names=$(gzip -dc "sysroot/boot/$GOT" 2>/dev/null | cpio -t 2>/dev/null)
fi
if printf '%s\n' "$names" | grep -q '/nvme\.ko$'; then
  echo "❌ $GOT does contain nvme.ko (list it with the right decompressor; an empty listing means the wrong one)"
else
  echo "❌ $GOT is not the answer: check the file name against the other images"
fi
exit 1
