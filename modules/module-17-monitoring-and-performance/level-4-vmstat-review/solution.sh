#!/bin/bash
first=$(awk '$1 ~ /^[0-9]/ {n++; if ($7 > 0 || $8 > 0) {print n; exit}}' vmstat.txt)
high=$(awk '$1 ~ /^[0-9]/ && $16 > 30' vmstat.txt | wc -l)
printf 'FIRST_SWAP_SAMPLE=%s\nHIGH_IOWAIT_SAMPLES=%s\n' "$first" "$high" > answers.env
