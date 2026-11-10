#!/bin/bash
# p2.img must be exactly the bytes of partition 2 (checksum from setup).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
. .lm-state/spec

if ! sha256sum -c --quiet .lm-state/disk.sum >/dev/null 2>&1; then
  echo "❌ disk.img was changed; type 'reset' to get it back"
  exit 1
fi
if [ ! -f p2.img ] || [ -L p2.img ]; then
  echo "❌ p2.img does not exist yet (it must be a regular file)"
  exit 1
fi
size=$(stat -c %s p2.img)
if [ "$size" -gt "$BYTES" ]; then
  echo "❌ p2.img is $((size - BYTES)) bytes too big: it contains more than partition 2 (check how much dd was asked to copy, and in which units)"
  exit 1
fi
if [ "$size" -lt "$BYTES" ]; then
  echo "❌ p2.img is $((BYTES - size)) bytes too small: part of partition 2 is missing (check how much dd was asked to copy, and in which units)"
  exit 1
fi
got=$(sha256sum p2.img | cut -d' ' -f1)
if [ "$got" != "$EXPECT" ]; then
  echo "❌ p2.img has the right size but the wrong content: it starts at the wrong place in disk.img (compare the start sector with the units of skip)"
  exit 1
fi
echo "✅ p2.img is exactly partition 2 and matches the vendor's checksum"
exit 0
