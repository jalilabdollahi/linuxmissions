#!/bin/bash
# Classify field 2 of etc/shadow: empty = NP, starts with ! or * = L, anything else = P.
cut -d: -f1,2 etc/shadow
awk -F: '{ s = ($2 == "") ? "NP" : (($2 ~ /^[!*]/) ? "L" : "P"); print $1, s }' etc/shadow > status.txt
awk '$2 == "NP" { print $1 }' status.txt > np.txt
cat status.txt np.txt
