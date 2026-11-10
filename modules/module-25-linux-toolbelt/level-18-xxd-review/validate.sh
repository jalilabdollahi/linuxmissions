#!/bin/bash
# config.bin = original with byte 0x2A set to 01 and the last byte replaced by
# the sum of all earlier bytes mod 256.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
orig=.lm-state/config.orig
[ -f config.bin ] || { echo "❌ config.bin is missing; copy config.bin.orig back and patch again"; exit 1; }
size=$(wc -c < config.bin)
[ "$size" -eq 128 ] || { echo "❌ config.bin is $size bytes, it must stay 128"; exit 1; }
b() { od -An -v -t u1 -j "$2" -N 1 "$1" | tr -d ' '; }
if [ "$(b config.bin 42)" -ne 1 ]; then
  printf '❌ the byte at offset 0x2A is 0x%02x, debug mode needs 01\n' "$(b config.bin 42)"; exit 1
fi
diffs=$(cmp -l config.bin "$orig" | awk '{ print $1 - 1 }' | grep -vx -e 42 -e 127 | head -1)
if [ -n "$diffs" ]; then
  printf '❌ the byte at offset 0x%02x changed, but only 0x2A and the checksum may differ\n' "$diffs"; exit 1
fi
want=$(head -c 127 config.bin | od -An -v -t u1 | awk '{ for (i = 1; i <= NF; i++) s += $i } END { print s % 256 }')
if [ "$(b config.bin 127)" -ne "$want" ]; then
  echo "❌ the debug byte is set, but the last byte is not the sum of the 127 bytes before it modulo 256 (the bootloader would reject it)"; exit 1
fi
echo "✅ debug flag set, checksum updated, nothing else touched"
exit 0
