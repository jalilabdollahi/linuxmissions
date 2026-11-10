#!/bin/bash
cat fleet/web-01/uname.txt fleet/web-01/kernels.txt
for d in fleet/*/; do
  h=$(basename "$d")
  run=$(awk '{print $3}' "$d/uname.txt")
  newest=$(awk '$1 == "ii" && $2 ~ /^linux-image-[0-9]/ { sub("linux-image-", "", $2); print $2 }' "$d/kernels.txt" | sort -V | tail -n 1)
  if [ "$run" != "$newest" ] && [ "$(printf '%s\n%s\n' "$run" "$newest" | sort -V | head -n 1)" = "$run" ]; then
    echo "$h"
  fi
done | sort > reboot_needed.txt
cat reboot_needed.txt
