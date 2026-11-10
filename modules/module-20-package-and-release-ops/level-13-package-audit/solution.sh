#!/bin/bash
export LC_ALL=C
norm() { awk '{ sub(/:[a-z0-9]+$/, "", $1); print $1 "\t" $2 }' "$1" | sort -t $'\t' -k1,1; }
norm prod.txt > prod.norm
norm staging.txt > staging.norm
join -t $'\t' -a1 -a2 -e - -o 0,1.2,2.2 prod.norm staging.norm | awk -F '\t' '$2 != $3' > drift.tsv
