#!/bin/bash
who capture/utmp | awk '
  match($0, /\([^)]*\)$/) {
    host = substr($0, RSTART + 1, RLENGTH - 2)
    if (host !~ /^10\./) print $1, $2, host
  }' > outside_sessions.txt
cat outside_sessions.txt
