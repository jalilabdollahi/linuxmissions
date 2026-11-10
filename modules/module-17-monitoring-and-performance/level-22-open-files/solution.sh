#!/bin/bash
for p in $(pgrep -f 'opt/svc.py'); do
  n=$(ls /proc/$p/fd | wc -l)
  lim=$(awk '/^Max open files/ {print $4}' /proc/$p/limits)
  echo "$((n * 100 / lim)) $p $n $lim"
done | sort -rn | head -1 > .top
read -r pct pid n lim < .top
type=$(for l in /proc/$pid/fd/*; do readlink "$l"; done | sed -E 's/^(socket|pipe):.*/\1/; t; s#^/.*#file#' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
printf 'pid=%s\ntype=%s\nlimit=%s\nfds=%s\n' "$pid" "$type" "$lim" "$n" > fdleak.env
