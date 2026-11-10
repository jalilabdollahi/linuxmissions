#!/bin/bash
# Look at the compression first, then list each image with the matching tool.
file sysroot/boot/initrd.img-*
for f in sysroot/boot/initrd.img-*; do
  if file "$f" | grep -q Zstandard; then dec="zstdcat"; else dec="zcat"; fi
  echo "== $f"
  $dec "$f" | cpio -t 2>/dev/null | grep 'nvme.*\.ko'
done
echo initrd.img-6.8.0-31-generic > bad_initrd.txt
