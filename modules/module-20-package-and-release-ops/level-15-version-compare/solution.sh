#!/bin/bash
mapfile -t v < versions.txt
n=${#v[@]}
for ((i = 0; i < n; i++)); do
  for ((j = 0; j < n - 1 - i; j++)); do
    if dpkg --compare-versions "${v[j]}" gt "${v[j+1]}"; then
      t=${v[j]}; v[j]=${v[j+1]}; v[j+1]=$t
    fi
  done
done
printf '%s\n' "${v[@]}" > sorted.txt
