#!/bin/bash
for i in $(seq 30); do
  ps -eo ppid=,pcpu=,args= | awk '$2 > 30 && /-step\.sh/ {print $1}'
  sleep 0.1
done | sort | uniq -c | sort -rn | awk 'NR==1 {print $2}' > culprit.txt
