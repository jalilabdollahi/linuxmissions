#!/bin/bash
# time is a shell keyword: it reports on the shell's stderr, so the group { } gets
# the redirect. TIMEFORMAT picks "real user sys" in plain seconds.
export TIMEFORMAT='%3R %3U %3S'
: > timings.txt
for s in reports/gen-*.sh; do
  { time bash "$s" > /dev/null; } 2>> timings.txt
done
cat timings.txt
# little CPU time compared with real time = waiting; more system than user time = syscalls; else CPU
paste -d' ' <(ls reports) timings.txt | awk '{ c = ($3 + $4 < 0.25 * $2) ? "wait" : ($4 > $3 ? "syscall" : "cpu"); print $1, c }' > class.txt
cat class.txt
