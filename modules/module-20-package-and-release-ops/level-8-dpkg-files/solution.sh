#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
for p in $(cat suspects.txt); do
  real=$(readlink -f "rootfs$p" | sed "s|^$SANDBOX/rootfs||")
  owner=$(dpkg -S "$real" 2>/dev/null | cut -d: -f1)
  printf '%s\t%s\n' "$p" "${owner:-none}"
done > owners.tsv
cat owners.tsv
