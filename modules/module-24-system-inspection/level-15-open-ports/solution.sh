#!/bin/bash
# every listening port that is not in approved.txt (IPv4 and IPv6), with its owner
ss -ltnpH | while read -r _ _ _ local _ users; do
  port=${local##*:}
  grep -q "^$port " approved.txt && continue
  pid=$(sed -n 's/.*pid=\([0-9]*\).*/\1/p' <<< "$users")
  echo "$port $pid $(readlink /proc/$pid/exe)"
done > rogue.txt
cat rogue.txt
read -r port pid exe < rogue.txt
kill "$pid"
