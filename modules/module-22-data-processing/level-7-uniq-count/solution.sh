#!/bin/bash
# Look at the runs first, then find the longest DOWN run and where it started.
awk '{ print $2 }' probe.log | uniq -c | grep DOWN | sort -rn | head -3
awk '$2 == "DOWN" { if (run == 0) start = $1; run++; if (run > best) { best = run; beststart = start }; next }
     { run = 0 }
     END { print beststart, best }' probe.log > longest_outage.txt
cat longest_outage.txt
