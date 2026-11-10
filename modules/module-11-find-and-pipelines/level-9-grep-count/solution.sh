#!/bin/bash
# -w: ERROR as a whole word (not NOERROR, not ERRORS_RESET); -c: lines per file.
grep -c -w ERROR logs/*.log | head -3
grep -c -w ERROR logs/*.log | awk -F: '$2 > 50 { sub(/^logs\//, "", $1); print $1, $2 }' | sort -k2,2nr > noisy.txt
cat noisy.txt
