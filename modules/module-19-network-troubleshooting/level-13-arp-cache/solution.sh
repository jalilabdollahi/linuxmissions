#!/bin/bash
# IP -> MAC pairs for VLAN 30 (lower-cased, FAILED lines have no lladdr),
# the IP with two different MACs, then inventory and OUI lookups.
pairs=$(cat captures/neigh-*.txt | awk '$3 == "eth0.30" && $4 == "lladdr" { print $1, tolower($5) }' | sort -u)
ip=$(echo "$pairs" | awk '{ print $1 }' | uniq -d)
known=$(grep "^$ip," vlan30-inventory.csv | cut -d, -f3 | tr 'A-F' 'a-f')
rogue=$(echo "$pairs" | awk -v ip="$ip" '$1 == ip { print $2 }' | grep -v "$known")
oui=$(echo "$rogue" | cut -c1-8 | tr 'a-f:' 'A-F-')
vendor=$(grep "^$oui *(hex)" oui.txt | cut -f3)
printf 'IP=%s\nKNOWN_MAC=%s\nROGUE_MAC=%s\nROGUE_VENDOR=%s\n' "$ip" "$known" "$rogue" "$vendor" > conflict.env
cat conflict.env
