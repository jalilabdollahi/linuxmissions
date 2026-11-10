#!/bin/bash
# Files of the last 7 days (both relays, plain and gz) as one stream; remember
# each queue ID's sender domain, mark the bounced IDs, count at the end.
find var/log -name 'mail.log*' -mtime -7 | sort
find var/log -name 'mail.log*' -mtime -7 -exec gzip -cdf {} + \
  | awk '$7 ~ /^from=<.*@/ { d = $7; sub(/.*@/, "", d); sub(/>.*/, "", d); from[$6] = tolower(d) }
         /status=bounced/ { bounced[$6] = 1 }
         END { for (q in bounced) if (q in from) print from[q] }' \
  | sort | uniq -c | sort -k1,1nr -k2,2 | head -5 | awk '{ print NR, $2, $1 }' > report.txt
cat report.txt
