#!/bin/bash
# record the chain first (child -> parent), then stop the whole session's process group
p=$(pgrep -f 'worker\.py --job 7$')
: > chain.txt
while :; do
  echo "$p" >> chain.txt
  grep -q 'supervisor\.sh' /proc/$p/cmdline && break
  p=$(ps -o ppid= -p "$p" | tr -d ' ')
done
cat chain.txt
kill -- -"$(ps -o pgid= -p "$(tail -1 chain.txt)" | tr -d ' ')"
