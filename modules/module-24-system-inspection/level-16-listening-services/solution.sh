#!/bin/bash
# For each listening port: the owner's cgroup (last component), or, when only PID 1
# holds the socket, the service behind the matching .socket file.
{
echo "port,proto,unit"
ss_ports=$(awk '{n=split($4, a, ":"); print a[n]}' capture/ss.txt | sort -un)
for port in $ss_ports; do
  line=$(awk -v p=":$port\$" '$4 ~ p' capture/ss.txt | head -1)
  pid=$(grep -o 'pid=[0-9]*' <<< "$line" | cut -d= -f2 | grep -vx 1 | head -1)
  if [ -n "$pid" ]; then
    unit=$(basename "$(cut -d: -f3 capture/proc/$pid/cgroup)")
  else
    sock=$(grep -lE "^ListenStream=(.*[:.])?$port\$" capture/units/*.socket | head -1)
    unit=$(sed -n 's/^Service=//p' "$sock")
    [ -n "$unit" ] || unit=$(basename "${sock%.socket}").service
  fi
  echo "$port,tcp,$unit"
done
} > inventory.csv
cat inventory.csv
