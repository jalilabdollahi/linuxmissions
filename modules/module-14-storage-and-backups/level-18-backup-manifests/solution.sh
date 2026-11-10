#!/bin/bash
# Regular files and symlinks separately; read file names NUL-terminated so spaces
# survive; hash the content through stdin so the name is not in sha256sum's output.
cd backup || exit 1
{
  find . -type f -print0 | while IFS= read -r -d '' f; do
    printf '%s\t%s\t%s\t%s\n' "$f" "$(stat -c %s "$f")" "$(stat -c %a "$f")" "$(sha256sum < "$f" | cut -d' ' -f1)"
  done
  find . -type l -print0 | while IFS= read -r -d '' l; do
    printf '%s\tsymlink\t%s\n' "$l" "$(readlink "$l")"
  done
} | LC_ALL=C sort > ../MANIFEST.tsv
cd ..
wc -l MANIFEST.tsv
head -5 MANIFEST.tsv
