#!/bin/bash
# What the restore needs, exactly
xz -l restore.tar.xz
need_kib=$(( ( $(xz -l --robot restore.tar.xz | awk '$1 == "totals" { print $5 }') + 1023 ) / 1024 ))
need_ino=$(tar -tJf restore.tar.xz | wc -l)
echo "need $need_kib KiB and $need_ino inodes"
# Which filesystem holds /srv on each host, and does it have both?
for h in hosts/*.txt; do
  awk -v k="$need_kib" -v n="$need_ino" -v host="$(basename "$h" .txt)" '
    /^\$ df -PT/ { s = "kib" }
    /^\$ df -i/  { s = "ino" }
    $NF == "/srv" || $NF == "/" { free[s, $NF] = (s == "kib" ? $5 : $4) }
    END { m = (("kib", "/srv") in free) ? "/srv" : "/"
          if (free["kib", m] >= k && free["ino", m] >= n) print host }' "$h"
done > targets.txt
cat targets.txt
