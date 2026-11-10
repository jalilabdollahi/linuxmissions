#!/bin/bash
# Normalise the three sources to sorted lists of lowercase usernames, then
# compare them with comm.
export LC_ALL=C
head -4 licenses.txt directory.csv active_30d.log | cat -A | head -20
grep -v '^#' licenses.txt | tr -d ' \r' | tr 'A-Z' 'a-z' | grep . | sort -u > licensed.lst
awk -F, 'NR > 1 && $4 == "yes" { print $1 }' directory.csv | sort -u > enabled.lst
grep ' result=success ' active_30d.log | grep -o 'user=[^ ]*' | cut -d= -f2 | tr 'A-Z' 'a-z' | sort -u > loggedin.lst
comm -12 enabled.lst loggedin.lst > active.lst
comm -23 licensed.lst active.lst > unused_seats.txt
comm -13 licensed.lst active.lst > unlicensed_active.txt
wc -l unused_seats.txt unlicensed_active.txt
