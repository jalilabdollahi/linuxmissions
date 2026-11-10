#!/bin/bash
# Normalise the inventory MACs to the lease format, sort both inputs on the
# MAC, left-join, then sort by IP.
head -3 dnsmasq.leases inventory.csv
tail -n +2 inventory.csv | tr 'A-Z,-' 'a-z :' | sort > inventory.sorted
sort -k2,2 dnsmasq.leases > leases.sorted
join -1 2 -2 1 -a1 -e UNKNOWN -o 1.3,1.2,2.2 leases.sorted inventory.sorted \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n > owners.txt
head owners.txt
