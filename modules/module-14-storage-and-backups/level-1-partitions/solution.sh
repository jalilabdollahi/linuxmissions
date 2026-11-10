#!/bin/bash
# Read the table, then keep the rows that are data partitions (not type 5/f/85)
# with the size converted from sectors to MiB.
sfdisk -d disk.img
sfdisk -d disk.img | sed 's/[=,]/ /g' | awk '/^disk.img[0-9]/ && $8 != "5" && $8 != "f" && $8 != "85" { n = $1; sub(/disk.img/, "", n); print n, $4, $6 / 2048, $8 }' > partitions.txt
cat partitions.txt
