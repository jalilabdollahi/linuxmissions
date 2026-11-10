#!/bin/bash
# Ping each inventory line once; keep the names whose ping exits 0.
while read -r host; do
  case "$host" in ''|'#'*) continue ;; esac
  if ./ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
    echo "$host"
  fi
done < hosts.txt > reachable.txt
cat reachable.txt
