#!/bin/bash
# IDLE is column 5. Under 10 minutes means: seconds ("45.00s"), or min:sec
# with fewer than 10 minutes. Days and hours:minutes ("1:05m") are stale.
awk 'NR > 2 {
  i = $5
  if (i ~ /days$/ || i ~ /m$/) ok = 0
  else if (i ~ /s$/) ok = 1
  else { split(i, t, ":"); ok = (t[1] < 10) }
  if (ok) print $1
}' capture/w.txt | sort -u > warn_users.txt
cat warn_users.txt
