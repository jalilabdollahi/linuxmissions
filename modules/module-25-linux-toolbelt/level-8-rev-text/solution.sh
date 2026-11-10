#!/bin/bash
# 1. reduce each URL to a lower-case host.
sed -E 's#^[A-Za-z]+://##; s#[/?].*##; s#:[0-9]+$##; s#\.$##' urls.txt | tr 'A-Z' 'a-z' > hosts.tmp
# 2. hosts under a two-level suffix keep 3 labels, the others 2 (rev makes "last N labels" a plain cut).
re=$(sed 's/\./\\./g' two-level-suffixes.txt | paste -sd'|')
{
  grep -E "\.($re)\$" hosts.tmp | rev | cut -d. -f1-3 | rev
  grep -vE "\.($re)\$" hosts.tmp | rev | cut -d. -f1-2 | rev
} | sort | uniq -c | LC_ALL=C sort -k1,1nr -k2,2 | awk '{print $1, $2}' > domains.txt
rm hosts.tmp
head -5 domains.txt
