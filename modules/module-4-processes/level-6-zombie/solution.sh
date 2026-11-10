#!/bin/bash
ps -eo pid,ppid,stat,comm | awk '$3 ~ /^Z/' > zombies.txt
# Show every zombie parent with its command line, then stop the one that is job_runner.py
ps -o pid,args -p "$(awk '{print $2}' zombies.txt | sort -u | paste -sd, -)"
PARENT=$(ps -o pid=,args= -p "$(awk '{print $2}' zombies.txt | sort -u | paste -sd, -)" | awk '/job_runner\.py/ {print $1}')
kill "$PARENT"
sleep 0.5
