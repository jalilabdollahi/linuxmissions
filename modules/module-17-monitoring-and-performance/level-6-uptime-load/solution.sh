#!/bin/bash
sed 's/: .*load average: /\t/; s/, /\t/g' uptime.txt | sort > load.tsv
sort inventory.tsv > cpus.tsv
join -t "$(printf '\t')" load.tsv cpus.tsv | awk -F'\t' '$3 / $5 > 1.0 {print $1}' > overloaded.txt
rm -f load.tsv cpus.tsv
