#!/bin/bash
echo "host,available_mib,consumer" > memory.csv
for f in capture/*.meminfo; do
  awk -v h="$(basename "$f" .meminfo)" '
    /^MemAvailable:/    { a = int($2 / 1024) }
    /^HugePages_Total:/ { ht = $2 }
    /^Hugepagesize:/    { hs = $2 }
    /^Shmem:/           { sh = $2 }
    /^SUnreclaim:/      { su = $2 }
    END {
      hp = ht * hs; c = "HugePages"; m = hp
      if (sh > m) { c = "Shmem"; m = sh }
      if (su > m) { c = "SUnreclaim"; m = su }
      print h "," a "," c
    }' "$f"
done >> memory.csv
cat memory.csv
