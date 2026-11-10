#!/bin/bash
# Reproduce systemd-sysctl: per file name the highest-priority directory wins
# (etc > run > usr/lib), apply the files in name order, remember the last setter.
cd capture || exit 1
declare -A src
for d in usr/lib/sysctl.d run/sysctl.d etc/sysctl.d; do      # later dir overwrites: etc ends up winning
  for f in $d/*.conf; do src[$(basename "$f")]=$f; done
done
for n in $(printf '%s\n' "${!src[@]}" | LC_ALL=C sort); do
  f=${src[$n]}
  grep -hv '^[[:space:]]*[#;]' "$f" | grep '=' | while IFS='=' read -r k v; do
    k=$(echo "$k" | tr -d ' \t' | sed 's/^-//' | tr / .)
    v=$(echo $v)
    echo "$k=$v $f"
  done
done | awk '{ key = $0; sub(/=.*/, "", key); last[key] = $0 } END { for (k in last) print last[k] }' | LC_ALL=C sort > ../effective.txt
cat ../effective.txt
