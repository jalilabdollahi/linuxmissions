#!/bin/bash
# config.bin: 128 random bytes with byte 0x2A forced to 00 and the last byte set
# to the sum of the first 127 bytes mod 256, as the bootloader expects.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
head -c 127 /dev/urandom > config.body
printf '\0' | dd of=config.body bs=1 seek=42 conv=notrunc 2>/dev/null
sum=$(od -An -v -t u1 config.body | awk '{ for (i = 1; i <= NF; i++) s += $i } END { print s % 256 }')
{ cat config.body; printf "$(printf '\\x%02x' "$sum")"; } > config.bin
rm config.body
cp config.bin config.bin.orig
cp config.bin .lm-state/config.orig
