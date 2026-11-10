#!/bin/bash
# Path lists compared with comm; content compared by sha256 for the files both sides have.
cut -f1 MANIFEST.tsv | LC_ALL=C sort > want.lst
(cd restored && find . -type f | LC_ALL=C sort) > have.lst
{
  echo "== MISSING =="
  comm -23 want.lst have.lst
  echo "== EXTRA =="
  comm -13 want.lst have.lst
  echo "== CORRUPTED =="
  comm -12 want.lst have.lst | while IFS= read -r p; do
    now=$(sha256sum < "restored/$p" | cut -d' ' -f1)
    was=$(awk -F'\t' -v p="$p" '$1 == p {print $4}' MANIFEST.tsv)
    [ "$now" = "$was" ] || echo "$p"
  done
} > verify-report.txt
rm -f want.lst have.lst
cat verify-report.txt
