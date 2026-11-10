#!/bin/bash
for pid in $(ps -eo pid,ni,cmd | awk '/opt\/jobs\/batch-/ && !/awk/ && $2 < 10 {print $1}'); do
  renice -n 15 -p "$pid"
done
