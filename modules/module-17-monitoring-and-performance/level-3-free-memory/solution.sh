#!/bin/bash
total=$(awk '/^Mem:/ {print $2}' free2.txt)
avail=$(awk '/^Mem:/ {print $7}' free2.txt)
swap1=$(awk '/^Swap:/ {print $3}' free1.txt)
swap2=$(awk '/^Swap:/ {print $3}' free2.txt)
verdict=ok
if [ $((avail * 10)) -lt "$total" ] || [ "$swap2" -gt "$swap1" ]; then verdict=pressure; fi
printf 'available_mib=%s\nswap_used_mib=%s\nverdict=%s\n' "$avail" "$swap2" "$verdict" > memory.env
