#!/bin/bash
# Only query lines, field 6 = the name; normalise it, then count.
grep 'query\[' dnsmasq.log | awk '{ print $6 }' | tr 'A-Z' 'a-z' | sed 's/\.$//' | sort > names.txt
uniq -c names.txt | awk '$1 >= 3' | sort -rn > beacons.txt
uniq -u names.txt > once.txt
head beacons.txt once.txt
