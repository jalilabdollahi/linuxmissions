#!/bin/bash
# Turn CRs and non-breaking spaces into something awk can see, then clean
# every field and keep the first record per username.
head -3 users.tsv | cat -A
grep -c $'\xc2\xa0' users.tsv
sed $'s/\r$//; s/\xc2\xa0/ /g' users.tsv \
  | awk -F'\t' -v OFS='\t' '{ for (i = 1; i <= NF; i++) { gsub(/ +/, " ", $i); sub(/^ /, "", $i); sub(/ $/, "", $i) } } !seen[$1]++' > users_clean.tsv
head -3 users_clean.tsv | cat -A
