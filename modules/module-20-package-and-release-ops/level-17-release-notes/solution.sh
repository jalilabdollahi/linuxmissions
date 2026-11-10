#!/bin/bash
awk '/tag: v2\.4\.0[,)]/ { on = 1; next } /tag: v2\.3\.0[,)]/ { on = 0 } on' gitlog.txt | awk '{ a[NR] = $0 } END { for (i = NR; i >= 1; i--) print a[i] }' > range.txt
sed -nE 's/^[0-9a-f]+ Revert "(.*)" \(#[0-9]+\)$/\1/p' range.txt > reverted.txt
grep -vF -f reverted.txt range.txt | grep -v ' Revert "' > keep.txt
sec() { grep -E "$1" keep.txt | sed -E 's/^[0-9a-f]+ [a-z]+(\([^)]*\))?!?: /- /'; }
{
  echo "# Release v2.4.0"; echo; echo "## Features"; echo
  sec '^[0-9a-f]+ feat(\([^)]*\))?: '
  echo; echo "## Fixes"; echo
  sec '^[0-9a-f]+ fix(\([^)]*\))?: '
  echo; echo "## Breaking"; echo
  sec '^[0-9a-f]+ [a-z]+(\([^)]*\))?!: '
} > RELEASE_NOTES.md
