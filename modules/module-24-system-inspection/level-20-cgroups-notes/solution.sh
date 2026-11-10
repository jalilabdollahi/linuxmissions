#!/bin/bash
{
echo "unit,memory_max_mib,oom_kills,throttled_pct"
for d in cgroup/system.slice/*/; do
  u=$(basename "$d")
  m=$(cat "$d/memory.max")
  [ "$m" = max ] && m=unlimited || m=$((m / 1048576))
  k=$(awk '$1 == "oom_kill" {print $2}' "$d/memory.events")
  p=$(awk '$1 == "nr_periods" {per = $2} $1 == "nr_throttled" {thr = $2} END {printf "%.1f", per ? thr * 100 / per : 0}' "$d/cpu.stat")
  echo "$u,$m,$k,$p"
done
} > cgroups.csv
cat cgroups.csv
