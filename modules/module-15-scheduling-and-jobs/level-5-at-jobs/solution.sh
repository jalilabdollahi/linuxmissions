#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
atq
for j in 4 5 6; do echo "== job $j"; at -c "$j" | tail -n 2 | head -n 1; done
atrm 4
echo '/usr/local/bin/pgctl restart main --mode=fast' | at 03:00 tomorrow
atq
