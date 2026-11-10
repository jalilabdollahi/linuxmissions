#!/bin/bash
# CSV: BOM first, then quote every field that has a comma or a quote (with
# the quotes doubled). JSON: let jq read the raw lines, zip them with the
# header and convert the two numeric columns.
head -5 clean.tsv
printf '\xef\xbb\xbf' > export.csv
awk -F'\t' -v OFS=, '{ for (i = 1; i <= NF; i++) if ($i ~ /[",]/) { gsub(/"/, "\"\"", $i); $i = "\"" $i "\"" } $1 = $1; print }' clean.tsv >> export.csv
jq -R -s 'split("\n") | map(select(length > 0) | split("\t")) | .[0] as $h | .[1:] | map([$h, .] | transpose | map({key: .[0], value: .[1]}) | from_entries | .id |= tonumber | .amount |= tonumber)' clean.tsv > export.json
head -4 export.csv
jq '.[0]' export.json
