#!/bin/bash
# 1. cut at every --- line; -z drops the empty piece before the first one
mkdir -p manifests
csplit -z -s -f manifests/piece- -b '%02d.part' all.yaml '/^---$/' '{*}'
# 2. name each piece after its kind and its metadata name, dropping the --- line
for f in manifests/piece-*.part; do
  kind=$(grep -m1 '^kind:' "$f" | cut -d' ' -f2 | tr 'A-Z' 'a-z')
  name=$(sed -n '/^metadata:/,/^[a-z]/{s/^  name: //p}' "$f" | head -1)
  if [ -z "$kind" ]; then rm "$f"; continue; fi   # the trailing comment piece
  sed '1d' "$f" > "manifests/$kind-$name.yaml"
  rm "$f"
done
ls manifests
