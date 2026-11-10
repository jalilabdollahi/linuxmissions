#!/bin/bash
# -o: print only the match; -w: the match must not touch other letters/digits,
# so "2024.04.08.1" (a build number) is not cut down to "024.04.08.1".
grep -Eow '([0-9]{1,3}\.){3}[0-9]{1,3}' app.log | sort -u > ips.txt
cat ips.txt
