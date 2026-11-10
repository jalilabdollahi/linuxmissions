#!/bin/bash
# List everything with a setuid/setgid bit as seen from inside the image,
# drop what the baseline allows, then strip the bits from the rest.
find rootfs -type f -perm /6000 | sed 's|^rootfs||' | sort > found.txt
grep -vxFf <(grep -v '^#' suid-baseline.txt) found.txt > unexpected.txt
cat unexpected.txt
while IFS= read -r p; do chmod u-s,g-s "rootfs$p"; done < unexpected.txt
rm found.txt
