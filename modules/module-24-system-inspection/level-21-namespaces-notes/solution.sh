#!/bin/bash
hostpid=$(jq -r '.namespaces[] | select(.type == "pid" and .pid == 1) | .ns' capture/lsns.json)
hostnet=$(jq -r '.namespaces[] | select(.type == "net" and .pid == 1) | .ns' capture/lsns.json)
awk -v hp="$hostpid" -v hn="$hostnet" 'NR > 1 && $3 != hp && $4 == hn {print $1, $5}' capture/ps.txt | sort -n > host_net.txt
cat host_net.txt
