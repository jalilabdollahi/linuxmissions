#!/bin/bash
# 1. find the descriptor that points to a deleted file in tmp/
for f in /proc/[0-9]*/fd/*; do
  case "$(readlink "$f" 2>/dev/null)" in *"/tmp/app-debug.log (deleted)") fd=$f ;; esac
done
# 2. copy the data out through the descriptor, then stop the holder
mkdir -p recovered
cp "$fd" recovered/app-debug.log
pid=${fd#/proc/}; pid=${pid%%/*}
kill "$pid"
# 3. policy cleanup: regular files older than 7 days that nobody has open
find tmp -type f -mtime +7 -print0 | while IFS= read -r -d '' x; do
  fuser -s "$x" 2>/dev/null || rm -- "$x"
done
ls -la tmp
