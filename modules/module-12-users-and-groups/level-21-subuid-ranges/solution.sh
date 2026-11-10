#!/bin/bash
# Find the first ID after the highest existing range in each file (an odd-sized
# range counts), then hand out consecutive 65536 blocks to whoever is missing.
for kind in subuid subgid; do
  next=$(awk -F: '$2 + $3 > m { m = $2 + $3 } END { print m }' etc/$kind)
  for u in omar pavel nina; do
    grep -q "^$u:" etc/$kind && continue
    end=$((next + 65535))
    if [ $kind = subuid ]; then bin/usermod -v $next-$end $u; else bin/usermod -w $next-$end $u; fi
    next=$((end + 1))
  done
done
cat etc/subuid etc/subgid
