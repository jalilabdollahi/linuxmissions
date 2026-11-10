#!/bin/bash
best=$(for r in releases/*/; do r=${r%/}; n=$(awk '$4 >= 500' "$r/health.log" | wc -l); [ "$n" -eq 0 ] && basename "$r"; done | sort -V | tail -1)
echo "rolling back to $best"
ln -sfn "releases/$best" current
./appctl reload
