#!/bin/bash
tr -d '\r' < mirror/SHA256SUMS | sed 's/^\([0-9a-f]*\) [ *]/\1  /' > sums.clean
flock mirror/upload.lock true
mkdir -p public
: > rejected.txt
while read -r hash name; do
  if [ -f "mirror/data/$name" ] && echo "$hash  mirror/data/$name" | sha256sum -c --quiet - 2>/dev/null; then
    cp -- "mirror/data/$name" public/
  else
    echo "$name" >> rejected.txt
  fi
done < sums.clean
sort -o rejected.txt rejected.txt
