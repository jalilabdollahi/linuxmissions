#!/bin/bash
cat captures/README
grep 'segfault at' captures/dmesg.txt
bt=$(awk '$1 == "btime" { print $2 }' captures/proc-stat.txt)
# [ seconds.micro] binary[pid]: segfault at ... in library[addr+size] ...
sed -nE 's/^\[ *([0-9]+)\.[0-9]+\] ([^[]+)\[[0-9]+\]: segfault at .* in ([^[]+)\[.*/\1 \2 \3/p' captures/dmesg.txt |
while read -r up bin lib; do
  echo "$(date -u -d "@$((bt + up))" +%Y-%m-%dT%H:%M:%SZ) $bin $lib"
done > crash.txt
cat crash.txt
