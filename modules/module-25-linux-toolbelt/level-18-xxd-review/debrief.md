# Flip One Byte, Fix One Sum

## Why it works
`xxd -p -c1` turns the binary into one hex byte per line, so offset N is line
N+1 and `sed` can change a single byte without moving the others. The checksum
byte depends on every byte before it, including the one just patched, so it is
computed after the edit: bash adds the 127 hex values and `% 256` keeps the low
byte. `xxd -r -p` rebuilds the binary from the edited list. The result differs
from the original in exactly two places, which `cmp -l` confirms.

## Common mistakes
- Changing the flag and forgetting the checksum: the bootloader rejects the blob.
- Editing the normal `xxd` dump by hand and adding or removing a byte shifts
  everything after it; the file must stay 128 bytes.
- Counting lines from 0 instead of 1 patches the neighbouring byte.

## Learn next
For a single byte you can also write in place:
`printf '\x01' | dd of=config.bin bs=1 seek=$((0x2A)) conv=notrunc`.
