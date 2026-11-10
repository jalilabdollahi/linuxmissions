#!/bin/bash
declare -A before
for p in $(pgrep -x worker); do before[$p]=$(awk '/^wchar/{print $2}' /proc/$p/io); done
sleep 2
best=0
for p in $(pgrep -x worker); do
  now=$(awk '/^wchar/{print $2}' /proc/$p/io)
  d=$((now - ${before[$p]:-0}))
  if [ "$d" -gt "$best" ]; then best=$d; pid=$p; fi
done
exe=$(readlink /proc/$pid/exe)
echo "$pid $exe" > culprit.txt
kill "$pid"
sleep 0.5
rm -f spool/.dump-*
