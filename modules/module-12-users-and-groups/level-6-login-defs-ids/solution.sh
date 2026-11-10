#!/bin/bash
# Read the ranges, then look at what is used inside each range.
grep -E '^(UID|GID|SYS_UID|SYS_GID)_(MIN|MAX)' etc/login.defs
smin=$(awk '$1 == "SYS_UID_MIN" { print $2 }' etc/login.defs)
smax=$(awk '$1 == "SYS_UID_MAX" { print $2 }' etc/login.defs)
umin=$(awk '$1 == "UID_MIN" { print $2 }' etc/login.defs)
umax=$(awk '$1 == "UID_MAX" { print $2 }' etc/login.defs)
# lena: highest regular UID + 1; the GID follows the UID only if no group has that number
lu=$(awk -F: -v a="$umin" -v b="$umax" '$3 >= a && $3 <= b && $3 > m { m = $3 } END { print m + 1 }' etc/passwd)
lg=$lu
if cut -d: -f3 etc/group | grep -qx "$lu"; then
  lg=$(awk -F: -v a="$umin" -v b="$umax" '$3 >= a && $3 <= b && $3 > m { m = $3 } END { print m + 1 }' etc/group)
fi
# metrics: lowest used system UID - 1, and the same for the group
mu=$(awk -F: -v a="$smin" -v b="$smax" '$3 >= a && $3 <= b && (m == "" || $3 < m) { m = $3 } END { print m - 1 }' etc/passwd)
mg=$mu
if cut -d: -f3 etc/group | grep -qx "$mu"; then
  mg=$(awk -F: -v a="$smin" -v b="$smax" '$3 >= a && $3 <= b && (m == "" || $3 < m) { m = $3 } END { print m - 1 }' etc/group)
fi
printf 'lena %s %s\nmetrics %s %s\n' "$lu" "$lg" "$mu" "$mg" > next-ids.txt
cat next-ids.txt
