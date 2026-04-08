#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX"/{small,medium,big}

# small files
for i in 1 2 3 4 5; do
  dd if=/dev/urandom of="$SANDBOX/small/file$i.dat" bs=1K count=1 2>/dev/null
done
# medium
dd if=/dev/urandom of="$SANDBOX/medium/data.dat" bs=1K count=100 2>/dev/null
# big - the one to find
dd if=/dev/urandom of="$SANDBOX/big/hugefile.dat" bs=1K count=500 2>/dev/null
