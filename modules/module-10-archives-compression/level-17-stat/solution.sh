#!/bin/bash
# List: compare stat's mode and mtime (of the entry itself) with each MANIFEST line.
grep -v '^#' MANIFEST | while read -r mode epoch path; do
  [ "$(stat -c '%a %Y' "$path")" = "$mode $epoch" ] || echo "$path"
done > drift.txt
cat drift.txt
# Fix: chmod everything except the symlink, touch -h sets the link's own time.
grep -v '^#' MANIFEST | while read -r mode epoch path; do
  [ -L "$path" ] || chmod "$mode" "$path"
  touch -h -d "@$epoch" "$path"
done
