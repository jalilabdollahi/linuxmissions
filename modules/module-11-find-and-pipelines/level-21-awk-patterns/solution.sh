#!/bin/bash
# Field 1 user, 4 %MEM, 8 STAT; the command is everything from field 11 on.
head -1 ps-aux.txt
awk 'NR > 1 && $1 == "www-data" && $4 > 5 { out = $2; for (i = 11; i <= NF; i++) out = out " " $i; print out }' ps-aux.txt > heavy.txt
awk 'NR > 1 && $8 ~ /^[DZ]/ { out = $2; for (i = 11; i <= NF; i++) out = out " " $i; print out }' ps-aux.txt > stuck.txt
cat stuck.txt
