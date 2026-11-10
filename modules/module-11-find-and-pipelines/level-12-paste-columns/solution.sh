#!/bin/bash
od -c cpu.txt | head -2
# Strip the \r from cpu.txt and paste it in the middle (- = standard input).
tr -d '\r' < cpu.txt | paste hosts.txt - mem.txt > report.tsv
# Hosts with cpu >= 90, joined into one comma-separated line.
awk -F'\t' '$2 >= 90 { print $1 }' report.tsv | paste -s -d, - > limit.txt
head -3 report.tsv; cat limit.txt
