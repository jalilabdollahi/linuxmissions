#!/bin/bash
# Start sector and length of partition 2 from the table, then copy that many
# 512-byte sectors starting at that sector, and check against the vendor's sum.
sfdisk -d disk.img
read -r start size < <(sfdisk -d disk.img | sed 's/[=,]/ /g' | awk '$1 == "disk.img2" { print $4, $6 }')
dd if=disk.img of=p2.img bs=512 skip="$start" count="$size"
sha256sum -c vendor.sha256
