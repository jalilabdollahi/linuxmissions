#!/bin/bash
# Per interface: the transns (carrier transitions) and crc counters from each
# capture; the one whose transns moved is flapping. Duplex from sysfs.
counters() {
  awk '/^[0-9]+: / { sub(":", "", $2); ifc = $2 }
       /RX errors:/ { getline; crc[ifc] = $2 }
       /TX errors:/ { getline; print ifc, $5, crc[ifc] }' "$1"
}
counters ip-link-1402.txt > before.txt
counters ip-link-1403.txt > after.txt
flap=$(join before.txt after.txt | awk '$2 != $4 { print $1 }')
crc=$(join before.txt after.txt | awk -v i="$flap" '$1 == i { print $5 - $3 }')
half=$(grep '/duplex:half$' sysfs-net.txt | cut -d/ -f5)
printf 'FLAPPING=%s\nDUPLEX_MISMATCH=%s\nCRC_DELTA=%s\n' "$flap" "$half" "$crc" > link.env
cat link.env
