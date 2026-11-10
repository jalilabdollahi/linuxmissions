#!/bin/bash
# For each name: keep only the IPv4 lines of `dig +short` (CNAME targets are
# names, not addresses); no address at all means the name does not exist.
while read -r host; do
  ips="$(./dig +short "$host" | grep -E '^[0-9.]+$')"
  if [ -z "$ips" ]; then
    echo "$host NXDOMAIN"
  else
    for ip in $ips; do
      echo "$host $ip"
    done
  fi
done < hosts.txt > resolved.txt
cat resolved.txt
