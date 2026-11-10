#!/bin/bash
pids=$(pgrep -f 'opt/worker.py')
for p in $pids; do echo "$p $(awk '/^VmRSS/ {print $2}' /proc/$p/status)"; done > rss0.txt
sleep 10
for p in $pids; do echo "$p $(awk '/^VmRSS/ {print $2}' /proc/$p/status)"; done > rss1.txt
join rss0.txt rss1.txt | awk '{print $1, int(($3 - $2) / 10)}' | sort -k2 -n | tail -1 > leak.txt
