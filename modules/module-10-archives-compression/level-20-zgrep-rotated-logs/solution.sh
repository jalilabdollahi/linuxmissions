#!/bin/bash
# Oldest rotation first; xzgrep picks the right decompressor for .gz, .bz2 and .xz.
for i in $(seq 14 -1 2); do
  xzgrep -hE 'order=88412( |$)' logs/app.log.$i.*
done > order-88412.txt
grep -hE 'order=88412( |$)' logs/app.log.1 logs/app.log >> order-88412.txt
cat order-88412.txt
