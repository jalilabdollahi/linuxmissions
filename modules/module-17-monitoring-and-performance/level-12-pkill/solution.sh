#!/bin/bash
for hb in $(find run/hb -type f -mmin +2); do
  pkill -f "worker.sh $(basename "$hb")\$"
done
