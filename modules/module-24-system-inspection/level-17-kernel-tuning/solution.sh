#!/bin/bash
# compare each live value with the requirement and write only what is missing
out=sysctl.d/90-search.conf
: > $out
for kv in "vm.max_map_count 262144" "fs.file-max 2097152" "net.core.somaxconn 4096"; do
  set -- $kv
  [ "$(sysctl -n $1)" -ge "$2" ] || echo "$1 = $2" >> $out
done
[ "$(sysctl -n vm.swappiness)" = 1 ] || echo "vm.swappiness = 1" >> $out
read -r lo hi < <(sysctl -n net.ipv4.ip_local_port_range)
[ "$lo" = 1024 ] || echo "net.ipv4.ip_local_port_range = 1024 $hi" >> $out
cat $out
