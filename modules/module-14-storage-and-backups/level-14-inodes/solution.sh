#!/bin/bash
# Count files per directory to find the hog, then delete expired sessions with
# find (a glob like sess_* would exceed the argument-list limit).
hog=$(find srv-root -type f | sed 's#/[^/]*$##' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
echo "$hog" > hog.txt
find "$hog" -maxdepth 1 -name 'sess_*' -mmin +1440 -delete
find "$hog" -type f | wc -l
