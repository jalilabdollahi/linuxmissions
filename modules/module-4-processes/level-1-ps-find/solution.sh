#!/bin/bash
sleep 3   # let the runaway build up some CPU time
# GNU ps sorts with --sort; BSD/macOS ps sorts by CPU with -r.
if ps aux --sort=-%cpu >/dev/null 2>&1; then
  ps aux --sort=-%cpu | head -6 > top_procs.txt
else
  ps aux -r | head -6 > top_procs.txt
fi
pgrep -f report_builder.sh > culprit.txt
