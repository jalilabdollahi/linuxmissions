#!/bin/bash
# timeout sends TERM after 3 s (exit 124); -k 2 adds a KILL 2 s later for a
# check that ignores TERM (exit 137). Any other non-zero status is a failure.
while read -r host; do
  timeout -k 2 3 ./healthcheck.sh "$host" >/dev/null 2>&1
  case $? in
    0) echo "$host OK" ;;
    124|137) echo "$host TIMEOUT" ;;
    *) echo "$host FAIL" ;;
  esac
done < hosts.txt > report.txt
cat report.txt
