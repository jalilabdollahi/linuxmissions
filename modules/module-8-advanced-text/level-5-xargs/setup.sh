#!/bin/bash
SANDBOX="$1"

mkdir -p "$SANDBOX/files"
for i in $(seq 1 50); do
  echo "normal text $i" > "$SANDBOX/files/file-$i.txt"
done
echo "contains NEBULA_KEY right here" > "$SANDBOX/files/file-37.txt"
