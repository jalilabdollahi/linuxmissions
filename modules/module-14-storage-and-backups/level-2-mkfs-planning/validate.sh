#!/bin/bash
# logs.img must be an ext4 image of exactly SIZE_MiB with the requested label,
# reserved-block count and inode density, and must be consistent (e2fsck).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
. .lm-state/spec

if [ ! -f logs.img ]; then
  echo "❌ logs.img does not exist yet"
  exit 1
fi
info=$(dumpe2fs -h logs.img 2>/dev/null)
if [ -z "$info" ]; then
  echo "❌ logs.img is not an ext2/3/4 file system (dumpe2fs cannot read it)"
  exit 1
fi
field() { printf '%s\n' "$info" | sed -n "s/^$1: *//p" | head -1; }

features=$(field 'Filesystem features')
case " $features " in
  *" extent "*) ;;
  *) echo "❌ logs.img is not ext4: the extents feature is missing (ext4 was requested, not ext2/ext3)"; exit 1 ;;
esac
case " $features " in
  *" has_journal "*) ;;
  *) echo "❌ logs.img has no journal; the request is for ext4 with its default journal"; exit 1 ;;
esac

bytes=$(stat -c %s logs.img)
want_bytes=$((SIZE_MIB * 1024 * 1024))
if [ "$bytes" -ne "$want_bytes" ]; then
  echo "❌ logs.img is $((bytes / 1024 / 1024)) MiB ($bytes bytes), the request asks for exactly ${SIZE_MIB} MiB"
  exit 1
fi
bs=$(field 'Block size'); blocks=$(field 'Block count')
if [ $((bs * blocks)) -ne "$want_bytes" ]; then
  echo "❌ the file system uses $((bs * blocks / 1024 / 1024)) MiB of the ${SIZE_MIB} MiB image: the whole image must be used"
  exit 1
fi
label=$(field 'Filesystem volume name')
if [ "$label" != "$LABEL" ]; then
  echo "❌ the volume name is '$label', the request says ${LABEL}"
  exit 1
fi
reserved=$(field 'Reserved block count')
inodes=$(field 'Inode count')
# What mke2fs reserves for a percentage is not always blocks*pct/100 (it
# depends on the layout, inode tables included), so ask mke2fs itself with the same block size.
ref=.lm-state/ref.img
rm -f "$ref"; truncate -s "$want_bytes" "$ref"
mke2fs -q -F -t ext4 -b "$bs" -N "$inodes" -m "$RESERVED" "$ref" >/dev/null 2>&1
want_res=$(dumpe2fs -h "$ref" 2>/dev/null | sed -n 's/^Reserved block count: *//p')
rm -f "$ref"
if [ "$reserved" != "$want_res" ]; then
  pct=$(awk -v r="$reserved" -v b="$blocks" 'BEGIN { printf "%.1f", r * 100 / b }')
  echo "❌ $reserved blocks are reserved for root ($pct% of the volume), the request asks for ${RESERVED}%"
  exit 1
fi
want_inodes=$((want_bytes / RATIO))
if [ "$inodes" -lt "$want_inodes" ]; then
  echo "❌ logs.img has only $inodes inodes, but one inode per ${RATIO} bytes needs at least $want_inodes"
  exit 1
fi
if ! e2fsck -fn logs.img >/dev/null 2>&1; then
  echo "❌ e2fsck finds problems in logs.img; build it again with a clean mke2fs run"
  exit 1
fi
echo "✅ logs.img is a clean ${SIZE_MIB} MiB ext4 volume '$LABEL' with ${RESERVED}% reserved and $inodes inodes"
exit 0
