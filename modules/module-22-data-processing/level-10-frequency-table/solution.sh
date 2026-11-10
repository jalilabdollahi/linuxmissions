#!/bin/bash
# Split on double quotes: $1 = everything up to the request (with the time),
# $3 = " status bytes ". Count per (hour, first digit), print all 24 hours.
awk -F'"' '{
    split($1, t, ":"); hour = t[2] + 0
    split($3, s, " "); cls = substr(s[1], 1, 1)
    count[hour, cls]++
  }
  END {
    print "hour,2xx,3xx,4xx,5xx"
    for (h = 0; h < 24; h++) printf "%02d,%d,%d,%d,%d\n", h, count[h, 2], count[h, 3], count[h, 4], count[h, 5]
  }' access.log > status_by_hour.csv
column -s, -t status_by_hour.csv
