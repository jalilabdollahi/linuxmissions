#!/bin/bash
awk 'NR > 1 { print $1 }' healthy.lsmod | sort > h.txt
awk 'NR > 1 { print $1 }' broken.lsmod | sort > b.txt
comm -23 h.txt b.txt > missing.txt
cat missing.txt
# The "Used by" column of the healthy host, for the missing modules only.
grep -wFf missing.txt healthy.lsmod | awk '{print $1, $4}'
echo raid456 > load_first.txt
rm h.txt b.txt
