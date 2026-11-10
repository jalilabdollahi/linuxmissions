#!/bin/bash
# Decompress to stdout, one output file per input; the .gz stays where it is.
for f in inbox/*.csv.gz; do
  gunzip -c "$f" > "import/$(basename "$f" .gz)"
done
ls -l import
