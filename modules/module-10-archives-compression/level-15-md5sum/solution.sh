#!/bin/bash
# Hash every file, keep the first file per hash, move every later one.
mkdir -p dupes
md5sum photos/* | sort | awk 'seen[$1]++' | cut -c35- |
  while IFS= read -r f; do mv -- "$f" dupes/; done
ls photos | wc -l
ls dupes | wc -l
