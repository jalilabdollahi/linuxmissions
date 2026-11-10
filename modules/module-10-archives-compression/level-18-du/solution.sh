#!/bin/bash
# Outermost cache dirs only (-prune), their disk usage in KiB, keep > 5 MiB, largest first.
find projects -type d \( -name node_modules -o -name .cache -o -name target -o -name build \) -prune \
  -exec du -sk {} + | awk '$1 > 5120' | sort -nr > bloat.txt
cat bloat.txt
