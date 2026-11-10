#!/bin/bash
# Line number of the second real deploy marker (dry runs have "(dry-run)"
# where the colon would be), the first panic after it, and the trace id on
# the line two above that panic.
m=$(grep -n 'deploy finished: ' huge.log | sed -n 2p | cut -d: -f1)
p=$(awk -v m="$m" 'NR > m && / panic: / { print NR; exit }' huge.log)
sed -n "$((p - 2)),${p}p" huge.log
sed -n "$((p - 2))p" huge.log | grep -o 'trace=[0-9a-f]*' | cut -d= -f2 > trace.txt
cat trace.txt
