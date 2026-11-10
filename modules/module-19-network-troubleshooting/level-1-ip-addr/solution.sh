#!/bin/bash
# 10.20.0.0/22 = 10.20.0.0 - 10.20.3.255, so the third octet is 0-3.
line=$(grep -E 'inet 10\.20\.[0-3]\.' ip-addr.txt)
iface=$(echo "$line" | awk '{print $NF}')
addr=$(echo "$line" | awk '{print $2}' | cut -d/ -f1)
state=$(grep -E "^[0-9]+: $iface[@:]" ip-addr.txt | sed 's/.* state \([A-Z]*\) .*/\1/')
printf 'IFACE=%s\nADDR=%s\nSTATE=%s\n' "$iface" "$addr" "$state" > db-iface.env
cat db-iface.env
