#!/bin/bash
# Test each dump fully; bzip2 -t exits non-zero for any damage.
for f in dumps/*.sql.bz2; do
  if bzip2 -t "$f" 2>/dev/null; then
    bunzip2 -c "$f" > "restore/$(basename "$f" .bz2)"
  else
    mv "$f" quarantine/
  fi
done
ls quarantine restore
