#!/bin/bash
# 1. the boundary string is declared in the header
b=$(grep -o 'boundary="[^"]*"' bundle.eml | cut -d'"' -f2)
# 2. cut the message at every boundary line: p-00 = mail headers, p-01..p-03 = the parts
mkdir -p parts
csplit -z -s -f parts/p- -b '%02d' bundle.eml "/^--$b/" '{*}'
# 3. a part is its own headers, a blank line, then base64: drop everything up to the blank line and decode
for f in parts/p-0[1-3]; do
  sed '1,/^$/d' "$f" | base64 -d > "$f.bin"
  echo "$f: $(file -b "$f.bin" | cut -c1-60)"
done
# 4. identify each part by what file says about the decoded bytes, and read it accordingly
for f in parts/p-0[1-3].bin; do
  case $(file -b "$f") in
    gzip*)   kernel=$(zcat "$f" | grep -o 'Linux version [^ ]*' | cut -d' ' -f3) ;;
    *UTF-16*) errors=$(iconv -f UTF-16 -t UTF-8 "$f" | grep -c ' ERROR ') ;;
    *text*)  setting=$(grep 'Recommended setting:' "$f" | sed 's/.*: //') ;;
  esac
done
printf 'errors: %s\nkernel: %s\nsetting: %s\n' "$errors" "$kernel" "$setting" > summary.txt
cat summary.txt
