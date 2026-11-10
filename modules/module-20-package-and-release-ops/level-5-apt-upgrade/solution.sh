#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
apt-get -s upgrade | awk '/have been kept back/ {on=1; next} on && /^  / {for (i=1;i<=NF;i++) print $i; next} {on=0}' > kept-back.txt
cat kept-back.txt
