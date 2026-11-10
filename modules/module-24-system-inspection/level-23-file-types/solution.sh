#!/bin/bash
# classify by content (mime type of the file, and of its decompressed content for archives)
cls() {
  case "$1" in
    application/x-pie-executable|application/x-executable|application/x-sharedlib) echo elf ;;
    image/*) echo image ;;
    text/plain|text/csv) echo text ;;
    text/*) echo script ;;
  esac
}
for f in quarantine/*; do
  m=$(file -b --mime-type "$f")
  case "$m" in
    application/gzip|application/x-bzip2|application/x-xz) c="archive:$(cls "$(file -zb --mime-type "$f")")" ;;
    *) c=$(cls "$m") ;;
  esac
  printf '%s\t%s\n' "$(basename "$f")" "$c"
done | LC_ALL=C sort > types.tsv
cat types.tsv
