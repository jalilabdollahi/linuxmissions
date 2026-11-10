#!/bin/bash
# every process whose cwd or any open fd points below $PWD/data
base=$(pwd -P)/data
for p in /proc/[0-9]*; do
  for l in "$p"/cwd "$p"/fd/*; do
    t=$(readlink "$l" 2>/dev/null) || continue
    case $t in "$base"|"$base"/*) echo "${p#/proc/} $t";; esac
  done
done | sort -u > holders.txt
